extends SceneTree
## TRAFİK SESLERİ DİNLEME DOSYALARI (traffic/traffic_engine.gd): her motor tipi için rölanti → kalkış → seyir → fren →
## rölanti senaryosu oyundaki sürüş mantığıyla (TrafficEngine.drive) çevrimdışı karıştırılır; lastik sesi de hızla
## eklenir (CityAmbience ile aynı oranlar). Kornalar (tip × basış deseni) ayrı dosyalar.
##   godot-4 --headless --path . --script res://qa/trafik_sesleri_dinle.gd
## Çıktı: /home/burak/Projects/ct_shots/trafik_sesleri/motor_<tip>.wav, korna_<tip>_<desen>.wav

const OUT: String = "/home/burak/Projects/ct_shots/trafik_sesleri/"
const RATE: int = 22050
const CONTROL_HZ: int = 60
## Senaryo: [süre sn, hedef hız birim/sn] — hız ivmeyle yaklaşır (trafik aracının 0,6 / 1,4 değerleri).
const SCRIPT_STEPS: Array = [[1.5, 0.0], [3.0, 0.8], [3.0, 0.8], [1.6, 0.0], [1.6, 0.0]]
const ACCEL: float = 0.6
const BRAKE: float = 1.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var tire: PackedFloat32Array = _samples(_tire_stream())
	for kind: int in TrafficEngine.Kind.values():
		var stream: AudioStreamWAV = TrafficEngine.make_stream(kind as TrafficEngine.Kind)
		var name: String = String(TrafficEngine.Kind.keys()[kind]).to_lower()
		_render(kind as TrafficEngine.Kind, _samples(stream), tire).save_to_wav(OUT + "motor_%s.wav" % name)
		print("motor_%s.wav" % name)
	var patterns: Array[String] = ["dit", "dit_dit", "uzun", "sabirsiz"]
	for horn: int in TrafficEngine.Horn.values():
		var streams: Array[AudioStreamWAV] = TrafficEngine.horn_streams(horn as TrafficEngine.Horn)
		for i: int in streams.size():
			var file: String = "korna_%s_%s.wav" % [String(TrafficEngine.Horn.keys()[horn]).to_lower(), patterns[i]]
			streams[i].save_to_wav(OUT + file)
	print("kornalar: %s" % OUT)
	quit()


## Senaryo boyunca motor (oyundaki drive()) + lastik: perde ve düzey kontrol hızında güncellenir, döngüler okunur.
func _render(kind: TrafficEngine.Kind, loop: PackedFloat32Array, tire: PackedFloat32Array) -> AudioStreamWAV:
	var engine: TrafficEngine = TrafficEngine.new()
	engine.setup(null, kind, 1.0, &"Master")
	var out: PackedFloat32Array = PackedFloat32Array()
	var speed: float = 0.0
	var smooth: float = 0.0
	var head: float = 0.0
	var tire_head: float = 0.0
	var dt: float = 1.0 / float(CONTROL_HZ)
	var per_step: int = RATE / CONTROL_HZ
	var engine_db: float = float((TrafficEngine.DRIVES[kind] as Array)[0])
	for step: Array in SCRIPT_STEPS:
		for n: int in int(float(step[0]) * CONTROL_HZ):
			var goal: float = float(step[1])
			speed = minf(speed + ACCEL * dt, goal) if goal > speed else maxf(speed - BRAKE * dt, goal)
			smooth = lerpf(smooth, speed, 1.0 - exp(-6.0 * dt))
			engine.drive(smooth, dt)
			var gain: float = 0.0 if engine.stream_paused else db_to_linear(engine.volume_db - engine_db) * 0.5
			var level: float = smooth / CityAmbience.TIRE_REF_SPEED
			var tire_gain: float = db_to_linear(CityAmbience.TIRE_DB - engine_db + linear_to_db(maxf(minf(level, 1.8), 0.0001))) * 0.5 \
				if level > 0.06 else 0.0
			var tire_pitch: float = 0.82 + 0.2 * minf(level, 3.0)
			for i: int in per_step:
				head = fmod(head + engine.pitch_scale, float(loop.size()))
				tire_head = fmod(tire_head + tire_pitch, float(tire.size()))
				out.append(loop[int(head)] * gain + tire[int(tire_head)] * tire_gain)
	engine.free()
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(out.size() * 2)
	var top: float = 0.0001
	for s: float in out:
		top = maxf(top, absf(s))
	for i: int in out.size():
		bytes.encode_s16(i * 2, int(clampf(out[i] * 0.7 / top, -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	return wav


func _tire_stream() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261017
	return CityAmbience._to_wav(CityAmbience._make_tire(3.0, rng), 0.7, true)


static func _samples(stream: AudioStreamWAV) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	var data: PackedByteArray = stream.data
	out.resize(data.size() / 2)
	for i: int in out.size():
		out[i] = data.decode_s16(i * 2) / 32768.0
	return out
