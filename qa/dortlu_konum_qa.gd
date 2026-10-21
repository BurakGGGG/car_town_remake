extends SceneTree
## DÖRTLÜ KONUMU QA (HazardLights.corners): her trafik aracını dörtlüleri sürekli yanık olarak oyun kamerasının açısından
## önden ve arkadan çizer; iki temas sayfası (ön / arka) ve araç başına köşe kaynağı (lamba parçası / yedek) dökümü.
##   tools/qa_isolated.sh res://qa/dortlu_konum_qa.gd --display-driver x11 --resolution 1280x720 [-- <araç_id> ...]
## `-- yakin <araç_id> ...`: önden ve arkadan DİK (ortografik), model uzayı ızgarasıyla — lamba konumunu ölçmek için
## (CarPartMap "hazards"): ince çizgi 0,01, kalın 0,05; kırmızı dikey çizgi x = 0, kırmızı yatay y = 0,1.
## Çıktı: /home/burak/Projects/ct_shots/dortlu/konum_on.png, konum_arka.png (yakın: yakin_<araç>.png)

const OUT: String = "/home/burak/Projects/ct_shots/dortlu/"
const TILE: Vector2i = Vector2i(300, 210)
const COLUMNS: int = 6
## Oyun kamerasının açısı (Main.tscn MainCamera): güneydoğudan, ~25° yükseklik.
const CAMERA_BASIS: Basis = Basis(Vector3(0.70710677, 0.0, -0.70710677), Vector3(-0.29883623, 0.90630776, -0.29883623),
	Vector3(0.6408563, 0.42261827, 0.6408563))


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


## Yakın ölçüm: 1 birim = PX piksel, görüntü x ∈ [-HALF_W, HALF_W], y ∈ [0, HEIGHT].
const PX: float = 1600.0
const HALF_W: float = 0.26
const HEIGHT: float = 0.36


func _run() -> void:
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	if not wanted.is_empty() and wanted[0] == "yakin":
		await _close_ups(wanted.slice(1))
		quit()
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = TILE * 2
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.35)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	viewport.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 40.0, 0.0)
	viewport.add_child(sun)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.62
	viewport.add_child(camera)
	camera.global_transform = Transform3D(CAMERA_BASIS, CAMERA_BASIS.z * 6.0 + Vector3(0.0, 0.1, 0.0))
	camera.current = true
	var ids: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		if bool(entry["traffic"]) and (wanted.is_empty() or wanted.has(String(entry["id"]))):
			ids.append(entry["id"])
	var rows: int = ceili(float(ids.size()) / COLUMNS)
	var sheets: Array[Image] = [Image.create(TILE.x * COLUMNS, TILE.y * rows, false, Image.FORMAT_RGBA8),
		Image.create(TILE.x * COLUMNS, TILE.y * rows, false, Image.FORMAT_RGBA8)]
	for i: int in ids.size():
		var id: StringName = ids[i]
		var scene: PackedScene = load(CarCatalog.scene_path(id)) as PackedScene
		if scene == null:
			print("%s: sahne yok" % id)
			continue
		var holder: Node3D = Node3D.new()
		viewport.add_child(holder)
		var model: Node3D = scene.instantiate() as Node3D
		model.scale = Vector3.ONE * CarCatalog.model_scale(id)
		holder.add_child(model)
		var rig: CarRig = CarRig.new(model)
		rig.apply(CarAppearance.new())
		var lights: HazardLights = HazardLights.attach(model, rig, CarCatalog.scene_path(id))
		(lights.material_override as ShaderMaterial).set_shader_parameter(&"duty", 1.2)   # sürekli yanık
		lights.set_on(true)
		var head: int = rig.get_meshes(&"headlights").size()
		var tail: int = rig.get_meshes(&"taillights").size()
		print("%-22s far %d parça, stop %d parça · köşeler %s" % [id, head, tail, HazardLights.corners(model, rig)])
		for view: int in 2:
			# Ön: burun kameraya (sağa) bakar; arka: burun kameradan uzağa
			var dir: Vector3 = Vector3(0.94, 0.0, 0.34) if view == 0 else Vector3(-0.34, 0.0, -0.94)
			holder.rotation.y = atan2(dir.x, dir.z)
			for f: int in 6:
				await process_frame
			var image: Image = viewport.get_texture().get_image()
			image.resize(TILE.x, TILE.y, Image.INTERPOLATE_LANCZOS)
			image.convert(Image.FORMAT_RGBA8)
			sheets[view].blit_rect(image, Rect2i(Vector2i.ZERO, TILE), Vector2i((i % COLUMNS) * TILE.x, (i / COLUMNS) * TILE.y))
		holder.queue_free()
		await process_frame
	sheets[0].save_png(OUT + "konum_on.png")
	sheets[1].save_png(OUT + "konum_arka.png")
	print("sayfalar: %skonum_on.png, konum_arka.png (%d araç, sıra: %s)" % [OUT, ids.size(), ids])
	quit()


func _close_ups(ids: PackedStringArray) -> void:
	var size: Vector2i = Vector2i(int(HALF_W * 2.0 * PX), int(HEIGHT * PX))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = size
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.21, 0.23)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.8)
	viewport.add_child(env)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = HEIGHT
	viewport.add_child(camera)
	camera.current = true
	for id_text: String in ids:
		var id: StringName = StringName(id_text)
		var scene: PackedScene = load(CarCatalog.scene_path(id)) as PackedScene
		var model: Node3D = scene.instantiate() as Node3D   # model uzayı = dünya (ölçek 1)
		viewport.add_child(model)
		var rig: CarRig = CarRig.new(model)
		rig.apply(CarAppearance.new())
		var lights: HazardLights = HazardLights.attach(model, rig, CarCatalog.scene_path(id) + "#yakin")
		(lights.material_override as ShaderMaterial).set_shader_parameter(&"duty", 1.2)
		lights.set_on(true)
		var halves: Array[Image] = []
		for front: bool in [true, false]:
			var z: float = 3.0 if front else -3.0
			camera.global_transform = Transform3D(Basis.looking_at(Vector3(0.0, 0.0, -signf(z)), Vector3.UP),
				Vector3(0.0, HEIGHT * 0.5, z))
			for f: int in 6:
				await process_frame
			var image: Image = viewport.get_texture().get_image()
			image.convert(Image.FORMAT_RGBA8)
			_grid(image, not front)
			halves.append(image)
		var sheet: Image = Image.create(size.x * 2 + 8, size.y, false, Image.FORMAT_RGBA8)
		sheet.blit_rect(halves[0], Rect2i(Vector2i.ZERO, size), Vector2i.ZERO)
		sheet.blit_rect(halves[1], Rect2i(Vector2i.ZERO, size), Vector2i(size.x + 8, 0))
		sheet.save_png(OUT + "yakin_%s.png" % id)
		print("yakin_%s.png  köşeler %s" % [id, HazardLights.corners(model, rig)])
		model.queue_free()
		await process_frame


## Izgara: ince 0,01, kalın 0,05; x = 0 ve y = 0,1 kırmızı. Arka görünümde x ters (aracın solu sağda).
func _grid(image: Image, mirrored: bool) -> void:
	var w: int = image.get_width()
	var h: int = image.get_height()
	for k: int in range(-26, 27):
		var x: float = k * 0.01
		var px: int = int((x + HALF_W) * PX)
		if px < 0 or px >= w:
			continue
		var color: Color = Color(1, 0.2, 0.2, 0.9) if k == 0 else (Color(1, 1, 1, 0.55) if k % 5 == 0 else Color(1, 1, 1, 0.16))
		for py: int in h:
			image.set_pixel(px, py, image.get_pixel(px, py).blend(color))
	for k: int in range(0, 37):
		var py: int = h - 1 - int(k * 0.01 * PX)
		if py < 0 or py >= h:
			continue
		var color: Color = Color(1, 0.2, 0.2, 0.9) if k == 10 else (Color(1, 1, 1, 0.55) if k % 5 == 0 else Color(1, 1, 1, 0.16))
		for px: int in w:
			image.set_pixel(px, py, image.get_pixel(px, py).blend(color))
