extends SceneTree
## SERGİ ARACI LOD DENETİMİ: garajdaki sergi araçları farklı LOD katsayılarıyla aynı karede çizilir;
## piksel farkı ve çizilen üçgen ölçülür, görüntüler kaydedilir. Kamera garaja, en yakın ve açılış
## zoom'unda bakar (araçlar ekranda en büyük oldukları yerde).
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/display_lod_check.gd --display-driver x11 \
##   --disable-vsync --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/display_lod/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _grab() -> Image:
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image()


func _rigs() -> Array[CarRig]:
	var out: Array[CarRig] = []
	var view: Node = get_first_node_in_group("garage_decor_view")
	for node: Node in view.find_children("*", "Node3D", true, false):
		if node.has_meta(CarRig.META_KEY):
			out.append(node.get_meta(CarRig.META_KEY) as CarRig)
	return out


func _prims() -> float:
	var total: float = 0.0
	for i: int in 10:
		await process_frame
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	return total / 10.0


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 300:
		await process_frame
	Engine.max_fps = 0
	for node: Node in current_scene.find_children("*", "TrafficVehicle", true, false):
		(node as Node3D).visible = false
		node.set_process(false)
		node.set_physics_process(false)
	var rigs: Array[CarRig] = _rigs()
	print("LOD sergi aracı: %d" % rigs.size())
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	var garage: Node3D = get_first_node_in_group("garage_system") as Node3D
	var focus: Vector3 = Vector3(-1.2, 0.0, -0.95)
	for zoom: float in [camera.start_zoom, camera.min_zoom]:
		camera.follow(focus, zoom)
		# Zoom yumuşatılarak oturur: kısıtsız FPS'te kare sayısı değil gerçek süre beklenir
		var t0: int = Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2500:
			await process_frame
		var shots: Dictionary = {}
		for bias: float in [CarRig.LOD_BIAS_GARAGE, CarRig.LOD_BIAS_WORLD, CarRig.LOD_BIAS_NPC]:
			for rig: CarRig in rigs:
				rig.set_lod_bias(bias)
			var prims: float = await _prims()
			var img: Image = await _grab()
			shots[bias] = img
			img.save_png(OUT + "zoom_%.1f_bias_%.1f.png" % [zoom, bias])
			print("LOD zoom %.1f bias %.1f: %dk üçgen" % [zoom, bias, prims / 1000.0])
		var ref: Image = shots[CarRig.LOD_BIAS_GARAGE]
		for bias: float in [CarRig.LOD_BIAS_WORLD, CarRig.LOD_BIAS_NPC]:
			var img: Image = shots[bias]
			var differing: int = 0
			var big: int = 0
			for y: int in img.get_height():
				for x: int in img.get_width():
					var a: Color = ref.get_pixel(x, y)
					var b: Color = img.get_pixel(x, y)
					var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
					if d > 0.06:
						differing += 1
					if d > 0.4:
						big += 1
			var total: float = float(img.get_width() * img.get_height())
			print("LOD zoom %.1f bias %.1f vs 4.0: farklı piksel %%%.3f (%d), büyük fark %%%.4f (%d)" % [zoom, bias,
				100.0 * differing / total, differing, 100.0 * big / total, big])
	quit(0)
