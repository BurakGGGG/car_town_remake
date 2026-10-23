extends SceneTree
## EKRAN AÇILIŞ TAKILMASI (profilleyicisiz): router.open'ın kendi süresi + sonraki karelerin süreleri.
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/open_hitch.gd --display-driver x11 \
##   --disable-vsync --resolution 1152x648 -- garage showroom ...

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 120:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	await create_timer(6.0).timeout
	Engine.max_fps = 0
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	for round: int in 2:
		for id: String in ids:
			hud.router.close_all()
			for i: int in 30:
				await process_frame
			var t0: int = Time.get_ticks_usec()
			hud.router.open(StringName(id))
			var open_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			var frames: PackedFloat32Array = PackedFloat32Array()
			var last: int = Time.get_ticks_usec()
			for i: int in 20:
				await process_frame
				var now: int = Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
			var worst: float = 0.0
			for f: float in frames:
				worst = maxf(worst, f)
			print("%s #%d: open() %.1f ms · kareler %s · en uzun %.1f ms" % [id, round + 1, open_ms,
				", ".join(Array(frames.slice(0, 6)).map(func(f: float) -> String: return "%.0f" % f)), worst])
	quit()
