extends SceneTree
## RAKİP SÜRE DAĞILIMI — aynı araçla rakip AI'nin N yarıştaki süreleri (bilinmezlik faktörünün ölçüsü).
## Kullanım: godot-4 --headless --path . -s res://qa/rival_spread.gd -- [<koşu> [<araç_id> ...]]
## Sütunlar: medyan · p5 / p95 · en iyi / en kötü · medyandan %4,5 hızlı ve %9 yavaş koşu oranı
## (kullanıcının örneği: "11 yapan rakip bazen 10,5, düşük ihtimalle 12 yapsın").


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var runs: int = int(args[0]) if args.size() > 0 else 400
	var ids: Array[StringName] = []
	for i: int in range(1, args.size()):
		ids.append(StringName(args[i]))
	if ids.is_empty():
		ids = [&"tofas_sahin", &"hyundai_getz", &"vw_golf_7", &"bmw_e46", &"ferrari_488_pista"]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	print("%-18s %-2s %6s %13s %13s %7s %7s" % ["araç", "sn", "medyan", "p5 / p95", "en iyi/kötü", "-%4,5", "+%9"])
	for id: StringName in ids:
		var times: Array[float] = []
		for i: int in runs:
			times.append(DragRaceSim.run_rival(id, rng).time)
		times.sort()
		var med: float = times[runs / 2]
		var fast: int = 0
		var slow: int = 0
		for t: float in times:
			if t <= med * 0.955:
				fast += 1
			if t >= med * 1.09:
				slow += 1
		print("%-18s %-2s %6.2f %6.2f/%6.2f %6.2f/%6.2f %6.1f%% %6.1f%%" % [id, CarCatalog.get_entry(id).get("class", "?"), med,
			times[runs * 5 / 100], times[runs * 95 / 100], times[0], times[runs - 1], 100.0 * fast / runs, 100.0 * slow / runs])
	quit()
