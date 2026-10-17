extends SceneTree
## SIKILAN MÜŞTERİNİN ÇIKIŞI — kaldırımda 4 müşteri dizilir; önce en arkadaki, sonra ortadaki sabrını yitirip yola
## çıkar. Her fizik karesinde ayrılan aracın taban kutusu (CarHitbox) bekleyenlerinkiyle kesişiyor mu ölçülür
## (dönük dikdörtgen, ayırıcı eksen): en derin giriş + kaç kare. Kullanıcı: "sıkılan NPC diğer bekleyenlerin içinden geçiyor".
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/musteri_cikis_qa.gd --display-driver x11 --resolution 1440x810
## Görüntü: ~/Projects/ct_shots/sehir/musteri_cikis_*.png

const OUT: String = "/home/burak/Projects/ct_shots/sehir/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


## Taban dikdörtgeni (dünya XZ): merkez, iki eksen, yarı boylar.
func footprint(car: TrafficVehicle) -> Dictionary:
	var shape: CollisionShape3D = car.get_node("CarHitbox/CollisionShape3D") as CollisionShape3D
	var size: Vector3 = (shape.shape as BoxShape3D).size
	var center3: Vector3 = car.global_transform * shape.position
	var bx: Vector3 = car.global_transform.basis.x
	var bz: Vector3 = car.global_transform.basis.z
	return {"c": Vector2(center3.x, center3.z), "ax": Vector2(bx.x, bx.z).normalized(), "az": Vector2(bz.x, bz.z).normalized(),
		"hx": size.x * 0.5 * Vector2(bx.x, bx.z).length(), "hz": size.z * 0.5 * Vector2(bz.x, bz.z).length()}


## Kesişme derinliği (ayırıcı eksenlerde en küçük örtüşme); kesişmiyorsa 0.
func overlap(a: Dictionary, b: Dictionary) -> float:
	var depth: float = INF
	for axis: Vector2 in [a["ax"], a["az"], b["ax"], b["az"]]:
		var ra: float = absf((a["ax"] as Vector2).dot(axis)) * a["hx"] + absf((a["az"] as Vector2).dot(axis)) * a["hz"]
		var rb: float = absf((b["ax"] as Vector2).dot(axis)) * b["hx"] + absf((b["az"] as Vector2).dot(axis)) * b["hz"]
		var dist: float = absf(((b["c"] as Vector2) - (a["c"] as Vector2)).dot(axis))
		var o: float = ra + rb - dist
		if o <= 0.0:
			return 0.0
		depth = minf(depth, o)
	return depth


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	rm._customer_timer = 999.0
	traffic.chase._timer = 99999.0
	traffic.max_vehicles = 8
	(current_scene.find_child("HUD", true, false) as CanvasLayer).visible = false
	var count: int = mini(4, rm.repair_wait_spots.size())
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until and traffic.vehicles.size() < count:
		await process_frame
	var cars: Array[TrafficVehicle] = []
	for i: int in count:
		var car: TrafficVehicle = traffic.vehicles[i]
		var spot: Node3D = rm.repair_wait_spots[i]
		# Son müşteri şeridin gerisinden gelir: dolu noktaların yanından geçip en öndeki noktaya yanaşır
		var start_x: float = spot.global_position.x + 0.6 if i < count - 1 else -1.4
		car.global_position = Vector3(start_x, car.global_position.y, 0.3)
		car.global_rotation.y = spot.global_rotation.y
		car.customer_stopped.connect(rm._on_customer_stopped)
		if i < count - 1:
			car.request_repair(spot, RepairType.defaults()[i % 4])
		cars.append(car)
	until = Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < until and not cars.slice(0, count - 1).all(func(c: TrafficVehicle) -> bool: return c.is_waiting()):
		await process_frame
	# YANAŞMA (oyunun kendi seçimiyle): son araç şeritten gelir. Dolu noktaların ötesindeki nokta ADAY OLMAMALI
	# (RepairManager._path_clear); verilen noktaya yanaşırken hiçbir bekleyene binmemeli.
	var arriving: TrafficVehicle = cars[count - 1]
	var offered: Array = rm._candidates().filter(func(c: Dictionary) -> bool: return c["vehicle"] == arriving) \
		.map(func(c: Dictionary) -> Node3D: return c["spot"])
	print("YANAŞMA adayları (0..%d dolu): %s" % [count - 2, offered.map(func(n: Node3D) -> String: return n.name)])
	var arrive_bad: int = 0
	var arrive_worst: float = 0.0
	if offered.has(rm.repair_wait_spots[count - 1]):
		print("  HATA: dolu noktaların ötesindeki nokta aday")
		arrive_bad += 1
	cars.resize(count - 1)   # yanaşacak araç bu aşamada bekleyen değil; çıkış senaryoları ilk iki aracı kullanır
	arriving.target = null   # çıkış testleri boyunca yerinde beklesin (sürüp yolun ucunda silinmesin)
	arriving.speed = 0.0
	for i: int in cars.size():
		print("bekleme %d: x %.2f z %.2f" % [i, cars[i].global_position.x, cars[i].global_position.z])
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.follow(Vector3(-4.3, 0.0, 0.1), 2.4)
	var total_bad: int = 0
	for leaving: int in [0, 1]:
		var car: TrafficVehicle = cars[leaving]
		rm._dismiss_customer(car)
		var worst: float = 0.0
		var bad: int = 0
		var shot: int = 0
		for f: int in 300:
			await physics_frame
			if not is_instance_valid(car):
				break
			var mine: Dictionary = footprint(car)
			for other: TrafficVehicle in cars:
				if other == car or not is_instance_valid(other) or not other.is_waiting():
					continue
				var depth: float = overlap(mine, footprint(other))
				if depth > 0.0:
					bad += 1
					worst = maxf(worst, depth)
			if f % 30 == 0:
				print("  t=%.1f x %.2f z %.2f hız %.2f çıkışta %s yön %.0f°" % [f / 60.0, car.global_position.x,
					car.global_position.z, car.speed, car._merging, rad_to_deg(car.global_rotation.y)])
			if f % 24 == 0 and shot < 6:
				shot += 1
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png(OUT + "musteri_cikis_%d_%d.png" % [leaving, shot])
		var where: String = "yolun ucunda silindi" if not is_instance_valid(car) else "son konum x %.2f z %.2f" % [
			car.global_position.x, car.global_position.z]
		print("ÇIKIŞ %d (bekleme noktası %d): %d karede bindi, en derin %.3f birim  · %s" % [leaving, leaving, bad, worst, where])
		total_bad += bad
	# Boşalan noktalara gerçek yanaşma: şeritten gelen araç oyunun aday seçimiyle (öndekiler dolu)
	arriving.global_position = Vector3(-1.4, arriving.global_position.y, 0.3)
	arriving.global_rotation.y = rm.repair_wait_spots[0].global_rotation.y
	arriving.target = traffic.nearest_waypoint_ahead(arriving)
	var options: Array = rm._candidates().filter(func(c: Dictionary) -> bool: return c["vehicle"] == arriving)
	if options.is_empty():
		print("YANAŞMA: aday nokta yok")
	else:
		var spot_given: Node3D = options[0]["spot"]
		arriving.request_repair(spot_given, RepairType.defaults()[0])
		for f: int in 900:
			await physics_frame
			if arriving.is_waiting():
				break
			var mine_a: Dictionary = footprint(arriving)
			for other: TrafficVehicle in cars:
				if other != arriving and is_instance_valid(other) and other.is_waiting():
					var d: float = overlap(mine_a, footprint(other))
					if d > 0.0:
						arrive_bad += 1
						arrive_worst = maxf(arrive_worst, d)
		print("YANAŞMA (%s): %d karede bindi, en derin %.3f · bekliyor %s" % [spot_given.name, arrive_bad, arrive_worst,
			arriving.is_waiting()])
	total_bad += arrive_bad
	print("SONUÇ: %s" % ("TEMİZ" if total_bad == 0 else "İÇİNDEN GEÇİYOR (%d kare)" % total_bad))
	quit(0)
