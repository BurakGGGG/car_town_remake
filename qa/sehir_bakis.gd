extends SceneTree
## ŞEHİR BAKIŞI — kavşak ve showroom çevresinin görüntüsü (yerleşim kararları için): oyun açısı (geniş) ve
## kuşbakışı. HUD gizli. İşaretler: kırmızı küp +X (doğu), mavi küp +Z (güney), sarı küp kavşak merkezi.
##   tools/qa_isolated.sh res://qa/sehir_bakis.gd --display-driver x11 --resolution 1440x810 [-- <ad>]
## Görüntüler: /home/burak/Projects/ct_shots/sehir/<ad>_oyun.png, <ad>_ust.png

const OUT: String = "/home/burak/Projects/ct_shots/sehir/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _marker(color: Color, at: Vector3) -> void:
	var box: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.15, 0.15, 0.15)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	box.mesh = mesh
	box.position = at
	current_scene.add_child(box)


func _shot(name: String) -> void:
	await frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("kaydedildi: ", OUT + name + ".png")


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var tag: String = args[0] if args.size() > 0 else "sehir"
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	if hud:
		hud.visible = false
	var marks: bool = not args.has("isaretsiz")
	if marks:
		_marker(Color.RED, Vector3(3.0, 0.1, 0.6))
		_marker(Color.BLUE, Vector3(0.6, 0.1, 3.0))
		_marker(Color.YELLOW, Vector3(0.6, 0.1, 0.6))
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	var focus: Vector3 = Vector3(2.4, 0.0, -0.8)
	for i: int in args.size():
		if args[i] == "odak" and i + 2 < args.size():
			focus = Vector3(float(args[i + 1]), 0.0, float(args[i + 2]))
	var zoom: float = 3.6
	for i: int in args.size():
		if args[i] == "zoom" and i + 1 < args.size():
			zoom = float(args[i + 1])
	camera.follow(focus, zoom)
	await frames(60)
	await _shot(tag + "_oyun")
	var top: Camera3D = Camera3D.new()
	top.projection = Camera3D.PROJECTION_ORTHOGONAL
	top.size = 12.0
	current_scene.add_child(top)
	top.global_position = Vector3(2.0, 20.0, -0.5)
	top.rotation_degrees = Vector3(-90.0, 0.0, 0.0)   # yukarısı -Z (kuzey), sağı +X (doğu)
	top.make_current()
	await _shot(tag + "_ust")
	quit(0)
