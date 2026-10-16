extends RefCounted
## 20–22 sn GARAJ SENİN. KURALLAR SENİN. (son 2 sn) Garaj vitrininden sonra son darbe: marka mavisi zemin,
## dönen ışın demeti, AUTO YARD logosu çarparak gelir (şok halkası + parıltı süpürmesi), slogan ve
## "19 EKİM'DE PLAY STORE'DA". 21,25'ten sonra her şey durur (son ~0,75 sn tamamen sabit).
const D = preload("res://qa/teaser/teaser.gd")
const LOGO: String = "res://assets/branding/autoyard_logo.png"
const SETTLE: float = 21.25

const BG_SHADER: String = """
shader_type canvas_item;
uniform float spin = 0.0;
uniform float glow = 0.0;
uniform float ring = 0.0;
uniform vec2 aspect = vec2(0.5625, 1.0);
void fragment() {
	vec2 p = (UV - vec2(0.5, 0.36)) * aspect;
	float r = length(p);
	float a = atan(p.y, p.x);
	vec3 deep = vec3(0.02, 0.06, 0.2);
	vec3 mid = vec3(0.07, 0.24, 0.66);
	vec3 col = mix(mid, deep, smoothstep(0.0, 0.75, r));
	float rays = smoothstep(0.35, 0.65, 0.5 + 0.5 * sin(a * 14.0 + spin));
	col += vec3(0.08, 0.16, 0.38) * rays * (1.0 - smoothstep(0.05, 0.8, r));
	col += vec3(0.35, 0.55, 1.0) * glow * exp(-r * 6.0);
	float band = exp(-pow((r - ring) * 28.0, 2.0)) * step(0.001, ring) * (1.0 - smoothstep(0.2, 0.9, ring));
	col += vec3(0.7, 0.85, 1.0) * band;
	COLOR = vec4(col, 1.0);
}
"""

const SHINE_SHADER: String = """
shader_type canvas_item;
uniform float sweep = -1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float x = UV.x + (1.0 - UV.y) * 0.25;
	float band = exp(-pow((x - sweep) * 9.0, 2.0));
	c.rgb += vec3(1.0, 0.97, 0.85) * band * 0.75 * c.a;
	COLOR = c;
}
"""

var d: D
var bg: ShaderMaterial
var logo: TextureRect
var shine: ShaderMaterial
var tagline: Label
var date: Label
var badge: PanelContainer
var sparks: CPUParticles2D


func run(director: D) -> void:
	d = director
	var bg_layer: CanvasLayer = CanvasLayer.new()
	bg_layer.layer = 5
	d.vp.add_child(bg_layer)
	var rect: ColorRect = ColorRect.new()
	rect.size = Vector2(D.W, D.H)
	bg = ShaderMaterial.new()
	var bg_shader: Shader = Shader.new()
	bg_shader.code = BG_SHADER
	bg.shader = bg_shader
	bg.set_shader_parameter(&"aspect", Vector2(float(D.W) / float(D.H), 1.0))
	rect.material = bg
	bg_layer.add_child(rect)
	sparks = CPUParticles2D.new()
	sparks.position = Vector2(D.W * 0.5, D.H * 0.36)
	sparks.amount = 120
	sparks.lifetime = 1.4
	sparks.one_shot = true
	sparks.explosiveness = 0.95
	sparks.direction = Vector2(0.0, -1.0)
	sparks.spread = 180.0
	sparks.initial_velocity_min = 300.0
	sparks.initial_velocity_max = 1300.0
	sparks.damping_min = 600.0
	sparks.damping_max = 900.0
	sparks.gravity = Vector2(0.0, 300.0)
	sparks.scale_amount_min = 3.0
	sparks.scale_amount_max = 8.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	fade.set_color(1, Color(1.0, 0.7, 0.2, 0.0))
	sparks.color_ramp = fade
	sparks.emitting = false
	bg_layer.add_child(sparks)
	_build_stack()
	await d.frames(5)
	_place()
	await d.record(tick)


## Logo + slogan + tarih rozeti. Kap kullanılmaz: yazı tipi yüklenince boyut değişip dizilim kayıyordu;
## boyutlar ölçüldükten sonra _place() bir kez yerleştirir (canlandırma yalnız ölçek/saydamlık).
func _build_stack() -> void:
	var box: Control = d.title_layer
	logo = TextureRect.new()
	logo.texture = load(LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(D.W - 90.0, (D.W - 90.0) * 475.0 / 2048.0)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shine = ShaderMaterial.new()
	var sh: Shader = Shader.new()
	sh.code = SHINE_SHADER
	shine.shader = sh
	logo.material = shine
	box.add_child(logo)
	tagline = d.make_title("Garaj senin.\nKurallar senin.", 92, 0.5, 900, Color.WHITE)
	tagline.get_parent().remove_child(tagline)
	tagline.custom_minimum_size = Vector2(D.W - 140.0, 240.0)
	tagline.size = tagline.custom_minimum_size
	tagline.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tagline)
	badge = PanelContainer.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.08, 0.24, 0.92)
	style.border_color = D.BRAND_GOLD
	style.set_border_width_all(6)
	style.set_corner_radius_all(40)
	style.content_margin_left = 60.0
	style.content_margin_right = 60.0
	style.content_margin_top = 26.0
	style.content_margin_bottom = 30.0
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0.0, 8.0)
	badge.add_theme_stylebox_override(&"panel", style)
	badge.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override(&"separation", 0)
	badge.add_child(inner)
	date = d.make_title("19 EKİM'DE", 118, 0.5, 900, D.BRAND_GOLD)
	date.get_parent().remove_child(date)
	date.autowrap_mode = TextServer.AUTOWRAP_OFF
	date.custom_minimum_size = Vector2(700.0, 140.0)
	date.modulate.a = 1.0
	inner.add_child(date)
	var store: Label = d.make_title("PLAY STORE'DA", 64, 0.5, 900, Color.WHITE)
	store.get_parent().remove_child(store)
	store.autowrap_mode = TextServer.AUTOWRAP_OFF
	store.custom_minimum_size = Vector2(700.0, 80.0)
	store.modulate.a = 1.0
	inner.add_child(store)
	box.add_child(badge)
	for c: Control in [logo, tagline, badge]:
		c.modulate.a = 0.0
	_center_pivots.call_deferred()


func _place() -> void:
	logo.size = logo.custom_minimum_size
	badge.size = badge.get_combined_minimum_size()
	logo.position = Vector2((D.W - logo.size.x) * 0.5, D.H * 0.36 - logo.size.y * 0.5)
	tagline.position = Vector2((D.W - tagline.size.x) * 0.5, D.H * 0.5 - tagline.size.y * 0.5)
	badge.position = Vector2((D.W - badge.size.x) * 0.5, D.H * 0.66 - badge.size.y * 0.5)
	_center_pivots()


func _center_pivots() -> void:
	for c: Control in [logo, tagline, badge]:
		c.pivot_offset = c.size * 0.5


func tick(t: float) -> void:
	d.reset_post()
	_center_pivots()
	var live: float = minf(t, SETTLE)   # 21,25'ten sonra zaman durur → son kare sabit
	d.set_post(&"vignette", 0.55)
	d.set_post(&"grain", 0.02 if t < SETTLE else 0.0)
	bg.set_shader_parameter(&"spin", live * 0.35)
	bg.set_shader_parameter(&"glow", 0.4 + D.pulse(t, 20.05, 0.6) * 1.6)
	bg.set_shader_parameter(&"ring", D.ease_out(D.span(t, 20.05, 20.8), 2.0) * 1.0)
	# Kesme: önce bir kare beyaz darbe, sonra logo çarparak gelir
	d.set_post(&"white", D.pulse(t, 20, 0.18) * 0.9)
	d.set_post(&"aberration", D.pulse(t, 20.05, 0.35) * 10.0)
	var lk: float = D.span(t, 20, 20.22)
	logo.modulate.a = D.ease_out(lk, 2.0)
	var bounce: float = sin(D.span(t, 20.22, 20.6) * PI * 2.0) * (1.0 - D.span(t, 20.22, 20.6)) * 0.05
	logo.scale = Vector2.ONE * (lerpf(2.6, 1.0, D.ease_in(lk, 2.0)) + bounce)
	logo.rotation = deg_to_rad(lerpf(-8.0, 0.0, D.ease_in(lk, 2.0)))
	if t >= 20.22 and t < 20.22 + 1.0 / D.FPS:
		sparks.restart()
		sparks.emitting = true
	shine.set_shader_parameter(&"sweep", lerpf(-0.4, 1.5, D.span(t, 20.55, 21.2)) if t < SETTLE else -1.0)
	# Slogan 20,3, tarih rozeti 20,5
	var tk: float = D.span(t, 20.3, 20.5)
	tagline.modulate.a = D.ease_out(tk, 2.0)
	tagline.scale = Vector2.ONE * lerpf(1.25, 1.0, D.ease_out(tk, 3.0))
	var bk: float = D.span(t, 20.5, 20.7)
	badge.modulate.a = D.ease_out(bk, 2.0)
	var beat: float = 0.0
	if t < SETTLE:
		beat = D.pulse(t, 20.7, 0.2) * 0.06
	badge.scale = Vector2.ONE * (lerpf(1.6, 1.0, D.ease_out(bk, 4.0)) + beat)
