class_name TrafficSfx
extends Node
## TRAFİK SESLERİ — ses dosyası yok, KODLA üretilir (RewardSfx / PoliceSiren gibi), Efekt (SFX) bus'ında çalar:
##   honk    — iki tonlu araba kornası (kaçak yüzünden fren yapan araç)
##   screech — lastik cıyaklaması (yarışı kaybeden araç kaçmaya başlarken)
## Sentez açılışta bir kez arka plan iş parçacığında yapılır (telefonda ana iş parçacığında ~50 ms takılma olurdu);
## hazır değilken istenen ses atlanır. TrafficManager kurar; araç ekranda görünmüyorsa çağrılmaz.

const MIX_RATE: int = 22050
## Aynı sesin art arda tekrarı arasında en az süre (ms): üç araç birden fren yapınca korna kakofonisi olmasın.
const HONK_GAP_MSEC: int = 450

static var _honk_streams: Array[AudioStreamWAV] = []
static var _screech_stream: AudioStreamWAV

var _honk_player: AudioStreamPlayer
var _screech_player: AudioStreamPlayer
var _task: int = -1
var _last_honk: int = -10000
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	name = "TrafficSfx"
	_rng.randomize()
	_honk_player = _player(-9.0, 3)
	_screech_player = _player(-11.0, 1)
	if _screech_stream == null:
		_task = WorkerThreadPool.add_task(_synthesize)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func honk() -> void:
	if not _ready_streams():
		return
	var now: int = Time.get_ticks_msec()
	if now - _last_honk < HONK_GAP_MSEC:
		return
	_last_honk = now
	_honk_player.stream = _honk_streams[_rng.randi() % _honk_streams.size()]
	_honk_player.pitch_scale = _rng.randf_range(0.94, 1.08)   # her araç biraz farklı korna
	_honk_player.play()


func screech() -> void:
	if not _ready_streams():
		return
	_screech_player.stream = _screech_stream
	_screech_player.pitch_scale = _rng.randf_range(0.95, 1.05)
	_screech_player.play()


func _ready_streams() -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _screech_stream != null and not _honk_streams.is_empty()


func _player(volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = GameSettings.SFX_BUS
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


# --- Sentez (arka plan) --------------------------------------------------------------------------

static func _synthesize() -> void:
	var honks: Array[AudioStreamWAV] = [
		_horn([[0.0, 0.34]], 392.0, 494.0),                 # tek, uzun "döööt"
		_horn([[0.0, 0.13], [0.19, 0.30]], 415.0, 523.0),   # çift "dıt-dııt"
	]
	_honk_streams = honks
	_screech_stream = _squeal(0.85)


## Korna: iki tonlu (iki sinyal birlikte), zengin harmonik (kare dalgaya yakın), yumuşak atak / bırakış.
static func _horn(beeps: Array, low: float, high: float) -> AudioStreamWAV:
	var total: float = 0.0
	for beep: Array in beeps:
		total = maxf(total, float(beep[0]) + float(beep[1]))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int((total + 0.05) * MIX_RATE))
	for beep: Array in beeps:
		var start: int = int(float(beep[0]) * MIX_RATE)
		var length: int = int(float(beep[1]) * MIX_RATE)
		for i: int in length:
			var t: float = float(i) / float(MIX_RATE)
			var env: float = minf(t / 0.012, 1.0) * clampf((float(beep[1]) - t) / 0.035, 0.0, 1.0)
			var v: float = 0.0
			for k: int in [1, 3, 5, 7]:   # tek harmonikler: kornanın "boru" sesi
				v += sin(TAU * low * k * t) / k + sin(TAU * high * k * t) / k
			samples[start + i] += v * 0.32 * env
	return _wav(samples)


## Lastik cıyaklaması: 1,4–2,6 kHz arasında rastgele kayan dar bantlı tonlar + biraz gürültü, sönerek biter.
static func _squeal(seconds: float) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7341
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * MIX_RATE))
	var phases: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
	var freqs: PackedFloat32Array = PackedFloat32Array([1480.0, 1960.0, 2550.0])
	var drift: PackedFloat32Array = PackedFloat32Array([0.0, 0.0, 0.0])
	for i: int in samples.size():
		var t: float = float(i) / float(MIX_RATE)
		var env: float = minf(t / 0.03, 1.0) * pow(maxf(1.0 - t / seconds, 0.0), 1.6)
		var v: float = rng.randf_range(-0.18, 0.18)
		for k: int in 3:
			drift[k] = clampf(drift[k] + rng.randf_range(-6.0, 6.0), -90.0, 90.0)
			phases[k] += TAU * (freqs[k] + drift[k]) / float(MIX_RATE)
			v += sin(phases[k]) * (0.5 if k == 1 else 0.3)
		samples[i] = v * env * (0.75 + 0.25 * sin(TAU * 13.0 * t))
	return _wav(samples)


static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * 0.55, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream
