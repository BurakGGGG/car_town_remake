class_name MasteryScreen
extends Control
## USTALIK PANOSU — garajın duvarına asılı ustalık belgesi gibi: her arıza türü için yıldızlar,
## sayaç ve o işten gelen kalıcı bonuslar. Tamamen KODLA kurulur (.tscn yok), GarageScreen'in
## üstüne oturur ve "yol mobilyası / plaka" dilini kullanır (generic kart yok).
##
## HİÇBİR MANTIK BURADA DEĞİL: eşikler, yıldızlar ve bonuslar JobMastery'de hesaplanır; bu ekran
## yalnızca gösterir. Arıza listesi RepairManager'ın kataloğundan gelir, elle yazılmaz.

signal closed

const PLATE_WIDTH: float = 470.0

var _list: VBoxContainer
var _summary: Label
var _column: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "MasteryScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
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


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	_column = column

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", "USTALIK PANOSU")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	var head: PlatePanel = PlatePanel.new()
	head.theme_type_variation = &"HudCarPlate"
	head.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_summary = _label(&"HudInkCaption", "")
	head.add_child(_summary)
	column.add_child(head)

	var list_plate: PlatePanel = PlatePanel.new()
	list_plate.theme_type_variation = &"HudCarPlate"
	list_plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override(&"separation", 2)
	list_plate.add_child(_list)
	column.add_child(list_plate)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = "KAPAT"
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _refresh() -> void:
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if mastery == null:
		_summary.text = "USTALIK SİSTEMİ SAHNEDE YOK"
		return
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	var types: Array[RepairType] = repairs.repair_types if repairs and not repairs.repair_types.is_empty() else RepairType.defaults()
	var mastered: int = mastery.mastered_jobs().size()
	_summary.text = "TOPLAM %d ★   ·   HER YILDIZ: +%%%d XP, +%%%d ÖDÜL   ·   5★ İŞ: %d" % [
		mastery.total_stars(), roundi(JobMastery.XP_BONUS_PER_STAR * 100.0),
		roundi(JobMastery.REWARD_BONUS_PER_STAR * 100.0), mastered]
	for type: RepairType in types:
		_list.add_child(_row(mastery, type))


## "LASTİK   ★★★☆☆   74 / 120   +%30 XP · +%6 ÖDÜL"
func _row(mastery: JobMastery, type: RepairType) -> HBoxContainer:
	var stars: int = mastery.stars(type.id)
	var count: int = mastery.count(type.id)
	var next: int = mastery.next_threshold(type.id)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)

	var name_label: Label = _label(&"HudInkCaption", type.short_title())
	name_label.custom_minimum_size = Vector2(92.0, 0.0)
	var star_label: Label = _label(&"HudInkCaption",
			"★".repeat(stars) + "☆".repeat(maxi(JobMastery.BASE_THRESHOLDS.size() - stars, 0)))
	star_label.custom_minimum_size = Vector2(72.0, 0.0)
	var count_label: Label = _label(&"HudInkCaption",
			"%d / %d" % [count, next] if next > 0 else "%d   USTA" % count)
	count_label.custom_minimum_size = Vector2(86.0, 0.0)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var bonus_label: Label = _label(&"HudInkCaption", "+%%%d XP · +%%%d ₺" % [
		roundi(JobMastery.XP_BONUS_PER_STAR * float(stars) * 100.0),
		roundi(JobMastery.REWARD_BONUS_PER_STAR * float(stars) * 100.0)])
	bonus_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	if stars >= JobMastery.BASE_THRESHOLDS.size():
		for label: Label in [name_label, star_label, count_label, bonus_label]:
			label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	elif stars == 0 and count == 0:
		for label: Label in [name_label, star_label, count_label, bonus_label]:
			label.modulate.a = 0.5
	row.add_child(name_label)
	row.add_child(star_label)
	row.add_child(count_label)
	row.add_child(bonus_label)
	return row


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
