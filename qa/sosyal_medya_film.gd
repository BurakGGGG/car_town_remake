extends SceneTree
## Tanıtım filmi için oyun içi sahneler (Movie Maker, yalıtılmış kayıt, HUD gizli). Her sahne ayrı süreç:
##   --resolution WxH --write-movie x.avi --fixed-fps 30 --script qa/sosyal_medya_film.gd -- <sahne>
## Sahneler: g1 (seviye 1 garaj + tamir) · g2 (seviye 2, dekorlu, lüks araç tamiri) · hurda · restore · lux
var hud: Hud
var router: UiRouter
var traffic: TrafficManager
var rm: RepairManager
var own: VehicleOwnership
var cam: WorldCamera
var bays: RepairBayManager
var _scene: String = ""
var _fix: bool = false
var _secs: float = 30.0
var _cheap: Array[StringName] = [&"tofas_sahin", &"anadol_a1", &"renault_toros", &"hyundai_getz", &"opel_corsa", &"fiat_500_1965"]
var _lux: Array[StringName] = [&"porsche_gt3", &"mercedes_300sl", &"ferrari_488_pista", &"aston_martin_db5", &"lambo_huracan", &"jaguar_e_type"]


func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	_scene = a[0]
	_secs = float(a[1]) if a.size() > 1 else 30.0
	Engine.max_fps = 0
	process_frame.connect(_guard)
	_run.call_deferred()


var _hard: int = 0


## Betik hatası sahneyi yarıda bırakırsa kayıt sonsuza dek sürmesin (AVI diski doldurur).
func _guard() -> void:
	_hard += 1
	if _hard > 2400:
		print("WATCHDOG: 80 sn doldu")
		quit(1)


func frames(n: int) -> void:
	for i: int in n:
		await process_frame
		_total += 1
		if _total > 1500:
			print("WATCHDOG: sahne 50 sn'yi aştı")
			quit(1)
			return
		if _fix:
			_service()


func sec(s: float) -> void:
	await frames(int(s * 30.0))


var _want: Array[StringName] = []
var _tick: int = 0
var _total: int = 0


## İstenen modellerden birini müşteri yapar (rastgele müşteri seçimi kapalı: sayaç hep dolmuyor).
func _make_customer() -> void:
	for v: TrafficVehicle in traffic.vehicles:
		if v.mode != TrafficVehicle.Mode.TRAFFIC or not _want.has(v.vehicle_id):
			continue
		for spot: Node3D in rm.active_wait_spots():
			if not rm._spot_free(spot):
				continue
			var fwd: Vector3 = rm._flat(spot.global_transform.basis.z).normalized()
			v.global_position = Vector3(spot.global_position.x - fwd.x * 4.0, v.global_position.y, spot.global_position.z - fwd.z * 4.0)
			v.rotation.y = atan2(fwd.x, fwd.z)
			v.request_repair(spot, rm._pick_fault(rm.unlocked_types(1)), 1.0)
			if not v.customer_stopped.is_connected(rm._on_customer_stopped):
				v.customer_stopped.connect(rm._on_customer_stopped)
			return


func _service() -> void:
	_tick += 1
	rm.set("_customer_timer", 100000.0)
	if not _want.is_empty() and _tick % 15 == 0 and rm.waiting_count() == 0:
		_make_customer()
	for v: TrafficVehicle in traffic.vehicles:
		if v.is_waiting():
			rm.start_repair(v)
		elif v.mode == TrafficVehicle.Mode.REWARD_WAITING:
			rm.collect(v)


func _boot(hide_hud: bool = true) -> void:
	await frames(2)
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	hud = current_scene.find_child("HUD", true, false) as Hud
	router = hud.router
	traffic = current_scene.find_child("Traffic", true, false) as TrafficManager
	rm = get_first_node_in_group("repair_manager") as RepairManager
	own = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	bays = get_first_node_in_group("repair_bays") as RepairBayManager
	cam = current_scene.get_viewport().get_camera_3d() as WorldCamera
	if hide_hud:
		hud.visible = false


func _send(ids: Array[StringName], gap: float) -> void:
	for id: StringName in ids:
		var tries: int = 0
		while traffic.spawn_model(id, null) == null and tries < 120:
			tries += 1
			await frames(1)
		await sec(gap)


func _bay_box(i: int, pad: float) -> AABB:
	var p: Vector2 = bays.bay_position(i)
	return AABB(Vector3(p.x - pad, 0.0, p.y - pad), Vector3(pad * 2.0, 0.5, pad * 2.0))


func _run() -> void:
	match _scene:
		"g1":
			await _boot()
			_fix = true
			Engine.max_physics_steps_per_frame = 64
			cam.frame_box(_bay_box(0, 1.3), 0.1, 0.9, 0.05, 0.8)
			await sec(1.0)
			_want = _cheap
			_send(_cheap, 1.0)
			Engine.time_scale = 3.0
			await sec(_secs)
		"g2":
			await _boot(false)
			Engine.max_physics_steps_per_frame = 64
			(get_first_node_in_group("economy") as EconomyManager).set_money(900000)
			(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
			var d2: Dictionary = _design2()
			bays.load_layout(d2["bays"])
			bays.load_state(3)
			for car_id: String in d2["cars"]:
				own.add_vehicle(StringName(car_id))
			await sec(0.5)
			var dview: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
			dview.refresh()
			dview._rebuild_area()
			var dmgr: DecorManager = get_first_node_in_group("decor") as DecorManager
			dmgr.load_state(_decor_state(d2, dview))
			await sec(0.5)
			dview.refresh()
			_validate(d2, dview, dmgr)
			await sec(0.7)
			hud.visible = false
			var area: Rect2 = dview.lot_rect()
			var whole: AABB = AABB(Vector3(area.position.x, 0.0, area.position.y), Vector3(area.size.x, 0.45, area.size.y))
			cam.min_zoom = 0.5
			cam.frame_box(whole, 0.05, 0.96, 0.02, 0.5)
			await sec(3.0)
			_fix = true
			_want = _lux
			_send(_lux, 1.0)
			Engine.time_scale = 3.0
			cam.frame_box(_bay_box(1, 1.0), 0.08, 0.92, 0.04, 0.5)
			await sec(_secs)
		"shot":
			await _boot(false)
			Engine.max_physics_steps_per_frame = 64
			(get_first_node_in_group("economy") as EconomyManager).set_money(900000)
			(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
			var d2: Dictionary = _design2()
			bays.load_layout(d2["bays"])
			bays.load_state(3)
			for car_id: String in d2["cars"]:
				own.add_vehicle(StringName(car_id))
			await sec(0.5)
			var dview: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
			dview.refresh()
			dview._rebuild_area()
			var dmgr: DecorManager = get_first_node_in_group("decor") as DecorManager
			dmgr.load_state(_decor_state(d2, dview))
			await sec(0.5)
			dview.refresh()
			_validate(d2, dview, dmgr)
			await sec(0.7)
			var area: Rect2 = dview.lot_rect()
			var whole: AABB = AABB(Vector3(area.position.x, 0.0, area.position.y), Vector3(area.size.x, 0.45, area.size.y))
			cam.min_zoom = 0.5
			cam.frame_box(whole, 0.12, 0.80, 0.03, 0.5)
			await sec(2.5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/home/burak/Projects/social_media/foto/oyun_ici/garaj_luks_arayuzlu.png")
		"park":
			await _boot()
			var ids: Array[StringName] = [&"lambo_huracan", &"ferrari_488_pista", &"porsche_gt3", &"mercedes_300sl"]
			var xs: Array[float] = [3.45, 4.25, 5.05, 5.85]
			var yaw: float = float(OS.get_cmdline_user_args()[2]) if OS.get_cmdline_user_args().size() > 2 else 0.0
			var ua: PackedStringArray = OS.get_cmdline_user_args()
			var dxo: float = float(ua[3])
			var dzo: float = float(ua[4])
			for i: int in 4:
				var car: Node3D = (load(CarCatalog.scene_path(ids[i])) as PackedScene).instantiate()
				car.scale = Vector3.ONE * traffic.model_scale * CarCatalog.model_scale(ids[i])
				car.position = Vector3(xs[i] + dxo, 0.03, -1.646 + dzo)
				car.rotation_degrees.y = 39.6 + yaw
				current_scene.add_child(car)
				CarRig.for_node(car).apply(CarAppearance.get_for(CarCatalog.scene_path(ids[i])))
			var spot: AABB = AABB(Vector3(3.2, 0.0, -2.3), Vector3(3.2, 0.5, 1.7))
			cam.min_zoom = 0.3
			cam.frame_box(spot, 0.1, 0.9, 0.05, 0.3)
			await sec(2.5)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/home/burak/Projects/social_media/foto/oyun_ici/showroom_onu_luks_%d_%d.png" % [int(dxo * 100.0), int(dzo * 100.0)])
		"hurda":
			await _boot(false)
			bays.load_state(2)
			bays.bays_changed.emit()
			await sec(1.0)
			print("DBG f=%d " % _total, "map butonu ", hud.map_button.visible, " ", hud.map_button.get_global_rect())
			hud.map_button.pressed.emit()
			await sec(0.8)
			print("DBG f=%d " % _total, "harita açık ", hud.map_screen.visible)
			var map: MapScreen = hud.map_screen
			(map.get("_pins")[&"junkyard"] as BaseButton).pressed.emit()
			var t: int = 0
			while not hud.junkyard_screen.visible and t < 300:
				t += 1
				await frames(1)
			print("DBG f=%d " % _total, "hurdalık açık ", hud.junkyard_screen.visible)
			await sec(2.0)
			var screen: JunkyardScreen = hud.junkyard_screen
			var world: JunkyardWorld = screen.world()
			for pile: int in [0, 1, 2]:
				await _tap(world.screen_point(world.pile_position(pile) + Vector3.UP * 0.9))
				await sec(1.8)
			await sec(1.0)
			await _tap(world.screen_point(world.car_position(1) + Vector3.UP * 0.7))
			await sec(2.5)
		"restore":
			await _boot()
			var jy: JunkyardManager = get_first_node_in_group(&"junkyard") as JunkyardManager
			var id: StringName = &"chevrolet_bel_air_1956"
			for part_id: StringName in RestorationCatalog.recipe(id):
				jy.add_parts(part_id, RestorationCatalog.required(id, part_id), &"debug")
			jy.start(id)
			await sec(2.0)
			var rbays: RestorationBays = get_first_node_in_group(&"restoration_bays") as RestorationBays
			var display: RestorationDisplay = rbays.display_of(id)
			var at: Vector3 = display.global_position
			cam.frame_box(AABB(at - Vector3(0.55, 0.0, 0.55), Vector3(1.1, 0.6, 1.1)), 0.15, 0.85, 0.1, 0.45)
			await sec(2.5)
			var parts: Array = RestorationCatalog.recipe(id).keys()
			for k: int in parts.size():
				jy.install(id, parts[k])
				await frames(maxi(int(_secs * 30.0 / float(parts.size())), 6))
			await sec(2.5)
		"lux":
			var FakeFB: GDScript = load("res://tests/social_test.gd")
			var fb: Object = FakeFB.FakeFB.new()
			fb.tree = self
			fb.store = {}
			fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
			Engine.register_singleton("GodotFirebaseAndroid", fb)
			await _boot(false)
			var tour: Array = [
				["featured_emre", [
					[AABB(Vector3(-5.8, 0.0, -3.875), Vector3(5.6, 0.6, 3.675)), 2.5],
					[AABB(Vector3(-5.8, 0.0, -3.9), Vector3(2.8, 0.8, 2.4)), 3.0],
					[AABB(Vector3(-2.9, 0.0, -3.9), Vector3(2.7, 0.8, 2.2)), 3.0]]],
				["featured_elif", [
					[AABB(Vector3(-5.8, 0.0, -3.875), Vector3(5.6, 0.6, 3.675)), 2.5],
					[AABB(Vector3(-4.2, 0.0, -2.2), Vector3(2.8, 0.8, 2.0)), 3.0],
					[AABB(Vector3(-3.4, 0.0, -3.9), Vector3(3.2, 0.8, 2.0)), 3.0]]]]
			for entry: Array in tour:
				router.close_all()
				await sec(0.5)
				hud.friends_button.pressed.emit()
				await sec(0.5)
				(current_scene.find_child("Visit_" + String(entry[0]), true, false) as PlateButton).pressed.emit()
				await sec(2.0)
				hud.visible = false
				for bar: Node in get_nodes_in_group("visit_bar"):
					bar.set("visible", false)
				var vcam: WorldCamera = current_scene.get_viewport().get_camera_3d() as WorldCamera
				for stop: Array in entry[1]:
					vcam.frame_box(stop[0], 0.08, 0.92, 0.04, 0.5)
					await sec(float(stop[1]))
				hud.visible = true
				GarageVisit.end(self)
				await sec(1.0)
		_:
			pass
	quit(0)


const LEFT_FACE: float = -3.875
const BACK_FACE: float = -2.475
const RIGHT_EDGE: float = -0.2
const FRONT_EDGE: float = -0.2


func cx(i: float) -> float:
	return -0.2 - 0.175 * (i + 0.5)


func cz(j: float) -> float:
	return -0.2 - 0.175 * (j + 0.5)


func L(ext: float) -> float:
	return LEFT_FACE + 0.006 + ext * 0.5


func B(ext: float) -> float:
	return BACK_FACE + 0.006 + ext * 0.5


func R(ext: float) -> float:
	return RIGHT_EDGE - 0.009 - ext * 0.5


## SEVİYE 2 GARAJ (21 x 13 göz): sol önde kırmızı atölye (3 alan), arkada lüks sergi kaidesi, sağ arkada lounge.
func _design2() -> Dictionary:
	return {
		"wall_surface": "wall_brick",
		"bays": [
			{"x": cx(17.5), "z": cz(3.2), "yaw": 0.0},
			{"x": cx(13.5), "z": cz(3.2), "yaw": 0.0},
			{"x": cx(9.5), "z": cz(3.2), "yaw": 0.0},
		],
		"cars": ["lambo_huracan", "ferrari_488_pista", "mercedes_300sl", "porsche_gt3"],
		"tiles": [
			["concrete_dark", 0, 0, 20, 12],
			["epoxy_red", 7, 0, 20, 6],
			["hazard", 7, 6, 20, 6],
			["hazard", 7, 0, 7, 5],
			["wood_dark", 0, 7, 6, 12],
			["checker_red", 1, 8, 5, 11],
			["checker_bw_big", 8, 8, 14, 12],
			["carbon", 15, 8, 20, 12],
		],
		"walls": [],
		"items": [
			["car:lambo_huracan", cx(11.0), cz(9.6), 0.0],
			["car:ferrari_488_pista", cx(17.6), cz(9.2), 0.0],
			["car:mercedes_300sl", cx(3.2), cz(2.6), 90.0],
			["neon_garage", "back", cx(11.0)],
			["neon_car", "back", cx(17.5)],
			["poster_red", "back", cx(14.2)],
			["poster_blue", "back", cx(7.9)],
			["wall_clock", "back", cx(8.7)],
			["led_strip", "back", cx(3.6)],
			["pegboard", "left", cz(8.0)],
			["sign_service", "left", cz(3.2)],
			["wall_shelf", "left", cz(11.0)],
			["parts_shelf", cx(17.4), B(0.125), 0.0],
			["tyre_rack", cx(19.5), B(0.127), 0.0],
			["workbench", cx(13.2), B(0.097), 0.0],
			["tool_cabinet", L(0.115), cz(9.0), 90.0],
			["compressor", L(0.104), cz(6.4), 0.0],
			["tool_trolley", cx(15.5), cz(6.9), 0.0],
			["mechanic", cx(11.5), cz(5.6), 0.0],
			["mechanic", cx(15.7), cz(1.0), 0.0],
			["oil_drums", cx(19.3), cz(7.5), 0.0],
			["traffic_cones", cx(7.8), cz(0.6), 0.0],
			["sofa", cx(3.0), B(0.125), 0.0],
			["coffee_table", cx(3.0), cz(9.4), 0.0],
			["vending", cx(5.9), B(0.115), 0.0],
			["jukebox", R(0.112), cz(10.4), 0.0],
			["potted_plant", cx(0.9), B(0.113), 0.0],
			["potted_plant", cx(6.2), cz(7.6), 0.0],
			["trophy_case", cx(9.0), B(0.071), 0.0],
			["flagpole", R(0.066), cz(0.6), 0.0],
		],
	}


func _decor_state(design: Dictionary, view: GarageDecorView) -> Dictionary:
	var owned: Dictionary = {}
	var instances: Array = []
	var n: int = 1
	var area: DecorArea = view.area()
	for entry: Array in design["items"]:
		var item: StringName = StringName(entry[0])
		var pos: Vector3
		var yaw: float
		if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
			var mount: Dictionary = area.mount_on(entry[1], float(entry[2]), view.wall_width(item))
			pos = mount["position"]
			yaw = float(mount["yaw"])
		else:
			pos = Vector3(float(entry[1]), area.floor_y, float(entry[2]))
			yaw = float(entry[3]) if entry.size() > 3 else 0.0
		if not GarageDecor.is_vehicle(item):
			owned[String(item)] = int(owned.get(String(item), 0)) + 1
		instances.append({"instance_id": "i%d" % n, "catalog_id": String(item),
			"position": {"x": pos.x, "y": pos.y, "z": pos.z}, "rotation": {"x": 0.0, "y": yaw, "z": 0.0},
			"scale": {"x": 1.0, "y": 1.0, "z": 1.0}})
		n += 1
	var cells: Dictionary = {}
	for rect: Array in design["tiles"]:
		for j: int in range(int(rect[2]), int(rect[4]) + 1):
			for i: int in range(int(rect[1]), int(rect[3]) + 1):
				if DecorGrid.in_bounds(Vector2i(i, j)):
					cells[Vector2i(i, j)] = String(rect[0])
	var palette: Array = []
	var rows: Array = []
	for j: int in DecorGrid.MAX_ROWS:
		var row: String = ""
		for i: int in DecorGrid.MAX_COLS:
			var pat: String = cells.get(Vector2i(i, j), "")
			if pat == "":
				row += "."
				continue
			if not palette.has(pat):
				palette.append(pat)
			row += DecorManager.TILE_ALPHABET[palette.find(pat)]
		rows.append(row)
	var surfaces: Dictionary = {}
	if String(design.get("wall_surface", "")) != "":
		surfaces["wall"] = design["wall_surface"]
		owned[design["wall_surface"]] = 1
	for pat: String in palette:
		owned.erase(pat)
	return {"owned": owned, "instances": instances, "surfaces": surfaces, "next_instance": n,
		"tiles": {"palette": palette, "rows": rows}, "walls": []}


func _validate(design: Dictionary, view: GarageDecorView, decor: DecorManager) -> void:
	print("DECOR yüklenen ", decor.instance_count(), " / ", (design["items"] as Array).size())
	for inst: Dictionary in decor.instances():
		var yaw: float = float((inst["rot"] as Vector3).y)
		if not view.is_valid(inst["item"], inst["pos"], yaw, inst["iid"]):
			var poly: PackedVector2Array = view.footprint(inst["item"], inst["pos"], yaw)
			var why: String = ""
			if not view.area().inside_floor(poly):
				why += " dışarıda"
			if view.area().hits_obstacle(poly):
				why += " engel"
			if view.area().hits_wall(poly):
				why += " duvar"
			for other: Dictionary in decor.instances():
				if other["iid"] != inst["iid"] and GarageDecor.placement(other["item"]) != GarageDecor.PLACE_WALL \
						and DecorArea.overlaps(poly, view.footprint(other["item"], other["pos"], float((other["rot"] as Vector3).y))):
					why += " çakışma:" + String(other["item"])
			print("DECOR HATA geçersiz: %s @ (%.2f, %.2f) %d°%s" % [inst["item"], inst["pos"].x, inst["pos"].z, yaw, why])
	for i: int in 3:
		if not view.is_bay_valid(i, bays.bay_position(i), bays.bay_yaw(i)):
			print("DECOR HATA tamir alanı %d geçersiz @ %s" % [i, bays.bay_position(i)])



func _tap(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		root.push_input(event)
		await frames(2)


func _tap_control(control: Control) -> void:
	await _tap(control.get_global_rect().get_center())
