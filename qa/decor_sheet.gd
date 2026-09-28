extends SceneTree
## Dekor modellerini nötr sahnede, zemin çizgisiyle yan yana çeker (kalite kontrolü).
const OUT: String = "/home/burak/Projects/ct_shots/decor/"
var _f: int = 0
var _world: Node3D
var _cam: Camera3D
var _page: int = 0
var _ids: Array = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_ids = OS.get_cmdline_user_args()
	_world = Node3D.new()
	get_root().add_child(_world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.20, 0.21, 0.23)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.88, 0.90, 0.94)
	e.ambient_light_energy = 1.05
	env.environment = e
	_world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	sun.light_energy = 1.15
	_world.add_child(sun)
	var line: MeshInstance3D = MeshInstance3D.new()
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(60.0, 0.006, 2.0)
	line.mesh = bar
	line.position = Vector3(0.0, -0.003, 0.0)
	var lm: StandardMaterial3D = StandardMaterial3D.new()
	lm.albedo_color = Color(1.0, 0.85, 0.2)
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = lm
	_world.add_child(line)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_WIDTH
	_world.add_child(_cam)

func _page_ids(page: int) -> Array:
	return _ids.slice(page * 4, page * 4 + 4)

func _build(page: int) -> void:
	for c: Node in _world.get_children():
		if c.name.begins_with("P_"):
			c.free()
	var ids: Array = _page_ids(page)
	for i: int in ids.size():
		var body: Node3D = DecorBuilder.build(StringName(ids[i]))
		if body == null:
			continue
		body.name = "P_%d" % i
		# Sahnede GERÇEK metre ölçüsünde göster
		body.scale = Vector3.ONE * DecorBuilder.PLACER_SCALE / 0.1367
		body.position = Vector3(float(i) * 4.6 - 6.9, 0.0, 0.0)
		body.rotation_degrees = Vector3(0.0, 28.0, 0.0)
		_world.add_child(body)
	_cam.size = 19.0
	_cam.position = Vector3(0.0, 1.9, 11.0)
	_cam.rotation_degrees = Vector3(-4.0, 0.0, 0.0)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		_build(0)
		return false
	if _f > 2 and (_f - 2) % 8 == 0:
		RenderingServer.force_draw()
		get_root().get_texture().get_image().save_png("%shero_%d.png" % [OUT, _page + 1])
		_page += 1
		if _page * 4 >= _ids.size():
			print("çekildi: %d sayfa" % _page)
			quit(0)
			return true
		_build(_page)
	return false
