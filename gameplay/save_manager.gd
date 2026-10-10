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
## Kayıtta garajın FİZİKSEL seviyesi (garage_upgrades.garage_level) ile SATIN ALINMIŞ tamir alanı
## sayısı (repair_bays.unlocked) ayrı alanlardır: garaj büyük olup alan satın alınmamış olabilir.
##
## Dosya: user://savegame.json (JSON, "version" alanıyla). Eski sürümler hâlâ geçerlidir ve yüklenince
## güncel sürümle yeniden yazılır: v9 ve öncesinde "crates" / "gem_rewards" / "vehicles.discovered"
## yoktur (sahip olunan araçlar keşfedilmiş sayılır, bekleyen kasa yoktur, günlük seri sıfırdan), v8'de "decor" yuva biçimindedir (DecorManager yüklerken gerçek konumlu
## örneklere taşır), v7'de "decor" yoktur (garaj dekorasyonsuz başlar), v1'de "vehicles" yoktur (başlangıç aracı sahiplenilir), v2'de
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
const SAVE_VERSION: int = 10
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
## ARKADAŞ GARAJI ziyareti (GarageVisit sahne ağaca girmeden açar): diskteki kayıt OKUNMAZ, arkadaşın
## açık garajı (GarageVisit.garage) uygulanır ve HİÇBİR ŞEY YAZILMAZ (save_game / new_game /
## apply_snapshot reddedilir). Oyuncunun kendi kaydı ziyaret boyunca dokunulmadan kalır.
var visit_mode: bool = false

var _economy: EconomyManager
var _progress: PlayerProgress
var _upgrades: GarageUpgradeManager
var _ownership: VehicleOwnership
var _quests: QuestManager
var _bays: RepairBayManager
var _mastery: JobMastery
var _decor: DecorManager
var _crates: CrateManager
var _gem_rewards: GemRewards
var _missions: MissionManager
var _ads: AdService
var _race: RaceManager
var _tutorial: TutorialManager
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
	_bays = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	_mastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	_decor = get_tree().get_first_node_in_group("decor") as DecorManager
	_crates = get_tree().get_first_node_in_group("crates") as CrateManager
	_gem_rewards = get_tree().get_first_node_in_group("gem_rewards") as GemRewards
	_missions = get_tree().get_first_node_in_group("missions") as MissionManager
	_ads = get_tree().get_first_node_in_group("ads") as AdService
	_race = get_tree().get_first_node_in_group("race") as RaceManager
	_tutorial = get_tree().get_first_node_in_group("tutorial") as TutorialManager
	if visit_mode:
		_loading = true
		_apply(GarageVisit.garage())
		_loading = false
		game_loaded.emit(true)
		return   # otomatik kayıt bağlanmaz
	if _gem_rewards and not has_save():
		# Yeni kurulum: ilk günün giriş ödülü başlangıç değerine dahil olsun, yoksa bu cihaz
		# "ilerleme var" sayılır ve Google girişinde bulut kaydı otomatik gelmez (çakışma sorulur).
		_gem_rewards.check_day()
	_fresh_json = _progress_json()
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
## ATOMİK: önce geçici dosyaya yazılır, sonra asıl dosyanın üzerine taşınır. Yazım yarıda kesilirse
## (uygulama öldürüldü, pil bitti) eski kayıt bozulmadan kalır — kasa satın alma / açma gibi tek
## yazımlık işlemler ya tamamen diskte olur ya hiç olmaz.
func save_game() -> bool:
	if visit_mode:
		return false
	var tmp_path: String = SAVE_PATH + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: kayıt yazılamadı (%s): %d" % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(_collect(), "\t"))
	file.close()
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp_path),
		ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveManager: kayıt yerine taşınamadı (%d)" % err)
		return false
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
	if SaveSafe.i(data.get("version", SAVE_VERSION)) < SAVE_VERSION:
		save_game()   # v1/v2/v3 → v4: dosya yeni formatta yeniden yazılır
	game_loaded.emit(true)
	return true


func delete_save() -> bool:
	if visit_mode or not has_save():
		return false
	var err: Error = DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	if err != OK:
		push_error("SaveManager: kayıt silinemedi (%d)" % err)
		return false
	return true


## Yeni oyun: kayıt silinir, manager'lar başlangıç değerlerine döner ve yeni kayıt yazılır.
func new_game() -> void:
	if visit_mode:
		return
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
	if _bays:
		_bays.reset()
	if _decor:
		_decor.reset()
	if _mastery:
		_mastery.reset()
	if _crates:
		_crates.reset()
	if _gem_rewards:
		_gem_rewards.reset()
	if _missions:
		_missions.reset()
	if _ads:
		_ads.reset()
	if _race:
		_race.reset()
	if _tutorial:
		_tutorial.reset()
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
	return _progress_json() != _fresh_json


## İlerleme karşılaştırması için snapshot: gem ödülü durumu (saat damgası, günlük seri) oyuncu
## oynamasa da zamanla değişir, bu yüzden karşılaştırmaya girmez.
func _progress_json() -> String:
	var data: Dictionary = _collect()
	data.erase("gem_rewards")
	data.erase("missions")   # gün / hafta değişimiyle kendiliğinden değişir; ilerleme sayılmaz
	data.erase("ads")   # reklam sayaçları da zamanla / izlemeyle değişir; ilerleme sayılmaz
	data.erase("tutorial")   # ders atlamak / izlemek bulut kaydını "ilerlemiş" göstermesin
	return JSON.stringify(data, "", true)


## Dışarıdan gelen (bulut) kaydı load_game ile aynı doğrulamadan geçirir, uygular ve diske yazar.
## Geçersizse hiçbir şey değişmez ve false döner.
func apply_snapshot(raw: Variant) -> bool:
	if visit_mode:
		return false
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
	var version: int = SaveSafe.i(data.get("version", 0))
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
			# GARAJ SEVİYESİ: garajın fiziksel boyutu. Satın alınmış tamir alanı sayısı ayrı alandadır
			# ("repair_bays.unlocked") — ikisi bilinçli olarak birbirinden bağımsızdır.
			String(GarageUpgradeManager.GARAGE_ID): int(levels.get(GarageUpgradeManager.GARAGE_ID, 1)),
		},
		"vehicles": _vehicles_state(),
		"quests": _quests.state() if _quests else {},
		"repair_bays": {"unlocked": _bays.state() if _bays else 1, "layout": _bays.layout_state() if _bays else []},
		# İŞ USTALIĞI: arıza id → tamamlanan iş sayısı (yıldızlar bundan türetilir)
		"job_mastery": _mastery.state() if _mastery else {},
		# GARAJ DEKORASYONU: depo (eşya → adet), garajdaki örnekler (kimlik, konum, dönüş, ölçek),
		# uygulanan zemin / duvar kaplaması
		"decor": _decor.state() if _decor else {},
		# ARAÇ TESLİMAT KASALARI: bekleyen kasalar, sonuçları (satın almada çekilmiş) ve durumları
		"crates": _crates.state() if _crates else {},
		# TEKRARLAYAN GEM KAYNAKLARI: giriş serisi, günlük / haftalık görevler, bahşiş
		"gem_rewards": _gem_rewards.state() if _gem_rewards else {},
		"missions": _missions.state() if _missions else {},
		# REKLAM SAYAÇLARI: günlük izleme hakları (saat geri alınarak sıfırlanamaz). Eski kayıtta yoktur: sorun değil.
		"ads": _ads.state() if _ads else {},
		# KİŞİSEL YARIŞ REKORLARI: araç başına en iyi süre + hayalet izi. Eski kayıtta yoktur: rekorsuz başlanır.
		"race": _race.state() if _race else {},
		# EĞİTİM: biten ustalık dersleri. Eski kayıtta yoktur: seviye 2+ oyuncu dersleri bitmiş sayar.
		"tutorial": _tutorial.state() if _tutorial else {},
	}


## Araçlar: sahiplik + boya + koleksiyon (keşif, kopya, yarış aracı).
func _vehicles_state() -> Dictionary:
	var out: Dictionary = {
		"owned": _owned_ids(),
		"paint": _ownership.paint_state() if _ownership else {},
	}
	if _ownership:
		out.merge(_ownership.collection_state())
	return out


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
		_economy.set_money(maxi(SaveSafe.i(economy_data["money"]), 0))   # negatif para kabul edilmez
	var progress_data: Dictionary = data.get("progress", {}) if typeof(data.get("progress")) == TYPE_DICTIONARY else {}
	if _progress:
		_progress.load_state(
			clampi(SaveSafe.i(progress_data.get("level", _progress.level)), 1, MAX_LEVEL),
			maxi(SaveSafe.i(progress_data.get("xp", _progress.xp)), 0),
			maxi(SaveSafe.i(progress_data.get("gems", _progress.gems)), 0))
	var upgrade_data: Dictionary = data.get("garage_upgrades", {}) if typeof(data.get("garage_upgrades")) == TYPE_DICTIONARY else {}
	var bay_data: Dictionary = data.get("repair_bays", {}) if data.get("repair_bays") is Dictionary else {}
	var unlocked_bays: int = maxi(SaveSafe.i(bay_data.get("unlocked", 1)), 1)
	if _upgrades and not upgrade_data.is_empty():
		var levels: Dictionary = {}
		for key: String in upgrade_data:
			levels[StringName(key)] = SaveSafe.i(upgrade_data[key])   # aralık dışı → apply_levels 1'e çeker
		if not levels.has(GarageUpgradeManager.GARAGE_ID):
			# v5 ve öncesi: "repair_capacity" hem garaj büyüklüğü hem kapasite demekti. Oyuncunun
			# ödediği seviye fiziksel garaj seviyesi olur; satın alınmış alan sayısı ayrı kalır.
			levels[GarageUpgradeManager.GARAGE_ID] = maxi(
				SaveSafe.i(upgrade_data.get(SaveSafe.s(GarageUpgradeManager.CAPACITY_ID), 1)), unlocked_bays)
		_upgrades.apply_levels(levels)
	if _ownership:
		# v1 kayıtta "vehicles" yoktur: liste boş gider, VehicleOwnership başlangıç aracını sahiplenir
		var vehicle_data: Dictionary = data.get("vehicles", {}) if typeof(data.get("vehicles")) == TYPE_DICTIONARY else {}
		var owned: Variant = vehicle_data.get("owned", [])
		_ownership.load_state(owned if owned is Array else [])
		# v2 kayıtta "paint" yoktur: araçlar fabrika renginde kalır
		var paint: Variant = vehicle_data.get("paint", {})
		_ownership.load_paint(paint if paint is Dictionary else {})
		# v9 ve öncesi: "discovered" yoktur, sahip olunanlar keşfedilmiş sayılır; yarış aracı başlangıç
		_ownership.load_collection(vehicle_data)
	# v9 ve öncesi (kasa sisteminden önceki oyuncu): eski ilerleme için geriye dönük ödül verilmez —
	# İLK KASA görevi alınmış sayılır (bedava kasa yok), geçilmiş tamir / koleksiyon kilometre taşları
	# ödenmiş sayılır (bkz. aşağıda). Yalnızca o günün giriş ödülü normal şekilde gelir.
	var legacy: bool = SaveSafe.i(data.get("version", SAVE_VERSION)) < 10
	if _quests:
		# v3 kayıtta "quests" yoktur: görevler baştan başlar
		var quest_data: Dictionary = (data.get("quests", {}) as Dictionary).duplicate(true) if data.get("quests") is Dictionary else {}
		if legacy:
			var claimed: Array = quest_data.get("claimed", []) if quest_data.get("claimed") is Array else []
			if not claimed.has("first_crate"):
				claimed.append("first_crate")
			quest_data["claimed"] = claimed
		_quests.load_state(quest_data)
	if _bays:
		# v4 ve öncesi kayıtta "repair_bays" yoktur: yalnızca ilk tamir alanı açık gelir
		# Yerler (taşınabilir alanlar): eski kayıtta yoktur, varsayılan yerde gelir
		_bays.load_layout(bay_data.get("layout", []))
		_bays.load_state(unlocked_bays)
	if _mastery:
		# v6 ve öncesi kayıtta "job_mastery" yoktur: ustalık sayaçları sıfırdan başlar
		var mastery_data: Variant = data.get("job_mastery", {})
		_mastery.load_state(mastery_data if mastery_data is Dictionary else {})
	if _decor:
		# v7 ve öncesi kayıtta "decor" yoktur: garaj boş dekorasyonla başlar. v8'in yuva biçimini
		# DecorManager kendisi tanır ve taşır (garaj seviyesi yukarıda yüklendi, taşıma ona bakar).
		var decor_data: Variant = data.get("decor", {})
		_decor.load_state(decor_data if decor_data is Dictionary else {})
	if _crates:
		# v9 ve öncesi: bekleyen kasa yok
		var crate_data: Variant = data.get("crates", {})
		_crates.load_state(crate_data if crate_data is Dictionary else {})
	if _gem_rewards:
		var gem_data: Variant = data.get("gem_rewards", {})
		_gem_rewards.load_state(gem_data if gem_data is Dictionary else {})
	if _missions:
		# v10 ve öncesi kayıtta "missions" yoktur: görevler boş başlar (bugünün görevleri ilk açılışta üretilir)
		var mission_data: Variant = data.get("missions", {})
		_missions.load_state(mission_data if mission_data is Dictionary else {})
	if _ads:
		var ads_data: Variant = data.get("ads", {})
		_ads.load_state(ads_data if ads_data is Dictionary else {})
	if _race:
		var race_data: Variant = data.get("race", {})
		_race.load_state(race_data if race_data is Dictionary else {})
	if _tutorial:
		# Seviye yukarıda yüklendi: bölümü olmayan (eski) kayıtta karar seviyeye göre verilir
		var tutorial_data: Variant = data.get("tutorial", {})
		_tutorial.load_state(tutorial_data if tutorial_data is Dictionary else {}, data.has("tutorial"))
	if legacy:
		if _missions:
			_missions.mark_legacy_repairs_passed()   # geçilmiş tamir yıldızları ödenmiş sayılır
		if _crates and _ownership:
			_crates.mark_passed_milestones(_ownership.discovered_count())


# --- Otomatik kayıt (debounce) -----------------------------------------------------

func _connect_auto_save() -> void:
	if not auto_save:
		return
	if _economy:
		_economy.money_changed.connect(func(_m: int) -> void: request_save())
	if _crates:
		_crates.crates_changed.connect(request_save)
	if _race:
		_race.records_changed.connect(request_save)
	if _ownership:
		_ownership.ownership_changed.connect(request_save)
	if _progress:
		_progress.xp_changed.connect(func(_l: int, _x: int, _n: int) -> void: request_save())
		_progress.level_up.connect(func(_l: int) -> void: request_save())
		_progress.gems_changed.connect(func(_g: int) -> void: request_save())
	if _upgrades:
		_upgrades.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: request_save())
	if _decor:
		# Eşya yalnızca taşınınca / döndürülünce para değişmez: yerleşim ayrıca kaydı tetikler.
		_decor.placement_changed.connect(request_save)
		_decor.tiles_changed.connect(request_save)   # zemin karoları (dekorasyon v2) ayrı sinyalle gelir


## Kaydı DEBOUNCE saniye sonraya planlar; bu süre içinde gelen yeni istekler tek yazmada birleşir.
func request_save() -> void:
	if _loading or not auto_save:
		return
	_timer.start(DEBOUNCE)


func _on_debounce_timeout() -> void:
	save_game()
