class_name GameMusic
extends AudioStreamPlayer
## ARKA PLAN MÜZİĞİ: garaj teması, drag yarışı teması ve hurdalık teması (tools/music/*.py ile bestelenip basılır;
## .import'ta ileri döngü). "Music" bus'ında çalar: ayarlardaki müzik düzeyi ve sessiz seçeneği uygulanır.
##
## Sahnenin DEĞİL kökün çocuğudur (ensure): dil değişiminde sahne yeniden kurulurken, arkadaş garajı
## ziyaretinde kendi sahne ağaçtan çıkarılırken müzik kesilip baştan başlamaz.
## Drag yarışı açılınca garaj teması kısılıp DURAKLAR, yarış teması yükselir; yarış kapanınca garaj
## teması kaldığı yerden geri gelir (race). Hurdalık da aynı yolla kendi temasına geçer (junkyard).

const THEME: String = "res://assets/audio/music/garage_theme.wav"
const RACE_THEME: String = "res://assets/audio/music/drag_theme.wav"
const JUNKYARD_THEME: String = "res://assets/audio/music/junkyard_theme.wav"
const NODE_NAME: String = "GameMusic"
const BASE_DB: float = -4.0
## Yarış teması motor seslerinin altında kalsın (motorlar SFX bus'ında).
const RACE_DB: float = -9.0
const JUNKYARD_DB: float = -5.0
const SILENT_DB: float = -40.0
const FADE_IN: float = 2.5
const SWAP_TIME: float = 0.8

var _race: AudioStreamPlayer
var _yard: AudioStreamPlayer
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
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", BASE_DB, FADE_IN).set_trans(Tween.TRANS_SINE)


## Yarışta mı çalıyor (yarış teması duyulur durumda)?
func is_racing() -> bool:
	return _race.playing


func _set_race(on: bool) -> void:
	_swap(_race, on, RACE_DB)


## Garaj temasıyla bir yer teması arasında geçiş: tema baştan başlar (yarışta giriş riff'i geri sayımla),
## garaj teması kısılıp DURAKLAR ve dönüşte kaldığı yerden gelir.
func _swap(player: AudioStreamPlayer, on: bool, db: float) -> void:
	if player == null or player.stream == null or on == player.playing:
		return
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
