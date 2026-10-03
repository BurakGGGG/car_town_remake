extends SceneTree
## Elle ayarlanan boyut laboratuvarını okur: her aracın Scale'ini (= model_scale) ve cars.json'daki
## mevcut değerle farkını basar. Kullanım: godot-4 --headless --path . -s res://tools/read_size_lab.gd


func _initialize() -> void:
	var scene: PackedScene = load("res://tools/size_lab.tscn")
	if scene == null:
		print("size_lab.tscn yok")
		quit(1)
		return
	var root: Node = scene.instantiate()
	for entry: Dictionary in CarCatalog.all():
		var id: String = String(entry["id"])
		var car: Node3D = root.get_node_or_null(id) as Node3D
		if car == null:
			print("%-26s YOK" % id)
			continue
		var s: Vector3 = car.scale
		var uniform: bool = absf(s.x - s.y) < 0.0005 and absf(s.x - s.z) < 0.0005
		print("%-26s sahnede %.4f  cars.json %.4f  fark %+.1f%%%s" % [id, s.x, float(entry.get("model_scale", 1.0)),
			(s.x / float(entry.get("model_scale", 1.0)) - 1.0) * 100.0, "" if uniform else "  UNIFORM DEĞİL %s" % s])
	quit()
