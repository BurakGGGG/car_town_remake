class_name FriendsScreen
extends Control
## ARKADAŞLAR tabelası: takma ad + arkadaş kodu, kodla arkadaş ekleme, gelen / giden istekler,
## arkadaş listesi ve GARAJA GİT. Ekran TAMAMEN KODLA kurulur (.tscn yok); HUD temalı Root'un altına
## ekler ve UiRouter'a MODAL olarak kaydeder. Mantık SocialManager'dadır ("social" grubu); bu ekran
## yalnızca durumunu gösterir ve butonları ona iletir.
##
## Ziyarete gidilince kendi sahne dondurulur ve bu ekran AÇIK kalır: dönünce oyuncu listeye döner.
## ÖNE ÇIKAN ARKADAŞLAR (FeaturedFriends: oyunla gelen iki garaj) listenin başında HER durumda görünür:
## misafir, çevrimdışı ve PC sürümü dahil. Çıkarılamazlar.
## PROFİL (2026-10-16): her satırda kişinin avatarı (+ bayrak); avatara / ada dokununca ARKADAŞ KARTI açılır
## (person_requested → HUD → FriendCardScreen). ÇIKAR, ŞİKAYET ET ve ENGELLE kartta; satırda GÖNDER / GARAJA GİT.

signal opened
signal closed
## Başka bir ekran istendi (giriş için &"account").
signal screen_requested(id: StringName)
## Bir kişinin kartı istendi (satırdaki avatar / ad).
signal person_requested(uid: String)
## YARIŞ HABERİ: İNTİKAM AL (gönderenin aracına karşı pist doğrudan açılır; HUD yürütür).
signal revenge_requested(uid: String)

const PANEL_WIDTH: float = 400.0
const ROW_BUTTON_WIDTH: float = 112.0
const AVATAR_SIZE: float = 46.0

var _social: SocialManager
var _body: Label
var _notice: Label
var _profile_box: VBoxContainer
var _name_label: Label
var _code_label: Label
var _name_edit: LineEdit
var _name_row: HBoxContainer
var _add_row: HBoxContainer
var _code_edit: LineEdit
var _lists: VBoxContainer
var _primary: PlateButton
var _notice_text: String = ""
var _renaming: bool = false


func _ready() -> void:
	name = "FriendsScreen"
	add_to_group("friends_screen")
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_connect_social.call_deferred()


func open() -> void:
	_notice_text = ""
	_renaming = false
	if _social:
		_social.retry()
		_social.refresh()
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

	var center: CenterContainer = FitScroll.center_in(self)
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Column"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 8)
	center.add_child(column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("ARKADAŞLAR"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	var info: PlatePanel = PlatePanel.new()
	info.theme_type_variation = &"HudCarPlate"
	info.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 8)
	info.add_child(box)
	column.add_child(info)

	# Profil: ad + kod (+ adı değiştir)
	_profile_box = VBoxContainer.new()
	_profile_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_profile_box.add_theme_constant_override(&"separation", 2)
	_profile_box.add_child(_label(&"HudInkCaption", Loc.t("TAKMA ADIN")))
	var name_line: HBoxContainer = _row()
	_name_label = _label(&"HudPlateTitle", "")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_line.add_child(_name_label)
	name_line.add_child(_small_button(Loc.t("DEĞİŞTİR"), _on_rename_pressed))
	_profile_box.add_child(name_line)
	_profile_box.add_child(_label(&"HudInkCaption", Loc.t("ARKADAŞ KODUN")))
	var code_line: HBoxContainer = _row()
	_code_label = _label(&"HudPlateTitle", "")
	_code_label.name = "MyCode"
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_line.add_child(_code_label)
	code_line.add_child(_small_button(Loc.t("KOPYALA"), _on_copy_pressed))
	_profile_box.add_child(code_line)
	box.add_child(_profile_box)

	# Takma ad girişi (profil oluşturma ve ad değiştirme)
	_name_row = _row()
	_name_edit = _line_edit(Loc.t("Takma ad"), SocialNames.NAME_MAX)
	_name_edit.name = "NameEdit"
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_primary_pressed())
	_name_row.add_child(_name_edit)
	box.add_child(_name_row)

	_body = _wrapped(&"HudInkCaption")
	box.add_child(_body)

	# Kodla arkadaş ekle
	_add_row = _row()
	_code_edit = _line_edit(Loc.t("Arkadaş kodu (AY-…)"), 9)
	_code_edit.name = "CodeEdit"
	_code_edit.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	_add_row.add_child(_code_edit)
	var add: PlateButton = _small_button(Loc.t("EKLE"), _on_add_pressed)
	add.name = "AddButton"
	_add_row.add_child(add)
	box.add_child(_add_row)

	_notice = _wrapped(&"HudInkCaption")
	_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	box.add_child(_notice)

	_lists = VBoxContainer.new()
	_lists.name = "Lists"
	_lists.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lists.add_theme_constant_override(&"separation", 6)
	box.add_child(_lists)

	_primary = PlateButton.new()
	_primary.name = "PrimaryButton"
	_primary.theme_type_variation = &"HudPlate"
	_primary.kind = HudIcon.Kind.HELMET
	_primary.custom_minimum_size = Vector2(PANEL_WIDTH, 54.0)
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.pressed.connect(_on_primary_pressed)
	column.add_child(_primary)

	var close_button: PlateButton = PlateButton.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.custom_minimum_size = Vector2(PANEL_WIDTH, 0.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)


func _connect_social() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	if _social:
		_social.changed.connect(_refresh)
		_social.notice.connect(_on_notice)
		_social.avatar_ready.connect(func(_uid: String) -> void:
			if visible:
				_refresh())
	_refresh()


func _on_notice(text: String) -> void:
	_notice_text = text
	_refresh()


# --- Görünüm -----------------------------------------------------------------

func _refresh() -> void:
	if _body == null:
		return
	var state: SocialManager.State = _social.get_state() if _social else SocialManager.State.UNAVAILABLE
	var ready: bool = state == SocialManager.State.READY
	var busy: bool = _social != null and _social.is_busy()
	_profile_box.visible = ready
	_add_row.visible = ready and not _renaming
	_lists.visible = not _renaming and state != SocialManager.State.LOADING
	_name_row.visible = state == SocialManager.State.NO_PROFILE or (ready and _renaming)
	_primary.visible = true
	_primary.disabled = busy
	_notice.text = _notice_text
	_notice.visible = not _notice_text.is_empty()
	match state:
		SocialManager.State.UNAVAILABLE:
			_body.text = Loc.t("Arkadaş eklemek yalnızca Android sürümünde. Auto Yard ustalarının garajlarını yine de gezebilirsin.")
			_primary.visible = false
		SocialManager.State.SIGNED_OUT:
			_body.text = Loc.t("Arkadaş eklemek ve garajlarını gezmek için Google ile giriş yap. İlerlemen de buluta kaydedilir.")
			_primary.text = Loc.t("GİRİŞ YAP")
		SocialManager.State.LOADING:
			_body.text = Loc.t("Yükleniyor…")
			_primary.visible = false
		SocialManager.State.OFFLINE:
			_body.text = Loc.t("Sunucuya ulaşılamadı. İnternet bağlantını kontrol et.")
			_primary.text = Loc.t("TEKRAR DENE")
		SocialManager.State.NO_PROFILE:
			_body.text = Loc.t("Bir takma ad seç. Arkadaşların bu adı ve garajını görecek; gerçek adın paylaşılmaz.")
			_primary.text = Loc.t("PROFİLİ OLUŞTUR")
			if _name_edit.text.is_empty():
				_name_edit.text = SocialNames.default_name()
		SocialManager.State.READY:
			_name_label.text = _social.my_name()
			_code_label.text = SocialNames.display_code(_social.my_code())
			if _renaming:
				_body.text = Loc.t("Yeni takma adını yaz.")
				_primary.text = Loc.t("KAYDET")
			else:
				_body.text = Loc.t("Kodunu paylaş ya da arkadaşının kodunu yaz. İstek kabul edilince garajlarınızı gezebilirsiniz.")
				_primary.text = Loc.t("YENİLE")
	if _lists.visible:
		_build_lists(busy, ready)


func _build_lists(busy: bool, ready: bool) -> void:
	for child: Node in _lists.get_children():
		_lists.remove_child(child)
		child.queue_free()
	var featured: Array[Dictionary] = FeaturedFriends.all()
	if not ready:
		_lists.add_child(_label(&"HudInkCaption", Loc.t("ARKADAŞLARIN (%d)") % featured.size()))
		_add_featured_rows(featured, busy)
		return
	if not _social.race_events.is_empty():
		_lists.add_child(_label(&"HudInkCaption", Loc.t("YARIŞ HABERLERİ (%d)") % _social.race_events.size()))
		for event: Dictionary in _social.race_events:
			var sender: String = event["uid"]
			var row: HBoxContainer = _person_row(event, event_caption(event), true)
			if bool(event["won"]):
				var revenge: PlateButton = _small_button(Loc.t("İNTİKAM AL"), func() -> void: revenge_requested.emit(sender), busy, true)
				revenge.name = "Revenge_" + sender
				row.add_child(revenge)
			row.add_child(_small_button(Loc.t("TAMAM"), func() -> void: _social.dismiss_event(sender), busy))
			_lists.add_child(row)
	if not _social.incoming.is_empty():
		_lists.add_child(_label(&"HudInkCaption", Loc.t("GELEN İSTEKLER (%d)") % _social.incoming.size()))
		for entry: Dictionary in _social.incoming:
			var uid: String = entry["uid"]
			var row: HBoxContainer = _person_row(entry, SocialNames.display_code(entry["code"]))
			row.add_child(_small_button(Loc.t("KABUL"), func() -> void: _social.accept(uid), busy, true))
			row.add_child(_small_button(Loc.t("RET"), func() -> void: _social.reject(uid), busy))
			_lists.add_child(row)
	_lists.add_child(_label(&"HudInkCaption", Loc.t("ARKADAŞLARIN (%d)") % (_social.friends.size() + featured.size())))
	_add_featured_rows(featured, busy)
	for entry: Dictionary in _social.friends:
		var uid: String = entry["uid"]
		var caption: String = Loc.t("SEVİYE %d") % int(entry["level"])
		var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
		var score: Vector2i = race.score_with(uid) if race else Vector2i.ZERO
		if score.x + score.y > 0:
			caption += Loc.t("  ·  SKOR %d–%d") % [score.x, score.y]
		var asked: String = SaveSafe.s(entry.get("ask_part", ""))
		if not asked.is_empty():
			caption += Loc.t("  ·  %s İSTİYOR") % RestorationCatalog.part_name(StringName(asked))
		var row: HBoxContainer = _person_row(entry, caption)
		if _social.can_gift(uid):
			var gift: PlateButton = _small_button(Loc.t("GÖNDER"), func() -> void: _social.send_gift(uid), busy, true)
			gift.name = "Gift_" + uid
			row.add_child(gift)
		var go: PlateButton = _small_button(Loc.t("GARAJA GİT"), func() -> void: _on_visit_pressed(uid), busy, true)
		go.name = "Visit_" + uid
		row.add_child(go)
		_lists.add_child(row)
	if not _social.outgoing.is_empty():
		_lists.add_child(_label(&"HudInkCaption", Loc.t("GÖNDERDİĞİN İSTEKLER (%d)") % _social.outgoing.size()))
		for entry: Dictionary in _social.outgoing:
			var uid: String = entry["uid"]
			var row: HBoxContainer = _person_row(entry, Loc.t("YANIT BEKLENİYOR"))
			row.add_child(_small_button(Loc.t("GERİ AL"), func() -> void: _social.cancel(uid), busy))
			_lists.add_child(row)


## Haber satırının alt yazısı (ad satırın üstünde): gönderen kazandıysa "VW GOLF 7 ARACINI YENDİ!", kaybettiyse
## "VW GOLF 7 ARACIN ONU YENDİ!"; İNTİKAM yarışıysa önünde "İNTİKAM:".
static func event_caption(event: Dictionary) -> String:
	var car: String = car_name(event["their_car"])
	var text: String = Loc.t("%s ARACINI YENDİ!") % car if bool(event["won"]) else Loc.t("%s ARACIN ONU YENDİ!") % car
	return Loc.t("İNTİKAM: %s") % text if bool(event.get("revenge", false)) else text


## Aracın tek satırlık adı (CarCatalog.label iki satırdır: "MARKA\nMODEL").
static func car_name(vehicle_id: StringName) -> String:
	return String(CarCatalog.get_entry(vehicle_id).get("display_name", vehicle_id)).to_upper()


## HUD bildirimi (adla, tam cümle).
static func event_notice(event: Dictionary) -> String:
	var name: String = SaveSafe.s(event.get("name", ""))
	var car: String = car_name(event["their_car"])
	if bool(event["won"]):
		return Loc.t("%s, %s ARACINI YENDİ!\nİNTİKAM İÇİN: ARKADAŞLAR") % [Loc.upper(name), car]
	return Loc.t("%s ARACIN %s YENDİ!") % [car, Loc.upper(Loc.accusative(name))]


## Öne çıkan arkadaşlar: yalnızca GARAJA GİT (çıkarılamaz), altında "AUTO YARD · SEVİYE n".
func _add_featured_rows(featured: Array[Dictionary], busy: bool) -> void:
	for entry: Dictionary in featured:
		var uid: String = entry["uid"]
		var row: HBoxContainer = _person_row(entry, Loc.t("AUTO YARD USTASI · SEVİYE %d") % int(entry["level"]))
		var go: PlateButton = _small_button(Loc.t("GARAJA GİT"), func() -> void: _on_visit_pressed(uid), busy, true)
		go.name = "Visit_" + uid
		row.add_child(go)
		_lists.add_child(row)


# --- Butonlar ----------------------------------------------------------------

func _on_primary_pressed() -> void:
	if _social == null:
		return
	_notice_text = ""
	match _social.get_state():
		SocialManager.State.SIGNED_OUT:
			screen_requested.emit(&"account")
		SocialManager.State.OFFLINE:
			_social.retry()
		SocialManager.State.NO_PROFILE:
			_social.create_profile(_name_edit.text)
		SocialManager.State.READY:
			if _renaming:
				_renaming = false
				_social.rename(_name_edit.text)
			else:
				_social.refresh(true)
	_refresh()


func _on_rename_pressed() -> void:
	_renaming = true
	_notice_text = ""
	_name_edit.text = _social.my_name() if _social else ""
	_refresh()


func _on_copy_pressed() -> void:
	if _social == null:
		return
	DisplayServer.clipboard_set(SocialNames.display_code(_social.my_code()))
	_on_notice(Loc.t("Kodun kopyalandı."))


func _on_add_pressed() -> void:
	if _social == null or _code_edit.text.strip_edges().is_empty():
		return
	_notice_text = ""
	var sent: bool = await _social.send_request(_code_edit.text)
	if sent:
		_code_edit.text = ""


func _on_visit_pressed(uid: String) -> void:
	_notice_text = ""
	if FeaturedFriends.is_featured(uid):
		if not FeaturedFriends.visit(get_tree(), uid):
			_on_notice(Loc.t("Kayıt buluta yazılıyor, birazdan tekrar dene."))
		return
	_social.visit(uid)


# --- Parçalar ----------------------------------------------------------------

## Kişi satırı: [avatar + ad + alt yazı] (dokununca kart) ve sağda satırın düğmeleri (çağıran ekler).
func _person_row(entry: Dictionary, caption: String, wrap_caption: bool = false) -> HBoxContainer:
	var row: HBoxContainer = _row()
	var uid: String = SaveSafe.s(entry.get("uid", ""))
	var person: Button = Button.new()
	person.name = "Person_" + uid
	person.flat = true
	person.focus_mode = Control.FOCUS_NONE
	person.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		person.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	person.pressed.connect(func() -> void: person_requested.emit(uid))
	var inner: HBoxContainer = _row()
	inner.add_theme_constant_override(&"separation", 8)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	person.add_child(inner)
	var avatar: AvatarView = AvatarView.new()
	avatar.custom_minimum_size = Vector2(AVATAR_SIZE, AVATAR_SIZE)
	avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), entry)
	avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(entry.get("frame", "")),
		SaveSafe.s(entry.get("flag", "")))
	inner.add_child(avatar)
	var names: VBoxContainer = VBoxContainer.new()
	names.mouse_filter = Control.MOUSE_FILTER_IGNORE
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	names.add_theme_constant_override(&"separation", 0)
	var name_label: Label = _label(&"HudInkValue", SaveSafe.s(entry.get("name", "")))
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(name_label)
	var caption_label: Label = _label(&"HudInkCaption", caption)
	if wrap_caption:   # haber cümlesi: düğmeler yer kaplayınca iki satıra sarar (kesilmez)
		caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		caption_label.clip_text = true
		caption_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	names.add_child(caption_label)
	inner.add_child(names)
	# Düğme içindeki kutu kendi boyunu bildirmez: düğmenin en küçük boyu kutununkine eşitlenir
	var fit: Callable = func() -> void: person.custom_minimum_size = Vector2(0.0, inner.get_combined_minimum_size().y)
	inner.minimum_size_changed.connect(fit)
	fit.call()
	row.add_child(person)
	return row


func _row() -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 6)
	return row


func _small_button(text: String, callback: Callable, disabled: bool = false, accent: bool = false) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.custom_minimum_size = Vector2(ROW_BUTTON_WIDTH, 0.0)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	button.highlight = accent
	button.pressed.connect(callback)
	return button


func _line_edit(placeholder: String, max_length: int) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 44.0)
	edit.add_theme_color_override(&"font_color", HudPalette.INK)
	edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	edit.add_theme_font_size_override(&"font_size", 20)
	for style_name: StringName in [&"normal", &"focus"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if style_name == &"focus" else HudPalette.PLATE_EDGE
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 10.0
		style.content_margin_right = 10.0
		edit.add_theme_stylebox_override(style_name, style)
	return edit


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
