extends SceneTree
## DRIFT EFEKTLERİ MALİYETİ (başsız, kare başına µs): DriftSmoke yayma + benzetim, SkidMarks kurulum / solma, DriftLine
## çizelge kurulumu ve poz örnekleme. 2026-11-02 masaüstü: duman ~10 µs (hareket shader'da), iz ~45 µs, poz ~7 µs/araç.
##   timeout -k 5 60 godot-4 --headless --path . --script res://qa/drift_fx_bench.gd

func _initialize() -> void:
	var smoke: DriftSmoke = DriftSmoke.new()
	root.add_child(smoke)
	var marks: SkidMarks = SkidMarks.new()
	root.add_child(marks)
	var dt: float = 1.0 / 60.0
	var smoke_us: int = 0
	var emit_us: int = 0
	var marks_us: int = 0
	var frames_n: int = 600
	var peak: int = 0
	for f: int in frames_n:
		var t: float = f * dt
		var t0: int = Time.get_ticks_usec()
		for key: int in 4:
			var at: Vector3 = Vector3(t * 1.4 + key * 0.3, 0.0, sin(t * 2.0 + key) * 0.3)
			smoke.emit(key, at, Vector3(1.4, 0, 0), Vector3(-1, 0, 0.3).normalized(), 1.0, dt)
			marks.add(key, at, 0.0 if int(t * 1.6) % 4 == 0 else 0.8)
		var t1: int = Time.get_ticks_usec()
		smoke._process(dt)
		var t2: int = Time.get_ticks_usec()
		marks._process(dt)
		var t3: int = Time.get_ticks_usec()
		emit_us += t1 - t0
		smoke_us += t2 - t1
		marks_us += t3 - t2
		peak = maxi(peak, smoke.alive_count())
	print("duman: emit %.0f µs/kare, benzetim %.0f µs/kare (en çok %d topak); iz: %.0f µs/kare (%d nokta)" % [
		float(emit_us) / frames_n, float(smoke_us) / frames_n, peak, float(marks_us) / frames_n, marks.point_count()])
	marks.release()
	var fade_us: int = 0
	for f: int in 120:
		var t0: int = Time.get_ticks_usec()
		marks._process(dt)
		fade_us += Time.get_ticks_usec() - t0
	print("iz solarken: %.1f µs/kare" % (float(fade_us) / 120.0))
	var idle_us: int = 0
	smoke.clear()
	for f: int in 120:
		var t0: int = Time.get_ticks_usec()
		if smoke.is_processing():
			smoke._process(dt)
		idle_us += Time.get_ticks_usec() - t0
	print("duman boşta: %.1f µs/kare, işleniyor mu: %s" % [float(idle_us) / 120.0, smoke.is_processing()])
	var line: DriftLine = DriftLine.build(Vector3(0, 0, 1), -1)
	var t_build: int = Time.get_ticks_usec()
	var lead: DriftLine.Track = line.lead_track(&"", line.corner_from - 9.5)
	var follow: DriftLine.Track = line.follow_track(&"", lead)
	print("çizelge kurulumu (iki araç): %.1f ms" % ((Time.get_ticks_usec() - t_build) / 1000.0))
	var t_s: int = Time.get_ticks_usec()
	var acc: float = 0.0
	for i: int in 1000:
		var t: float = i * 0.01
		acc += lead.sample_position(t).x + lead.sample_angle(lead.yaw, t) + lead.sample_f(lead.roll, t) + lead.sample_f(lead.pitch, t)
	print("poz örnekleme: %.2f µs / araç-kare" % ((Time.get_ticks_usec() - t_s) / 1000.0 * 3.0))
	quit()
