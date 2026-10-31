extends SceneTree
## GARAJ DOSTLARI kedi eşyaları QA: yatak / lastik kule / mama kabı (basit ve lüks) garaja konur; kedi yatakta uyur,
## kulenin tablasına ve direğin tepesine çıkar, kabın önünde yer. Yakın kareler + garaj kamerasından geniş kare (ölçek:
## kedi ×0,8, eşyalar ×1,25, arabalara göre). Kareler ~/Projects/ct_shots/pets/esyalar/. Kayıt yalıtılmış.
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_furniture_qa.gd --resolution 1600x720
const OUT: String = "/home/burak/Projects/ct_shots/pets/esyalar/"

var _n: int = 0
var _world: PetWorld
var _decor: DecorManager
var _view: GarageDecorView
var _cam: Camera3D


func _initialize() -> void:
	create_timer(280.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _shot(label: String) -> void:
	for i: int in 3:   # kamera taşındıysa yeni dönüşüm çizime girsin (yoksa kare bir önceki konumu gösteriyor)
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


## Eşyayı hedefe en yakın geçerli yere koyar.
func _place(item: StringName, near: Vector2) -> String:
	_decor.grant(item)
	var y: float = _view.area().floor_y
	var best: Vector3 = Vector3.INF
	var floor: Rect2 = _view.area().floor_rect
	var step: float = DecorGrid.CELL * 0.5
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
	var sets: Array = [[&"cat_bed", &"cat_tower", &"cat_bowls"], [&"lux_cat_bed", &"lux_cat_tower", &"lux_cat_bowls"]]
	var game_cam: Camera3D = current_scene.get_viewport().get_camera_3d()
	for k: int in sets.size():
		var ids: Array = sets[k]
		var bed: String = _place(ids[0], front + Vector2(-0.35, 0.0))
		var tower: String = _place(ids[1], front + Vector2(0.05, -0.05))
		var bowls: String = _place(ids[2], front + Vector2(0.4, 0.05))
		await _wait(1.0)
		print("QA yerleşti ", ids, " → ", bed, " ", tower, " ", bowls)
		var fb: Dictionary = _furn(bed)
		var ft: Dictionary = _furn(tower)
		var fw: Dictionary = _furn(bowls)
		if fb.is_empty() or ft.is_empty() or fw.is_empty():
			print("QA HATA: eşya bulunamadı")
			quit(1)
			return
		# Geniş kare: oyun kamerası eşyalara odaklı (arabalara göre ölçek)
		hud.visible = false
		game_cam.current = true
		var wc: WorldCamera = game_cam as WorldCamera
		var mid: Vector3 = Vector3(front.x, _view.area().floor_y, front.y)
		for i: int in 40:
			wc.follow(mid, 1.0)
			await process_frame
		_world.hold(_world._land_near(fw["rect"]), atan2(-0.62, -0.78), &"sit_idle")
		await _wait(1.5)
		await _shot("%d_genis" % k)
		if _cam == null:
			_cam = Camera3D.new()
			_cam.fov = 30.0
			_cam.near = 0.005
			current_scene.add_child(_cam)
		_cam.current = true
		# Yatak
		_world.hold(_world._land_near(fb["rect"]), 0.0, &"idle")
		_world.debug_do(&"bed")
		await _until(func() -> bool: return _world.on_roof() and _world.is_asleep(), 25.0)
		await _wait(1.2)
		_look((fb["spots"] as Array)[0], 0.55)
		await _shot("%d_yatakta_uyuyor" % k)
		_decor.remove_instance(bed)
		await _wait(0.5)
		bed = _place(ids[0], front + Vector2(-0.35, 0.0))
		# Kule: tabla, sonra direğin tepesi
		_world.hold(_world._land_near(ft["rect"]), 0.0, &"idle")
		_world.debug_do(&"tower")
		await _until(func() -> bool: return _world.on_roof(), 20.0)
		await _wait(3.0)
		var spots: Array = ft["spots"]
		_look((spots[0] as Vector3).lerp(spots[1], 0.4), 0.85)
		await _shot("%d_kule_tabla" % k)
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
		await _shot("%d_kule_tepe" % k)
		# Kap
		_world.hold(_world._land_near(fw["rect"]), 0.0, &"idle")
		_world.debug_do(&"eat")
		await _until(func() -> bool: return _world.actor().current_clip() == &"eat", 20.0)
		await _wait(1.0)
		_look((fw["spots"] as Array)[0], 0.5)
		await _shot("%d_yiyor" % k)
		for iid: String in [bed, tower, bowls]:
			if iid != "":
				_decor.remove_instance(iid)
		await _wait(0.6)
	quit(0)
