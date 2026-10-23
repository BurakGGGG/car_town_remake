extends SceneTree
## HUD'un 2B çizim çağrısı payı: dünya oturunca kümeler (sol üst, sağ üst, alt sütun, alt bar ve parçaları) tek tek
## gizlenir, çizim çağrısı farkı o kümenin maliyetidir. Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh \
##   res://qa/hud_draw_census.gd --display-driver x11 --disable-vsync --resolution 1152x648


func _initialize() -> void:
	_run.call_deferred()


func _calls() -> int:
	var total: int = 0
	for i: int in 6:
		await process_frame
	for i: int in 4:
		await RenderingServer.frame_post_draw
		total += int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	return roundi(total / 4.0)


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 120:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	await create_timer(5.0).timeout
	hud.router.close_all()
	(hud.get("_notice_queue") as Array).clear()
	var notice: Control = hud.get("_notice_plate") as Control
	if notice:
		notice.hide()
	await create_timer(1.0).timeout
	var base: int = await _calls()
	print("toplam: %d çağrı" % base)
	var parts: Array = [["sol üst", hud.top_left], ["sağ üst", hud.top_right], ["alt sütun", hud.bottom],
		["alt sıra (NavRow)", hud.garage_button.get_parent()], ["HARİTA plakası", hud.map_button]]
	for part: Array in parts:
		var node: CanvasItem = part[1]
		var was: bool = node.visible
		node.visible = false
		var without: int = await _calls()
		node.visible = was
		print("%-26s %4d çağrı" % [part[0], base - without])
	var root_hud: CanvasItem = hud.get_node("Root") as CanvasItem
	root_hud.visible = false
	print("%-26s %4d çağrı" % ["HUD kökü (tümü)", base - await _calls()])
	root_hud.visible = true
	quit()
