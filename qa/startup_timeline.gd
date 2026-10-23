extends SceneTree
## AÇILIŞ ZAMAN ÇİZELGESİ: gerçek ilk sahne (yükleme ekranı) → Main; yükleme ekranının kalktığı an, en uzun kareler ve
## 100 ms'yi aşan her kare (soğuk / sıcak shader önbelleği kıyası için). Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 \
##   tools/qa_isolated.sh res://qa/startup_timeline.gd --display-driver x11 --disable-vsync --resolution 1152x648

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	var t0: int = Time.get_ticks_msec()
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var last: int = Time.get_ticks_usec()
	var loading_gone: int = -1
	var loading_seen: int = -1
	var long_frames: Array[String] = []
	var after_worst: float = 0.0
	while Time.get_ticks_msec() - t0 < 25000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		var at: int = Time.get_ticks_msec() - t0
		var loading: bool = root.get_node_or_null("LoadingScreen") != null or (current_scene != null and current_scene.name == "LoadingScreen")
		if loading and loading_seen < 0:
			loading_seen = at
		# Sahne değişimi ertelenir: yükleme ekranı belirmeden önceki boş kareler "kalktı" sayılmasın (2026-10-23 düzeltmesi)
		if not loading and loading_seen >= 0 and loading_gone < 0:
			loading_gone = at
		if ms > 100.0:
			long_frames.append("%d ms@%.1fs%s" % [roundi(ms), at / 1000.0, "" if loading else "*"])
		if loading_gone >= 0 and at - loading_gone < 10000:
			after_worst = maxf(after_worst, ms)
	print("YÜKLEME EKRANI: %.2f sn'de belirdi, %.2f sn'de kalktı" % [loading_seen / 1000.0, loading_gone / 1000.0])
	print("kalktıktan sonra ilk 10 sn en uzun kare: %.0f ms" % after_worst)
	print("100 ms+ kareler (* = yükleme ekranı kalktıktan sonra): %s" % ", ".join(long_frames))
	quit()
