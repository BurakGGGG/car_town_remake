extends SceneTree
## YARIŞ AYARI ÖNHESABI — her aracın kalibre edilmiş torkunu, yarış vites kutusunu ve kusursuz 300 m süresini
## vehicles/race_specs.json'a yazar. DragRaceSim.EngineSpec.derive girdiler değişmemişse bunu okur (kalibrasyon
## araç başına ~11 ms; telefonda yarış ekranı açılırken takılma yapıyordu). Ayrıntı: docs/PERFORMANS_V2.md
## Ne zaman: cars.json'da race / performance / year / real_dimensions / category değişince ya da
## DragRaceSim'in ayar mantığı değişince (TUNING_VERSION artırılır). vehicle_asset_test eskimeyi yakalar.
## Kullanım: godot-4 --headless --path . -s res://tools/bake_race_specs.gd


func _initialize() -> void:
	DragRaceSim.ignore_baked = true
	DragRaceSim.clear_cache()
	var cars: Dictionary = {}
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var spec: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
		cars[String(id)] = {
			"key": DragRaceSim.tuning_key(id),
			"torque": snappedf(spec.peak_torque_nm, 0.001),
			"race_top_kmh": snappedf(spec.race_top_kmh, 0.001),
			"base_time": snappedf(DragRaceSim.base_time(id), 0.0001),
		}
		print("%-20s tork %7.1f Nm  kutu %6.1f km/sa  300 m %.3f sn" % [id, spec.peak_torque_nm, spec.race_top_kmh, DragRaceSim.base_time(id)])
	var data: Dictionary = {
		"_readme": "OTOMATİK ÜRETİLİR — elle düzenleme. tools/bake_race_specs.gd (bkz. DragRaceSim.TUNING_VERSION).",
		"tuning_version": DragRaceSim.TUNING_VERSION,
		"cars": cars,
	}
	var file: FileAccess = FileAccess.open(DragRaceSim.BAKED_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "  ", true) + "\n")
	file.close()
	print("yazıldı: %s (%d araç)" % [DragRaceSim.BAKED_PATH, cars.size()])
	quit()
