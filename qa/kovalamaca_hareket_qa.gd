extends SceneTree
## KOVALAMACA HAREKET QA — şüpheliyi (ve polisi) yakından izler: kamera şüpheliyi takip eder, 0,15 sn arayla 18 kare;
## yanal konum (orta çizgiden), burun açısı (yol yönüne göre), ön teker açısı, gövde yatışı, hız, atlatılan araç sayısı.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/kovalamaca_hareket_qa.gd --display-driver x11 --resolution 1280x720 \
##     [-- S_in_spawn|W_in_spawn|E_in_spawn]
## Görüntüler: /home/burak/Projects/ct_shots/kovalamaca/hareket_<n>.png

const OUT: String = "/home/burak/Projects/ct_shots/kovalamaca/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var lane_name: String = args[0] if not args.is_empty() else "S_in_spawn"
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var chase: PoliceChase = traffic.chase
	var hud: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	hud.visible = false
	var lane: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.spawn_points:
		if point.name == lane_name:
			lane = point
	var started: bool = false
	for attempt: int in 300:
		if chase.start_now(lane, &"police_vito"):
			started = true
			break
		await create_timer(0.1).timeout
	print("başladı: ", started)
	if not started:
		quit(1)
		return
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	var suspect: TrafficVehicle = chase.suspect()
	var shot: int = 0
	var last: int = 0
	var sways: Array[float] = []
	while chase.is_active() and shot < 18:
		await physics_frame
		suspect = chase.suspect()
		if suspect == null:
			break
		camera.follow(suspect.global_position, 2.4)
		var frame: Dictionary = suspect.chase_frame(suspect.chase_distance)
		var heading: float = 0.0
		if not frame.is_empty():
			heading = rad_to_deg((frame["along"] as Vector3).signed_angle_to(suspect.global_transform.basis.z, Vector3.UP))
		sways.append(chase._sway)
		if Time.get_ticks_msec() - last >= 150:
			last = Time.get_ticks_msec()
			shot += 1
			RenderingServer.force_draw()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT + "hareket_%d.png" % shot)
			print("  %2d) hız %.2f  yanal %+.2f  burun %+5.1f°  teker %+5.1f°  yatış %+.3f  atlatılan %d" % [shot, suspect.speed,
				chase._sway, heading, suspect.rig.steer_deg, suspect.model.rotation.z, chase._dodged.size()])
	sways.sort()
	print("yanal aralık: %+.2f … %+.2f" % [sways[0], sways[sways.size() - 1]] if not sways.is_empty() else "yok")
	quit(0)
