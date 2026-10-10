extends SceneTree
## LOD çarpanı kalibrasyonu: MERGED_LOD_SCALE'e göre çizilen üçgen — dekorlu garaj (dünya) ve
## drag yarışı (yakın kamera). Birleştirme ÖNCESİ değerle (perf_bench base_*) karşılaştırılır.
func _initialize() -> void:
	_run.call_deferred()


func _apply(scale: float) -> void:
	CarRig.MERGED_LOD_SCALE = scale
	for node: Node in current_scene.find_children("MergedParts", "MeshInstance3D", true, false):
		var root3d: Node3D = node.get_parent()
		for mi: Node in root3d.find_children("*", "MeshInstance3D", true, false):
			if mi != node:
				(node as MeshInstance3D).lod_bias = (mi as MeshInstance3D).lod_bias * scale
				break


func _prims() -> int:
	var total: float = 0.0
	for i: int in 30:
		await process_frame
		total += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	return int(total / 30000.0)


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 240:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false)
	var line: String = "dünya:"
	for scale: float in [1.0, 0.7, 0.55, 0.45]:
		_apply(scale)
		line += " %.2f→%dk" % [scale, await _prims()]
	print(line)
	hud.router.open(&"drag_race")
	for i: int in 200:
		await process_frame
	line = "drag:"
	for scale: float in [1.0, 0.7, 0.55, 0.45]:
		_apply(scale)
		line += " %.2f→%dk" % [scale, await _prims()]
	print(line)
	quit(0)
