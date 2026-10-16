extends SceneTree
## MÜŞTERİ SABRI — tamir için 3–4 müşteri bekleyebilir (garaj sv.1–2: 3, sv.3–4: 4); çok bekleyen sabrı bitince gider.
##   - bekleme sınırı / nokta sayısı / trafik payı (bekleyenler trafik sınırına dahil, yol boşalmasın)
##   - sabır yerleşince başlar, son PATIENCE_WARN sn balonda geri sayım, bitince müşteri trafiğe döner (bildirim)
##   - seçiliyken ve eğitim sürerken sabır azalmaz; giden müşteri hemen yeniden seçilmez
## Çalıştırma: tools/run_tests.sh customer_patience_test (pencereli: trafik modelleri arka planda yüklenir)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var hud: Hud = main.find_child("HUD", true, false)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	rm.customer_interval_min = 999.0   # kendiliğinden müşteri gelmesin: test kendisi kurar
	rm.customer_interval_max = 999.0
	rm._customer_timer = 999.0

	print("== BEKLEME SINIRI ==")
	var waits: Array[int] = []
	for row: Dictionary in RepairManager.SUPPLY:
		waits.append(int(row["waiting"]))
	check(waits == [3, 3, 4, 4], "garaj seviyesine göre 3–4 müşteri bekleyebilir (%s)" % [waits])
	check(rm.waiting_limit() == 3 and rm.active_wait_spots().size() == 3, "sv.1: 3 müşteri, 3 nokta")
	check(traffic.max_vehicles == RepairManager.traffic_limit(RepairManager.SUPPLY[0]) and traffic.max_vehicles == 5,
		"bekleyenler için trafik payı: 4 + 1 = %d" % traffic.max_vehicles)

	print("== SABIR ==")
	for i: int in 600:
		if not traffic.vehicles.is_empty():
			break
		await process_frame
	var car: TrafficVehicle = traffic.vehicles[0] if not traffic.vehicles.is_empty() else null
	check(car != null, "trafikte araç var")
	if car == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	var spot: Node3D = rm.repair_wait_spots[0]
	car.global_position = Vector3(spot.global_position.x + 0.7, car.global_position.y, 0.3)   # batıya giden şerit
	car.global_rotation.y = spot.global_rotation.y
	if not car.customer_stopped.is_connected(rm._on_customer_stopped):
		car.customer_stopped.connect(rm._on_customer_stopped)
	car.request_repair(spot, RepairType.defaults()[0])
	for i: int in 900:
		if car.is_waiting():
			break
		await physics_frame
	check(car.is_waiting(), "müşteri bekleme noktasına yerleşti")
	check(car.patience >= RepairManager.CUSTOMER_PATIENCE.x and car.patience <= RepairManager.CUSTOMER_PATIENCE.y,
		"sabrı başladı (%.0f sn)" % car.patience)
	car.patience = RepairManager.PATIENCE_WARN - 0.5
	await frames(3)
	check(car._bubble._label.visible and car._bubble._label.text == "0:20", "son 20 sn balonda geri sayım («%s»)" % car._bubble._label.text)

	CarHitboxScript.set(&"selected_car", car)
	await frames(3)
	var held: float = car.patience
	await create_timer(0.6).timeout
	check(rm.get_target() == car and is_equal_approx(car.patience, held), "plakası açıkken sabır azalmaz")
	CarHitboxScript.call(&"clear_selection", self)
	await frames(3)

	var director: Node = get_first_node_in_group("tutorial_director")
	if director:
		var state: StringName = director.get(&"_state")
		director.set(&"_state", &"step")
		var before: float = car.patience
		rm._tick_patience(1.0)
		check(is_equal_approx(car.patience, before), "eğitim sürerken sabır azalmaz")
		director.set(&"_state", state)

	var left: Array[Node3D] = []
	rm.customer_left.connect(func(c: Node3D) -> void: left.append(c))
	car.patience = 0.25
	await create_timer(0.6).timeout
	check(left.size() == 1 and left[0] == car, "sabrı biten müşteri gitti (customer_left)")
	check(car.mode == TrafficVehicle.Mode.TRAFFIC and car.fault == null and car.repair_status == TrafficVehicle.RepairStatus.NORMAL,
		"trafiğe döndü, arızası sıfırlandı")
	check(not car.bubble_visible() and car.wait_spot() == null, "balon kapandı, nokta boşaldı")
	var noticed: bool = hud._notice_label.text == "MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ"
	for queued: Dictionary in hud._notice_queue:   # başka bildirim oynuyorsa sırada bekler
		noticed = noticed or String(queued["text"]) == "MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ"
	check(noticed, "bildirim: MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ")
	var picked_again: bool = false
	for option: Dictionary in rm._candidates():
		picked_again = picked_again or option["vehicle"] == car
	check(car.busy_after_race() and not picked_again, "giden müşteri hemen yeniden müşteri seçilmez")
	var start: Vector3 = car.global_position
	await create_timer(1.5).timeout
	check(car.global_position.distance_to(start) > 0.3, "kaldırımdan çıkıp yola koyuldu")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
