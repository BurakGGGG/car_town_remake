extends SceneTree
## ÇİZİM SAYIMI: sahnedeki görünür geometri, kaynağına göre (dekor / araç / trafik / şehir…) —
## örnek sayısı, yüzey (≈ çizim çağrısı) ve üçgen. Hangi sistemin çizim bütçesini yediğini gösterir.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/draw_census.gd --resolution 1152x648

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 200:
		await process_frame
	var groups: Dictionary = {}
	var main: Node = current_scene
	for node: Node in main.find_children("*", "GeometryInstance3D", true, false):
		var g: GeometryInstance3D = node as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		var key: String = _category(g, main)
		if not groups.has(key):
			groups[key] = {"count": 0, "surfaces": 0, "tris": 0}
		var entry: Dictionary = groups[key]
		entry["count"] += 1
		var surfaces: int = 1
		var tris: int = 0
		if g is MeshInstance3D and (g as MeshInstance3D).mesh:
			var mesh: Mesh = (g as MeshInstance3D).mesh
			surfaces = mesh.get_surface_count()
			tris = _tris(mesh)
		elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
			var mm: MultiMesh = (g as MultiMeshInstance3D).multimesh
			surfaces = mm.mesh.get_surface_count() if mm.mesh else 1
			tris = (_tris(mm.mesh) if mm.mesh else 0) * mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		entry["surfaces"] += surfaces
		entry["tris"] += tris
	var keys: Array = groups.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return groups[a]["surfaces"] > groups[b]["surfaces"])
	print("| kaynak | örnek | yüzey | üçgen |")
	for k: String in keys:
		var e: Dictionary = groups[k]
		print("| %s | %d | %d | %dk |" % [k, e["count"], e["surfaces"], e["tris"] / 1000])
	quit(0)


## Kaynağı: ağaçta kök sahneden itibaren ilk iki anlamlı ata adı.
func _category(node: Node, root: Node) -> String:
	var path: Array[String] = []
	var n: Node = node
	while n and n != root:
		path.push_front(String(n.name))
		n = n.get_parent()
	if path.is_empty():
		return "?"
	# Araç modelleri (trafik / park): kök düğümün sınıfına bak
	n = node
	while n and n != root:
		if n is TrafficVehicle:
			return "trafik aracı"
		n = n.get_parent()
	var head: String = path[0]
	if path.size() > 2:
		head += "/" + path[1]
	if path.size() > 3 and path[1] in ["GarageSystem", "Decor", "Gameplay"]:
		head += "/" + path[2]
	return head.left(60)


func _tris(mesh: Mesh) -> int:
	var total: int = 0
	for s: int in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(s)
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index is PackedInt32Array and (index as PackedInt32Array).size() > 0:
			total += (index as PackedInt32Array).size() / 3
		else:
			total += (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total
