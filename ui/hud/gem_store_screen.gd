class_name GemStoreScreen
extends Control
## MARKET (eski adıyla GEM MAĞAZASI) — üç sekme: GEM AL (gerçek parayla gem paketleri), PARAYA ÇEVİR
## (gem → ₺, tek yön; GemExchange) ve KOD GİR (kupon kodu, PromoService; kullanıcı kararı 2026-10-21). Sol üstteki gem sayacına / MARKET düğmesine dokununca ya da "GEM YETERSİZ"
## plakalarından açılır (MODAL, UiRouter id &"gem_store"). Her açılışta GEM AL sekmesiyle başlar. Kodla
## kurulur (.tscn yok).
##
## YERLEŞİM (kullanıcı kararı 2026-10-20): pano ekran ne olursa olsun AYNI ORANDA ve TAM ORTADA — tek parça olarak
## FILL oranına sığacak kadar ölçeklenir (kaydırma yok, HUD payı yok). Kart sırası hep 5 kartlık genişlikte:
## sekme değişince pano boyu oynamaz. Bilgi satırı yok; gereken uyarılar (ulaşılamıyor, iptal, gem yetersiz)
## yerleşimi oynatmayan, kendiliğinden sönen bir bildirimdir.
##
## HİÇBİR MANTIK BURADA DEĞİL: ürünler GemProducts'ta, fiyat / satın alma / defter PurchaseManager'da, kur ve
## çeviri GemExchange'de. Fiyatlar Play'den oyuncunun para biriminde gelir; burada sayı yazılmaz. PARAYA ÇEVİR
## Play'e bağlı değildir: mağazaya ulaşılamasa da çalışır.

signal closed

const PLATE_WIDTH: float = 470.0
## Kart: çizim + miktar + ad + fiyat. Sıra en çok 5 kart (GEM AL, başlangıç paketi alınmadıysa).
const CARD_WIDTH: float = 178.0
const ART_SIZE: Vector2 = Vector2(166.0, 132.0)
const CARD_GAP: float = 8.0
const MAX_CARDS: int = 5
## Panonun kaplayacağı ekran oranı (genişlik, yükseklik): hangisi önce dolarsa ölçek odur.
const FILL: Vector2 = Vector2(0.86, 0.80)
const TAB_GEMS: StringName = &"gems"
const TAB_CASH: StringName = &"cash"
const TAB_CODE: StringName = &"code"
## Kupon kodu kabul edildi metninin rengi (taslaktaki yeşil; HUD paletinde yeşil yok).
const OK_COLOR: Color = Color("2E7D4F")
## Çeviri iki dokunuşla onaylanır (geri alınamaz); ilk dokunuştan sonra bu süre içinde ikinci dokunuş gerekir.
const CONFIRM_TIME: float = 3.0
## Bildirimin ekranda kalma süresi (sn).
const NOTICE_TIME: float = 2.6

## Satın alınan gem pencereden sayaca uçsun (Hud verir).
var hud: Hud

var _purchases: PurchaseManager
var _list: HBoxContainer
## Ölçeklenen sahne: ekranı kaplar, ortasından ölçeklenir; içindeki CenterContainer sütunu ortalar. Ölçek bir
## KAP çocuğuna verilemez (Container her yerleştirmede çocuğun ölçeğini 1'e sıfırlar); açılış animasyonu da
## sütunun kendi ölçeğiyle oynar, ikisi çakışmaz.
var _stage: Control
var _column: VBoxContainer
var _reward_popup: RewardPopup
var _notice: PlatePanel
var _notice_label: Label
var _notice_tween: Tween
var _closing: bool = false
var _tab: StringName = TAB_GEMS
var _tab_buttons: Dictionary = {}   # sekme → PlateButton
## Kart sırasının en yüksek boyu: KOD GİR panosu da bu boyda durur (sekme değişince pano boyu oynamaz).
var _list_min_h: float = 0.0
## Onay bekleyen çeviri teklifinin sırası (-1: yok) ve onayın verildiği an (msn).
var _confirm_offer: int = -1
var _confirm_at: int = 0


func _ready() -> void:
	name = "GemStoreScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_bind.call_deferred()
	resized.connect(_fit, CONNECT_DEFERRED)
	visibility_changed.connect(_fit, CONNECT_DEFERRED)


func open() -> void:
	_confirm_offer = -1
	_notice.hide()
	_select_tab(TAB_GEMS)
	_fit()
	PlateAnim.pop_in(self, _column)
	if _purchases and _purchases.is_available() and _purchases.pending_payment:
		_show_notice(Loc.t("ÖDEMESİ BEKLENEN BİR SATIN ALMAN VAR\nÖDEME TAMAMLANINCA GEMLER GELİR"))
	elif _purchases and _purchases.awaiting_verification:
		_show_notice(Loc.t("ÖDEMEN HENÜZ DOĞRULANAMADI\nİNTERNETE BAĞLANINCA GEMLER GELİR"), 3.6)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	if _reward_popup.visible:
		_reward_popup.close()
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


func _bind() -> void:
	_purchases = get_tree().get_first_node_in_group("purchases") as PurchaseManager
	_reward_popup.hud = hud
	if _purchases == null:
		return
	_purchases.products_changed.connect(func() -> void:
		if visible and _tab == TAB_GEMS:
			_refresh())
	_purchases.purchase_finished.connect(_on_purchase_finished)
	_purchases.gems_purchased.connect(_on_gems_purchased)


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_stage = Control.new()
	_stage.name = "Stage"
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_stage)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.add_child(center)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	column.minimum_size_changed.connect(_fit, CONNECT_DEFERRED)   # kartlar yerleşince boy değişir
	center.add_child(column)
	_column = column

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("MARKET"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	# Sekmeler: GEM AL · PARAYA ÇEVİR (seçili olan amber)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override(&"separation", 8)
	column.add_child(tabs)
	for entry: Array in [[TAB_GEMS, Loc.t("GEM AL")], [TAB_CASH, Loc.t("PARAYA ÇEVİR")], [TAB_CODE, Loc.t("KOD GİR")]]:
		var tab: PlateButton = PlateButton.new()
		tab.theme_type_variation = &"HudPlateSmall"
		tab.text = entry[1]
		tab.kind = HudIcon.Kind.NONE
		tab.focus_mode = Control.FOCUS_NONE
		tab.custom_minimum_size = Vector2((PLATE_WIDTH - 8.0) * 0.5, 0.0)
		tab.pressed.connect(_on_tab_pressed.bind(entry[0]))
		tabs.add_child(tab)
		_tab_buttons[entry[0]] = tab

	_list = HBoxContainer.new()
	_list.name = "Cards"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override(&"separation", int(CARD_GAP))
	column.add_child(_list)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)

	# Bildirim: panonun üstünde, ekranın üst ortasında; yerleşimi oynatmaz, dokunuşu geçirir
	var notice_box: MarginContainer = MarginContainer.new()
	notice_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	notice_box.add_theme_constant_override(&"margin_top", 14)
	add_child(notice_box)
	_notice = PlatePanel.new()
	_notice.theme_type_variation = &"HudCarPlate"
	_notice.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_notice.visible = false
	notice_box.add_child(_notice)
	_notice_label = _label(&"HudInkCaption", "")
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.add_child(_notice_label)

	_reward_popup = RewardPopup.new()   # son çocuk: mağazanın üstünde açılır
	add_child(_reward_popup)


## Pano FILL oranına sığacak kadar büyür / küçülür (oran korunur) ve ekranın tam ortasında durur: sahne ekranın
## ortasından ölçeklenir, sütun sahnenin ortasındadır.
func _fit() -> void:
	if _stage == null or size.x <= 0.0 or size.y <= 0.0:
		return
	var content: Vector2 = _column.get_combined_minimum_size()
	if content.x <= 0.0 or content.y <= 0.0:
		return
	var k: float = minf(size.x * FILL.x / content.x, size.y * FILL.y / content.y)
	_stage.pivot_offset = size * 0.5
	_stage.scale = Vector2.ONE * k


func _on_tab_pressed(tab: StringName) -> void:
	_select_tab(tab)


func _select_tab(tab: StringName) -> void:
	_tab = tab
	_confirm_offer = -1
	for key: StringName in _tab_buttons:
		(_tab_buttons[key] as PlateButton).highlight = key == tab
	_refresh()
	if tab == TAB_GEMS and (_purchases == null or not _purchases.is_available()):
		_show_notice(Loc.t("MAĞAZAYA ŞU AN ULAŞILAMIYOR\nİNTERNET BAĞLANTINI VE GOOGLE PLAY'İ KONTROL ET"), 3.6)


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _tab == TAB_CODE:
		_list.add_child(_code_panel())
		return
	if _tab == TAB_CASH:
		var player: PlayerProgress = _player()
		for i: int in GemExchange.OFFERS.size():
			_list.add_child(_cash_card(i, player.level if player else 1))
	else:
		for entry: Dictionary in GemProducts.PRODUCTS:
			if bool(entry["once"]) and _purchases and _purchases.was_bought(entry["id"]):
				continue   # tek seferlik paket alındı: listeden çıkar
			_list.add_child(_card(entry))
	# Sıra hep 5 kartlık genişlikte: sekme / alınan başlangıç paketi pano boyunu oynatmaz
	var card_w: float = (_list.get_child(0) as Control).get_combined_minimum_size().x if _list.get_child_count() > 0 \
		else CARD_WIDTH
	_list.custom_minimum_size.x = card_w * MAX_CARDS + CARD_GAP * (MAX_CARDS - 1)
	_list_min_h = maxf(_list_min_h, _list.get_combined_minimum_size().y)


## KOD GİR: kupon kodu kutusu + KULLAN. Misafirde kutu kilitli ve neden yazılı (kod hesaba bir kez geçer).
func _code_panel() -> PlatePanel:
	var panel: PlatePanel = PlatePanel.new()
	panel.name = "CodePanel"
	panel.theme_type_variation = &"HudCarPlate"
	panel.custom_minimum_size = Vector2(600.0, _list_min_h if _list_min_h > 0.0 else 300.0)
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	box.add_child(_label(&"HudPlateTitle", Loc.t("Kupon kodun mu var?")))
	var caption: Label = _label(&"HudInkCaption",
		Loc.t("Instagram ve YouTube'da paylaştığımız kodu yaz. Her kod hesabına bir kez geçer, ödül postana düşer."))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(560.0, 0.0)
	box.add_child(caption)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	var edit: LineEdit = LineEdit.new()
	edit.name = "CodeEdit"
	edit.placeholder_text = Loc.t("KOD")
	edit.max_length = 16
	edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit.custom_minimum_size = Vector2(0.0, 56.0)
	edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	edit.add_theme_color_override(&"font_color", HudPalette.INK)
	edit.add_theme_color_override(&"font_placeholder_color", HudPalette.INK_SOFT)
	edit.add_theme_color_override(&"caret_color", HudPalette.INK)
	edit.add_theme_font_size_override(&"font_size", 26)
	for style_name: StringName in [&"normal", &"focus", &"read_only"]:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = HudPalette.PLATE_HOVER
		style.border_color = HudPalette.PLATE_SELECTED_EDGE if style_name == &"focus" else HudPalette.INK
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12.0
		style.content_margin_right = 12.0
		edit.add_theme_stylebox_override(style_name, style)
	row.add_child(edit)
	var use: PlateButton = PlateButton.new()
	use.name = "UseButton"
	use.theme_type_variation = &"HudPlate"
	use.text = Loc.t("KULLAN")
	use.highlight = true
	use.focus_mode = Control.FOCUS_NONE
	use.custom_minimum_size = Vector2(160.0, 56.0)
	row.add_child(use)
	var result: Label = _label(&"HudInkCaption", "")
	result.name = "CodeResult"
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size = Vector2(560.0, 0.0)
	box.add_child(result)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty():
		edit.editable = false
		use.disabled = true
		result.text = PromoService.status_text("signin")
	edit.text_changed.connect(func(text: String) -> void:
		var code: String = PromoService.normalize(text)
		if code != text:
			edit.text = code
			edit.caret_column = code.length())
	var submit: Callable = func() -> void:
		if use.disabled:
			return
		use.disabled = true
		edit.editable = false
		result.remove_theme_color_override(&"font_color")
		result.text = Loc.t("Kod kontrol ediliyor…")
		var outcome: Dictionary = await PromoService.redeem(get_tree(), edit.text)
		if not is_instance_valid(result):
			return   # sekme değişti / pano kapandı
		var status: String = SaveSafe.s(outcome.get("status", ""))
		result.text = PromoService.status_text(status)
		result.add_theme_color_override(&"font_color", OK_COLOR if status == "ok" else HudPalette.DANGER)
		use.disabled = false
		edit.editable = true
		if status == "ok":
			edit.text = ""
	use.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	return panel


## Paket kartı: hareketli çizim (rozetli), miktar, ad, fiyat plakası. Başlangıç paketi amber kart.
func _card(entry: Dictionary) -> PlatePanel:
	var id: StringName = entry["id"]
	var card: PlatePanel = PlatePanel.new()
	card.theme_type_variation = &"HudCarPlate"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	if bool(entry["once"]):
		var base: StyleBoxFlat = get_theme_stylebox(&"panel", &"HudCarPlate") as StyleBoxFlat
		if base:
			var amber: StyleBoxFlat = base.duplicate() as StyleBoxFlat
			amber.bg_color = HudPalette.PLATE_SELECTED
			amber.border_color = HudPalette.PLATE_SELECTED_EDGE
			card.add_theme_stylebox_override(&"panel", amber)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	card.add_child(box)

	var art: GemPackArt = GemPackArt.new()
	art.kind = entry["art"]
	art.custom_minimum_size = ART_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if int(entry["bonus"]) > 0:
		art.badge_text = "+" + Loc.percent(str(int(entry["bonus"])))
	box.add_child(art)

	var amount: Label = _label(&"HudInkValue", Loc.t("%d GEM") % int(entry["gems"]))
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override(&"font_size", 24)
	amount.add_theme_color_override(&"font_color", HudPalette.GEM_DARK if not bool(entry["once"]) else HudPalette.INK)
	box.add_child(amount)

	var note: String = Loc.t(String(entry["name"]))
	if bool(entry["once"]):
		note = Loc.t("TEK SEFERLİK TEKLİF")
	elif bool(entry.get("best", false)):
		note = Loc.t("EN İYİ DEĞER")
	var caption: Label = _label(&"HudInkCaption", note)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)

	# Mağazaya ulaşılamıyorsa kartlar yine durur (pano boyu oynamasın), fiyat "—" ve basılamaz
	var reason: String = _purchases.block_reason(id) if _purchases else "unavailable"
	var price_text: String = _purchases.price_text(id) if _purchases else ""
	var price: PlateButton = PlateButton.new()
	price.theme_type_variation = &"HudPlateSmall"
	price.focus_mode = Control.FOCUS_NONE
	price.kind = HudIcon.Kind.NONE
	price.text = "…" if reason == "busy" else (price_text if not price_text.is_empty() else "—")
	price.disabled = not reason.is_empty()
	price.pressed.connect(func() -> void: _purchases.buy(id))
	box.add_child(price)
	return card


# --- PARAYA ÇEVİR ------------------------------------------------------------------------------

func _player() -> PlayerProgress:
	return get_tree().get_first_node_in_group("player_progress") as PlayerProgress


## Çeviri kartı: para çizimi (bonus rozetli), kazanılacak ₺, gem başına ₺, gem düğmesi. Onay beklerken düğme ONAYLA.
func _cash_card(index: int, level: int) -> PlatePanel:
	var offer: Dictionary = GemExchange.OFFERS[index]
	var card: PlatePanel = PlatePanel.new()
	card.theme_type_variation = &"HudCarPlate"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	card.add_child(box)

	var art: GemPackArt = GemPackArt.new()
	art.kind = offer["art"]
	art.custom_minimum_size = ART_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if int(offer["bonus"]) > 0:
		art.badge_text = "+" + Loc.percent(str(int(offer["bonus"])))
	box.add_child(art)

	var amount: Label = _label(&"HudInkValue", "+%s ₺" % Hud.format_thousands(GemExchange.money_for(offer, level)))
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override(&"font_size", 22)
	amount.add_theme_color_override(&"font_color", HudPalette.COIN_DARK)
	box.add_child(amount)

	# gem başına düşen ₺: bonusun etkisi görünsün
	var per_gem: int = int(round(float(GemExchange.money_for(offer, level)) / float(int(offer["gems"]))))
	var caption: Label = _label(&"HudInkCaption", Loc.t("%s ₺ / GEM") % Hud.format_thousands(per_gem))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)

	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.focus_mode = Control.FOCUS_NONE
	button.kind = HudIcon.Kind.NONE
	var confirming: bool = index == _confirm_offer
	button.text = Loc.t("ONAYLA") if confirming else Loc.t("%d GEM") % int(offer["gems"])
	button.highlight = confirming
	button.pressed.connect(_on_cash_pressed.bind(index))
	box.add_child(button)
	return card


## İlk dokunuş onay ister (düğme ONAYLA olur), CONFIRM_TIME içindeki ikinci dokunuş çevirir. Gem yetmiyorsa
## bildirim + GEM AL sekmesi.
func _on_cash_pressed(index: int) -> void:
	var offer: Dictionary = GemExchange.OFFERS[index]
	var player: PlayerProgress = _player()
	if player == null:
		return
	var gems: int = int(offer["gems"])
	if player.gems < gems:
		_select_tab(TAB_GEMS)
		_show_notice(Loc.t("GEM YETERSİZ · %d GEM GEREKİYOR") % gems)
		return
	var now: int = Time.get_ticks_msec()
	if _confirm_offer != index or now - _confirm_at > int(CONFIRM_TIME * 1000.0):
		_confirm_offer = index
		_confirm_at = now
		_refresh()
		get_tree().create_timer(CONFIRM_TIME).timeout.connect(func() -> void:
			if _confirm_offer == index and _confirm_at == now and visible and _tab == TAB_CASH:
				_confirm_offer = -1
				_refresh())
		return
	_confirm_offer = -1
	var money: int = GemExchange.exchange(get_tree(), offer)
	_refresh()
	if money > 0:
		_reward_popup.show_rewards({"money": money, "title": Loc.t("PARAYA ÇEVRİLDİ!")})


## Kendiliğinden sönen bildirim (yerleşimi oynatmaz).
func _show_notice(text: String, hold: float = NOTICE_TIME) -> void:
	_notice_label.text = text
	_notice.modulate.a = 1.0
	_notice.show()
	if _notice_tween and _notice_tween.is_valid():
		_notice_tween.kill()
	_notice_tween = create_tween()
	_notice_tween.tween_interval(hold)
	_notice_tween.tween_property(_notice, "modulate:a", 0.0, 0.35)
	_notice_tween.tween_callback(_notice.hide)


func _on_purchase_finished(_id: StringName, status: StringName) -> void:
	if visible and _tab == TAB_GEMS:
		_refresh()
	if not visible:
		return
	match status:
		&"canceled":
			_show_notice(Loc.t("SATIN ALMA İPTAL EDİLDİ"))
		&"error":
			_show_notice(Loc.t("SATIN ALMA TAMAMLANAMADI, TEKRAR DENE"))
		&"pending":
			_show_notice(Loc.t("ÖDEME BEKLENİYOR\nÖDEME TAMAMLANINCA GEMLER GELİR"), 3.6)
		&"verifying":
			_show_notice(Loc.t("ÖDEMEN HENÜZ DOĞRULANAMADI\nİNTERNETE BAĞLANINCA GEMLER GELİR"), 3.6)
		&"rejected":
			_show_notice(Loc.t("GOOGLE PLAY BU ÖDEMEYİ ONAYLAMADI\nGEM VERİLMEDİ"), 3.6)


func _on_gems_purchased(_id: StringName, gems: int) -> void:
	if visible:
		_reward_popup.show_rewards({"gems": gems, "title": Loc.t("SATIN ALMA TAMAMLANDI!")})


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
