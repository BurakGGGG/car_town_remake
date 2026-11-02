extends SceneTree
## GARAJ DOSTLARI kıyafet + tüy rengi QA (2026-11-03): üç tüy rengi (turuncu / beyaz mavi göz / siyah yeşil göz) ve
## dört gövde kıyafeti (İKAZ YELEĞİ, ÖRGÜ KAZAK, YARIŞ MONTU, DERİ CEKET) oyunda: yakın kamerada pozlar (oturma, somun,
## uyku, yürüme, yuvarlanma, yalanma, kaşınma, zıplama) — deri gizleme maskesi ve bükülme; kapalı göz dokusu; yakın kamera
## kartı (taslak arka planı). Kareler ~/Projects/ct_shots/pets/kiyafet_oyun/. Kayıt yalıtılmış (QA_SAVE kopyası).
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_wear_qa.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/kiyafet_oyun/"

var _n: int = 0


func _initialize() -> void:
	create_timer(280.0).timeout.connect(func() -> void:
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
	progress.load_state(maxi(progress.level, 6), 0, 3000)
	if not await _until(func() -> bool: return world.actor() != null, 5.0):
		print("QA HATA: kedi sahnede yok")
		quit(1)
		return
	await _wait(1.0)
	for id: StringName in [&"vest", &"sweater", &"race_jacket", &"leather_jacket", &"collar_red", &"cap"]:
		pets.grant_accessory(id)

	# --- Yakın kamera kartı (taslak arka planı) ---
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	pets.set_fur(&"white")
	pets.equip(&"body", &"race_jacket")
	hud.router.open(&"pet_closeup")
	await _until(func() -> bool: return closeup._ready_to_pet, 8.0)
	await _wait(0.8)
	_shot("kart_beyaz_yaris_montu")
	pets.set_fur(&"black")
	pets.equip(&"body", &"leather_jacket")
	await _wait(0.8)
	_shot("kart_siyah_deri_ceket")
	pets.set_fur(&"orange")
	pets.equip(&"body", &"sweater")
	await _wait(0.8)
	_shot("kart_turuncu_kazak")
	world.closeup_clips([&"trick_roll"])
	await _wait(1.3)
	_shot("kart_turuncu_kazak_yuvarlanma")
	hud.router.back()
	await _wait(1.2)
	pets.equip(&"body", &"")

	# --- Pozlar: kamera yakında ---
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
	var yaw: float = atan2(-0.62, -0.78)   # yüz güneydoğu kameraya
	var to_front: Vector3 = Vector3(0.62, 0.0, 0.78).normalized()
	var to_side: Vector3 = Vector3(-0.78, 0.0, 0.62).normalized()
	# Üç renk yan yana bakış: çıplak, açık ve kapalı göz
	for fur: StringName in [&"orange", &"white", &"black"]:
		pets.set_fur(fur)
		for clip: StringName in [&"sit_idle", &"sleep"]:
			world.hold(spot, yaw, clip)
			cam.global_position = cat_pos + to_front * 0.36 + Vector3(0, 0.14, 0)
			cam.look_at(cat_pos + Vector3(0, 0.06, 0), Vector3.UP)
			await _wait(1.4)
			_shot("renk_%s_%s" % [fur, clip])
	var sets: Array = [[&"white", &"vest"], [&"black", &"race_jacket"], [&"orange", &"leather_jacket"],
		[&"white", &"sweater"]]
	var poses: Array = [[&"sit_idle", 1.0], [&"loaf", 1.5], [&"sleep", 1.5], [&"walk", 0.4], [&"trick_roll", 1.3],
		[&"groom", 1.4], [&"scratch", 1.2], [&"jump_air", 0.3], [&"play_crouch", 0.8]]
	for k: int in sets.size():
		pets.set_fur(sets[k][0])
		pets.equip(&"body", sets[k][1])
		pets.equip(&"neck", &"collar_red" if k % 2 == 0 else &"")
		for p: Array in poses:
			for side: int in 2:
				world.hold(spot, yaw, p[0])
				cam.global_position = cat_pos + (to_front if side == 0 else to_side) * 0.42 + Vector3(0, 0.16, 0)
				cam.look_at(cat_pos + Vector3(0, 0.05, 0), Vector3.UP)
				await _wait(float(p[1]))
				_shot("poz_%s_%s_%s_%s" % [sets[k][1], sets[k][0], p[0], "on" if side == 0 else "yan"])
	# Garaj kamerasından (oyuncunun gördüğü boy)
	hud.visible = true
	cam.current = false
	world.resume()
	await _wait(2.0)
	_shot("garaj_kamerasi")
	print("QA bitti: deri gizli=", world.actor().skin_hidden(), " tüy=", world.actor().fur())
	quit(0)
