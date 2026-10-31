extends SceneTree
## GARAJ DOSTLARI QA: oyunu açar, Tekir'i sahiplendirir, garaj kamerasından ve kedinin yanındaki perspektif bir
## kameradan kareler alır; davranışları (dolaş, otur, somun, şekerleme, uyku, kokla, sergideki araca zıpla) sırayla
## tetikler. Kayıt yalıtılmış klasörde (QA_SAVE kopyası) — geliştirme kaydına dokunulmaz.
## Kullanım: QA_SAVE=<savegame.json> tools/qa_isolated.sh res://qa/pet_qa.gd --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/pets/oyun/"

var _shot_index: int = 0
var _cam: Camera3D
var _game_cam: Camera3D
var _world: PetWorld


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _shot(label: String) -> void:
	RenderingServer.force_draw()
	_shot_index += 1
	root.get_texture().get_image().save_png(OUT + "%02d_%s.png" % [_shot_index, label])
	print("QA kare %02d_%s" % [_shot_index, label])


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame
		_follow_close()


func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


## Yakın kamera kediyi izler (oyun kamerası açısından, 3/4 yukarıdan)
func _follow_close() -> void:
	if _cam == null or not _cam.current or _world == null or _world.actor() == null:
		return
	var p: Vector3 = _world.actor().global_position
	_cam.global_position = p + Vector3(0.32, 0.26, 0.32)
	_cam.look_at(p + Vector3(0, 0.03, 0), Vector3.UP)


func _close(on: bool) -> void:
	if on:
		_cam.current = true
		_follow_close()
	else:
		_game_cam.current = true


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait(3.0)
	var pets: PetManager = current_scene.get_tree().get_first_node_in_group("pets") as PetManager
	_world = current_scene.get_tree().get_first_node_in_group("pet_world") as PetWorld
	if pets == null or _world == null:
		print("QA HATA: PetManager / PetWorld yok")
		quit(1)
		return
	print("QA sahiplenme: ", pets.adopt("Tekir"))
	await _until(func() -> bool: return _world.actor() != null, 5.0)
	_game_cam = current_scene.get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.fov = 40.0
	_cam.near = 0.01
	current_scene.add_child(_cam)
	await _wait(1.5)
	_shot("garaj_genel")
	var wc: WorldCamera = _game_cam as WorldCamera
	if wc:
		for i: int in 20:
			wc.follow(_world.actor().global_position, 1.0)
			await process_frame
		await _wait(0.6)
		_shot("garaj_yakin_zoom")
	_close(true)
	for act: StringName in [&"wander", &"sit", &"loaf", &"sleep", &"sniff"]:
		_world.debug_do(act)
		await _wait(2.4)
		_shot(String(act) + "_a")
		await _wait(3.0)
		_shot(String(act) + "_b")
	# Sergiye araç koy ve tavana zıplat
	var own: VehicleOwnership = current_scene.get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var view: GarageDecorView = current_scene.get_tree().get_first_node_in_group("garage_decor_view") as GarageDecorView
	if own and view and not own.owned_vehicle_ids().is_empty():
		var item: StringName = GarageDecor.vehicle_item_id(own.owned_vehicle_ids()[0])
		var iid: String = view.place_free(item)
		print("QA sergi aracı: ", item, " → ", iid)
		await _wait(1.0)
		_world.debug_do(&"roof")
		var ok: bool = await _until(func() -> bool: return _world.on_roof(), 40.0)
		print("QA tavanda: ", ok)
		await _wait(1.0)
		_shot("tavan_a")
		await _wait(6.0)
		_shot("tavan_b")
	_close(false)
	await _wait(0.5)
	_shot("garaj_son")
	quit(0)
