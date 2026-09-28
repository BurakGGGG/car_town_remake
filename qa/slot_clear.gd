extends SceneTree
## Avlu yuvaları tamir alanlarına / tabelaya çarpıyor mu?
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 70: await process_frame
	var garage: Node3D = get_first_node_in_group("garage_system")
	var blockers: Array = []
	for name: String in ["PlacedObjects/CarSpot", "PlacedObjects/CarSpot2", "PlacedObjects/CarSpot3"]:
		var n: Node3D = garage.get_node_or_null(name)
		if n:
			blockers.append([name.get_file(), Vector2(n.position.x, n.position.z)])
	var sign_node: Node3D = garage.get_node_or_null("ExpandSign")
	for child: Node in garage.get_children():
		if String(child.name).findn("sign") >= 0 and child is Node3D:
			blockers.append([child.name, Vector2((child as Node3D).position.x, (child as Node3D).position.z)])
	print("engeller: %s" % str(blockers))
	print("%-10s %-18s %s" % ["yuva", "konum", "en yakın engel"])
	for slot: StringName in GarageDecor.FLOOR_SLOTS:
		var p: Vector3 = GarageDecor.FLOOR_SLOTS[slot]
		var here: Vector2 = Vector2(p.x, p.z)
		var best: float = 999.0
		var who: String = "-"
		for b: Array in blockers:
			var d: float = here.distance_to(b[1])
			if d < best:
				best = d
				who = b[0]
		print("%-10s (%5.2f,%5.2f)     %-12s %.2f %s" % [slot, p.x, p.z, who, best,
			"ÇAKIŞMA" if best < 0.62 else ""])
	quit(0)
