extends SceneTree
## SÜPER ARAÇ GAZLAMASI QA (2026-11-02, TrafficVehicle.SURGE_* + TrafficManager.EXOTIC_PACE + ExoticEngine vitesleri):
## Huracán şehre sokulur, kamera onu izler; 40 sn boyunca hızı, gazlama sayısı, motor devri / vitesi / yükü ölçülür,
## Ambience bus'ı WAV'a kaydedilir (dinleme), arada kare çekilir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/superarac_gazlama_qa.gd --resolution 1152x648
## Çıktı: /home/burak/Projects/ct_shots/gazlama/

const OUT: String = "/home/burak/Projects/ct_shots/gazlama/"
const CAR: StringName = &"lambo_huracan"
const WATCH: float = 60.0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(5.0).timeout
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	var ambience: CityAmbience = root.find_child("CityAmbience", true, false) as CityAmbience
	traffic._hazard_timer = 9999.0
	var car: TrafficVehicle = null
	while car == null:
		traffic.request_model(CAR)
		await create_timer(1.0).timeout
		car = traffic.spawn_model(CAR, null)
	print("  ·    %s şehre girdi, en yüksek hız %.2f (trafik %.2f–%.2f)" % [CAR, car.max_speed, traffic.min_speed,
		traffic.max_speed])
	var record: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(CityAmbience.BUS), record)
	record.set_recording_active(true)
	var surges: int = 0
	var was: bool = false
	var t: float = 0.0
	var rpm_sum: float = 0.0
	var rpm_n: int = 0
	var slow_rpm: Array[float] = []
	var gears: Dictionary = {}
	var top: float = 0.0
	var shot: int = 0
	var moving_n: int = 0
	var clear_n: int = 0
	var cross_n: int = 0
	while t < WATCH:
		await physics_frame
		t += 1.0 / 60.0
		if not is_instance_valid(car):
			car = null
			while car == null:   # şehirden çıktı: yeniden sokulur
				traffic.request_model(CAR)
				await create_timer(0.5).timeout
				t += 0.5
				car = traffic.spawn_model(CAR, null)
			was = false
			print("  ·    %5.1f sn yeniden girdi" % t)
		if camera:
			camera.follow(car.global_position, 3.2)
		var launching: bool = car.is_launching()
		if launching and not was:
			surges += 1
			print("  ·    %5.1f sn gazlama (hız %.2f)" % [t, car.speed])
		was = launching
		top = maxf(top, car.speed)
		if car.speed > 0.25 and not launching:
			moving_n += 1
			var ahead: float = traffic.distance_to_vehicle_ahead(car)
			if ahead > TrafficVehicle.SURGE_CLEAR:
				clear_n += 1
			if car.get("_in_intersection"):
				cross_n += 1
		var engine: ExoticEngine = null
		if ambience:
			for e: ExoticEngine in ambience.exotic_engines():
				engine = e
		if engine and car.speed > 0.05:
			rpm_sum += engine.rpm()
			rpm_n += 1
			gears[engine.gear() + 1] = int(gears.get(engine.gear() + 1, 0)) + 1
			if car.speed < 0.45:
				slow_rpm.append(engine.rpm())
		if int(t * 60.0) % 600 == 0 and shot < 4:
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(OUT + "kare_%d.png" % shot)
			shot += 1
	record.set_recording_active(false)
	var wav: AudioStreamWAV = record.get_recording()
	if wav:
		wav.save_to_wav(OUT + "huracan_sehir.wav")
	var slow_avg: float = 0.0
	for r: float in slow_rpm:
		slow_avg += r / maxf(slow_rpm.size(), 1.0)
	print("SONUÇ %.0f sn: gazlama %d, en yüksek hız %.2f, ort. devir %.0f, yavaşken (<0,45) ort. devir %.0f (%d kare), vites %s" % [
		t, surges, top, rpm_sum / maxf(rpm_n, 1.0), slow_avg, slow_rpm.size(), gears])
	print("SEYİR %d kare: önü boş %d (%.0f%%), kavşakta %d" % [moving_n, clear_n, 100.0 * clear_n / maxf(moving_n, 1.0), cross_n])
	quit()
