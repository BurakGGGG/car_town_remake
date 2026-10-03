extends SceneTree
## YENİ OYUNCU SİMÜLASYONU (kasa ekonomisi): temiz kayıtla başlar, "iyi oyuncu" gibi oynar
## (müşteriyi alır, tamir eder, ödülü toplar), ₺'yi ve gemi en mantıklı yere harcar ve belirlenen
## dakikalarda ilerleme fotoğrafı basar. Hız: Engine.time_scale.
##
## Kullanım: godot-4 --path . --headless --script qa/sim_progress.gd -- <dakika>
##
## KASA SİSTEMİNDEN SONRA (docs/vehicle_crate_implementation_report.md): araçlar artık ₺ ile
## ALINMAZ; kasadan çıkar (gem). Bu yüzden ₺ harcama sırası: tamir alanı > garaj seviyesi > tamir
## hızı > dekorasyon (en ucuz sahip olunmayan eşya). Gem: açık kasalardan P(yeni araç)/fiyat oranı en
## iyi olan alınır, gelir gelmez açılır. Günlük giriş / günlük görev gemi burada GELMEZ (oyun saati
## 12 kat hızlı akar ama takvim günü değişmez) — onların etkisi tools/economy/crate_sim.py'dedir.

const SNAPSHOTS: Array[float] = [5.0, 10.0, 20.0, 30.0, 60.0, 120.0, 180.0, 300.0, 450.0, 600.0]

var _frame: int = 0
var _time: float = 0.0
var _next: int = 0
var _limit: float = 120.0
var _repairs: int = 0
var _races: int = 0
var _earned: int = 0
var _spent: Dictionary = {"alan": 0, "garaj": 0, "hiz": 0, "dekor": 0}
var _crates_opened: int = 0
var _dups: int = 0
var _eco: EconomyManager
var _prog: PlayerProgress
var _own: VehicleOwnership
var _repairs_mgr: RepairManager
var _upgrades: GarageUpgradeManager
var _bays: RepairBayManager
var _race: RaceManager
var _traffic: TrafficManager
var _decor: DecorManager
var _crates: CrateManager


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
		_decor = get_first_node_in_group("decor")
		_crates = get_first_node_in_group("crates")
		_traffic = _find(current_scene)
		var save: SaveManager = get_first_node_in_group("save_manager")
		if save:
			save.new_game()
		Engine.time_scale = 12.0
		Engine.max_physics_steps_per_frame = 64
		print("dk | bakiye | kazanç | alan | garaj | hız | dekor | sv | g.sv | alan | eşya | araç | garaj değeri | rütbe | tamir | gem | kasa | kopya")
		return false
	_time += delta
	_play()
	while _next < SNAPSHOTS.size() and _time >= SNAPSHOTS[_next] * 60.0:
		_snapshot(SNAPSHOTS[_next])
		_next += 1
	if _time >= _limit * 60.0:
		Engine.time_scale = 1.0
		_final()
		return true
	return false


## "İyi oyuncu": bekleyen müşteriyi tamire alır, biten işi toplar, ₺ ve gem harcar.
func _play() -> void:
	for vehicle: TrafficVehicle in _traffic.vehicles:
		if vehicle.is_waiting() and _repairs_mgr.start_repair(vehicle):
			pass
		elif vehicle.mode == TrafficVehicle.Mode.REWARD_WAITING:
			var before: int = _eco.money
			_repairs_mgr.collect(vehicle)
			_earned += maxi(_eco.money - before, 0)
			_repairs += 1
	_spend_gems()
	# ₺ yatırım sırası: tamir alanı > garaj seviyesi > tamir hızı > dekorasyon
	if _bays:
		for index: int in _bays.bay_count():
			if _bays.can_purchase(index) and _eco.money >= _bays.price(index):
				_spent["alan"] += _bays.price(index)
				_bays.purchase(index)
				return
	for pair: Array in [[GarageUpgradeManager.GARAGE_ID, "garaj"], [GarageUpgradeManager.CAPACITY_ID, "alan"],
			[GarageUpgradeManager.SPEED_ID, "hiz"]]:
		var id: StringName = pair[0]
		if _upgrades.can_buy(id) and _eco.money >= _upgrades.next_cost(id):
			_spent[pair[1]] += _upgrades.next_cost(id)
			_upgrades.buy(id)
			return
	# Dekor ancak sıradaki yatırımın parası ayrıldıktan sonra: yoksa ucuz eşyalar her kuruşu yiyip
	# garaj seviyesini sonsuza erteliyordu (ilk koşuda 30. dakikada garaj hâlâ 1, dekora 14.800 ₺).
	var reserve: int = 0
	if _bays:
		for index: int in _bays.bay_count():
			var st: RepairBayManager.Status = _bays.status(index)
			if st == RepairBayManager.Status.BUYABLE or st == RepairBayManager.Status.TOO_EXPENSIVE:
				reserve = maxi(reserve, _bays.price(index))
				break
	# can_buy() "parası yetiyor mu"yu da sorar: yedek için yalnızca "maksimumda değil mi" bakılır
	# (ilk düzeltmede can_buy kullanılmıştı; para yetmeyince yedek sıfırlanıyor, garaj 300. dakikaya kalıyordu)
	for id: StringName in [GarageUpgradeManager.GARAGE_ID, GarageUpgradeManager.SPEED_ID]:
		var u: GarageUpgrade = _upgrades.get_upgrade(id)
		if u and not u.is_max():
			reserve = maxi(reserve, u.next_cost())
	if _decor:
		var cheapest: StringName = &""
		var cheapest_price: int = 1 << 30
		for item: Dictionary in GarageDecor.all():
			var id: StringName = item["id"]
			if _decor.owned_of(id) == 0 and _decor.can_purchase(id) and _decor.price_of(id) < cheapest_price:
				cheapest = id
				cheapest_price = _decor.price_of(id)
		if cheapest != &"" and _eco.money >= cheapest_price + reserve and _decor.purchase(cheapest):
			_spent["dekor"] += cheapest_price


## Gem: P(yeni araç)/fiyat oranı en iyi açık kasa; alınır alınmaz açılır (teslimat animasyonu beklenmez).
func _spend_gems() -> void:
	if _crates == null:
		return
	var best: StringName = &""
	var best_ratio: float = 0.0
	for crate: Dictionary in CrateCatalog.all():
		var id: StringName = crate["id"]
		if not _crates.can_buy(id):
			continue
		var p_new: float = 0.0
		for row: Dictionary in CrateCatalog.odds(id):
			if not _own.is_owned(row["id"]):
				p_new += float(row["chance"])
		var ratio: float = p_new / float(maxi(CrateCatalog.price(id), 1))
		if ratio > best_ratio:
			best_ratio = ratio
			best = id
	if best == &"":
		return
	var uid: int = _crates.buy(best)
	if uid <= 0:
		return
	var result: Dictionary = _crates.open(uid)
	if result.is_empty():
		return   # teslimat noktası bulunamadı: kasa bekler
	_crates_opened += 1
	if bool(result["duplicate"]):
		_dups += 1
	_crates.claim(uid)


func _snapshot(minutes: float) -> void:
	var value: int = GarageValue.compute(self)
	print("%4.0f | %8d | %8d | %6d | %6d | %5d | %8d | %2d | %d/4 | %d/3 | %2d | %2d | %9d | %2d | %4d | %4d | %3d | %3d" % [
		minutes, _eco.money, _earned, _spent["alan"], _spent["garaj"], _spent["hiz"], _spent["dekor"],
		_prog.level, _upgrades.garage_level(), _bays.unlocked_count() if _bays else 1,
		_decor.owned_count() if _decor else 0, _own.owned_count(), value, GarageValue.rank(value),
		_repairs, _prog.gems, _crates_opened, _dups])


func _final() -> void:
	var total_spent: int = 0
	for key: String in _spent:
		total_spent += int(_spent[key])
	print("--- toplam: %d tamir, tamir kazancı %d ₺, harcama %d ₺ %s, kalan %d ₺ ---" % [
		_repairs, _earned, total_spent, _spent, _eco.money])
	var missing: Array[String] = []
	for entry: Dictionary in CarCatalog.all():
		if not _own.is_owned(entry["id"]):
			missing.append(String(entry["id"]))
	print("koleksiyonda olmayan: %s" % [missing])


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager: return node
	for c: Node in node.get_children():
		var f: TrafficManager = _find(c)
		if f: return f
	return null
