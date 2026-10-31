class_name GemStoreScreen
extends Control
## MARKET (eski adıyla GEM MAĞAZASI) — dört sekme: GEM AL (gerçek parayla gem paketleri), ÜCRETSİZ (Instagram / TikTok
## takibine bir kerelik gem; CommunityLinks, 2026-10-24), PARAYA ÇEVİR (gem → ₺, tek yön; GemExchange) ve KOD GİR
## (kupon kodu, PromoService; kullanıcı kararı 2026-10-21). Sol üstteki gem sayacına / MARKET düğmesine dokununca ya da "GEM YETERSİZ"
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
const MAX_CARDS: int = 6   # GEM AL: ÜCRETSİZ ELMAS + 5 paket
## Panonun kaplayacağı ekran oranı (genişlik, yükseklik): hangisi önce dolarsa ölçek odur.
const FILL: Vector2 = Vector2(0.86, 0.80)
const TAB_GEMS: StringName = &"gems"
const TAB_FREE: StringName = &"free"
const TAB_CASH: StringName = &"cash"
const TAB_CODE: StringName = &"code"
## Kupon kodu kabul edildi plakasının rengi (taslaktaki yeşil; HUD paletinde yeşil yok).
const OK_COLOR: Color = Color("2E7D4F")
## KOD GİR yazı boyları (2026-10-31, kullanıcı: "hata da başarılı olsa da çok küçük gözüküyor"): sonuç eskiden en küçük
## altyazı boyuyla (HudInkCaption 10) basılıyordu, pano telefonda ~0,8 ölçekle daha da küçülüyordu.
const CODE_TITLE_SIZE: int = 20
const CODE_CAPTION_SIZE: int = 13
const CODE_INPUT_SIZE: int = 30
const CODE_RESULT_SIZE: int = 22
const CODE_RESULT_DETAIL_SIZE: int = 15
## Kabul edilen kodun postası (p_<kod>) en çok bu kadar beklenir (deneme × aralık, sn); gelmezse HABERLER'de bekler.
const GIFT_WAIT_TRIES: int = 10
const GIFT_WAIT_SEC: float = 0.75
## Ekran klavyesiyle kod kutusunun alt kenarı arasında kalan pay (tuval birimi).
const KEYBOARD_GAP: float = 14.0
## Çeviri iki dokunuşla onaylanır (geri alınamaz); ilk dokunuştan sonra bu süre içinde ikinci dokunuş gerekir.
const CONFIRM_TIME: float = 3.0
## Bildirimin ekranda kalma süresi (sn).
const NOTICE_TIME: float = 2.6

## Satın alınan gem pencereden sayaca uçsun (Hud verir).
var hud: Hud

var _purchases: PurchaseManager
var _community: CommunityLinks
var _list: HBoxContainer
## Ölçeklenen sahne: ekranı kaplar, ortasından ölçeklenir; içindeki CenterContainer sütunu ortalar. Ölçek bir
## KAP çocuğuna verilemez (Container her yerleştirmede çocuğun ölçeğini 1'e sıfırlar); açılış animasyonu da
## sütunun kendi ölçeğiyle oynar, ikisi çakışmaz.
var _stage: Control
var _center: CenterContainer
var _column: VBoxContainer
var _reward_popup: RewardPopup
var _notice: PlatePanel
var _notice_label: Label
var _notice_tween: Tween
var _guest_strip: PlatePanel
var _closing: bool = false
var _tab: StringName = TAB_GEMS
var _tab_buttons: Dictionary = {}   # sekme → PlateButton
## Kart sırasının en yüksek boyu: KOD GİR panosu da bu boyda durur (sekme değişince pano boyu oynamaz).
var _list_min_h: float = 0.0
## Onay bekleyen çeviri teklifinin sırası (-1: yok) ve onayın verildiği an (msn).
var _confirm_offer: int = -1
var _confirm_at: int = 0
## KOD GİR sekmesinin kutusu (başka sekmede serbest) ve klavye yüzünden panonun yukarı kaydığı miktar (tuval birimi).
var _code_edit: LineEdit
var _keyboard_shift: float = 0.0
## QA / test: ekran klavyesinin tuval birimindeki yüksekliği (≥ 0 ise gerçek klavye yerine kullanılır; oyunda -1).
static var simulate_keyboard: float = -1.0


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
	var reminder: SaveReminder = get_tree().get_first_node_in_group("save_reminder") as SaveReminder
	_guest_strip.visible = reminder != null and reminder.is_guest()
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
	_community = get_tree().get_first_node_in_group("community") as CommunityLinks
	_reward_popup.hud = hud
	if _community:
		_community.changed.connect(func() -> void:
			if visible and _tab == TAB_FREE:
				_refresh()
			else:
				_update_free_badge())
	_update_free_badge()
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
	_center = center

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

	# Sekmeler: GEM AL · ÜCRETSİZ · PARAYA ÇEVİR · KOD GİR (seçili olan amber)
	var tabs: HBoxContainer = HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override(&"separation", 8)
	column.add_child(tabs)
	for entry: Array in [[TAB_GEMS, Loc.t("GEM AL")], [TAB_FREE, Loc.t("ÜCRETSİZ")], [TAB_CASH, Loc.t("PARAYA ÇEVİR")],
			[TAB_CODE, Loc.t("KOD GİR")]]:
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

	# HESABA KAYDET (2026-10-28, kullanıcı kararı: taslak C): misafirken uyarı şeridi. Her sekmede aynı (pano boyu
	# sekmeyle oynamaz); HESABA KAYDET hesap panosunu açar (MARKET kapanır).
	_guest_strip = PlatePanel.new()
	_guest_strip.name = "GuestStrip"
	_guest_strip.theme_type_variation = &"HudCarPlate"
	_guest_strip.custom_minimum_size = Vector2(PLATE_WIDTH * 1.6, 0.0)
	_guest_strip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_guest_strip.visible = false
	var strip_row: HBoxContainer = HBoxContainer.new()
	strip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_row.add_theme_constant_override(&"separation", 12)
	_guest_strip.add_child(strip_row)
	var strip_text: VBoxContainer = VBoxContainer.new()
	strip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip_text.alignment = BoxContainer.ALIGNMENT_CENTER
	strip_text.add_theme_constant_override(&"separation", 0)
	strip_text.add_child(_label(&"HudPlateTitle", Loc.t("MİSAFİR OLARAK OYNUYORSUN")))
	var strip_caption: Label = _label(&"HudInkCaption",
		Loc.t("Aldığın gemler yalnızca bu telefonda kalır. Telefon değişirse kaybolur."))
	strip_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	strip_caption.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)   # sarılan etiket kapta sıfır genişliğe düşmesin
	strip_text.add_child(strip_caption)
	strip_row.add_child(strip_text)
	var save_button: PlateButton = PlateButton.new()
	save_button.name = "SaveAccountButton"
	save_button.theme_type_variation = &"HudPlateSmall"
	save_button.text = Loc.t("HESABA KAYDET")
	save_button.kind = HudIcon.Kind.HELMET
	save_button.icon_left = true
	save_button.highlight = true
	save_button.focus_mode = Control.FOCUS_NONE
	save_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	save_button.pressed.connect(_on_save_account)
	strip_row.add_child(save_button)
	column.add_child(_guest_strip)

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
	# İçerik ekrandan genişse (6 kart, dar tuval) ortalayıcı kap taşan kısmı yalnız sağa büyütüyordu: pano kayıyordu.
	# Taşma iki yana eşit verilir, ölçek sahneyi ekranın ortasından küçültür.
	var over: Vector2 = (content - size).max(Vector2.ZERO) * 0.5
	_center.offset_left = -over.x
	_center.offset_right = over.x
	_center.offset_top = -over.y
	_center.offset_bottom = over.y
	_stage.pivot_offset = size * 0.5
	_stage.scale = Vector2.ONE * k


func _process(_delta: float) -> void:
	if visible:
		_fit_keyboard()


## EKRAN KLAVYESİ (kullanıcı 2026-10-31: "klavye kodu girdiğimiz yerin üzerine basıyor, ne yazdığımı bilemiyorum"): KOD GİR
## kutusu odaktayken klavye açıksa pano, kutunun alt kenarı klavyenin KEYBOARD_GAP üstünde kalacak kadar yukarı kayar;
## klavye kapanınca (KULLAN, geri tuşu, odak gitti) yerine döner. Klavye yüksekliği pencere pikselinden tuval birimine
## çevrilir (EmailCodePanel ile aynı). Pano ortadan ölçeklendiği için kutunun yeri ölçekli dönüşümle okunur (Hud.screen_rect).
func _fit_keyboard() -> void:
	var keyboard: float = 0.0
	var typing: bool = is_instance_valid(_code_edit) and _code_edit.is_visible_in_tree() and _code_edit.has_focus()
	if typing and simulate_keyboard >= 0.0:
		keyboard = simulate_keyboard
	elif typing and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		var window_height: float = maxf(1.0, float(DisplayServer.window_get_size().y))
		keyboard = DisplayServer.virtual_keyboard_get_height() * get_viewport_rect().size.y / window_height
	var shift: float = 0.0
	if keyboard > 0.0:
		var bottom: float = Hud.screen_rect(_code_edit).end.y + _keyboard_shift   # kaymasız yer
		shift = maxf(0.0, bottom + KEYBOARD_GAP - (get_viewport_rect().size.y - keyboard))
	if not is_equal_approx(shift, _keyboard_shift):
		_keyboard_shift = shift
		_stage.position.y = -shift


func _on_save_account() -> void:
	Telemetry.event(&"save_strip_tap")
	if hud:
		hud.router.open(&"account")   # MODAL: MARKET kapanır, hesap panosu açılır


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
	_update_free_badge()
	if _tab == TAB_CODE:
		_list.add_child(_code_panel())
		return
	if _tab == TAB_FREE:
		for link: Dictionary in CommunityLinks.LINKS:
			_list.add_child(_follow_card(link))
	elif _tab == TAB_CASH:
		var player: PlayerProgress = _player()
		for i: int in GemExchange.OFFERS.size():
			_list.add_child(_cash_card(i, player.level if player else 1))
	else:
		_list.add_child(_free_card())   # ödüllü reklamla elmas (mağazaya ulaşılamasa da çalışır)
		for entry: Dictionary in GemProducts.PRODUCTS:
			if bool(entry["once"]) and _purchases and _purchases.was_bought(entry["id"]):
				continue   # tek seferlik paket alındı: listeden çıkar
			_list.add_child(_card(entry))
	# Sıra hep 5 kartlık genişlikte: sekme / alınan başlangıç paketi pano boyunu oynatmaz
	var card_w: float = (_list.get_child(0) as Control).get_combined_minimum_size().x if _list.get_child_count() > 0 \
		else CARD_WIDTH
	_list.custom_minimum_size.x = card_w * MAX_CARDS + CARD_GAP * (MAX_CARDS - 1)
	_list_min_h = maxf(_list_min_h, _list.get_combined_minimum_size().y)


## KOD GİR: kupon kodu kutusu + KULLAN + sonuç plakası. Misafirde kutu kilitli ve neden yazılı (kod hesaba bir kez geçer).
## 2026-10-31 (kullanıcı: "hata da başarılı olsa da çok küçük gözüküyor, hediyeyi aldım mı almadım mı anlayamıyorum; klavye
## kodu girdiğimiz yerin üzerine bastığı için ne yazdığımı bilemiyorum"): sonuç büyük renkli plakada (yeşil ✔ / kırmızı ✖),
## kabul edilen kodun hediyesi HEDİYEN GELDİ! ekranıyla hemen açılır (_open_coupon_gift), KULLAN klavyeyi kapatır, yazarken
## klavye açıksa pano kutu görünecek kadar yukarı kayar (_fit_keyboard).
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
	var title: Label = _label(&"HudPlateTitle", Loc.t("Kupon kodun mu var?"))
	title.add_theme_font_size_override(&"font_size", CODE_TITLE_SIZE)
	box.add_child(title)
	var caption: Label = _label(&"HudInkCaption",
		Loc.t("Instagram ve YouTube'da paylaştığımız kodu yaz. Her kod hesabına bir kez geçer, hediyen hemen açılır."))
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.custom_minimum_size = Vector2(560.0, 0.0)
	caption.add_theme_font_size_override(&"font_size", CODE_CAPTION_SIZE)
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
	edit.add_theme_font_size_override(&"font_size", CODE_INPUT_SIZE)
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
	_code_edit = edit
	var use: PlateButton = PlateButton.new()
	use.name = "UseButton"
	use.theme_type_variation = &"HudPlate"
	use.text = Loc.t("KULLAN")
	use.highlight = true
	use.focus_mode = Control.FOCUS_NONE
	use.custom_minimum_size = Vector2(160.0, 56.0)
	row.add_child(use)
	var result: PanelContainer = _result_plate()
	box.add_child(result)
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty():
		edit.editable = false
		use.disabled = true
		_show_result(result, &"info", PromoService.status_text("signin"))
	edit.text_changed.connect(func(text: String) -> void:
		var code: String = PromoService.normalize(text)
		if code != text:
			edit.text = code
			edit.caret_column = code.length())
	var submit: Callable = func() -> void:
		if use.disabled:
			return
		var code: String = PromoService.normalize(edit.text)
		var gift_id: String = "p_" + code.to_lower()   # sunucunun hediye postası (functions/promo.js)
		use.disabled = true
		edit.editable = false
		edit.release_focus()   # klavye kapansın: sonuç plakası altında kalmasın
		_show_result(result, &"wait", Loc.t("Kod kontrol ediliyor…"))
		var inbox: Inbox = hud.inbox if hud else null
		if inbox:
			inbox.set_announced(gift_id, true)   # hediye burada açılır: HUD'da "HEDİYEN VAR" yazısı çıkmasın
		var outcome: Dictionary = await PromoService.redeem(get_tree(), code)
		var status: String = SaveSafe.s(outcome.get("status", ""))
		var opened: bool = false
		if is_instance_valid(result) and (status == "ok" or status == "already"):
			if status == "ok":
				edit.text = ""
				_show_result(result, &"ok", Loc.t("KOD KABUL EDİLDİ!"), Loc.t("Hediyen açılıyor…"))
			# Kod daha önce kabul edilmiş ama hediyesi alınmamış olabilir ("already"): bekleyen posta da açılır
			opened = await _open_coupon_gift(gift_id, status == "ok")
		if not opened and inbox and is_instance_valid(inbox):
			inbox.set_announced(gift_id, false)   # açılamadı: hediye HABERLER'de her zamanki gibi duyurulur
		if not is_instance_valid(result):
			return   # sekme değişti / pano kapandı
		if opened:
			_show_result(result, &"ok", Loc.t("KOD KABUL EDİLDİ!"), Loc.t("Hediyen hesabına geçti."))
		elif status == "ok":
			_show_result(result, &"ok", Loc.t("KOD KABUL EDİLDİ!"), PromoService.status_text(status))
		else:
			_show_result(result, &"error", PromoService.status_text(status))
		use.disabled = false
		edit.editable = true
	use.pressed.connect(submit)
	edit.text_submitted.connect(func(_t: String) -> void: submit.call())
	return panel


## Kabul edilen kuponun postası (p_<kod>) gelince hemen alınır: HEDİYEN GELDİ! ekranı MARKET'in üstünde açılır, HABERLER'e
## gitmek gerekmez. wait = false: yalnız şu an bekleyen posta denenir. Posta GIFT_WAIT_TRIES × GIFT_WAIT_SEC içinde
## gelmezse (ağ yavaş, bulut eşitlenmemiş) ya da pano kapanırsa false: hediye HABERLER'de bekler.
func _open_coupon_gift(gift_id: String, wait: bool) -> bool:
	var mail: MailService = get_tree().get_first_node_in_group("mail") as MailService
	if mail == null or hud == null or hud.mail_notice == null:
		return false
	var tries: int = GIFT_WAIT_TRIES if wait else 1
	for i: int in tries:
		if mail.pending().any(func(m: Dictionary) -> bool: return m["id"] == gift_id):
			return hud.mail_notice.claim_now(gift_id)
		if i == tries - 1:
			break
		mail.poll()   # PromoService bir kez okuttu; posta sunucuda biraz sonra yazılmış olabilir
		await get_tree().create_timer(GIFT_WAIT_SEC).timeout
		if not is_inside_tree() or not visible or not is_instance_valid(mail):
			return false
	return false


## Sonuç plakası: başta gizli; _show_result durumuna göre renk, simge ve yazı verir.
func _result_plate() -> PanelContainer:
	var plate: PanelContainer = PanelContainer.new()
	plate.name = "CodeResult"
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.custom_minimum_size = Vector2(560.0, 0.0)
	plate.visible = false
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 12)
	plate.add_child(row)
	var icon: Control = Control.new()
	icon.name = "Icon"
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = Vector2(34.0, 34.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.draw.connect(func() -> void:
		var kind: HudIcon.Kind = icon.get_meta(&"kind", HudIcon.Kind.NONE)
		if kind != HudIcon.Kind.NONE:
			HudIcon.draw_icon(icon, kind, icon.size * 0.5, icon.size.x, Color.WHITE,
				icon.get_meta(&"cutout", HudPalette.INK) as Color))
	row.add_child(icon)
	var texts: VBoxContainer = VBoxContainer.new()
	texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texts.alignment = BoxContainer.ALIGNMENT_CENTER
	texts.add_theme_constant_override(&"separation", 0)
	row.add_child(texts)
	var heading: Label = _label(&"HudPlateTitle", "")
	heading.name = "Heading"
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	heading.custom_minimum_size = Vector2(470.0, 0.0)   # sarılan etiket kapta sıfır genişliğe düşmesin
	heading.add_theme_font_size_override(&"font_size", CODE_RESULT_SIZE)
	texts.add_child(heading)
	var detail: Label = _label(&"HudPlateTitle", "")
	detail.name = "Detail"
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.custom_minimum_size = Vector2(470.0, 0.0)
	detail.add_theme_font_size_override(&"font_size", CODE_RESULT_DETAIL_SIZE)
	texts.add_child(detail)
	return plate


## state: &"ok" (yeşil, ✔), &"error" (kırmızı, ✖), &"wait" / &"info" (krem plaka, simgesiz). detail boşsa tek satır.
func _show_result(plate: PanelContainer, state: StringName, heading: String, detail: String = "") -> void:
	var fill: Color = OK_COLOR if state == &"ok" else HudPalette.DANGER if state == &"error" else HudPalette.PLATE_HOVER
	var ink: Color = Color.WHITE if state == &"ok" or state == &"error" else HudPalette.INK
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = fill.darkened(0.25) if state == &"ok" or state == &"error" else HudPalette.PLATE_EDGE
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12.0)
	plate.add_theme_stylebox_override(&"panel", style)
	var icon: Control = plate.find_child("Icon", true, false) as Control
	var kind: HudIcon.Kind = HudIcon.Kind.CHECK if state == &"ok" else HudIcon.Kind.CROSS if state == &"error" \
		else HudIcon.Kind.NONE
	icon.set_meta(&"kind", kind)
	icon.set_meta(&"cutout", fill)
	icon.visible = kind != HudIcon.Kind.NONE
	icon.queue_redraw()
	for label_name: String in ["Heading", "Detail"]:
		var label: Label = plate.find_child(label_name, true, false) as Label
		label.text = heading if label_name == "Heading" else detail
		label.visible = not label.text.is_empty()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if kind == HudIcon.Kind.NONE else HORIZONTAL_ALIGNMENT_LEFT
		label.add_theme_color_override(&"font_color", ink)
		label.add_theme_color_override(&"font_outline_color", fill.darkened(0.35) if ink == Color.WHITE else Color.TRANSPARENT)
	plate.visible = true
	if state == &"ok" or state == &"error":   # sonuç belirerek gelir (ölçek animasyonu olmaz: kap çocuğun ölçeğini sıfırlar)
		plate.modulate.a = 0.0
		create_tween().tween_property(plate, ^"modulate:a", 1.0, 0.2)


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


## ÜCRETSİZ ELMAS (2026-10-23): reklam izle → +AdPolicy.free_gems() elmas; günde 5, iki izleme arası 3 dk (panelden
## değişebilir). Düğme beklemede geri sayımı, hak bitince YARIN YENİLENİR yazar.
func _free_card() -> PlatePanel:
	var card: PlatePanel = PlatePanel.new()
	card.name = "FreeGemsCard"
	card.theme_type_variation = &"HudCarPlate"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	card.add_child(box)
	var art: GemPackArt = GemPackArt.new()
	art.kind = GemPackArt.Kind.FREE
	art.custom_minimum_size = ART_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var amount: Label = _label(&"HudInkValue", Loc.t("+%d GEM") % AdPolicy.free_gems())
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override(&"font_size", 24)
	amount.add_theme_color_override(&"font_color", HudPalette.GEM_DARK)
	box.add_child(amount)
	var ads: AdService = get_tree().get_first_node_in_group("ads") as AdService if is_inside_tree() else null
	var left: int = ads.remaining_today(AdPolicy.FREE_GEMS) if ads else 0
	var caption: Label = _label(&"HudInkCaption", Loc.t("ÜCRETSİZ · BUGÜN %d / %d") % [left, AdPolicy.daily_cap(AdPolicy.FREE_GEMS)])
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var button: AdOfferButton = AdOfferButton.new(AdPolicy.FREE_GEMS, "", true)
	button.clip_text = true   # uzun durum yazısı kartı (ve panoyu) genişletmesin
	button.ready_text = Loc.tc("REKLAM İZLE", "market")   # dar kart: DE / FR / ES kısa karşılık (TR aynı)
	button.loading_text = Loc.tc("YÜKLENİYOR", "market")   # kullanıcı (2026-10-28): markette yalnız "YÜKLENİYOR"
	button.rewarded.connect(_on_free_gems)
	button.finished.connect(func(_ok: bool) -> void:
		if visible and _tab == TAB_GEMS:
			_refresh())
	box.add_child(button)
	return card


## TAKİP KARTI (ÜCRETSİZ sekmesi): marka simgesi, +10 GEM, marka adı, durum düğmesi. TAKİP ET bağlantıyı açar; oyuncu
## dönünce düğme amber ÖDÜLÜ AL olur; alınınca soluk ALINDI.
func _follow_card(link: Dictionary) -> PlatePanel:
	var id: StringName = link["id"]
	var card: PlatePanel = PlatePanel.new()
	card.name = "Follow_" + String(id)
	card.theme_type_variation = &"HudCarPlate"
	card.custom_minimum_size = Vector2(CARD_WIDTH, 0.0)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	card.add_child(box)
	var art: GemPackArt = GemPackArt.new()
	art.kind = link["art"]
	art.custom_minimum_size = ART_SIZE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(art)
	var amount: Label = _label(&"HudInkValue", Loc.t("+%d GEM") % CommunityLinks.FOLLOW_GEMS)
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_theme_font_size_override(&"font_size", 24)
	amount.add_theme_color_override(&"font_color", HudPalette.GEM_DARK)
	box.add_child(amount)
	var caption: Label = _label(&"HudInkCaption", String(link["name"]))
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	var state: CommunityLinks.Follow = _community.follow_state(id) if _community else CommunityLinks.Follow.NONE
	var button: PlateButton = PlateButton.new()
	button.name = "FollowButton"
	button.theme_type_variation = &"HudPlateSmall"
	button.focus_mode = Control.FOCUS_NONE
	button.kind = HudIcon.Kind.NONE
	match state:
		CommunityLinks.Follow.OPENED:
			button.text = Loc.t("ÖDÜLÜ AL")
			button.highlight = true
			button.pressed.connect(_on_follow_claim.bind(id))
		CommunityLinks.Follow.CLAIMED:
			button.text = Loc.t("ALINDI")
			button.disabled = true
		_:
			button.text = Loc.t("TAKİP ET")
			button.disabled = _community == null
			button.pressed.connect(func() -> void: _community.open_link(id))
	box.add_child(button)
	return card


func _on_follow_claim(id: StringName) -> void:
	var gems: int = _community.claim(id) if _community else 0
	if gems > 0:
		_reward_popup.show_rewards({"gems": gems, "title": Loc.t("TEŞEKKÜRLER!")})


## ÜCRETSİZ sekmesinde ödülü alınmamış takip kartı sayısı (kırmızı rozet; hepsi alınınca kalkar).
func _update_free_badge() -> void:
	var tab: PlateButton = _tab_buttons.get(TAB_FREE)
	if tab:
		tab.badge = _community.unclaimed() if _community else 0


func _on_free_gems() -> void:
	var player: PlayerProgress = _player()
	var gems: int = AdPolicy.free_gems()
	if player == null:
		return
	player.add_gems(gems)
	_reward_popup.show_rewards({"gems": gems, "title": Loc.t("ÜCRETSİZ ELMAS")})


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
