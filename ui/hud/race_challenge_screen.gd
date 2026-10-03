class_name RaceChallengeScreen
extends Control
## YARIŞ DAVETİ panosu — yoldan gelen rakibin 🏁 balonuna dokununca açılır.
## İki araç yan yana: oyuncunun aracı ve rakip; statlar cars.json'daki "race" bloğundan
## (DragRaceSim.stats_of) gelir, ödül RaceManager'dan — UI'da hardcode sayı yoktur.
## Plaka dili: her araç bir PlatePanel, aksiyonlar plaka buton. UiRouter bunu MODAL olarak açar.

signal closed
## YARIŞ plakasına basıldı.
signal race_accepted

const PLATE_WIDTH: float = 210.0

var _player_plate: PlatePanel
var _rival_plate: PlatePanel
var _player_labels: Dictionary = {}
var _rival_labels: Dictionary = {}
var _reward_label: Label
var _column: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "RaceChallengeScreen"
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


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Soru doğrudan panoda: oyuncu "ne istiyor bu araç?" diye düşünmesin
	var title: Label = _label(&"HudSignTitle", "YARIŞMAK İSTER MİSİN?")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_column.add_child(sign)

	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	_player_plate = _car_plate(row, "SENİN ARACIN", _player_labels)
	_rival_plate = _car_plate(row, "RAKİP", _rival_labels)
	_column.add_child(row)

	var reward_plate: PlatePanel = PlatePanel.new()
	reward_plate.theme_type_variation = &"HudCarPlate"
	reward_plate.custom_minimum_size = Vector2(PLATE_WIDTH * 2.0 + 8.0, 0.0)
	_reward_label = _label(&"HudInkValue", "")
	_reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_label.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	reward_plate.add_child(_reward_label)
	_column.add_child(reward_plate)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override(&"separation", 8)
	var accept: PlateButton = PlateButton.new()
	accept.name = "AcceptButton"
	accept.theme_type_variation = &"HudPlate"
	accept.kind = HudIcon.Kind.NONE
	accept.text = "YARIŞ"
	accept.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	accept.focus_mode = Control.FOCUS_NONE
	accept.pressed.connect(func() -> void: race_accepted.emit())
	var cancel: PlateButton = PlateButton.new()
	cancel.theme_type_variation = &"HudPlateSmall"
	cancel.text = "VAZGEÇ"
	cancel.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	cancel.focus_mode = Control.FOCUS_NONE
	cancel.pressed.connect(close)
	buttons.add_child(accept)
	buttons.add_child(cancel)
	_column.add_child(buttons)


func _car_plate(row: HBoxContainer, caption: String, labels: Dictionary) -> PlatePanel:
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 1)
	labels["caption"] = _label(&"HudInkCaption", caption)
	labels["name"] = _label(&"HudPlateTitle", "")
	labels["class"] = _label(&"HudInkCaption", "")
	labels["overall"] = _label(&"HudInkCaption", "")
	for key: String in ["caption", "name", "class", "overall"]:
		box.add_child(labels[key])
	plate.add_child(box)
	row.add_child(plate)
	return plate


# --- Güncelleme -------------------------------------------------------------------

func _refresh() -> void:
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race == null:
		return
	var player_id: StringName = race.player_vehicle_id()
	var rival: StringName = race.rival_id()
	_fill(_player_labels, player_id)
	_fill(_rival_labels, rival)
	var reward: Dictionary = race.reward_for(rival, true)
	var loss: Dictionary = race.reward_for(rival, false)
	_reward_label.text = "KAZANIRSAN  +%s ₺  ·  +%d XP\nKAYBEDERSEN  +%d XP" % [
		Hud.format_thousands(int(reward["money"])), int(reward["xp"]), int(loss["xp"])]


func _fill(labels: Dictionary, vehicle_id: StringName) -> void:
	var entry: Dictionary = CarCatalog.get_entry(vehicle_id)
	(labels["name"] as Label).text = String(entry.get("display_name", vehicle_id)).to_upper()
	(labels["class"] as Label).text = "%s SINIFI" % String(entry.get("class", "?"))
	(labels["overall"] as Label).text = "GENEL  %d" % DragRaceSim.overall_of(vehicle_id)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
