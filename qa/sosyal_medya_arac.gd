extends SceneTree
## Sosyal medya araç portreleri ve turntable klipleri (stüdyo zemini, fabrika boyası).
##   Foto : godot-4 --path . --resolution 1920x1080 --script qa/sosyal_medya_arac.gd -- foto <çıktı_klasörü> [id ...]
##   Video: godot-4 --path . --resolution 1920x1080 --write-movie <x.avi> --fixed-fps 30 \
##          --script qa/sosyal_medya_arac.gd -- video <id> [saniye]
const FOV_H: float = 30.0
const BG: Color = Color(0.93, 0.87, 0.74)
var _mode: String = ""
var _out: String = ""
var _ids: Array[StringName] = []
var _world: Node3D
var _camera: Camera3D
var _holder: Node3D
var _sun: DirectionalLight3D
var _vp: SubViewport
var _disc: MeshInstance3D
var _ring: MeshInstance3D
var _look: Vector3
var _cam_base: Vector3


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_mode = args[0]
	_out = args[1]
	for i: int in range(2, args.size()):
		if _mode == "foto":
			_ids.append(StringName(args[i]))
	if _mode == "video":
		_ids.append(StringName(args[1]))
	if _mode == "spin":
		for i: int in range(2, args.size()):
			_ids.append(StringName(args[i]))
	if _mode == "spinpng":
		DirAccess.make_dir_recursive_absolute(_out)
		for i: int in range(4, args.size()):
			_ids.append(StringName(args[i]))
	if _ids.is_empty():
		for entry: Dictionary in CarCatalog.all():
			_ids.append(StringName(entry["id"]))
	if _mode == "foto":
		DirAccess.make_dir_recursive_absolute(_out)
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	get_root().add_child(_vp)
	_build_world(get_root() if _mode in ["video", "spin"] else _vp)
	_run.call_deferred(args)


func _build_world(parent: Node) -> void:
	_world = Node3D.new()
	parent.add_child(_world)
	var env: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = BG
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1.0, 0.96, 0.9)
	e.ambient_light_energy = 0.85
	env.environment = e
	_world.add_child(env)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-48.0, -40.0, 0.0)
	_sun.light_energy = 1.15
	_sun.shadow_enabled = true
	_world.add_child(_sun)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 3.3
	cyl.bottom_radius = 3.3
	cyl.height = 0.12
	disc.mesh = cyl
	disc.position = Vector3(0.0, -0.06, 0.0)
	var disc_mat: StandardMaterial3D = StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.26, 0.27, 0.29)
	disc_mat.roughness = 0.9
	disc.material_override = disc_mat
	_world.add_child(disc)
	_disc = disc
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 3.22
	torus.outer_radius = 3.34
	ring.mesh = torus
	ring.scale = Vector3(1.0, 0.25, 1.0)
	ring.position = Vector3(0.0, 0.005, 0.0)
	var ring_mat: StandardMaterial3D = StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.8, 0.15)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring.material_override = ring_mat
	_world.add_child(ring)
	_ring = ring
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(80.0, 80.0)
	floor_mesh.mesh = plane
	floor_mesh.position = Vector3(0.0, -0.13, 0.0)
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.albedo_color = BG
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mesh.material_override = floor_mat
	_world.add_child(floor_mesh)
	_camera = Camera3D.new()
	_camera.keep_aspect = Camera3D.KEEP_WIDTH
	_camera.fov = FOV_H
	_world.add_child(_camera)
	_holder = Node3D.new()
	_world.add_child(_holder)


func _aabb(n: Node, root: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var cur: Node = stack.pop_back()
		for c: Node in cur.get_children():
			stack.append(c)
		if cur is MeshInstance3D:
			var mi: MeshInstance3D = cur
			var local: AABB = root.global_transform.affine_inverse() * mi.global_transform * mi.get_aabb()
			if first:
				box = local
				first = false
			else:
				box = box.merge(local)
	return box


func _spawn(id: StringName) -> void:
	for c: Node in _holder.get_children():
		c.free()
	var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
	car.scale = Vector3.ONE * CarCatalog.model_scale(id)
	_holder.add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(CarCatalog.scene_path(id)))
	_holder.rotation = Vector3.ZERO
	var box: AABB = _aabb(car, _holder)
	car.position = Vector3(-box.get_center().x, 0.0, -box.get_center().z)
	var radius: float = maxf(box.size.x, box.size.z) * 0.5
	# Araç kutusunun merkezi ve boyuna göre kamera mesafesi (yatay görüş alanına sığar)
	_disc.scale = Vector3(radius * 1.4 / 3.3, 1.0, radius * 1.4 / 3.3)
	_ring.scale = Vector3(radius * 1.4 / 3.3, 0.25, radius * 1.4 / 3.3)
	var dist: float = radius * 1.65 / tan(deg_to_rad(FOV_H * 0.5))
	var look: Vector3 = Vector3(0.0, box.size.y * 0.15, 0.0)
	if _mode == "spinpng" and _vp.size.y > _vp.size.x:
		dist *= 0.84   # dikey çerçevede araç daha büyük dursun
	_camera.position = Vector3(0.0, look.y + dist * 0.27, dist)
	_camera.look_at(look, Vector3.UP)
	_look = look
	_cam_base = _camera.position
	_camera.far = dist * 4.0


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(path: String) -> void:
	RenderingServer.force_draw()
	_vp.get_texture().get_image().save_png(path)


func _run(args: PackedStringArray) -> void:
	await _frames(3)
	if _mode == "video":
		var secs: float = float(args[2]) if args.size() > 2 else 8.0
		_spawn(_ids[0])
		var total: int = int(secs * 30.0)
		for i: int in total:
			_holder.rotation.y = TAU * float(i) / float(total) + deg_to_rad(25.0)
			await process_frame
		quit(0)
		return
	if _mode == "spinpng":
		var wh: PackedStringArray = args[2].split("x")
		_vp.size = Vector2i(int(wh[0]), int(wh[1]))
		var lab: Label = Label.new()
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.anchor_right = 1.0
		lab.anchor_top = 1.0
		lab.anchor_bottom = 1.0
		lab.offset_top = -float(_vp.size.y) * 0.13
		lab.offset_bottom = -float(_vp.size.y) * 0.03
		lab.add_theme_font_size_override("font_size", int(_vp.size.x * 0.05))
		lab.add_theme_color_override("font_color", Color(0.17, 0.12, 0.08))
		lab.add_theme_color_override("font_outline_color", Color(0.96, 0.9, 0.78))
		lab.add_theme_constant_override("outline_size", int(_vp.size.x * 0.012))
		_vp.add_child(lab)
		var perf: int = int(float(args[3]) * 30.0)
		var spinf: float = TAU * clampf(float(args[3]) * 0.7, 0.35, 0.9)
		var n: int = 0
		for id: StringName in _ids:
			_spawn(id)
			lab.text = String(CarCatalog.get_entry(id).get("display_name", "")).to_upper()
			var sweep: float = 60.0 + float(args[3]) * 33.0   # ± derece: araç hep ÖNDEN / yandan görünür, arkası değil
			for i: int in perf:
				var k: float = float(i) / float(perf - 1)
				var e: float = k * k * (3.0 - 2.0 * k)
				_holder.rotation.y = deg_to_rad(-sweep + 2.0 * sweep * e)
				_camera.position = _look + (_cam_base - _look) * (1.0 - 0.08 * k)
				await process_frame
				await RenderingServer.frame_post_draw
				_vp.get_texture().get_image().save_png("%s/%05d.png" % [_out, n])
				n += 1
		quit(0)
		return
	if _mode == "spin":
		var label: Label = Label.new()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.anchor_left = 0.0
		label.anchor_right = 1.0
		label.anchor_top = 1.0
		label.anchor_bottom = 1.0
		label.offset_top = -get_root().size.y * 0.16
		label.offset_bottom = -get_root().size.y * 0.06
		label.add_theme_font_size_override("font_size", int(get_root().size.x * 0.05))
		label.add_theme_color_override("font_color", Color(0.17, 0.12, 0.08))
		label.add_theme_color_override("font_outline_color", Color(0.96, 0.9, 0.78))
		label.add_theme_constant_override("outline_size", int(get_root().size.x * 0.012))
		var layer: CanvasLayer = CanvasLayer.new()
		layer.add_child(label)
		get_root().add_child(layer)
		var per: int = int(float(_out) * 30.0)
		var spin: float = TAU * clampf(float(_out) * 0.7, 0.35, 0.9)
		for id: StringName in _ids:
			_spawn(id)
			label.text = String(CarCatalog.get_entry(id).get("display_name", "")).to_upper()
			for i: int in per:
				var k: float = float(i) / float(per)
				_holder.rotation.y = deg_to_rad(90.0) + spin * k
				await process_frame
		quit(0)
		return
	var angles: Dictionary = {"onden": 30.0, "yandan": 90.0, "arkadan": 210.0}
	var sizes: Dictionary = {"yatay": Vector2i(1920, 1080), "dikey": Vector2i(1080, 1350)}
	for id: StringName in _ids:
		_spawn(id)
		for sname: String in sizes:
			_vp.size = sizes[sname]
			await _frames(4)
			for aname: String in angles:
				_holder.rotation.y = deg_to_rad(angles[aname])
				await _frames(4)
				_shot("%s/%s_%s_%s.png" % [_out, id, aname, sname])
		print("çekildi: ", id)
	quit(0)
