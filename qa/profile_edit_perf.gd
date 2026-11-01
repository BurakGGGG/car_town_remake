extends SceneTree
## PROFİL › DÜZENLE süreleri: açılış, FOTOĞRAF (36 avatar) / ÇERÇEVE (28) sekmesine geçiş, avatara / çerçeveye dokunma.
## Her işlem 5 kez: çağrı + sonraki 2 kare, boşta 2 karenin süresi düşülür (FPS sınırı kapalı). Masaüstü; telefonda ~5–8 kat.
## tools/qa_isolated.sh res://qa/profile_edit_perf.gd --display-driver x11 --disable-vsync --resolution 1152x648


func _initialize() -> void:
	_run.call_deferred()


## Çağrı + ardından gelen 2 karenin süresi, eksi boşta 2 karenin süresi (ertelenen yeniden kurulum, queue_free dahil).
var _idle_ms: float = 0.0


func _ms(work: Callable) -> float:
	var t0: int = Time.get_ticks_usec()
	work.call()
	await process_frame
	await process_frame
	return maxf((Time.get_ticks_usec() - t0) / 1000.0 - _idle_ms, 0.0)


func _measure_idle() -> void:
	var total: float = 0.0
	for i: int in 10:
		var t0: int = Time.get_ticks_usec()
		await process_frame
		await process_frame
		total += (Time.get_ticks_usec() - t0) / 1000.0
	_idle_ms = total / 10.0
	print("PERF boşta 2 kare: %.2f ms" % _idle_ms)


func _avg(label: String, work: Callable, n: int = 5) -> void:
	var total: float = 0.0
	var worst: float = 0.0
	for i: int in n:
		var ms: float = await _ms(work)
		total += ms
		worst = maxf(worst, ms)
		await process_frame
	print("PERF %-34s ort %6.2f ms  en kötü %6.2f ms" % [label, total / n, worst])


func _run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: quit(1))
	OS.set_environment("CT_NO_TUTORIAL", "1")
	change_scene_to_file("res://Main.tscn")
	for i: int in 120:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(30, 0, 5000)
	var screen: ProfileEditScreen = hud.profile_edit_screen
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i: int in 30:
		await process_frame
	await _measure_idle()
	await _avg("açılış (PROFİL + DÜZENLE)", func() -> void:
		hud.router.close_all()
		hud.router.open(&"profile")
		hud.router.open(&"profile_edit"))
	await _avg("sekme FOTOĞRAF (36 avatar)", func() -> void: screen.call("_select_tab", 0))
	var ids: Array[String] = ["p01", "p23", "p25", "p03"]
	var k: Array[int] = [0]
	await _avg("avatara dokun (seçim)", func() -> void:
		var pick: AvatarButton = screen.find_child("Preset_" + ids[k[0] % ids.size()], true, false) as AvatarButton
		k[0] += 1
		pick.pressed.emit())
	await _avg("kilitli avatara dokun (koşul)", func() -> void:
		(screen.find_child("Preset_p14", true, false) as AvatarButton).pressed.emit())
	await _avg("sekme ÇERÇEVE (28)", func() -> void: screen.call("_select_tab", 1))
	var frames: Array[String] = ["bronze", "silver", "hazard", "plate"]
	await _avg("çerçeveye dokun (seçim)", func() -> void:
		var pick: AvatarButton = screen.find_child("Frame_" + frames[k[0] % frames.size()], true, false) as AvatarButton
		k[0] += 1
		if pick:
			pick.pressed.emit())
	quit(0)
