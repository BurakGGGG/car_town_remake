extends SceneTree
## PERFORMANS RAPORU — her aracın drag simülasyonundaki gerçek davranışını ölçer (kusursuz kalkış +
## kusursuz vitesler, tepki yok). Katalogdaki gerçek veriyle (performance bloğu) yan yana basar.
## Kullanım: godot-4 --headless --path . -s res://qa/performance_report.gd
## Sütunlar: sınıf · gerçek 0-100 · simülasyon 0-100 (PACE ile kısalmış) · PACE'siz eşdeğeri · 300 m süresi ·
## bitiş hızı · GENEL puan.


func _initialize() -> void:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var perf: Dictionary = entry.get("performance", {})
		var sim_0_100: float = DragRaceSim.measure_0_100(DragRaceSim.spec_of(id))
		var run: DragRaceSim.Run = DragRaceSim.drive(id, 0.0, 1.0, 1.0, null)
		rows.append({"id": id, "class": entry.get("class", "?"), "real": float(perf.get("zero_100", 0.0)),
			"sim": sim_0_100, "time": run.time, "trap": run.top_speed, "overall": DragRaceSim.overall_of(id),
			"drive": String(perf.get("drivetrain", "?")), "spin": run.spin_time})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["time"] < b["time"])
	print("%-20s %-2s %-4s %7s %7s %8s %8s %8s %6s %6s" % ["araç", "sn", "çkş", "ger0-100", "sim", "sim×P²", "300m", "bitiş", "patinaj", "GENEL"])
	for r: Dictionary in rows:
		print("%-20s %-2s %-4s %7.1f %7.2f %8.2f %8.2f %8.0f %6.2f %6d" % [r["id"], r["class"], r["drive"], r["real"],
			r["sim"], r["sim"] * DragRaceSim.PACE * DragRaceSim.PACE, r["time"], r["trap"], r["spin"], r["overall"]])
	quit()

