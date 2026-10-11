extends SceneTree
## TAMİR BAŞLANGICI TAKILMASI — TAMİRE AL anından sonraki karelerde en uzun kare ve betik süresi.
## İki tamir art arda ölçülür: ilki shader derlemesi / ilk kullanım maliyetini, ikincisi kalıcı maliyeti gösterir.
## Takılan karede (> 21 ms) ağaca eklenen düğümler de basılır. Ölçüm ve çözüm: vfx/world_prewarm.gd.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/repair_hitch.gd --resolution 1152x648 [-- nohud | warmbubble]

const WATCH: int = 90


func _initialize() -> void:
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


var _added: Array = []


func _on_added(node: Node) -> void:
	_added.append("%s(%s)" % [node.name, node.get_class()])


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	var repairs: RepairManager = get_first_node_in_group("repair_manager")
	if OS.get_cmdline_user_args().has("warmbubble"):
		var bubble: CarBubble = CarBubble.new()
		get_root().get_viewport().get_camera_3d().get_parent().add_child(bubble)
		var cam: Camera3D = get_root().get_viewport().get_camera_3d()
		bubble.global_position = cam.global_position - cam.global_basis.z * 3.0
		bubble.show_text("TAMİR +150 ₺", CarBubble.GLYPH_WRENCH)
		await _frames(3)
		bubble.queue_free()
		await _frames(30)
	node_added.connect(_on_added)
	if OS.get_cmdline_user_args().has("nohud"):
		for layer: Node in get_root().find_children("HUD", "", true, false):
			if layer is CanvasLayer:
				(layer as CanvasLayer).visible = false
	for round: int in 2:
		var car: TrafficVehicle = null
		for node: Node in get_root().find_children("*", "TrafficVehicle", true, false):
			if (node as TrafficVehicle).mode == TrafficVehicle.Mode.TRAFFIC:
				car = node
				break
		if car == null:
			print("araç yok")
			break
		car.fault = RepairType.by_id(&"body")
		car.mode = TrafficVehicle.Mode.REPAIR_WAITING
		var worst: float = 0.0
		var worst_proc: float = 0.0
		var worst_at: float = 0.0
		var t0: int = Time.get_ticks_usec()
		_added.clear()
		var ok: bool = repairs.start_repair(car)
		print("  start_repair sırasında eklenen: %s" % str(_added.slice(0, 20)))
		var call_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		for i: int in WATCH:
			var f0: int = Time.get_ticks_usec()
			_added.clear()
			await process_frame
			var p1: int = Time.get_ticks_usec()
			await RenderingServer.frame_post_draw
			var draw_ms: float = float(Time.get_ticks_usec() - p1) / 1000.0
			if i < 3:
				print("  kare %d: süreç→çizim %.1f ms, çizim %.1f ms" % [i, float(p1 - f0) / 1000.0, draw_ms])
			worst = maxf(worst, float(Time.get_ticks_usec() - f0) / 1000.0)
			var proc: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			var frame: float = float(Time.get_ticks_usec() - f0) / 1000.0
			if frame > 21.0:
				print("  kare %d (%.2f sn): %.1f ms, eklenen %d düğüm: %s" % [i, float(Time.get_ticks_usec() - t0) / 1e6, frame, _added.size(), str(_added.slice(0, 12))])
			if proc > worst_proc:
				worst_proc = proc
				worst_at = float(Time.get_ticks_usec() - t0) / 1e6
		print("tamir %d (%s): start_repair %.1f ms · en uzun kare %.1f ms · en uzun betik %.1f ms (%.2f sn'de) " % [
			round + 1, ok, call_ms, worst, worst_proc, worst_at])
		await _frames(60)
	quit(0)
