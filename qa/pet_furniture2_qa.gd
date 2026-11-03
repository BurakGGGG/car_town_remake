extends SceneTree
## KEDİ EŞYALARI 2 QA (tools/decor/props_v11_kedi2.py): karton kutu / lastik yatak / hamak (yatak), tırmalama direği /
## mini garaj / sakura kedi ağacı (kule), su çeşmesi (kap) tek tek garaja konur; kedi her birini kullanır, yakın kare
## alınır. Sonunda bütün yeni kedi eşyaları birlikte geniş karede. Kareler ~/Projects/ct_shots/pets/esyalar2/.
## Kullanım: CT_NO_TUTORIAL=1 GODOT="timeout -k 5 420 godot-4" tools/qa_isolated.sh res://qa/pet_furniture2_qa.gd \
##             --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/esyalar2/"
var _n: int = 0
var _fails: int = 0
var _world: PetWorld
var _decor: DecorManager
var _view: GarageDecorView
var _cam: Camera3D


func _initialize() -> void:
	create_timer(400.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


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


func _place(item: StringName, near: Vector2) -> String:
	_decor.grant(item)
	var y: float = _view.area().floor_y
	var best: Vector3 = Vector3.INF
	var floor: Rect2 = _view.area().floor_rect
	var step: float = DecorGrid.CELL * 0.25
	var x: float = floor.position.x + step
	while x < floor.end.x - step:
		var z: float = floor.position.y + step
		while z < floor.end.y - step:
			var p: Vector3 = Vector3(x, y, z)
			if _view.is_valid(item, p, 0.0) and (best == Vector3.INF or Vector2(p.x, p.z).distance_to(near)
					< Vector2(best.x, best.z).distance_to(near)):
				best = p
			z += step
		x += step
	return _decor.add_instance(item, best, 0.0) if best != Vector3.INF else ""


func _look(at: Vector3, dist: float) -> void:
	_cam.global_position = at + Vector3(0.64, 0.5, 0.64).normalized() * dist
	_cam.look_at(at, Vector3.UP)


func _furn(iid: String) -> Dictionary:
	for f: Dictionary in _world._furniture():
		if f["iid"] == iid:
			return f
	return {}


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait(5.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var pets: PetManager = get_first_node_in_group("pets") as PetManager
	_world = get_first_node_in_group("pet_world") as PetWorld
	_decor = get_first_node_in_group("decor") as DecorManager
	_view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	pets.reset()
	pets.adopt("Paşa")
	if not await _until(func() -> bool: return _world.actor() != null, 5.0):
		print("QA HATA: kedi yok")
		quit(1)
		return
	var floor: Rect2 = _view.area().floor_rect
	var front: Vector2 = Vector2(floor.get_center().x, floor.end.y - 0.45)
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.005
	current_scene.add_child(_cam)
	_cam.current = true
	hud.visible = false

	for item: StringName in [&"cat_box", &"cat_tire_bed", &"cat_hammock"]:
		var iid: String = _place(item, front)
		await _wait(0.8)
		var f: Dictionary = _furn(iid)
		check(not f.is_empty(), "%s yerleşti ve kedi eşyası sayıldı" % item)
		if f.is_empty():
			continue
		_world.hold(_world._land_near(f["rect"]), 0.0, &"idle")
		_world.debug_do(&"bed")
		var ok: bool = await _until(func() -> bool: return _world.on_roof() and _world.is_asleep(), 25.0)
		var spot: Vector3 = (f["spots"] as Array)[0]
		check(ok and absf(_world.actor().global_position.y - spot.y) < 0.003,
			"%s: kedi içine girip uyudu (y %.4f / nokta %.4f)" % [item, _world.actor().global_position.y, spot.y])
		await _wait(1.2)
		_look(spot, 0.55)
		await _shot("%s_uyuyor" % item)
		_decor.remove_instance(iid)
		await _wait(0.6)

	for item: StringName in [&"cat_scratcher", &"cat_house", &"lux_cat_sakura"]:
		var iid: String = _place(item, front)
		await _wait(0.8)
		var f: Dictionary = _furn(iid)
		check(not f.is_empty(), "%s yerleşti ve kedi eşyası sayıldı" % item)
		if f.is_empty():
			continue
		_world.hold(_world._land_near(f["rect"]), 0.0, &"idle")
		_world.debug_do(&"tower")
		var ok: bool = await _until(func() -> bool: return _world.on_roof(), 20.0)
		await _wait(3.0)
		var spots: Array = f["spots"]
		var on_spot: bool = false   # iki noktalı kulede kedi %45 olasılıkla hemen tepeye de çıkar
		for sp: Vector3 in spots:
			on_spot = on_spot or absf(_world.actor().global_position.y - sp.y) < 0.003
		check(ok and on_spot, "%s: kedi üstüne çıktı" % item)
		_look(spots[0], 0.75)
		await _shot("%s_ustunde" % item)
		if spots.size() > 1:
			_world._react(func(gen: int) -> bool:
				if not await _world._jump_to(spots[1], gen):
					return false
				_world._perch_spot = 1
				if not await _world._turn_to(0.0, gen):
					return false
				if not await _world._once(&"sit_down", gen):
					return false
				_world.actor().play(&"sit_idle")
				return await _world._wait(30.0, gen))
			await _wait(3.5)
			check(absf(_world.actor().global_position.y - (spots[1] as Vector3).y) < 0.003, "%s: tepeye çıktı" % item)
			_look((spots[0] as Vector3).lerp(spots[1], 0.5), 1.0)
			await _shot("%s_tepede" % item)
		_decor.remove_instance(iid)
		await _wait(0.6)

	var fountain: String = _place(&"cat_fountain", front)
	await _wait(0.8)
	var fw: Dictionary = _furn(fountain)
	check(not fw.is_empty(), "su çeşmesi kedi kabı sayıldı")
	if not fw.is_empty():
		_world.hold(_world._land_near(fw["rect"]), 0.0, &"idle")
		_world.debug_do(&"eat")
		var ok: bool = await _until(func() -> bool: return _world.actor().current_clip() == &"eat", 20.0)
		check(ok, "kedi çeşmeden içiyor")
		await _wait(1.0)
		_look((fw["spots"] as Array)[0], 0.5)
		await _shot("cat_fountain_iciyor")
	_decor.remove_instance(fountain)
	await _wait(0.5)

	# Geniş kare: yeni kedi eşyalarının hepsi, oyun kamerasından
	var placed: Array[String] = []
	var spots_at: Array = [
		[&"lux_cat_sakura", Vector2(-0.10, -0.25)], [&"cat_house", Vector2(0.30, -0.20)], [&"cat_hammock", Vector2(-0.45, 0.0)],
		[&"cat_tire_bed", Vector2(0.05, 0.05)], [&"cat_box", Vector2(0.45, 0.05)], [&"cat_scratcher", Vector2(-0.70, -0.15)],
		[&"cat_tunnel", Vector2(-0.30, 0.25)], [&"cat_toys", Vector2(0.25, 0.28)], [&"cat_fountain", Vector2(0.60, 0.25)]]
	for pair: Array in spots_at:
		placed.append(_place(pair[0], front + (pair[1] as Vector2)))
	var wall_iid: String = ""
	_decor.grant(&"cat_wall_steps")
	var mount: Dictionary = _view.area().wall_mount(Vector2(front.x, _view.area().back_face_z), _view.wall_width(&"cat_wall_steps"))
	if not mount.is_empty() and _view.is_valid(&"cat_wall_steps", mount["position"], float(mount["yaw"])):
		wall_iid = _decor.add_instance(&"cat_wall_steps", mount["position"], float(mount["yaw"]))
	await _wait(1.0)
	var game_cam: Camera3D = null
	for c: Node in current_scene.find_children("*", "Camera3D", true, false):
		if c is WorldCamera:
			game_cam = c
	if game_cam:
		game_cam.current = true
		var mid: Vector3 = Vector3(front.x, _view.area().floor_y, front.y)
		for i: int in 40:
			(game_cam as WorldCamera).follow(mid, 1.4)
			await process_frame
		_world.hold(front + Vector2(0.15, 0.30), atan2(-0.62, -0.78), &"sit_idle")
		await _wait(1.5)
		await _shot("genis_hepsi")
	print("QA yerleşen: ", placed, " duvar: ", wall_iid)
	print("QA bitti, FAIL: %d" % _fails)
	quit(0 if _fails == 0 else 1)
