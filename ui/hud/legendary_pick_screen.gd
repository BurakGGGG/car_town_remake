class_name LegendaryPickScreen
extends Control
## EFSANEVİ ARACINI SEÇ (2026-10-23, ARKADAŞ DAVETİ 10. basamak; docs/ARKADAS_DAVET.md). SÜPER KASA havuzunda sahip
## olunmayan araçlar kart olarak dizilir; oyuncu birini seçer → ReferralManager.choose_car → ödül penceresi. Havuzun
## hepsine zaten sahipse seçim yerine elmas (ReferralRewards.LEGENDARY_FALLBACK_GEMS). SONRA SEÇ: hak kayıtta kalır
## (ARKADAŞLAR › DAVET ET'teki 10. basamaktan yeniden açılır). Açanlar: POSTA penceresi (10. basamak alınınca) ve DAVET ET
## sekmesi. HUD kurar (UiRouter SUB &"legendary_pick"). Ekran tamamen kodla kurulur.

signal opened
signal closed

const COLUMNS: int = 4
const CARD_SIZE: Vector2 = Vector2(176.0, 128.0)
const COMPACT_CARD: Vector2 = Vector2(168.0, 104.0)
const COMPACT_HEIGHT: float = 600.0
const WIDTH: float = 4.0 * 176.0 + 3.0 * 8.0

var _hud: Hud
var _referral: ReferralManager
var _column: VBoxContainer
var _text: Label
var _grid: GridContainer
var _confirm: PlateButton
var _later: PlateButton
var _popup: RewardPopup
var _picked: StringName = &""
var _group: ButtonGroup = ButtonGroup.new()
var _closing: bool = false


func _init(hud: Hud) -> void:
	name = "LegendaryPickScreen"
	_hud = hud


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_referral = get_tree().get_first_node_in_group("referral") as ReferralManager
	_picked = &""
	_closing = false
	_fill()
	PlateAnim.pop_in(self, _column)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Seçilecek araçlar (testler / QA): kartların araç kimlikleri, ekrandaki sırayla.
func choices() -> Array[StringName]:
	var out: Array[StringName] = []
	for card: Node in _grid.get_children():
		out.append(StringName(card.get_meta(&"car", "")))
	return out


## Kart seçimi (testler de çağırır).
func pick(id: StringName) -> void:
	_picked = id
	for card: Node in _grid.get_children():
		(card as Button).set_pressed_no_signal(StringName(card.get_meta(&"car", "")) == id)
		(card as Control).queue_redraw()
	_confirm.disabled = _picked == &""
	_confirm.text = Loc.t("%s AL") % FriendsScreen.car_name(_picked) if _picked != &"" else Loc.t("BİR ARAÇ SEÇ")


func _fill() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var compact: bool = get_viewport_rect().size.y < COMPACT_HEIGHT
	var pool: Array[StringName] = []
	if _referral:
		pool = _referral.car_pool()
	var rights: int = _referral.car_choices if _referral else 0
	_grid.visible = not pool.is_empty()
	if pool.is_empty():
		_text.text = Loc.t("Bütün efsanevi araçlar zaten garajında! Seçim yerine %d GEM alırsın.") \
			% ReferralRewards.LEGENDARY_FALLBACK_GEMS
		_confirm.text = Loc.t("+%d GEM AL") % ReferralRewards.LEGENDARY_FALLBACK_GEMS
		_confirm.disabled = rights <= 0
		return
	_text.text = Loc.t("10 arkadaşını Auto Yard'a getirdin! Garajına koyacağın efsanevi aracı seç.")
	for id: StringName in pool:
		_grid.add_child(_card(id, COMPACT_CARD if compact else CARD_SIZE))
	pick(&"")
	_confirm.disabled = true


func _on_confirm() -> void:
	if _referral == null:
		return
	var summary: Dictionary = {}
	if _grid.visible:
		if _picked == &"" or not _referral.choose_car(_picked):
			return
		summary = {"title": Loc.t("ARACIN GARAJINDA!"), "items": ["+1 " + FriendsScreen.car_name(_picked)]}
	elif _referral.take_fallback():
		summary = {"title": Loc.t("ÖDÜL KAZANDIN!"), "gems": ReferralRewards.LEGENDARY_FALLBACK_GEMS}
	if summary.is_empty():
		return
	close()
	if _popup == null:
		_popup = RewardPopup.new()
		_popup.hud = _hud
		_hud.get_node("Root").add_child(_popup)
	_popup.show_rewards(summary)


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("EFSANEVİ ARACINI SEÇ"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	info.add_child(box)
	_text = _label(&"HudInkCaption", "")
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_text)
	_grid = GridContainer.new()
	_grid.name = "Cars"
	_grid.columns = COLUMNS
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override(&"h_separation", 8)
	_grid.add_theme_constant_override(&"v_separation", 8)
	_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_grid)
	_column.add_child(info)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override(&"separation", 8)
	_later = PlateButton.new()
	_later.name = "LaterButton"
	_later.theme_type_variation = &"HudPlateSmall"
	_later.text = Loc.t("SONRA SEÇ")
	_later.focus_mode = Control.FOCUS_NONE
	_later.custom_minimum_size = Vector2(180.0, 54.0)
	_later.pressed.connect(close)
	buttons.add_child(_later)
	_confirm = PlateButton.new()
	_confirm.name = "ConfirmButton"
	_confirm.theme_type_variation = &"HudPlate"
	_confirm.kind = HudIcon.Kind.CAR
	_confirm.highlight = true
	_confirm.focus_mode = Control.FOCUS_NONE
	_confirm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_confirm.custom_minimum_size = Vector2(0.0, 54.0)
	_confirm.pressed.connect(_on_confirm)
	buttons.add_child(_confirm)
	_column.add_child(buttons)


## Araç kartı: resim + ad + sınıf; dokununca seçilir (altın kenar).
func _card(id: StringName, card_size: Vector2) -> Button:
	var card: Button = Button.new()
	card.name = "Car_" + String(id)
	card.set_meta(&"car", String(id))
	card.toggle_mode = true
	card.button_group = _group
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = card_size
	for state: StringName in [&"normal", &"hover", &"focus", &"disabled", &"pressed", &"hover_pressed"]:
		var selected: bool = state in [&"pressed", &"hover_pressed"]
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.INK if not selected else Color("3A3226")
		style.border_color = HudPalette.PLATE_SELECTED if selected else Color(HudPalette.PLATE_SELECTED, 0.35)
		style.set_border_width_all(4 if selected else 2)
		style.set_corner_radius_all(10)
		card.add_theme_stylebox_override(state, style)
	card.pressed.connect(func() -> void: pick(id))
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 0)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 6.0
	column.offset_right = -6.0
	column.offset_top = 4.0
	column.offset_bottom = -4.0
	card.add_child(column)
	var thumb: TextureRect = TextureRect.new()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var path: String = ProfileCard.THUMB_DIR + String(id) + ".png"
	if ResourceLoader.exists(path):
		thumb.texture = load(path) as Texture2D
	column.add_child(thumb)
	var name_label: Label = _label(&"HudInkCaption", FriendsScreen.car_name(id))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(name_label)
	return card


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
