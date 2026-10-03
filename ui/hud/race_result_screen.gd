class_name RaceResultScreen
extends Control
## YARIŞ SONUCU panosu — pistin üstüne açılır (UiRouter MODAL). Ödülü KENDİSİ vermez:
## parayı ve XP'yi RaceManager.finish_race() tek seferlik olarak yazar, bu ekran yalnızca gösterir.
## GARAJA DÖN plakası (ya da ESC) hem sonucu hem pisti kapatır.

signal closed
## GARAJA DÖN: yarış modundan tamamen çıkılacak.
signal exit_requested
## Oyuncu "REKLAM İZLE" plakasına bastı (açık onay). Reklamı ve ödülü HUD yönetir; bu ekran yalnızca gösterir.
signal bonus_requested

const PLATE_WIDTH: float = 380.0

var _title: Label
var _reward: Label
var _times: Label
var _winner: Label
var _bonus_button: PlateButton
var _bonus_amount: int = 0
var _column: VBoxContainer
var _closing: bool = false


func _ready() -> void:
	name = "RaceResultScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Sonuç verileri dışarıdan gelir (yarış ekranı + RaceManager ödülü).
func show_result(won: bool, player_time: float, rival_time: float, money: int, xp: int,
		winner_id: StringName) -> void:
	_title.text = "KAZANDIN!" if won else "KAYBETTİN"
	var parts: PackedStringArray = PackedStringArray()
	if money > 0:
		parts.append("+%s ₺" % Hud.format_thousands(money))
	if xp > 0:
		parts.append("+%d XP" % xp)
	_reward.text = "   ".join(parts) if not parts.is_empty() else "ÖDÜL YOK"
	_times.text = "SEN  %.2f sn        RAKİP  %.2f sn" % [player_time, rival_time]
	hide_bonus()
	_winner.text = "KAZANAN: %s" % String(CarCatalog.get_entry(winner_id).get("display_name", winner_id)).to_upper()


## Ödüllü reklam teklifi: "REKLAM İZLE +X ₺". Yalnızca oyuncu basarsa reklam gösterilir.
func offer_bonus(amount: int) -> void:
	_bonus_amount = amount
	_bonus_button.text = "REKLAM İZLE   +%s ₺" % Hud.format_thousands(amount)
	_bonus_button.disabled = false
	_bonus_button.visible = true


## Reklam bitti ama ödül hak edilmedi (erken kapatıldı): teklif tekrar basılabilir olsun.
func rearm_bonus() -> void:
	if _bonus_amount > 0:
		_bonus_button.disabled = false
		_bonus_button.visible = true


## Ödül verildi: teklif kapanır, ödül satırı bonusu gösterir.
func bonus_granted(amount: int) -> void:
	_bonus_button.visible = false
	_bonus_amount = 0
	_reward.text = "%s   +%s ₺ BONUS" % [_reward.text, Hud.format_thousands(amount)]


func hide_bonus() -> void:
	_bonus_amount = 0
	_bonus_button.visible = false


func open() -> void:
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

	var center: CenterContainer = FitScroll.center_in(self)

	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 6)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var head: Label = _label(&"HudSignTitle", "YARIŞ BİTTİ")
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(head)
	_column.add_child(sign)

	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	_title = _label(&"HudPlateTitle", "")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward = _label(&"HudInkValue", "")
	_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_times = _label(&"HudInkCaption", "")
	_times.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner = _label(&"HudInkCaption", "")
	_winner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for label: Label in [_title, _reward, _times, _winner]:
		box.add_child(label)
	plate.add_child(box)
	_column.add_child(plate)

	_bonus_button = PlateButton.new()
	_bonus_button.name = "BonusButton"
	_bonus_button.theme_type_variation = &"HudPlate"
	_bonus_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	_bonus_button.focus_mode = Control.FOCUS_NONE
	_bonus_button.visible = false
	_bonus_button.pressed.connect(func() -> void:
		_bonus_button.disabled = true   # çift dokunuş: reklam bitene kadar pasif
		bonus_requested.emit())
	_column.add_child(_bonus_button)

	var exit_button: PlateButton = PlateButton.new()
	exit_button.name = "ExitButton"
	exit_button.theme_type_variation = &"HudPlate"
	exit_button.text = "GARAJA DÖN"
	exit_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	exit_button.focus_mode = Control.FOCUS_NONE
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	_column.add_child(exit_button)


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
