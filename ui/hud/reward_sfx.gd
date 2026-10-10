class_name RewardSfx
extends Node
## ÖDÜL SESLERİ — ses varlığı yok, RaceAudio gibi KODLA üretilir ve bir kez önbelleğe alınır.
## fanfare: pencere açılınca kısa yükselen arpej · tick: sayı sayarken tık · coin: para sayaca
## varınca "çın-çın" · gem: gem varınca ince çan. Hepsi Efekt (SFX) bus'ında çalar.

const MIX_RATE: int = 22050
## Sayma tıkları en fazla bu sıklıkta çalar (her karede değil).
const TICK_GAP_MSEC: int = 55

static var _fanfare_stream: AudioStreamWAV
static var _tick_stream: AudioStreamWAV
static var _coin_stream: AudioStreamWAV
static var _gem_stream: AudioStreamWAV

var _fanfare: AudioStreamPlayer
var _tick: AudioStreamPlayer
var _coin: AudioStreamPlayer
var _gem: AudioStreamPlayer
var _last_tick: int = 0


func _ready() -> void:
	name = "RewardSfx"
	_ensure_streams()
	_fanfare = _player(_fanfare_stream, -4.0, 1)
	_tick = _player(_tick_stream, -14.0, 2)
	_coin = _player(_coin_stream, -9.0, 6)
	_gem = _player(_gem_stream, -8.0, 6)


func fanfare() -> void:
	_fanfare.play()


## progress 0-1: sayı büyüdükçe tık incelir.
func tick(progress: float) -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_tick < TICK_GAP_MSEC:
		return
	_last_tick = now
	_tick.pitch_scale = lerpf(1.0, 1.6, clampf(progress, 0.0, 1.0))
	_tick.play()


## index: kaçıncı para (sıradakiler biraz daha ince çalar).
func coin(index: int) -> void:
	_coin.pitch_scale = 1.0 + minf(float(index) * 0.03, 0.4) + randf_range(-0.02, 0.02)
	_coin.play()


func gem(index: int) -> void:
	_gem.pitch_scale = 1.0 + minf(float(index) * 0.04, 0.4) + randf_range(-0.02, 0.02)
	_gem.play()


func _player(stream: AudioStream, volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	player.bus = GameSettings.SFX_BUS
	add_child(player)
	return player


# --- Üretim ---------------------------------------------------------------------

static func _ensure_streams() -> void:
	if _fanfare_stream:
		return
	# C5 E5 G5 → C6 (uzun): "kazandın" arpeji
	_fanfare_stream = _notes([[523.25, 0.08], [659.25, 0.08], [783.99, 0.08], [1046.5, 0.45]], 4.0)
	_tick_stream = _notes([[1760.0, 0.035]], 60.0)
	# Klasik para sesi: kısa B5 → uzun E6
	_coin_stream = _notes([[987.77, 0.055], [1318.5, 0.28]], 9.0)
	_gem_stream = _bell(2093.0, 0.4)


## Ardışık notalar; her nota kendi zarfıyla (hızlı atak, üstel sönüm) çalar.
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
			# temel + oktav + biraz kare dalga parlaklığı (3. harmonik)
			samples[start + i] = envelope * (sin(TAU * hz * t) * 0.65 + sin(TAU * hz * 2.0 * t) * 0.2
				+ sin(TAU * hz * 3.0 * t) * 0.15)
		start += count
	return _wav(samples, 0.7)


## Çan: uyumsuz kısmi sesler (1 · 2,76 · 5,4) — gem parıltısı.
static func _bell(hz: float, seconds: float) -> AudioStreamWAV:
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(seconds * float(MIX_RATE)))
	for i: int in samples.size():
		var t: float = float(i) / float(MIX_RATE)
		var attack: float = minf(t / 0.003, 1.0)
		samples[i] = attack * (sin(TAU * hz * t) * exp(-t * 9.0) * 0.6
			+ sin(TAU * hz * 2.76 * t) * exp(-t * 16.0) * 0.3
			+ sin(TAU * hz * 5.4 * t) * exp(-t * 28.0) * 0.1)
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
