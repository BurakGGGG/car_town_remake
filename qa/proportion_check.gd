extends SceneTree
## Model oranları gerçeğe uyuyor mu: kutu en/boy ve yükseklik/boy oranları karşılaştırılır.
func _initialize() -> void:
	_run.call_deferred()

func _bounds(node: Node, acc: AABB, first: bool) -> Array:
	if node is MeshInstance3D:
		var m: MeshInstance3D = node
		if m.mesh:
			var box: AABB = m.get_aabb()
			box = m.global_transform * box if m.is_inside_tree() else m.transform * box
			acc = box if first else acc.merge(box)
			first = false
	for c: Node in node.get_children():
		var r: Array = _bounds(c, acc, first)
		acc = r[0]; first = r[1]
	return [acc, first]

func _run() -> void:
	print("%-22s %6s %6s | %6s %6s | %s" % ["araç", "m.en/boy", "g.en/boy", "m.yük/boy", "g.yük/boy", "sapma"])
	var holder: Node3D = Node3D.new()
	root.add_child(holder)
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
		car.scale = Vector3.ONE
		holder.add_child(car)
		await process_frame
		# Ayna ve anten kutuyu şişiriyor (resmi ölçüler onları saymaz): rolleriyle çıkarılır.
		var rig: CarRig = CarRig.for_node(car)
		for role: StringName in [&"mirrors", &"antenna", &"hidden"]:
			for mesh: MeshInstance3D in rig.get_meshes(role):
				mesh.visible = false
				mesh.mesh = null
		await process_frame
		var r: Array = _bounds(car, AABB(), true)
		var b: AABB = r[0]
		var rd: Dictionary = entry["real_dimensions"]
		var mw: float = b.size.x / b.size.z
		var rw: float = float(rd["width_m"]) / float(rd["length_m"])
		var mh: float = b.size.y / b.size.z
		var rh: float = float(rd["height_m"]) / float(rd["length_m"])
		print("%-22s %6.3f %6.3f | %6.3f %6.3f | en %+5.1f%%  yük %+5.1f%%" % [id, mw, rw, mh, rh,
			100.0 * (mw / rw - 1.0), 100.0 * (mh / rh - 1.0)])
		car.free()
	quit(0)
