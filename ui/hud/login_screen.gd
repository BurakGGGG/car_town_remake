class_name LoginScreen
extends Control
## PLAYER tabelası: Google / Facebook / e-posta koduyla giriş, profil / çıkış ve kayıt seçimi (bu cihaz ↔ bulut).
## Ekran TAMAMEN KODLA kurulur (.tscn yok); HUD onu ShowroomScreen gibi temalı Root'un altına ekler.
## Mantık burada değil: her şey CloudSaveManager'dadır ("cloud_save" grubu); bu ekran yalnızca
## durumunu gösterir ve butonları ona iletir. CloudSaveManager yoksa (PC / node eklenmemiş) misafir
## metni gösterilir.
##
## Oyuncuyu engellemez: açılışta AÇILMAZ — ilk açılıştaki giriş seçimi yükleme ekranındadır (LoginGate).
## O ekran hiç gösterilmediyse oyuncu biraz ilerleyince (ilk ders bitince) HUD bunu bir kez açar
## (Hud._tick_login_prompt → show_prompt); MİSAFİR OLARAK DEVAM ET / KAPAT ile oyun sürer.
## Misafir ilerlemesi giriş yapılan hesaba taşınır: hesabın bulut kaydı yoksa bu cihazın oyunu
## buluta yazılır; varsa KAYIT SEÇ ile oyuncu hangisinin kalacağını seçer. Kayıt seçimi (CONFLICT) çıkınca kendiliğinden
## açılır; SONRA KARAR VER ile kapatılabilir, seçim yapılana kadar buluta yazılmaz.
## Hesapla girişte bulut kaydı yüklenip dünya yenilenince bu pano AÇILMAZ, oyun doğrudan başlar ("Hesabın yüklendi."
## kısa bildirim); çıkış / hesap silme sonucu ise burada söylenir.
##
## HESABIMI SİL iki adımlıdır: ilk basış yalnızca neyin silineceğini anlatan onay görünümünü açar,
## silme EVET, KALICI OLARAK SİL ile başlar (hesap kendi yoluyla — Google / Facebook — yeniden seçtirilir; bu cihazda
## e-posta koduyla girildiyse E-POSTA penceresi açılır, kod hesabın e-postasına gider).
##
## E-POSTA İLE GİRİŞ: EmailCodePanel bu ekranın üstünde açılır (kod adımı, klavye payı orada).
## FACEBOOK: Meta onayına kadar (CloudSaveManager.FACEBOOK_READY) Facebook düğmeleri "üzerinde çalışıyoruz" der.

signal opened
signal closed
## Dünya yenilendikten sonraki mesaj (hesap yüklendi / kayıt geri yüklendi) pano açılmadan söylensin: HUD kısa bildirim
## olarak gösterir.
signal toast_requested(text: String)

const PANEL_WIDTH: float = 380.0
const CHOICE_WIDTH: float = 200.0
## Google ile giriş düğmesinde resmi "G" logosu (Google marka kuralı: dört renkli, değiştirilmeden).
const GOOGLE_MARK: Texture2D = preload("res://ui/icons/google_g.svg")
## Facebook ile giriş düğmesinde mavi yuvarlak "f" logosu.
const FACEBOOK_MARK: Texture2D = preload("res://ui/icons/facebook_logo.svg")
## E-posta ile giriş düğmesinde turuncu zarf.
const MAIL_MARK: Texture2D = preload("res://ui/icons/mail_plate.svg")

var _cloud: CloudSaveManager
var _title: Label
var _body: Label
var _notice: Label
var _account_box: VBoxContainer
var _account_caption: Label
var _name_label: Label
var _email_label: Label
var _choice_row: HBoxContainer
var _local_info: Label
var _cloud_info: Label
var _primary: PlateButton
var _facebook: PlateButton
var _email: PlateButton
var _email_panel: EmailCodePanel
var _link: PlateButton
var _secondary: PlateButton
var _delete: PlateButton
var _notice_text: String = ""
var _confirm_delete: bool = false


func _ready() -> void:
	name = "LoginScreen"
	add_to_group("login_screen")
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP   # açıkken dünyaya tıklama gitmez
	_build()
	_connect_cloud.call_deferred()


# --- Aç / kapa ---------------------------------------------------------------

func open() -> void:
	_notice_text = ""
	_confirm_delete = false
	_refresh()
	if visible:
		return
	show()
	opened.emit()


func close() -> void:
	if not visible:
		return
	_close_email_panel(true)
	hide()
	closed.emit()


# --- Kurulum -----------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)
	center.name = "Center"

	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)

	# Tabela
	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_title = _label(&"HudSignTitle", Loc.t("PLAYER"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	column.add_child(sign)

	# Bilgi plakası
	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_theme_constant_override(&"separation", 6)
	info.add_child(info_box)
	column.add_child(info)

	_account_box = VBoxContainer.new()
	_account_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_account_box.add_theme_constant_override(&"separation", 0)
	_account_caption = _label(&"HudInkCaption", "")
	_account_box.add_child(_account_caption)
	_name_label = _label(&"HudPlateTitle", "")
	_email_label = _label(&"HudInkCaption", "")
	_account_box.add_child(_name_label)
	_account_box.add_child(_email_label)
	info_box.add_child(_account_box)

	_body = _wrapped(&"HudInkCaption")
	info_box.add_child(_body)

	# Kayıt seçimi: iki plaka yan yana, her birinin altında kendi butonu
	_choice_row = HBoxContainer.new()
	_choice_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_choice_row.add_theme_constant_override(&"separation", 8)
	_local_info = _choice(_choice_row, Loc.t("BU CİHAZDAKİ KAYIT"), false)
	_cloud_info = _choice(_choice_row, Loc.t("BULUT KAYDI"), true)
	info_box.add_child(_choice_row)

	_notice = _wrapped(&"HudInkCaption")
	_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	info_box.add_child(_notice)

	# Butonlar
	_primary = PlateButton.new()
	_primary.name = "PrimaryButton"
	_primary.theme_type_variation = &"HudPlate"
	_primary.kind = HudIcon.Kind.HELMET
	_primary.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(_on_primary_pressed)
	column.add_child(_primary)

	# Oturum açıkken ikinci giriş yolunu bağlar (FACEBOOK'U BAĞLA / GOOGLE'I BAĞLA)
	_link = PlateButton.new()
	_link.name = "LinkButton"
	_link.theme_type_variation = &"HudPlate"
	_link.kind = HudIcon.Kind.NONE
	_link.avatar_frame = false
	_link.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_link.focus_mode = Control.FOCUS_NONE
	_link.pressed.connect(_on_link_pressed)
	column.add_child(_link)

	# Misafirken ikinci giriş yolu (Google düğmesinin altında, aynı boyda)
	_facebook = PlateButton.new()
	_facebook.name = "FacebookButton"
	_facebook.theme_type_variation = &"HudPlate"
	_facebook.text = Loc.t("FACEBOOK İLE GİRİŞ")
	_facebook.kind = HudIcon.Kind.NONE
	_facebook.avatar = FACEBOOK_MARK
	_facebook.avatar_frame = false
	_facebook.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_facebook.focus_mode = Control.FOCUS_NONE
	_facebook.pressed.connect(_on_facebook_pressed)
	column.add_child(_facebook)

	# Misafirken üçüncü yol: e-postaya gelen kodla (şifresiz)
	_email = PlateButton.new()
	_email.name = "EmailButton"
	_email.theme_type_variation = &"HudPlate"
	_email.text = Loc.t("E-POSTA İLE GİRİŞ")
	_email.kind = HudIcon.Kind.NONE
	_email.avatar = MAIL_MARK
	_email.avatar_frame = false
	_email.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_email.focus_mode = Control.FOCUS_NONE
	_email.pressed.connect(_open_email_panel.bind(""))
	column.add_child(_email)

	_secondary = PlateButton.new()
	_secondary.name = "SecondaryButton"
	_secondary.theme_type_variation = &"HudPlateSmall"
	_secondary.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_secondary.focus_mode = Control.FOCUS_NONE
	_secondary.pressed.connect(_on_secondary_pressed)
	column.add_child(_secondary)

	_delete = PlateButton.new()
	_delete.name = "DeleteAccountButton"
	_delete.theme_type_variation = &"HudPlateSmall"
	_delete.text = Loc.t("HESABIMI SİL")
	_delete.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	_delete.focus_mode = Control.FOCUS_NONE
	for color_name: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		_delete.add_theme_color_override(color_name, HudPalette.DANGER)
	_delete.pressed.connect(_on_delete_pressed)
	column.add_child(_delete)


## Seçim sütunu: özet plakası + seçme butonu. Özet etiketini döndürür.
func _choice(parent: HBoxContainer, caption: String, use_cloud: bool) -> Label:
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(CHOICE_WIDTH, 0.0)
	var summary: Label = _wrapped(&"HudInkValue")
	summary.custom_minimum_size = Vector2(CHOICE_WIDTH - 24.0, 0.0)
	plate.add_child(summary)
	box.add_child(plate)
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = caption
	button.custom_minimum_size = Vector2(CHOICE_WIDTH, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(_on_choice_pressed.bind(use_cloud))
	box.add_child(button)
	parent.add_child(box)
	return summary


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _wrapped(variation: StringName) -> Label:
	var label: Label = _label(variation, "")
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	return label


# --- CloudSaveManager -----------------------------------------------------------

func _connect_cloud() -> void:
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	if _cloud == null:
		_refresh()
		return
	_cloud.state_changed.connect(func(_s: CloudSaveManager.State) -> void: _refresh())
	_cloud.user_changed.connect(func(_p: Dictionary) -> void: _refresh())
	_cloud.conflict_found.connect(_on_conflict_found)
	_cloud.notice.connect(_on_notice)
	_cloud.account_deleted.connect(_on_account_deleted)
	_cloud.links_changed.connect(_refresh)
	_cloud.email_reauth_needed.connect(_open_email_panel)
	_refresh()
	await get_tree().process_frame
	# Dünya yenilendiyse sonucu bir kez söyle. Çıkış / hesap silme bu panoda söylenir; hesapla giriş (bulut kaydı
	# yüklendi) panoyu AÇMAZ, oyun doğrudan açılır ve mesaj kısa bildirimdir (2026-10-26, kullanıcı isteği).
	var opens: bool = _cloud.pending_notice_opens_account()
	var pending: String = _cloud.take_pending_notice()
	if pending.is_empty():
		return
	if opens:
		open()
		_on_notice(pending)
	else:
		toast_requested.emit(pending)


## Oyuncu biraz ilerledi: giriş BİR KEZ, nedeniyle birlikte önerilir (HUD açar, router üstünden).
func show_prompt() -> void:
	if _cloud:
		_cloud.mark_login_prompt_seen()
	_on_notice(Loc.t("Garajın büyümeye başladı! Giriş yap, ilerlemen hesabına kaydedilsin. Telefon değişse de kaybolmaz."))


func _on_conflict_found(local_summary: Dictionary, cloud_summary: Dictionary) -> void:
	_local_info.text = _summary_text(local_summary)
	_cloud_info.text = _summary_text(cloud_summary)
	open()


func _on_notice(text: String) -> void:
	_notice_text = text
	_refresh()


func _on_account_deleted(success: bool) -> void:
	_confirm_delete = false
	if success:
		_notice_text = Loc.t("Hesabın ve tüm verilerin silindi. Yeni bir oyunla misafir olarak devam ediyorsun.")
	_refresh()


func _summary_text(summary: Dictionary) -> String:
	var vehicles: PackedStringArray = summary.get("vehicles", PackedStringArray())
	return Loc.t("%s ₺\nSEVİYE %d\n%d ARAÇ\n%s") % [
		Hud.format_thousands(int(summary.get("money", 0))),
		int(summary.get("level", 1)),
		vehicles.size(),
		", ".join(vehicles),
	]


# --- Görünüm ---------------------------------------------------------------------

## Giriş düğmesi: kask yerine logo, öteki plaka düğmelerindeki ikon gibi yazının üstünde ortada.
func _google_mark(on: bool) -> void:
	_primary.kind = HudIcon.Kind.NONE if on else HudIcon.Kind.HELMET
	_primary.avatar = GOOGLE_MARK if on else null
	_primary.avatar_frame = not on   # logo çerçevesiz, olduğu gibi


func _refresh() -> void:
	var state: CloudSaveManager.State = _cloud.get_state() if _cloud else CloudSaveManager.State.UNAVAILABLE
	var profile: Dictionary = _cloud.get_profile() if _cloud else {}
	var signed_in: bool = not profile.is_empty()
	var provider: String = CloudSaveManager.provider_name(String(profile.get("provider", "")))
	var linked: PackedStringArray = _cloud.get_providers() if _cloud else PackedStringArray()
	var linked_names: PackedStringArray = PackedStringArray()
	for id: String in linked:
		linked_names.append(CloudSaveManager.provider_name(id).to_upper())

	_title.text = Loc.t("KAYIT SEÇ") if state == CloudSaveManager.State.CONFLICT else Loc.t("PLAYER")
	_account_box.visible = signed_in and state != CloudSaveManager.State.CONFLICT
	_choice_row.visible = state == CloudSaveManager.State.CONFLICT
	_account_caption.text = Loc.t("%s HESABI") % (" + ".join(linked_names) if not linked_names.is_empty() else provider.to_upper())
	_name_label.text = String(profile.get("display_name", "")).to_upper()
	_email_label.text = String(profile.get("email", ""))
	_notice.text = _notice_text
	_notice.visible = not _notice_text.is_empty()
	_primary.visible = true
	_primary.disabled = false
	_primary.remove_theme_color_override(&"font_color")
	_google_mark(false)
	_facebook.visible = false
	_facebook.disabled = false
	_email.visible = false
	_email.disabled = false
	_link.visible = false
	_delete.visible = false
	if _confirm_delete and not (_cloud and _cloud.can_delete_account()):
		_confirm_delete = false   # bu arada oturum / durum değişti

	if _confirm_delete:
		_title.text = Loc.t("HESABI SİL")
		_account_box.visible = true
		if String(profile.get("provider", "")) == CloudSaveManager.PROVIDER_EMAIL:
			_body.text = Loc.t("Hesabın oyundan silinir. Bulut kaydın ve bu cihazdaki tüm ilerlemen (para, elmas, araçlar, garaj, görevler) kalıcı olarak silinir ve oyun baştan başlar.\n\nBu işlem GERİ ALINAMAZ. Devam edersen e-postana gelecek kodu girmen istenecek.")
		else:
			_body.text = Loc.t("%s hesabın oyundan silinir. Bulut kaydın ve bu cihazdaki tüm ilerlemen (para, elmas, araçlar, garaj, görevler) kalıcı olarak silinir ve oyun baştan başlar.\n\nBu işlem GERİ ALINAMAZ. Devam edersen %s hesabını bir kez daha seçmen istenecek.") % [provider, provider]
		_primary.text = Loc.t("EVET, KALICI OLARAK SİL")
		_primary.add_theme_color_override(&"font_color", HudPalette.DANGER_DARK)
		_secondary.text = Loc.t("VAZGEÇ")
		return

	match state:
		CloudSaveManager.State.UNAVAILABLE:
			_body.text = Loc.t("Misafir olarak oynuyorsun. İlerlemen bu cihazda kayıtlı.\nHesapla giriş yalnızca Android sürümünde.")
			_primary.visible = false
			_secondary.text = Loc.t("DEVAM ET")
		CloudSaveManager.State.SIGNED_OUT:
			_body.text = Loc.t("Misafir olarak oynuyorsun. İlerlemen bu cihazda kayıtlı.\nGiriş yaparsan ilerlemen buluta yedeklenir, telefon değişse de kaybolmaz.")
			_primary.text = Loc.t("GOOGLE İLE GİRİŞ")
			_google_mark(true)
			_facebook.visible = true
			_email.visible = true
			_secondary.text = Loc.t("MİSAFİR OLARAK DEVAM ET")
		CloudSaveManager.State.SIGNING_IN, CloudSaveManager.State.SYNCING:
			_body.text = Loc.t("Bağlanıyor…")
			_primary.text = Loc.t("GOOGLE İLE GİRİŞ") if not signed_in else Loc.t("ÇIKIŞ YAP")
			_google_mark(not signed_in)
			_primary.disabled = true
			_facebook.visible = not signed_in
			_facebook.disabled = true
			_email.visible = not signed_in
			_email.disabled = true
			_secondary.text = Loc.t("KAPAT")
		CloudSaveManager.State.CONFLICT:
			_body.text = Loc.t("Bu cihazda kayıt bulundu.\nBulut kaydı bulundu.\nHangisini kullanmak istiyorsun?")
			_primary.visible = false
			_secondary.text = Loc.t("SONRA KARAR VER")
		CloudSaveManager.State.SYNCED:
			_body.text = Loc.t("Bulut kaydı güncel.\nÇıkış yaparsan bu cihazda yeni bir misafir oyunu başlar; ilerlemen hesabında güvende kalır, tekrar girince geri gelir.")
			_primary.text = Loc.t("ÇIKIŞ YAP")
			_secondary.text = Loc.t("KAPAT")
		CloudSaveManager.State.OFFLINE:
			_body.text = Loc.t("Buluta ulaşılamıyor. Bu cihazdaki kayıt kullanılıyor; bağlantı gelince eşitlenecek.\nEşitlenmemiş değişiklik varken çıkış yapılamaz.")
			_primary.text = Loc.t("ÇIKIŞ YAP")
			_secondary.text = Loc.t("KAPAT")
		CloudSaveManager.State.ERROR:
			_body.text = Loc.t("Bulut kaydı bu sürümle açılamıyor. Bulut kaydına dokunulmadı; bu cihazdaki kayıt kullanılıyor.")
			_primary.text = Loc.t("ÇIKIŞ YAP")
			_secondary.text = Loc.t("KAPAT")
		CloudSaveManager.State.DELETING:
			_body.text = Loc.t("Hesap siliniyor… E-postana gelen kodu girince bu birkaç saniye sürer.") \
				if String(profile.get("provider", "")) == CloudSaveManager.PROVIDER_EMAIL \
				else Loc.t("Hesap siliniyor… %s hesabını seçtiysen bu birkaç saniye sürer.") % provider
			_primary.text = Loc.t("SİLİNİYOR")
			_primary.disabled = true
			_secondary.text = Loc.t("KAPAT")
	if _cloud != null and _cloud.is_linking():
		_primary.disabled = true   # bağlama bitmeden çıkış yapılmaz
	_delete.visible = _cloud != null and _cloud.can_delete_account()
	_refresh_link(linked)


## İkinci giriş yolu: bağlı olmayan yol düğmede (logosuyla; önce Google — e-postayla açılmış hesapta ikisi de yok);
## bağlanırken soluk, ikisi de bağlıysa gizli.
func _refresh_link(linked: PackedStringArray) -> void:
	if _cloud == null or not _cloud.is_authenticated() or linked.size() >= 2:
		return
	var missing: String = CloudSaveManager.PROVIDER_FACEBOOK if linked.has(CloudSaveManager.PROVIDER_GOOGLE) \
		else CloudSaveManager.PROVIDER_GOOGLE
	var linking: bool = _cloud.is_linking()
	if not linking and not _cloud.can_link(missing):
		return
	_link.visible = true
	_link.disabled = linking
	_link.set_meta(&"provider", missing)
	_link.text = Loc.t("Bağlanıyor…") if linking else (Loc.t("FACEBOOK'U BAĞLA")
		if missing == CloudSaveManager.PROVIDER_FACEBOOK else Loc.t("GOOGLE'I BAĞLA"))
	_link.avatar = FACEBOOK_MARK if missing == CloudSaveManager.PROVIDER_FACEBOOK else GOOGLE_MARK


# --- Butonlar ----------------------------------------------------------------------

func _on_primary_pressed() -> void:
	if _cloud == null:
		return
	_notice_text = ""
	if _confirm_delete:
		_confirm_delete = false
		_cloud.delete_account()
	elif _cloud.is_authenticated():
		_cloud.sign_out()   # local kayıt silinmez
	else:
		_cloud.sign_in()
	_refresh()


func _on_link_pressed() -> void:
	if _cloud == null:
		return
	var provider: String = String(_link.get_meta(&"provider", ""))
	if provider == CloudSaveManager.PROVIDER_FACEBOOK and not CloudSaveManager.FACEBOOK_READY:
		_on_notice(Loc.t("Facebook girişi üzerinde çalışıyoruz, çok yakında!"))
		return
	_notice_text = ""
	_cloud.link_provider(provider)
	_refresh()


func _on_facebook_pressed() -> void:
	if _cloud == null:
		return
	if not CloudSaveManager.FACEBOOK_READY:
		_on_notice(Loc.t("Facebook girişi üzerinde çalışıyoruz, çok yakında!"))
		return
	_notice_text = ""
	_cloud.sign_in_facebook()
	_refresh()


## E-POSTA penceresi: reauth_email boş → misafir girişi; dolu → hesap silmede kodla yeniden doğrulama.
func _open_email_panel(reauth_email: String) -> void:
	if _cloud == null:
		return
	_close_email_panel(false)
	_notice_text = ""
	if not visible:
		open()
	_email_panel = EmailCodePanel.new()
	_email_panel.setup(_cloud, reauth_email)
	_email_panel.accepted.connect(_close_email_panel.bind(false))
	_email_panel.cancelled.connect(_close_email_panel.bind(true))
	add_child(_email_panel)
	_refresh()


## HESABA KAYDET kartından (SaveReminderCard): pano açıktır, misafirse seçilen yolla giriş hemen başlar (Google seçicisi /
## E-POSTA penceresi); bekleme, hata ve KAYIT SEÇ her zamanki gibi bu panoda.
func start_sign_in(provider: String) -> void:
	if _cloud == null or _cloud.is_authenticated() or _cloud.is_busy():
		return
	if provider == CloudSaveManager.PROVIDER_EMAIL:
		_open_email_panel("")
		return
	_notice_text = ""
	_cloud.sign_in()
	_refresh()


## cancel: vazgeçildi (silme doğrulamasıysa silme iptal); değilse kod kabul edildi, giriş / silme sürer.
func _close_email_panel(cancel: bool) -> void:
	if _email_panel == null:
		return
	_email_panel.queue_free()
	_email_panel = null
	if cancel and _cloud:
		_cloud.cancel_email_reauth()
	_refresh()


func _on_secondary_pressed() -> void:
	if _confirm_delete:
		_confirm_delete = false   # VAZGEÇ: hesap görünümüne dön
		_refresh()
		return
	close()


func _on_delete_pressed() -> void:
	_notice_text = ""
	_confirm_delete = true
	_refresh()


func _on_choice_pressed(use_cloud: bool) -> void:
	if _cloud:
		_cloud.resolve_conflict(use_cloud)
