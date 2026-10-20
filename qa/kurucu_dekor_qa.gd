extends SceneTree
## ÖN KAYIT ÖDÜLÜ GÖRSEL QA — gerçek Main.tscn'de "yaşanmış" bir garaj kurar (hoş geldin kutusu açılmış, liftlerde
## tamirdeki araçlar, kenarlarda ucuz eşyalar), sahte Play'e ön kayıt ödülünü (FounderReward.PRODUCT_ID) verdirir
## ve akışı çeker: ödül penceresi → kapanınca kamera garaja konan TAŞTAKİ ALTIN ANAHTAR'a → oyun kamerası →
## yakın plan → düzenleme paletinde LÜKS sekmesi (kart SERGİLENİYOR).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/kurucu_dekor_qa.gd --display-driver x11 --disable-vsync \
##     --resolution 1152x648 [-- seviye=<garaj seviyesi>]
## Çıktı: ~/Projects/ct_shots/kurucu_dekor/
const OUT: String = "/home/burak/Projects/ct_shots/kurucu_dekor/"
## Sıradan eşyalar: id → garaj zemininde hedef nokta (kesir; x sol→sağ, y arka→ön) ya da [duvar, kesir].
const DRESSING: Array[Array] = [
	[&"tool_cabinet", Vector2(0.03, 0.10)], [&"tyre_rack", Vector2(0.03, 0.45)], [&"oil_drums", Vector2(0.04, 0.80)],
	[&"pallet_stack", Vector2(0.97, 0.06)], [&"cooler", Vector2(0.72, 0.05)], [&"tyre_planter", Vector2(0.97, 0.90)],
	[&"sign_service", "left", 0.3], [&"sign_oil", "back", 0.85],
]

var _fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var cam: WorldCamera
var hud: Hud


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	await frames(4)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + file)
	print("  foto: ", file)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _arg(key: String, fallback: String) -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	hud = current_scene.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	cam = get_root().get_camera_3d() as WorldCamera
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pp.load_state(6, 0, 1000)
	var level: int = int(_arg("seviye", "2"))
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: level})
	await _lived_in(level)

	# --- Ödül Play'den gelir (sahte Play), pencere oyun sakinleşince açılır --------------------
	var pm: PurchaseManager = get_first_node_in_group("purchases") as PurchaseManager
	var mock: MockBillingClient = pm.client() as MockBillingClient
	check(mock != null, "sahte Play bağlı")
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var money: int = economy.money
	mock.owned.append(mock.make_purchase(String(FounderReward.PRODUCT_ID)))
	mock.query_purchases(BillingClient.ProductType.INAPP)
	var popup: RewardPopup = null   # mağaza / görev ekranlarının da (gizli) RewardPopup'ı var: görüneni ara
	for i: int in 900:
		await process_frame
		for n: Node in hud.find_children("RewardPopup", "RewardPopup", true, false):
			if (n as RewardPopup).visible:
				popup = n as RewardPopup
		if popup:
			break
	check(popup != null and popup.visible, "ödül penceresi açıldı")
	check(decor.owned_of(FounderReward.DECOR) == 1 and decor.placed_of(FounderReward.DECOR) == 1,
		"anahtar verildi ve garaja kondu")
	await frames(70)                        # sayılar sayarak dolsun
	await shot("1_odul_penceresi.png")
	if popup:
		popup.close()
	await frames(90)                        # paralar sayaca uçsun, kamera anahtara gitsin
	check(economy.money == money + FounderReward.MONEY, "+10.000 ₺")
	await shot("2_kamera_anahtarda.png")

	var iid: String = ""
	for inst: Dictionary in decor.instances():
		if inst["item"] == FounderReward.DECOR:
			iid = String(inst["iid"])
	hud.visible = false
	cam.reset_view()
	await frames(70)
	await shot("3_oyun.png")
	if iid != "":
		await _close_up(iid, "4_tek.png")
	hud.visible = true

	# --- Düzenleme paleti: LÜKS sekmesinde kart (SERGİLENİYOR) -------------------------------
	hud.router.open(&"garage_edit")
	await frames(50)
	hud.garage_edit_screen._on_tab_pressed(GarageDecor.Kind.LUXURY)
	await frames(40)
	await shot("5_palet.png")
	print("SONUC: fails=%d" % _fails)
	quit()


## Hoş geldin kutusu açılmış, iki araç sahipli, liftler dolu, kenarlarda sıradan eşyalar.
func _lived_in(level: int) -> void:
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for id: StringName in [&"tofas_sahin", &"vw_golf_7"]:
		own.add_vehicle(id)
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	crates.get("_crates").clear()
	crates.crates_changed.emit()
	(get_first_node_in_group("economy") as EconomyManager).set_money(200000)
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(level)
	await frames(20)
	for entry: Array in DRESSING:
		if not decor.purchase(entry[0]):
			print("  alınamadı: ", entry[0])
			continue
		var iid: String = _place_wall(entry[0], entry[1], entry[2]) if entry[1] is String \
				else _place_floor(entry[0], entry[1])
		if iid == "":
			print("  yer yok: ", entry[0])
	view.refresh()
	# müşteriler gelsin, liftlere alınsın (tamir sürerken çekilir: araçlar lifte durur)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = current_scene.find_child("Traffic", true, false) as TrafficManager
	Engine.time_scale = 4.0
	var t: float = 0.0
	while t < 40.0:
		for v: TrafficVehicle in traffic.vehicles:
			if v.is_waiting():
				rm.start_repair(v)
		await process_frame
		t += 1.0 / 60.0
	Engine.time_scale = 1.0
	await frames(30)


## Duvarın `along` kesrine en yakın geçerli asma noktası.
func _place_wall(id: StringName, side: String, along: float = 0.5) -> String:
	var area: DecorArea = view.area()
	var span: Vector2 = area.face(side)["span"]
	var mid: float = lerpf(span.x, span.y, along)
	for k: int in 60:
		for s: int in [1, -1]:
			var m: Dictionary = area.mount_on(side, mid + s * k * 0.03, view.wall_width(id))
			if view.is_valid(id, m["position"], float(m["yaw"])):
				return decor.add_instance(id, m["position"], float(m["yaw"]))
	return ""


## Zeminde `frac` (x sol→sağ, y arka→ön) noktasına en yakın geçerli yer.
func _place_floor(id: StringName, frac: Vector2) -> String:
	var r: Rect2 = view.area().floor_rect
	var size: Vector2 = view.footprint_size(id)
	var target: Vector2 = r.position + Vector2(size.x * 0.5 + frac.x * maxf(r.size.x - size.x, 0.0),
		size.y * 0.5 + frac.y * maxf(r.size.y - size.y, 0.0))
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	var step: float = DecorGrid.CELL * 0.25
	var x: float = r.position.x
	while x < r.end.x:
		var z: float = r.position.y
		while z < r.end.y:
			var pos: Vector3 = Vector3(x, 0.0, z)
			var dist: float = Vector2(x, z).distance_to(target)
			if dist < best_d and view.is_valid(id, pos, 0.0):
				best = pos
				best_d = dist
			z += step
		x += step
	return "" if best == Vector3.INF else decor.add_instance(id, best, 0.0)


func _box_of(iid: String) -> AABB:
	var body: Node3D = view.body_of(iid)
	var out: AABB = AABB()
	var first: bool = true
	for n: Node in body.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = n as VisualInstance3D
		var b: AABB = vi.global_transform * vi.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out


## Oyunun ışığında, eşyaya oyun kamerası yönünden bakan geçici dar açılı kamera.
func _close_up(iid: String, file: String) -> void:
	var box: AABB = _box_of(iid)
	var center: Vector3 = box.get_center()
	var close: Camera3D = Camera3D.new()
	close.fov = 30.0
	current_scene.add_child(close)
	close.position = center + Vector3(0.45, 0.42, 1.0).normalized() * (box.size.length() * 1.55 + 0.04)
	close.look_at(center, Vector3.UP)
	close.make_current()
	await frames(12)
	await shot(file)
	cam.make_current()
	close.queue_free()
