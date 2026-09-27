extends SceneTree
## GERÇEK OYNANIŞ: geri sayımda gaz tut, GO'da bırak, yeşil pencerede vites at.
## Hem ekran görüntüsü alır hem de UI'nin simülasyonla birebir olduğunu doğrular.
const OUT: String = "/home/burak/Projects/ct_shots/drag2/"
var _hud: Node
var _drag: Node
var _mismatch: int = 0
var _checked: int = 0

func _initialize() -> void:
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")

func _verify() -> void:
	# Kadran ibresi = simülasyonun devri (aynı eşleme), vites numarası = modelin vitesi.
	var p: DragRaceSim.Runner = _drag.get("_player")
	var dial: Control = _drag.get("_shift_dial")
	if p == null or dial == null or not p.running:
		return
	_checked += 1
	if absf(float(dial.get("ratio")) - p.gauge()) > 0.001:
		_mismatch += 1

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	_hud = _find(current_scene, "HUD")
	_drag = _hud.get("drag_race_screen")
	_drag.call("open")
	await process_frame

	# 1) GERİ SAYIM: araç hazır devirde bekler, oyuncu YEŞİLDE dokunur
	var spec: DragRaceSim.EngineSpec = (_drag.get("_player") as DragRaceSim.Runner).spec
	var shot_rev: bool = false
	var launched: bool = false
	var shifts: int = 0
	var shot_shift: bool = false
	var shot_red: bool = false
	var elapsed: float = 0.0
	while elapsed < 30.0 and int(_drag.get("_phase")) != 3:
		await process_frame
		elapsed += get_root().get_process_delta_time()
		var p: DragRaceSim.Runner = _drag.get("_player")
		var phase: int = int(_drag.get("_phase"))
		if phase <= 1:
			if not shot_rev and p.rpm > spec.launch_rpm * 0.9:
				shot_rev = true
				_shot("1_kalkis_devri")
				print("geri sayım: devir %.0f (optimum %.0f) kadran %.2f" % [
					p.rpm, spec.launch_rpm, float((_drag.get("_shift_dial") as Control).get("ratio"))])
		elif phase == 2:
			if not launched:
				launched = true
				_drag.call("tap")
				print("KALKIŞ: devir %.0f → kalite %s" % [p.launch_rpm,
					DragRaceSim.shift_name(p.launch_quality)])
				_shot("2_kalkis")
			else:
				_verify()
				var caption: Label = _drag.get("_shift_caption")
				if bool(_drag.get("_shift_hot")) and caption and caption.text == "ŞİMDİ!":
					var before: float = p.rpm
					var q: int = -1
					_drag.call("tap")
					q = p.shift_log[p.shift_log.size() - 1] if p.shift_log.size() > 0 else -1
					if p.shift_log.size() > shifts:
						shifts = p.shift_log.size()
						print("vites %d: %.0f → %.0f  (%s)" % [p.gear + 1, before, p.rpm,
							DragRaceSim.shift_name(q)])
						if not shot_shift:
							shot_shift = true
							_shot("3_vites")
				if not shot_red and p.is_red():
					shot_red = true
					_shot("4_devir_siniri")
	await process_frame
	_shot("5_bitis")
	var player: DragRaceSim.Runner = _drag.get("_player")
	var rival: DragRaceSim.Runner = _drag.get("_rival")
	print("SONUÇ oyuncu %.2f sn (%d isabet, %d kusursuz, sınır %.2f sn, patinaj %.2f sn, en yüksek devir %.0f)" % [
		player.finish_time, player.good_shifts, player.perfect_shifts, player.limiter_time,
		player.spin_time, player.max_rpm])
	print("      rakip  %.2f sn (%s)" % [rival.finish_time, rival.vehicle_id])
	print("UI/fizik uyumu: %d örnek, %d sapma" % [_checked, _mismatch])
	quit(0)
