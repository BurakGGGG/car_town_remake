class_name PaintPanel
extends VBoxContainer
## BOYA ATÖLYESİ plakası — garaj ekranının sağ sütununda, aksiyon plakalarının yerine açılır.
## Tamamen kodla kurulur. Renkler PaintCatalog'dan, satın alma VehicleOwnership.purchase_paint'ten
## geçer (para / gem EconomyManager / PlayerProgress); bu panel ücret hesaplamaz, yalnızca gösterir.
##
## Renge dokunmak yalnızca ÖNİZLEMEDİR (preview_requested): lifteki araç o renge boyanır, hiçbir şey
## harcanmaz ve kaydedilmez. BOYA plakası satın alır; GERİ / araç değişimi / garajdan çıkış önizlemeyi
## bırakır (preview_cleared) ve araç kendi rengine döner.

## Lifteki araç bu renkle gösterilsin (önizleme).
signal preview_requested(color: Color)
## Önizleme bitti: lifteki araç kendi (kayıtlı) rengine dönsün.
signal preview_cleared
signal closed

const COLUMNS: int = 5
const SWATCH: float = 36.0
const WIDTH: float = COLUMNS * SWATCH + (COLUMNS - 1) * 6.0 + 24.0

var _vehicle: StringName = &""
var _selected: StringName = &""
var _ownership: VehicleOwnership
var _economy: EconomyManager
var _progress: PlayerProgress
var _swatches: Dictionary = {}   # paint id → Button
var _name_label: Label
var _price_label: Label
var _buy_button: PlateButton


func _ready() -> void:
	name = "PaintPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override(&"separation", 8)
	_build()
	_connect_managers.call_deferred()


# --- Aç / kapa ---------------------------------------------------------------

## Panel bu araç için açılır; seçim aracın mevcut rengindedir.
func open(vehicle_id: StringName) -> void:
	show()
	set_vehicle(vehicle_id)


func close() -> void:
	if not visible:
		return
	hide()
	preview_cleared.emit()
	closed.emit()


## Lifteki araç değişti: önizleme bırakılır, seçim yeni aracın rengine geçer.
func set_vehicle(vehicle_id: StringName) -> void:
	_vehicle = vehicle_id
	_selected = _current_paint_id()
	preview_cleared.emit()
	_refresh()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	plate.add_child(box)
	add_child(plate)

	box.add_child(_label(&"HudPlateTitle", "BOYA ATÖLYESİ"))
	var grid: GridContainer = GridContainer.new()
	grid.columns = COLUMNS
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 6)
	box.add_child(grid)
	_add_swatch(grid, PaintCatalog.FACTORY_ID)
	for entry: Dictionary in PaintCatalog.all():
		_add_swatch(grid, entry["id"])

	_name_label = _label(&"HudInkCaption", "")
	_price_label = _label(&"HudInkValue", "")
	box.add_child(_name_label)
	box.add_child(_price_label)

	_buy_button = PlateButton.new()
	_buy_button.name = "PaintBuyButton"
	_buy_button.theme_type_variation = &"HudPlate"
	_buy_button.kind = HudIcon.Kind.PAINT
	_buy_button.custom_minimum_size = Vector2(WIDTH, 54.0)
	_buy_button.focus_mode = Control.FOCUS_NONE
	_buy_button.pressed.connect(_on_buy_pressed)
	add_child(_buy_button)

	var back: PlateButton = PlateButton.new()
	back.theme_type_variation = &"HudPlateSmall"
	back.text = "GERİ"
	back.custom_minimum_size = Vector2(WIDTH, 0.0)
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(close)
	add_child(back)


func _add_swatch(grid: GridContainer, paint_id: StringName) -> void:
	var swatch: Button = Button.new()
	swatch.custom_minimum_size = Vector2(SWATCH, SWATCH)
	swatch.focus_mode = Control.FOCUS_NONE
	swatch.pressed.connect(_on_swatch_pressed.bind(paint_id))
	# Özel (gem) renkler köşede küçük bir gem işaretiyle, fabrika rengi "F" harfiyle ayrılır
	swatch.draw.connect(_draw_swatch_mark.bind(swatch, paint_id))
	grid.add_child(swatch)
	_swatches[paint_id] = swatch


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _connect_managers() -> void:
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	_progress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if _ownership:
		_ownership.paint_changed.connect(func(_id: StringName, _c: Color) -> void: _refresh())
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: _refresh())
	if _progress:
		_progress.gems_changed.connect(func(_g: int) -> void: _refresh())


# --- Görünüm -------------------------------------------------------------------

func _refresh() -> void:
	if not visible or _vehicle == &"":
		return
	var current: StringName = _current_paint_id()
	for paint_id: StringName in _swatches:
		_style_swatch(_swatches[paint_id], _color_of(paint_id), paint_id == _selected, paint_id == current)
	var entry: Dictionary = PaintCatalog.get_entry(_selected)
	_name_label.text = "FABRİKA RENGİ" if _selected == PaintCatalog.FACTORY_ID else String(entry.get("name", ""))
	_price_label.text = "ÜCRETSİZ" if _selected == PaintCatalog.FACTORY_ID else _price_text(entry)
	_buy_button.kind = HudIcon.Kind.GEM if _is_gem(entry) else HudIcon.Kind.PAINT
	if _selected == current:
		_buy_button.text = "MEVCUT RENK"
		_buy_button.disabled = true
	elif _ownership and _ownership.can_purchase_paint(_vehicle, _selected):
		_buy_button.text = "BOYA"
		_buy_button.disabled = false
	else:
		_buy_button.text = "GEM YETERSİZ" if _is_gem(entry) else "PARA YETERSİZ"
		_buy_button.disabled = true


func _style_swatch(swatch: Button, color: Color, selected: bool, current: bool) -> void:
	var edge: Color = HudPalette.PLATE_SELECTED_EDGE if selected else Color(HudPalette.INK, 0.35)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.bg_color = color.lightened(0.08) if state == &"hover" else color
		sb.set_corner_radius_all(6)
		sb.set_border_width_all(3 if selected else (2 if current else 1))
		sb.border_color = edge
		sb.anti_aliasing = true
		swatch.add_theme_stylebox_override(state, sb)
	swatch.queue_redraw()


func _draw_swatch_mark(swatch: Button, paint_id: StringName) -> void:
	var entry: Dictionary = PaintCatalog.get_entry(paint_id)
	var ink: Color = Color.WHITE if _color_of(paint_id).get_luminance() < 0.5 else HudPalette.INK
	if paint_id == PaintCatalog.FACTORY_ID:
		var font: Font = swatch.get_theme_default_font()
		swatch.draw_string(font, Vector2(0.0, swatch.size.y * 0.5 + 6.0), "F", HORIZONTAL_ALIGNMENT_CENTER, swatch.size.x, 16, ink)
	elif _is_gem(entry):
		HudIcon.draw_icon(swatch, HudIcon.Kind.GEM, Vector2(swatch.size.x - 9.0, 9.0), 11.0, ink, Color.TRANSPARENT)
	if paint_id == _current_paint_id():
		swatch.draw_circle(Vector2(7.0, swatch.size.y - 7.0), 3.0, ink, true, -1.0, true)   # aracın şu anki rengi


func _price_text(entry: Dictionary) -> String:
	if _is_gem(entry):
		return "%d GEM" % int(entry["price"])
	return "%s ₺" % Hud.format_thousands(int(entry.get("price", 0)))


func _is_gem(entry: Dictionary) -> bool:
	return int(entry.get("currency", PaintCatalog.Currency.MONEY)) == PaintCatalog.Currency.GEMS


func _color_of(paint_id: StringName) -> Color:
	if paint_id == PaintCatalog.FACTORY_ID:
		return CarCatalog.default_color_for(CarCatalog.scene_path(_vehicle))
	return PaintCatalog.get_entry(paint_id).get("color", Color.WHITE)


## Aracın şu anki boyasının katalog id'si (fabrika rengindeyse FACTORY_ID).
func _current_paint_id() -> StringName:
	if _ownership == null:
		_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if _ownership == null or _vehicle == &"":
		return PaintCatalog.FACTORY_ID
	var color: Color = _ownership.paint_color(_vehicle)
	if color.is_equal_approx(_color_of(PaintCatalog.FACTORY_ID)):
		return PaintCatalog.FACTORY_ID
	var paint_id: StringName = PaintCatalog.id_for_color(color)
	return paint_id if paint_id != &"" else PaintCatalog.FACTORY_ID


# --- Butonlar ----------------------------------------------------------------------

func _on_swatch_pressed(paint_id: StringName) -> void:
	_selected = paint_id
	if paint_id == _current_paint_id():
		preview_cleared.emit()
	else:
		preview_requested.emit(_color_of(paint_id))
	_refresh()


func _on_buy_pressed() -> void:
	if _ownership and _ownership.purchase_paint(_vehicle, _selected):
		preview_cleared.emit()   # artık kayıtlı renk bu: önizleme yerine gerçek görünüm
	_refresh()
