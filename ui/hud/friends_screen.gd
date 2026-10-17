class_name FriendsScreen
extends Control
## ARKADAŞLAR (2026-10-17 yeniden tasarım — kullanıcıyla birlikte karar verildi). Eskiden bütün pano tek sütunda
## kayıyordu: çok arkadaşta KAPAT en alta düşüyor, telefonda liste sıkışıyordu. Şimdi tek pencere, kaymayan başlık;
## YALNIZCA arkadaş vitrini (yatay, ataletli kart şeridi — TouchScroll) kayar.
##   Başlık:  (kask rozeti) ARKADAŞLAR · [ARKADAŞLAR n] [İSTEKLER ●n] [HABERLER ●n] · ↻ · ✕   (rozet: bekleyen sayısı)
##   Eylem:   [DAVET LİNKİ GÖNDER] [KODLA EKLE] · son bildirim
##   Vitrin:  tek sıra büyük kart — avatar (+ bayrak), ad, seviye, vitrin aracı, istatistik kutusu (aranızdaki skor,
##            kazanma yüzdesi, koleksiyon, en iyi 300 m), istediği hurdalık parçası + GÖNDER, GARAJA GİT. Kartın
##            düğmeler dışındaki her yerine dokununca ARKADAŞ KARTI (person_requested). Auto Yard Ustaları
##            (Emre / Elif) başta, altın şeritli. Gerçek arkadaş yoksa sonda "arkadaşını çağır" kartı.
##            İSTEKLER: gelen (KABUL / RET) + gönderdiğin (GERİ AL). HABERLER: İNTİKAM AL / TAMAM.
##   Oturum yoksa (misafir / PC / çevrimdışı / takma ad yok) ustaların yanında durum kartı: GİRİŞ YAP, TEKRAR DENE,
##   takma ad + PROFİLİ OLUŞTUR.
## KODLA EKLE penceresi (ekranın içinde): senin kodun (KOPYALA), arkadaşının kodu (EKLE), takma adın (DEĞİŞTİR).
## Kararlar: kart ızgarası / tek sıra büyük kart, krem plaka dili sadeleşmiş, istek + haber rozetli sekmelerde,
## sağ üstte yuvarlak ✕, kendi kodun KODLA EKLE'de, ustalar başta. Haber varken ekran HABERLER'de açılır.
## Ziyarete gidilince kendi sahne dondurulur ve bu ekran AÇIK kalır: dönünce oyuncu vitrine döner.
## Ekran TAMAMEN KODLA kurulur (.tscn yok); HUD temalı Root'un altına ekler, UiRouter'a MODAL kaydeder. Mantık
## SocialManager'da ("social" grubu); bu ekran yalnızca gösterir ve düğmeleri ona iletir.

signal opened
signal closed
## Başka bir ekran istendi (giriş için &"account").
signal screen_requested(id: StringName)
## Bir kişinin kartı istendi (kartın düğmeler dışındaki gövdesi).
signal person_requested(uid: String)
## YARIŞ HABERİ: İNTİKAM AL (gönderenin aracına karşı pist doğrudan açılır; HUD yürütür).
signal revenge_requested(uid: String)

enum Tab { FRIENDS, REQUESTS, NEWS }

const CARD_WIDTH: float = 176.0
const WIDE_CARD_WIDTH: float = 250.0
const AVATAR_SIZE: float = 96.0
const THUMB_SIZE: Vector2 = Vector2(160.0, 90.0)   # assets/cars/thumbs 176x110
## KISA EKRAN (telefon tuvali 480 yükseklik; 2026-10-17 ölçümü: pencere 598 / 480, en kalabalık kart 460): avatar adın
## soluna geçer, araç resmi küçülür, pencere payları daralır. Bütün pencereyi küçültmek yazıyı %75'e indirirdi.
const COMPACT_HEIGHT: float = 600.0
const COMPACT_AVATAR: float = 54.0
const COMPACT_THUMB: Vector2 = Vector2(140.0, 60.0)
const POPUP_WIDTH: float = 380.0

var _social: SocialManager
var _tab: Tab = Tab.FRIENDS
var _compact: bool = false
var _margin: MarginContainer
var _rows: VBoxContainer
var _window: PlatePanel
var _tabs: Dictionary = {}               # Tab → PlateButton
var _tab_group: ButtonGroup = ButtonGroup.new()
var _refresh_button: PlateButton
var _invite_button: PlateButton
var _code_button: PlateButton
var _notice: Label
var _scroll: ScrollContainer
var _cards: HBoxContainer
var _profile_edit: LineEdit              # takma ad kartındaki giriş (profil oluşturma)
var _notice_text: String = ""
# KODLA EKLE penceresi
var _popup: Control
var _popup_column: VBoxContainer
var _code_label: Label
var _code_edit: LineEdit
var _name_label: Label
var _name_edit: LineEdit
var _name_line: HBoxContainer
var _rename_line: HBoxContainer
var _popup_notice: Label
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
	_popup.hide()
	if _social:
		_social.retry()
		_social.refresh()
		# İNTİKAM bekleyen haber varsa doğrudan oraya (HUD bildirimi "İNTİKAM İÇİN: ARKADAŞLAR" der)
		_tab = Tab.NEWS if _social.is_ready() and not _social.race_events.is_empty() else Tab.FRIENDS
	_scroll.scroll_horizontal = 0
	_apply_compact()
	_refresh()
	if visible:
		return
	PlateAnim.pop_in(self, _window)
	opened.emit()


func close() -> void:
	if not visible:
		return
	_popup.hide()
	hide()
	closed.emit()


## Android GERİ: açık KODLA EKLE penceresi önce kapanır. Kapattıysa true.
func close_popup() -> bool:
	if not visible or not _popup.visible:
		return false
	_popup.hide()
	return true


# --- Kurulum -------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	for side: String in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	add_child(margin)
	_margin = margin
	_window = PlatePanel.new()
	_window.name = "Window"
	_window.theme_type_variation = &"HudCarPlate"
	margin.add_child(_window)
	var rows: VBoxContainer = VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override(&"separation", 8)
	_window.add_child(rows)
	_rows = rows

	# Başlık: ad · sekmeler · yenile · kapat (kaymaz)
	var header: HBoxContainer = _hbox(10)
	rows.add_child(header)
	header.add_child(_title_block())
	var tabs: HBoxContainer = _hbox(6)
	tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(tabs)
	for tab: Tab in [Tab.FRIENDS, Tab.REQUESTS, Tab.NEWS]:
		var button: PlateButton = _button("", func() -> void: _select_tab(tab))
		button.name = "Tab%d" % tab
		button.toggle_mode = true
		button.button_group = _tab_group
		tabs.add_child(button)
		_tabs[tab] = button
	header.add_child(_spacer())
	_refresh_button = _round(HudIcon.Kind.ROTATE, func() -> void:
		_notice_text = ""
		if _social:
			_social.refresh(true))
	_refresh_button.name = "RefreshButton"
	header.add_child(_refresh_button)
	var close_button: PlateButton = _round(HudIcon.Kind.CROSS, close)
	close_button.name = "CloseButton"
	header.add_child(close_button)

	# Eylem satırı: davet + kodla ekle + son bildirim (kaymaz)
	var actions: HBoxContainer = _hbox(8)
	rows.add_child(actions)
	_invite_button = _button(Loc.t("DAVET LİNKİ GÖNDER"), _on_invite_pressed, true)
	_invite_button.name = "InviteButton"
	actions.add_child(_invite_button)
	_code_button = _button(Loc.t("KODLA EKLE"), _open_popup)
	_code_button.name = "CodeButton"
	actions.add_child(_code_button)
	_notice = _label(&"HudInkCaption", "")
	_notice.name = "Notice"
	_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_notice.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_notice.max_lines_visible = 2
	actions.add_child(_notice)
	rows.add_child(_rule())

	# Vitrin: YALNIZCA bu kayar (yatay, ataletli)
	_scroll = ScrollContainer.new()
	_scroll.name = "Showcase"
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(_scroll)
	_cards = _hbox(10)
	_cards.name = "Cards"
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL   # az kart vitrini doldurmazsa ortada durur
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	_scroll.add_child(_cards)
	TouchScroll.attach(_scroll)

	_build_popup()


## Kısa ekranda sıkı düzen (açılışta; kartlar _refresh'te buna göre kurulur).
func _apply_compact() -> void:
	_compact = get_viewport_rect().size.y < COMPACT_HEIGHT
	for side: String in ["top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 6 if _compact else 14)
	_rows.add_theme_constant_override(&"separation", 5 if _compact else 8)


## KODLA EKLE: senin kodun · arkadaşının kodu · takma adın (ekranın içinde, kendi karartmasıyla).
func _build_popup() -> void:
	_popup = Control.new()
	_popup.name = "CodePopup"
	_popup.visible = false
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP
	_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_popup)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.35)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_popup.add_child(dim)
	var center: CenterContainer = FitScroll.center_in(_popup)
	_popup_column = VBoxContainer.new()
	_popup_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_popup_column)
	var plate: PlatePanel = PlatePanel.new()
	plate.theme_type_variation = &"HudCarPlate"
	plate.custom_minimum_size = Vector2(POPUP_WIDTH, 0.0)
	_popup_column.add_child(plate)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	plate.add_child(box)

	var head: HBoxContainer = _hbox(8)
	var head_title: Label = _label(&"HudPlateTitle", Loc.t("KODLA EKLE"))
	head_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(head_title)
	head.add_child(_round(HudIcon.Kind.CROSS, func() -> void: _popup.hide()))
	box.add_child(head)

	box.add_child(_label(&"HudInkCaption", Loc.t("SENİN KODUN")))
	var code_line: HBoxContainer = _hbox(8)
	_code_label = _label(&"HudPlateTitle", "")
	_code_label.name = "MyCode"
	_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_line.add_child(_code_label)
	code_line.add_child(_button(Loc.t("KOPYALA"), _on_copy_pressed))
	box.add_child(code_line)

	box.add_child(_label(&"HudInkCaption", Loc.t("ARKADAŞININ KODU")))
	var add_line: HBoxContainer = _hbox(8)
	_code_edit = _line_edit(Loc.t("Arkadaş kodu (AY-…)"), 9)
	_code_edit.name = "CodeEdit"
	_code_edit.text_submitted.connect(func(_t: String) -> void: _on_add_pressed())
	add_line.add_child(_code_edit)
	var add: PlateButton = _button(Loc.t("EKLE"), _on_add_pressed, true)
	add.name = "AddButton"
	add_line.add_child(add)
	box.add_child(add_line)
	box.add_child(_rule())

	box.add_child(_label(&"HudInkCaption", Loc.t("TAKMA ADIN")))
	_name_line = _hbox(8)
	_name_label = _label(&"HudPlateTitle", "")
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_line.add_child(_name_label)
	_name_line.add_child(_button(Loc.t("DEĞİŞTİR"), func() -> void:
		_renaming = true
		_name_edit.text = _social.my_name() if _social else ""
		_refresh_popup()))
	box.add_child(_name_line)
	_rename_line = _hbox(8)
	_name_edit = _line_edit(Loc.t("Takma ad"), SocialNames.NAME_MAX)
	_name_edit.name = "NameEdit"
	_name_edit.text_submitted.connect(func(_t: String) -> void: _on_rename_saved())
	_rename_line.add_child(_name_edit)
	_rename_line.add_child(_button(Loc.t("KAYDET"), _on_rename_saved, true))
	box.add_child(_rename_line)

	_popup_notice = _label(&"HudInkCaption", "")
	_popup_notice.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_popup_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_popup_notice.custom_minimum_size = Vector2(POPUP_WIDTH - 28.0, 0.0)
	box.add_child(_popup_notice)


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


# --- Görünüm -------------------------------------------------------------------

func _refresh() -> void:
	if _cards == null:
		return
	var state: SocialManager.State = _social.get_state() if _social else SocialManager.State.UNAVAILABLE
	var ready: bool = state == SocialManager.State.READY
	var busy: bool = _social != null and _social.is_busy()
	if not ready:
		_tab = Tab.FRIENDS
	var featured: Array[Dictionary] = FeaturedFriends.all()
	var friend_count: int = featured.size() + (_social.friends.size() if ready else 0)
	(_tabs[Tab.FRIENDS] as PlateButton).text = Loc.t("ARKADAŞLAR %d") % friend_count
	(_tabs[Tab.REQUESTS] as PlateButton).text = Loc.t("İSTEKLER")
	(_tabs[Tab.NEWS] as PlateButton).text = Loc.t("HABERLER")
	(_tabs[Tab.REQUESTS] as PlateButton).badge = _social.incoming.size() if ready else 0
	(_tabs[Tab.NEWS] as PlateButton).badge = _social.race_events.size() if ready else 0
	for tab: Tab in _tabs:
		var button: PlateButton = _tabs[tab]
		button.visible = ready or tab == Tab.FRIENDS
		button.set_pressed_no_signal(tab == _tab)
		button.highlight = tab == _tab
	_refresh_button.visible = ready or state == SocialManager.State.OFFLINE
	_refresh_button.disabled = busy
	_invite_button.visible = ready
	_invite_button.disabled = busy
	_code_button.visible = ready
	_notice.text = _notice_text
	_build_cards(state, busy)
	if _popup.visible:
		if ready:
			_refresh_popup()
		else:
			_popup.hide()


func _select_tab(tab: Tab) -> void:
	if tab == _tab:
		(_tabs[tab] as PlateButton).set_pressed_no_signal(true)
		return
	_tab = tab
	_scroll.scroll_horizontal = 0
	_refresh()


func _build_cards(state: SocialManager.State, busy: bool) -> void:
	for child: Node in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	if state != SocialManager.State.READY:
		_add_featured_cards(busy)
		_add_state_card(state, busy)
		return
	match _tab:
		Tab.REQUESTS:
			_add_request_cards(busy)
		Tab.NEWS:
			_add_news_cards(busy)
		_:
			_add_featured_cards(busy)
			for entry: Dictionary in _social.friends:
				_cards.add_child(_friend_card(entry, busy))
			if _social.friends.is_empty():
				_cards.add_child(_invite_card(busy))


func _add_featured_cards(busy: bool) -> void:
	for entry: Dictionary in FeaturedFriends.all():
		_cards.add_child(_friend_card(entry, busy))


## Arkadaş (ve usta) kartı: avatar / ad / seviye (dokununca kart), vitrin aracı, skor; altta istediği parça + GÖNDER
## ve GARAJA GİT. Ustada üstte altın şerit, hediye yok. Üst kısım her kartta aynı hizada (şerit yeri boş da olsa ayrılır).
func _friend_card(entry: Dictionary, busy: bool) -> PanelContainer:
	var uid: String = SaveSafe.s(entry.get("uid", ""))
	var featured: bool = FeaturedFriends.is_featured(uid)
	var card: PanelContainer = _card(CARD_WIDTH, featured)
	var box: VBoxContainer = card.get_child(0)
	var body: Button = _body(uid)
	box.add_child(body)
	var inner: VBoxContainer = body.get_child(0)
	inner.add_child(_ribbon(Loc.t("AUTO YARD USTASI"), featured))
	_add_person(inner, entry, Loc.t("SEVİYE %d") % maxi(int(entry.get("level", 1)), 1))
	inner.add_child(_thumb(SaveSafe.s(entry.get("car", ""))))
	inner.add_child(_stats(entry))
	inner.add_child(_spacer(true))
	var asked: String = SaveSafe.s(entry.get("ask_part", ""))
	if not featured and not asked.is_empty():
		var part: String = Loc.t(RestorationCatalog.part_name(StringName(asked)))
		if _social and _social.can_gift(uid):
			# İstek + düğme tek satır ("CIVATA GÖNDER"): kısa ekranda kartın en kalabalık hali buydu
			var gift: PlateButton = _button(Loc.t("%s GÖNDER") % part, func() -> void: _social.send_gift(uid), true, busy)
			gift.name = "Gift_" + uid
			box.add_child(gift)
		else:
			var wish: Label = _centered(&"HudInkCaption", Loc.t("%s İSTİYOR") % part)
			wish.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
			inner.add_child(wish)
	var go: PlateButton = _button(Loc.t("GARAJA GİT"), func() -> void: _on_visit_pressed(uid), true, busy)
	go.name = "Visit_" + uid
	box.add_child(go)
	return card


## Gerçek arkadaş yokken vitrinin sonunda: arkadaşını çağır (davet linki).
func _invite_card(busy: bool) -> PanelContainer:
	var card: PanelContainer = _card(WIDE_CARD_WIDTH, false)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_spacer(true))
	box.add_child(_centered(&"HudPlateTitle", Loc.t("ARKADAŞINI ÇAĞIR")))
	box.add_child(_wrapped(Loc.t("Davet linki gönder; açan arkadaşın seni hemen ekler. Garajını gezer, aracına karşı yarışırsınız.")))
	box.add_child(_spacer(true))
	box.add_child(_button(Loc.t("DAVET LİNKİ GÖNDER"), _on_invite_pressed, true, busy))
	return card


func _add_request_cards(busy: bool) -> void:
	for entry: Dictionary in _social.incoming:
		var uid: String = entry["uid"]
		var card: PanelContainer = _card(CARD_WIDTH, false)
		var box: VBoxContainer = card.get_child(0)
		box.add_child(_request_body(entry, Loc.t("SANA İSTEK GÖNDERDİ")))
		box.add_child(_button(Loc.t("KABUL"), func() -> void: _social.accept(uid), true, busy))
		box.add_child(_button(Loc.t("RET"), func() -> void: _social.reject(uid), false, busy))
		_cards.add_child(card)
	for entry: Dictionary in _social.outgoing:
		var uid: String = entry["uid"]
		var card: PanelContainer = _card(CARD_WIDTH, false)
		var box: VBoxContainer = card.get_child(0)
		box.add_child(_request_body(entry, Loc.t("YANIT BEKLENİYOR")))
		box.add_child(_button(Loc.t("GERİ AL"), func() -> void: _social.cancel(uid), false, busy))
		_cards.add_child(card)
	if _social.incoming.is_empty() and _social.outgoing.is_empty():
		_cards.add_child(_message_card(Loc.t("BEKLEYEN İSTEK YOK"),
			Loc.t("Davet linkiyle arkadaşın seni hemen ekler; kodla eklemede istek burada görünür.")))


func _add_news_cards(busy: bool) -> void:
	for event: Dictionary in _social.race_events:
		var sender: String = event["uid"]
		var card: PanelContainer = _card(CARD_WIDTH, false)
		var box: VBoxContainer = card.get_child(0)
		var body: Button = _body(sender)
		box.add_child(body)
		var inner: VBoxContainer = body.get_child(0)
		inner.add_child(_ribbon("", false))
		_add_person(inner, event, "")
		inner.add_child(_thumb(String(event.get("car", ""))))   # yarıştığı (seni yenen) aracı
		inner.add_child(_wrapped(event_caption(event)))
		if bool(event["won"]):
			var revenge: PlateButton = _button(Loc.t("İNTİKAM AL"), func() -> void: revenge_requested.emit(sender), true, busy)
			revenge.name = "Revenge_" + sender
			box.add_child(revenge)
		box.add_child(_button(Loc.t("TAMAM"), func() -> void: _social.dismiss_event(sender), false, busy))
		_cards.add_child(card)
	if _social.race_events.is_empty():
		_cards.add_child(_message_card(Loc.t("YENİ HABER YOK"),
			Loc.t("Bir arkadaşın aracına karşı yarışınca burada görürsün. Seni yenen olursa İNTİKAM AL!")))


## Oturum yokken ustaların yanında: ne yapılacağını söyleyen kart (+ düğme / takma ad girişi).
func _add_state_card(state: SocialManager.State, busy: bool) -> void:
	match state:
		SocialManager.State.UNAVAILABLE:
			_cards.add_child(_message_card(Loc.t("YALNIZCA ANDROID"),
				Loc.t("Arkadaş eklemek yalnızca Android sürümünde. Auto Yard ustalarının garajlarını yine de gezebilirsin.")))
		SocialManager.State.SIGNED_OUT:
			var card: PanelContainer = _message_card(Loc.t("GOOGLE İLE GİRİŞ"),
				Loc.t("Arkadaş eklemek ve garajlarını gezmek için Google ile giriş yap. İlerlemen de buluta kaydedilir."))
			(card.get_child(0) as VBoxContainer).add_child(_button(Loc.t("GİRİŞ YAP"),
				func() -> void: screen_requested.emit(&"account"), true, busy))
			_cards.add_child(card)
		SocialManager.State.LOADING:
			_cards.add_child(_message_card(Loc.t("YÜKLENİYOR"), Loc.t("Yükleniyor…")))
		SocialManager.State.OFFLINE:
			var card: PanelContainer = _message_card(Loc.t("BAĞLANTI YOK"),
				Loc.t("Sunucuya ulaşılamadı. İnternet bağlantını kontrol et."))
			(card.get_child(0) as VBoxContainer).add_child(_button(Loc.t("TEKRAR DENE"),
				func() -> void: _social.retry(), true, busy))
			_cards.add_child(card)
		SocialManager.State.NO_PROFILE:
			var card: PanelContainer = _message_card(Loc.t("TAKMA AD SEÇ"),
				Loc.t("Arkadaşların bu adı ve garajını görecek; gerçek adın paylaşılmaz."))
			var box: VBoxContainer = card.get_child(0)
			_profile_edit = _line_edit(Loc.t("Takma ad"), SocialNames.NAME_MAX)
			_profile_edit.name = "NameEdit"
			_profile_edit.size_flags_horizontal = Control.SIZE_FILL
			_profile_edit.text = SocialNames.default_name()
			_profile_edit.text_submitted.connect(func(_t: String) -> void: _social.create_profile(_profile_edit.text))
			box.add_child(_profile_edit)
			var create: PlateButton = _button(Loc.t("PROFİLİ OLUŞTUR"),
				func() -> void: _social.create_profile(_profile_edit.text), true, busy)
			create.name = "PrimaryButton"
			box.add_child(create)
			_cards.add_child(card)


# --- KODLA EKLE penceresi ----------------------------------------------------------

func _open_popup() -> void:
	_renaming = false
	_code_edit.text = ""
	_popup_notice.text = ""
	_refresh_popup()
	_popup.show()
	PlateAnim.pop_in(_popup, _popup_column)


func _refresh_popup() -> void:
	if _social == null:
		return
	_code_label.text = SocialNames.display_code(_social.my_code())
	_name_label.text = _social.my_name()
	_name_line.visible = not _renaming
	_rename_line.visible = _renaming
	_popup_notice.text = _notice_text
	_popup_notice.visible = not _notice_text.is_empty()


func _on_copy_pressed() -> void:
	if _social == null:
		return
	DisplayServer.clipboard_set(SocialNames.display_code(_social.my_code()))
	_on_notice(Loc.t("Kodun kopyalandı."))


func _on_add_pressed() -> void:
	if _social == null or _code_edit.text.strip_edges().is_empty():
		return
	_notice_text = ""
	if await _social.send_request(_code_edit.text):
		_code_edit.text = ""


func _on_rename_saved() -> void:
	if _social == null:
		return
	_renaming = false
	_social.rename(_name_edit.text)
	_refresh_popup()


# --- Düğmeler -------------------------------------------------------------------

## DAVET LİNKİ: link oluşturulur, telefonun paylaşım penceresi açılır (PC'de panoya kopyalanır).
func _on_invite_pressed() -> void:
	if _social == null:
		return
	_notice_text = ""
	var link: String = await _social.create_invite()
	if link.is_empty():
		_refresh()   # nedeni SocialManager.notice yazdı
		return
	var text: String = Loc.t("Auto Yard'da arkadaşım ol! Linke dokun, beni hemen eklersin (1 saat geçerli): %s") % link
	var how: String = LinkShare.share(text, Loc.t("Davet linkini gönder"))
	_on_notice(Loc.t("Link 1 saat geçerli. Açan arkadaşın seni hemen ekler.") if how == "shared"
		else Loc.t("Davet linki kopyalandı. Arkadaşına gönder (1 saat geçerli)."))


func _on_visit_pressed(uid: String) -> void:
	_notice_text = ""
	if FeaturedFriends.is_featured(uid):
		if not FeaturedFriends.visit(get_tree(), uid):
			_on_notice(Loc.t("Kayıt buluta yazılıyor, birazdan tekrar dene."))
		return
	_social.visit(uid)


# --- Haber metinleri (HUD de kullanır) ---------------------------------------------

## Haber kartının alt yazısı: gönderen kazandıysa "VW GOLF 7 ARACINI YENDİ!", kaybettiyse
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


# --- Parçalar --------------------------------------------------------------------

## Kart: açık krem zemin, yuvarlak köşe, ince kenar, hafif gölge (ustada altın kenar). İçinde dikey kutu.
func _card(width: float, gold: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(width, 0.0)
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.PLATE_HOVER
	style.border_color = HudPalette.PLATE_SELECTED_EDGE if gold else Color(HudPalette.PLATE_EDGE, 0.8)
	style.set_border_width_all(2 if gold else 1)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.12)
	style.shadow_size = 3
	style.shadow_offset = Vector2(0.0, 2.0)
	style.set_content_margin_all(8.0)
	card.add_theme_stylebox_override(&"panel", style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 3)
	card.add_child(box)
	return card


## Başlık + açıklama kartı (boş liste / oturum durumu); çağıran altına düğme ekleyebilir.
func _message_card(title: String, text: String) -> PanelContainer:
	var card: PanelContainer = _card(WIDE_CARD_WIDTH, false)
	var box: VBoxContainer = card.get_child(0)
	box.add_child(_spacer(true))
	box.add_child(_centered(&"HudPlateTitle", title))
	box.add_child(_wrapped(text))
	box.add_child(_spacer(true))
	return card


## Kartın üst şeridi (ustalar): altın zemin, koyu yazı. shown=false: aynı boyda görünmez yer (avatarlar hizalı kalsın).
func _ribbon(text: String, shown: bool = true) -> PanelContainer:
	var ribbon: PanelContainer = PanelContainer.new()
	ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not shown:
		ribbon.modulate = Color.TRANSPARENT
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.PLATE_SELECTED
	style.set_corner_radius_all(6)
	style.content_margin_top = 1.0
	style.content_margin_bottom = 1.0
	ribbon.add_theme_stylebox_override(&"panel", style)
	ribbon.add_child(_centered(&"HudInkCaption", text if shown else " "))
	return ribbon


## Kartın dokunulan GÖVDESİ (düğmeler dışındaki her yer): dokununca ARKADAŞ KARTI. İçerik `get_child(0)` kutusuna
## eklenir; gövde kartın boş yüksekliğini doldurur, düğmeler altta kalır. Basılıyken hafif koyulaşır (fareyle üstüne
## gelince değil: telefonda dokunuştan sonra "üstünde" hâli takılı kalıyor).
func _body(uid: String) -> Button:
	var body: Button = Button.new()
	body.name = "Person_" + uid
	body.flat = true
	body.focus_mode = Control.FOCUS_NONE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for state: StringName in [&"normal", &"hover", &"focus", &"disabled"]:
		body.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var pressed: StyleBoxFlat = StyleBoxFlat.new()
	pressed.bg_color = Color(HudPalette.INK, 0.07)
	pressed.set_corner_radius_all(8)
	for state: StringName in [&"pressed", &"hover_pressed"]:
		body.add_theme_stylebox_override(state, pressed)
	body.pressed.connect(func() -> void: person_requested.emit(uid))
	var inner: VBoxContainer = VBoxContainer.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_constant_override(&"separation", 3)
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(inner)
	# Düğme içindeki kutu kendi boyunu bildirmez: düğmenin en küçük boyu kutununkine eşitlenir
	var fit: Callable = func() -> void: body.custom_minimum_size = Vector2(0.0, inner.get_combined_minimum_size().y)
	inner.minimum_size_changed.connect(fit)
	fit.call()
	return body


## Kişi: avatar (+ bayrak), ad, alt yazı.
func _add_person(box: VBoxContainer, entry: Dictionary, caption: String) -> void:
	var avatar: AvatarView = AvatarView.new()
	var diameter: float = COMPACT_AVATAR if _compact else AVATAR_SIZE
	avatar.custom_minimum_size = Vector2(diameter, diameter)
	avatar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var art: Dictionary = ProfileCard.avatar_for(get_tree(), entry)
	avatar.show_avatar(art.get("texture"), bool(art.get("illustrated", true)), SaveSafe.s(entry.get("frame", "")),
		SaveSafe.s(entry.get("flag", "")))
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
	if _compact:
		# Kısa ekran: avatar solda, ad + alt yazı sağında (alt alta dizilince kart 70 birim uzuyordu)
		var person_row: HBoxContainer = _hbox(6)
		box.add_child(person_row)
		avatar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		person_row.add_child(avatar)
		var column: VBoxContainer = VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		column.add_theme_constant_override(&"separation", 0)
		person_row.add_child(column)
		box = column
		align = HORIZONTAL_ALIGNMENT_LEFT
	else:
		box.add_child(avatar)
	var name_label: Label = _centered(&"HudPlateTitle", SaveSafe.s(entry.get("name", "")))
	name_label.horizontal_alignment = align
	name_label.clip_text = true
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(name_label)
	if caption.is_empty():
		return
	var likes: int = SaveSafe.i((entry.get("stats", {}) as Dictionary).get("likes", 0)) if entry.get("stats") is Dictionary else 0
	if likes <= 0:
		var caption_label: Label = _centered(&"HudInkCaption", caption)
		caption_label.horizontal_alignment = align
		box.add_child(caption_label)
		return
	# GARAJIN BEĞENİSİ (OTO MANŞET): seviyenin yanında kalp + sayı — kart boyu değişmez (vitrin 16:9'da zaten dar)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Likes"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if _compact else BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 3)
	row.add_child(_label(&"HudInkCaption", caption + "  ·"))
	var heart: HudIcon = HudIcon.new()
	heart.kind = HudIcon.Kind.HEART
	heart.icon_size = 11.0
	heart.custom_minimum_size = Vector2(11.0, 11.0)
	heart.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(heart)
	var count: Label = _label(&"HudInkCaption", Hud.format_thousands(likes))
	count.add_theme_color_override(&"font_color", HudIcon.HEART_DARK)
	row.add_child(count)
	box.add_child(row)


## İstek kartının gövdesi: kişi, kodu, durum yazısı (istek belgesinde araç / istatistik yok).
func _request_body(entry: Dictionary, status: String) -> Button:
	var body: Button = _body(SaveSafe.s(entry.get("uid", "")))
	var inner: VBoxContainer = body.get_child(0)
	inner.add_child(_ribbon("", false))
	_add_person(inner, entry, SocialNames.display_code(SaveSafe.s(entry.get("code", ""))))
	inner.add_child(_centered(&"HudInkCaption", status))
	return body


## İstatistik kutusu (koyu krem): aranızdaki skor (öndeysen altın, gerideysen kırmızı), kazanma yüzdesi, koleksiyon,
## en iyi 300 m. Profil belgesinde olmayan değer (eski sürüm / hiç yarışmamış) "–".
func _stats(entry: Dictionary) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Stats"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.PLATE
	style.set_corner_radius_all(6)
	style.content_margin_left = 8.0
	style.content_margin_right = 8.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	panel.add_theme_stylebox_override(&"panel", style)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.add_theme_constant_override(&"h_separation", 6)
	grid.add_theme_constant_override(&"v_separation", 0)
	panel.add_child(grid)

	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	var score: Vector2i = race.score_with(SaveSafe.s(entry.get("uid", ""))) if race else Vector2i.ZERO
	var score_color: Color = HudPalette.INK
	if score.x > score.y:
		score_color = HudPalette.COIN_DARK
	elif score.x < score.y:
		score_color = HudPalette.DANGER
	var stats: Dictionary = entry.get("stats", {}) if entry.get("stats") is Dictionary else {}
	var races: int = SaveSafe.i(stats.get("races", 0))
	var wins: int = SaveSafe.i(stats.get("wins", 0))
	var cars: int = SaveSafe.i(stats.get("cars", 0))
	var best: int = SaveSafe.i(stats.get("best", 0))
	var rows: Array[Array] = [
		[Loc.t("ARANIZDA"), "%d–%d" % [score.x, score.y] if score.x + score.y > 0 else "–", score_color],
		[Loc.t("KAZANMA"), Loc.percent(str(roundi(100.0 * wins / races))) if races > 0 else "–", HudPalette.INK],
		[Loc.t("KOLEKSİYON"), "%d/%d" % [cars, VehicleOwnership.collection_ids().size()] if cars > 0 else "–",
			HudPalette.INK],
		[Loc.t("EN İYİ 300 M"), Loc.t("%s sn") % Loc.decimal(best / 1000.0, 2) if best > 0 else "–", HudPalette.INK],
	]
	for row: Array in rows:
		var key: Label = _label(&"HudInkCaption", row[0])
		key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		key.clip_text = true
		key.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		grid.add_child(key)
		var value: Label = _label(&"HudInkValue", row[1])
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.add_theme_font_size_override(&"font_size", 12)
		value.add_theme_color_override(&"font_color", row[2])
		grid.add_child(value)
	return panel


## Vitrin aracının küçük resmi (assets/cars/thumbs); seçilmemişse aynı boyda boşluk (kartlar hizalı kalsın).
func _thumb(car_id: String) -> TextureRect:
	var thumb: TextureRect = TextureRect.new()
	thumb.custom_minimum_size = COMPACT_THUMB if _compact else THUMB_SIZE
	thumb.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var path: String = ProfileCard.THUMB_DIR + car_id + ".png"
	if not car_id.is_empty() and not CarCatalog.get_entry(StringName(car_id)).is_empty() and ResourceLoader.exists(path):
		thumb.texture = load(path) as Texture2D
	return thumb


func _button(text: String, callback: Callable, accent: bool = false, disabled: bool = false) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.highlight = accent
	button.disabled = disabled
	button.pressed.connect(callback)
	return button


## Ekran başlığı: altın yuvarlak rozette kask + kalın ARKADAŞLAR, altında kısa altın çizgi.
func _title_block() -> HBoxContainer:
	var block: HBoxContainer = _hbox(8)
	block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var badge: PanelContainer = PanelContainer.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.COIN
	style.border_color = HudPalette.COIN_DARK
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.set_content_margin_all(7.0)
	badge.add_theme_stylebox_override(&"panel", style)
	var icon: HudIcon = HudIcon.new()
	icon.kind = HudIcon.Kind.HELMET
	icon.icon_size = 24.0
	icon.color = HudPalette.INK
	icon.cutout = HudPalette.COIN
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	block.add_child(badge)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	column.add_theme_constant_override(&"separation", 2)
	var title: Label = _label(&"HudSignTitle", Loc.t("ARKADAŞLAR"))
	title.name = "Title"
	title.add_theme_font_size_override(&"font_size", 24)
	column.add_child(title)
	var bar: ColorRect = ColorRect.new()
	bar.color = HudPalette.COIN
	bar.custom_minimum_size = Vector2(40.0, 3.0)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(bar)
	block.add_child(column)
	return block


## Başlıktaki yuvarlak tabela (HUD'un kamera / ayarlar tabelalarıyla aynı dil).
func _round(kind: HudIcon.Kind, callback: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudSign"
	button.shape = PlateButton.Shape.ROUND
	button.kind = kind
	button.icon_size = 18.0
	button.custom_minimum_size = Vector2(32.0, 32.0)
	button.bolts = false
	button.lift_when_pressed = 0.0
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.pressed.connect(callback)
	return button


func _line_edit(placeholder: String, max_length: int) -> LineEdit:
	var edit: LineEdit = LineEdit.new()
	edit.placeholder_text = placeholder
	edit.max_length = max_length
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	edit.custom_minimum_size = Vector2(0.0, PlateButton.MIN_PLATE_HEIGHT)
	edit.focus_mode = Control.FOCUS_ALL
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


func _hbox(separation: int) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", separation)
	return row


## `vertical`: kartta düğmeleri alta iten boşluk; değilse satırda yatay boşluk.
func _spacer(vertical: bool = false) -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical:
		spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	else:
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spacer


## İnce ayırıcı çizgi (mürekkep, düşük opaklık).
func _rule() -> ColorRect:
	var line: ColorRect = ColorRect.new()
	line.color = Color(HudPalette.INK, 0.14)
	line.custom_minimum_size = Vector2(0.0, 2.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _centered(variation: StringName, text: String) -> Label:
	var label: Label = _label(variation, text)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _wrapped(text: String) -> Label:
	var label: Label = _centered(&"HudInkCaption", text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
