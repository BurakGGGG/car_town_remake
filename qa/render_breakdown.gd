extends SceneTree
## ÇİZİLEN (LOD sonrası) üçgen ve çizim çağrısının kaynaklara dağılımı: her adımda bir kaynak gizlenir,
## kare ölçülür, fark o kaynağın gerçek maliyetidir. draw_census LOD0'ı sayar; bu betik GPU'ya gideni.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/render_breakdown.gd --display-driver x11 \
##   --disable-vsync --resolution 1152x648 [-- <zoom: start|min|max>]

func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _sample() -> Vector3:
	await _frames(20)
	var draws: float = 0.0
	var prims: float = 0.0
	var objects: float = 0.0
	for i: int in 30:
		await process_frame
		draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		objects += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	return Vector3(draws, prims, objects) / 30.0


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	Engine.max_fps = 0
	var zoom: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "start"
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	if camera and zoom != "start":
		camera.set("_target_size", camera.min_zoom if zoom == "min" else camera.max_zoom)
		await _frames(60)
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var decor: DecorManager = get_first_node_in_group("decor")
	var bodies: Dictionary = view.get("_bodies")
	var vehicles: Array[Node3D] = []
	var others: Array[Node3D] = []
	for iid: String in bodies:
		var body: Node3D = bodies[iid]
		if not is_instance_valid(body):
			continue
		var item: StringName = StringName(decor.instance(iid).get("item", ""))
		if GarageDecor.is_vehicle(item):
			vehicles.append(body)
		else:
			others.append(body)
	var batch: Node3D = view.find_child("DecorBatch", true, false) as Node3D
	if batch:
		others.append(batch)   # dekorun toplu çizimi (asıl parçalar çizilmiyor)
	var traffic: Array[Node3D] = []
	for node: Node in current_scene.find_children("*", "TrafficVehicle", true, false):
		traffic.append(node as Node3D)
	var hud: Array[Node3D] = []
	var city: Array[Node3D] = []
	for child: Node in current_scene.get_children():
		if child is Node3D and child.name != &"GarageSystem" and not (child is Camera3D) and not (child is Light3D) \
				and child.name != &"Traffic" and child.name != &"Gameplay":
			city.append(child as Node3D)
	var base: Vector3 = await _sample()
	print("ÇİZİM toplam: %d çağrı, %dk üçgen, %d nesne (zoom %s)" % [base.x, base.y / 1000.0, base.z, zoom])
	var steps: Array = [["sergi araçları (%d)" % vehicles.size(), vehicles], ["diğer dekor (%d)" % others.size(), others],
		["trafik (%d)" % traffic.size(), traffic], ["şehir / dünya süsü (%d kök)" % city.size(), city]]
	for step: Array in steps:
		for n: Node3D in step[1]:
			n.visible = false
		var now: Vector3 = await _sample()
		print("ÇİZİM %s: %d çağrı, %dk üçgen, %d nesne" % [step[0], base.x - now.x, (base.y - now.y) / 1000.0, base.z - now.z])
		for n: Node3D in step[1]:
			n.visible = true
		await _frames(5)
	var canvas: CanvasLayer = current_scene.find_child("HUD", true, false) as CanvasLayer
	if canvas:
		canvas.visible = false
		var now: Vector3 = await _sample()
		print("ÇİZİM HUD (2B): %d çağrı, %dk üçgen, %d nesne" % [base.x - now.x, (base.y - now.y) / 1000.0, base.z - now.z])
		canvas.visible = true
	quit(0)
