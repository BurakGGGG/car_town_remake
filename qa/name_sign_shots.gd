extends SceneTree
## İSİM TABELASI görsel denetimi: her iç mekân (otopark + 5 depo) birkaç araçla ve örnek tabelayla, oyundaki genel
## görünüm kamerasıyla telefon oranında çizilir → ~/Projects/ct_shots/name_sign/<garaj>_<stil>.png.
## Kullanım (PENCERELİ):
##   godot-4 --path . --display-driver x11 --disable-vsync --resolution 640x360 \
##     --script res://qa/name_sign_shots.gd [-- <garaj_id> ...]

const RENDER_SIZE: Vector2i = Vector2i(1280, 720)
const SAMPLES: Array[Dictionary] = [
	{"t": "Burak Garaj", "s": 0, "c": 0},
	{"t": "Neon Gece", "s": 1, "c": 0},
	{"t": "Usta", "s": 2, "c": 4},
	{"t": "Auto Yard 2026", "s": 3, "c": 3},
]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var out_dir: String = OS.get_environment("HOME") + "/Projects/ct_shots/name_sign/"
	DirAccess.make_dir_recursive_absolute(out_dir)
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	var key: DirectionalLight3D = DirectionalLight3D.new()
	viewport.add_child(key)
	var view: GarageInteriorView = GarageInteriorView.new()
	root.add_child(view)
	var cars: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if CarCatalog.is_obtainable(StringName(entry["id"])):
			cars.append(StringName(entry["id"]))
		if cars.size() >= 12:
			break
	var ids: Array[StringName] = [CarGarageManager.WAITING]
	ids.append_array(CarGarageCatalog.ids())
	for garage: StringName in ids:
		if not wanted.is_empty() and not wanted.has(String(garage)):
			continue
		if not view.enter(garage, viewport, camera, key, []):
			push_error("name_sign_shots: %s iç mekânı yok" % garage)
			continue
		var slots: Array[StringName] = []
		for i: int in mini(view.interior.slot_count(), cars.size()):
			slots.append(cars[i] if i % 3 != 2 else &"")
		view.sync_cars(slots)
		view.overview(false)
		for sample: int in SAMPLES.size():
			view.set_sign(SAMPLES[sample])
			for i: int in 24:
				await process_frame
			var tiles: int = view.name_sign().tile_count() if view.name_sign() else -1
			var image: Image = viewport.get_texture().get_image()
			var path: String = out_dir + "%s_%d.png" % [garage, sample]
			image.save_png(path)
			print("name_sign_shots: %s karo=%d" % [path, tiles])
		view.exit()
		await process_frame
	quit()
