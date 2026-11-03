extends SceneTree
## JAPON DEKOR VİTRİNİ QA (tools/decor/props_v12_japon.py + TATAMİ / SHOJİ): seviye 3 garaja tatami zemin, shoji duvar,
## Japon eşyalarının hepsi ve yeni kedi eşyalarından birkaçı konur; oyun kamerasından HUD'suz geniş ve yakın kareler.
## Kareler ~/Projects/ct_shots/japon_dekor/. Kayıt yalıtılmış.
## Kullanım: CT_NO_TUTORIAL=1 GODOT=<timeout'lu godot-4 sarmalayıcı> tools/qa_isolated.sh res://qa/japon_dekor_qa.gd \
##             --resolution 1600x900
const OUT: String = "/home/burak/Projects/ct_shots/japon_dekor/"
var _decor: DecorManager
var _view: GarageDecorView
var _floor: Rect2
var _fails: int = 0


func _initialize() -> void:
	create_timer(240.0).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
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


func _shot(label: String) -> void:
	for i: int in 4:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("QA kare ", label)


## Zemin dikdörtgeninde oransal nokta (fx: 0 sol duvar → 1 sağ / açık kenar, fz: 0 arka duvar → 1 ön).
func _at(fx: float, fz: float) -> Vector2:
	return _floor.position + _floor.size * Vector2(fx, fz)


func _place(item: StringName, near: Vector2, yaw: float = 0.0) -> String:
	_decor.grant(item)
	var y: float = _view.area().floor_y
	var best: Vector3 = Vector3.INF
	var step: float = DecorGrid.CELL * 0.25
	var x: float = _floor.position.x + step
	while x < _floor.end.x - step:
		var z: float = _floor.position.y + step
		while z < _floor.end.y - step:
			var p: Vector3 = Vector3(x, y, z)
			if _view.is_valid(item, p, yaw) and (best == Vector3.INF or Vector2(p.x, p.z).distance_to(near)
					< Vector2(best.x, best.z).distance_to(near)):
				best = p
			z += step
		x += step
	if best == Vector3.INF:
		print("  FAIL yer bulunamadı: ", item)
		_fails += 1
		return ""
	return _decor.add_instance(item, best, yaw)


func _hang(item: StringName, side: String, frac: float) -> void:
	_decor.grant(item)
	var w: float = _view.wall_width(item)
	var along: float = lerpf(_floor.position.x, _floor.end.x, frac) if side == "back" \
		else lerpf(_floor.position.y, _floor.end.y, frac)
	var mount: Dictionary = _view.area().mount_on(side, along, w)
	if _view.is_valid(item, mount["position"], float(mount["yaw"])):
		_decor.add_instance(item, mount["position"], float(mount["yaw"]))
	else:
		print("  FAIL asılamadı: ", item)
		_fails += 1


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait(4.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	_decor = get_first_node_in_group("decor") as DecorManager
	_view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(30, 0, 500)
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	(get_first_node_in_group("economy") as EconomyManager).set_money(90_000_000)
	await _wait(1.5)
	_floor = _view.area().floor_rect

	# Zemin: bütün garaj tatami; duvarlar shoji
	var cells: Array[Vector2i] = []
	var n: Vector2i = DecorGrid.lot_cells(_view.lot_rect())
	for i: int in n.x:
		for j: int in n.y:
			cells.append(Vector2i(i, j))
	var painted: Dictionary = _decor.paint_tiles(cells, &"tatami")
	print("tatami: ", painted.get("changes", []).size(), " göz")
	_decor.purchase(&"wall_shoji")
	if not _decor.apply_surface(DecorManager.SURFACE_WALL, &"wall_shoji"):
		print("  FAIL shoji uygulanamadı")
		_fails += 1

	# Büyükler önce
	for spec: Array in [[&"jp_torii", 0.84, 0.90], [&"jp_ramen_stall", 0.74, 0.22], [&"jp_koi_pond", 0.24, 0.72],
			[&"jp_zen_garden", 0.52, 0.74], [&"jp_maple", 0.07, 0.90], [&"jp_koinobori", 0.97, 0.58],
			[&"jp_kotatsu", 0.36, 0.22], [&"jp_byobu", 0.14, 0.08], [&"jp_vending", 0.95, 0.08],
			[&"jp_taiko", 0.90, 0.40], [&"jp_stone_lantern", 0.06, 0.55], [&"jp_shishi_odoshi", 0.40, 0.92],
			[&"jp_bamboo_fence", 0.30, 0.46], [&"jp_bamboo_fence", 0.47, 0.46], [&"jp_maneki", 0.58, 0.30],
			[&"jp_daruma", 0.56, 0.12], [&"jp_andon", 0.05, 0.26], [&"jp_andon", 0.24, 0.10],
			[&"lux_cat_sakura", 0.66, 0.52], [&"cat_house", 0.12, 0.40], [&"cat_tire_bed", 0.46, 0.34]]:
		_place(spec[0], _at(spec[1], spec[2]))
	for spec: Array in [[&"jp_lanterns", "back", 0.40], [&"jp_noren", "back", 0.56], [&"jp_scroll", "back", 0.30],
			[&"jp_neon_kanji", "back", 0.66], [&"jp_fan", "back", 0.10], [&"jp_lanterns", "left", 0.35],
			[&"jp_scroll", "left", 0.62], [&"cat_wall_steps", "left", 0.18]]:
		_hang(spec[0], spec[1], spec[2])
	await _wait(2.0)
	print("eşya: ", _decor.instance_count())

	hud.visible = false
	var cam: WorldCamera = null
	for c: Node in current_scene.find_children("*", "Camera3D", true, false):
		if c is WorldCamera:
			cam = c
	cam.current = true
	var center: Vector3 = Vector3(_floor.get_center().x, 0.0, _floor.get_center().y)
	for spec: Array in [["01_genis", center, 3.2], ["02_sol", Vector3(_at(0.28, 0.5).x, 0, _at(0.28, 0.5).y), 1.9],
			["03_sag", Vector3(_at(0.75, 0.45).x, 0, _at(0.75, 0.45).y), 1.9],
			["04_arka_duvar", Vector3(_at(0.45, 0.12).x, 0, _at(0.45, 0.12).y), 1.5],
			["05_on", Vector3(_at(0.55, 0.85).x, 0, _at(0.55, 0.85).y), 1.7]]:
		for i: int in 50:
			cam.follow(spec[1], spec[2])
			await process_frame
		await _wait(0.4)
		await _shot(spec[0])
	print("QA bitti, FAIL: %d" % _fails)
	quit(0 if _fails == 0 else 1)
