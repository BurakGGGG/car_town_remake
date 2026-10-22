extends SceneTree
## KOŞU EŞLEŞTİRME (docs/KOSU_ESLESTIRME.md, Faz 1): zorluk kolu (başlangıç kuralı, seri kırıcı, üç ZOR yok), kazanma şansı,
## oyuncunun süre örnekleri (aynı araç / oran taşıma / yeni oyuncu), yapay zekâ havuzu (pişmiş + güncel), seçicinin hedefi
## tutturması, koşu deposu (sınır, kayıt turu, bozuk veri) ve açık garajdaki koşular.
## Çalıştırma: tools/run_tests.sh rival_select_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


## Oyuncunun koşusu yerine: aracın yapay zekâ koşusu, oyuncu koşusu gibi (gün formu gücü yok, kalkış devri optimum —
## Recording.is_player_run; açık garaj başkasını kabul etmez). Süre tekrarla yeniden hesaplanır.
func _run_of(id: StringName, rng: RandomNumberGenerator, at: int) -> DragRaceSim.Recording:
	var form: DragRaceSim.Form = DragRaceSim.roll_form(id, rng)
	form.power = 1.0
	var recording: DragRaceSim.Recording = DragRaceSim.ai_recording(id, {}, form, rng)
	recording.launch_rpm = roundf(recording.spec().launch_rpm)
	recording.time = DragRaceSim.replay(recording).finish_time
	recording.at = at
	return recording


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77

	print("== 1) Zorluk kolu ==")
	var counts: Dictionary = {RivalSelector.Arm.EASY: 0, RivalSelector.Arm.EVEN: 0, RivalSelector.Arm.HARD: 0}
	var won: Array = [{"w": true, "a": RivalSelector.Arm.EVEN}, {"w": true, "a": RivalSelector.Arm.EVEN}]
	for i: int in 4000:
		counts[RivalSelector.choose_arm(won, rng)] += 1
	check(absf(counts[RivalSelector.Arm.EVEN] / 4000.0 - 0.55) < 0.03 and absf(counts[RivalSelector.Arm.EASY] / 4000.0 - 0.33) < 0.03
		and absf(counts[RivalSelector.Arm.HARD] / 4000.0 - 0.12) < 0.02,
		"başlangıç kuralı: dengeli %d · kolay %d · zor %d / 4000" % [counts[RivalSelector.Arm.EVEN], counts[RivalSelector.Arm.EASY], counts[RivalSelector.Arm.HARD]])
	var lost: Array = [{"w": true, "a": 1}, {"w": false, "a": 1}, {"w": false, "a": 2}]
	var breaker: bool = true
	for i: int in 200:
		breaker = breaker and RivalSelector.choose_arm(lost, rng) == RivalSelector.Arm.EASY
	check(breaker, "üst üste iki kayıptan sonra hep KOLAY (seri kırıcı)")
	var hard: Array = [{"w": true, "a": RivalSelector.Arm.HARD}, {"w": true, "a": RivalSelector.Arm.HARD}]
	var third: int = 0
	for i: int in 2000:
		if RivalSelector.choose_arm(hard, rng) == RivalSelector.Arm.HARD:
			third += 1
	check(third == 0, "üç ZOR üst üste gelmez (%d)" % third)

	print("== 2) Kazanma şansı + oyuncunun örnekleri ==")
	var samples: PackedFloat64Array = PackedFloat64Array([12.20, 12.25, 12.25, 12.30, 12.40])
	var faster: float = RivalSelector.win_chance(samples, 12.10)
	var even: float = RivalSelector.win_chance(samples, 12.27)
	var slower: float = RivalSelector.win_chance(samples, 12.60)
	check(faster < 0.15 and slower > 0.85 and even > 0.35 and even < 0.65,
		"12.25 yapan oyuncu: 12.10'a %.2f · 12.27'ye %.2f · 12.60'a %.2f" % [faster, even, slower])
	check(RivalSelector.win_chance(samples, 12.21) < RivalSelector.win_chance(samples, 12.29), "rakip yavaşladıkça şans artar")
	var fresh: PackedFloat64Array = RivalSelector.samples_for(&"tofas_sahin", {}, {})
	var perfect: float = RivalSelector.perfect_time(&"tofas_sahin", {})
	check(fresh.size() == RivalSelector.MIN_SAMPLES and fresh[0] > perfect, "hiç koşu yok: yeni oyuncu varsayımı (%d örnek)" % fresh.size())
	var runs: Dictionary = {"tofas_sahin": []}
	for i: int in 7:
		(runs["tofas_sahin"] as Array).append(_run_of(&"tofas_sahin", rng, 1000 + i).to_dict())
	var own: PackedFloat64Array = RivalSelector.samples_for(&"tofas_sahin", {}, runs)
	check(own.size() == 7 and own[6] == float((runs["tofas_sahin"] as Array)[6]["t"]), "aynı araçla ≥5 koşu: doğrudan süreleri")
	var other: PackedFloat64Array = RivalSelector.samples_for(&"bmw_e46", {}, runs)
	var ratio: float = float((runs["tofas_sahin"] as Array)[6]["t"]) / perfect
	check(other.size() == 7 and absf(other[0] - ratio * RivalSelector.perfect_time(&"bmw_e46", {})) < 0.0001,
		"başka araçta beceri ORANLA taşınır (en yeni koşu önce)")
	var modded: PackedFloat64Array = RivalSelector.samples_for(&"tofas_sahin", {&"motor": 3}, runs)
	check(modded[0] < own[6], "modifiye gelince eski koşular yeni kusursuz süreye ölçeklenir")

	print("== 3) Yapay zekâ havuzu ==")
	var stale: Array[String] = []
	for entry: Dictionary in CarCatalog.all():
		if RivalPool.baked_times(entry["id"]).size() != RivalPool.SIZE:
			stale.append(String(entry["id"]))
	check(stale.is_empty(), "pişmiş havuz bütün araçlarda güncel (eski: %s) — tools/bake_rival_pool.gd" % [stale])
	var spot: int = 0
	for id: StringName in [&"tofas_sahin", &"bmw_e46", &"porsche_gt3"]:
		for index: int in [0, 17, 47]:
			var baked: float = RivalPool.baked_times(id)[index] if RivalPool.baked_times(id).size() > index else -1.0
			if absf(RivalPool.recording(id, index).time - baked) < 0.0002:
				spot += 1
	check(spot == 9, "havuz süresi = o tohumun koşusu (%d / 9; değilse yapay zekâ değişti, havuzu yeniden pişir)" % spot)

	print("== 4) Seçici hedefi tutturur ==")
	var player_runs: Dictionary = {"vw_golf_7": []}
	var player_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	player_rng.seed = 5
	for i: int in 12:
		(player_runs["vw_golf_7"] as Array).append(_run_of(&"vw_golf_7", player_rng, 2000 + i).to_dict())
	var me: PackedFloat64Array = RivalSelector.samples_for(&"vw_golf_7", {}, player_runs)
	# Her araç her kolu tutmaz (pencerenin hızlı ucundaki yapay zekâ çoğunlukla yener): seçici tutan aracı arar.
	var per_arm: Array[int] = []
	var pool_size: int = RaceManager.rival_pool(&"vw_golf_7").size()
	for arm: int in [RivalSelector.Arm.EASY, RivalSelector.Arm.EVEN, RivalSelector.Arm.HARD]:
		var hits: int = 0
		for id: StringName in RaceManager.rival_pool(&"vw_golf_7"):
			var times: PackedFloat64Array = RivalPool.times(id)
			var index: int = RivalSelector.closest(times, me, RivalSelector.target_of(arm))
			if RivalSelector.fits(RivalSelector.win_chance(me, times[index]), RivalSelector.target_of(arm)):
				hits += 1
		per_arm.append(hits)
	check(per_arm.min() >= 2, "pencerede her kolu tutan araç var (kolay %d · dengeli %d · zor %d / %d araç)"
		% [per_arm[0], per_arm[1], per_arm[2], pool_size])

	print("== 5) RaceManager: koşu deposu + pistteki koşu ==")
	var holder: Node = Node.new()
	root.add_child(holder)
	var race: RaceManager = RaceManager.new()
	holder.add_child(race)
	await frames(2)
	race._rng.seed = 3
	for i: int in 20:
		race.add_run(_run_of(&"vw_golf_7", rng, 0))
	check(race.runs_of(&"vw_golf_7").size() == RaceManager.RUNS_PER_CAR, "araç başına son %d koşu tutulur" % RaceManager.RUNS_PER_CAR)
	check(int(race.runs_of(&"vw_golf_7")[0]["at"]) > 0, "koşunun zamanı yazıldı")
	var never: DragRaceSim.Recording = DragRaceSim.Recording.begin(&"vw_golf_7", {}, rng)
	race.add_run(never)
	check(race.runs_of(&"vw_golf_7").size() == RaceManager.RUNS_PER_CAR, "kalkmamış koşu saklanmaz")
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}   # ilk yarış değil
	race.friend_chance = 0.0
	var near: int = 0
	for i: int in 30:
		var pick: Dictionary = race.pick_rival(&"vw_golf_7")
		race._reward_paid = false   # oyunda yola çıkan rakip sıfırlar (_send_challenger)
		race._rival_id = pick["id"]
		race._rival_owner = pick["owner"]
		var recording: DragRaceSim.Recording = race.rival_recording(&"vw_golf_7")
		if recording and recording.vehicle_id == race._rival_id \
				and RivalSelector.fits(race.chance(), RivalSelector.target_of(race.arm())):
			near += 1
		race.finish_race(rng.randf() < 0.5)
		race.release_challenger()
	check(near >= 26, "isimsiz rakip havuzdan, hedef şansa yakın (%d / 30)" % near)
	check(race.history().size() == RaceManager.HISTORY_MAX, "son yarış özeti %d ile sınırlı" % RaceManager.HISTORY_MAX)
	var state: Dictionary = race.state()
	var copy: RaceManager = RaceManager.new()
	copy.load_state(JSON.parse_string(JSON.stringify(state)))
	check(copy.runs_of(&"vw_golf_7").size() == RaceManager.RUNS_PER_CAR and copy.history().size() == RaceManager.HISTORY_MAX,
		"koşular ve yarış özeti kayıttan geri gelir")
	var bad: Dictionary = state.duplicate(true)
	(bad["runs"] as Dictionary)["vw_golf_7"].append({"v": 1, "car": "bmw_e46", "l": 3, "lr": 4000, "s": [], "t": 12.0})
	(bad["runs"] as Dictionary)["yok_boyle"] = [{"x": 1}]
	(bad["runs"] as Dictionary)["tofas_sahin"] = "bozuk"
	bad["recent"] = [{"w": "evet", "a": 99, "p": 7}, "x"]
	copy.load_state(bad)
	check(copy.runs_of(&"vw_golf_7").size() == RaceManager.RUNS_PER_CAR - 1 and copy.runs_of(&"bmw_e46").is_empty()
		and copy.runs_of(&"tofas_sahin").is_empty(), "bozuk / başka araca ait koşular atılır (son %d içinden)" % RaceManager.RUNS_PER_CAR)
	check(copy.history().size() == 1 and int(copy.history()[0]["a"]) <= RivalSelector.Arm.HARD
		and float(copy.history()[0]["p"]) <= 1.0, "bozuk yarış özeti sınırlanır")
	copy.free()
	race._records.clear()
	race._rival_id = &"tofas_sahin"
	race._rival_owner = {}
	var first: DragRaceSim.Recording = race.rival_recording(&"vw_golf_7")
	check(first != null and race.chance() < 0.0, "ilk yarışta seçici çalışmaz (eski kural: gün formu yok)")

	print("== 6) Açık garajda koşular ==")
	var snapshot: Dictionary = {"version": SaveManager.SAVE_VERSION, "vehicles": {"owned": ["vw_golf_7", "bmw_e46"]},
		"race": state}
	(snapshot["race"]["runs"] as Dictionary)["tofas_sahin"] = [_run_of(&"tofas_sahin", rng, 9).to_dict()]   # satılmış araç
	var garage: Dictionary = PublicGarage.from_snapshot(snapshot)
	var public_runs: Dictionary = (garage.get("race", {}) as Dictionary).get("runs", {})
	check(public_runs.keys() == ["vw_golf_7"] and (public_runs["vw_golf_7"] as Array).size() == PublicGarage.RUNS_PER_CAR,
		"yalnız sahip olunan araçlar, araç başına son %d koşu" % PublicGarage.RUNS_PER_CAR)
	check(not (garage["race"] as Dictionary).has("best") and not (garage["race"] as Dictionary).has("recent"),
		"rekor izi ve yarış özeti açık garaja gitmez")
	check(not ((public_runs["vw_golf_7"] as Array)[0] as Dictionary).has("at"), "koşunun zamanı açık garaja gitmez (gizlilik)")
	var back: Dictionary = PublicGarage.parse(PublicGarage.to_json(garage))
	var data: Dictionary = PublicGarage.race_data(back)
	check((data["runs"] as Dictionary).has("vw_golf_7") and ((data["runs"] as Dictionary)["vw_golf_7"] as Array).size() == PublicGarage.RUNS_PER_CAR,
		"arkadaş tarafında koşular okunur")
	# Açık garaj oyuncunun kendi yazdığı belgedir: elle yazılmış koşu (gün formu gücü, uydurma devir / sapma) atılır
	var forged: Array = []
	for change: Dictionary in [{"p": 500000}, {"lr": 9000}, {"j": 90000}]:
		var run: Dictionary = (public_runs["vw_golf_7"] as Array)[0].duplicate(true)
		run.merge(change, true)
		forged.append(run)
	var forged_runs: Dictionary = PublicGarage.public_runs({"vw_golf_7": forged}, ["vw_golf_7"], PublicGarage.RUNS_PER_CAR)
	check(forged_runs.is_empty(), "elle yazılmış koşu (güç +%%50, kalkış devri, sapma) arkadaşa gitmez (%d kaldı)" % forged_runs.size())
	check(RaceManager._runs_with_build(forged, &"vw_golf_7", {}).is_empty()
		and RaceManager._runs_with_build(public_runs["vw_golf_7"], &"vw_golf_7", {}).size() == PublicGarage.RUNS_PER_CAR,
		"arkadaşın elle yazılmış koşusu rakip olmaz, gerçek koşuları olur")
	var tight: Dictionary = PublicGarage.with_runs(garage, PublicGarage.RUNS_TIGHT)
	check(((tight["race"] as Dictionary)["runs"]["vw_golf_7"] as Array).size() == PublicGarage.RUNS_TIGHT
		and ((garage["race"] as Dictionary)["runs"]["vw_golf_7"] as Array).size() == PublicGarage.RUNS_PER_CAR, "sınırda koşular azaltılır (asıl garaj değişmez)")
	var heavy: Dictionary = {"version": SaveManager.SAVE_VERSION, "vehicles": {"owned": []}, "race": {"runs": {}}}
	for entry: Dictionary in CarCatalog.all().slice(0, 25):
		(heavy["vehicles"]["owned"] as Array).append(String(entry["id"]))
		var list: Array = []
		for i: int in RaceManager.RUNS_PER_CAR:
			list.append(_run_of(entry["id"], rng, 3000 + i).to_dict())
		heavy["race"]["runs"][String(entry["id"])] = list
	var packed: int = CloudPack.pack(PublicGarage.to_json(PublicGarage.from_snapshot(heavy))).length()
	check(packed < PublicGarage.MAX_JSON / 2, "25 araç × %d koşu açık garajda %d karakter (sınır %d)" % [PublicGarage.RUNS_PER_CAR, packed, PublicGarage.MAX_JSON])
	holder.queue_free()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
