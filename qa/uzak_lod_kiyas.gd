extends SceneTree
## UZAK LOD KIYASI (CarFarLod): her araç birleşik mesh'iyle (garajın sergi araçları gibi tekerler dahil) üç hâlde çizilir —
## LOD0 (tam detay), eski en kaba kademe (içe aktarıcının), yeni uzak kademe — her biri yakın (araç ekranı dolduruyor),
## orta ve uzak (garajın uzak sergi araçları kadar) kadrajda; kademe zorla en kaba (lod_bias 0). Satırlar: tam / eski / yeni.
## Konsolda çizilen üçgen. Çıktı: <klasör>/<id>.png
##   godot-4 --path . --display-driver x11 --resolution 1500x900 -s res://qa/uzak_lod_kiyas.gd -- <klasör> <id> ...

const SPANS: Array[float] = [1.15, 3.0, 9.0]   # kadraj genişliği / araç uzunluğu
const TILE: Vector2i = Vector2i(500, 300)


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.6, 0.66)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	root.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	root.add_child(cam)
	cam.make_current()
	root.size = Vector2i(TILE.x * SPANS.size(), TILE.y)
	for id: String in args.slice(1):
		var path: String = CarCatalog.scene_path(StringName(id))
		var sheet: Image = Image.create(TILE.x * SPANS.size(), TILE.y * 3, false, Image.FORMAT_RGB8)
		var report: PackedStringArray = PackedStringArray()
		for row: int in 3:   # 0 tam detay, 1 eski en kaba, 2 yeni uzak
			CarFarLod.enabled = row == 2
			CarMeshMerger.clear_cache()
			var car: Node3D = (load(path) as PackedScene).instantiate() as Node3D
			root.add_child(car)
			var rig: CarRig = CarRig.for_node(car)
			rig.apply(CarAppearance.get_for(path))
			rig.set_steer(0.0)
			rig.optimize(true, true)
			await _frames(2)
			while CarMeshMerger.busy():
				await process_frame
			rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE if row == 0 else 0.0)
			var box: AABB = _bounds(car)
			for col: int in SPANS.size():
				cam.size = box.size.x * SPANS[col] * float(TILE.y) / float(TILE.x)
				cam.size = maxf(box.size.z, box.size.x) * SPANS[col] * float(TILE.y) / float(TILE.x)
				var center: Vector3 = box.get_center()
				cam.look_at_from_position(center + Vector3(1.0, 0.55, 0.85).normalized() * 20.0, center, Vector3.UP)
				root.size = TILE
				await _frames(3)
				RenderingServer.force_draw()
				var tris: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
				var shot: Image = root.get_texture().get_image()
				shot.convert(Image.FORMAT_RGB8)
				sheet.blit_rect(shot, Rect2i(Vector2i.ZERO, TILE), Vector2i(col * TILE.x, row * TILE.y))
				if col == 0:
					report.append(str(tris))
			car.free()
		CarFarLod.enabled = true
		sheet.save_png(out_dir.path_join(id + ".png"))
		print("UZAKLOD %s üçgen: tam %s, eski kaba %s, yeni uzak %s" % [id, report[0], report[1], report[2]])
	quit(0)


func _bounds(car: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.visible:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
