extends SceneTree
## Merdiven panosu kare hızı sondası: panoyu açar, parçaları sırayla gizleyip her adımda 1 sn'deki kare sayısını yazar.

func _initialize() -> void:
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _fps(label: String) -> void:
	var f0: int = Engine.get_process_frames()
	await _wait(1.0)
	print("FPS %-28s %d  · process %.1f ms · physics %.1f ms · nodes %d" % [label, Engine.get_process_frames() - f0,
		Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and (current_scene == null or current_scene.name == "LoadingScreen" \
			or root.get_node_or_null("LoadingScreen") != null):
		await process_frame
	await _wait(2.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	await _fps("dünya")
	var shop_row: Control = hud.find_child("ShopRow", true, false) as Control
	shop_row.visible = false
	await _fps("dünya, tabela sırası gizli")
	shop_row.visible = true
	hud.router.open(&"login_ladder")
	await _wait(1.5)
	await _fps("pano açık")
	var screen: LoginLadderScreen = hud.login_ladder_screen
	screen.set_process(false)
	await _fps("pano _process kapalı")
	(screen.get("_hero_slot") as Control).visible = false
	await _fps("+ ay ödülü 3B gizli")
	(screen.get("_rays") as Control).visible = false
	await _fps("+ ışınlar gizli")
	var column: VBoxContainer = screen.get("_column")
	column.get_child(2).get_child(0).visible = false
	await _fps("+ merdiven gizli")
	quit(0)
