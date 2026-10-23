class_name HudSfx
extends Node
## TAMİR SESLERİ (2026-10-17, kullanıcı: "tamirdeki aracın altınını toplama sesi ve elmasla geçme sesi ekle").
## Ses dosyası yok — RewardSfx / TrafficSfx gibi KODLA üretilir, Efekt (SFX) bus'ında çalar:
##   collect  — tamiri biten araçtan para toplanınca: "ka-çın-çın" (kasa tıkı + iki parlak çan), ardından araçtan
##              fışkıran altınların yere düşüp sekme şıngırtısı. Düşüş zamanları RepairFx.coins'tekilerle aynı aralıkta
##              (paralar 0,025 sn arayla fırlar, 0,4–0,9 sn'de yere değer, iki kez seker).
##   gem_skip — ELMASLA BİTİR (uzun tamir ya da parça takma): yükselen hışırtı (zaman ileri sarılıyor) + kristal
##              arpej, varışta parlak akor ve ışıltı tıkırtıları.
## Sentez açılışta bir kez arka plan iş parçacığında yapılır (telefonda ana iş parçacığında takılma olurdu); hazır
## değilken istenen ses atlanır. Hud kurar.

const MIX_RATE: int = 22050
const COLLECT_DB: float = -6.0
const GEM_DB: float = -5.0

## Vurulan cisimlerin kısmi sesleri: [frekans oranı, kazanç, sönüm çarpanı]. Çan (para "çın"ı) ve küçük metal
## disk (yere düşen altın: ince levhanın uyumsuz kipleri).
const BELL: Array = [[1.0, 1.0, 1.0], [2.0, 0.45, 1.6], [2.76, 0.32, 2.2], [4.07, 0.16, 3.0]]
const COIN: Array = [[1.0, 1.0, 1.0], [1.73, 0.6, 1.3], [2.33, 0.45, 1.6], [3.91, 0.2, 2.0]]
const GLASS: Array = [[1.0, 1.0, 1.0], [3.0, 0.22, 1.8], [5.04, 0.08, 2.6]]

static var _collect_stream: AudioStreamWAV
static var _gem_stream: AudioStreamWAV

var _collect: AudioStreamPlayer
var _gem: AudioStreamPlayer
var _task: int = -1


func _ready() -> void:
	name = "HudSfx"
	_collect = _player(COLLECT_DB, 3)
	_gem = _player(GEM_DB, 2)
	if _gem_stream == null:
		_task = WorkerThreadPool.add_task(_synthesize)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


## Tamiri biten araçtan para toplandı.
func collect() -> void:
	if not _ready_streams():
		return
	_collect.stream = _collect_stream
	_collect.pitch_scale = randf_range(0.97, 1.03)
	_collect.play()


## Elmasla bitirildi (uzun tamir ya da parça takma).
func gem_skip() -> void:
	if not _ready_streams():
		return
	_gem.stream = _gem_stream
	_gem.play()


func _ready_streams() -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _collect_stream != null and _gem_stream != null


func _player(volume_db: float, polyphony: int) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = GameSettings.SFX_BUS
	player.volume_db = volume_db
	player.max_polyphony = polyphony
	add_child(player)
	return player


# --- Sentez (arka plan) --------------------------------------------------------------------------

static func _synthesize() -> void:
	var streams: Array = AudioCache.fetch("hud_sfx", func() -> Array:
		return [_wav(collect_samples()), _wav(gem_samples())])
	_collect_stream = streams[0]
	_gem_stream = streams[1]   # en son: ana iş parçacığı ikisi de hazır olunca çalar


## "Ka-çın-çın" + yere düşen altınlar. QA da çağırır (dinleme dosyası).
static func collect_samples() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5150
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(1.2 * MIX_RATE))
	_click(out, 0.0, 0.55, rng)                    # "ka": kasa çekmecesinin mekanik tıkı
	_strike(out, 0.03, 1568.0, 0.5, 5.5, BELL)     # "çın" (G6)
	_strike(out, 0.09, 2093.0, 0.45, 4.5, BELL)    # "çın" (C7, daha ince)
	for i: int in 11:
		var land: float = 0.4 + 0.042 * float(i) + rng.randf_range(-0.015, 0.015)
		var hz: float = rng.randf_range(2300.0, 3500.0)
		var amp: float = rng.randf_range(0.14, 0.22) * (1.0 - 0.035 * float(i))
		_strike(out, land, hz, amp, 40.0, COIN)
		_strike(out, land + rng.randf_range(0.12, 0.16), hz * rng.randf_range(0.99, 1.02), amp * 0.4, 46.0, COIN)
		_strike(out, land + rng.randf_range(0.19, 0.23), hz * rng.randf_range(0.99, 1.02), amp * 0.15, 52.0, COIN)
	return out


## Hışırtı + kristal arpej + varış akoru. QA da çağırır.
static func gem_samples() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7707
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(1.6 * MIX_RATE))
	_sweep(out, 0.0, 0.42, 450.0, 4000.0, 0.3, rng)
	# E majör pentatonik yukarı koşu, gittikçe sıklaşır: E6 F#6 G#6 B6 C#7 E7 F#7 G#7
	var notes: Array[float] = [1318.5, 1480.0, 1661.2, 1975.5, 2217.5, 2637.0, 2960.0, 3322.4]
	var at: float = 0.04
	for i: int in notes.size():
		_strike(out, at, notes[i], 0.13 + 0.012 * float(i), 16.0, GLASS)
		at += lerpf(0.058, 0.03, float(i) / float(notes.size() - 1))
	var land: float = at + 0.02
	for hz: float in [1318.5, 1975.5, 2637.0]:     # E6 + B6 + E7
		_strike(out, land, hz, 0.28, 3.4, BELL)
	for k: int in 9:                               # ışıltı
		_strike(out, land + rng.randf_range(0.03, 0.65), rng.randf_range(3300.0, 4600.0), 0.05, 28.0, GLASS)
	return out


## Vurulan cisim: her kısmi ses kendi sönümüyle (hızlı atak, üstel sönüm). Nyquist'e yakın kısmiler atlanır.
static func _strike(out: PackedFloat32Array, at: float, hz: float, amp: float, decay: float, partials: Array) -> void:
	var start: int = int(at * MIX_RATE)
	if start >= out.size():
		return
	for partial: Array in partials:
		var f: float = hz * float(partial[0])
		if f >= MIX_RATE * 0.45:
			continue
		var gain: float = amp * float(partial[1])
		var d: float = decay * float(partial[2])
		var count: int = mini(int(5.0 / d * MIX_RATE), out.size() - start)
		var w: float = TAU * f / float(MIX_RATE)
		var fall: float = exp(-d / float(MIX_RATE))
		var env: float = gain
		for i: int in count:
			out[start + i] += env * minf(float(i) / 30.0, 1.0) * sin(w * float(i))
			env *= fall


## "Ka": 15 ms bant geçiren gürültü + kısa tok vuruş.
static func _click(out: PackedFloat32Array, at: float, amp: float, rng: RandomNumberGenerator) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = mini(int(0.05 * MIX_RATE), out.size() - start)
	var low: float = 0.0
	var band: float = 0.0
	var f: float = 2.0 * sin(PI * 1900.0 / float(MIX_RATE))
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var high: float = rng.randf_range(-1.0, 1.0) - low - 0.6 * band
		band += f * high
		low += f * band
		out[start + i] += amp * (band * exp(-t * 140.0) + 0.5 * sin(TAU * 190.0 * t) * exp(-t * 70.0))


## Hışırtı: kesimi f0 → f1 üstel kayan bant geçiren gürültü; sonuna doğru kabarır, varışta kesilir.
static func _sweep(out: PackedFloat32Array, at: float, seconds: float, f0: float, f1: float, amp: float,
		rng: RandomNumberGenerator) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = mini(int(seconds * MIX_RATE), out.size() - start)
	var low: float = 0.0
	var band: float = 0.0
	for i: int in count:
		var x: float = float(i) / float(count)
		var f: float = 2.0 * sin(PI * f0 * pow(f1 / f0, x) / float(MIX_RATE))
		var high: float = rng.randf_range(-1.0, 1.0) - low - 0.7 * band
		band += f * high
		low += f * band
		out[start + i] += amp * band * pow(x, 1.6) * clampf((1.0 - x) / 0.1, 0.0, 1.0)


## En yüksek tepe 0,89'a getirilir (ses düzeyini oyuncu bus'ı ve COLLECT_DB / GEM_DB belirler); son 0,15 sn'de
## söndürülür (uzun çanlar arabelleğin sonunda tık diye kesilmesin).
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0001
	for v: float in samples:
		peak = maxf(peak, absf(v))
	var gain: float = 0.89 / peak
	var tail: int = mini(int(0.15 * MIX_RATE), samples.size())
	for i: int in tail:
		samples[samples.size() - 1 - i] *= float(i) / float(tail)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.data = bytes
	return stream
