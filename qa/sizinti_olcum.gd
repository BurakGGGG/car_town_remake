extends SceneTree
## SIZINTI ÖLÇÜMÜ — ekranlar art arda açılıp kapanır; her turdan sonra düğüm, nesne, kaynak sayısı ve bellek yazılır.
## İlk açılışta kurulan (önbellek) artış normaldir; sonraki turlarda sayılar BÜYÜMEYE devam ediyorsa sızıntı vardır.
##   QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/sizinti_olcum.gd \
##     --display-driver x11 --disable-vsync --resolution 1152x648 [-- <ekran> ...]

const SCREENS: Array[StringName] = [&"garage", &"showroom", &"collection", &"quests", &"garage_edit", &"map",
	&"gem_store", &"profile", &"social", &"car_garages"]
const ROUNDS: int = 4


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _stats() -> String:
	return "düğüm %d (yetim %d) · nesne %d · kaynak %d · bellek %.1f MB · VRAM %.1f MB (doku %.1f, tampon %.1f)" % [
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0]


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	var router: UiRouter = get_first_node_in_group("ui_router") as UiRouter
	var screens: Array[StringName] = SCREENS
	if not OS.get_cmdline_user_args().is_empty():
		screens = []
		for arg: String in OS.get_cmdline_user_args():
			screens.append(StringName(arg))
	print("SIZINTI başlangıç: ", _stats())
	for id: StringName in screens:
		if not router.has_method("is_registered") and not router.get("_screens").has(id):
			print("SIZINTI %s: kayıtlı değil" % id)
			continue
		for round_index: int in ROUNDS:
			router.open(id)
			await _frames(45)
			router.close_all()
			await _frames(45)
			print("SIZINTI %s tur %d: %s · canlı rig %d · birleşik önbellek %d" % [id, round_index + 1, _stats(), _live_rigs(),
				CarMeshMerger._cache.size()], " · iş ", CarMeshMerger._jobs.size())
	_holders()
	quit(0)


## Canlı birleşik mesh'leri tutan ağaçtaki düğümler (önbellekte olmayanlar).
func _holders() -> void:
	var cached: Array = CarMeshMerger._cache.values()
	var seen: Dictionary = {}
	for node: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh is ArrayMesh and mi.mesh.has_meta(&"groups"):
			var key: String = "%s önbellekte=%s" % [str(mi.get_path()).get_slice("/", 2) + "/…/" + str(mi.get_parent().name) + "/" + str(mi.name), cached.has(mi.mesh)]
			seen[key] = int(seen.get(key, 0)) + 1
	for key: String in seen:
		print("TUTAN ", seen[key], "× ", key)


func _live_rigs() -> int:
	var count: int = 0
	for path: String in CarRig._rigs:
		for ref: WeakRef in CarRig._rigs[path]:
			if ref.get_ref() != null:
				count += 1
	return count
