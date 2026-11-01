class_name RenamePrompt
extends Control
## YENİ TAKMA AD ÖNERİSİ (2026-11-01, kullanıcı kararı): adı hâlâ eski otomatik "Usta1234" olan oyuncuya güncellemeden
## sonra BİR KEZ, açılıştaki gazete / hediye / ders kapandıktan sonra sakin bir anda açılır (Hud._tick_rename_prompt).
## Havuzdan (NamePool, oyun dilinde) bir ad önerir; ZAR yenisini çeker. KAYDET → SocialManager.rename, KALSIN → kapanır.
## İkisinde de bu hesap için bu cihazda bir daha sorulmaz (SocialManager.mark_rename_offered). UiRouter MODAL
## "rename_prompt"; ekran TAMAMEN KODLA kurulur.

signal opened
signal closed

const PANEL_WIDTH: float = 400.0

var _social: SocialManager
var _root: VBoxContainer
var _old_name: Label
var _suggestion: Label
var _save: PlateButton
var _keep: PlateButton
var _dice: PlateButton
var _closing: bool = false


func _ready() -> void:
	name = "RenamePrompt"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()


func open() -> void:
	if visible:
		return
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		_social.mark_rename_offered()   # gösterildi: ne seçilirse seçilsin bir daha sorulmaz
		_old_name.text = Loc.t("Şu anki adın: %s") % _social.my_name()
	_reroll()
	_set_busy(false)
	PlateAnim.pop_in(self, _root)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _root, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Önerilen ad (testler okur).
func suggestion() -> String:
	return _suggestion.text


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	center.name = "Center"
	_root = VBoxContainer.new()
	_root.name = "Column"
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_theme_constant_override(&"separation", 8)
	center.add_child(_root)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("YENİ TAKMA AD"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_root.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	info.add_child(box)
	box.add_child(_wrapped(Loc.t("Garajına yakışan bir takma ad seçtik. Beğenmezsen zarı at!")))
	_old_name = _label(&"HudInkCaption", "")
	_old_name.modulate.a = 0.7
	box.add_child(_old_name)

	var name_row: HBoxContainer = HBoxContainer.new()
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_row.add_theme_constant_override(&"separation", 8)
	var name_plate: PanelContainer = PanelContainer.new()   # yazı alanı görünümü (ad düzenlemedeki LineEdit ile aynı)
	name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_plate.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_plate.custom_minimum_size = Vector2(0.0, 48.0)
	var field: StyleBoxFlat = StyleBoxFlat.new()
	field.bg_color = HudPalette.PLATE_HOVER
	field.border_color = HudPalette.PLATE_SELECTED_EDGE
	field.set_border_width_all(2)
	field.set_corner_radius_all(6)
	field.content_margin_left = 10.0
	field.content_margin_right = 10.0
	name_plate.add_theme_stylebox_override(&"panel", field)
	_suggestion = _label(&"HudPlateTitle", "")
	_suggestion.name = "Suggestion"
	_suggestion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_suggestion.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_plate.add_child(_suggestion)
	name_row.add_child(name_plate)
	_dice = dice_button(_reroll, 48.0)
	name_row.add_child(_dice)
	box.add_child(name_row)

	var hint: Label = _wrapped(Loc.t("İstediğin zaman PROFİL > DÜZENLE'den değiştirebilirsin."))
	hint.modulate.a = 0.7
	box.add_child(hint)
	_root.add_child(info)

	_save = PlateButton.new()
	_save.name = "SaveButton"
	_save.theme_type_variation = &"HudPlate"
	_save.kind = HudIcon.Kind.CHECK
	_save.highlight = true
	_save.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_save.focus_mode = Control.FOCUS_NONE
	_save.pressed.connect(_on_save)
	_root.add_child(_save)

	_keep = PlateButton.new()
	_keep.name = "KeepButton"
	_keep.theme_type_variation = &"HudPlateSmall"
	_keep.text = Loc.t("KALSIN")
	_keep.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_keep.focus_mode = Control.FOCUS_NONE
	_keep.pressed.connect(close)
	_root.add_child(_keep)


## ZAR düğmesi (kart, PROFİL › DÜZENLE, ARKADAŞLAR): kare plaka, ortada zar simgesi. PlateButton'ın kendi simgesi
## yazının üstüne yerleşir; yazısız düğmede ortalansın diye simge ayrı bir HudIcon çocuğudur.
static func dice_button(on_press: Callable, height: float = 44.0) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = "DiceButton"
	button.theme_type_variation = &"HudPlateSmall"
	button.bolts = false
	button.custom_minimum_size = Vector2(height + 8.0, height)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	var icon: HudIcon = HudIcon.new()
	icon.kind = HudIcon.Kind.DICE
	icon.icon_size = roundf(height * 0.55)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_child(icon)
	button.pressed.connect(on_press)
	return button


func _reroll() -> void:
	var current: String = _suggestion.text
	var next: String = SocialNames.default_name()
	for i: int in 4:   # aynı ad üst üste gelmesin
		if next != current:
			break
		next = SocialNames.default_name()
	_suggestion.text = next


func _on_save() -> void:
	if _social == null or not _social.is_ready():
		close()
		return
	_set_busy(true)
	_save.text = Loc.t("BİR SANİYE…")
	await _social.rename(_suggestion.text)   # sonucu SocialManager HUD bildirimiyle söyler
	close()


func _set_busy(busy: bool) -> void:
	_save.disabled = busy
	_keep.disabled = busy
	_dice.disabled = busy
	if not busy:
		_save.text = Loc.t("KAYDET")


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(text: String) -> Label:
	var label: Label = _label(&"HudInkCaption", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	return label
