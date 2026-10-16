extends SceneTree
## TRAFİK LAMBASI QA — gerçek şehir trafiğini hızlandırılmış (time_scale 3) ~3 dakika izler:
##   - kavşak izni (TrafficManager._crossing'e giren araç) yalnızca o eksen YEŞİLKEN verilmiş mi
##   - kırmızıda giriş çizgisinde DURAN araç sayısı (> 0 olmalı: lambalar trafiği gerçekten durduruyor)
##   - araçlar kavşaktan geçip yol ucunda kayboluyor mu (tıkanma yok)
##   - bekleyen aracın burnunun dur çizgisine göre yeri (− = gerisinde): dağılım yazılır
## Kırmızıda bekleyen araçların görüntüleri (aralıklı 3 tane): /home/burak/Projects/ct_shots/sehir/kirmizida_bekleyen_<n>.png
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/trafik_lamba_qa.gd --display-driver x11 --resolution 1440x810

const OUT: String = "/home/burak/Projects/ct_shots/sehir/"
const SIM_SECONDS: float = 180.0


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var lights: TrafficLights = traffic.lights if traffic else null
	print("lambalar bağlı: ", lights != null)
	if lights == null:
		quit(1)
		return
	var hud: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	hud.visible = false
	traffic.chase._timer = 99999.0   # kovalamaca ölçümü karıştırmasın
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.follow(Vector3(0.6, 0.0, 0.6), 2.4)
	Engine.time_scale = 3.0
	var seen_crossing: Dictionary = {}
	var violations: int = 0
	var grants: int = 0
	var red_stops: Dictionary = {}
	var despawned: Array[int] = [0]   # lambda yerel int'i kopyalar; dizi paylaşılır
	var shots: int = 0
	var last_shot: float = -100.0
	var offsets: Array[float] = []
	traffic.vehicle_spawned.connect(func(v: TrafficVehicle) -> void:
		v.reached_despawn.connect(func(_x: TrafficVehicle) -> void: despawned[0] += 1))
	var phases: Dictionary = {}
	var start: int = Time.get_ticks_msec()
	while (Time.get_ticks_msec() - start) / 1000.0 * Engine.time_scale < SIM_SECONDS:
		await physics_frame
		phases[lights.light_of(0) + "/" + lights.light_of(1)] = true
		for v: TrafficVehicle in traffic._crossing:
			if is_instance_valid(v) and not seen_crossing.has(v):
				seen_crossing[v] = true
				grants += 1
				if lights.light_of(v.axis) != &"green":
					violations += 1
					print("  İHLAL: %s eksen %d, ışık %s" % [v.name, v.axis, lights.light_of(v.axis)])
		for v: TrafficVehicle in traffic.vehicles:
			if not is_instance_valid(v) or v.mode != TrafficVehicle.Mode.TRAFFIC or v.target == null:
				continue
			if v.speed < 0.02 and lights.light_of(v.axis) != &"green" and IntersectionMarkings._outside(v.global_position) < 1.9 \
					and IntersectionMarkings._outside(v.global_position) > 0.2 and traffic.distance_to_vehicle_ahead(v) > 1.0:
				if not red_stops.has(v):
					red_stops[v] = true
					var front: Vector3 = v.global_position + v.global_transform.basis.z * v._front
					var line_back: float = IntersectionMarkings.STOP_LINE_OUT + IntersectionMarkings.STOP_LINE_WIDTH * 0.5
					var past: float = line_back - IntersectionMarkings._outside(front)
					offsets.append(past)
					print("  kırmızıda duruyor: %s (eksen %d) — burun dur çizgisine göre %+.2f" % [v.vehicle_id, v.axis, past])
				var sim_now: float = (Time.get_ticks_msec() - start) / 1000.0 * Engine.time_scale
				if shots < 3 and sim_now - last_shot > 25.0:
					shots += 1
					last_shot = sim_now
					Engine.time_scale = 1.0
					await frames(2)
					RenderingServer.force_draw()
					await RenderingServer.frame_post_draw
					var path: String = OUT + "kirmizida_bekleyen_%d.png" % shots
					root.get_texture().get_image().save_png(path)
					print("  görüntü: ", path)
					Engine.time_scale = 3.0
		# Kavşaktan seen_crossing'e girmiş ama artık listede olmayanlar temizlenir (yeniden giriş sayılsın)
		for v: Variant in seen_crossing.keys():
			if not is_instance_valid(v) or not traffic._crossing.has(v):
				seen_crossing.erase(v)
	Engine.time_scale = 1.0
	print("görülen ışık durumları: ", phases.keys())
	offsets.sort()
	print("burun konumları (dur çizgisine göre): ", offsets.map(func(o: float) -> String: return "%+.2f" % o))
	print("SONUÇ: izin %d · ihlal %d · kırmızıda duran araç %d · yol ucunda kaybolan %d" % [grants, violations, red_stops.size(), despawned[0]])
	quit(0 if violations == 0 and red_stops.size() > 0 and despawned[0] > 0 else 1)


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
