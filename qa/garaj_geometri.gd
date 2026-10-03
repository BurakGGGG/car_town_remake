extends SceneTree
## GARAJ GEOMETRİSİ — düzenleyicinin dayanacağı ölçüler (tahmin değil):
## zemin üst yüzeyinin y'si, duvarların iç yüzleri ve yüksekliği, tamir alanlarının (CarSpot)
## zemindeki izdüşümü, dekor gövdelerinin gerçek boyutları. Her garaj seviyesi için.
## Kullanım: godot-4 --headless --path . -s res://qa/garaj_geometri.gd

var _f: int = 0


func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn")
	elif _f == 40:
		_measure()
		quit()
	return false


func _measure() -> void:
	var garage: Node3D = get_first_node_in_group("garage_system") as Node3D
	for level: int in 4:
		garage.call("set_level", level)
		var floor_node: Node3D = garage.get_node("Floor/GarageFloor")
		var fb: AABB = _world_aabb(floor_node)
		var lw: Node3D = garage.get_node("Walls/GarageLeftWall")
		var bw: Node3D = garage.get_node("Walls/GarageBackWall")
		var lb: AABB = _world_aabb(lw)
		var bb: AABB = _world_aabb(bw)
		print("SEVİYE %d  zemin x[%.3f..%.3f] z[%.3f..%.3f] üst y=%.4f" % [
			level + 1, fb.position.x, fb.end.x, fb.position.z, fb.end.z, fb.end.y])
		print("   sol duvar x[%.3f..%.3f] z[%.3f..%.3f] y[%.3f..%.3f]" % [
			lb.position.x, lb.end.x, lb.position.z, lb.end.z, lb.position.y, lb.end.y])
		print("   arka duvar x[%.3f..%.3f] z[%.3f..%.3f] y[%.3f..%.3f]" % [
			bb.position.x, bb.end.x, bb.position.z, bb.end.z, bb.position.y, bb.end.y])
	garage.call("set_level", 3)
	for spot: Node in current_scene.find_children("*", "", true, false):
		if String(spot.name).begins_with("CarSpot") and spot is Node3D:
			var n: Node3D = spot
			print("CarSpot %-12s konum (%.3f, %.3f, %.3f) yaw %.1f  sınıf %s" % [
				n.name, n.global_position.x, n.global_position.y, n.global_position.z,
				n.global_rotation_degrees.y, n.get_class()])
			var sb: AABB = _tree_aabb(n)
			print("      zemin izdüşümü x[%.3f..%.3f] z[%.3f..%.3f]  (%.3f x %.3f)" % [
				sb.position.x, sb.end.x, sb.position.z, sb.end.z, sb.size.x, sb.size.z])
	print("--- dekor gövdeleri (dünya ölçeğinde, PLACER_SCALE uygulanmış) ---")
	var ids: Array = []
	for item: Dictionary in GarageDecor.all():
		ids.append(item["id"])
	var built: int = 0
	var missing: Array = []
	var sizes: Array = []
	for id: StringName in ids:
		var kind: int = int(GarageDecor.get_item(id)["kind"])
		if kind == GarageDecor.Kind.FLOOR_SURFACE or kind == GarageDecor.Kind.WALL_SURFACE:
			continue
		var body: Node3D = DecorBuilder.build(id)
		if body == null:
			missing.append(id)
			continue
		built += 1
		body.scale = Vector3.ONE * DecorBuilder.PLACER_SCALE
		get_root().add_child(body)
		var b: AABB = _tree_aabb(body)
		sizes.append([id, b.size.x, b.size.y, b.size.z, b.position.y, kind])
		body.free()
	sizes.sort_custom(func(a: Array, b: Array) -> bool: return a[1] * a[3] > b[1] * b[3])
	for s: Array in sizes:
		print("   %-20s %.3f x %.3f x %.3f   alt y=%+.3f  tür=%d" % [s[0], s[1], s[2], s[3], s[4], s[5]])
	print("gövde üretilen: %d   üretilemeyen: %s" % [built, missing])


func _world_aabb(node: Node3D) -> AABB:
	return _tree_aabb(node)


## Düğüm ağacındaki bütün görünür geometrinin DÜNYA kutusu — köşe dönüşümüyle (Transform*AABB şişirir).
func _tree_aabb(root: Node) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if not (n is VisualInstance3D):
			continue
		var vi: VisualInstance3D = n
		var local: AABB = vi.get_aabb()
		var xf: Transform3D = vi.global_transform
		for i: int in 8:
			var p: Vector3 = xf * (local.position + Vector3(
				local.size.x if (i & 1) else 0.0, local.size.y if (i & 2) else 0.0,
				local.size.z if (i & 4) else 0.0))
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out
