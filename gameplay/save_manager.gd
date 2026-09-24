class_name SaveManager
extends Node
## Oyuncunun kalıcı ilerlemesi: para, XP / seviye / gem, garaj geliştirme seviyeleri,
## sahip olunan araçlar ve boyaları, görevler.
## Sahnede World/Gameplay/SaveManager olarak durur; arayanlar "save_manager" grubundan bulur
## (autoload yok — proje kuralı).
##
## KENDİ VERİSİNİ TUTMAZ: her şeyi mevcut manager'ların public API'sinden okur ve onlara yazar
## (EconomyManager.money / set_money / reset, PlayerProgress.load_state / reset,
## GarageUpgradeManager.levels / apply_levels / reset, VehicleOwnership.owned_vehicle_ids /
## load_state / paint_state / load_paint / reset, QuestManager.state / load_state / reset).
## Paralel bir ekonomi / XP / upgrade / araç / görev sistemi yoktur.
##
## Kaydedilmeyenler (oyun açılışında sıfırdan oluşur): trafikteki NPC'ler, bekleyen müşteriler,
## süren tamirler, araç konumları, kamera, UI durumu, seçili araç.
##
## Dosya: user://savegame.json (JSON, "version" alanıyla). Eski sürümler hâlâ geçerlidir ve yüklenince
## güncel sürümle yeniden yazılır: v1'de "vehicles" yoktur (başlangıç aracı sahiplenilir), v2'de
## "vehicles.paint" yoktur (araçlar fabrika renginde kalır), v3'te "quests" yoktur (görevler baştan). Bozuk / okunamayan / daha yeni sürümlü
## kayıt oyunu çökertmez: hata loglanır ve sahnedeki başlangıç değerleriyle devam edilir.
## Otomatik kayıt: para / XP / seviye / gem / geliştirme değişince DEBOUNCE saniyelik gecikmeli tek
## yazma (aynı karedeki birden fazla değişiklik tek save'de birleşir). Kare başına iş yapılmaz.
##
## Bulut kaydı (CloudSaveManager) AYNI veriyi kullanır: snapshot_json() bu dosyaya yazılan sözlüğün
## JSON'udur, apply_snapshot() buluttan gelen sözlüğü load_game ile aynı doğrulamadan geçirip uygular
## ve diske yazar. İkinci bir kayıt modeli yoktur.

## Kayıt diske yazıldı.
signal game_saved
## Kayıt yüklendi (true) ya da kayıt yok / geçersizdi (false).
signal game_loaded(success: bool)

const SAVE_PATH: String = "user://savegame.json"
const SAVE_VERSION: int = 4
## Okunabilen en eski sürüm (daha eskisi reddedilir; 1/2/3 → 4 migration yapılır).
const MIN_VERSION: int = 1
## Değişiklikten sonra diske yazmadan önce beklenen süre (sn).
const DEBOUNCE: float = 0.5
const MAX_LEVEL: int = 99

## Açılışta kayıt varsa otomatik yükle.
@export var load_on_start: bool = true
## Kayıt yoksa açılışta ilk kaydı oluştur.
@export var create_save_on_first_run: bool = true
## Değişikliklerde otomatik kayıt.
@export var auto_save: bool = true

var _economy: EconomyManager
var _progress: PlayerProgress
var _upgrades: GarageUpgradeManager
var _ownership: VehicleOwnership
var _quests: QuestManager
var _timer: Timer
var _loading: bool = false   # yükleme sırasında gelen sinyaller otomatik kaydı tetiklemesin
var _fresh_json: String = ""  # sahnenin başlangıç değerleri (kayıt yüklenmeden önce), has_progress için


func _ready() -> void:
	add_to_group("save_manager")
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = DEBOUNCE
	_timer.timeout.connect(_on_debounce_timeout)
	add_child(_timer)
	_setup.call_deferred()   # manager'lar _ready'sini bitirsin


func _setup() -> void:
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	_progress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	_quests = get_tree().get_first_node_in_group("quests") as QuestManager
	_fresh_json = snapshot_json()
	if load_on_start:
		if has_save():
			load_game()
		elif create_save_on_first_run:
			save_game()   # ilk açılış: sahnedeki başlangıç değerleriyle kayıt oluştur
	_connect_auto_save()


# --- Dış API ---------------------------------------------------------------------

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Güncel durumu diske yazar. Başarılıysa true (hata oyunu bozmaz, yalnızca loglanır).
func save_game() -> bool:
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: kayıt yazılamadı (%s): %d" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(_collect(), "\t"))
	file.close()
	game_saved.emit()
	return true


## Kaydı okur ve manager'lara uygular. Kayıt yok / bozuk / bilinmeyen sürümse false döner ve
## sahnedeki mevcut değerler korunur.
func load_game() -> bool:
	var data: Dictionary = _read()
	if data.is_empty():
		game_loaded.emit(false)
		return false
	_loading = true
	_apply(data)
	_loading = false
	if int(data.get("version", SAVE_VERSION)) < SAVE_VERSION:
		save_game()   # v1/v2/v3 → v4: dosya yeni formatta yeniden yazılır
	game_loaded.emit(true)
	return true


func delete_save() -> bool:
	if not has_save():
		return false
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveManager: kayıt silinemedi (%d)" % err)
		return false
	return true


## Yeni oyun: kayıt silinir, manager'lar başlangıç değerlerine döner ve yeni kayıt yazılır.
func new_game() -> void:
	delete_save()
	_loading = true
	if _economy:
		_economy.reset()
	if _progress:
		_progress.reset()
	if _upgrades:
		_upgrades.reset()
	if _ownership:
		_ownership.reset()
	if _quests:
		_quests.reset()
	_loading = false
	save_game()


## Kayıttaki ham veri (test / hata ayıklama; kayıt yoksa boş).
func peek() -> Dictionary:
	return _read()


## Güncel durum, diske yazılanla aynı sözlük.
func snapshot() -> Dictionary:
	return _collect()


## Güncel durumun sıralı anahtarlı JSON'u (bulut kaydı ve karşılaştırma için tek biçim).
func snapshot_json() -> String:
	return JSON.stringify(_collect(), "", true)


## Oyuncu yeni oyundan ilerlemiş mi (para / XP / seviye / gem / geliştirme / araç farklı mı)?
## Açılışta kendiliğinden oluşan başlangıç kaydı "kayıt yok" sayılır.
func has_progress() -> bool:
	return snapshot_json() != _fresh_json


## Dışarıdan gelen (bulut) kaydı load_game ile aynı doğrulamadan geçirir, uygular ve diske yazar.
## Geçersizse hiçbir şey değişmez ve false döner.
func apply_snapshot(raw: Variant) -> bool:
	var data: Dictionary = validate(raw)
	if data.is_empty():
		return false
	_loading = true
	_apply(data)
	_loading = false
	save_game()
	game_loaded.emit(true)
	return true


## Sürümü desteklenen bir kayıt sözlüğü mü? Değilse boş sözlük (hata loglanır).
func validate(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		push_error("SaveManager: kayıt bozuk (JSON okunamadı), varsayılan değerlerle devam ediliyor")
		return {}
	var data: Dictionary = raw
	var version: int = int(data.get("version", 0))
	if version < MIN_VERSION or version > SAVE_VERSION:
		push_error("SaveManager: desteklenmeyen kayıt sürümü %d (beklenen %d..%d), varsayılan değerlerle devam ediliyor" % [version, MIN_VERSION, SAVE_VERSION])
		return {}
	return data


# --- İç ---------------------------------------------------------------------------

## Manager'ların public API'sinden kayıt sözlüğü.
func _collect() -> Dictionary:
	var levels: Dictionary = _upgrades.levels() if _upgrades else {}
	return {
		"version": SAVE_VERSION,
		"economy": {"money": _economy.money if _economy else 0},
		"progress": {
			"xp": _progress.xp if _progress else 0,
			"level": _progress.level if _progress else 1,
			"gems": _progress.gems if _progress else 0,
		},
		"garage_upgrades": {
			String(GarageUpgradeManager.SPEED_ID): int(levels.get(GarageUpgradeManager.SPEED_ID, 1)),
			String(GarageUpgradeManager.CAPACITY_ID): int(levels.get(GarageUpgradeManager.CAPACITY_ID, 1)),
		},
		"vehicles": {
			"owned": _owned_ids(),
			"paint": _ownership.paint_state() if _ownership else {},
		},
		"quests": _quests.state() if _quests else {},
	}


## Sahip olunan araç id'leri, JSON'a yazılabilir String dizisi olarak.
func _owned_ids() -> Array:
	var out: Array = []
	if _ownership == null:
		return out
	for id: StringName in _ownership.owned_vehicle_ids():
		out.append(String(id))
	return out


## Dosyayı okur ve doğrular; sorun varsa boş sözlük döner (çağıran mevcut değerlerle devam eder).
func _read() -> Dictionary:
	if not has_save():
		return {}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_error("SaveManager: kayıt açılamadı (%s): %d" % [SAVE_PATH, FileAccess.get_open_error()])
		return {}
	var text: String = file.get_as_text()
	file.close()
	return validate(JSON.parse_string(text))


## Doğrulanmış değerleri manager'lara yazar. Geçersiz alanlar mevcut / varsayılan değerde bırakılır.
func _apply(data: Dictionary) -> void:
	var economy_data: Dictionary = data.get("economy", {}) if typeof(data.get("economy")) == TYPE_DICTIONARY else {}
	if _economy and economy_data.has("money"):
		_economy.set_money(maxi(int(economy_data["money"]), 0))   # negatif para kabul edilmez
	var progress_data: Dictionary = data.get("progress", {}) if typeof(data.get("progress")) == TYPE_DICTIONARY else {}
	if _progress:
		_progress.load_state(
			clampi(int(progress_data.get("level", _progress.level)), 1, MAX_LEVEL),
			maxi(int(progress_data.get("xp", _progress.xp)), 0),
			maxi(int(progress_data.get("gems", _progress.gems)), 0))
	var upgrade_data: Dictionary = data.get("garage_upgrades", {}) if typeof(data.get("garage_upgrades")) == TYPE_DICTIONARY else {}
	if _upgrades and not upgrade_data.is_empty():
		var levels: Dictionary = {}
		for key: String in upgrade_data:
			levels[StringName(key)] = int(upgrade_data[key])   # aralık dışı → apply_levels 1'e çeker
		_upgrades.apply_levels(levels)
	if _ownership:
		# v1 kayıtta "vehicles" yoktur: liste boş gider, VehicleOwnership başlangıç aracını sahiplenir
		var vehicle_data: Dictionary = data.get("vehicles", {}) if typeof(data.get("vehicles")) == TYPE_DICTIONARY else {}
		var owned: Variant = vehicle_data.get("owned", [])
		_ownership.load_state(owned if owned is Array else [])
		# v2 kayıtta "paint" yoktur: araçlar fabrika renginde kalır
		var paint: Variant = vehicle_data.get("paint", {})
		_ownership.load_paint(paint if paint is Dictionary else {})
	if _quests:
		# v3 kayıtta "quests" yoktur: görevler baştan başlar
		_quests.load_state(data.get("quests", {}) if data.get("quests") is Dictionary else {})


# --- Otomatik kayıt (debounce) -----------------------------------------------------

func _connect_auto_save() -> void:
	if not auto_save:
		return
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: request_save())
	if _progress:
		_progress.xp_changed.connect(func(_l: int, _x: int, _n: int) -> void: request_save())
		_progress.level_up.connect(func(_l: int) -> void: request_save())
		_progress.gems_changed.connect(func(_g: int) -> void: request_save())
	if _upgrades:
		_upgrades.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: request_save())


## Kaydı DEBOUNCE saniye sonraya planlar; bu süre içinde gelen yeni istekler tek yazmada birleşir.
func request_save() -> void:
	if _loading or not auto_save:
		return
	_timer.start(DEBOUNCE)


func _on_debounce_timeout() -> void:
	save_game()
