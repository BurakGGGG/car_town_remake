extends SceneTree
## ETKİNLİK TAKVİMİ + ETKİNLİK ARACI (2026-10-26) — takvim (config/app.events: süren seçimi, eski tek alan, kimlik
## tekrarı, sıralama, aracın reveal_days önce görünmesi); araç modülü (edinilebilir araç, görevsiz etkinlikte yok);
## EventCar (ödünç, günde 3 hak + reklamla 1, gün dönümü, görevler bitince araç oyuncunun, zaten varsa elmas + kasa, kayıt);
## ETKİNLİK YARIŞI (oyuncunun aracı etkinlik aracı, koşu / rekor yazılmaz, görev sayaçları); kaldırımda park
## (EventCarSpot, showroom'a dönük); tabela (araç resmi + görev, YAKINDA), ETKİNLİK PANOSU (pist durakları, yarış düğmesi, takvim
## kartları, yalnız takvim), ödül ekranı (ETKİNLİK ARACI SENİN!). Ağ yok: belge AppConfig.apply ile verilir.
##   tools/run_tests.sh event_car_test

const CAR: StringName = &"audi_quattro_s1"

var fails: int = 0
var hud: Hud
var config: AppConfig
var now: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	config = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	config.learning_url = ""
	root.add_child(config)
	await frames(2)
	now = int(Time.get_unix_time_from_system())
	(g(&"vehicle_ownership") as VehicleOwnership).add_vehicle(&"tofas_sahin")   # yarış aracı olsun
	hud.router.close_all()
	_calendar()
	await _loan()
	await _race()
	await _win()
	await _owned()
	await _soon()
	config.apply({})
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _ev(id: String, start: int, end: int, extra: Dictionary = {}) -> Dictionary:
	var e: Dictionary = {"id": id, "start": start, "end": end, "title": {"tr": id.to_upper()},
		"missions": [{"id": "m1", "metric": "repairs", "target": 1}]}
	e.merge(extra, true)
	return e


func _calendar() -> void:
	print("== 1) Takvim ==")
	var day: int = 86400
	var cfg: Dictionary = {"events": [
		_ev("sonra", now + 9 * day, now + 12 * day, {"car": {"id": "porsche_gt3"}}),
		_ev("simdi", now - day, now + 2 * day, {"car": {"id": String(CAR), "owned_gems": 50, "owned_crate": "city_crate"}}),
		_ev("yakin", now + 2 * day, now + 4 * day, {"car": {"id": "chevrolet_corvette_c2"}, "reveal_days": 3}),
		_ev("bitti", now - 9 * day, now - 8 * day),
		{"id": "bozuk", "start": now, "end": now - 5},
	], "event": _ev("simdi", now - day, now + 2 * day)}
	var raw: Variant = LiveEvent.active_raw(cfg, now)
	check(raw is Dictionary and String(raw["id"]) == "simdi", "süren etkinlik listeden seçildi")
	var e: Dictionary = LiveEvent.normalize(raw, now)
	check(e["car"]["id"] == CAR and int(e["car"]["owned_gems"]) == 50 and e["car"]["owned_crate"] == &"city_crate",
		"araç modülü okundu")
	check(LiveEvent.active_raw({"event": _ev("eski", now - 10, now + 10)}, now)["id"] == "eski", "eski tek alan (event) de okunur")
	var cal: Array[Dictionary] = LiveEvent.calendar(cfg, now)
	var ids: Array = cal.map(func(c: Dictionary) -> String: return String(c["id"]))
	check(ids == ["simdi", "yakin", "sonra"], "takvim başlangıca göre, biten ve bozuk yok, aynı kimlik bir kez: %s" % [ids])
	check(bool(cal[0]["active"]) and cal[0]["car"] == CAR, "süren etkinliğin aracı görünür")
	check(cal[1]["car"] == &"chevrolet_corvette_c2", "3 gün kala araç açıklandı")
	check(cal[2]["car"] == &"" and bool(cal[2]["car_hidden"]), "9 gün kala araç gizli (siluet)")
	var no_missions: Dictionary = _ev("x", now - 10, now + 10, {"car": {"id": String(CAR)}, "missions": [], "money_mult": 2})
	check((LiveEvent.normalize(no_missions, now)["car"] as Dictionary).is_empty(), "görevsiz etkinlikte araç yok sayılır")
	var police: Dictionary = _ev("p", now - 10, now + 10, {"car": {"id": "police_vito"}})
	check((LiveEvent.normalize(police, now)["car"] as Dictionary).is_empty(), "edinilemeyen araç etkinlik aracı olamaz")
	var many: Array = []
	for i: int in 8:
		many.append(_ev("e%d" % i, now + (i + 1) * day, now + (i + 1) * day + 3600))
	check(LiveEvent.calendar({"events": many}, now).size() == LiveEvent.CALENDAR_MAX, "takvimde en çok %d" % LiveEvent.CALENDAR_MAX)
	check(LiveEvent.MISSION_TEXTS.has(&"event_car_wins") and LiveEvent.MISSION_TEXTS.has(&"garage_visits"), "yeni görev türleri")


func _apply_car_event(id: String, missions: Array) -> void:
	config.apply({"events": [{"id": id, "start": now - 60, "end": now + 7200, "title": {"tr": "Kış rallisi"},
		"missions": missions, "car": {"id": String(CAR), "owned_gems": 40, "owned_crate": "city_crate"}}]})
	(g(&"missions") as MissionManager).ensure_current()


func _loan() -> void:
	print("== 2) Ödünç araç, haklar, garaj ==")
	EventCar.test_today = 20000
	_apply_car_event("kis", [{"id": "win", "metric": "event_car_wins", "target": 1},
		{"id": "rep", "metric": "repairs", "target": 1, "money": 500}])
	var car: EventCar = g(&"event_car")
	check(car != null and car.active() and car.is_loan() and EventCar.car_id() == CAR, "etkinlik aracı ödünç")
	check(car.tries_left() == EventCar.DAILY_RACES, "günde %d hak" % EventCar.DAILY_RACES)
	check(car.progress() == Vector2i(0, 2), "ilerleme 0 / 2")
	var spot: EventCarSpot = g(&"event_car_spot")
	var waited: float = 0.0
	while waited < 6.0 and not spot.has_car():
		await seconds(0.3)
		waited += 0.3
	check(spot.has_car() and spot.car_position().distance_to(EventCarSpot.PARK) < 0.01,
		"ödünç araç showroom'un karşısındaki kaldırımda park etti")
	await seconds(1.2)
	var banner: EventBanner = hud.find_child("EventBanner", true, false) as EventBanner
	var texts: String = " ".join(banner.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(banner.visible and (banner.find_child("CarThumb", true, false) as Control).visible and texts.contains("0 / 2 GÖREV"),
		"tabela: araç resmi + görev ilerlemesi (%s)" % texts)
	hud.router.open(&"event")
	await seconds(0.6)
	var screen: EventScreen = hud.event_screen
	check(screen.visible and (screen.find_child("Road", true, false) as Control).visible, "pano: araca giden yol")
	check(screen.find_child("Stop_win", true, false) != null and screen.find_child("Stop_rep", true, false) != null,
		"görevler pistin durakları")
	var race_button: PlateButton = screen.find_child("Action_car_race", true, false) as PlateButton
	check(race_button.visible and race_button.text.contains("3 / 3"), "ETKİNLİK YARIŞI düğmesi: %s" % race_button.text)
	check(screen.find_child("Card_kis", true, false) != null, "takvim kartı")
	hud.router.close_all()
	await seconds(0.4)
	for i: int in 3:
		check(car.use_try(), "hak %d" % (i + 1))
	check(not car.use_try() and car.tries_left() == 0, "haklar bitti")
	check(not hud.start_event_car_race(), "hak yokken yarış açılmaz")
	check(car.can_add_try(), "reklamla +1 hak sunulur")
	car.add_try()
	check(car.tries_left() == 1 and not car.can_add_try(), "+1 hak (günde bir)")
	EventCar.test_today = 20001
	check(car.tries_left() == EventCar.DAILY_RACES and car.can_add_try(), "ertesi gün haklar yenilendi")


func _race() -> void:
	print("== 3) Etkinlik yarışı ==")
	var race: RaceManager = g(&"race")
	var car: EventCar = g(&"event_car")
	var runs_before: int = (race.get("_runs") as Dictionary).size()
	var best_before: float = race.best_time()
	check(hud.start_event_car_race(), "yarış açıldı")
	await seconds(0.5)
	check(hud.router.top() == &"drag_race" and race.is_event_car_race() and race.player_vehicle_id() == CAR,
		"oyuncunun aracı etkinlik aracı")
	check(car.tries_left() == EventCar.DAILY_RACES - 1, "hak yarış başlarken düştü")
	check(not race.submit_time(CAR, 11.0, PackedFloat32Array()), "etkinlik aracıyla rekor yazılmaz")
	var rec: DragRaceSim.Recording = DragRaceSim.ai_recording(CAR, {}, DragRaceSim.roll_form(CAR, null), RandomNumberGenerator.new())
	race.add_run(rec)
	check((race.get("_runs") as Dictionary).size() == runs_before and race.best_time() == best_before, "koşu arkadaşlara gitmez")
	var missions: MissionManager = g(&"missions")
	race.finish_race(true)
	check(car.progress() == Vector2i(1, 2), "kazanınca 'etkinlik aracıyla yarış kazan' ilerledi")
	hud.call(&"_on_race_exit")
	await seconds(0.6)
	check(race.player_vehicle_id() != CAR and not race.is_event_car_race(), "yarıştan sonra oyuncunun kendi aracı")
	check(missions.event_tasks().size() == 2, "iki görev")


func _win() -> void:
	print("== 4) Görevler bitti: araç oyuncunun ==")
	var car: EventCar = g(&"event_car")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var got: Array[Dictionary] = []
	car.won.connect(func(entry: Dictionary) -> void: got.append(entry))
	(g(&"missions") as MissionManager).count(&"repairs", 1)
	check(got.size() == 1 and not bool(got[0]["owned"]) and own.is_owned(CAR), "araç verildi")
	check(car.is_won() and not car.active() and not car.is_loan(), "etkinlik aracı kazanıldı")
	await seconds(2.5)
	var spot: EventCarSpot = g(&"event_car_spot")
	check(not spot.has_car(), "ödünç park yeri kalktı")
	hud.router.close_all()
	var gift: GiftScreen = hud.mail_notice.gift_screen()
	var waited: float = 0.0
	while waited < 5.0 and not gift.visible:
		hud.router.close_all()
		await seconds(0.3)
		waited += 0.3
	check(gift.visible and (gift.get("_title") as Label).text == "ETKİNLİK ARACI SENİN!", "ödül ekranı: %s" % (gift.get("_title") as Label).text)
	gift.close()
	await seconds(0.5)
	var save: SaveManager = g(&"save_manager")
	save.save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	check(data.has("event_car") and bool(data["event_car"]["paid"]) and String(data["event_car"]["id"]) == "kis", "kayıtta event_car")


func _owned() -> void:
	print("== 5) Araç zaten var: elmas + kasa ==")
	var car: EventCar = g(&"event_car")
	var pp: PlayerProgress = g(&"player_progress")
	var crates: CrateManager = g(&"crates")
	_apply_car_event("kis2", [{"id": "rep", "metric": "repairs", "target": 1}])
	check(car.active() and car.owns_car() and not car.is_loan(), "yeni etkinlik, araç oyuncuda: ödünç değil")
	var gems: int = pp.gems
	var pending: int = crates.pending_count()
	var got: Array[Dictionary] = []
	car.won.connect(func(entry: Dictionary) -> void: got.append(entry))
	(g(&"missions") as MissionManager).count(&"repairs", 1)
	check(got.size() == 1 and bool(got[0]["owned"]) and pp.gems == gems + 40, "teselli: +40 elmas (%d)" % (pp.gems - gems))
	check(crates.pending_count() == pending + 1, "teselli: +1 kasa")
	config.apply({})
	await seconds(0.5)
	check(not car.active(), "etkinlik bitince araç yok")


func _soon() -> void:
	print("== 6) Yaklaşan etkinlik: YAKINDA tabelası, yalnız takvim ==")
	config.apply({"events": [{"id": "yakinda", "start": now + 86400, "end": now + 3 * 86400, "title": {"tr": "Amerikan kas"},
		"missions": [{"id": "m", "metric": "repairs", "target": 1}], "car": {"id": "chevrolet_corvette_c2"}}]})
	await seconds(1.3)
	var banner: EventBanner = hud.find_child("EventBanner", true, false) as EventBanner
	var texts: String = " ".join(banner.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(banner.visible and texts.contains("YAKINDA") and texts.contains("AMERİKAN KAS"), "YAKINDA tabelası (%s)" % texts)
	hud.router.open(&"event")
	await seconds(0.6)
	var screen: EventScreen = hud.event_screen
	check(screen.visible and (screen.get("_title") as Label).text == "ETKİNLİK TAKVİMİ" and screen.find_child("Card_yakinda", true, false) != null,
		"pano yalnız takvimle açıldı")
	check(not (screen.find_child("Action_car_race", true, false) as Control).visible, "takvimde yarış düğmesi yok")
	hud.router.close_all()
	await seconds(0.4)
