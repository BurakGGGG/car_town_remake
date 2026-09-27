extends SceneTree
## 16 aracı tekerlek DÖNÜK halde yan yana çeker: pivot/çamurluk/zemin hatası gözle görülsün.
const OUT: String = "/home/burak/Projects/ct_shots/wheels/"
const SPIN: float = 40.0
var _frame: int = 0
var _world: Node3D
var _camera: Camera3D
var _cars: Array[Node3D] = []
var _ids: PackedStringArray
var _page: int = 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_ids = PackedStringArray()
	for entry: Dictionary in CarCatalog.all():
		_ids.append(String(entry["id"]))
	_world = Node3D.new()
	get_root().add_child(_world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.22, 0.23, 0.25)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.92, 0.96)
	e.ambient_light_energy = 1.0
	env.environment = e
	_world.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	sun.light_energy = 1.1
	_world.add_child(sun)
	# ZEMİN ÇİZGİSİ: y=0'ın hemen altında ince parlak şerit — teker ona değmiyorsa gözle görülür
	var line: MeshInstance3D = MeshInstance3D.new()
	var bar: BoxMesh = BoxMesh.new()
	bar.size = Vector3(40.0, 0.004, 0.6)
	line.mesh = bar
	line.position = Vector3(0.0, -0.002, 0.0)
	var line_mat: StandardMaterial3D = StandardMaterial3D.new()
	line_mat.albedo_color = Color(1.0, 0.85, 0.2)
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = line_mat
	_world.add_child(line)
	# ZEMİN: y=0 düzlemi — teker havadaysa/gömülüyse burada görünür
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(40.0, 40.0)
	floor_mesh.mesh = plane
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.33, 0.35)
	floor_mesh.material_override = mat
	_world.add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_world.add_child(_camera)

func _build_page(page: int) -> void:
	for c: Node3D in _cars:
		c.free()
	_cars.clear()
	var count: int = 4
	for i: int in count:
		var index: int = page * count + i
		if index >= _ids.size():
			break
		var id: StringName = StringName(_ids[index])
		var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
		car.position = Vector3(float(i) * 1.35 - 2.02, 0.0, 0.0)
		car.rotation_degrees = Vector3(0.0, 90.0, 0.0)   # YANDAN görünsün
		car.scale = Vector3.ONE * CarCatalog.model_scale(id)
		_world.add_child(car)
		var rig: CarRig = CarRig.for_node(car)
		rig.apply(CarAppearance.get_for(CarCatalog.scene_path(id)))
		rig.set_wheel_spin(SPIN)
		_cars.append(car)
	# Yandan bakış: teker/zemin ilişkisi ve çamurluk en iyi buradan görünür
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.size = 5.5
	_camera.position = Vector3(0.0, 0.22, 4.2)
	_camera.rotation_degrees = Vector3.ZERO   # TAM YATAY: y=0 tek bir çizgiye düşer

func _process(_d: float) -> bool:
	_frame += 1
	if _frame == 2:
		_build_page(0)
		return false
	if _frame > 2 and (_frame - 2) % 8 == 0:
		RenderingServer.force_draw()
		get_root().get_texture().get_image().save_png("%ssayfa_%d.png" % [OUT, _page + 1])
		_page += 1
		if _page * 4 >= _ids.size():
			print("çekildi: %d sayfa, teker açısı %.0f°" % [_page, SPIN])
			quit(0)
			return true
		_build_page(_page)
	return false
