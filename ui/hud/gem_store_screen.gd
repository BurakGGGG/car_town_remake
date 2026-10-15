class_name GemStoreScreen
extends Control
## GEM MAĞAZASI — gerçek parayla gem paketleri. Sol üstteki gem sayacına dokununca ya da showroom'da
## "GEM YETERSİZ" plakasından açılır (MODAL, UiRouter id &"gem_store"). Kodla kurulur (.tscn yok).
##
## HİÇBİR MANTIK BURADA DEĞİL: ürünler GemProducts'ta, fiyat / satın alma / defter PurchaseManager'da.
## Fiyatlar Play'den oyuncunun para biriminde gelir; burada sayı yazılmaz.

signal closed

const PLATE_WIDTH: float = 470.0
## Kart: çizim + miktar + ad + fiyat. 5 kart yan yana 1152 tabanına sığar.
const CARD_WIDTH: float = 178.0
const ART_SIZE: Vector2 = Vector2(166.0, 132.0)

## Satın alınan gem pencereden sayaca uçsun (Hud verir).
var hud: Hud

var _purchases: PurchaseManager
var _list: HBoxContainer
## Kart sırasının kabı: 5 kart 982 birim; dar tuvalde (853 birim, sol üstte HUD payı) kalan yere sığar,
## kartlar parmakla kaydırılır (eskiden sıra ekranın sağından taşıyordu).
var _list_scroll: ScrollContainer
var _status: Label
var _column: VBoxContainer
var _reward_popup: RewardPopup
var _closing: bool = false
var _last_status: String = ""


func _ready() -> void:
	name = "GemStoreScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	_bind.call_deferred()
	get_viewport().size_changed.connect(_fit_list, CONNECT_DEFERRED)
	visibility_changed.connect(_fit_list, CONNECT_DEFERRED)


func open() -> void:
	_last_status = ""
	_refresh()
	PlateAnim.pop_in(self, _column)


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
		if visible:
			_refresh())
	_purchases.purchase_finished.connect(_on_purchase_finished)
	_purchases.gems_purchased.connect(_on_gems_purchased)


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.45)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center: CenterContainer = FitScroll.center_in(self)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 6)
	center.add_child(column)
	_column = column

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = _label(&"HudSignTitle", Loc.t("GEM MAĞAZASI"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sign.add_child(title)
	column.add_child(sign)

	var head: PlatePanel = PlatePanel.new()
	head.theme_type_variation = &"HudCarPlate"
	head.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	head.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_status = _label(&"HudInkCaption", "")
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_child(_status)
	column.add_child(head)

	_list_scroll = ScrollContainer.new()
	_list_scroll.name = "CardScroll"
	_list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_list_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_list_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_child(_list_scroll)
	_list = HBoxContainer.new()
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override(&"separation", 8)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.minimum_size_changed.connect(_fit_list, CONNECT_DEFERRED)
	_list_scroll.add_child(_list)
	TouchScroll.attach(_list_scroll)

	var close_button: PlateButton = PlateButton.new()
	close_button.theme_type_variation = &"HudPlateSmall"
	close_button.text = Loc.t("KAPAT")
	close_button.custom_minimum_size = Vector2(PLATE_WIDTH, 0.0)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	column.add_child(close_button)

	_reward_popup = RewardPopup.new()   # son çocuk: mağazanın üstünde açılır
	add_child(_reward_popup)


func _refresh() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	if _purchases == null or not _purchases.is_available():
		_status.text = Loc.t("MAĞAZAYA ŞU AN ULAŞILAMIYOR\nİNTERNET BAĞLANTINI VE GOOGLE PLAY'İ KONTROL ET")
		return
	if not _last_status.is_empty():
		_status.text = _last_status
	elif _purchases.pending_payment:
		_status.text = Loc.t("ÖDEMESİ BEKLENEN BİR SATIN ALMAN VAR\nÖDEME TAMAMLANINCA GEMLER GELİR")
	else:
		_status.text = Loc.t("GEMLE ARAÇ KASASI VE ÖZEL BOYA ALINIR")
	for entry: Dictionary in GemProducts.PRODUCTS:
		var id: StringName = entry["id"]
		if bool(entry["once"]) and _purchases.was_bought(id):
			continue   # tek seferlik paket alındı: listeden çıkar
		_list.add_child(_card(entry))


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

	var reason: String = _purchases.block_reason(id)
	var price: PlateButton = PlateButton.new()
	price.theme_type_variation = &"HudPlateSmall"
	price.focus_mode = Control.FOCUS_NONE
	price.kind = HudIcon.Kind.NONE
	price.text = "…" if reason == "busy" else _purchases.price_text(id)
	price.disabled = not reason.is_empty()
	price.pressed.connect(func() -> void:
		_last_status = ""
		_purchases.buy(id))
	box.add_child(price)
	return card


## FitScroll: HUD payı değişti (pano açıldı / kadraj döndü).
func fit_reserve_changed() -> void:
	_fit_list()


## Kart sırası kadar geniş; sığmıyorsa kullanılabilir genişlik kadar (FitScroll: HUD payı düşülmüş).
func _fit_list() -> void:
	if _list_scroll == null:
		return
	var width: float = floorf(minf(_list.get_combined_minimum_size().x, FitScroll.available_width(self, _list_scroll)))
	if not is_equal_approx(_list_scroll.custom_minimum_size.x, width):
		_list_scroll.custom_minimum_size.x = width


func _on_purchase_finished(_id: StringName, status: StringName) -> void:
	match status:
		&"canceled":
			_last_status = Loc.t("SATIN ALMA İPTAL EDİLDİ")
		&"error":
			_last_status = Loc.t("SATIN ALMA TAMAMLANAMADI, TEKRAR DENE")
		&"pending":
			_last_status = Loc.t("ÖDEME BEKLENİYOR\nÖDEME TAMAMLANINCA GEMLER GELİR")
		_:
			_last_status = Loc.t("TEŞEKKÜRLER! GEMLER HESABINA EKLENDİ")
	if visible:
		_refresh()


func _on_gems_purchased(_id: StringName, gems: int) -> void:
	if visible:
		_reward_popup.show_rewards({"gems": gems, "title": Loc.t("SATIN ALMA TAMAMLANDI!")})


func _label(variation: StringName, text: String) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = variation
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
