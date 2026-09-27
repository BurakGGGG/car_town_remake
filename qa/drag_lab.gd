extends SceneTree
## DRAG LABORATUVARI — shift pattern karşılaştırması (Faz 19) ve optimum arama (Faz 20).
##   --script qa/drag_lab.gd -- patterns [araç]     tek araçta erken/kusursuz/geç/rastgele/optimum
##   --script qa/drag_lab.gd -- launch   [araç]     kalkış devri taraması
##   --script qa/drag_lab.gd -- optimize [araç]     kaba→ince optimum vites deseni araması
##   --script qa/drag_lab.gd -- balance             16 aracın dengeleme tablosu

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "balance"
	var id: StringName = StringName(args[1]) if args.size() > 1 else &"bmw_e46"
	match mode:
		"patterns": _patterns(id)
		"launch": _launch(id)
		"optimize": _optimize_report(id)
		_: _balance()
	quit(0)


## Verilen vites devirleriyle koşu (kalkış kusursuz, tepki yok) → süre.
func _run(id: StringName, targets: PackedFloat32Array) -> DragRaceSim.Run:
	return DragRaceSim.drive(id, 0.0, 1.0, 1.0, null, targets)


func _targets(spec: DragRaceSim.EngineSpec, factor: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	for g: int in spec.gear_count() - 1:
		out.append(clampf(spec.shift_rpm[g] * factor, spec.idle_rpm, spec.redline_rpm))
	return out


func _fmt(t: PackedFloat32Array) -> String:
	var s: String = ""
	for v: float in t:
		s += "%.0f " % v
	return s


func _patterns(id: StringName) -> void:
	var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	print("=== SHIFT PATTERN — %s (%d vites, sınır %.0f, optimum %s) ===" % [
		id, spec.gear_count(), spec.redline_rpm, _fmt(spec.shift_rpm).strip_edges()])
	var rows: Array = [
		["çok erken (%75)", _targets(spec, 0.75)],
		["erken (%90)", _targets(spec, 0.90)],
		["KUSURSUZ (optimum)", _targets(spec, 1.0)],
		["geç (%105)", _targets(spec, 1.05)],
		["devir sınırı", _targets(spec, 2.0)],
	]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var random: PackedFloat32Array = PackedFloat32Array()
	for g: int in spec.gear_count() - 1:
		random.append(clampf(spec.shift_rpm[g] * rng.randf_range(0.78, 1.10),
			spec.idle_rpm, spec.redline_rpm))
	rows.append(["rastgele", random])
	rows.append(["ARANAN OPTİMUM", _optimize(id)])
	print("%-22s %8s %8s %8s %8s  %s" % ["desen", "süre", "km/s", "sınır", "patinaj", "vites devirleri"])
	var best: float = 999.0
	for row: Array in rows:
		var run: DragRaceSim.Run = _run(id, row[1])
		best = minf(best, run.time)
		print("%-22s %8.3f %8.1f %8.2f %8.2f  %s" % [row[0], run.time, run.top_speed,
			run.limiter_time, run.spin_time, _fmt(row[1])])
	print("en iyi: %.3f sn" % best)


func _launch(id: StringName) -> void:
	var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	print("=== KALKIŞ TARAMASI — %s (optimum %.0f, sınır %.0f) ===" % [
		id, spec.launch_rpm, spec.redline_rpm])
	print("%8s %8s %8s %8s %8s  %s" % ["devir", "süre", "60m", "patinaj", "kalite", "not"])
	var targets: PackedFloat32Array = _targets(spec, 1.0)
	for f: float in [0.35, 0.50, 0.70, 0.85, 0.95, 1.00, 1.05, 1.15, 1.30, 1.50]:
		var rpm: float = clampf(spec.launch_rpm * f, spec.idle_rpm, spec.redline_rpm)
		var runner: DragRaceSim.Runner = DragRaceSim.Runner.new()
		runner.setup(id, null)
		runner.rpm = rpm
		runner.launch()
		var t: float = 0.0
		var sixty: float = -1.0
		var gear_target: float = targets[0] if targets.size() > 0 else INF
		while runner.finish_time < 0.0 and t < 40.0:
			t += DragRaceSim.STEP
			runner.step(DragRaceSim.STEP, t)
			if sixty < 0.0 and runner.distance >= 60.0:
				sixty = t
			if runner.gear < runner.top_gear() and not runner.shifting \
					and runner.rpm >= gear_target:
				if runner.shift() >= 0 and runner.gear < targets.size():
					gear_target = targets[runner.gear]
		print("%8.0f %8.3f %8.3f %8.2f %8s  %s" % [rpm, runner.finish_time, sixty,
			runner.spin_time, DragRaceSim.shift_name(runner.launch_quality),
			"patinaj" if runner.spin_time > 0.01 else ("bog" if rpm < spec.launch_rpm * 0.8 else "")])


## Kaba→ince arama: her vitesin devrini sırayla iyileştirir (koordinat inişi, 3 tur).
func _optimize(id: StringName) -> PackedFloat32Array:
	var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	var best: PackedFloat32Array = _targets(spec, 1.0)
	var best_time: float = _run(id, best).time
	for pass_index: int in 3:
		var span: float = [0.18, 0.07, 0.025][pass_index]
		var steps: int = 8
		for g: int in best.size():
			var local_best: float = best[g]
			for i: int in steps + 1:
				var factor: float = lerpf(1.0 - span, 1.0 + span, float(i) / float(steps))
				var trial: PackedFloat32Array = best.duplicate()
				trial[g] = clampf(best[g] * factor, spec.idle_rpm * 1.5, spec.redline_rpm)
				var t: float = _run(id, trial).time
				if t < best_time - 0.0005:
					best_time = t
					local_best = trial[g]
			best[g] = local_best
	return best


func _optimize_report(id: StringName) -> void:
	var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	var perfect: PackedFloat32Array = _targets(spec, 1.0)
	var found: PackedFloat32Array = _optimize(id)
	var t_perfect: float = _run(id, perfect).time
	var t_found: float = _run(id, found).time
	print("=== OPTİMUM ARAMA — %s ===" % id)
	print("modelin 'kusursuz'u : %s → %.3f sn" % [_fmt(perfect), t_perfect])
	print("aranan en iyi       : %s → %.3f sn" % [_fmt(found), t_found])
	print("fark                : %.3f sn (%.2f%%)" % [t_perfect - t_found,
		(t_perfect - t_found) / t_perfect * 100.0])


func _balance() -> void:
	print("%-22s %-3s %5s %5s %6s %5s %6s %6s %6s %6s" % ["araç", "sf", "vits", "sınır",
		"optim", "kalkş", "kusrsz", "iyi", "zayıf", "fark"])
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
		var perfect: DragRaceSim.Run = _run(id, _targets(spec, 1.0))
		var good: DragRaceSim.Run = _run(id, _targets(spec, 0.93))
		var weak: DragRaceSim.Run = _run(id, _targets(spec, 0.78))
		print("%-22s %-3s %5d %5.0f %6.0f %5.0f %6.2f %6.2f %6.2f %6.2f" % [id,
			entry.get("class", ""), spec.gear_count(), spec.redline_rpm, spec.shift_rpm[0],
			spec.launch_rpm, perfect.time, good.time, weak.time, weak.time - perfect.time])
