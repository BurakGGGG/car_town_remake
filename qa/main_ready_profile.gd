extends SceneTree
## ANA SAHNE KURULUM PROFİLİ: Main.tscn'nin yüklenmesi, örneklenmesi ve ağaca eklenmesi (_ready zinciri) ayrı ayrı; ağaca
## eklemede kök çocuklar TEK TEK eklenerek her birinin payı ölçülür (yükleme ekranındaki donmanın kaynağı).
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/main_ready_profile.gd --display-driver x11

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var t: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://Main.tscn") as PackedScene
	var load_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	t = Time.get_ticks_usec()
	var main: Node = scene.instantiate()
	var inst_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	var children: Array[Node] = []
	for child: Node in main.get_children():
		children.append(child)
		main.remove_child(child)
	t = Time.get_ticks_usec()
	root.add_child(main)
	current_scene = main
	var self_ms: float = (Time.get_ticks_usec() - t) / 1000.0
	var parts: Array[String] = []
	var total: float = 0.0
	for child: Node in children:
		t = Time.get_ticks_usec()
		main.add_child(child)
		var ms: float = (Time.get_ticks_usec() - t) / 1000.0
		total += ms
		if ms >= 5.0:
			parts.append("%s %.0f ms" % [child.name, ms])
	t = Time.get_ticks_usec()
	await process_frame
	var first_frame: float = (Time.get_ticks_usec() - t) / 1000.0
	print("load %.0f ms · instantiate %.0f ms · Main kendisi %.0f ms · çocuklar %.0f ms · ilk kare %.0f ms" % [load_ms, inst_ms,
		self_ms, total, first_frame])
	print("  " + " · ".join(parts))
	quit()
