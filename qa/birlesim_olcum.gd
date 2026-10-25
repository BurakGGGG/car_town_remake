extends SceneTree
## BİRLEŞTİRME YÜKÜ — ekran açıldıktan sonra araç parçalarının birleştirilmesi (CarMeshMerger) bitene kadar geçen kareler:
## kare sayısı, toplam / en uzun kare, 16 ms'yi aşan kare sayısı. Parça okuma GPU'yu beklettiği için (telefonda daha da
## pahalı) birleştirme sürerken kareler uzar.
##   QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/birlesim_olcum.gd \
##     --display-driver x11 --disable-vsync --resolution 1152x648 -- garage drag_race
## QA_UZAKSIZ=1: araçların uzak kademesi (CarFarLod) kapalı.

func _initialize() -> void:
	CarFarLod.enabled = not OS.has_environment("QA_UZAKSIZ")   # araç uzak kademesi kapalı (önce / sonra kıyası)
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
	await _frames(30)
	var router: UiRouter = get_first_node_in_group("ui_router") as UiRouter
	for id: String in OS.get_cmdline_user_args():
		for round_index: int in 2:
			router.open(StringName(id))
			var frames: int = 0
			var total: float = 0.0
			var longest: float = 0.0
			var slow: int = 0
			var last: int = Time.get_ticks_usec()
			await process_frame
			while (CarMeshMerger.busy() or frames < 3) and frames < 900:
				await process_frame
				var now: int = Time.get_ticks_usec()
				var ms: float = (now - last) / 1000.0
				last = now
				frames += 1
				total += ms
				longest = maxf(longest, ms)
				if ms > 16.0:
					slow += 1
			print("BİRLEŞİM %s #%d: %d kare, toplam %.0f ms, en uzun %.1f ms, 16 ms+ kare %d" % [id, round_index + 1, frames,
				total, longest, slow])
			router.close_all()
			await _frames(60)
			while CarMeshMerger.busy():
				await process_frame
	quit(0)
