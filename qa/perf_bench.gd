extends SceneTree
## PERFORMANS KIYASLAMASI — oyunun ana durumlarında kare süresi, betik süresi, çizim, bellek.
## Optimizasyonun ÖNCE / SONRA ölçüsü: her senaryo oturtulur, sonra SAMPLE kare ölçülür.
##
## Kullanım (yalıtılmış kayıt; QA_SAVE ile hazır bir kaydın kopyasıyla başlanabilir):
##   QA_SAVE=~/Projects/ct_shots/bench_saves/featured.json \
##     tools/qa_isolated.sh res://qa/perf_bench.gd --resolution 1152x648 -- <etiket>
## Çıktı: tablo stdout'a ve ~/Projects/ct_shots/bench/<etiket>.txt
##
## Masaüstü (Intel ADL) sayıları telefonla aynı DEĞİL; kıyas ÖNCE/SONRA içindir. Telefonda asıl
## belirleyici olan çizim çağrısı, üçgen, VRAM ve betik süresidir (CPU ~5-8 kat yavaş).

const OUT_DIR: String = "/home/burak/Projects/ct_shots/bench/"
const SETTLE: int = 60
const SAMPLE: int = 150

var _rows: PackedStringArray = PackedStringArray()
var _hud: Hud
var _tag: String = "bench"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	var t0: int = Time.get_ticks_usec()
	change_scene_to_file("res://Main.tscn")
	await process_frame
	await process_frame
	var first_frame_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	# Kayıt yüklemesi ve tembel kurulumlar oturana kadar (ilk 3 sn) say
	var settle_t0: int = Time.get_ticks_usec()
	var hitch_ms: float = 0.0
	for i: int in 180:
		var f0: int = Time.get_ticks_usec()
		await process_frame
		hitch_ms = maxf(hitch_ms, float(Time.get_ticks_usec() - f0) / 1000.0)
	# GameSettings oyun açılınca kare sınırını (60) yeniden koyar: ölçüm için yine kaldırılır.
	# Başsız modda kare süresi böylece SAF CPU maliyetidir (betik + fizik + sahne).
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	_hud = current_scene.find_child("HUD", true, false) as Hud
	var level: int = (get_first_node_in_group("player_progress") as PlayerProgress).level
	var owned: int = (get_first_node_in_group("vehicle_ownership") as VehicleOwnership).owned_vehicle_ids().size()
	_rows.append("# %s — seviye %d, %d araç, Engine %s" % [_tag, level, owned, Engine.get_version_info()["string"]])
	_rows.append("açılış: ilk kare %.0f ms, ilk 3 sn en uzun kare %.0f ms (toplam %.1f sn)" % [
		first_frame_ms, hitch_ms, float(Time.get_ticks_usec() - settle_t0) / 1e6])
	_rows.append("| senaryo | kare ms ort | kare ms p95 | süreç ms (1 sn en uzun) | fizik ms | çizim | nesne | üçgen | VRAM MB | bellek MB | düğüm |")
	_rows.append("|---|---|---|---|---|---|---|---|---|---|---|")

	await _measure("dünya (varsayılan kamera)")
	var camera: WorldCamera = get_root().get_viewport().get_camera_3d() as WorldCamera
	if camera:
		camera.set("_target_size", camera.max_zoom)
		await _measure("dünya (en uzak zoom)")
		camera.set("_target_size", camera.min_zoom)
		await _measure("dünya (en yakın zoom)")
		camera.set("_target_size", camera.start_zoom)
	var router: UiRouter = _hud.router
	for id: StringName in [&"garage", &"showroom", &"collection", &"quests", &"garage_edit"]:
		var o0: int = Time.get_ticks_usec()
		router.open(id)
		await process_frame
		var open_ms: float = float(Time.get_ticks_usec() - o0) / 1000.0
		await _measure("%s (açılış %.0f ms)" % [id, open_ms])
		router.close_all()
		await _frames(20)
	# Drag yarışı: açılış + koşu ortası
	var r0: int = Time.get_ticks_usec()
	router.open(&"drag_race")
	await process_frame
	var race_open: float = float(Time.get_ticks_usec() - r0) / 1000.0
	var drag: DragRaceScreen = _hud.drag_race_screen
	var guard: int = 0
	while int(drag.get("_phase")) != DragRaceScreen.Phase.RUNNING and guard < 600:
		await process_frame
		guard += 1
	drag.tap()
	await _measure("drag yarışı koşu (açılış %.0f ms)" % race_open, 30, 120, drag)
	router.close_all()
	await _frames(30)
	# Tamir: bir araç lifte alınır, iş efektleri sürerken ölçülür
	var repairs: RepairManager = get_first_node_in_group("repair_manager")
	var car: TrafficVehicle = null
	for node: Node in get_root().find_children("*", "TrafficVehicle", true, false):
		if (node as TrafficVehicle).mode == TrafficVehicle.Mode.TRAFFIC:
			car = node
			break
	if car and repairs:
		car.fault = RepairType.by_id(&"body")
		car.mode = TrafficVehicle.Mode.REPAIR_WAITING
		if repairs.start_repair(car):
			await _measure("tamir sürerken (kaynak efekti)")
	_report()
	quit(0)


## Ölçüm: `settle` kare oturt, `count` kare ölç. Yarışta her karede vites (ideal devirde) atılır.
func _measure(label: String, settle: int = SETTLE, count: int = SAMPLE, drag: DragRaceScreen = null) -> void:
	await _frames(settle)
	var frame_ms: PackedFloat32Array = PackedFloat32Array()
	var proc: float = 0.0
	var phys: float = 0.0
	var draws: float = 0.0
	var objects: float = 0.0
	var prims: float = 0.0
	for i: int in count:
		var f0: int = Time.get_ticks_usec()
		await process_frame
		frame_ms.append(float(Time.get_ticks_usec() - f0) / 1000.0)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		draws += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objects += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		prims += float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		if drag:
			var p: DragRaceSim.Runner = drag.get("_player")
			if p and p.running and p.gear < p.top_gear() and p.clutch <= 0.0 and not p.shifting \
					and p.rpm >= p.spec.shift_rpm[p.gear]:
				drag.tap()
	var sorted: PackedFloat32Array = frame_ms.duplicate()
	sorted.sort()
	var total: float = 0.0
	for v: float in frame_ms:
		total += v
	var n: float = float(count)
	_rows.append("| %s | %.2f | %.2f | %.2f | %.2f | %d | %d | %.0fk | %.0f | %.0f | %d |" % [label,
		total / n, sorted[int(n * 0.95)], proc / n, phys / n, int(draws / n), int(objects / n),
		prims / n / 1000.0,
		float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED)) / 1048576.0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])


func _report() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var text: String = "\n".join(_rows)
	print(text)
	var file: FileAccess = FileAccess.open(OUT_DIR + _tag + ".txt", FileAccess.WRITE)
	if file:
		file.store_string(text + "\n")
