class_name AdOfferButton
extends PlateButton
## ÖDÜLLÜ REKLAM DÜĞMESİ — "REKLAM İZLE" tekliflerinin ortak düğmesi (2026-10-23, kullanıcı kararı: yalnızca oyuncunun
## kendi bastığı ödüllü reklam; kendiliğinden açılan reklam / pencere yok). Düğme kendi durumunu yönetir:
##   uygun + reklam yüklü      → "REKLAM İZLE" + ödül satırı, basılabilir
##   reklam henüz yüklenmedi   → "REKLAM YÜKLENİYOR" + ödül satırı, pasif; yüklenince kendiliğinden açılır (2026-10-26,
##                               kullanıcı: eskiden gizleniyordu, oyuncu teklifi hiç görmüyordu; kimisi birkaç sn bekler)
##   tür beklemede (cooldown)  → kalıcı düğmede geri sayım ("2:41 SONRA"), değilse gizli
##   bugünlük hak bitti        → kalıcı düğmede "YARIN YENİLENİR", değilse gizli
## Basınca AdService.show_rewarded(kind). Ödül YALNIZCA bu düğme başlattıysa `rewarded` olarak yayılır (aynı türün
## başka düğmesi ödülü yanlışlıkla almasın); reklam bitince `finished(rewarded)`. Ödülü veren çağıran tarafır.
## `condition` (isteğe bağlı): teklifin o an anlamlı olup olmadığı (ör. kesilecek süre var mı); false → gizli.

signal rewarded
signal finished(was_rewarded: bool)

var offer: StringName = &""
## Alt satır: ödülün kendisi ("+5 GEM", "−12 DK").
var reward_text: String = ""
## Kalıcı düğme (MARKET kartı): uygun değilken gizlenmez, nedenini yazar.
var persistent: bool = false
var condition: Callable = Callable()
## Ödül satırı her tazelemede bundan okunur (süre kısaltma: kalan süre azaldıkça "−12 DK" değişir).
var reward_fn: Callable = Callable()
## Sade düğme (listede çok kez görünen teklif: GÖREVİ DEĞİŞTİR): tek satır, yalnız ödül yazısı + oynat ikonu, amber değil.
var compact: bool = false

var _ads: AdService
var _waiting: bool = false
var _timer: Timer


func _init(p_offer: StringName = &"", p_reward_text: String = "", p_persistent: bool = false) -> void:
	offer = p_offer
	reward_text = p_reward_text
	persistent = p_persistent
	name = "AdOffer_%s" % p_offer
	theme_type_variation = &"HudPlateSmall"
	kind = HudIcon.Kind.PLAY
	icon_left = true
	focus_mode = Control.FOCUS_NONE
	visible = false


func _ready() -> void:
	super._ready()
	pressed.connect(_on_pressed)
	_timer = Timer.new()
	_timer.wait_time = 1.0
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_timer.start()
	refresh()


## Durumu yeniden değerlendirir (çağıran ödül metni / koşul değişince de çağırabilir).
func refresh() -> void:
	var ads: AdService = _service()
	if ads == null or offer == &"" or (condition.is_valid() and not bool(condition.call())):
		visible = false
		return
	if _waiting:
		visible = true
		disabled = true
		text = Loc.t("REKLAM OYNUYOR…")
		return
	if reward_fn.is_valid():
		reward_text = String(reward_fn.call())
	var state: AdService.Offer = ads.offer_state(offer)
	if state == AdService.Offer.READY:
		visible = true
		disabled = false
		highlight = not compact
		if compact:
			text = reward_text
		else:
			text = Loc.t("REKLAM İZLE") + ("\n" + reward_text if not reward_text.is_empty() else "")
		return
	highlight = false
	disabled = true
	if state == AdService.Offer.LOADING:
		visible = true
		ads.request(offer)
		if compact:
			text = Loc.t("YÜKLENİYOR…")
		else:
			text = Loc.t("REKLAM YÜKLENİYOR") + ("\n" + reward_text if not reward_text.is_empty() else "")
		return
	var reason: StringName = ads.block_reason(offer)
	if not persistent or reason in [AdPolicy.LEVEL_LOW, AdPolicy.UNKNOWN_KIND]:
		visible = false
		return
	visible = true
	match reason:
		AdPolicy.COOLDOWN:
			text = Loc.t("%s SONRA") % _clock(ads.cooldown_left(offer))
		AdPolicy.DAILY_CAP, AdPolicy.TOTAL_CAP:
			text = Loc.t("YARIN YENİLENİR")
		_:
			text = Loc.t("REKLAM YÜKLENİYOR")   # bu oturumda reklam yok (reklamsız derleme / SDK başlamadı)


func _on_pressed() -> void:
	var ads: AdService = _service()
	if ads == null or _waiting:
		return
	if ads.show_rewarded(offer):
		_waiting = true
	refresh()


func _service() -> AdService:
	if _ads == null and is_inside_tree():
		_ads = get_tree().get_first_node_in_group("ads") as AdService
		if _ads:
			_ads.readiness_changed.connect(refresh)
			_ads.reward_earned.connect(_on_earned)
			_ads.ad_finished.connect(_on_finished)
			_ads.ensure_loaded()
	return _ads


func _on_earned(k: StringName) -> void:
	if _waiting and k == offer:
		rewarded.emit()


func _on_finished(k: StringName, was_rewarded: bool) -> void:
	if not _waiting or k != offer:
		return
	_waiting = false
	finished.emit(was_rewarded)
	refresh()


## Süre kısaltma ödülünün yazısı: "−12 DK" / "−45 SN".
static func cut_text(seconds: float) -> String:
	if seconds >= 60.0:
		return Loc.t("−%d DK") % int(round(seconds / 60.0))
	return Loc.t("−%d SN") % int(ceil(seconds))


static func _clock(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	return "%d:%02d" % [s / 60, s % 60]
