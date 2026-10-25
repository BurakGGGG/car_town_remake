extends SceneTree
## GARAJ EKRANI AÇILIŞI — dünyadan doğrudan (router.open) ve DEPOLARIM → garaj seçimi → GİT yoluyla (iç mekân seçimde
## arka planda yüklenir, GarageInterior.prefetch) sırayla açılıp kapanır. Her açılışta: open() süresi (ana iş parçacığı),
## sonraki 8 karenin en uzunu ve bu karelerdeki en uzun ÇİZİM (RenderingServer frame_pre_draw → frame_post_draw; shader
## derlemesi / doku yüklemesi burada görünür). İlk satır soğuk açılıştır.
##   QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/garaj_acilis_olcum.gd \
##     --display-driver x11 --disable-vsync --resolution 1152x648 [-- dogrudan]
##   dogrudan: hep router.open (DEPOLARIM yolu yok)

var _pre: int = 0
var _draws: Array[float] = []


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	Engine.max_fps = 0
	while CarMeshMerger.busy():
		await process_frame
	RenderingServer.frame_pre_draw.connect(func() -> void: _pre = Time.get_ticks_usec())
	RenderingServer.frame_post_draw.connect(func() -> void: _draws.append((Time.get_ticks_usec() - _pre) / 1000.0))
	var router: UiRouter = get_first_node_in_group("ui_router") as UiRouter
	var board: CarGaragesScreen = root.find_children("*", "CarGaragesScreen", true, false).front() as CarGaragesScreen
	var manager: CarGarageManager = get_first_node_in_group("car_garages") as CarGarageManager
	var places: Array[StringName] = manager.owned_garages()
	if not manager.waiting_ids().is_empty():
		places.append(CarGarageManager.WAITING)
	var direct_only: bool = OS.get_cmdline_user_args().has("dogrudan")
	for round_index: int in 4:
		var via_board: bool = not direct_only and round_index % 2 == 0 and not places.is_empty()
		var start: int = 0
		if via_board:
			router.open(&"car_garages")
			await _frames(3)
			board.select(places[(round_index / 2) % places.size()])
			await _frames(20)   # oyuncu GİT'e basana kadar (~0,3 sn)
			start = Time.get_ticks_usec()
			board.call(&"_on_main_pressed")
		else:
			start = Time.get_ticks_usec()
			router.open(&"garage")
		var open_ms: float = (Time.get_ticks_usec() - start) / 1000.0
		_draws.clear()
		var worst: float = 0.0
		var last: int = Time.get_ticks_usec()
		for f: int in 8:
			await process_frame
			var now: int = Time.get_ticks_usec()
			worst = maxf(worst, (now - last) / 1000.0)
			last = now
		print("GARAJ #%d %-14s open() %5.1f ms · sonraki en uzun kare %5.1f ms · en uzun çizim %5.1f ms" % [round_index + 1,
			"DEPOLARIM→GİT" if via_board else "doğrudan", open_ms, worst, _draws.max() if not _draws.is_empty() else 0.0])
		router.close_all()
		await _frames(120)
		while CarMeshMerger.busy():
			await process_frame
	quit(0)
