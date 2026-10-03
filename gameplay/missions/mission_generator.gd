class_name MissionGenerator
extends RefCounted
## GÖREV ÜRETİCİ — SAF fonksiyonlar (sahneye / saate / kayda dokunmaz): profil + tohum → görevler.
## Aynı profil ve tohum her zaman aynı görevleri üretir (test ve simülasyon bunu sınar). Tasarım:
## docs/gorevler_tasarimi.md §4–5.
##
## PROFİL (Dictionary) alanları — MissionManager.build_profile() kurar:
##   level, garage, bays, owned, money, gems : int
##   jobs: Array[Dictionary]   açık işler {id, long, weight, reward, xp}
##   typical: Dictionary       metrik → tipik GÜNLÜK değer (geçmiş medyanı ya da seviye ön-kabulü)
##   active_days: int          son 14 günde oynanan gün
##   difficulty: float         DDA çarpanı (0,65–1,35)
##   used: Dictionary          Cat → son 7 günde kullanıldı mı
##   income_per_min, repair_xp : float
##   race_ok, crate_waiting, min_crate_price, decor_ready, paint_ready, growth_ready, display_ready

const Cat = MissionCatalog.Cat
const Tier = MissionCatalog.Tier


## Bugünün 5 görevi. `yesterday`: dünkü şablon kimlikleri. Dönüş: [{id, slot, cat, tier, metric, target,
## money, xp}] (id "job:<iş>" olabilir).
static func daily(profile: Dictionary, seed_value: int, yesterday: Array) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[Dictionary] = []
	var used_metrics: Dictionary = {}
	var cat_count: Dictionary = {}
	var nudged: bool = false
	var templates: Array[Dictionary] = _expand_daily(profile)
	for slot: int in MissionCatalog.DAILY_SLOTS.size():
		var tier: int = MissionCatalog.DAILY_SLOTS[slot]
		var picked: Dictionary = {}
		# Önce tam kurallarla, aday yoksa kural gevşetilerek (kademe → aynı kategori sınırı → tekrar)
		for relax: int in 4:
			var pool: Array[Dictionary] = _eligible(templates, profile, tier, slot, used_metrics, cat_count, relax)
			if pool.is_empty():
				continue
			picked = _pick(pool, profile, yesterday, nudged, rng)
			break
		if picked.is_empty():
			continue
		var cat: int = int(picked["cat"])
		if not bool(profile.get("used", {}).get(cat, true)) and slot > 0:
			nudged = true
		used_metrics[picked["metric"]] = true
		cat_count[cat] = int(cat_count.get(cat, 0)) + 1
		out.append(_make_daily(picked, slot, tier, profile))
	return out


## Haftalık 5 görev: hacim, kazanç, günlük bağı + 2 havuz görevi.
static func weekly(profile: Dictionary, seed_value: int, last_week: Array) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wk: float = weekly_factor(profile)
	var out: Array[Dictionary] = []
	var used_metrics: Dictionary = {}
	for tpl: Dictionary in MissionCatalog.WEEKLY_CORE:
		var target: int
		if tpl["id"] == &"w_daily":
			target = clampi(int(round(float(profile.get("active_days", 4)) * 0.5 * 3.4 * float(profile.get("difficulty", 1.0)))),
				int(tpl["lo"]), int(tpl["hi"]))
		else:
			target = _target(tpl, float(_typical(profile, tpl["base"])) * wk, profile)
		out.append(_make_weekly(tpl, target, out.size(), profile))
		used_metrics[tpl["metric"]] = true
	# 4. slot: kullanılmayan kategoriden (nudge); 5. slot: en çok kullanılan kategori ya da zor hedef
	for slot: int in [3, 4]:
		var pool: Array[Dictionary] = []
		for tpl: Dictionary in MissionCatalog.WEEKLY_POOL:
			if used_metrics.has(tpl["metric"]) or not _requirement_ok(StringName(tpl.get("req", &"")), profile):
				continue
			pool.append(tpl)
		if pool.is_empty():
			break
		var weights: PackedFloat32Array = PackedFloat32Array()
		for tpl: Dictionary in pool:
			var w: float = float(tpl["weight"])
			var unused: bool = not bool(profile.get("used", {}).get(int(tpl["cat"]), true))
			if slot == 3 and unused:
				w *= 2.0
			elif slot == 4 and not unused:
				w *= 1.5
			if last_week.has(String(tpl["id"])):
				w *= 0.25
			weights.append(w)
		var chosen: Dictionary = pool[_weighted_index(weights, rng)]
		var target: int = _weekly_pool_target(chosen, wk, profile)
		out.append(_make_weekly(chosen, target, slot, profile))
		used_metrics[chosen["metric"]] = true
	return out


## Haftalık çarpan: tipik günlük × beklenen aktif gün × 0,9, DDA ile. Sınır 2,5–5 aktif gün.
static func weekly_factor(profile: Dictionary) -> float:
	var active_per_week: float = clampf(float(profile.get("active_days", 8)) * 0.5, 2.5, 5.0)
	return active_per_week * 0.8 * clampf(float(profile.get("difficulty", 1.0)), 0.8, 1.2)


# --- Seçim -----------------------------------------------------------------------------------

## İş şablonu açık işlere göre genişletilir: id "job:<iş>", metrik "job_<iş>".
static func _expand_daily(profile: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tpl: Dictionary in MissionCatalog.DAILY:
		if tpl["id"] != &"job":
			out.append(tpl)
			continue
		for job: Dictionary in profile.get("jobs", []):
			var copy: Dictionary = tpl.duplicate()
			copy["id"] = StringName("job:%s" % job["id"])
			copy["metric"] = StringName("job_%s" % job["id"])
			copy["base"] = copy["metric"]
			copy["job"] = job["id"]
			copy["long_job"] = bool(job.get("long", false))
			if bool(job.get("long", false)):
				copy["lo"] = 1
				copy["hi"] = 8
			out.append(copy)
	return out


static func _eligible(templates: Array[Dictionary], profile: Dictionary, tier: int, slot: int,
		used_metrics: Dictionary, cat_count: Dictionary, relax: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for tpl: Dictionary in templates:
		if relax < 1 and int(tpl["tier"]) != tier:
			continue
		if relax >= 1 and absi(int(tpl["tier"]) - tier) > 1:
			continue
		if used_metrics.has(tpl["metric"]):
			continue
		if not _requirement_ok(StringName(tpl.get("req", &"")), profile):
			continue
		var cat: int = int(tpl["cat"])
		if slot == 0 and cat != Cat.REPAIR and cat != Cat.EARN:
			continue   # konfor görevi: oyuncunun zaten yaptığı şey
		if relax < 2 and int(cat_count.get(cat, 0)) >= 2:
			continue
		if relax < 2 and slot > 0 and int(cat_count.get(cat, 0)) >= 1 and (cat == Cat.REPAIR or cat == Cat.EARN) \
				and int(cat_count.get(Cat.REPAIR, 0)) + int(cat_count.get(Cat.EARN, 0)) >= 2:
			continue   # tamir + kazanç ailesi en çok 2 görev
		out.append(tpl)
	return out


static func _pick(pool: Array[Dictionary], profile: Dictionary, yesterday: Array, nudged: bool,
		rng: RandomNumberGenerator) -> Dictionary:
	var weights: PackedFloat32Array = PackedFloat32Array()
	var used: Dictionary = profile.get("used", {})
	var favorite: int = _favorite_category(used, profile)
	for tpl: Dictionary in pool:
		var w: float = float(tpl["weight"])
		if yesterday.has(String(tpl["id"])):
			w *= 0.25
		var cat: int = int(tpl["cat"])
		if not nudged and not bool(used.get(cat, true)):
			w *= 1.6
		if cat == favorite:
			w *= 1.3
		weights.append(w)
	return pool[_weighted_index(weights, rng)]


## Son 7 günde en çok yapılan kategori (yoksa -1).
static func _favorite_category(used: Dictionary, profile: Dictionary) -> int:
	var best: int = -1
	var best_value: float = 0.0
	for cat: int in MissionCatalog.CAT_METRICS:
		var total: float = 0.0
		for metric: StringName in MissionCatalog.CAT_METRICS[cat]:
			total += float(profile.get("typical", {}).get(metric, 0.0))
		if bool(used.get(cat, false)) and total > best_value:
			best_value = total
			best = cat
	return best


static func _weighted_index(weights: PackedFloat32Array, rng: RandomNumberGenerator) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


## Şablon açık mı? (özellik / durum şartı)
static func _requirement_ok(req: StringName, profile: Dictionary) -> bool:
	if int(profile.get("level", 1)) < MissionCatalog.MIN_LEVEL:
		return false
	match req:
		&"": return true
		&"race": return bool(profile.get("race_ok", false))
		&"job": return not (profile.get("jobs", []) as Array).is_empty()
		&"long_job":
			for job: Dictionary in profile.get("jobs", []):
				if bool(job.get("long", false)):
					return true
			return false
		&"crate_open": return int(profile.get("crate_waiting", 0)) > 0 or int(profile.get("gems", 0)) >= int(profile.get("min_crate_price", 9999))
		&"crate_buy": return int(profile.get("gems", 0)) >= int(profile.get("min_crate_price", 9999))
		&"paint": return bool(profile.get("paint_ready", false))
		&"decor": return bool(profile.get("decor_ready", false))
		&"display": return bool(profile.get("display_ready", false))
		&"growth": return bool(profile.get("growth_ready", false))
		&"spend": return int(profile.get("level", 1)) >= 6
	return true


# --- Hedef ve ödül -------------------------------------------------------------------------------

static func _typical(profile: Dictionary, metric: StringName) -> float:
	return float((profile.get("typical", {}) as Dictionary).get(metric, 0.0))


## hedef = güzel_yuvarla(değer) sınırlar içinde.
static func _target(tpl: Dictionary, value: float, _profile: Dictionary) -> int:
	var lo: int = int(tpl["lo"])
	var hi: int = int(tpl["hi"])
	return clampi(_nice(value, StringName(tpl.get("step", &"one"))), lo, hi)


static func _nice(value: float, step: StringName) -> int:
	match step:
		&"count":
			return maxi(int(round(value / 5.0)) * 5, 5)
		&"money":
			var unit: int = 50 if value < 2000.0 else (100 if value < 10000.0 else (500 if value < 50000.0 else 1000))
			return maxi(int(round(value / float(unit))) * unit, unit)
	return maxi(int(round(value)), 1)


static func _make_daily(tpl: Dictionary, slot: int, tier: int, profile: Dictionary) -> Dictionary:
	var factor: float = float(MissionCatalog.TIER_FACTOR[tier]) * float(profile.get("difficulty", 1.0))
	var typical: float = _typical(profile, tpl["base"])
	var target: int = _target(tpl, typical * factor, profile)
	# Tamamlanabilirlik: hedef tipik günlüğün 1,05 katını aşmasın (alt sınır buna rağmen geçerliyse oyuncunun
	# yapmadığı bir kategoriye yönlendirme: "nudge", hedef alt sınırdadır)
	if typical > 0.0:
		target = mini(target, maxi(int(ceil(typical * 1.05)), int(tpl["lo"])))
	var share: float = float(MissionCatalog.DAILY_SHARE[tier])
	return {
		"id": tpl["id"], "slot": slot, "cat": tpl["cat"], "tier": tier, "metric": tpl["metric"], "target": target,
		"money": _round10(maxf(_typical(profile, &"repair_money") * share, _reward_floor(profile))),
		"xp": maxi(int(round(_typical(profile, &"repairs") * float(profile.get("repair_xp", 10.0)) * share)), 1),
		"claimed": false,
	}


static func _make_weekly(tpl: Dictionary, target: int, slot: int, profile: Dictionary) -> Dictionary:
	var wk: float = weekly_factor(profile)
	return {
		"id": tpl["id"], "slot": slot, "cat": tpl["cat"], "tier": Tier.HARD, "metric": tpl["metric"], "target": target,
		"money": _round10(maxf(_typical(profile, &"repair_money") * wk * MissionCatalog.WEEKLY_SHARE, _reward_floor(profile) * 3.0)),
		"gems": MissionCatalog.WEEKLY_GEMS,
		"xp": maxi(int(round(_typical(profile, &"repairs") * wk * float(profile.get("repair_xp", 10.0)) * MissionCatalog.WEEKLY_SHARE)), 1),
		"claimed": false,
	}


## Ödül alt sınırı: yarım dakikalık gelir.
static func _reward_floor(profile: Dictionary) -> float:
	return float(profile.get("income_per_min", 100.0)) * MissionCatalog.REWARD_FLOOR_MIN


static func _weekly_pool_target(tpl: Dictionary, wk: float, profile: Dictionary) -> int:
	match tpl["id"]:
		&"w_days":
			return 5 if int(profile.get("active_days", 8)) >= 8 else 4
		&"w_perfect":
			return 3 if int(profile.get("active_days", 8)) >= 8 else 2
	return _target(tpl, _typical(profile, tpl["base"]) * wk, profile)


static func _round10(value: float) -> int:
	return maxi(int(round(value / 10.0)) * 10, 10)
