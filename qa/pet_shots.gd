extends SceneTree
## GARAJ DOSTLARI taslak arka planları: HUD gizli, temiz oyun görüntüleri (yakın kamera ekranı ve geliş sinematiği
## taslakları bunların üstüne çizilir). Kayıt yalıtılmış klasörde (QA_SAVE kopyası).
## Kullanım: QA_SAVE=<savegame.json> tools/qa_isolated.sh res://qa/pet_shots.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/taslak/"

var _world: PetWorld
var _cam: Camera3D


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	_world = get_first_node_in_group("pet_world") as PetWorld
	pets.adopt("Tekir")
	await _until(func() -> bool: return _world.actor() != null, 5.0)
	hud.visible = false
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var floor: Rect2 = view.area().floor_rect
	# Yakın kamera: kedi garaj ağzına yakın boş bir yerde, kameraya (güneydoğu) dönük oturur
	var spot: Vector2 = _world._nearest_free(Vector2(floor.get_center().x, floor.end.y - 0.35))
	var game_cam: Camera3D = current_scene.get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 34.0
	_cam.near = 0.005
	current_scene.add_child(_cam)
	var cat_pos: Vector3 = Vector3(spot.x, view.area().floor_y, spot.y)
	var to_cam: Vector3 = Vector3(0.62, 0.0, 0.78).normalized()
	var face_cam: float = atan2(-to_cam.x, -to_cam.z)   # −Z ileri: ileri(yaw) = (−sin, −cos) → yüz kameraya
	_world.hold(spot, face_cam, &"sit_idle")
	_cam.current = true
	# Kedi kadrajın SOL-ORTASINDA (sağda menü alanı): kamera hedefi kedinin biraz sağı
	var right: Vector3 = to_cam.cross(Vector3.UP).normalized() * -1.0
	_cam.global_position = cat_pos + to_cam * 0.36 + Vector3(0, 0.11, 0) + right * -0.05
	_cam.look_at(cat_pos + Vector3(0, 0.045, 0) + right * -0.05, Vector3.UP)
	await _wait(2.5)
	_shot("yakin_oturan")
	_world.actor().play(&"pet", 0.2)
	await _wait(1.1)
	_shot("yakin_seviliyor")
	_world.actor().play(&"play_crouch", 0.2)
	await _wait(1.2)
	_shot("yakin_oyun")
	# Geliş sinematiği: oyun kamerası garaj ağzına bakar, kedi sokaktan içeri yürür
	game_cam.current = true
	var door: Vector2 = Vector2(floor.get_center().x, floor.end.y + 0.12)
	_world.hold(door, 0.0, &"walk")
	var wc: WorldCamera = game_cam as WorldCamera
	for i: int in 30:
		wc.follow(Vector3(door.x, 0.0, door.y - 0.25), 1.0)
		await process_frame
	await _wait(1.0)
	_shot("gelis_kapi")
	_world.hold(Vector2(door.x, door.y - 0.28), face_cam, &"sit_idle")
	await _wait(1.2)
	_shot("gelis_bakiyor")
	quit(0)
