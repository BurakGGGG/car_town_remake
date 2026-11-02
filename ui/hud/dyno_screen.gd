class_name DynoScreen
extends Control
## DİNAMOMETRE ekranının arayüzü (2026-11-02, kullanıcı taslak C'yi seçti: "dinamometre olsun, gaz pedalı falan olsun").
## Garaj ekranının üstünde tam ekran katman; 3B atölye ve fizik DynoView'da. Bu düğüm yalnız girdiyi iletir ve
## durumu gösterir:
##   ÜST     GERİ · araç adı + motor künyesi + çekiş (önden / arkadan / 4 çeker)
##   SOL     DİNAMOMETRE paneli: devir ışıkları, devir / hız / tork, büyük GÜÇ, eğri (güç, tork, fabrika, en iyi)
##   SAĞ     gaz pedalı
## Kullanıcı (2026-11-02): START / STOP yok (motor atölyeye girince çalışır), vites yok, tek kamera, DİNO KOŞUSU düğmesi
## yok — rölantiden kesiciye her tam gaz çekiş ölçümdür; rekor kırılınca EN İYİ satırı bir süre "YENİ REKOR!" yazar.
## Düzen container'larla (mutlak konum yok); garaj ekranının HUD temasını devralır.

signal back_pressed

const TEXT_HZ: float = 15.0
## "YENİ REKOR!" yazısının kaldığı süre (sn).
const RECORD_SHOW: float = 3.0

var view: DynoView

var _title: Label
var _subtitle: Label
var _lights: DynoLights
var _rpm: Label
var _kmh: Label
var _torque: Label
var _power: Label
var _best: Label
var _graph: DynoGraph
var _pedal: DynoPedal
var _text_timer: float = 0.0
var _record_left: float = 0.0


func _ready() -> void:
	name = "DynoScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	hide()
	set_process(false)


## Ekranı açar (DynoView atölyeye girmiş olmalı).
func open(dyno_view: DynoView) -> void:
	view = dyno_view
	if not view.pull_measured.is_connected(_on_pull_measured):
		view.pull_measured.connect(_on_pull_measured)
	var entry: Dictionary = CarCatalog.get_entry(view.vehicle_id)
	_title.text = CarCatalog.label(entry).replace("\n", " ")
	var perf: Dictionary = entry.get("performance", {}) if entry.get("performance", {}) is Dictionary else {}
	var drive: String = Loc.t("4 ÇEKER") if view.sim.drives_front and view.sim.drives_rear \
		else (Loc.t("ÖNDEN ÇEKİŞ") if view.sim.drives_front else Loc.t("ARKADAN İTİŞ"))
	_subtitle.text = "%s · %s · %s" % [String(perf.get("engine", "")), Loc.t("%d bg") % int(perf.get("hp", 0)), drive]
	_graph.idle_rpm = view.sim.spec.idle_rpm
	_graph.redline_rpm = view.sim.spec.redline_rpm
	_graph.scale_hp = maxf(view.sim.catalog_hp, 1.0)
	_graph.factory = PerformanceMods.power_curve(view.vehicle_id, {})["points"]
	_graph.set_data(PackedVector2Array(), PackedVector2Array(), view.best_hp())
	_record_left = 0.0
	_text_timer = 0.0
	show()
	set_process(true)


func close() -> void:
	set_process(false)
	_pedal.throttle = 0.0
	hide()
	view = null


# --- Kurulum -------------------------------------------------------------------------------------------

func _build() -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	margin.add_child(column)
	column.add_child(_build_top())
	var middle: HBoxContainer = HBoxContainer.new()
	middle.name = "Middle"
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	middle.add_child(_build_panel())
	middle.add_child(_spacer())
	_pedal = DynoPedal.new()
	_pedal.name = "Pedal"
	_pedal.size_flags_vertical = Control.SIZE_SHRINK_END
	_pedal.throttle_changed.connect(func(value: float) -> void:
		if view:
			view.set_throttle(value))
	middle.add_child(_pedal)


## GERİ solda, araç plakası ortada (iki yanda eşit genişleyen alan: plaka tam ortada kalır).
func _build_top() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Top"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	var left: HBoxContainer = HBoxContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var back: PlateButton = _plate(&"HudPlateSmall", Loc.t("GERİ"))
	back.name = "BackButton"
	back.pressed.connect(func() -> void: back_pressed.emit())
	left.add_child(back)
	row.add_child(left)
	var plate: PlatePanel = PlatePanel.new()
	plate.name = "TitlePlate"
	plate.theme_type_variation = &"HudCarPlate"
	plate.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	plate.add_child(box)
	_title = _label(&"HudPlateTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_subtitle = _label(&"HudInkCaption", "")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_subtitle)
	row.add_child(plate)
	row.add_child(_spacer())
	return row


func _build_panel() -> Control:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "DynoPanel"
	panel.theme_type_variation = &"HudCarPlate"
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	panel.add_child(box)
	var head: HBoxContainer = HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_label(&"HudPlateTitle", Loc.t("DİNAMOMETRE")))
	head.add_child(_spacer())
	_lights = DynoLights.new()
	_lights.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(_lights)
	box.add_child(head)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"v_separation", 0)
	box.add_child(grid)
	_rpm = _row(grid, Loc.t("DEVİR"))
	_kmh = _row(grid, Loc.t("HIZ"))
	_torque = _row(grid, Loc.t("TORK"))
	var power_row: HBoxContainer = HBoxContainer.new()
	power_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	power_row.add_child(_label(&"HudInkCaption", Loc.t("GÜÇ")))
	power_row.add_child(_spacer())
	_power = _label(&"HudPlateTitle", "")
	_power.add_theme_font_size_override(&"font_size", 26)
	_power.add_theme_color_override(&"font_color", DynoGraph.POWER)
	power_row.add_child(_power)
	box.add_child(power_row)
	_graph = DynoGraph.new()
	box.add_child(_graph)
	var legend: HBoxContainer = HBoxContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.add_theme_constant_override(&"separation", 10)
	var power_key: Label = _label(&"HudInkCaption", "— " + Loc.t("güç"))
	power_key.add_theme_color_override(&"font_color", DynoGraph.POWER)
	legend.add_child(power_key)
	var torque_key: Label = _label(&"HudInkCaption", "— " + Loc.t("tork"))
	torque_key.add_theme_color_override(&"font_color", DynoGraph.TORQUE)
	legend.add_child(torque_key)
	legend.add_child(_label(&"HudInkCaption", "- - " + Loc.t("fabrika")))
	legend.add_child(_spacer())
	_best = _label(&"HudInkCaption", "")
	_best.name = "Best"
	legend.add_child(_best)
	box.add_child(legend)
	return panel


# --- Kare -----------------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if view == null or view.sim == null:
		return
	var sim: DynoSim = view.sim
	_lights.ratio = sim.rpm_ratio() if sim.running else 0.0
	_lights.flashing = sim.limiter
	_record_left = maxf(_record_left - delta, 0.0)
	_text_timer -= delta
	if _text_timer <= 0.0:
		_text_timer = 1.0 / TEXT_HZ
		_rpm.text = Loc.t("%s d/dk") % Hud.format_thousands(roundi(sim.rpm))
		_kmh.text = Loc.t("%d km/sa") % roundi(sim.kmh())
		_torque.text = Loc.t("%d Nm") % roundi(sim.torque_nm)
		_power.text = Loc.t("%d bg") % roundi(sim.power_hp)
		var best: float = view.best_hp()
		if _record_left > 0.0:
			_best.text = "%s %s" % [Loc.t("YENİ REKOR!"), Loc.t("%d bg") % roundi(best)]
			_best.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
		else:
			_best.text = Loc.t("EN İYİ %d bg") % roundi(best) if best > 0.0 else ""
			_best.remove_theme_color_override(&"font_color")
		_graph.set_data(sim.curve_power, sim.curve_torque, best)


func _on_pull_measured(_peak: float, record: bool) -> void:
	if record:
		_record_left = RECORD_SHOW
		_text_timer = 0.0


# --- Yardımcılar ------------------------------------------------------------------------------------------

func _row(grid: GridContainer, caption: String) -> Label:
	var name_label: Label = _label(&"HudInkCaption", caption)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(name_label)
	var value: Label = _label(&"HudInkValue", "")
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	grid.add_child(value)
	return value


func _plate(variation: StringName, text: String) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.text = text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	return button


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer
