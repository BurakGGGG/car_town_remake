class_name CarGaragesScreen
extends Control
## GARAJLARIM panosu — garaj ekranının başlık plakasından açılır (UiRouter MODAL; garaj altta açık kalır).
## Beş garajın kartı: alınmış (doluluk, süren iç iş, GİT / İÇ YÜKSELTMELER), inşaatta (geri sayım + ELMASLA BİTİR),
## kilitli (fiyat, süre, kapasite, seviye şartı, SATIN AL). Bekleyen araç varsa üstte uyarı + BEKLEYENLER.
## Mantık yok: CarGarageManager okunur / çağrılır. Kararlar: docs/GARAJLAR_TASARIM.md §2, §6.
## Ekran TAMAMEN KODLA kurulur (.tscn yok).

signal closed
## GİT: garaj ekranı bu garaja geçer (pano kendini kapatır). CarGarageManager.WAITING = bekleme otoparkı.
signal garage_chosen(garage: StringName)
## İÇ YÜKSELTMELER panosu (UiRouter SUB) istendi.
signal upgrades_requested(garage: StringName)
## Elmas yetmedi: GEM MAĞAZASI.
signal gem_store_requested

const PLATE_WIDTH: float = 640.0
const EDGE: float = 16.0
const BUTTON_WIDTH: float = 150.0
## Geri sayımların yenilenme aralığı (sn).
const TICK: float = 0.5

var _title: Label
var _body: PlatePanel
var _rows_box: VBoxContainer
var _waiting_row: Control
var _waiting_label: Label
var _column: VBoxContainer
var _rows: Dictionary = {}       # garaj id → {"info": Label, "main": PlateButton}
var _armed: Dictionary = {}      # garaj id → onay süresinin bittiği an (ms): ELMASLA BİTİR iki dokunuş
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
	_build()
	set_process(false)
	get_viewport().size_changed.connect(_fit_width)


func open() -> void:
	_connect_manager()
	_armed.clear()
	_rebuild()
	set_process(true)
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	set_process(false)
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


func _process(delta: float) -> void:
	_tick -= delta
	if _tick > 0.0:
		return
	_tick = TICK
	_refresh_rows()


## Mantığı sınayan testler ve QA için: garaj kartının ana plakası (SATIN AL / GİT / BİTİR).
func main_button(garage: StringName) -> PlateButton:
	return _rows.get(garage, {}).get("main") as PlateButton


## "3:12:45" / "04:12".
static func clock_text(seconds: float) -> String:
	var s: int = maxi(ceili(seconds), 0)
	if s >= 3600:
		return "%d:%02d:%02d" % [s / 3600, (s % 3600) / 60, s % 60]
	return "%02d:%02d" % [s / 60, s % 60]


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
	_title = _label(&"HudSignTitle", Loc.t("GARAJLARIM"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	_body = PlatePanel.new()
	_body.theme_type_variation = &"HudCarPlate"
	_body.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "GaragesScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override(&"separation", 8)
	scroll.add_child(inner)

	# Bekleyen araç uyarısı (yalnız bekleyen varken)
	var waiting: HBoxContainer = HBoxContainer.new()
	waiting.name = "WaitingRow"
	waiting.add_theme_constant_override(&"separation", 8)
	_waiting_label = _label(&"HudInkCaption", "")
	_waiting_label.add_theme_color_override(&"font_color", HudPalette.DANGER)
	_waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_waiting_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	waiting.add_child(_waiting_label)
	var see: PlateButton = _button(Loc.t("BEKLEYENLER"), func() -> void: _choose(CarGarageManager.WAITING))
	see.name = "SeeWaiting"
	waiting.add_child(see)
	_waiting_row = waiting
	inner.add_child(waiting)

	_rows_box = VBoxContainer.new()
	_rows_box.add_theme_constant_override(&"separation", 6)
	inner.add_child(_rows_box)
	_column.add_child(_body)

	var close_button: PlateButton = _button(Loc.t("KAPAT"), close)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.custom_minimum_size = Vector2(220.0, 0.0)
	_column.add_child(close_button)


func _connect_manager() -> void:
	if _manager:
		return
	_manager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if _manager == null:
		return
	_manager.garages_changed.connect(func() -> void:
		if visible:
			_rebuild())
	_manager.layout_changed.connect(func() -> void:
		if visible:
			_rebuild())
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_changed.connect(func(_money: int) -> void:
			if visible:
				_rebuild())


# --- İçerik ---------------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	if _manager == null:
		return
	var parked: int = 0
	for garage: StringName in _manager.owned_garages():
		parked += _manager.used(garage)
	_title.text = Loc.t("GARAJLARIM   %d / %d YER") % [parked, _manager.total_capacity()]
	var waiting: int = _manager.waiting_ids().size()
	_waiting_row.visible = waiting > 0
	_waiting_label.text = Loc.t("%d ARAÇ BEKLİYOR: YER AÇ YA DA YENİ GARAJ AL") % waiting
	for garage: StringName in CarGarageCatalog.ids():
		_rows_box.add_child(_row(garage))
	_refresh_rows()
	_fit_width()


func _row(garage: StringName) -> Control:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "Garage_%s" % garage
	panel.theme_type_variation = &"HudCarPlate"
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 10)
	panel.add_child(line)
	var text: VBoxContainer = VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(text)
	var title: Label = _label(&"HudPlateTitle", CarGarageCatalog.display_name(garage))
	text.add_child(title)
	var info: Label = _label(&"HudInkCaption", "")
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(info)
	# Plakalar yan yana: alt alta iken satır iki kat uzuyor, telefonda beş garajdan üçü görünüyordu
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buttons.add_theme_constant_override(&"separation", 6)
	line.add_child(buttons)
	var main: PlateButton = _button("", _on_main_pressed.bind(garage))
	main.name = "Main"
	main.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	buttons.add_child(main)
	var status: CarGarageManager.Status = _manager.status(garage)
	if status == CarGarageManager.Status.OWNED:
		var inside: PlateButton = _button(Loc.t("İÇ YÜKSELTMELER"), func() -> void: upgrades_requested.emit(garage))
		inside.name = "Upgrades"
		inside.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
		buttons.add_child(inside)
	elif status == CarGarageManager.Status.BUILDING:
		main.kind = HudIcon.Kind.GEM
		main.icon_left = true
		main.icon_size = 16.0
	else:
		title.add_theme_color_override(&"font_color", HudPalette.INK_SOFT)
	_rows[garage] = {"info": info, "main": main}
	return panel


## Satırların yazıları (geri sayımlar dahil); yapı değişmez, plakalar basılı kalabilir.
func _refresh_rows() -> void:
	if _manager == null:
		return
	for garage: StringName in _rows:
		var info: Label = _rows[garage]["info"]
		var main: PlateButton = _rows[garage]["main"]
		match _manager.status(garage):
			CarGarageManager.Status.OWNED:
				var parts: PackedStringArray = PackedStringArray([Loc.t("%d/%d PARK YERİ") % [_manager.used(garage),
					_manager.capacity(garage)]])
				var job: Dictionary = _manager.job_of(garage)
				if not job.is_empty():
					parts.append(Loc.t("İŞ: %s · %s") % [CarGarageCatalog.item_name(job["item"]),
						clock_text(_manager.job_remaining(garage))])
				info.text = "  ·  ".join(parts)
				main.text = Loc.t("BURADASIN") if _is_current(garage) else Loc.t("GİT")
				main.disabled = false
			CarGarageManager.Status.BUILDING:
				info.text = Loc.t("İNŞAAT SÜRÜYOR · %s") % clock_text(_manager.build_remaining(garage))
				main.text = Loc.t("ONAYLA: %d") % _manager.build_gem_cost(garage) if _is_armed(garage) \
					else Loc.t("BİTİR  %d") % _manager.build_gem_cost(garage)
				main.disabled = false
			var status:
				info.text = Loc.t("%s ₺ · %s İNŞAAT · %d → %d YER") % [Hud.format_thousands(CarGarageCatalog.price(garage)),
					ModWorkshop.duration_text(CarGarageCatalog.build_time(garage)), CarGarageCatalog.capacity_at(garage, 1),
					CarGarageCatalog.max_capacity(garage)]
				if status == CarGarageManager.Status.NEEDS_LEVEL:
					main.text = Loc.t("SEVİYE %d GEREKLİ") % CarGarageCatalog.required_level(garage)
					main.disabled = true
				elif status == CarGarageManager.Status.TOO_EXPENSIVE:
					main.text = Loc.t("PARA YETERSİZ")
					main.disabled = true
				else:
					main.text = Loc.t("SATIN AL")
					main.disabled = false


func _on_main_pressed(garage: StringName) -> void:
	match _manager.status(garage):
		CarGarageManager.Status.OWNED:
			_choose(garage)
		CarGarageManager.Status.BUILDING:
			if not _is_armed(garage):
				_armed[garage] = Time.get_ticks_msec() + int(GemSkip.CONFIRM_TIME * 1000.0)   # ilk dokunuş: onay
				_refresh_rows()
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


func _fit_width() -> void:
	if _body == null:
		return
	_body.custom_minimum_size.x = minf(PLATE_WIDTH, get_viewport_rect().size.x - EDGE * 2.0)


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
