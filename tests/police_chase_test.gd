extends SceneTree
## POLİS KOVALAMACASI (traffic/police_chase.gd): polis araçları edinilemez (kasa / koleksiyon / trafik / rakip
## dışında); zamanlayıcı ilk 15 sn, sonra 2 dakika; kovalamaca araçları trafik listesine girmez ve seçilemez; şüpheli trafikten
## çok hızlı, polis şüpheliden hızlı ve aradaki mesafe kapanıyor ama polis asla çarpmıyor; şeritteki araç sağa
## çekilip yavaşlayarak yol veriyor ve sonra şeridine dönüyor; kavşakta karşı eksen bekliyor; siren polisle
## çalıyor ve kovalamaca bitince her şey temizleniyor.
## Çalıştırma: tools/run_tests.sh police_chase_test (pencereli: traffic_pool_test ile aynı gerekçe)

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


func _find_traffic(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== katalog: polis edinilemez ==")
	for id: StringName in PoliceChase.POLICE_IDS:
		var entry: Dictionary = CarCatalog.get_entry(id)
		check(not entry.is_empty() and not CarCatalog.is_obtainable(id) and not bool(entry["traffic"]),
			"%s: edinilemez, normal trafiğe kapalı" % id)
		check(not VehicleOwnership.collection_ids().has(id), "%s koleksiyonda yok" % id)
		check(CrateCatalog.crate_of(id) == &"", "%s hiçbir kasada yok" % id)
		var in_set: bool = false
		for set_entry: Dictionary in CrateCatalog.sets():
			in_set = in_set or (set_entry["cars"] as Array).has(id)
		check(not in_set, "%s hiçbir sette yok" % id)
	var rival_leak: bool = false
	for entry: Dictionary in CarCatalog.all():
		if CarCatalog.is_obtainable(entry["id"]):
			for id: StringName in RaceManager.rival_pool(entry["id"]):
				rival_leak = rival_leak or not CarCatalog.is_obtainable(id)
	check(not rival_leak, "hiçbir aracın yarış rakibi havuzunda polis yok")
	check(CarCatalog.is_obtainable(&"togg_t10x"), "normal araç edinilebilir")

	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var traffic: TrafficManager = _find_traffic(main)
	check(traffic != null and traffic.chase != null, "TrafficManager kovalamacayı kurdu")
	if traffic == null or traffic.chase == null:
		_finish()
		return
	var chase: PoliceChase = traffic.chase
	check(chase.time_left() > 0.0 and chase.time_left() <= 15.0, "ilk kovalamaca açılıştan 15 sn sonra (%.1f sn kaldı)" % chase.time_left())
	chase._timer = 9999.0   # kendiliğinden başlamasın: kovalamacayı test kendisi başlatır
	traffic.max_vehicles = 0
	for v: TrafficVehicle in traffic.vehicles.duplicate():
		traffic._on_vehicle_despawn(v)
	check(await wait_until(func() -> bool: return not traffic.city_model_ids().is_empty(), 20.0), "şehir havuzu yüklendi")
	check(not traffic.city_model_ids().has(&"police_vito") and not traffic.city_model_ids().has(&"police_bentley"),
		"polis şehir havuzunda yok")

	print("== kovalamaca ==")
	var lane: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.spawn_points:
		if point.name == &"W_in_spawn":
			lane = point
	check(lane != null, "batıdan doğuya şerit bulundu")
	# Şeritte, kovalamacanın önünde yavaş giden normal bir araç
	var car: TrafficVehicle = traffic._spawn_at(lane)
	car.global_position = Vector3(-2.4, car.global_position.y, lane.global_position.z)
	car.max_speed = 0.55
	var free_speed: float = car.max_speed
	check(chase.start_now(lane, &"police_vito"), "kovalamaca başladı (Vito)")
	var suspect: TrafficVehicle = chase.suspect()
	check(suspect != null and suspect.is_chasing() and not traffic.vehicles.has(suspect), "şüpheli kovalamaca kipinde, trafik listesinde değil")
	var hitbox: StaticBody3D = suspect.get_node_or_null("CarHitbox") as StaticBody3D if suspect else null
	check(hitbox == null or not hitbox.input_ray_pickable, "kovalamaca aracı seçilemez")
	check(chase.holds_crossing(1) and not chase.holds_crossing(0), "kavşakta karşı eksen bekliyor, kovalamaca ekseni geçiyor")

	Engine.time_scale = 2.0
	var gaps: Array[float] = []
	var suspect_speed: float = 0.0
	var police_speed: float = 0.0
	var max_shift: float = 0.0
	var min_car_speed: float = INF
	var closest_pass: float = INF
	var siren_ok: bool = false
	var last_suspect: float = 0.0
	var last_police: float = -1.0
	var frames_run: int = 0
	while chase.is_active() and frames_run < 3000:
		await physics_frame
		frames_run += 1
		var s: TrafficVehicle = chase.suspect()
		var p: TrafficVehicle = chase.police()
		if s and p:
			gaps.append(s.chase_distance - p.chase_distance)
			if last_police >= 0.0:
				suspect_speed += s.chase_distance - last_suspect
				police_speed += p.chase_distance - last_police
			last_police = p.chase_distance
			siren_ok = siren_ok or chase.get_node("PoliceSiren").is_playing()
		if s:
			last_suspect = s.chase_distance
		if is_instance_valid(car):
			max_shift = maxf(max_shift, car.yield_shift())
			for other: TrafficVehicle in chase.vehicles():
				var d: Vector3 = other.global_position - car.global_position
				if absf(d.x) < 0.45:
					closest_pass = minf(closest_pass, absf(d.z))
			if max_shift > 0.04:
				min_car_speed = minf(min_car_speed, car.speed)
	Engine.time_scale = 1.0
	check(not chase.is_active(), "kovalamaca bitti (%d kare)" % frames_run)
	check(gaps.size() > 10 and gaps[gaps.size() - 1] < gaps[0] - 1.0, "polis yaklaştı: mesafe %.2f → %.2f" % [
		gaps[0] if not gaps.is_empty() else -1.0, gaps[gaps.size() - 1] if not gaps.is_empty() else -1.0])
	check(not gaps.is_empty() and gaps.min() >= PoliceChase.GAP_END - 0.01, "polis hiçbir an şüpheliye çarpmadı (en az %.2f)" % (gaps.min() if not gaps.is_empty() else -1.0))
	check(police_speed > suspect_speed * 1.05, "polis şüpheliden hızlı")
	check(PoliceChase.SUSPECT_SPEED > traffic.max_speed * 2.0, "şüpheli normal trafiğin iki katından hızlı")
	check(siren_ok, "polis yoldayken siren çaldı")
	check(max_shift > 0.06, "şeritteki araç sağa çekildi (%.3f)" % max_shift)
	check(min_car_speed < free_speed * 0.6, "yol verirken yavaşladı (%.2f)" % min_car_speed)
	check(closest_pass >= 0.3, "kovalamaca aracı yol veren aracın yanından açıklıkla geçti (%.2f)" % closest_pass)
	check(chase.vehicles().is_empty() and not chase.get_node("PoliceSiren").is_playing(), "kovalamaca araçları silindi, siren sustu")
	check(is_equal_approx(chase.time_left(), 120.0), "sıradaki kovalamaca 2 dakika sonra (%.1f sn)" % chase.time_left())
	await create_timer(1.5).timeout
	check(is_instance_valid(car) and car.yield_shift() < 0.01, "yol veren araç şeridine döndü")
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
