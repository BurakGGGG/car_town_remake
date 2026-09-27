extends SceneTree
## Yeni şanzıman modelinin künyesi ve 300 m süreleri.
func _initialize() -> void:
	print("%-22s %-3s %5s %5s %5s %5s %6s %5s | %s" % ["araç","sf","idle","tepe","kırm","kalkş","tork","kütle","vites oranları"])
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var s: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
		var ratios: String = ""
		for r: float in s.gear_ratios:
			ratios += "%.2f " % r
		print("%-22s %-3s %5.0f %5.0f %5.0f %5.0f %6.0f %5.0f | %s· %.2f" % [id,
			entry.get("class",""), s.idle_rpm, s.peak_torque_rpm, s.redline_rpm, s.launch_rpm,
			s.peak_torque_nm, s.mass, ratios, s.final_drive])
	print()
	print("%-22s %6s %6s %6s %6s | %s" % ["araç","kusursz","iyi(.7)","zayıf(.3)","0-100","vites devirleri"])
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		var s: DragRaceSim.EngineSpec = DragRaceSim.spec_of(id)
		var perfect: DragRaceSim.Run = DragRaceSim.drive(id, 0.0, 1.0, 1.0, null)
		var mid: DragRaceSim.Run = DragRaceSim.drive(id, 0.0, 0.7, 0.7, null)
		var weak: DragRaceSim.Run = DragRaceSim.drive(id, 0.0, 0.3, 0.3, null)
		var shifts: String = ""
		for r: float in s.shift_rpm:
			shifts += "%.0f " % r
		print("%-22s %6.2f %6.2f %6.2f %6.1f | %s" % [id, perfect.time, mid.time, weak.time,
			perfect.top_speed, shifts])
	quit(0)
