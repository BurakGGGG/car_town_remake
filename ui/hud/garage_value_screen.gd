class_name GarageValueScreen
extends Control
## GARAJ DEĞERİ tabelası: garajın toplam değeri, hangi kalemden geldiği ve 10 basamaklı rütbe merdiveni.
## Ekran TAMAMEN KODLA kurulur (.tscn yok) ve GarageScreen'in üstüne oturur; "yol mobilyası / plaka" dili.
##
## HİÇBİR MANTIK BURADA DEĞİL: değer de rütbe de GarageValue'nun statik hesabıdır (kayda yazılmaz,
## sinyali yoktur), bu ekran yalnızca açılırken hesaplayıp gösterir. Rütbe pahalı araçların kilidini
## açtığı için (CarCatalog "min_garage_rank") oyuncunun bu merdiveni GÖREBİLMESİ gerekir.

signal closed

const PLATE_WIDTH: float = 460.0

var _value_label: Label
var _rank_label: Label
var _next_label: Label
var _gauge: XpLane
var _breakdown: VBoxContainer
var _ladder: VBoxContainer
var _column: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "GarageValueScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken arkadaki garaj plakalarına tıklama gitmez
	_build()


func open() -> void:
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


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	_column = column

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", "GARAJ DEĞERİ")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	# Toplam değer + rütbe + sıradaki rütbeye ilerleme
	var head: PlatePanel = PlatePanel.new()
	head.theme_type_variation = &"HudCarPlate"
	head.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var head_box: VBoxContainer = VBoxContainer.new()
	head_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head_box.add_theme_constant_override(&"separation", 2)
	_value_label = _label(&"HudSignTitle", "0 ₺")
	_value_label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_rank_label = _label(&"HudPlateTitle", "")
	_gauge = XpLane.new()
	_gauge.custom_minimum_size = Vector2(PLATE_WIDTH - 40.0, 9.0)
	_gauge.segments = 10
	_next_label = _label(&"HudInkCaption", "")
	head_box.add_child(_value_label)
	head_box.add_child(_rank_label)
	head_box.add_child(_gauge)
	head_box.add_child(_next_label)
	head.add_child(head_box)
	column.add_child(head)

	# Değerin nereden geldiği
	var parts: PlatePanel = PlatePanel.new()
	parts.theme_type_variation = &"HudCarPlate"
	parts.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_breakdown = VBoxContainer.new()
	_breakdown.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_breakdown.add_theme_constant_override(&"separation", 1)
	parts.add_child(_breakdown)
	column.add_child(parts)

	# Rütbe merdiveni
	var ladder_plate: PlatePanel = PlatePanel.new()
	ladder_plate.theme_type_variation = &"HudCarPlate"
	ladder_plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_ladder = VBoxContainer.new()
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.add_theme_constant_override(&"separation", 0)
	ladder_plate.add_child(_ladder)
	column.add_child(ladder_plate)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = "KAPAT"
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


# --- Güncelleme -------------------------------------------------------------------

func _refresh() -> void:
	var tree: SceneTree = get_tree()
	var value: int = GarageValue.compute(tree)
	var rank: int = GarageValue.rank(value)
	_value_label.text = "%s ₺" % Hud.format_thousands(value)
	_rank_label.text = "%d. RÜTBE — %s" % [rank, GarageValue.rank_name(rank)]
	_gauge.ratio = GarageValue.rank_ratio(value)
	var next: int = GarageValue.next_threshold(value)
	_next_label.text = ("EN ÜST RÜTBE" if next == 0
			else "SIRADAKİ RÜTBE: %s ₺ (%s ₺ kaldı)"
				% [Hud.format_thousands(next), Hud.format_thousands(next - value)])

	for child: Node in _breakdown.get_children():
		_breakdown.remove_child(child)
		child.queue_free()
	_breakdown.add_child(_row("ARAÇLAR", GarageValue.vehicles_value(tree), false))
	_breakdown.add_child(_row("GELİŞTİRMELER", GarageValue.upgrades_value(tree), false))
	_breakdown.add_child(_row("TAMİR ALANLARI", GarageValue.bays_value(tree), false))
	_breakdown.add_child(_row("BOYA", GarageValue.paint_value(tree), false))

	for child: Node in _ladder.get_children():
		_ladder.remove_child(child)
		child.queue_free()
	for i: int in GarageValue.THRESHOLDS.size():
		_ladder.add_child(_ladder_row(i + 1, value, rank))


## "ARAÇLAR .......... 85.000 ₺"
func _row(caption: String, amount: int, dim: bool) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left: Label = _label(&"HudInkCaption", caption)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var right: Label = _label(&"HudInkCaption", "%s ₺" % Hud.format_thousands(amount))
	if dim:
		left.modulate.a = 0.45
		right.modulate.a = 0.45
	row.add_child(left)
	row.add_child(right)
	return row


## Merdiven satırı: ulaşılan rütbeler koyu, içinde bulunulan rütbe amber, kilitliler soluk.
func _ladder_row(rank_index: int, value: int, current: int) -> HBoxContainer:
	var threshold: int = GarageValue.THRESHOLDS[rank_index - 1]
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	var no: Label = _label(&"HudInkCaption", "%d." % rank_index)
	no.custom_minimum_size = Vector2(24.0, 0.0)
	no.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var name_label: Label = _label(&"HudInkCaption", GarageValue.rank_name(rank_index))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var need: Label = _label(&"HudInkCaption",
			"AÇILDI" if value >= threshold else "%s ₺" % Hud.format_thousands(threshold))
	if rank_index == current:
		for label: Label in [no, name_label, need]:
			label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
		need.text = "ŞU ANDA"
	elif value < threshold:
		for label: Label in [no, name_label, need]:
			label.modulate.a = 0.45
	row.add_child(no)
	row.add_child(name_label)
	row.add_child(need)
	return row


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
