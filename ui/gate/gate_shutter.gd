class_name GateShutter
extends Control
## KEPENK — bakım / güncelleme ekranı (2026-10-25, kullanıcının seçtiği taslak B). Ekranın üstüne garaj kepengi iner:
## üstte kepenk kutusu, iki yanda ray, oluklu kanat; ortada zincirle asılı krem tabela (etiket, büyük başlık, metin,
## süre hapı), altında düğmeler ve kısa not.
##   BAKIM        kepenk tam iner, altında sarı-siyah şerit, yanlarda trafik konisi ve takım çantası
##   GÜNCELLEME   kepenk yarıda durur, altından garaj ışığı sızar (zorunlu ve YENİ SÜRÜM VAR aynı görünüm)
## Yükleme ekranında slaytın üstüne (logo görünür kalır), oyunda dünyanın üstüne iner. Açılış: kepenk iner, sonra tabela
## belirir; kapanış (leave): tabela söner, kepenk kalkar. Tam ekran STOP: dokunuş alttakine geçmez. AppGate kurar.

enum Mode { MAINTENANCE, UPDATE }

const DIM: float = 0.45
const SLAT: float = 22.0
const SLAT_FACE: Color = Color("A3AAB1")
const SLAT_GROOVE: Color = Color("7A8188")
const SLAT_SHINE: Color = Color("B4BAC0")
const RAIL: Color = Color("50565C")
const HOUSING: Color = Color("3A3F44")
const HOUSING_EDGE: Color = Color("24282C")
const TEAL: Color = Color("3D6E72")
const ALERT: Color = Color("C0392B")
const CONE: Color = Color("F08A2C")
const CONE_DARK: Color = Color("D9662A")
## Güncellemede kepenk tabelanın bu kadar altında durur (düğmeler altındaki ışıkta); tabela yokken ekranın RAISED oranı.
const RAISED_GAP: float = 14.0
const RAISED: float = 0.74

var mode: Mode = Mode.MAINTENANCE
## Ayrılıyor (kepenk kalkıyor): testler / QA yeni pencereyle karıştırmasın.
var leaving: bool = false

var _drop: float = 0.0:   # 0 = kepenk yukarıda, 1 = yerinde
	set(value):
		_drop = value
		queue_redraw()
var _margin: MarginContainer
var _column: VBoxContainer
var _sign: PanelContainer
var _chip: PanelContainer
var _buttons: HBoxContainer


func _init(shutter_mode: Mode, tag: String, title: String, body: String, chip: String, footer: String) -> void:
	mode = shutter_mode
	name = "GateShutter"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken alttakine dokunuş gitmez
	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override(&"separation", 10)
	_column.modulate.a = 0.0
	_margin.add_child(_column)
	_build_sign(tag, title, body, chip)
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override(&"separation", 12)
	_column.add_child(_buttons)
	if not footer.is_empty():
		var note: Label = _label(&"HudOutlined", footer, 12)
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_column.add_child(note)
	resized.connect(_layout)


func _ready() -> void:
	_layout()
	var tween: Tween = create_tween()
	tween.tween_property(self, "_drop", 1.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_column, "modulate:a", 1.0, 0.2)


## Tabelanın altına düğme ekler (sırayla, ortalı). primary: amber.
func add_button(text: String, primary: bool, on_pressed: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlate" if primary else &"HudPlateSmall"
	button.text = text
	button.highlight = primary
	button.custom_minimum_size = Vector2(220.0 if primary else 160.0, 50.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	_buttons.add_child(button)
	return button


## Süre hapının yazısı (bakımda tahmini dönüş); boşsa hap gizlenir.
func set_chip(text: String) -> void:
	(_chip.get_child(0) as Label).text = text
	_chip.visible = not text.is_empty()


## Tabela söner, kepenk kalkar, sonra düğüm serbest bırakılır.
func leave() -> void:
	if leaving:
		return
	leaving = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween: Tween = create_tween()
	tween.tween_property(_column, "modulate:a", 0.0, 0.12)
	tween.tween_property(self, "_drop", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


func _build_sign(tag: String, title: String, body: String, chip: String) -> void:
	_sign = PanelContainer.new()
	_sign.name = "Sign"
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = HudPalette.PLATE
	plate.set_border_width_all(3)
	plate.border_color = HudPalette.INK
	plate.set_corner_radius_all(12)
	plate.shadow_color = Color(0.0, 0.0, 0.0, 0.35)
	plate.shadow_size = 1
	plate.shadow_offset = Vector2(0.0, 5.0)
	plate.content_margin_left = 22.0
	plate.content_margin_right = 22.0
	plate.content_margin_top = 14.0
	plate.content_margin_bottom = 16.0
	_sign.add_theme_stylebox_override(&"panel", plate)
	_sign.rotation_degrees = -1.5 if mode == Mode.MAINTENANCE else 1.2
	_sign.resized.connect(func() -> void:
		_sign.pivot_offset = _sign.size * 0.5
		queue_redraw())
	_column.add_child(_sign)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	_sign.add_child(box)
	if not tag.is_empty():
		box.add_child(_pill(tag, TEAL, Color.WHITE, 12))
	var head: Label = _label(&"HudSignTitle", title, 36 if mode == Mode.MAINTENANCE else 30)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_theme_color_override(&"font_color", ALERT if mode == Mode.MAINTENANCE else HudPalette.INK)
	box.add_child(head)
	var text: Label = _label(&"HudInkCaption", body, 15)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(400.0, 0.0)
	box.add_child(text)
	_chip = _pill(chip, HudPalette.PLATE_SELECTED, HudPalette.INK, 13)
	_chip.name = "Chip"
	_chip.visible = not chip.is_empty()
	box.add_child(_chip)


## Kepenk ölçüleri ekrana göre; içerik kepenk kutusunun hemen altından başlar.
func _layout() -> void:
	var g: Dictionary = _geometry()
	_margin.add_theme_constant_override(&"margin_top", int(g["shutter_top"] + maxf(10.0, size.y * 0.03)))
	_margin.add_theme_constant_override(&"margin_left", int(g["left"]) + 8)
	_margin.add_theme_constant_override(&"margin_right", int(g["left"]) + 8)
	_margin.add_theme_constant_override(&"margin_bottom", 6)
	queue_redraw()


func _geometry() -> Dictionary:
	var w: float = size.x
	var h: float = size.y
	var mx: float = roundf(w * 0.085)
	var rail: float = maxf(roundf(w * 0.011), 8.0)
	var top: float = roundf(h * 0.29)
	var housing: float = maxf(roundf(h * 0.045), 16.0)
	return {"mx": mx, "rail": rail, "top": top, "housing": housing, "shutter_top": top + housing,
		"left": mx + rail, "width": w - 2.0 * (mx + rail)}


func _draw() -> void:
	var g: Dictionary = _geometry()
	var h: float = size.y
	var left: float = g["left"]
	var width: float = g["width"]
	var shutter_top: float = g["shutter_top"]
	var target: float = h if mode == Mode.MAINTENANCE else _raised_bottom(shutter_top)
	var bottom: float = lerpf(shutter_top, target, clampf(_drop, 0.0, 1.05))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.04, 0.05, 0.06, DIM * clampf(_drop, 0.0, 1.0)))
	if mode == Mode.UPDATE:   # yarı açık kepengin altından garaj ışığı
		draw_rect(Rect2(left, bottom, width, h - bottom), Color(HudPalette.COIN, 0.22 * clampf(_drop, 0.0, 1.0)))
	draw_rect(Rect2(g["mx"], shutter_top, g["rail"], h - shutter_top), RAIL)
	draw_rect(Rect2(left + width, shutter_top, g["rail"], h - shutter_top), RAIL)
	var y: float = shutter_top
	while y < bottom:
		draw_rect(Rect2(left, y, width, minf(SLAT, bottom - y)), SLAT_FACE)
		if y + SLAT - 1.0 < bottom:
			draw_rect(Rect2(left, y + SLAT - 3.0, width, 2.0), SLAT_GROOVE)
			draw_rect(Rect2(left, y + SLAT - 1.0, width, 1.0), SLAT_SHINE)
		y += SLAT
	if mode == Mode.MAINTENANCE:
		_hazard(Rect2(left, bottom - maxf(roundf(h * 0.065), 22.0), width, maxf(roundf(h * 0.065), 22.0)))
	else:
		draw_rect(Rect2(left, bottom - 10.0, width, 10.0), HOUSING)
		draw_rect(Rect2(left + width * 0.5 - 22.0, bottom, 44.0, 9.0), HudPalette.INK)
	var housing: StyleBoxFlat = StyleBoxFlat.new()
	housing.bg_color = HOUSING
	housing.set_corner_radius_all(6)
	housing.border_width_bottom = 3
	housing.border_color = HOUSING_EDGE
	draw_style_box(housing, Rect2(g["mx"] - g["rail"], g["top"], width + 4.0 * g["rail"], g["housing"]))
	if _drop > 0.6:
		_chains(shutter_top)
	if mode == Mode.MAINTENANCE and _drop > 0.9:
		var s: float = maxf(h * 0.2, 70.0)
		_cone(Vector2(left + s * 0.55, h - s * 0.5 - 2.0), s)
		_toolbox(Vector2(left + width - s * 0.6, h - s * 0.32 - 2.0), s * 0.8)


## Güncelleme kepengi: tabelanın hemen altında durur (düğmeler kepengin altındaki ışıkta kalsın).
func _raised_bottom(shutter_top: float) -> float:
	if _sign == null or _sign.size.y <= 0.0:
		return roundf(size.y * RAISED)
	var sign_bottom: float = _sign.global_position.y - global_position.y + _sign.size.y
	return clampf(roundf(sign_bottom + RAISED_GAP), shutter_top + 60.0, roundf(size.y * 0.86))


## Tabelayı kepenk kutusuna bağlayan iki zincir.
func _chains(from_y: float) -> void:
	if _sign == null or not _sign.is_visible_in_tree():
		return
	var r: Rect2 = Rect2(_sign.global_position - global_position, _sign.size)
	for x: float in [r.position.x + r.size.x * 0.18, r.position.x + r.size.x * 0.82]:
		var y: float = from_y
		while y < r.position.y + 4.0:
			draw_rect(Rect2(x - 2.0, y, 4.0, 5.0), HudPalette.INK)
			y += 7.0


## Sarı-siyah uyarı şeridi (eğik çizgiler banda kırpılır).
func _hazard(band: Rect2) -> void:
	draw_rect(band, HudPalette.INK)
	var step: float = band.size.y * 0.8
	var clip: PackedVector2Array = PackedVector2Array([band.position, band.position + Vector2(band.size.x, 0.0),
		band.end, band.position + Vector2(0.0, band.size.y)])
	var x: float = band.position.x - band.size.y
	while x < band.end.x:
		var stripe: PackedVector2Array = PackedVector2Array([Vector2(x, band.end.y), Vector2(x + step, band.end.y),
			Vector2(x + step + band.size.y, band.position.y), Vector2(x + band.size.y, band.position.y)])
		for part: PackedVector2Array in Geometry2D.intersect_polygons(stripe, clip):
			draw_colored_polygon(part, HudPalette.PLATE_SELECTED)
		x += step * 2.0


func _shape(points: PackedVector2Array, fill: Color) -> void:
	draw_colored_polygon(points, fill)
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, HudPalette.INK, 3.0, true)


## Trafik konisi: turuncu gövde, iki beyaz bant, taban.
func _cone(c: Vector2, s: float) -> void:
	var tip: Vector2 = c + Vector2(0.0, -0.45 * s)
	var bl: Vector2 = c + Vector2(-0.25 * s, 0.38 * s)
	var br: Vector2 = c + Vector2(0.25 * s, 0.38 * s)
	_shape(PackedVector2Array([tip, br, bl]), CONE)
	for band: Array in [[-0.12, -0.02], [0.12, 0.22]]:
		var t0: float = (float(band[0]) + 0.45) / 0.83
		var t1: float = (float(band[1]) + 0.45) / 0.83
		draw_colored_polygon(PackedVector2Array([tip.lerp(bl, t0), tip.lerp(br, t0), tip.lerp(br, t1), tip.lerp(bl, t1)]),
			Color.WHITE)
	var base: Rect2 = Rect2(c + Vector2(-0.33 * s, 0.36 * s), Vector2(0.66 * s, 0.1 * s))
	draw_rect(base, CONE_DARK)
	draw_rect(base, HudPalette.INK, false, 3.0)


## Takım çantası: kırmızı gövde, gri kapak, sap ve amber kilit.
func _toolbox(c: Vector2, s: float) -> void:
	var body: Rect2 = Rect2(c + Vector2(-0.45 * s, -0.12 * s), Vector2(0.9 * s, 0.48 * s))
	var lid: Rect2 = Rect2(c + Vector2(-0.32 * s, -0.3 * s), Vector2(0.64 * s, 0.2 * s))
	draw_rect(Rect2(c + Vector2(-0.09 * s, -0.42 * s), Vector2(0.18 * s, 0.14 * s)), HudPalette.INK)
	draw_rect(lid, Color("9AA3A8"))
	draw_rect(lid, HudPalette.INK, false, 3.0)
	draw_rect(body, ALERT)
	draw_rect(body, HudPalette.INK, false, 3.0)
	draw_line(body.position + Vector2(0.0, body.size.y * 0.35), body.position + Vector2(body.size.x, body.size.y * 0.35),
		HudPalette.INK, 3.0)
	var lock: Rect2 = Rect2(c + Vector2(-0.08 * s, 0.0), Vector2(0.16 * s, 0.13 * s))
	draw_rect(lock, HudPalette.PLATE_SELECTED)
	draw_rect(lock, HudPalette.INK, false, 2.0)


static func _pill(text: String, fill: Color, ink: Color, font_size: int) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(6)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override(&"panel", box)
	var label: Label = _label(&"HudInkCaption", text, font_size)
	label.add_theme_color_override(&"font_color", ink)
	pill.add_child(label)
	return pill


static func _label(variation: StringName, text: String, font_size: int) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
