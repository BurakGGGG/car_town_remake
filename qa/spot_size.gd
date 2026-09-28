extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 70: await process_frame
	var g: Node3D = get_first_node_in_group("garage_system")
	for n: String in ["PlacedObjects/CarSpot", "PlacedObjects/CarSpot2", "BuildGrid/BuildGrid"]:
		var node: Node = g.get_node_or_null(n)
		if node == null:
			print("%s: yok" % n); continue
		if node is VisualInstance3D:
			var aabb: AABB = (node as VisualInstance3D).get_aabb()
			print("%-28s kutu %s konum %s ölçek %s" % [n, aabb.size, (node as Node3D).position,
				(node as Node3D).scale])
		else:
			print("%-28s cell_size=%s width=%s depth=%s" % [n, node.get("cell_size"),
				node.get("width"), node.get("depth")])
	quit(0)
