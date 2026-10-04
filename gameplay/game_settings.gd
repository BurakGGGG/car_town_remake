class_name GameSettings
extends Node
## OYUN AYARLARI — grafik, performans ve ses. CİHAZA özeldir: oyun kaydına / buluta yazılmaz
## (başka telefonda farklı kalite istenebilir), user://settings.cfg (ConfigFile) dosyasında durur.
## "settings" grubundan bulunur (GarageSystem kodla kurar). Ayar değişince hemen uygulanır ve yazılır.
##
## Grafik kalitesi (yalnızca ana 3B görünüm; GL Compatibility'de çalışan iki kaldıraç):
##   DÜŞÜK  — 3B çözünürlük %70, kenar yumuşatma yok   (zayıf telefon / ısınma)
##   ORTA   — 3B çözünürlük %100, kenar yumuşatma yok  (eski varsayılan görünüm)
##   YÜKSEK — 3B çözünürlük %100, MSAA 2×
## Pil tasarrufu: kare hızı 60 → 30.
## Ses: Müzik ve Efekt bus'ları kodla kurulur (Master'a bağlı); oyunda henüz ses varlığı yok, düzeyler
## hazır durur ve ses eklendiğinde AudioStreamPlayer'lar bu bus'lara verilir.

signal settings_changed

enum Quality { LOW, MEDIUM, HIGH }

const PATH: String = "user://settings.cfg"
const CAR_HITBOX: GDScript = preload("res://car_hitbox.gd")
const MUSIC_BUS: StringName = &"Music"
const SFX_BUS: StringName = &"SFX"
const QUALITY_SCALE: Array[float] = [0.7, 1.0, 1.0]
const QUALITY_MSAA: Array[int] = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X]
const QUALITY_NAMES: Array[String] = ["DÜŞÜK", "ORTA", "YÜKSEK"]
const FPS_NORMAL: int = 60
const FPS_SAVER: int = 30
## Test: dil değişince sahne yeniden kurulmasın.
var reload_on_language_change: bool = true

var quality: int = Quality.MEDIUM
var battery_saver: bool = false
var music_volume: float = 0.8
var sfx_volume: float = 1.0
var muted: bool = false
## Dil: "" = cihaz dili (destekleniyorsa), yoksa Loc.LANGUAGES'tan biri.
var language: String = ""


func _ready() -> void:
	add_to_group("settings")
	_ensure_buses()
	load_settings()
	Loc.use(effective_language())
	apply()


## Kullanılan dil: seçilmişse o, seçilmemişse cihaz dili.
func effective_language() -> String:
	return language if Loc.LANGUAGES.has(language) else Loc.device_language()


## Dili değiştirir: ayar yazılır, oyun kaydedilir ve dünya yeni dille YENİDEN KURULUR (açık ekranlar,
## HUD, kataloglardan gelen metinler hepsi baştan çevrilir; ekran ekran canlı güncelleme yerine tek yol).
func set_language(value: String) -> void:
	if not Loc.LANGUAGES.has(value) or value == effective_language() and language == value:
		return
	language = value
	save_settings()
	Loc.use(value)
	settings_changed.emit()
	if not reload_on_language_change or not is_inside_tree():
		return
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"save_game"):
		save.call(&"save_game")
	CAR_HITBOX.set(&"selected_car", null)   # static: eski sahnenin aracını göstermesin
	get_tree().reload_current_scene.call_deferred()


func set_quality(value: int) -> void:
	quality = clampi(value, Quality.LOW, Quality.HIGH)
	_changed()


func set_battery_saver(value: bool) -> void:
	battery_saver = value
	_changed()


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_changed()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_changed()


func set_muted(value: bool) -> void:
	muted = value
	_changed()


## Ayarları oyuna uygular (çağrılması güvenli, tekrar edilebilir).
func apply() -> void:
	if is_inside_tree():
		var root: Viewport = get_tree().root
		root.scaling_3d_scale = QUALITY_SCALE[quality]
		root.msaa_3d = QUALITY_MSAA[quality]
	Engine.max_fps = FPS_SAVER if battery_saver else FPS_NORMAL
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)
	var master: int = AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)


func _changed() -> void:
	apply()
	save_settings()
	settings_changed.emit()


func _ensure_buses() -> void:
	for bus: StringName in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")


static func _set_bus(bus: StringName, volume: float) -> void:
	var index: int = AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, volume <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.001)))


func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("graphics", "quality", quality)
	cfg.set_value("graphics", "battery_saver", battery_saver)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("general", "language", language)
	cfg.save(PATH)


## Dosya yoksa / bozuksa varsayılanlar kalır.
func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", Quality.MEDIUM)), Quality.LOW, Quality.HIGH)
	battery_saver = bool(cfg.get_value("graphics", "battery_saver", false))
	music_volume = clampf(float(cfg.get_value("audio", "music", 0.8)), 0.0, 1.0)
	sfx_volume = clampf(float(cfg.get_value("audio", "sfx", 1.0)), 0.0, 1.0)
	muted = bool(cfg.get_value("audio", "muted", false))
	language = String(cfg.get_value("general", "language", ""))
