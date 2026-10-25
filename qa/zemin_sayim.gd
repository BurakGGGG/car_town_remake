extends SceneTree
## ZEMİN SAYIMI — şehirdeki düz (zemin) ve yüksek (gölge düşüren) geometrinin materyal türleri.
##   QA_SAVE=~/Projects/ct_shots/bench_saves/featured.json CT_NO_TUTORIAL=1 \
##   tools/qa_isolated.sh res://qa/zemin_sayim.gd --display-driver x11 --disable-vsync --resolution 1152x648

const FLAT: float = 0.045


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(150)
	var flat: Dictionary = {}
	var tall: Dictionary = {}
	for node: Node in current_scene.find_children("*", "GeometryInstance3D", true, false):
		var gi: GeometryInstance3D = node as GeometryInstance3D
		if not gi.is_visible_in_tree() or gi is Label3D or gi is Sprite3D:
			continue
		var box: AABB = gi.global_transform * gi.get_aabb()
		if gi is MultiMeshInstance3D:
			box = gi.global_transform * (gi as MultiMeshInstance3D).multimesh.get_aabb()
		var is_flat: bool = box.size.y < FLAT
		var key: String = "%s %s" % [gi.get_class(), _materials(gi)]
		var path: String = str(current_scene.get_path_to(gi))
		var bucket: Dictionary = flat if is_flat else tall
		if not bucket.has(key):
			bucket[key] = []
		(bucket[key] as Array).append("%s y=%.3f..%.3f" % [path, box.position.y, box.end.y])
	print("=== DÜZ ===")
	for key: String in flat:
		print("%3d  %s   örn: %s" % [(flat[key] as Array).size(), key, (flat[key] as Array).slice(0, 3)])
	print("=== YÜKSEK ===")
	for key: String in tall:
		print("%3d  %s   örn: %s" % [(tall[key] as Array).size(), key, (tall[key] as Array).slice(0, 2)])
	quit(0)


func _materials(gi: GeometryInstance3D) -> String:
	var names: PackedStringArray = []
	if gi.material_override:
		names.append("override:" + _mat_name(gi.material_override))
	var mesh: Mesh = null
	if gi is MeshInstance3D:
		mesh = (gi as MeshInstance3D).mesh
	elif gi is MultiMeshInstance3D:
		mesh = (gi as MultiMeshInstance3D).multimesh.mesh
	elif gi is CSGShape3D:
		var csg: CSGShape3D = gi as CSGShape3D
		names.append("csg:" + _mat_name(csg.get("material")))
	if mesh:
		for s: int in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(s)
			if gi is MeshInstance3D and (gi as MeshInstance3D).get_surface_override_material(s):
				m = (gi as MeshInstance3D).get_surface_override_material(s)
			names.append(_mat_name(m))
	return ",".join(names)


func _mat_name(m: Variant) -> String:
	if m == null:
		return "null"
	if m is ShaderMaterial:
		var sh: Shader = (m as ShaderMaterial).shader
		return "Shader(%s)" % (sh.resource_path.get_file() if sh and sh.resource_path != "" else "kod")
	if m is StandardMaterial3D:
		var sm: StandardMaterial3D = m
		return "Std(%s%s%s)" % [sm.albedo_color.to_html(false), " tex" if sm.albedo_texture else "",
			" unsh" if sm.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else ""]
	return (m as Object).get_class()
