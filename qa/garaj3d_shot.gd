extends SceneTree
## GARAJLARIM 3D iç mekân görüntüleyici (QA): pişmiş sahneyi garaj ekranından bağımsız kurar, araçları park yerlerine
## koyar, ekran görüntüsü alır — Blender önizlemesiyle (~/Projects/ct_shots/garaj3d/*/son*.png) karşılaştırma için.
## Çalıştırma (pencereli):
##   godot-4 --path . --display-driver x11 --resolution 1280x640 --script res://qa/garaj3d_shot.gd -- <garaj> <seviye> <çıktı.png>
##   garaj: mahalle | sanayi | … | waiting   seviye: 1-3 (her kalem aynı seviye; sv.3'te PARK YERİ en üstte)
##   QA_FOCUS=<araç> odak · QA_ZOOM=0.42 en yakın zoom · QA_CARS virgüllü liste · QA_SETTLE birleştirme bekleme karesi
##   QA_UZAKSIZ=1 araç uzak kademesi (CarFarLod) kapalı. Görüntü araç birleştirmeleri bittikten sonra alınır.

const CARS: Array[StringName] = [&"tofas_sahin", &"bmw_e46", &"lambo_huracan", &"vw_golf_7", &"porsche_gt3", &"renault_toros",
	&"hyundai_getz", &"vw_passat_b55", &"bmw_f30", &"toyota_corolla", &"audi_a6", &"mercedes_g", &"porsche_taycan",
	&"renault_megane_4", &"skoda_superb", &"ford_transit", &"chery_tiggo_8", &"cupra_formentor", &"bugatti_chiron",
	&"ferrari_laferrari", &"mercedes_sprinter", &"vw_passat_b8", &"bugatti_veyron", &"tofas_sahin"]
const WAITING_CARS: Array[StringName] = [&"renault_toros", &"hyundai_getz", &"tofas_sahin", &"vw_golf_7", &"bmw_e46",
	&"porsche_gt3", &"lambo_huracan", &"vw_passat_b55"]


func _initialize() -> void:
	CarFarLod.enabled = not OS.has_environment("QA_UZAKSIZ")   # araç uzak kademesi kapalı (önce / sonra kıyası)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var garage: StringName = StringName(args[0]) if args.size() > 0 else &"mahalle"
	var level: int = int(args[1]) if args.size() > 1 else 1
	var out: String = args[2] if args.size() > 2 else OS.get_environment("HOME") + "/Projects/ct_shots/garaj3d/godot.png"
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var camera: Camera3D = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	var light: DirectionalLight3D = DirectionalLight3D.new()
	world.add_child(light)
	var view: GarageInteriorView = GarageInteriorView.new()
	root.add_child(view)
	if not view.enter(garage, world, camera, light, []):
		push_error("iç mekân yok: %s" % garage)
		quit(1)
		return
	var park: int = level if level < 3 else CarGarageCatalog.max_level(garage, CarGarageCatalog.PARK)
	view.set_levels({&"floor": level, &"walls": level, &"lights": level, &"lift": level, &"park": park})
	var slots: Array[StringName] = []
	var tow: StringName = &""
	var cars: Array[StringName] = CARS
	if OS.get_environment("QA_CARS") != "":   # virgüllü araç listesi (hata ayıklama)
		cars = []
		for id: String in OS.get_environment("QA_CARS").split(","):
			cars.append(StringName(id))
	if garage != &"waiting":
		slots.assign(cars.slice(0, mini(CarGarageCatalog.capacity_at(garage, park), view.interior.slot_count())))
	else:
		for i: int in 12:
			slots.append(WAITING_CARS[[0, 1, 3, 4, 6, 8, 9].find(i)] if [0, 1, 3, 4, 6, 8, 9].has(i) else &"")
		tow = WAITING_CARS[7]
	view.sync_cars(slots, tow)
	if OS.get_environment("QA_FOCUS") != "":
		view.focus(StringName(OS.get_environment("QA_FOCUS")), false)
	if OS.get_environment("QA_ZOOM") != "":   # varsayılan uzaklığın oranı (GarageInteriorView.ZOOM_MIN = en yakın)
		var dist: float = float(view.get("_dist0")) * float(OS.get_environment("QA_ZOOM"))
		view.set("_goal_dist", dist)
		view.set("_dist", dist)
		view.call("_apply_camera")
	for i: int in 30:
		await process_frame
	var guard: int = 0
	while CarMeshMerger.busy() and guard < 900:   # oyundaki kalıcı hâl: parçalar birleşmiş, LOD kademeleri birleşik mesh'te
		await process_frame
		guard += 1
	for i: int in 5:
		await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(out)
	# Çizim yükü (kare süresi Blender pişirmesi gibi işlemci yükünden etkilenir; bunlar etkilenmez)
	var calls: float = 0.0
	var prims: float = 0.0
	for i: int in int(OS.get_environment("QA_SETTLE")) if OS.get_environment("QA_SETTLE") != "" else 0:
		await process_frame   # araç birleştirmeleri (CarMeshMerger kuyruğu) bitsin
	for i: int in 20:
		await process_frame
		calls = maxf(calls, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		prims = maxf(prims, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	print("YÜK %s sv%d araç=%d çizim=%d üçgen=%d" % [garage, level, slots.filter(func(x: StringName) -> bool: return x != &"").size()
		+ (1 if tow != &"" else 0), int(calls), int(prims)])
	print("KAYDEDİLDİ ", out, " ", image.get_size())
	quit(0)
