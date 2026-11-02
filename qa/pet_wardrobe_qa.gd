extends SceneTree
## GARAJ DOSTLARI yakın kamera GARDIROP QA (2026-11-03, taslak C): sol kart + sağda gardırop (AKSESUAR 2×2, KIYAFET
## 2×2); kıyafet dene → al → giy, bandana çakışması, iki panel arasında bildirim satır kırma. Kareler
## ~/Projects/ct_shots/pets/gardirop/<çözünürlük>_<dil>_*.png.
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 [QA_LANG=de] tools/qa_isolated.sh res://qa/pet_wardrobe_qa.gd --resolution 1280x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/gardirop/"

var _tag: String = ""


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + "%s_%s.png" % [_tag, label])
	print("QA kare ", _tag, "_", label)


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
	var win: Vector2i = root.get_window().size
	_tag = "%dx%d_%s" % [win.x, win.y, TranslationServer.get_locale().substr(0, 2)]
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	pets.reset()
	pets.adopt("Paşa")
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 35})
	progress.load_state(maxi(progress.level, 6), 0, 900)
	if not await _until(func() -> bool: return world.actor() != null, 5.0):
		print("QA HATA: kedi sahnede yok")
		quit(1)
		return
	pets.grant_accessory(&"collar_red")
	pets.grant_accessory(&"bandana")
	pets.equip(&"neck", &"collar_red")
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 8.0)
	await _wait(0.8)
	_shot("1_gardirop")
	closeup._on_accessory(&"race_jacket")
	await _wait(0.9)
	_shot("2_deneme_yaris_montu")
	closeup._on_accessory(&"race_jacket")
	await _wait(1.0)
	_shot("3_alindi_yaris_montu")
	closeup._on_accessory(&"bandana")
	await _wait(0.9)
	_shot("4_bandana_mont_cikti")
	progress.load_state(progress.level, progress.xp, 100)
	closeup._on_accessory(&"leather_jacket")
	await _wait(0.5)
	closeup._on_accessory(&"leather_jacket")
	await _wait(0.6)
	_shot("5_gem_yetmiyor")
	print("QA market açık: ", hud.router.is_open(&"gem_store"), " takılı: ", pets.worn())
	quit(0)
