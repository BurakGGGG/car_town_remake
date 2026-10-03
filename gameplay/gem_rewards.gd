class_name GemRewards
extends Node
## TEKRARLAYAN GEM KAYNAKLARI — günlük giriş serisi, tamir bahşişi ve ustalık yıldızı gemi. Tasarım ve
## simülasyon: docs/vehicle_crate_design_v2.md §3. GÜNLÜK / HAFTALIK GÖREVLER ve tamir kilometre taşları
## artık GÖREVLER sistemindedir (gameplay/missions/, docs/gorevler_tasarimi.md); bu sınıf gün / hafta
## SAATİNİN tek kaynağı olarak kalır (MissionManager buradan okur).
## Seviye gemi PlayerProgress.LEVEL_REWARDS'ta, keşif / koleksiyon / kopya gemi CrateManager'dadır.
## "gem_rewards" grubundan bulunur (GarageSystem kodla kurar). Gem PlayerProgress.add_gems ile verilir.
##
## YENİ SAYAÇ KURMAZ: tamir → RepairManager.repair_collected, ustalık → JobMastery.mastery_up.
##
## SAAT GÜVENLİĞİ (cihaz saati oyuncunun elinde, sunucu saati yok):
##   * Gün, yerel tarihin epoch'tan gün numarasıdır ve kayıtta yalnızca İLERİ gider. Saat geri
##     alınırsa (gün < kayıttaki gün) hiçbir günlük ödül verilmez, görevler sıfırlanmaz, sayaçlar
##     kayıttaki güne yazılmaya devam eder. Gerçek saat kayıttaki güne yetişene kadar yeni ödül yok.
##   * Saat ileri alınırsa yalnızca O GÜNÜN ödülü alınır (kaçırılan günler telafi edilmez) ve seri
##     bozulur (gün farkı 1 değilse seri 1'e döner). Geri dönülünce yukarıdaki kural kilitler:
##     ileri almanın kazancı, gerçek zamanda o günler kaybedilerek geri ödenir.
##   * Her ödül (giriş, görev, bonus, haftalık) kayıtta işaretlidir: aynı gün / hafta iki kez verilmez.
##     İşaretler gemle aynı kayıt dosyasındadır; eski bir kayda dönmek gemleri de geri alır.

signal reward_granted(amount: int, text: String)
## Seri değişti (UI tazelensin).
signal daily_changed
## Yeni güne geçildi (yalnızca ileri; MissionManager yeni görevleri kurar).
signal day_changed(day: int)

const LOGIN_CYCLE: Array[int] = [10, 10, 15, 10, 15, 10, 40]
const TIP_EVERY: int = 20
const TIP_DAILY_CAP: int = 40
const MASTERY_STAR_GEMS: int = 10
## Saatin "geri alındı" sayılması için tolerans (sn).
const ROLLBACK_TOLERANCE: int = 600

## Test: -1 değilse sistem saati yerine bu unix zamanı kullanılır.
var test_now: int = -1

var _login_day: int = -1
var _streak: int = 0
var _max_seen: int = 0
var _day: int = -1
var _tip_day: int = -1
var _tip_count: int = 0
var _tip_carry: int = 0
var _repair_step: int = 0   # ESKİ tamir kilometre taşı sayısı (başarıma göç için; artık ödenmez)
var _clock_rolled_back: bool = false
var _timer: Timer


func _ready() -> void:
	add_to_group("gem_rewards")
	_timer = Timer.new()
	_timer.wait_time = 30.0
	_timer.timeout.connect(check_day)
	add_child(_timer)
	_timer.start()
	_connect.call_deferred()


func _connect() -> void:
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repairs:
		repairs.repair_collected.connect(_on_repair_collected)
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(_id: StringName, _stars: int) -> void:
			_grant(MASTERY_STAR_GEMS, "USTALIK YILDIZI  +%d GEM" % MASTERY_STAR_GEMS))
	# Kayıt yüklemesi SaveManager'ın ertelenmiş kurulumunda olur; ilk gün kontrolü ondan sonra.
	get_tree().create_timer(1.0).timeout.connect(check_day)


# --- Saat ----------------------------------------------------------------------------

func now_unix() -> int:
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


## Yerel tarihin epoch'tan gün numarası.
func day_key(unix: int) -> int:
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias_min * 60) / 86400.0)


## Pazartesi başlayan hafta numarası (epoch günü 0 Perşembe'dir).
static func week_key(day: int) -> int:
	return floori(float(day + 3) / 7.0)


func is_clock_rolled_back() -> bool:
	return _clock_rolled_back


## Gün değişimini işler: giriş ödülü, görev sıfırlama, hafta sıfırlama. Tekrar çağrılması güvenlidir.
func check_day() -> void:
	var now: int = now_unix()
	_clock_rolled_back = now < _max_seen - ROLLBACK_TOLERANCE
	_max_seen = maxi(_max_seen, now)
	var today: int = day_key(now)
	if today > _day:   # yalnızca ileri: saat geri alınırsa gün ilerlemez
		_day = today
		day_changed.emit(today)
	if today > _login_day:
		_streak = _streak + 1 if today == _login_day + 1 else 1
		_login_day = today
		var gems: int = login_gems(_streak)
		_grant(gems, "GÜNLÜK GİRİŞ  %d. GÜN\n+%d GEM" % [_streak, gems])
		daily_changed.emit()
	_request_save()


## Serinin n. günündeki giriş ödülü (7 günlük döngü).
static func login_gems(streak: int) -> int:
	return LOGIN_CYCLE[(maxi(streak, 1) - 1) % LOGIN_CYCLE.size()]


func streak() -> int:
	return _streak


# --- Tamir: bahşiş ------------------------------------------------------

func _on_repair_collected(_car: Node3D, _reward: int, _xp: int) -> void:
	var today: int = maxi(day_key(now_unix()), _day)
	if today != _tip_day:
		_tip_day = today
		_tip_count = 0
	_tip_carry += 1
	if _tip_carry >= TIP_EVERY:
		_tip_carry -= TIP_EVERY
		if _tip_count < TIP_DAILY_CAP:
			_tip_count += 1
			_grant(1, "")   # bahşiş sessizdir (sık gelir); gem plakası artışı gösterir


## Eski kayıttaki ödenmiş tamir kilometre taşı sayısı (TAMİRCİ başarımına göç: MissionManager okur).
func legacy_repair_step() -> int:
	return _repair_step


# --- Kayıt ---------------------------------------------------------------------------------

func state() -> Dictionary:
	return {
		"login": {"day": _login_day, "streak": _streak},
		"max_seen": _max_seen,
		"day": _day,
		"tips": {"day": _tip_day, "count": _tip_count, "carry": _tip_carry},
		"repair_step": _repair_step,
	}


func load_state(data: Dictionary) -> void:
	var login: Dictionary = data.get("login", {}) if data.get("login") is Dictionary else {}
	_login_day = SaveSafe.i(login.get("day", -1))
	_streak = maxi(SaveSafe.i(login.get("streak", 0)), 0)
	_max_seen = maxi(SaveSafe.i(data.get("max_seen", 0)), 0)
	# Eski kayıt: günlük görev bölümündeki gün (geriye dönük uyum); yeni kayıt "day" yazar
	var legacy: Dictionary = data.get("daily", {}) if data.get("daily") is Dictionary else {}
	_day = SaveSafe.i(data.get("day", legacy.get("day", -1)))
	var tips: Dictionary = data.get("tips", {}) if data.get("tips") is Dictionary else {}
	_tip_day = SaveSafe.i(tips.get("day", -1))
	_tip_count = clampi(SaveSafe.i(tips.get("count", 0)), 0, TIP_DAILY_CAP)
	_tip_carry = clampi(SaveSafe.i(tips.get("carry", 0)), 0, TIP_EVERY - 1)
	_repair_step = clampi(SaveSafe.i(data.get("repair_step", 0)), 0, 5)
	daily_changed.emit()


## Yeni oyun: seri ve görevler sıfırdan (ilk check_day bugünün girişini verir).
func reset() -> void:
	load_state({})
	check_day.call_deferred()


# --- İç ----------------------------------------------------------------------------------

func _grant(amount: int, text: String) -> void:
	if amount <= 0:
		return
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if progress:
		progress.add_gems(amount)
	reward_granted.emit(amount, text)


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
