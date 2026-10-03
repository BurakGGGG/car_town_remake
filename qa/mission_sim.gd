extends SceneTree
## GÖREV SİMÜLASYONU — 5 oyuncu profili × 30 gün (sahnesiz: MissionGenerator + MissionManager'ın saf kısımları).
## Her profilin günlük performansı (tamir, kazanç, yarış, kasa, dekor …) gürültülü üretilir; üretici
## oyuncunun kendi geçmişinden tipik değerleri hesaplar (MissionManager.typical_daily), görevler dağıtılır,
## tamamlanma ölçülür, DDA işletilir. Çıktı: tamamlama oranı, ₺ / gem akışı, çeşitlilik.
##
## Kullanım: godot-4 --headless --path . -s res://qa/mission_sim.gd
## Sonuç docs/gorevler_tasarimi.md §12'ye işlenir.

const DAYS: int = 30
const SEEDS: int = 40   # profil başına bağımsız oyuncu

# ad, günlük dk, başlangıç seviye, 30. gün seviye, yarış eğilimi, kasa eğilimi, dekor eğilimi, haftada aktif gün
const PROFILES: Array = [
	["YENİ (10 dk)", 10, 3, 9, 0.5, 0.3, 0.3, 7],
	["CASUAL (20 dk)", 20, 5, 25, 0.8, 0.6, 0.6, 6],
	["ARA SIRA (30 dk, 4 gün)", 30, 6, 20, 0.6, 0.6, 0.4, 4],
	["ACTIVE (60 dk)", 60, 11, 31, 1.0, 0.8, 0.8, 7],
	["HEAVY (150 dk)", 150, 17, 35, 1.2, 1.0, 1.0, 7],
]


func _initialize() -> void:
	print("GÖREV SİMÜLASYONU — %d gün × %d oyuncu / profil" % [DAYS, SEEDS])
	print("%-26s | tamam/5 | 5/5 gün | gem/gün | ödül ₺ / günlük gelir | haftalık 5/5 | görev çeşidi | DDA" % "profil")
	for profile: Array in PROFILES:
		_simulate(profile)
	quit()


func _jobs_for(level: int) -> Array[Dictionary]:
	var garage: int = 1 if level < 6 else (2 if level < 11 else (3 if level < 17 else 4))
	var bays: int = 1 if level < 6 else (2 if level < 12 else 3)
	var jobs: Array[Dictionary] = []
	for type: RepairType in RepairType.defaults():
		if type.min_level > level or type.min_garage_level > garage or type.min_bays > bays:
			continue
		jobs.append({"id": type.id, "long": type.duration >= 60.0, "weight": type.weight, "reward": type.reward, "xp": type.xp})
	return jobs


func _simulate(profile: Array) -> void:
	var minutes: int = profile[1]
	var done_sum: float = 0.0
	var all_days: int = 0
	var gem_sum: float = 0.0
	var reward_pct_sum: float = 0.0
	var weekly_all: int = 0
	var weeks: int = 0
	var kinds_sum: float = 0.0
	var dda_sum: float = 0.0
	var day_count: int = 0
	for s: int in SEEDS:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 1000 + s * 7919
		var mm: MissionManager = MissionManager.new()
		var seed_value: int = rng.randi() & 0x7FFFFFFF
		var dda: float = 1.0
		var yesterday: Array = []
		var week_counters: Dictionary = {}
		var weekly_tasks: Array[Dictionary] = []
		var last_week: Array = []
		var seen_ids: Dictionary = {}
		var affinity_race: float = float(profile[4]) * rng.randf_range(0.4, 1.6)
		var affinity_crate: float = float(profile[5]) * rng.randf_range(0.4, 1.6)
		var affinity_decor: float = float(profile[6]) * rng.randf_range(0.2, 1.8)
		for day: int in DAYS:
			var level: int = roundi(lerpf(float(profile[2]), float(profile[3]), float(day) / float(DAYS - 1)))
			var active: bool = rng.randf() < float(profile[7]) / 7.0
			var jobs: Array[Dictionary] = _jobs_for(level)
			var weight_sum: float = 0.0
			var reward_sum: float = 0.0
			var xp_sum: float = 0.0
			for j: Dictionary in jobs:
				weight_sum += float(j["weight"])
				reward_sum += float(j["weight"]) * float(j["reward"])
				xp_sum += float(j["weight"]) * float(j["xp"])
			var avg_reward: float = reward_sum / weight_sum * (1.0 + 0.15 * float(clampi(level / 6, 0, 4)))
			var used: Dictionary = {}
			for cat: int in MissionCatalog.CAT_METRICS:
				used[cat] = true
			var prof: Dictionary = {
				"level": level, "garage": 1, "bays": 1, "owned": 3 + level / 4, "money": 20000, "gems": 150, "jobs": jobs,
				"typical": mm.typical_daily(level, jobs, avg_reward), "active_days": mm._active_days_sim(),
				"difficulty": dda, "used": used, "income_per_min": 3.4 * avg_reward, "repair_xp": xp_sum / weight_sum,
				"race_ok": true, "crate_waiting": 1, "min_crate_price": 30, "decor_ready": level >= 4, "paint_ready": false,
				"growth_ready": true, "display_ready": level >= 4,
			}
			var tasks: Array[Dictionary] = MissionGenerator.daily(prof, seed_value * 31 + day, yesterday)
			if day % 7 == 0 or weekly_tasks.is_empty():
				weekly_tasks = MissionGenerator.weekly(prof, seed_value * 17 + day, last_week)
				last_week = weekly_tasks.map(func(t: Dictionary) -> String: return String(t["id"]))
				week_counters = {}
			for t: Dictionary in tasks:
				seen_ids[String(t["id"])] = true
			if not active:
				# oynanmayan gün: görev tamamlanmaz; DDA değişmez, geçmişe yazılmaz
				yesterday = tasks.map(func(t: Dictionary) -> String: return String(t["id"]))
				day_count += 1
				continue
			# günün performansı
			var repairs: float = float(minutes) * 3.4 * rng.randf_range(0.75, 1.25)
			var m: Dictionary = {
				"repairs": roundf(repairs), "repair_money": roundf(repairs * avg_reward * rng.randf_range(0.9, 1.1)),
				"races": roundf(float(minutes) / 25.0 * affinity_race * rng.randf_range(0.5, 1.5)),
				"crates_opened": roundf(float(minutes) / 60.0 * affinity_crate * rng.randf_range(0.0, 2.0)),
				"decor_placed": roundf(affinity_decor * rng.randf_range(0.0, 3.0)),
				"money_spent": roundf(repairs * avg_reward * rng.randf_range(0.2, 0.9)),
				"growth_buys": 1.0 if rng.randf() < 0.25 else 0.0, "crates_bought": 1.0 if rng.randf() < 0.3 * affinity_crate else 0.0,
				"cars_displayed": 1.0 if rng.randf() < 0.15 * affinity_decor else 0.0,
			}
			m["race_wins"] = roundf(float(m["races"]) * 0.55)
			var long_share: float = 0.0
			for j: Dictionary in jobs:
				m["job_%s" % j["id"]] = roundf(repairs * float(j["weight"]) / weight_sum * rng.randf_range(0.7, 1.3))
				if bool(j["long"]):
					long_share += float(j["weight"]) / weight_sum
			m["long_jobs"] = roundf(repairs * long_share)
			# Motivasyon: küçük hedefli görevi oyuncu %70 ihtimalle yapar (görev yönlendirir)
			for t: Dictionary in tasks:
				var metric: String = String(t["metric"])
				if int(t["target"]) <= 3 and float(m.get(metric, 0.0)) < float(t["target"]) and rng.randf() < 0.7:
					m[metric] = float(m.get(metric, 0.0)) + float(t["target"])
			var done: int = 0
			var money_reward: float = 0.0
			for t: Dictionary in tasks:
				if float(m.get(String(t["metric"]), 0.0)) >= float(t["target"]):
					done += 1
					money_reward += float(t["money"])
			done_sum += done
			day_count += 1
			if done >= tasks.size():
				all_days += 1
				gem_sum += float(MissionCatalog.DAILY_BONUS_GEMS)
			dda = MissionManager.dda_after(dda, done, tasks.size())
			reward_pct_sum += money_reward / maxf(float(m["repair_money"]), 1.0)
			dda_sum += dda
			# haftalık sayaçlar
			for key: Variant in m:
				week_counters[key] = float(week_counters.get(key, 0.0)) + float(m[key])
			week_counters["daily_done"] = float(week_counters.get("daily_done", 0.0)) + done
			week_counters["days_played"] = float(week_counters.get("days_played", 0.0)) + 1.0
			if done >= tasks.size():
				week_counters["daily_all"] = float(week_counters.get("daily_all", 0.0)) + 1.0
			# geçmişe yaz (tipik değerler için)
			var snapshot: Dictionary = {}
			for key: Variant in m:
				snapshot[String(key)] = int(m[key])
			mm._history.append({"day": day, "m": snapshot})
			while mm._history.size() > 14:
				mm._history.pop_front()
			yesterday = tasks.map(func(t: Dictionary) -> String: return String(t["id"]))
			if day % 7 == 6:
				var w_done: int = 0
				for t: Dictionary in weekly_tasks:
					if float(week_counters.get(String(t["metric"]), 0.0)) >= float(t["target"]):
						w_done += 1
				weeks += 1
				if w_done >= weekly_tasks.size():
					weekly_all += 1
		kinds_sum += seen_ids.size()
		mm.free()
	var played: float = maxf(float(day_count), 1.0)
	print("%-26s | %6.2f  | %6.0f%% | %7.1f | %19.1f%%    | %10.0f%% | %12.1f | %.2f" % [
		profile[0], done_sum / maxf(float(SEEDS * DAYS) * float(profile[7]) / 7.0, 1.0),
		100.0 * float(all_days) / maxf(float(SEEDS * DAYS) * float(profile[7]) / 7.0, 1.0),
		gem_sum / float(SEEDS * DAYS), 100.0 * reward_pct_sum / maxf(float(SEEDS * DAYS) * float(profile[7]) / 7.0, 1.0),
		100.0 * float(weekly_all) / maxf(float(weeks), 1.0), kinds_sum / float(SEEDS), dda_sum / maxf(float(SEEDS * DAYS) * float(profile[7]) / 7.0, 1.0)])
