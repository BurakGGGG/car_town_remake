extends SceneTree
## Tek koşunun devir izi: vites sonrası düşüş, tekrar tırmanış, patinaj, limitçi görünsün.
func _initialize() -> void:
	var id: StringName = &"bmw_e46"
	if OS.get_cmdline_user_args().size() > 0:
		id = StringName(OS.get_cmdline_user_args()[0])
	var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
	print("%s — rölanti %.0f, tepe tork %.0f, tepe güç %.0f, sınır %.0f, kalkış %.0f, %d vites" % [
		id, spec.idle_rpm, spec.peak_torque_rpm, spec.peak_power_rpm, spec.redline_rpm,
		spec.launch_rpm, spec.gear_count()])
	var r: DragRaceSim.Runner = DragRaceSim.Runner.new()
	r.setup(id, null)
	r.rpm = spec.launch_rpm
	r.launch()
	var t: float = 0.0
	var next_print: float = 0.0
	print("%6s %4s %7s %7s %7s  %s" % ["sn", "vit", "devir", "km/s", "mesafe", "durum"])
	while r.finish_time < 0.0 and t < 30.0:
		t += DragRaceSim.STEP
		r.step(DragRaceSim.STEP, t)
		if r.gear < r.top_gear() and not r.shifting and r.rpm >= spec.shift_rpm[r.gear]:
			var q: int = r.shift()
			print("%6.2f %4d %7.0f %7.1f %7.1f  → VİTES %d (%s)" % [t, r.gear, r.rpm,
				r.speed_kmh(), r.distance, r.gear + 1, DragRaceSim.shift_name(q)])
			next_print = t + 0.15
			continue
		if t >= next_print:
			next_print = t + 0.30
			var flags: String = ""
			if r.shifting: flags += "geçiş "
			if r.wheelspin: flags += "PATİNAJ "
			if r.limiter: flags += "SINIR "
			if r.clutch > 0.0: flags += "debriyaj "
			print("%6.2f %4d %7.0f %7.1f %7.1f  %s" % [t, r.gear + 1, r.rpm, r.speed_kmh(), r.distance, flags])
	print("BİTİŞ %.2f sn, %.1f km/s, patinaj %.2f sn, sınırda %.2f sn, en yüksek devir %.0f" % [
		r.finish_time, r.speed_kmh(), r.spin_time, r.limiter_time, r.max_rpm])
	quit(0)
