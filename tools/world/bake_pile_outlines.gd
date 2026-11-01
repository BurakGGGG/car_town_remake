extends SceneTree
## HURDALIK YIĞIN HATLARI → res://assets/world/junkyard_outlines.json (PileOutline.DATA_PATH).
## Aranabilir yığınların dış hattı + hangi kısımlarının görüneceği (öteki hurdaya yaslandığı / önünde bir şey olduğu
## yerler gizli) önceden hesaplanır; oyun açılışta yalnız okur. Ayrıntı: world/pile_outline.gd.
## Ne zaman: hurdalık sahnesi yeniden dışa aktarılınca (tools/world/export_junkyard.py) ya da kamera açısı değişince.
## junkyard_test, verideki sahne MD5'i ile assets/world/junkyard.glb'yi karşılaştırır.
## Kullanım (başsız olur): godot-4 --headless --path . --script res://tools/world/bake_pile_outlines.gd


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world: JunkyardWorld = JunkyardWorld.new()
	root.add_child(world)
	await process_frame
	await process_frame   # sahnedeki eski halkalar (queue_free) silinsin
	var yard: Node3D = world.get_node_or_null("Yard") as Node3D
	if yard == null or world.piles.is_empty():
		push_error("bake_pile_outlines: hurdalık sahnesi / yığınlar bulunamadı")
		quit(1)
		return
	var started: int = Time.get_ticks_msec()
	var data: Dictionary = PileOutline.bake(yard, world.piles, world.camera.global_basis)
	var file: FileAccess = FileAccess.open(PileOutline.DATA_PATH, FileAccess.WRITE)
	if file == null:
		push_error("bake_pile_outlines: yazılamadı: " + PileOutline.DATA_PATH)
		quit(1)
		return
	file.store_string(JSON.stringify(data) + "\n")
	file.close()
	for i: int in (data["piles"] as Array).size():
		var entry: Dictionary = data["piles"][i]
		var shown: Array = entry["shown"]
		print("yığın %d: %d nokta, %d görünür" % [i, shown.size(), shown.count(1)])
	print("yazıldı %s (%d ms)" % [PileOutline.DATA_PATH, Time.get_ticks_msec() - started])
	world.queue_free()
	quit(0)
