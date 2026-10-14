class_name GemShopButton
extends Button
## HUD'un sol üstündeki GEM AL düğmesi — para / gem sayacının hemen altında, dikkat çeken mavi hap:
## solda zıplayan gem çizimi (GemPackArt.BUTTON), üstünden periyodik ışık süpürmesi, birkaç saniyede
## bir "nefes alma" büyümesi. Başlangıç paketi alınmadıysa sağ üstte kırmızı "!" rozeti.
## Kodla kurulur (Hud._setup_gem_store); basınca `pressed` → mağaza.

const HEIGHT: float = 44.0
const PULSE_EVERY: float = 4.0
const SHINE_EVERY: float = 3.2

## Sağ üstte rozet gösterilsin mi (tek seferlik paket hâlâ alınabilir).
var show_badge: bool = false:
	set(value):
		show_badge = value
		_overlay.animate()

var _art: GemPackArt
var _row: HBoxContainer
var _overlay: _Overlay
var _t: float = 0.0
var _next_pulse: float = 1.5


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	custom_minimum_size = Vector2(0.0, HEIGHT)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	clip_contents = false
	text = ""
	add_theme_stylebox_override(&"normal", _style(HudPalette.GEM_DARK, HudPalette.GEM))
	add_theme_stylebox_override(&"hover", _style(HudPalette.GEM_DARK.lightened(0.08), HudPalette.GEM.lightened(0.1)))
	add_theme_stylebox_override(&"pressed", _style(HudPalette.GEM_DARK.darkened(0.12), HudPalette.GEM_DARK))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

	var row: HBoxContainer = HBoxContainer.new()
	_row = row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(4.0, 0.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	_art = GemPackArt.new()
	_art.kind = GemPackArt.Kind.BUTTON
	_art.custom_minimum_size = Vector2(38.0, 38.0)
	_art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_art)
	var label: Label = Label.new()
	label.text = Loc.t("GEM AL")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"HudOutlined"
	label.add_theme_font_size_override(&"font_size", 17)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", HudPalette.GEM_DARK.darkened(0.45))
	label.add_theme_constant_override(&"outline_size", 5)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(label)
	var tail: Control = Control.new()
	tail.custom_minimum_size = Vector2(14.0, 0.0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)

	_overlay = _Overlay.new()
	_overlay.owner_button = self
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


func _ready() -> void:
	# Genişlik içerikten (yazı tipi temadan ağaca girince çözülür)
	_fit_width.call_deferred()
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	_overlay.animate()
	if _t >= _next_pulse:
		_next_pulse = _t + PULSE_EVERY
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.08, 1.08), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tween.tween_property(self, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _fit_width() -> void:
	custom_minimum_size.x = _row.get_combined_minimum_size().x


static func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border.lightened(0.35)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(int(HEIGHT * 0.5))
	sb.shadow_color = HudPalette.SHADOW
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0.0, 2.0)
	sb.anti_aliasing = true
	return sb


## Üst katman: cam parlaklığı, süpürme ışığı, rozet. Yazının ÜSTÜNDE çizilir. Parlaklık yalnızca boyut
## değişince çizilir; süpürme ve rozet nabzı alt öğelerin konum / ölçek / saydamlığıyla oynar (eskiden her
## karede yeni StyleBoxFlat + çokgen üretiliyordu; görüntü aynı — qa/gem_button_shots.gd).
class _Overlay:
	extends Control
	var owner_button: GemShopButton
	var _gloss: StyleBoxFlat
	var _shine: _Shape
	var _disc: _Shape
	var _mark: _Shape

	func _ready() -> void:
		_gloss = StyleBoxFlat.new()
		_gloss.bg_color = Color(1.0, 1.0, 1.0, 0.16)
		_gloss.anti_aliasing = true
		_shine = _Shape.new(_Shape.SHINE)
		_disc = _Shape.new(_Shape.DISC)
		_mark = _Shape.new(_Shape.MARK)
		_mark.font = get_theme_default_font()
		for shape: _Shape in [_shine, _disc, _mark]:
			add_child(shape)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		var r: float = size.y * 0.5
		_gloss.set_corner_radius_all(int(r))
		_gloss.corner_radius_bottom_left = 0
		_gloss.corner_radius_bottom_right = 0
		_shine.extent = size.y
		_shine.queue_redraw()
		_disc.position = Vector2(size.x - 4.0, 3.0)
		_mark.position = _disc.position
		queue_redraw()
		animate()

	func _draw() -> void:
		# Üst yarıda cam parlaklığı
		draw_style_box(_gloss, Rect2(Vector2(4.0, 3.0), Vector2(size.x - 8.0, size.y * 0.42)))

	## Süpürme: eğik beyaz şerit soldan sağa geçer (hap şeklinin içinde kalsın diye kenarlarda söner).
	## Rozet dairesi nabız atar, "!" sabit boyda kalır.
	func animate() -> void:
		if _shine == null:
			return
		var t: float = owner_button._t
		var r: float = size.y * 0.5
		var phase: float = fmod(t, SHINE_EVERY) / 0.7
		var fade: float = 0.0
		var x: float = 0.0
		if phase < 1.0:
			x = lerpf(-size.y, size.x + size.y, phase)
			fade = clampf(minf(x - r * 0.5, size.x - r * 0.5 - x) / r, 0.0, 1.0)
		_shine.visible = fade > 0.0
		_shine.position = Vector2(x, 0.0)
		_shine.modulate.a = fade
		var badge: bool = owner_button.show_badge
		_disc.visible = badge
		_mark.visible = badge
		if badge:
			var pulse: float = 1.0 + 0.12 * maxf(sin(t * 5.0), 0.0)
			_disc.scale = Vector2(pulse, pulse)


## Üst katmanın bir kez çizilen parçası.
class _Shape:
	extends Node2D
	const SHINE: int = 0
	const DISC: int = 1
	const MARK: int = 2
	var what: int
	var extent: float = 0.0   # SHINE: düğme yüksekliği
	var font: Font

	func _init(what_value: int) -> void:
		what = what_value

	func _draw() -> void:
		match what:
			SHINE:
				if extent <= 0.0:
					return
				var w: float = extent * 0.35
				draw_colored_polygon(PackedVector2Array([
					Vector2(0.0, 4.0), Vector2(w, 4.0),
					Vector2(w - extent * 0.4, extent - 5.0), Vector2(-extent * 0.4, extent - 5.0)]),
					Color(1.0, 1.0, 1.0, 0.35))
			DISC:
				draw_circle(Vector2.ZERO, 10.0, Color("A42E35"), true, -1.0, true)
				draw_circle(Vector2.ZERO, 8.5, Color("E2474F"), true, -1.0, true)
			MARK:
				if font == null:
					return
				var w2: float = font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
				draw_string(font, Vector2(-w2 * 0.5, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
