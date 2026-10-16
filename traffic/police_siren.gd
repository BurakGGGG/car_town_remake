class_name PoliceSiren
extends Node
## POLİS SİRENİ — ses varlığı yok, RewardSfx / RaceAudio gibi KODLA sentezlenir ve bir kez önbelleğe alınır.
## İki tip: WAIL (Türk / Amerikan tipi yükselip alçalan uluma — Bentley trafik polisi) ve HI_LO (Alman
## "Martinshorn"u, la–re dörtlüsü iki ton — POLIZEI Vito). Döngü uzunluğu tam periyot sayısına yuvarlanır,
## dikiş tıklamaz.
##
## Dinleyici oyun kamerasının baktığı zemin noktasıdır (ekranın ortası): polis yaklaştıkça ses yükselir, geçip
## uzaklaştıkça söner; kameraya yaklaşma / uzaklaşma hızından hafif Doppler (perde) kayması. Duyulma yarıçapı
## kameranın zumuyla büyür (uzaktan bakınca daha geniş alan görünür). Bir ekran açıkken (garaj vb.) susar.
## SFX bus'ında çalar (ayarlardaki efekt sesi düzeyi uygulanır).

enum Kind { WAIL, HI_LO }

const MIX_RATE: int = 22050
const MAX_DB: float = -7.0
const SILENT_DB: float = -60.0
## Duyulma yarıçapı: ortografik kameranın görünen boyunun bu katı (en az MIN_RADIUS birim).
const RADIUS_PER_SIZE: float = 1.1
const MIN_RADIUS: float = 4.0
const DOPPLER: float = 0.035      # perde kayması / (birim/sn)
const DOPPLER_MAX: float = 0.08
const FADE_RATE: float = 30.0     # dB/sn (ses birden açılıp kapanmasın)

static var _streams: Dictionary = {}   # Kind → AudioStreamWAV

var _player: AudioStreamPlayer
var _target: Node3D
var _last_distance: float = -1.0


func _ready() -> void:
	name = "PoliceSiren"
	_player = AudioStreamPlayer.new()
	_player.bus = GameSettings.SFX_BUS
	_player.volume_db = SILENT_DB
	add_child(_player)


## Polis aracı tipine göre siren (Vito Alman polisi → iki ton; diğerleri uluma).
static func kind_for(vehicle_id: StringName) -> Kind:
	return Kind.HI_LO if vehicle_id == &"police_vito" else Kind.WAIL


## Bu aracı izleyerek çalmaya başla (ses sessizden açılır).
func follow(vehicle: Node3D, kind: Kind) -> void:
	_target = vehicle
	_last_distance = -1.0
	_player.stream = stream(kind)
	_player.volume_db = SILENT_DB
	_player.pitch_scale = 1.0
	_player.play()


func stop() -> void:
	_target = null
	_player.stop()


func is_playing() -> bool:
	return _player.playing


## O anki ses düzeyi (dB; test / QA).
func volume_db() -> float:
	return _player.volume_db


func _process(delta: float) -> void:
	if not _player.playing:
		return
	if not is_instance_valid(_target):
		stop()
		return
	var goal: float = SILENT_DB
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera and not _screen_open():
		var listener: Vector3 = _ground_focus(camera)
		var offset: Vector3 = _target.global_position - listener
		offset.y = 0.0
		var distance: float = offset.length()
		var radius: float = maxf(MIN_RADIUS, camera.size * RADIUS_PER_SIZE) \
			if camera.projection == Camera3D.PROJECTION_ORTHOGONAL else MIN_RADIUS * 1.5
		var level: float = pow(clampf(1.0 - distance / radius, 0.0, 1.0), 1.6)
		goal = MAX_DB + linear_to_db(maxf(level, 0.001)) if level > 0.0 else SILENT_DB
		goal = maxf(goal, SILENT_DB)
		if _last_distance >= 0.0 and delta > 0.0:
			var radial: float = (distance - _last_distance) / delta   # < 0 yaklaşıyor
			_player.pitch_scale = 1.0 + clampf(-radial * DOPPLER, -DOPPLER_MAX, DOPPLER_MAX)
		_last_distance = distance
	_player.volume_db = move_toward(_player.volume_db, goal, FADE_RATE * delta)


## Kameranın baktığı zemin noktası (y = 0 düzlemi).
static func _ground_focus(camera: Camera3D) -> Vector3:
	var forward: Vector3 = -camera.global_basis.z
	var origin: Vector3 = camera.global_position
	if absf(forward.y) < 0.01:
		return origin
	return origin + forward * (-origin.y / forward.y)


func _screen_open() -> bool:
	var router: UiRouter = get_tree().get_first_node_in_group("ui_router") as UiRouter
	return router != null and router.top() != &""


## Sentezlenmiş siren (döngülü, önbellekli). Önbellekte yoksa BURADA üretilir (masaüstünde 16–28 ms; telefonda
## takılma olur) — PoliceChase bunu polis modeliyle birlikte arka planda build() ile önceden hazırlar.
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


## Saf sentez (önbelleğe dokunmaz): iş parçacığından çağrılabilir.
static func build(kind: Kind) -> AudioStreamWAV:
	return _make_wail() if kind == Kind.WAIL else _make_hi_lo()


## Uluma: 2,4 sn'de 620 → 1.380 → 620 Hz (yükseliş biraz uzun, düşüş hızlı), kare-benzeri tını.
static func _make_wail() -> AudioStreamWAV:
	var period: float = 2.4
	var count: int = int(period * MIX_RATE)
	var freqs: PackedFloat32Array = PackedFloat32Array()
	freqs.resize(count)
	for i: int in count:
		var u: float = float(i) / float(count)
		var rise: float = sin(PI * pow(u, 0.8))   # tepe döngünün ortasından biraz sonra
		freqs[i] = 620.0 + 760.0 * rise
	return _render(freqs, [1.0, 0.0, 0.33, 0.0, 0.16], 0.55)


## İki ton (Alman Martinshorn): la (440 Hz) ve re (587 Hz) dörtlüsü, her biri 0,6 sn; geçişte 15 ms kayma.
static func _make_hi_lo() -> AudioStreamWAV:
	var half: int = int(0.6 * MIX_RATE)
	var glide: int = int(0.015 * MIX_RATE)
	var freqs: PackedFloat32Array = PackedFloat32Array()
	freqs.resize(half * 2)
	for i: int in half * 2:
		var low: bool = i < half
		var k: int = i if low else i - half
		var from: float = 587.0 if low else 440.0
		var to: float = 440.0 if low else 587.0
		freqs[i] = lerpf(from, to, smoothstep(0.0, 1.0, float(k) / float(glide))) if k < glide else to
	return _render(freqs, [1.0, 0.55, 0.38, 0.22, 0.12], 0.5)


## Frekans eğrisinden döngülü dalga: faz birikerek ilerler; toplam faz tam tur sayısına ölçeklenir (dikiş yok).
static func _render(freqs: PackedFloat32Array, harmonics: Array, gain: float) -> AudioStreamWAV:
	var total: float = 0.0
	for f: float in freqs:
		total += f / MIX_RATE
	var scale: float = maxf(roundf(total), 1.0) / total
	var norm: float = 0.0
	for h: float in harmonics:
		norm += h
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(freqs.size() * 2)
	var phase: float = 0.0
	for i: int in freqs.size():
		var sample: float = 0.0
		for n: int in harmonics.size():
			if float(harmonics[n]) > 0.0:
				sample += float(harmonics[n]) * sin(TAU * phase * float(n + 1))
		bytes.encode_s16(i * 2, int(clampf(sample / norm * gain, -1.0, 1.0) * 32767.0))
		phase = fposmod(phase + freqs[i] / MIX_RATE * scale, 1.0)
	var out: AudioStreamWAV = AudioStreamWAV.new()
	out.format = AudioStreamWAV.FORMAT_16_BITS
	out.mix_rate = MIX_RATE
	out.stereo = false
	out.data = bytes
	out.loop_mode = AudioStreamWAV.LOOP_FORWARD
	out.loop_begin = 0
	out.loop_end = freqs.size()
	return out
