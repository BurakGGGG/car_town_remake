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
## DÜŞÜK'te ayrıca: showroom / garaj ekranında gölge yok, trafikte en çok 2 araç.
##
## OTOMATİK KALİTE: oyuncu kaliteyi elle seçmediyse mobilde her açılışta cihaz sınıflanır
## (detect_quality): RAM, çekirdek sayısı ve GPU adı. Zayıf cihaz (ör. Oppo A15: Helio P35, PowerVR GE8320,
## 2–3 GB) DÜŞÜK'te açılır. Elle seçilen kalite (quality_chosen) bir daha değiştirilmez.
##
## MSAA ve PowerVR: GL Compatibility'de PowerVR Rogue (GE8320 vb.) hareket eden modellerde MSAA ile gri /
## delikli çizim üretiyor (godotengine/godot#104351, açık). Bu GPU'da MSAA HİÇBİR görünümde açılmaz;
## SubViewport'lar MSAA'yı subviewport_msaa() üzerinden alır (drag pisti eskiden 2×'te sabitti).
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
## Standart ses düzeyleri: müzik tam, efektler (motor, patlama) müziği bastırmasın diye %60.
const DEFAULT_MUSIC: float = 1.0
const DEFAULT_SFX: float = 0.6
## Ses ayarlarının sürümü. 2: oyuna müzik geldi. Eski dosyalardaki düzeyler hiç ses yokken yazılmış
## varsayılanlardı (kimse bilerek seçmedi): bir kez standarda çekilir.
const AUDIO_VERSION: int = 2
const FPS_SAVER: int = 30
## Düşük kalitede trafikteki en fazla araç (normalde TrafficManager.max_vehicles).
const LOW_TRAFFIC: int = 2
## Bu kadar RAM'in altı DÜŞÜK (bayt); bu kadar ve üstü + güçlü GPU YÜKSEK.
const LOW_RAM: int = 3_500_000_000
const HIGH_RAM: int = 7_500_000_000
## GPU adında geçerse DÜŞÜK (küçük harfle aranır). Eski / giriş seviyesi mobil GPU'lar.
const WEAK_GPUS: PackedStringArray = [
	"powervr", "mali-g31", "mali-g51", "mali-g52", "mali-t", "mali-4", "mali-g57 mc1",
	"adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 50", "adreno (tm) 51", "adreno (tm) 610", "adreno (tm) 612",
]
## GPU adında geçerse (ve RAM yetiyorsa) YÜKSEK.
const STRONG_GPUS: PackedStringArray = [
	"adreno (tm) 7", "adreno (tm) 66", "adreno (tm) 65", "mali-g71", "mali-g72", "mali-g610", "mali-g615",
	"mali-g710", "mali-g715", "mali-g720", "mali-g925", "immortalis", "xclipse", "adreno (tm) 8",
]
## Test: dil değişince sahne yeniden kurulmasın.
var reload_on_language_change: bool = true

var quality: int = Quality.MEDIUM
## Oyuncu kaliteyi AYARLAR'dan seçti mi (seçmediyse mobilde cihaza göre otomatik).
var quality_chosen: bool = false
var battery_saver: bool = false
var music_volume: float = DEFAULT_MUSIC
var sfx_volume: float = DEFAULT_SFX
var muted: bool = false
## Dil: "" = cihaz dili (destekleniyorsa), yoksa Loc.LANGUAGES'tan biri.
var language: String = ""


func _ready() -> void:
	add_to_group("settings")
	_ensure_buses()
	load_settings()
	if not quality_chosen and OS.has_feature("mobile"):
		quality = detect_quality(RenderingServer.get_video_adapter_name(), int(OS.get_memory_info().get("physical", 0)),
			OS.get_processor_count())
	Loc.use(effective_language())
	apply()
	_apply_traffic.call_deferred()   # trafik yöneticisi sahnede bu düğümden sonra hazırlanır


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
	RepairManager.carry_over(get_tree())   # süren tamirler yeni sahnede aynen sürsün
	CAR_HITBOX.set(&"selected_car", null)   # static: eski sahnenin aracını göstermesin
	get_tree().reload_current_scene.call_deferred()


func set_quality(value: int) -> void:
	quality = clampi(value, Quality.LOW, Quality.HIGH)
	quality_chosen = true
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
		root.msaa_3d = QUALITY_MSAA[quality] if msaa_supported() else Viewport.MSAA_DISABLED
		_apply_traffic()
	_active_quality = quality
	Engine.max_fps = FPS_SAVER if battery_saver else FPS_NORMAL
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)
	var master: int = AudioServer.get_bus_index(&"Master")
	if master >= 0:
		AudioServer.set_bus_mute(master, muted)


## Trafikteki araç sayısı: DÜŞÜK'te azalır (her araç ayrı model + hareket = çizim ve CPU).
func _apply_traffic() -> void:
	for node: Node in get_tree().get_nodes_in_group("traffic"):
		if not node.has_meta(&"default_max_vehicles"):
			node.set_meta(&"default_max_vehicles", int(node.get("max_vehicles")))
		var normal: int = int(node.get_meta(&"default_max_vehicles"))
		node.set("max_vehicles", mini(LOW_TRAFFIC, normal) if quality == Quality.LOW else normal)


# --- Cihaz sınıfı / görünüm kararları ---------------------------------------------------

## Uygulanan son kalite (SubViewport'lar ve ışıklar sahne kurulurken buna bakar).
static var _active_quality: int = Quality.MEDIUM


## Cihazı sınıflar. Saf: testler sahte değerlerle çağırır.
static func detect_quality(adapter: String, ram_bytes: int, cores: int) -> int:
	var gpu: String = adapter.to_lower()
	if ram_bytes > 0 and ram_bytes < LOW_RAM:
		return Quality.LOW
	if cores > 0 and cores <= 4:
		return Quality.LOW
	for weak: String in WEAK_GPUS:
		if gpu.contains(weak):
			return Quality.LOW
	if ram_bytes >= HIGH_RAM:
		for strong: String in STRONG_GPUS:
			if gpu.contains(strong):
				return Quality.HIGH
	return Quality.MEDIUM


## Bu GPU'da MSAA güvenli mi? PowerVR Rogue'da Compatibility + MSAA hareketli modelleri bozuyor (#104351).
static func msaa_supported(adapter: String = "", vendor: String = "") -> bool:
	var name: String = (adapter if adapter != "" else RenderingServer.get_video_adapter_name()).to_lower()
	var maker: String = (vendor if vendor != "" else RenderingServer.get_video_adapter_vendor()).to_lower()
	return not (name.contains("powervr") or maker.contains("imagination"))


## SubViewport'un MSAA'sı: istenen değer, ama DÜŞÜK kalitede ya da MSAA'nın bozuk olduğu GPU'da kapalı.
static func subviewport_msaa(preferred: Viewport.MSAA) -> Viewport.MSAA:
	if _active_quality == Quality.LOW or not msaa_supported():
		return Viewport.MSAA_DISABLED
	return preferred


## Gölge açılsın mı (showroom / garaj ekranı ışıkları)? DÜŞÜK'te kapalı.
static func shadows_enabled() -> bool:
	return _active_quality != Quality.LOW


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
	cfg.set_value("graphics", "quality_chosen", quality_chosen)
	cfg.set_value("graphics", "battery_saver", battery_saver)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "version", AUDIO_VERSION)
	cfg.set_value("general", "language", language)
	cfg.save(PATH)


## Dosya yoksa / bozuksa varsayılanlar kalır.
func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	quality = clampi(int(cfg.get_value("graphics", "quality", Quality.MEDIUM)), Quality.LOW, Quality.HIGH)
	# Eski dosyada işaret yoktur: ORTA dışında bir değer varsa oyuncu onu seçmişti (varsayılan ORTA'ydı)
	quality_chosen = bool(cfg.get_value("graphics", "quality_chosen", quality != Quality.MEDIUM))
	battery_saver = bool(cfg.get_value("graphics", "battery_saver", false))
	if int(cfg.get_value("audio", "version", 1)) >= AUDIO_VERSION:
		music_volume = clampf(float(cfg.get_value("audio", "music", DEFAULT_MUSIC)), 0.0, 1.0)
		sfx_volume = clampf(float(cfg.get_value("audio", "sfx", DEFAULT_SFX)), 0.0, 1.0)
	else:
		music_volume = DEFAULT_MUSIC
		sfx_volume = DEFAULT_SFX
	muted = bool(cfg.get_value("audio", "muted", false))
	language = String(cfg.get_value("general", "language", ""))
