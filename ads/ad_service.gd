class_name AdService
extends Node
## REKLAM SERVİSİ — oyunun reklamlarla konuştuğu TEK nokta ("ads" grubu; autoload yok).
##
## Sorumluluklar: sağlayıcı seçimi, onay + SDK başlatma, ödüllü reklamı önceden yükleme, teklif uygunluğu
## (AdPolicy), günlük sayaçlar (kayıt), ödülü TEK kez bildirme.
##
## ÖDÜL SÖZLEŞMESİ: `reward_earned(kind)` bir reklam gösteriminde en çok BİR kez yayılır ve yalnızca
## oyuncu reklamı gerçekten hak ettiyse. Dinleyici ödülü verir (₺ ×2, süre kısaltma…); ödül verildikten sonra
## kayıt zaten istenmiştir. Reklam ortasında uygulama kapanırsa ödül yoktur, kayıp yoktur.
##
## Teklif akışı (UI): `block_reason(kind) == &""` ve `is_ready()` ise "REKLAM İZLE" plakası gösterilir;
## oyuncu plakaya basarsa `show_rewarded(kind)`. Reddetmek hiçbir şeyi engellemez (AdMob politikası).

## Bir ödüllü reklam hak edildi. Dinleyici ödülü uygular.
signal reward_earned(kind: StringName)
## Reklam akışı bitti (kapandı / gösterilemedi). rewarded: ödül hak edildi mi.
signal ad_finished(kind: StringName, rewarded: bool)
## Hazırlık / yükleme durumu değişti (teklif plakası kendini tazelesin).
signal readiness_changed

## Reklam geçerlilik süresi (Google: 1 saat). Daha eskiyse yeniden yüklenir.
const AD_MAX_AGE_MS: int = 50 * 60 * 1000
## Yükleme başarısız olunca yeniden deneme bekleme süreleri (ms) — sonsuz döngü yok.
const RETRY_MS: Array[int] = [15_000, 45_000, 120_000]

var _provider: AdProvider
var _started: bool = false          # SDK hazır mı
var _busy: bool = false             # bir reklam gösteriliyor
var _last_ad_end_ms: int = -1
## Yuva başına: {"loading": bool, "loaded_at": int(ms, -1=yok), "retry": int}
var _slots: Dictionary = {}
var _pending_slot: StringName = &""
var _state: Dictionary = {"day": -1, "counts": {}}
var _pending_kind: StringName = &""
var _earned_this_show: bool = false
var _clock_unix: float = -1.0       # testler için: ≥0 ise sistem saati yerine bu unix zamanı


func _ready() -> void:
	add_to_group("ads")
	process_mode = Node.PROCESS_MODE_ALWAYS
	for slot: StringName in AdConfig.slots():
		_slots[slot] = {"loading": false, "loaded_at": -1, "retry": 0}
	if _provider == null:
		_provider = _pick_provider()
	_roll_day()
	_provider.start(_on_provider_started)


## Test / geliştirme: sağlayıcıyı elle ver (_ready'den ÖNCE çağrılmalı).
func use_provider(provider: AdProvider) -> void:
	_provider = provider


func provider() -> AdProvider:
	return _provider


static func _pick_provider() -> AdProvider:
	if not GameFeatures.ADS or not AdConfig.any_slot_usable():
		return AdProvider.new()   # kapalı: hiçbir şey yüklenmez, hiçbir teklif çıkmaz
	if Engine.has_singleton("PoingGodotAdMob"):
		return AdMobProvider.new()
	if OS.is_debug_build():
		return MockAdProvider.new()   # masaüstü geliştirme
	return AdProvider.new()


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
	return AdPolicy.block_reason(kind, _state, _level(), Time.get_ticks_msec(), _last_ad_end_ms)


## Teklif plakası görünsün mü: politika uygun VE reklam hazır.
func can_offer(kind: StringName) -> bool:
	return block_reason(kind) == AdPolicy.OK and is_ready(kind)


## Bugün bu türden kaç reklam izlendi / kaç hakkı kaldı (UI "2/5" yazısı için).
func used_today(kind: StringName) -> int:
	_roll_day()
	return int((_state["counts"] as Dictionary).get(kind, 0))


func remaining_today(kind: StringName) -> int:
	var rule: Dictionary = AdPolicy.RULES.get(kind, {})
	return maxi(int(rule.get("daily_cap", 0)) - used_today(kind), 0)


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
	_started = ok
	if ok:
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
	var unit: String = AdConfig.rewarded_unit(slot)
	if not AdConfig.unit_is_safe(unit):
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
	get_tree().create_timer(float(RETRY_MS[index]) / 1000.0).timeout.connect(func() -> void: _load_slot(slot))


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
			_provider.load_rewarded(slot, AdConfig.rewarded_unit(slot), func(ok: bool) -> void: _on_loaded(slot, ok)))


# --- Kayıt ------------------------------------------------------------------------

func state() -> Dictionary:
	_roll_day()
	return {"day": int(_state["day"]), "counts": (_state["counts"] as Dictionary).duplicate()}


## Kayıttan (SaveManager). Bozuk alanlar güvenle atılır.
func load_state(data: Dictionary) -> void:
	var counts: Dictionary = {}
	var raw: Variant = data.get("counts", {})
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary):
			var kind: StringName = StringName(SaveSafe.s(key))
			if AdPolicy.RULES.has(kind):
				counts[kind] = clampi(SaveSafe.i((raw as Dictionary)[key]), 0, 1000)
	_state = {"day": SaveSafe.i(data.get("day", -1)), "counts": counts}
	_roll_day()
	readiness_changed.emit()


func reset() -> void:
	_state = {"day": -1, "counts": {}}
	_roll_day()


func _roll_day() -> void:
	_state = AdPolicy.roll_day(_state, _today())


func _today() -> int:
	var now: float = _clock_unix if _clock_unix >= 0.0 else Time.get_unix_time_from_system()
	return AdPolicy.day_number(now, int(Time.get_time_zone_from_system().get("bias", 0)))


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
