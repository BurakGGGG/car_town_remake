class_name GemShopButton
extends Button
## HUD'un MARKET düğmesi (eski adı GEM AL) — 2026-10-23 alt bar taslağıyla sağ üstte, tabelaların altında: oyunun krem
## plakası (PLAYER plakası gibi, altta kalınlık kenarı), solda plakadan taşan 2B elmas + altın çizimi, koyu yazı; birkaç
## saniyede bir "nefes alma" büyümesi. Başlangıç paketi alınmadıysa sağ üstte kırmızı "!" rozeti.
## Kodla kurulur (Hud._setup_gem_store); basınca `pressed` → mağaza.

const HEIGHT: float = 44.0
const PULSE_EVERY: float = 4.0
## Çizim plakanın solundan ve üstünden taşar (yükselen ikon dili).
const ART_SIZE: Vector2 = Vector2(56.0, 46.7)
const ART_SLOT: float = 50.0

## Sağ üstte rozet gösterilsin mi (tek seferlik paket hâlâ alınabilir).
var show_badge: bool = false:
	set(value):
		show_badge = value
		_overlay.animate()

var _art: TextureRect
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
	add_theme_stylebox_override(&"normal", _style(HudPalette.PLATE))
	add_theme_stylebox_override(&"hover", _style(HudPalette.PLATE_HOVER))
	add_theme_stylebox_override(&"pressed", _style(HudPalette.PLATE.darkened(0.06)))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())

	var row: HBoxContainer = HBoxContainer.new()
	_row = row
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 4)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(row)
	var pad: Control = Control.new()
	pad.custom_minimum_size = Vector2(ART_SLOT, 0.0)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(pad)
	var label: Label = Label.new()
	label.text = Loc.t("MARKET")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"HudOutlined"
	label.add_theme_font_size_override(&"font_size", 16)
	label.add_theme_color_override(&"font_color", HudPalette.INK)
	label.add_theme_constant_override(&"outline_size", 0)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	row.add_child(label)
	var tail: Control = Control.new()
	tail.custom_minimum_size = Vector2(14.0, 0.0)
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(tail)

	_art = TextureRect.new()
	_art.texture = load("res://ui/hud/art/nav/market.svg") as Texture2D
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.size = ART_SIZE
	_art.position = Vector2(-2.0, HEIGHT - 4.0 - ART_SIZE.y)
	add_child(_art)

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


## Krem plaka: altta kalınlık kenarı (oyunun plaka dili), cıvatalar _Overlay'da.
static func _style(bg: Color) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = HudPalette.PLATE_EDGE
	sb.border_width_bottom = 4
	sb.set_corner_radius_all(9)
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.15)
	sb.shadow_size = 1
	sb.shadow_offset = Vector2(0.0, 2.0)
	sb.anti_aliasing = true
	return sb


## Üst katman: sağdaki cıvata ve rozet. Yazının ÜSTÜNDE çizilir; rozet nabzı alt öğenin ölçeğiyle oynar (her karede
## yeni çizim yok).
class _Overlay:
	extends Control
	var owner_button: GemShopButton
	var _disc: _Shape
	var _mark: _Shape

	func _ready() -> void:
		_disc = _Shape.new(_Shape.DISC)
		_mark = _Shape.new(_Shape.MARK)
		_mark.font = get_theme_default_font()
		for shape: _Shape in [_disc, _mark]:
			add_child(shape)
		resized.connect(_layout)
		_layout()

	func _layout() -> void:
		_disc.position = Vector2(size.x - 4.0, 3.0)
		_mark.position = _disc.position
		queue_redraw()
		animate()

	func _draw() -> void:
		draw_circle(Vector2(size.x - 9.0, (size.y - 4.0) * 0.5), 2.4, HudPalette.PLATE_EDGE, true, -1.0, true)

	## Rozet dairesi nabız atar, "!" sabit boyda kalır.
	func animate() -> void:
		if _disc == null:
			return
		var t: float = owner_button._t
		var badge: bool = owner_button.show_badge
		_disc.visible = badge
		_mark.visible = badge
		if badge:
			var pulse: float = 1.0 + 0.12 * maxf(sin(t * 5.0), 0.0)
			_disc.scale = Vector2(pulse, pulse)


## Üst katmanın bir kez çizilen parçası.
class _Shape:
	extends Node2D
	const DISC: int = 1
	const MARK: int = 2
	var what: int
	var font: Font

	func _init(what_value: int) -> void:
		what = what_value

	func _draw() -> void:
		match what:
			DISC:
				draw_circle(Vector2.ZERO, 10.0, Color("A42E35"), true, -1.0, true)
				draw_circle(Vector2.ZERO, 8.5, Color("E2474F"), true, -1.0, true)
			MARK:
				if font == null:
					return
				var w2: float = font.get_string_size("!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
				draw_string(font, Vector2(-w2 * 0.5, 5.0), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color.WHITE)
