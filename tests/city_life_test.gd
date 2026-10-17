extends SceneTree
## ŞEHİR CANLILIĞI — showroom önündeki kavşağın TRAFİK LAMBALARI, YAYA GEÇİTLERİ ve showroom meydanındaki BILLBOARD.
##   - lamba döngüsü (yeşil → sarı → tüm kırmızı → karşı eksen yeşil), kavşak izni yalnızca yeşilde
##   - kırmızıda araç dur çizgisine göre durur (çoğu çizginin gerisinde, bazısı yaya geçidinde), kavşağa girmez
##   - billboard: günde bir afiş (yerel gece yarısı), afiş dosyaları sıkıştırılmış + mipmap'li, bugünün afişi yüklenir
##   - kavşak çizgileri: tek gövde (alpha scissor atlas), sahnenin eski kare / kenar çizgileri gizli
##   - maliyet: lambalar 7, çizgiler 1, billboard 3 çizim gövdesi (ışık kaynağı yok)
##   - 2026-10-17: kavşak çizgilerinin her üçgeni yukarıdan ön yüz (ters örülen doğu / kuzey kolu mağazadan dönünce
##     simsiyah çiziliyordu) ve şehrin KENDİ ortam ışığı var (yoksa ortam ışığı son çizilen ekrandan sızıyordu)
## Çalıştırma: tools/run_tests.sh city_life_test (pencereli: doku arka planda yüklenir)

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


func _meshes(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			count += 1
		count += _meshes(child)
	return count


func _lights_only(node: Node) -> int:
	var count: int = 0
	for child: Node in node.get_children():
		if child is Light3D:
			count += 1
		count += _lights_only(child)
	return count


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var lights: TrafficLights = main.find_child("TrafficLights", true, false) as TrafficLights
	var billboard: CityBillboard = main.find_child("CityBillboard", true, false) as CityBillboard
	check(traffic != null and lights != null and billboard != null, "kavşak lambaları ve billboard şehirde")
	if lights == null or billboard == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return

	print("== TRAFİK LAMBALARI ==")
	check(traffic.lights == lights, "trafik yöneticisi lambaya bağlı")
	check(lights.get_child_count() == 7 and _meshes(lights) == 7 and _lights_only(lights) == 0,
		"direkler + kafalar tek gövde, 6 ışık gövdesi, ışık kaynağı yok (%d gövde)" % _meshes(lights))
	lights.set_process(false)   # zamanı test ilerletir
	lights.set_phase(TrafficLights.Phase.ALL_RED, 0)
	lights.advance(TrafficLights.ALL_RED_TIME + 0.01)   # tüm kırmızıdan → eksen 1 yeşil
	check(lights.phase == TrafficLights.Phase.GREEN and lights.green_axis == 1, "tüm kırmızıdan sonra karşı eksen yeşil")
	check(lights.light_of(1) == &"green" and lights.light_of(0) == &"red" and lights.allows(1) and not lights.allows(0),
		"yeşil eksen geçer, kırmızı eksen bekler")
	check(lights.is_lit(1, &"green") and lights.is_lit(0, &"red") and not lights.is_lit(1, &"red"), "lambalar renge göre yanıyor")
	lights.advance(TrafficLights.GREEN_TIME)
	check(lights.phase == TrafficLights.Phase.YELLOW and lights.light_of(1) == &"yellow" and not lights.allows(1),
		"sarıda yeni izin yok")
	lights.advance(TrafficLights.YELLOW_TIME)
	check(lights.phase == TrafficLights.Phase.ALL_RED and lights.light_of(0) == &"red" and lights.light_of(1) == &"red",
		"tüm kırmızı: iki eksen de bekler")
	lights.advance(TrafficLights.ALL_RED_TIME)
	check(lights.green_axis == 0 and lights.allows(0), "sıra doğu-batıya geçti")
	var cycle: float = (TrafficLights.GREEN_TIME + TrafficLights.YELLOW_TIME + TrafficLights.ALL_RED_TIME) * 2.0
	lights.advance(cycle)
	check(lights.green_axis == 0 and lights.phase == TrafficLights.Phase.GREEN, "tam döngü %.0f sn" % cycle)

	print("== KAVŞAK İZNİ ==")
	traffic.max_vehicles = 0
	for v: TrafficVehicle in traffic.vehicles.duplicate():
		traffic._on_vehicle_despawn(v)
	traffic.chase._timer = 99999.0
	for i: int in 600:
		if not traffic.city_model_ids().is_empty():
			break
		await process_frame
	var east: TrafficWaypoint = null
	var north: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.spawn_points:
		if point.name == &"W_in_spawn":
			east = point
		elif point.name == &"S_in_spawn":
			north = point
	var car_x: TrafficVehicle = traffic._spawn_at(east) if east else null
	var car_z: TrafficVehicle = traffic._spawn_at(north) if north else null
	check(car_x != null and car_z != null and car_x.axis == 0 and car_z.axis == 1, "doğu-batı ve kuzey-güney araçları")
	if car_x and car_z:
		car_x.set_physics_process(false)
		car_z.set_physics_process(false)
		lights.set_phase(TrafficLights.Phase.GREEN, 1)
		check(not traffic.request_crossing(car_x), "kırmızıdaki araç kavşağa giremez")
		check(traffic.request_crossing(car_z), "yeşildeki araç girer")
		traffic.finish_crossing(car_z)
		lights.set_phase(TrafficLights.Phase.YELLOW, 1)
		check(not traffic.request_crossing(car_z), "sarıda yeni izin verilmez")
		lights.set_phase(TrafficLights.Phase.GREEN, 0)
		check(traffic.request_crossing(car_x), "ışık dönünce bekleyen araç geçer")
		traffic.finish_crossing(car_x)
		traffic._on_vehicle_despawn(car_x)
		traffic._on_vehicle_despawn(car_z)

	print("== YAYA GEÇİDİ / DUR ÇİZGİSİ ==")
	var kinds: Dictionary = {}
	var behind: int = 0
	for i: int in 1000:
		var o: float = TrafficVehicle.stop_overshoot(randf(), randf())
		kinds["daha geride" if o <= -0.3 else ("geride" if o <= -0.11 else ("çizgide" if o < 0.0 else "geçitte"))] = true
		if o < -0.481 or o > 0.261:
			kinds["ARALIK DIŞI"] = true
		if o < 0.0:
			behind += 1
	check(kinds.size() == 4 and not kinds.has("ARALIK DIŞI"), "duruş çeşitleri: %s" % [kinds.keys()])
	check(behind > 800, "araçların çoğu dur çizgisinin gerisinde (%d / 1000)" % behind)
	var entry_w: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.waypoints:
		if point.name == &"W_in_entry":
			entry_w = point
	var line_back: float = -(IntersectionMarkings.STOP_LINE_OUT + IntersectionMarkings.STOP_LINE_WIDTH * 0.5)   # batı kolu, x
	check(entry_w != null and absf(lights.stop_gap(entry_w) - (entry_w.global_position.x - line_back)) < 0.001,
		"dur çizgisi girişten %.2f geride" % (lights.stop_gap(entry_w) if entry_w else 0.0))
	var waiter: TrafficVehicle = traffic._spawn_at(east) if east else null
	check(waiter != null, "batıdan gelen araç")
	if waiter and entry_w:
		lights.set_phase(TrafficLights.Phase.GREEN, 1)   # doğu-batı kırmızı (zaman durdurulmuş)
		waiter.global_position = Vector3(-2.8, waiter.global_position.y, 0.9)
		waiter.max_speed = 0.9
		for i: int in 900:
			await physics_frame
			if waiter.speed < 0.005 and i > 60:
				break
		var front: float = waiter.global_position.x + waiter._front
		check(waiter.speed < 0.01 and not waiter.is_in_intersection() and waiter._stop_entry == entry_w,
			"kırmızıda durdu, kavşağa girmedi (yaklaşma noktasından önce de durabilir)")
		check(absf((front - line_back) - waiter._stop_overshoot) < 0.04,
			"burnu seçtiği yerde: dur çizgisine göre %+.2f (hedef %+.2f)" % [front - line_back, waiter._stop_overshoot])
		check(front < -IntersectionMarkings.CROSSWALK_IN * 0.5, "burun kavşak kenarının gerisinde (%.2f)" % front)
		lights.set_phase(TrafficLights.Phase.GREEN, 0)
		for i: int in 600:
			await physics_frame
			if waiter.is_in_intersection():
				break
		check(waiter.is_in_intersection(), "yeşilde kalkıp kavşağa girdi")
		traffic._on_vehicle_despawn(waiter)

	print("== KAVŞAK ÇİZGİLERİ ==")
	var marks: IntersectionMarkings = main.find_child("IntersectionMarkings", true, false) as IntersectionMarkings
	check(marks != null and _meshes(marks) == 1, "yaya geçitleri, dur / orta çizgileri, oklar, izler tek gövde")
	if marks:
		var mesh_node: MeshInstance3D = marks.get_child(0) as MeshInstance3D
		var mat: StandardMaterial3D = mesh_node.material_override as StandardMaterial3D
		check(mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and mat.albedo_texture != null,
			"aşınmış boya atlası, alpha scissor (saydam sıralama yok)")
		check(mesh_node.mesh.get_faces().size() / 3 >= 4 * 4 * 2, "dört kolun hepsi çizildi (%d üçgen)" % (mesh_node.mesh.get_faces().size() / 3))
		var faces: PackedVector3Array = mesh_node.mesh.get_faces()
		var reversed: int = 0
		for i: int in range(0, faces.size(), 3):
			var a: Vector3 = faces[i]
			var b: Vector3 = faces[i + 1]
			var c: Vector3 = faces[i + 2]
			if (b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x) <= 0.0:
				reversed += 1
		check(reversed == 0, "her üçgen yukarıdan ön yüz (ters örülmüş: %d)" % reversed)
	var environment: Environment = main.get_world_3d().environment
	check(environment != null and environment.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR
		and environment.ambient_light_color.is_equal_approx(WorldDressing.AMBIENT_COLOR),
		"şehrin kendi ortam ışığı var (başka ekrandan sızmaz)")
	var atlas_cfg: ConfigFile = ConfigFile.new()
	atlas_cfg.load(IntersectionMarkings.ATLAS_PATH + ".import")
	check(int(atlas_cfg.get_value("params", "compress/mode", 0)) == 2 and bool(atlas_cfg.get_value("params", "mipmaps/generate", false)),
		"çizgi atlası VRAM sıkıştırmalı + mipmap'li")
	var old_square: Node3D = main.get_node_or_null("RoadLeft/Square") as Node3D
	var old_edge: Node3D = main.get_node_or_null("RoadLeft/TurnLine") as Node3D
	var near_dash: Node3D = main.get_node_or_null("RoadLeft/LaneLine7") as Node3D    # x −0,41: dur çizgisinin üstünde
	var far_dash: Node3D = main.get_node_or_null("RoadLeft/LaneLine15") as Node3D    # x −6,01
	check(old_square != null and not old_square.visible and old_edge != null and not old_edge.visible,
		"sahnenin eski kavşak karesi ve kenar çizgileri gizli")
	check(near_dash != null and not near_dash.visible and far_dash != null and far_dash.visible,
		"kavşağa yakın kesikler gizli (orta çizgi düz), uzaktakiler duruyor")

	print("== BILLBOARD ==")
	check(CityBillboard.POSTERS.size() >= 7, "%d afiş (en az bir hafta)" % CityBillboard.POSTERS.size())
	var all_ok: bool = true
	for id: String in CityBillboard.POSTERS:
		var path: String = CityBillboard.POSTER_DIR + id + ".jpg"
		var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
		if texture == null or texture.get_size() != Vector2(1024, 512):
			all_ok = false
			print("    sorunlu afiş: ", path)
			continue
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(path + ".import")
		if int(cfg.get_value("params", "compress/mode", 0)) != 2 or not bool(cfg.get_value("params", "mipmaps/generate", false)):
			all_ok = false
			print("    sıkıştırma / mipmap kapalı: ", path)
	check(all_ok, "her afiş 1024×512, VRAM sıkıştırmalı ve mipmap'li")
	var day: float = 86400.0
	var base: float = 20000.0 * day   # bir gece yarısı (UTC)
	check(CityBillboard.poster_for(base + 10.0) == CityBillboard.poster_for(base + day - 10.0), "gün içinde afiş değişmez")
	check(CityBillboard.poster_for(base + day - 10.0) != CityBillboard.poster_for(base + day + 10.0), "gece yarısı sıradaki afiş")
	check(CityBillboard.poster_for(base - 3600.0 * 2.0, 180) == CityBillboard.poster_for(base + 10.0)
		and CityBillboard.poster_for(base - 3600.0 * 2.0, 0) != CityBillboard.poster_for(base + 10.0),
		"yerel saat: UTC+3'te gün 3 saat önce döner (22:00 UTC = yerel 01:00)")
	var seen: Dictionary = {}
	for i: int in CityBillboard.POSTERS.size():
		seen[CityBillboard.poster_for(base + day * i + 100.0)] = true
	check(seen.size() == CityBillboard.POSTERS.size(), "%d günde her afiş bir kez" % CityBillboard.POSTERS.size())
	var expected: String = CityBillboard.poster_for(Time.get_unix_time_from_system(), CityBillboard._bias_minutes())
	for i: int in 300:
		if billboard.poster_id != "":
			break
		await process_frame
	check(billboard.poster_id == expected, "bugünün afişi panoda (%s)" % billboard.poster_id)
	var material: StandardMaterial3D = billboard._panel_material
	check(material.albedo_texture != null and material.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"pano gölgesiz, afiş dokusu atanmış")
	check(_meshes(billboard) == 3 and _lights_only(billboard) == 0, "billboard 3 gövde, ışık kaynağı yok")
	var camera: Camera3D = root.get_camera_3d()
	var facing: Vector3 = billboard.global_transform.basis.z
	check(facing.dot(-camera.global_transform.basis.z) < -0.5, "pano yüzü oyun kamerasına dönük")
	check(facing.z > 0.9, "pano yüzü yola (güneye) bakıyor")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
