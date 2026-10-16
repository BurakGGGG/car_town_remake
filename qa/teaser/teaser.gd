extends SceneTree
## AUTO YARD TEASER — 22 sn, dikey 1080x1920, 30 fps. Her bölüm ayrı süreçte çekilir; kareler GLOBAL kare
## numarasıyla PNG yazılır (bölümler yan yana birleşir), ses ayrıca qa/teaser/soundtrack.py ile basılır.
##   godot-4 --path . --display-driver x11 --disable-vsync --fixed-fps 30 --script qa/teaser/teaser.gd \
##       -- <bölüm> <çıktı_klasörü> [önizleme_adımı]
## Bölümler: hikaye (0–7 sn: paslı Integrale + tamir) · garaj (7–12) · drag (12–17) ·
## vitrin_ev / vitrin_sanayi / vitrin_luks / vitrin_eglence (17–20, 0,75'er sn) · logo (20–22).
## önizleme_adımı N > 0: yalnızca her N. kare yarım boyda yazılır (kurgu provası).
## Ekran 1920 piksel yüksek olmadığı için pencereye değil SubViewport'a çizilir (Movie Maker kullanılmaz).
const FPS: float = 30.0
const W: int = 1080
const H: int = 1920
const SEGMENTS: Dictionary = {
	"hikaye": [0.0, 7.0],
	"garaj": [7.0, 12.0],
	"drag": [12.0, 17.0],
	"vitrin_ev": [17.0, 17.75],
	"vitrin_sanayi": [17.75, 18.5],
	"vitrin_luks": [18.5, 19.25],
	"vitrin_eglence": [19.25, 20.0],
	"logo": [20.0, 25.4],
}
## KURGU ZAMANI ↔ ÇEKİM ZAMANI (seslendirme gelince, 2026-10-14): bölümler "çekim" saniyeleriyle yazılıdır;
## video bu parçalı eşlemeyle uzatılır: [çekim_baş, çekim_son, kurgu_baş, kurgu_son]. Gizem 3 → 5,5 sn
## ağırlaşır, garaj vitrini 3 → 4 sn, kapanış 25,4'e kadar (son kare sabit) sürer; kesmeler aynı hızda.
## qa/teaser/soundtrack.py aynı tabloyu (PIECES) kullanır.
const PIECES: Array = [
	[0.0, 3.0, 0.0, 5.5],
	[3.0, 7.0, 5.5, 9.5],
	[7.0, 12.0, 9.5, 14.5],
	[12.0, 17.0, 14.5, 19.5],
	[17.0, 20.0, 19.5, 23.5],
	[20.0, 25.4, 23.5, 28.9],
]
const SEGMENT_SCRIPTS: Dictionary = {
	"hikaye": "res://qa/teaser/seg_hikaye.gd",
	"garaj": "res://qa/teaser/seg_garaj.gd",
	"drag": "res://qa/teaser/seg_drag.gd",
	"vitrin_ev": "res://qa/teaser/seg_vitrin.gd",
	"vitrin_sanayi": "res://qa/teaser/seg_vitrin.gd",
	"vitrin_luks": "res://qa/teaser/seg_vitrin.gd",
	"vitrin_eglence": "res://qa/teaser/seg_vitrin.gd",
	"logo": "res://qa/teaser/seg_logo.gd",
}
const BRAND_BLUE: Color = Color(0.12, 0.33, 0.85)
const BRAND_GOLD: Color = Color(1.0, 0.76, 0.2)

var vp: SubViewport
var post: ShaderMaterial
var title_layer: Control
var out_dir: String = ""
var preview_step: int = 0
var segment: String = ""
var frame_index: int = 0
var _saved: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	segment = args[0]
	out_dir = args[1]
	preview_step = int(args[2]) if args.size() > 2 else 0
	DirAccess.make_dir_recursive_absolute(out_dir)
	Engine.max_fps = 0
	vp = SubViewport.new()
	vp.size = Vector2i(W, H)
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.audio_listener_enable_3d = false
	root.add_child(vp)
	var preview: TextureRect = TextureRect.new()
	preview.texture = vp.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	var preview_layer: CanvasLayer = CanvasLayer.new()
	preview_layer.layer = 100
	preview_layer.add_child(preview)
	root.add_child(preview_layer)
	_build_overlay()
	_run.call_deferred()


func _build_overlay() -> void:
	var post_layer: CanvasLayer = CanvasLayer.new()
	post_layer.layer = 20
	vp.add_child(post_layer)
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.size = Vector2(W, H)
	post = ShaderMaterial.new()
	post.shader = preload("res://qa/teaser/post.gdshader")
	rect.material = post
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_layer.add_child(rect)
	var text_layer: CanvasLayer = CanvasLayer.new()
	text_layer.layer = 21
	vp.add_child(text_layer)
	title_layer = Control.new()
	title_layer.size = Vector2(W, H)
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.add_child(title_layer)


func _run() -> void:
	var script: GDScript = load(SEGMENT_SCRIPTS[segment])
	var seg: RefCounted = script.new()
	await seg.call(&"run", self)
	print("TEASER %s bitti: %d kare yazıldı → %s" % [segment, _saved, out_dir])
	quit(0)


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Çekim saniyesi → kurgu saniyesi (PIECES).
static func to_edit(t: float) -> float:
	for p: Array in PIECES:
		if t <= float(p[1]) + 1e-6:
			return lerpf(float(p[2]), float(p[3]), inverse_lerp(float(p[0]), float(p[1]), t))
	return t


## Kurgu saniyesi → çekim saniyesi.
static func to_shot(t: float) -> float:
	for p: Array in PIECES:
		if t < float(p[3]) - 1e-6:
			return lerpf(float(p[0]), float(p[1]), inverse_lerp(float(p[2]), float(p[3]), t))
	return t


## Bölümün kare döngüsü: kurgu zaman çizelgesinde her kare için tick(t) (t = ÇEKİM saniyesi; bölümler bu
## saniyelerle yazılı), sonra çizilen kare KURGU kare numarasıyla diske.
func record(tick: Callable) -> void:
	var span: Array = SEGMENTS[segment]
	var f0: int = roundi(to_edit(float(span[0])) * FPS)
	var f1: int = roundi(to_edit(float(span[1])) * FPS)
	for f: int in range(f0, f1):
		frame_index = f
		var t: float = to_shot(float(f) / FPS)
		post.set_shader_parameter(&"seed", float(f % 97))
		tick.call(t)
		await process_frame
		if preview_step > 0 and (f - f0) % preview_step != 0:
			continue
		await RenderingServer.frame_post_draw
		var img: Image = vp.get_texture().get_image()
		if preview_step > 0:
			img.resize(W / 2, H / 2, Image.INTERPOLATE_BILINEAR)
		img.save_png("%s/%05d.png" % [out_dir, f])
		_saved += 1


# --- Yardımcılar -------------------------------------------------------------------------------

static func smooth(x: float) -> float:
	var k: float = clampf(x, 0.0, 1.0)
	return k * k * (3.0 - 2.0 * k)


static func ease_out(x: float, power: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), power)


static func ease_in(x: float, power: float = 3.0) -> float:
	return pow(clampf(x, 0.0, 1.0), power)


## t'nin [a, b) aralığındaki oranı (0..1, kırpılmış).
static func span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


## Kesme darbesi: kesme anında 1, `length` saniyede söner (flaş / renk sapması için).
static func pulse(t: float, at: float, length: float) -> float:
	if t < at:
		return 0.0
	return pow(1.0 - clampf((t - at) / length, 0.0, 1.0), 2.0)


## El kamerası titremesi (deterministik: t'ye bağlı).
static func shake(t: float, amount: float, freq: float = 1.0) -> Vector3:
	return Vector3(
		sin(t * 13.1 * freq) * 0.6 + sin(t * 29.7 * freq + 1.3) * 0.4,
		sin(t * 11.3 * freq + 2.1) * 0.6 + sin(t * 23.9 * freq + 0.4) * 0.4,
		sin(t * 7.7 * freq + 4.2)) * amount


func reset_post() -> void:
	post.set_shader_parameter(&"aberration", 0.0)
	post.set_shader_parameter(&"vignette", 0.45)
	post.set_shader_parameter(&"grain", 0.04)
	post.set_shader_parameter(&"exposure", 1.0)
	post.set_shader_parameter(&"black", 0.0)
	post.set_shader_parameter(&"white", 0.0)
	post.set_shader_parameter(&"zoom_blur", 0.0)
	post.set_shader_parameter(&"tint", Vector3.ONE)


func set_post(key: StringName, value: Variant) -> void:
	post.set_shader_parameter(key, value)


## Ekran yazısı: ortalanmış, kalın, gölgeli. y_frac: dikey merkez (0 üst, 1 alt).
func make_title(text: String, size: int, y_frac: float, weight: int = 900, color: Color = Color.WHITE,
		spacing: int = 0) -> Label:
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Lato", "Noto Sans", "DejaVu Sans"])
	font.font_weight = weight
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	var fv: FontVariation = FontVariation.new()
	fv.base_font = font
	fv.spacing_glyph = spacing
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override(&"font", fv)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_color_override(&"font_outline_color", Color(0.0, 0.0, 0.0, 0.55))
	label.add_theme_constant_override(&"outline_size", maxi(4, size / 9))
	label.add_theme_color_override(&"font_shadow_color", Color(0.0, 0.0, 0.0, 0.6))
	label.add_theme_constant_override(&"shadow_offset_x", 0)
	label.add_theme_constant_override(&"shadow_offset_y", maxi(3, size / 14))
	label.add_theme_constant_override(&"shadow_outline_size", maxi(6, size / 6))
	var margin: float = 70.0
	label.size = Vector2(W - margin * 2.0, size * 3.0)
	label.position = Vector2(margin, H * y_frac - label.size.y * 0.5)
	label.pivot_offset = label.size * 0.5
	label.modulate.a = 0.0
	title_layer.add_child(label)
	return label


## Karanlık / stüdyo ortamı.
func make_env(parent: Node, bg: Color, ambient: Color, ambient_energy: float, glow: float = 0.9) -> Environment:
	var env_node: WorldEnvironment = WorldEnvironment.new()
	var e: Environment = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = bg
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = ambient
	e.ambient_light_energy = ambient_energy
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.0
	e.tonemap_white = 6.0
	e.glow_enabled = glow > 0.0
	e.glow_intensity = glow
	e.glow_strength = 1.0
	e.glow_bloom = 0.02
	e.glow_hdr_threshold = 0.9
	e.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	e.set_glow_level(0, 0.0)
	e.set_glow_level(1, 1.0)
	e.set_glow_level(2, 1.0)
	e.set_glow_level(3, 0.6)
	e.set_glow_level(4, 0.4)
	env_node.environment = e
	parent.add_child(env_node)
	return e


## Aracı kurar: boy `length` birim (+Z önde, zemin y=0), fabrika görünümü. Rig meta'da.
func spawn_car(id: StringName, parent: Node, length: float = 1.2) -> Node3D:
	var path: String = CarCatalog.scene_path(id)
	var car: Node3D = (load(path) as PackedScene).instantiate()
	car.scale = Vector3.ONE * length * CarCatalog.model_scale(id)
	parent.add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	var app: CarAppearance = CarAppearance.new()
	app.body_color = CarCatalog.default_color_for(path)
	rig.apply(app)
	rig.set_lod_bias(CarRig.LOD_BIAS_GARAGE)
	car.set_meta(&"appearance", app)
	return car


static func rig_of(car: Node3D) -> CarRig:
	return CarRig.for_node(car)


static func appearance_of(car: Node3D) -> CarAppearance:
	return car.get_meta(&"appearance") as CarAppearance


## Aracın dünya kutusu (tüm görünür mesh'ler).
static func car_box(car: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in car.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if not mi.visible:
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Rolün mesh'lerinin dünya merkezleri (ör. iki far).
static func role_centers(car: Node3D, role: StringName) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for mi: MeshInstance3D in rig_of(car).get_meshes(role):
		out.append((mi.global_transform * mi.get_aabb()).get_center())
	return out


static func look_cam(cam: Camera3D, pos: Vector3, target: Vector3, roll_deg: float = 0.0) -> void:
	cam.global_position = pos
	cam.look_at(target, Vector3.UP)
	if roll_deg != 0.0:
		cam.rotate_object_local(Vector3.FORWARD, deg_to_rad(roll_deg))


## Toplamalı, ışımalı küçük kıvılcım çubukları (hız yönüne hizalı).
static func make_sparks(color: Color, amount: int, speed: float, scale_len: float = 1.0) -> CPUParticles3D:
	var p: CPUParticles3D = CPUParticles3D.new()
	var stick: CylinderMesh = CylinderMesh.new()
	stick.top_radius = 0.0016 * scale_len
	stick.bottom_radius = 0.0016 * scale_len
	stick.height = 0.035 * scale_len
	stick.radial_segments = 4
	stick.rings = 1
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = color * 4.0
	m.vertex_color_use_as_albedo = true
	stick.material = m
	p.mesh = stick
	p.amount = amount
	p.lifetime = 0.55
	p.explosiveness = 0.0
	p.direction = Vector3(0.0, 1.0, 0.0)
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -3.2, 0.0)
	p.particle_flag_align_y = true
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 1.0, 0.9, 1.0))
	fade.set_color(1, Color(1.0, 0.35, 0.05, 1.0))
	p.color_ramp = fade
	p.emitting = false
	return p


## Yumuşak ışıma pulu (far parlaması, lens ışıltısı): kameraya dönük, toplamalı radyal gradyan.
static func make_glow_sprite(color: Color, size: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(size, size)
	var grad: Gradient = Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	grad.add_point(0.25, Color(1.0, 1.0, 1.0, 0.35))
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 128
	tex.height = 128
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.no_depth_test = false
	m.albedo_texture = tex
	m.albedo_color = color
	quad.material = m
	mi.mesh = quad
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
