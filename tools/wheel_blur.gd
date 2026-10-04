extends SceneTree
## TEKERLEK DÖNÜŞ GÖRÜNTÜSÜ — her tekerin 12 dönüş açısındaki render'ının ORTALAMASI (uzun pozlama).
## Kusursuz dönen tekerde lastiğin dış çizgisi keskin kalır, jant kolları düzgün bir diske dönüşür.
## Yalpalayan teker (eksen kaymış / eğik) çift ve bulanık çizgi verir; gövdeye ait dönen parça bulanık leke,
## dönmesi gerekip duran parça keskin kalır.
## Satır başına bir teker (fl, fr, rl, rr); sütunlar: yan (dışarıdan), ön (aks boyunca bakış değil, önden), tek kare.
## Kullanım: godot-4 --path . --resolution 900x300 -s res://tools/wheel_blur.gd -- <çıktı_klasörü> [<id> ...]

const ANGLES: int = 12
const TILE: int = 300


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ids: Array[StringName] = []
	for i: int in range(1, args.size()):
		ids.append(StringName(args[i]))
	if ids.is_empty():
		for entry: Dictionary in CarCatalog.all():
			ids.append(entry["id"])
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.55, 0.75, 0.95)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color.WHITE
	we.environment.ambient_light_energy = 0.8
	stage.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.3, -0.6, -0.7).normalized(), Vector3.UP)
	stage.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.001
	cam.far = 10.0
	stage.add_child(cam)
	cam.current = true
	for id: StringName in ids:
		var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
		stage.add_child(car)
		var rig: CarRig = CarRig.for_node(car)
		rig.apply(CarAppearance.get_for(car.scene_file_path))
		var sheet: Image = Image.create(TILE * 3, TILE * rig._wheel_groups.size(), false, Image.FORMAT_RGBA8)
		for gi: int in rig._wheel_groups.size():
			var group: Dictionary = rig._wheel_groups[gi]
			var pivot: Vector3 = group["pivot"]
			var tyre: MeshInstance3D = group["meshes"][int(group["tyre_index"])]
			var box: AABB = tyre.transform * tyre.get_aabb()
			var r: float = maxf(box.size.y, box.size.z) * 0.5
			# Mesh'ler aracın kök düğümünün (GLB) çocukları: pivot o uzayda → dünyaya çevir
			var parent: Node3D = tyre.get_parent() as Node3D
			var world_pivot: Vector3 = parent.global_transform * pivot
			var side: float = signf(pivot.x) if absf(pivot.x) > 0.001 else 1.0
			cam.size = r * 2.0 * 1.35
			var views: Array = [
				[world_pivot + Vector3(side * 1.5, 0.0, 0.0), Vector3.UP],             # yan, dışarıdan
				[world_pivot + Vector3(0.0, 0.0, 1.5 if gi < 2 else -1.5), Vector3.UP],  # önden / arkadan
			]
			for vi: int in 3:
				var view: Array = views[mini(vi, 1) if vi < 2 else 0]
				cam.position = view[0]
				cam.look_at(world_pivot, view[1])
				var acc: PackedFloat32Array = PackedFloat32Array()
				acc.resize(TILE * TILE * 3)
				var frames_n: int = ANGLES if vi < 2 else 1
				for a: int in frames_n:
					rig.set_wheel_spin(360.0 * float(a) / float(ANGLES) + 7.0)
					await process_frame
					await process_frame
					await RenderingServer.frame_post_draw
					var img: Image = get_root().get_texture().get_image()
					img.convert(Image.FORMAT_RGB8)
					var ox: int = (img.get_width() - TILE) / 2
					var oy: int = (img.get_height() - TILE) / 2
					var data: PackedByteArray = img.get_data()
					var w: int = img.get_width()
					for y: int in TILE:
						var row: int = ((y + oy) * w + ox) * 3
						var arow: int = y * TILE * 3
						for x: int in TILE * 3:
							acc[arow + x] += float(data[row + x])
				var tile: Image = Image.create(TILE, TILE, false, Image.FORMAT_RGB8)
				var bytes: PackedByteArray = PackedByteArray()
				bytes.resize(TILE * TILE * 3)
				for i: int in acc.size():
					bytes[i] = int(acc[i] / float(frames_n))
				tile.set_data(TILE, TILE, false, Image.FORMAT_RGB8, bytes)
				tile.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(vi * TILE, gi * TILE))
			rig.set_wheel_spin(0.0)
		sheet.save_png(out_dir.path_join(String(id) + ".png"))
		print("kaydedildi %s" % id)
		car.queue_free()
		await process_frame
	quit()
