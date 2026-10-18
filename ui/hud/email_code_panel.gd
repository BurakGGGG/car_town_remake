class_name EmailCodePanel
extends Control
## E-POSTA İLE GİRİŞ penceresi: e-posta adresi → 6 haneli kod → giriş. Kod sunucuda üretilir, e-postayla gider ve
## sunucuda doğrulanır (CloudSaveManager.request_email_code / submit_email_code → firebase/functions/email_code.js);
## şifre yoktur. İlk açılış giriş ekranı (LoginGate) ve PLAYER ekranı (misafirken giriş; e-postayla girilmiş hesabı
## silerken yeniden doğrulama — adres kilitli, kod açılınca kendiliğinden istenir) kullanır.
## Ekran klavyesi açılınca pencere klavyenin üstünde kalır (alt pay = klavye yüksekliği, tuval birimiyle).
## Pencere kendini kapatmaz: açan, accepted / cancelled gelince kaldırır.

## Kod doğrulandı, Firebase'e giriliyor (sonuç CloudSaveManager durumuyla gelir).
signal accepted
## GERİ / VAZGEÇ: hiçbir şey değişmedi.
signal cancelled

enum Step { EMAIL, CODE }

const PANEL_WIDTH: float = 380.0
const CODE_LENGTH: int = 6

var _cloud: CloudSaveManager
var _reauth: bool = false
var _step: Step = Step.EMAIL
var _email: String = ""
var _busy: bool = false
var _resend_left: float = 0.0
var _keyboard: int = -1

var _margin: MarginContainer
var _title: Label
var _body: Label
var _edit: LineEdit
var _status: Label
var _primary: PlateButton
var _back: PlateButton
var _resend: PlateButton


## cloud: girişi yapan CloudSaveManager. reauth_email doluysa hesap silme doğrulaması: adres değişmez, kod hemen istenir.
func setup(cloud: CloudSaveManager, reauth_email: String = "") -> void:
	_cloud = cloud
	_reauth = not reauth_email.is_empty()
	_email = reauth_email
	if _cloud:
		_cloud.email_code_sent.connect(_on_code_sent)
		_cloud.email_code_failed.connect(_on_failed)
		_cloud.email_code_accepted.connect(_on_accepted)


func _ready() -> void:
	name = "EmailCodePanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_show_step(Step.EMAIL)
	if _reauth:
		_send()
	else:
		_focus_edit.call_deferred()


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_margin = MarginContainer.new()
	_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = _label(&"HudSignTitle")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	info.add_child(box)
	column.add_child(info)
	_body = _label(&"HudInkCaption")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	box.add_child(_body)
	_edit = _line_edit()
	_edit.text_changed.connect(_on_text_changed)
	_edit.text_submitted.connect(func(_t: String) -> void: _on_primary())
	box.add_child(_edit)
	_status = _label(&"HudInkCaption")
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	box.add_child(_status)

	_primary = _button(&"HudPlate", _on_primary)
	_primary.name = "PrimaryButton"
	_primary.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	column.add_child(_primary)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 8)
	column.add_child(row)
	_back = _button(&"HudPlateSmall", _on_back)
	_back.name = "BackButton"
	_back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_back)
	_resend = _button(&"HudPlateSmall", _send)
	_resend.name = "ResendButton"
	_resend.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_resend)
	column.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)


func _label(variation: StringName) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(variation: StringName, on_pressed: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


## ARKADAŞLAR ekranındaki giriş kutusuyla aynı görünüm (plaka zemini, kenar, mürekkep yazı).
func _line_edit() -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.name = "Input"
	edit.custom_minimum_size = Vector2(0.0, PlateButton.MIN_PLATE_HEIGHT + 4.0)
	edit.focus_mode = Control.FOCUS_ALL
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_color_override(&"font_color", HudPalette.INK)
	edit.add_theme_color_override(&"font_uneditable_color", HudPalette.INK_SOFT)
	edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	edit.add_theme_font_size_override(&"font_size", 20)
	for style_name: StringName in [&"normal", &"focus", &"read_only"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if style_name == &"focus" else HudPalette.PLATE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		edit.add_theme_stylebox_override(style_name, style)
	return edit


# --- Adımlar ---------------------------------------------------------------------------------

func _show_step(step: Step) -> void:
	_step = step
	_title.text = Loc.t("HESABI DOĞRULA") if _reauth else Loc.t("E-POSTA İLE GİRİŞ")
	_edit.clear()
	if step == Step.EMAIL:
		_body.text = Loc.t("Hesabının e-posta adresine 6 haneli bir kod gönderiyoruz.") if _reauth \
			else Loc.t("E-posta adresini yaz, sana 6 haneli bir giriş kodu gönderelim. Şifre gerekmez.")
		_edit.text = _email
		_edit.editable = not _reauth
		_edit.max_length = 254
		_edit.placeholder_text = Loc.t("e-posta adresin")
		_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_EMAIL_ADDRESS
		_primary.text = Loc.t("KOD GÖNDER")
	else:
		_body.text = Loc.t("%s adresine 6 haneli bir kod gönderdik. Gelmediyse gereksiz (spam) klasörüne de bak.") % _email
		_edit.editable = true
		_edit.max_length = CODE_LENGTH
		_edit.placeholder_text = "••••••"
		_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		_primary.text = Loc.t("DOĞRULA") if _reauth else Loc.t("GİRİŞ YAP")
	_back.text = Loc.t("VAZGEÇ") if _reauth or step == Step.EMAIL else Loc.t("E-POSTAYI DEĞİŞTİR")
	_set_status("")
	_refresh_buttons()


func _refresh_buttons() -> void:
	_primary.disabled = _busy
	_back.disabled = _busy and _step == Step.CODE and not _reauth
	_resend.visible = _step == Step.CODE
	_resend.disabled = _busy or _resend_left > 0.0
	_resend.text = Loc.t("YENİDEN GÖNDER (%d)") % ceili(_resend_left) if _resend_left > 0.0 else Loc.t("KODU YENİDEN GÖNDER")


func _set_status(text: String, error: bool = false) -> void:
	_status.text = text
	_status.visible = not text.is_empty()
	_status.add_theme_color_override(&"font_color", HudPalette.DANGER if error else HudPalette.INK_SOFT)


func _focus_edit() -> void:
	if is_inside_tree() and _edit.editable:
		_edit.grab_focus()


# --- Düğmeler ---------------------------------------------------------------------------------

func _on_primary() -> void:
	if _busy:
		return
	if _step == Step.EMAIL:
		_email = _edit.text.strip_edges().to_lower() if not _reauth else _email
		_send()
	else:
		_verify()


func _on_back() -> void:
	if _step == Step.CODE and not _reauth:
		_show_step(Step.EMAIL)   # yanlış adres: geri dön, düzelt
		_focus_edit.call_deferred()
		return
	_edit.release_focus()
	cancelled.emit()


func _send() -> void:
	if _busy or _cloud == null:
		return
	if not CloudSaveManager.is_valid_email(_email):
		_set_status(Loc.t("Geçerli bir e-posta adresi yaz."), true)
		return
	_busy = true
	_set_status(Loc.t("Gönderiliyor…"))
	_refresh_buttons()
	_cloud.request_email_code(_email)


func _verify() -> void:
	var code: String = _edit.text.strip_edges()
	if code.length() != CODE_LENGTH:
		_set_status(Loc.t("Kod 6 haneli olmalı."), true)
		return
	_busy = true
	_set_status(Loc.t("Doğrulanıyor…"))
	_refresh_buttons()
	_cloud.submit_email_code(_email, code)


## Kod kutusuna yalnızca rakam girer; 6 hane dolunca kendiliğinden doğrulanır.
func _on_text_changed(text: String) -> void:
	if _step != Step.CODE:
		return
	var digits: String = ""
	for c: String in text:
		if c >= "0" and c <= "9":
			digits += c
	if digits != text:
		_edit.text = digits
		_edit.caret_column = digits.length()
	if digits.length() == CODE_LENGTH and not _busy:
		_verify()


# --- CloudSaveManager -------------------------------------------------------------------------

func _on_code_sent(email: String) -> void:
	_busy = false
	_email = email
	_resend_left = float(CloudSaveManager.EMAIL_RESEND_SECONDS)
	if _step != Step.CODE:
		_show_step(Step.CODE)
	else:
		_edit.clear()
		_set_status(Loc.t("Yeni kod gönderildi."))
		_refresh_buttons()
	_focus_edit.call_deferred()


func _on_failed(text: String) -> void:
	_busy = false
	_set_status(text, true)
	if _step == Step.CODE:
		_edit.clear()
	_refresh_buttons()


func _on_accepted() -> void:
	_busy = false
	_edit.release_focus()
	accepted.emit()


func _process(delta: float) -> void:
	if _resend_left > 0.0:
		var before: int = ceili(_resend_left)
		_resend_left = maxf(0.0, _resend_left - delta)
		if ceili(_resend_left) != before:
			_refresh_buttons()
	_fit_keyboard()


## Ekran klavyesi pencerenin altını örtmesin: klavye yüksekliği (piksel) tuval birimine çevrilip alt pay yapılır.
func _fit_keyboard() -> void:
	var height: int = 0
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var window_height: float = maxf(1.0, float(DisplayServer.window_get_size().y))
		height = roundi(DisplayServer.virtual_keyboard_get_height() * get_viewport_rect().size.y / window_height)
	if height != _keyboard:
		_keyboard = height
		_margin.add_theme_constant_override(&"margin_bottom", height)
