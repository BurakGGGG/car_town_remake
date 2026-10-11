extends SceneTree
## EŞLEŞME RAPORU — her araç için, RaceManager'ın verebileceği rakip havuzuna (RaceManager.rival_pool)
## karşı İYİ bir oyuncunun (tepki 0,25 sn, kusursuz kalkış, vites becerisi 0,85) kazanma oranı. Rakip gün
## formuyla koşar (DragRaceSim.run_rival — oyundaki rakiple aynı kural).
## Kullanım: godot-4 --headless --path . -s res://qa/matchup_report.gd [-- <koşu_sayısı>]
## Sütunlar: havuz ortalaması · en kötü eşleşme · en iyi eşleşme · havuzdaki kazanılamaz (%0) rakip sayısı.

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 20
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var entries: Array[Dictionary] = CarCatalog.all()
	print("%-20s %-2s %6s %22s %22s %5s" % ["araç", "sn", "ort.%", "en kötü", "en iyi", "%0"])
	for player: Dictionary in entries:
		var klass: String = String(player.get("class", "D"))
		var pool: Array[StringName] = RaceManager.rival_pool(player["id"])
		var total: float = 0.0
		var count: int = 0
		var worst: Array = ["", 2.0]
		var best: Array = ["", -1.0]
		var hopeless: int = 0
		for rival: Dictionary in entries:
			if not pool.has(rival["id"]):
				continue
			var wins: int = 0
			for i: int in runs:
				var mine: float = DragRaceSim.drive(player["id"], 0.25, 1.0, 0.85, rng).time
				var theirs: float = DragRaceSim.run_rival(rival["id"], rng).time
				if mine < theirs:
					wins += 1
			var rate: float = float(wins) / float(runs)
			total += rate
			count += 1
			if rate < float(worst[1]):
				worst = [rival["id"], rate]
			if rate > float(best[1]):
				best = [rival["id"], rate]
			if wins == 0:
				hopeless += 1
		print("%-20s %-2s %5.0f%% %16s %4.0f%% %16s %4.0f%% %3d/%d" % [player["id"], klass, 100.0 * total / maxf(count, 1),
			String(worst[0]).left(16), 100.0 * float(worst[1]), String(best[0]).left(16), 100.0 * float(best[1]), hopeless, count])
	quit()
