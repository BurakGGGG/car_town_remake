extends SceneTree
## ETKİNLİK ARACI + TAKVİM görsel denetimi (2026-10-26, taslak B): telefon tuvalinde (1152x648 + content_scale 1,35 =
## 853x480; geniş 1440x648 → 1067x480) garajın köşesindeki kaldırımda park eden ödünç araç + tabela, ETKİNLİK PANOSU (araca giden yol: 2 görev
## bitmiş, biri ödül bekliyor, şu anki durakta araç), görevler bitince ETKİNLİK ARACI SENİN! ve etkinlik yokken yalnız
## takvim. Ağ yok: etkinlik AppConfig.apply ile verilir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/etkinlik_araci_qa.gd --resolution 1152x648 --display-driver x11
## Kareler ~/Projects/ct_shots/etkinlik_araci/.

const OUT: String = "/home/burak/Projects/ct_shots/etkinlik_araci/"
const DAY: int = 86400

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
	if not OS.get_cmdline_user_args().has("masaustu"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current()]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var config: AppConfig = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	config.learning_url = ""
	root.add_child(config)
	await process_frame
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	ownership.add_vehicle(&"tofas_sahin")
	var now: int = int(Time.get_unix_time_from_system())
	var title: Dictionary = {"tr": "Kış Rallisi", "en": "Winter Rally", "es": "Rally de invierno", "de": "Winter-Rallye",
		"fr": "Rallye d'hiver"}
	var active: Dictionary = {"id": "kis_rallisi", "start": now - DAY, "end": now + 4 * DAY + 6 * 3600, "title": title,
		"money_mult": 2, "sale": {"crates": 30},
		"rival": {"car": "lancia_stratos", "stage": 2, "name": {"tr": "Kral Rıza"}, "money": 10000, "gems": 25},
		"missions": [
			{"id": "kazan", "metric": "event_car_wins", "target": 3},
			{"id": "tamir", "metric": "repairs", "target": 15, "money": 5000},
			{"id": "kasa", "metric": "crates_opened", "target": 2, "gems": 20},
			{"id": "para", "metric": "repair_money", "target": 50000},
			{"id": "ziyaret", "metric": "garage_visits", "target": 1},
		],
		"car": {"id": "audi_quattro_s1", "owned_gems": 100, "owned_crate": "city_crate"}}
	var upcoming: Array = [
		{"id": "amerikan_kas", "start": now + 2 * DAY, "end": now + 5 * DAY, "title": {"tr": "Amerikan kas haftası",
			"en": "American muscle week"}, "xp_mult": 2, "missions": [{"id": "m", "metric": "races", "target": 5}],
			"car": {"id": "chevrolet_corvette_c2"}},
		{"id": "super_spor", "start": now + 9 * DAY, "end": now + 12 * DAY, "title": {"tr": "Süper spor gecesi",
			"en": "Supercar night"}, "sale": {"decor": 20}, "missions": [{"id": "m", "metric": "repairs", "target": 10}],
			"car": {"id": "porsche_gt3"}},
	]
	config.apply({"events": [active] + upcoming})
	var missions: MissionManager = get_first_node_in_group("missions") as MissionManager
	missions.ensure_current()
	missions.count(&"event_car_wins", 1)
	missions.count(&"repairs", 15)
	missions.claim_event("tamir")
	missions.count(&"crates_opened", 2)   # ödülü bekliyor (ÖDÜLÜ AL)
	missions.count(&"repair_money", 31500)
	hud.router.close_all()
	await create_timer(9.0).timeout   # araç kaldırıma park etsin, tabela dolsun, görev bildirimleri geçsin
	var spot: EventCarSpot = get_first_node_in_group("event_car_spot") as EventCarSpot
	check(spot.has_car(), "ödünç araç kaldırımda")
	await shot("01_garaj_odunc")
	hud.router.open(&"event")
	await create_timer(1.4).timeout
	check(hud.event_screen.visible, "pano açık")
	await shot("02_pano_yol")
	var view: Rect2 = root.get_visible_rect()
	var road: Control = hud.event_screen.find_child("Road", true, false) as Control
	for plate: Node in road.get_children():
		check(view.encloses((plate as Control).get_global_rect().grow(-1.0)), "%s ekrana sığıyor" % plate.name)
	hud.router.close_all()
	await create_timer(0.6).timeout
	missions.count(&"event_car_wins", 2)
	missions.count(&"repair_money", 20000)
	missions.count(&"garage_visits", 1)
	var gift: GiftScreen = hud.mail_notice.gift_screen()
	var waited: float = 0.0
	while waited < 8.0 and not gift.visible:
		hud.router.close_all()
		await create_timer(0.3).timeout
		waited += 0.3
	await create_timer(1.6).timeout
	check(gift.visible, "ETKİNLİK ARACI SENİN! açık")
	await shot("03_arac_senin")
	gift.close()
	await create_timer(0.8).timeout
	config.apply({"events": upcoming})
	await create_timer(1.3).timeout
	await shot("04_yakinda_tabela")
	hud.router.open(&"event")
	await create_timer(1.2).timeout
	await shot("05_takvim")
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
