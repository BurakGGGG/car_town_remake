class_name DecorThumbs
extends Node
## DEKOR KÜÇÜK RESİMLERİ — paletteki kartlar için, TEMBEL ve önbellekli.
##
## Araç galerisindeki kalıp (ui/hud/car_gallery.gd): istenen eşya kuyruğa girer, kare başına en
## çok THUMBS_PER_FRAME eşya kendi SubViewport'unda BİR KARE render edilir, görüntü statik
## önbelleğe alınır, gövde ve viewport serbest bırakılır. Yalnızca paletin GÖRÜNEN kartları
## ister; 70 eşyanın hepsi açılışta üretilmez. Başsız çalışmada hiç üretilmez.

signal ready_for(id: StringName)

const THUMB_SIZE: Vector2i = Vector2i(160, 110)
const THUMBS_PER_FRAME: int = 2
## Dünya kamerasıyla aynı bakış yönü (Main.tscn MainCamera): oyuncu eşyayı garajdaki gibi görür.
const VIEW_DIR: Vector3 = Vector3(0.6408563, 0.42261827, 0.6408563)

static var _cache: Dictionary = {}   # id → ImageTexture

var _queue: Array[StringName] = []
var _queued: Dictionary = {}
var _pumping: bool = false


static func cached(id: StringName) -> Texture2D:
	return _cache.get(id)


func request(id: StringName) -> void:
	if _cache.has(id) or _queued.has(id) or DisplayServer.get_name() == "headless":
		return
	_queued[id] = true
	_queue.append(id)
	if not _pumping:
		_pumping = true
		_pump.call_deferred()


func _pump() -> void:
	await get_tree().process_frame
	while not _queue.is_empty():
		if not is_inside_tree():
			_pumping = false
			return
		var batch: Array[StringName] = []
		while batch.size() < THUMBS_PER_FRAME and not _queue.is_empty():
			batch.append(_queue.pop_front())
		await _render(batch)
		for id: StringName in batch:
			_queued.erase(id)
	_pumping = false


func _render(ids: Array[StringName]) -> void:
	var jobs: Array[Dictionary] = []
	for id: StringName in ids:
		var body: Node3D = DecorBuilder.build_placeable(id)
		if body == null:
			continue
		var viewport: SubViewport = SubViewport.new()
		viewport.size = THUMB_SIZE
		viewport.transparent_bg = true
		viewport.own_world_3d = true
		viewport.msaa_3d = Viewport.MSAA_4X
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		var camera: Camera3D = Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		var env: Environment = Environment.new()
		env.background_mode = Environment.BG_CLEAR_COLOR
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color("D8CFBD")
		env.ambient_light_energy = 0.55
		camera.environment = env
		viewport.add_child(camera)
		var light: DirectionalLight3D = DirectionalLight3D.new()
		light.basis = Basis.looking_at(Vector3(-0.45, -1.0, -0.6).normalized(), Vector3.UP)
		light.light_color = Color("FFF3E0")
		light.light_energy = 1.05
		viewport.add_child(light)
		viewport.add_child(body)
		add_child(viewport)
		var size: Vector3 = DecorBuilder.local_size(id)
		var center: Vector3 = Vector3(0.0, size.y * 0.5, 0.0)
		if GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			center = Vector3(0.0, 0.0, size.z * 0.5)
		# Kadraj: izometrik bakışta eşyanın kapladığı yaklaşık alan (en + derinlik çaprazı, boy)
		var extent: float = maxf((size.x + size.z) * 0.72, size.y * 1.15)
		camera.size = maxf(extent, 0.05) * 1.08
		camera.position = center + VIEW_DIR * 8.0
		camera.basis = Basis.looking_at(-VIEW_DIR, Vector3.UP)
		camera.force_update_transform()
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		jobs.append({"id": id, "viewport": viewport})
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	for job: Dictionary in jobs:
		var viewport: SubViewport = job["viewport"]
		if not is_instance_valid(viewport):
			continue
		var image: Image = viewport.get_texture().get_image()
		if image and not image.is_empty():
			_cache[job["id"]] = ImageTexture.create_from_image(image)
			ready_for.emit(job["id"])
		viewport.queue_free()
