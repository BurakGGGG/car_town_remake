class_name GiftScreen
extends RewardScreen
## HEDİYEN GELDİ! — posta / hediye alınınca açılan ödül ekranı (2026-10-25, kullanıcı: "hediyeyi toplama ekranını
## güzelleştir, hediyenin fotosu gözüksün, seviye atlama ekranındaki gibi; araba da hediye edebileyim"). SEVİYE ATLADIN ile
## aynı dil (RewardScreen): hediye kutusu rozeti ve arkasında dönen ışık, HEDİYEN GELDİ!, postanın başlığı ve göndereni,
## ₺ / GEM hapları, İÇİNDEKİLER kartları — araç (fotoğrafı, nadirliği; zaten varsa satış değeri ₺), kasa (dönen 3B kasa),
## dekor (küçük resim), profil çerçevesi (oyuncunun avatarıyla), efsanevi araç seçimi. TOPLA'ya ya da boş yere dokununca
## kapanır; paralar sayaçlara uçar (RewardPopup gibi: sayaç paralar varana dek eski değeri gösterir). Ekran açıkken gelen
## ikinci hediye sıraya girer. Özet MailService._grant'tan ("cards"). MailNotice kurar.
## ETKİNLİK ARACI da bu ekranla verilir (2026-10-26): başlık "headline", alt satır "line" ile değişir; kendiliğinden gelen
## ödül show_when_calm ile oyun sakinleşince açılır (SEVİYE ATLADIN kuralı: pano / ders / kasa plakası yokken).

## Kapandı; car_choice: alınan hediyede efsanevi araç seçimi vardı (seçim ekranı açılmalı).
signal finished(car_choice: bool)

var _subtitle: Label
var _collect: PlateButton
var _queue: Array[Dictionary] = []
var _pending_money: int = 0
var _pending_gems: int = 0
var _choice: bool = false
## Sakin anı bekleyen kendiliğinden ödüller (sayaçları geldiği an bekletilmiş).
var _calm_queue: Array[Dictionary] = []
var _calm: float = 0.0
var _calm_timer: Timer

const CHECK_SEC: float = 0.4
const CALM_SEC: float = 0.8


func _init(hud: Hud) -> void:
	_hud = hud
	name = "GiftScreen"


func _ready() -> void:
	super._ready()
	_title.text = Loc.t("HEDİYEN GELDİ!")
	_subtitle = _label(&"HudOutlined", "")
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override(&"font_size", 13)
	_column.add_child(_subtitle)
	_column.move_child(_subtitle, _title.get_index() + 1)
	_divider_label.text = Loc.t("İÇİNDEKİLER")
	_calm_timer = Timer.new()
	_calm_timer.wait_time = CHECK_SEC
	_calm_timer.timeout.connect(_calm_tick)
	add_child(_calm_timer)


## Kendiliğinden gelen ödül (etkinlik aracı): ödül hesapta, sayaçlar şimdiden bekler; ekran oyun sakinleşince açılır.
func show_when_calm(summary: Dictionary) -> void:
	if _hud:
		_hud.hold_reward(int(summary.get("money", 0)), int(summary.get("gems", 0)))
	_calm_queue.append(summary)
	_calm = 0.0
	_calm_timer.start()


func _calm_tick() -> void:
	if _calm_queue.is_empty():
		_calm_timer.stop()
		return
	if visible or not _game_calm():
		_calm = 0.0
		return
	_calm += CHECK_SEC
	if _calm >= CALM_SEC:
		show_gift(_calm_queue.pop_front(), true)


## Alınan postanın özeti (MailService.claim): {title, subtitle, from, money, gems, items, cards, choice; isteğe bağlı
## headline (başlık), line (alt satır)}. Ekran açıksa sıraya girer, kapanınca açılır. held: sayaçlar zaten bekletildi.
func show_gift(summary: Dictionary, held: bool = false) -> void:
	if visible:
		if held:
			summary["_held"] = true
		_queue.append(summary)
		return
	var money: int = int(summary.get("money", 0))
	var gems: int = int(summary.get("gems", 0))
	_set_amounts(money, gems)
	_title.text = SaveSafe.s(summary.get("headline", "")) if summary.has("headline") else Loc.t("HEDİYEN GELDİ!")
	if _hud and not held and not summary.get("_held", false):
		_hud.hold_reward(money, gems)   # ödül hesapta; sayaç paralar varana dek eski değeri gösterir
	_pending_money += money
	_pending_gems += gems
	_choice = summary.has("choice")
	var parts: PackedStringArray = PackedStringArray()
	var mail_title: String = SaveSafe.s(summary.get("subtitle", ""))
	if not mail_title.is_empty():
		parts.append(mail_title)
	var from: String = SaveSafe.s(summary.get("from", ""))
	if summary.has("line"):
		parts.append(SaveSafe.s(summary["line"]))
	else:
		parts.append(Loc.t("%s gönderdi") % (from if not from.is_empty() else "AUTO YARD"))
	_subtitle.text = "  ·  ".join(parts)
	_clear_cards()
	for card: Variant in summary.get("cards", []):
		if card is Dictionary:
			var built: Control = _gift_card(card)
			if built:
				_cards.add_child(built)
	_divider.visible = _cards.get_child_count() > 0
	_present()


func is_busy() -> bool:
	return visible or not _queue.is_empty()


func _on_closing() -> void:
	_fly(_pending_money, _pending_gems)
	_pending_money = 0
	_pending_gems = 0


func _on_closed() -> void:
	var choice: bool = _choice
	_choice = false
	finished.emit(choice)
	if not _queue.is_empty():
		show_gift(_queue.pop_front())
	elif not _calm_queue.is_empty():
		_calm = 0.0
		_calm_timer.start()


# --- Kartlar -----------------------------------------------------------------

## Kart: {kind: car | crate | decor | frame | choice, id, count, owned, money}.
func _gift_card(card: Dictionary) -> Control:
	var id: StringName = StringName(SaveSafe.s(card.get("id", "")))
	var count: int = maxi(SaveSafe.i(card.get("count", 1)), 1)
	var times: String = " ×%d" % count if count > 1 else ""
	match SaveSafe.s(card.get("kind", "")):
		"car":
			var owned: bool = card.get("owned", false) == true
			var rarity: StringName = CollectionRewards.car_rarity(id)   # hurdalık klasiği: kademesinin nadirliği
			return _card_from(Loc.t("ARAÇ") if owned else Loc.t("YENİ ARAÇ"), _car_photo(id), MailService.car_name(id),
				CrateCatalog.rarity_label(rarity) if rarity != &"" else Loc.t("GARAJINA EKLENDİ"),
				Loc.t("ZATEN VARDI · +%s ₺") % Hud.format_thousands(SaveSafe.i(card.get("money", 0))) if owned else "")
		"crate":
			var entry: Dictionary = CrateCatalog.get_entry(id)
			return _card_from(Loc.t("KASA"), _CratePreview.new(entry), MailService.crate_name(id) + times,
				Loc.t("GARAJINA TESLİM EDİLECEK"))
		"decor":
			var items: Array[StringName] = [id]
			return _card_from(Loc.t("DEKOR"), _decor_strip(items), MailService.decor_name(id) + times,
				Loc.t("GARAJI DÜZENLE'DE YERLEŞTİR"))
		"frame":
			return _card_from(Loc.t("ÇERÇEVE"), _framed_avatar(String(id)), MailService.frame_name(String(id)),
				Loc.t("PROFİLİNDE KULLANABİLİRSİN"))
		"choice":
			return _card_from(Loc.t("SEÇİM HAKKI"), _bubble(HudIcon.Kind.CAR, CrateCatalog.rarity_color(&"legendary")),
				Loc.t("EFSANEVİ ARAÇ"), Loc.t("TOPLA'YA BASINCA ARACINI SEÇ"))
	return null


## Aracın fabrika renkli küçük resmi (assets/cars/thumbs); kartın resim alanına sığar, ortalı.
func _car_photo(id: StringName) -> TextureRect:
	var photo: TextureRect = _photo(ProfileCard.THUMB_DIR + String(id) + ".png")
	photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return photo


# --- Kurulum -----------------------------------------------------------------

func _make_badge() -> Control:
	return _GiftBadge.new()


func _add_buttons(row: HBoxContainer) -> void:
	_collect = PlateButton.new()
	_collect.name = "CollectButton"
	_collect.theme_type_variation = &"HudPlateSmall"
	_collect.text = Loc.t("TOPLA")
	_collect.highlight = true
	_collect.focus_mode = Control.FOCUS_NONE
	_collect.custom_minimum_size = Vector2(220.0, 0.0)
	_collect.pressed.connect(close)
	row.add_child(_collect)


## Amber rozet (seviye rozetiyle aynı halkalar), içinde hediye kutusu.
class _GiftBadge extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art: InboxCover = InboxCover.new()
		art.kind = &"gift"
		art.bare = true
		art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		art.offset_left = 9.0
		art.offset_top = 7.0
		art.offset_right = -9.0
		art.offset_bottom = -11.0
		add_child(art)

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5
		draw_circle(center + Vector2(0.0, 3.0), radius, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(center, radius, HudPalette.PLATE_SELECTED, true, -1.0, true)
		draw_circle(center, radius - 3.0, HudPalette.INK, true, -1.0, true)
		draw_circle(center, radius - 7.0, HudPalette.PLATE, true, -1.0, true)
