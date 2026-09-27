extends SceneTree
## TEK ekranın performansı (her ekran ayrı süreçte: VRAM birikmesin).
## Kullanım: godot-4 --path . --resolution WxH --script qa/perf_screen.gd -- <ekran> [owned...]

var _frame: int = 0
var _hud: Node
var _samples: Array[float] = []
var _rows: Array[String] = []
var _label: String = ""
var _open_ms: float = 0.0


func _initialize() -> void:
	Engine.max_fps = 0   # ölçüm: proje ayarındaki 60 FPS sınırı başlığı gizlemesin
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _flush() -> void:
	if _samples.is_empty():
		return
	var total: float = 0.0
	var low: float = 1e9
	for v: float in _samples:
		total += v
		low = minf(low, v)
	_rows.append("| %-28s | %5d / %4d | %5d | %7.1f MB |" % [_label, int(total / _samples.size()), int(low),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0])
	_samples.clear()


func _process(delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		change_scene_to_file("res://Main.tscn")
		return false
	if _frame < 100:
		return false
	if _frame == 100:
		_hud = _find(current_scene, "HUD")
		var args: PackedStringArray = OS.get_cmdline_user_args()
		var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		for i: int in range(1, args.size()):
			own.add_vehicle(StringName(args[i]))
		var race: Node = get_first_node_in_group("race")
		if race:
			race.set("_rival_id", &"volvo_s60")
		_label = "Dünya"
		return false
	if _frame < 220:
		_samples.append(1.0 / maxf(delta, 0.0001))
		return false
	if _frame == 220:
		_flush()
		var screen: String = OS.get_cmdline_user_args()[0]
		var t0: int = Time.get_ticks_usec()
		(_hud.get("router") as Node).call("open", StringName(screen))
		_open_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		_label = screen
		return false
	if _frame < 380:
		_samples.append(1.0 / maxf(delta, 0.0001))
		return false
	_flush()
	for r: String in _rows:
		print(r)
	print("açılış süresi: %.1f ms" % _open_ms)
	return true


func _find(node: Node, n: String) -> Node:
	if node.name == n: return node
	for c: Node in node.get_children():
		var f: Node = _find(c, n)
		if f: return f
	return null
