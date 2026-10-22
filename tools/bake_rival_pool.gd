extends SceneTree
## YAPAY ZEKÂ KOŞU HAVUZU ÖNHESABI — her aracın RivalPool.SIZE tohumlu koşusunun süresini vehicles/rival_pool.json'a
## yazar (RivalPool; seçici hedef kazanma şansına en yakın tohumu buradan seçer). Ayrıntı: docs/KOSU_ESLESTIRME.md
## Ne zaman: race_specs.json yeniden pişirilince (araç ayarı), DragRaceSim.SIM_VERSION ya da RivalPool.VERSION artınca
## (fizik / yapay zekâ sürüşü değişti). race_replay_test eskimeyi yakalar.
## Kullanım: godot-4 --headless --path . -s res://tools/bake_rival_pool.gd


func _initialize() -> void:
	RivalPool.clear_cache()
	var cars: Dictionary = {}
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var times: Array[float] = []
		for i: int in RivalPool.SIZE:
			times.append(snappedf(RivalPool.recording(id, i).time, 0.0001))
		cars[String(id)] = {"key": RivalPool.key_of(id), "t": times}
		var sorted: Array[float] = times.duplicate()
		sorted.sort()
		print("%-20s %2d koşu  en iyi %.3f  ortanca %.3f  en kötü %.3f" % [id, times.size(), sorted[0],
			sorted[floori(sorted.size() * 0.5)], sorted[sorted.size() - 1]])
	var data: Dictionary = {
		"_readme": "OTOMATİK ÜRETİLİR — elle düzenleme. tools/bake_rival_pool.gd (bkz. RivalPool.VERSION).",
		"version": RivalPool.VERSION,
		"size": RivalPool.SIZE,
		"cars": cars,
	}
	var file: FileAccess = FileAccess.open(RivalPool.PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "", true) + "\n")
	file.close()
	print("yazıldı: %s (%d araç)" % [RivalPool.PATH, cars.size()])
	quit()
