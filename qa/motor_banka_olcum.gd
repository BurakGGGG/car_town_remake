extends SceneTree
## MOTOR SESİ BANKALARI ölçümü: hepsini yükler (süre), QOA mı, döngü sınırları, bir örnek bankanın içeriği.
##   godot-4 --headless --path . -s res://qa/motor_banka_olcum.gd
func _initialize() -> void:
	var t0: int = Time.get_ticks_usec()
	var n: int = 0
	for entry: Dictionary in CarCatalog.all():
		var b: EngineBank = EngineBank.for_vehicle(StringName(entry["id"]))
		n += 1 if b and b.on_loops.size() > 0 and b.on_loops[0].format == AudioStreamWAV.FORMAT_QOA else 0
	var t1: int = Time.get_ticks_usec()
	print("yüklenen QOA banka: %d, toplam %.1f ms, ortalama %.2f ms" % [n, (t1 - t0) / 1000.0, (t1 - t0) / 1000.0 / n])
	var b: EngineBank = EngineBank.for_vehicle(&"chevrolet_camaro")
	print(b.rpms, " start_idle_at ", b.start_idle_at, " loop_end ", b.on_loops[0].loop_end, " mode ", b.on_loops[0].loop_mode, " len ", b.on_loops[0].get_length(), " runtime ", b.runtime)
	for id: StringName in [&"lambo_huracan", &"tofas_sahin", &"chevrolet_camaro", &"tesla_model_y", &"vw_passat_b55"]:
		var bank: EngineBank = EngineBank.for_vehicle(id)
		var on: PackedStringArray = PackedStringArray()
		var off: PackedStringArray = PackedStringArray()
		for v: float in bank.on_db:
			on.append("%.1f" % v)
		for v: float in bank.off_db:
			off.append("%.1f" % v)
		print("%-16s gaz açık dB [%s]  gaz kesik dB [%s]" % [id, ", ".join(on), ", ".join(off)])
	quit()
