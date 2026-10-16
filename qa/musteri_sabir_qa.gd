extends SceneTree
## MÜŞTERİ SABRI QA — garaj önündeki kaldırımda 3 müşteri; biri sabrının son saniyelerinde (balonda geri sayım).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/musteri_sabir_qa.gd --display-driver x11 --resolution 1440x810
## Görüntü: /home/burak/Projects/ct_shots/sehir/musteri_sabir.png

const OUT: String = "/home/burak/Projects/ct_shots/sehir/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	rm._customer_timer = 999.0
	(current_scene.find_child("HUD", true, false) as CanvasLayer).visible = false
	var until: int = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until and traffic.vehicles.size() < 3:
		await process_frame
	var cars: Array[TrafficVehicle] = []
	for i: int in mini(3, traffic.vehicles.size()):
		var car: TrafficVehicle = traffic.vehicles[i]
		var spot: Node3D = rm.repair_wait_spots[i]
		car.global_position = Vector3(spot.global_position.x + 0.6, car.global_position.y, 0.3)
		car.global_rotation.y = spot.global_rotation.y
		car.customer_stopped.connect(rm._on_customer_stopped)
		car.request_repair(spot, RepairType.defaults()[i % 4])
		cars.append(car)
	until = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < until and not cars.all(func(c: TrafficVehicle) -> bool: return c.is_waiting()):
		await process_frame
	cars[0].patience = 13.4
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.follow(Vector3(-3.8, 0.0, 0.1), 2.0)
	await frames(40)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "musteri_sabir.png")
	print("bekleyen: ", rm.waiting_count(), "  balon: ", cars[0]._bubble._label.text)
	quit(0)
