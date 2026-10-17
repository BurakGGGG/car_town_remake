class_name LoginGate
extends Control
## İLK AÇILIŞ GİRİŞ EKRANI: yükleme çubuğu dolunca (LoadingScreen) çubuğun ve ipucunun yerine hesap
## seçenekleri gelir — FACEBOOK · GOOGLE · E-POSTA · misafir (örnek: eksik_dosyalar/login_ornek.png).
## Arka plan yükleme ekranının görselidir; oyun (Main) altta yüklenmiş durur, LoadingScreen kökte
## kaldıkça ders / gazete / kasa hatırlatması / bildirim izni beklemededir (hepsi ona bakar).
##
## YALNIZCA BİR KEZ: seçim yapılınca (misafir ya da Google girişi) CloudSaveManager login_prompt_seen
## yazar; sonraki açılışlar doğrudan oyuna gider. Seçim yapmadan uygulama kapatılırsa bir dahaki açılışta
## yine gelir. PC'de (Firebase eklentisi yok) gösterilmez; ekran taraması için CT_LOGIN_GATE=1 zorlar.
##
## GOOGLE / FACEBOOK: CloudSaveManager.sign_in / sign_in_facebook. Ekran sonucu bekler, eşitleme durulunca kapanır: bulut kaydı
## yüklenirse sahne yenilenir (yeni CloudSaveManager yeniden eşitler, ekran onu da bekler), KAYIT SEÇ
## gerekirse HUD'un PLAYER ekranı kendiliğinden açılır ve ekran çekilir. Vazgeçilir / hata olursa düğmeler
## geri gelir, hata metni düğmelerin üstünde görünür. E-posta öteki yolla kayıtlıysa CloudSaveManager öteki yolun
## seçicisini açar ve iki yolu aynı hesapta birleştirir; ekran bunu da aynı bekleyişle karşılar.
## E-POSTA şimdilik yalnızca düğme (bağlantı sonraki adım): "Çok yakında" der.

## Ekran işini bitirdi (seçim yapıldı): LoadingScreen söner, oyun başlar.
signal finished

const FORCE_ENV: String = "CT_LOGIN_GATE"
const FACEBOOK_LOGO: Texture2D = preload("res://ui/icons/facebook_f.svg")
const GOOGLE_LOGO: Texture2D = preload("res://ui/icons/google_g.svg")
const MAIL_LOGO: Texture2D = preload("res://ui/icons/mail.svg")
const GUEST_LOGO: Texture2D = preload("res://ui/icons/guest.svg")
## Marka renkleri (Facebook mavisi #1877F2; Google düğmesi beyaz zemin + koyu yazı, marka kuralı).
const FACEBOOK_BLUE: Color = Color("1877F2")
const GOOGLE_WHITE: Color = Color("FFFFFF")
const MAIL_ORANGE: Color = Color("F28B1E")
const GUEST_SLATE: Color = Color("4D5566")
const GOOGLE_INK: Color = Color("1F2A44")
const LIGHT_INK: Color = Color("FFFFFF")
## 853 birimlik en dar tuvalde (16:9 telefon) dört düğme + aralar 782 birim.
const WIDE_SIZE: Vector2 = Vector2(226.0, 58.0)
const GUEST_SIZE: Vector2 = Vector2(74.0, 58.0)
const BOTTOM_MARGIN: int = 30
## Düğmeler sırayla belirir (sn).
const APPEAR_DELAY: float = 0.25
const APPEAR_STAGGER: float = 0.06
## Giriş sonrası eşitleme bu kadar kare durgun kalınca ekran kapanır (sahne yenilenirse sayaç baştan).
const SETTLE_FRAMES: int = 8
const BUSY_STATES: Array[CloudSaveManager.State] = [
	CloudSaveManager.State.SIGNING_IN, CloudSaveManager.State.SYNCING, CloudSaveManager.State.DELETING,
]

var _status: Label
var _buttons: Array[LoginOptionButton] = []
var _signing_in: bool = false
var _sign_in_cloud_id: int = 0      # girişin başladığı CloudSaveManager (sahne yenilenince değişir)
var _cloud_id: int = 0
var _settled: int = 0
var _notice_text: String = ""
var _done: bool = false


## Açılışta ekran gösterilmeli mi (Android, misafir, daha önce seçim yapılmamış).
static func wanted(tree: SceneTree) -> bool:
	if OS.get_environment(FORCE_ENV) == "1":
		return true
	var cloud: CloudSaveManager = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
	return cloud != null and cloud.should_prompt_login()


func _ready() -> void:
	name = "LoginGate"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	_appear()


func _build() -> void:
	var bottom: MarginContainer = MarginContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	for side: String in ["left", "right"]:
		bottom.add_theme_constant_override("margin_" + side, 16)
	bottom.add_theme_constant_override(&"margin_bottom", BOTTOM_MARGIN)
	add_child(bottom)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 10)
	bottom.add_child(column)

	_status = Label.new()
	_status.name = "Status"
	_status.theme_type_variation = &"HudOutlinedLarge"
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override(&"font_size", 17)
	_status.add_theme_constant_override(&"outline_size", 6)
	_status.visible = false
	column.add_child(_status)

	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Options"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	column.add_child(row)
	_add(row, &"FacebookButton", LoginOptionButton.new(FACEBOOK_BLUE, LIGHT_INK, FACEBOOK_LOGO,
		Loc.t("FACEBOOK İLE DEVAM ET")), WIDE_SIZE, _on_sign_in.bind(CloudSaveManager.PROVIDER_FACEBOOK))
	_add(row, &"GoogleButton", LoginOptionButton.new(GOOGLE_WHITE, GOOGLE_INK, GOOGLE_LOGO,
		Loc.t("GOOGLE İLE DEVAM ET")), WIDE_SIZE, _on_sign_in.bind(CloudSaveManager.PROVIDER_GOOGLE))
	_add(row, &"EmailButton", LoginOptionButton.new(MAIL_ORANGE, LIGHT_INK, MAIL_LOGO,
		Loc.t("E-POSTA İLE DEVAM ET")), WIDE_SIZE, _on_coming_soon)
	_add(row, &"GuestButton", LoginOptionButton.new(GUEST_SLATE, LIGHT_INK, GUEST_LOGO,
		Loc.t("MİSAFİR"), true), GUEST_SIZE, _on_guest)


func _add(row: HBoxContainer, node_name: StringName, button: LoginOptionButton, min_size: Vector2,
		on_pressed: Callable) -> void:
	button.name = node_name
	button.custom_minimum_size = min_size
	button.pressed.connect(on_pressed)
	row.add_child(button)
	_buttons.append(button)


## Düğmeler sırayla, hafif yaylanarak belirir (çubuk sönerken).
func _appear() -> void:
	for button: LoginOptionButton in _buttons:
		button.modulate.a = 0.0
		button.disabled = true
	await get_tree().process_frame   # boyutlar (pivot) kurulsun
	for i: int in _buttons.size():
		var button: LoginOptionButton = _buttons[i]
		button.scale = Vector2.ONE * 0.8
		var tween: Tween = create_tween().set_parallel()
		var delay: float = APPEAR_DELAY + i * APPEAR_STAGGER
		tween.tween_property(button, "modulate:a", 1.0, 0.2).set_delay(delay)
		tween.tween_property(button, "scale", Vector2.ONE, 0.32).set_delay(delay) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.chain().tween_callback(func() -> void: button.disabled = _signing_in)


# --- Düğmeler ---------------------------------------------------------------------------

func _on_sign_in(provider: String) -> void:
	var cloud: CloudSaveManager = _cloud()
	if cloud == null:
		_show_status(Loc.t("Facebook girişi yapılamadı") if provider == CloudSaveManager.PROVIDER_FACEBOOK
			else Loc.t("Google girişi yapılamadı"))
		return
	if not cloud.notice.is_connected(_on_notice):
		cloud.notice.connect(_on_notice)
	_notice_text = ""
	_sign_in_cloud_id = cloud.get_instance_id()
	_cloud_id = _sign_in_cloud_id
	_settled = 0
	_set_busy(true)
	# PC'de hemen "yalnızca Android" uyarısı verir, _process düğmeleri geri getirir
	if provider == CloudSaveManager.PROVIDER_FACEBOOK:
		cloud.sign_in_facebook()
	else:
		cloud.sign_in()


func _on_guest() -> void:
	var cloud: CloudSaveManager = _cloud()
	if cloud:
		cloud.mark_login_prompt_seen()
	_finish()


## E-POSTA: bağlantısı sonraki adım.
func _on_coming_soon() -> void:
	_show_status(Loc.t("Çok yakında!"))


## Giriş sürerken de gösterilir (ör. "bu e-posta Google hesabınla kayıtlı, Google ile doğrula"); giriş
## olmazsa düğmeler bu metinle geri gelir (_process).
func _on_notice(text: String) -> void:
	_notice_text = text
	_show_status(text)


# --- Giriş sonucu ---------------------------------------------------------------------------

func _process(_delta: float) -> void:
	if not _signing_in or _done:
		return
	var cloud: CloudSaveManager = _cloud()
	if cloud == null:
		_settled = 0   # sahne yenileniyor
		return
	if cloud.get_instance_id() != _cloud_id:
		_cloud_id = cloud.get_instance_id()   # bulut kaydı yüklendi, dünya yeniden kuruldu
		_settled = 0
	var state: CloudSaveManager.State = cloud.get_state()
	if _cloud_id == _sign_in_cloud_id and not cloud.is_authenticated() and state not in BUSY_STATES:
		# Vazgeçildi ya da giriş olmadı: seçim ekranına dönülür
		_set_busy(false)
		_show_status(_notice_text)
		return
	if state in BUSY_STATES:
		_settled = 0
		return
	_settled += 1
	if _settled >= SETTLE_FRAMES:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	for button: LoginOptionButton in _buttons:
		button.disabled = true
	finished.emit()


# --- Yardımcılar -----------------------------------------------------------------------------

func _cloud() -> CloudSaveManager:
	var cloud: CloudSaveManager = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	return cloud if cloud != null and not cloud.is_queued_for_deletion() else null


func _set_busy(busy: bool) -> void:
	_signing_in = busy
	for button: LoginOptionButton in _buttons:
		button.disabled = busy
		button.modulate.a = 0.55 if busy else 1.0
	_show_status(Loc.t("Bağlanıyor…") if busy else "")


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = not text.is_empty()
