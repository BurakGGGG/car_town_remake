extends SceneTree
## BOYA ÖNİZLEME — aracı verilen renge boyayıp dört açıdan render eder (boya maskesi görsel kontrolü).
## Kullanım: godot-4 --path . --resolution 640x400 -s res://tools/paint_preview.gd -- <id> "#1A43B8" <çıktı.png>
func _initialize() -> void:
	await process_frame
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
	stage.add_child(sun)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.85, 0.85, 0.82)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	stage.add_child(we)
	var path: String = CarCatalog.scene_path(StringName(a[0]))
	var car: Node3D = (load(path) as PackedScene).instantiate()
	stage.add_child(car)
	var app: CarAppearance = CarAppearance.new()
	app.body_color = Color(a[1])
	CarRig.for_node(car).apply(app)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 28.0
	stage.add_child(cam)
	cam.current = true
	var sheet: Image = null
	var k: int = 0
	for pos: Vector3 in [Vector3(0.9, 0.45, 0.75), Vector3(-0.9, 0.5, -0.7), Vector3(0.0, 1.3, 0.05), Vector3(1.1, 0.2, -0.2)]:
		cam.position = pos
		cam.look_at(Vector3(0, 0.12, 0), Vector3.UP)
		for i: int in 4: await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_root().get_texture().get_image()
		if sheet == null:
			sheet = Image.create(img.get_width() * 2, img.get_height() * 2, false, img.get_format())
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() * (k % 2), img.get_height() * (k / 2)))
		k += 1
	sheet.save_png(a[2])
	quit()
