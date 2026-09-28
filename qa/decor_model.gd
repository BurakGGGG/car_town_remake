extends SceneTree
## Blender modeli oyunda doğru ölçekte mi: lastik yığınını avluya koy, kutusunu ölç.
var _hud: Node
func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null
func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()
func _frames(n: int) -> void:
	for i: int in n: await process_frame
func _box(n: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [n]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var t: Transform3D = Transform3D.IDENTITY
			var walk: Node = node
			while walk != null and walk != n:
				if walk is Node3D: t = (walk as Node3D).transform * t
				walk = walk.get_parent()
			var b: AABB = t * (node as MeshInstance3D).get_aabb()
			out = b if first else out.merge(b)
			first = false
		for c: Node in node.get_children(): stack.append(c)
	return out
func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(70)
	print("model dosyası var mı: %s" % DecorBuilder.has_model(&"tyre_pile"))
	var body: Node3D = DecorBuilder.build(&"tyre_pile")
	get_root().add_child(body)
	await _frames(2)
	var b: AABB = _box(body)
	var placed: float = DecorBuilder.PLACER_SCALE
	print("model kutusu (yerleştirme ölçeği UYGULANMADAN): %.3f x %.3f x %.3f birim" % [b.size.x, b.size.y, b.size.z])
	print("avluda görünecek boy: %.3f x %.3f x %.3f birim  =  %.2f x %.2f x %.2f METRE" % [
		b.size.x * placed, b.size.y * placed, b.size.z * placed,
		b.size.x * placed / 0.1367, b.size.y * placed / 0.1367, b.size.z * placed / 0.1367])
	body.free()
	# Avluya gerçekten koy
	var decor: DecorManager = get_first_node_in_group("decor")
	var eco: EconomyManager = get_first_node_in_group("economy")
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	eco.set_money(2000000)
	for i: int in 2: upgrades.buy(GarageUpgradeManager.GARAGE_ID)
	await _frames(6)
	for id: StringName in [&"tyre_pile", &"oil_drums", &"pallet_stack", &"traffic_cones"]:
		decor.purchase(id)
	await _frames(10)
	var view: Node3D = get_first_node_in_group("garage_decor_view")
	print("avluda gövde: %d" % (view.get_node("DecorBodies") as Node3D).get_child_count())
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/decor/")
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/decor/model.png")
	quit(0)
