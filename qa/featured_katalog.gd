extends SceneTree
## Öne çıkan garaj tasarımı için katalog dökümü: her dekor eşyasının yerleşimi, türü, zemin izi (dünya
## birimi) / duvar genişliği; desenler, duvar parçaları, kaplamalar; araçlar ve zemin izleri.
##   godot-4 --path . --headless -s res://qa/featured_katalog.gd

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 40:
		await process_frame
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	for d: Dictionary in GarageDecor.all():
		var id: StringName = StringName(d["id"])
		if d.get("retired", false):
			continue
		var pl: StringName = GarageDecor.placement(id)
		var size: String = ""
		if pl == GarageDecor.PLACE_FLOOR:
			var s: Vector2 = view.footprint_size(id)
			size = "%.3f x %.3f h%.2f" % [s.x, s.y, DecorBuilder.local_size(id).y * GarageDecorView.WORLD_SCALE]
		elif pl == GarageDecor.PLACE_WALL:
			size = "w %.3f" % view.wall_width(id)
		print("D|%s|%s|%s|%s|%s|%s" % [id, pl, d.get("kind", ""), d.get("title", ""), size, d.get("desc", "")])
	for e: Dictionary in CarCatalog.all():
		var vid: StringName = StringName(String(e["id"]))
		var item: StringName = GarageDecor.vehicle_item_id(vid)
		var s2: Vector2 = view.footprint_size(item)
		var perf: Dictionary = e.get("performance", {})
		print("C|%s|%s|%s|%s|%.3f x %.3f|%s hp|%s" % [vid, e.get("display_name", ""), e.get("year", ""),
			e.get("class", e.get("category", e.get("role", ""))), s2.x, s2.y, perf.get("hp", "?"),
			e.get("default_color", e.get("color", ""))])
	quit(0)
