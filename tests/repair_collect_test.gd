extends SceneTree
## PARA BALONU — tamiri biten aracın üstünde ₺ balonu çıkar; araca / balona DOKUNMAK parayı doğrudan toplar,
## araç plakası (PARA TOPLA) açılmaz. Tamir sürerken plakası açık bırakılan araç tamamlanınca plaka kapanır.
## Çalıştırma: tools/run_tests.sh repair_collect_test

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


## Gerçek dokunuş: fare basış + bırakış, görünüm alanı koordinatında (picking fizik karesinde işlenir).
func _tap(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await physics_frame
		await process_frame


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	check(hud != null and rm != null and traffic != null and economy != null and camera != null, "sahne parçaları bulundu")
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
	car.request_repair(rm.repair_wait_spots[0], RepairType.defaults()[0])
	check(rm.start_repair(car), "tamir başladı")
	await frames(3)
	var hitbox: StaticBody3D = car.get_node_or_null("CarHitbox") as StaticBody3D
	check(hitbox != null, "aracın tıklama kutusu var")

	print("== plakası açık araç tamamlanır ==")
	hitbox.call(&"select")
	await frames(3)
	check(rm.get_target() == car and hud.car_info_panel.visible, "tamir sürerken plaka açık (ilerleme)")
	var state: RepairState = rm.get_state(car)
	state.elapsed = state.repair_duration - 0.01
	await frames(4)
	check(rm.can_collect(car), "sayaç bitti, para bekliyor")
	check(car.bubble_visible(), "aracın üstünde ₺ balonu")
	check(not hud.car_info_panel.visible and rm.get_target() == null, "tamamlanınca plaka kapandı (PARA TOPLA ekranı yok)")

	print("== dokununca doğrudan toplanır ==")
	camera.follow(car.global_position, 2.6)   # araç kadrajın ortasında olsun (dokunuş ekranda)
	await frames(30)
	var collected: Array[int] = []
	rm.repair_collected.connect(func(_c: Node3D, reward: int, _xp: int) -> void: collected.append(reward))
	var money_before: int = economy.money
	await _tap(camera.unproject_position(car.global_position + Vector3(0.0, 0.15, 0.0)))
	await frames(3)
	check(collected.size() == 1, "araca dokunmak parayı topladı")
	check(collected.size() == 1 and economy.money == money_before + collected[0],
		"kasaya girdi (+%d ₺)" % (collected[0] if collected.size() > 0 else 0))
	check(not hud.car_info_panel.visible and CarHitboxScript.get(&"selected_car") == null, "plaka açılmadı, araç seçilmedi")
	check(not rm.can_collect(car), "aynı ödül ikinci kez toplanmaz")
	check(not car.bubble_visible(), "balon kayboldu")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
