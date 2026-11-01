extends SceneTree
## HURDALIK KARTPOSTALI — 1. adım: restorasyon araçlarının TEMİZ hâli, kartpostal açısından (3/4 ön, alçak),
## saydam zeminde; ayrıca kademe manzaralarının (scenes/*.svg) pikselleri fotoğraf boyunda.
## Sonraki adım make_postcards.py bu dosyalardan eski, sararmış kartpostal fotoğrafını pişirir.
##
## Araç oyundaki restorasyon görünümüyle AYNI (RestorationDisplay: CarAppearance.get_for) — restorasyon araçları
## boyanamaz, kartpostaldaki renk oyuncunun alacağı renktir.
##
## Kullanım (PENCERELİ — başsızda çizim yok); hepsi birden: tools/postcards/build.sh
##   godot-4 --path . --display-driver x11 --disable-vsync --resolution 640x360 \
##     --script res://tools/postcards/render_cars.gd -- <çıktı_klasörü> [<araç_id> ...]

const SCENE_DIR: String = "res://tools/postcards/scenes/"
const SCENES: PackedStringArray = ["mahalle", "sahil", "ralli"]
## Fotoğraf boyu (make_postcards.py PW x PH ile aynı): manzara bu boyda, object-fit: cover gibi kırpılır.
const PHOTO_SIZE: Vector2i = Vector2i(1242, 702)
## Araç çizimi: iki kat büyük çizilip Python'da küçültülür (kenar yumuşatma).
const RENDER_SIZE: Vector2i = Vector2i(2400, 1560)
const FOV: float = 26.0
const YAW_DEG: float = 38.0     # önü +Z olan aracın sol önünden
const PITCH_DEG: float = 11.0

var _viewport: SubViewport
var _camera: Camera3D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_cars: çıktı klasörü verilmedi")
		quit(1)
		return
	var out: String = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(out)
	var wanted: PackedStringArray = args.slice(1)

	for scene_name: String in SCENES:
		_save_scene(scene_name, out)

	_build_stage()
	var done: int = 0
	for entry: Dictionary in RestorationCatalog.cars():
		var id: StringName = StringName(entry.get("id", ""))
		if not wanted.is_empty() and not wanted.has(String(id)):
			continue
		if not RestorationCatalog.has_model(id):
			print("ATLANDI (modeli yok) ", id)
			continue
		await _render_car(id, out)
		done += 1
	print("BİTTİ: %d araç" % done)
	quit(0)


## Manzara SVG'si fotoğraf boyunda: genişlik tutturulur, üst/alt eşit kırpılır (CSS object-fit: cover).
func _save_scene(scene_name: String, out: String) -> void:
	var image: Image = Image.new()
	var data: PackedByteArray = FileAccess.get_file_as_bytes(SCENE_DIR + scene_name + ".svg")
	if data.is_empty() or image.load_svg_from_buffer(data, float(PHOTO_SIZE.x) / 800.0) != OK:
		push_error("render_cars: manzara okunamadı: " + scene_name)
		return
	image.convert(Image.FORMAT_RGB8)
	var top: int = maxi((image.get_height() - PHOTO_SIZE.y) / 2, 0)
	image.get_region(Rect2i(0, top, PHOTO_SIZE.x, mini(PHOTO_SIZE.y, image.get_height()))).save_png(out + "scene_" + scene_name + ".png")
	print("MANZARA ", scene_name)


func _build_stage() -> void:
	_viewport = SubViewport.new()
	_viewport.size = RENDER_SIZE
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var env: WorldEnvironment = WorldEnvironment.new()
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("E4DCD2")
	environment.ambient_light_energy = 0.8
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = environment
	_viewport.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38.0, 30.0, 0.0)   # alçak, sıcak öğleden sonra güneşi
	sun.light_color = Color("FFE6C4")
	sun.light_energy = 1.35
	_viewport.add_child(sun)
	_camera = Camera3D.new()
	_camera.fov = FOV
	_viewport.add_child(_camera)
	_camera.current = true


func _render_car(id: StringName, out: String) -> void:
	var path: String = CarCatalog.scene_path(id)
	var scene: PackedScene = load(path) as PackedScene if path != "" else null
	if scene == null:
		print("ATLANDI (sahnesi yok) ", id)
		return
	var car: Node3D = scene.instantiate() as Node3D
	car.scale = Vector3.ONE * CarCatalog.model_scale(id)
	_viewport.add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(path))
	rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	for i: int in 3:
		await process_frame
	var box: AABB = _bounds(car)
	car.position -= Vector3(box.get_center().x, box.position.y, box.get_center().z)
	for i: int in 30:   # dokular / LOD otursun
		await process_frame
	box = _bounds(car)
	var center: Vector3 = box.get_center()
	var radius: float = box.size.length() * 0.5
	var yaw: float = deg_to_rad(YAW_DEG)
	var pitch: float = deg_to_rad(PITCH_DEG)
	var direction: Vector3 = Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	var distance: float = radius / tan(deg_to_rad(FOV) * 0.5) * 0.92
	_camera.position = center + direction * distance
	_camera.look_at(center, Vector3.UP)
	_camera.near = 0.05
	_camera.far = distance * 4.0
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	_viewport.get_texture().get_image().save_png(out + "car_" + String(id) + ".png")
	print("ARAÇ ", id)
	car.queue_free()
	await process_frame


static func _bounds(root_node: Node3D) -> AABB:
	var merged: AABB = AABB()
	var first: bool = true
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var box: AABB = mi.global_transform * mi.get_aabb()
		merged = box if first else merged.merge(box)
		first = false
	return merged
