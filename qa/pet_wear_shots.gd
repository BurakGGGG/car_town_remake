extends SceneTree
## GARAJ DOSTLARI kıyafet/tüy kartı TASLAK ARKA PLANLARI (2026-11-03): yakın kamera açık, kedi kartı GİZLİ (taslak
## üstüne çizilir), farklı tüy + kıyafet. Kareler ~/Projects/ct_shots/pets/kiyafet_taslak/.
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_wear_shots.gd --resolution 1200x540
const OUT: String = "/home/burak/Projects/ct_shots/pets/kiyafet_taslak/"


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("QA kare ", label)


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
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	pets.reset()
	pets.adopt("Paşa")
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 35})
	progress.load_state(maxi(progress.level, 6), 0, 3000)
	if not await _until(func() -> bool: return world.actor() != null, 5.0):
		print("QA HATA: kedi sahnede yok")
		quit(1)
		return
	for id: StringName in [&"vest", &"sweater", &"race_jacket", &"leather_jacket", &"collar_red", &"cap"]:
		pets.grant_accessory(id)
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	var looks: Array = [[&"white", &"race_jacket", &""], [&"black", &"leather_jacket", &"collar_red"],
		[&"orange", &"vest", &"cap"], [&"white", &"sweater", &"collar_red"]]
	pets.set_fur(looks[0][0])
	pets.equip(&"body", looks[0][1])
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 8.0)
	closeup._card.visible = false
	for k: int in looks.size():
		pets.set_fur(looks[k][0])
		pets.equip(&"body", looks[k][1])
		pets.equip(&"neck", looks[k][2] if PetManager.slot_of(looks[k][2]) == &"neck" else &"")
		pets.equip(&"head", looks[k][2] if PetManager.slot_of(looks[k][2]) == &"head" else &"")
		world.actor().set_eyes_shut(false)
		await _wait(1.6)
		_shot("arka_%d_%s_%s" % [k, looks[k][0], looks[k][1]])
	closeup._card.visible = true
	await _wait(0.4)
	_shot("simdiki_kart")
	quit(0)
