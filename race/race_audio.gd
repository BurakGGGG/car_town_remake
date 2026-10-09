class_name RaceAudio
extends Node
## DRAG YARIŞI SESLERİ — oyunda ses varlığı yok; hepsi KODLA, bir kez üretilir (statik önbellek).
##
## Motor: tek bir döngü örneği (ateşleme darbeleri + alt harmonik + yanma gürültüsü) üretilir ve
## `pitch_scale` motor devrine göre ayarlanır — örnek başına GDScript döngüsü YOK, mobilde
## maliyeti iki AudioStreamPlayer kadar. Oyuncunun motoru önde, rakibinki kısık.
## Tek seferlikler: geri sayım bipi, GO bipi, vites patlaması (backfire).
##
## ARAÇ KARAKTERİ: üç motor tınısı — ekonomi (kaba 4 silindir), spor (düzgün 6 silindir), süper
## (V8/V10 çığlığı: daha tiz ateşleme, daha çok harmonik). `set_character` performans payından
## seçer; döngüler ilk ihtiyaçta bir kez üretilir.
## Yalnızca SES üretir; yarış mantığını bilmez. DragRaceScreen her kare `drive()` ile besler.

const MIX_RATE: int = 22050
## Döngü örneğinin ateşleme frekansı (Hz) ve karşılık gelen devir (4 silindir: devir/60·2).
const BASE_FIRE_HZ: float = 100.0
const BASE_RPM: float = 3000.0
## 0,6 sn = 60 ateşleme döngüsü ve 30 alt harmonik döngüsü: döngü sınırında tık OLMAZ.
const LOOP_SECONDS: float = 0.6

const PLAYER_DB: float = -7.0
const RIVAL_DB: float = -17.0
## Vites geçişinde (gaz kesik) motor bu kadar kısılır.
const SHIFT_DUCK_DB: float = -9.0

## Karakter → [perde katsayısı, ses düzeyi farkı (dB), darbe sönümü, rezonans, harmonik, gürültü, gövde]
const CHARACTERS: Array = [
	[1.0, -2.0, 5.5, 3.0, 0.0, 0.30, 0.50],    # ekonomi: kaba, homurtulu
	[1.3, 0.0, 4.5, 2.5, 0.25, 0.16, 0.38],    # spor: düzgün, dolgun
	[1.8, 2.5, 3.6, 2.0, 0.55, 0.09, 0.26],    # süper: tiz, çığlık
]

static var _engine_streams: Dictionary = {}
static var _beep_stream: AudioStreamWAV
static var _go_stream: AudioStreamWAV
static var _pop_stream: AudioStreamWAV

var _player_engine: AudioStreamPlayer
var _rival_engine: AudioStreamPlayer
var _oneshot: AudioStreamPlayer
var _pop: AudioStreamPlayer
var _time: float = 0.0
var _player_pitch: float = 1.0
var _rival_pitch: float = 1.0
var _player_db: float = PLAYER_DB
var _rival_db: float = RIVAL_DB
var _fading: bool = false


func _ready() -> void:
	name = "RaceAudio"
	_ensure_streams()
	_player_engine = _player(null)
	_rival_engine = _player(null)
	_oneshot = _player(null)
	_pop = _player(_pop_stream)
	_pop.max_polyphony = 3


func _player(stream: AudioStream) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.bus = GameSettings.SFX_BUS
	add_child(player)
	return player


## Araçların performans payına (0-1) göre motor tınısı seçilir.
func set_character(player_perf: float, rival_perf: float) -> void:
	var p: int = _character_of(player_perf)
	var r: int = _character_of(rival_perf)
	_player_engine.stream = _engine(p)
	_rival_engine.stream = _engine(r)
	_player_pitch = CHARACTERS[p][0]
	_rival_pitch = CHARACTERS[r][0]
	_player_db = PLAYER_DB + float(CHARACTERS[p][1])
	_rival_db = RIVAL_DB + float(CHARACTERS[r][1])


static func _character_of(perf: float) -> int:
	if perf >= 0.75:
		return 2
	if perf >= 0.35:
		return 1
	return 0


static func _engine(character: int) -> AudioStreamWAV:
	if not _engine_streams.has(character):
		var c: Array = CHARACTERS[character]
		_engine_streams[character] = _make_engine(c[2], c[3], c[4], c[5], c[6])
	return _engine_streams[character]


## Motorlar rölantide çalışmaya başlar (geri sayımda devir yükselir).
func start() -> void:
	_time = 0.0
	_fading = false
	if _player_engine.stream == null:
		set_character(0.0, 0.0)
	_player_engine.volume_db = _player_db
	_rival_engine.volume_db = _rival_db
	_player_engine.play()
	# Rakip döngüsü farklı yerden başlasın: iki motor aynı fazda "tek motor" gibi duyulmasın
	_rival_engine.play(LOOP_SECONDS * 0.37)


## Yarış bitti: motorlar kısa sürede susar (sonuç panosu sessiz).
func fade_out() -> void:
	_fading = true


func stop() -> void:
	_fading = false
	for player: AudioStreamPlayer in [_player_engine, _rival_engine, _oneshot, _pop]:
		player.stop()


## Her kare: motor devri → perde, durum → ses düzeyi. `limiter` devir sınırında tekleme yapar.
func drive(delta: float, player: DragRaceSim.Runner, rival: DragRaceSim.Runner) -> void:
	_time += delta
	if _fading:
		for engine: AudioStreamPlayer in [_player_engine, _rival_engine]:
			engine.volume_db = move_toward(engine.volume_db, -60.0, delta * 50.0)
			if engine.volume_db <= -59.0 and engine.playing:
				engine.stop()
		return
	_drive_engine(_player_engine, player, _player_db, _player_pitch)
	_drive_engine(_rival_engine, rival, _rival_db, _rival_pitch)


func _drive_engine(engine: AudioStreamPlayer, runner: DragRaceSim.Runner, base_db: float,
		character_pitch: float) -> void:
	if runner == null:
		return
	engine.pitch_scale = clampf(runner.rpm / BASE_RPM * character_pitch, 0.28, 4.0)
	var target: float = base_db
	if runner.shifting:
		target += SHIFT_DUCK_DB
	elif runner.limiter:
		# Devir kesici: 16 Hz'te açıp kapanır ("brrrap")
		target += -14.0 if fmod(_time * 16.0, 1.0) < 0.45 else 0.0
	elif runner.finish_time >= 0.0:
		target += -10.0   # çizgiden sonra gaz bırakıldı
	engine.volume_db = lerpf(engine.volume_db, target, 0.35)


func countdown_beep() -> void:
	_oneshot.stream = _beep_stream
	_oneshot.volume_db = -8.0
	_oneshot.play()


func go_beep() -> void:
	_oneshot.stream = _go_stream
	_oneshot.volume_db = -6.0
	_oneshot.play()


## Vites patlaması: `strength` 0-1 (kusursuz vites en gürü).
func backfire(strength: float, rival: bool = false) -> void:
	_pop.volume_db = lerpf(-16.0, -4.0, clampf(strength, 0.0, 1.0)) + (-10.0 if rival else 0.0)
	_pop.pitch_scale = randf_range(0.9, 1.15)
	_pop.play()


# --- Ses üretimi (bir kez) -------------------------------------------------------------

static func _ensure_streams() -> void:
	if _beep_stream:
		return
	_beep_stream = _make_tone(660.0, 0.14)
	_go_stream = _make_tone(990.0, 0.38)
	_pop_stream = _make_pop()


## Motor döngüsü: her ateşlemede sönümlenen bir rezonans darbesi (silindirler arası küçük
## farklarla), yarı frekansta gövde uğultusu ve darbeye bağlı yanma gürültüsü; sonra yumuşak
## doyum + alçak geçiren. Süzgeç durumu döngü sonundan başlatılır → döngü dikişsiz.
static func _make_engine(decay: float, resonance: float, harmonic: float, noise: float,
		body_gain: float) -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7351
	var count: int = int(LOOP_SECONDS * float(MIX_RATE))
	var cycles: int = int(round(LOOP_SECONDS * BASE_FIRE_HZ))
	var cylinder: PackedFloat32Array = PackedFloat32Array([1.0, 0.82, 0.94, 0.76])
	var cycle_gain: PackedFloat32Array = PackedFloat32Array()
	for i: int in cycles:
		cycle_gain.append(cylinder[i % 4] * rng.randf_range(0.85, 1.12))
	var raw: PackedFloat32Array = PackedFloat32Array()
	raw.resize(count)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var cycle_pos: float = t * BASE_FIRE_HZ
		var k: int = int(cycle_pos) % cycles
		var phase: float = cycle_pos - floorf(cycle_pos)
		var ring: float = sin(TAU * phase * resonance) + harmonic * sin(TAU * phase * resonance * 2.0)
		var pulse: float = exp(-phase * decay) * ring * cycle_gain[k]
		var body: float = body_gain * sin(TAU * t * BASE_FIRE_HZ * 0.5)
		var grit: float = rng.randf_range(-1.0, 1.0) * noise * exp(-phase * 3.0)
		raw[i] = tanh(1.7 * (pulse + body + grit))
	# İki geçişli tek kutuplu alçak geçiren: ikinci geçiş birincinin bitiş durumundan başlar.
	var state: float = 0.0
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	for _pass: int in 2:
		for i: int in count:
			state += (raw[i] - state) * 0.32
			out[i] = state
	return _wav(out, 0.75, true)


static func _make_tone(hz: float, seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var envelope: float = minf(t / 0.008, 1.0) * clampf((seconds - t) / 0.06, 0.0, 1.0)
		samples[i] = envelope * (sin(TAU * hz * t) * 0.8 + sin(TAU * hz * 2.0 * t) * 0.2)
	return _wav(samples, 0.6, false)


## Backfire: kısa gürültü patlaması + alçak "güm".
static func _make_pop() -> AudioStreamWAV:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 991
	var seconds: float = 0.22
	var count: int = int(seconds * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	var state: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		state += (rng.randf_range(-1.0, 1.0) - state) * 0.45
		var crack: float = state * exp(-t * 38.0) * 1.6
		var thump: float = sin(TAU * 62.0 * t) * exp(-t * 16.0)
		samples[i] = tanh(crack + thump)
	return _wav(samples, 0.9, false)


static func _wav(samples: PackedFloat32Array, gain: float, loop: bool) -> AudioStreamWAV:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = samples.size()
	return stream
