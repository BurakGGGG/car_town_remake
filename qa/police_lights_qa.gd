extends SceneTree
## POLİS IŞIKLARI QA — trafikte iki polis aracını (Vito, Bentley) doğurur, OYUN KAMERASIYLA izler: çakma döngüsü
## boyunca kareler (iki zum: varsayılan + en yakın) ve polis araçları yolda varken / yokken çizim çağrısı ile kare
## süresi. Işık sistemi: vehicles/police_lights.gd.
##   tools/qa_isolated.sh res://qa/police_lights_qa.gd --display-driver x11 --resolution 1170x540 -- <çıktı_klasörü>

const IDS: Array[StringName] = [&"police_vito", &"police_bentley"]

var fails: int = 0
var _out: String = ""


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
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if not args.is_empty() else OS.get_user_data_dir()
	DirAccess.make_dir_recursive_absolute(_out)
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	var traffic: TrafficManager = _find(current_scene)
	check(traffic != null, "TrafficManager bulundu")
	if traffic == null:
		quit(1)
		return
	var before: Vector2 = await _measure(120)

	var cars: Array[TrafficVehicle] = []
	for id: StringName in IDS:
		var vehicle: TrafficVehicle = null
		for attempt: int in 120:
			vehicle = traffic.spawn_model(id, CarAppearance.get_for(CarCatalog.scene_path(id)))
			if vehicle:
				break
			await frames(5)
		check(vehicle != null, "%s trafikte doğdu" % id)
		if vehicle:
			cars.append(vehicle)
			await frames(40)   # ikincisi aynı noktada üst üste doğmasın
	for vehicle: TrafficVehicle in cars:
		check(vehicle.rig != null and vehicle.rig.has_police_lights(), "%s: CarRig polis ışıklarını kurdu" % vehicle.vehicle_id)
		check(vehicle.model.find_child("PoliceBeacons", true, false) != null, "%s: hale düğümü var" % vehicle.vehicle_id)
	var after: Vector2 = await _measure(120)
	print("ölçüm  önce: %.1f çizim / %.2f ms   sonra (2 polis): %.1f çizim / %.2f ms" % [before.x, before.y, after.x, after.y])

	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	for vehicle: TrafficVehicle in cars:
		for zoom: Array in [["varsayilan", 0.0], ["yakin", -10.0]]:
			camera.zoom_by(float(zoom[1]))
			await _sheet(camera, vehicle, "%s/%s_%s.png" % [_out, vehicle.vehicle_id, zoom[0]])
			camera.zoom_by(10.0)
	print("polis_isiklari_qa: %d FAIL" % fails)
	quit(1 if fails > 0 else 0)


## Ortalama çizim çağrısı ve kare süresi (ms).
func _measure(n: int) -> Vector2:
	var draws: float = 0.0
	var start: int = Time.get_ticks_usec()
	for i: int in n:
		await process_frame
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	return Vector2(draws / n, (Time.get_ticks_usec() - start) / 1000.0 / n)


## Kamerayı aracın üstünde tutarak çakma döngüsü boyunca 8 kare (~80 ms arayla), aracın çevresinden kırpılmış.
func _sheet(camera: WorldCamera, vehicle: TrafficVehicle, path: String) -> void:
	var sheet: Image = null
	var k: int = 0
	var t0: int = Time.get_ticks_msec()
	while k < 8 and is_instance_valid(vehicle):
		camera.set("_focus", vehicle.global_position)
		camera.call("_apply_focus")
		await RenderingServer.frame_post_draw
		if Time.get_ticks_msec() - t0 < 600 + k * 80:   # ilk 600 ms: zum yerleşsin
			continue
		var img: Image = get_root().get_texture().get_image()
		var center: Vector2 = camera.unproject_position(vehicle.global_position)
		center = get_root().get_final_transform() * center
		var crop: Rect2i = Rect2i(Vector2i(center) - Vector2i(160, 110), Vector2i(320, 220))
		crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		var part: Image = img.get_region(crop)
		if sheet == null:
			sheet = Image.create(320 * 4, 220 * 2, false, img.get_format())
		sheet.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(320 * (k % 4), 220 * (k / 4)))
		k += 1
	if sheet:
		sheet.save_png(path)
		print("kaydedildi " + path)


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find(child)
		if found:
			return found
	return null
