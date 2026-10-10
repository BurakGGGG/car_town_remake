extends SceneTree
## Ekranı art arda açıp en uzun kareyi ölçer: ilk açılış maliyeti mi, her seferinde mi?
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/open_repeat.gd --resolution 1152x648 -- <ekran>
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var id: StringName = StringName(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else &"showroom"
	change_scene_to_file("res://Main.tscn")
	for i: int in 180:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false)
	for round: int in 3:
		hud.router.open(id)
		var worst: float = 0.0
		var worst_at: int = -1
		for i: int in 40:
			var f0: int = Time.get_ticks_usec()
			await process_frame
			var ms: float = (Time.get_ticks_usec() - f0) / 1000.0
			if ms > worst:
				worst = ms
				worst_at = i
		print("ÖLÇÜM %s %d. açılış: en uzun kare %.1f ms (%d. karede)" % [id, round + 1, worst, worst_at])
		hud.router.close_all()
		for i: int in 30:
			await process_frame
	quit(0)
