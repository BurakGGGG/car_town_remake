class_name PetVoice
extends Node
## KEDİ SESİ (2026-11-02, kullanıcı: "kedinin halen bir sesi yok, kedi sesi yapalım. sadece yakından bakarken sesi
## olsun, sevince falan"). Gerçek kayıtlar — 2026-10-31 kararı: CC0 / ücretsiz lisanslı, kod sentezi değil. Kaynaklar
## assets/audio/pets/KAYNAKLAR.txt (Freesound, CC0), kesim / düzey / döngü tools/pets/kedi_sesleri.py.
##
## YALNIZ YAKIN KAMERADA çalar: PetCloseupScreen kurar, açılışta begin(), kapanışta end() çağırır. Garajda dolaşan
## kedi sessizdir.
##   greet()   — kedi oturup kameraya bakınca selam miyavı (gelişte de)
##   petted()  — sevilince mırlama: yumuşak girer, son dokunuştan PURR_HOLD sn sonra söner, her dokunuş uzatır.
##               Oturumdaki ilk sevmede kesin, sonra ara sıra "mrrp" (trill)
##   happy()   — numara yapınca / aksesuar alınca / ad konunca sevinç miyavı
##   hunt(start) — olta: kedi tüye cıvıldar (av sesi); oltaya geçince mırlama hızla söner
## Tek ağız: bir ses sürerken gelen yenisi atlanır (kedi üst üste konuşmaz); kümede aynı kayıt arka arkaya çıkmaz,
## perde ±%4 oynar. Efekt (SFX) bus'ı.

const DIR: String = "res://assets/audio/pets/"
const POOLS: Dictionary = {
	&"hello": [&"hello_1", &"hello_2", &"hello_3"],
	&"happy": [&"happy_1", &"happy_2", &"happy_3"],
	&"trill": [&"trill_1", &"trill_2", &"trill_3"],
	&"chirp": [&"chirp_1", &"chirp_2", &"chirp_3", &"chirp_4"],
}
const VOICE_DB: float = -5.0
const PURR_DB: float = -2.0
## Mırlama zarfı (sn): sessizden tam düzeye, tam düzeyden sessize, son dokunuştan sonra sürme.
const PURR_IN: float = 0.6
const PURR_OUT: float = 1.8
const PURR_OUT_FAST: float = 0.35
const PURR_HOLD: float = 4.5
## Sevilirken "mrrp": ilk sevmeden sonra bu olasılıkla, en az TRILL_GAP sn arayla.
const TRILL_CHANCE: float = 0.3
const TRILL_GAP: float = 3.5
## Olta: oltaya geçince / atlayınca cıvıldama olasılığı.
const HUNT_START_CHANCE: float = 0.75
const HUNT_POUNCE_CHANCE: float = 0.5
## İki ses arası en az boşluk (sn, bir önceki sesin bitişinden).
const GAP: float = 0.25

var _voice: AudioStreamPlayer
var _purr: AudioStreamPlayer
var _streams: Dictionary = {}          # kayıt adı → AudioStream
var _last: Dictionary = {}             # küme → son çalınan kayıt adı
var _gen: int = 0                      # end() artırır: bekleyen gecikmeli sesler düşer
var _active: bool = false
var _busy_until: float = 0.0           # sn (_clock), bu ana kadar ağız dolu
var _clock: float = 0.0
var _last_clip: StringName = &""
var _petted_once: bool = false
var _last_trill: float = -100.0
var _purr_level: float = 0.0           # 0..1 doğrusal genlik
var _purr_hold: float = 0.0
var _purr_out: float = PURR_OUT


func _ready() -> void:
	name = "PetVoice"
	_voice = AudioStreamPlayer.new()
	_voice.bus = GameSettings.SFX_BUS
	_voice.volume_db = VOICE_DB
	add_child(_voice)
	_purr = AudioStreamPlayer.new()
	_purr.bus = GameSettings.SFX_BUS
	add_child(_purr)
	set_process(false)


## Yakın kamera açıldı: sesler serbest, oturum sayaçları sıfırlanır.
func begin() -> void:
	_gen += 1
	_active = true
	_petted_once = false
	_last_trill = -100.0
	set_process(true)


## Yakın kamera kapanıyor: konuşma kesilir, mırlama hızla söner; bekleyen gecikmeli sesler düşer.
func end() -> void:
	_gen += 1
	_active = false
	_voice.stop()
	_busy_until = 0.0
	_purr_hold = 0.0
	_purr_out = PURR_OUT_FAST


func greet(delay: float = 0.0) -> void:
	say(&"hello", delay)


func happy(delay: float = 0.0) -> void:
	say(&"happy", delay)


func petted() -> void:
	if not _active:
		return
	_purr_hold = PURR_HOLD
	_purr_out = PURR_OUT
	if not _purr.playing:
		if _purr.stream == null:
			_purr.stream = _stream(&"purr")
		_purr_level = 0.0
		_purr.volume_db = linear_to_db(0.001)
		# her seferinde döngünün başka yerinden: hep aynı nefesle başlamasın
		var length: float = _purr.stream.get_length() if _purr.stream else 0.0
		_purr.play(randf() * length * 0.9)
	var first: bool = not _petted_once
	_petted_once = true
	if first or (_clock - _last_trill >= TRILL_GAP and randf() < TRILL_CHANCE):
		if say(&"trill", 0.0 if first else 0.15):
			_last_trill = _clock


## Olta: start = oltaya geçildi (yoksa tüye atladı / pati vurdu).
func hunt(start: bool) -> void:
	if not _active:
		return
	if start:
		_purr_hold = 0.0
		_purr_out = PURR_OUT_FAST
	if randf() < (HUNT_START_CHANCE if start else HUNT_POUNCE_CHANCE):
		say(&"chirp", 0.35 if start else 0.0)


## Kümeden bir kayıt çalar (delay sn sonra). Ağız doluysa ya da yakın kamera kapandıysa çalmaz; çaldıysa true
## (gecikmeli istekte istek kabul edildiyse true).
func say(kind: StringName, delay: float = 0.0) -> bool:
	if not _active or not POOLS.has(kind) or _clock < _busy_until:
		return false
	if delay > 0.0:
		_busy_until = _clock + delay   # sıradaki ses için ağzı ayır
		_say_later(kind, delay, _gen)
		return true
	var pool: Array = POOLS[kind]
	var pick: StringName = pool[randi() % pool.size()]
	if pool.size() > 1 and pick == _last.get(kind, &""):
		pick = pool[(pool.find(pick) + 1 + randi() % (pool.size() - 1)) % pool.size()]
	var stream: AudioStream = _stream(pick)
	if stream == null:
		return false
	_last[kind] = pick
	_last_clip = pick
	_voice.stream = stream
	_voice.pitch_scale = randf_range(0.96, 1.04)
	_voice.play()
	_busy_until = _clock + stream.get_length() / _voice.pitch_scale + GAP
	return true


func _say_later(kind: StringName, delay: float, gen: int) -> void:
	await get_tree().create_timer(delay).timeout
	if gen != _gen or not is_inside_tree():
		return
	_busy_until = 0.0
	say(kind)


func _process(delta: float) -> void:
	_clock += delta
	if _purr_hold > 0.0:
		_purr_hold -= delta
		_purr_level = minf(_purr_level + delta / PURR_IN, 1.0)
	else:
		_purr_level = maxf(_purr_level - delta / _purr_out, 0.0)
	if _purr.playing:
		if _purr_level <= 0.0:
			_purr.stop()
		else:
			_purr.volume_db = PURR_DB + linear_to_db(_purr_level)
	if not _active and _purr_level <= 0.0:
		set_process(false)


func _stream(clip: StringName) -> AudioStream:
	if not _streams.has(clip):
		_streams[clip] = load(DIR + String(clip) + ".wav") as AudioStream
	return _streams[clip]


# --- Test / QA ----------------------------------------------------------------------------------

func active() -> bool:
	return _active


func last_clip() -> StringName:
	return _last_clip


func purr_level() -> float:
	return _purr_level


func purring() -> bool:
	return _purr_hold > 0.0 or _purr_level > 0.0
