class_name SaveReminderCard
extends Control
## İLERLEMENİ KAYDET (2026-10-28, kullanıcı kararı: taslak B). Misafir seviye 5'e ve 10'a varınca sakin bir anda BİR KEZ
## açılır (eşik SaveReminder'da, sakin anı Hud seçer). Oyuncunun kendi seviyesi / parası / elması gösterilir: telefon
## değişirse bunlar gider. Kaydedene SaveReminder.BONUS_GEMS gem (kayıt buluta eşitlenince SaveReminder verir).
## GOOGLE / E-POSTA hesap panosunu (LoginScreen) açıp o yolla girişi başlatır; KAYIT SEÇ, hata ve bekleme orada.
## SONRA kapatır, o eşikte bir daha gelmez. UiRouter MODAL "save_reminder"; ekran TAMAMEN KODLA kurulur.

signal opened
signal closed
## Hesaba giriş istendi (CloudSaveManager.PROVIDER_GOOGLE / PROVIDER_EMAIL), kart kapandıktan sonra: Hud hesap panosunu
## açar.
signal sign_in_requested(provider: String)

const PANEL_WIDTH: float = 400.0
const GOOGLE_MARK: Texture2D = preload("res://ui/icons/google_g.svg")
const MAIL_MARK: Texture2D = preload("res://ui/icons/mail_plate.svg")

var _root: VBoxContainer
var _level: Label
var _money: Label
var _gems: Label
var _closing: bool = false
var _pending: String = ""   # kart kapanınca istenecek giriş yolu (pano üst üste binmesin)


func _ready() -> void:
	name = "SaveReminderCard"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()


func open() -> void:
	if visible:
		return
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	var level: int = progress.level if progress else 1
	_level.text = Loc.t("SEVİYE %d") % level
	_money.text = "%s ₺" % Hud.format_thousands(economy.money if economy else 0)
	_gems.text = Loc.t("%d GEM") % (progress.gems if progress else 0)
	var reminder: SaveReminder = get_tree().get_first_node_in_group("save_reminder") as SaveReminder
	if reminder:
		reminder.mark_shown(level)   # açıldı: ne seçilirse seçilsin bu eşik bir daha gelmez
	PlateAnim.pop_in(self, _root)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _root, func() -> void:
		hide()
		_closing = false
		closed.emit()
		if not _pending.is_empty():
			var provider: String = _pending
			_pending = ""
			sign_in_requested.emit(provider))


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
	var title: Label = _label(&"HudSignTitle", Loc.t("İLERLEMENİ KAYDET"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	_root.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	info.add_child(box)
	box.add_child(_wrapped(Loc.t("Garajın, araçların ve elmasların şu an yalnızca bu telefonda. Telefon değişir ya da oyun silinirse hepsi kaybolur. Hesabına kaydet, her telefonda devam et.")))
	var stats: HBoxContainer = HBoxContainer.new()
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override(&"separation", 16)
	_level = _label(&"HudPlateTitle", "")
	_money = _label(&"HudPlateTitle", "")
	_money.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_gems = _label(&"HudPlateTitle", "")
	_gems.add_theme_color_override(&"font_color", HudPalette.GEM_DARK)
	for label: Label in [_level, _money, _gems]:
		stats.add_child(label)
	box.add_child(stats)
	var gift: HBoxContainer = HBoxContainer.new()
	gift.name = "Gift"
	gift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gift.alignment = BoxContainer.ALIGNMENT_CENTER
	gift.add_theme_constant_override(&"separation", 6)
	var gem: HudIcon = HudIcon.new()
	gem.kind = HudIcon.Kind.GEM
	gem.icon_size = 22.0
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gift.add_child(gem)
	var gift_label: Label = _label(&"HudPlateTitle", Loc.t("KAYDEDENE +%d GEM HEDİYE") % SaveReminder.BONUS_GEMS)
	gift_label.add_theme_color_override(&"font_color", HudPalette.GEM_DARK)
	gift.add_child(gift_label)
	box.add_child(gift)
	_root.add_child(info)

	var google: PlateButton = _button("GoogleButton", Loc.t("GOOGLE İLE KAYDET"), GOOGLE_MARK)
	google.highlight = true
	google.pressed.connect(_request.bind(CloudSaveManager.PROVIDER_GOOGLE))
	_root.add_child(google)
	var email: PlateButton = _button("EmailButton", Loc.t("E-POSTA İLE KAYDET"), MAIL_MARK)
	email.pressed.connect(_request.bind(CloudSaveManager.PROVIDER_EMAIL))
	_root.add_child(email)

	var later: PlateButton = PlateButton.new()
	later.name = "LaterButton"
	later.theme_type_variation = &"HudPlateSmall"
	later.text = Loc.t("SONRA")
	later.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	later.focus_mode = Control.FOCUS_NONE
	later.pressed.connect(_on_later)
	_root.add_child(later)


func _button(node_name: String, text: String, mark: Texture2D) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudPlate"
	button.text = text
	button.kind = HudIcon.Kind.NONE
	button.avatar = mark
	button.avatar_frame = false   # logo çerçevesiz, olduğu gibi
	button.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	button.focus_mode = Control.FOCUS_NONE
	return button


func _request(provider: String) -> void:
	Telemetry.event(&"save_prompt_choice", {"option": Telemetry.account_kind(provider)})
	_pending = provider
	close()


func _on_later() -> void:
	Telemetry.event(&"save_prompt_choice", {"option": "later"})
	close()


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
