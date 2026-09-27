extends SceneTree
## Yol kenarında bekleyen müşteri sayısı: garaj 4. seviyede bile 2'yi geçmemeli.
var _repairs: RepairManager
var _upgrades: GarageUpgradeManager

func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	_repairs = get_first_node_in_group("repair_manager")
	_upgrades = get_first_node_in_group("garage_upgrades")
	var eco: EconomyManager = get_first_node_in_group("economy")
	eco.set_money(500000)
	for i: int in 3:
		_upgrades.buy(GarageUpgradeManager.GARAGE_ID)
	var bays: RepairBayManager = get_first_node_in_group("repair_bays")
	for index: int in bays.bay_count():
		if bays.can_purchase(index):
			bays.purchase(index)
	print("garaj seviyesi=%d | bekleme sınırı=%d | alan=%d" % [
		_upgrades.garage_level(), _repairs.waiting_limit(), bays.unlocked_count()])
	Engine.time_scale = 8.0
	var worst: int = 0
	var samples: int = 0
	var over: int = 0
	for i: int in 120:
		await create_timer(0.25).timeout
		var n: int = _repairs.waiting_count()
		worst = maxi(worst, n)
		samples += 1
		if n > 2:
			over += 1
	Engine.time_scale = 1.0
	print("%d örnek (≈4 dk oyun süresi): en yüksek bekleyen=%d | 2'yi aşan örnek=%d" % [samples, worst, over])
	quit(0 if worst <= 2 else 1)
