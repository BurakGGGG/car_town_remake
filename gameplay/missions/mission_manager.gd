class_name MissionManager
extends Node
## GÖREVLER — günlük · haftalık · başarımlar. Tasarım: docs/gorevler_tasarimi.md.
## "missions" grubundan bulunur (GarageSystem kodla kurar; sahne dosyası düzenlenmez).
##
## Görev = (metrik, hedef): ilerleme DÖNEM sayacından okunur (günlük → bugün, haftalık → bu hafta,
## başarım → yaşam boyu), böylece her olay üç alanı birden besler. Sayaçlar mevcut sinyallerden gelir;
## ödül mevcut API'lerle verilir (EconomyManager.add_money, PlayerProgress.add_xp / add_gems,
## CrateManager.grant_free). Kalıcılık SaveManager'ın "missions" alanıdır (state / load_state / reset).
##
## SAAT: gün / hafta anahtarı GemRewards'ın saatinden gelir (tek kaynak: test_now, geri alma koruması).
## Gün yalnızca İLERİ gider: saat geri alınırsa görevler yeniden üretilmez / sıfırlanmaz.
## Gece yarısı (yerel 00:00): dünün alınmamış ödülleri OTOMATİK verilir, sayaçlar geçmişe yazılır,
## zorluk (DDA) güncellenir, yeni görevler oyuncunun geçmişine göre üretilir.

## Sayaç / görev durumu değişti (arayüz tazelensin).
signal missions_changed
## Bir görev ya da başarım yıldızı tamamlandı (HUD bildirimi): kind = &"daily" / &"weekly" / &"ach".
signal task_completed(kind: StringName, text: String)
## Ödül verildi (HUD bildirimi).
signal reward_granted(text: String)

const HISTORY_DAYS: int = 14
const CHECK_INTERVAL: float = 30.0
const DDA_MIN: float = 0.65
const DDA_MAX: float = 1.3

## Test: -1 değilse gün anahtarı için GemRewards.test_now değil bu unix zamanı kullanılır (GemRewards yoksa).
var test_now: int = -1

var _seed: int = 0
var _dda: float = 1.0
var _best_streak: int = 0
var _life: Dictionary = {}
var _day_c: Dictionary = {}
var _week_c: Dictionary = {}
var _history: Array[Dictionary] = []
var _life_seeded: bool = false
var _daily_day: int = -1
var _daily: Array[Dictionary] = []
var _daily_bonus_claimed: bool = false
var _daily_all_counted: bool = false
var _weekly_week: int = -1
var _weekly: Array[Dictionary] = []
var _weekly_final_claimed: bool = false
var _weekly_all_counted: bool = false
var _ach_claimed: Dictionary = {}
var _ach_announced: Dictionary = {}
var _yesterday_ids: Array = []
var _last_week_ids: Array = []
var _timer: Timer
var _wired: bool = false


func _ready() -> void:
	add_to_group("missions")
	if _seed == 0:
		_seed = randi() & 0x7FFFFFFF
	_timer = Timer.new()
	_timer.wait_time = CHECK_INTERVAL
	_timer.timeout.connect(ensure_current)
	add_child(_timer)
	_timer.start()
	_connect.call_deferred()


func _connect() -> void:
	_wired = true
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repairs:
		repairs.repair_collected.connect(func(_car: Node3D, reward: int, _xp: int) -> void:
			count(&"repairs", 1)
			count(&"repair_money", reward))
		repairs.job_collected.connect(_on_job_collected)
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race:
		race.race_finished.connect(func(won: bool, _money: int, _xp: int) -> void:
			count(&"races", 1)
			if won:
				count(&"race_wins", 1))
	var crates: CrateManager = get_tree().get_first_node_in_group("crates") as CrateManager
	if crates:
		crates.crate_opened.connect(func(_uid: int, _result: Dictionary) -> void: count(&"crates_opened", 1))
		crates.crate_added.connect(func(uid: int) -> void:
			if String(crates.get_crate(uid).get("source", "")) == "gems":
				count(&"crates_bought", 1))
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership:
		ownership.paint_purchased.connect(func(_id: StringName, _paint: StringName) -> void: count(&"paints", 1))
		ownership.ownership_changed.connect(scan_achievements)
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	if upgrades:
		upgrades.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void:
			count(&"growth_buys", 1)
			scan_achievements())
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.bay_unlocked.connect(func(_i: int) -> void:
			count(&"growth_buys", 1)
			scan_achievements())
	var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
	if decor:
		decor.instance_added.connect(func(item: StringName) -> void:
			count(&"decor_placed", 1)
			if GarageDecor.is_vehicle(item):
				count(&"cars_displayed", 1))
		decor.purchased.connect(func(_id: StringName) -> void: count(&"decor_bought", 1))
		decor.placement_changed.connect(scan_achievements)
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_spent.connect(func(amount: int) -> void: count(&"money_spent", amount))
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if player:
		player.level_up.connect(func(_level: int) -> void:
			count(&"levels", 1)
			ensure_current())
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(_id: StringName, _stars: int) -> void: scan_achievements())
	var gem: GemRewards = _gem()
	if gem:
		gem.day_changed.connect(func(_day: int) -> void: ensure_current())
	# Kayıt yüklemesi SaveManager'ın ertelenmiş kurulumunda olur; ilk gün kontrolü ondan sonra.
	get_tree().create_timer(1.2).timeout.connect(func() -> void:
		ensure_current()
		_seed_legacy()
		_mark_announced())


func _on_job_collected(job_id: StringName, _reward: int) -> void:
	count(StringName("job_%s" % job_id), 1)
	var job: RepairType = RepairType.by_id(job_id)
	if job and job.duration >= 60.0:
		count(&"long_jobs", 1)


# --- Saat ------------------------------------------------------------------------------------

func _gem() -> GemRewards:
	return get_tree().get_first_node_in_group("gem_rewards") as GemRewards if is_inside_tree() else null


func _now() -> int:
	var gem: GemRewards = _gem()
	if gem:
		return gem.now_unix()
	return test_now if test_now >= 0 else int(Time.get_unix_time_from_system())


func _day_of(unix: int) -> int:
	var gem: GemRewards = _gem()
	if gem:
		return gem.day_key(unix)
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	return floori(float(unix + bias_min * 60) / 86400.0)


## Bugünün gün numarası (yalnızca ileri: kayıttaki günden küçük olamaz).
func today() -> int:
	return maxi(_day_of(_now()), _daily_day)


## Gece yarısına kalan saniye (arayüz geri sayımı). Yerel gün sınırı.
func seconds_to_reset() -> int:
	var unix: int = _now()
	var bias_min: int = int(Time.get_time_zone_from_system().get("bias", 0))
	var into_day: int = posmod(unix + bias_min * 60, 86400)
	return 86400 - into_day


## Haftanın sonuna (Pazartesi 00:00) kalan saniye.
func seconds_to_week_reset() -> int:
	var day: int = today()
	var days_left: int = 6 - posmod(day + 3, 7)   # Pazartesi=0 … Pazar=6
	return seconds_to_reset() + days_left * 86400


## Gün / hafta değişimini işler. Tekrar çağrılması güvenlidir.
func ensure_current() -> void:
	if not is_inside_tree():
		return
	var day: int = today()
	var week: int = GemRewards.week_key(day)
	var changed: bool = false
	if day > _daily_day:
		_rollover_day(day)
		changed = true
	if week > _weekly_week:
		_rollover_week(week)
		changed = true
	# Seviye sonradan açıldıysa (3. seviye) bugünün görevleri o an üretilir
	if _unlocked() and _daily.is_empty():
		_generate_daily(day)
		changed = true
	if _unlocked() and _weekly.is_empty():
		_generate_weekly(week)
		changed = true
	if changed:
		_request_save()
		missions_changed.emit()


func _rollover_day(day: int) -> void:
	if _daily_day >= 0:
		_finish_daily()
	_daily_day = day
	_day_c = {}
	_daily = []
	_daily_bonus_claimed = false
	_daily_all_counted = false
	count(&"days_played", 1)
	if _unlocked():
		_generate_daily(day)


## Dünün sonu: alınmamış ödüller verilir, sayaçlar geçmişe yazılır, DDA güncellenir.
func _finish_daily() -> void:
	var granted: bool = false
	var done: int = 0
	for task: Dictionary in _daily:
		if bool(task.get("done", false)):
			done += 1
			if not bool(task.get("claimed", false)):
				task["claimed"] = true
				_pay(int(task["money"]), int(task["xp"]), 0, false)
				granted = true
	if done >= _daily.size() and not _daily.is_empty() and not _daily_bonus_claimed:
		_daily_bonus_claimed = true
		_pay(0, 0, MissionCatalog.DAILY_BONUS_GEMS, false)
		granted = true
	if granted:
		reward_granted.emit("DÜNÜN GÖREV ÖDÜLLERİ")
	var active: bool = int(_day_c.get(&"repairs", 0)) > 0 or int(_day_c.get(&"races", 0)) > 0
	if not _daily.is_empty() and active:
		_dda = dda_after(_dda, done, _daily.size())
	_yesterday_ids = []
	for task: Dictionary in _daily:
		_yesterday_ids.append(String(task["id"]))
	if not _day_c.is_empty() and active:
		var snapshot: Dictionary = {}
		for key: Variant in _day_c:
			snapshot[String(key)] = int(_day_c[key])
		_history.append({"day": _daily_day, "m": snapshot})
		while _history.size() > HISTORY_DAYS:
			_history.pop_front()


func _rollover_week(week: int) -> void:
	if _weekly_week >= 0:
		var granted: bool = false
		var done: int = 0
		for task: Dictionary in _weekly:
			if bool(task.get("done", false)):
				done += 1
				if not bool(task.get("claimed", false)):
					task["claimed"] = true
					_pay(int(task["money"]), int(task["xp"]), int(task["gems"]), false)
					granted = true
		if done >= _weekly.size() and not _weekly.is_empty() and not _weekly_final_claimed:
			_weekly_final_claimed = true
			_pay_weekly_bonus(false)
			granted = true
		if granted:
			reward_granted.emit("GEÇEN HAFTANIN GÖREV ÖDÜLLERİ")
		_last_week_ids = []
		for task: Dictionary in _weekly:
			_last_week_ids.append(String(task["id"]))
	_weekly_week = week
	_week_c = {}
	_weekly = []
	_weekly_final_claimed = false
	_weekly_all_counted = false
	# Hafta sayaçları sıfırlandı ama bugün zaten başladıysa bugünün "oynanan gün"ü haftaya yazılır
	_week_c[&"days_played"] = 1 if _daily_day >= 0 else 0
	if _unlocked():
		_generate_weekly(week)


func _unlocked() -> bool:
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress if is_inside_tree() else null
	return player == null or player.level >= MissionCatalog.MIN_LEVEL


func _generate_daily(day: int) -> void:
	var profile: Dictionary = build_profile()
	_daily = MissionGenerator.daily(profile, _mix(_seed, day), _yesterday_ids)
	for task: Dictionary in _daily:
		task["base"] = int(_day_c.get(task["metric"], 0))
		task["done"] = false


func _generate_weekly(week: int) -> void:
	var profile: Dictionary = build_profile()
	_weekly = MissionGenerator.weekly(profile, _mix(_seed, week + 100000), _last_week_ids)
	for task: Dictionary in _weekly:
		task["base"] = int(_week_c.get(task["metric"], 0))
		task["done"] = false


## Zorluk (DDA) güncellemesi: tüm görevler bitti → biraz zorlaş; çoğu bitti → aynı; çoğu bitmedi → kolaylaş.
static func dda_after(current: float, done: int, total: int) -> float:
	if total <= 0:
		return current
	if done >= total:
		return minf(current * 1.05, DDA_MAX)
	if done >= total - 1:
		return current
	if done == total - 2:
		return maxf(current * 0.97, DDA_MIN)
	return maxf(current * 0.92, DDA_MIN)


static func _mix(seed_value: int, key: int) -> int:
	return int((seed_value * 2654435761 + key * 40503 + 12345) & 0x7FFFFFFF)


# --- Sayaçlar --------------------------------------------------------------------------------

## Bir metriği artırır (yaşam boyu + bugün + bu hafta) ve görev / başarım tamamlanmasını denetler.
func count(metric: StringName, amount: int = 1) -> void:
	if amount <= 0:
		return
	_life[metric] = int(_life.get(metric, 0)) + amount
	_day_c[metric] = int(_day_c.get(metric, 0)) + amount
	_week_c[metric] = int(_week_c.get(metric, 0)) + amount
	_check_completions()
	_request_save()
	missions_changed.emit()


## Metrik değeri: sayaçlar yaşam boyu; durum metrikleri oyunun anlık durumundan.
func value_of(metric: StringName) -> int:
	match metric:
		&"cars_discovered":
			var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
			return ownership.discovered_count() if ownership else 0
		&"cars_on_display":
			var decor: DecorManager = get_tree().get_first_node_in_group("decor") as DecorManager
			var n: int = 0
			if decor:
				for inst: Dictionary in decor.instances():
					if GarageDecor.is_vehicle(inst["item"]):
						n += 1
			return n
		&"garage_level":
			var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
			return upgrades.garage_level() if upgrades else 1
		&"bays":
			var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
			return bays.unlocked_count() if bays else 1
		&"garage_rank":
			return GarageValue.current_rank(get_tree())
		&"job_stars":
			var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
			return mastery.total_stars() if mastery else 0
		&"player_level":
			var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
			return player.level if player else 1
		&"best_streak":
			var gem: GemRewards = _gem()
			return maxi(_best_streak, gem.streak() if gem else 0)
		&"ach_stars":
			return _reached_stars_total()
		&"legend":
			return 1 if _legend_done() else 0
	return int(_life.get(metric, 0))


func _legend_done() -> bool:
	return value_of(&"cars_discovered") >= CarCatalog.size() and value_of(&"garage_level") >= 4 \
			and value_of(&"bays") >= 3 and value_of(&"garage_rank") >= 10 and value_of(&"job_stars") >= 35


## Görev ilerlemesi (0..hedef): dönem sayacı − görev başlarkenki taban.
func progress_of(task: Dictionary, weekly: bool) -> int:
	var counters: Dictionary = _week_c if weekly else _day_c
	var value: int = int(counters.get(task["metric"], 0)) - int(task.get("base", 0))
	return clampi(value, 0, int(task["target"]))


func _check_completions() -> void:
	var guard: bool = false
	for task: Dictionary in _daily:
		if not bool(task.get("done", false)) and progress_of(task, false) >= int(task["target"]):
			task["done"] = true
			guard = true
			task_completed.emit(&"daily", "GÖREV TAMAM\n%s" % MissionCatalog.text_of(task["id"], int(task["target"])))
			_bump(&"daily_done")
	if not _daily.is_empty() and not _daily_all_counted and _daily.all(func(t: Dictionary) -> bool: return bool(t.get("done", false))):
		_daily_all_counted = true
		guard = true
		_bump(&"daily_all")
	for task: Dictionary in _weekly:
		if not bool(task.get("done", false)) and progress_of(task, true) >= int(task["target"]):
			task["done"] = true
			guard = true
			task_completed.emit(&"weekly", "HAFTALIK GÖREV TAMAM\n%s" % MissionCatalog.text_of(task["id"], int(task["target"])))
			_bump(&"weekly_done")
	if not _weekly.is_empty() and not _weekly_all_counted and _weekly.all(func(t: Dictionary) -> bool: return bool(t.get("done", false))):
		_weekly_all_counted = true
		guard = true
		_bump(&"weekly_all")
	scan_achievements()
	if guard:
		missions_changed.emit()


## Görev sayacı (daily_done gibi): count() özyinelemesine girmeden üç dönemi artırır; tamamlanma
## denetimi çağıran _check_completions döngüsünün sonraki turunda yapılır.
func _bump(metric: StringName) -> void:
	_life[metric] = int(_life.get(metric, 0)) + 1
	_day_c[metric] = int(_day_c.get(metric, 0)) + 1
	_week_c[metric] = int(_week_c.get(metric, 0)) + 1
	# Haftalık görev bu metriğe bağlıysa (daily_done, daily_all) hemen denetlenir
	for task: Dictionary in _weekly:
		if task["metric"] == metric and not bool(task.get("done", false)) and progress_of(task, true) >= int(task["target"]):
			task["done"] = true
			task_completed.emit(&"weekly", "HAFTALIK GÖREV TAMAM\n%s" % MissionCatalog.text_of(task["id"], int(task["target"])))
			_bump(&"weekly_done")


# --- Sorgu -----------------------------------------------------------------------------------

func daily_tasks() -> Array[Dictionary]:
	return _daily


func weekly_tasks() -> Array[Dictionary]:
	return _weekly


func daily_all_done() -> bool:
	return not _daily.is_empty() and _daily.all(func(t: Dictionary) -> bool: return bool(t.get("done", false)))


func weekly_all_done() -> bool:
	return not _weekly.is_empty() and _weekly.all(func(t: Dictionary) -> bool: return bool(t.get("done", false)))


func daily_bonus_claimed() -> bool:
	return _daily_bonus_claimed


func weekly_final_claimed() -> bool:
	return _weekly_final_claimed


func is_unlocked() -> bool:
	return _unlocked()


func difficulty() -> float:
	return _dda


## Başarım çizgisinin ulaşılan yıldız sayısı.
func stars_reached(line: Dictionary) -> int:
	var value: int = value_of(line["metric"])
	var n: int = 0
	for threshold: int in line["tiers"]:
		if value >= threshold:
			n += 1
	return n


func stars_claimed(line: Dictionary) -> int:
	return mini(int(_ach_claimed.get(String(line["id"]), 0)), (line["tiers"] as Array).size())


func achievements() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for line: Dictionary in MissionCatalog.ACHIEVEMENTS:
		if StringName(line.get("feature", &"")) == &"paint" and not GameFeatures.PAINT:
			continue
		out.append(line)
	return out


func _reached_stars_total() -> int:
	var total: int = 0
	for line: Dictionary in MissionCatalog.ACHIEVEMENTS:
		if line["metric"] == &"ach_stars" or line["metric"] == &"legend":
			continue
		if StringName(line.get("feature", &"")) == &"paint" and not GameFeatures.PAINT:
			continue
		total += stars_reached(line)
	return total


## Ödülü alınmayı bekleyen öğe sayısı (HUD plakası rozeti).
func claimable_count() -> int:
	return claimable_daily() + claimable_weekly() + claimable_achievements()


func claimable_daily() -> int:
	var n: int = 0
	for task: Dictionary in _daily:
		if bool(task.get("done", false)) and not bool(task.get("claimed", false)):
			n += 1
	if daily_all_done() and not _daily_bonus_claimed:
		n += 1
	return n


func claimable_weekly() -> int:
	var n: int = 0
	for task: Dictionary in _weekly:
		if bool(task.get("done", false)) and not bool(task.get("claimed", false)):
			n += 1
	if weekly_all_done() and not _weekly_final_claimed:
		n += 1
	return n


func claimable_achievements() -> int:
	var n: int = 0
	for line: Dictionary in achievements():
		n += maxi(stars_reached(line) - stars_claimed(line), 0)
	return n


# --- Ödül ------------------------------------------------------------------------------------

func claim_daily(index: int) -> bool:
	if index < 0 or index >= _daily.size():
		return false
	var task: Dictionary = _daily[index]
	if not bool(task.get("done", false)) or bool(task.get("claimed", false)):
		return false
	task["claimed"] = true
	_pay(int(task["money"]), int(task["xp"]), 0, true)
	_request_save()
	missions_changed.emit()
	return true


## Beş günlük görev tamam ve bonus alınmadıysa gem verir.
func claim_daily_bonus() -> bool:
	if not daily_all_done() or _daily_bonus_claimed:
		return false
	_daily_bonus_claimed = true
	_pay(0, 0, MissionCatalog.DAILY_BONUS_GEMS, true)
	_request_save()
	missions_changed.emit()
	return true


func claim_weekly(index: int) -> bool:
	if index < 0 or index >= _weekly.size():
		return false
	var task: Dictionary = _weekly[index]
	if not bool(task.get("done", false)) or bool(task.get("claimed", false)):
		return false
	task["claimed"] = true
	_pay(int(task["money"]), int(task["xp"]), int(task["gems"]), true)
	_request_save()
	missions_changed.emit()
	return true


func claim_weekly_bonus() -> bool:
	if not weekly_all_done() or _weekly_final_claimed:
		return false
	_weekly_final_claimed = true
	_pay_weekly_bonus(true)
	_request_save()
	missions_changed.emit()
	return true


## Başarım çizgisinde ulaşılmış ama alınmamış SIRADAKİ yıldızı verir.
func claim_achievement(line_id: StringName) -> bool:
	var line: Dictionary = MissionCatalog.achievement(line_id)
	if line.is_empty():
		return false
	var claimed: int = stars_claimed(line)
	if claimed >= stars_reached(line):
		return false
	_ach_claimed[String(line_id)] = claimed + 1
	_pay(MissionCatalog.ach_money(line, claimed), MissionCatalog.ach_xp(line, claimed), MissionCatalog.ach_gems(line, claimed), true,
		"%s ★%d" % [line["title"], claimed + 1])
	_request_save()
	missions_changed.emit()
	scan_achievements()
	return true


func claim_all_daily() -> int:
	var n: int = 0
	for i: int in _daily.size():
		if claim_daily(i):
			n += 1
	if claim_daily_bonus():
		n += 1
	return n


func claim_all_weekly() -> int:
	var n: int = 0
	for i: int in _weekly.size():
		if claim_weekly(i):
			n += 1
	if claim_weekly_bonus():
		n += 1
	return n


func claim_all_achievements() -> int:
	var n: int = 0
	for line: Dictionary in achievements():
		while claim_achievement(line["id"]):
			n += 1
	return n


func _pay(money: int, xp: int, gems: int, announce: bool, label: String = "") -> void:
	var parts: PackedStringArray = PackedStringArray()
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if money > 0 and economy:
		economy.add_money(money)
		parts.append("+%s ₺" % Hud.format_thousands(money))
	if gems > 0 and player:
		player.add_gems(gems)
		parts.append("+%d GEM" % gems)
	if xp > 0 and player:
		player.add_xp(xp)   # seviye atlarsa level_up → ensure_current (görevler açılabilir)
		parts.append("+%d XP" % xp)
	if announce and not parts.is_empty():
		reward_granted.emit(("%s\n" % label if label != "" else "") + "  ".join(parts))


## Haftalık BÜYÜK ÖDÜL: gem + XP + bedava kasa (seviyeye göre en iyi açık kasa).
func _pay_weekly_bonus(announce: bool) -> void:
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	var profile: Dictionary = build_profile()
	var xp: int = maxi(int(round(float((profile["typical"] as Dictionary).get(&"repairs", 20.0)) * MissionGenerator.weekly_factor(profile)
			* float(profile.get("repair_xp", 10.0)) * MissionCatalog.WEEKLY_BONUS_XP_SHARE)), 1)
	_pay(0, xp, MissionCatalog.WEEKLY_BONUS_GEMS, false)
	var crate_name: String = ""
	var crates: CrateManager = get_tree().get_first_node_in_group("crates") as CrateManager
	if crates:
		var crate_id: StringName = best_crate_for(player.level if player else 1)
		if crate_id != &"" and crates.grant_free(crate_id, "weekly") > 0:
			crate_name = String(CrateCatalog.get_entry(crate_id).get("display_name", "KASA"))
	if announce:
		reward_granted.emit("HAFTALIK BÜYÜK ÖDÜL\n+%d GEM%s  +%d XP" % [MissionCatalog.WEEKLY_BONUS_GEMS,
			("  +1 %s" % crate_name) if crate_name != "" else "", xp])


## Seviyeye açık en pahalı kasa (haftalık büyük ödül).
static func best_crate_for(level: int) -> StringName:
	var best: StringName = &""
	var best_price: int = -1
	for entry: Dictionary in CrateCatalog.all():
		var id: StringName = entry["id"]
		if CrateCatalog.min_level(id) <= level and CrateCatalog.price(id) > best_price:
			best = id
			best_price = CrateCatalog.price(id)
	return best


# --- Başarım taraması ------------------------------------------------------------------------

## Yeni ulaşılan başarım yıldızları için bir kez bildirim yayar (açılışta bildirim yok).
func scan_achievements() -> void:
	if not is_inside_tree():
		return
	var any: bool = false
	for line: Dictionary in achievements():
		var reached: int = stars_reached(line)
		var known: int = int(_ach_announced.get(String(line["id"]), -1))
		if known < 0:
			_ach_announced[String(line["id"])] = reached
			continue
		if reached > known:
			_ach_announced[String(line["id"])] = reached
			any = true
			task_completed.emit(&"ach", "BAŞARIM\n%s ★%d" % [line["title"], reached])
	if any:
		missions_changed.emit()


func _mark_announced() -> void:
	_ach_announced.clear()
	for line: Dictionary in achievements():
		_ach_announced[String(line["id"])] = stars_reached(line)


## Göç: eski oyuncunun (kasa sistemi + görev sistemi öncesi) tamir sayısı yaşam boyu sayaca yazılır,
## eski tamir kilometre taşları ödenmiş yıldız sayılır (çifte ödeme yok). Bir kez çalışır.
func _seed_legacy() -> void:
	if _life_seeded:
		return
	_life_seeded = true
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		var total: int = 0
		var counts: Dictionary = mastery.state()
		for key: Variant in counts:
			total += int(counts[key])
		_life[&"repairs"] = maxi(int(_life.get(&"repairs", 0)), total)
	var gem: GemRewards = _gem()
	if gem:
		var line: Dictionary = MissionCatalog.achievement(&"a_repairs")
		_ach_claimed["a_repairs"] = maxi(int(_ach_claimed.get("a_repairs", 0)), mini(gem.legacy_repair_step(), (line["tiers"] as Array).size()))
	_mark_announced()
	_request_save()


## Kasa sistemi öncesi (v9-) kayıt: geçilmiş tamir yıldızları ödenmiş sayılır (geriye dönük gem yok).
func mark_legacy_repairs_passed() -> void:
	_life_seeded = false
	_seed_legacy()
	var line: Dictionary = MissionCatalog.achievement(&"a_repairs")
	_ach_claimed["a_repairs"] = stars_reached(line)
	_mark_announced()


# --- Profil ----------------------------------------------------------------------------------

## Üreticiye giren oyuncu profili (docs §4.1). Saf okuma: oyunu değiştirmez.
func build_profile() -> Dictionary:
	var tree: SceneTree = get_tree()
	var player: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	var upgrades: GarageUpgradeManager = tree.get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var bays: RepairBayManager = tree.get_first_node_in_group("repair_bays") as RepairBayManager
	var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var repair: RepairManager = tree.get_first_node_in_group("repair_manager") as RepairManager
	var crates: CrateManager = tree.get_first_node_in_group("crates") as CrateManager
	var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
	var level: int = player.level if player else 1
	var garage: int = upgrades.garage_level() if upgrades else 1
	var bay_count: int = bays.unlocked_count() if bays else 1
	var money: int = economy.money if economy else 0
	var gems: int = player.gems if player else 0
	var reward_mult: float = repair.reward_multiplier() if repair else 1.0
	var jobs: Array[Dictionary] = []
	var weight_sum: float = 0.0
	var reward_sum: float = 0.0
	var xp_sum: float = 0.0
	for type: RepairType in RepairType.defaults():
		if type.min_level > level or type.min_garage_level > garage or type.min_bays > bay_count:
			continue
		jobs.append({"id": type.id, "long": type.duration >= 60.0, "weight": type.weight, "reward": type.reward, "xp": type.xp})
		weight_sum += type.weight
		reward_sum += type.weight * float(type.reward)
		xp_sum += type.weight * float(type.xp)
	var avg_reward: float = (reward_sum / maxf(weight_sum, 0.001)) * reward_mult
	var avg_xp: float = xp_sum / maxf(weight_sum, 0.001)
	var min_crate: int = 9999
	for entry: Dictionary in CrateCatalog.all():
		if CrateCatalog.min_level(entry["id"]) <= level:
			min_crate = mini(min_crate, CrateCatalog.price(entry["id"]))
	var growth_cost: int = _cheapest_growth(upgrades, bays)
	var typical: Dictionary = typical_daily(level, jobs, avg_reward)
	return {
		"level": level, "garage": garage, "bays": bay_count, "owned": ownership.owned_count() if ownership else 1,
		"money": money, "gems": gems, "jobs": jobs, "typical": typical,
		"active_days": _active_days_14(), "difficulty": _dda, "used": _used_categories(),
		"income_per_min": MissionCatalog.REPAIRS_PER_MIN * avg_reward, "repair_xp": avg_xp,
		"race_ok": level >= MissionCatalog.MIN_LEVEL, "crate_waiting": crates.pending_count() if crates else 0,
		"min_crate_price": min_crate,
		"decor_ready": level >= 4 and (money >= 3000 or (decor != null and decor.owned_total() > 0)),
		"paint_ready": GameFeatures.PAINT and gems >= 15,
		"growth_ready": growth_cost > 0 and money + int(typical.get(&"repair_money", 0.0)) >= growth_cost,
		"display_ready": level >= 4 and (ownership.owned_count() if ownership else 1) >= 2,
	}


## En ucuz satın alınabilir büyüme (geliştirme / alan); yoksa 0.
func _cheapest_growth(upgrades: GarageUpgradeManager, bays: RepairBayManager) -> int:
	var best: int = 0
	if upgrades:
		for id: StringName in [GarageUpgradeManager.SPEED_ID, GarageUpgradeManager.GARAGE_ID]:
			if not upgrades.is_max(id):
				var cost: int = upgrades.next_cost(id)
				best = cost if best == 0 else mini(best, cost)
	if bays and bays.unlocked_count() < bays.bay_count():
		var next: int = bays.unlocked_count()
		if bays.status(next) != RepairBayManager.Status.NEEDS_LEVEL:
			var price: int = bays.price(next)
			best = price if best == 0 else mini(best, price)
	return best


## Tipik GÜNLÜK değerler: son 7 aktif günün medyanı (≥2 aktif gün varsa), yoksa seviyeden ön-kabul.
func typical_daily(level: int, jobs: Array[Dictionary], avg_reward: float) -> Dictionary:
	var prior: Dictionary = prior_typical(level, jobs, avg_reward)
	var days: Array[Dictionary] = []
	for entry: Dictionary in _history:
		if int((entry["m"] as Dictionary).get("repairs", 0)) > 0:
			days.append(entry["m"])
	if days.size() > 7:
		days.assign(days.slice(days.size() - 7))
	if days.size() < 2:
		return prior
	var out: Dictionary = prior.duplicate()
	for metric: Variant in prior:
		var values: Array[float] = []
		for m: Dictionary in days:
			values.append(float(m.get(String(metric), 0)))
		values.sort()
		var mid: int = values.size() / 2
		var median: float = values[mid] if values.size() % 2 == 1 else (values[mid - 1] + values[mid]) * 0.5
		out[metric] = median
	return out


## Yeni oyuncu ön-kabulü (tahmini günlük değerler). Saf: test edilebilir.
static func prior_typical(level: int, jobs: Array[Dictionary], avg_reward: float) -> Dictionary:
	var repairs: float = clampf(18.0 + 3.0 * float(level), 18.0, 150.0)
	var weight_sum: float = 0.0
	var long_weight: float = 0.0
	for job: Dictionary in jobs:
		weight_sum += float(job["weight"])
		if bool(job["long"]):
			long_weight += float(job["weight"])
	var out: Dictionary = {
		&"repairs": repairs, &"repair_money": repairs * avg_reward, &"races": 2.0, &"race_wins": 1.0,
		&"crates_opened": 1.0, &"crates_bought": 1.0, &"money_spent": repairs * avg_reward * 0.35,
		&"decor_placed": 2.0, &"cars_displayed": 1.0, &"paints": 1.0, &"growth_buys": 1.0,
		&"long_jobs": repairs * long_weight / maxf(weight_sum, 0.001),
	}
	for job: Dictionary in jobs:
		out[StringName("job_%s" % job["id"])] = repairs * float(job["weight"]) / maxf(weight_sum, 0.001)
	return out


## Simülasyon (ağaç dışı örnek): geçmişteki aktif gün sayısı.
func _active_days_sim() -> int:
	var n: int = 0
	for entry: Dictionary in _history:
		if int((entry["m"] as Dictionary).get("repairs", 0)) > 0:
			n += 1
	return n


func _active_days_14() -> int:
	var n: int = 0
	var cutoff: int = today() - 14
	for entry: Dictionary in _history:
		if int(entry["day"]) > cutoff and int((entry["m"] as Dictionary).get("repairs", 0)) > 0:
			n += 1
	return n + (1 if int(_day_c.get(&"repairs", 0)) > 0 else 0)


## Kategori → son 7 günde (ve bugün) kullanıldı mı.
func _used_categories() -> Dictionary:
	var out: Dictionary = {}
	var recent: Array[Dictionary] = []
	for entry: Dictionary in _history:
		recent.append(entry["m"])
	if recent.size() > 7:
		recent.assign(recent.slice(recent.size() - 7))
	var dc: Dictionary = {}
	for key: Variant in _day_c:
		dc[String(key)] = _day_c[key]
	recent.append(dc)
	for cat: int in MissionCatalog.CAT_METRICS:
		var used: bool = false
		for m: Dictionary in recent:
			for metric: StringName in MissionCatalog.CAT_METRICS[cat]:
				if int(m.get(String(metric), 0)) > 0:
					used = true
		out[cat] = used
	return out


# --- Kayıt -----------------------------------------------------------------------------------

func state() -> Dictionary:
	return {
		"seed": _seed, "dda": snappedf(_dda, 0.0001), "best_streak": maxi(_best_streak, _gem().streak() if _gem() else 0),
		"life_seeded": _life_seeded,
		"life": _counters_out(_life), "day_counters": _counters_out(_day_c), "week_counters": _counters_out(_week_c),
		"history": _history.duplicate(true),
		"daily": {"day": _daily_day, "tasks": _tasks_out(_daily), "bonus": _daily_bonus_claimed, "all_counted": _daily_all_counted},
		"weekly": {"week": _weekly_week, "tasks": _tasks_out(_weekly), "final": _weekly_final_claimed, "all_counted": _weekly_all_counted},
		"ach": _ach_claimed.duplicate(),
		"yesterday": _yesterday_ids.duplicate(), "last_week": _last_week_ids.duplicate(),
	}


func load_state(data: Dictionary) -> void:
	_seed = SaveSafe.i(data.get("seed", 0))
	if _seed <= 0:
		_seed = randi() & 0x7FFFFFFF
	_dda = clampf(SaveSafe.f(data.get("dda", 1.0)), DDA_MIN, DDA_MAX)
	_best_streak = maxi(SaveSafe.i(data.get("best_streak", 0)), 0)
	_life_seeded = SaveSafe.b(data.get("life_seeded", false))
	_life = _counters_in(data.get("life"))
	_day_c = _counters_in(data.get("day_counters"))
	_week_c = _counters_in(data.get("week_counters"))
	_history.clear()
	var history: Variant = data.get("history", [])
	if history is Array:
		for raw: Variant in (history as Array):
			if raw is Dictionary and (raw as Dictionary).get("m") is Dictionary:
				var m: Dictionary = {}
				for key: Variant in ((raw as Dictionary)["m"] as Dictionary):
					m[SaveSafe.s(key)] = maxi(SaveSafe.i(((raw as Dictionary)["m"] as Dictionary)[key]), 0)
				_history.append({"day": SaveSafe.i((raw as Dictionary).get("day", 0)), "m": m})
		while _history.size() > HISTORY_DAYS:
			_history.pop_front()
	var daily: Dictionary = data.get("daily", {}) if data.get("daily") is Dictionary else {}
	_daily_day = SaveSafe.i(daily.get("day", -1))
	_daily = _tasks_in(daily.get("tasks"), false)
	_daily_bonus_claimed = SaveSafe.b(daily.get("bonus", false))
	_daily_all_counted = SaveSafe.b(daily.get("all_counted", false))
	var weekly: Dictionary = data.get("weekly", {}) if data.get("weekly") is Dictionary else {}
	_weekly_week = SaveSafe.i(weekly.get("week", -1))
	_weekly = _tasks_in(weekly.get("tasks"), true)
	_weekly_final_claimed = SaveSafe.b(weekly.get("final", false))
	_weekly_all_counted = SaveSafe.b(weekly.get("all_counted", false))
	_ach_claimed.clear()
	var ach: Variant = data.get("ach", {})
	if ach is Dictionary:
		for key: Variant in (ach as Dictionary):
			var line: Dictionary = MissionCatalog.achievement(StringName(SaveSafe.s(key)))
			if not line.is_empty():
				_ach_claimed[SaveSafe.s(key)] = clampi(SaveSafe.i((ach as Dictionary)[key]), 0, (line["tiers"] as Array).size())
	_yesterday_ids = _strings_in(data.get("yesterday"))
	_last_week_ids = _strings_in(data.get("last_week"))
	_mark_announced()
	missions_changed.emit()


## Yeni oyun: her şey sıfır (tohum yeni).
func reset() -> void:
	load_state({})
	ensure_current.call_deferred()


static func _counters_out(counters: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in counters:
		out[String(key)] = int(counters[key])
	return out


static func _counters_in(raw: Variant) -> Dictionary:
	var out: Dictionary = {}
	if raw is Dictionary:
		for key: Variant in (raw as Dictionary):
			out[StringName(SaveSafe.s(key))] = maxi(SaveSafe.i((raw as Dictionary)[key]), 0)
	return out


static func _strings_in(raw: Variant) -> Array:
	var out: Array = []
	if raw is Array:
		for item: Variant in (raw as Array):
			out.append(SaveSafe.s(item))
	return out


static func _tasks_out(tasks: Array[Dictionary]) -> Array:
	var out: Array = []
	for task: Dictionary in tasks:
		var d: Dictionary = {}
		for key: Variant in task:
			d[String(key)] = String(task[key]) if task[key] is StringName else task[key]
		out.append(d)
	return out


static func _tasks_in(raw: Variant, weekly: bool) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not (raw is Array):
		return out
	for item: Variant in (raw as Array):
		if not (item is Dictionary):
			continue
		var d: Dictionary = item
		var id: StringName = StringName(SaveSafe.s(d.get("id", "")))
		var known: bool = not MissionCatalog.weekly_template(id).is_empty() if weekly \
				else (not MissionCatalog.daily_template(id).is_empty() or String(id).begins_with("job:"))
		if not known or SaveSafe.i(d.get("target", 0)) <= 0:
			continue
		var task: Dictionary = {
			"id": id, "slot": SaveSafe.i(d.get("slot", out.size())), "cat": SaveSafe.i(d.get("cat", 0)),
			"tier": SaveSafe.i(d.get("tier", 0)), "metric": StringName(SaveSafe.s(d.get("metric", ""))),
			"target": SaveSafe.i(d.get("target", 1)), "money": maxi(SaveSafe.i(d.get("money", 0)), 0),
			"xp": maxi(SaveSafe.i(d.get("xp", 0)), 0),
			"base": maxi(SaveSafe.i(d.get("base", 0)), 0), "done": SaveSafe.b(d.get("done", false)),
			"claimed": SaveSafe.b(d.get("claimed", false)),
		}
		if weekly:
			task["gems"] = maxi(SaveSafe.i(d.get("gems", 0)), 0)
		out.append(task)
	return out


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager") if is_inside_tree() else null
	if save and save.has_method(&"request_save"):
		save.request_save()
