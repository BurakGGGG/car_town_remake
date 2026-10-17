extends SceneTree
## OTO MANŞET HABER KAYNAKLARI QA (2026-10-17, adım 3): gerçek oyunda soğuk açılış — 5 saat yokluk (usta kazancı + yarım iş),
## arkadaş verisi (masaüstünde Firebase yok: SocialManager taklit edilir) — Elif seni 4 kez yendi, senin aracın Mert'i
## yendi, Mert'ten cıvata, yeni arkadaş, yeni istek, parça isteği — ve oyun haberleri (dolan hurda yığını, biten modifiye,
## yenilenen görev). Gazete kendiliğinden açılır, toplarken yarış bildirimi çıkmaz, TAMAM'da arkadaş tabanı ilerler.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/haber_kaynaklari_qa.gd --display-driver x11 --resolution 1152x648
##   (1440x648 = 20:9; QA_LANG=es)
## Kareler: /home/burak/Projects/ct_shots/haber_kaynaklari/<tuval>_<dil>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/haber_kaynaklari/"

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func _initialize() -> void:
	get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func hud() -> Hud:
	return root.get_node_or_null("World/HUD") as Hud


func _friend(uid: String, name: String, av: String, flag: String = "TR") -> Dictionary:
	return {"uid": uid, "name": name, "code": "ABC123", "level": 8, "av": av, "frame": "", "flag": flag, "ask_part": "", "ask_at": 0}


func _event(uid: String, name: String, won: bool, mw: int, ml: int, car: StringName, theirs: StringName, at: int) -> Dictionary:
	return {"uid": uid, "name": name, "car": car, "their_car": theirs, "paint": "", "build": {}, "won": won, "revenge": false,
		"mw": mw, "ml": ml, "at": at, "av": "", "frame": "", "flag": "TR"}


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current()]
	(get_first_node_in_group("tutorial") as TutorialManager).mark_done(TutorialManager.BASICS)
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(2)
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(6, 0, 20)
	(get_first_node_in_group("save_manager") as SaveManager).save_game()

	var now: int = int(Time.get_unix_time_from_system())
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	data["away"]["last_seen"] = now - 5 * 3600
	data["repairs"] = [{"vehicle": "tofas_sahin", "colors": {"body": "c0392b"}, "type": "body", "severity": 1.0, "bay": 0,
		"elapsed": 4.0, "duration_scale": 1.0, "reward_scale": 1.15, "boosted": false, "saved_at": now - 5 * 3600}]
	var file: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var old_social: Node = get_first_node_in_group("social")
	reload_current_scene()

	# Yeni sahnenin SocialManager'ı gelir gelmez taklit veri (gazete toplanmadan önce)
	var social: SocialManager = null
	for i: int in 200:
		await process_frame
		var found: Node = get_first_node_in_group("social")
		if found and found != old_social and is_instance_valid(found):
			social = found as SocialManager
			break
	check(social != null, "yeni sahne")
	social._state = SocialManager.State.READY
	social._uid = "qa"
	social._meta = {"uid": "qa", "name": "Burak", "code": "XYZ789", "news": {"scores": {"f1": [1, 0], "f2": [3, 2]},
		"friends": ["f1", "f2"], "requests": ["r1"], "asks": {}, "at": now - 6 * 3600},
		"gift_log": [{"uid": "f2", "name": "Mert", "part": "bolt"}]}
	social.friends.assign([_friend("f1", "Elif", "p06"), _friend("f2", "Mert", "p04"), _friend("f3", "Zeynep", "p02")])
	social.friends[2]["ask_part"] = "piston"
	social.friends[2]["ask_at"] = now - 600
	social.incoming.assign([_friend("r1", "Tolga", "p11"), _friend("r2", "Melis", "p03", "DE")])
	social.race_events.assign([_event("f1", "Elif", true, 5, 0, &"vw_golf_7", &"tofas_sahin", now - 900),
		_event("f2", "Mert", false, 3, 3, &"bmw_e60", &"tofas_sahin", now - 3000)])
	social._refreshed_at = 1.0
	var junkyard: JunkyardManager = get_first_node_in_group("junkyard") as JunkyardManager
	junkyard._pile_ready_at.resize(junkyard.pile_count())
	for i: int in junkyard.pile_count():
		junkyard._pile_ready_at[i] = now - 1800 if i < 2 else now + 1800
	(get_first_node_in_group("performance_mods") as PerformanceModManager)._jobs.append({"car": &"tofas_sahin",
		"category": &"motor", "stage": 1, "bay": 1, "start": float(now - 9000), "end": float(now - 4000)})

	await create_timer(0.3).timeout
	check(hud().news_flow.is_gathering() and social.quiet, "açılışta haber toplanıyor")
	var queued: Array = hud()._notice_queue.map(func(n: Dictionary) -> String: return String(n["text"]))
	var shown_text: String = hud()._notice_label.text if hud()._notice_plate.visible else ""
	social.race_news.emit(social.race_events[0])
	await create_timer(0.1).timeout
	var after: Array = hud()._notice_queue.map(func(n: Dictionary) -> String: return String(n["text"]))
	print("  bildirim kuyruğu önce %s / %s · sonra %s / %s" % [queued, shown_text, after,
		hud()._notice_label.text if hud()._notice_plate.visible else ""])
	var race_text: String = FriendsScreen.event_notice(social.race_events[0])
	check(not after.has(race_text) and (hud()._notice_label.text != race_text or not hud()._notice_plate.visible),
		"toplarken yarış bildirimi çıkmadı")

	var waited: float = 0.0
	while hud().router.top() != &"news" and waited < 10.0:
		await create_timer(0.25).timeout
		waited += 0.25
	check(hud().router.top() == &"news", "gazete açıldı (%.1f sn)" % waited)
	await create_timer(1.3).timeout
	var paper: Control = hud().news_screen._paper
	var headline: Label = paper.find_child("Headline", true, false) as Label
	print("  manşet: %s" % (headline.text if headline else "?"))
	check(headline != null and (headline.text.contains("ELİF") or headline.text.contains("ELIF")), "manşet Elif")
	var briefs: Label = paper.find_child("Briefs", true, false) as Label
	print("  kısa kısa: %s" % (briefs.text.replace(" ", " ") if briefs else "-"))
	await shot("01_gazete")
	hud().news_screen._ok.pressed.emit()
	await create_timer(0.8).timeout
	check(not hud().news_flow.is_gathering() and not social.quiet, "toplama bitti")
	check(social._meta["news"]["scores"]["f1"] == [5, 0] and (social._meta["gift_log"] as Array).is_empty(),
		"arkadaş tabanı ilerledi, hediye kaydı silindi")
	check((social._meta["news"]["friends"] as Array).has("f3") and (social._meta["news"]["requests"] as Array).has("r2"),
		"yeni arkadaş / istek tabana girdi")
	await create_timer(2.5).timeout
	await shot("02_sonra")
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
