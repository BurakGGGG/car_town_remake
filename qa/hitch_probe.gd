extends SceneTree
## İLK DAKİKA TAKILMA SONDASI: gerçek açılış akışında (yükleme ekranı → oyun) her karede ağaca eklenen düğümleri sayar;
## uzun karede (> 200 ms) o kareden ve bir önceki kareden eklenenlerin özetini basar (takılmayı ne getirdi).
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/hitch_probe.gd --display-driver x11 --disable-vsync

var _added: Dictionary = {}


func _initialize() -> void:
	node_added.connect(func(node: Node) -> void:
		var key: String = node.get_class() if node.get_script() == null else String((node.get_script() as Script).resource_path.get_file())
		var parent_key: String = String(node.get_parent().name) if node.get_parent() else "?"
		key += " ← " + parent_key
		_added[key] = int(_added.get(key, 0)) + 1)
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	var t0: int = Time.get_ticks_msec()
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var last: int = Time.get_ticks_usec()
	var previous: Dictionary = {}
	while Time.get_ticks_msec() - t0 < 9000:
		var before: Dictionary = _added
		_added = {}
		await process_frame
		var now: int = Time.get_ticks_usec()
		var ms: float = (now - last) / 1000.0
		last = now
		var loading: bool = root.get_node_or_null("LoadingScreen") != null
		if ms > 200.0:
			print("== %.0f ms kare @ %.2f sn (yükleme ekranı: %s)" % [ms, (Time.get_ticks_msec() - t0) / 1000.0, loading])
			for source: Dictionary in [before, _added]:
				var keys: Array = source.keys()
				keys.sort_custom(func(a: String, b: String) -> bool: return int(source[a]) > int(source[b]))
				print("   eklenen: " + ", ".join(keys.slice(0, 8).map(func(k: String) -> String: return "%s ×%d" % [k, source[k]])))
	quit()
