extends SceneTree
## DRAG HIZ HİSSİ QA: yarışı uçtan uca İKİ KEZ koşturur (yeşilde kalkar, vitesleri ideal devirde
## atar) ve belirli anlarda kare alır. 1. yarış rekoru koyar, 2. yarışta hayalet görünür.
## Ölçümler: bitiş süreleri, rekor, ekrandaki akış hızı, kadrajda iki araç da var mı.
##
## Kullanım (araç verilirse sahiplenilip yarış aracı yapılır — KAYDI DEĞİŞTİRİR, yalıtılmış
## kullanıcı klasöründe çalıştırın: tools/qa_isolated.sh):
##   godot-4 --path . --resolution 1280x720 -s res://qa/drag_feel.gd -- <çıktı_klasörü> [<araç_id>]
const DEFAULT_OUT: String = "/home/burak/Projects/ct_shots/drag_feel/"
const SHOT_TIMES: Array[float] = [0.35, 2.5, 6.0]

var _out: String = DEFAULT_OUT
var _vehicle: StringName = &""
var _hud: Node
var _drag: DragRaceScreen


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].path_join("")
	if args.size() > 1:
		_vehicle = StringName(args[1])
	DirAccess.make_dir_recursive_absolute(_out)
	Engine.max_fps = 60
	_run.call_deferred()


func _find(n: Node, s: String) -> Node:
	if n.name == s:
		return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r:
			return r
	return null


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	var pc: Node3D = _drag.get("_player_car")
	var rc: Node3D = _drag.get("_rival_car")
	var cam: Camera3D = _drag.get("_camera")
	var rect: Rect2 = Rect2(Vector2.ZERO, get_root().get_visible_rect().size)
	var inside: bool = rect.has_point(cam.unproject_position(pc.global_position)) \
		and rect.has_point(cam.unproject_position(rc.global_position))
	print("%s: kadrajda=%s akış=%.1f birim/sn" % [name, inside, _drag.call("_player_flow")])


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(70)
	_hud = _find(current_scene, "HUD")
	if _vehicle != &"":
		var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		own.add_vehicle(_vehicle)
		own.set_race_vehicle(_vehicle)
	_drag = _hud.get("drag_race_screen")
	for race: int in 2:
		await _race(race + 1)
		_hud.call("_on_race_exit")
		await _frames(20)
	quit(0)


func _race(index: int) -> void:
	_hud.get("router").call("open", &"drag_race")
	await _frames(2)
	print("yarış %d açıldı: %s" % [index, _drag.get("_player_id")])
	var taken: Dictionary = {}
	var countdown_shot: bool = false
	var shift_shot: bool = false
	var max_flow: float = 0.0
	var guard: int = 0
	while int(_drag.get("_phase")) != DragRaceScreen.Phase.DONE and guard < 60 * 60:
		await process_frame
		guard += 1
		var phase: int = _drag.get("_phase")
		var player: DragRaceSim.Runner = _drag.get("_player")
		var t: float = _drag.get("_time")
		if index == 1 and phase == DragRaceScreen.Phase.COUNTDOWN and not countdown_shot \
				and float(_drag.get("_countdown")) < 1.9:
			countdown_shot = true
			_shot("r1_0_geri_sayim")
		if phase != DragRaceScreen.Phase.RUNNING:
			continue
		max_flow = maxf(max_flow, float(_drag.call("_player_flow")))
		if not player.running and t > 0.18:
			_drag.tap()
		elif player.running and player.gear < player.top_gear() and player.clutch <= 0.0 \
				and not player.shifting and player.rpm >= player.spec.shift_rpm[player.gear] * 0.995:
			_drag.tap()
			if player.gear == 3 and not shift_shot:
				shift_shot = true
				await _frames(4)
				_shot("r%d_vites_3" % index)
		for i: int in SHOT_TIMES.size():
			if t >= SHOT_TIMES[i] and not taken.has(i):
				taken[i] = true
				_shot("r%d_%d_t%.1f" % [index, i + 1, SHOT_TIMES[i]])
	var pr: DragRaceSim.Run = _drag.player_run()
	var record: Dictionary = _drag.record_result()
	print("YARIŞ %d (%s, ölçek %.2f): oyuncu %.3f  rakip %.3f  en yüksek akış %.1f  rekor=%s önceki=%.3f" % [
		index, _drag.get("_player_id"), (_drag.get("_track") as DragTrack).length / DragTrack.TRACK_LENGTH,
		pr.time if pr else -1.0, (_drag.rival_run().time if _drag.rival_run() else -1.0), max_flow,
		record["new"], record["previous"]])
	await _frames(40)
	_shot("r%d_9_sonuc" % index)
