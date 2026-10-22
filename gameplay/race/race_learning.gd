class_name RaceLearning
extends Node
## ÖĞRENEN ZORLUK (docs/KOSU_ESLESTIRME.md, Faz 2): sıradaki yarışın kolunu (kolay / dengeli / zor) oyuncunun yarıştan
## SONRA oyunda kalıp kalmamasına göre seçer — "kazanınca mı kaybedince mi daha çok kalıyor". RaceManager kurar (_init)
## ve kol çekerken (choose_arm), pist açılırken (race_started) ve yarış bitince (race_finished) çağırır.
##
## KALIŞ (kullanıcı kararı: yarış sonrası kalış): sonuçtan sonra WINDOW_DEFAULT (5 dk; config/race_learning.window) içinde
## oyun kapanmadı / arka plana atılmadı (LEAVE_GRACE içinde geri dönüş sayılmaz) YA DA sıradaki yarış başladı → "kaldı".
## Oyun bu arada kapanırsa / arka planda öldürülürse sonuç diskte bekler, sonraki açılışta AYRILMA ANINA göre karara
## bağlanır. Sahne yeniden kurulsa da (bulut kaydı) sonuç kaybolmaz: yeni örnek dosyadan devam eder.
##
## ÖĞRENME: bağlam (son iki sonuç WW / WL / LW / LL — W kazandı, L kaybetti, eskisi önce; ilk NEW_RACES yarış "new") ×
## kol başına Thompson örneklemesi (Beta). Önsel = sunucudaki GENEL tablo (config/race_learning.table: bütün hesaplı
## oyuncuların son 30 günü, raceLearning gece toplar) PRIOR_WEIGHT yarışa eşdeğer ağırlıkla; üstüne oyuncunun KENDİ
## sayıları (kayıtta: RaceManager "learn"). Genel tabloda o bağlamın her kolunda MIN_TRIALS deneme yoksa ya da panelden
## kapatıldıysa (off) BAŞLANGIÇ KURALI (RivalSelector.choose_arm) — o kuralın kendi karışımı veriyi de toplar.
## KORKULUKLAR (öğrenme ne derse desin): seri kırıcı (iki kayıp → kolay); ZOR son HISTORY yarışta en çok HARD_SHARE;
## üç ZOR üst üste yok.
##
## GÜNLÜK ("sistemimizde hep tutalım"): her sonuç race_log/{uid}_{UTC gün}'e gider (yalnızca hesapla girenler; misafirin
## olayları cihazdan çıkmaz). Günün olayları cihazda (FILE) birikir, belge her yazışta günün tamamıyla yeniden yazılır;
## internet yoksa sonra. Kural yalnız son iki günü kabul eder: daha eski yazılamayan gün atılır.

## Kişisel sayılar değişti (kayıt).
signal changed

const CONTEXTS: Array[String] = ["new", "WW", "WL", "LW", "LL"]
## Bu kadar yarışa kadar bağlam "new" (yeni oyuncu ayrı öğrenilir).
const NEW_RACES: int = 10
const WINDOW_DEFAULT: int = 300
const LEAVE_GRACE: int = 60
const PRIOR_WEIGHT_DEFAULT: int = 20
## Genel tabloda bağlamın HER kolunda en az bu kadar deneme yoksa o bağlamda başlangıç kuralı.
const MIN_TRIALS: int = 30
const HARD_SHARE: float = 0.25
const HARD_WINDOW: int = 20
## Sonuç bu kadar eskiyse (pencere dahil) ve ayrılma anı bilinmiyorsa (çökme) sayılmaz.
const STALE_SEC: int = 3600
const FILE: String = "user://race_learning.json"
const MAX_DAY_EVENTS: int = 500
## Kural bugünü ve son iki günü kabul eder.
const UPLOAD_DAYS: int = 2
const UPLOAD_DELAY: float = 20.0

## Testler: sabit saat (unix sn; -1 = gerçek) ve genel belge (null = AppConfig).
var now_override: int = -1
var global_override: Variant = null

## Kişisel sayılar: bağlam → {"0": [kaldı, deneme], "1": …, "2": …}.
var _counts: Dictionary = {}
## Karara bağlanmamış son yarış: olay alanları + "t" (bitiş, unix sn) + "left" (ayrılma anı, varsa).
var _pending: Dictionary = {}
## Günün olayları (UTC gün numarası metin olarak → olaylar) ve sunucuya yazılmamış günler.
var _days: Dictionary = {}
var _dirty: Dictionary = {}
var _paused_at: int = -1
## Ziyaret kipinde (arkadaşın garajı) dosya / yükleme yok.
var _io: bool = true
var _uploading: bool = false
var _upload_timer: Timer
var _tick: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GarageVisit.is_visiting():
		_io = false
		set_process(false)
		return
	_load_file()
	_resume_pending()
	_upload_timer = Timer.new()
	_upload_timer.one_shot = true
	_upload_timer.timeout.connect(upload)
	add_child(_upload_timer)
	if not _dirty.is_empty():
		_upload_timer.start(5.0)


func _process(delta: float) -> void:
	_tick += delta
	if _tick >= 1.0:
		_tick = 0.0
		poll()


# --- Kol ---------------------------------------------------------------------------

## Bağlam: son iki sonuç ("LW" = önce kaybetti, sonra kazandı); ilk NEW_RACES yarışta "new". `races`: bu yarıştan önceki
## toplam yarış.
static func context_of(history: Array, races: int) -> String:
	var n: int = history.size()
	if races < NEW_RACES or n < 2:
		return "new"
	return _letter(history[n - 2]) + _letter(history[n - 1])


## Sıradaki yarışın kolu (RivalSelector.Arm).
func choose_arm(history: Array, races: int, rng: RandomNumberGenerator) -> int:
	if RivalSelector.streak_breaker(history):
		return RivalSelector.Arm.EASY
	var allowed: Array[int] = [RivalSelector.Arm.EASY, RivalSelector.Arm.EVEN, RivalSelector.Arm.HARD]
	if _hard_capped(history):
		allowed.erase(RivalSelector.Arm.HARD)
	var context: String = context_of(history, races)
	var prior: Array[Vector2] = prior_of(context)
	if prior.is_empty():
		var start: int = RivalSelector.choose_arm(history, rng)
		return start if allowed.has(start) else RivalSelector.Arm.EVEN
	var best: int = allowed[0]
	var best_sample: float = -1.0
	for arm: int in allowed:
		var mine: Vector2i = cell(context, arm)
		var sample: float = beta(prior[arm].x + float(mine.x), prior[arm].y + float(mine.y - mine.x), rng)
		if sample > best_sample:
			best_sample = sample
			best = arm
	return best


## Genel tablodan bağlamın önseli: kol başına Beta(α, β) — Vector2(α, β). Tablo kapalı / yetersizse boş.
func prior_of(context: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var doc: Dictionary = global_doc()
	if SaveSafe.b(doc.get("off", false)) or not doc.get("table") is Dictionary:
		return out
	var row: Variant = (doc["table"] as Dictionary).get(context, {})
	if not row is Dictionary:
		return out
	var weight: float = float(clampi(SaveSafe.i(doc.get("weight", PRIOR_WEIGHT_DEFAULT)), 1, 200))
	for arm: int in 3:
		var raw: Variant = (row as Dictionary).get(str(arm), {})
		var stays: int = SaveSafe.i((raw as Dictionary).get("s", 0)) if raw is Dictionary else 0
		var trials: int = SaveSafe.i((raw as Dictionary).get("n", 0)) if raw is Dictionary else 0
		if trials < MIN_TRIALS or stays < 0 or stays > trials:
			out.clear()
			return out
		var rate: float = (float(stays) + 1.0) / (float(trials) + 2.0)
		out.append(Vector2(1.0 + weight * rate, 1.0 + weight * (1.0 - rate)))
	return out


## Oyuncunun kendi sayıları: Vector2i(kaldı, deneme).
func cell(context: String, arm: int) -> Vector2i:
	var row: Variant = _counts.get(context, {})
	var raw: Variant = (row as Dictionary).get(str(arm), []) if row is Dictionary else []
	if raw is Array and (raw as Array).size() == 2:
		return Vector2i(SaveSafe.i(raw[0]), SaveSafe.i(raw[1]))
	return Vector2i.ZERO


func global_doc() -> Dictionary:
	if global_override is Dictionary:
		return global_override
	return AppConfig.learning_of(get_tree()) if is_inside_tree() else {}


## Kalış penceresi (sn; panelden ayarlanır).
func window() -> int:
	return clampi(SaveSafe.i(global_doc().get("window", WINDOW_DEFAULT)), 60, 1800)


# --- Kalış -------------------------------------------------------------------------

## Pist açıldı (yeni yarış): bekleyen sonuç "kaldı" olur.
func race_started() -> void:
	if not _pending.is_empty():
		_resolve(true, _now() - SaveSafe.i(_pending.get("t", 0)), true)


## Yarış bitti: olay ({c, a, p, w, pc, pt, rc, rt, o, lv}) kalış penceresini bekler.
func race_finished(event: Dictionary) -> void:
	if not _pending.is_empty():
		_resolve(true, _now() - SaveSafe.i(_pending.get("t", 0)), true)   # öncekinin ardından bir yarış daha bitti
	_pending = event.duplicate(true)
	_pending["t"] = _now()
	_save()


## Pencere doldu mu (saniyede bir).
func poll() -> void:
	if _pending.is_empty() or _paused_at >= 0:
		return
	var elapsed: int = _now() - SaveSafe.i(_pending.get("t", 0))
	if elapsed >= window():
		_resolve(true, window(), false)


func _notification(what: int) -> void:
	if not _io:
		return
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			_paused_at = _now()
			if not _pending.is_empty():
				_pending["left"] = _paused_at
				_save()
			upload()   # arka plana giderken: eklenti yazmayı sıraya alır, bağlantı gelince gider
		NOTIFICATION_APPLICATION_RESUMED:
			if _paused_at >= 0 and not _pending.is_empty():
				if _now() - _paused_at >= LEAVE_GRACE:
					_resolve_left()
				else:
					_pending.erase("left")   # kısa süre (bildirim, telefon): ayrılma sayılmaz
					_save()
			_paused_at = -1


## Önceki oturumdan / sahne yenilemeden kalan sonuç: ayrılma anı varsa ona göre karar, yoksa bekleme sürer.
func _resume_pending() -> void:
	if _pending.is_empty():
		return
	if _pending.has("left"):
		_resolve_left()
	elif _now() - SaveSafe.i(_pending.get("t", 0)) > window() + STALE_SEC:
		_pending.clear()   # ayrılma anı bilinmiyor (çökme) ve çok eski: sayılmaz
		_save()


func _resolve_left() -> void:
	var stayed_for: int = SaveSafe.i(_pending.get("left", 0)) - SaveSafe.i(_pending.get("t", 0))
	_resolve(stayed_for >= window(), stayed_for, false)


func _resolve(stayed: bool, seconds: int, next_race: bool) -> void:
	var event: Dictionary = _pending
	_pending = {}
	event.erase("left")
	event["s"] = stayed
	event["d"] = clampi(seconds, 0, window())
	event["n"] = next_race
	var arm: int = SaveSafe.i(event.get("a", -1))
	var context: String = SaveSafe.s(event.get("c", ""))
	if arm >= 0 and arm <= RivalSelector.Arm.HARD and CONTEXTS.has(context):
		var counts: Vector2i = cell(context, arm) + Vector2i(1 if stayed else 0, 1)
		var row: Dictionary = _counts.get(context, {}) if _counts.get(context) is Dictionary else {}
		row[str(arm)] = [counts.x, counts.y]
		_counts[context] = row
	var day: String = str(floori(SaveSafe.i(event.get("t", 0)) / 86400.0))
	var list: Array = _days.get(day, [])
	if list.size() < MAX_DAY_EVENTS:
		list.append(event)
		_days[day] = list
		_dirty[day] = true
	_prune()
	_save()
	changed.emit()
	if _upload_timer and _upload_timer.is_stopped():
		_upload_timer.start(UPLOAD_DELAY)


# --- Günlük yükleme ----------------------------------------------------------------

## Yazılmamış günleri sunucuya yazar (oturum yoksa — misafir — hiçbir şey gitmez).
func upload() -> void:
	if _uploading or not _io or not is_inside_tree():
		return
	var social: SocialManager = get_tree().get_first_node_in_group("social") as SocialManager
	if social == null or social.uid().is_empty():
		return
	_uploading = true
	var keys: Array = _dirty.keys()
	keys.sort()
	for key: Variant in keys:
		var events: Array = _days.get(key, [])
		var sent: int = events.size()
		if not await social.write_race_log(int(key), JSON.stringify(events), sent):
			continue   # kuralın kalıcı reddettiği gün (cihaz saati kaymış) sonraki günleri tıkamasın
		if (_days.get(key, []) as Array).size() == sent:
			_dirty.erase(key)   # yazarken yeni olay geldiyse gün kirli kalır
	_uploading = false
	_save()


## Bugünden UPLOAD_DAYS günden eski günler atılır (kural kabul etmez; kişisel sayılar zaten kayıtta).
func _prune() -> void:
	var oldest: int = _today() - UPLOAD_DAYS
	for key: Variant in _days.keys():
		if int(key) < oldest:
			_days.erase(key)
			_dirty.erase(key)


# --- Kayıt / dosya -----------------------------------------------------------------

## Kişisel sayılar (RaceManager kaydı "learn").
func counts_state() -> Dictionary:
	return _counts.duplicate(true)


func load_counts(data: Variant) -> void:
	_counts.clear()
	if not data is Dictionary:
		return
	for context: String in CONTEXTS:
		var row: Variant = (data as Dictionary).get(context, {})
		if not row is Dictionary:
			continue
		var clean: Dictionary = {}
		for arm: int in 3:
			var raw: Variant = (row as Dictionary).get(str(arm), [])
			if raw is Array and (raw as Array).size() == 2:
				var trials: int = clampi(SaveSafe.i(raw[1]), 0, 1000000)
				clean[str(arm)] = [clampi(SaveSafe.i(raw[0]), 0, trials), trials]
		if not clean.is_empty():
			_counts[context] = clean


## Bekleyen sonuç ve günün olayları (testler).
func pending() -> Dictionary:
	return _pending.duplicate(true)


func day_events(day: int) -> Array:
	return (_days.get(str(day), []) as Array).duplicate(true)


func is_dirty(day: int) -> bool:
	return _dirty.has(str(day))


func _load_file() -> void:
	if not FileAccess.file_exists(FILE):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not parsed is Dictionary:
		return
	var data: Dictionary = parsed
	_pending = data.get("pending", {}) if data.get("pending") is Dictionary else {}
	_days.clear()
	if data.get("days") is Dictionary:
		for key: Variant in data["days"]:
			if str(key).is_valid_int() and data["days"][key] is Array:
				_days[str(key)] = (data["days"][key] as Array).slice(0, MAX_DAY_EVENTS)
	_dirty.clear()
	if data.get("dirty") is Array:
		for key: Variant in data["dirty"]:
			if _days.has(str(key)):
				_dirty[str(key)] = true
	_prune()


func _save() -> void:
	if not _io:
		return
	var file: FileAccess = FileAccess.open(FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"pending": _pending, "days": _days, "dirty": _dirty.keys()}))


func _now() -> int:
	return now_override if now_override >= 0 else int(Time.get_unix_time_from_system())


func _today() -> int:
	return floori(_now() / 86400.0)


# --- Yardımcılar -------------------------------------------------------------------

## ZOR sınırı: son iki yarış ZOR'du ya da son HARD_WINDOW yarışta ZOR payı HARD_SHARE'e ulaştı.
static func _hard_capped(history: Array) -> bool:
	var n: int = history.size()
	if n >= 2 and _arm_of(history[n - 1]) == RivalSelector.Arm.HARD and _arm_of(history[n - 2]) == RivalSelector.Arm.HARD:
		return true
	var hard: int = 0
	for entry: Variant in history.slice(-HARD_WINDOW):
		if _arm_of(entry) == RivalSelector.Arm.HARD:
			hard += 1
	return float(hard) >= HARD_SHARE * float(HARD_WINDOW)


static func _letter(entry: Variant) -> String:
	return "W" if entry is Dictionary and SaveSafe.b((entry as Dictionary).get("w", false)) else "L"


static func _arm_of(entry: Variant) -> int:
	return SaveSafe.i((entry as Dictionary).get("a", -1)) if entry is Dictionary else -1


## Beta(a, b) örneği (iki Gamma örneğinin oranı).
static func beta(a: float, b: float, rng: RandomNumberGenerator) -> float:
	var x: float = gamma(maxf(a, 0.01), rng)
	var y: float = gamma(maxf(b, 0.01), rng)
	return x / maxf(x + y, 1e-12)


## Gamma(k, 1) örneği — Marsaglia–Tsang; k < 1 için k + 1'den yükseltilir.
static func gamma(k: float, rng: RandomNumberGenerator) -> float:
	if k < 1.0:
		return gamma(k + 1.0, rng) * pow(maxf(rng.randf(), 1e-12), 1.0 / k)
	var d: float = k - 1.0 / 3.0
	var c: float = 1.0 / sqrt(9.0 * d)
	for i: int in 64:
		var x: float = rng.randfn(0.0, 1.0)
		var v: float = 1.0 + c * x
		if v <= 0.0:
			continue
		v = v * v * v
		var u: float = maxf(rng.randf(), 1e-12)
		if u < 1.0 - 0.0331 * x * x * x * x or log(u) < 0.5 * x * x + d * (1.0 - v + log(v)):
			return d * v
	return d   # olasılığı ihmal edilebilir: ortalama
