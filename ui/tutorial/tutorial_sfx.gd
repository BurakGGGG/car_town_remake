class_name TutorialSfx
extends Node
## EĞİTİM SESLERİ — RewardSfx gibi KODLA üretilir, bir kez önbelleğe alınır, Efekt (SFX) bus'ında çalar.
## whoosh: ders kartı süzülerek gelir · pop: Rıza Usta'nın konuşma kartı · type: yazı akarken tık ·
## chime: adım tamam · stamp: DERS TAMAM damgası (tok vuruş + kâğıt hışırtısı).

const MIX_RATE: int = 22050
## Yazı tıkları en fazla bu sıklıkta çalar.
const TYPE_GAP_MSEC: int = 45

static var _streams: Dictionary = {}

var _players: Dictionary = {}
var _last_type: int = 0


func _ready() -> void:
	name = "TutorialSfx"
	_ensure_streams()
	for entry: Array in [[&"whoosh", -8.0, 1], [&"pop", -9.0, 2], [&"type", -20.0, 2], [&"chime", -8.0, 2],
			[&"stamp", -3.0, 1]]:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.stream = _streams[entry[0]]
		player.volume_db = float(entry[1])
		player.max_polyphony = int(entry[2])
		player.bus = GameSettings.SFX_BUS
		add_child(player)
		_players[entry[0]] = player


func play(id: StringName, pitch: float = 1.0) -> void:
	var player: AudioStreamPlayer = _players.get(id) as AudioStreamPlayer
	if player == null:
		return
	player.pitch_scale = pitch
	player.play()


func type_tick() -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_type < TYPE_GAP_MSEC:
		return
	_last_type = now
	play(&"type", randf_range(0.9, 1.15))


# --- Üretim ---------------------------------------------------------------------

static func _ensure_streams() -> void:
	if not _streams.is_empty():
		return
	_streams[&"whoosh"] = _whoosh(0.5)
	_streams[&"pop"] = _pop()
	_streams[&"type"] = _click()
	# G5 → C6: "tamam" iki notası
	_streams[&"chime"] = _notes([[783.99, 0.07], [1046.5, 0.32]], 7.0)
	_streams[&"stamp"] = _stamp()


## Süzülme: süzgeci açılıp kapanan gürültü (alçak geçiren, kesim frekansı zarfla birlikte yükselir).
static func _whoosh(seconds: float) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * float(MIX_RATE)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var low: float = 0.0
	for i: int in samples.size():
		var k: float = float(i) / float(samples.size())
		var envelope: float = sin(PI * pow(k, 0.7))
		var cutoff: float = lerpf(0.02, 0.22, envelope)
		low += (rng.randf_range(-1.0, 1.0) - low) * cutoff
		samples[i] = low * envelope * 2.2
	return _wav(samples, 0.8)


## Pıt: hızla inen kısa bir sinüs (baloncuk).
static func _pop() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.12 * float(MIX_RATE)))
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / float(MIX_RATE)
		phase += TAU * lerpf(900.0, 360.0, minf(t / 0.08, 1.0)) / float(MIX_RATE)
		samples[i] = sin(phase) * minf(t / 0.003, 1.0) * exp(-t * 30.0)
	return _wav(samples, 0.8)


static func _click() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.025 * float(MIX_RATE)))
	for i: int in samples.size():
		var t: float = float(i) / float(MIX_RATE)
		samples[i] = sin(TAU * 2400.0 * t) * exp(-t * 260.0)
	return _wav(samples, 0.7)


## Damga: alçak tok vuruş (inen perde) + kısa gürültü patlaması.
static func _stamp() -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.45 * float(MIX_RATE)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var phase: float = 0.0
	for i: int in samples.size():
		var t: float = float(i) / float(MIX_RATE)
		phase += TAU * lerpf(150.0, 55.0, minf(t / 0.12, 1.0)) / float(MIX_RATE)
		var body: float = sin(phase) * exp(-t * 11.0)
		var slap: float = rng.randf_range(-1.0, 1.0) * exp(-t * 70.0) * 0.6
		samples[i] = (body + slap) * minf(t / 0.002, 1.0)
	return _wav(samples, 0.95)


static func _notes(notes: Array, decay: float) -> AudioStreamWAV:
	var total: float = 0.0
	for note: Array in notes:
		total += float(note[1])
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(total * float(MIX_RATE)))
	var start: int = 0
	for note: Array in notes:
		var hz: float = float(note[0])
		var seconds: float = float(note[1])
		var count: int = mini(int(seconds * float(MIX_RATE)), samples.size() - start)
		for i: int in count:
			var t: float = float(i) / float(MIX_RATE)
			var envelope: float = minf(t / 0.004, 1.0) * exp(-t * decay) * clampf((seconds - t) / 0.01, 0.0, 1.0)
			samples[start + i] = envelope * (sin(TAU * hz * t) * 0.7 + sin(TAU * hz * 2.0 * t) * 0.2
				+ sin(TAU * hz * 3.0 * t) * 0.1)
		start += count
	return _wav(samples, 0.7)


static func _wav(samples: PackedFloat32Array, gain: float) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
