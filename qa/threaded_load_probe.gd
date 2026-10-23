extends SceneTree
## ARKA PLAN YÜKLEME SONDASI: Main.tscn'yi load_threaded_request ile yükler, her karenin süresini ve
## load_threaded_get_status çağrısının kendi süresini yazar (yükleme ekranındaki donmanın kaynağı).
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/threaded_load_probe.gd --display-driver x11 -- [sub|nosub]

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var sub: bool = args.size() > 0 and args[0] == "sub"
	var t0: int = Time.get_ticks_usec()
	ResourceLoader.load_threaded_request("res://Main.tscn", "", sub)
	var request_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("istek %.1f ms (alt iş parçacığı: %s)" % [request_ms, sub])
	var last: int = Time.get_ticks_usec()
	for i: int in 2000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		var frame_ms: float = (now - last) / 1000.0
		var progress: Array = []
		var c0: int = Time.get_ticks_usec()
		var status: int = ResourceLoader.load_threaded_get_status("res://Main.tscn", progress)
		var call_ms: float = (Time.get_ticks_usec() - c0) / 1000.0
		last = Time.get_ticks_usec()
		if frame_ms > 40.0 or call_ms > 5.0 or status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			print("%.2f sn: kare %.0f ms · durum çağrısı %.0f ms · durum %d · ilerleme %.2f" % [(now - t0) / 1e6, frame_ms,
				call_ms, status, float(progress[0]) if not progress.is_empty() else -1.0])
		if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			break
	quit()
