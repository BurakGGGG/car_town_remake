extends RefCounted
## 7–12 sn KENDİ KOLEKSİYONUNU OLUŞTUR. Gerçek oyun dünyası (Main.tscn), seviye 2 garaj dekorlu kurulur;
## altı araç arka duvar önünde tek sırada, burunları kameraya dönük. Kamera: yüksekten iniş → alçak kayma
## (Evo VI, M3) → vuruşta dört hızlı kesme (Land Rover, S400, RS6, Toros) → geri çekilip tüm garaj.
const D = preload("res://qa/teaser/teaser.gd")
## Soldan sağa (kameradan bakınca) dizilim.
const CARS: Array[StringName] = [&"mitsubishi_evo6", &"bmw_m3_e30", &"land_rover_series3", &"mercedes_s400",
	&"audi_rs6", &"renault_toros"]
const COLS: Array[float] = [18.2, 14.9, 11.6, 8.3, 5.0, 1.7]
const ROW: float = 8.6
const CUTS: Array[float] = [7.0, 8.2, 9.0, 9.4, 9.8, 10.2, 10.6]

var d: D
var cam: Camera3D
var title: Label
var car_x: Array[float] = []
var car_z: float = 0.0
var car_h: Array[float] = []


func run(director: D) -> void:
	d = director
	await d.frames(2)
	d.change_scene_to_file("res://Main.tscn")
	await d.frames(70)
	var hud: Hud = d.current_scene.find_child("HUD", true, false) as Hud
	var own: VehicleOwnership = d.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var bays: RepairBayManager = d.get_first_node_in_group("repair_bays") as RepairBayManager
	(d.get_first_node_in_group("economy") as EconomyManager).set_money(900000)
	(d.get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
	var design: Dictionary = _design()
	bays.load_layout(design["bays"])
	bays.load_state(1)
	for id: StringName in CARS:
		own.add_vehicle(id)
	await d.frames(15)
	var view: GarageDecorView = d.get_first_node_in_group("garage_decor_view") as GarageDecorView
	view.refresh()
	view._rebuild_area()
	var decor: DecorManager = d.get_first_node_in_group("decor") as DecorManager
	decor.load_state(_decor_state(design, view))
	await d.frames(15)
	view.refresh()
	hud.visible = false
	# SubViewport aynı 3B dünyayı kendi kamerasıyla çizer; pencerenin kendi 3B çizimi kapatılır
	d.vp.world_3d = d.root.get_world_3d()
	cam = Camera3D.new()
	cam.near = 0.01
	cam.far = 80.0
	d.vp.add_child(cam)
	cam.make_current()
	d.root.disable_3d = true
	_sky()
	for c: float in COLS:
		car_x.append(cx(c))
	car_z = cz(ROW)
	for id: StringName in CARS:
		car_h.append(0.16)
	title = d.make_title("KENDİ KOLEKSİYONUNU\nOLUŞTUR.", 90, 0.13, 900, Color.WHITE)
	await d.frames(20)
	await d.record(tick)


func tick(t: float) -> void:
	d.reset_post()
	var shot: int = 0
	for i: int in CUTS.size():
		if t >= CUTS[i]:
			shot = i
	var s0: float = CUTS[shot]
	var s1: float = CUTS[shot + 1] if shot + 1 < CUTS.size() else 12.0
	var k: float = D.span(t, s0, s1)
	d.set_post(&"white", D.pulse(t, s0, 0.12) * (0.8 if shot == 0 else 0.35))
	d.set_post(&"aberration", 0.3 + D.pulse(t, s0, 0.15) * 4.0)
	d.set_post(&"vignette", 0.38)
	d.set_post(&"grain", 0.03)
	var mid_x: float = (car_x[0] + car_x[5]) * 0.5
	match shot:
		0:
			# Yüksekten iniş: tüm garaj → ortadaki araçlara doğru alçalır
			# Çapraz ön köşeden: sıra derinliğe uzanır, dikey kadraja altı araç da girer
			var e: float = D.ease_out(k, 2.4)
			var pos: Vector3 = Vector3(1.3, 2.1, 1.5).lerp(Vector3(-0.15, 0.2, -0.75), e)
			var look: Vector3 = Vector3(mid_x, 0.0, car_z + 0.3).lerp(Vector3(mid_x - 0.35, 0.16, car_z - 0.05), e)
			D.look_cam(cam, pos, look)
			cam.fov = lerpf(58.0, 50.0, e)
		1:
			# Alçak yan kayma: Evo VI → M3 burunları
			var x: float = lerpf(car_x[0] + 0.2, car_x[1] - 0.1, D.smooth(k))
			D.look_cam(cam, Vector3(x, 0.07, car_z + 0.62), Vector3(x - 0.12, 0.09, car_z), 2.0)
			cam.fov = 50.0
		2, 3, 4, 5:
			var i: int = shot
			var side: float = -1.0 if shot % 2 == 0 else 1.0
			var e2: float = D.ease_out(k, 2.0)
			var target: Vector3 = Vector3(car_x[i], 0.1, car_z + 0.12)
			var pos2: Vector3 = target + Vector3(side * lerpf(0.42, 0.3, e2), lerpf(0.03, 0.07, e2), lerpf(0.62, 0.48, e2))
			D.look_cam(cam, pos2, target, side * -3.0)
			cam.fov = 48.0
		6:
			# Geri çekiliş: alçaktan yükseğe, tüm koleksiyon
			var e3: float = D.smooth(k)
			var pos3: Vector3 = Vector3(car_x[5] + 0.1, 0.07, car_z + 0.6).lerp(Vector3(0.05, 0.62, -0.25), D.ease_out(k, 2.0))
			D.look_cam(cam, pos3, Vector3(mid_x - 0.3, lerpf(0.12, 0.1, e3), car_z - 0.05))
			cam.fov = lerpf(55.0, 50.0, e3)
	# Yazı: 7,15'te darbeyle gelir, 11,85'te söner
	var a: float = D.span(t, 7.2, 7.37)
	title.modulate.a = D.ease_out(a, 2.0) * (1.0 - D.span(t, 11.85, 11.97))
	title.scale = Vector2.ONE * (lerpf(1.5, 1.0, D.ease_out(a, 4.0)) + D.pulse(t, 7.37, 0.12) * 0.05)


## Ana dünyada Environment yok (düz gri arka plan; oyun yukarıdan baktığı için gökyüzü görünmez). Alçak
## kamerada mavi gökyüzü: yalnızca bu kameraya; ortam ışığı varsayılanla aynı, yansıma / ton eşleme kapalı.
func _sky() -> void:
	var mat: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.2, 0.42, 0.82)
	mat.sky_horizon_color = Color(0.7, 0.82, 0.95)
	mat.ground_horizon_color = Color(0.7, 0.82, 0.95)
	mat.ground_bottom_color = Color(0.3, 0.35, 0.3)
	var sky: Sky = Sky.new()
	sky.sky_material = mat
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	# Environment yokken ortam ışığı = varsayılan temizleme rengi (0,3 gri); aynısı verilir
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color(0.3, 0.3, 0.3))
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = e


# --- Garaj tasarımı (qa/sosyal_medya_film.gd ızgarası: 21 x 13 göz, i=0 sağ, j=0 ön) -------------------

const LEFT_FACE: float = -3.875
const BACK_FACE: float = -2.475
const RIGHT_EDGE: float = -0.2


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


## Showroom: arkada marka mavisi epoksi sergi şeridi + altı araç, önde açık zemin; sol ön köşe lounge,
## sağ ön köşe tek tamir alanı ve tezgâh.
func _design() -> Dictionary:
	var items: Array = []
	for i: int in CARS.size():
		items.append(["car:" + String(CARS[i]), cx(COLS[i]), cz(ROW), 0.0])
	items.append_array([
		["neon_garage", "back", cx(10.0)],
		["neon_car", "back", cx(16.6)],
		["neon_speed", "back", cx(3.4)],
		["led_strip", "back", cx(13.3)],
		["led_strip", "back", cx(6.7)],
		["checkered_flags", "back", cx(19.6)],
		["poster_race", "back", cx(0.9)],
		["tyre_hanger", "left", cz(10.5)],
		["rim_display", "left", cz(7.0)],
		["neon_wrench", "left", cz(3.6)],
		["potted_plant", cx(19.6), cz(4.6), 0.0],
		["potted_plant", cx(0.6), cz(4.6), 0.0],
		["tyre_rack", cx(19.5), B(0.127), 0.0],
		["jukebox", cx(0.5), B(0.112), 0.0],
	])
	return {
		"wall_surface": "wall_brick_grey",
		"bays": [
			{"x": cx(17.5), "z": cz(1.6), "yaw": 90.0},
			{"x": cx(17.5), "z": cz(1.6), "yaw": 90.0},
			{"x": cx(17.5), "z": cz(1.6), "yaw": 90.0},
		],
		"tiles": [
			["concrete_dark", 0, 0, 20, 12],
			["epoxy_blue", 0, 7, 20, 12],
			["hazard", 0, 6, 20, 6],
		],
		"items": items,
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
