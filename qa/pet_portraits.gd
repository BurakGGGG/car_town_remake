extends SceneTree
## Hayvan portreleri (taslak / ekran görselleri): turuncu, beyaz, siyah kedi oturur, gözler açık, aksesuarsız; yakın
## kamera, HUD gizli. Kareler ~/Projects/ct_shots/pets/portre/<renk>.png
## Kullanım: QA_SAVE=<kayıt> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_portraits.gd --resolution 1200x900
const OUT: String = "/home/burak/Projects/ct_shots/pets/portre/"


func _initialize() -> void:
	create_timer(150.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


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
	var world: PetWorld = get_first_node_in_group("pet_world") as PetWorld
	pets.reset()
	pets.adopt("Paşa")
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 35})
	if not await _until(func() -> bool: return world.actor() != null, 5.0):
		print("QA HATA: kedi sahnede yok")
		quit(1)
		return
	hud.visible = false
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var floor: Rect2 = view.area().floor_rect
	var spot: Vector2 = world._nearest_free(Vector2(floor.get_center().x, floor.end.y - 0.35))
	var cat_pos: Vector3 = Vector3(spot.x, view.area().floor_y, spot.y)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 26.0
	cam.near = 0.005
	current_scene.add_child(cam)
	cam.current = true
	var yaw: float = atan2(-0.62, -0.78)
	var to_front: Vector3 = Vector3(0.62, 0.0, 0.78).normalized()
	for fur: StringName in [&"orange", &"white", &"black"]:
		pets.set_fur(fur)
		world.hold(spot, yaw, &"sit_idle")
		cam.global_position = cat_pos + to_front * 0.30 + Vector3(0, 0.07, 0)
		cam.look_at(cat_pos + Vector3(0, 0.05, 0), Vector3.UP)
		await _wait(1.3)
		var actor: PetActor = world.actor()
		actor._blink_left = 100.0
		actor._blinking = 0.0
		actor.set_eyes_shut(false)
		await _wait(0.3)
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(OUT + String(fur) + ".png")
		print("QA kare ", fur)
	quit(0)
