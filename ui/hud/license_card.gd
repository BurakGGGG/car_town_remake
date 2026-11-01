class_name LicenseCard
extends VBoxContainer
## SOL ÜST PROFİL: SÜRÜCÜ BELGESİ (2026-11-01, kullanıcı taslak B'yi seçti; tuval
## https://claude.ai/artifact/M3bazLWzg6uQJzXWJTpg7w). Kart: solda mavi ülke kodu şeridi (set_country), fotoğraf yerinde avatar
## (Hud'un AvatarButton'ı, avatar_slot'a konur), "1." takma ad, "9. SINIF" + koyu seviye çipi + araba, "SONRAKİ SINIF %62"
## ve mavi ilerleme çubuğu. Altında krem şeritte para · elmas (Hud'un sahnedeki CoinBox / GemBox
## düğümleri currency'ye taşınır: uçan para hedefi, MARKET dokunuşu, test parası olduğu gibi çalışır).
## Karta dokunmak `pressed` yayar (Hud profili açar). Bütün düzen konteynerlerle; renkler ve çizim _Backdrop'ta.

signal pressed

const BAND: float = 18.0
const BAND_COLOR: Color = Color("2F62C0")
const PAPER: Color = Color("F6EBDD")
const PAPER_PINK: Color = Color(0.984, 0.906, 0.933, 0.85)
const PAPER_BLUE: Color = Color(0.914, 0.945, 0.965, 0.75)
const FIELD: Color = Color("8A7A5A")
const NAME_MAX_WIDTH: float = 128.0

var avatar_slot: CenterContainer
var currency: HBoxContainer
var _name: Label
var _level: Label
var _xp_caption: Label
var _xp_bar: _XpBar
var _field_font: FontVariation
var _backdrop: _Backdrop


func _init() -> void:
	name = "LicenseCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 4)


func _ready() -> void:
	_field_font = FontVariation.new()
	_field_font.base_font = get_theme_default_font()
	_field_font.variation_embolden = 0.6
	_field_font.spacing_glyph = 1
	_build()


## Uzun ad (16 harfe kadar) önce KÜÇÜLÜR (NAME_SIZE → NAME_MIN_SIZE), yine sığmazsa NAME_MAX_WIDTH'te "…" ile kısalır:
## kart dar tuvalde ortadaki etkinlik şeridine uzanmasın. (İlk sürüm hep kısaltıyordu: İngilizce / Almanca / İspanyolca /
## Fransızca havuz adlarının çoğu "CHEEKYWREN…" gibi kesik görünüyordu.)
const NAME_SIZE: int = 15
const NAME_MIN_SIZE: int = 10


func set_player_name(value: String) -> void:
	_name.text = value.to_upper()
	var font: Font = _name.get_theme_font(&"font")
	var size: int = NAME_SIZE
	var width: float = NAME_MAX_WIDTH
	if font:
		width = font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		while width > NAME_MAX_WIDTH and size > NAME_MIN_SIZE:
			size -= 1
			width = font.get_string_size(_name.text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	_name.add_theme_font_size_override(&"font_size", size)
	_name.custom_minimum_size.x = minf(ceilf(width) + 2.0, NAME_MAX_WIDTH)


## Mavi şeritteki ülke kodu (AB ehliyeti gibi): oyuncunun profilde seçtiği bayrak, seçmediyse cihazın bölgesi
## (OS.get_locale "de_DE" → DE) bayrak listesindeyse; ikisi de yoksa şeritte yalnız noktalı halka. 2026-11-01'e kadar
## herkese "TR" yazıyordu.
func set_country(flag_code: String) -> void:
	var code: String = flag_code
	if code.is_empty():
		var locale: String = OS.get_locale()
		var region: String = locale.get_slice("_", 1).left(2).to_upper() if locale.contains("_") else ""
		code = region if ProfileCatalog.is_flag(region) else ""
	_backdrop.country = code


func set_level(value: int) -> void:
	_level.text = Loc.t("SV %d") % value


func set_xp_ratio(value: float) -> void:
	_xp_bar.ratio = clampf(value, 0.0, 1.0)
	_xp_caption.text = Loc.t("SONRAKİ SINIF %s") % Loc.percent(str(int(floor(_xp_bar.ratio * 100.0))))


func _build() -> void:
	var card: PanelContainer = PanelContainer.new()
	card.name = "Card"
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	card.add_theme_stylebox_override(&"panel", StyleBoxEmpty.new())
	add_child(card)
	_backdrop = _Backdrop.new()
	card.add_child(_backdrop)
	var tap: Button = Button.new()   # içerikteki yazılar fareyi geçirir: karta dokunmak profili açar (avatar kendi düğmesi)
	tap.name = "Tap"
	tap.flat = true
	tap.focus_mode = Control.FOCUS_NONE
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		tap.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	tap.pressed.connect(func() -> void: pressed.emit())
	card.add_child(tap)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override(&"margin_left", int(BAND) + 6)
	margin.add_theme_constant_override(&"margin_right", 12)
	margin.add_theme_constant_override(&"margin_top", 3)
	margin.add_theme_constant_override(&"margin_bottom", 4)
	card.add_child(margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	margin.add_child(row)
	avatar_slot = CenterContainer.new()
	avatar_slot.name = "AvatarSlot"
	avatar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(avatar_slot)

	var info: VBoxContainer = VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override(&"separation", 1)
	row.add_child(info)
	info.add_child(_field(Loc.t("SÜRÜCÜ BELGESİ") + " · AUTO YARD", 7))

	var name_row: HBoxContainer = _hbox(3)
	name_row.add_child(_field("1.", 8))
	_name = Label.new()
	_name.name = "Name"
	_name.theme_type_variation = &"HudPlateTitle"
	_name.add_theme_font_size_override(&"font_size", NAME_SIZE)
	_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name.clip_text = true
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.custom_minimum_size = Vector2(0.0, 20.0)
	name_row.add_child(_name)
	info.add_child(name_row)

	var class_row: HBoxContainer = _hbox(4)
	class_row.add_child(_field("9. " + Loc.t("SINIF"), 8))
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var chip_box: StyleBoxFlat = StyleBoxFlat.new()
	chip_box.bg_color = HudPalette.INK
	chip_box.set_corner_radius_all(3)
	chip_box.content_margin_left = 5.0
	chip_box.content_margin_right = 5.0
	chip.add_theme_stylebox_override(&"panel", chip_box)
	_level = Label.new()
	_level.name = "Level"
	_level.theme_type_variation = &"HudInkValue"
	_level.add_theme_color_override(&"font_color", HudPalette.COIN)
	_level.add_theme_font_size_override(&"font_size", 11)
	_level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_child(_level)
	class_row.add_child(chip)
	var car: HudIcon = HudIcon.new()
	car.kind = HudIcon.Kind.CAR
	car.icon_size = 13.0
	car.color = HudPalette.INK
	car.cutout = PAPER
	class_row.add_child(car)
	info.add_child(class_row)

	_xp_caption = _field("", 7)
	info.add_child(_xp_caption)
	_xp_bar = _XpBar.new()
	_xp_bar.custom_minimum_size = Vector2(0.0, 5.0)
	info.add_child(_xp_bar)

	var strip_row: MarginContainer = MarginContainer.new()   # para şeridi kartın kâğıt kısmıyla hizalı
	strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_row.add_theme_constant_override(&"margin_left", int(BAND))
	strip_row.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_child(strip_row)
	var strip: PanelContainer = PanelContainer.new()
	strip.name = "Currency"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var plate: StyleBoxFlat = StyleBoxFlat.new()
	plate.bg_color = HudPalette.PLATE
	plate.border_color = HudPalette.PLATE_EDGE
	plate.set_border_width_all(2)
	plate.set_corner_radius_all(6)
	plate.shadow_color = HudPalette.SHADOW
	plate.shadow_offset = Vector2(0.0, 2.0)
	plate.shadow_size = 1
	plate.content_margin_left = 7.0
	plate.content_margin_right = 9.0
	plate.content_margin_top = 1.0
	plate.content_margin_bottom = 1.0
	strip.add_theme_stylebox_override(&"panel", plate)
	strip_row.add_child(strip)
	currency = _hbox(8)
	strip.add_child(currency)


## Para şeridine Hud'un para / elmas kutularını taşır (aralarına ince ayraç). Yazılar koyu mürekkep olur (krem zemin).
func take_currency(coin_box: Control, gem_box: Control) -> void:
	for box: Control in [coin_box, gem_box]:
		box.reparent(currency, false)
		for child: Node in box.get_children():
			if child is Label:
				(child as Label).theme_type_variation = &"HudInkValue"
	var divider: ColorRect = ColorRect.new()
	divider.color = HudPalette.PLATE_EDGE
	divider.custom_minimum_size = Vector2(2.0, 13.0)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	currency.add_child(divider)
	currency.move_child(divider, 1)


func _field(text: String, size: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override(&"font", _field_font)
	label.add_theme_font_size_override(&"font_size", size)
	label.add_theme_color_override(&"font_color", FIELD)
	return label


func _hbox(separation: int) -> HBoxContainer:
	var box: HBoxContainer = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	box.add_theme_constant_override(&"separation", separation)
	return box


## Kartın kâğıdı: gölge, açık krem zemin (solda pembe, sağda mavi hafif tül), mavi şerit (noktalı halka + "TR"), kenar.
## (Taslaktaki silik barkod XP çubuğunun ucuna biniyordu, kaldırıldı.) Tek çizim, içerik yazıları üstünde.
class _Backdrop:
	extends Control
	var country: String = "":
		set(value):
			country = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var paper: StyleBoxFlat = StyleBoxFlat.new()
		paper.bg_color = LicenseCard.PAPER
		paper.border_color = HudPalette.PLATE_EDGE
		paper.set_border_width_all(2)
		paper.set_corner_radius_all(8)
		paper.shadow_color = HudPalette.SHADOW
		paper.shadow_offset = Vector2(0.0, 3.0)
		paper.shadow_size = 1
		paper.anti_aliasing = true
		paper.draw(get_canvas_item(), r)
		# tül: şeritten sağa pembe → krem → mavi (köşelere değmeden)
		var x0: float = LicenseCard.BAND + 2.0
		var x1: float = size.x - 9.0
		var xm: float = lerpf(x0, x1, 0.55)
		var y0: float = 2.0
		var y1: float = size.y - 2.0
		var clear: Color = Color(LicenseCard.PAPER, 0.0)
		draw_polygon(PackedVector2Array([Vector2(x0, y0), Vector2(xm, y0), Vector2(xm, y1), Vector2(x0, y1)]),
			PackedColorArray([LicenseCard.PAPER_PINK, clear, clear, LicenseCard.PAPER_PINK]))
		draw_polygon(PackedVector2Array([Vector2(xm, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(xm, y1)]),
			PackedColorArray([clear, LicenseCard.PAPER_BLUE, LicenseCard.PAPER_BLUE, clear]))
		var band: StyleBoxFlat = StyleBoxFlat.new()
		band.bg_color = LicenseCard.BAND_COLOR
		band.corner_radius_top_left = 6
		band.corner_radius_bottom_left = 6
		band.anti_aliasing = true
		band.draw(get_canvas_item(), Rect2(2.0, 2.0, LicenseCard.BAND, size.y - 4.0))
		var ring_c: Vector2 = Vector2(2.0 + LicenseCard.BAND * 0.5, 13.0)
		for i: int in 10:   # noktalı amber halka
			var a: float = TAU * i / 10.0
			draw_arc(ring_c, 5.0, a, a + TAU / 20.0, 3, HudPalette.COIN, 1.6, true)
		if not country.is_empty():
			var font: Font = get_theme_default_font()
			var w: float = font.get_string_size(country, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(font, Vector2(2.0 + (LicenseCard.BAND - w) * 0.5, size.y - 8.0), country,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.WHITE)


## Mavi ilerleme çubuğu (açık kahve iz üstünde).
class _XpBar:
	extends Control
	var ratio: float = 0.0:
		set(value):
			ratio = value
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var track: StyleBoxFlat = StyleBoxFlat.new()
		track.bg_color = Color("D9CDB4")
		track.set_corner_radius_all(3)
		track.anti_aliasing = true
		track.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))
		if ratio > 0.0:
			var fill: StyleBoxFlat = StyleBoxFlat.new()
			fill.bg_color = LicenseCard.BAND_COLOR
			fill.set_corner_radius_all(3)
			fill.anti_aliasing = true
			fill.draw(get_canvas_item(), Rect2(0.0, 0.0, maxf(size.x * ratio, 5.0), size.y))
