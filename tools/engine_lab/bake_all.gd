extends SceneTree
## Bütün araçların motor sesi bankalarını pişirir (laboratuvardaki TÜMÜNÜ PİŞİR'in başsız eşi): her araç için kayıtlı
## ön ayar (res://vehicles/sound/presets/<id>.json) ya da otomatik ayar → res://vehicles/sound/banks/<id>.res (QOA).
##   godot-4 --headless --path . -s res://tools/engine_lab/bake_all.gd [-- <araç_id> …]
## Araç verilmezse katalogdaki hepsi. Sonunda toplam boyutu yazar.


func _initialize() -> void:
	EngineSynth.prepare()
	var ids: Array[StringName] = []
	for arg: String in OS.get_cmdline_user_args():
		ids.append(StringName(arg))
	if ids.is_empty():
		for entry: Dictionary in CarCatalog.all():
			ids.append(StringName(entry["id"]))
	var total: int = 0
	var started: int = Time.get_ticks_msec()
	for id: StringName in ids:
		var preset: Dictionary = EnginePreset.for_vehicle(id)
		var jobs: Array = EngineBank.jobs_for(preset)
		var results: Array = []
		results.resize(jobs.size())
		var mutex: Mutex = Mutex.new()
		var task: int = WorkerThreadPool.add_group_task(func(index: int) -> void:
			var result: Variant = EngineBank.run_job(preset, jobs[index])
			mutex.lock()
			results[index] = result
			mutex.unlock(), jobs.size(), -1, true, "bake")
		WorkerThreadPool.wait_for_group_task_completion(task)
		var bank: EngineBank = EngineBank.assemble(id, preset, jobs, results, true)
		bank.custom = EnginePreset.has_custom(id)
		var err: Error = bank.save_to_disk()
		var bytes: int = FileAccess.get_file_as_bytes(EngineBank.bank_path(id)).size()
		total += bytes
		print("%-26s %-9s %s %6.1f KB %s" % [id, preset["layout"], "elle" if bank.custom else "oto ", bytes / 1024.0,
			"" if err == OK else error_string(err)])
	print("TOPLAM %d araç, %.2f MB, %.1f sn" % [ids.size(), total / 1048576.0, (Time.get_ticks_msec() - started) / 1000.0])
	quit()
