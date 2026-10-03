extends SceneTree
## KASA PERFORMANS ÖLÇÜMÜ — dünya FPS / çizim çağrısı / VRAM: kasasız, 2 kasa, 6 kasa, açılış sahnesi.
## Çalıştırma (vsync kapalı, yalıtılmış kayıt): godot-4 --path . --resolution 1152x648 -s res://qa/crate_perf.gd

const SAMPLE_SECONDS: float = 3.0


func _init() -> void:
	_run()


func measure(label: String) -> void:
	var frames: int = 0
	var worst: float = 0.0
	var draws: int = 0
	var t0: int = Time.get_ticks_usec()
	var last: int = t0
	while Time.get_ticks_usec() - t0 < int(SAMPLE_SECONDS * 1e6):
		await process_frame
		var now: int = Time.get_ticks_usec()
		worst = maxf(worst, float(now - last) / 1000.0)
		last = now
		frames += 1
		draws = maxi(draws, int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	var fps: float = frames / SAMPLE_SECONDS
	var vram: float = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0
	print("%-22s FPS %6.0f | en uzun kare %5.1f ms | çizim %4d | VRAM %6.1f MB" % [label, fps, worst, draws, vram])


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.0).timeout
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	var up: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	var eco: EconomyManager = get_first_node_in_group("economy")
	eco.set_money(500000)
	for i: int in 3:
		up.buy(GarageUpgradeManager.GARAGE_ID)   # 6 kasa sığsın diye büyük garaj
	pp.load_state(25, 0, 2000)
	await create_timer(1.5).timeout
	var crates: CrateManager = get_first_node_in_group("crates")
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	await measure("kasasız")
	var tb: int = Time.get_ticks_usec()
	var first: int = crates.buy(&"prestige_crate")
	print("  buy() çağrısı: %.1f ms (gem + çekiliş + atomik kayıt yazımı + teslimat noktası taraması)" % ((Time.get_ticks_usec() - tb) / 1000.0))
	crates.buy(&"city_crate")
	delivery.focus_on_arrival(first)
	await create_timer(1.5).timeout
	await measure("2 kasa")
	for id: StringName in [&"family_crate", &"sport_crate", &"city_crate", &"prestige_crate"]:
		crates.buy(id)
	await create_timer(1.8).timeout
	print("  bekleyen %d, dünyada %d kasa" % [crates.pending_count(), delivery.occupied_rects().size()])
	await measure("6 kasa")
	var revealed_at: Array = []
	delivery.reveal_ready.connect(func(_u: int, _r: Dictionary) -> void: revealed_at.append(Time.get_ticks_usec()))
	var t0: int = Time.get_ticks_usec()
	delivery.open_crate(first)
	var open_ms: float = (Time.get_ticks_usec() - t0) / 1000.0
	print("  open_crate() çağrısı: %.1f ms (ödül + kayıt yazımı)" % open_ms)
	await measure("açılış sahnesi")
	while revealed_at.is_empty():
		await process_frame
	print("  AÇ → sonuç plakası: %.2f sn" % ((revealed_at[0] - t0) / 1e6))
	await create_timer(0.5).timeout
	await measure("araç çıktı")
	delivery.finish_reveal(first)
	await create_timer(1.0).timeout
	await measure("kasa kalktı")
	quit()
