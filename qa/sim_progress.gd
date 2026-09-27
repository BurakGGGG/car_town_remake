extends SceneTree
## YENİ OYUNCU SİMÜLASYONU: temiz kayıtla başlar, "iyi oyuncu" gibi oynar
## (müşteriyi alır, tamir eder, ödülü toplar, parası yettikçe en mantıklı yatırımı yapar)
## ve belirlenen dakikalarda ilerleme fotoğrafı basar. Hız: Engine.time_scale.
##
## Kullanım: godot-4 --path . --headless --script qa/sim_progress.gd -- <dakika> [hiz]

const SNAPSHOTS: Array[float] = [5.0, 10.0, 20.0, 30.0, 60.0, 120.0, 300.0, 600.0]

var _frame: int = 0
var _time: float = 0.0
var _next: int = 0
var _limit: float = 120.0
var _repairs: int = 0
var _races: int = 0
var _earned: int = 0
var _spent: int = 0
var _eco: EconomyManager
var _prog: PlayerProgress
var _own: VehicleOwnership
var _repairs_mgr: RepairManager
var _upgrades: GarageUpgradeManager
var _bays: RepairBayManager
var _race: RaceManager
var _traffic: TrafficManager


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_limit = float(args[0]) if args.size() > 0 else 120.0


func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		change_scene_to_file("res://Main.tscn")
		return false
	if _frame < 60:
		return false
	if _frame == 60:
		_eco = get_first_node_in_group("economy")
		_prog = get_first_node_in_group("player_progress")
		_own = get_first_node_in_group("vehicle_ownership")
		_repairs_mgr = get_first_node_in_group("repair_manager")
		_upgrades = get_first_node_in_group("garage_upgrades")
		_bays = get_first_node_in_group("repair_bays")
		_race = get_first_node_in_group("race")
		_traffic = _find(current_scene)
		var save: SaveManager = get_first_node_in_group("save_manager")
		if save:
			save.new_game()
		Engine.time_scale = 12.0
		Engine.max_physics_steps_per_frame = 64
		print("dk | para | XP | sv | garaj | alan | araç | garaj değeri | rütbe | tamir | yarış | ustalık★")
		return false
	_time += delta
	_play()
	if _frame % 600 == 0:
		var modes: Dictionary = {}
		for v: TrafficVehicle in _traffic.vehicles:
			modes[v.mode] = int(modes.get(v.mode, 0)) + 1
		print("  [%4.0f sn] araç=%d kipler=%s | müşteri hazır=%s | alan=%d kapasite=%d" % [
			_time, _traffic.vehicles.size(), modes,
			_repairs_mgr.get("_waiting").size() if _repairs_mgr.get("_waiting") != null else "?",
			_bays.unlocked_count(), _repairs_mgr.capacity()])
	while _next < SNAPSHOTS.size() and _time >= SNAPSHOTS[_next] * 60.0:
		_snapshot(SNAPSHOTS[_next])
		_next += 1
	if _time >= _limit * 60.0:
		Engine.time_scale = 1.0
		_final()
		return true
	return false


## "İyi oyuncu": bekleyen müşteriyi tamire alır, biten işi toplar, parası yettikçe yatırım yapar.
func _play() -> void:
	for vehicle: TrafficVehicle in _traffic.vehicles:
		if vehicle.is_waiting() and _repairs_mgr.start_repair(vehicle):
			pass
		elif vehicle.mode == TrafficVehicle.Mode.REWARD_WAITING:
			var before: int = _eco.money
			_repairs_mgr.collect(vehicle)
			_earned += maxi(_eco.money - before, 0)
			_repairs += 1
	# Yatırım sırası: tamir alanı > garaj seviyesi > tamir hızı > yeni araç
	if _bays:
		for index: int in _bays.bay_count():
			if _bays.can_purchase(index) and _eco.money >= _bays.price(index):
				_spent += _bays.price(index)
				_bays.purchase(index)
				return
	for id: StringName in [GarageUpgradeManager.GARAGE_ID, GarageUpgradeManager.CAPACITY_ID, GarageUpgradeManager.SPEED_ID]:
		if _upgrades.can_buy(id) and _eco.money >= _upgrades.next_cost(id):
			_spent += _upgrades.next_cost(id)
			_upgrades.buy(id)
			return
	# En pahalı alınabilir aracı al (ilerleme hissi: yeni araç)
	var best: StringName = &""
	var best_price: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		if _own.can_purchase(id) and int(entry["price"]) > best_price:
			best = id
			best_price = int(entry["price"])
	if best != &"":
		_spent += best_price
		_own.purchase_vehicle(best)


func _snapshot(minutes: float) -> void:
	var value: int = GarageValue.compute(self)
	var stars: int = 0
	var mastery: JobMastery = get_first_node_in_group("job_mastery") as JobMastery
	if mastery:
		for job: RepairType in RepairType.defaults():
			stars += mastery.stars(job.id)
	print("%4.0f | %8d | %6d | %2d | %d/%d | %d/%d | %2d | %9d | %2d | %4d | %3d | %2d" % [
		minutes, _eco.money, _prog.xp, _prog.level,
		_upgrades.garage_level(), 4,
		_bays.unlocked_count() if _bays else 1, 3,
		_own.owned_count(), value, GarageValue.rank(value), _repairs, _races, stars])


func _final() -> void:
	print("--- toplam: %d tamir, kazanç %d ₺, harcama %d ₺, kalan %d ₺ ---" % [
		_repairs, _earned, _spent, _eco.money])
	var locked: Array[String] = []
	for entry: Dictionary in CarCatalog.all():
		if not _own.is_owned(entry["id"]):
			locked.append("%s(%s,%d₺,durum%d)" % [entry["id"], entry["class"], entry["price"],
				_own.status(entry["id"])])
	print("alınmayan araçlar: %s" % [locked])


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager: return node
	for c: Node in node.get_children():
		var f: TrafficManager = _find(c)
		if f: return f
	return null
