class_name InboxScreen
extends Control
## HABERLER — sağ üstteki gazete tabelasının panosu (UiRouter MODAL "inbox"; 2026-10-25, docs/HABERLER.md, kullanıcının
## seçtiği taslak A): solda haber listesi (koyu çerçevede krem satırlar: kapak, tür hapı, zaman, başlık; sağda durum —
## kırmızı nokta, SON N GÜN, ALINDI, kalan süre), sağda seçilen haberin okuma kartı (büyük kapak, gönderen · zaman,
## başlık, metin, içindekiler, düğme). Açılınca haberler görülmüş sayılır (Inbox.mark_open) — bu açılışta yeni olanlar
## yine noktalı görünür; hediyeler AL ile TEK TEK alınır (claim_requested → MailNotice ödül penceresi). Düğmenin hedefi
## panelde seçilir (action_requested → Hud). Kodla kurulur (Hud).

signal closed
signal action_requested(kind: String, url: String)
signal claim_requested(id: String)

const LIST_WIDTH: float = 400.0
const CARD_WIDTH: float = 290.0
const BODY_HEIGHT: float = 380.0
const ROW_HEIGHT: float = 56.0
const COVER_HEIGHT: float = 104.0
## Bitmesine bu kadar kalan hediyede kırmızı SON N GÜN (kullanıcı kararı: son 3 gün).
const SOON_SEC: int = 3 * 86400

## Tür → (hap yazısı, hap rengi, yazı rengi).
const PILLS: Dictionary = {
	&"gift": ["HEDİYE", Color("C0392B"), Color.WHITE],
	&"message": ["MESAJ", Color("8A7F68"), Color.WHITE],
	&"update": ["GÜNCELLEME", Color("3D6E72"), Color.WHITE],
	&"event": ["ETKİNLİK", Color("F5BE4C"), Color("2F3236")],
	&"notice": ["DUYURU", Color("2F3236"), Color("F3E8CF")],
	&"guest": ["HESAP", Color("3D9FC7"), Color.WHITE],
}
const ACTION_TEXT: Dictionary = {
	"market": "MARKET'E GİT", "event": "ETKİNLİĞE GİT", "quests": "GÖREVLERE GİT", "showroom": "SHOWROOM'A GİT",
	"friends": "ARKADAŞLARA GİT", "invite": "DAVET ET", "store": "GÜNCELLE", "url": "BAĞLANTIYI AÇ", "account": "GİRİŞ YAP",
}
const ALERT: Color = Color("C0392B")

var _hud: Hud
var _inbox: Inbox
var _images: InboxImages
var _column: VBoxContainer
var _gift_pill: PanelContainer
var _new_pill: PanelContainer
var _scroll: ScrollContainer
var _list: VBoxContainer
var _empty: Label
var _card: PlatePanel
var _cover: InboxCover
var _card_pill: PanelContainer
var _card_meta: Label
var _card_title: Label
var _card_text: Label
var _rewards: VBoxContainer
var _status: Label
var _button: PlateButton
var _selected: String = ""
var _fresh: Dictionary = {}   # bu açılışta yeni olan haberler (görüldü sayıldı ama noktası kalır)
var _closing: bool = false


func _init(hud: Hud, inbox: Inbox) -> void:
	_hud = hud
	_inbox = inbox
	name = "InboxScreen"


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_images = InboxImages.new()
	_images.loaded.connect(func(_url: String, _texture: Texture2D) -> void:
		if visible:
			_refresh())
	add_child(_images)
	_build()
	_inbox.changed.connect(func() -> void:
		if visible:
			_refresh())


func open() -> void:
	_closing = false
	_fresh.clear()
	for entry: Dictionary in _inbox.items():
		if entry["unread"] and entry["kind"] != Inbox.GIFT:
			_fresh[entry["id"]] = true
	_selected = _default_selection()
	_inbox.mark_open()
	_refresh()
	_scroll.scroll_vertical = 0
	show()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Seçili haberin kimliği (testler / QA).
func selected() -> String:
	return _selected


## Haberi seçer (testler / QA): okuma kartı onu gösterir.
func select(id: String) -> void:
	_selected = id
	_refresh()


## İlk açılışta alınmamış ilk hediye, yoksa listenin ilki.
func _default_selection() -> String:
	var items: Array[Dictionary] = _inbox.items()
	for entry: Dictionary in items:
		if entry["kind"] == Inbox.GIFT and not entry["claimed"]:
			return entry["id"]
	return items[0]["id"] if not items.is_empty() else ""


func _refresh() -> void:
	var items: Array[Dictionary] = _inbox.items()
	if _inbox.item(_selected).is_empty():
		_selected = items[0]["id"] if not items.is_empty() else ""
	var gifts: int = _inbox.gift_count()
	(_gift_pill.get_child(0) as Label).text = Loc.tn("%d HEDİYE", gifts) % gifts
	_gift_pill.visible = gifts > 0
	(_new_pill.get_child(0) as Label).text = Loc.tn("%d YENİ", _fresh.size()) % _fresh.size()
	_new_pill.visible = not _fresh.is_empty()
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var now: int = LiveEvent.now()
	for entry: Dictionary in items:
		var row: _Row = _Row.new(entry, _fresh.has(entry["id"]), entry["id"] == _selected, now,
			_images.get_texture(entry["image"]))
		row.pressed.connect(select.bind(entry["id"]))
		_list.add_child(row)
	_empty.visible = items.is_empty()
	_card.visible = not items.is_empty()
	if not items.is_empty():
		_show_card(_inbox.item(_selected), now)


# --- Okuma kartı ---------------------------------------------------------------------------

func _show_card(entry: Dictionary, now: int) -> void:
	var kind: StringName = entry["kind"]
	_cover.kind = kind
	_cover.texture = _images.get_texture(entry["image"])
	_cover.fit = false
	var mail: Dictionary = entry["mail"]
	if _cover.texture == null and not mail.is_empty() and not (mail["cars"] as Array).is_empty():
		_cover.texture = _car_thumb(mail["cars"][0])   # araç hediyesi: kapakta aracın kendisi (kırpılmadan)
		_cover.fit = true
	_cover.faded = entry["claimed"] and kind == Inbox.GIFT
	_set_pill(_card_pill, kind)
	var parts: Array[String] = []
	if not String(entry["from"]).is_empty():
		parts.append(Loc.t("%s gönderdi") % entry["from"])
	elif kind == Inbox.GIFT or kind == Inbox.MESSAGE:
		parts.append(Loc.t("%s gönderdi") % "AUTO YARD")
	if int(entry["at"]) > 0:
		parts.append(age_text(int(entry["at"]), now))
	_card_meta.text = "  ·  ".join(parts)
	_card_title.text = entry["title"]
	_card_title.visible = not String(entry["title"]).is_empty()
	_card_text.text = entry["text"]
	_card_text.visible = not String(entry["text"]).is_empty()
	for child: Node in _rewards.get_children():
		_rewards.remove_child(child)
		child.queue_free()
	if not (entry["mail"] as Dictionary).is_empty():
		_mail_rewards(entry["mail"])
	elif not (entry["rewards"] as Dictionary).is_empty():
		_past_rewards(entry["rewards"])
	_rewards.visible = _rewards.get_child_count() > 0
	_status.text = status_text(entry, now)
	_status.visible = not _status.text.is_empty()
	_set_button(entry)


func _set_button(entry: Dictionary) -> void:
	var mail: Dictionary = entry["mail"]
	_button.highlight = false
	if not mail.is_empty() and entry["kind"] == Inbox.GIFT:
		_button.highlight = true
		_button.text = Loc.t("KAYDI GERİ YÜKLE") if not (mail["restore"] as Dictionary).is_empty() \
			else (Loc.t("AL") if MailService.has_reward(mail) else Loc.t("TAMAM"))
		_button.visible = true
		return
	var kind: String = SaveSafe.s((entry["action"] as Dictionary).get("kind", ""))
	_button.text = Loc.t(ACTION_TEXT.get(kind, ""))
	_button.visible = ACTION_TEXT.has(kind)


func _on_button() -> void:
	var entry: Dictionary = _inbox.item(_selected)
	if entry.is_empty():
		return
	if entry["kind"] == Inbox.GIFT and not entry["claimed"]:
		claim_requested.emit(entry["id"])
		return
	var action: Dictionary = entry["action"]
	action_requested.emit(SaveSafe.s(action.get("kind", "")), SaveSafe.s(action.get("url", "")))


## Alınmamış postanın içindekiler (MailNotice'teki satırlarla aynı bilgiler).
func _mail_rewards(mail: Dictionary) -> void:
	if int(mail["money"]) > 0:
		_reward_line(HudIcon.Kind.COIN, "+%s ₺" % Hud.format_thousands(int(mail["money"])))
	if int(mail["money_min"]) > 0:
		_reward_line(HudIcon.Kind.COIN, "+%s ₺" % Hud.format_thousands(MailService.income_money(get_tree(), int(mail["money_min"]))))
	if int(mail["gems"]) > 0:
		_reward_line(HudIcon.Kind.GEM, Loc.t("+%d GEM") % int(mail["gems"]))
	for car: StringName in mail["cars"]:
		_reward_line(HudIcon.Kind.CAR, MailService.car_name(car))
	for crate_id: StringName in mail["crates"]:
		var count: int = int(mail["crates"][crate_id])
		var crate_text: String = MailService.crate_name(crate_id)
		_reward_line(HudIcon.Kind.BOX, crate_text if count == 1 else "%s ×%d" % [crate_text, count])
	for item: StringName in mail["decor"]:
		var count: int = int(mail["decor"][item])
		var decor_text: String = MailService.decor_name(item)
		_reward_line(HudIcon.Kind.CHAIR, decor_text if count == 1 else "%s ×%d" % [decor_text, count])
	if not String(mail["frame"]).is_empty():
		_reward_line(HudIcon.Kind.HELMET, MailService.frame_name(mail["frame"]))
	if not String(mail["choice"]).is_empty():
		_reward_line(HudIcon.Kind.CAR, Loc.t("EFSANEVİ ARAÇ SEÇİMİ"))
	var adjust: Dictionary = mail["adjust"]
	var adjust_money: int = int(adjust.get("money", 0))
	var adjust_gems: int = int(adjust.get("gems", 0))
	if adjust_money != 0:
		_reward_line(HudIcon.Kind.COIN, "%s%s ₺" % ["+" if adjust_money > 0 else "−", Hud.format_thousands(absi(adjust_money))],
			HudPalette.INK if adjust_money > 0 else HudPalette.DANGER)
	if adjust_gems != 0:
		_reward_line(HudIcon.Kind.GEM, ("+" if adjust_gems > 0 else "−") + Loc.t("%d GEM") % absi(adjust_gems),
			HudPalette.INK if adjust_gems > 0 else HudPalette.DANGER)
	if not (mail["restore"] as Dictionary).is_empty():
		_reward_line(HudIcon.Kind.UNDO, Loc.t("Dokununca oyunun bu kayda döner; şimdiki kaydın telefonunda yedeklenir."))


func _past_rewards(past: Dictionary) -> void:
	if int(past["money"]) > 0:
		_reward_line(HudIcon.Kind.COIN, "+%s ₺" % Hud.format_thousands(int(past["money"])))
	if int(past["gems"]) > 0:
		_reward_line(HudIcon.Kind.GEM, Loc.t("+%d GEM") % int(past["gems"]))
	for line: Variant in past["items"]:
		_reward_line(HudIcon.Kind.CHECK, SaveSafe.s(line))


func _reward_line(kind: HudIcon.Kind, text: String, color: Color = HudPalette.INK) -> void:
	var row: PanelContainer = PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("FBF4E4")
	box.set_corner_radius_all(6)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	row.add_theme_stylebox_override(&"panel", box)
	var line: HBoxContainer = HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override(&"separation", 8)
	row.add_child(line)
	var icon: HudIcon = HudIcon.new()
	icon.kind = kind
	icon.icon_size = 18.0
	icon.custom_minimum_size = Vector2(20.0, 20.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(icon)
	var label: Label = _label(&"HudInkCaption", text)
	label.add_theme_color_override(&"font_color", color)
	label.add_theme_font_size_override(&"font_size", 13)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(label)
	_rewards.add_child(row)


static func _car_thumb(car: StringName) -> Texture2D:
	var path: String = ProfileCard.THUMB_DIR + String(car) + ".png"
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


# --- Metinler ------------------------------------------------------------------------------

## "ŞİMDİ" · "5 DK ÖNCE" · "2 SA ÖNCE" · "DÜN" · "4 GÜN ÖNCE".
static func age_text(at: int, now: int) -> String:
	var ago: int = maxi(now - at, 0)
	if ago < 60:
		return Loc.t("ŞİMDİ")
	if ago < 3600:
		return Loc.t("%d DK ÖNCE") % (ago / 60)
	if ago < 86400:
		return Loc.t("%d SA ÖNCE") % (ago / 3600)
	if ago < 2 * 86400:
		return Loc.t("DÜN")
	return Loc.t("%d GÜN ÖNCE") % (ago / 86400)


## Satırın / kartın durum yazısı: alınmış hediye ALINDI, bitmek üzere hediye SON N GÜN, bitişli haber kalan süre.
static func status_text(entry: Dictionary, now: int) -> String:
	if entry["claimed"]:
		return Loc.t("ALINDI") if entry["kind"] == Inbox.GIFT else ""
	var expires: int = int(entry["expires"])
	if entry["kind"] == Inbox.GIFT and expires > 0 and expires - now <= SOON_SEC:
		var left: int = maxi(expires - now, 0)
		return Loc.t("SON %d SAAT") % maxi(left / 3600, 1) if left < 86400 else Loc.tn("SON %d GÜN", ceili(left / 86400.0)) % ceili(left / 86400.0)
	var end: int = int(entry["end"])
	if end > now:
		var left: int = end - now
		if left >= 86400:
			return Loc.t("%d G %d SA KALDI") % [left / 86400, left / 3600 % 24]
		if left >= 3600:
			return Loc.t("%d SA %d DK KALDI") % [left / 3600, left / 60 % 60]
		return Loc.t("%d DK KALDI") % maxi(left / 60, 1)
	return ""


# --- Kurulum -------------------------------------------------------------------------------

func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.05, 0.06, 0.05, 0.86)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(center)
	_column = VBoxContainer.new()
	_column.name = "Column"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var header: HBoxContainer = HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override(&"separation", 10)
	_column.add_child(header)
	var title: Label = _label(&"HudOutlinedLarge", Loc.t("HABERLER"))
	title.add_theme_font_size_override(&"font_size", 24)
	header.add_child(title)
	_gift_pill = _pill(PILLS[&"gift"][1], PILLS[&"gift"][2], 12)
	header.add_child(_gift_pill)
	_new_pill = _pill(PILLS[&"notice"][1], PILLS[&"notice"][2], 12)
	header.add_child(_new_pill)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_button: PlateButton = PlateButton.new()
	close_button.name = "CloseButton"
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 12)
	_column.add_child(body)
	body.add_child(_build_list())
	body.add_child(_build_card())


func _build_list() -> Control:
	var frame: PanelContainer = PanelContainer.new()
	frame.name = "ListFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.custom_minimum_size = Vector2(LIST_WIDTH, BODY_HEIGHT)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color("5C5442")
	box.set_corner_radius_all(10)
	box.set_content_margin_all(6.0)
	frame.add_theme_stylebox_override(&"panel", box)
	_scroll = ScrollContainer.new()
	_scroll.name = "ListScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	TouchScroll.attach(_scroll)
	frame.add_child(_scroll)
	var inner: VBoxContainer = VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scroll.add_child(inner)
	_list = VBoxContainer.new()
	_list.name = "List"
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.add_theme_constant_override(&"separation", 6)
	inner.add_child(_list)
	_empty = _label(&"HudOutlined", Loc.t("HENÜZ HABER YOK"))
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.custom_minimum_size = Vector2(0.0, BODY_HEIGHT - 20.0)
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	inner.add_child(_empty)
	return frame


func _build_card() -> Control:
	_card = PlatePanel.new()
	_card.name = "Card"
	_card.theme_type_variation = &"HudCarPlate"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(CARD_WIDTH, BODY_HEIGHT)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 6)
	_card.add_child(box)
	_cover = InboxCover.new()
	_cover.name = "Cover"
	_cover.custom_minimum_size = Vector2(0.0, COVER_HEIGHT)
	box.add_child(_cover)
	var meta: HBoxContainer = HBoxContainer.new()
	meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meta.add_theme_constant_override(&"separation", 8)
	box.add_child(meta)
	_card_pill = _pill(PILLS[&"gift"][1], PILLS[&"gift"][2], 10)
	meta.add_child(_card_pill)
	_card_meta = _label(&"HudInkCaption", "")
	_card_meta.add_theme_font_size_override(&"font_size", 11)
	_card_meta.modulate.a = 0.8
	_card_meta.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART   # gönderen · zaman sığmazsa alt satıra
	_card_meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta.add_child(_card_meta)
	# Başlık, metin ve içindekiler kayar (uzun güncelleme notu); düğme hep altta görünür
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "CardScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	TouchScroll.attach(scroll)
	box.add_child(scroll)
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override(&"separation", 6)
	scroll.add_child(content)
	_card_title = _label(&"HudPlateTitle", "")
	_card_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_title.custom_minimum_size = Vector2(CARD_WIDTH - 30.0, 0.0)
	content.add_child(_card_title)
	_card_text = _label(&"HudInkCaption", "")
	_card_text.add_theme_font_size_override(&"font_size", 13)
	_card_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_text.custom_minimum_size = Vector2(CARD_WIDTH - 30.0, 0.0)
	content.add_child(_card_text)
	_rewards = VBoxContainer.new()
	_rewards.name = "Rewards"
	_rewards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rewards.add_theme_constant_override(&"separation", 4)
	content.add_child(_rewards)
	_status = _label(&"HudInkCaption", "")
	_status.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	_status.add_theme_font_size_override(&"font_size", 12)
	box.add_child(_status)
	_button = PlateButton.new()
	_button.name = "ActionButton"
	_button.theme_type_variation = &"HudPlateSmall"
	_button.focus_mode = Control.FOCUS_NONE
	_button.pressed.connect(_on_button)
	box.add_child(_button)
	return _card


func _set_pill(pill: PanelContainer, kind: StringName) -> void:
	var spec: Array = PILLS.get(kind, PILLS[&"notice"])
	(pill.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = spec[1]
	var label: Label = pill.get_child(0) as Label
	label.text = Loc.t(spec[0])
	label.add_theme_color_override(&"font_color", spec[2])


static func _pill(fill: Color, ink: Color, font_size: int) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(5)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 1.0
	pill.add_theme_stylebox_override(&"panel", box)
	var label: Label = _label(&"HudInkCaption", "")
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", ink)
	pill.add_child(label)
	return pill


static func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Liste satırı: krem plaka (seçiliyse amber çerçeve), kapak, tür hapı + zaman, başlık; sağda durum.
class _Row:
	extends Button

	var _selected: bool = false

	func _init(entry: Dictionary, fresh: bool, selected: bool, now: int, image: Texture2D) -> void:
		_selected = selected
		name = "Row_" + String(entry["id"]).validate_node_name()
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(0.0, InboxScreen.ROW_HEIGHT)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus"]:
			add_theme_stylebox_override(state, StyleBoxEmpty.new())
		var margin: MarginContainer = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override(&"margin_left", 6)
		margin.add_theme_constant_override(&"margin_right", 10)
		margin.add_theme_constant_override(&"margin_top", 5)
		margin.add_theme_constant_override(&"margin_bottom", 7)
		add_child(margin)
		var line: HBoxContainer = HBoxContainer.new()
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		line.add_theme_constant_override(&"separation", 8)
		margin.add_child(line)
		var claimed: bool = entry["claimed"]
		if claimed:
			line.modulate = Color(1.0, 1.0, 1.0, 0.62)
		var cover: InboxCover = InboxCover.new()
		cover.kind = entry["kind"]
		cover.texture = image
		cover.faded = claimed and entry["kind"] == Inbox.GIFT
		cover.corner = 6
		cover.custom_minimum_size = Vector2(42.0, 42.0)
		cover.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(cover)
		var middle: VBoxContainer = VBoxContainer.new()
		middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.alignment = BoxContainer.ALIGNMENT_CENTER
		middle.add_theme_constant_override(&"separation", 1)
		line.add_child(middle)
		var meta: HBoxContainer = HBoxContainer.new()
		meta.mouse_filter = Control.MOUSE_FILTER_IGNORE
		meta.add_theme_constant_override(&"separation", 6)
		middle.add_child(meta)
		var spec: Array = InboxScreen.PILLS.get(entry["kind"], InboxScreen.PILLS[&"notice"])
		var pill: PanelContainer = InboxScreen._pill(spec[1], spec[2], 9)
		(pill.get_child(0) as Label).text = Loc.t(spec[0])
		meta.add_child(pill)
		var info: Array[String] = []
		if entry["pinned"] and entry["kind"] != Inbox.GUEST:
			info.append(Loc.t("SABİT"))
		if int(entry["at"]) > 0:
			info.append(InboxScreen.age_text(int(entry["at"]), now))
		var age: Label = InboxScreen._label(&"HudInkCaption", "  ·  ".join(info))
		age.add_theme_font_size_override(&"font_size", 10)
		age.modulate.a = 0.75
		meta.add_child(age)
		var title: Label = InboxScreen._label(&"HudInkValue", entry["title"] if not String(entry["title"]).is_empty() else entry["text"])
		title.add_theme_font_size_override(&"font_size", 14)
		title.clip_text = true
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		middle.add_child(title)
		var status: String = InboxScreen.status_text(entry, now)
		var gift_waiting: bool = entry["kind"] == Inbox.GIFT and not claimed
		if not status.is_empty() and gift_waiting:   # SON N GÜN: kırmızı etiket
			var alert: PanelContainer = InboxScreen._pill(InboxScreen.ALERT, Color.WHITE, 10)
			(alert.get_child(0) as Label).text = status
			alert.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(alert)
		elif not status.is_empty():   # ALINDI / kalan süre
			var tag: Label = InboxScreen._label(&"HudInkCaption", status)
			tag.add_theme_font_size_override(&"font_size", 10)
			tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			tag.add_theme_color_override(&"font_color", HudPalette.COIN_DARK if not claimed else HudPalette.INK_SOFT)
			line.add_child(tag)
		elif gift_waiting or fresh:
			var dot: _Dot = _Dot.new()
			dot.custom_minimum_size = Vector2(14.0, 14.0)
			dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			line.add_child(dot)

	func _draw() -> void:
		var plate: StyleBoxFlat = StyleBoxFlat.new()
		plate.bg_color = HudPalette.PLATE
		plate.set_corner_radius_all(8)
		plate.border_width_bottom = 3
		plate.border_color = HudPalette.PLATE_EDGE
		if _selected:
			plate.set_border_width_all(3)
			plate.border_width_bottom = 4
			plate.border_color = HudPalette.PLATE_SELECTED
		draw_style_box(plate, Rect2(Vector2.ZERO, size))


## Okunmamış noktası: beyaz kenarlı kırmızı daire.
class _Dot:
	extends Control

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(size * 0.5, r, Color.WHITE, true, -1.0, true)
		draw_circle(size * 0.5, r - 2.0, Color("E2474F"), true, -1.0, true)
