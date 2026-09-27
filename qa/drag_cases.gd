extends SceneTree
## Uç durumlar: (a) hiç dokunmayan oyuncu, (b) hatalı çıkış, (c) sınırda tutan oyuncu.
var _hud: Node
var _drag: Node

func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _race(mode: String) -> void:
	_drag.call("open")
	await process_frame
	var p: DragRaceSim.Runner = _drag.get("_player")
	var t: float = 0.0
	var false_started: bool = false
	while t < 40.0 and int(_drag.get("_phase")) != 3:
		await process_frame
		t += get_root().get_process_delta_time()
		var phase: int = int(_drag.get("_phase"))
		if mode == "hatali" and phase == 1 and not false_started:
			false_started = true
			_drag.call("tap")        # GO'dan önce dokun
		if phase == 2:
			if not p.running and mode != "pasif":
				_drag.call("tap")
			elif p.running and mode == "sinir" and p.is_red():
				_drag.call("tap")     # ancak sınıra dayanınca at
	print("%-8s → %.2f sn | kalkış %.0f (%s) | isabet %d/%d | sınır %.2f sn | patinaj %.2f | hatalı çıkış %s" % [
		mode, p.finish_time, p.launch_rpm, DragRaceSim.shift_name(p.launch_quality),
		p.good_shifts, p.gear_count() - 1, p.limiter_time, p.spin_time, p.false_start])
	_drag.call("close")
	for i: int in 20:
		await process_frame

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	_hud = _find(current_scene, "HUD")
	_drag = _hud.get("drag_race_screen")
	for mode: String in ["pasif", "hatali", "sinir"]:
		await _race(mode)
	quit(0)
