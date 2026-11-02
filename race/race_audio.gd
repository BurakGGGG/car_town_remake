class_name RaceAudio
extends Node
## DRAG YARIŞI SESLERİ.
##
## MOTORLAR (2026-11-02, kullanıcı: "sesler çok yapay ve neredeyse hepsi birbirinin aynısı"): her aracın KENDİ pişmiş
## motor sesi (EngineBank, MOTOR SES LABORATUVARI'nda tasarlanır — tools/engine_lab) EngineVoice ile çalar: devir
## katmanları arası geçiş, gaz açık / kesik, turbo ıslığı + blow-off, devir kesici, egzoz patlamaları. Eskiden üç
## "karakter" döngüsünün perdesi oynatılıyordu.
## Devir eşlemesi: yarış fiziğinin devri (spec.idle_rpm–redline_rpm) aracın ses bankasının rölanti–kırmızı aralığına
## oranla taşınır (fizik ve ses ayrı ayarlanır; kırmızı çizgi her zaman sesin kırmızısında duyulur).
## Gaz: geri sayımda yarım (kalkış devrinde bekler), yarışta tam, vites geçişinde ve çizgiden sonra kesik (kesince
## bankanın patlama / blow-off'u kendiliğinden gelir; vites patlaması backfire() ile alevle eş zamanlı).
## Düzey (2026-11-02, kullanıcı: "araç sesleri dragta da çok kısık"): motorlar yüksek motor sesi bus'ında
## (EngineVoice.loud_bus: sert sınırlayıcı → SFX) 0 dB'nin üstünde çalar, katman farklarının DYNAMICS payı çalınır
## (orta devir de dolgun); tam gaz / patlama kırpılmaz. Eskiden −6 / −15 dB doğrudan SFX'teydi.
## Tek seferlikler: geri sayım bipi, GO bipi. Yalnızca SES üretir; yarış mantığını bilmez. DragRaceScreen her kare
## drive() ile besler.

const MIX_RATE: int = 22050
const PLAYER_DB: float = 4.0
const RIVAL_DB: float = -5.0
const DYNAMICS: float = 0.75
## Geri sayımda (kalkış devrinde beklerken) gaz.
const STAGED_THROTTLE: float = 0.55

static var _beep_stream: AudioStreamWAV
static var _go_stream: AudioStreamWAV
static var _pop_stream: AudioStreamWAV

var _player_engine: AudioStreamPlayer
var _rival_engine: AudioStreamPlayer
var _player_voice: EngineVoice
var _rival_voice: EngineVoice
var _oneshot: AudioStreamPlayer
var _fading: bool = false


func _ready() -> void:
	name = "RaceAudio"
	_ensure_streams()
	_player_engine = _player()
	_rival_engine = _player()
	_player_engine.bus = EngineVoice.loud_bus()
	_rival_engine.bus = EngineVoice.loud_bus()
	_oneshot = _player()


func _player() -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = GameSettings.SFX_BUS
	add_child(player)
	return player


## Yarışan iki aracın motor sesleri.
func set_vehicles(player_id: StringName, rival_id: StringName) -> void:
	_player_voice = _voice(_player_engine, player_id, _player_voice)
	_rival_voice = _voice(_rival_engine, rival_id, _rival_voice)


static func _voice(target: AudioStreamPlayer, id: StringName, previous: EngineVoice) -> EngineVoice:
	var bank: EngineBank = bank_for(id)
	if previous:
		previous.set_bank(bank)
		return previous
	var voice: EngineVoice = EngineVoice.new(target, bank)
	voice.dynamics = DYNAMICS
	return voice


## Aracın pişmiş bankası; yoksa (yeni araç pişirilmemiş) ön ayardan bellekte üretilir (yavaş, uyarı verir).
static func bank_for(id: StringName) -> EngineBank:
	var bank: EngineBank = EngineBank.for_vehicle(id)
	if bank == null:
		push_warning("RaceAudio: '%s' için pişmiş motor sesi yok (tools/engine_lab ile PİŞİR) — bellekte üretiliyor" % id)
		bank = EngineBank.build(id, EnginePreset.for_vehicle(id), false)
	return bank


## Vites patlaması örneği (tek seferlik; motor bankası olmayan yerler için genel patlama).
static func pop_stream() -> AudioStreamWAV:
	_ensure_streams()
	return _pop_stream


## Motorlar rölantide çalışmaya başlar (geri sayımda devir yükselir).
func start() -> void:
	_fading = false
	_player_engine.volume_db = PLAYER_DB
	_rival_engine.volume_db = RIVAL_DB
	for voice: EngineVoice in [_player_voice, _rival_voice]:
		if voice:
			voice.running = true


## Yarış bitti: motorlar kısa sürede susar (sonuç panosu sessiz).
func fade_out() -> void:
	_fading = true


func stop() -> void:
	_fading = false
	for voice: EngineVoice in [_player_voice, _rival_voice]:
		if voice:
			voice.stop_all()
	for player: AudioStreamPlayer in [_player_engine, _rival_engine, _oneshot]:
		player.stop()


## Her kare: motor devri → bankanın devri, durum → gaz.
func drive(delta: float, player: DragRaceSim.Runner, rival: DragRaceSim.Runner) -> void:
	if _fading:
		for engine: AudioStreamPlayer in [_player_engine, _rival_engine]:
			engine.volume_db = move_toward(engine.volume_db, -60.0, delta * 50.0)
			if engine.volume_db <= -59.0 and engine.playing:
				engine.stop()
		if _player_engine.playing:
			_drive_voice(delta, _player_voice, player)
		if _rival_engine.playing:
			_drive_voice(delta, _rival_voice, rival)
		return
	_drive_voice(delta, _player_voice, player)
	_drive_voice(delta, _rival_voice, rival)


func _drive_voice(delta: float, voice: EngineVoice, runner: DragRaceSim.Runner) -> void:
	if voice == null or runner == null or voice.bank == null:
		return
	voice.update(delta, sound_rpm(voice.bank, runner), throttle_of(runner), runner.limiter and not runner.shifting)


## Fizik devri → ses bankasının devri (rölanti–kırmızı aralığında oranla).
static func sound_rpm(bank: EngineBank, runner: DragRaceSim.Runner) -> float:
	var span: float = maxf(runner.spec.redline_rpm - runner.spec.idle_rpm, 1.0)
	var x: float = (runner.rpm - runner.spec.idle_rpm) / span
	var low: float = maxf(bank.idle_rpm(), 600.0) if not bank.is_electric() else 400.0
	return low + x * (bank.redline_rpm() - low)


static func throttle_of(runner: DragRaceSim.Runner) -> float:
	if runner.finish_time >= 0.0 or runner.shifting:
		return 0.0
	return 1.0 if runner.running else STAGED_THROTTLE


func countdown_beep() -> void:
	_oneshot.stream = _beep_stream
	_oneshot.volume_db = -8.0
	_oneshot.play()


func go_beep() -> void:
	_oneshot.stream = _go_stream
	_oneshot.volume_db = -6.0
	_oneshot.play()


## Vites patlaması: `strength` 0-1 (kusursuz vites en gürü); aracın kendi egzoz patlaması.
func backfire(strength: float, rival: bool = false) -> void:
	var voice: EngineVoice = _rival_voice if rival else _player_voice
	if voice:
		voice.pop(clampf(strength, 0.15, 1.0))


## Oyuncunun / rakibin motor sesi (test / QA).
func player_voice() -> EngineVoice:
	return _player_voice


func rival_voice() -> EngineVoice:
	return _rival_voice


# --- Ses üretimi (bir kez) -------------------------------------------------------------

static func _ensure_streams() -> void:
	if _beep_stream:
		return
	_beep_stream = _make_tone(660.0, 0.14)
	_go_stream = _make_tone(990.0, 0.38)
	_pop_stream = _make_pop()


static func _make_tone(hz: float, seconds: float) -> AudioStreamWAV:
	var count: int = int(seconds * float(MIX_RATE))
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(count)
	for i: int in count:
		var t: float = float(i) / float(MIX_RATE)
		var envelope: float = minf(t / 0.008, 1.0) * clampf((seconds - t) / 0.06, 0.0, 1.0)
		samples[i] = envelope * (sin(TAU * hz * t) * 0.8 + sin(TAU * hz * 2.0 * t) * 0.2)
	return _wav(samples, 0.6)


## Genel patlama: kısa gürültü patlaması + alçak "güm".
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
	return _wav(samples, 0.9)


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
