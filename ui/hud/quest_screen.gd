class_name QuestScreen
extends Control
## GÖREVLER tabelası: aktif görevler (en fazla QuestManager.ACTIVE_COUNT), ilerleme şeridi, ödül ve
## ÖDÜLÜ AL plakası. Ekran TAMAMEN KODLA kurulur (.tscn yok); HUD onu LoginScreen gibi temalı Root'un
## altına ekler. Mantık burada değil: ilerleme ve ödül QuestManager'dadır ("quests" grubu); bu ekran
## yalnızca gösterir ve ÖDÜLÜ AL'ı ona iletir. Oyunu engellemez: KAPAT ile oyun sürer.

signal opened
signal closed
## Ödül alındı (HUD kısa bildirim gösterir).
signal reward_claimed(text: String)

const PLATE_WIDTH: float = 440.0

var _quests: QuestManager
var _list: VBoxContainer
var _empty: PlatePanel


func _ready() -> void:
	name = "QuestScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()
	_connect_quests.call_deferred()


func open() -> void:
	_refresh()
	if visible:
		return
	show()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	closed.emit()


# --- Kurulum -----------------------------------------------------------------

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
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", "GÖREVLER")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	_list = VBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override(&"separation", 8)
	column.add_child(_list)

	_empty = PlatePanel.new()
	_empty.theme_type_variation = &"HudCarPlate"
	_empty.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_empty.add_child(_label(&"HudInkCaption", "Tüm görevler tamamlandı. Yenileri yolda!"))
	column.add_child(_empty)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = "KAPAT"
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


## Tek görev plakası: başlık, açıklama, şerit + sayı, ödül; sağda ÖDÜLÜ AL.
func _quest_plate(entry: Dictionary) -> PlatePanel:
	var quest_id: StringName = entry["id"]
	var target: int = int(entry["target"])
	var value: int = _quests.progress(quest_id)
	var done: bool = _quests.is_complete(quest_id)

	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	plate.add_child(row)

	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override(&"separation", 2)
	texts.add_child(_label(&"HudPlateTitle", String(entry["title"])))
	texts.add_child(_label(&"HudInkCaption", String(entry["text"])))
	var gauge_row: HBoxContainer = HBoxContainer.new()
	gauge_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gauge_row.add_theme_constant_override(&"separation", 8)
	var gauge: XpLane = XpLane.new()
	gauge.custom_minimum_size = Vector2(150.0, 8.0)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.segments = 10
	gauge.ratio = float(value) / float(maxi(target, 1))
	gauge_row.add_child(gauge)
	gauge_row.add_child(_label(&"HudInkCaption", _count_text(entry, value)))
	texts.add_child(gauge_row)
	var reward: Label = _label(&"HudInkCaption", _reward_text(entry))
	reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	texts.add_child(reward)
	row.add_child(texts)

	var claim: PlateButton = PlateButton.new()
	claim.theme_type_variation = &"HudPlateSmall"
	claim.text = "ÖDÜLÜ AL" if done else "DEVAM"
	claim.disabled = not done
	claim.highlight = done   # alınabilir ödül amber plaka olarak öne çıkar
	claim.custom_minimum_size = Vector2(100.0, 0.0)
	claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	claim.focus_mode = Control.FOCUS_NONE
	claim.pressed.connect(_on_claim_pressed.bind(quest_id))
	row.add_child(claim)
	return plate


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# --- QuestManager ----------------------------------------------------------------

func _connect_quests() -> void:
	_quests = get_tree().get_first_node_in_group("quests") as QuestManager
	if _quests:
		_quests.quests_changed.connect(_refresh)


func _refresh() -> void:
	if _list == null:
		return
	for child: Node in _list.get_children():
		child.queue_free()
	var active: Array[Dictionary] = _quests.active_quests() if _quests else []
	for entry: Dictionary in active:
		_list.add_child(_quest_plate(entry))
	_empty.visible = active.is_empty()


func _on_claim_pressed(quest_id: StringName) -> void:
	if _quests == null:
		return
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	if _quests.claim(quest_id):
		reward_claimed.emit(_reward_text(entry))
	_refresh()


# --- Metin -----------------------------------------------------------------------------

## "2 / 3" ya da para görevlerinde "600 / 1.000 ₺"
static func _count_text(entry: Dictionary, value: int) -> String:
	var target: int = int(entry["target"])
	if int(entry["type"]) == QuestCatalog.Type.REPAIR_MONEY:
		return "%s / %s ₺" % [Hud.format_thousands(value), Hud.format_thousands(target)]
	return "%d / %d" % [value, target]


## "+30 XP  +5 GEM  +1.000 ₺"
static func _reward_text(entry: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	if int(entry.get("xp", 0)) > 0:
		parts.append("+%d XP" % int(entry["xp"]))
	if int(entry.get("gems", 0)) > 0:
		parts.append("+%d GEM" % int(entry["gems"]))
	if int(entry.get("money", 0)) > 0:
		parts.append("+%s ₺" % Hud.format_thousands(int(entry["money"])))
	return "   ".join(parts)
