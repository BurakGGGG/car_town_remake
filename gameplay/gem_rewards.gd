class_name GemRewards
extends Node
## TEKRARLAYAN GEM KAYNAKLARI — günlük giriş serisi, günlük görevler, haftalık hedef, tamir bahşişi,
## tamir kilometre taşları ve ustalık yıldızı gemi. Tasarım ve simülasyon: docs/vehicle_crate_design_v2.md §3.
## Seviye gemi PlayerProgress.LEVEL_REWARDS'ta, keşif / koleksiyon / kopya gemi CrateManager'dadır.
## "gem_rewards" grubundan bulunur (GarageSystem kodla kurar). Gem PlayerProgress.add_gems ile verilir.
##
## YENİ SAYAÇ KURMAZ: tamir → RepairManager.repair_collected, yarış → RaceManager.race_finished,
## ustalık → JobMastery.mastery_up, toplam tamir sayısı → JobMastery sayaçlarının toplamı.
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
## Günlük görevler / seri değişti (UI tazelensin).
signal daily_changed

const LOGIN_CYCLE: Array[int] = [10, 10, 15, 10, 15, 10, 40]
const TASK_GEMS: int = 10
const ALL_TASKS_BONUS: int = 20
const WEEKLY_GEMS: int = 100
## Haftalık hedef: haftada tamamlanan günlük görev sayısı.
const WEEKLY_NEED: int = 12
## Günlük görevler bu seviyeden sonra açılır.
const TASK_MIN_LEVEL: int = 3
const TIP_EVERY: int = 20
const TIP_DAILY_CAP: int = 40
const MASTERY_STAR_GEMS: int = 10
## Toplam tamir → gem (tek seferlik).
const REPAIR_MILESTONES: Array[Vector2i] = [
	Vector2i(50, 10), Vector2i(250, 20), Vector2i(1000, 30), Vector2i(2500, 50), Vector2i(5000, 75)]
## Saatin "geri alındı" sayılması için tolerans (sn).
const ROLLBACK_TOLERANCE: int = 600

## Günlük görev türleri: her gün her türden bir görev, hedef gün numarasından türetilir.
const TASKS: Array[Dictionary] = [
	{"type": &"repairs", "targets": [10, 15, 20], "text": "%s TAMİR YAP"},
	{"type": &"repair_money", "targets": [1500, 3000, 5000], "text": "TAMİRDEN %s ₺ KAZAN"},
	{"type": &"races", "targets": [1, 2, 3], "text": "%s YARIŞA KATIL"},
]

## Test: -1 değilse sistem saati yerine bu unix zamanı kullanılır.
var test_now: int = -1

var _login_day: int = -1
var _streak: int = 0
var _max_seen: int = 0
var _day: int = -1
var _progress_by_task: Dictionary = {}   # tür → sayaç
var _done: Array[StringName] = []
var _bonus_paid: bool = false
var _week: int = -1
var _week_count: int = 0
var _week_paid: bool = false
var _tip_day: int = -1
var _tip_count: int = 0
var _tip_carry: int = 0
var _repair_step: int = 0
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
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race:
		race.race_finished.connect(func(_won: bool, _m: int, _xp: int) -> void: _count(&"races", 1))
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(_id: StringName, _stars: int) -> void:
			_grant(MASTERY_STAR_GEMS, "USTALIK YILDIZI  +%d GEM" % MASTERY_STAR_GEMS))
	# Kayıt yüklemesi SaveManager'ın ertelenmiş kurulumunda olur; ilk gün kontrolü ondan sonra.
	get_tree().create_timer(1.0).timeout.connect(func() -> void:
		check_day()
		check_repair_milestones())


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
	if today > _day:   # yalnızca ileri: saat geri alınırsa görevler sıfırlanmaz
		_day = today
		_progress_by_task.clear()
		_done.clear()
		_bonus_paid = false
		daily_changed.emit()
	var week: int = week_key(maxi(today, _day))
	if week > _week:
		_week = week
		_week_count = 0
		_week_paid = false
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


# --- Günlük görevler -------------------------------------------------------------------

## Bugünün görevleri: [{"type", "target", "progress", "done", "text"}]. Seviye yetmiyorsa boş.
func daily_tasks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not tasks_unlocked():
		return out
	for i: int in TASKS.size():
		var def: Dictionary = TASKS[i]
		var type: StringName = def["type"]
		var target: int = task_target(i, _day)
		var shown: String = Hud.format_thousands(target) if type == &"repair_money" else str(target)
		out.append({"type": type, "target": target, "progress": mini(int(_progress_by_task.get(type, 0)), target),
			"done": _done.has(type), "text": String(def["text"]) % shown})
	return out


## Görev hedefi gün numarasından türetilir (aynı gün hep aynı hedef; kayda yazılmaz).
static func task_target(index: int, day: int) -> int:
	var targets: Array = TASKS[index]["targets"]
	return int(targets[posmod(day * 7 + index * 3, targets.size())])


func tasks_unlocked() -> bool:
	var progress: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	return progress == null or progress.level >= TASK_MIN_LEVEL


func week_progress() -> Vector2i:
	return Vector2i(_week_count, WEEKLY_NEED)


func _count(type: StringName, amount: int) -> void:
	if amount <= 0 or _day < 0 or not tasks_unlocked():
		return
	_progress_by_task[type] = int(_progress_by_task.get(type, 0)) + amount
	for i: int in TASKS.size():
		if TASKS[i]["type"] != type or _done.has(type):
			continue
		if int(_progress_by_task[type]) >= task_target(i, _day):
			_done.append(type)
			_grant(TASK_GEMS, "GÜNLÜK GÖREV TAMAM\n+%d GEM" % TASK_GEMS)
			_week_count += 1
			if _done.size() >= TASKS.size() and not _bonus_paid:
				_bonus_paid = true
				_grant(ALL_TASKS_BONUS, "BÜTÜN GÜNLÜK GÖREVLER\n+%d GEM" % ALL_TASKS_BONUS)
			if _week_count >= WEEKLY_NEED and not _week_paid:
				_week_paid = true
				_grant(WEEKLY_GEMS, "HAFTALIK HEDEF\n+%d GEM" % WEEKLY_GEMS)
	daily_changed.emit()
	_request_save()


# --- Tamir: bahşiş ve kilometre taşı ------------------------------------------------------

func _on_repair_collected(_car: Node3D, reward: int, _xp: int) -> void:
	_count(&"repairs", 1)
	_count(&"repair_money", reward)
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
	check_repair_milestones()


## Toplam tamir (JobMastery sayaçları) kilometre taşlarını öder.
func check_repair_milestones() -> void:
	var total: int = _total_repairs()
	if total < 0:
		return
	while _repair_step < REPAIR_MILESTONES.size() and total >= REPAIR_MILESTONES[_repair_step].x:
		var gems: int = REPAIR_MILESTONES[_repair_step].y
		_grant(gems, "%s TAMİR\n+%d GEM" % [Hud.format_thousands(REPAIR_MILESTONES[_repair_step].x), gems])
		_repair_step += 1
	_request_save()


## Kasa sisteminden ÖNCEKİ kayıt (v9-): geçilmiş tamir kilometre taşları ödenmiş sayılır, gem verilmez
## (eski ilerlemeye geriye dönük ödül yok). SaveManager göçte çağırır.
func mark_passed_repair_milestones() -> void:
	var total: int = _total_repairs()
	while _repair_step < REPAIR_MILESTONES.size() and total >= REPAIR_MILESTONES[_repair_step].x:
		_repair_step += 1


## Toplam tamir sayısı: JobMastery sayaçlarının toplamı (ayrı sayaç tutulmaz). Yönetici yoksa -1.
func _total_repairs() -> int:
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery == null:
		return -1
	var total: int = 0
	var counts: Dictionary = mastery.state()
	for key: Variant in counts:
		total += int(counts[key])
	return total


# --- Kayıt ---------------------------------------------------------------------------------

func state() -> Dictionary:
	var progress: Dictionary = {}
	for key: StringName in _progress_by_task:
		progress[String(key)] = int(_progress_by_task[key])
	var done: Array = []
	for key: StringName in _done:
		done.append(String(key))
	return {
		"login": {"day": _login_day, "streak": _streak},
		"max_seen": _max_seen,
		"daily": {"day": _day, "progress": progress, "done": done, "bonus": _bonus_paid},
		"week": {"key": _week, "count": _week_count, "paid": _week_paid},
		"tips": {"day": _tip_day, "count": _tip_count, "carry": _tip_carry},
		"repair_step": _repair_step,
	}


func load_state(data: Dictionary) -> void:
	var login: Dictionary = data.get("login", {}) if data.get("login") is Dictionary else {}
	_login_day = SaveSafe.i(login.get("day", -1))
	_streak = maxi(SaveSafe.i(login.get("streak", 0)), 0)
	_max_seen = maxi(SaveSafe.i(data.get("max_seen", 0)), 0)
	var daily: Dictionary = data.get("daily", {}) if data.get("daily") is Dictionary else {}
	_day = SaveSafe.i(daily.get("day", -1))
	_progress_by_task.clear()
	var progress: Variant = daily.get("progress", {})
	if progress is Dictionary:
		for key: Variant in progress:
			_progress_by_task[StringName(SaveSafe.s(key))] = maxi(SaveSafe.i((progress as Dictionary)[key]), 0)
	_done.clear()
	var done: Variant = daily.get("done", [])
	if done is Array:
		for key: Variant in done:
			var type: StringName = StringName(SaveSafe.s(key))
			if not _done.has(type):
				_done.append(type)
	_bonus_paid = SaveSafe.b(daily.get("bonus", false))
	var week: Dictionary = data.get("week", {}) if data.get("week") is Dictionary else {}
	_week = SaveSafe.i(week.get("key", -1))
	_week_count = maxi(SaveSafe.i(week.get("count", 0)), 0)
	_week_paid = SaveSafe.b(week.get("paid", false))
	var tips: Dictionary = data.get("tips", {}) if data.get("tips") is Dictionary else {}
	_tip_day = SaveSafe.i(tips.get("day", -1))
	_tip_count = clampi(SaveSafe.i(tips.get("count", 0)), 0, TIP_DAILY_CAP)
	_tip_carry = clampi(SaveSafe.i(tips.get("carry", 0)), 0, TIP_EVERY - 1)
	_repair_step = clampi(SaveSafe.i(data.get("repair_step", 0)), 0, REPAIR_MILESTONES.size())
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
