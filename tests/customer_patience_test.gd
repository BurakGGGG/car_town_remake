extends SceneTree
## MÜŞTERİ SABRI — tamir için 3–4 müşteri bekleyebilir (garaj sv.1–2: 3, sv.3–4: 4); çok bekleyen sabrı bitince gider.
##   - bekleme sınırı / nokta sayısı / trafik payı (bekleyenler trafik sınırına dahil, yol boşalmasın)
##   - sabır yerleşince başlar, son PATIENCE_WARN sn balonda geri sayım, bitince müşteri trafiğe döner (bildirim)
##   - seçiliyken ve eğitim sürerken sabır azalmaz; giden müşteri hemen yeniden seçilmez
## Çalıştırma: tools/run_tests.sh customer_patience_test (pencereli: trafik modelleri arka planda yüklenir)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var hud: Hud = main.find_child("HUD", true, false)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	rm.customer_interval_min = 999.0   # kendiliğinden müşteri gelmesin: test kendisi kurar
	rm.customer_interval_max = 999.0
	rm._customer_timer = 999.0

	print("== BEKLEME SINIRI ==")
	var waits: Array[int] = []
	for row: Dictionary in RepairManager.SUPPLY:
		waits.append(int(row["waiting"]))
	check(waits == [3, 3, 4, 4], "garaj seviyesine göre 3–4 müşteri bekleyebilir (%s)" % [waits])
	check(rm.waiting_limit() == 3 and rm.active_wait_spots().size() == 3, "sv.1: 3 müşteri, 3 nokta")
	check(traffic.max_vehicles == RepairManager.traffic_limit(RepairManager.SUPPLY[0]) and traffic.max_vehicles == 5,
		"bekleyenler için trafik payı: 4 + 1 = %d" % traffic.max_vehicles)

	print("== SABIR ==")
	for i: int in 600:
		if not traffic.vehicles.is_empty():
			break
		await process_frame
	var car: TrafficVehicle = traffic.vehicles[0] if not traffic.vehicles.is_empty() else null
	check(car != null, "trafikte araç var")
	if car == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	var spot: Node3D = rm.repair_wait_spots[0]
	car.global_position = Vector3(spot.global_position.x + 0.7, car.global_position.y, 0.3)   # batıya giden şerit
	car.global_rotation.y = spot.global_rotation.y
	if not car.customer_stopped.is_connected(rm._on_customer_stopped):
		car.customer_stopped.connect(rm._on_customer_stopped)
	car.request_repair(spot, RepairType.defaults()[0])
	for i: int in 900:
		if car.is_waiting():
			break
		await physics_frame
	check(car.is_waiting(), "müşteri bekleme noktasına yerleşti")
	check(car.patience >= RepairManager.CUSTOMER_PATIENCE.x and car.patience <= RepairManager.CUSTOMER_PATIENCE.y,
		"sabrı başladı (%.0f sn)" % car.patience)
	car.patience = RepairManager.PATIENCE_WARN - 0.5
	await frames(3)
	check(car._bubble._label.visible and car._bubble._label.text == "0:20", "son 20 sn balonda geri sayım («%s»)" % car._bubble._label.text)

	CarHitboxScript.set(&"selected_car", car)
	await frames(3)
	var held: float = car.patience
	await create_timer(0.6).timeout
	check(rm.get_target() == car and is_equal_approx(car.patience, held), "plakası açıkken sabır azalmaz")
	CarHitboxScript.call(&"clear_selection", self)
	await frames(3)

	var director: Node = get_first_node_in_group("tutorial_director")
	if director:
		var state: StringName = director.get(&"_state")
		director.set(&"_state", &"step")
		var before: float = car.patience
		rm._tick_patience(1.0)
		check(is_equal_approx(car.patience, before), "eğitim sürerken sabır azalmaz")
		director.set(&"_state", state)

	var left: Array[Node3D] = []
	rm.customer_left.connect(func(c: Node3D) -> void: left.append(c))
	car.patience = 0.25
	await create_timer(0.6).timeout
	check(left.size() == 1 and left[0] == car, "sabrı biten müşteri gitti (customer_left)")
	check(car.mode == TrafficVehicle.Mode.TRAFFIC and car.fault == null and car.repair_status == TrafficVehicle.RepairStatus.NORMAL,
		"trafiğe döndü, arızası sıfırlandı")
	check(not car.bubble_visible() and car.wait_spot() == null, "balon kapandı, nokta boşaldı")
	var noticed: bool = hud._notice_label.text == "MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ"
	for queued: Dictionary in hud._notice_queue:   # başka bildirim oynuyorsa sırada bekler
		noticed = noticed or String(queued["text"]) == "MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ"
	check(noticed, "bildirim: MÜŞTERİ BEKLEMEKTEN SIKILIP GİTTİ")
	var picked_again: bool = false
	for option: Dictionary in rm._candidates():
		picked_again = picked_again or option["vehicle"] == car
	check(car.busy_after_race() and not picked_again, "giden müşteri hemen yeniden müşteri seçilmez")
	var start: Vector3 = car.global_position
	await create_timer(1.5).timeout
	check(car.global_position.distance_to(start) > 0.3, "kaldırımdan çıkıp yola koyuldu")

	print("== ÇIKIŞ: öndeki bekleyenlerin içinden geçmez ==")
	# Kullanıcı bildirdi (2026-10-17): sıkılan müşteri uzaktaki yol noktasına paralel gidip öndekilerin içinden geçiyordu.
	for i: int in 900:
		if traffic.vehicles.size() >= 4:
			break
		await process_frame
	var line: Array[TrafficVehicle] = []
	for v: TrafficVehicle in traffic.vehicles:
		if v != car and line.size() < 3 and v.mode == TrafficVehicle.Mode.TRAFFIC and not v.race_lane \
				and v.repair_status == TrafficVehicle.RepairStatus.NORMAL:
			line.append(v)
			v.target = null   # yerinde kalsın; request_repair kendi noktasına götürür
			if not v.customer_stopped.is_connected(rm._on_customer_stopped):
				v.customer_stopped.connect(rm._on_customer_stopped)   # sabrı başlasın (yoksa 0'da kalıp hemen gider)
	check(line.size() == 3, "kaldırım için 3 araç")
	if line.size() == 3:
		for i: int in 3:
			var s: Node3D = rm.repair_wait_spots[i]
			line[i].global_position = Vector3(s.global_position.x + 0.6, line[i].global_position.y, 0.3)
			line[i].global_rotation.y = s.global_rotation.y
			line[i].request_repair(s, RepairType.defaults()[i])
		var all_waiting: Callable = func() -> bool:
			return line.all(func(v: TrafficVehicle) -> bool: return is_instance_valid(v) and v.is_waiting())
		for i: int in 900:
			if all_waiting.call():
				break
			await physics_frame
		check(all_waiting.call(), "3 müşteri kaldırımda bekliyor")
		if not all_waiting.call():
			for v: TrafficVehicle in line:
				if is_instance_valid(v):
					print("    %s kip %d konum (%.2f, %.2f) hız %.2f vardı %s önde %.2f" % [v.vehicle_id, v.mode,
						v.global_position.x, v.global_position.z, v.speed, v._arrived, traffic.distance_to_vehicle_ahead(v)])
				else:
					print("    (silinmiş)")
			print("RESULT fails=%d" % fails)
			quit(1)
			return
		rm._dismiss_customer(line[0])   # en arkadaki gider: önünde iki bekleyen var
		var worst: float = 0.0
		for f: int in 240:
			await physics_frame
			if not is_instance_valid(line[0]):
				break
			for other: TrafficVehicle in [line[1], line[2]]:
				worst = maxf(worst, _overlap(_footprint(line[0]), _footprint(other)))
		check(worst == 0.0, "giden müşteri öndekilere binmedi (en derin %.3f)" % worst)
		check(is_instance_valid(line[0]) and not line[0]._merging and line[0].global_position.z > 0.2,
			"şeride çıktı ve şeritte sürüyor (z %.2f)" % (line[0].global_position.z if is_instance_valid(line[0]) else -1.0))

		print("== SIRA: iki müşteri aynı anda sıkılıp gitmez ==")
		# Kullanıcı bildirdi (2026-10-19): aynı anda çıkan iki müşteri birbirini ve trafiği kilitliyordu.
		var pair: Array[TrafficVehicle] = [line[1], line[2]]
		for v: TrafficVehicle in pair:
			v.patience = RepairManager.PATIENCE_WARN + 0.05
		rm._tick_patience(0.1)
		var counting: Array = pair.filter(func(v: TrafficVehicle) -> bool: return v.patience < RepairManager.PATIENCE_WARN)
		var held_back: Array = pair.filter(func(v: TrafficVehicle) -> bool: return is_equal_approx(v.patience, RepairManager.PATIENCE_WARN))
		check(counting.size() == 1 and held_back.size() == 1, "aynı anda gelen iki geri sayımdan biri başladı, diğeri 0:20'de bekliyor")
		var waited: float = 0.0
		while held_back.size() == 1 and is_equal_approx((held_back[0] as TrafficVehicle).patience, RepairManager.PATIENCE_WARN) \
				and waited < 10.0:
			rm._tick_patience(0.5)
			waited += 0.5
		check(waited >= RepairManager.COUNTDOWN_GAP - 0.1 and waited <= RepairManager.COUNTDOWN_GAP + 0.6,
			"ikinci geri sayım %.1f sn sonra başladı (en az %.0f)" % [waited, RepairManager.COUNTDOWN_GAP])
		var gone: Array[Node3D] = []
		rm.customer_left.connect(func(c: Node3D) -> void: gone.append(c))
		for v: TrafficVehicle in pair:
			v.patience = 0.05   # seçiliyken durmuş bir sayım öbürüyle aynı anda bitebilir: gidişte de sıra var
		rm._tick_patience(0.1)
		check(gone.size() == 1 and pair.filter(func(v: TrafficVehicle) -> bool: return v.is_waiting()).size() == 1,
			"aynı anda biten iki sayımdan yalnızca biri gitti")
		rm._tick_patience(RepairManager.COUNTDOWN_GAP - 0.5)
		check(gone.size() == 1, "öteki son gidişten %.0f sn geçmeden gitmez" % RepairManager.COUNTDOWN_GAP)
		rm._tick_patience(0.6)
		check(gone.size() == 2, "aralık dolunca öteki de gitti")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Araç taban dikdörtgeni (dünya XZ; CarHitbox kutusu).
func _footprint(v: TrafficVehicle) -> Dictionary:
	var shape: CollisionShape3D = v.get_node("CarHitbox/CollisionShape3D") as CollisionShape3D
	var size: Vector3 = (shape.shape as BoxShape3D).size
	var c: Vector3 = v.global_transform * shape.position
	var bx: Vector3 = v.global_transform.basis.x
	var bz: Vector3 = v.global_transform.basis.z
	return {"c": Vector2(c.x, c.z), "ax": Vector2(bx.x, bx.z).normalized(), "az": Vector2(bz.x, bz.z).normalized(),
		"hx": size.x * 0.5 * Vector2(bx.x, bx.z).length(), "hz": size.z * 0.5 * Vector2(bz.x, bz.z).length()}


## İki dönük dikdörtgenin kesişme derinliği (ayırıcı eksen); kesişmiyorsa 0.
func _overlap(a: Dictionary, b: Dictionary) -> float:
	var depth: float = INF
	for axis: Vector2 in [a["ax"], a["az"], b["ax"], b["az"]]:
		var ra: float = absf((a["ax"] as Vector2).dot(axis)) * a["hx"] + absf((a["az"] as Vector2).dot(axis)) * a["hz"]
		var rb: float = absf((b["ax"] as Vector2).dot(axis)) * b["hx"] + absf((b["az"] as Vector2).dot(axis)) * b["hz"]
		var o: float = ra + rb - absf(((b["c"] as Vector2) - (a["c"] as Vector2)).dot(axis))
		if o <= 0.0:
			return 0.0
		depth = minf(depth, o)
	return depth
