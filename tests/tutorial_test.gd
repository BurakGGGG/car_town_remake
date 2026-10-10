extends SceneTree
## EĞİTİM (Rıza Usta'nın dersleri) — TutorialManager kuralları, SaveManager "tutorial" bölümü turu,
## eski kayıt kararı (seviye 2+ → dersler bitmiş), ilerleme karşılaştırmasına girmemesi, yarış dersinin
## rakibi bekletmesi ve oyunda ilk dersin hoş geldin kartıyla açılması.
## Çalıştırma: tools/run_tests.sh tutorial_test
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


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))

	print("== 1) Oyun içinde: durum ve kayıt ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var tutorial: TutorialManager = get_first_node_in_group("tutorial") as TutorialManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	check(tutorial != null, "GarageSystem TutorialManager'ı kurdu")
	save.new_game()
	await frames(2)
	check(tutorial.done_count() == 0 and not tutorial.all_done(), "yeni oyunda hiçbir ders bitmemiş")
	check(save.snapshot().has("tutorial"), "kayıtta 'tutorial' bölümü var")
	var before: bool = save.has_progress()
	tutorial.mark_done(TutorialManager.BASICS)
	tutorial.mark_done(TutorialManager.BASICS)
	tutorial.mark_done(&"yok_boyle_ders")
	check(tutorial.done_count() == 1 and tutorial.is_done(TutorialManager.BASICS), "ders bir kez işaretlenir, bilinmeyen ders yok sayılır")
	check(save.has_progress() == before, "ders bitirmek bulut kaydını 'ilerlemiş' göstermez")
	save.save_game()
	tutorial.reset()
	save.load_game()
	check(tutorial.is_done(TutorialManager.BASICS) and tutorial.done_count() == 1, "kayıttan biten ders geri geldi")
	check(tutorial.rewarded(), "ilk oynayışta ders ödülü verilir")

	print("== 2) Eski kayıt (bölüm yok) ==")
	var legacy: Dictionary = save.snapshot()
	legacy.erase("tutorial")
	legacy["progress"]["level"] = 1
	check(save.apply_snapshot(legacy), "bölümsüz kayıt yüklenir")
	check(tutorial.done_count() == 0, "seviye 1 eski oyuncu eğitimi baştan görür")
	legacy["progress"]["level"] = 4
	save.apply_snapshot(legacy)
	check(tutorial.all_done(), "seviye 4 eski oyuncuya eğitim dayatılmaz (hepsi bitmiş)")
	var broken: Dictionary = save.snapshot()
	broken["tutorial"] = {"done": ["race", 42, "uydurma", "race"], "replay": "x"}
	save.apply_snapshot(broken)
	check(tutorial.done_count() == 1 and tutorial.is_done(TutorialManager.RACE), "bozuk liste süzülür (%d)" % tutorial.done_count())

	print("== 3) Baştan oynama ve atlama ==")
	tutorial.restart()
	check(tutorial.done_count() == 0 and not tutorial.rewarded(), "NASIL OYNANIR? dersleri sıfırlar, ödül ikinci kez yok")
	save.save_game()
	tutorial.reset()
	save.load_game()
	check(not tutorial.rewarded(), "ödülsüz bayrak kayıtta kalır")
	tutorial.skip_all()
	check(tutorial.all_done(), "EĞİTİMİ ATLA bütün dersleri bitirir")

	print("== 4) Yarış dersi rakibi bekletir ==")
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var got: bool = false
	var deadline: int = Time.get_ticks_msec() + 8000
	while not got and Time.get_ticks_msec() < deadline:   # trafik başsızda birkaç saniyede dolar
		got = race.request_challenge_now()
		await frames(5)
	if got:
		race.set("_wait", 0.05)
		race.tutorial_hold = true
		await create_timer(0.3).timeout
		check(race.has_challenge(), "eğitim anlatırken rakip zaman aşımıyla gitmez")
		race.tutorial_hold = false
		await create_timer(0.3).timeout
		check(not race.has_challenge(), "bekletme kalkınca rakip yola döner")
	else:
		check(false, "rakip getirilemedi")

	print("== 5) İlk ders hoş geldin kartıyla açılır ==")
	save.new_game()
	progress.load_state(1, 0, progress.gems)
	var hud: Hud = main.find_child("HUD", true, false)
	var director: TutorialDirector = hud.tutorial
	if TutorialDirector.disabled_by_env():
		print("  (CT_NO_TUTORIAL=1: kart bekleme denetimi atlandı)")
		check(not director.is_running(), "ortam değişkeni eğitimi kapatır")
	else:
		var until: int = Time.get_ticks_msec() + 6000
		while not director.is_running() and Time.get_ticks_msec() < until:
			await process_frame
		check(director.is_running() and hud.tutorial_overlay.chapter_open(), "hoş geldin kartı açıldı")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
