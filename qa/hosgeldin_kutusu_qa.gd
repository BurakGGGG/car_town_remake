extends SceneTree
## HOŞ GELDİN KUTUSU QA — temiz kayıtla (eğitim kapalı) açılır: araç yok, garajda hediye kutusu var, rakip gelmez,
## hatırlatma bildirimi + kamera kutuya gider; kutu açılınca Tofaş Şahin çıkar (elmas / kasa sayacı değişmez),
## "ilerleme" sayılmaz, kayıttan yeniden yüklemede kutu geri gelmez; YENİ OYUN kutuyu yeniden getirir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/hosgeldin_kutusu_qa.gd --display-driver x11 --resolution 1152x648
## Görüntüler: /home/burak/Projects/ct_shots/hosgeldin/

const OUT: String = "/home/burak/Projects/ct_shots/hosgeldin/"

var _fails: int = 0


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file)
	print("  foto: ", file)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery") as CrateDelivery
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var player: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var missions: MissionManager = get_first_node_in_group("missions") as MissionManager

	print("== YENİ OYUN ==")
	var uid: int = crates.welcome_uid()
	check(own.owned_count() == 0, "yeni oyunda araç yok (%s)" % [own.owned_vehicle_ids()])
	check(uid > 0 and crates.get_crate(uid).get("vehicle") == &"tofas_sahin", "garajda HOŞ GELDİN KUTUSU, içinde Şahin")
	check(delivery.visual_of(uid) != null and crates.can_open(uid), "kutu garaja indi, açılabilir")
	check(not save.has_progress(), "bekleyen kutu ilerleme sayılmaz")
	check(not race.request_challenge_now() and not race.has_challenge(), "araç yokken yarış rakibi gelmez")
	var disk: Dictionary = save.peek()
	check(((disk.get("crates", {}) as Dictionary).get("items", []) as Array).size() == 1, "kutu ilk kayda yazıldı")
	await create_timer(7.0).timeout
	await shot("01_hatirlatma.png")
	check(hud._notice_label.text.begins_with("HOŞ GELDİN HEDİYEN GARAJINDA"), "hatırlatma bildirimi («%s»)" % hud._notice_label.text.replace("\n", " / "))

	print("== AÇILIŞ ==")
	var gems: int = player.gems
	var opened_before: int = int((missions.get("_life") as Dictionary).get(&"crates_opened", 0))
	var results: Array[Dictionary] = []
	delivery.reveal_ready.connect(func(_u: int, r: Dictionary) -> void: results.append(r))
	hud._on_crate_clicked(uid)
	await frames(10)
	await shot("02_soru.png")
	check(hud.crate_panel.mode() == &"prompt", "dokununca soru plakası")
	hud.crate_panel.call("_on_action")
	for i: int in 900:
		if not results.is_empty():
			break
		await process_frame
	await frames(20)
	await shot("03_sonuc.png")
	check(results.size() == 1 and bool(results[0].get("gift", false)), "açıldı, sonuç hediye olarak işaretli")
	check(own.owned_vehicle_ids() == [&"tofas_sahin"] and own.is_discovered(&"tofas_sahin"), "Tofaş Şahin garajda ve koleksiyonda")
	check(player.gems == gems and int(results[0].get("gems", -1)) == 0, "hediye elmas vermez (%d → %d)" % [gems, player.gems])
	var opened_after: int = int((missions.get("_life") as Dictionary).get(&"crates_opened", 0))
	check(opened_after == opened_before, "görevlerin kasa sayacı değişmedi (%d)" % opened_after)
	hud.crate_panel.call("_on_action")
	await create_timer(1.0).timeout
	check(crates.welcome_uid() == 0 and crates.crates().is_empty(), "kutu kalktı")
	check(not save.has_progress(), "kutuyu açmak da ilerleme sayılmaz (bulut kaydı kendiliğinden gelsin)")
	check(race.request_challenge_now(), "araç gelince yarış rakibi gelebilir")
	race.release_challenger()

	print("== KAYIT ==")
	save.save_game()
	save.load_game()
	await frames(10)
	check(own.owned_vehicle_ids() == [&"tofas_sahin"] and crates.welcome_uid() == 0, "yeniden yüklemede kutu geri gelmez")

	print("== YENİ OYUN (sıfırla) ==")
	save.new_game()
	await frames(30)
	var again: int = crates.welcome_uid()
	check(own.owned_count() == 0 and again > 0, "YENİ OYUN: araç yok, kutu yeniden geldi")
	await create_timer(1.5).timeout
	check(delivery.visual_of(again) != null, "yeni kutu garaja indi")
	print("SONUC: fails=%d" % _fails)
	quit()
