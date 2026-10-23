class_name NewsSfx
extends Node
## OTO MANŞET SESLERİ (2026-10-17, kullanıcı: "+ bisiklet zili"). Ses dosyası yok — HudSfx / RewardSfx gibi KODLA
## üretilir, Efekt (SFX) bus'ında çalar:
##   bell   — gazeteci çocuğun bisiklet zili: "dırın dırın" (kubbe zilin uyumsuz kısmileri, tokmak saniyede ~30 kez
##            vurur; iki kısa çalış). Gazete ekrana gelmeden hemen önce.
##   slap   — gazete masaya düşer: tok "pat" (alçak geçiren gürültü + kısa gövde vuruşu) ve kâğıdın şaklaması.
##   rustle — kâğıt hışırtısı: rastgele aralıklı ince çıtırtılar (bant geçiren kısa gürültüler) yumuşak bir zemin üstünde.
## Sentez açılışta bir kez arka plan iş parçacığında yapılır; hazır değilken istenen ses atlanır. NewsScreen kurar.

const MIX_RATE: int = 22050
const BELL_DB: float = -9.0
const SLAP_DB: float = -4.0
const RUSTLE_DB: float = -10.0

## Bisiklet zili kubbesi: [frekans oranı, kazanç, sönüm çarpanı]. İkinci kısmi birinciye çok yakın: "vıvv" diye
## dalgalanan zil sesi (iki yakın frekansın vuruşu) oradan gelir.
const DOME: Array = [[1.0, 1.0, 1.0], [1.012, 0.7, 1.05], [2.32, 0.42, 1.7], [3.86, 0.2, 2.4], [5.1, 0.08, 3.2]]
const BELL_HZ: float = 2050.0

static var _bell_stream: AudioStreamWAV
static var _slap_stream: AudioStreamWAV
static var _rustle_stream: AudioStreamWAV

var _bell: AudioStreamPlayer
var _slap: AudioStreamPlayer
var _rustle: AudioStreamPlayer
var _task: int = -1


func _ready() -> void:
	name = "NewsSfx"
	_bell = _player(BELL_DB)
	_slap = _player(SLAP_DB)
	_rustle = _player(RUSTLE_DB)
	if _rustle_stream == null:
		_task = WorkerThreadPool.add_task(_synthesize)


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func bell() -> void:
	_play(_bell, _bell_stream, 1.0)


func slap() -> void:
	_play(_slap, _slap_stream, randf_range(0.95, 1.05))


func rustle() -> void:
	_play(_rustle, _rustle_stream, randf_range(0.92, 1.08))


func _play(player: AudioStreamPlayer, stream: AudioStreamWAV, pitch: float) -> void:
	if not _ready_streams():
		return
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func _ready_streams() -> bool:
	if _task >= 0:
		if not WorkerThreadPool.is_task_completed(_task):
			return false
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
	return _bell_stream != null and _slap_stream != null and _rustle_stream != null


func _player(volume_db: float) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = GameSettings.SFX_BUS
	player.volume_db = volume_db
	add_child(player)
	return player


# --- Sentez (arka plan) --------------------------------------------------------------------------

static func _synthesize() -> void:
	var streams: Array = AudioCache.fetch("news_sfx", func() -> Array:
		return [_wav(bell_samples()), _wav(slap_samples()), _wav(rustle_samples())])
	_bell_stream = streams[0]
	_slap_stream = streams[1]
	_rustle_stream = streams[2]   # en son: ana iş parçacığı üçü de hazır olunca çalar


## "Dırın dırın": her çalışta tokmak kubbeye hızla 6 kez vurur (ilk vuruş en güçlü), zil çınlayarak söner.
## QA da çağırır (dinleme dosyası).
static func bell_samples() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1903
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(1.5 * MIX_RATE))
	for ring: int in 2:
		var at: float = 0.02 + 0.36 * float(ring)
		for hit: int in 6:
			var amp: float = (0.5 if hit == 0 else rng.randf_range(0.22, 0.32)) * (1.0 - 0.06 * float(hit))
			_strike(out, at, BELL_HZ * rng.randf_range(0.998, 1.002), amp, 3.2, DOME)
			_tick(out, at, 0.08, rng)   # tokmağın metal tıkı
			at += rng.randf_range(0.028, 0.036)
	return out


## Masaya düşen gazete: kalın kâğıt destesinin tok "pat"ı + kenarların şaklaması. QA da çağırır.
static func slap_samples() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2210
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int(0.35 * MIX_RATE))
	_noise(out, 0.0, 0.09, 380.0, 0.95, 55.0, rng)     # tok gövde: alçak bant gürültü, hızlı sönüm
	_thump(out, 0.0, 95.0, 0.55, 38.0)                  # masanın gümbürtüsü
	_noise(out, 0.004, 0.05, 2400.0, 0.5, 90.0, rng)    # kâğıt kenarının şaklaması
	_noise(out, 0.03, 0.04, 4200.0, 0.18, 120.0, rng)   # yayılan sayfaların hışırtısı
	return out


## Kâğıt hışırtısı: 0,45 sn boyunca kabarıp sönen, sık ama düzensiz ince çıtırtılar. QA da çağırır.
static func rustle_samples() -> PackedFloat32Array:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 3117
	var length: float = 0.5
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(int((length + 0.1) * MIX_RATE))
	_noise(out, 0.0, length, 1600.0, 0.06, 0.0, rng, true)   # yumuşak zemin
	var at: float = 0.0
	while at < length:
		var x: float = at / length
		var swell: float = sin(PI * x) * (0.6 + 0.4 * sin(PI * x * 3.0))
		_noise(out, at, rng.randf_range(0.004, 0.012), rng.randf_range(2200.0, 6500.0), 0.35 * swell * rng.randf_range(0.4, 1.0),
			rng.randf_range(220.0, 400.0), rng)
		at += rng.randf_range(0.006, 0.022)
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
		var d: float = decay * float(partial[2])
		var count: int = mini(int(5.0 / d * MIX_RATE), out.size() - start)
		var w: float = TAU * f / float(MIX_RATE)
		var fall: float = exp(-d / float(MIX_RATE))
		var env: float = amp * float(partial[1])
		for i: int in count:
			out[start + i] += env * minf(float(i) / 12.0, 1.0) * sin(w * float(i))
			env *= fall


## Tokmağın kubbeye değdiği an: 4 ms parlak gürültü.
static func _tick(out: PackedFloat32Array, at: float, amp: float, rng: RandomNumberGenerator) -> void:
	_noise(out, at, 0.004, 5200.0, amp, 600.0, rng)


## Bant geçiren gürültü parçası (durum değişkenli süzgeç). `decay` > 0: üstel sönüm (1/sn); 0 ve `swell`: süre boyunca
## yumuşakça kabarıp söner. Sonu her durumda 3 ms'de kapanır (tık olmasın).
static func _noise(out: PackedFloat32Array, at: float, seconds: float, hz: float, amp: float, decay: float,
		rng: RandomNumberGenerator, swell: bool = false) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = mini(int(seconds * MIX_RATE), out.size() - start)
	if count <= 0:
		return
	var f: float = 2.0 * sin(PI * minf(hz, MIX_RATE * 0.22) / float(MIX_RATE))
	var low: float = 0.0
	var band: float = 0.0
	var fade: int = maxi(int(0.003 * MIX_RATE), 1)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var high: float = rng.randf_range(-1.0, 1.0) - low - 0.8 * band
		band += f * high
		low += f * band
		var env: float = sin(PI * float(i) / float(count)) if swell else exp(-t * decay)
		env *= minf(float(i) / 8.0, 1.0) * minf(float(count - i) / float(fade), 1.0)
		out[start + i] += amp * band * env


## Alçak frekanslı gövde vuruşu: perdesi hafifçe düşen sinüs.
static func _thump(out: PackedFloat32Array, at: float, hz: float, amp: float, decay: float) -> void:
	var start: int = int(at * MIX_RATE)
	var count: int = mini(int(0.2 * MIX_RATE), out.size() - start)
	var phase: float = 0.0
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		phase += TAU * hz * (1.0 + 0.6 * exp(-t * 60.0)) / float(MIX_RATE)
		out[start + i] += amp * sin(phase) * exp(-t * decay) * minf(float(i) / 20.0, 1.0)


## En yüksek tepe 0,89'a getirilir (düzeyi bus ve *_DB belirler); son 0,1 sn'de söndürülür.
static func _wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak: float = 0.0001
	for v: float in samples:
		peak = maxf(peak, absf(v))
	var gain: float = 0.89 / peak
	var tail: int = mini(int(0.1 * MIX_RATE), samples.size())
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
