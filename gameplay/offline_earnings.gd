class_name OfflineEarnings
extends Node
## PASİF GELİR — "garaj patronsuz da çalışır" (2026-10-17, kullanıcıyla soru-cevapla karar; bkz. docs/OTO_MANSET.md).
## Oyuncu yokken tamir alanları müşteri almaya devam eder. Kazanç ölçülmüş AKTİF gelirin 1/16'sıdır: 8 saatlik yokluk
## ≈ 30 dakikalık oyun (kullanıcı: "yarı hız" önerim ölçümle çok cömert çıktı, geç oyunda gecede ~600.000 ₺). Aktif gelir
## garaj seviyesi × açık tamir alanı × tamir hızı tablosundan (docs/PROGRESSION_REFACTOR.md §8). YALNIZ PARA: XP,
## ustalık, görev sayılmaz. Birikim KASADA bekler (CAP_MINUTES = 8 saat dolunca durur) ve oyuna girişteki gazetede
## (OTO MANŞET, NewsFlow) TAMAM'da sayaca uçar. 30 dk'dan kısa aralarda kasa sessizce büyür, sonraki gazetede çıkar.
## YARIM KALAN TAMİRLER (RepairManager): oyun kapanırken alandaki işler kayda girer; açılışta sen yokken bitenler tam
## ödül + XP ile kasaya, bitmeyenler alana geri kurulur. Uygulama arka plandayken sayaçlar geçen süre kadar ilerler;
## LONG_AWAY'den uzun aradan dönülünce bitip ₺ balonu bekleyenler de kasaya toplanır.
## SAAT: Firebase eklentisinde sunucu saati okunamıyor → Google'ın HTTPS cevabındaki Date başlığı (kullanıcı kararı
## "sunucu saati"). Oyun içinde süre ondan + monoton sayaçtan yürür (cihaz saatini oynatmak işe yaramaz); internet yoksa
## cihaz saati, geri alınmışsa yokluk 0 sayılır. Usta, temel ders (Rıza Usta'nın ilk dersi) bitmeden çalışmaz.
## Kayıt: SaveManager "away" bölümü (state / load_state). GarageSystem kodla kurar (ziyarette kurulmaz).

## Yokluk işlendi: açılışta (cold) ve her arka plan dönüşünde. NewsFlow açılışta ve LONG_AWAY'den uzun dönüşte gazete
## toplar (haber yoksa açılmaz).
signal away_resolved(cold: bool, seconds: int)

## Ölçülmüş aktif gelir (₺/dk): [garaj seviyesi][açık alan - 1], orta işler AÇIKKEN (oyuncu sv. 5+). Ölçüm 2026-09-26.
const ACTIVE_RATE: Array = [[372, 372, 372], [626, 991, 1258], [1008, 1234, 1666], [1441, 1441, 1877]]
## Yalnız kısa işler açıkken (orta iş yok): alan sayısı geliri değiştirmiyor, garaj seviyesi değiştiriyor.
const EARLY_RATE: Array = [372, 626, 1008, 1441]
## Tamir hızı 5. seviyede (süre ×0,6) geç oyun geliri +%48 ölçüldü; aradaki seviyeler süre çarpanıyla orantılı.
const SPEED_GAIN_AT_MAX: float = 0.48
const SPEED_MAX_MULTIPLIER: float = 0.6
## Pasif gelir aktifin bu kadarı (8 saat ≈ 30 dk oyun).
const OFFLINE_SHARE: float = 1.0 / 16.0
## Kasa en çok bu kadar dakikalık kazanç biriktirir (8 saat; sonra "kepenk iner").
const CAP_MINUTES: float = 480.0
## Bundan kısa birikim gazetede haber olmaz (kasa büyümeye devam eder).
const MIN_NEWS_MINUTES: float = 10.0
## Arka plandan bu kadar uzun aradan dönülünce gazete çıkar (kullanıcı kararı: 30 dk).
const LONG_AWAY: int = 1800
## Orta iş sayılan en kısa tamir süresi (sn): tablonun hangi sütunu kullanılacağı.
const MEDIUM_JOB: float = 60.0

const TIME_URL: String = "https://www.google.com/generate_204"
const TIME_TIMEOUT: float = 4.0
const MONTHS: Array[String] = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

## Testler ağa çıkmasın (cihaz saati kullanılır).
var use_network: bool = true
## Testler için "şimdi" (unix sn); 0 = gerçek saat.
var test_now: int = 0

## Son etkin an (unix sn): oyuncu bu andan beri yok. Kayda her yazımda o anın saati gider.
var last_seen: int = 0
## Kasa: gazetede henüz gösterilmemiş usta kazancı, kaç dakikalık olduğu ve kaç araç sayıldığı.
var bank_money: int = 0
var bank_minutes: float = 0.0
var bank_jobs: int = 0
## Kasa 8 saati doldurdu (bir sonraki gazetede "kepenk indi" yazar).
var full: bool = false
## Sen yokken biten yarım işler: [{type, reward, xp}] (ödülleri gazetede verilir).
var finished: Array[Dictionary] = []
## Gazetenin sayısı (OTO MANŞET "SAYI n").
var issue: int = 0
## Rıza Usta'nın tek seferlik açıklamaları: ilk kazanç, ilk kez 8 saat dolması.
var told_first: bool = false
var told_full: bool = false

## Son yokluğun aralığı (unix sn): o arada dolan hurda yığını / biten modifiye / yenilenen görev gazeteye girer.
## Kayda girmez; gazete gösterilince sıfırlanır.
var window_from: int = 0
var window_to: int = 0

var _resolved: bool = false   # yokluk hesaplanmadan kayda "şimdi" yazılmaz (yokluk silinirdi)
var _anchor_unix: int = 0     # sunucu saati (unix sn) ...
var _anchor_ticks: int = 0    # ... ve o anki monoton sayaç (ms)
var _http: HTTPRequest
var _shown: Dictionary = {}   # gazetede gösterilen pay (TAMAM'da yalnız bu verilir)
var _syncing: bool = false


func _ready() -> void:
	name = "OfflineEarnings"
	add_to_group("offline_earnings")
	if OS.get_environment("CT_NO_NET") == "1":
		use_network = false   # testler ağa çıkmaz
	_http = HTTPRequest.new()
	_http.timeout = TIME_TIMEOUT
	add_child(_http)
	_boot.call_deferred()


## Açılış: kayıt yüklensin, saat alınsın; sonra yokluk hesaplanır (yarım işler + kasa).
func _boot() -> void:
	for i: int in 2:
		await get_tree().process_frame   # SaveManager ertelenmiş _setup'ında kaydı yükler
	await _sync_time()
	_resolve(_away_seconds(now()), true)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED:
			if _resolved:
				last_seen = now()
				_save_now()   # uygulama arka planda öldürülebilir: çıkış anı diske yazılsın
		NOTIFICATION_APPLICATION_RESUMED:
			_resume()
		NOTIFICATION_WM_CLOSE_REQUEST:
			if _resolved:
				last_seen = now()
				_save_now()


func _resume() -> void:
	if not _resolved or _syncing:
		return
	_resolved = false
	_anchor_unix = 0   # arka planda monoton sayaç güvenilmez: saat yeniden alınır
	await _sync_time()
	_resolve(_away_seconds(now()), false)


## Yokluğu işler: yarım işler (açılışta kayıttan, dönüşte alandakiler), kasa, son görülme; haber varsa news_ready.
func _resolve(away: int, cold: bool) -> void:
	var repairs: RepairManager = _repairs()
	if repairs:
		if cold:
			finished.append_array(repairs.resume_saved_jobs(float(away)))
		else:
			repairs.advance_all(float(away))
			if away >= LONG_AWAY:
				finished.append_array(repairs.settle_finished())
	accrue(away)
	var at: int = now()
	if away > 0 and (cold or away >= LONG_AWAY):
		window_from = last_seen if window_from <= 0 else mini(window_from, last_seen)
		window_to = at
	last_seen = at
	_resolved = true
	_request_save()
	away_resolved.emit(cold, away)


func is_resolved() -> bool:
	return _resolved


## Gazete gösterildi: yokluk aralığı tüketildi.
func clear_window() -> void:
	window_from = 0
	window_to = 0


## Yokluk süresi kadar kasaya kazanç ekler (8 saat sınırına kadar). Temel ders bitmediyse usta çalışmaz.
func accrue(seconds: int) -> void:
	if seconds <= 0 or not _working():
		return
	var room: float = maxf(CAP_MINUTES - bank_minutes, 0.0)
	var minutes: float = minf(float(seconds) / 60.0, room)
	if minutes <= 0.0:
		full = true
		return
	bank_money += int(round(minutes * offline_rate()))
	bank_minutes += minutes
	bank_jobs = maxi(int(round(float(bank_money) / maxf(average_job_reward(), 1.0))), 1)
	if bank_minutes >= CAP_MINUTES - 0.01:
		full = true


## Gazetede haber olacak bir şey var mı.
func has_news() -> bool:
	return bank_minutes >= MIN_NEWS_MINUTES or not finished.is_empty()


## Gazetenin kazanç haberi (NewsDigest.EARNINGS). Gösterilen pay saklanır: TAMAM'da yalnız o verilir (gazete açıkken
## biriken yeni kazanç sonraki gazeteye kalır).
func news_items() -> Array[Dictionary]:
	if not has_news():
		return []
	var show_bank: bool = bank_minutes >= MIN_NEWS_MINUTES
	var finished_money: int = 0
	var finished_xp: int = 0
	for job: Dictionary in finished:
		finished_money += int(job.get("reward", 0))
		finished_xp += int(job.get("xp", 0))
	_shown = {"bank_money": bank_money if show_bank else 0, "bank_minutes": bank_minutes if show_bank else 0.0,
		"bank_jobs": bank_jobs if show_bank else 0, "full": full and show_bank, "finished": finished.duplicate(true),
		"money": (bank_money if show_bank else 0) + finished_money, "xp": finished_xp}
	return [{"kind": NewsDigest.EARNINGS, "money": int(_shown["money"]), "jobs": int(_shown["bank_jobs"]),
		"minutes": int(_shown["bank_minutes"]), "full": bool(_shown["full"]), "finished": finished.size(),
		"finished_money": finished_money, "finished_xp": finished_xp}]


## Gazetenin vereceği para (HUD sayacı uçuş bitene dek bunu bekletir).
func shown_money() -> int:
	return int(_shown.get("money", 0))


## Gazete şimdi açılsa gösterilecek kazanç (₺; news_items gibi ama yan etkisiz). NewsFlow ×2 reklamını beklerken bakar.
func pending_money() -> int:
	if not has_news():
		return 0
	var money: int = bank_money if bank_minutes >= MIN_NEWS_MINUTES else 0
	for job: Dictionary in finished:
		money += int(job.get("reward", 0))
	return money


## TAMAM: gösterilen pay verilir (para + yarım işlerin XP'si ve ustalık sayacı), kasadan düşülür, kayıt HEMEN yazılır
## (gazete açıkken uygulama kapanırsa ödeme ya hiç yapılmamış ya da bir kez yapılmıştır). {money, xp, bank, full}.
## money_mult: gazetede ödüllü reklam izlendiyse 2 (yalnız para katlanır).
func collect(money_mult: int = 1) -> Dictionary:
	if _shown.is_empty():
		return {}
	var shown: Dictionary = _shown
	_shown = {}
	var paid: int = int(shown["money"]) * clampi(money_mult, 1, 2)
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.add_money(paid)
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		progress.add_xp(int(shown["xp"]))
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	for job: Dictionary in shown["finished"]:
		if mastery:
			mastery.record(StringName(job.get("type", &"")))
		finished.erase(job)
	var paid_minutes: float = float(shown["bank_minutes"])
	if paid_minutes > 0.0:
		bank_money = maxi(bank_money - int(shown["bank_money"]), 0)
		bank_minutes = maxf(bank_minutes - paid_minutes, 0.0)
		bank_jobs = maxi(bank_jobs - int(shown["bank_jobs"]), 0)
		full = full and bank_minutes >= CAP_MINUTES - 0.01
	_save_now()
	return {"money": paid, "xp": int(shown["xp"]), "bank": paid_minutes > 0.0, "full": bool(shown["full"])}


## Gazetenin bir sonraki sayısı (açılırken çağrılır, kayda girer).
func next_issue() -> int:
	issue += 1
	_request_save()
	return issue


# --- Oran -------------------------------------------------------------------------------------------

## Şu anki garajın pasif geliri (₺/dk).
func offline_rate() -> float:
	return current_active_rate() * OFFLINE_SHARE


## Şu anki garajın ölçülmüş AKTİF geliri (₺/dk): garaj seviyesi, açık alan, tamir hızı, orta işler. Günlük giriş merdiveninin
## para ödülleri de buna bağlıdır (LoginLadder: "kaç dakikalık oyun geliri").
func current_active_rate() -> float:
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	return active_rate(upgrades.garage_level() if upgrades else 1, bays.unlocked_count() if bays else 1,
		upgrades.repair_speed_multiplier() if upgrades else 1.0, _medium_jobs())


## Ölçülmüş aktif gelir (₺/dk). `speed`: tamir süresi çarpanı (1,0 … 0,6).
static func active_rate(garage: int, bays: int, speed: float, medium_jobs: bool) -> float:
	var g: int = clampi(garage, 1, ACTIVE_RATE.size()) - 1
	var base: float = float(ACTIVE_RATE[g][clampi(bays, 1, 3) - 1]) if medium_jobs else float(EARLY_RATE[g])
	var faster: float = clampf((1.0 / maxf(speed, 0.1) - 1.0) / (1.0 / SPEED_MAX_MULTIPLIER - 1.0), 0.0, 1.0)
	return base * (1.0 + SPEED_GAIN_AT_MAX * faster)


## Açık işlerin ortalama ödülü (garaj seviyesinin müşteri çarpanıyla): kazancın "kaç araç" sayısı buradan.
func average_job_reward() -> float:
	var repairs: RepairManager = _repairs()
	if repairs == null:
		return 150.0
	var types: Array[RepairType] = repairs.unlocked_types(_player_level())
	if types.is_empty():
		return 150.0
	var total: float = 0.0
	for type: RepairType in types:
		total += float(type.reward)
	return total / float(types.size()) * repairs.reward_multiplier()


func _medium_jobs() -> bool:
	var repairs: RepairManager = _repairs()
	if repairs == null:
		return false
	for type: RepairType in repairs.unlocked_types(_player_level()):
		if type.duration >= MEDIUM_JOB:
			return true
	return false


func _working() -> bool:
	var tutorial: TutorialManager = get_tree().get_first_node_in_group("tutorial") as TutorialManager
	return tutorial == null or tutorial.is_done(TutorialManager.BASICS)


# --- Saat ---------------------------------------------------------------------------------------------

## Güvenilir "şimdi" (unix sn): sunucu saati alındıysa ondan + monoton sayaçtan, yoksa cihaz saati.
func now() -> int:
	if test_now > 0:
		return test_now
	if _anchor_unix > 0:
		return _anchor_unix + int((Time.get_ticks_msec() - _anchor_ticks) / 1000)
	return int(Time.get_unix_time_from_system())


func is_trusted() -> bool:
	return _anchor_unix > 0


## Son görülmeden bu yana geçen süre. Saat geri alınmışsa (ya da kayıt yoksa) 0.
func _away_seconds(at: int) -> int:
	if last_seen <= 0:
		return 0
	return maxi(at - last_seen, 0)


## Google'ın HTTPS cevabının Date başlığı → sunucu saati (TIME_TIMEOUT'ta vazgeçilir, cihaz saatine düşülür).
func _sync_time() -> void:
	if not use_network or test_now > 0 or _syncing:
		return
	_syncing = true
	if _http.request(TIME_URL, PackedStringArray(), HTTPClient.METHOD_HEAD) == OK:
		var result: Array = await _http.request_completed
		var stamp: int = 0
		if int(result[0]) == HTTPRequest.RESULT_SUCCESS:
			for header: String in result[2] as PackedStringArray:
				if header.to_lower().begins_with("date:"):
					stamp = parse_http_date(header.substr(5).strip_edges())
		if stamp > 0:
			_anchor_unix = stamp
			_anchor_ticks = Time.get_ticks_msec()
	_syncing = false


## RFC 1123 tarihi ("Sat, 17 Oct 2026 14:52:03 GMT") → unix sn (UTC). Okunamazsa 0.
static func parse_http_date(text: String) -> int:
	var parts: PackedStringArray = text.replace(",", " ").split(" ", false)
	if parts.size() < 5:
		return 0
	var month: int = MONTHS.find(parts[2].substr(0, 3).capitalize()) + 1
	var clock: PackedStringArray = parts[4].split(":")
	if month <= 0 or clock.size() != 3 or not parts[1].is_valid_int() or not parts[3].is_valid_int():
		return 0
	return Time.get_unix_time_from_datetime_dict({"year": int(parts[3]), "month": month, "day": int(parts[1]),
		"hour": int(clock[0]), "minute": int(clock[1]), "second": int(clock[2])})


# --- Kayıt --------------------------------------------------------------------------------------------

func state() -> Dictionary:
	return {
		"last_seen": now() if _resolved else last_seen,
		"bank": {"money": bank_money, "minutes": snappedf(bank_minutes, 0.01), "jobs": bank_jobs, "full": full},
		"finished": finished.duplicate(true),
		"issue": issue,
		"told": {"first": told_first, "full": told_full},
	}


func load_state(data: Dictionary) -> void:
	last_seen = maxi(SaveSafe.i(data.get("last_seen", 0)), 0)
	var bank: Dictionary = data.get("bank", {}) if data.get("bank") is Dictionary else {}
	bank_money = maxi(SaveSafe.i(bank.get("money", 0)), 0)
	bank_minutes = clampf(SaveSafe.f(bank.get("minutes", 0.0)), 0.0, CAP_MINUTES)
	bank_jobs = maxi(SaveSafe.i(bank.get("jobs", 0)), 0)
	full = SaveSafe.b(bank.get("full", false))
	finished = []
	for raw: Variant in data.get("finished", []) if data.get("finished") is Array else []:
		if raw is Dictionary and RepairType.by_id(StringName(SaveSafe.s((raw as Dictionary).get("type", "")))) != null:
			finished.append({"type": SaveSafe.s(raw["type"]), "reward": maxi(SaveSafe.i(raw.get("reward", 0)), 0),
				"xp": maxi(SaveSafe.i(raw.get("xp", 0)), 0)})
	issue = maxi(SaveSafe.i(data.get("issue", 0)), 0)
	var told: Dictionary = data.get("told", {}) if data.get("told") is Dictionary else {}
	told_first = SaveSafe.b(told.get("first", false))
	told_full = SaveSafe.b(told.get("full", false))
	_shown = {}


func reset() -> void:
	load_state({})


## Kayıt kısa süre sonra yazılsın (Rıza Usta'nın açıklaması gösterildi gibi küçük değişiklikler).
func save_soon() -> void:
	_request_save()


func _save_now() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.save_game()


func _request_save() -> void:
	var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
	if save:
		save.request_save()


func _repairs() -> RepairManager:
	return get_tree().get_first_node_in_group("repair_manager") as RepairManager


func _player_level() -> int:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	return progress.level if progress else 1
