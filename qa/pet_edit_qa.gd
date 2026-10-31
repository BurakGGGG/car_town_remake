extends SceneTree
## GARAJ DOSTLARI QA: GARAJI DÜZENLE'deki EVCİL HAYVAN modu (plaka çizimi + 6 kartlık şerit) ve yakın kamera kartında
## günlük sevgi satırı / sınır uyarısı. Kareler ~/Projects/ct_shots/pets/duzenle/. Kayıt yalıtılmış.
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_edit_qa.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/duzenle/"

var _n: int = 0


func _initialize() -> void:
	create_timer(200.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _shot(label: String) -> void:
	for i: int in 3:
		await process_frame
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
	await _wait(5.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	pets.reset()
	pets.adopt("Paşa")
	await _until(func() -> bool: return world.actor() != null, 5.0)
	# GARAJI DÜZENLE → EVCİL HAYVAN
	hud.router.open(&"garage_edit")
	await _wait(1.5)
	var edit: GarageEditScreen = hud.garage_edit_screen
	edit._on_mode_pressed(&"pets")
	await _wait(1.5)
	await _shot("duzenle_evcil_hayvan")
	print("QA kartlar: ", edit._cards.keys())
	hud.router.close_all()
	await _wait(1.0)
	# Yakın kamera: 5 sevgi, sonra sınır
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 10.0)
	await _wait(0.5)
	await _shot("kart_bugun_0")
	for i: int in 7:
		pets._last_pet_msec = -100000
		closeup._pet()
		await _wait(0.25)
	await _wait(0.3)
	await _shot("kart_sinir_doldu")
	print("QA bugün ", pets.love_today(), " kalan ", pets.love_left(), " dostluk ", pets.friendship())
	quit(0)
