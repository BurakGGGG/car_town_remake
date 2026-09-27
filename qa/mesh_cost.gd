extends SceneTree
## Araç modellerinin bellek maliyetini ölçer: yüzey/vertex sayısı, örnek başına VRAM artışı.
func _initialize() -> void:
	_run.call_deferred()

func _vram() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0

func _count(node: Node, acc: Dictionary) -> void:
	if node is MeshInstance3D:
		var m: Mesh = (node as MeshInstance3D).mesh
		if m:
			acc["mesh"] = int(acc.get("mesh", 0)) + 1
			acc["surf"] = int(acc.get("surf", 0)) + m.get_surface_count()
			for s: int in m.get_surface_count():
				var arr: Array = m.surface_get_arrays(s)
				acc["vert"] = int(acc.get("vert", 0)) + (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
				acc["tri"] = int(acc.get("tri", 0)) + int(idx.size() / 3.0)
	for c: Node in node.get_children():
		_count(c, acc)

func _run() -> void:
	var ids: Array = []
	for e: Dictionary in CarCatalog.all():
		ids.append(StringName(e["id"]))
	print("araç                      mesh  yüzey    vertex     üçgen   +VRAM(1)  +VRAM(2)")
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	for id: StringName in ids:
		var path: String = CarCatalog.scene_path(id)
		var scene: PackedScene = load(path)
		var a: Node3D = scene.instantiate()
		var acc: Dictionary = {}
		_count(a, acc)
		var before: float = _vram()
		holder.add_child(a)
		CarRig.for_node(a).apply(CarAppearance.get_for(path))
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var one: float = _vram() - before
		# İkinci örnek: paylaşılmayan (kopyalanan) veri ne kadar?
		var b: Node3D = scene.instantiate()
		holder.add_child(b)
		CarRig.for_node(b).apply(CarAppearance.get_for(path))
		await process_frame
		await process_frame
		RenderingServer.force_draw()
		var two: float = _vram() - before - one
		print("%-24s %5d %6d %9d %9d %9.1f %9.1f" % [id, acc.get("mesh",0), acc.get("surf",0),
			acc.get("vert",0), acc.get("tri",0), one, two])
		a.free(); b.free()
		await process_frame
	quit(0)
