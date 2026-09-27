extends SceneTree
## OYUN İÇİ: trafikte hareket eden araçların tekerleri dönerken gövde/çamurluk kıpırdıyor mu?
## Trafikteki her aracın gövdesi iki kare arasında (araç hareketi çıkarılarak) sabit kalmalı.
var _f: int = 0
var _traffic: Node
var _snap: Dictionary = {}
var _worst: float = 0.0
var _worst_id: String = ""
var _samples: int = 0
var _spun: int = 0

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node)
	for c: Node in node.get_children():
		_meshes(c, out)

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn")
		return false
	if _f == 90:
		_traffic = _find(current_scene, "Traffic")
		DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/wheels/")
		return false
	if _f > 100 and _f % 12 == 0 and _traffic:
		for v: Node in _traffic.get_children():
			if not (v is TrafficVehicle):
				continue
			var model: Node3D = (v as TrafficVehicle).model
			if model == null:
				continue
			var rig: CarRig = CarRig.for_node(model)
			var groups: Array = rig.get("_wheel_groups")
			var wheel_set: Dictionary = {}
			for g: Dictionary in groups:
				for m: MeshInstance3D in (g["meshes"] as Array):
					wheel_set[m] = true
			var all: Array = []
			_meshes(model, all)
			# Gövde parçalarının ARAÇ YEREL uzayındaki konumu (araç hareketi bu uzayda yok)
			var key: String = str(v.get_instance_id())
			var now: Dictionary = {}
			for m: MeshInstance3D in all:
				if not wheel_set.has(m):
					now[m.name] = m.transform.origin
				else:
					now["TEKER:" + m.name] = m.transform.basis.y   # X ekseni dönüşte değişmez, Y değişir
			if _snap.has(key):
				var before: Dictionary = _snap[key]
				for name: String in now:
					if not before.has(name):
						continue
					var d: float = ((now[name] as Vector3) - (before[name] as Vector3)).length()
					if name.begins_with("TEKER:"):
						if d > 0.0001:
							_spun += 1
						continue
					_samples += 1
					if d > _worst:
						_worst = d
						_worst_id = "%s/%s" % [String((v as TrafficVehicle).vehicle_id), name]
			_snap[key] = now

	if _f == 400:
		RenderingServer.force_draw()
		get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/wheels/trafik.png")
		print("trafik: %d gövde örneği, en büyük gövde kıpırdaması %.6f (%s) | DÖNEN teker ölçümü %d" % [
			_samples, _worst, _worst_id, _spun])
		quit(0)
	return false
