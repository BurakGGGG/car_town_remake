extends SceneTree
## BİRLEŞTİRME GÖRSEL DENETİMİ: aynı kare bir kez BİRLEŞİK, bir kez PARÇALI çizilir; piksel farkı
## ölçülür ve iki görüntü kaydedilir. Araç modeli, LOD farkı yüzünden çok az değişebilir (kenar
## pikselleri); renk / materyal / konum hatası büyük ve toplu farktır.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/merge_visual_check.gd --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/merge_check/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _set_merged(on: bool) -> void:
	for node: Node in current_scene.find_children("MergedParts", "MeshInstance3D", true, false):
		var merged: MeshInstance3D = node
		var rig: CarRig = _rig_of(merged.get_parent())
		if rig == null:
			continue
		merged.visible = on
		for source: MeshInstance3D in rig.get("_merge_hidden"):
			source.visible = not on
		# Karşılaştırma adil olsun: parçalı çizimde de aynı LOD katsayısı tabanı
		merged.lod_bias = merged.lod_bias


func _rig_of(node: Node) -> CarRig:
	if node.has_meta(CarRig.META_KEY):
		return node.get_meta(CarRig.META_KEY)
	var parent: Node = node.get_parent()
	if parent is TrafficVehicle:
		return (parent as TrafficVehicle).rig
	return null


func _grab() -> Image:
	for i: int in 3:
		await process_frame
	RenderingServer.force_draw()
	return root.get_texture().get_image()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 260:
		await process_frame
	# Trafik dursun: iki kare arasında araçlar yer değiştirmesin
	for node: Node in current_scene.find_children("*", "TrafficVehicle", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	var camera: WorldCamera = root.get_viewport().get_camera_3d() as WorldCamera
	for zoom: float in [camera.start_zoom, camera.min_zoom]:
		camera.set("_target_size", zoom)
		for i: int in 40:
			await process_frame
		_set_merged(true)
		var merged: Image = await _grab()
		_set_merged(false)
		var parts: Image = await _grab()
		_set_merged(true)
		var tag: String = "zoom_%.1f" % zoom
		merged.save_png(OUT + tag + "_birlesik.png")
		parts.save_png(OUT + tag + "_parcali.png")
		var differing: int = 0
		var big: int = 0
		for y: int in range(0, merged.get_height(), 2):
			for x: int in range(0, merged.get_width(), 2):
				var a: Color = merged.get_pixel(x, y)
				var b: Color = parts.get_pixel(x, y)
				var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
				if d > 0.06:
					differing += 1
				if d > 0.4:
					big += 1
		var total: int = (merged.get_width() / 2) * (merged.get_height() / 2)
		print("%s: farklı piksel %%%.2f, büyük fark %%%.3f" % [tag, 100.0 * differing / total, 100.0 * big / total])
	quit(0)
