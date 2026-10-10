class_name CoachCard
extends HBoxContainer
## RIZA USTA'NIN KARTI — eğitim adımının metni. Solda ustanın yuvarlak rozeti (kodla çizilen yüz:
## kasket, bıyık), sağda plaka: adım çipi, başlık, yazı yazılıyormuş gibi akan metin, adım noktaları,
## GEÇ ve (adım bir düğmeyle ilerliyorsa) eylem düğmesi. Yazı akarken karta dokunmak metni tamamlar.
## Kodla kurulur (.tscn yok); TutorialOverlay sahibidir.

## Eylem düğmesine (İLERİ / TAMAM / HAZIRIM) basıldı.
signal action_pressed
## GEÇ: oyuncu bu dersi geçmek istiyor.
signal skip_pressed

const BODY_WIDTH: float = 390.0
const TITLE_SIZE: int = 22
const BODY_SIZE: int = 17
## Yazı akış hızı (sn / harf).
const TYPE_SPEED: float = 0.018

var sfx: TutorialSfx

var _badge: _Badge
var _chip: Label
var _title: Label
var _body: Label
var _dots: _Dots
var _skip: PlateButton
var _action: PlateButton
var _type_tween: Tween
var _shown_chars: int = 0


func _ready() -> void:
	name = "CoachCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override(&"separation", -22)
	_badge = _Badge.new()
	_badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_badge.z_index = 1
	add_child(_badge)

	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.mouse_filter = Control.MOUSE_FILTER_STOP   # karta dokunuş dünyaya sızmasın
	plate.gui_input.connect(_on_plate_input)
	add_child(plate)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", 26)
	margin.add_theme_constant_override(&"margin_right", 6)
	margin.add_theme_constant_override(&"margin_top", 2)
	plate.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 4)
	margin.add_child(column)

	_chip = _label(&"HudInkCaption", "")
	_chip.add_theme_font_size_override(&"font_size", 12)
	_chip.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	column.add_child(_chip)
	_title = _label(&"HudSignTitle", "")
	_title.add_theme_font_size_override(&"font_size", TITLE_SIZE)
	column.add_child(_title)
	_body = _label(&"HudInkValue", "")
	_body.add_theme_font_size_override(&"font_size", BODY_SIZE)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(BODY_WIDTH, 0.0)
	column.add_child(_body)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	column.add_child(row)
	_skip = PlateButton.new()
	_skip.theme_type_variation = &"HudPlateSmall"
	_skip.text = Loc.t("DERSİ GEÇ")
	_skip.bolts = false
	_skip.focus_mode = Control.FOCUS_NONE
	_skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_skip.pressed.connect(func() -> void: skip_pressed.emit())
	row.add_child(_skip)
	_dots = _Dots.new()
	_dots.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_dots.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_dots)
	_action = PlateButton.new()
	_action.theme_type_variation = &"HudPlateSmall"
	_action.highlight = true
	_action.focus_mode = Control.FOCUS_NONE
	_action.custom_minimum_size = Vector2(120.0, 0.0)
	_action.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_action.pressed.connect(func() -> void:
		if _typing():
			_finish_typing()   # ilk dokunuş metni tamamlar, ikincisi ilerler
			return
		action_pressed.emit())
	row.add_child(_action)


## Kartı yeni adımın içeriğiyle doldurur ve yazıyı baştan akıtır.
## action "" ise düğme gizlenir (adım oyundaki bir eylemle ilerler).
func present(chip: String, title: String, body: String, action: String, index: int, count: int) -> void:
	_chip.text = chip
	_chip.visible = chip != ""
	_title.text = title
	_title.visible = title != ""
	_body.text = body
	_action.text = action
	_action.visible = action != ""
	_dots.count = count
	_dots.index = index
	_dots.visible = count > 1
	_start_typing()
	_badge.pop()


func _start_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	var total: int = _body.get_total_character_count()
	_body.visible_characters = 0
	_shown_chars = 0
	_badge.talking = true
	_type_tween = create_tween()
	_type_tween.tween_method(func(v: float) -> void:
		var shown: int = int(v)
		if shown != _shown_chars:
			_shown_chars = shown
			_body.visible_characters = shown
			if sfx and shown % 2 == 0:
				sfx.type_tick(), 0.0, float(total), float(total) * TYPE_SPEED)
	_type_tween.tween_callback(_finish_typing)


func _typing() -> bool:
	return _body.visible_characters >= 0 and _body.visible_characters < _body.get_total_character_count()


func _finish_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	_body.visible_characters = -1
	_badge.talking = false


func _on_plate_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tapped and _typing():
		_finish_typing()
		accept_event()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Rıza Usta: gök mavisi yuvarlak tabelada kasketli, bıyıklı usta yüzü; altında isim şeridi.
## Konuşurken (yazı akarken) hafifçe sallanır.
class _Badge extends Control:
	const RADIUS: float = 42.0
	const SKIN: Color = Color("F2C49B")
	const SKIN_SHADE: Color = Color("D9A57A")
	const CAP: Color = Color("2F6FB0")
	const CAP_DARK: Color = Color("214F80")
	const MUSTACHE: Color = Color("5B3A29")

	var talking: bool = false
	var _t: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(RADIUS * 2.0 + 8.0, RADIUS * 2.0 + 24.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func pop() -> void:
		pivot_offset = Vector2(size.x * 0.5, RADIUS + 4.0)
		scale = Vector2.ONE * 0.4
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	func _process(delta: float) -> void:
		_t += delta
		rotation = sin(_t * 16.0) * 0.045 if talking else lerpf(rotation, 0.0, 1.0 - exp(-10.0 * delta))
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = Vector2(size.x * 0.5, RADIUS + 4.0)
		# Tabela: gölge, koyu kenar, krem çember, gök mavisi zemin
		draw_circle(c + Vector2(0.0, 4.0), RADIUS + 3.0, HudPalette.SHADOW)
		draw_circle(c, RADIUS + 3.0, HudPalette.PLATE_SELECTED_EDGE)
		draw_circle(c, RADIUS, HudPalette.PLATE_SELECTED)
		draw_circle(c, RADIUS - 5.0, HudPalette.GLASS)
		# Omuzlar (iş tulumu)
		draw_colored_polygon(_clip_to_circle(c, RADIUS - 5.0, c + Vector2(0.0, 44.0), 30.0), CAP)
		# Kulaklar, yüz
		draw_circle(c + Vector2(-19.0, 6.0), 5.5, SKIN_SHADE)
		draw_circle(c + Vector2(19.0, 6.0), 5.5, SKIN_SHADE)
		draw_circle(c + Vector2(0.0, 6.0), 19.0, SKIN)
		# Kasket: kubbe + siper
		var dome: PackedVector2Array = PackedVector2Array()
		for i: int in 17:
			dome.append(c + Vector2(0.0, -2.0) + Vector2.from_angle(PI + PI * float(i) / 16.0) * Vector2(20.5, 17.0))
		draw_colored_polygon(dome, CAP)
		draw_rect(Rect2(c + Vector2(-20.5, -4.0), Vector2(41.0, 5.0)), CAP_DARK)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-6.0, -2.0), c + Vector2(24.0, -2.0),
			c + Vector2(27.0, 2.5), c + Vector2(-6.0, 2.5)]), CAP_DARK)
		draw_circle(c + Vector2(0.0, -18.0), 2.5, HudPalette.PLATE_SELECTED)
		# Gözler (göz kırpar), yanaklar, burun
		var blink: bool = fmod(_t, 3.6) > 3.45
		for x: float in [-7.0, 7.0]:
			if blink:
				draw_line(c + Vector2(x - 2.5, 5.0), c + Vector2(x + 2.5, 5.0), HudPalette.INK, 2.0, true)
			else:
				draw_circle(c + Vector2(x, 5.0), 2.4, HudPalette.INK)
			draw_circle(c + Vector2(x * 1.6, 11.0), 3.2, Color(0.95, 0.5, 0.45, 0.35))
		draw_circle(c + Vector2(0.0, 10.0), 3.4, SKIN_SHADE)
		# Bıyık: iki kıvrık yarım ay; konuşurken altında ağız açılıp kapanır
		var mouth: float = absf(sin(_t * 14.0)) * 3.0 if talking else 0.0
		draw_circle(c + Vector2(0.0, 18.5), 2.0 + mouth, Color("7A3B2E"))
		for side: float in [-1.0, 1.0]:
			var points: PackedVector2Array = PackedVector2Array()
			for i: int in 9:
				var k: float = float(i) / 8.0
				points.append(c + Vector2(side * lerpf(1.0, 13.0, k), 14.0 + sin(k * PI) * -1.5 + k * k * 3.0))
			for i: int in range(8, -1, -1):
				var k: float = float(i) / 8.0
				points.append(c + Vector2(side * lerpf(1.0, 13.0, k), 14.0 + lerpf(4.5, 1.0, k) + k * k * 3.0))
			draw_colored_polygon(points, MUSTACHE)
		# İsim şeridi
		var font: Font = get_theme_default_font()
		var label: String = Loc.t("RIZA USTA")
		var font_size: int = 12
		var width: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 16.0
		var ribbon: Rect2 = Rect2(Vector2(c.x - width * 0.5, c.y + RADIUS - 6.0), Vector2(width, 18.0))
		draw_rect(Rect2(ribbon.position + Vector2(0.0, 2.0), ribbon.size), HudPalette.SHADOW)
		draw_rect(ribbon, HudPalette.INK)
		draw_string(font, Vector2(ribbon.position.x + 8.0, ribbon.position.y + 13.5), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudPalette.TEXT_LIGHT)

	## Omuz dairesinin tabela dairesi içinde kalan kısmı (çokgen yaklaşık).
	func _clip_to_circle(c: Vector2, r: float, oc: Vector2, orad: float) -> PackedVector2Array:
		var out: PackedVector2Array = PackedVector2Array()
		for i: int in 48:
			var p: Vector2 = oc + Vector2.from_angle(TAU * float(i) / 48.0) * orad
			if p.distance_to(c) > r:
				p = c + (p - c).normalized() * r
			out.append(p)
		return out


## Adım noktaları: geçilen adımlar dolu amber, şimdiki biraz büyük, kalanlar boş halka.
class _Dots extends Control:
	var count: int = 0:
		set(value):
			count = value
			custom_minimum_size = Vector2(float(maxi(count, 1)) * 16.0, 14.0)
			queue_redraw()
	var index: int = 0:
		set(value):
			index = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var start: float = size.x * 0.5 - float(count - 1) * 8.0
		for i: int in count:
			var p: Vector2 = Vector2(start + float(i) * 16.0, size.y * 0.5)
			if i < index:
				draw_circle(p, 4.0, HudPalette.PLATE_SELECTED_EDGE)
			elif i == index:
				draw_circle(p, 6.0, HudPalette.PLATE_SELECTED)
				draw_arc(p, 6.0, 0.0, TAU, 20, HudPalette.PLATE_SELECTED_EDGE, 1.5, true)
			else:
				draw_arc(p, 4.0, 0.0, TAU, 16, HudPalette.PLATE_EDGE, 1.5, true)
