extends SceneTree
## POLİS KOVALAMACASI QA — oyunun kendi kamerasıyla bir kovalamacayı baştan sona izler: ~0,3 sn arayla 16 kare
## (4×4 kontakt), kovalamaca sırasında en uzun kare süresi (polis modeli / siren ilk çıkış takılması) ve trafiğin
## yol verip vermediği. Her şerit için ayrı kontakt. Sistem: traffic/police_chase.gd.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/police_chase_qa.gd --display-driver x11 --resolution 1170x540 \
##     -- <çıktı_klasörü> [W_in_spawn|E_in_spawn|S_in_spawn ...]

const SHOT_GAP_MSEC: int = 300
const SHOTS: int = 16


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if not args.is_empty() else OS.get_user_data_dir()
	var lanes: PackedStringArray = args.slice(1) if args.size() > 1 else PackedStringArray(["W_in_spawn", "E_in_spawn", "S_in_spawn"])
	DirAccess.make_dir_recursive_absolute(out)
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var traffic: TrafficManager = _find(current_scene)
	if traffic == null:
		print("TrafficManager yok")
		quit(1)
		return
	for lane_name: String in lanes:
		var lane: TrafficWaypoint = null
		for point: TrafficWaypoint in traffic.spawn_points:
			if String(point.name) == lane_name:
				lane = point
		if lane == null:
			print("şerit yok: " + lane_name)
			continue
		await create_timer(2.0).timeout
		var police_id: StringName = PoliceChase.POLICE_IDS[lanes.find(lane_name) % PoliceChase.POLICE_IDS.size()]
		if not traffic.chase.start_now(lane, police_id):
			print("başlamadı: " + lane_name)
			continue
		var sheet: Image = null
		var k: int = 0
		var next_shot: int = Time.get_ticks_msec()
		var worst: float = 0.0
		var last: int = Time.get_ticks_usec()
		var yielded: int = 0
		var best_center: float = INF
		var best_frame: Image = null
		var camera: Camera3D = get_root().get_camera_3d()
		while traffic.chase.is_active():
			await RenderingServer.frame_post_draw
			var now_us: int = Time.get_ticks_usec()
			worst = maxf(worst, (now_us - last) / 1000.0)
			last = now_us
			for v: TrafficVehicle in traffic.vehicles:
				if v.yield_shift() > 0.06:
					yielded = maxi(yielded, 1)
			var police: TrafficVehicle = traffic.chase.police()
			if police and camera and k % 2 == 0:
				var screen: Vector2 = get_root().get_final_transform() * camera.unproject_position(police.global_position)
				var size: Vector2 = Vector2(get_root().get_texture().get_size())
				var off: float = screen.distance_to(size * 0.5)
				if off < best_center:
					best_center = off
					best_frame = get_root().get_texture().get_image()
			if k < SHOTS and Time.get_ticks_msec() >= next_shot:
				next_shot += SHOT_GAP_MSEC
				var img: Image = get_root().get_texture().get_image()
				img.resize(img.get_width() / 3, img.get_height() / 3, Image.INTERPOLATE_BILINEAR)
				if sheet == null:
					sheet = Image.create(img.get_width() * 4, img.get_height() * 4, false, img.get_format())
				sheet.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i(img.get_width() * (k % 4), img.get_height() * (k / 4)))
				k += 1
		if sheet:
			sheet.save_png("%s/kovalamaca_%s.png" % [out, lane_name])
		if best_frame:
			best_frame.save_png("%s/kovalamaca_%s_tam.png" % [out, lane_name])
		print("%s (%s): %d kare, en uzun kare %.1f ms, yol veren araç %s" % [lane_name, police_id, k, worst,
			"var" if yielded > 0 else "yok"])
	quit()


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find(child)
		if found:
			return found
	return null
