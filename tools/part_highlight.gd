extends SceneTree
## PARÇA VURGU RENDER'I — seçilen tripo_part_N parçalarını sırayla kırmızı, yeşil, mavi, sarı, mor, camgöbeği,
## turuncu, eflatun boyar; aracı dört açıdan (sağ-arka, sol-arka, sağ-ön, sol-ön) çizer. Rol / teker grubu teşhisi.
## Kullanım: godot-4 --path . --resolution 480x300 -s res://tools/part_highlight.gd -- <çıktı.png> <id> <n,n,...>
## Ön = +Z; "sağ" = aracın +X yanı.

const COLORS: Array[Color] = [Color.RED, Color.LIME, Color.BLUE, Color.YELLOW, Color.MAGENTA, Color.CYAN, Color.ORANGE, Color.PURPLE]


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0]
	var id: String = args[1]
	var want: Array[int] = []
	for s: String in args[2].split(","):
		want.append(int(s))
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
	stage.add_child(light)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = Color(0.85, 0.85, 0.85)
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color.WHITE
	stage.add_child(we)
	var car: Node3D = (load(CarCatalog.scene_path(StringName(id))) as PackedScene).instantiate()
	stage.add_child(car)
	for m: Node in car.find_children("tripo_part_*", "MeshInstance3D", true, false):
		var k: int = want.find(int(String(m.name).get_slice("_", 2)))
		if k >= 0:
			var mat: StandardMaterial3D = StandardMaterial3D.new()
			mat.albedo_color = COLORS[k % COLORS.size()]
			(m as MeshInstance3D).material_override = mat
	var cam: Camera3D = Camera3D.new()
	cam.fov = 32.0
	stage.add_child(cam)
	cam.current = true
	var sheet: Image = null
	var k2: int = 0
	for pos: Vector3 in [Vector3(1.1, 0.35, -0.8), Vector3(-1.1, 0.35, -0.8), Vector3(1.1, 0.35, 0.8), Vector3(-1.1, 0.35, 0.8)]:
		cam.position = pos
		cam.look_at(Vector3(0, 0.12, 0), Vector3.UP)
		for i: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var img: Image = get_root().get_texture().get_image()
		if sheet == null:
			sheet = Image.create(img.get_width() * 2, img.get_height() * 2, false, img.get_format())
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() * (k2 % 2), img.get_height() * (k2 / 2)))
		k2 += 1
	sheet.save_png(out)
	quit()
