extends SceneTree
## GARAJ DOSTLARI uzun davranış testi: oyun Engine.time_scale ile hızlandırılır (varsayılan 15 kat, 60 oyun dakikası),
## garaja kedi eşyaları konur, kedinin hayatı ölçülür:
##   - iş dağılımı (başlama / başarı / süre), eşya kullanımı, tepkiler (müşteri / kasa / tamir)
##   - HATALAR: zeminde bir eşyanın İÇİNDE (gerçek iz, şişirilmemiş), havada asılı, zemin dışında, yürürken takılma
##   - yatakta uyurken gövdenin yatağın ortasına uzaklığı
##   - ara olaylar: 25. dk düzenleyici açılıp kedinin yerine kule konur (çıkışta kaçmalı), 40. dk yakın kamerada sevme
## Rapor: ~/Projects/ct_shots/pets/sim/rapor.json + kareler (her 6 oyun dakikasında).
## Kullanım: QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pet_sim_qa.gd --resolution 1280x720 \
##           [-- <dakika> <hız>]
const OUT: String = "/home/burak/Projects/ct_shots/pets/sim/"
const SAMPLE: float = 0.5        # oyun saniyesi

var _minutes: float = 60.0
var _speed: float = 15.0
var _world: PetWorld
var _decor: DecorManager
var _view: GarageDecorView
var _pets: PetManager
var _cam: Camera3D
var _t: float = 0.0              # oyun saniyesi
var _next_sample: float = 0.0
var _running: bool = false
var _acts: Dictionary = {}       # iş → {n, ok, sec}
var _cur: StringName = &""
var _cur_t: float = 0.0
var _clips: Dictionary = {}      # klip → oyun saniyesi
var _errors: Dictionary = {"inside_item": 0, "floating": 0, "off_floor": 0, "stuck": 0}
var _inside_items: Dictionary = {}
var _error_log: Array = []
var _bed_offsets: Array[float] = []
var _reaction_sec: float = 0.0
var _hidden_sec: float = 0.0
var _last_pos: Vector3 = Vector3.INF
var _still_walk: float = 0.0
var _events: Array = []
var _shots: int = 0
var _bed_iid: String = ""
var _beds: Array[String] = []


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_minutes = float(args[0])
	if args.size() > 1:
		_speed = float(args[1])
	create_timer(_minutes * 60.0 / _speed + 150.0, true, false, true).timeout.connect(func() -> void:
		print("QA HATA: süre doldu")
		quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	for f: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + f)
	_run.call_deferred()


func _wait_real(seconds: float) -> void:
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


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await _until(func() -> bool: return current_scene != null and current_scene.name != "LoadingScreen" \
		and current_scene.find_child("HUD", true, false) != null, 60.0)
	await _wait_real(5.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	_pets = get_first_node_in_group("pets") as PetManager
	_world = get_first_node_in_group("pet_world") as PetWorld
	_decor = get_first_node_in_group("decor") as DecorManager
	_view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	_pets.reset()
	_pets.adopt("Paşa")
	if not await _until(func() -> bool: return _world.actor() != null, 5.0):
		print("QA HATA: kedi yok")
		quit(1)
		return
	var floor: Rect2 = _view.area().floor_rect
	var c: Vector2 = floor.get_center()
	_bed_iid = _place(&"cat_bed", c + Vector2(-0.5, 0.2))
	_beds.append(_bed_iid)
	_place(&"cat_tower", c + Vector2(0.4, -0.3))
	_place(&"cat_bowls", c + Vector2(0.1, 0.5))
	_beds.append(_place(&"lux_cat_bed", c + Vector2(0.9, 0.4)))
	await _wait_real(1.0)
	_event("kuruldu: yatak, kule, kap, lüks yatak (%d eşya garajda)" % _decor.instances().size())
	_world.activity_started.connect(func(act: StringName) -> void:
		_cur = act
		_cur_t = _t
		var a: Dictionary = _acts.get(act, {"n": 0, "ok": 0, "sec": 0.0})
		a["n"] = int(a["n"]) + 1
		_acts[act] = a)
	_world.activity_finished.connect(func(act: StringName, ok: bool) -> void:
		var a: Dictionary = _acts.get(act, {"n": 0, "ok": 0, "sec": 0.0})
		a["sec"] = float(a["sec"]) + (_t - _cur_t)
		if ok:
			a["ok"] = int(a["ok"]) + 1
		_acts[act] = a
		_cur = &"")
	_cam = Camera3D.new()
	_cam.fov = 30.0
	_cam.near = 0.005
	current_scene.add_child(_cam)
	_world.resume()
	Engine.time_scale = _speed
	_running = true
	var edited: bool = false
	var petted: bool = false
	while _t < _minutes * 60.0:
		await process_frame
		if not edited and _t > 25.0 * 60.0:
			edited = true
			await _edit_event(hud)
		if not petted and _t > 40.0 * 60.0:
			petted = true
			await _pet_event(hud)
		if _t >= _shots * 360.0:
			_shots += 1
			await _shot("dk%02d" % int(_t / 60.0))
	_running = false
	Engine.time_scale = 1.0
	_report()
	quit(0)


var _prof_next: int = 0
var _prof_nav: Object = null
var _prof_rebuilds: int = 0
var _prof_acts: int = 0
var _reactions: int = 0
var _was_reacting: bool = false


func _process(delta: float) -> bool:
	if not _running:
		return false
	_t += delta
	if _world._nav != _prof_nav:
		_prof_nav = _world._nav
		_prof_rebuilds += 1
	if Time.get_ticks_msec() >= _prof_next:
		_prof_next = Time.get_ticks_msec() + 15000
		var n: int = 0
		for a: Dictionary in _acts.values():
			n += int(a["n"])
		print("QA ölçüm: oyun %.1f dk, fps %d, ızgara kurulumu %d, iş %d, iş şimdi %s, mod %d" % [_t / 60.0,
			Engine.get_frames_per_second(), _prof_rebuilds, n, _cur, _world._mode])
	if _t >= _next_sample:
		_next_sample = _t + SAMPLE
		_sample()
	return false


func _sample() -> void:
	var cat: PetActor = _world.actor()
	if cat == null:
		return
	var clip: StringName = cat.current_clip()
	_clips[clip] = float(_clips.get(clip, 0.0)) + SAMPLE
	if _world.is_editing():
		_hidden_sec += SAMPLE
		return
	if _world._busy_reaction:
		_reaction_sec += SAMPLE
		if not _was_reacting:
			_reactions += 1
	_was_reacting = _world._busy_reaction
	var p: Vector3 = cat.global_position
	var p2: Vector2 = Vector2(p.x, p.z)
	var floor_y: float = _view.area().floor_y
	var on_floor: bool = absf(p.y - floor_y) < 0.002
	var jumping: bool = _world._mode == PetWorld.Mode.JUMP
	if not _view.area().floor_rect.grow(0.02).has_point(p2) and not _world._visitor:
		_err("off_floor", "zemin dışında %s (%s)" % [p2, clip])
	if not on_floor and not jumping and _world._roof == "":
		_err("floating", "havada y=%.3f iş %s klip %s" % [p.y - floor_y, _cur, clip])
	if on_floor and not jumping:
		for inst: Dictionary in _decor.instances():
			if GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
				continue
			var poly: PackedVector2Array = _view.footprint(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y))
			if Geometry2D.is_point_in_polygon(p2, poly):
				_inside_items[String(inst["item"])] = int(_inside_items.get(String(inst["item"]), 0)) + 1
				_err("inside_item", "eşyanın içinde: %s (iş %s, klip %s)" % [inst["item"], _cur, clip])
				break
	# Takılma: yürüme modunda ama yerinden oynamıyor
	if _world._mode == PetWorld.Mode.WALK and _last_pos != Vector3.INF and p.distance_to(_last_pos) < 0.0005:
		_still_walk += SAMPLE
		if _still_walk >= 5.0:
			_err("stuck", "yürürken takıldı %s (iş %s)" % [p2, _cur])
			_still_walk = -1000.0
	elif _world._mode != PetWorld.Mode.WALK:
		_still_walk = 0.0
	_last_pos = p
	# Yatakta uyurken gövde merkezi
	if _world.is_asleep() and _beds.has(_world._roof):
		for f: Dictionary in _world._furniture(&"bed"):
			if f["iid"] == _world._roof:
				var pose: StringName = &"sleep" if clip == &"sleep" else &"loaf"
				var o: Vector2 = PetWorld.POSE_CENTER[pose] * PetActor.METER
				var body: Vector3 = p + Basis(Vector3.UP, cat.rotation.y) * Vector3(o.x, 0.0, o.y)
				var spot: Vector3 = (f["spots"] as Array)[0]
				_bed_offsets.append(Vector2(body.x, body.z).distance_to(Vector2(spot.x, spot.z)))


func _err(kind: String, text: String) -> void:
	_errors[kind] = int(_errors[kind]) + 1
	if _error_log.size() < 60:
		_error_log.append("%5.1f dk  %s" % [_t / 60.0, text])


func _event(text: String) -> void:
	_events.append("%5.1f dk  %s" % [_t / 60.0, text])
	print("QA olay ", text)


func _shot(label: String) -> void:
	var cat: PetActor = _world.actor()
	if cat == null or _world.is_editing():
		return
	var prev: Camera3D = current_scene.get_viewport().get_camera_3d()
	var at: Vector3 = cat.global_position + Vector3(0.0, 0.02, 0.0)
	_cam.global_position = at + Vector3(0.64, 0.55, 0.64).normalized() * 0.55
	_cam.look_at(at, Vector3.UP)
	_cam.current = true
	for i: int in 3:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + label + ".png")
	if prev:
		prev.current = true


func _edit_event(hud: Hud) -> void:
	var cat: PetActor = _world.actor()
	# Kedi yerdeyken (eşya / tavan üstünde değil, zıplamıyor) yapılır: kaçmayı denemek için
	var limit: float = _t + 600.0
	while (_world._roof != "" or _world._mode == PetWorld.Mode.JUMP) and _t < limit:
		await process_frame
	var p: Vector2 = Vector2(cat.global_position.x, cat.global_position.z)
	_event("düzenleyici açılıyor (kedi %s, üstte %s)" % [p, _world._roof != ""])
	hud.router.open(&"garage_edit")
	await _until(func() -> bool: return _world.is_editing(), 3.0)
	var hidden: bool = not cat.visible
	var iid: String = ""
	var placed: StringName = &""
	for item: StringName in [&"cat_tower", &"cat_bed", &"cat_bowls"]:
		var at: Vector3 = Vector3(p.x, _view.area().floor_y, p.y)
		if _view.is_valid(item, at, 0.0):
			_decor.grant(item)
			iid = _decor.add_instance(item, at, 0.0)
			placed = item
			break
	await process_frame
	hud.router.close_all()
	await _until(func() -> bool: return not _world.is_editing(), 3.0)
	await process_frame
	var q: Vector2 = Vector2(cat.global_position.x, cat.global_position.z)
	var inside: bool = false
	if iid != "":
		inside = Geometry2D.is_point_in_polygon(q, _view.footprint(placed, Vector3(p.x, 0.0, p.y), 0.0)) \
			and _world._roof == ""
	_event("düzenleyici kapandı: gizliydi %s, kedinin yerine %s, kedi %s → %s, eşyanın içinde %s" % [hidden,
		String(placed) if iid != "" else "hiçbir eşya sığmadı", p, q, inside])


func _pet_event(hud: Hud) -> void:
	var closeup: PetCloseupScreen = hud.pet_closeup_screen
	var before: int = _pets.friendship()
	hud.router.open(&"pet_closeup")
	var ready: bool = await _until(func() -> bool: return closeup._ready_to_pet, 8.0)
	for i: int in 8:
		_pets._last_pet_msec.clear()
		closeup._pet()
		await process_frame
	hud.router.back()
	await _until(func() -> bool: return not _world.in_closeup(), 4.0)
	_event("yakın kamera: hazır %s, 8 dokunuşta dostluk %d → %d (günlük sınır %d)" % [ready, before,
		_pets.friendship(), PetManager.DAILY_LOVE])


func _report() -> void:
	var lines: Array[String] = []
	lines.append("SÜRE %.0f oyun dakikası, hız ×%.0f" % [_t / 60.0, _speed])
	var keys: Array = _acts.keys()
	keys.sort_custom(func(a: StringName, b: StringName) -> bool: return float(_acts[a]["sec"]) > float(_acts[b]["sec"]))
	for k: StringName in keys:
		var a: Dictionary = _acts[k]
		lines.append("İŞ %-10s %3d kez, %3d başarılı, toplam %5.1f dk (%4.1f%%), ort %5.1f sn" % [k, int(a["n"]), int(a["ok"]),
			float(a["sec"]) / 60.0, 100.0 * float(a["sec"]) / maxf(_t, 1.0), float(a["sec"]) / maxf(float(a["n"]), 1.0)])
	var ck: Array = _clips.keys()
	ck.sort_custom(func(a: StringName, b: StringName) -> bool: return float(_clips[a]) > float(_clips[b]))
	var cl: Array[String] = []
	for k: StringName in ck.slice(0, 10):
		cl.append("%s %.0f%%" % [k, 100.0 * float(_clips[k]) / maxf(_t, 1.0)])
	lines.append("KLİP " + ", ".join(cl))
	lines.append("TEPKİ %d kez, %.1f dk; DÜZENLEYİCİDE GİZLİ %.1f dk" % [_reactions, _reaction_sec / 60.0, _hidden_sec / 60.0])
	lines.append("HATA %s içindeki eşyalar %s" % [_errors, _inside_items])
	if not _bed_offsets.is_empty():
		var mx: float = 0.0
		var sum: float = 0.0
		for o: float in _bed_offsets:
			mx = maxf(mx, o)
			sum += o
		lines.append("YATAK gövde-orta uzaklığı ort %.4f en çok %.4f birim (%d örnek; yatak iç yarıçapı ~%.3f)" % [
			sum / _bed_offsets.size(), mx, _bed_offsets.size(), 0.17 * PetWorld.PET_FURNITURE_SCALE * DecorBuilder.METER])
	lines.append("DOSTLUK %d, bugün %d / %d" % [_pets.friendship(), _pets.love_today(), PetManager.DAILY_LOVE])
	for l: String in lines:
		print("RAPOR ", l)
	for e: String in _events:
		print("RAPOR OLAY ", e)
	for e: String in _error_log:
		print("RAPOR HATA ", e)
	var f: FileAccess = FileAccess.open(OUT + "rapor.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"lines": lines, "events": _events, "errors": _error_log, "acts": _acts,
			"clips": _clips}, "  "))
