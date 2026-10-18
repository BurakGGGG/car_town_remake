extends "res://tools/make_loading_art.gd"
## YÜKLEME EKRANI SLAYTLARI — Şahin'li garaj görselinin (make_loading_art.gd) kardeşleri. Aynı dil: oyunun izometrik
## açısı, kapalı ve dolu bir DİYORAMA (iki arka duvar / sınır, oyunun dekor eşyaları), karanlık zemin üstünde sıcak /
## soğuk ışık havuzları, görünür ışık huzmeleri, 2B katmanda parıltılar, üstte logo, altta sakin şerit.
## Yardımcılar (eşya, lamba, start ağacı, parıltı, katman) üst sınıftan gelir.
##   drag        gece start çizgisi: iki araç patinajda, egzoz alevi, far huzmeleri, tribün + projektörler
##   hurdalik    gün batımında hurdalık köşesi: üst üste hurdalar, vinçte asılı hurda, kaynak kıvılcımı, ateş varili,
##               ortada restore edilmiş parlak klasik ve paslı ikizi
##   showroom    gece lansman salonu: döner platformda süper spor, spot huzmeleri, cam duvar arkasında şehir ışıkları
##   kovalamaca  gece sokak köşesi: kayarak dönen araç, lastik dumanı, arkasında çakarlı polis, ıslak asfalt
## Kullanım (PENCERELİ):
##   godot-4 --path . --display-driver x11 --resolution 960x432 -s res://tools/make_loading_scenes.gd -- <sahne> [önizleme]
## Önizleme → ~/Projects/ct_shots/loading_art/<sahne>.png (1×); değilse ui/loading/slides/<sahne>.png (2× çizilip küçültülür).

const SLIDES_DIR: String = "res://ui/loading/slides/"
const SLIDE_PREVIEW_DIR: String = "/home/burak/Projects/ct_shots/loading_art/"
const SLIDES: Array[String] = ["drag", "hurdalik", "showroom", "kovalamaca"]
## Araç boyu: garajdaki liftli Şahin'le aynı ölçek (0,6 × 1,35).
const CAR_LEN: float = 0.81
const ASPHALT_TEXTURE: String = "res://race/art/asphalt_dark.png"

var _slide: String = ""
var _fxs: Array[DragFx] = []


func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg in SLIDES:
			_slide = arg
	if _slide == "":
		push_error("sahne: %s" % ", ".join(SLIDES))
		quit(1)
		return
	var preview: bool = OS.get_cmdline_user_args().has("önizleme")
	_scale = 1 if preview else 2
	_run_slide.call_deferred(preview)


func _run_slide(preview: bool) -> void:
	var size: Vector2i = FINAL_SIZE * _scale
	_viewport = SubViewport.new()
	_viewport.size = size
	_viewport.own_world_3d = true
	_viewport.transparent_bg = false
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.positional_shadow_atlas_size = 4096
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_world = Node3D.new()
	_viewport.add_child(_world)
	match _slide:
		"drag":
			_drag()
		"showroom":
			_showroom()
		"hurdalik":
			_junkyard()
		"kovalamaca":
			_chase()
	for i: int in 32:   # duman birikir, parçacıklar oturur
		await process_frame
	for fx: DragFx in _fxs:
		fx.flame(1.0)
	for i: int in 3:
		await process_frame
	_build_overlay(Vector2(size))
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	var image: Image = _viewport.get_texture().get_image()
	if _scale != 1:
		image.resize(FINAL_SIZE.x, FINAL_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var target: String
	if preview:
		DirAccess.make_dir_recursive_absolute(SLIDE_PREVIEW_DIR)
		target = SLIDE_PREVIEW_DIR + _slide + ".png"
	else:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLIDES_DIR))
		target = ProjectSettings.globalize_path(SLIDES_DIR + _slide + ".png")
	image.save_png(target)
	print("KAYDEDİLDİ ", target, " ", image.get_size())
	quit(0)


# --- Ortak kurulum -------------------------------------------------------------------------

func _env(background: Color, ambient: Color, energy: float, glow: float) -> void:
	var node: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = background
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = energy
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	e.glow_intensity = glow
	e.glow_bloom = 0.08
	node.environment = e
	_world.add_child(node)


## Oyunun izometrik açısı (garaj görseliyle aynı): `focus` ekranın ortası, `size` dikey görüş (birim).
func _iso_cam(focus: Vector3, size: float) -> void:
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(-30.0, 45.0, 0.0)
	camera.size = size
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.position = focus + camera.basis.z * 12.0
	camera.far = 40.0
	_world.add_child(camera)


func _dir_light(rotation_deg: Vector3, color: Color, energy: float, shadows: bool) -> void:
	var light: DirectionalLight3D = DirectionalLight3D.new()
	light.rotation_degrees = rotation_deg
	light.light_color = color
	light.light_energy = energy
	light.shadow_enabled = shadows
	_world.add_child(light)


func _omni_light(pos: Vector3, color: Color, energy: float, radius: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = pos
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.2
	_world.add_child(light)


func _spot_light(from: Vector3, to: Vector3, color: Color, energy: float, angle: float, shadows: bool = true) -> void:
	var spot: SpotLight3D = SpotLight3D.new()
	spot.light_color = color
	spot.light_energy = energy
	spot.spot_range = from.distance_to(to) * 1.6
	spot.spot_angle = angle
	spot.spot_attenuation = 0.7
	spot.shadow_enabled = shadows
	_world.add_child(spot)
	var up: Vector3 = Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.FORWARD
	spot.look_at_from_position(from, to, up)


## Görünür ışık huzmesi: `from` (dar, parlak) → `to` (geniş, sönük) saydam koni (asılı lambanın konisiyle aynı malzeme).
func _beam(from: Vector3, to: Vector3, r_from: float, r_to: float, color: Color, alpha: float) -> void:
	var axis: Vector3 = from - to
	var length: float = axis.length()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = r_from
	mesh.bottom_radius = r_to
	mesh.height = length
	mesh.cap_top = false
	mesh.cap_bottom = false
	mesh.radial_segments = 28
	var beam: MeshInstance3D = MeshInstance3D.new()
	beam.mesh = mesh
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = _beam_fade_texture()
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	beam.material_override = m
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y: Vector3 = axis / length
	var helper: Vector3 = Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	beam.transform = Transform3D(Basis(x, y, z), (from + to) * 0.5)
	_world.add_child(beam)


## Aracı fabrika görünümüyle kurar ve yerine koyar: `yaw` 0 = burun +Z.
func _place_car(id: StringName, pos: Vector3, yaw: float, length: float = CAR_LEN) -> Node3D:
	var car: Node3D = _car(id)
	car.scale = Vector3.ONE * length * CarCatalog.model_scale(id)
	car.position = pos
	car.rotation_degrees = Vector3(0.0, yaw, 0.0)
	car.set_meta(&"zemin_esyasi", true)
	_world.add_child(car)
	return car


## Far noktaları (dünya): burun ucunun biraz gerisi, yanlarda.
func _headlights(car: Node3D, length: float = CAR_LEN) -> Array[Vector3]:
	var forward: Vector3 = car.global_basis.z.normalized()
	var side: Vector3 = car.global_basis.x.normalized()
	var nose: Vector3 = car.global_position + forward * length * 0.47 + Vector3(0.0, length * 0.085, 0.0)
	return [nose + side * length * 0.16, nose - side * length * 0.16]


## Aracın albedo dokusunu yalnız bu çizim için değiştirir (ör. polis kaplamasındaki yerel yazılar silinmiş kopya:
## tools/debadge/debadge.py copy). Oyun dokusuna dokunulmaz. Dosya yoksa araç olduğu gibi kalır.
func _swap_albedo(car: Node3D, image_path: String) -> void:
	if not FileAccess.file_exists(image_path):
		print("doku kopyası yok: ", image_path)
		return
	var texture: ImageTexture = ImageTexture.create_from_image(Image.load_from_file(image_path))
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		var materials: Array[Material] = [mi.material_override]
		for i: int in mi.get_surface_override_material_count():
			materials.append(mi.get_surface_override_material(i))
		if mi.mesh:
			for i: int in mi.mesh.get_surface_count():
				materials.append(mi.mesh.surface_get_material(i))
		for material: Material in materials:
			if material is StandardMaterial3D and (material as StandardMaterial3D).albedo_texture != null:
				(material as StandardMaterial3D).albedo_texture = texture
			elif material is ShaderMaterial and (material as ShaderMaterial).get_shader_parameter(&"albedo_tex") != null:
				(material as ShaderMaterial).set_shader_parameter(&"albedo_tex", texture)


func _alpha_mat(color: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(color, 0.9)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _glow_mat(color: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = _mat(color, 0.4)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


func _text(text: String, pos: Vector3, rotation_deg: Vector3, pixel: float, color: Color) -> Label3D:
	var label: Label3D = Label3D.new()
	label.text = text
	label.position = pos
	label.rotation_degrees = rotation_deg
	label.pixel_size = pixel
	label.font_size = 64
	label.modulate = color
	label.outline_size = 0
	label.double_sided = false
	label.shaded = false
	var bold: FontVariation = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 1.0
	label.font = bold
	_world.add_child(label)
	return label


# --- DRAG: gece start çizgisi -----------------------------------------------------------------

const DRAG_NEAR: StringName = &"chevrolet_camaro"    # CROSSBOW BRUTE SS
const DRAG_FAR: StringName = &"ferrari_488_pista"    # FURIA CIRCUITO 19
const NIGHT_BG: Color = Color("0B0E15")
const FLOOD: Color = Color("DCE7FF")


func _drag() -> void:
	_env(NIGHT_BG, Color("56637E"), 0.7, 0.7)
	_iso_cam(Vector3(0.2, 0.2, 0.02), 1.42)
	_dir_light(Vector3(-55.0, -35.0, 0.0), Color("8DA0C8"), 0.28, true)
	# Asfalt + şerit çizgileri: araçlar +X'e (ekranda sağ aşağı) bakar
	var asphalt: StandardMaterial3D = _mat(Color("3A3E44"), 0.82)
	if ResourceLoader.exists(ASPHALT_TEXTURE):
		asphalt.albedo_texture = load(ASPHALT_TEXTURE)
		asphalt.uv1_scale = Vector3(5.0, 5.0, 1.0)
	_box(Vector3(6.0, 0.05, 6.0), Vector3(0.0, -0.025, 0.0), asphalt)
	var paint: StandardMaterial3D = _mat(Color("ECEAE2"), 0.6)
	var amber_paint: StandardMaterial3D = _mat(AMBER, 0.6)
	for z: float in [-0.52, 0.07, 0.66]:
		_box(Vector3(4.2, 0.006, 0.022), Vector3(0.6, 0.003, z), paint)
	_box(Vector3(0.035, 0.007, 1.2), Vector3(0.66, 0.0035, 0.07), paint)          # çıkış çizgisi
	_box(Vector3(0.02, 0.007, 1.2), Vector3(0.56, 0.0035, 0.07), amber_paint)     # sahne çizgisi
	# Çıkış çizgisinin önünde iki sıra dama şeridi (beyaz zemin + siyah kareler)
	_box(Vector3(0.12, 0.006, 1.18), Vector3(0.77, 0.0032, 0.07), _mat(Color("ECEAE2"), 0.6))
	var ink: StandardMaterial3D = _mat(Color("15161A"), 0.7)
	for row: int in 2:
		for i: int in 20:
			if (i + row) % 2 == 0:
				_box(Vector3(0.06, 0.007, 0.059), Vector3(0.74 + float(row) * 0.06, 0.0036, -0.49 + float(i) * 0.059), ink)
	_text("START", Vector3(0.98, 0.006, -0.22), Vector3(-90.0, 90.0, 0.0), 0.0042, Color(0.95, 0.94, 0.9, 0.85))
	# Arkada lastik izleri (yanık kauçuk)
	var rubber: StandardMaterial3D = _alpha_mat(Color(0.02, 0.02, 0.025, 0.55))
	for lane: float in [-0.22, 0.37]:
		for side: float in [-0.13, 0.13]:
			_box(Vector3(1.6, 0.004, 0.055), Vector3(-0.95, 0.006, lane + side), rubber)
	# Sol arka sınır: beton bariyer + üstünde tel çit + sponsor panoları
	var concrete: StandardMaterial3D = _mat(Color("8E8B84"), 0.9)
	_box(Vector3(0.14, 0.24, 6.0), Vector3(-1.22, 0.12, 0.0), concrete)
	_box(Vector3(0.16, 0.03, 6.0), Vector3(-1.22, 0.255, 0.0), _mat(Color("D8D4CA"), 0.8))
	var post: StandardMaterial3D = _mat(Color("5B6168"), 0.4, 0.7)
	for i: int in 8:
		_box(Vector3(0.025, 0.55, 0.025), Vector3(-1.25, 0.52, -1.3 + float(i) * 0.45), post)
	_box(Vector3(0.02, 0.02, 6.0), Vector3(-1.25, 0.79, 0.0), post)
	_box(Vector3(0.005, 0.52, 6.0), Vector3(-1.25, 0.53, 0.0), _alpha_mat(Color(0.75, 0.8, 0.86, 0.12)))
	var sponsors: Array = [["NITRO", Color("17181C"), Color("5FD36A")], ["DRAG CUP", Color("D93A2B"), Color.WHITE],
		["AUTO YARD", Color("1F55D9"), Color("FFC233")], ["300 M", Color("FFC233"), Color("17181C")]]
	for i: int in sponsors.size():
		var z: float = -0.9 + float(i) * 0.55   # son ikisi logonun solunda tam görünür
		var s: Array = sponsors[i]
		_box(Vector3(0.012, 0.17, 0.46), Vector3(-1.145, 0.12, z), _mat(s[1], 0.5))
		_text(s[0], Vector3(-1.137, 0.12, z), Vector3(0.0, 90.0, 0.0), 0.0011, s[2])
	# Sağ arka: tribün (basamaklar + seyirci) ve çatı
	var stand: StandardMaterial3D = _mat(Color("5E6168"), 0.85)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var shirts: Array[Color] = [Color("E2483D"), Color("F5BE4C"), Color("3E8ED0"), Color("F3E8CF"), Color("5FD36A"),
		Color("9A5BD3"), Color("2F3236"), Color("E87A2E")]
	for row: int in 5:
		var y: float = 0.1 + float(row) * 0.13
		var z: float = -1.32 - float(row) * 0.2
		_box(Vector3(3.6, 0.1, 0.22), Vector3(0.15, y - 0.05, z), stand)
		_box(Vector3(3.6, y, 0.04), Vector3(0.15, y * 0.5, z + 0.11), _mat(Color("44474D"), 0.9))
		var x: float = -1.2
		while x < 1.9:
			x += rng.randf_range(0.07, 0.13)
			if rng.randf() < 0.12:
				continue
			var shirt: Color = shirts[rng.randi() % shirts.size()]
			_box(Vector3(0.045, 0.07, 0.04), Vector3(x, y + 0.035, z - 0.02), _mat(shirt, 0.8))
			_box(Vector3(0.03, 0.03, 0.03), Vector3(x, y + 0.087, z - 0.02), _mat(Color("C99A72"), 0.8))
	_box(Vector3(3.8, 0.04, 1.4), Vector3(0.15, 1.02, -1.9), _mat(Color("2A2D33"), 0.7))     # çatı
	for x: float in [-1.1, 0.15, 1.4]:
		_box(Vector3(0.04, 1.0, 0.04), Vector3(x, 0.5, -1.25), post)
	# Çatı kenarında projektör bankları: aşağı, araçlara huzme
	for x: float in [-0.55, 0.85]:
		var head: Vector3 = Vector3(x, 0.98, -1.22)
		_box(Vector3(0.3, 0.1, 0.06), head, _mat(Color("2B2F35"), 0.5))
		for k: int in 3:
			var lamp: Vector3 = head + Vector3(-0.1 + float(k) * 0.1, 0.0, 0.035)
			_box(Vector3(0.07, 0.06, 0.01), lamp, _glow_mat(FLOOD, 3.0))
			_glows.append([lamp, 0.2, Color(FLOOD, 0.8)])
		var target: Vector3 = Vector3(x * 0.4 + 0.05, 0.0, 0.05)
		_beam(head + Vector3(0.0, -0.03, 0.05), target, 0.12, 0.55, FLOOD, 0.13)
		_spot_light(head + Vector3(0.0, 0.0, 0.1), target, FLOOD, 2.4, 34.0)
	# Tribün önünde beton bariyer + tel çit, çatıda flama dizisi
	for i: int in 9:   # alçak beton bariyer, üstünde kırmızı / beyaz şerit
		_box(Vector3(0.37, 0.09, 0.07), Vector3(-0.85 + float(i) * 0.38, 0.045, -0.98), _mat(Color("8E8B84"), 0.9))
		_box(Vector3(0.37, 0.02, 0.072), Vector3(-0.85 + float(i) * 0.38, 0.1, -0.98), _mat(Color("D94A3D") if i % 2 == 0 else Color("ECEAE2"), 0.8))
	var flag_colors: Array[Color] = [Color("E2483D"), Color("F5BE4C"), Color("3E8ED0"), Color("F3E8CF")]
	for i: int in 22:
		var fx_: float = -1.15 + float(i) * 0.15
		var flag: MeshInstance3D = _box(Vector3(0.06, 0.07, 0.004), Vector3(fx_, 0.96 - 0.03 * sin(float(i % 4) * 0.8), -1.21),
			_mat(flag_colors[i % flag_colors.size()], 0.8))
		flag.rotation_degrees = Vector3(0.0, 0.0, 45.0)
	# Pist kenarı: mesafe panosu, hakem, fotoğrafçı, ışık kulesi
	_box(Vector3(0.025, 0.42, 0.025), Vector3(1.45, 0.21, -0.72), _mat(Color("5B6168"), 0.4, 0.7))
	_box(Vector3(0.012, 0.13, 0.26), Vector3(1.45, 0.42, -0.72), _mat(Color("F3E8CF"), 0.6))
	_text("60 FT", Vector3(1.458, 0.42, -0.72), Vector3(0.0, 90.0, 0.0), 0.0014, Color("17181C"))
	_decor(&"mechanic", Vector3(1.08, 0.0, -0.84), -45.0, 1.35)
	_decor(&"tyre_wall", Vector3(1.6, 0.0, 0.95), 0.0, 1.3)
	_decor(&"cooler", Vector3(-0.98, 0.0, 0.25), 90.0, 1.3)
	_decor(&"barrel_rack", Vector3(-1.0, 0.0, -0.32), 90.0, 1.25)
	# Start ağacı (iki şeridin ortasında, çizginin önünde) ve çevre eşyaları
	_start_tree(Vector3(0.78, 0.0, -0.74), 0.62, 20.0)
	_decor(&"tyre_wall", Vector3(-1.02, 0.0, 1.0), 90.0, 1.3)
	_decor(&"traffic_drums", Vector3(1.55, 0.0, -0.75), 0.0, 1.2)
	_decor(&"traffic_cones", Vector3(1.4, 0.0, 0.95), 30.0, 1.2)
	_wall(&"checkered_flags", Vector3(-1.15, 0.62, 0.55), 90.0, 1.3)
	# Ön sol: pit köşesi (tamirci, lastikler, alet arabası, bidonlar)
	_decor(&"mechanic", Vector3(-0.42, 0.0, 0.98), 45.0, 1.35)
	_decor(&"tyre_pile", Vector3(-0.82, 0.0, 0.62), 0.0, 1.3)
	_decor(&"tool_trolley", Vector3(-0.75, 0.0, 1.05), 90.0, 1.3)
	_decor(&"jerry_cans", Vector3(-0.15, 0.0, 1.12), 0.0, 1.25)
	# Araçlar: iki şeritte burun buruna, patinaj dumanı + egzoz alevi, far huzmeleri
	for spec: Array in [[DRAG_FAR, -0.22], [DRAG_NEAR, 0.37]]:
		var car: Node3D = _place_car(spec[0], Vector3(0.12, 0.0, float(spec[1])), 90.0)
		var fx: DragFx = DragFx.new(CAR_LEN)
		_world.add_child(fx)
		fx.follow(car)
		fx.set_smoke(0.0)   # DragFx dumanı tek karelik çizimde gri / siyah leke çiziyordu: yerine 2B pus (aşağıda)
		var rear: Vector3 = car.global_position - car.global_basis.z.normalized() * CAR_LEN * 0.55
		for puff: Array in [[Vector3(0.0, 0.08, 0.0), 0.75, 0.24], [Vector3(-0.18, 0.2, -0.05), 0.65, 0.2],
				[Vector3(-0.35, 0.3, 0.08), 0.6, 0.15], [Vector3(-0.1, 0.38, -0.12), 0.5, 0.12]]:
			_glows.append([rear + (puff[0] as Vector3), puff[1], Color(0.86, 0.88, 0.95, puff[2])])
		fx.position -= car.global_basis.z.normalized() * CAR_LEN * 0.3   # duman aracın gerisinde birikir (aradaki boşluğa değil)
		for particles: Node in fx.find_children("*", "CPUParticles3D", true, false):
			(particles as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF   # spot gölgesi siyah top yapıyordu
		_fxs.append(fx)
		for lamp: Vector3 in _headlights(car):
			_glows.append([lamp, 0.16, Color(1.0, 0.97, 0.88, 0.95)])
			_beam(lamp + Vector3(0.02, 0.0, 0.0), lamp + Vector3(1.4, -0.07, 0.0), 0.025, 0.32, Color("FFF4DC"), 0.09)
		_spot_light(car.global_position + Vector3(0.45, 0.07, 0.0), car.global_position + Vector3(2.0, 0.0, 0.0),
			Color("FFF1D6"), 1.4, 28.0, false)
	# Ağacın yeşil ışığı zemine ve araçların burnuna vurur
	_omni_light(Vector3(0.78, 0.5, -0.6), Color("5FD36A"), 0.9, 0.9)


# --- SHOWROOM: gece lansman salonu --------------------------------------------------------------

const SHOW_HERO: StringName = &"lambo_huracan"        # BULL MONSOON (döner platformda)
const SHOW_SIDE: Array[Array] = [                     # [araç, konum, yön]
	[&"porsche_gt3", Vector3(-0.92, 0.0, 0.52), 75.0],      # STALLION RING 18 (solda)
	[&"mercedes_cls", Vector3(0.95, 0.0, -0.62), 15.0],     # STERN COUPÉ 350 (sağda)
]
const SHOW_WARM: Color = Color("FFD9A0")
const SHOW_COOL: Color = Color("9CC4FF")


func _showroom() -> void:
	_env(Color("0C0E14"), Color("5A6378"), 0.62, 0.75)
	_iso_cam(Vector3(0.05, 0.3, -0.02), 1.72)
	_dir_light(Vector3(-60.0, -30.0, 0.0), Color("A9B8CC"), 0.18, true)
	# Parlak siyah zemin (yansıma hissi: düşük pürüz, hafif metalik) + ince derz
	var floor_mat: StandardMaterial3D = _mat(Color("34383F"), 0.12, 0.45)
	floor_mat.albedo_texture = _tile_texture()
	floor_mat.uv1_scale = Vector3(5.0, 5.0, 1.0)
	_box(Vector3(6.0, 0.05, 6.0), Vector3(0.0, -0.025, 0.0), floor_mat)
	# Sol arka duvar: koyu panel, altın şerit, büyük tabela
	var wall: StandardMaterial3D = _mat(Color("22252C"), 0.7)
	_box(Vector3(0.08, 1.4, 6.0), Vector3(-WALL - 0.04, 0.7, 0.0), wall)
	_box(Vector3(0.02, 0.025, 6.0), Vector3(-WALL + 0.005, 0.2, 0.0), _glow_mat(AMBER, 1.6))
	_box(Vector3(0.02, 0.025, 6.0), Vector3(-WALL + 0.005, 1.05, 0.0), _glow_mat(AMBER, 1.6))
	_text("SHOWROOM", Vector3(-WALL + 0.012, 0.52, 0.72), Vector3(0.0, 90.0, 0.0), 0.0022, Color("F3E8CF"))
	_text("NEW ARRIVALS", Vector3(-WALL + 0.012, 0.42, 0.72), Vector3(0.0, 90.0, 0.0), 0.0012, AMBER)
	# Sağ arka duvar: cam cephe (çerçeve + saydam cam), arkasında gece şehri ışıkları
	_box(Vector3(6.0, 0.1, 0.08), Vector3(0.0, 0.05, -WALL - 0.04), wall)
	_box(Vector3(6.0, 0.08, 0.08), Vector3(0.0, 1.32, -WALL - 0.04), wall)
	var frame: StandardMaterial3D = _mat(Color("15171B"), 0.4, 0.6)
	for i: int in 7:
		_box(Vector3(0.035, 1.3, 0.05), Vector3(-1.2 + float(i) * 0.48, 0.68, -WALL - 0.03), frame)
	var glass: StandardMaterial3D = _alpha_mat(Color(0.55, 0.7, 0.9, 0.12))
	glass.roughness = 0.05
	glass.metallic = 0.5
	_box(Vector3(6.0, 1.2, 0.01), Vector3(0.0, 0.68, -WALL - 0.02), glass)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	for i: int in 9:   # karşı binalar: koyu kütleler, sarı / mavi pencereler
		var bx: float = -1.4 + float(i) * 0.42 + rng.randf_range(-0.05, 0.05)
		var bh: float = rng.randf_range(0.7, 1.5)
		_box(Vector3(0.36, bh, 0.3), Vector3(bx, bh * 0.5, -WALL - 1.1), _mat(Color("12151D"), 0.9))
		for wy: int in int(bh / 0.11):
			for wx: int in 3:
				if rng.randf() < 0.45:
					continue
				var c: Color = Color("FFC97A") if rng.randf() < 0.7 else Color("8FB8FF")
				_box(Vector3(0.05, 0.04, 0.005), Vector3(bx - 0.1 + float(wx) * 0.1, 0.08 + float(wy) * 0.11, -WALL - 0.948),
					_glow_mat(c, 1.4))
	# Döner platform: koyu disk, ışıklı kenar halkası, altın üst çizgi
	var plat: Vector3 = Vector3(0.1, 0.0, 0.15)
	var disc: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = 0.62
	cyl.bottom_radius = 0.64
	cyl.height = 0.06
	cyl.radial_segments = 64
	disc.mesh = cyl
	disc.material_override = _mat(Color("2A2D33"), 0.25, 0.5)
	disc.position = plat + Vector3(0.0, 0.03, 0.0)
	_world.add_child(disc)
	var ring: MeshInstance3D = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 0.6
	torus.outer_radius = 0.635
	torus.rings = 64
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _glow_mat(Color("6FB2FF"), 3.0)
	ring.position = plat + Vector3(0.0, 0.035, 0.0)
	_world.add_child(ring)
	var hero: Node3D = _place_car(SHOW_HERO, plat + Vector3(0.0, 0.06, 0.0), 35.0, 0.86)
	# Üstten iki spot: platforma sıcak + soğuk, görünür huzmeler
	for spec: Array in [[Vector3(-0.35, 1.5, 0.6), SHOW_WARM, 2.6], [Vector3(0.55, 1.5, -0.25), SHOW_COOL, 1.8]]:
		var at: Vector3 = spec[0]
		_box(Vector3(0.1, 0.08, 0.1), at, _mat(Color("1B1D22"), 0.5))
		_glows.append([at + Vector3(0.0, -0.05, 0.0), 0.22, Color(spec[1], 0.9)])
		_beam(at + Vector3(0.0, -0.05, 0.0), plat + Vector3(0.0, 0.05, 0.0), 0.05, 0.62, spec[1], 0.09)
		_spot_light(at, plat, spec[1], spec[2], 26.0)
	_glows.append([plat + Vector3(0.0, 0.04, 0.0), 1.5, Color(0.43, 0.7, 1.0, 0.18)])   # halka ışıması
	for lamp: Vector3 in _headlights(hero, 0.86):
		_glows.append([lamp, 0.13, Color(1.0, 0.97, 0.9, 0.9)])
	# Yan sergi araçları: kendi küçük spotları, kadife iplik direkleri
	for spec: Array in SHOW_SIDE:
		var at: Vector3 = spec[1]
		# Alçak sergi kaidesi: koyu kare, ışıklı kenar
		_box(Vector3(0.82, 0.03, 0.82), at + Vector3(0.0, 0.015, 0.0), _mat(Color("22252B"), 0.3, 0.5)).rotation_degrees = Vector3(0.0, float(spec[2]), 0.0)
		var edge: MeshInstance3D = _box(Vector3(0.84, 0.008, 0.84), at + Vector3(0.0, 0.032, 0.0), _glow_mat(AMBER, 1.6))
		edge.rotation_degrees = Vector3(0.0, float(spec[2]), 0.0)
		edge.scale = Vector3(1.0, 1.0, 1.0)
		_box(Vector3(0.8, 0.01, 0.8), at + Vector3(0.0, 0.036, 0.0), _mat(Color("22252B"), 0.3, 0.5)).rotation_degrees = Vector3(0.0, float(spec[2]), 0.0)
		var car: Node3D = _place_car(spec[0], at + Vector3(0.0, 0.04, 0.0), spec[2], 0.72)
		_spot_light(car.position + Vector3(0.0, 1.3, 0.2), car.position, SHOW_WARM, 1.4, 30.0)
		for lamp: Vector3 in _headlights(car, 0.72):
			_glows.append([lamp, 0.1, Color(1.0, 0.97, 0.9, 0.85)])
	# Platformun çevresinde kadife iplik: altın direkler, kırmızı halat
	var gold: StandardMaterial3D = _mat(Color("D9A93E"), 0.3, 0.8)
	var velvet: StandardMaterial3D = _mat(Color("A3182A"), 0.7)
	var posts: Array[Vector3] = []
	for i: int in 7:   # yalnız kameraya bakan yarım çember (yan kaidelerin üstünden geçmesin)
		var a: float = deg_to_rad(-35.0 + float(i) * 26.0)
		posts.append(plat + Vector3(cos(a), 0.0, sin(a)) * 0.74)
	for i: int in posts.size():
		_box(Vector3(0.022, 0.2, 0.022), posts[i] + Vector3(0.0, 0.1, 0.0), gold)
		_box(Vector3(0.05, 0.012, 0.05), posts[i] + Vector3(0.0, 0.006, 0.0), gold)
		if i > 0:
			var mid: Vector3 = (posts[i] + posts[i - 1]) * 0.5 + Vector3(0.0, 0.16, 0.0)
			var rope: MeshInstance3D = _box(Vector3(posts[i].distance_to(posts[i - 1]), 0.012, 0.012), mid, velvet)
			rope.look_at_from_position(mid, mid + (posts[i] - posts[i - 1]).normalized().cross(Vector3.UP), Vector3.UP)
	# Salon eşyaları: lounge köşesi, şampanya barı, ödül vitrini, bitkiler, zemin LED şeritleri
	_decor(&"lux_velvet_lounge", Vector3(1.2, 0.0, 0.0), -45.0, 1.1)
	_decor(&"coffee_table", Vector3(0.95, 0.0, 0.25), 0.0, 1.1)
	_decor(&"lux_champagne_bar", Vector3(-0.98, 0.0, 0.0), 90.0, 1.05)
	_decor(&"lux_gold_palm", Vector3(-1.02, 0.0, 1.15), 0.0, 0.85)
	_decor(&"lux_bonsai", Vector3(1.45, 0.0, -0.95), 0.0, 1.1)
	_decor(&"lux_crystal_lamp", Vector3(-0.98, 0.0, -0.6), 0.0, 1.0)
	_decor(&"lux_gold_car_statue", Vector3(-0.25, 0.0, 1.05), 45.0, 0.9)
	_decor(&"potted_plant", Vector3(1.5, 0.0, 0.45), 0.0, 1.2)
	for i: int in 5:   # cam cephe dibinde ışık şeridi + zeminde platforma uzanan çizgiler
		_box(Vector3(0.006, 0.004, 1.1), Vector3(-0.55 + float(i) * 0.3, 0.003, 0.95), _glow_mat(Color("6FB2FF"), 1.2))
	_box(Vector3(6.0, 0.01, 0.02), Vector3(0.0, 0.006, -WALL + 0.06), _glow_mat(Color("6FB2FF"), 1.1))
	_wall(&"lux_crystal_sconces", Vector3(-WALL, 0.75, -0.6), 90.0, 1.3)
	_wall(&"lux_crystal_sconces", Vector3(-WALL, 0.75, 1.0), 90.0, 1.3)
	_hanging_lamp(Vector3(0.95, 1.4, -0.6), 0.6)
	_wall(&"neon_car", Vector3(-WALL, 0.72, 0.15), 90.0, 1.4)
	_wall(&"lux_neon_crown", Vector3(-WALL, 0.78, -0.55), 90.0, 1.3)
	_confetti(plat)


## Lansman konfetisi: platformun üstünde havada süzülen ve yere dağılmış küçük renkli pullar (sabit tohum: her
## çizimde aynı). Işıksız malzeme: karanlık salonda da renkli okunur.
func _confetti(center: Vector3) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 23
	var colors: Array[Color] = [AMBER, Color("FFFFFF"), Color("6FB2FF"), Color("FF5A7A"), Color("7CF0A0")]
	var materials: Array[StandardMaterial3D] = []
	for c: Color in colors:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		materials.append(m)
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.028, 0.014)
	for i: int in 220:
		var piece: MeshInstance3D = MeshInstance3D.new()
		piece.mesh = quad
		piece.material_override = materials[rng.randi() % materials.size()]
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var airborne: bool = i < 130
		var r: float = rng.randf_range(0.0, 1.0 if airborne else 1.25)
		var a: float = rng.randf() * TAU
		var y: float = rng.randf_range(0.15, 1.25) if airborne else 0.004
		piece.position = center + Vector3(cos(a) * r, y, sin(a) * r)
		piece.rotation = Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU) if airborne \
			else Vector3(-PI * 0.5, rng.randf() * TAU, 0.0)
		_world.add_child(piece)


# --- HURDALIK: gün batımında hurda köşesi -----------------------------------------------------

const YARD_HERO: StringName = &"ford_mustang_1967"       # FORGE WILD PONY 67 (restore edilmiş)
const YARD_WRECK_DIR: String = "res://assets/world/junk_wrecks/"
const SUNSET: Color = Color("FF9A4D")
const FIRE: Color = Color("FF7A2A")


## Hurdalık enkazı (köşe renkli glb, ışığı Blender'da pişmiş): burada ışıklı malzemeyle (köşe rengi = albedo) kurulur,
## sahnenin gün batımı ışığını da alsın. `length` = aracın boyu (birim).
func _wreck(id: StringName, pos: Vector3, rotation_deg: Vector3, length: float) -> Node3D:
	var path: String = YARD_WRECK_DIR + String(id) + ".glb"
	if not ResourceLoader.exists(path):
		print("enkaz yok: ", id)
		return null
	var model: Node3D = (load(path) as PackedScene).instantiate()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node
		mi.material_override = material
		var b: AABB = mi.transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var holder: Node3D = Node3D.new()
	holder.position = pos
	holder.rotation_degrees = rotation_deg
	_world.add_child(holder)
	holder.add_child(model)
	var longest: float = maxf(box.size.x, box.size.z)
	model.scale = Vector3.ONE * (length / longest)
	model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * model.scale.x
	holder.set_meta(&"zemin_esyasi", true)
	return holder


func _junkyard() -> void:
	_env(Color("1A1418"), Color("8A6E78"), 0.72, 0.7)
	_iso_cam(Vector3(0.1, 0.3, -0.05), 1.45)
	# Gün batımı: alçak turuncu güneş soldan (kepenk / çit arkasından), uzun gölgeler
	_dir_light(Vector3(-18.0, -112.0, 0.0), SUNSET, 1.9, true)
	_dir_light(Vector3(-50.0, 40.0, 0.0), Color("7F88C8"), 0.22, false)
	# Zemin: tozlu toprak + yağ lekeleri
	var dirt: StandardMaterial3D = _mat(Color("6E5A44"), 0.95)
	if ResourceLoader.exists(ASPHALT_TEXTURE):
		dirt.albedo_texture = load(ASPHALT_TEXTURE)
		dirt.uv1_scale = Vector3(3.0, 3.0, 1.0)
	_box(Vector3(6.0, 0.05, 6.0), Vector3(0.0, -0.025, 0.0), dirt)
	var stain: StandardMaterial3D = _alpha_mat(Color(0.08, 0.06, 0.05, 0.5))
	for spec: Array in [[Vector3(-0.3, 0.003, 0.4), 0.35], [Vector3(0.5, 0.003, -0.3), 0.25], [Vector3(-0.8, 0.003, -0.5), 0.3]]:
		var disc: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = spec[1]
		cyl.bottom_radius = spec[1]
		cyl.height = 0.002
		disc.mesh = cyl
		disc.material_override = stain
		disc.position = spec[0]
		_world.add_child(disc)
	# Sol arka sınır: oluklu sac çit (paslı tonlar) + HURDALIK tabelası
	var tones: Array[Color] = [Color("7A4A30"), Color("5E6670"), Color("8A5A38"), Color("4E5560"), Color("6B3E2A")]
	for i: int in 16:
		var z: float = -1.5 + float(i) * 0.2
		_box(Vector3(0.03, 0.75 + 0.06 * float(i % 3), 0.2), Vector3(-WALL - 0.02, 0.38, z), _mat(tones[i % tones.size()], 0.85, 0.3))
	_box(Vector3(0.04, 0.2, 0.9), Vector3(-WALL + 0.02, 0.62, 0.55), _mat(Color("F3E8CF"), 0.7))
	_text("JUNKYARD", Vector3(-WALL + 0.045, 0.64, 0.55), Vector3(0.0, 90.0, 0.0), 0.0019, Color("7A2A20"))
	_text("PARTS · SALVAGE", Vector3(-WALL + 0.045, 0.56, 0.55), Vector3(0.0, 90.0, 0.0), 0.0009, Color("2F3236"))
	for k: int in 9:   # tabelanın ampul dizisi
		var bulb: Vector3 = Vector3(-WALL + 0.045, 0.73, 0.15 + float(k) * 0.1)
		_glows.append([bulb, 0.06, Color(1.0, 0.85, 0.5, 0.9)])
	# Sağ arka: üst üste hurda yığını (enkazlar, eğik)
	_wreck(&"chevrolet_bel_air_1956", Vector3(0.1, 0.0, -1.0), Vector3(0.0, 12.0, 0.0), 0.85)
	_wreck(&"vw_beetle_1967", Vector3(0.12, 0.2, -1.02), Vector3(4.0, -18.0, 6.0), 0.62)
	_wreck(&"fiat_500_1965", Vector3(0.6, 0.0, -1.05), Vector3(0.0, 40.0, 0.0), 0.5)
	_wreck(&"mercedes_w123", Vector3(1.05, 0.0, -0.95), Vector3(0.0, -10.0, 0.0), 0.82)
	_wreck(&"anadol_a1", Vector3(1.0, 0.21, -0.98), Vector3(-5.0, 25.0, -4.0), 0.7)
	_wreck(&"vw_t1_bus", Vector3(-0.85, 0.0, -0.95), Vector3(0.0, 70.0, 0.0), 0.8)
	# Gün batımı pusu: hurda yığınının arkasından sıcak ışıma
	_glows.append([Vector3(1.3, 0.9, -1.5), 2.4, Color(SUNSET, 0.32)])
	_glows.append([Vector3(1.1, 0.55, -1.3), 1.2, Color(1.0, 0.75, 0.45, 0.25)])
	# Ortada: restore edilmiş parlak klasik (kriko sehpalarında değil, yerde, ışık altında) + paslı ikizi
	var hero: Node3D = _place_car(YARD_HERO, Vector3(0.3, 0.0, 0.28), 60.0, 0.82)
	_wreck(YARD_HERO, Vector3(-0.62, 0.0, 0.45), Vector3(0.0, 75.0, 0.0), 0.82)
	# Ayaklı projektör: restore edilmiş aracı yandan aydınlatır (asılı lamba uzun güneş gölgesiyle zemini kesiyordu)
	_decor(&"floodlight", Vector3(1.15, 0.0, 0.62), 240.0, 1.35)
	_spot_light(Vector3(1.05, 0.55, 0.6), hero.position + Vector3(0.0, 0.12, 0.0), Color("FFE7C0"), 1.3, 42.0)
	_glows.append([Vector3(1.1, 0.5, 0.6), 0.3, Color(1.0, 0.92, 0.75, 0.75)])
	for lamp: Vector3 in _headlights(hero, 0.82):
		_glows.append([lamp, 0.12, Color(1.0, 0.95, 0.8, 0.9)])
	# Kaynak işi: paslı ikizin yanında kaynakçı arabası, mavi-beyaz ark ışığı ve kıvılcımlar
	_decor(&"welding_set", Vector3(-0.95, 0.0, 0.85), 90.0, 1.3)
	_decor(&"mechanic", Vector3(-0.72, 0.0, 0.9), 135.0, 1.3)
	var arc: Vector3 = Vector3(-0.55, 0.16, 0.7)
	_omni_light(arc, Color("9FD4FF"), 1.8, 0.8)
	_glows.append([arc, 0.32, Color(0.75, 0.9, 1.0, 1.0)])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	for i: int in 26:
		var d: Vector3 = Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(0.2, 1.0), rng.randf_range(-1.0, 1.0)).normalized()
		var spark: Vector3 = arc + d * rng.randf_range(0.04, 0.26) + Vector3(0.0, -0.02, 0.0)
		_glows.append([spark, rng.randf_range(0.02, 0.045), Color(1.0, rng.randf_range(0.6, 0.85), 0.3, 1.0)])
	# Ateş varili: paslı varil, içinde alev dilleri (ışıklı koniler), sıcak ışık, yükselen kıvılcımlar
	var barrel_at: Vector3 = Vector3(0.88, 0.0, -0.22)
	var barrel: MeshInstance3D = MeshInstance3D.new()
	var bcyl: CylinderMesh = CylinderMesh.new()
	bcyl.top_radius = 0.05
	bcyl.bottom_radius = 0.05
	bcyl.height = 0.16
	bcyl.radial_segments = 20
	barrel.mesh = bcyl
	barrel.material_override = _mat(Color("6B3A24"), 0.85, 0.3)
	barrel.position = barrel_at + Vector3(0.0, 0.08, 0.0)
	_world.add_child(barrel)
	var frng: RandomNumberGenerator = RandomNumberGenerator.new()
	frng.seed = 9
	for i: int in 6:
		var tongue: MeshInstance3D = MeshInstance3D.new()
		var cone: CylinderMesh = CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = frng.randf_range(0.018, 0.03)
		cone.height = frng.randf_range(0.06, 0.12)
		tongue.mesh = cone
		var flame: StandardMaterial3D = StandardMaterial3D.new()   # ışıksız: ışıma + ton eşleme turuncuyu limona çeviriyordu
		flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		flame.albedo_color = Color("C8340F") if i % 2 == 0 else Color("E0621A")   # Filmic ton eşleme parlak turuncuyu sarıya kaydırır: koyu tutulur
		tongue.material_override = flame
		tongue.position = barrel_at + Vector3(frng.randf_range(-0.025, 0.025), 0.16 + cone.height * 0.5, frng.randf_range(-0.025, 0.025))
		tongue.rotation_degrees = Vector3(frng.randf_range(-12.0, 12.0), 0.0, frng.randf_range(-12.0, 12.0))
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_world.add_child(tongue)
	_omni_light(barrel_at + Vector3(0.0, 0.3, 0.0), FIRE, 2.2, 1.1)
	# Parıltı kırmızıya yakın ve hafif: alevin üstüne eklenince kanallar doyup sarı / zeytin oluyordu
	_glows.append([barrel_at + Vector3(0.0, 0.24, 0.0), 0.6, Color(1.0, 0.3, 0.08, 0.3)])
	for i: int in 12:
		_glows.append([barrel_at + Vector3(frng.randf_range(-0.07, 0.07), frng.randf_range(0.3, 0.7), frng.randf_range(-0.07, 0.07)),
			frng.randf_range(0.015, 0.03), Color(1.0, 0.6, 0.25, 1.0)])
	# Çit boyunca ampul dizisi, köşede su kulesi, dağınık parçalar
	for i: int in 16:
		_glows.append([Vector3(-WALL + 0.01, 0.86 + 0.02 * sin(float(i)), -1.1 + float(i) * 0.16), 0.07, Color(1.0, 0.82, 0.45, 0.9)])
	_decor(&"tyre_pile", Vector3(-0.95, 0.0, 1.0), 0.0, 1.3)
	_decor(&"wooden_crates", Vector3(0.05, 0.0, 1.2), 30.0, 1.1)
	_decor(&"engine_block", Vector3(-0.25, 0.0, -0.15), 70.0, 1.2)
	_decor(&"rim_stack", Vector3(-1.0, 0.0, 0.2), 0.0, 1.3)
	_decor(&"barrel_rack", Vector3(1.3, 0.0, -0.5), 0.0, 1.25)
	_decor(&"jerry_cans", Vector3(0.4, 0.0, 0.95), 0.0, 1.25)
	_decor(&"car_ramps", Vector3(1.45, 0.0, 0.55), 90.0, 1.2)
	_decor(&"tyre_planter", Vector3(-0.45, 0.0, 1.15), 0.0, 1.2)
	_decor(&"engine_hoist", Vector3(-0.2, 0.0, 0.95), 45.0, 1.3)
	_decor(&"engine_block", Vector3(0.55, 0.0, 0.98), 30.0, 1.3)
	_decor(&"tyre_pile", Vector3(1.2, 0.0, 0.15), 0.0, 1.3)
	_decor(&"spare_doors", Vector3(-1.05, 0.0, -0.25), 90.0, 1.3)
	_decor(&"wooden_crates", Vector3(1.3, 0.0, -0.55), 0.0, 1.2)
	_decor(&"dog_house", Vector3(-1.0, 0.0, 1.25), 90.0, 1.1)


# --- KOVALAMACA: gece sokak köşesi -------------------------------------------------------------

const CHASE_SUSPECT: StringName = &"dodge_charger_1970"   # BLACKTOP BRUISER 70
const CHASE_POLICE: StringName = &"police_bentley"        # MONARCH PATROL GT
const P_RED: Color = Color(1.0, 0.18, 0.2)
const P_BLUE: Color = Color(0.22, 0.45, 1.0)
const STREET: Color = Color("FFC27A")
## Polis kaplamasının yazısız kopyası: blender ... debadge.py -- copy police_bentley police_bentley@yazisiz <bu yol>
const POLICE_CLEAN: String = "/home/burak/Projects/ct_shots/loading_art/doku/police_bentley_yazisiz.jpg"


func _chase() -> void:
	_env(Color("080B12"), Color("3E4A6A"), 0.6, 0.8)
	_iso_cam(Vector3(0.12, 0.22, -0.02), 1.6)
	_dir_light(Vector3(-55.0, 30.0, 0.0), Color("7C8FC8"), 0.25, true)
	# Islak asfalt (düşük pürüz, metalik: ışıklar parlak lekeler bırakır) + kaldırımlar
	var wet: StandardMaterial3D = _mat(Color("2A2E36"), 0.12, 0.45)
	if ResourceLoader.exists(ASPHALT_TEXTURE):
		wet.albedo_texture = load(ASPHALT_TEXTURE)
		wet.uv1_scale = Vector3(5.0, 5.0, 1.0)
	_box(Vector3(6.0, 0.05, 6.0), Vector3(0.0, -0.025, 0.0), wet)
	var curb: StandardMaterial3D = _mat(Color("7D7A74"), 0.8)
	var walk: StandardMaterial3D = _mat(Color("55565A"), 0.6, 0.2)
	walk.albedo_texture = _tile_texture()
	walk.uv1_scale = Vector3(6.0, 6.0, 1.0)
	_box(Vector3(6.0, 0.035, 0.42), Vector3(0.0, 0.0175, -1.0), walk)       # sağ arka kaldırım (dükkânlar)
	_box(Vector3(6.0, 0.04, 0.03), Vector3(0.0, 0.02, -0.79), curb)
	_box(Vector3(0.42, 0.035, 6.0), Vector3(-1.0, 0.0175, 0.0), walk)       # sol arka kaldırım
	_box(Vector3(0.03, 0.04, 6.0), Vector3(-0.79, 0.02, 0.0), curb)
	var paint: StandardMaterial3D = _mat(Color("E9E6DC"), 0.5)
	for i: int in 7:   # orta şerit kesikleri (x boyunca)
		_box(Vector3(0.22, 0.004, 0.025), Vector3(-0.55 + float(i) * 0.4, 0.002, 0.02), paint)
	for i: int in 6:   # yaya geçidi (sol arkadaki kavşak ağzı)
		_box(Vector3(0.24, 0.004, 0.08), Vector3(-0.62, 0.002, -0.6 + float(i) * 0.15), paint)
	# Sağ arka cephe: dükkân vitrinleri (ışıklı), tabelalar, tente
	var facade: StandardMaterial3D = _mat(Color("3A2F33"), 0.85)
	_box(Vector3(6.0, 1.4, 0.08), Vector3(0.0, 0.7, -WALL - 0.04), facade)
	var shops: Array = [[-0.3, "AUTO SHOP", Color("5FD36A")], [0.55, "PIZZA", Color("FF5A7A")], [1.35, "CAFE", Color("6FB2FF")]]
	for shop: Array in shops:
		var x: float = shop[0]
		_box(Vector3(0.62, 0.36, 0.01), Vector3(x, 0.26, -WALL + 0.005), _glow_mat(Color("FFD9A0"), 1.1))
		_box(Vector3(0.66, 0.03, 0.03), Vector3(x, 0.45, -WALL + 0.01), _mat(Color("1C1D22"), 0.5))
		_box(Vector3(0.5, 0.11, 0.02), Vector3(x, 0.58, -WALL + 0.015), _mat(Color("15161A"), 0.6))
		_text(shop[1], Vector3(x, 0.58, -WALL + 0.028), Vector3.ZERO, 0.0016, shop[2]).modulate = Color(shop[2] * 1.6, 1.0)
		_glows.append([Vector3(x, 0.58, -WALL + 0.03), 0.55, Color(shop[2], 0.28)])
		_omni_light(Vector3(x, 0.3, -WALL + 0.25), Color("FFD9A0"), 0.9, 0.7)
		var awning: MeshInstance3D = _box(Vector3(0.66, 0.015, 0.2), Vector3(x, 0.5, -WALL + 0.1), _mat(shop[2].darkened(0.3), 0.7))
		awning.rotation_degrees = Vector3(-18.0, 0.0, 0.0)
	# Sol arka cephe: tuğla duvar, yangın merdiveni, grafiti tonu, duvar lambası
	_box(Vector3(0.08, 1.4, 6.0), Vector3(-WALL - 0.04, 0.7, 0.0), _mat(Color("4A2E2A"), 0.9))
	_wall(&"neon_flame", Vector3(-WALL, 0.75, 0.5), 90.0, 1.4)
	_wall(&"sign_street", Vector3(-WALL, 0.55, -0.35), 90.0, 1.3)
	_decor(&"dumpster", Vector3(-1.02, 0.0, 0.85), 90.0, 1.2)
	_decor(&"fire_hydrant", Vector3(-0.92, 0.0, 0.35), 0.0, 1.3)
	_decor(&"phone_booth", Vector3(1.75, 0.0, -1.0), 0.0, 1.2)
	# Sokak lambaları: tepede sıcak ışık, görünür huzme, ıslak zeminde ışık havuzu
	for at: Vector3 in [Vector3(-0.9, 0.0, -0.9), Vector3(1.0, 0.0, -0.92)]:
		_box(Vector3(0.03, 1.1, 0.03), at + Vector3(0.0, 0.55, 0.0), _mat(Color("2A2D33"), 0.5, 0.5))
		var head: Vector3 = at + Vector3(0.12, 1.08, 0.12)
		_box(Vector3(0.26, 0.025, 0.025), at + Vector3(0.06, 1.1, 0.06), _mat(Color("2A2D33"), 0.5, 0.5)).rotation_degrees = Vector3(0.0, -45.0, 0.0)
		_box(Vector3(0.1, 0.03, 0.06), head, _glow_mat(STREET, 3.0))
		_glows.append([head, 0.3, Color(STREET, 0.85)])
		_beam(head + Vector3(0.0, -0.02, 0.0), Vector3(head.x, 0.0, head.z), 0.04, 0.42, STREET, 0.1)
		_spot_light(head, Vector3(head.x, 0.0, head.z), STREET, 1.8, 40.0)
	# Kaçan araç: sağda, burnu kameraya dönmüş drift; arkasında lastik dumanı ve kavisli izler
	var suspect_at: Vector3 = Vector3(0.62, 0.0, -0.36)
	var suspect: Node3D = _place_car(CHASE_SUSPECT, suspect_at, 48.0, 0.84)
	# Arka tekerlerden yükselen lastik pusu (2B, katkılı). DragFx dumanı bu karanlık sahnede siyah leke çiziyordu.
	var back: Vector3 = suspect.global_position - suspect.global_basis.z.normalized() * 0.3
	for spec: Array in [[Vector3(0.0, 0.1, 0.0), 0.7, 0.2], [Vector3(-0.15, 0.22, 0.12), 0.55, 0.16], [Vector3(0.12, 0.3, -0.1), 0.5, 0.13],
			[Vector3(-0.3, 0.12, 0.3), 0.6, 0.12]]:
		_glows.append([back + (spec[0] as Vector3), spec[1], Color(0.82, 0.84, 0.9, spec[2])])
	var rubber: StandardMaterial3D = _alpha_mat(Color(0.02, 0.02, 0.025, 0.6))
	for k: int in 2:
		for i: int in 26:   # kavisli iz: polisin önünden kaçanın arka tekerlerine
			var t: float = float(i) / 25.0
			var p: Vector3 = Vector3(lerpf(-0.1, 0.42, t), 0.004, lerpf(0.25, -0.5, t) + sin(t * PI) * 0.12 + (float(k) - 0.5) * 0.18)
			var mark: MeshInstance3D = _box(Vector3(0.075, 0.003, 0.04), p, rubber)
			mark.rotation_degrees = Vector3(0.0, 55.0 - t * 30.0, 0.0)
	for lamp: Vector3 in _headlights(suspect, 0.84):
		_glows.append([lamp, 0.16, Color(1.0, 0.96, 0.85, 0.95)])
		var dir: Vector3 = suspect.global_basis.z.normalized()
		_beam(lamp + dir * 0.02, lamp + dir * 1.1 + Vector3(0.0, -0.06, 0.0), 0.025, 0.28, Color("FFF4DC"), 0.1)
	# Polis: arkasında, çakarları yanık; kırmızı / mavi ışık zemine ve cephelere vurur
	var police: Node3D = _place_car(CHASE_POLICE, Vector3(-0.42, 0.0, 0.38), 70.0, 0.82)
	CarRig.for_node(police).set_police_lights(PoliceLights.Mode.LIT)
	_swap_albedo(police, POLICE_CLEAN)   # kaplamada yerel yazı / arma yok
	var side: Vector3 = police.global_basis.x.normalized()
	var top: Vector3 = police.global_position + Vector3(0.0, 0.82 * 0.36, 0.0)
	for spec: Array in [[side, P_RED], [-side, P_BLUE]]:
		var at: Vector3 = top + (spec[0] as Vector3) * 0.06
		_omni_light(at + Vector3(0.0, 0.08, 0.0), spec[1], 2.0, 1.3)
		_glows.append([at, 0.42, Color(spec[1], 0.6)])
		_glows.append([at, 0.13, Color(Color(spec[1]).lightened(0.5), 0.95)])
	for lamp: Vector3 in _headlights(police, 0.82):
		_glows.append([lamp, 0.13, Color(1.0, 0.96, 0.85, 0.9)])
	# Park etmiş araç, üst kat pencereleri, sokak eşyaları
	_place_car(&"hyundai_getz", Vector3(1.75, 0.0, -0.6), 90.0, 0.7)
	var wrng: RandomNumberGenerator = RandomNumberGenerator.new()
	wrng.seed = 31
	for i: int in 12:   # sağ cephe üst kat pencereleri
		if wrng.randf() < 0.35:
			continue
		var c: Color = Color("FFD9A0") if wrng.randf() < 0.75 else Color("8FB8FF")
		_box(Vector3(0.16, 0.12, 0.01), Vector3(-0.9 + float(i) * 0.26, 0.88 + float(i % 2) * 0.2, -WALL + 0.004), _glow_mat(c, 1.0))
	for i: int in 10:   # sol cephe pencereleri
		if wrng.randf() < 0.35:
			continue
		_box(Vector3(0.01, 0.12, 0.16), Vector3(-WALL + 0.004, 0.9 + float(i % 2) * 0.22, -0.9 + float(i) * 0.26), _glow_mat(Color("FFD9A0"), 0.9))
	_wall(&"neon_speed", Vector3(-WALL, 0.48, -0.75), 90.0, 1.3)
	_decor(&"bench", Vector3(1.4, 0.035, -1.05), 0.0, 1.2)
	_decor(&"mailbox", Vector3(0.15, 0.035, -1.08), 0.0, 1.2)
	_decor(&"traffic_light", Vector3(-0.85, 0.035, -0.85), 45.0, 1.3)
	_decor(&"wooden_crates", Vector3(-1.05, 0.035, 1.25), 90.0, 1.1)
	# Devrilmiş koni ve bariyer: kaçan aracın çarptığı
	_decor(&"traffic_cones", Vector3(1.15, 0.0, 0.05), 70.0, 1.2)
	_decor(&"a_barrier", Vector3(1.45, 0.0, -0.4), 30.0, 1.2)


## Kovalamacada ince yağmur: logonun ve karartmanın ALTINDA kalsın diye üst sınıfın katmanından önce eklenir.
func _build_overlay(size: Vector2) -> void:
	if _slide == "kovalamaca":
		var rain: ColorRect = ColorRect.new()
		rain.size = size
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = preload("res://vfx/speed_lines.gdshader")
		material.set_shader_parameter(&"aspect", size.x / size.y)
		material.set_shader_parameter(&"intensity", 0.32)
		material.set_shader_parameter(&"flow", Vector2(-0.22, 1.0).normalized())
		material.set_shader_parameter(&"rows", 110.0)
		rain.material = material
		_viewport.add_child(rain)
	super._build_overlay(size)
