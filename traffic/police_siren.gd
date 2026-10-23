class_name PoliceSiren
extends Node
## POLİS SİRENİ — ses varlığı yok, RewardSfx / RaceAudio gibi KODLA sentezlenir ve bir kez önbelleğe alınır.
## İki tip: WAIL (Türk / Amerikan tipi elektronik siren — Bentley trafik polisi) ve HI_LO (Alman "Martinshorn"u,
## la–re dörtlüsü iki ton — POLIZEI Vito).
##
## GERÇEKÇİLİK (kullanıcı: "pek hoşuma gitmedi, daha gerçekçi yap"): saf sinüs yerine gerçek sirenin zinciri
## taklit edilir — kaynak (elektronik sürücünün kare dalgası / havalı kornanın pirinç tınısı) → korna hoparlörünün
## rezonansları (her harmonik o anki frekansında süzülür: uluma yükselirken tını da değişir) → sürücü doyması
## (yumuşak kırpma) → binalardan gelen kısa yankılar. WAIL kovalamacadaki polis gibi uluma + hızlı "yelp" karışımıdır;
## HI_LO'da her ton hafif farklı akortlu iki kornadan çıkar (havalı Martinshorn'daki vuru), ton başında basınç
## oturana kadar perde hafifçe yükselir. Döngü tam tur sayısına ölçeklenir ve yankı döngü içinde sarar: dikiş yok.
##
## DUYULMA (kullanıcı kararı): polis haritaya girdiği andan çıkana kadar duyulur; ses ekrandaki konumuna göre —
## ekranın tam ortasında en yüksek, kenarlarında en az (ama duyulur). Ekran dışındayken (girerken / çıkarken ya da
## kamera başka yere bakarken) yavaşça daha da kısılır ama polis şehirde olduğu sürece susmaz. Uzaklaştıkça tiz
## kısılır (uzaktaki siren boğuk), ekranın solundaki polis soldan duyulur, yanından geçerken Doppler (perde düşer).
## Kendi bus'ında çalar (alçak geçiren + panner), o bus Efekt (SFX) bus'ına gider: ayarlardaki efekt düzeyi uygulanır.
## Bir ekran açıkken (garaj vb.) susar.

enum Kind { WAIL, HI_LO }

const MIX_RATE: int = 24000
## Ses düzeyi: ekranın tam ortasında CENTER_DB, ekran kenarında EDGE_DB (arası dB'de doğrusal). Kenarın dışında ekran
## yarı boyu başına OUTSIDE_DB daha kısılır, FLOOR_DB'nin altına inmez.
const CENTER_DB: float = -8.0
const EDGE_DB: float = -21.0
const OUTSIDE_DB: float = 8.0
const FLOOR_DB: float = -31.0
const SILENT_DB: float = -60.0
## Uzaklık boğukluğu (alçak geçiren kesimi): ortada açık, ses kısıldıkça kesim CUTOFF_FAR'a iner.
const CUTOFF_NEAR: float = 11000.0
const CUTOFF_FAR: float = 1500.0
## Stereo genişliği (ekranın sol / sağ kenarındaki polis bu kadar yana).
const PAN_WIDTH: float = 0.6
## Doppler: ses hızı birim/sn cinsinden (trafikte araç ~0,6 birim ≈ 4,5 m → 1 birim ≈ 7,5 m; 343 m/sn ≈ 46).
## Dinleyici ekran ortasının LISTENER_HEIGHT üstünde: polis tam altından geçerken perde birden sıçramaz.
const SOUND_SPEED: float = 46.0
const LISTENER_HEIGHT: float = 1.2
const DOPPLER_MAX: float = 0.09
## Açılış hızı (dB/sn; girişte pıtırtısız ama hemen duyulur) ve susarken kısılma hızı (tıklamasız).
const ATTACK_RATE: float = 140.0
const RELEASE_RATE: float = 120.0
## Perde / pan / süzgeç yumuşatma (1/sn).
const SMOOTH: float = 10.0
const BUS: StringName = &"PoliceSiren"

## Sentez: harmonik genlikleri bu kadar örnekte bir güncellenir; bu frekansın üstündeki harmonik atlanır.
const BLOCK: int = 64
const TOP_HZ: float = 9000.0
## Binalardan yankı: (gecikme sn, kazanç). Yankılar yumuşatılmış (ECHO_TONE Hz alçak geçiren) kopyadan.
const ECHOES: Array[Vector2] = [Vector2(0.027, 0.26), Vector2(0.046, 0.19), Vector2(0.081, 0.14),
	Vector2(0.133, 0.095), Vector2(0.21, 0.06)]
const ECHO_TONE: float = 2800.0

static var _streams: Dictionary = {}   # Kind → AudioStreamWAV

var _player: AudioStreamPlayer
var _filter: AudioEffectLowPassFilter
var _panner: AudioEffectPanner
var _target: Node3D
var _last_position: Vector3 = Vector3.INF
var _pitch: float = 1.0
var _fresh: bool = true   # ilk karede pan / süzgeç yumuşatılmadan yerine oturur
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	name = "PoliceSiren"
	_rng.randomize()
	var bus: int = _ensure_bus()
	_filter = AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter
	_panner = AudioServer.get_bus_effect(bus, 1) as AudioEffectPanner
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	_player.volume_db = SILENT_DB
	add_child(_player)


## Sirenin bus'ı: alçak geçiren (0) + panner (1) → SFX. Bir kez kurulur (sahne yeniden yüklense de aynı bus).
static func _ensure_bus() -> int:
	var index: int = AudioServer.get_bus_index(BUS)
	if index >= 0:
		return index
	AudioServer.add_bus()
	index = AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, BUS)
	AudioServer.set_bus_send(index, GameSettings.SFX_BUS)
	var low_pass: AudioEffectLowPassFilter = AudioEffectLowPassFilter.new()
	low_pass.cutoff_hz = CUTOFF_NEAR
	low_pass.db = AudioEffectFilter.FILTER_12DB
	AudioServer.add_bus_effect(index, low_pass)
	AudioServer.add_bus_effect(index, AudioEffectPanner.new())
	return index


## Polis aracı tipine göre siren (Vito Alman polisi → iki ton; diğerleri uluma).
static func kind_for(vehicle_id: StringName) -> Kind:
	return Kind.HI_LO if vehicle_id == &"police_vito" else Kind.WAIL


## Bu aracı izleyerek çalmaya başla (ses kısa bir açılışla gelir; her kovalamaca döngünün başka yerinden başlar).
func follow(vehicle: Node3D, kind: Kind) -> void:
	_target = vehicle
	_last_position = Vector3.INF
	_fresh = true
	var wav: AudioStreamWAV = stream(kind)
	_player.stream = wav
	_player.volume_db = SILENT_DB
	_pitch = 1.0
	_player.pitch_scale = 1.0
	_player.play(_rng.randf() * wav.get_length())


## Sireni sustur: tıklamasın diye kısılarak durur (is_playing hemen false döner).
func stop() -> void:
	_target = null


## Siren polisi izleyerek çalıyor mu? (Susarken kısılma süresinde false.)
func is_playing() -> bool:
	return _player.playing and is_instance_valid(_target)


## O anki ses düzeyi (dB; test / QA).
func volume_db() -> float:
	return _player.volume_db


## Ekrandaki konuma göre hedef düzey: `edge` 0 = ekranın tam ortası, 1 = kenarı, > 1 ekran dışı.
static func level_db(edge: float) -> float:
	if edge <= 1.0:
		return lerpf(CENTER_DB, EDGE_DB, maxf(edge, 0.0))
	return maxf(EDGE_DB - (edge - 1.0) * OUTSIDE_DB, FLOOR_DB)


func _physics_process(delta: float) -> void:
	if not _player.playing:
		return
	if not is_instance_valid(_target):
		_target = null   # araç silindi: kısılarak sus
	var goal: float = SILENT_DB
	var camera: Camera3D = get_viewport().get_camera_3d()
	if _target and camera and not _screen_open():
		var size: Vector2 = get_viewport().get_visible_rect().size
		var place: Vector2 = camera.unproject_position(_target.global_position) / size * 2.0 - Vector2.ONE
		# Yuvarlatılmış dikdörtgen ölçü: ekranın dört kenarı da 1 (köşeler biraz dışarıda)
		var edge: float = pow(pow(absf(place.x), 4.0) + pow(absf(place.y), 4.0), 0.25)
		goal = level_db(edge)
		var far: float = clampf(inverse_lerp(CENTER_DB, FLOOR_DB, goal), 0.0, 1.0)
		var cutoff: float = CUTOFF_NEAR * pow(CUTOFF_FAR / CUTOFF_NEAR, pow(far, 0.8))
		var pan: float = clampf(place.x, -1.0, 1.0) * PAN_WIDTH
		var blend: float = 1.0 if _fresh else 1.0 - exp(-SMOOTH * delta)
		_filter.cutoff_hz = lerpf(_filter.cutoff_hz, cutoff, blend)
		_panner.pan = lerpf(_panner.pan, pan, blend)
		_fresh = false
		_doppler(camera, delta)
	var rate: float = ATTACK_RATE if _target else RELEASE_RATE
	_player.volume_db = move_toward(_player.volume_db, goal, rate * delta)
	if _target == null and _player.volume_db <= SILENT_DB + 0.01:
		_player.stop()


## Perde: aracın dinleyiciye (ekran ortasının üstü) yaklaşma hızından. Yalnızca aracın hızı sayılır — kamerayı
## kaydırmak perdeyi oynatmaz.
func _doppler(camera: Camera3D, delta: float) -> void:
	var at: Vector3 = _target.global_position
	if _last_position != Vector3.INF and delta > 0.0:
		var listener: Vector3 = WorldCamera.ground_point(camera) + Vector3.UP * LISTENER_HEIGHT
		var away: Vector3 = (at - listener).normalized()
		var radial: float = ((at - _last_position) / delta).dot(away)   # > 0 uzaklaşıyor
		var goal: float = clampf(1.0 / (1.0 + radial / SOUND_SPEED), 1.0 - DOPPLER_MAX, 1.0 + DOPPLER_MAX)
		_pitch = lerpf(_pitch, goal, 1.0 - exp(-SMOOTH * delta))
		_player.pitch_scale = _pitch
	_last_position = at


func _screen_open() -> bool:
	var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
	return router != null and router.top() != &""


## Sentezlenmiş siren (döngülü, önbellekli). Önbellekte yoksa BURADA üretilir (telefonda takılma olur) —
## PoliceChase bunu polis modeliyle birlikte arka planda build() ile önceden hazırlar.
static func stream(kind: Kind) -> AudioStreamWAV:
	if not _streams.has(kind):
		_streams[kind] = build(kind)
	return _streams[kind]


static func has_stream(kind: Kind) -> bool:
	return _streams.has(kind)


## Arka planda üretilmiş sesi önbelleğe koyar (ANA iş parçacığında çağrılmalı).
static func store(kind: Kind, wav: AudioStreamWAV) -> void:
	if wav and not _streams.has(kind):
		_streams[kind] = wav


## Saf sentez (önbelleğe dokunmaz): iş parçacığından çağrılabilir. Paketlenmiş sürümde diskten (AudioCache).
static func build(kind: Kind) -> AudioStreamWAV:
	return AudioCache.fetch("siren_%d" % kind, _synth.bind(kind))


static func _synth(kind: Kind) -> AudioStreamWAV:
	if kind == Kind.WAIL:
		return _to_wav(_make_wail(), 1.9)
	return _to_wav(_make_hi_lo(), 1.4)


# --- Sentez (arka plan) --------------------------------------------------------------------------

## Elektronik siren: 4,6 sn uluma (motorlu siren gibi hızlanarak yükselir, yavaşlayarak düşer: 650 → 1.480 → 650 Hz)
## + 3 sn "yelp" (aynı aralık 0,3 sn'de bir — kovalamacada polis ikisini değiştirir). Kaynak: sürücünün kare dalgası
## (doluluk %46: tek harmoniklerin yanında biraz çift), korna hoparlörü 1,3 / 2,6 / 3,9 kHz rezonanslı.
static func _make_wail() -> PackedFloat32Array:
	var low: float = 650.0
	var high: float = 1480.0
	var freqs: PackedFloat32Array = PackedFloat32Array()
	_sweep(freqs, 2.1, low, high, 0.85)
	_sweep(freqs, 2.5, high, low, 0.95)
	for i: int in 10:
		_sweep(freqs, 0.135, low, high, 0.06)
		_sweep(freqs, 0.165, high, low, 0.07)
	var source: PackedFloat32Array = PackedFloat32Array()
	for n: int in range(1, 15):
		source.append(sin(float(n) * PI * 0.46) / float(n))
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(freqs.size())
	_additive(out, freqs, PackedFloat32Array(), source, [500.0, 5500.0, 1300.0, 1.4, 2600.0, 0.9, 3900.0, 0.5], 1.0)
	return out


## Frekans eğrisine `seconds` sürelik geçiş ekler: başta hızlı, sona doğru yavaşlayan (zaman sabiti `tau` sn).
static func _sweep(freqs: PackedFloat32Array, seconds: float, from: float, to: float, tau: float) -> void:
	var count: int = int(seconds * MIX_RATE)
	var full: float = 1.0 - exp(-seconds / tau)
	for i: int in count:
		var t: float = float(i) / MIX_RATE
		freqs.append(lerpf(from, to, (1.0 - exp(-t / tau)) / full))


## Martinshorn: la (440 Hz) ve re (587 Hz), her ton 0,65 sn, 4 tam çevrim (5,2 sn). Her ton hafif farklı akortlu
## iki kornadan (vuru); ton başında basınç oturana kadar perde %3,5 alttan gelir, valf geçişinde eski korna ~25 ms'de
## söner (kısa örtüşme). Ton başına küçük perde / düzey farkı (sabit tohum: her seferinde aynı ses). Kaynak pirinç
## tınısı (bütün harmonikler), korna 0,9 / 1,8 / 2,9 kHz rezonanslı. Döngü bir la tonunun ortasından başlar: dikişte
## yalnızca o ton çalar.
static func _make_hi_lo() -> PackedFloat32Array:
	var tone: float = 0.65
	var length: float = tone * 8.0
	var count: int = int(length * MIX_RATE)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 14610
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var brass: PackedFloat32Array = PackedFloat32Array()
	for n: int in range(1, 17):
		brass.append(1.0 / pow(float(n), 0.85))
	var pair: PackedFloat32Array = brass.slice(0, 5)
	var horn: Array = [330.0, 4500.0, 900.0, 1.1, 1800.0, 1.0, 2900.0, 0.6]
	for high: int in 2:
		var starts: PackedFloat32Array = PackedFloat32Array()
		var tunes: PackedFloat32Array = PackedFloat32Array()
		var levels: PackedFloat32Array = PackedFloat32Array()
		for k: int in 4:
			starts.append(fposmod(tone * (2.0 * k + high) - tone * 0.5, length))
			tunes.append(1.0 + rng.randf_range(-0.003, 0.003))
			levels.append(db_to_linear(rng.randf_range(-0.8, 0.8)))
		var base: float = 587.33 if high == 1 else 440.0
		var freqs: PackedFloat32Array = PackedFloat32Array()
		var gains: PackedFloat32Array = PackedFloat32Array()
		freqs.resize(count)
		gains.resize(count)
		for i: int in count:
			var t: float = float(i) / MIX_RATE
			var k: int = 0
			var since: float = INF
			for j: int in 4:   # en son başlayan ton (döngü sarar)
				var d: float = fposmod(t - starts[j], length)
				if d < since:
					since = d
					k = j
			var f: float = base * tunes[k] * (1.0 - 0.035 * exp(-since / 0.035))
			var g: float = smoothstep(0.0, 0.03, since)
			if since > tone:
				var after: float = since - tone
				f *= 1.0 - 0.02 * (1.0 - exp(-after / 0.03))
				g = exp(-after / 0.025) if after < 0.15 else 0.0
			freqs[i] = f
			gains[i] = g * levels[k]
		var twin: PackedFloat32Array = freqs.duplicate()
		for i: int in count:
			twin[i] *= 1.0045   # eşi biraz tiz: ~2–3 Hz vuru
		_additive(out, freqs, gains, brass, horn, 1.0)
		_additive(out, twin, gains, pair, horn, 0.55)
	return out


## Korna hoparlörü / borusu frekans yanıtı: 2. derece yüksek geçiren `h[0]`, 6. derece alçak geçiren `h[1]`,
## üç rezonans tepesi (merkez, kazanç) çiftleri `h[2..7]` (log-frekansta ~yarım oktav genişlik).
static func _horn(h: Array, f: float) -> float:
	var hp: float = pow(f / float(h[0]), 2.0)
	var gain: float = hp / sqrt(1.0 + hp * hp) / sqrt(1.0 + pow(f / float(h[1]), 6.0))
	var peaks: float = 1.0
	for p: int in range(2, 8, 2):
		var octaves: float = log(f / float(h[p])) / log(2.0)
		peaks += float(h[p + 1]) * exp(-octaves * octaves / 0.09)
	return gain * peaks


## Toplamalı sentez `out`a eklenir: `freqs` örnek başına frekans, `gains` genlik zarfı (boşsa 1), `source` kaynağın
## harmonik genlikleri (1., 2., …). Her harmonik o anki frekansında kornadan (`horn`) geçer; TOP_HZ üstü atlanır.
## Genlikler BLOCK örnekte bir güncellenir. sin(nθ) özyinelemeyle (örnek başına bir sin + bir cos). Toplam faz tam tur
## sayısına ölçeklenir: döngü dikişsiz.
static func _additive(out: PackedFloat32Array, freqs: PackedFloat32Array, gains: PackedFloat32Array,
		source: PackedFloat32Array, horn: Array, level: float) -> void:
	var total: float = 0.0
	for f: float in freqs:
		total += f / MIX_RATE
	var scale: float = maxf(roundf(total), 1.0) / total
	var amps: PackedFloat32Array = PackedFloat32Array()
	amps.resize(source.size())
	var harmonics: int = 0
	var phase: float = 0.0
	var gated: bool = not gains.is_empty()
	for i: int in freqs.size():
		var f: float = freqs[i] * scale
		if i % BLOCK == 0:
			harmonics = 0
			for n: int in source.size():
				var at: float = f * float(n + 1)
				if at > TOP_HZ:
					break
				amps[n] = source[n] * _horn(horn, at)
				harmonics = n + 1
		var g: float = gains[i] if gated else 1.0
		if g > 0.0005:
			var theta: float = TAU * phase
			var two_cos: float = 2.0 * cos(theta)
			var previous: float = 0.0
			var current: float = sin(theta)
			var sum: float = 0.0
			for n: int in harmonics:
				sum += amps[n] * current
				var next: float = two_cos * current - previous
				previous = current
				current = next
			out[i] += sum * g * level
		phase = fposmod(phase + f / MIX_RATE, 1.0)


## Kuru sesten döngülü dalga: tepe 1'e ölçeklenir → sürücü doyması (tanh, `drive`) → binalardan yankılar (döngü
## içinde sarar; yankı kopyası alçak geçirenden, süzgeç döngünün sonundan ısıtılır) → −1 dBFS'e ölçeklenip 16 bit.
static func _to_wav(dry: PackedFloat32Array, drive: float) -> AudioStreamWAV:
	var count: int = dry.size()
	var peak: float = 0.0001
	for s: float in dry:
		peak = maxf(peak, absf(s))
	var norm: float = tanh(drive)
	var shaped: PackedFloat32Array = PackedFloat32Array()
	shaped.resize(count)
	for i: int in count:
		shaped[i] = tanh(dry[i] / peak * drive) / norm
	var a: float = 1.0 - exp(-TAU * ECHO_TONE / MIX_RATE)
	var state: float = 0.0
	for i: int in range(count - mini(count, 4096), count):
		state += a * (shaped[i] - state)
	var soft: PackedFloat32Array = PackedFloat32Array()
	soft.resize(count)
	for i: int in count:
		state += a * (shaped[i] - state)
		soft[i] = state
	var mixed: PackedFloat32Array = shaped.duplicate()
	for echo: Vector2 in ECHOES:
		var lag: int = count - int(echo.x * MIX_RATE) % count
		for i: int in count:
			mixed[i] += echo.y * soft[(i + lag) % count]
	var top: float = 0.0001
	for s: float in mixed:
		top = maxf(top, absf(s))
	var gain: float = 0.89 / top
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(count * 2)
	for i: int in count:
		bytes.encode_s16(i * 2, int(clampf(mixed[i] * gain, -1.0, 1.0) * 32767.0))
	var out: AudioStreamWAV = AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = MIX_RATE
	out.stereo = false
	out.data = bytes
	out.loop_mode = AudioStreamWAV.LOOP_FORWARD
	out.loop_begin = 0
	out.loop_end = count
	return out
