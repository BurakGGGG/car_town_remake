extends SceneTree
## TRAFİK SESLERİ + DÖRTLÜ (2026-10-20) — kullanıcı: "araç seslerini çeşitlendir ve daha da güzel olsun. sokakta
## trafikte bazen korna sesleri olsun. araçlar bazı yerlerde durup dörtlü yaksınlar 3 5 saniye sonra devam etsinler.
## nadir olarak". Denetlenen: motor tipi ataması (katalog), tip başına döngü ve korna takımı, motor sürüşü (rölanti,
## vites, elektrikli sessizliği, uzak / kontak kapalı susma), şehirde her araca motor + boyuna göre lastik, duyulan
## motor sınırı, aracın kendi kornası ve korna aralığı, bağlamlı korna (dörtlü yakmış aracın arkasındaki), dörtlü
## (durur, ışıklar yanar, süre bitince söner ve devam eder, kavşak çıkışına yakınken durmaz), dörtlü köşeleri.
## Çalıştırma: tools/run_tests.sh traffic_sound_test (pencereli: araç modelleri arka planda yüklenir)

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func wait_until(cond: Callable, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		left -= 0.1
	return cond.call()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== motor tipi (cars.json) ==")
	var expected: Dictionary = {
		&"tofas_sahin": TrafficEngine.Kind.CLASSIC, &"renault_toros": TrafficEngine.Kind.CLASSIC,
		&"togg_t10x": TrafficEngine.Kind.ELECTRIC, &"tesla_model_y": TrafficEngine.Kind.ELECTRIC,
		&"toyota_corolla": TrafficEngine.Kind.ELECTRIC, &"mercedes_sprinter": TrafficEngine.Kind.VAN,
		&"ford_transit": TrafficEngine.Kind.VAN, &"hyundai_getz": TrafficEngine.Kind.DIESEL,
		&"vw_passat_b55": TrafficEngine.Kind.DIESEL, &"chevrolet_camaro": TrafficEngine.Kind.V8,
		&"mercedes_g": TrafficEngine.Kind.V8, &"bmw_e46": TrafficEngine.Kind.SIX, &"mercedes_cls": TrafficEngine.Kind.SIX,
		&"vw_golf_7": TrafficEngine.Kind.SMALL, &"opel_corsa": TrafficEngine.Kind.SMALL, &"audi_a6": TrafficEngine.Kind.FAMILY,
	}
	for id: StringName in expected:
		check(TrafficEngine.kind_of(id) == expected[id], "%s → %s (%s)" % [id, TrafficEngine.Kind.keys()[expected[id]],
			TrafficEngine.Kind.keys()[TrafficEngine.kind_of(id)]])
	var used: Dictionary = {}
	for entry: Dictionary in CarCatalog.all():
		if entry["traffic"]:
			used[TrafficEngine.kind_of(entry["id"])] = true
	check(used.size() == TrafficEngine.Kind.size(), "trafikte bütün motor tipleri var (%d / %d)" % [used.size(), TrafficEngine.Kind.size()])
	check(TrafficEngine.horn_kind(TrafficEngine.Kind.CLASSIC) == TrafficEngine.Horn.OLD
		and TrafficEngine.horn_kind(TrafficEngine.Kind.VAN) == TrafficEngine.Horn.VAN
		and TrafficEngine.horn_kind(TrafficEngine.Kind.ELECTRIC) == TrafficEngine.Horn.CLEAN, "korna motor tipine göre")

	print("== sentez ==")
	for kind: int in TrafficEngine.Kind.values():
		var loop: AudioStreamWAV = TrafficEngine.make_stream(kind as TrafficEngine.Kind)
		var count: int = loop.data.size() / 2
		var seam: float = absf(loop.data.decode_s16(0) - loop.data.decode_s16((count - 1) * 2)) / 32768.0
		check(loop.loop_mode == AudioStreamWAV.LOOP_FORWARD and loop.loop_end == count and seam < 0.2,
			"%s döngüsü dikişsiz (%.3f)" % [TrafficEngine.Kind.keys()[kind], seam])
	for horn: int in TrafficEngine.Horn.values():
		var streams: Array[AudioStreamWAV] = TrafficEngine.horn_streams(horn as TrafficEngine.Horn)
		check(streams.size() == 4 and streams[TrafficEngine.HORN_LONG].get_length() > streams[TrafficEngine.HORN_TAP].get_length(),
			"%s kornası: 4 basış deseni" % TrafficEngine.Horn.keys()[horn])

	print("== motor sürüşü ==")
	var engine: TrafficEngine = TrafficEngine.new()
	engine.setup(null, TrafficEngine.Kind.FAMILY, 1.0, &"Master")
	var base: float = float((TrafficEngine.DRIVES[TrafficEngine.Kind.FAMILY] as Array)[0])
	for i: int in 120:
		engine.drive(0.0, 1.0 / 60.0)
	check(absf(engine.volume_db - (base + TrafficEngine.IDLE_DB)) < 1.0, "rölantide kısık (%.1f dB)" % engine.volume_db)
	var speed: float = 0.0
	var top_gear: int = 0
	var loud: float = -100.0
	for i: int in 240:
		speed = minf(speed + 0.6 / 60.0, 0.8)
		engine.drive(speed, 1.0 / 60.0)
		top_gear = maxi(top_gear, engine.gear())
		loud = maxf(loud, engine.volume_db)
	check(top_gear >= 2, "kalkışta vites büyüdü (%d)" % top_gear)
	check(loud > base, "gaz verirken gürleşti (%.1f dB)" % loud)
	for i: int in 120:
		engine.drive(0.8, 1.0 / 60.0, true, false)
	check(engine.stream_paused or engine.volume_db <= TrafficEngine.SILENT_DB + 0.5, "uzaktaki motor susar")
	engine.free()
	var ev: TrafficEngine = TrafficEngine.new()
	ev.setup(null, TrafficEngine.Kind.ELECTRIC, 1.0, &"Master")
	for i: int in 120:
		ev.drive(0.0, 1.0 / 60.0)
	check(ev.volume_db <= TrafficEngine.SILENT_DB + 0.5, "elektrikli dururken sessiz")
	var low_pitch: float = 0.0
	for i: int in 120:
		ev.drive(0.3, 1.0 / 60.0)
	low_pitch = ev.pitch_scale
	for i: int in 120:
		ev.drive(0.8, 1.0 / 60.0)
	check(ev.pitch_scale > low_pitch, "elektrikli vınlama hızla incelir (%.2f → %.2f)" % [low_pitch, ev.pitch_scale])
	ev.free()

	print("== şehirde ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	check(traffic != null, "TrafficManager bulundu")
	if traffic == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	traffic._hazard_timer = 9999.0   # dörtlüyü test başlatır
	var ambience: CityAmbience = traffic.ambience
	check(await wait_until(func() -> bool: return ambience.is_running(), 20.0), "şehir sesleri çalışıyor")
	check(await wait_until(func() -> bool: return ambience.traffic_engines().size() >= 3, 25.0),
		"trafik araçlarına motor kuruldu (%d)" % ambience.traffic_engines().size())
	await create_timer(1.0).timeout
	check(ambience.audible_engine_count() <= CityAmbience.ENGINE_VOICES,
		"duyulan motor sınırı (%d / %d)" % [ambience.audible_engine_count(), CityAmbience.ENGINE_VOICES])
	check(_tire_of(&"mercedes_sprinter") == "tire_big" and _tire_of(&"hyundai_getz") == "tire_small"
		and _tire_of(&"vw_golf_7") == "tire", "lastik sesi araç boyuna göre")

	print("-- korna --")
	var car: TrafficVehicle = traffic.vehicles[0] if not traffic.vehicles.is_empty() else null
	check(car != null, "yolda araç var")
	if car:
		ambience._last_honk = -100.0
		check(ambience.honk_from(car, TrafficEngine.HORN_DOUBLE), "araç kendi kornasını çaldı")
		var horn: TrafficEngine.Horn = TrafficEngine.horn_kind(TrafficEngine.kind_of(car.vehicle_id))
		var expected_stream: AudioStreamWAV = ((CityAmbience._bank["car_horns"] as Dictionary)[horn] as Array)[TrafficEngine.HORN_DOUBLE]
		var playing: bool = false
		for player: AudioStreamPlayer3D in ambience._horns:
			playing = playing or player.stream == expected_stream
		check(playing, "çalan korna aracın tipinin kornası (%s)" % TrafficEngine.Horn.keys()[horn])
		check(not ambience.honk_from(car, TrafficEngine.HORN_TAP), "kornalar arası en az %.1f sn" % CityAmbience.HONK_SPACING)

	print("-- dörtlü --")
	check(await wait_until(func() -> bool: return not traffic.chase.is_active(), 90.0), "kovalamaca yok (dörtlü kovalamacada olmaz)")
	var picked: Array[TrafficVehicle] = []   # lambda yereli kopyalar: seçilen araç dizide
	check(await wait_until(func() -> bool:
		for vehicle: TrafficVehicle in traffic.vehicles:
			if vehicle.can_hazard_stop():
				picked.append(vehicle)
				return true
		return false, 30.0), "dörtlü için uygun araç")
	var hazard: TrafficVehicle = picked[0] if not picked.is_empty() else null
	if hazard:
		check(traffic.start_hazard(hazard) == hazard and hazard.hazards_on(), "dörtlü yandı (%s)" % hazard.vehicle_id)
		check(not hazard.can_hazard_stop(), "dörtlü sürerken yeniden seçilmez")
		check(await wait_until(func() -> bool: return hazard.is_hazard_stopped(), 4.0), "araç durdu")
		var corners: PackedVector3Array = HazardLights.corners(hazard.model, hazard.rig)
		check(corners.size() == 4 and corners[0].z > corners[2].z and corners[0].x < corners[1].x,
			"dört köşe: önde ikisi, arkada ikisi (%s)" % [corners])
		# Bağlamlı korna: arkadaki araç sıkışınca (eşik geçti) korna çalar
		var follower: TrafficVehicle = null
		for vehicle: TrafficVehicle in traffic.vehicles:
			if vehicle != hazard and ambience._tires.has(vehicle):
				follower = vehicle
				break
		if follower:
			ambience._last_honk = -100.0
			follower.leader = hazard
			follower.stuck_time = 5.0
			(ambience._tires[follower] as Dictionary)["honk_at"] = 0.5
			ambience._context_honks()
			check(float((ambience._tires[follower] as Dictionary)["honk_at"]) == INF and ambience._clock - ambience._last_honk < 0.1,
				"dörtlü yakmış aracın arkasındaki araç korna çaldı")
		check(await wait_until(func() -> bool: return not hazard.hazards_on() and hazard.speed > 0.1, 8.0),
			"süre bitince dörtlü söndü ve devam etti")
		hazard._last_exit = hazard.global_position
		check(not hazard.can_hazard_stop(), "kavşak çıkışına yakınken durmaz")
	print("-- süper araç kalkışı --")
	var dice: TrafficVehicle = TrafficVehicle.new()
	dice.vehicle_id = &"lambo_huracan"
	var hits: int = 0
	for i: int in 4000:
		hits += 1 if dice.roll_launch() else 0
	check(absf(hits / 4000.0 - TrafficVehicle.LAUNCH_CHANCE) < 0.03, "egzotik yeşilde %%%.0f gaza basar (%d / 4000)"
		% [TrafficVehicle.LAUNCH_CHANCE * 100.0, hits])
	dice.vehicle_id = &"vw_golf_7"
	var normal_hits: int = 0
	for i: int in 400:
		normal_hits += 1 if dice.roll_launch() else 0
	check(normal_hits == 0, "normal araç gaza basmaz")
	dice.free()
	var branch: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.waypoints:
		if point.get_next().size() > 1 and traffic.previous_waypoint(point) != null:
			branch = point
			break
	if branch:
		var dir: Vector3 = branch.global_position - traffic.previous_waypoint(branch).global_position
		dir.y = 0.0
		var probe: TrafficVehicle = TrafficVehicle.new()
		traffic.add_child(probe)
		probe.set_physics_process(false)
		probe.global_transform = Transform3D(Basis.looking_at(dir.normalized(), Vector3.UP, true), branch.global_position)
		var straight: TrafficWaypoint = probe._straightest(branch)
		var to_next: Vector3 = straight.global_position - branch.global_position
		to_next.y = 0.0
		check(dir.normalized().dot(to_next.normalized()) > 0.9, "kalkışta kavşaktan düz geçer (%s → %s)" % [branch.name, straight.name])
		probe.queue_free()
	else:
		print("  ·    şehirde dallanan kavşak yok: bütün yollar düz (kalkış zaten dümdüz)")
	var chirps: Array[int] = [0]   # lambda yereli kopyalar: sayaç dizide
	traffic.vehicle_launched.connect(func(_v: TrafficVehicle) -> void: chirps[0] += 1)
	var best: float = 0.0
	var racer: TrafficVehicle = null
	for attempt: int in 3:
		racer = null
		await wait_until(func() -> bool:
			for vehicle: TrafficVehicle in traffic.vehicles:
				if vehicle.mode == TrafficVehicle.Mode.TRAFFIC and vehicle.can_hazard_stop() \
						and traffic.distance_to_vehicle_ahead(vehicle) > 5.0:
					picked.clear()
					picked.append(vehicle)
					return true
			return false, 20.0)
		racer = picked[0] if not picked.is_empty() else null
		if racer == null:
			continue
		var normal: float = racer.max_speed
		racer.start_launch()
		for i: int in 120:
			await physics_frame
			if not is_instance_valid(racer):
				break   # hızlanan araç harita kenarına varıp silindi
			best = maxf(best, racer.speed)
		if best > normal * 1.6:
			break
	check(best > 0.8 * 1.6, "kalkışta hızla gider (en çok %.2f birim/sn, normal 0,8)" % best)
	check(chirps[0] >= 1, "kalkışta lastik cıyağı çaldı")
	# Araç şehirden çıkınca silinir: lambda nesneyi değil zayıf başvuruyu yakalar ("Lambda capture … was freed" hatası)
	var racer_ref: WeakRef = weakref(racer)
	check(await wait_until(func() -> bool:
		var alive: Variant = racer_ref.get_ref()
		return alive == null or not alive.is_launching(), 8.0),
		"kalkış biter (ya da araç şehirden çıkar)")
	if is_instance_valid(racer):
		check(await wait_until(func() -> bool:
			var alive: Variant = racer_ref.get_ref()
			return alive == null or alive.speed <= alive.max_speed + 0.05, 5.0),
			"normal hıza süzülür")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Lastik çeşidi (yalnız vehicle_id'ye bakar: sahnesiz araç yeter).
func _tire_of(id: StringName) -> String:
	var vehicle: TrafficVehicle = TrafficVehicle.new()
	vehicle.vehicle_id = id
	var key: String = CityAmbience._tire_key(vehicle)
	vehicle.free()
	return key
