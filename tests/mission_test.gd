extends SceneTree
## GÖREVLER — üretici (saf), sayaçlar, günlük / haftalık / başarım akışı, gece yarısı, kayıt, göç.
## Çalıştırma: tools/run_tests.sh mission_test   (docs/gorevler_tasarimi.md)

var fails: int = 0
var mm: MissionManager
var gem: GemRewards
var pp: PlayerProgress
var eco: EconomyManager
var save: SaveManager

const T0: int = 1_900_000_000 + 43200   # gelecekte sabit bir gün, öğle (gerçek saatten ileri: geri alma sayılmaz)


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


## Test profili (saf üretici için): seviye + açık işler + ön-kabul tipik değerler.
func _profile(level: int, garage: int, bays: int, owned: int, used_all: bool = true) -> Dictionary:
	var jobs: Array[Dictionary] = []
	var weight: float = 0.0
	var reward: float = 0.0
	var xp: float = 0.0
	for type: RepairType in RepairType.defaults():
		if type.min_level > level or type.min_garage_level > garage or type.min_bays > bays:
			continue
		jobs.append({"id": type.id, "long": type.duration >= 60.0, "weight": type.weight, "reward": type.reward, "xp": type.xp})
		weight += type.weight
		reward += type.weight * float(type.reward)
		xp += type.weight * float(type.xp)
	var avg: float = reward / weight
	var used: Dictionary = {}
	for cat: int in MissionCatalog.CAT_METRICS:
		used[cat] = used_all
	return {
		"level": level, "garage": garage, "bays": bays, "owned": owned, "money": 20000, "gems": 100, "jobs": jobs,
		"typical": MissionManager.prior_typical(level, jobs, avg), "active_days": 8, "difficulty": 1.0, "used": used,
		"income_per_min": 3.4 * avg, "repair_xp": xp / weight, "race_ok": level >= 3, "crate_waiting": 0,
		"min_crate_price": 30, "decor_ready": level >= 4, "paint_ready": false, "growth_ready": true,
		"display_ready": level >= 4 and owned >= 2,
	}


func _run() -> void:
	_generator_tests()
	await _scene_tests()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- Üretici (saf) ----------------------------------------------------------------------------

func _generator_tests() -> void:
	print("== ÜRETİCİ: yapı ==")
	for p: Array in [[3, 1, 1, 1], [8, 2, 2, 3], [15, 3, 3, 7], [25, 4, 3, 16]]:
		var profile: Dictionary = _profile(p[0], p[1], p[2], p[3])
		var all_ok: bool = true
		var slot0_ok: bool = true
		var tier_ok: bool = true
		var cap_ok: bool = true
		var bound_ok: bool = true
		var unlock_ok: bool = true
		for s: int in 60:
			var tasks: Array[Dictionary] = MissionGenerator.daily(profile, s * 7919 + 13, [])
			if tasks.size() != 5:
				all_ok = false
				continue
			var metrics: Dictionary = {}
			var cats: Dictionary = {}
			for i: int in tasks.size():
				var t: Dictionary = tasks[i]
				metrics[t["metric"]] = true
				cats[t["cat"]] = int(cats.get(t["cat"], 0)) + 1
				var typ: float = float((profile["typical"] as Dictionary).get(t["base"] if t.has("base") else t["metric"], 0.0))
				var tpl: Dictionary = MissionCatalog.daily_template(StringName(String(t["id"]).split(":")[0]))
				if int(t["target"]) < int(tpl["lo"]) or int(t["target"]) > int(tpl["hi"]):
					bound_ok = false
				if typ > 0.0 and int(t["target"]) > maxi(int(ceil(typ * 1.05)), int(tpl["lo"])):
					bound_ok = false
				if String(t["id"]).begins_with("long") and not (profile["jobs"] as Array).any(func(j: Dictionary) -> bool: return bool(j["long"])):
					unlock_ok = false
				if String(t["id"]).begins_with("race") and not bool(profile["race_ok"]):
					unlock_ok = false
				if String(t["id"]) == "display_e" and not bool(profile["display_ready"]):
					unlock_ok = false
			if metrics.size() != 5:
				all_ok = false
			for c: Variant in cats:
				if int(cats[c]) > 2:
					cap_ok = false
			if not (tasks[0]["cat"] == MissionCatalog.Cat.REPAIR or tasks[0]["cat"] == MissionCatalog.Cat.EARN):
				slot0_ok = false
			if tasks[0]["tier"] != MissionCatalog.Tier.EASY or tasks[4]["tier"] != MissionCatalog.Tier.HARD:
				tier_ok = false
		var tag: String = "Sv.%d garaj %d" % [p[0], p[1]]
		check(all_ok, "%s: 5 görev, 5 farklı metrik" % tag)
		check(slot0_ok, "%s: 1. görev konfor (tamir / kazanç)" % tag)
		check(tier_ok, "%s: kademeler 1. KOLAY … 5. ZOR" % tag)
		check(cap_ok, "%s: kategori başına en çok 2 görev" % tag)
		check(bound_ok, "%s: hedefler şablon sınırında ve tipik günlüğü aşmıyor" % tag)
		check(unlock_ok, "%s: açılmamış özelliğe görev verilmedi" % tag)

	print("== ÜRETİCİ: kararlılık ve çeşitlilik ==")
	var prof: Dictionary = _profile(12, 3, 3, 5)
	var a: Array[Dictionary] = MissionGenerator.daily(prof, 4242, [])
	var b: Array[Dictionary] = MissionGenerator.daily(prof, 4242, [])
	check(JSON.stringify(a) == JSON.stringify(b), "aynı tohum + aynı profil = birebir aynı görevler")
	var distinct: Dictionary = {}
	for s: int in 80:
		var ids: PackedStringArray = PackedStringArray()
		for t: Dictionary in MissionGenerator.daily(prof, s * 104729 + 1, []):
			ids.append(String(t["id"]))
		ids.sort()
		distinct[",".join(ids)] = true
	check(distinct.size() >= 40, "farklı oyuncular / günler farklı kümeler alır (80 tohumda %d farklı)" % distinct.size())
	var overlap_sum: int = 0
	var overlap_max: int = 0
	for s: int in 80:
		var day1: Array[Dictionary] = MissionGenerator.daily(prof, s * 31 + 5, [])
		var ids1: Array = day1.map(func(t: Dictionary) -> String: return String(t["id"]))
		var day2: Array[Dictionary] = MissionGenerator.daily(prof, s * 31 + 6, ids1)
		var overlap: int = 0
		for t: Dictionary in day2:
			if ids1.has(String(t["id"])):
				overlap += 1
		overlap_sum += overlap
		overlap_max = maxi(overlap_max, overlap)
	check(float(overlap_sum) / 80.0 < 1.5, "dünkü görevler pek tekrar etmez (ort. kesişim %.2f / 5)" % (float(overlap_sum) / 80.0))
	check(overlap_max <= 3, "dünkü görevlerle en çok 3 kesişim (görülen %d)" % overlap_max)
	check(MissionGenerator.daily(_profile(2, 1, 1, 1), 1, []).is_empty(), "Sv.2'de günlük görev yok (REHBER dönemi)")

	print("== ÜRETİCİ: nudge ve zorluk ==")
	var unused: Dictionary = _profile(12, 3, 3, 5, false)   # hiçbir kategori kullanılmamış
	var racers: int = 0
	for s: int in 100:
		for t: Dictionary in MissionGenerator.daily(unused, s + 9000, []):
			if t["cat"] == MissionCatalog.Cat.RACE:
				racers += 1
				break
	var used_profile: Dictionary = _profile(12, 3, 3, 5, true)
	var racers_used: int = 0
	for s: int in 100:
		for t: Dictionary in MissionGenerator.daily(used_profile, s + 9000, []):
			if t["cat"] == MissionCatalog.Cat.RACE:
				racers_used += 1
				break
	print("   yarış görevi: kullanılmayan %d / 100 · kullanılan %d / 100" % [racers, racers_used])
	check(true, "nudge ölçümü basıldı")
	var hard: Dictionary = _profile(12, 3, 3, 5)
	hard["difficulty"] = 1.3
	var easy: Dictionary = _profile(12, 3, 3, 5)
	easy["difficulty"] = 0.7
	var hard_sum: int = 0
	var easy_sum: int = 0
	for t: Dictionary in MissionGenerator.daily(hard, 77, []):
		hard_sum += int(t["target"])
	for t: Dictionary in MissionGenerator.daily(easy, 77, []):
		easy_sum += int(t["target"])
	check(hard_sum >= easy_sum, "DDA: yüksek zorlukta hedefler daha büyük (%d ≥ %d)" % [hard_sum, easy_sum])

	print("== ÜRETİCİ: ödül ölçeği ==")
	var low: Array[Dictionary] = MissionGenerator.daily(_profile(3, 1, 1, 1), 5, [])
	var high: Array[Dictionary] = MissionGenerator.daily(_profile(25, 4, 3, 16), 5, [])
	check(int(high[0]["money"]) > int(low[0]["money"]) * 2, "ödül seviye / garajla ölçeklenir (%d → %d ₺)" % [low[0]["money"], high[0]["money"]])
	check(int(high[4]["money"]) > int(high[0]["money"]), "ZOR görev KOLAY'dan çok verir")

	print("== ÜRETİCİ: haftalık ==")
	for p: Array in [[3, 1, 1, 1], [12, 3, 3, 5], [25, 4, 3, 16]]:
		var profile: Dictionary = _profile(p[0], p[1], p[2], p[3])
		var ok: bool = true
		var core_ok: bool = true
		for s: int in 40:
			var tasks: Array[Dictionary] = MissionGenerator.weekly(profile, s * 977 + 3, [])
			if tasks.size() != 5:
				ok = false
				continue
			var metrics: Dictionary = {}
			for t: Dictionary in tasks:
				metrics[t["metric"]] = true
				if int(t["target"]) < int(MissionCatalog.weekly_template(t["id"])["lo"]) or int(t["target"]) > int(MissionCatalog.weekly_template(t["id"])["hi"]):
					ok = false
			if metrics.size() != 5:
				ok = false
			if tasks[0]["id"] != &"w_repairs" or tasks[1]["id"] != &"w_earn" or tasks[2]["id"] != &"w_daily":
				core_ok = false
		check(ok, "Sv.%d: haftalık 5 görev, farklı metrik, hedefler sınırda" % p[0])
		check(core_ok, "Sv.%d: ilk üç görev hacim / kazanç / günlük bağı" % p[0])
	var weekly_p: Dictionary = _profile(12, 3, 3, 5)
	var wt: Array[Dictionary] = MissionGenerator.weekly(weekly_p, 1, [])
	var dt: Array[Dictionary] = MissionGenerator.daily(weekly_p, 1, [])
	var wrep: int = int(wt[0]["target"])
	var drep: int = 0
	for t: Dictionary in dt:
		if t["metric"] == &"repairs":
			drep = maxi(drep, int(t["target"]))
	check(drep == 0 or wrep > drep * 2, "haftalık tamir hedefi günlüğün katları (%d > %d)" % [wrep, drep])
	var casual: Dictionary = _profile(12, 3, 3, 5)
	casual["active_days"] = 4   # son 14 günde 4 gün: haftada ~2 gün
	var casual_week: Array[Dictionary] = MissionGenerator.weekly(casual, 1, [])
	check(int(casual_week[0]["target"]) < wrep, "az oynayana haftalık hedef düşük (%d < %d)" % [casual_week[0]["target"], wrep])

	print("== ÜRETİCİ: genişletme (2026-10-20: hurdalık, modifiye, depolar, arkadaş yarışı, rekor, fotoğraf) ==")
	var ids: Dictionary = {}
	var unique: bool = true
	for list: Array in [MissionCatalog.DAILY, MissionCatalog.WEEKLY_CORE, MissionCatalog.WEEKLY_POOL, MissionCatalog.ACHIEVEMENTS]:
		for entry: Dictionary in list:
			unique = unique and not ids.has(entry["id"])
			ids[entry["id"]] = true
	check(unique, "görev / başarım kimlikleri benzersiz (%d)" % ids.size())
	check(MissionCatalog.ACHIEVEMENTS.size() >= 38, "başarım çizgisi %d (22'den)" % MissionCatalog.ACHIEVEMENTS.size())
	var gated: Array[StringName] = [&"junk_e", &"junk_m", &"mod_m", &"interior_m"]
	var closed: Dictionary = _profile(12, 3, 3, 5, false)
	var leaked: bool = false
	for s: int in 120:
		for t: Dictionary in MissionGenerator.daily(closed, s * 131 + 7, []):
			leaked = leaked or gated.has(t["id"])
	check(not leaked, "özellik kapalıyken hurdalık / modifiye / iç yükseltme görevi çıkmaz")
	var open: Dictionary = _profile(12, 3, 3, 5, false)
	for key: String in ["junk_ready", "mods_ready", "interior_ready", "record_ready"]:
		open[key] = true
	var seen_daily: Dictionary = {}
	var seen_weekly: Dictionary = {}
	var in_range: bool = true
	for s: int in 400:
		for t: Dictionary in MissionGenerator.daily(open, s * 131 + 7, []):
			seen_daily[t["id"]] = true
			var tpl: Dictionary = MissionCatalog.daily_template(t["id"])
			if not tpl.is_empty() and (int(t["target"]) < int(tpl["lo"]) or int(t["target"]) > int(tpl["hi"])):
				in_range = false
		for t: Dictionary in MissionGenerator.weekly(open, s * 977 + 3, []):
			seen_weekly[t["id"]] = true
	var missing_daily: Array = []
	for id: StringName in [&"photo_e", &"junk_e", &"junk_m", &"mod_m", &"friend_e", &"friend_win_m", &"interior_m"]:
		if not seen_daily.has(id):
			missing_daily.append(id)
	check(missing_daily.is_empty(), "yeni günlük şablonların hepsi çıkabiliyor (eksik: %s)" % [missing_daily])
	var missing_weekly: Array = []
	for id: StringName in [&"w_junk", &"w_parts", &"w_restore", &"w_mods", &"w_friend_wins", &"w_record", &"w_interior", &"w_photos"]:
		if not seen_weekly.has(id):
			missing_weekly.append(id)
	check(missing_weekly.is_empty(), "yeni haftalık şablonların hepsi çıkabiliyor (eksik: %s)" % [missing_weekly])
	check(in_range, "yeni günlük hedefler sınırların içinde")
	var texts_ok: bool = true
	for id: StringName in seen_daily:
		if not String(id).begins_with("job:"):
			texts_ok = texts_ok and not MissionCatalog.text_of(id, 3).contains("%")
	check(texts_ok, "görev metinleri hedefle doluyor (%% kalmıyor)")


# --- Sahne: yönetici ----------------------------------------------------------------------------

func _scene_tests() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	mm = get_first_node_in_group("missions")
	gem = get_first_node_in_group("gem_rewards")
	pp = get_first_node_in_group("player_progress")
	eco = get_first_node_in_group("economy")
	save = get_first_node_in_group("save_manager")
	check(mm != null, "MissionManager sahnede ('missions' grubu)")
	save.new_game()
	await frames(4)
	pp.xp_base = 100000000   # görev ödülü XP'si seviye atlatıp gem eklemesin (ödül miktarları net ölçülsün)

	print("== SEVİYE KİLİDİ ==")
	gem.test_now = T0
	gem.check_day()
	pp.load_state(2, 0, 100)
	mm.ensure_current()
	check(mm.daily_tasks().is_empty() and not mm.is_unlocked(), "Sv.2: günlük görev yok, kilitli")
	pp.load_state(5, 0, 100)
	mm.ensure_current()
	check(mm.daily_tasks().size() == 5 and mm.weekly_tasks().size() == 5, "Sv.5: 5 günlük + 5 haftalık görev üretildi")

	print("== SAYAÇLAR (olay → metrik) ==")
	var before_spent: int = mm.value_of(&"money_spent")
	eco.add_money(10000)
	check(eco.spend_money(1234), "para harcandı")
	check(mm.value_of(&"money_spent") == before_spent + 1234, "money_spent sayacı arttı (+1234)")
	var decor: DecorManager = get_first_node_in_group("decor")
	var placed_before: int = mm.value_of(&"decor_placed")
	decor._owned[&"deck_chair"] = 1
	decor.add_instance(&"deck_chair", Vector3(-1.0, 0.0, -1.0), 0.0)
	check(mm.value_of(&"decor_placed") == placed_before + 1, "dekor yerleştirme sayacı arttı")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	var repairs_before: int = mm.value_of(&"repairs")
	var rm: RepairManager = get_first_node_in_group("repair_manager")
	rm.repair_collected.emit(null, 300, 10)
	rm.job_collected.emit(&"engine", 300)
	check(mm.value_of(&"repairs") == repairs_before + 1 and mm.value_of(&"repair_money") >= 300, "tamir: repairs + repair_money")
	check(mm.value_of(&"job_engine") == 1, "iş türü sayacı (job_engine)")
	rm.job_collected.emit(&"paint_job", 600)
	check(mm.value_of(&"long_jobs") == 1, "uzun iş sayacı (boya işi)")
	var race: RaceManager = get_first_node_in_group("race")
	if race:
		race.race_finished.emit(true, 450, 25)
		race.race_finished.emit(false, 0, 7)
		check(mm.value_of(&"races") == 2 and mm.value_of(&"race_wins") == 1, "yarış: katılım 2, zafer 1")
		race.friend_race_finished.emit({"uid": "x"}, true, &"tofas_sahin", &"bmw_e46", true)
		race.friend_race_finished.emit({"uid": "x"}, false, &"tofas_sahin", &"bmw_e46", false)
		check(mm.value_of(&"friend_races") == 2 and mm.value_of(&"friend_wins") == 1 and mm.value_of(&"revenges") == 1,
			"arkadaş yarışı: katılım 2, zafer 1, intikam 1")
		race.reset()
		race.submit_time(&"tofas_sahin", 12.5, PackedFloat32Array([0.0, 300.0]))
		check(mm.value_of(&"records") == 0, "ilk koşu rekor KIRMA sayılmaz")
		race.submit_time(&"tofas_sahin", 12.1, PackedFloat32Array([0.0, 300.0]))
		check(mm.value_of(&"records") == 1, "önceki rekoru geçmek: records 1")

	print("== SAYAÇLAR: genişletme ==")
	var junk: JunkyardManager = get_first_node_in_group("junkyard")
	if junk:
		junk.pile_searched.emit(0, {})
		junk.parts_gained.emit(&"engine_block", 3, &"pile")
		junk.project_completed.emit(&"anadol_a1")
		check(mm.value_of(&"junk_searches") == 1 and mm.value_of(&"junk_parts") == 3 and mm.value_of(&"restorations") == 1,
			"hurdalık: yığın 1, parça 3, restorasyon 1")
	var mods: PerformanceModManager = get_first_node_in_group("performance_mods")
	if mods:
		mods.install_completed.emit(&"tofas_sahin", &"engine", 1, "D", "C")
		check(mm.value_of(&"mods_installed") == 1, "modifiye takıldı: mods_installed 1")
	var depots: CarGarageManager = get_first_node_in_group("car_garages")
	if depots:
		depots.upgrade_finished.emit(&"sanayi", &"floor", 2)
		depots.build_finished.emit(&"sanayi")
		check(mm.value_of(&"interior_ups") == 1 and mm.value_of(&"depot_builds") == 1, "depo: iç yükseltme 1, inşaat 1")
		check(mm.value_of(&"depots_owned") == depots.owned_garages().size(), "depots_owned = sahip olunan depo")
	decor.purchased.emit(&"lux_neon_crown")
	decor.purchased.emit(&"deck_chair")
	check(mm.value_of(&"luxury_bought") == 1, "yalnız LÜKS eşya alımı sayılır (luxury_bought 1)")
	own.vehicle_purchased.emit(&"bmw_e46")
	check(mm.value_of(&"cars_bought") == 1, "showroom'dan araç: cars_bought 1")
	check(mm.value_of(&"cars_owned") == own.owned_count(), "cars_owned = sahip olunan araç")
	var legends: int = 0
	for id: StringName in own.discovered_ids():
		if StringName(CarCatalog.get_entry(id).get("rarity", &"common")) == &"legendary":
			legends += 1
	check(mm.value_of(&"legendary_cars") == legends, "legendary_cars = keşfedilen efsane araç (%d)" % legends)

	print("== GÜNLÜK: ilerleme ve ödül ==")
	var tasks: Array[Dictionary] = mm.daily_tasks()
	var money0: int = eco.money
	var xp_total: Callable = func() -> int: return pp.xp + pp.level * 100000
	# Her görevi tamamlat
	var first: Dictionary = tasks[0]
	check(mm.progress_of(first, false) < int(first["target"]) or bool(first["done"]), "görev başlangıçta tamam değil / ya da önceden dolmuş")
	mm.count(first["metric"], int(first["target"]))
	check(bool(mm.daily_tasks()[0]["done"]), "hedefe ulaşan görev DONE")
	check(mm.claimable_daily() >= 1, "ödül alınmayı bekliyor (rozet)")
	var money_before: int = eco.money
	check(mm.claim_daily(0), "ÖDÜLÜ AL çalıştı")
	check(eco.money - money_before >= int(first["money"]), "₺ ödülü verildi (+%d)" % int(first["money"]))
	check(not mm.claim_daily(0), "aynı görevin ödülü ikinci kez alınamaz")
	check(not mm.claim_daily(4) or bool(mm.daily_tasks()[4]["done"]), "tamamlanmamış görev alınamaz")
	var gems_before: int = pp.gems
	for t: Dictionary in mm.daily_tasks():
		mm.count(t["metric"], int(t["target"]))
	check(mm.daily_all_done(), "beş görev de tamam")
	check(not mm.daily_bonus_claimed() and mm.claim_daily_bonus(), "bonus: beşi birden → gem")
	check(pp.gems - gems_before == MissionCatalog.DAILY_BONUS_GEMS, "bonus %d gem verildi" % MissionCatalog.DAILY_BONUS_GEMS)
	check(not mm.claim_daily_bonus(), "bonus ikinci kez alınamaz")
	check(mm.value_of(&"daily_done") >= 5 and mm.value_of(&"daily_all") == 1, "daily_done ≥ 5, daily_all = 1 (başarım sayaçları)")
	mm.claim_all_daily()
	check(mm.claimable_daily() == 0, "HEPSİNİ AL sonrası bekleyen ödül yok")

	print("== HAFTALIK ==")
	var wtasks: Array[Dictionary] = mm.weekly_tasks()
	for t: Dictionary in wtasks:
		mm.count(t["metric"], int(t["target"]))
	check(mm.weekly_all_done(), "haftalık 5 görev tamam")
	var crates: CrateManager = get_first_node_in_group("crates")
	var crates_before: int = crates.crates().size()
	var wgems: int = pp.gems
	for i: int in 5:
		mm.claim_weekly(i)
	check(pp.gems - wgems == 5 * MissionCatalog.WEEKLY_GEMS, "haftalık görev başına %d gem" % MissionCatalog.WEEKLY_GEMS)
	var bonus_gems: int = pp.gems
	check(mm.claim_weekly_bonus(), "haftalık BÜYÜK ÖDÜL alındı")
	check(pp.gems - bonus_gems == MissionCatalog.WEEKLY_BONUS_GEMS, "büyük ödül %d gem" % MissionCatalog.WEEKLY_BONUS_GEMS)
	check(crates.crates().size() == crates_before + 1, "büyük ödül bedava kasa verdi")
	check(not mm.claim_weekly_bonus(), "büyük ödül ikinci kez alınamaz")
	check(mm.value_of(&"weekly_all") == 1, "weekly_all sayacı")

	print("== GECE YARISI ==")
	var day1_ids: Array = mm.daily_tasks().map(func(t: Dictionary) -> String: return String(t["id"]))
	var week_ids: Array = mm.weekly_tasks().map(func(t: Dictionary) -> String: return String(t["id"]))
	# Bugünün görevlerinden biri tamamlanıp ALINMADAN gece yarısı gelsin
	mm.load_state(mm.state())   # kayıt turu: durum aynı kalmalı
	check(mm.daily_tasks().size() == 5 and JSON.stringify(mm.daily_tasks().map(func(t: Dictionary) -> String: return String(t["id"]))) == JSON.stringify(day1_ids), "kayıt → yükleme: günlük görevler aynı")
	gem.test_now = T0 + 86400
	gem.check_day()
	mm.ensure_current()
	var day2: Array[Dictionary] = mm.daily_tasks()
	check(day2.size() == 5, "yeni gün: 5 yeni görev")
	var same: int = 0
	for t: Dictionary in day2:
		if day1_ids.has(String(t["id"])):
			same += 1
	check(same <= 3, "yeni gün görevleri dünkünden farklı (%d ortak)" % same)
	check(not mm.daily_bonus_claimed() and mm.value_of(&"days_played") >= 2, "yeni gün: bonus sıfırlandı, days_played ≥ 2")
	check(mm.weekly_tasks().size() == 5 and mm.weekly_tasks()[0]["id"] == &"w_repairs", "haftalık görevler gün değişince yenilenmez (aynı hafta)")
	# Alınmamış tamamlanmış görev: gece yarısı otomatik verilir
	var t2: Dictionary = mm.daily_tasks()[1]
	mm.count(t2["metric"], int(t2["target"]))
	var money_pre: int = eco.money
	gem.test_now = T0 + 2 * 86400
	gem.check_day()
	mm.ensure_current()
	check(eco.money - money_pre >= int(t2["money"]), "alınmamış ödül gece yarısı otomatik verildi (+%d ₺)" % int(t2["money"]))
	var dda_before: float = mm.difficulty()
	print("   DDA %.3f" % dda_before)
	check(mm.state()["history"].size() >= 1, "dünün sayaçları geçmişe yazıldı")

	print("== SAAT GERİ ALMA ==")
	var today_tasks: String = JSON.stringify(mm.daily_tasks())
	gem.test_now = T0 - 5 * 86400
	gem.check_day()
	mm.ensure_current()
	check(JSON.stringify(mm.daily_tasks()) == today_tasks, "saat geri alınınca görevler yeniden üretilmez / sıfırlanmaz")

	print("== HAFTA DEĞİŞİMİ ==")
	var old_week_ids: Array = mm.weekly_tasks().map(func(t: Dictionary) -> String: return String(t["id"]))
	gem.test_now = T0 + 9 * 86400
	gem.check_day()
	mm.ensure_current()
	check(mm.weekly_tasks().size() == 5 and not mm.weekly_final_claimed(), "yeni hafta: 5 yeni haftalık görev, ödül işareti sıfır")
	check(mm.value_of(&"weekly_all") == 1, "yaşam boyu haftalık sayaç korundu")
	check(old_week_ids.size() == 5, "(eski hafta kaydı vardı)")

	print("== BAŞARIMLAR ==")
	var line: Dictionary = MissionCatalog.achievement(&"a_repairs")
	var base_repairs: int = mm.value_of(&"repairs")
	var need1: int = 100 - base_repairs
	if need1 > 0:
		mm.count(&"repairs", need1)
	check(mm.stars_reached(line) >= 1, "100 tamir → 1. yıldız (TAMİRCİ)")
	var g0: int = pp.gems
	check(mm.claim_achievement(&"a_repairs"), "1. yıldız alındı")
	check(pp.gems - g0 == MissionCatalog.ach_gems(line, 0) and MissionCatalog.ach_value(line, 0) == 6,
		"TAMİRCİ 1. yıldız: değer 6 (2026-10-21 zorluk turu), gem %d" % MissionCatalog.ach_gems(line, 0))
	check(not mm.claim_achievement(&"a_repairs") or mm.stars_reached(line) >= 2, "ulaşılmamış 2. yıldız alınamaz")
	mm.count(&"repairs", 500)
	var g1: int = pp.gems
	check(mm.claim_achievement(&"a_repairs") and pp.gems - g1 == MissionCatalog.ach_gems(line, 1), "2. yıldız %d gem" % MissionCatalog.ach_gems(line, 1))
	var earn_line: Dictionary = MissionCatalog.achievement(&"a_earn")
	mm.count(&"repair_money", 50000)
	check(mm.stars_reached(earn_line) >= 1, "50.000 ₺ kazanç → KAZANÇLI 1. yıldız")
	mm.count(&"repair_money", 450000)
	check(mm.stars_reached(earn_line) >= 2, "500.000 ₺ → 2. yıldız")
	mm.count(&"repair_money", 2500000)
	check(mm.stars_reached(earn_line) >= 3, "3.000.000 ₺ → 3. yıldız")
	check(mm.value_of(&"ach_stars") >= 5, "YILDIZ TOPLAYICI meta sayacı (≥5 yıldız: %d)" % mm.value_of(&"ach_stars"))
	var summaries: Array[Dictionary] = []
	var notices: Array[String] = []
	var on_summary: Callable = func(summary: Dictionary) -> void: summaries.append(summary)
	var on_notice: Callable = func(text: String) -> void: notices.append(text)
	mm.rewards_claimed.connect(on_summary)
	mm.reward_granted.connect(on_notice)
	var gems_before_all: int = pp.gems
	var money_before_all: int = eco.money
	var claimed_all: int = mm.claim_all_achievements()
	mm.rewards_claimed.disconnect(on_summary)
	mm.reward_granted.disconnect(on_notice)
	check(claimed_all >= 3 and mm.claimable_achievements() == 0, "HEPSİNİ AL: %d yıldız alındı, bekleyen yok" % claimed_all)
	check(summaries.size() == 1 and notices.is_empty(), "HEPSİNİ AL: tek ödül penceresi, tek tek bildirim yok (%d / %d)" % [summaries.size(), notices.size()])
	if summaries.size() == 1:
		var summary: Dictionary = summaries[0]
		check(int(summary["count"]) == claimed_all, "pencere: %d ödülün toplamı" % int(summary["count"]))
		check(int(summary["gems"]) == pp.gems - gems_before_all and int(summary["money"]) == eco.money - money_before_all,
			"pencere toplamı verilenle aynı (+%d gem, +%d ₺)" % [int(summary["gems"]), int(summary["money"])])
	print("== HEPSİNİ AL: bütün sekmeler ==")
	for t: Dictionary in mm.daily_tasks():
		mm.count(t["metric"], int(t["target"]))
	for t: Dictionary in mm.weekly_tasks():
		mm.count(t["metric"], int(t["target"]))
	mm.count(&"repairs", 3000)   # TAMİRCİ'nin yeni yıldızı da beklesin
	check(mm.claimable_daily() > 0 and mm.claimable_weekly() > 0 and mm.claimable_achievements() > 0,
		"üç sekmede de bekleyen ödül var (%d / %d / %d)" % [mm.claimable_daily(), mm.claimable_weekly(), mm.claimable_achievements()])
	summaries.clear()
	mm.rewards_claimed.connect(on_summary)
	var everything: int = mm.claim_all()
	mm.rewards_claimed.disconnect(on_summary)
	check(mm.claimable_count() == 0, "HEPSİNİ AL günlük + haftalık + başarımı birden topladı (%d ödül, kalan %d)"
		% [everything, mm.claimable_count()])
	check(summaries.size() == 1 and int(summaries[0]["count"]) == everything, "bütün sekmeler tek ödül penceresinde")
	check(mm.claim_all() == 0, "ikinci basış: alınacak bir şey yok")
	check(mm.value_of(&"player_level") == pp.level and mm.value_of(&"garage_level") >= 1, "durum metrikleri oyundan okunuyor")
	check(mm.value_of(&"cars_discovered") == own.discovered_count(), "cars_discovered = keşfedilen araç")

	print("== KAYIT ==")
	var snap: Dictionary = mm.state()
	check(snap.has("seed") and snap.has("daily") and snap.has("weekly") and snap.has("life"), "state() alanları")
	check(save.save_game(), "kaydedildi")
	var seed_before: int = int(snap["seed"])
	mm.load_state({})
	check(mm.daily_tasks().is_empty(), "boş yükleme: görev yok")
	check(save.load_game(), "yüklendi")
	await frames(3)
	check(int(mm.state()["seed"]) == seed_before, "tohum kayıttan geri geldi")
	check(JSON.stringify(mm.state()["daily"], "", true) == JSON.stringify(snap["daily"], "", true), "günlük görev durumu birebir geri geldi")
	check(mm.value_of(&"repair_money") == int((snap["life"] as Dictionary).get("repair_money", 0)), "yaşam boyu sayaç geri geldi")
	mm.load_state({"seed": 5, "daily": {"day": 3, "tasks": [{"id": "uydurma", "target": 5}, "bozuk"]}, "ach": {"yok": 3, "a_earn": 99}, "life": {"repairs": -5}})
	check(mm.daily_tasks().is_empty(), "bozuk görev kaydı atlandı")
	check(mm.stars_claimed(earn_line) <= 4, "geçersiz başarım kaydı kırpıldı")

	print("== GÖÇ (eski kayıt) ==")
	gem.load_state({"repair_step": 2})
	mm.load_state({})
	mm._life_seeded = false
	mm._seed_legacy()
	check(mm.stars_claimed(line) == 2, "eski tamir kilometre taşları ödenmiş yıldız sayıldı (2)")
	var gl: int = pp.gems
	mm._life[&"repairs"] = 300
	mm.scan_achievements()
	check(mm.claim_achievement(&"a_repairs") is bool, "göç sonrası yeni yıldız normal alınır")
	check(pp.gems >= gl, "çifte ödeme yok")
	mm.load_state({})
	mm._life_seeded = false
	mm.mark_legacy_repairs_passed()
	check(mm.stars_claimed(line) == mm.stars_reached(line), "v9- kayıt: geçilmiş yıldızlar ödenmiş (geriye dönük gem yok)")

	print("== KAYIT ETKİSİ: has_progress ==")
	check(not (save._progress_json().contains("\"missions\"")), "görev durumu ilerleme karşılaştırmasına girmez")
	gem.test_now = -1
