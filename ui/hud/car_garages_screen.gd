class_name CarGaragesScreen
extends Control
## GARAJLARIM panosu — garaj ekranının başlık plakasından açılır (UiRouter MODAL; garaj altta açık kalır).
## MERDİVEN + BÜYÜK ÖNİZLEME (C tasarımı, 2026-10-20): solda beş garajın sıra plakaları (1 MAHALLE … 5 HANGAR; durum
## satırı, inşaatta çekiç, seviye kilidinde kilit, bulunduğun garajda nişangâh), sağda seçili garajın fotoğrafı
## (tools/make_garage_cards.gd: araçsız iç mekân), park yeri şeridi, durum satırı, görünüm kalemlerinin yıldızları ve
## eylemler: alınmış (GİT / BURADASIN + İÇ YÜKSELTMELER), inşaatta (ELMASLA BİTİR, iki dokunuş), kilitli (SATIN AL /
## PARA YETERSİZ / SEVİYE GEREKLİ). Bekleyen araç varsa başlığın sağında uyarı plakası → BEKLEYENLER.
## Mantık yok: CarGarageManager okunur / çağrılır. Kararlar: docs/GARAJLAR_TASARIM.md §2, §6.
## Ekran TAMAMEN KODLA kurulur (.tscn yok).

signal closed
## GİT: garaj ekranı bu garaja geçer (pano kendini kapatır). CarGarageManager.WAITING = bekleme otoparkı.
signal garage_chosen(garage: StringName)
## İÇ YÜKSELTMELER panosu (UiRouter SUB) istendi.
signal upgrades_requested(garage: StringName)
## Elmas yetmedi: GEM MAĞAZASI.
signal gem_store_requested

const EDGE: float = 16.0
## Merdiven tuvalin bu payı kadar geniş (sınırlar arasında); plakaları KAPAT'a kadar boyu doldurur.
const LADDER_SHARE: float = 0.34
const LADDER_MIN: float = 272.0
const LADDER_MAX: float = 400.0
const TAB_HEIGHT: float = 46.0   # altı basamak (OTOPARK + 5 depo) telefonda KAPAT'la birlikte sığsın
const ACTION_WIDTH: float = 190.0
## Deponun fotoğrafı (tools/make_garage_cards.gd üretir); yoksa koyu zemin. OTOPARK çatı katı sahnesinin klasöründe.
const CARD_PATH: String = "res://assets/garages/%s/card.png"
## Fotoğrafın en küçük boyu; kalan yükseklik fotoğrafa gider (tablette büyür).
const PHOTO_MIN_HEIGHT: float = 140.0
## Geri sayımların yenilenme aralığı (sn).
const TICK: float = 0.5
## Bu genişlikten (tuval birimi) dar ekranda yıldız çipleri tek sütun: 16:9 telefon / tablette (853) iki sütunda
## "LİFT / PLATFORM" (DE "HEBEBÜHNE / PODEST") kesiliyordu; yükseklik tek sütuna yetiyor (fotoğraf küçülür).
const TWO_COLUMN_WIDTH: float = 1000.0
## Yıldızlı görünüm kalemleri (PARK YERİ şeritte).
const LOOK_ITEMS: Array[StringName] = [CarGarageCatalog.FLOOR, CarGarageCatalog.LIGHTS, CarGarageCatalog.WALLS,
	CarGarageCatalog.LIFT]
## Fotoğraf: seviye kilidinde gri + karanlık, inşaatta ve satılıkta karanlık.
const PHOTO_SHADER: String = """
shader_type canvas_item;
uniform float gray : hint_range(0.0, 1.0) = 0.0;
uniform float dark : hint_range(0.0, 1.0) = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float g = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	COLOR = vec4(mix(c.rgb, vec3(g), gray) * dark, c.a) * COLOR;
}
"""

var _title: Label
var _home_button: PlateButton
var _column: VBoxContainer
var _ladder: Control
## Merdiven: garaj id → {"button", "name", "status", "number", "icon", "badge" (StyleBoxFlat), "mark"}
var _tabs: Dictionary = {}
var _tab_group: ButtonGroup = ButtonGroup.new()
var _selected: StringName = &""
# Önizleme
var _photo: TextureRect
var _photo_material: ShaderMaterial
var _tape: Control
var _lock: Control
var _here_chip: Control
var _usage_chip: Control
var _usage_label: Label
var _name_label: Label
var _lane_row: Control
var _lane: XpLane
var _lane_value: Label
var _status: Label
var _stars: GridContainer
var _star_labels: Dictionary = {}   # kalem → Label
var _main: PlateButton
var _upgrades: PlateButton
var _cards: Dictionary = {}         # garaj id → Texture2D (pano açıkken; kapanınca bırakılır)
var _armed: Dictionary = {}         # garaj id → onay süresinin bittiği an (ms): ELMASLA BİTİR iki dokunuş
var _closing: bool = false
var _tick: float = 0.0
## Garaj ekranında bakılan garaj (HUD bağlar; boşsa her garajda GİT yazar).
var current_garage: Callable = Callable()
var _manager: CarGarageManager


func _ready() -> void:
	name = "CarGaragesScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_tab_group.allow_unpress = false
	_build()
	set_process(false)
	get_viewport().size_changed.connect(_fit_layout)


func open() -> void:
	_connect_manager()
	_armed.clear()
	_fit_layout()
	_select(_default_selection())
	_refresh()
	set_process(true)
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	set_process(false)
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_photo.texture = null
		_cards.clear()   # fotoğraflar pano kapalıyken bellekte durmaz
		_closing = false
		closed.emit())


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	_refresh()


## Merdivende seçili garaj.
func selected() -> StringName:
	return _selected


## Merdivende garajı seçer (eğitim: İÇ YÜKSELTMELER'i göstermek için alınmış garaja döner).
func select(garage: StringName) -> void:
	if _tabs.has(garage) and garage != _selected:
		_select(garage)


## Sıradaki edinilecek garaj (merdivende alınmamış ilk garaj; hepsi alınmışsa boş).
func next_garage() -> StringName:
	_connect_manager()
	if _manager == null:
		return &""
	for garage: StringName in CarGarageCatalog.ids():
		if _manager.status(garage) != CarGarageManager.Status.OWNED:
			return garage
	return &""


## Eğitim (DEPO DERSİ) çapaları: &"next" sıradaki deponun plakası, &"main" önizlemenin ana plakası,
## &"upgrades" İÇ YÜKSELTMELER, &"waiting" OTOPARK basamağı, &"home" GARAJIM düğmesi.
func tutorial_anchor(what: StringName) -> Control:
	match what:
		&"next":
			var garage: StringName = next_garage()
			return _tabs[garage]["button"] as Control if _tabs.has(garage) else null
		&"main":
			return _main
		&"upgrades":
			return _upgrades
		&"waiting":
			return _tabs[CarGarageManager.WAITING]["button"] as Control
		&"home":
			return _home_button
	return null


## Mantığı sınayan testler ve QA için: garajı SEÇER ve önizlemenin ana plakasını (SATIN AL / GİT / BİTİR) döndürür.
func main_button(garage: StringName) -> PlateButton:
	if not _tabs.has(garage):
		return null
	if garage != _selected:
		_select(garage)
	return _main


## "3:12:45" / "04:12".
static func clock_text(seconds: float) -> String:
	var s: int = maxi(ceili(seconds), 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", int(EDGE))
	margin.add_theme_constant_override(&"margin_right", int(EDGE))
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_bottom", 14)
	add_child(margin)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 10)
	margin.add_child(_column)

	# Başlık satırı: tabela ortada, solda GARAJIM'a dönüş (iki yan eşit genişleyip tabelayı ortada tutar)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 8)
	var left: HBoxContainer = HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_button = _button("", func() -> void: _choose(CarGarageManager.HOME))
	_home_button.name = "SeeHome"
	_home_button.kind = HudIcon.Kind.GARAGE
	_home_button.icon_left = true
	_home_button.icon_size = 16.0
	_home_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	left.add_child(_home_button)
	head.add_child(left)
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	_title = _label(&"HudSignTitle", Loc.t("DEPOLARIM"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	head.add_child(sign)
	var right: Control = Control.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(right)
	_column.add_child(head)

	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override(&"separation", 16)
	body.add_child(_build_ladder())
	body.add_child(_build_preview())
	_column.add_child(body)


## Sol: garaj merdiveni ve altında KAPAT. Beş plaka sütunun boyunu paylaşır (en küçük telefonda da sığar: 5 × 54).
func _build_ladder() -> Control:
	var ladder: VBoxContainer = VBoxContainer.new()
	ladder.name = "Ladder"
	ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ladder.custom_minimum_size = Vector2(LADDER_MIN, 0.0)
	ladder.add_theme_constant_override(&"separation", 10)
	var tabs: VBoxContainer = VBoxContainer.new()
	tabs.name = "Tabs"
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_constant_override(&"separation", 8)
	tabs.add_child(_tab(CarGarageManager.WAITING))   # OTOPARK: merdivenin ilk basamağı (sınırsız, ücretli)
	for garage: StringName in CarGarageCatalog.ids():
		tabs.add_child(_tab(garage))
	ladder.add_child(tabs)
	var close_button: PlateButton = _button(Loc.t("KAPAT"), close)
	ladder.add_child(close_button)
	_ladder = ladder
	return ladder


## Merdiven plakası: sıra rozeti (no / çekiç / kilit), ad, durum satırı, bulunduğun garajda nişangâh.
func _tab(garage: StringName) -> Control:
	var button: PlateButton = PlateButton.new()
	button.name = "Garage_%s" % garage
	button.theme_type_variation = &"HudPlate"
	button.toggle_mode = true
	button.button_group = _tab_group
	button.bolts = false
	button.lift_when_pressed = 0.0
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, TAB_HEIGHT)
	button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	button.toggled.connect(func(on: bool) -> void:
		if on:
			_select(garage))
	var pad: MarginContainer = MarginContainer.new()
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_theme_constant_override(&"margin_left", 10)
	pad.add_theme_constant_override(&"margin_right", 12)
	pad.add_theme_constant_override(&"margin_bottom", 3)   # plakanın alt kalınlığı
	button.add_child(pad)
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	pad.add_child(row)

	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.custom_minimum_size = Vector2(30.0, 30.0)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge_style: StyleBoxFlat = StyleBoxFlat.new()
	badge_style.bg_color = HudPalette.INK
	badge_style.set_corner_radius_all(15)
	badge_style.anti_aliasing = true
	badge.add_theme_stylebox_override(&"panel", badge_style)
	var number: Label = _label(&"HudInkValue", "P" if garage == CarGarageManager.WAITING else str(CarGarageCatalog.rank(garage) + 1))
	number.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	number.add_theme_font_size_override(&"font_size", 13)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(number)
	var icon: HudIcon = HudIcon.new()
	icon.icon_size = 16.0
	icon.color = HudPalette.TEXT_LIGHT
	icon.cutout = HudPalette.INK
	icon.visible = false
	badge.add_child(icon)
	row.add_child(badge)

	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.add_theme_constant_override(&"separation", 0)
	var title: Label = _label(&"HudPlateTitle", _place_name(garage))
	title.add_theme_font_size_override(&"font_size", 15)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var status: Label = _label(&"HudInkCaption", "")
	status.add_theme_font_size_override(&"font_size", 11)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	text.add_child(status)
	row.add_child(text)

	var mark: HudIcon = HudIcon.new()   # BURADASIN
	mark.kind = HudIcon.Kind.TARGET
	mark.icon_size = 16.0
	mark.color = HudPalette.INK
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mark.visible = false
	row.add_child(mark)
	_tabs[garage] = {"button": button, "name": title, "status": status, "number": number, "icon": icon,
		"badge": badge_style, "mark": mark}
	return button


## Sağ: seçili garajın fotoğrafı (üst üste katmanlar) ve altında bilgi + eylemler.
func _build_preview() -> Control:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "Preview"
	panel.theme_type_variation = &"HudCarPlate"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)

	# Fotoğraf katmanları: MarginContainer çocuklarını aynı dikdörtgene yayar
	var frame: MarginContainer = MarginContainer.new()
	frame.name = "Photo"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.clip_contents = true
	frame.custom_minimum_size = Vector2(0.0, PHOTO_MIN_HEIGHT)
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = ModWorkshop.TRAY_COLOR
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(backdrop)
	_photo = TextureRect.new()
	_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var shader: Shader = Shader.new()
	shader.code = PHOTO_SHADER
	_photo_material = ShaderMaterial.new()
	_photo_material.shader = shader
	_photo.material = _photo_material
	frame.add_child(_photo)
	frame.add_child(_bottom_shade())
	_tape = Control.new()   # inşaat şeridi
	_tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tape.draw.connect(_draw_tape)
	_tape.resized.connect(_tape.queue_redraw)
	frame.add_child(_tape)
	_lock = _lock_badge()
	frame.add_child(_lock)

	var overlay: MarginContainer = MarginContainer.new()
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		overlay.add_theme_constant_override(side, 12)
	var layers: VBoxContainer = VBoxContainer.new()
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_here_chip = _chip(HudPalette.PLATE_SELECTED, HudIcon.Kind.TARGET, HudPalette.INK)
	(_here_chip.get_node("Row/Text") as Label).text = Loc.t("BURADASIN")
	top.add_child(_here_chip)
	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_usage_chip = _chip(Color(HudPalette.INK, 0.9), HudIcon.Kind.CAR, HudPalette.TEXT_LIGHT)
	_usage_label = _usage_chip.get_node("Row/Text") as Label
	top.add_child(_usage_chip)
	layers.add_child(top)
	var fill: Control = Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layers.add_child(fill)
	_name_label = _label(&"HudOutlined", "")
	_name_label.add_theme_font_size_override(&"font_size", 26)
	_name_label.add_theme_constant_override(&"outline_size", 8)
	layers.add_child(_name_label)
	overlay.add_child(layers)
	frame.add_child(overlay)
	box.add_child(frame)

	# Bilgi: park yeri şeridi, durum satırı, yıldızlar · sağda eylemler
	var info: HBoxContainer = HBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_constant_override(&"separation", 16)
	var facts: VBoxContainer = VBoxContainer.new()
	facts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	facts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	facts.alignment = BoxContainer.ALIGNMENT_CENTER
	facts.add_theme_constant_override(&"separation", 6)
	var lane_row: HBoxContainer = HBoxContainer.new()
	lane_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lane_row.add_theme_constant_override(&"separation", 8)
	lane_row.add_child(_label(&"HudInkCaption", CarGarageCatalog.item_name(CarGarageCatalog.PARK)))
	_lane = XpLane.new()
	_lane.segments = 10
	_lane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lane.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lane_row.add_child(_lane)
	_lane_value = _label(&"HudInkValue", "")
	_lane_value.add_theme_font_size_override(&"font_size", 12)
	lane_row.add_child(_lane_value)
	_lane_row = lane_row
	facts.add_child(lane_row)
	_status = _label(&"HudInkCaption", "")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.add_child(_status)
	_stars = GridContainer.new()
	_stars.columns = 2
	_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stars.add_theme_constant_override(&"h_separation", 6)
	_stars.add_theme_constant_override(&"v_separation", 5)
	for item: StringName in LOOK_ITEMS:
		_stars.add_child(_star_chip(item))
	facts.add_child(_stars)
	info.add_child(facts)

	var actions: VBoxContainer = VBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.custom_minimum_size = Vector2(ACTION_WIDTH, 0.0)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override(&"separation", 8)
	_main = _button("", _on_main_pressed)
	_main.name = "Main"
	_main.icon_size = 16.0
	actions.add_child(_main)
	_upgrades = _button(Loc.t("İÇ YÜKSELTMELER"), func() -> void: upgrades_requested.emit(_selected))
	_upgrades.name = "Upgrades"
	_upgrades.kind = HudIcon.Kind.WRENCH
	_upgrades.icon_left = true
	_upgrades.icon_size = 16.0
	actions.add_child(_upgrades)
	info.add_child(actions)
	box.add_child(info)
	return panel


## Fotoğrafın altı koyulaşır: garajın adı her fotoğrafta okunsun.
func _bottom_shade() -> TextureRect:
	var gradient: Gradient = Gradient.new()
	gradient.offsets = PackedFloat32Array([0.45, 1.0])
	gradient.colors = PackedColorArray([Color(HudPalette.INK, 0.0), Color(HudPalette.INK, 0.75)])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 0.0)
	texture.fill_to = Vector2(0.0, 1.0)
	texture.width = 4
	texture.height = 64
	var shade: TextureRect = TextureRect.new()
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.texture = texture
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	return shade


## Seviye kilidi: fotoğrafın ortasında koyu daire + kilit.
func _lock_badge() -> Control:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var disc: PanelContainer = PanelContainer.new()
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.custom_minimum_size = Vector2(52.0, 52.0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(HudPalette.INK, 0.9)
	style.set_corner_radius_all(26)
	style.anti_aliasing = true
	disc.add_theme_stylebox_override(&"panel", style)
	var icon: HudIcon = HudIcon.new()
	icon.kind = HudIcon.Kind.LOCK
	icon.icon_size = 24.0
	icon.color = HudPalette.TEXT_LIGHT
	icon.cutout = HudPalette.INK
	disc.add_child(icon)
	center.add_child(disc)
	return center


## Fotoğraf üstü küçük etiket: renkli yuvarlak zemin, ikon + yazı ("Row/Text").
func _chip(bg: Color, kind: HudIcon.Kind, ink: Color) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(12)
	style.content_margin_left = 9.0
	style.content_margin_right = 10.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override(&"panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 5)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 13.0
	icon.color = ink
	icon.cutout = bg
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text: Label = _label(&"HudInkCaption", "")
	text.name = "Text"
	text.add_theme_color_override(&"font_color", ink)
	text.add_theme_font_size_override(&"font_size", 11)
	row.add_child(text)
	chip.add_child(row)
	return chip


## Görünüm kalemi: ad + ★★☆.
func _star_chip(item: StringName) -> PanelContainer:
	var chip: PanelContainer = PanelContainer.new()
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(HudPalette.INK, 0.07)
	style.set_corner_radius_all(5)
	style.content_margin_left = 9.0
	style.content_margin_right = 9.0
	style.content_margin_top = 3.0
	style.content_margin_bottom = 3.0
	chip.add_theme_stylebox_override(&"panel", style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	var title: Label = _label(&"HudInkCaption", CarGarageCatalog.item_name(item))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(title)
	var stars: Label = _label(&"HudInkValue", "")
	stars.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	stars.add_theme_font_size_override(&"font_size", 12)
	row.add_child(stars)
	chip.add_child(row)
	_star_labels[item] = stars
	return chip


## İnşaat şeridi: fotoğrafın ortasından hafif eğik geçen sarı-siyah bant.
func _draw_tape() -> void:
	var band: float = 26.0
	var step: float = 26.0
	var half: float = _tape.size.x * 0.6
	_tape.draw_set_transform(_tape.size * 0.5, deg_to_rad(-6.0), Vector2.ONE)
	_tape.draw_rect(Rect2(-half, -band * 0.5, half * 2.0, band), HudPalette.INK)
	var x: float = -half
	while x < half + band:
		_tape.draw_colored_polygon(PackedVector2Array([Vector2(x, -band * 0.5), Vector2(x + step * 0.5, -band * 0.5),
			Vector2(x + step * 0.5 - band, band * 0.5), Vector2(x - band, band * 0.5)]), HudPalette.PLATE_SELECTED)
		x += step
	_tape.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Merdiven genişliği ve yıldız sütunları tuval genişliğinden.
func _fit_layout() -> void:
	var width: float = get_viewport_rect().size.x
	if _ladder:
		_ladder.custom_minimum_size.x = clampf(width * LADDER_SHARE, LADDER_MIN, LADDER_MAX)
	if _stars:
		_stars.columns = 2 if width >= TWO_COLUMN_WIDTH else 1


func _connect_manager() -> void:
	if _manager:
		return
	_manager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if _manager == null:
		return
	_manager.garages_changed.connect(func() -> void:
		if visible:
			_refresh())
	_manager.layout_changed.connect(func() -> void:
		if visible:
			_refresh())
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_changed.connect(func(_money: int) -> void:
			if visible:
				_refresh())


# --- İçerik ---------------------------------------------------------------------------

## Açılışta seçili basamak: bakılan yer (depo / otopark); GARAJIM'dan açıldıysa alınmış ilk depo, yoksa otopark
## (araç varsa), yoksa MAHALLE.
func _default_selection() -> StringName:
	var here: StringName = StringName(current_garage.call()) if current_garage.is_valid() else &""
	if _tabs.has(here):
		return here
	if _manager and not _manager.owned_garages().is_empty():
		return _manager.owned_garages()[0]
	if _manager and not _manager.waiting_ids().is_empty():
		return CarGarageManager.WAITING
	return CarGarageCatalog.MAHALLE


static func _place_name(garage: StringName) -> String:
	return Loc.t("OTOPARK") if garage == CarGarageManager.WAITING else CarGarageCatalog.display_name(garage)


func _select(garage: StringName) -> void:
	_selected = garage
	for id: StringName in _tabs:
		(_tabs[id]["button"] as PlateButton).set_pressed_no_signal(id == garage)
	_refresh_preview()


## Başlık, uyarı, merdiven ve önizleme yazıları (geri sayımlar dahil). Yapı değişmez.
func _refresh() -> void:
	if _manager == null:
		return
	var parked: int = 0
	for garage: StringName in _manager.owned_garages():
		parked += _manager.used(garage)
	_title.text = Loc.t("DEPOLARIM   %d / %d YER") % [parked, _manager.total_capacity()]
	_home_button.text = Loc.t("GARAJIM   %d") % _manager.cars_in(CarGarageManager.HOME).size()
	for garage: StringName in _tabs:
		_refresh_tab(garage)
	_refresh_preview()


func _refresh_tab(garage: StringName) -> void:
	var tab: Dictionary = _tabs[garage]
	var status: CarGarageManager.Status = _manager.status(garage)
	var icon: HudIcon = tab["icon"]
	var badge: StyleBoxFlat = tab["badge"]
	var line: Label = tab["status"]
	var kind: HudIcon.Kind = HudIcon.Kind.NONE
	badge.bg_color = HudPalette.INK
	if garage == CarGarageManager.WAITING:
		var cars: int = _manager.waiting_ids().size()
		line.text = Loc.tn("%d ARAÇ · GÜNLÜK %s ₺", cars) % [cars, Hud.format_thousands(_manager.daily_fee())] if cars > 0 \
			else Loc.t("BOŞ")
		line.add_theme_color_override(&"font_color", HudPalette.DANGER if cars > 0 else HudPalette.INK_SOFT)
		(tab["name"] as Label).add_theme_color_override(&"font_color", HudPalette.INK)
		icon.visible = false
		(tab["number"] as Label).visible = true
		(tab["mark"] as HudIcon).visible = _is_current(garage)
		return
	match status:
		CarGarageManager.Status.OWNED:
			var job: Dictionary = _manager.job_of(garage)
			line.text = Loc.t("İŞ: %s · %s") % [CarGarageCatalog.item_name(job["item"]), clock_text(_manager.job_remaining(garage))] \
				if not job.is_empty() else Loc.t("%d/%d PARK YERİ") % [_manager.used(garage), _manager.capacity(garage)]
		CarGarageManager.Status.BUILDING:
			kind = HudIcon.Kind.HAMMER
			line.text = Loc.t("İNŞAAT SÜRÜYOR · %s") % clock_text(_manager.build_remaining(garage))
		CarGarageManager.Status.NEEDS_LEVEL:
			kind = HudIcon.Kind.LOCK
			badge.bg_color = HudPalette.INK_SOFT
			line.text = Loc.t("SEVİYE %d GEREKLİ") % CarGarageCatalog.required_level(garage)
		_:
			badge.bg_color = HudPalette.INK_SOFT
			line.text = "%s ₺" % Hud.format_thousands(CarGarageCatalog.price(garage))
	icon.kind = kind
	icon.visible = kind != HudIcon.Kind.NONE
	(tab["number"] as Label).visible = kind == HudIcon.Kind.NONE
	var built: bool = status == CarGarageManager.Status.OWNED or status == CarGarageManager.Status.BUILDING
	line.add_theme_color_override(&"font_color", HudPalette.COIN_DARK if status == CarGarageManager.Status.BUILDING
		or (status == CarGarageManager.Status.OWNED and not _manager.job_of(garage).is_empty()) else HudPalette.INK_SOFT)
	(tab["name"] as Label).add_theme_color_override(&"font_color", HudPalette.INK if built else HudPalette.INK_SOFT)
	(tab["mark"] as HudIcon).visible = _is_current(garage)


func _refresh_preview() -> void:
	if _manager == null or not _tabs.has(_selected):
		return
	var garage: StringName = _selected
	if garage == CarGarageManager.WAITING:
		_refresh_lot_preview()
		return
	var status: CarGarageManager.Status = _manager.status(garage)
	var owned: bool = status == CarGarageManager.Status.OWNED
	var building: bool = status == CarGarageManager.Status.BUILDING
	var locked: bool = status == CarGarageManager.Status.NEEDS_LEVEL
	_photo.texture = _card(garage)
	_photo_material.set_shader_parameter(&"gray", 1.0 if locked else 0.0)
	_photo_material.set_shader_parameter(&"dark", 0.45 if locked else (0.6 if building else (0.8 if not owned else 1.0)))
	_tape.visible = building
	_lock.visible = locked
	_here_chip.visible = owned and _is_current(garage)
	_name_label.text = CarGarageCatalog.display_name(garage)
	var top: int = CarGarageCatalog.max_capacity(garage)
	var capacity: int = _manager.capacity(garage) if owned else CarGarageCatalog.capacity_at(garage, 1)
	_usage_chip.visible = owned
	_usage_label.text = "%d/%d" % [_manager.used(garage), capacity]
	# Şerit: kapasitenin en çoğa göre yeri (park yeri yükseltmesi ilerledikçe dolar). Alınmamış garajda durum satırı
	# zaten "8 → 14 YER" yazıyor
	_lane_row.visible = owned
	_lane.ratio = float(capacity) / float(maxi(top, 1))
	_lane_value.text = "%d/%d" % [capacity, top]
	var text: String = ""
	var color: Color = HudPalette.INK_SOFT
	match status:
		CarGarageManager.Status.OWNED:
			var job: Dictionary = _manager.job_of(garage)
			if not job.is_empty():
				text = Loc.t("İŞ: %s · %s") % [CarGarageCatalog.item_name(job["item"]), clock_text(_manager.job_remaining(garage))]
				color = HudPalette.COIN_DARK
			elif _manager.used(garage) >= capacity:
				text = Loc.t("DOLU")
		CarGarageManager.Status.BUILDING:
			text = Loc.t("İNŞAAT SÜRÜYOR · %s") % clock_text(_manager.build_remaining(garage))
			color = HudPalette.COIN_DARK
		_:
			text = Loc.t("%s ₺ · %s İNŞAAT · %d → %d YER") % [Hud.format_thousands(CarGarageCatalog.price(garage)),
				ModWorkshop.duration_text(CarGarageCatalog.build_time(garage)), CarGarageCatalog.capacity_at(garage, 1), top]
	_status.text = text
	_status.visible = text != ""
	_status.add_theme_color_override(&"font_color", color)
	_stars.visible = owned
	if owned:
		for item: StringName in LOOK_ITEMS:
			var level: int = _manager.item_level(garage, item)
			(_star_labels[item] as Label).text = "★".repeat(level) + "☆".repeat(maxi(CarGarageCatalog.max_level(garage, item) - level, 0))
	_upgrades.visible = owned
	_refresh_main(garage, status)


## OTOPARK seçili: kaç araç, günlük ücret ve sıradaki faturaya kalan süre; yükseltme yok. Boşsa GİT kapalı.
func _refresh_lot_preview() -> void:
	var cars: int = _manager.waiting_ids().size()
	_photo.texture = _card(CarGarageManager.WAITING)
	_photo_material.set_shader_parameter(&"gray", 0.0)
	_photo_material.set_shader_parameter(&"dark", 1.0)
	_tape.visible = false
	_lock.visible = false
	_here_chip.visible = _is_current(CarGarageManager.WAITING)
	_name_label.text = Loc.t("OTOPARK")
	_usage_chip.visible = cars > 0
	_usage_label.text = str(cars)
	_lane_row.visible = false
	_status.visible = true
	if cars > 0:
		_status.text = Loc.t("GÜNLÜK %s ₺ · SONRAKİ FATURA %s") % [Hud.format_thousands(_manager.daily_fee()),
			clock_text(_manager.next_fee_in())]
		_status.add_theme_color_override(&"font_color", HudPalette.DANGER)
	else:
		_status.text = Loc.t("SINIRSIZ · ARAÇ BAŞINA HER GÜN DEĞERİNİN YÜZDE 5'İ")
		_status.add_theme_color_override(&"font_color", HudPalette.INK_SOFT)
	_stars.visible = false
	_upgrades.visible = false
	var current: bool = _is_current(CarGarageManager.WAITING)
	_main.text = Loc.t("BOŞ") if cars == 0 else (Loc.t("BURADASIN") if current else Loc.t("GİT"))
	_main.disabled = cars == 0
	if _main.kind != HudIcon.Kind.NONE:
		_main.kind = HudIcon.Kind.NONE
		_main.icon_left = false
	var amber: bool = cars > 0 and not current
	if _main.highlight != amber:
		_main.highlight = amber


## Ana plaka: GİT / BURADASIN · ELMASLA BİTİR (onay) · SATIN AL / PARA YETERSİZ / SEVİYE GEREKLİ. Stil yalnız değişince
## yeniden kurulur (PlateButton her atamada stil kutularını kopyalıyor; geri sayım yarım saniyede bir yazar).
func _refresh_main(garage: StringName, status: CarGarageManager.Status) -> void:
	var kind: HudIcon.Kind = HudIcon.Kind.NONE
	var amber: bool = true
	var off: bool = false
	var text: String = ""
	match status:
		CarGarageManager.Status.OWNED:
			amber = not _is_current(garage)
			text = Loc.t("GİT") if amber else Loc.t("BURADASIN")
		CarGarageManager.Status.BUILDING:
			kind = HudIcon.Kind.GEM
			text = Loc.t("ONAYLA: %d") % _manager.build_gem_cost(garage) if _is_armed(garage) \
				else Loc.t("BİTİR  %d") % _manager.build_gem_cost(garage)
		CarGarageManager.Status.NEEDS_LEVEL:
			kind = HudIcon.Kind.LOCK
			amber = false
			off = true
			text = Loc.t("SEVİYE %d GEREKLİ") % CarGarageCatalog.required_level(garage)
		CarGarageManager.Status.TOO_EXPENSIVE:
			amber = false
			off = true
			text = Loc.t("PARA YETERSİZ")
		_:
			text = Loc.t("SATIN AL")
	_main.text = text
	_main.disabled = off
	if _main.kind != kind:
		_main.kind = kind
		_main.icon_left = kind != HudIcon.Kind.NONE
	if _main.highlight != amber:
		_main.highlight = amber


static func card_path(garage: StringName) -> String:
	return CARD_PATH % ("rooftop" if garage == CarGarageManager.WAITING else String(garage))


func _card(garage: StringName) -> Texture2D:
	if not _cards.has(garage):
		var path: String = card_path(garage)
		_cards[garage] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _cards[garage]


func _on_main_pressed() -> void:
	var garage: StringName = _selected
	if garage == CarGarageManager.WAITING:
		if not _manager.waiting_ids().is_empty():
			_choose(garage)
		return
	match _manager.status(garage):
		CarGarageManager.Status.OWNED:
			_choose(garage)
		CarGarageManager.Status.BUILDING:
			if not _is_armed(garage):
				_armed[garage] = Time.get_ticks_msec() + int(GemSkip.CONFIRM_TIME * 1000.0)   # ilk dokunuş: onay
				_refresh_preview()
				return
			_armed.erase(garage)
			var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
			if player == null or not player.can_afford_gems(_manager.build_gem_cost(garage)):
				gem_store_requested.emit()
				return
			_manager.finish_build_with_gems(garage)
		CarGarageManager.Status.BUYABLE:
			_manager.purchase(garage)


func _choose(garage: StringName) -> void:
	if _closing:
		return
	garage_chosen.emit(garage)
	close()


func _is_armed(garage: StringName) -> bool:
	return Time.get_ticks_msec() < int(_armed.get(garage, 0))


## Garaj ekranında şu an bu garaja mı bakılıyor (GİT yerine BURADASIN).
func _is_current(garage: StringName) -> bool:
	return current_garage.is_valid() and StringName(current_garage.call()) == garage


func _button(text: String, action: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	return button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
