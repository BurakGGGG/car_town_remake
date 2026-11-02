extends SceneTree
## MOTOR SESİ DİNLEME DOSYALARI: verilen araçlar için (ön ayar: kayıtlı ya da otomatik) EngineSynth'in sürekli devir
## eğrisiyle "rölanti → gaz → vites → kesik → rölanti" sürüşünü ve marş + kontak kapatmayı WAV'a yazar; pişirme
## süresini ölçer. Kullanım:
##   godot-4 --headless --path . -s res://qa/motor_sesi_dinle.gd -- <çıktı_klasörü> <araç_id> [<araç_id> …]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/motor_sesleri/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0].path_join("") if args.size() > 0 else DEFAULT_OUT
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array[StringName] = []
	for i: int in range(1, args.size()):
		ids.append(StringName(args[i]))
	if ids.is_empty():
		ids = [&"tofas_sahin", &"vw_golf_7", &"vw_passat_b55", &"chevrolet_camaro", &"lambo_huracan", &"tesla_model_y"]
	for id: StringName in ids:
		var p: Dictionary = EnginePreset.for_vehicle(id)
		var rate: int = int(p["rate"])
		var t0: int = Time.get_ticks_msec()
		var drive: PackedFloat32Array = _drive(p)
		var t1: int = Time.get_ticks_msec()
		var bank: EngineBank = EngineBank.build(id, p, false)
		var t2: int = Time.get_ticks_msec()
		var bank_q: EngineBank = EngineBank.build(id, p, true)
		var t3: int = Time.get_ticks_msec()
		var bytes: int = 0
		for s: AudioStreamWAV in bank_q.on_loops + bank_q.off_loops + bank_q.pops:
			bytes += s.data.size()
		for s: AudioStreamWAV in [bank_q.start, bank_q.stop, bank_q.blowoff, bank_q.whistle]:
			if s:
				bytes += s.data.size()
		var calib: float = EngineSynth.calibrate([drive])
		EngineSynth.finish(drive, p, calib)
		EngineBank.write_wav(out + String(id) + "_surus.wav", _norm(drive, 0.8), rate)
		# Katmanları sırayla (her biri 1,2 sn): gaz açık, sonra gaz kesik
		var layers: PackedFloat32Array = PackedFloat32Array()
		for s: AudioStreamWAV in bank.on_loops + bank.off_loops:
			layers.append_array(_repeat(s, 1.2, rate))
		EngineBank.write_wav(out + String(id) + "_katmanlar.wav", layers, rate)
		var start_stop: PackedFloat32Array = _pcm(bank.start)
		start_stop.append_array(_repeat(bank.off_loops[0], 2.0, rate))
		start_stop.append_array(_pcm(bank.stop))
		for pop: AudioStreamWAV in bank.pops:
			start_stop.append_array(_pcm(pop))
		if bank.blowoff:
			start_stop.append_array(_pcm(bank.blowoff))
		EngineBank.write_wav(out + String(id) + "_mars.wav", start_stop, rate)
		print("%s  şablon=%s  sürüş %d ms  banka(PCM) %d ms  banka(QOA) %d ms  QOA %.0f KB" % [id, p["layout"],
			t1 - t0, t2 - t1, t3 - t2, bytes / 1024.0])
	quit()


## Sürüş eğrisi: rölanti 1,5 sn → 1. vites gaz → vites (devir düşer) → 2. vites → gaz kes (patlama yok, sentez) →
## rölanti; ardından iki gaz pompası.
func _drive(p: Dictionary) -> PackedFloat32Array:
	var rate: float = float(p["rate"])
	var idle: float = maxf(float(p["idle_rpm"]), 600.0 if p["layout"] != "ev" else 0.0)
	var red: float = float(p["redline_rpm"])
	var keys: Array = [
		[0.0, idle, p["off_load"]], [1.5, idle, p["off_load"]], [1.6, idle * 1.3, 1.0], [3.4, red * 0.92, 1.0],
		[3.55, red * 0.62, 0.2], [3.7, red * 0.62, 1.0], [5.6, red * 0.95, 1.0], [5.7, red * 0.9, 0.0],
		[7.2, idle * 1.15, p["off_load"]], [8.0, idle, p["off_load"]], [8.4, idle, 1.0], [8.75, red * 0.6, 1.0],
		[8.8, red * 0.6, 0.0], [9.5, idle, p["off_load"]], [9.9, idle, 1.0], [10.3, red * 0.75, 1.0],
		[10.35, red * 0.75, 0.0], [11.2, idle, p["off_load"]], [12.5, idle, p["off_load"]],
	]
	var n: int = int(12.5 * rate)
	var rpm: PackedFloat32Array = PackedFloat32Array()
	rpm.resize(n)
	var load: PackedFloat32Array = PackedFloat32Array()
	load.resize(n)
	var k: int = 0
	for i: int in n:
		var t: float = float(i) / rate
		while k < keys.size() - 2 and t > float(keys[k + 1][0]):
			k += 1
		var a: Array = keys[k]
		var b: Array = keys[k + 1]
		var x: float = clampf((t - float(a[0])) / maxf(float(b[0]) - float(a[0]), 1e-4), 0.0, 1.0)
		rpm[i] = maxf(lerpf(float(a[1]), float(b[1]), x), 300.0)
		load[i] = lerpf(float(a[2]), float(b[2]), x)
	return EngineSynth.render_curve(p, rpm, load, 77)


func _pcm(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var data: PackedByteArray = stream.data
	var frames: int = data.size() / 2
	if stream.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		frames = stream.loop_end
	for i: int in frames:
		out.append(data.decode_s16(i * 2) / 32768.0)
	return out


func _repeat(stream: AudioStreamWAV, seconds: float, rate: int) -> PackedFloat32Array:
	var one: PackedFloat32Array = _pcm(stream)
	var out: PackedFloat32Array = PackedFloat32Array()
	while out.size() < int(seconds * rate):
		out.append_array(one)
	return out


func _norm(samples: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var top: float = 1e-6
	for s: float in samples:
		top = maxf(top, absf(s))
	for i: int in samples.size():
		samples[i] *= peak / top
	return samples
