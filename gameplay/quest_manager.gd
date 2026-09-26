class_name QuestManager
extends Node
## Görev ilerlemesi ve ödülleri. Sahnede World/Gameplay/QuestManager olarak durur; arayanlar "quests"
## grubundan bulur (autoload yok — proje kuralı). Görev tanımları QuestCatalog'dadır.
##
## YENİ SİSTEM KURMAZ: ilerleme mevcut sinyallerden gelir (RepairManager.repair_collected,
## VehicleOwnership.paint_purchased / ownership_changed, GarageUpgradeManager.upgrade_purchased,
## PlayerProgress.level_up); ödül mevcut API'lerle verilir (PlayerProgress.add_xp / add_gems,
## EconomyManager.add_money). Kare başına iş yapmaz.
##
## Aynı anda ACTIVE_COUNT görev aktiftir (katalogdaki sırayla, ödülü alınmamış ilk görevler). Sayaç
## görevleri yalnızca aktifken sayar; durum görevleri (araç sayısı, geliştirme / oyuncu seviyesi)
## oyunun o anki durumundan okunur. Hedefe ulaşan görevin ödülü ÖDÜLÜ AL (claim) ile alınır.
## Kalıcılık SaveManager'dadır (state / load_state / reset); değişince request_save çağrılır.

## Aktif bir görevin ilerlemesi değişti.
signal quest_progressed(quest_id: StringName, progress: int, target: int)
## Görev hedefe ulaştı, ödül alınmayı bekliyor (HUD bildirimi için; bir kez yayılır).
signal quest_completed(quest_id: StringName)
## Ödül verildi.
signal quest_claimed(quest_id: StringName)
## Aktif görev listesi ya da ilerlemeler değişti (UI tazelensin).
signal quests_changed

const ACTIVE_COUNT: int = 3

var _counters: Dictionary = {}          # sayaç görevi id → birikmiş değer
var _claimed: Array[StringName] = []    # ödülü alınmış görevler
var _announced: Dictionary = {}         # tamamlandı bildirimi yapılmış görevler (kaydedilmez)
var _economy: EconomyManager
var _player: PlayerProgress
var _upgrades: GarageUpgradeManager
var _ownership: VehicleOwnership


func _ready() -> void:
	add_to_group("quests")
	_connect.call_deferred()   # diğer manager'lar _ready'sini bitirsin


func _connect() -> void:
	_economy = get_tree().get_first_node_in_group("economy") as EconomyManager
	_player = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	_upgrades = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	_ownership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var repairs: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repairs:
		repairs.repair_collected.connect(_on_repair_collected)
	if _ownership:
		_ownership.paint_purchased.connect(func(_id: StringName, _paint: StringName) -> void: _count(QuestCatalog.Type.PAINTS, 1))
		_ownership.ownership_changed.connect(_check_completed)
	if _upgrades:
		_upgrades.upgrade_purchased.connect(func(_id: StringName, _level: int) -> void: _check_completed())
	if _player:
		_player.level_up.connect(func(_level: int) -> void: _check_completed())
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.bays_changed.connect(_check_completed)
	var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		mastery.mastery_up.connect(func(_id: StringName, _stars: int) -> void: _check_completed())
	_mark_announced()


# --- Sorgu ---------------------------------------------------------------------

## Aktif görevler (katalog sırasıyla, ödülü alınmamış ilk ACTIVE_COUNT görev).
func active_quests() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in QuestCatalog.all():
		if _claimed.has(entry["id"]):
			continue
		out.append(entry)
		if out.size() >= ACTIVE_COUNT:
			break
	return out


func is_active(quest_id: StringName) -> bool:
	for entry: Dictionary in active_quests():
		if entry["id"] == quest_id:
			return true
	return false


## Hedefe göre ilerleme (0..target).
func progress(quest_id: StringName) -> int:
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	if entry.is_empty():
		return 0
	var target: int = int(entry["target"])
	if _claimed.has(quest_id):
		return target
	var value: int = 0
	match int(entry["type"]):
		QuestCatalog.Type.OWN_VEHICLES:
			value = _ownership.owned_count() if _ownership else 0
		QuestCatalog.Type.UPGRADE_LEVEL:
			value = _upgrades.level(entry["upgrade"]) if _upgrades else 1
		QuestCatalog.Type.PLAYER_LEVEL:
			value = _player.level if _player else 1
		QuestCatalog.Type.REPAIR_BAYS:
			var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
			value = bays.unlocked_count() if bays else 1
		QuestCatalog.Type.GARAGE_RANK:
			value = GarageValue.current_rank(get_tree())
		QuestCatalog.Type.JOB_STARS:
			var mastery: JobMastery = get_tree().get_first_node_in_group("job_mastery") as JobMastery
			value = mastery.total_stars() if mastery else 0
		_:
			value = int(_counters.get(quest_id, 0))
	return clampi(value, 0, target)


func is_complete(quest_id: StringName) -> bool:
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	return not entry.is_empty() and progress(quest_id) >= int(entry["target"])


func is_claimed(quest_id: StringName) -> bool:
	return _claimed.has(quest_id)


## Ödülü alınmayı bekleyen aktif görev sayısı (HUD plakası için).
func claimable_count() -> int:
	var count: int = 0
	for entry: Dictionary in active_quests():
		if is_complete(entry["id"]):
			count += 1
	return count


func all_done() -> bool:
	return active_quests().is_empty()


# --- Ödül ------------------------------------------------------------------------

## ÖDÜLÜ AL: görev aktif ve tamamlanmışsa ödül verilir (bir kez). Değilse hiçbir şey olmaz (false).
func claim(quest_id: StringName) -> bool:
	if _claimed.has(quest_id) or not is_active(quest_id) or not is_complete(quest_id):
		return false
	var entry: Dictionary = QuestCatalog.get_entry(quest_id)
	_claimed.append(quest_id)
	_counters.erase(quest_id)
	if _economy and int(entry.get("money", 0)) > 0:
		_economy.add_money(int(entry["money"]))
	if _player and int(entry.get("gems", 0)) > 0:
		_player.add_gems(int(entry["gems"]))
	if _player and int(entry.get("xp", 0)) > 0:
		_player.add_xp(int(entry["xp"]))   # seviye atlarsa level_up → yeni aktif görevler kontrol edilir
	quest_claimed.emit(quest_id)
	quests_changed.emit()
	_check_completed()   # yeni açılan durum görevi zaten tamamlanmış olabilir
	_request_save()
	return true


# --- İlerleme --------------------------------------------------------------------

func _on_repair_collected(_car: Node3D, reward: int, _xp: int) -> void:
	_count(QuestCatalog.Type.REPAIRS, 1)
	_count(QuestCatalog.Type.REPAIR_MONEY, reward)


## Sayaç görevleri: yalnızca aktif ve tamamlanmamış olanlar sayar.
func _count(type: int, amount: int) -> void:
	if amount <= 0:
		return
	var changed: bool = false
	for entry: Dictionary in active_quests():
		var quest_id: StringName = entry["id"]
		if int(entry["type"]) != type or is_complete(quest_id):
			continue
		var target: int = int(entry["target"])
		_counters[quest_id] = mini(int(_counters.get(quest_id, 0)) + amount, target)
		quest_progressed.emit(quest_id, int(_counters[quest_id]), target)
		changed = true
	if changed:
		_check_completed()
		quests_changed.emit()
		_request_save()


## Aktif görevlerden yeni tamamlananlar için bir kez quest_completed yayılır.
func _check_completed() -> void:
	var any: bool = false
	for entry: Dictionary in active_quests():
		var quest_id: StringName = entry["id"]
		if is_complete(quest_id) and not _announced.has(quest_id):
			_announced[quest_id] = true
			quest_completed.emit(quest_id)
			any = true
	if any:
		quests_changed.emit()


## Açılışta / kayıttan yüklemede zaten tamamlanmış görevler için bildirim yapılmaz.
func _mark_announced() -> void:
	_announced.clear()
	for entry: Dictionary in active_quests():
		if is_complete(entry["id"]):
			_announced[entry["id"]] = true
	quests_changed.emit()


# --- Kayıt ------------------------------------------------------------------------

## {"progress": {id: int}, "claimed": [id]}
func state() -> Dictionary:
	var counters: Dictionary = {}
	for quest_id: StringName in _counters:
		counters[String(quest_id)] = int(_counters[quest_id])
	var claimed: Array = []
	for quest_id: StringName in _claimed:
		claimed.append(String(quest_id))
	return {"progress": counters, "claimed": claimed}


## Kayıttan: katalogda olmayan görevler atlanır, sayaçlar hedefle sınırlanır.
func load_state(data: Dictionary) -> void:
	_counters.clear()
	_claimed.clear()
	var claimed: Variant = data.get("claimed", [])
	if claimed is Array:
		for raw: Variant in claimed:
			var quest_id: StringName = StringName(str(raw))
			if not QuestCatalog.get_entry(quest_id).is_empty() and not _claimed.has(quest_id):
				_claimed.append(quest_id)
	var counters: Variant = data.get("progress", {})
	if counters is Dictionary:
		for raw: Variant in counters:
			var quest_id: StringName = StringName(str(raw))
			var entry: Dictionary = QuestCatalog.get_entry(quest_id)
			if entry.is_empty() or _claimed.has(quest_id) or not QuestCatalog.is_counter(int(entry["type"])):
				continue
			_counters[quest_id] = clampi(int((counters as Dictionary)[raw]), 0, int(entry["target"]))
	_mark_announced()


## Yeni oyun: hiçbir görev alınmamış, sayaçlar sıfır.
func reset() -> void:
	_counters.clear()
	_claimed.clear()
	_mark_announced()


func _request_save() -> void:
	var save: Node = get_tree().get_first_node_in_group("save_manager")
	if save and save.has_method(&"request_save"):
		save.request_save()
