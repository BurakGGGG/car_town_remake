extends SceneTree
## KAÇAN KAYBEDEN QA — oyuncu yarışı kazanır, garaja döner; kaybeden rakip kırmızıda kavşağa dalar. Karşı yönde
## yeşilde gelen iki araç frene basar (korna). Kaçış boyunca aralıklı görüntü + konum / hız / ışık çıktısı.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/kacan_kaybeden_qa.gd --display-driver x11 --resolution 1440x810
## Görüntüler: /home/burak/Projects/ct_shots/sehir/kacak_<n>.png

const OUT: String = "/home/burak/Projects/ct_shots/sehir/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _shot(index: int) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + "kacak_%d.png" % index)


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	(get_first_node_in_group("vehicle_ownership") as VehicleOwnership).add_vehicle(&"tofas_sahin")   # araçsız oyuncuya rakip gelmez
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var lights: TrafficLights = current_scene.find_child("TrafficLights", true, false) as TrafficLights
	traffic.chase._timer = 99999.0
	race.challenge_timeout = 600.0
	race.flee_chance = 1.0   # kaçış oyunda ~7'de 1
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and not race.has_challenge():
		await process_frame
		race.request_challenge_now()
	var loser: TrafficVehicle = race.challenger()
	print("rakip: ", loser.vehicle_id if loser else &"yok")
	hud.race_challenge_screen.race_accepted.emit()
	await create_timer(0.6).timeout
	hud.drag_race_screen.race_completed.emit(true, 11.2, 11.7)
	await create_timer(0.5).timeout
	# Karşı yönde (yeşil) kavşağa yaklaşan iki araç
	lights.set_process(false)
	lights.set_phase(TrafficLights.Phase.GREEN, 1 - loser.axis)
	for point: TrafficWaypoint in traffic.spawn_points:
		if point.name in [&"W_in_spawn", &"E_in_spawn"]:
			var car: TrafficVehicle = traffic._spawn_at(point)
			if car:
				var toward: float = 1.0 if point.name == &"W_in_spawn" else -1.0
				car.global_position = Vector3(0.6 - toward * 2.2, car.global_position.y, point.global_position.z)
				car.speed = car.max_speed
	hud.visible = false
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.follow(Vector3(0.4, 0.0, 0.2), 2.6)
	hud.race_result_screen.exit_requested.emit()
	await frames(3)
	print("kaçıyor: ", loser.fleeing, "  ışığı: ", lights.light_of(loser.axis))
	var shot: int = 0
	var entered: bool = false
	for i: int in 240:
		await physics_frame
		if i % 6 == 0 and i <= 150:
			var lane_dir: Vector3 = Vector3(0, 0, 1) if loser.axis == 1 else Vector3(1, 0, 0)
			var heading: float = rad_to_deg(lane_dir.signed_angle_to(loser.global_transform.basis.z, Vector3.UP))
			if absf(heading) > 90.0:
				heading = rad_to_deg((-lane_dir).signed_angle_to(loser.global_transform.basis.z, Vector3.UP))
			print("  t=%.2f  hız %.2f  yanal %+.2f  burun %+5.1f°  direksiyon %+5.1f°  yatış %+.3f" % [i / 60.0, loser.speed,
				loser.yield_shift(), heading, loser.rig.steer_deg if loser.rig else 0.0, loser.model.rotation.z])
		if i % 18 == 0 and shot < 8:
			shot += 1
			await _shot(shot)
		if loser.is_in_intersection() and not entered:
			entered = true
			print("  KAVŞAĞA DALDI — kendi ışığı: ", lights.light_of(loser.axis))
	lights.set_process(true)
	quit(0)
