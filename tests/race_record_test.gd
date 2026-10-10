extends SceneTree
## KİŞİSEL YARIŞ REKORU + HIZ SINIFI ÖLÇEĞİ — RaceManager rekor kuralları, kayıt turu (SaveManager
## "race" bölümü), bozuk kayıt reddi, eski kayıt (bölümsüz) uyumu ve pistin araca göre ölçeği.
## Çalıştırma: tools/run_tests.sh race_record_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _trace(time: float) -> PackedFloat32Array:
	var trace: PackedFloat32Array = PackedFloat32Array()
	var steps: int = int(time / RaceManager.TRACE_STEP)
	for i: int in steps + 1:
		trace.append(DragRaceSim.DISTANCE * pow(float(i) / float(steps), 2.0))
	return trace


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))

	print("== 1) Rekor kuralları ==")
	var race: RaceManager = RaceManager.new()
	var changes: Array[int] = [0]
	race.records_changed.connect(func() -> void: changes[0] += 1)
	check(race.best_time(&"tofas_sahin") < 0.0, "rekor yokken -1")
	check(race.submit_time(&"tofas_sahin", 12.4, _trace(12.4)), "ilk koşu rekordur")
	check(is_equal_approx(race.best_time(&"tofas_sahin"), 12.4), "rekor saklandı")
	check(not race.submit_time(&"tofas_sahin", 12.9, _trace(12.9)), "daha yavaş koşu rekor değil")
	check(not race.submit_time(&"tofas_sahin", 12.4, _trace(12.4)), "eşit süre rekor değil")
	check(race.submit_time(&"tofas_sahin", 12.1, _trace(12.1)), "daha hızlı koşu yeni rekor")
	check(is_equal_approx(race.best_time(&"tofas_sahin"), 12.1), "rekor güncellendi")
	check(race.best_time(&"lambo_huracan") < 0.0, "rekor ARAÇ BAŞINA (başka araç etkilenmez)")
	check(not race.submit_time(&"tofas_sahin", 1.0, _trace(1.0)), "imkânsız süre reddedilir")
	check(changes[0] == 2, "yalnızca rekorlar kayıt sinyali verir (%d)" % changes[0])
	check(race.best_trace(&"tofas_sahin").size() > 10, "hayalet izi saklandı")

	print("== 2) Kayıt turu ve bozuk veri ==")
	var state: Dictionary = JSON.parse_string(JSON.stringify(race.state()))
	var copy: RaceManager = RaceManager.new()
	copy.load_state(state)
	check(absf(copy.best_time(&"tofas_sahin") - 12.1) < 0.001, "JSON turundan sonra rekor aynı")
	check(copy.best_trace(&"tofas_sahin").size() == race.best_trace(&"tofas_sahin").size(), "JSON turundan sonra iz aynı uzunlukta")
	copy.load_state({"best": {
		"tofas_sahin": {"time": "abc", "trace": [1, 2]},
		"yok_boyle_arac": {"time": 11.0, "trace": []},
		"lambo_huracan": {"time": 10.5, "trace": [0, 50, 9999, "x"]},
		"bmw_e46": "bozuk",
	}})
	check(copy.best_time(&"tofas_sahin") < 0.0, "sayı olmayan süre yok sayılır")
	check(copy.best_time(&"yok_boyle_arac") < 0.0, "katalogda olmayan araç yok sayılır")
	check(is_equal_approx(copy.best_time(&"lambo_huracan"), 10.5), "geçerli kayıt yüklenir")
	var lambo_trace: PackedFloat32Array = copy.best_trace(&"lambo_huracan")
	check(lambo_trace.size() == 4 and lambo_trace[2] <= DragRaceSim.DISTANCE, "iz değerleri pist sınırında kırpılır")
	copy.load_state({"best": "bozuk"})
	check(copy.best_time(&"lambo_huracan") < 0.0, "bozuk bölüm → rekorsuz")
	race.free()
	copy.free()

	print("== 3) Oyun içinde: SaveManager 'race' bölümü ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var live: RaceManager = get_first_node_in_group("race") as RaceManager
	save.new_game()
	await frames(2)
	check(live.best_time(&"tofas_sahin") < 0.0, "yeni oyunda rekor yok")
	live.submit_time(&"tofas_sahin", 11.8, _trace(11.8))
	check(save.snapshot().has("race"), "kayıtta 'race' bölümü var")
	save.save_game()
	live.reset()
	check(live.best_time(&"tofas_sahin") < 0.0, "sıfırlandı")
	save.load_game()
	check(absf(live.best_time(&"tofas_sahin") - 11.8) < 0.001, "kayıttan rekor geri geldi")
	var legacy: Dictionary = save.snapshot()
	legacy.erase("race")
	check(save.apply_snapshot(legacy), "eski kayıt (race bölümü yok) yüklenir")
	check(live.best_time(&"tofas_sahin") < 0.0, "eski kayıtta rekorsuz başlanır")
	save.new_game()

	print("== 4) Hız sınıfı ölçeği ==")
	var slow: float = DragTrack.scale_for(&"tofas_sahin")
	var fast: float = DragTrack.scale_for(&"lambo_huracan")
	check(is_equal_approx(slow, DragTrack.SCALE_MIN), "ekonomi aracı gerçek ölçekte (%.2f)" % slow)
	check(fast > 1.5 and fast <= DragTrack.SCALE_MAX, "süper spor dünyayı hızlı akıtır (%.2f)" % fast)
	var hud: Hud = main.find_child("HUD", true, false)
	var drag: DragRaceScreen = hud.drag_race_screen
	drag.open()
	var track: DragTrack = drag.get("_track")
	var expected: float = DragTrack.TRACK_LENGTH * DragTrack.scale_for(drag.get("_player_id"))
	check(is_equal_approx(track.length, expected), "pist oyuncu aracına göre kuruldu (%.1f)" % track.length)

	print("== 5) Yarış müziği ==")
	var music: GameMusic = root.get_node_or_null(GameMusic.NODE_NAME) as GameMusic
	check(music != null and music.is_racing(), "yarış açılınca yarış teması çalıyor")
	await create_timer(GameMusic.SWAP_TIME + 0.4).timeout
	check(music != null and music.stream_paused, "garaj teması duraklatıldı (yarışta duyulmaz)")
	drag.close()
	check(music != null and not music.stream_paused, "yarış kapanınca garaj teması kaldığı yerden sürüyor")
	await create_timer(GameMusic.SWAP_TIME * 1.5 + 0.4).timeout
	check(music != null and not music.is_racing() and is_equal_approx(music.volume_db, GameMusic.BASE_DB),
		"yarış teması sustu, garaj teması tam sesinde")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
