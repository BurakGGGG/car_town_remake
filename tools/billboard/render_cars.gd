extends SceneTree
## BILLBOARD AFİŞİ 1/2 — araçları oyunun KENDİ modelleri ve fabrika görünümüyle (CarRig) şeffaf arka planda,
## stüdyo ışığında çizer: alçak 3/4 ön açı, dar perspektif, önden anahtar ışık + iki renkli arka kenar ışığı
## (posters.json rim / rim2). Büyük çizilir (3200×1600), birleştirme küçültürken kenarlar yumuşar.
## Çıktı: /home/burak/Projects/ct_shots/billboard/raw/<id>.png (oyuna girmez; 2. adım tools/billboard/compose.py).
## Kullanım (PENCERELİ — başsızda çizim yok):
##   godot-4 --path . --display-driver x11 --disable-vsync --resolution 640x360 \
##     --script res://tools/billboard/render_cars.gd [-- <id> ...]

const POSTERS: String = "res://tools/billboard/posters.json"
const OUT: String = "/home/burak/Projects/ct_shots/billboard/raw/"
const SIZE: Vector2i = Vector2i(3200, 1600)
## Aracın kadrajdaki eni (görüntü eninin oranı) ve kamera açısı.
const FILL: float = 0.86
const FOV: float = 24.0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(OUT)
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POSTERS))
	for poster: Dictionary in data["posters"]:
		var id: String = poster["id"]
		if not wanted.is_empty() and not wanted.has(id):
			continue
		var image: Image = await _render(StringName(id), poster)
		if image == null:
			push_error("render_cars: %s çizilemedi" % id)
			continue
		image.save_png(OUT + id + ".png")
		print("çizildi: %s (%s)" % [id, image.get_size()])
	quit(0)


func _render(id: StringName, poster: Dictionary) -> Image:
	var entry: Dictionary = CarCatalog.get_entry(id)
	if entry.is_empty():
		return null
	var scene_path: String = entry["scene_path"]
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return null
	var viewport: SubViewport = SubViewport.new()
	viewport.size = SIZE
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(viewport)

	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("C9CEDA")
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = float(poster.get("exposure", 1.0))
	var world_env: WorldEnvironment = WorldEnvironment.new()
	world_env.environment = env
	viewport.add_child(world_env)

	var car: Node3D = scene.instantiate() as Node3D
	viewport.add_child(car)
	var appearance: CarAppearance = CarAppearance.new()   # oyuncunun kayıtlı görünümüne dokunulmaz
	appearance.reset(scene_path)
	var rig: CarRig = CarRig.new(car)
	rig.apply(appearance)
	var bounds: AABB = _bounds(car)
	var center: Vector3 = bounds.get_center()
	var length: float = maxf(maxf(bounds.size.x, bounds.size.z), 0.1)

	# Kamera: aracın ön-sol 3/4'ü (burun görüntünün soluna bakar), alçaktan; aracın eni kadrajın FILL'i
	var az: float = deg_to_rad(float(poster.get("az", 38.0)))
	var elev: float = deg_to_rad(float(poster.get("elev", 8.0)))
	var dir: Vector3 = Vector3(sin(az) * cos(elev), sin(elev), cos(az) * cos(elev))
	var camera: Camera3D = Camera3D.new()
	camera.fov = FOV
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	var aspect: float = float(SIZE.x) / float(SIZE.y)
	var half_width: float = tan(deg_to_rad(FOV) * 0.5)   # KEEP_WIDTH: fov yatay
	var distance: float = (length * 0.62) / (half_width * FILL)
	camera.position = center + dir * distance + Vector3(0.0, -bounds.size.y * 0.08, 0.0)
	viewport.add_child(camera)
	camera.look_at(center + Vector3(0.0, -bounds.size.y * 0.05, 0.0), Vector3.UP)
	camera.current = true

	# Işıklar: önden-yukarıdan sıcak anahtar (gölgeli), arkadan iki renkli kenar ışığı, alttan soğuk dolgu
	var key: DirectionalLight3D = _light(viewport, Color("FFF4E2"), 0.95, center, center + Vector3(length * 1.2, length * 1.6, length * 1.4))
	key.shadow_enabled = true
	key.shadow_blur = 2.0
	# Kenar ışıkları temanın rengini YARI taşır: tam doymuş renk camları / beyaz gövdeyi boyuyordu (Huracán camı pembe)
	_light(viewport, Color(String(poster.get("rim", "#FFFFFF"))).lerp(Color.WHITE, 0.5), 0.85, center, center + Vector3(-length * 1.4, length * 0.7, -length * 1.6))
	_light(viewport, Color(String(poster.get("rim2", "#FFFFFF"))).lerp(Color.WHITE, 0.5), 0.55, center, center + Vector3(length * 1.6, length * 0.5, -length * 1.2))
	_light(viewport, Color("AFC6FF"), 0.22, center, center + Vector3(-length * 0.6, -length * 0.4, length * 1.4))
	camera.force_update_transform()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	viewport.queue_free()
	await process_frame
	return image


func _light(parent: Node, color: Color, energy: float, target: Vector3, from: Vector3) -> DirectionalLight3D:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	parent.add_child(light)
	light.look_at_from_position(from, target, Vector3.UP)
	return light


func _bounds(car: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [car]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).visible:
			var mesh_node: MeshInstance3D = node
			var box: AABB = mesh_node.global_transform * mesh_node.get_aabb()
			merged = box if first else merged.merge(box)
			first = false
		for child: Node in node.get_children():
			stack.append(child)
	return merged if not first else AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
