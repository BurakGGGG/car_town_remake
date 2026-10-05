extends SceneTree
## ÖNE ÇIKAN ARKADAŞ GARAJLARI — tasarımı (featured_designs.gd) GERÇEK oyunda kurar, oyunun kendi
## yerleşim kurallarıyla doğrular, ekran görüntüsü alır ve açık garaj verisini dışa aktarır.
##
## Çalıştırma (izole kullanıcı klasörü; gerçek kayda dokunmaz):
##   printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_featured"\n' > override.cfg
##   godot-4 --path . --resolution 1600x900 --script res://tools/featured/build_featured.gd -- [kimlik] [--export]
##   rm override.cfg
## Görüntüler: ~/Projects/ct_shots/featured/<kimlik>_*.png
## --export: gameplay/social/featured/<kimlik>.json yazılır (oyun bunu okur). Doğrulama hatası varsa YAZILMAZ.

const Designs: GDScript = preload("res://tools/featured/featured_designs.gd")
const SHOTS: String = "/home/burak/Projects/ct_shots/featured/"
const OUT_DIR: String = "res://gameplay/social/featured/"

var _errors: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(SHOTS)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var export: bool = args.has("--export")
	var only: String = ""
	for a: String in args:
		if not a.begins_with("--"):
			only = a
	var total: int = 0
	for design: Dictionary in Designs.all():
		if only != "" and design["id"] != only:
			continue
		# Her tasarım temiz sahnede: aynı örnek kimlikleri (i1, i2…) önceki tasarımın gövdelerini taşımasın
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join("savegame.json"))
		change_scene_to_file("res://Main.tscn")
		await frames(40)
		var hud: Node = current_scene.find_child("HUD", true, false)
		if hud:
			hud.set("visible", false)
		await build(design, export)
		total += _errors
	_errors = total
	print("RESULT errors=%d" % _errors)
	quit(1 if _errors > 0 else 0)


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func node(group: String) -> Node:
	return get_first_node_in_group(group)


func build(design: Dictionary, export: bool) -> void:
	var id: String = design["id"]
	print("== ", id)
	_errors = 0
	var upgrades: GarageUpgradeManager = node("garage_upgrades")
	var bays: RepairBayManager = node("repair_bays")
	var ownership: VehicleOwnership = node("vehicle_ownership")
	var decor: DecorManager = node("decor")
	var view: GarageDecorView = node("garage_decor_view")
	var progress: PlayerProgress = node("player_progress")
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 4, GarageUpgradeManager.SPEED_ID: 5})
	progress.load_state(int(design["level"]), 0, 0)
	bays.load_layout(design["bays"])
	bays.load_state(3)
	# Araçlar FABRİKA renginde (boya yok)
	ownership.load_state(design["cars"])
	ownership.load_paint({})
	await frames(5)
	view.refresh()
	view._rebuild_area()
	decor.load_state(decor_state(design, view))
	await frames(10)
	view.refresh()
	validate(design, view, decor, bays)
	# Görüntüler: bütün garaj + iki yakın kadraj
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	var lot: Rect2 = view.lot_rect()
	var shots: Array = [
		["full", AABB(Vector3(lot.position.x, 0.0, lot.position.y), Vector3(lot.size.x, 0.45, lot.size.y)), 0.04, 0.98],
		["left", AABB(Vector3(lot.position.x, 0.0, lot.position.y), Vector3(lot.size.x * 0.5, 0.45, lot.size.y)), 0.04, 0.98],
		["right", AABB(Vector3(lot.position.x + lot.size.x * 0.5, 0.0, lot.position.y), Vector3(lot.size.x * 0.5, 0.45, lot.size.y)), 0.04, 0.98],
	]
	for shot: Array in shots:
		camera.min_zoom = 0.5
		camera.frame_box(shot[1], shot[2], shot[3], 0.02)
		await frames(40)
		RenderingServer.force_draw()
		get_root().get_texture().get_image().save_png(SHOTS + "%s_%s.png" % [id, shot[0]])
	if export:
		if _errors > 0:
			print("  DIŞA AKTARILMADI: %d doğrulama hatası" % _errors)
			return
		var save: SaveManager = node("save_manager")
		var garage: Dictionary = PublicGarage.from_snapshot(save.snapshot())
		var out: Dictionary = {
			"id": id, "name": design["name"], "level": int(design["level"]),
			"value": GarageValue.compute(self), "garage": garage,
		}
		var path: String = OUT_DIR + id + ".json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(out, "\t", true) + "\n")
		file.close()
		print("  yazıldı: %s (%d bayt, değer %d)" % [path, PublicGarage.to_json(garage).length(), out["value"]])


## Tasarımdan DecorManager kaydı (v9 biçimi).
func decor_state(design: Dictionary, view: GarageDecorView) -> Dictionary:
	var owned: Dictionary = {}
	var instances: Array = []
	var n: int = 1
	var area: DecorArea = view.area()
	for entry: Array in design["items"]:
		var item: StringName = StringName(entry[0])
		var pos: Vector3
		var yaw: float
		if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
			# ["öğe", "back" | "left", duvar boyunca konum]
			var mount: Dictionary = area.mount_on(entry[1], float(entry[2]), view.wall_width(item))
			pos = mount["position"]
			yaw = float(mount["yaw"])
		else:
			# ["öğe", x, z, yön]
			pos = Vector3(float(entry[1]), area.floor_y, float(entry[2]))
			yaw = float(entry[3]) if entry.size() > 3 else 0.0
		if not GarageDecor.is_vehicle(item):
			owned[String(item)] = int(owned.get(String(item), 0)) + 1
		instances.append({"instance_id": "i%d" % n, "catalog_id": String(item),
			"position": {"x": pos.x, "y": pos.y, "z": pos.z}, "rotation": {"x": 0.0, "y": yaw, "z": 0.0},
			"scale": {"x": 1.0, "y": 1.0, "z": 1.0}})
		n += 1
	# Karolar: [desen, i0, j0, i1, j1] dikdörtgenleri sırayla boyanır (sonraki öncekinin üstüne)
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
	# Duvarlar: [parça, kaplama, "x"|"z", sabit, baş, son] koşuları
	var walls: Array = []
	for run: Array in design["walls"]:
		var piece: String = run[0]
		var finish: String = run[1]
		for k: int in range(int(run[4]), int(run[5])):
			var key: String = DecorGrid.edge_key(StringName(run[2]), k, int(run[3])) if run[2] == "x" \
				else DecorGrid.edge_key(&"z", int(run[3]), k)
			walls.append({"edge": key, "piece": piece, "finish": finish})
			owned[piece] = int(owned.get(piece, 0)) + 1
		if finish != "":
			owned[finish] = 1
	var surfaces: Dictionary = {}
	if String(design.get("wall_surface", "")) != "":
		surfaces["wall"] = design["wall_surface"]
		owned[design["wall_surface"]] = 1
	for pat: String in palette:
		owned.erase(pat)
	return {"owned": owned, "instances": instances, "surfaces": surfaces, "next_instance": n,
		"tiles": {"palette": palette, "rows": rows}, "walls": walls}


## Her eşya / tamir alanı oyunun kuralına göre geçerli mi (garaj içinde, çakışmasız, duvarda yerinde)?
func validate(design: Dictionary, view: GarageDecorView, decor: DecorManager, bays: RepairBayManager) -> void:
	var placed: int = decor.instance_count()
	if placed != (design["items"] as Array).size():
		fail("%d eşyadan %d'i yüklendi" % [(design["items"] as Array).size(), placed])
	for inst: Dictionary in decor.instances():
		var yaw: float = float((inst["rot"] as Vector3).y)
		if not view.is_valid(inst["item"], inst["pos"], yaw, inst["iid"]):
			fail("geçersiz yer: %s @ (%.2f, %.2f) %d°" % [inst["item"], inst["pos"].x, inst["pos"].z, yaw])
	for i: int in 3:
		if not view.is_bay_valid(i, bays.bay_position(i), bays.bay_yaw(i)):
			fail("tamir alanı %d geçersiz @ %s" % [i, bays.bay_position(i)])
	var expected_walls: int = 0
	for run: Array in design["walls"]:
		expected_walls += int(run[5]) - int(run[4])
	if decor.wall_count() != expected_walls:
		fail("duvar: %d / %d" % [decor.wall_count(), expected_walls])
	for key: String in decor.walls():
		if not view.wall_edge_valid(key):
			fail("duvar kenarı geçersiz: %s" % key)
	print("  %d eşya, %d duvar, %d karo; hata %d" % [placed, decor.wall_count(), decor.tile_count(), _errors])


func fail(text: String) -> void:
	_errors += 1
	print("  HATA ", text)
