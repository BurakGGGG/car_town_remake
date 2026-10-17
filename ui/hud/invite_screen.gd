class_name InviteScreen
extends Control
## ARKADAŞ DAVETİ (2026-10-17): arkadaşın gönderdiği link açılınca (InviteLinks) davet edenin profil kartı + ARKADAŞ EKLE.
## Davet eden ONAYLAMAZ (linki kendisi gönderdi): SocialManager.accept_invite iki arkadaşlık belgesini de yazar.
## Durumlar (SocialManager.read_invite + oturum):
##   ok       → ARKADAŞ EKLE / VAZGEÇ            done     → GARAJINA GİT / TAMAM (eklendi)
##   friend   → GARAJINA GİT / TAMAM            self     → kendi linkin (TAMAM)
##   expired  → 1 saat doldu, yeni link iste     missing  → davet yok / hesap silinmiş
##   error    → TEKRAR DENE / KAPAT              loading  → okunuyor (oturum açılıyorsa da bekler)
##   signin   → Google girişi gerekir → GİRİŞ YAP (giriş sahneyi yeniler; davet InviteLinks.pending ile geri gelir)
##   profile  → takma ad seçilmemiş → ARKADAŞLAR   unavailable → bu sürümde arkadaşlık yok (PC)
## HUD açar (UiRouter MODAL &"invite"). Ekran tamamen kodla kurulur.

signal opened
signal closed
## Başka bir ekran istendi (&"account" giriş, &"friends" takma ad).
signal screen_requested(id: StringName)

var _social: SocialManager
var _column: VBoxContainer
var _card: ProfileCard
var _title: Label
var _body: Label
var _primary: PlateButton
var _secondary: PlateButton
var _token: String = ""
var _invite: Dictionary = {}
var _state: String = ""
var _keep_pending: bool = false   # giriş / takma ad için kapandı: davet beklemede kalsın
var _closing: bool = false
var _gen: int = 0


func _ready() -> void:
	name = "InviteScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect_social.call_deferred()


## Gösterilecek davet (router.open'dan önce ya da sonra). Okuma hemen başlar.
func show_token(token: String) -> void:
	_token = token
	_invite = {}
	_keep_pending = false
	_load()


func token() -> String:
	return _token


func state() -> String:
	return _state


func open() -> void:
	_gen += 1
	_closing = false
	PlateAnim.pop_in(self, _column)
	opened.emit()


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_gen += 1
	var gen: int = _gen
	if not _keep_pending:
		InviteLinks.clear_pending(_token)
	PlateAnim.pop_out(self, _column, func() -> void:
		if gen != _gen:
			return
		hide()
		_closing = false
		closed.emit())


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.5)
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
	_title = _label(&"HudSignTitle", Loc.t("ARKADAŞ DAVETİ"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(_title)
	_column.add_child(sign)

	_card = ProfileCard.new()
	_card.name = "Card"
	_column.add_child(_card)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(ProfileCard.CARD_WIDTH, 0.0)
	_body = _label(&"HudInkCaption", "")
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_body)
	_column.add_child(info)

	_primary = PlateButton.new()
	_primary.name = "PrimaryButton"
	_primary.theme_type_variation = &"HudPlate"
	_primary.custom_minimum_size = Vector2(ProfileCard.CARD_WIDTH, 54.0)
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(_on_primary)
	_column.add_child(_primary)
	_secondary = PlateButton.new()
	_secondary.name = "SecondaryButton"
	_secondary.theme_type_variation = &"HudPlateSmall"
	_secondary.custom_minimum_size = Vector2(ProfileCard.CARD_WIDTH, 0.0)
	_secondary.focus_mode = Control.FOCUS_NONE
	_secondary.pressed.connect(_on_secondary)
	_column.add_child(_secondary)


func _connect_social() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		# Oturum bekleniyorsa (açılış / giriş sonrası) hazır olunca davet kendiliğinden okunur
		_social.changed.connect(func() -> void:
			if visible and _state in ["loading", "signin", "profile"] and not _social.is_busy() and not _token.is_empty():
				_load())
		_social.avatar_ready.connect(func(uid: String) -> void:
			if visible and uid == SaveSafe.s(_invite.get("uid", "")):
				_card.show_person(_invite.get("person", {})))


# --- Durum -------------------------------------------------------------------------

func _load() -> void:
	if _social == null:
		_social = get_tree().get_first_node_in_group("social") as SocialManager
	var session: SocialManager.State = _social.get_state() if _social else SocialManager.State.UNAVAILABLE
	match session:
		SocialManager.State.UNAVAILABLE:
			_show("unavailable")
			return
		SocialManager.State.SIGNED_OUT:
			_show("signin")
			return
		SocialManager.State.NO_PROFILE:
			_show("profile")
			return
		SocialManager.State.LOADING:
			_show("loading")
			return
		SocialManager.State.OFFLINE:
			_show("error")
			return
	if _social.is_busy():
		_show("loading")
		return
	_show("loading")
	var token: String = _token
	var info: Dictionary = await _social.read_invite(token)
	if token != _token:
		return   # bu arada başka bir link açıldı
	_invite = info
	_show(SaveSafe.s(info.get("status", "error")))


func _show(state: String) -> void:
	_state = state
	var person: Dictionary = _invite.get("person", {}) if _invite.get("person") is Dictionary else {}
	var name: String = SaveSafe.s(person.get("name", _invite.get("name", "")))
	_card.visible = not person.is_empty() and state in ["ok", "done", "friend", "self", "expired"]
	if _card.visible:
		_card.show_person(person)
	_primary.disabled = false
	_secondary.visible = true
	_primary.kind = HudIcon.Kind.NONE
	match state:
		"loading":
			_body.text = Loc.t("Davet açılıyor…")
			_primary.text = Loc.t("BİR SANİYE…")
			_primary.disabled = true
			_secondary.text = Loc.t("VAZGEÇ")
		"ok":
			_body.text = Loc.t("%s seni Auto Yard'da arkadaşı olmaya çağırıyor. Ekleyince garajını gezebilir, aracına karşı yarışabilirsin.") % name
			_primary.text = Loc.t("ARKADAŞ EKLE")
			_primary.kind = HudIcon.Kind.CHECK
			_secondary.text = Loc.t("VAZGEÇ")
		"done":
			_body.text = Loc.t("%s artık arkadaşın!") % name
			_primary.text = Loc.t("GARAJINA GİT")
			_primary.kind = HudIcon.Kind.GARAGE
			_secondary.text = Loc.t("TAMAM")
		"friend":
			_body.text = Loc.t("%s zaten arkadaşın.") % name
			_primary.text = Loc.t("GARAJINA GİT")
			_primary.kind = HudIcon.Kind.GARAGE
			_secondary.text = Loc.t("TAMAM")
		"self":
			_body.text = Loc.t("Bu senin kendi davet linkin. Arkadaşına gönder, o açınca arkadaş olursunuz.")
			_primary.text = Loc.t("TAMAM")
			_secondary.visible = false
		"expired":
			_body.text = Loc.t("Bu davet linkinin süresi dolmuş (linkler 1 saat geçerli). %s oyuncusundan yeni bir link iste.") % name
			_primary.text = Loc.t("TAMAM")
			_secondary.visible = false
		"missing":
			_body.text = Loc.t("Davet bulunamadı. Link yanlış ya da artık geçerli değil.")
			_primary.text = Loc.t("TAMAM")
			_secondary.visible = false
		"signin":
			_body.text = Loc.t("Arkadaş eklemek için Google ile giriş yapmalısın. Girişten sonra davet yeniden açılır.")
			_primary.text = Loc.t("GİRİŞ YAP")
			_primary.kind = HudIcon.Kind.HELMET
			_secondary.text = Loc.t("VAZGEÇ")
		"profile":
			_body.text = Loc.t("Önce ARKADAŞLAR'dan takma adını seç; sonra davet yeniden açılır.")
			_primary.text = Loc.t("ARKADAŞLAR")
			_secondary.text = Loc.t("VAZGEÇ")
		"unavailable":
			_body.text = Loc.t("Arkadaş eklemek yalnızca Android sürümünde.")
			_primary.text = Loc.t("TAMAM")
			_secondary.visible = false
		_:   # error
			_body.text = Loc.t("Davet açılamadı. İnternet bağlantını kontrol et.")
			_primary.text = Loc.t("TEKRAR DENE")
			_secondary.text = Loc.t("KAPAT")


func _on_primary() -> void:
	match _state:
		"ok":
			_primary.disabled = true
			_primary.text = Loc.t("BİR SANİYE…")
			if await _social.accept_invite(_invite):
				_show("done")
			else:
				# Süre doldu / bağlantı: nedeni SocialManager söyledi; durum yeniden okunur
				_load()
		"done", "friend":
			var uid: String = SaveSafe.s(_invite.get("uid", ""))
			close()
			if _social and not uid.is_empty():
				_social.visit(uid)
		"signin":
			_keep_pending = true
			close()
			screen_requested.emit(&"account")
		"profile":
			_keep_pending = true
			close()
			screen_requested.emit(&"friends")
		"error":
			_load()
		_:
			close()


func _on_secondary() -> void:
	close()


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
