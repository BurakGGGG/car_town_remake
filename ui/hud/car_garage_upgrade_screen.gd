class_name CarGarageUpgradeScreen
extends Control
## İÇ YÜKSELTMELER panosu — GARAJLARIM'daki garaj kartından açılır (UiRouter SUB: GERİ panoya döner).
## Beş kalem: PARK YERİ (kapasite) ve ZEMİN / IŞIKLAR / DUVAR / LİFT (görünüm + garaj değeri). Her satırda seviye
## yıldızları, sıradaki seviyenin etkisi, ücret ve süre; süren işte geri sayım + ELMASLA BİTİR (iki dokunuş).
## Garaj başına aynı anda tek iş: öteki satırlar İŞ SÜRÜYOR yazar. Mantık CarGarageManager'da.
## Ekran TAMAMEN KODLA kurulur (.tscn yok).

signal closed
## Elmas yetmedi: GEM MAĞAZASI.
signal gem_store_requested

const PLATE_WIDTH: float = 640.0
const EDGE: float = 16.0
const BUTTON_WIDTH: float = 190.0
const TICK: float = 0.5

## Hangi garajın kalemleri (açmadan önce HUD kurar).
var garage: StringName = CarGarageCatalog.MAHALLE

var _title: Label
var _body: PlatePanel
var _rows_box: VBoxContainer
var _column: VBoxContainer
var _rows: Dictionary = {}   # kalem → {"level": Label, "effect": Label, "main": PlateButton}
var _armed_until: int = 0    # ELMASLA BİTİR onayının bittiği an (ms)
var _closing: bool = false
var _tick: float = 0.0
var _manager: CarGarageManager


func _ready() -> void:
	name = "CarGarageUpgradeScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	set_process(false)
	get_viewport().size_changed.connect(_fit_width)


func open() -> void:
	_connect_manager()
	_armed_until = 0
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


## Testler ve QA için: kalemin ana plakası (YÜKSELT / BİTİR).
func main_button(item: StringName) -> PlateButton:
	return _rows.get(item, {}).get("main") as PlateButton


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
	_title = _label(&"HudSignTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	_body = PlatePanel.new()
	_body.theme_type_variation = &"HudCarPlate"
	_body.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "ItemsScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(scroll)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	_rows_box = VBoxContainer.new()
	_rows_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows_box.add_theme_constant_override(&"separation", 6)
	scroll.add_child(_rows_box)
	_column.add_child(_body)

	# Süren işi ödüllü reklamla kısalt (AdPolicy.TIME_SKIP; iş başına bir kez): GERİ'nin yanında, iş yokken gizli
	var bottom: HBoxContainer = HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override(&"separation", 8)
	_column.add_child(bottom)
	var back: PlateButton = _button(Loc.t("GERİ"), close)
	back.custom_minimum_size = Vector2(220.0, 0.0)
	bottom.add_child(back)
	var cut: AdOfferButton = AdOfferButton.new(AdPolicy.TIME_SKIP)
	cut.custom_minimum_size = Vector2(220.0, 0.0)
	cut.condition = func() -> bool: return _manager != null and visible and _manager.job_ad_cut(garage) > 0.0
	cut.reward_fn = func() -> String: return AdOfferButton.cut_text(_manager.job_ad_cut(garage)) if _manager else ""
	cut.rewarded.connect(func() -> void:
		if _manager:
			_manager.apply_job_ad_cut(garage)
		_refresh_rows())
	bottom.add_child(cut)


func _connect_manager() -> void:
	if _manager:
		return
	_manager = get_tree().get_first_node_in_group("car_garages") as CarGarageManager
	if _manager == null:
		return
	_manager.garages_changed.connect(func() -> void:
		if visible:
			_refresh_rows())
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_changed.connect(func(_money: int) -> void:
			if visible:
				_refresh_rows())


# --- İçerik ---------------------------------------------------------------------------

func _rebuild() -> void:
	for child: Node in _rows_box.get_children():
		_rows_box.remove_child(child)
		child.queue_free()
	_rows.clear()
	_title.text = Loc.t("%s · İÇ YÜKSELTMELER") % CarGarageCatalog.display_name(garage)
	for item: StringName in CarGarageCatalog.ITEMS:
		_rows_box.add_child(_row(item))
	_refresh_rows()
	_fit_width()


func _row(item: StringName) -> Control:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "Item_%s" % item
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
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 8)
	head.add_child(_label(&"HudPlateTitle", CarGarageCatalog.item_name(item)))
	var level: Label = _label(&"HudInkValue", "")
	level.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	head.add_child(level)
	text.add_child(head)
	var effect: Label = _label(&"HudInkCaption", "")
	effect.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_child(effect)
	var main: PlateButton = _button("", _on_main_pressed.bind(item))
	main.name = "Main"
	main.custom_minimum_size = Vector2(BUTTON_WIDTH, 0.0)
	main.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(main)
	_rows[item] = {"level": level, "effect": effect, "main": main}
	return panel


func _refresh_rows() -> void:
	if _manager == null:
		return
	var job: Dictionary = _manager.job_of(garage)
	for item: StringName in _rows:
		var row: Dictionary = _rows[item]
		var level: int = _manager.item_level(garage, item)
		var top: int = CarGarageCatalog.max_level(garage, item)
		(row["level"] as Label).text = "★".repeat(level) + "☆".repeat(maxi(top - level, 0))
		(row["effect"] as Label).text = _effect_text(item, level, top)
		var main: PlateButton = row["main"]
		main.kind = HudIcon.Kind.NONE
		main.disabled = false
		if not job.is_empty() and job["item"] == item:
			var cost: int = _manager.job_gem_cost(garage)
			main.kind = HudIcon.Kind.GEM
			main.icon_left = true
			main.icon_size = 16.0
			main.text = (Loc.t("ONAYLA: %d") % cost if Time.get_ticks_msec() < _armed_until else Loc.t("BİTİR  %d") % cost) \
				+ "\n" + CarGaragesScreen.clock_text(_manager.job_remaining(garage))
			continue
		var cost_line: String = "%s ₺ · %s" % [Hud.format_thousands(_manager.next_item_cost(garage, item)),
			ModWorkshop.duration_text(_manager.next_item_time(garage, item))]
		match _manager.item_status(garage, item):
			CarGarageManager.ItemStatus.MAXED:
				main.text = Loc.t("EN ÜSTTE")
				main.disabled = true
			CarGarageManager.ItemStatus.BUSY:
				main.text = Loc.t("İŞ SÜRÜYOR") + "\n" + cost_line
				main.disabled = true
			CarGarageManager.ItemStatus.TOO_EXPENSIVE:
				main.text = Loc.t("PARA YETERSİZ") + "\n" + cost_line
				main.disabled = true
			CarGarageManager.ItemStatus.NOT_OWNED:
				main.text = Loc.t("DEPO HENÜZ YOK")
				main.disabled = true
			_:
				main.text = Loc.t("YÜKSELT") + "\n" + cost_line


## PARK YERİ: "PARK YERİ 8 → 10"; görsel kalemler: görünüm + garaj değeri (denge bonusu yok).
func _effect_text(item: StringName, level: int, top: int) -> String:
	if item == CarGarageCatalog.PARK:
		var now_capacity: int = CarGarageCatalog.capacity_at(garage, level)
		if level >= top:
			return Loc.t("%d PARK YERİ (EN ÇOK)") % now_capacity
		return Loc.t("PARK YERİ %d → %d") % [now_capacity, CarGarageCatalog.capacity_at(garage, level + 1)]
	return Loc.t("GÖRÜNÜM + GARAJ DEĞERİ")


func _on_main_pressed(item: StringName) -> void:
	if _manager == null:
		return
	var job: Dictionary = _manager.job_of(garage)
	if job.is_empty() or job["item"] != item:
		_manager.upgrade_item(garage, item)
		return
	if Time.get_ticks_msec() >= _armed_until:
		_armed_until = Time.get_ticks_msec() + int(GemSkip.CONFIRM_TIME * 1000.0)   # ilk dokunuş: onay
		_refresh_rows()
		return
	_armed_until = 0
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if player == null or not player.can_afford_gems(_manager.job_gem_cost(garage)):
		gem_store_requested.emit()
		return
	_manager.finish_job_with_gems(garage)


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
