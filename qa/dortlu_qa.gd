extends SceneTree
## DÖRTLÜ QA (TrafficVehicle.hazard_stop, HazardLights): oyunu açar, ekranda görünen bir araca dörtlü yaktırır, kamerayı
## aracın üstüne getirir; durduğunu, dörtlülerin yandığını, arkadaki aracın beklediğini ve süre bitince dörtlü sönüp
## yola devam ettiğini denetler; yanık ve sönük anlarda kare çeker.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/dortlu_qa.gd --display-driver x11 --resolution 1152x648
## Çıktı: /home/burak/Projects/ct_shots/dortlu/

const OUT: String = "/home/burak/Projects/ct_shots/dortlu/"

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png(OUT + file)
	print("  ·    kare %s" % file)


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(6.0).timeout
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	var vehicle: TrafficVehicle = null
	for i: int in 40:   # uygun (düz yolda giden, görünen) araç beklenir
		vehicle = traffic.start_hazard()
		if vehicle:
			break
		await create_timer(0.5).timeout
	check(vehicle != null, "dörtlü için uygun araç bulundu")
	if vehicle == null:
		quit(1)
		return
	print("  ·    araç %s, motor tipi %s" % [vehicle.vehicle_id, TrafficEngine.Kind.keys()[TrafficEngine.kind_of(vehicle.vehicle_id)]])
	check(vehicle.hazards_on(), "dörtlüler yandı")
	var stopped: bool = false
	for i: int in 120:
		if vehicle.is_hazard_stopped():
			stopped = true
			break
		if camera:
			camera.follow(vehicle.global_position, 2.2)
		await physics_frame
	check(stopped, "araç şeridinde durdu")
	if camera:
		camera.follow(vehicle.global_position, 2.2)
	await create_timer(0.6).timeout
	var lit: bool = false
	for i: int in 30:   # yanık ana denk gelen kare (shader saatiyle)
		var material: ShaderMaterial = (vehicle.get("_hazards") as HazardLights).material_override as ShaderMaterial
		var t: float = fmod(fmod(Time.get_ticks_msec() / 1000.0, 3600.0) * HazardLights.BLINK_RATE \
			+ float(material.get_shader_parameter(&"phase")), 1.0)
		if t > 0.1 and t < 0.4:
			lit = true
			break
		await process_frame
	await _shot("dortlu_yanik.png")
	await create_timer(0.35).timeout
	await _shot("dortlu_sonuk.png")
	check(lit, "yanık an yakalandı")
	var follower: TrafficVehicle = null
	for other: TrafficVehicle in traffic.vehicles:
		if other.leader == vehicle:
			follower = other
	if follower:
		print("  ·    arkadaki araç %s, sıkışma %.1f sn" % [follower.vehicle_id, follower.stuck_time])
	var resumed: bool = false
	for i: int in 400:
		if not vehicle.hazards_on() and vehicle.speed > 0.1:
			resumed = true
			break
		await physics_frame
	check(resumed, "süre bitince dörtlü söndü, araç yola devam etti")
	check(vehicle.mode == TrafficVehicle.Mode.TRAFFIC, "araç trafikte")
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
