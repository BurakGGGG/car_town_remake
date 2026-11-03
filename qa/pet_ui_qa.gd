extends SceneTree
## GARAJ DOSTLARI arayüz QA: sv4 → sv5 (SEVİYE ATLADIN'da YENİ DOST) → geliş sinematiği → künye ad ekranı → ad →
## yakın kamera (kedi kartı) → sevme → olta → numara → kapat. Her adımda kare. Kayıt yalıtılmış (QA_SAVE kopyası).
## Kullanım: QA_SAVE=<savegame.json> tools/qa_isolated.sh res://qa/pet_ui_qa.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/arayuz/"

var _n: int = 0


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	_n += 1
	root.get_texture().get_image().save_png(OUT + "%02d_%s.png" % [_n, label])
	print("QA kare %02d_%s" % [_n, label])


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait(3.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pets.reset()
	progress.load_state(4, 0, progress.gems)
	await _wait(0.5)
	progress.add_xp(progress.xp_to_next() + 5)   # sv5 → SEVİYE ATLADIN + geliş bekler
	await _wait(2.0)
	_shot("seviye_atladin")
	# Seviye kartını kapat (DEVAM), geliş sakin anda başlar
	var screen: Control = hud.level_up_screen
	for i: int in 6:
		if screen == null or not screen.visible:
			break
		for b: Node in screen.find_children("*", "PlateButton", true, false):
			var pb: PlateButton = b as PlateButton
			if pb.visible and not pb.disabled and pb.text != "" and not (pb is AdOfferButton):
				pb.pressed.emit()
				break
		await _wait(1.0)
	print("QA geliş bekliyor: ", pets.is_arrival_pending())
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	await _until(func() -> bool: return closeup.visible, 12.0)
	await _wait(2.2)
	_shot("gelis_yuruyor")
	var name_screen: PetNameScreen = closeup.name_screen()
	await _until(func() -> bool: return name_screen.visible, 20.0)
	await _wait(0.8)
	_shot("kunye_bos")
	var edit: LineEdit = name_screen.find_children("*", "LineEdit", true, false).front() as LineEdit
	edit.text = "Paşa"
	edit.text_changed.emit("Paşa")
	await _wait(0.4)
	_shot("kunye_pasa")
	edit.text_submitted.emit("Paşa")
	await _until(func() -> bool: return pets.is_adopted(), 3.0)
	await _wait(1.2)
	_shot("kart_ilk")
	# Sev: dokunuşu kedinin üstüne ver
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	await _until(func() -> bool: return closeup._ready_to_pet, 6.0)
	var s: Dictionary = closeup._cat_screen()
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = s["center"]
	closeup._gui_input(press)
	await _wait(0.4)
	_shot("seviliyor")
	# Numaralar açılsın (dostluk 10)
	for i: int in 12:
		pets._last_pet_msec.clear()
		pets._cur()["love_day"] = ""   # günlük sınırı atla (QA)
		pets.pet()
	closeup._refresh_card()
	await _wait(2.0)
	_shot("numara_acik")
	world.closeup_clips([&"trick_paw"])
	await _wait(0.9)
	_shot("pati_ver")
	await _wait(1.6)
	# Olta
	closeup._set_play(true)
	await _wait(0.8)
	s = closeup._cat_screen()
	var head: Vector2 = s["head"]
	for k: int in 40:
		closeup._toy_target = head + Vector2(-220.0 + 5.0 * k, -30.0 + 20.0 * sin(k * 0.5))
		await process_frame
	await _wait(0.3)
	_shot("olta")
	await _wait(1.2)
	_shot("olta_atlayis")
	closeup._set_play(false)
	await _wait(1.0)
	hud.router.back()
	await _wait(1.0)
	_shot("garaj_donus")
	quit(0)
