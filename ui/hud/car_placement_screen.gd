class_name CarPlacementScreen
extends Control
## YERLEŞTİR — yeni araç gelince (kasa, galeri, hurdalık, ödül) aracın nerede duracağını seçtirir
## (docs/GARAJLAR_TASARIM.md §10): GARAJIMA KOY (ana garajın sergisi: düzenleme kipi açılır, araç parmakta), boş yeri
## olan DEPOLAR, depolar doluysa OTOPARK (günlük ücretiyle). Pano açılmadan araç varsayılan yerine (boş yeri olan en üst
## depo, yoksa otopark) oturmuştur: TAMAM onu bırakır, oyuncu düzenleme kipinde vazgeçerse de orada kalır.
## UiRouter MODAL; HUD yeni araçları sıraya koyar ve ekran boşken açar. Ekran TAMAMEN KODLA kurulur (.tscn yok).

signal closed
## GARAJIMA KOY: HUD düzenleme kipini aracı parmakta açar.
signal home_requested(vehicle_id: StringName)

const PANEL_WIDTH: float = 520.0
const THUMB_SIZE: Vector2 = Vector2(150.0, 94.0)

## Yerleştirilecek araç (HUD open()'dan önce atar).
var vehicle_id: StringName = &""

var _column: VBoxContainer
var _thumb: TextureRect
var _name: Label
var _options: VBoxContainer
var _options_scroll: ScrollContainer
var _closing: bool = false
var _manager: CarGarageManager


func _ready() -> void:
	name = "CarPlacementScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_manager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	_refresh()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Testler ve QA için: seçenek plakası (&"home", depo id'si, CarGarageManager.WAITING); yoksa null.
func option(location: StringName) -> PlateButton:
	return _options.get_node_or_null("Place_%s" % location) as PlateButton


# --- Kurulum -------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var panel: PlatePanel = PlatePanel.new()
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)

	# Üst: aracın küçük resmi + YENİ ARACIN / ad / soru
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 14)
	_thumb = TextureRect.new()
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.custom_minimum_size = THUMB_SIZE
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(_thumb)
	var words: VBoxContainer = VBoxContainer.new()
	words.mouse_filter = Control.MOUSE_FILTER_IGNORE
	words.alignment = BoxContainer.ALIGNMENT_CENTER
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_label(&"HudInkCaption", Loc.t("YENİ ARACIN")))
	_name = _label(&"HudPlateTitle", "")
	_name.add_theme_font_size_override(&"font_size", 20)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(_name)
	var ask: Label = _label(&"HudInkCaption", Loc.t("NEREYE KOYALIM?"))
	ask.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	words.add_child(ask)
	head.add_child(words)
	box.add_child(head)

	# Seçenekler kaydırılabilir: beş depolu oyuncuda telefon tuvaline (480) sığmayabilir
	_options_scroll = ScrollContainer.new()
	_options_scroll.name = "OptionsScroll"
	_options_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(_options_scroll)
	_options = VBoxContainer.new()
	_options.name = "Options"
	_options.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override(&"separation", 6)
	_options_scroll.add_child(_options)
	box.add_child(_options_scroll)
	_column.add_child(panel)

	var keep: PlateButton = PlateButton.new()
	keep.name = "Keep"
	keep.theme_type_variation = &"HudPlateSmall"
	keep.text = Loc.t("TAMAM")
	keep.bolts = false
	keep.focus_mode = Control.FOCUS_NONE
	keep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	keep.custom_minimum_size = Vector2(220.0, 0.0)
	keep.pressed.connect(close)
	_column.add_child(keep)


# --- İçerik ---------------------------------------------------------------------------

## Seçenekler: GARAJIMA KOY, boş yeri olan depolar (ve aracın şu anki deposu), depolar doluysa / araç oradaysa OTOPARK.
## Aracın şu anki yeri amber ve "ŞU AN BURADA".
func _refresh() -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	_name.text = String(entry.get("display_name", vehicle_id)).to_upper()
	_thumb.texture = _thumbnail(vehicle_id)
	for child: Node in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	var here: StringName = _manager.garage_of(vehicle_id) if _manager else &""
	_options.add_child(_row(CarGarageManager.HOME, HudIcon.Kind.GARAGE, Loc.t("GARAJIMA KOY"),
		Loc.t("SERGİLE · ÜCRETSİZ"), here))
	if _manager == null:
		return
	var targets: Array[StringName] = _manager.move_targets(vehicle_id)
	for garage: StringName in _manager.owned_garages():
		if garage != here and not targets.has(garage):
			continue   # dolu depo
		_options.add_child(_row(garage, HudIcon.Kind.BOX, CarGarageCatalog.display_name(garage),
			Loc.t("%d/%d YER · ÜCRETSİZ") % [_manager.used(garage), _manager.capacity(garage)], here))
	if here == CarGarageManager.WAITING or targets.has(CarGarageManager.WAITING):
		_options.add_child(_row(CarGarageManager.WAITING, HudIcon.Kind.CAR, Loc.t("OTOPARK"),
			Loc.t("GÜNLÜK %s ₺") % Hud.format_thousands(CarGarageManager.fee_of(vehicle_id)), here))
	_fit_options.call_deferred()


## Seçenek kabının boyu: içeriği kadar, ekranda başlığa ve TAMAM'a yer bırakarak en çok.
func _fit_options() -> void:
	var wanted: float = _options.get_combined_minimum_size().y
	var room: float = maxf(get_viewport_rect().size.y - 250.0, 120.0)
	_options_scroll.custom_minimum_size = Vector2(0.0, minf(wanted, room))


func _row(location: StringName, kind: HudIcon.Kind, title: String, detail: String, here: StringName) -> PlateButton:
	var current: bool = location == here
	var button: PlateButton = PlateButton.new()
	button.name = "Place_%s" % location
	button.theme_type_variation = &"HudPlate"
	button.kind = kind
	button.icon_left = true
	button.highlight = current
	button.text = "%s\n%s" % [title, "%s  ·  %s" % [detail, Loc.t("ŞU AN BURADA")] if current else detail]
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_pick.bind(location))
	return button


func _on_pick(location: StringName) -> void:
	if _closing:
		return
	if location == CarGarageManager.HOME:
		home_requested.emit(vehicle_id)
		close()
		return
	if _manager and _manager.garage_of(vehicle_id) != location:
		_manager.move(vehicle_id, location)
	close()


static func _thumbnail(id: StringName) -> Texture2D:
	var cached: Texture2D = CarGallery.cached_thumbnail(id)
	if cached:
		return cached
	var path: String = CarGallery.BAKED_DIR + String(id) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
