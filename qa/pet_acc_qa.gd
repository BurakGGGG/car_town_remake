extends SceneTree
## GARAJ DOSTLARI aksesuar QA: yakın kamera kartındaki AKSESUAR rafı (kilitli → dene → al → tak / çıkar, elmas
## yetmeyince MARKET) ve aksesuarlı kedinin pozları (oturma, yalanma, kaşınma, yuvarlanma, uyku, yürüme) — deri
## bükülmesi boyunda düzgün mü. Kareler ~/Projects/ct_shots/pets/aksesuar_oyun/. Kayıt yalıtılmış (QA_SAVE kopyası).
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_acc_qa.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/aksesuar_oyun/"

var _n: int = 0


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
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
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	pets.reset()
	pets.adopt("Paşa")   # ilk sahiplenme sinyali PetWorld'e kediyi koydurur (load_state sinyal yaymaz)
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 35})
	progress.load_state(maxi(progress.level, 6), 0, 1000)
	if not await _until(func() -> bool: return world.actor() != null, 5.0):
		print("QA HATA: kedi sahnede yok")
		quit(1)
		return
	await _wait(1.0)

	# --- Raf akışı ---
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 8.0)
	await _wait(0.6)
	_shot("raf_kilitli")
	closeup._on_accessory(&"collar_red")
	await _wait(0.6)
	_shot("deneme_tasma")
	closeup._on_accessory(&"collar_red")
	await _wait(0.8)
	_shot("alindi_tasma")
	closeup._on_accessory(&"cap")
	await _wait(0.6)
	closeup._on_accessory(&"cap")
	await _wait(1.0)
	_shot("alindi_kasket")
	closeup._on_accessory(&"helmet")
	await _wait(0.7)
	_shot("deneme_kask")
	closeup._on_accessory(&"bandana")
	await _wait(0.6)
	closeup._on_accessory(&"bandana")
	await _wait(1.0)
	_shot("alindi_bandana_kask_denemesi_bitti")
	closeup._on_accessory(&"collar_red")
	await _wait(0.6)
	_shot("tasma_giyildi")
	world.closeup_clips([&"trick_beg"])
	await _wait(1.0)
	_shot("arka_ayaklar")
	await _wait(2.0)
	progress.load_state(progress.level, progress.xp, 30)
	closeup._on_accessory(&"helmet")
	await _wait(0.5)
	closeup._on_accessory(&"helmet")
	await _wait(0.8)
	_shot("elmas_yetmiyor_market")
	print("QA market açık: ", hud.router.is_open(&"gem_store"))
	hud.router.back()
	await _wait(0.8)
	_shot("marketten_donus_deneme_suruyor")
	hud.router.back()
	await _wait(1.2)
	print("QA kapanınca takılı: ", world.actor().worn_accessories(), " deneme: ", world.accessory_preview())

	# --- Pozlar: kamera yakında, iki takım ---
	hud.visible = false
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var floor: Rect2 = view.area().floor_rect
	var spot: Vector2 = world._nearest_free(Vector2(floor.get_center().x, floor.end.y - 0.35))
	var cat_pos: Vector3 = Vector3(spot.x, view.area().floor_y, spot.y)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	cam.near = 0.005
	current_scene.add_child(cam)
	cam.current = true
	var sets: Array = [[&"collar_red", &"cap"], [&"bandana", &"helmet"]]
	var poses: Array = [[&"sit_idle", 1.0], [&"loaf", 1.5], [&"groom", 1.4], [&"scratch", 1.2], [&"trick_roll", 1.3],
		[&"sleep", 1.5], [&"walk", 0.25], [&"walk", 0.5], [&"walk", 0.75], [&"jump_air", 0.3]]
	for k: int in sets.size():
		var ids: Array[StringName] = []
		ids.assign(sets[k])
		world.actor().set_accessories(ids)
		for p: Array in poses:
			for side: int in 2:
				var to_cam: Vector3 = (Vector3(0.62, 0.0, 0.78) if side == 0 else Vector3(-0.78, 0.0, 0.62)).normalized()
				var yaw: float = atan2(-0.62, -0.78)   # yüz güneydoğu kameraya
				world.hold(spot, yaw, p[0])
				cam.global_position = cat_pos + to_cam * 0.42 + Vector3(0, 0.16, 0)
				cam.look_at(cat_pos + Vector3(0, 0.05, 0), Vector3.UP)
				await _wait(float(p[1]))
				_shot("poz_%d_%s_%d_%s" % [k, p[0], int(float(p[1]) * 100), "on" if side == 0 else "yan"])
	world.actor().set_accessories(pets.worn())
	quit(0)
