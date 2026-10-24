extends SceneTree
## MARKET ekranının çizim yükü: dünya, MARKET (her sekme), MARKET kart çizimleri gizli. Satır başına ortalama çizim
## çağrısı, ilkel sayısı ve ana görünümün ölçülen işleme süresi (CPU / GPU, ms).
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/market_perf.gd --display-driver x11 --resolution 1152x648

const SETTLE: int = 30
const SAMPLE: int = 90


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 0
	change_scene_to_file("res://Main.tscn")
	for i: int in 300:
		await process_frame
	var vp: RID = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var hud: Node = _find(current_scene, "HUD")
	var router: Node = hud.get("router")
	await _measure("Dünya")
	router.call("open", &"gem_store")
	var store: GemStoreScreen = hud.get("gem_store_screen")
	for tab: StringName in [GemStoreScreen.TAB_GEMS, GemStoreScreen.TAB_FREE, GemStoreScreen.TAB_CASH, GemStoreScreen.TAB_CODE]:
		store.call("_select_tab", tab)
		await _measure("MARKET %s" % tab)
	store.call("_select_tab", GemStoreScreen.TAB_GEMS)
	var arts: Array[Node] = store.find_children("*", "GemPackArt", true, false)
	for art: Node in arts:
		(art as CanvasItem).visible = false
	await _measure("MARKET gems, kart çizimi gizli")
	for art: Node in arts:
		(art as CanvasItem).visible = true
	print("BITTI")
	quit()


func _measure(label: String) -> void:
	for i: int in SETTLE:
		await process_frame
	var calls: float = 0.0
	var prims: float = 0.0
	var cpu: float = 0.0
	var gpu: float = 0.0
	var vp: RID = root.get_viewport_rid()
	for i: int in SAMPLE:
		await process_frame
		calls += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp)
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	var n: float = float(SAMPLE)
	print("PERF %-34s çizim %6.0f  ilkel %8.0f  cpu %5.2f ms  gpu %5.2f ms  süreç %5.2f ms" % [label, calls / n, prims / n,
		cpu / n, gpu / n, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])


func _find(node: Node, n: String) -> Node:
	if node.name == n:
		return node
	for c: Node in node.get_children():
		var f: Node = _find(c, n)
		if f:
			return f
	return null
