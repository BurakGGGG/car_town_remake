extends RefCounted
## Teaser garaj çekimlerinin ortak kurulumu: Main.tscn açılır, garaj seviyesi + tamir alanları + dekor
## (zemin karoları, duvar kaplaması, eşyalar, araçlar) tasarım sözlüğünden kurulur, yerleşim oyunun kendi
## kurallarıyla denetlenir (geçersiz eşya "DECOR HATA" basar), SubViewport aynı dünyaya bağlanır.
## Tasarım koordinatları: u = sağ kenardan (x = -0,2) sola, v = ön kenardan (z = -0,2) arkaya metre.
const D = preload("res://qa/teaser/teaser.gd")
const CELL: float = 0.175

var d: D
var hud: Hud
var own: VehicleOwnership
var bays: RepairBayManager
var view: GarageDecorView
var decor: DecorManager
var traffic: TrafficManager
var cam: Camera3D
var width: float = 0.0
var depth: float = 0.0


static func X(u: float) -> float:
	return -0.2 - u


static func Z(v: float) -> float:
	return -0.2 - v


## Arka duvara yaslı eşyanın v'si (eşyanın derinliği verilir).
func back(item_depth: float) -> float:
	return depth - 0.006 - item_depth * 0.5


## Sol duvara yaslı eşyanın u'su.
func left(item_width: float) -> float:
	return width - 0.006 - item_width * 0.5


func boot(director: D) -> void:
	d = director
	await d.frames(2)
	d.change_scene_to_file("res://Main.tscn")
	await d.frames(70)
	hud = d.current_scene.find_child("HUD", true, false) as Hud
	own = d.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	bays = d.get_first_node_in_group("repair_bays") as RepairBayManager
	view = d.get_first_node_in_group("garage_decor_view") as GarageDecorView
	decor = d.get_first_node_in_group("decor") as DecorManager
	traffic = d.current_scene.find_child("Traffic", true, false) as TrafficManager
	(d.get_first_node_in_group("economy") as EconomyManager).set_money(900000)


## Seviye (1..4) ve ölçüler; tasarım bu ölçülere göre yazılır.
func set_level(level: int) -> void:
	(d.get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: level})
	await d.frames(5)
	var lot: Rect2 = view.lot_rect()
	width = lot.size.x
	depth = lot.size.y


## design: {wall_surface, bays: [[u, v, yaw]], cars: [id], tiles: [[desen, i0, j0, i1, j1]],
##          items: [[eşya, u, v, yaw] | [eşya, "back"/"left", u_ya_da_v]]}
func build(design: Dictionary) -> void:
	var layout: Array = []
	for b: Array in design["bays"]:
		layout.append({"x": X(float(b[0])), "z": Z(float(b[1])), "yaw": float(b[2])})
	while layout.size() < 3:
		layout.append(layout[layout.size() - 1])
	bays.load_layout(layout)
	bays.load_state((design["bays"] as Array).size())
	for id: String in design.get("cars", []):
		own.add_vehicle(StringName(id))
	await d.frames(15)
	view.refresh()
	view._rebuild_area()
	decor.load_state(_decor_state(design))
	await d.frames(15)
	view.refresh()
	_validate(design)
	hud.visible = false


## Tamir alanındaki lifte araç koyup kaldırır (sanayi garajı).
func lift_car(index: int, id: StringName, height: float = 1.0) -> Node3D:
	var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
	car.scale = Vector3.ONE * traffic.model_scale * CarCatalog.model_scale(id)
	d.current_scene.add_child(car)
	var p: Vector2 = bays.bay_position(index)
	car.global_position = Vector3(p.x, 0.0, p.y)
	car.rotation.y = deg_to_rad(bays.bay_yaw(index))
	CarRig.for_node(car).apply(CarAppearance.get_for(CarCatalog.scene_path(id)))
	CarRig.for_node(car).set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	if height > 0.0:
		bays.raise_lift(index, car)
	else:
		car.global_position.y = bays.lift(index).car_y()
	return car


## SubViewport aynı 3B dünyayı kendi kamerasıyla çizer (pencerenin 3B çizimi kapatılır); mavi gökyüzü.
func attach_camera() -> Camera3D:
	d.vp.world_3d = d.root.get_world_3d()
	cam = Camera3D.new()
	cam.near = 0.01
	cam.far = 80.0
	d.vp.add_child(cam)
	cam.make_current()
	d.root.disable_3d = true
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
	# Ana dünyada Environment yok: ortam ışığı varsayılan temizleme rengiyle aynı (oyunun ışığı aynen)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color(0.3, 0.3, 0.3))
	e.ambient_light_energy = 1.0
	e.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = e
	return cam


func _decor_state(design: Dictionary) -> Dictionary:
	var owned: Dictionary = {}
	var instances: Array = []
	var n: int = 1
	var area: DecorArea = view.area()
	for entry: Array in design["items"]:
		var item: StringName = StringName(entry[0])
		var pos: Vector3
		var yaw: float
		if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
			var along: float = X(float(entry[2])) if entry[1] == "back" else Z(float(entry[2]))
			var mount: Dictionary = area.mount_on(entry[1], along, view.wall_width(item))
			pos = mount["position"]
			yaw = float(mount["yaw"])
		else:
			pos = Vector3(X(float(entry[1])), area.floor_y, Z(float(entry[2])))
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


## Oyunun kendi kurallarıyla denetim: her geçersiz eşya ve tamir alanı nedeniyle basılır.
func _validate(design: Dictionary) -> void:
	print("DECOR yüklenen ", decor.instance_count(), " / ", (design["items"] as Array).size())
	for inst: Dictionary in decor.instances():
		var yaw: float = float((inst["rot"] as Vector3).y)
		if view.is_valid(inst["item"], inst["pos"], yaw, inst["iid"]):
			continue
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
		print("DECOR HATA geçersiz: %s @ u=%.2f v=%.2f %d°%s" % [inst["item"], -0.2 - inst["pos"].x, -0.2 - inst["pos"].z, yaw, why])
	for i: int in (design["bays"] as Array).size():
		if not view.is_bay_valid(i, bays.bay_position(i), bays.bay_yaw(i)):
			print("DECOR HATA tamir alanı %d geçersiz" % i)
