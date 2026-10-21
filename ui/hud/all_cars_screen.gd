class_name AllCarsScreen
extends Control
## TÜM ARAÇLAR panosu — ARAÇLAR ekranının alt şeridindeki TÜM ARAÇLAR plakasından açılır (UiRouter MODAL;
## garaj altta açık kalır). Oyuncunun sahip olduğu bütün araçlar ızgarada; üstte üç açılır plaka:
## SINIF, NADİRLİK ve SIRALA. Karta dokununca pano kapanır ve garaj o aracı lifte alır (vehicle_chosen).
## Kararlar: docs/GARAJLAR_TASARIM.md §1. Filtre / sıralama kuralları VehicleSort'tadır, burada yalnız görünüm var.
##
## Seçenekler tek satırda açılır plaka: telefon tuvalinde (480 birim) üç çip satırı ızgaraya yer bırakmıyordu.
## Seçimler oyun açık kaldıkça hatırlanır (kayda yazılmaz).
## Ekran TAMAMEN KODLA kurulur (.tscn yok); küçük render'ları KOLEKSİYON gibi CarGallery önbelleği çizer.

signal closed
## Karta dokunuldu (pano kendini kapatır; HUD garajda aracı lifte alır).
signal vehicle_chosen(vehicle_id: StringName)

const CARD_SIZE: Vector2 = Vector2(150.0, 124.0)
const THUMB_SIZE: Vector2 = Vector2(112.0, 62.0)
const MAX_COLUMNS: int = 5
const MIN_COLUMNS: int = 2
const CARD_GAP: float = 6.0
const PLATE_WIDTH: float = 820.0
## Ekran kenarı payı (sütunun MarginContainer'ı ile aynı).
const EDGE: float = 16.0
## Açılır listenin plakasıyla arasındaki boşluk.
const MENU_GAP: float = 4.0

## Garajda lifteki araç (kartı işaretlenir). HUD bağlar; boşsa işaret yok.
var current_vehicle: Callable = Callable()
## Garaj ekranında bakılan garaj (BU GARAJ anahtarı). HUD bağlar.
var current_garage: Callable = Callable()

static var _class_filter: String = ""
static var _rarity_filter: StringName = &""
static var _sort_key: StringName = VehicleSort.NEWEST
static var _this_garage: bool = false

var _title: Label
var _body: PlatePanel
var _grid: GridContainer
var _empty: Label
var _column: VBoxContainer
var _class_button: PlateButton
var _rarity_button: PlateButton
var _sort_button: PlateButton
var _here_button: PlateButton
var _menu_catcher: Control
var _menu: PlatePanel
var _menu_box: VBoxContainer
var _thumb_host: CarGallery
var _thumbs: Dictionary = {}   # araç id → TextureRect
var _closing: bool = false


func _ready() -> void:
	name = "AllCarsScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_thumb_host = CarGallery.new()
	_thumb_host.name = "ThumbnailHost"
	_thumb_host.mode = CarGallery.Mode.OWNED
	_thumb_host.visible = false
	add_child(_thumb_host)
	_thumb_host.thumbnails_rendered.connect(_apply_thumbnails)
	get_viewport().size_changed.connect(_fit_width)


func open() -> void:
	_close_menu()
	_rebuild()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_close_menu()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Testler ve QA için: seçimleri doğrudan kurar, panoyu yeniler.
func set_query(klass: String, rarity: StringName, sort_key: StringName) -> void:
	_class_filter = klass
	_rarity_filter = rarity
	_sort_key = sort_key if VehicleSort.KEYS.has(sort_key) else VehicleSort.NEWEST
	if visible:
		_rebuild()


## BU GARAJ anahtarı (testler ve QA için).
func set_this_garage(on: bool) -> void:
	_this_garage = on
	if visible:
		_rebuild()


## Izgarada görünen araçlar, sırasıyla.
func listed_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for card: Node in _grid.get_children():
		if not card.is_queued_for_deletion():
			out.append(StringName(card.name))
	return out


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, int(EDGE))
	add_child(margin)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_column.add_theme_constant_override(&"separation", 6)
	margin.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = _label(&"HudSignTitle", Loc.t("TÜM ARAÇLAR"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	# Akış kabı: uzun dillerde üç plaka yan yana sığmazsa alt satıra iner
	var row: HFlowContainer = HFlowContainer.new()
	row.name = "QueryRow"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"h_separation", 6)
	row.add_theme_constant_override(&"v_separation", 6)
	_column.add_child(row)
	_class_button = _query_button("ClassButton", _open_class_menu)
	_rarity_button = _query_button("RarityButton", _open_rarity_menu)
	_sort_button = _query_button("SortButton", _open_sort_menu)
	_here_button = _query_button("HereButton", func() -> void:
		_this_garage = _here_button.button_pressed
		_rebuild())
	_here_button.text = Loc.t("BURADAKİLER")
	_here_button.toggle_mode = true
	for button: PlateButton in [_class_button, _rarity_button, _sort_button, _here_button]:
		row.add_child(button)

	var body: PlatePanel = PlatePanel.new()
	_body = body
	body.theme_type_variation = &"HudCarPlate"
	body.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "GridScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	_grid = GridContainer.new()
	_grid.name = "Grid"
	_grid.add_theme_constant_override(&"h_separation", int(CARD_GAP))
	_grid.add_theme_constant_override(&"v_separation", int(CARD_GAP))
	inner.add_child(_grid)
	_empty = _label(&"HudInkCaption", Loc.t("BU FİLTREYE UYAN ARAÇ YOK"))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.visible = false
	inner.add_child(_empty)
	_column.add_child(body)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(220.0, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	_column.add_child(close_button)

	# Açılır liste: bütün ekranı örten saydam yakalayıcı (dışarı dokunuş listeyi kapatır) + üstünde plaka
	_menu_catcher = Control.new()
	_menu_catcher.name = "MenuCatcher"
	_menu_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu_catcher.visible = false
	_menu_catcher.gui_input.connect(func(event: InputEvent) -> void:
		if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
				or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
			_close_menu())
	add_child(_menu_catcher)
	_menu = PlatePanel.new()
	_menu.name = "Menu"
	_menu.theme_type_variation = &"HudCarPlate"
	_menu.set_meta(&"qa_popup", true)   # ekran taraması: kartların üstüne binmesi bilinçli
	_menu_catcher.add_child(_menu)
	_menu_box = VBoxContainer.new()
	_menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box.add_theme_constant_override(&"separation", 4)
	_menu.add_child(_menu_box)


func _query_button(node_name: String, on_press: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlateSmall"
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_press)
	return button


# --- İçerik ---------------------------------------------------------------------------

func _rebuild() -> void:
	_thumbs.clear()
	for child: Node in _grid.get_children():
		_grid.remove_child(child)   # ad hemen serbest kalsın: yeni kart aynı araç adını alır
		child.queue_free()
	_class_button.text = Loc.t("SINIF: %s") % (_class_filter if _class_filter != "" else Loc.t("TÜMÜ"))
	_rarity_button.text = Loc.t("NADİRLİK: %s") % (CrateCatalog.rarity_label(_rarity_filter) if _rarity_filter != &"" else Loc.t("TÜMÜ"))
	_sort_button.text = Loc.t("SIRALA: %s") % VehicleSort.label(_sort_key)

	var own: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	var all: Array[StringName] = []
	if own:
		all = own.owned_vehicle_ids()
	# GARAJLARIM: rozet ve BU GARAJ anahtarı yalnız birden çok garaj (ya da bekleyen araç) varken anlamlı
	var garages: CarGarageManager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	var here: StringName = StringName(current_garage.call()) if current_garage.is_valid() else &""
	var several: bool = garages != null and (garages.owned_garages().size() > 1 or not garages.waiting_ids().is_empty())
	_here_button.visible = several and here != &""
	_here_button.set_pressed_no_signal(_this_garage)
	var pool: Array[StringName] = all
	if _here_button.visible and _this_garage:
		pool = []
		for id: StringName in all:
			if garages.garage_of(id) == here:
				pool.append(id)
	var ids: Array[StringName] = VehicleSort.sort(VehicleSort.filter(pool, _class_filter, _rarity_filter), _sort_key, race)
	_title.text = Loc.t("TÜM ARAÇLAR   %d / %d") % [ids.size(), all.size()]
	var current: StringName = StringName(current_vehicle.call()) if current_vehicle.is_valid() else &""
	var racer: StringName = own.race_vehicle_id() if own else &""
	for id: StringName in ids:
		_grid.add_child(_card(id, race, id == current, id == racer, garages.garage_of(id) if several else &""))
	_empty.visible = ids.is_empty()
	var scroll: ScrollContainer = _body.get_node("GridScroll") as ScrollContainer
	scroll.scroll_vertical = 0
	_fit_width()
	_apply_thumbnails()


## Plaka ve sütun sayısı kadraja göre: geniş tuvalde 820 birim / 5 sütun, dar tuvalde sığdığı kadar.
func _fit_width() -> void:
	if _body == null:
		return
	var style: StyleBox = _body.get_theme_stylebox(&"panel")
	var padding: float = style.get_minimum_size().x if style else 0.0
	var room: float = get_viewport_rect().size.x - EDGE * 2.0
	var inner: float = minf(PLATE_WIDTH, room) - padding
	_grid.columns = clampi(int((inner + CARD_GAP) / (CARD_SIZE.x + CARD_GAP)), MIN_COLUMNS, MAX_COLUMNS)
	_body.custom_minimum_size.x = minf(PLATE_WIDTH, room)


## Kart: nadirlik çerçeveli plaka (KOLEKSİYON kartıyla aynı dil) + üstünde saydam düğme. PanelContainer bütün
## çocuklarını aynı dikdörtgene yaydığı için düğme kartın tamamını kaplar; içerik kartı kendi boyuna büyütür.
func _card(id: StringName, race: RaceManager, current: bool, racer: bool, garage: StringName) -> Control:
	var entry: Dictionary = CarCatalog.get_entry(id)
	var rarity: StringName = CrateCatalog.rarity_of(id)
	var color: Color = CrateCatalog.rarity_color(rarity)

	var frame: PanelContainer = PanelContainer.new()
	frame.name = String(id)
	frame.custom_minimum_size = CARD_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_PASS
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.PLATE_SELECTED if current else HudPalette.PLATE
	style.set_corner_radius_all(6)
	var border: int = 2
	match rarity:
		&"epic":
			border = 3
		&"legendary":
			border = 4
	style.set_border_width_all(border)
	style.border_color = color
	style.content_margin_left = 6.0
	style.content_margin_right = 6.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	frame.add_theme_stylebox_override(&"panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	frame.add_child(box)

	var head: Label = _label(&"HudInkCaption", Loc.t("%s  ·  %s SINIFI") % [CrateCatalog.rarity_label(rarity),
		PerformanceMods.class_of(id)])
	head.add_theme_color_override(&"font_color", color.darkened(0.15))
	box.add_child(_wrap(head))

	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = THUMB_SIZE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(thumb)
	_thumbs[id] = thumb
	if _thumb_host and _thumb_host.is_inside_tree():
		_thumb_host.request_thumbnail(id)

	box.add_child(_wrap(_label(&"HudInkValue", String(entry.get("display_name", id)).to_upper())))
	var lines: PackedStringArray = PackedStringArray()
	var metric: String = VehicleSort.metric_text(id, _sort_key, race)
	if metric != "":
		lines.append(metric)
	if racer:
		lines.append(Loc.t("YARIŞ ARACI"))
	if not lines.is_empty():
		var info: Label = _label(&"HudInkCaption", "  ·  ".join(lines))
		info.name = "Metric"
		box.add_child(_wrap(info))
	if garage != &"":   # yer rozeti: aracın durduğu depo, OTOPARK (ücretli: kırmızı) ya da GARAJIM (sergide)
		var place: String = Loc.t("OTOPARK") if garage == CarGarageManager.WAITING \
			else (Loc.t("GARAJIM") if garage == CarGarageManager.HOME else CarGarageCatalog.display_name(garage))
		var badge: Label = _label(&"HudInkCaption", place)
		badge.name = "GarageBadge"
		badge.add_theme_color_override(&"font_color", HudPalette.DANGER if garage == CarGarageManager.WAITING
			else HudPalette.INK_SOFT)
		box.add_child(_wrap(badge))

	var hit: Button = Button.new()
	hit.name = "Hit"
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_filter = Control.MOUSE_FILTER_PASS
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		hit.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	hit.button_down.connect(func() -> void: frame.modulate = Color(0.92, 0.92, 0.92))
	hit.button_up.connect(func() -> void: frame.modulate = Color.WHITE)
	hit.pressed.connect(_on_card_pressed.bind(id))
	frame.add_child(hit)
	return frame


func _on_card_pressed(id: StringName) -> void:
	if _closing:
		return
	vehicle_chosen.emit(id)
	close()


func _apply_thumbnails() -> void:
	for id: StringName in _thumbs:
		var rect: TextureRect = _thumbs[id]
		if is_instance_valid(rect) and rect.texture == null:
			rect.texture = CarGallery.cached_thumbnail(id)


# --- Açılır liste ---------------------------------------------------------------------

func _open_class_menu() -> void:
	var options: Array = [["", Loc.t("TÜMÜ"), Color()]]
	for klass: String in PerformanceMods.CLASSES:
		options.append([klass, Loc.t("%s SINIFI") % klass, Color()])
	_open_menu(_class_button, options, _class_filter, func(value: Variant) -> void: _class_filter = String(value))


func _open_rarity_menu() -> void:
	var options: Array = [[&"", Loc.t("TÜMÜ"), Color()]]
	for index: int in range(CrateCatalog.RARITY_ORDER.size() - 1, -1, -1):   # en nadir üstte
		var rarity: StringName = CrateCatalog.RARITY_ORDER[index]
		options.append([rarity, CrateCatalog.rarity_label(rarity), CrateCatalog.rarity_color(rarity).darkened(0.15)])
	_open_menu(_rarity_button, options, _rarity_filter, func(value: Variant) -> void: _rarity_filter = StringName(value))


func _open_sort_menu() -> void:
	var options: Array = []
	for key: StringName in VehicleSort.KEYS:
		options.append([key, VehicleSort.label(key), Color()])
	_open_menu(_sort_button, options, _sort_key, func(value: Variant) -> void: _sort_key = StringName(value))


## options: [değer, yazı, yazı rengi (alfa 0 = temanın rengi)]. Seçilince `pick(değer)` çağrılır, pano yenilenir.
func _open_menu(anchor: PlateButton, options: Array, selected: Variant, pick: Callable) -> void:
	for child: Node in _menu_box.get_children():
		_menu_box.remove_child(child)
		child.queue_free()
	for option: Array in options:
		var item: PlateButton = PlateButton.new()
		item.name = "Option_%s" % String(option[0] if String(option[0]) != "" else "all")
		item.theme_type_variation = &"HudPlateSmall"
		item.bolts = false
		item.focus_mode = Control.FOCUS_NONE
		item.text = String(option[1])
		item.highlight = String(option[0]) == String(selected)   # seçili seçenek amber (lifteki aracın kartı gibi)
		var tint: Color = option[2]
		if tint.a > 0.0:
			item.add_theme_color_override(&"font_color", tint)
		var value: Variant = option[0]
		item.pressed.connect(func() -> void:
			pick.call(value)
			_close_menu()
			_rebuild())
		_menu_box.add_child(item)
	_menu_catcher.show()
	_menu.custom_minimum_size.x = anchor.size.x
	_menu.reset_size()
	# Plakanın altına; ekranın altına taşarsa üstüne. Konum ekranın kendi koordinatında.
	var to_local: Transform2D = _menu_catcher.get_global_transform().affine_inverse()
	var rect: Rect2 = anchor.get_global_rect()
	var top_left: Vector2 = to_local * rect.position
	var bottom: Vector2 = to_local * rect.end
	var menu_size: Vector2 = _menu.get_combined_minimum_size()
	var view: Vector2 = _menu_catcher.size
	var y: float = bottom.y + MENU_GAP
	if y + menu_size.y > view.y - EDGE:
		y = maxf(top_left.y - MENU_GAP - menu_size.y, EDGE)
	_menu.position = Vector2(clampf(top_left.x, EDGE, maxf(view.x - EDGE - menu_size.x, EDGE)), y)


func _close_menu() -> void:
	if _menu_catcher:
		_menu_catcher.hide()


# --- Yardımcılar ----------------------------------------------------------------------

## Kart yazısı kartı genişletmesin (ızgarada bütün sütun genişliyor, plaka taşıyordu): sarar.
func _wrap(label: Label) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
