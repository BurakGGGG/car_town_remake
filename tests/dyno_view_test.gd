extends SceneTree
## DİNO ATÖLYESİ (DynoView, kullanıcı 2026-11-02 "C dinamometre"): oda kurulur; arka teker sabit arka merdanenin
## tepesinde, ön merdane taşıyıcısı ön tekerin altına kayar (kısa / uzun dingil mesafesi), fan aracın önünde (uzun
## araçta rampanın önünde zemine), kayışlar ve hortum kurulur; motor kendiliğinden çalışır (START yok) → fizik rölantide;
## gaz verince devir çıkar, yalnız çeken aks döner; tam gaz çekiş en iyi ölçüm olur; tek kamera odanın içinde; açıkken
## garaj müziği kısılır; çıkışta
## ödünç kamera / ışık / gizlenen düğümler eski hâline döner, müzik geri gelir. Ayrıca en iyi ölçüm kaydı ve dünya örtülüyken
## trafik kornası çalmaz.
## Çalıştırma: tools/run_tests.sh dyno_view_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(853, 480)
	viewport.own_world_3d = true
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	viewport.add_child(camera)
	camera.position = Vector3(6.4, 4.6, 6.4)
	var saved_camera: Transform3D = camera.transform
	var key: DirectionalLight3D = DirectionalLight3D.new()
	viewport.add_child(key)
	var old_room: Node3D = Node3D.new()
	viewport.add_child(old_room)
	var mods: PerformanceModManager = PerformanceModManager.new()
	root.add_child(mods)
	var view: DynoView = DynoView.new()
	root.add_child(view)
	GameMusic.ensure(self)
	await frames(2)
	var music: GameMusic = root.get_node_or_null(GameMusic.NODE_NAME) as GameMusic
	if music:
		music.volume_db = GameMusic.BASE_DB
		music._tween.kill()

	print("== atölye ==")
	check(GarageInterior.has_scene(DynoView.GARAGE), "dynoroom sahnesi var")
	check(view.enter(&"toyota_supra", viewport, camera, key, [old_room]), "Supra dinoya çıktı")
	check(view.active and view.interior != null and not old_room.visible, "oda kuruldu, eski oda gizli")
	for part: String in ["DrumFront", "DrumRear", "FrontCarriage", "Fan", "FanBlades"]:
		check(view.node(part) != null, "%s düğümü var" % part)
	var rear: Vector3 = view.interior.marker("RearAxle").origin
	var bounds: AABB = view.get("_bounds")
	check(absf(bounds.position.y - rear.y) < 0.004, "araç arka merdanenin tepesinde (%.4f / %.4f)" % [bounds.position.y, rear.y])
	var front_z: float = view.get("_front_axle_z")
	var carriage: Node3D = view.node("FrontCarriage")
	check(absf(carriage.global_position.z - front_z) < 0.01, "ön merdane ön tekerin altında (%.3f / %.3f)" % [carriage.global_position.z,
		front_z])
	var fan: Node3D = view.node("Fan")
	check(fan.global_position.z > bounds.end.z, "fan aracın önünde")
	check(view.voice != null and view.sim != null and view.is_engine_on() and view.voice.running
		and not view.voice.is_starting() and absf(view.sim.rpm - view.sim.spec.idle_rpm) < 1.0,
		"araç çalışır hâlde gelir (rölantide, marş sesi yok)")
	var player: AudioStreamPlayer = view.get("_player")
	var bus: int = AudioServer.get_bus_index(player.bus)
	check(player.bus == DynoView.BUS and AudioServer.get_bus_send(bus) == GameSettings.SFX_BUS
		and AudioServer.get_bus_effect(bus, 0) is AudioEffectHardLimiter and player.volume_db > 0.0
		and view.voice.dynamics < 1.0, "motor sesi kendi bus'ında: sınırlayıcı → SFX, %.0f dB" % player.volume_db)

	print("== kamera ==")
	var room: Rect2 = view.interior.setup()["bounds"]
	var b: Vector3 = view.call("_to_blender", camera.global_position)
	check(room.has_point(Vector2(b.x, b.y)) and b.z > 0.2 and b.z < 4.6, "kamera odanın içinde (%.1f, %.1f, %.1f)" % [b.x, b.y,
		b.z])
	var to_car: Vector3 = (bounds.get_center() - camera.global_position).normalized()
	check(-camera.global_basis.z.dot(to_car) > 0.75, "kamera araca bakıyor")

	print("== gaz ==")
	await create_timer(0.5).timeout
	check(view.sim.running and absf(view.sim.rpm - view.sim.spec.idle_rpm) < 60.0, "rölantide bekler")
	var measured: Array = []
	view.pull_measured.connect(func(peak: float, record: bool) -> void: measured.append([peak, record]))
	view.set_throttle(1.0)
	await create_timer(1.4).timeout
	check(view.sim.rpm > view.sim.spec.redline_rpm * 0.9 and view.sim.speed > 1.0,
		"gaz verince devir çıkar, merdane döner (%.0f d/dk)" % view.sim.rpm)
	check(view.node("DrumRear").rotation.x != 0.0 and is_zero_approx(view.node("DrumFront").rotation.x),
		"arkadan itişli Supra: yalnız arka merdane döner")
	var rig: CarRig = view.get("_rig")
	check(rig != null and is_zero_approx(rig.front_spin_deg) and not is_zero_approx(rig.spin_deg),
		"yalnız arka tekerler döner (ön %.0f°, arka %.0f°)" % [rig.front_spin_deg, rig.spin_deg])
	check(measured.size() == 1 and bool(measured[0][1]) and absf(mods.dyno_best(&"toyota_supra") / view.sim.catalog_hp - 1.0) < 0.015,
		"tam gaz çekiş ölçüldü, en iyi ölçüm kaydedildi (%.0f bg)" % mods.dyno_best(&"toyota_supra"))
	view.set_throttle(0.0)
	if music:
		await create_timer(GameMusic.SWAP_TIME + 0.2).timeout
		check(music.volume_db < GameMusic.BASE_DB - 10.0, "dinoda müzik kısık (%.1f dB)" % music.volume_db)

	print("== korna (dünya örtülü) ==")
	var router: UiRouter = UiRouter.new()
	root.add_child(router)
	var place_script: GDScript = GDScript.new()
	place_script.source_code = "extends Control\nfunc open() -> void:\n\tpass\nfunc close() -> void:\n\tpass\n"
	place_script.reload()
	var place: Control = Control.new()
	place.set_script(place_script)
	root.add_child(place)
	router.register(&"garage", place, UiRouter.Kind.PLACE)
	var sfx: TrafficSfx = TrafficSfx.new()
	root.add_child(sfx)
	await frames(2)
	router.open(&"garage")
	await frames(2)
	check(router.current_place() == &"garage", "garaj (dünyayı örten yer) açık")
	var waited: float = 0.0
	while not sfx._ready_streams() and waited < 5.0:
		await create_timer(0.1).timeout
		waited += 0.1
	sfx.honk()
	check(not (sfx.get("_honk_player") as AudioStreamPlayer).playing, "garaj / dino açıkken trafik kornası çalmaz")
	router.close_all()
	await frames(2)
	sfx.set("_last_honk", -10000)
	sfx.honk()
	check((sfx.get("_honk_player") as AudioStreamPlayer).playing, "şehirde korna çalar")
	sfx.queue_free()
	router.queue_free()
	place.queue_free()

	print("== en iyi ölçüm ==")
	mods.load_state({})
	check(mods.dyno_best(&"toyota_supra") == 0.0 and mods.record_dyno(&"toyota_supra", 331.0), "ilk ölçüm rekor")
	check(not mods.record_dyno(&"toyota_supra", 329.0) and mods.dyno_best(&"toyota_supra") == 331.0, "düşük ölçüm rekor değil")
	var state: Dictionary = mods.state()
	mods.load_state({})
	check(mods.dyno_best(&"toyota_supra") == 0.0, "boş kayıtta ölçüm yok")
	mods.load_state(state)
	check(is_equal_approx(mods.dyno_best(&"toyota_supra"), 331.0), "kayıttan geri geldi")

	print("== çıkış ==")
	view.exit()
	await frames(2)
	check(not view.active and view.interior == null and old_room.visible, "oda kalktı, eski oda göründü")
	if music:
		await create_timer(GameMusic.SWAP_TIME + 0.2).timeout
		check(absf(music.volume_db - GameMusic.BASE_DB) < 0.5, "çıkışta müzik geri geldi (%.1f dB)" % music.volume_db)
	check(camera.transform.is_equal_approx(saved_camera) and camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
		"kamera geri verildi")

	print("== uzun / kısa / elektrikli ==")
	for id: StringName in [&"mercedes_sprinter", &"fiat_500_1965", &"tesla_model_y", &"vw_golf_7"]:
		check(view.enter(id, viewport, camera, key, []), "%s dinoya çıktı" % id)
		var b2: AABB = view.get("_bounds")
		var c2: Node3D = view.node("FrontCarriage")
		var f2: float = view.get("_front_axle_z")
		var r2: float = view.get("_rear_axle_z")
		var wb: float = (f2 - r2) / GarageInterior.METER
		var expected: float = clampf(f2, r2 + DynoView.WB_MIN * GarageInterior.METER, r2 + DynoView.WB_MAX * GarageInterior.METER)
		check(absf(c2.global_position.z - expected) < 0.01, "%s: ön merdane dingil mesafesinde (%.2f m)" % [id, wb])
		check(view.node("Fan").global_position.z > b2.end.z, "%s: fan aracın önünde" % id)
		view.sim.start_engine()
		view.set_throttle(1.0)
		await frames(20)
		var spins: Array = [not is_zero_approx(view.node("DrumFront").rotation.x), not is_zero_approx(view.node("DrumRear").rotation.x)]
		check(spins == [view.sim.drives_front, view.sim.drives_rear], "%s: dönen merdaneler çekişe uygun (ön %s, arka %s)" % [id,
			spins[0], spins[1]])
		view.set_throttle(0.0)
		view.exit()
		await frames(2)
	mods.queue_free()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
