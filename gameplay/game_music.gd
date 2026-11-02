class_name GameMusic
extends AudioStreamPlayer
## ARKA PLAN MÜZİĞİ: garaj teması, drag yarışı teması ve hurdalık teması (tools/music/*.py ile bestelenip basılır;
## .import'ta ileri döngü). "Music" bus'ında çalar: ayarlardaki müzik düzeyi ve sessiz seçeneği uygulanır.
##
## Sahnenin DEĞİL kökün çocuğudur (ensure): dil değişiminde sahne yeniden kurulurken, arkadaş garajı
## ziyaretinde kendi sahne ağaçtan çıkarılırken müzik kesilip baştan başlamaz.
## Drag yarışı açılınca garaj teması kısılıp DURAKLAR, yarış teması yükselir; yarış kapanınca garaj
## teması kaldığı yerden geri gelir (race). Hurdalık da aynı yolla kendi temasına geçer (junkyard).
## DİNAMOMETRE açıkken garaj teması DYNO_DB'ye kısılır (dyno; kullanıcı: "dyno da oyun müziğini kıs motor sesini aç").
## Kedinin YAKIN KAMERASINDA PET_DB'ye iner (pet_closeup): mırlama müziğin altında kayboluyordu (2026-11-02 kaydı).
## JAPON DRIFT GÖSTERİSİ (DriftEvent, drift): garaj teması kısılıp DURAKLAR, drift teması (Eurobeat, TEK SEFERLİK: döngü
## yok) baştan başlar; kendi sonunda (ya da drift(false) ile) garaj teması kaldığı yerden geri gelir. Yarış / hurdalık
## teması başlarsa drift teması hemen kesilir; onlar çalarken drift teması başlamaz.

const THEME: String = "res://assets/audio/music/garage_theme.wav"
const RACE_THEME: String = "res://assets/audio/music/drag_theme.wav"
const JUNKYARD_THEME: String = "res://assets/audio/music/junkyard_theme.wav"
const DRIFT_THEME: String = "res://assets/audio/music/drift_theme.wav"
const NODE_NAME: String = "GameMusic"
const BASE_DB: float = -4.0
## Yarış teması motor seslerinin altında kalsın (motorlar SFX bus'ında).
const RACE_DB: float = -9.0
const JUNKYARD_DB: float = -5.0
## Drift teması: nakarat garaj temasından ~2 dB yüksek (tools/music/drift_theme.py ölçümü); giriş kısık başlar.
const DRIFT_DB: float = -4.0
## Drift teması kesilirken / bitince garaj temasının geri gelişi (sn).
const DRIFT_OUT: float = 0.6
const DRIFT_RETURN: float = 2.2
## Drift temasının sonundaki yankı kuyruğu (son akor 15,5 sn, koto / taiko 17 sn) sönerken garaj teması bu konumdan
## itibaren geri gelir: dosya bitene kadar ~2 sn sessizlik kalıyordu (kayıtta ölçüldü).
const DRIFT_HANDBACK: float = 18.0
## Dino atölyesinde garaj teması (motor sesinin ~15 dB altında, arkada hafifçe duyulur).
const DYNO_DB: float = -19.0
## Kedi yakın kamerası: müzik ~6 dB geri çekilir, mırlama / miyav öne çıkar (müzik yine duyulur).
const PET_DB: float = -10.0
const SILENT_DB: float = -40.0
const FADE_IN: float = 2.5
const SWAP_TIME: float = 0.8

var _race: AudioStreamPlayer
var _yard: AudioStreamPlayer
var _drift: AudioStreamPlayer
var _drift_session: int = 0
var _tween: Tween


## Müzik yoksa kurar (ertelenmiş: sahne kurulurken köke çocuk eklenemez). Varsa dokunmaz.
static func ensure(tree: SceneTree) -> void:
	if tree == null or tree.root.has_node(NODE_NAME) or not ResourceLoader.exists(THEME):
		return
	var music: GameMusic = GameMusic.new()
	music.name = NODE_NAME
	tree.root.add_child.call_deferred(music)


## Drag yarışı ekranı açıldı (true) / kapandı (false).
static func race(tree: SceneTree, on: bool) -> void:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	if music:
		music._set_race(on)


## Hurdalık ekranı açıldı (true) / kapandı (false).
static func junkyard(tree: SceneTree, on: bool) -> void:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	if music:
		music._swap(music._yard, on, JUNKYARD_DB)


## DİNAMOMETRE açıldı (true) / kapandı (false): garaj teması kısılır / geri gelir (yer teması çalarken dokunmaz).
static func dyno(tree: SceneTree, on: bool) -> void:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	if music:
		music._duck(DYNO_DB if on else BASE_DB)


## Drift gösterisi başladı (true): drift teması baştan çalar; false: kesilir, garaj teması döner. Başladıysa true
## (müzik yoksa / yarış ya da hurdalık teması çalıyorsa false).
static func drift(tree: SceneTree, on: bool) -> bool:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	return music._set_drift(on) if music else false


## Drift temasının çalma konumu (sn; gösteri saati buna bağlanır), çalmıyorsa -1.
static func drift_position(tree: SceneTree) -> float:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	if music == null or not music._drift.playing:
		return -1.0
	return music._drift.get_playback_position() + AudioServer.get_time_since_last_mix()


## Kedinin yakın kamerası açıldı (true) / kapandı (false): garaj teması PET_DB'ye iner / geri gelir.
static func pet_closeup(tree: SceneTree, on: bool) -> void:
	var music: GameMusic = tree.root.get_node_or_null(NODE_NAME) as GameMusic if tree else null
	if music:
		music._duck(PET_DB if on else BASE_DB)


func _ready() -> void:
	bus = GameSettings.MUSIC_BUS
	stream = load(THEME) as AudioStream
	volume_db = SILENT_DB
	play()
	_race = AudioStreamPlayer.new()
	_race.name = "RaceTheme"
	_race.bus = GameSettings.MUSIC_BUS
	_race.volume_db = SILENT_DB
	if ResourceLoader.exists(RACE_THEME):
		_race.stream = load(RACE_THEME) as AudioStream
	add_child(_race)
	_yard = AudioStreamPlayer.new()
	_yard.name = "JunkyardTheme"
	_yard.bus = GameSettings.MUSIC_BUS
	_yard.volume_db = SILENT_DB
	if ResourceLoader.exists(JUNKYARD_THEME):
		_yard.stream = load(JUNKYARD_THEME) as AudioStream
	add_child(_yard)
	_drift = AudioStreamPlayer.new()
	_drift.name = "DriftTheme"
	_drift.bus = GameSettings.MUSIC_BUS
	_drift.volume_db = DRIFT_DB
	if ResourceLoader.exists(DRIFT_THEME):
		_drift.stream = load(DRIFT_THEME) as AudioStream
	_drift.finished.connect(_on_drift_finished)
	add_child(_drift)
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", BASE_DB, FADE_IN).set_trans(Tween.TRANS_SINE)


## Yarışta mı çalıyor (yarış teması duyulur durumda)?
func is_racing() -> bool:
	return _race.playing


## Drift teması çalıyor mu?
func is_drifting() -> bool:
	return _drift.playing


## Garaj temasını db'ye yumuşakça indirir / çıkarır (yer teması / drift teması çalarken dokunmaz).
func _duck(db: float) -> void:
	if _race.playing or _yard.playing or _drift.playing:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", db, SWAP_TIME).set_trans(Tween.TRANS_SINE)


func _set_race(on: bool) -> void:
	_swap(_race, on, RACE_DB)


## Garaj temasıyla bir yer teması arasında geçiş: tema baştan başlar (yarışta giriş riff'i geri sayımla),
## garaj teması kısılıp DURAKLAR ve dönüşte kaldığı yerden gelir.
func _swap(player: AudioStreamPlayer, on: bool, db: float) -> void:
	if player == null or player.stream == null or on == player.playing:
		return
	if on and _drift.playing:
		_drift.stop()   # drift gösterisi sırasında yarış / hurdalık açıldı: drift teması hemen susar
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if on:
		player.volume_db = SILENT_DB
		player.play()
		_tween.tween_property(player, "volume_db", db, SWAP_TIME * 0.5)
		_tween.tween_property(self, "volume_db", SILENT_DB, SWAP_TIME).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_callback(func() -> void: stream_paused = true)
	else:
		stream_paused = false
		_tween.tween_property(player, "volume_db", SILENT_DB, SWAP_TIME).set_trans(Tween.TRANS_SINE)
		_tween.tween_property(self, "volume_db", BASE_DB, SWAP_TIME * 1.5).set_trans(Tween.TRANS_SINE)
		_tween.chain().tween_callback(player.stop)


## Drift teması başlar (garaj teması hızla kısılıp duraklar) ya da kesilir (garaj teması kaldığı yerden döner).
func _set_drift(on: bool) -> bool:
	if _drift.stream == null:
		return false
	if on:
		if _race.playing or _yard.playing:
			return false
		if _tween:
			_tween.kill()
		_drift.volume_db = DRIFT_DB
		_drift.play()
		_drift_session += 1
		var session: int = _drift_session
		get_tree().create_timer(DRIFT_HANDBACK).timeout.connect(func() -> void:
			if _drift.playing and session == _drift_session:
				_on_drift_finished())
		_tween = create_tween()
		_tween.tween_property(self, "volume_db", SILENT_DB, SWAP_TIME * 0.6).set_trans(Tween.TRANS_SINE)
		_tween.tween_callback(func() -> void: stream_paused = true)
		return true
	if not _drift.playing:
		return false
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(_drift, "volume_db", SILENT_DB, DRIFT_OUT).set_trans(Tween.TRANS_SINE)
	_resume_garage(_tween)
	_tween.chain().tween_callback(_drift.stop)
	return true


## Drift teması sonuna geldi (kuyruğu sönüyor ya da dosya bitti): garaj teması geri gelir (bir kez).
func _on_drift_finished() -> void:
	if _race.playing or _yard.playing or not stream_paused:
		return
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_resume_garage(_tween)


## Garaj teması kaldığı yerden çalar ve BASE_DB'ye yükselir (yer teması çalıyorsa dokunmaz).
func _resume_garage(tween: Tween) -> void:
	if _race.playing or _yard.playing:
		return
	stream_paused = false
	tween.tween_property(self, "volume_db", BASE_DB, DRIFT_RETURN).set_trans(Tween.TRANS_SINE)
