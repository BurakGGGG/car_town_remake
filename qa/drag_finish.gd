extends SceneTree
## Drag bitişi / başlangıcı: (A) dokunulmazsa araç KENDİ kalkmaz, (B) bitişte araç durmaz,
## ilerlemeye devam edip frenler, kamera çizgide kalır, sonuç gecikmeli gelir.
var _hud: Node
var _drag: Node
var _fails: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _check(label: String, ok: bool) -> void:
	print(("  OK " if ok else "  FAIL ") + label)
	if not ok: _fails += 1

func _open() -> void:
	_drag.call("open")
	await process_frame

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	_hud = _find(current_scene, "HUD")
	_drag = _hud.get("drag_race_screen")
	var results: Array = []
	_drag.connect("race_completed", func(w: bool, pt: float, rt: float) -> void: results.append([w, pt, rt]))

	# A) hiç dokunma: GO'dan 3 sn sonra oyuncu hâlâ kalkmamış olmalı
	await _open()
	var t: float = 0.0
	while int(_drag.get("_phase")) != 2 and t < 10.0:
		await process_frame
		t += 0.016
	var after: float = 0.0
	while after < 3.0 and int(_drag.get("_phase")) == 2:
		await process_frame
		after += get_root().get_process_delta_time()
	var p: DragRaceSim.Runner = _drag.get("_player")
	_check("A: dokunulmadı → oyuncu kalkmadı (%.1fs)" % after, not p.running)
	var rv: DragRaceSim.Runner = _drag.get("_rival")
	_check("A: rakip gitti", rv.running and rv.distance > 5.0)
	# yarış rakip bitince kendiliğinden kapanmalı (kaybetti)
	t = 0.0
	while int(_drag.get("_phase")) != 3 and t < 40.0:
		await process_frame
		t += get_root().get_process_delta_time()
	_check("A: yarış sonlandı, oyuncu kaybetti", results.size() == 1 and not bool(results[0][0]))

	# B) normal koşu: vites at
	await _open()
	t = 0.0
	var launched: bool = false
	var line_z: float = DragTrack.START_Z + DragTrack.TRACK_LENGTH
	var max_car_z: float = -99.0
	var cam_at_finish: float = -99.0
	var cam_end: float = -99.0
	var first_finish_wall: float = -1.0
	var result_wall: float = -1.0
	var clock: float = 0.0
	while int(_drag.get("_phase")) != 3 and clock < 60.0:
		await process_frame
		var dt: float = get_root().get_process_delta_time()
		clock += dt
		p = _drag.get("_player")
		if int(_drag.get("_phase")) == 2:
			if not launched:
				launched = true
				_drag.call("tap")
			elif p.running and p.finish_time < 0.0 and p.in_shift_window():
				_drag.call("tap")
		var car: Node3D = _drag.get("_player_car")
		max_car_z = maxf(max_car_z, car.position.z)
		var cam: Camera3D = _drag.get("_camera")
		if p.finish_time >= 0.0:
			if first_finish_wall < 0.0:
				first_finish_wall = clock
				cam_at_finish = cam.position.z
			cam_end = cam.position.z
	result_wall = clock
	_check("B: yarış tamamlandı", results.size() == 2)
	_check("B: araç çizgiyi aşıp ilerledi (z=%.1f çizgi=%.1f)" % [max_car_z, line_z], max_car_z > line_z + 2.0)
	_check("B: pist sonu içinde kaldı (<%.1f)" % (DragTrack.TRACK_LENGTH + DragTrack.RUN_OUT), max_car_z < DragTrack.TRACK_LENGTH + DragTrack.RUN_OUT)
	_check("B: kamera bitişte sabit (%.2f→%.2f)" % [cam_at_finish, cam_end], absf(cam_end - cam_at_finish) < 0.3)
	_check("B: sonuç bitişten sonra gecikmeli (%.1fs)" % (result_wall - first_finish_wall), result_wall - first_finish_wall >= 2.0)
	print("sonuç: ", results)
	print("FAILS: ", _fails)
	quit(_fails)
