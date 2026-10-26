class_name AdService
extends Node
## REKLAM SERVİSİ — oyunun reklamlarla konuştuğu TEK nokta ("ads" grubu; autoload yok).
##
## Sorumluluklar: sağlayıcı seçimi (AdBoot; yükleme ekranı SDK'yı erken başlatır), onay + SDK başlatma, ödüllü reklamı
## önceden yükleme, teklif uygunluğu (AdPolicy), günlük sayaçlar (kayıt), ödülü TEK kez bildirme.
##
## ÖDÜL SÖZLEŞMESİ: `reward_earned(kind)` bir reklam gösteriminde en çok BİR kez yayılır ve yalnızca
## oyuncu reklamı gerçekten hak ettiyse. Dinleyici ödülü verir (₺ ×2, süre kısaltma…); ödül verildikten sonra
## kayıt zaten istenmiştir. Reklam ortasında uygulama kapanırsa ödül yoktur, kayıp yoktur.
##
## Teklif akışı (UI): `offer_state(kind)` READY ise "REKLAM İZLE" plakası gösterilir, oyuncu basarsa `show_rewarded(kind)`;
## LOADING ise plaka görünür ama pasif "REKLAM YÜKLENİYOR" der (2026-10-26, kullanıcı: reklam yüklenmemişken düğme hiç
## görünmüyordu; kimi oyuncu birkaç saniye bekler) ve yükleme `request(kind)` ile dürtülür. Reddetmek hiçbir şeyi
## engellemez (AdMob / AppLovin politikası).

## Bir ödüllü reklam hak edildi. Dinleyici ödülü uygular.
signal reward_earned(kind: StringName)
## Reklam akışı bitti (kapandı / gösterilemedi). rewarded: ödül hak edildi mi.
signal ad_finished(kind: StringName, rewarded: bool)
## Hazırlık / yükleme durumu değişti (teklif plakası kendini tazelesin).
signal readiness_changed

## Teklif düğmesinin durumu (offer_state). NONE: düğme yok · LOADING: düğme görünür ama pasif, "REKLAM YÜKLENİYOR" ·
## READY: "REKLAM İZLE", basılabilir.
enum Offer { NONE, LOADING, READY }

## Reklam geçerlilik süresi (Google: 1 saat). Daha eskiyse yeniden yüklenir.
const AD_MAX_AGE_MS: int = 50 * 60 * 1000
## Yükleme başarısız olunca yeniden deneme bekleme süreleri (ms) — sonsuz döngü yok.
const RETRY_MS: Array[int] = [15_000, 45_000, 120_000]

var _provider: AdProvider
var _started: bool = false          # SDK hazır mı
var _starting: bool = false         # SDK başlatılıyor (cevap bekleniyor)
var _busy: bool = false             # bir reklam gösteriliyor
var _last_ad_end_ms: int = -1
## Yuva başına: {"loading": bool, "loaded_at": int(ms, -1=yok), "retry": int, "waiting": bool (yeniden deneme bekleniyor)}
var _slots: Dictionary = {}
var _pending_slot: StringName = &""
var _state: Dictionary = {"day": -1, "counts": {}, "last": {}}
var _pending_kind: StringName = &""
var _earned_this_show: bool = false
var _clock_unix: float = -1.0       # testler için: ≥0 ise sistem saati yerine bu unix zamanı


func _ready() -> void:
	add_to_group("ads")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for slot: StringName in AdConfig.slots():
		_slots[slot] = {"loading": false, "loaded_at": -1, "retry": 0, "waiting": false}
	_starting = true
	var adopted: bool = false
	if _provider == null:
		_provider = AdBoot.take(_on_provider_started)   # yükleme ekranında başlatıldıysa SDK + ilk yükleme sürüyor
		adopted = _provider != null
	if _provider == null:
		_provider = AdBoot.pick()
	_roll_day()
	_apply_remote()
	var config: AppConfig = AppConfig.current()
	if config:
		config.changed.connect(_apply_remote)   # panelden reklam sınırları (config/app.ads)
	if not adopted:
		_provider.start(_on_provider_started)


## Yönetim panelinin reklam ayarı (sınırlar, ücretsiz elmas miktarı / beklemesi) kurallara yazılır.
func _apply_remote() -> void:
	var config: AppConfig = AppConfig.current()
	AdPolicy.remote = AdPolicy.normalize_remote(config.config().get("ads") if config else null)
	readiness_changed.emit()


## Test / geliştirme: sağlayıcıyı elle ver (_ready'den ÖNCE çağrılmalı).
func use_provider(provider: AdProvider) -> void:
	_provider = provider


func provider() -> AdProvider:
	return _provider


## Reklam gizlilik seçenekleri (UMP) giriş noktası gerekli mi? AYARLAR ekranı buna göre düğme gösterir.
func privacy_options_required() -> bool:
	return _provider != null and _provider.privacy_options_required()


func show_privacy_options(on_done: Callable = func() -> void: pass) -> void:
	if _provider:
		_provider.show_privacy_options(on_done)
	else:
		on_done.call()


## Kişiselleştirilmiş reklam AÇIK/KAPALI düğmesi gösterilsin mi (AppLovin)? AdMob'da Google formu kullanılır.
func personalization_toggle() -> bool:
	return _provider != null and _provider.personalization_toggle()


func personalized_ads() -> bool:
	return _provider != null and _provider.personalized_ads()


func set_personalized_ads(on: bool) -> void:
	if _provider:
		_provider.set_personalized_ads(on)


# --- Sorgular ---------------------------------------------------------------------

## Reklam gösterilmeye hazır mı (SDK hazır, başka reklam yok, yuvada yüklü reklam var)?
## kind verilmezse HERHANGİ bir yuva hazırsa true.
func is_ready(kind: StringName = &"") -> bool:
	if not _started or _busy:
		return false
	if kind == &"":
		for slot: StringName in _slots:
			if _provider.has_rewarded(slot):
				return true
		return false
	var slot_name: StringName = AdPolicy.slot_of(kind)
	return slot_name != &"" and _provider.has_rewarded(slot_name)


func is_busy() -> bool:
	return _busy


## Bu teklif şu an sunulabilir mi? Boş = evet; değilse AdPolicy'deki neden.
## (Yüklü reklam olup olmadığı AYRI: is_ready().)
func block_reason(kind: StringName) -> StringName:
	_roll_day()
	return AdPolicy.block_reason(kind, _state, _level(), Time.get_ticks_msec(), _last_ad_end_ms, _now_unix())


## Türün beklemesinin bitmesine kalan sn (ÜCRETSİZ ELMAS geri sayımı; 0 = izlenebilir).
func cooldown_left(kind: StringName) -> int:
	return AdPolicy.cooldown_left(kind, _state, _now_unix())


## Teklif plakası basılabilir mi: politika uygun VE reklam hazır.
func can_offer(kind: StringName) -> bool:
	return block_reason(kind) == AdPolicy.OK and is_ready(kind)


## Teklif düğmesi ne göstersin: READY (izlenebilir), LOADING (reklam yükleniyor / SDK başlıyor / iki reklam arası
## bekleme: az sonra izlenebilir), NONE (seviye, günlük sınır, tür beklemesi ya da bu oturumda reklam yok).
func offer_state(kind: StringName) -> Offer:
	var reason: StringName = block_reason(kind)
	if reason == AdPolicy.OK and is_ready(kind):
		return Offer.READY
	if reason in [AdPolicy.OK, AdPolicy.TOO_SOON] and can_load(kind):
		return Offer.LOADING
	return Offer.NONE


## Bu oturumda bu türün reklamı gelebilir mi: SDK başladı ya da başlıyor ve yuvanın birimi var. false = reklamsız
## derleme / SDK başlayamadı (teklif "yükleniyor"da asılı kalmaz, hiç görünmez).
func can_load(kind: StringName) -> bool:
	if _starting:
		return true
	var slot: StringName = AdPolicy.slot_of(kind)
	return _started and _slots.has(slot) and _provider.unit_for(slot) != ""


## LOADING gösteren düğme reklamı istiyor: yuva yüklenmiyorsa ve yeniden deneme beklemiyorsa yükleme başlar; denemeler
## bitmişse (pes edilmiş) baştan alınır. Saniyede bir çağrılabilir: yükleme ya da bekleme sürerken bir şey yapmaz.
func request(kind: StringName) -> void:
	var slot: StringName = AdPolicy.slot_of(kind)
	if not _slots.has(slot):
		return
	var info: Dictionary = _slots[slot]
	if bool(info["loading"]) or bool(info["waiting"]):
		return
	if int(info["retry"]) >= RETRY_MS.size():
		info["retry"] = 0
	_load_slot(slot)


## Bugün bu türden kaç reklam izlendi / kaç hakkı kaldı (UI "2/5" yazısı için).
func used_today(kind: StringName) -> int:
	_roll_day()
	return int((_state["counts"] as Dictionary).get(kind, 0))


func remaining_today(kind: StringName) -> int:
	return maxi(AdPolicy.daily_cap(kind) - used_today(kind), 0)


# --- Gösterim ---------------------------------------------------------------------

## Oyuncu "REKLAM İZLE" plakasına bastı. false: hiçbir şey olmadı (uygun değil / hazır değil / çift dokunuş).
func show_rewarded(kind: StringName) -> bool:
	if _busy or not can_offer(kind):
		return false
	_busy = true
	_pending_kind = kind
	_pending_slot = AdPolicy.slot_of(kind)
	_earned_this_show = false
	readiness_changed.emit()
	_provider.show_rewarded(_pending_slot, _on_earned, _on_finished)
	return true


func _on_earned() -> void:
	if _pending_kind == &"" or _earned_this_show:
		return   # ödül iki kez bildirilmez
	_earned_this_show = true
	var counts: Dictionary = _state["counts"]
	counts[_pending_kind] = int(counts.get(_pending_kind, 0)) + 1
	if not _state.has("last"):
		_state["last"] = {}
	(_state["last"] as Dictionary)[_pending_kind] = _now_unix()   # tür beklemesi (ÜCRETSİZ ELMAS 3 dk)
	_request_save()   # sayaç ödülden ÖNCE diske istenir: uygulama ölürse hak geri verilmez
	reward_earned.emit(_pending_kind)


func _on_finished() -> void:
	# Aracı ağlarda ödül geri çağrısı kapanıştan sonra gelebilir: iki kare bekle, sonra bitir.
	if not is_inside_tree():
		_finish_show()
		return
	await get_tree().process_frame
	await get_tree().process_frame
	_finish_show()


func _finish_show() -> void:
	var kind: StringName = _pending_kind
	var slot: StringName = _pending_slot
	var rewarded: bool = _earned_this_show
	_pending_kind = &""
	_pending_slot = &""
	_earned_this_show = false
	_busy = false
	_last_ad_end_ms = Time.get_ticks_msec()
	if _slots.has(slot):
		_slots[slot]["loaded_at"] = -1
	ad_finished.emit(kind, rewarded)
	readiness_changed.emit()
	ensure_loaded()   # gösterilen yuvanın yenisi arka planda hazırlanır


# --- Yükleme ----------------------------------------------------------------------

func _on_provider_started(ok: bool) -> void:
	_starting = false
	_started = ok
	if ok:
		for slot: StringName in _slots:
			if _provider.has_rewarded(slot):
				_on_loaded(slot, true)   # açılışta (AdBoot) yüklenmiş: eskime sayacı buradan başlar
		ensure_loaded()
	readiness_changed.emit()


## Yüklü olmayan her yuvanın reklamını yüklemeyi dener (zaten yükleniyorsa / yüklüyse dokunmaz).
## UI, teklif göstereceği ekranı açarken çağırabilir; bekleme / sınır kuralları teklif tarafında uygulanır.
func ensure_loaded() -> void:
	for slot: StringName in _slots:
		_load_slot(slot)


func _load_slot(slot: StringName) -> void:
	if not _started or _busy or _provider.has_rewarded(slot):
		return
	var info: Dictionary = _slots[slot]
	if bool(info["loading"]):
		return
	var unit: String = _provider.unit_for(slot)
	if unit == "":
		return   # bu yuvanın birimi yok / bu derlemede güvensiz: yuva kapalı
	info["loading"] = true
	_provider.load_rewarded(slot, unit, func(ok: bool) -> void: _on_loaded(slot, ok))


func _on_loaded(slot: StringName, ok: bool) -> void:
	var info: Dictionary = _slots[slot]
	info["loading"] = false
	if ok:
		info["retry"] = 0
		info["loaded_at"] = Time.get_ticks_msec()
		_schedule_expiry(slot)
	else:
		_schedule_retry(slot)
	readiness_changed.emit()


func _schedule_retry(slot: StringName) -> void:
	var info: Dictionary = _slots[slot]
	var index: int = int(info["retry"])
	if not is_inside_tree() or index >= RETRY_MS.size():
		return   # pes et: sonsuz istek yağmuru yok; sonraki oturum yeniden dener
	info["retry"] = index + 1
	info["waiting"] = true
	get_tree().create_timer(float(RETRY_MS[index]) / 1000.0).timeout.connect(func() -> void:
		info["waiting"] = false
		_load_slot(slot))


func _schedule_expiry(slot: StringName) -> void:
	if not is_inside_tree():
		return
	var stamp: int = int(_slots[slot]["loaded_at"])
	get_tree().create_timer(float(AD_MAX_AGE_MS) / 1000.0).timeout.connect(func() -> void:
		# Aynı reklam hâlâ bekliyorsa eskimiştir (Google: 1 saat): yenisini yükle.
		var info: Dictionary = _slots[slot]
		if stamp == int(info["loaded_at"]) and not _busy and not bool(info["loading"]):
			info["loaded_at"] = -1
			info["loading"] = true
			_provider.load_rewarded(slot, _provider.unit_for(slot), func(ok: bool) -> void: _on_loaded(slot, ok)))


# --- Kayıt ------------------------------------------------------------------------

func state() -> Dictionary:
	_roll_day()
	return {"day": int(_state["day"]), "counts": (_state["counts"] as Dictionary).duplicate(),
		"last": (_state.get("last", {}) as Dictionary).duplicate()}


## Kayıttan (SaveManager). Bozuk alanlar güvenle atılır.
func load_state(data: Dictionary) -> void:
	var counts: Dictionary = {}
	var raw: Variant = data.get("counts", {})
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary):
			var kind: StringName = StringName(SaveSafe.s(key))
			if AdPolicy.RULES.has(kind):
				counts[kind] = clampi(SaveSafe.i((raw as Dictionary)[key]), 0, 1000)
	var last: Dictionary = {}
	var raw_last: Variant = data.get("last", {})
	if raw_last is Dictionary:
		for key: Variant in (raw_last as Dictionary):
			var kind: StringName = StringName(SaveSafe.s(key))
			if AdPolicy.RULES.has(kind):
				last[kind] = maxi(SaveSafe.i((raw_last as Dictionary)[key]), 0)
	_state = {"day": SaveSafe.i(data.get("day", -1)), "counts": counts, "last": last}
	_roll_day()
	readiness_changed.emit()


func reset() -> void:
	_state = {"day": -1, "counts": {}, "last": {}}
	_roll_day()


func _roll_day() -> void:
	_state = AdPolicy.roll_day(_state, _today())


func _today() -> int:
	return AdPolicy.day_number(float(_now_unix()), int(Time.get_time_zone_from_system().get("bias", 0)))


func _now_unix() -> int:
	return int(_clock_unix if _clock_unix >= 0.0 else Time.get_unix_time_from_system())


## Testler: sistem saati yerine sabit unix zamanı (-1 = gerçek saat).
func set_test_clock(unix_time: float) -> void:
	_clock_unix = unix_time
	_roll_day()


## Testler: iki reklam arası bekleme sayacını sıfırla.
func forget_last_ad() -> void:
	_last_ad_end_ms = -1


func _level() -> int:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	return progress.level if progress else 1


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.request_save()
