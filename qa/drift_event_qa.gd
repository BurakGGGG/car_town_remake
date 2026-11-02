extends SceneTree
## JAPON DRIFT GÖSTERİSİ QA (DriftEvent): varsayılan şehir görünümünde gösteriyi başlatır (hazırlık dahil: şeritler
## boşalır), kareleri ve oyunun bütün sesini (Master) kaydeder, müzik "drop"u ile öndeki aracın ekrana girişini ölçer.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/drift_event_qa.gd --resolution 1152x648 [-- <giriş x,z> <dönüş ±1>]
## Çıktı: /home/burak/Projects/ct_shots/drift/ (kare_XXX.png, drift_oyun.wav)

const OUT: String = "/home/burak/Projects/ct_shots/drift/"
const SHOT_EVERY: int = 6   # fizik karesi (10 kare/sn)


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		if file.begins_with("kare_"):
			DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(6.0).timeout
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	traffic.chase._timer = 99999.0
	traffic._hazard_timer = 99999.0
	var drift: DriftEvent = traffic.drift
	drift.persist = false
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var entry: Vector3 = Vector3.ZERO
	var turn: int = 0
	if args.size() >= 2:
		var parts: PackedStringArray = args[0].split(",")
		entry = Vector3(float(parts[0]), 0.0, float(parts[1]))
		turn = int(args[1])
	var records: Dictionary = {}
	for bus_name: String in ["Master", "Music", CityAmbience.BUS]:
		var record: AudioEffectRecord = AudioEffectRecord.new()
		AudioServer.add_bus_effect(AudioServer.get_bus_index(bus_name), record)
		record.set_recording_active(true)
		records[bus_name] = record
	var zoom: String = OS.get_environment("QA_ZOOM")
	if zoom != "":
		var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
		camera.reset_view()
		await create_timer(0.5).timeout
		camera.follow(WorldCamera.ground_point(camera), float(zoom))
		await create_timer(1.5).timeout
	var router: UiRouter = get_first_node_in_group("ui_router") as UiRouter
	for attempt: int in 6:   # açılış gazetesi / giriş merdiveni gibi pencereler kapanır
		if router.top() == &"":
			break
		print("açık ekran kapanıyor: %s" % router.top())
		router.close_all()
		await create_timer(0.6).timeout
	drift.engine_gain_db = -80.0 if OS.get_environment("QA_MUTE") == "engine" else 0.0
	drift.squeal_gain_db = -80.0 if OS.get_environment("QA_MUTE") == "squeal" else 0.0
	if DriftEvent._routes.is_empty():
		drift._ensure_routes(true)
	var camera3d: Camera3D = root.get_viewport().get_camera_3d()
	for route: Dictionary in DriftEvent._routes:
		var line: DriftLine = route["line"]
		print("rota giriş %s %s: puan %.1f" % [line.entry_dir, "sola" if line.turn > 0 else "sağa", DriftEvent.route_score(line, camera3d)])
	var started: bool = drift.start_now(entry, turn)
	print("start_now: %s, faz %d" % [started, drift.phase])
	if not started:
		quit()
		return
	var t: float = 0.0
	var frame: int = 0
	var shot: int = 0
	var show_at: float = -1.0
	var lead_seen: float = -1.0
	var drop_music: float = -1.0
	var was_phase: int = drift.phase
	var max_smoke: int = 0
	var music_end: float = -1.0
	var proc_sum: float = 0.0
	var draw_max: int = 0
	while t < 60.0:
		await physics_frame
		t += 1.0 / 60.0
		frame += 1
		if drift.phase != was_phase:
			print("%5.2f sn faz %d → %d (araç %d)" % [t, was_phase, drift.phase, traffic.vehicles.size()])
			was_phase = drift.phase
			if drift.phase == DriftEvent.Phase.SHOW:
				show_at = t
		if show_at >= 0.0 and drift.phase == DriftEvent.Phase.IDLE and GameMusic.drift_position(self) < 0.0 \
				and t - show_at > 4.0:
			if music_end < 0.0:
				music_end = t
			elif t - music_end > 3.5:
				break
		if show_at < 0.0:
			proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
			draw_max = maxi(draw_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
			if frame % 60 == 0:
				print("%5.2f sn hazırlık | işlem ort. %.2f ms, çizim en çok %d" % [t, proc_sum * 1000.0 / 60.0, draw_max])
				proc_sum = 0.0
				draw_max = 0
			continue
		var cars: Array[TrafficVehicle] = drift.vehicles()
		if lead_seen < 0.0 and not cars.is_empty() and not traffic.is_hidden(cars[0].global_position):
			lead_seen = t
			drop_music = GameMusic.drift_position(self)
			print("%5.2f sn öndeki araç ekranda; müzik konumu %.3f (drop %.3f)" % [t, drop_music, DriftEvent.MUSIC_DROP])
		var smoke: DriftSmoke = traffic.get_node_or_null("DriftSmoke") as DriftSmoke
		if smoke:
			max_smoke = maxi(max_smoke, smoke.alive_count())
		if frame % SHOT_EVERY == 0 and t - show_at < 26.0 and OS.get_environment("QA_NOSHOT") == "":
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(OUT + "kare_%03d.png" % shot)
			shot += 1
		proc_sum += Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draw_max = maxi(draw_max, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		if frame % 60 == 0:
			print("%5.2f sn sahne: araç %d, drift %d, duman %d, kavşak açık %s, müzik %.2f | işlem ort. %.2f ms, çizim en çok %d" % [t,
				traffic.vehicles.size(), cars.size(), smoke.alive_count() if smoke else -1, drift._crossing_open,
				GameMusic.drift_position(self), proc_sum * 1000.0 / 60.0, draw_max])
			proc_sum = 0.0
			draw_max = 0
	for bus_name: String in records:
		var record: AudioEffectRecord = records[bus_name]
		record.set_recording_active(false)
		var wav: AudioStreamWAV = record.get_recording()
		if wav:
			wav.save_to_wav(OUT + "drift_%s.wav" % String(bus_name).to_lower())
	var marks: SkidMarks = null
	for child: Node in traffic.get_children():
		if child is SkidMarks:
			marks = child
	print("SONUÇ: kare %d, en çok duman %d, iz noktası %d, drop farkı %.3f sn" % [shot, max_smoke,
		marks.point_count() if marks else -1, drop_music - DriftEvent.MUSIC_DROP if drop_music >= 0.0 else -99.0])
	quit()
