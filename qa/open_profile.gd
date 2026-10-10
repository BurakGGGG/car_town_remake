extends SceneTree
## Ekran açılış maliyeti: görevler (başarım sekmesi) + diğer ekranların açılış sonrası en uzun karesi.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/open_profile.gd --resolution 1152x648
func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 180:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false)
	var ms: Node = hud.router.screen(&"quests")
	ms.call("_set_tab", 2)
	var t0: int = Time.get_ticks_usec()
	ms.call("_refresh")
	print("ÖLÇÜM başarım sekmesi yenileme: %.1f ms" % [(Time.get_ticks_usec() - t0) / 1000.0])
	for id: StringName in [&"quests", &"showroom", &"collection", &"garage_edit", &"garage", &"drag_race", &"settings"]:
		for i: int in 30:
			await process_frame
		var o0: int = Time.get_ticks_usec()
		hud.router.open(id)
		var open_ms: float = (Time.get_ticks_usec() - o0) / 1000.0
		var worst: float = 0.0
		for i: int in 20:
			var f0: int = Time.get_ticks_usec()
			await process_frame
			worst = maxf(worst, (Time.get_ticks_usec() - f0) / 1000.0)
		print("ÖLÇÜM %-12s open() %.1f ms | sonraki 20 karede en uzun %.1f ms" % [id, open_ms, worst])
		hud.router.close_all()
	quit(0)
