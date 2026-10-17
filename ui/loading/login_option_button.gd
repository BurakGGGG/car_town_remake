class_name LoginOptionButton
extends Button
## Açılış giriş ekranının (LoginGate) hesap düğmesi: marka rengi zemin, koyu kalın çerçeve, içte ince
## açık kenar ve üst yarıda parlaklık (örnek tasarım: eksik_dosyalar/login_ornek.png). Yazılı düğmede
## solda logo + ince ayraç, sağda yazı (uzun dillerde iki satıra kırılır); yazısız (sıkı) düğmede logo
## ortada, altında küçük alt yazı. Görünüm tamamen kodla kurulur; oyunun krem plaka temasından ayrıdır.
##
## Hover stili yok (telefonda takılı kalır); basılınca düğme hafif küçülür ve koyulaşır.

const BORDER: Color = Color("141B2D")
const RADIUS: int = 13
const BORDER_WIDTH: int = 3
## Yazılı düğmede logonun kapladığı sol alan (ayraç bunun sağında çizilir).
const LOGO_AREA: float = 52.0
const LOGO_SIZE: float = 28.0
const PRESS_SCALE: float = 0.94

var _fill: Color
var _ink: Color
var _logo: Texture2D
var _compact: bool
var _label: Label


## fill: zemin, ink: yazı rengi (beyaz yazıya ince gölge verilir), compact: yazı logonun altında küçük.
func _init(fill: Color, ink: Color, logo: Texture2D, text_value: String, compact: bool = false) -> void:
	_fill = fill
	_ink = ink
	_logo = logo
	_compact = compact
	focus_mode = Control.FOCUS_NONE
	add_theme_stylebox_override(&"normal", _box(fill))
	add_theme_stylebox_override(&"hover", _box(fill))
	add_theme_stylebox_override(&"pressed", _box(fill.darkened(0.12)))
	add_theme_stylebox_override(&"hover_pressed", _box(fill.darkened(0.12)))
	add_theme_stylebox_override(&"disabled", _box(fill))
	add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	_build(text_value, compact)
	button_down.connect(_squash.bind(true))
	button_up.connect(_squash.bind(false))
	resized.connect(func() -> void: pivot_offset = size * 0.5)


func _box(color: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = BORDER
	box.set_border_width_all(BORDER_WIDTH)
	box.set_corner_radius_all(RADIUS)
	box.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0.0, 3.0)
	return box


func _build(text_value: String, compact: bool) -> void:
	var box: BoxContainer = VBoxContainer.new() if compact else HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.add_theme_constant_override(&"separation", 2 if compact else 0)
	if compact:
		box.alignment = BoxContainer.ALIGNMENT_CENTER
	else:
		box.offset_right = -10.0
	add_child(box)

	var logo: TextureRect = TextureRect.new()
	logo.texture = _logo
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if compact:
		logo.custom_minimum_size = Vector2(0.0, LOGO_SIZE - 4.0)
		box.add_child(logo)
	else:
		var holder: CenterContainer = CenterContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.custom_minimum_size = Vector2(LOGO_AREA, 0.0)
		logo.custom_minimum_size = Vector2(LOGO_SIZE, LOGO_SIZE)
		holder.add_child(logo)
		box.add_child(holder)

	_label = Label.new()
	_label.theme_type_variation = &"HudOutlined"
	_label.text = text_value
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 11 if compact else 15)
	_label.add_theme_color_override(&"font_color", _ink)
	_label.add_theme_constant_override(&"outline_size", 0)
	_label.add_theme_constant_override(&"line_spacing", -2)
	if _ink.get_luminance() > 0.5:
		_label.add_theme_color_override(&"font_shadow_color", Color(BORDER, 0.55))
		_label.add_theme_constant_override(&"shadow_offset_x", 0)
		_label.add_theme_constant_override(&"shadow_offset_y", 2)
	if not compact:
		_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_label.size_flags_vertical = Control.SIZE_FILL
	box.add_child(_label)


func _draw() -> void:
	var inner: Rect2 = Rect2(Vector2.ONE * BORDER_WIDTH, size - Vector2.ONE * BORDER_WIDTH * 2.0)
	# Üst yarı parlaklık
	var gloss: StyleBoxFlat = StyleBoxFlat.new()
	gloss.bg_color = Color(1.0, 1.0, 1.0, 0.07 if get_draw_mode() == DRAW_PRESSED else 0.13)
	gloss.corner_radius_top_left = RADIUS - BORDER_WIDTH
	gloss.corner_radius_top_right = RADIUS - BORDER_WIDTH
	draw_style_box(gloss, Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.46)))
	# İçte ince açık kenar (örnekteki kabarık plastik hissi)
	var rim: StyleBoxFlat = StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = Color(1.0, 1.0, 1.0, 0.38)
	rim.set_border_width_all(2)
	rim.set_corner_radius_all(RADIUS - BORDER_WIDTH)
	draw_style_box(rim, inner)
	# Logo ile yazı arası ayraç
	if not _compact:
		draw_line(Vector2(LOGO_AREA, size.y * 0.24), Vector2(LOGO_AREA, size.y * 0.76), Color(_ink, 0.3), 2.0)


## Basılınca hafif küçülür, bırakınca yerine yaylanır.
func _squash(down: bool) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK if not down else Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * (PRESS_SCALE if down else 1.0), 0.08 if down else 0.18)
