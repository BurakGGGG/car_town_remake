extends SceneTree
## SÜPER ARAÇ KALKIŞI QA (TrafficVehicle.start_launch): Huracán şehre sokulur (kalkış olasılığı 1), kırmızıda en önde
## durması beklenir (yeşilde geçerse yeniden sokulur); yeşilde gaza basıp hızlandığını denetler, kalkış anında ve
## hemen sonra kare çeker, Ambience bus'ını kaydeder (motor tam gaz + vites + lastik cıyağı).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/superarac_kalkis_qa.gd --display-driver x11 --resolution 1152x648 --audio-driver Dummy
## Çıktı: /home/burak/Projects/ct_shots/kalkis/

const OUT: String = "/home/burak/Projects/ct_shots/kalkis/"
const CAR: StringName = &"lambo_huracan"

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
	await create_timer(5.0).timeout
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	traffic._hazard_timer = 9999.0
	var record: AudioEffectRecord = AudioEffectRecord.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index(CityAmbience.BUS), record)
	var launched: Array[TrafficVehicle] = []   # lambda yereli kopyalar: dizide
	traffic.vehicle_launched.connect(func(v: TrafficVehicle) -> void: launched.append(v))
	var car: TrafficVehicle = null
	var t0: int = Time.get_ticks_msec()
	while launched.is_empty() and Time.get_ticks_msec() - t0 < 150000:
		if car == null or not is_instance_valid(car):
			traffic.request_model(CAR)
			await create_timer(1.0).timeout
			car = traffic.spawn_model(CAR, null)
			if car:
				car.launch_chance = 1.0
				print("  ·    %s şehre girdi" % CAR)
			continue
		if camera:
			camera.follow(car.global_position, 3.2)
		if car.get("_light_stop") and not record.is_recording_active():
			print("  ·    kırmızıda en önde duruyor")
			record.set_recording_active(true)
		await physics_frame
	check(not launched.is_empty(), "süper araç yeşilde gaza bastı")
	if launched.is_empty():
		quit(1)
		return
	car = launched[0]
	for i: int in 24:   # kalkıştan sonraki ilk saniyeler (teşhis)
		if not is_instance_valid(car):
			print("  ·    araç silindi")
			break
		if i % 4 == 0:
			print("  ·    %.2f sn  hız %.2f  kalkış %s  ışık bekliyor %s  konum %s" % [i / 60.0, car.speed, car.is_launching(),
				car.waiting_light, car.global_position])
		if camera:
			camera.follow(car.global_position, 3.2)
		await physics_frame
	await _shot("kalkis_1.png")
	var top: float = 0.0
	for i: int in 50:
		if not is_instance_valid(car):
			break
		top = maxf(top, car.speed)
		if camera:
			camera.follow(car.global_position, 3.2)
		await physics_frame
	await _shot("kalkis_2.png")
	check(top > 1.4, "hızla kalktı (en çok %.2f birim/sn)" % top)
	await create_timer(2.5).timeout
	record.set_recording_active(false)
	var wav: AudioStreamWAV = record.get_recording()
	if wav:
		wav.save_to_wav(OUT + "kalkis.wav")
		print("  ·    ses %.1f sn → %skalkis.wav" % [wav.get_length(), OUT])
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
