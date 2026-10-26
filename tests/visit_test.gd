extends SceneTree
## ARKADAŞ GARAJI ZİYARETİ — GERÇEK Main.tscn, sahte Firebase (social_test.FakeFB), izole user://.
## Çalıştırma: tools/run_tests.sh visit_test   (pencereli)
##
## Akış: alice girişli açılır → ARKADAŞLAR → bob'un GARAJA GİT'i → bob'un garajı ziyaret kipinde kurulur
## → GARAJIMA DÖN. Denetlenenler: kendi sahne DONAR (aynı düğümler, zamanlayıcı ilerlemez), ziyaret
## sahnesi bob'un garajıyla kurulur, HUD / bulut / kasa / görev / reklam / sosyal yoktur, ziyaret
## boyunca diske ve buluta HİÇBİR ŞEY yazılmaz, dönüşte her şey (para, kamera, gruplar, ekran) yerindedir.

const SocialTest: GDScript = preload("res://tests/social_test.gd")

var fb: Object
var fails: int = 0


func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	if OS.get_user_data_dir().ends_with("/CarTownRemake") or OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func until(cond: Callable, limit: float = 6.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func user_file(name: String) -> String:
	return OS.get_user_data_dir().path_join(name)


func file_text(name: String) -> String:
	return FileAccess.get_file_as_string(user_file(name)) if FileAccess.file_exists(user_file(name)) else ""


## Bob'un açık garajı: alice'inkinden büyük garaj, fazladan araç, yüksek seviye.
func bob_garage() -> Dictionary:
	var snap: Dictionary = {
		"version": SaveManager.SAVE_VERSION,
		"progress": {"level": 30},
		"garage_upgrades": {String(GarageUpgradeManager.GARAGE_ID): 3},
		"repair_bays": {"unlocked": 2, "layout": []},
		"decor": {},
		"vehicles": {"owned": ["hyundai_getz", "ford_focus"], "paint": {"hyundai_getz": "ff00ff"}},
	}
	return PublicGarage.from_snapshot(snap)


## Aracın sahneler arasında paylaşılan görünümündeki gövde rengi (ziyaret sahnesi de buna yazar).
func shared_color(id: StringName) -> Color:
	return CarAppearance.get_for(CarCatalog.scene_path(id)).body_color


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(user_file(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	fb.max_delay = 0.02
	var bob_json: String = PublicGarage.to_json(bob_garage())
	fb.store = {
		"codes/ALC234": {"uid": "alice"},
		"codes/BQB234": {"uid": "bob"},
		"garages/g_alice": {"name": "Usta Ali", "code": "ALC234", "level": 1, "value": 0, "garage_json": "{}", "updated_at": 1},
		"garages/g_bob": {"name": "Bob Usta", "code": "BQB234", "level": 30, "value": 250000, "garage_json": bob_json, "updated_at": 1},
		"users/alice/friends/f_bob": {"since": 1},
		"users/bob/friends/f_alice": {"since": 1},
	}
	fb.account = "alice"
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)

	print("== 1) Kendi garaj açılır, sosyal hazır ==")
	change_scene_to_file("res://Main.tscn")
	await frames(20)
	var home: Node = current_scene
	var cloud: CloudSaveManager = get_first_node_in_group("cloud_save") as CloudSaveManager
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	check(home != null and cloud != null and social != null, "Main.tscn, CloudSaveManager, SocialManager")
	check(await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED), "bulut SYNCED")
	check(await until(func() -> bool: return social.is_ready()), "sosyal READY (profil sunucudan)")
	var eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	eco.set_money(77777)
	(get_first_node_in_group("save_manager") as SaveManager).save_game()
	await until(func() -> bool: return not cloud.is_busy() and CloudPack.unpack(SaveSafe.s(fb.store.get("players/alice", {}).get("save_json", ""))).contains("77777"))
	var own_level: int = int((get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).levels().get(GarageUpgradeManager.GARAGE_ID, 1))
	var camera: Camera3D = get_root().get_camera_3d()
	var camera_pos: Vector3 = camera.global_position
	var marker: Timer = Timer.new()
	marker.one_shot = true
	home.add_child(marker)
	marker.start(5.0)
	# Kendi garajda süren bir tamir: ziyaret sahneyi ağaçtan çıkarınca iptal OLMAMALI
	var repair: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	check(await until(func() -> bool: return traffic != null and not traffic.vehicles.is_empty(), 10.0), "trafikte araç var")
	var job_car: TrafficVehicle = traffic.vehicles[0] if traffic and not traffic.vehicles.is_empty() else null
	if job_car:
		job_car.request_repair(repair.repair_wait_spots[0], repair.repair_types[0])
	check(job_car != null and repair.start_repair(job_car), "kendi garajda tamir başladı")
	var job_progress: float = repair.get_state(job_car).repair_progress if repair.get_state(job_car) else -1.0

	print("== 2) ARKADAŞLAR → GARAJA GİT ==")
	var hud: Hud = home.find_child("HUD", true, false) as Hud
	check(hud.friends_button != null and hud.friends_button.visible, "ARKADAŞLAR plakası var")
	hud.friends_button.pressed.emit()
	var screen: FriendsScreen = hud.friends_screen
	check(screen.visible, "ARKADAŞLAR ekranı açıldı")
	check(await until(func() -> bool: return social.friends.size() == 1), "listede bob")
	await frames(2)
	var go: PlateButton = screen.find_child("Visit_bob", true, false) as PlateButton
	check(go != null, "GARAJA GİT düğmesi")
	var meta_before: String = file_text("cloud_sync.json")
	var social_before: String = file_text("social.json")
	var writes_before: int = fb.calls.filter(func(c: String) -> bool: return c.begins_with("set") or c.begins_with("delete")).size()
	var left_before: float = marker.time_left
	go.pressed.emit()
	check(await until(func() -> bool: return GarageVisit.is_visiting() and current_scene != home), "ziyaret başladı")
	# Karşılaştırma ziyaret BAŞLADIKTAN sonraki kayıtla: ziyaretten hemen önce kendi kayıt bilerek yazılır ve pasif gelirin
	# last_seen'i (saniye) değişir. Denetlenen, ziyaret sırasında / dönüşte hiçbir şeyin yazmaması.
	var save_before: String = file_text("savegame.json")
	await frames(20)

	print("== 3) Ziyaret sahnesi ==")
	var visit: Node = current_scene
	check(not home.is_inside_tree() and is_instance_valid(home), "kendi sahne ağaçtan çıktı ama bellekte")
	check(visit.find_child("HUD", true, false) == null, "ziyarette HUD yok")
	check(get_first_node_in_group("cloud_save") == null, "ziyarette CloudSaveManager yok")
	for group: String in ["crates", "missions", "ads", "social", "gem_rewards", "garage_editor", "crate_delivery"]:
		check(get_first_node_in_group(group) == null, "ziyarette '%s' yok" % group)
	var bar: Node = get_first_node_in_group("visit_bar")
	check(bar != null, "ziyaret çubuğu var")
	var title: Label = bar.find_child("VisitName", true, false) as Label if bar else null
	check(title != null and title.text == "Bob Usta", "çubukta bob'un adı")
	var visit_save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	check(visit_save != null and visit_save.visit_mode, "ziyaret SaveManager'ı visit_mode")
	var visit_upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	check(int(visit_upgrades.levels().get(GarageUpgradeManager.GARAGE_ID, 1)) == 3, "bob'un garaj seviyesi (3) kuruldu (kendi: %d)" % own_level)
	var visit_own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	check(visit_own.is_owned(&"ford_focus"), "bob'un aracı")
	var visit_eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	check(visit_eco != eco and visit_eco.money != 77777, "para bob'un açık garajında yok (kendi paran görünmez)")
	check(get_root().get_camera_3d() != camera, "ziyaret kamerası geçerli")
	# Ziyarette kayıt tetikleyen her şey denenir: hiçbiri yazmamalı
	visit_eco.set_money(1)
	visit_own.add_vehicle(&"hyundai_getz")
	check(not visit_save.save_game(), "save_game reddedilir")
	visit_save.request_save()
	visit_save.new_game()
	check(not visit_save.apply_snapshot({"version": SaveManager.SAVE_VERSION}), "apply_snapshot reddedilir")
	await create_timer(1.5).timeout
	check(file_text("savegame.json") == save_before, "savegame.json DEĞİŞMEDİ")
	check(file_text("cloud_sync.json") == meta_before and file_text("social.json") == social_before, "bulut / sosyal dosyaları değişmedi")
	var writes_now: int = fb.calls.filter(func(c: String) -> bool: return c.begins_with("set") or c.begins_with("delete")).size()
	check(writes_now == writes_before, "buluta yazılmadı (%d → %d)" % [writes_before, writes_now])

	print("== 4) GARAJIMA DÖN ==")
	check(shared_color(&"hyundai_getz").is_equal_approx(Color.MAGENTA), "ziyarette bob'un boyası görünüyor (eflatun Getz)")
	(bar.find_child("BackHomeButton", true, false) as PlateButton).pressed.emit()
	await frames(6)
	var own_paint: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	check(own_paint != null and shared_color(&"hyundai_getz").is_equal_approx(own_paint.paint_color(&"hyundai_getz"))
		and not shared_color(&"hyundai_getz").is_equal_approx(Color.MAGENTA),
		"dönünce kendi araçların kendi renginde (arkadaşın boyası kalmadı)")
	check(not GarageVisit.is_visiting() and current_scene == home and home.is_inside_tree(), "kendi sahneye dönüldü (aynı düğüm)")
	check(not is_instance_valid(visit), "ziyaret sahnesi silindi")
	check(get_first_node_in_group("economy") == eco and eco.money == 77777, "para yerinde (77777)")
	check(get_first_node_in_group("cloud_save") == cloud and get_first_node_in_group("social") == social, "gruplar kendi yöneticileri buluyor")
	check(get_root().get_camera_3d() == camera and camera.global_position.is_equal_approx(camera_pos), "kamera geri geldi, aynı yerde")
	var job_state: RepairState = repair.get_state(job_car)
	check(job_state != null and job_car.in_bay(), "tamir ziyaretten sonra sürüyor (araç tamir alanında)")
	check(job_state != null and job_state.repair_progress >= job_progress, "tamir ilerlemesi korundu")
	check(repair.active_count() == 1 and repair.get_spot_occupants() == [job_car], "tamir alanı hâlâ dolu sayılıyor")
	check(absf(marker.time_left - left_before) < 0.3, "kendi sahne dondu: zamanlayıcı ilerlemedi (%.2f → %.2f)" % [left_before, marker.time_left])
	check(screen.visible, "ARKADAŞLAR ekranı açık: oyuncu listeye döner")
	check(file_text("savegame.json") == save_before, "dönüşten sonra da kayıt aynı")
	(get_first_node_in_group("save_manager") as SaveManager).save_game()
	check(file_text("savegame.json").contains("77777"), "kendi kaydı yine yazılabiliyor")

	print("== 5) İkinci ziyaret + Android GERİ ile dönüş ==")
	go = screen.find_child("Visit_bob", true, false) as PlateButton
	go.pressed.emit()
	check(await until(func() -> bool: return GarageVisit.is_visiting()), "yeniden ziyaret")
	await frames(10)
	var bar2: Node = get_first_node_in_group("visit_bar")
	bar2.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(6)
	check(not GarageVisit.is_visiting() and current_scene == home, "GERİ tuşu kendi garaja döndürdü")
	check(eco.money == 77777, "para yerinde")

	print("== 6) Öne çıkan arkadaşlar (oyunla gelen iki garaj) ==")
	var featured: Array[Dictionary] = FeaturedFriends.all()
	check(featured.size() == 2, "iki öne çıkan arkadaş yüklendi")
	await frames(2)
	for entry: Dictionary in featured:
		var uid: String = entry["uid"]
		var fbtn: PlateButton = screen.find_child("Visit_" + uid, true, false) as PlateButton
		check(fbtn != null, "%s listede (GARAJA GİT)" % entry["name"])
		var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FeaturedFriends.DIR + uid + ".json"))
		var expected_items: int = ((raw["garage"]["decor"] as Dictionary)["instances"] as Array).size()
		fbtn.pressed.emit()
		check(await until(func() -> bool: return GarageVisit.is_visiting()), "%s garajı açıldı" % entry["name"])
		var save_text: String = file_text("savegame.json")   # ziyaret öncesi bilinçli kayıttan sonra (bkz. 2. bölüm)
		await frames(30)
		var fdecor: DecorManager = get_first_node_in_group("decor") as DecorManager
		var fview: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
		var fup: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
		var fown: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		check(int(fup.levels().get(GarageUpgradeManager.GARAGE_ID, 1)) == 4, "  garaj 4. seviye")
		check(fdecor.instance_count() == expected_items, "  %d / %d eşya yerinde" % [fdecor.instance_count(), expected_items])
		var expected_cars: int = ((raw["garage"]["vehicles"] as Dictionary)["owned"] as Array).size()
		check(fown.owned_vehicle_ids().size() == expected_cars and expected_cars >= 6, "  %d araç" % expected_cars)
		check(fown.paint_state().is_empty(), "  araçlar fabrika renginde (boya yok)")
		var bad: Array[String] = []
		for inst: Dictionary in fdecor.instances():
			if not fview.is_valid(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y), inst["iid"]):
				bad.append(String(inst["item"]))
		check(bad.is_empty(), "  her eşya oyunun kuralına göre geçerli yerde %s" % [bad])
		check(fdecor.surface(DecorManager.SURFACE_WALL) != &"", "  duvar kaplaması: %s" % fdecor.surface(DecorManager.SURFACE_WALL))
		var cam: Camera3D = get_root().get_camera_3d()
		var lot: Rect2 = fview.lot_rect()
		var corners_ok: bool = true
		var screen_size: Vector2 = get_root().get_visible_rect().size
		for corner: Vector3 in [Vector3(lot.position.x, 0, lot.position.y), Vector3(lot.end.x, 0, lot.position.y),
				Vector3(lot.position.x, 0, lot.end.y), Vector3(lot.end.x, 0, lot.end.y)]:
			var p: Vector2 = cam.unproject_position(corner)
			corners_ok = corners_ok and Rect2(Vector2.ZERO, screen_size).grow(2.0).has_point(p)
		check(corners_ok, "  kamera bütün garajı gösteriyor")
		check(file_text("savegame.json") == save_text, "  kendi kaydı değişmedi")
		(get_first_node_in_group("visit_bar").find_child("BackHomeButton", true, false) as PlateButton).pressed.emit()
		await frames(6)
		check(not GarageVisit.is_visiting() and current_scene == home, "  geri dönüldü")
	check(eco.money == 77777, "para yerinde")

	print("== 7) Bulut meşgulken ziyaret ertelenir ==")
	fb.hang = true
	eco.set_money(80000)
	cloud.upload_save()
	await frames(2)
	check(cloud.is_busy(), "bulut yazıyor")
	check(not await social.visit("bob"), "ziyaret reddedildi (önce kayıt buluta gitsin)")
	check(not GarageVisit.is_visiting(), "ziyaret başlamadı")
	fb.hang = false

	print("== 8) Ziyaretteyken kendi sahneye geç gelen cevaplar hata vermez ==")
	# Yayın derlemesinde GDScript boş nesneye metot çağrısını denetlemez: burada hata olan her satır telefonda
	# ÇÖKMEDİR (2026-10-27 Crashlytics, Xiaomi/Oppo: Emre'yi ziyaret ederken reklam yüklendi → AdService._level →
	# ağaçtan çıkmış sahnede get_tree() boş → get_first_node_in_group).
	var errors: ErrorCount = ErrorCount.new()
	var ads: AdService = get_first_node_in_group("ads") as AdService
	(get_first_node_in_group("player_progress") as PlayerProgress).level = 10   # teklifler 3. seviyeden
	var offer_btn: AdOfferButton = AdOfferButton.new(AdPolicy.FREE_GEMS, "+5", true)
	(home.find_child("HUD", true, false) as Node).add_child(offer_btn)
	offer_btn.refresh()   # görünen bir teklif gibi readiness_changed'e bağlanır
	fb.max_delay = 1.0    # ziyaretten hemen önceki yazmaların (kayıt, açık garaj) cevabı ziyarette gelir
	OS.add_logger(errors)
	# 7. bölümün askıdaki yazması zaman aşımıyla düşer (REQUEST_TIMEOUT, yeniden denemeler): bulut boşalınca gidilir
	var emre: String = String(FeaturedFriends.all()[0]["uid"])
	check(await until(func() -> bool: return not cloud.is_busy() and FeaturedFriends.visit(self, emre), 90.0),
		"Emre'nin garajına gidildi")
	if not await until(func() -> bool: return GarageVisit.is_visiting()):
		check(false, "ziyarette")
		OS.remove_logger(errors)
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	for slot: StringName in [AdConfig.SLOT_RACE, AdConfig.SLOT_REPAIR]:
		if ads._slots.has(slot):
			ads._on_loaded(slot, slot == AdConfig.SLOT_RACE)   # Appodeal geri çağrısı: biri yüklendi, biri yüklenemedi
	# Ağ cevabıyla (Firebase, davet, posta) kendi sahnedeki yöneticiler "changed" yayabilir: dinleyicileri ağaç dışında
	var emitters: Array[String] = []
	for node: Node in home.find_children("*", "", true, false):
		for sig: Dictionary in node.get_signal_list():
			if sig["name"] == "changed" and (sig["args"] as Array).is_empty() and not node.get_signal_connection_list(&"changed").is_empty():
				emitters.append(String(node.name))
				node.emit_signal(&"changed")
	check(emitters.size() >= 3, "ağaç dışında changed yayıldı: %s" % [emitters])
	social.notice.emit("ziyarette gelen bildirim")   # HUD bildirim plakası (hurdalık hediyesi vb.)
	for node: Node in home.find_children("*", "", true, false):
		if node is MailService:
			(node as MailService).arrived.emit()   # yeni posta → ARKADAŞLAR rozeti
	await create_timer(2.5).timeout
	check(errors.count == 0, "ziyarette kendi sahneden hata yok (%d) %s" % [errors.count, errors.first])
	(get_first_node_in_group("visit_bar").find_child("BackHomeButton", true, false) as PlateButton).pressed.emit()
	await frames(6)
	OS.remove_logger(errors)
	fb.max_delay = 0.02
	check(not GarageVisit.is_visiting() and current_scene == home, "geri dönüldü")
	offer_btn.refresh()
	check(offer_btn.visible, "dönünce reklam teklifi yine güncelleniyor")
	offer_btn.queue_free()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Ziyaret sırasında basılan hatalar (uyarılar sayılmaz).
class ErrorCount extends Logger:
	var count: int = 0
	var first: String = ""

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		count += 1
		if first.is_empty():
			var where: String = "%s:%d %s" % [file.get_file(), line, function]
			if not script_backtraces.is_empty() and script_backtraces[0] != null and not script_backtraces[0].is_empty():
				where = script_backtraces[0].format()
			first = "%s — %s" % [rationale if not rationale.is_empty() else code, where]
