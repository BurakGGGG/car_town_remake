extends SceneTree
## her aracın OPTİMİZE modelinin gerçek kutusu + dünya geometrisi ölçüleri.

var _frame: int = 0


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	print("== DÜNYA GEOMETRİSİ ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	get_root().add_child(main)
	var road: MeshInstance3D = main.get_node_or_null("RoadRight") as MeshInstance3D
	if road and road.mesh:
		print("  RoadRight kutu: %s (konum %s)" % [road.mesh.get_aabb().size, road.position])
	for spot_name: String in ["GarageSystem/PlacedObjects/CarSpot", "GarageSystem/PlacedObjects/CarSpot2",
			"GarageSystem/PlacedObjects/CarSpot3"]:
		var spot: Node3D = main.get_node_or_null(spot_name) as Node3D
		if spot:
			var m: MeshInstance3D = spot as MeshInstance3D
			print("  %s konum %s kutu %s" % [spot_name.get_file(), spot.position,
				m.mesh.get_aabb().size if m and m.mesh else "-"])
	var floor_node: CSGBox3D = main.get_node_or_null("GarageSystem/Floor/GarageFloor") as CSGBox3D
	if floor_node:
		print("  Garaj zemini: %s" % floor_node.size)
	print("  Trafik şerit aralığı: 0.60 birim (W_in z=0.9 / E_in z=0.3)")
	print("  Trafik araç ölçeği: 0.60 · drag: 1.20 · showroom: 0.88 · garaj önizleme: 1.00")
	main.queue_free()

	print("\n== OPTİMİZE MODEL KUTULARI (ölçeksiz) ==")
	print("%-22s %8s %8s %8s   %s" % ["araç", "uzunluk", "genişlik", "yükseklik", "oran W/L, H/L"])
	for entry: Dictionary in CarCatalog.all():
		var path: String = entry["scene_path"]
		if not ResourceLoader.exists(path):
			continue
		var car: Node3D = (load(path) as PackedScene).instantiate() as Node3D
		get_root().add_child(car)
		var box: AABB = AABB()
		var first: bool = true
		for mesh: MeshInstance3D in car.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = mesh.global_transform * mesh.get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("%-22s %8.4f %8.4f %8.4f   %.3f / %.3f   taban y=%.4f" % [
			entry["id"], box.size.z, box.size.x, box.size.y,
			box.size.x / box.size.z, box.size.y / box.size.z, box.position.y])
		car.queue_free()
	return true
