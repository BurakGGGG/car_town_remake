extends SceneTree
## JAPON DRIFT GÖSTERİSİ (traffic/drift_event.gd, traffic/drift_line.gd): yalnız arkadan itişli dört JDM (R34 yok);
## sekiz rotanın hepsinde iki araç yolda kalır, birbirine değmez, virajda büyük açıyla kayar, arkadaki öndekini izler;
## müzik tek seferlik, cıyak döngü; gösteri: hazırlıkta doğum / yarış daveti durur, kavşak yalnız boşalacak şeritlere
## açık, gösteride kimseye açık değil; drift araçları trafik listesinde değil, seçilemez, modelleri "kullanımda";
## gösteride hiçbir trafik aracına yaklaşmaz; duman ve iz oluşur; müziğin "drop"u öndeki aracın ekrana girişine denk;
## bitince her şey bırakılır, garaj teması döner, sayaç yeni aralığa kurulur ve kalıcıdır.
## Rota dört yoldan rastgele (art arda aynı yol yok), arkadaki araç hoplamaz.
## Çalıştırma: tools/run_tests.sh drift_event_test (pencereli: kamera görünürlüğü rota seçimine giriyor)

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func wait_until(cond: Callable, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		left -= 0.1
	return cond.call()


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== araçlar ==")
	check(not DriftEvent.DRIFT_IDS.has(&"nissan_skyline_r34"), "R34 (dört çeker) gösteride yok")
	for id: StringName in DriftEvent.DRIFT_IDS:
		var entry: Dictionary = CarCatalog.get_entry(id)
		check(not entry.is_empty() and String((entry["performance"] as Dictionary).get("drivetrain", "")) == "RWD",
			"%s arkadan itişli" % id)
		check(CarCatalog.scene_path(id) != "" and EngineBank.for_vehicle(id) != null, "%s: sahne ve pişmiş motor sesi var" % id)

	print("== çizgi: sekiz rota ==")
	for entry_dir: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(-1, 0, 0)]:
		for turn: int in [-1, 1]:
			_check_route(DriftLine.build(entry_dir, turn))

	print("== ses dosyaları ==")
	var theme: AudioStreamWAV = load(GameMusic.DRIFT_THEME) as AudioStreamWAV
	check(theme != null and theme.loop_mode == AudioStreamWAV.LOOP_DISABLED, "drift teması tek seferlik (döngü yok)")
	check(theme != null and theme.get_length() > DriftEvent.MUSIC_DROP + 8.0 and theme.get_length() < 30.0,
		"tema uzunluğu makul (%.1f sn)" % (theme.get_length() if theme else 0.0))
	var squeal: AudioStreamWAV = load(DriftEvent.SQUEAL_PATH) as AudioStreamWAV
	check(squeal != null and squeal.loop_mode == AudioStreamWAV.LOOP_FORWARD, "lastik cıyağı döngü")

	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	check(traffic != null and traffic.drift != null, "TrafficManager drift gösterisini kurdu")
	if traffic == null or traffic.drift == null:
		_finish()
		return
	var drift: DriftEvent = traffic.drift
	drift.persist = false
	traffic.chase._timer = 99999.0
	traffic._hazard_timer = 99999.0
	check(drift.time_left() > DriftEvent.PRELOAD_LEAD, "açılışta gösteri yok (%.0f sn kaldı)" % drift.time_left())
	var router: UiRouter = get_first_node_in_group("ui_router") as UiRouter
	await wait_until(func() -> bool: return traffic.vehicles.size() >= 2, 15.0)
	router.close_all()
	await frames(5)

	print("== hazırlık ==")
	var music: GameMusic = root.get_node_or_null(GameMusic.NODE_NAME) as GameMusic
	check(drift.start_now(Vector3(0, 0, 1), -1), "gösteri başladı (kuzeyden gelip sağa dönüş)")
	check(drift.phase == DriftEvent.Phase.PREPARE, "önce hazırlık")
	check(drift.holds_spawns() and traffic.spawn_challenger() == null, "hazırlıkta araç / yarış daveti doğmaz")
	var probe: TrafficVehicle = TrafficVehicle.new()
	root.add_child(probe)
	probe.global_transform.basis = Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)   # güneye (giriş şeridi)
	check(not drift.blocks_crossing(probe), "giriş şeridi kavşaktan geçip boşalabilir")
	probe.global_transform.basis = Basis.looking_at(Vector3(-1, 0, 0), Vector3.UP)   # doğuya (çıkış yolunun karşısı)
	check(not drift.blocks_crossing(probe), "çıkış yolunun karşı şeridi de boşalabilir")
	probe.global_transform.basis = Basis.looking_at(Vector3(1, 0, 0), Vector3.UP)    # batıya
	check(drift.blocks_crossing(probe), "öbür şeritler kavşağa giremez")
	probe.queue_free()
	for id: StringName in drift.reserved_models():
		check(traffic.models_in_use().has(id), "%s kullanımda sayılır (aynısı trafikte doğmaz)" % id)

	print("== gösteri ==")
	check(await wait_until(func() -> bool: return drift.phase == DriftEvent.Phase.SHOW, DriftEvent.PREPARE_MAX + 2.0),
		"şeritler boşaldı, gösteri başladı")
	check(music != null and music.is_drifting(), "drift teması çalıyor")
	check(await wait_until(func() -> bool: return drift.vehicles().size() == 2, 10.0), "iki araç doğdu")
	var cars: Array[TrafficVehicle] = drift.vehicles()
	for car: TrafficVehicle in cars:
		var hitbox: StaticBody3D = car.get_node_or_null("CarHitbox") as StaticBody3D
		check(car.is_drifting() and not traffic.vehicles.has(car) and (hitbox == null or not hitbox.input_ray_pickable),
			"%s drift kipinde, trafik listesinde değil, seçilemez" % car.vehicle_id)
	var near_miss: float = INF
	var crossing_breach: int = 0
	var drop_error: float = INF
	var max_smoke: int = 0
	while drift.phase == DriftEvent.Phase.SHOW:
		await physics_frame
		var alive: Array[TrafficVehicle] = drift.vehicles()
		for k: int in alive.size():
			var car: TrafficVehicle = alive[k]
			if drop_error == INF and k == 0 and not traffic.is_hidden(car.global_position):
				drop_error = GameMusic.drift_position(self) - DriftEvent.MUSIC_DROP
			for other: TrafficVehicle in traffic.vehicles:
				if is_instance_valid(other) and not other.in_bay():
					near_miss = minf(near_miss, DriftLine.box_gap(car.global_position, car.global_rotation.y,
						other.global_position, other.global_rotation.y, DriftEvent.HALF_LENGTH, DriftEvent.HALF_WIDTH))
			var at_center: Vector3 = TrafficVehicle._flat(car.global_position - DriftLine.CENTER)
			if absf(at_center.x) < 0.9 and absf(at_center.z) < 0.9:
				for other: TrafficVehicle in traffic.vehicles:
					var p: Vector3 = TrafficVehicle._flat(other.global_position - DriftLine.CENTER)
					if is_instance_valid(other) and absf(p.x) < 0.6 and absf(p.z) < 0.6:
						crossing_breach += 1
		var smoke: DriftSmoke = traffic.get_node_or_null("DriftSmoke") as DriftSmoke
		if smoke:
			max_smoke = maxi(max_smoke, smoke.alive_count())
	check(near_miss > 0.04, "drift araçları hiçbir trafik aracına değmedi (gövdeler arası en az %.2f)" % near_miss)
	check(crossing_breach == 0, "araçlar kavşaktayken kavşakta başka araç yok")
	check(absf(drop_error) < 0.2, "müziğin drop'u öndeki aracın ekrana girişine denk (%.3f sn)" % drop_error)
	check(max_smoke > 60, "duman çıktı (en çok %d topak)" % max_smoke)
	var marks: SkidMarks = null
	for child: Node in traffic.get_children():
		if child is SkidMarks:
			marks = child
	check(marks != null and marks.point_count() > 200, "yolda lastik izi kaldı (%d nokta)" % (marks.point_count() if marks else 0))

	print("== bitiş ==")
	check(drift.phase == DriftEvent.Phase.IDLE and drift.vehicles().is_empty(), "araçlar gitti, gösteri bitti")
	check(not drift.holds_spawns() and not drift.is_busy(), "doğum / kavşak serbest")
	check(drift.time_left() >= DriftEvent.EVERY.x and drift.time_left() <= DriftEvent.EVERY.y,
		"sonraki gösteri %.0f dk sonra (nadir)" % (drift.time_left() / 60.0))
	check(await wait_until(func() -> bool: return not music.is_drifting(), 30.0), "drift teması bitti")
	await create_timer(0.5).timeout
	check(not music.stream_paused and music.playing, "garaj teması kaldığı yerden döndü")

	print("== doğal akış: sayaç → ön yükleme → hazırlık → gösteri ==")
	DriftEvent._routes = []   # rotalar bu kez arka plan iş parçacığında kurulsun
	drift.set_time_left(4.0)
	check(await wait_until(func() -> bool: return drift.phase == DriftEvent.Phase.LOADING, 3.0), "süre yaklaşınca modeller yükleniyor")
	check(await wait_until(func() -> bool: return drift.is_busy(), 20.0), "süre dolunca hazırlık başladı (rotalar arka planda kuruldu)")
	check(await wait_until(func() -> bool: return drift.phase == DriftEvent.Phase.SHOW, DriftEvent.PREPARE_MAX + 2.0),
		"gösteri kendiliğinden başladı")
	check(await wait_until(func() -> bool: return drift.phase == DriftEvent.Phase.IDLE, 40.0), "ve bitti")
	check(await wait_until(func() -> bool: return not music.is_drifting(), 30.0), "tema bitti")

	print("== rota: dört yoldan rastgele ==")
	if DriftEvent._routes.is_empty():
		drift._ensure_routes(true)
	var seen: Dictionary = {}
	var repeats: int = 0
	var last: int = -1
	for n: int in 40:
		if drift._choose_route(Vector3.ZERO, 0):
			var e: int = int(drift._route["entry"])
			seen[e] = int(seen.get(e, 0)) + 1
			repeats += 1 if e == last else 0
			last = e
	drift._route = {}
	check(seen.size() == 4, "40 gösteride dört yolun hepsinden geldi (%s)" % seen)
	check(repeats == 0, "aynı yoldan art arda gelmedi")

	print("== müzik katmanları ==")
	check(GameMusic.drift(self, true), "drift teması yeniden başlatılabilir")
	GameMusic.race(self, true)
	await frames(2)
	check(not music.is_drifting(), "yarış teması başlayınca drift teması susar")
	check(not GameMusic.drift(self, true), "yarış teması çalarken drift teması başlamaz")
	GameMusic.race(self, false)
	await create_timer(1.5).timeout

	print("== kalıcı sayaç ==")
	drift.persist = true
	drift.set_time_left(321.0)
	drift._save_state()
	var config: ConfigFile = ConfigFile.new()
	check(config.load(DriftEvent.STATE_PATH) == OK and is_equal_approx(float(config.get_value("drift", "left", -1.0)), 321.0),
		"sayaç dosyaya yazıldı")
	drift.set_time_left(5.0)
	drift._load_state()
	check(is_equal_approx(drift.time_left(), 321.0), "sayaç dosyadan okundu")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DriftEvent.STATE_PATH))
	_finish()


## Bir rota: iki araç gövdesi (en uzun drift aracı ölçüsünde) yolda, birbirine değmez, virajda büyük açıyla kayar.
func _check_route(line: DriftLine) -> void:
	var lead: DriftLine.Track = line.lead_track(&"", maxf(line.corner_from - 9.5, 0.0))
	var follow: DriftLine.Track = line.follow_track(&"", lead)
	var off_road: int = 0
	var min_gap: float = INF
	var corner_slip: float = 0.0
	var max_slip: float = 0.0
	var behind: bool = true
	for i: int in lead.s.size():
		max_slip = maxf(max_slip, absf(lead.slip[i]))
		var s: float = lead.s[i]
		if s > line.corner_from and s < line.corner_to:
			corner_slip = maxf(corner_slip, absf(lead.slip[i]))
		for track: DriftLine.Track in [lead, follow]:
			if i < track.s.size():
				for c: Vector3 in DriftLine.corners(track.position[i], track.yaw[i], DriftEvent.HALF_LENGTH, DriftEvent.HALF_WIDTH):
					if not DriftLine.on_road(c):
						off_road += 1
		if i < follow.s.size():
			behind = behind and follow.s[i] < lead.s[i]
			min_gap = minf(min_gap, DriftLine.box_gap(lead.position[i], lead.yaw[i], follow.position[i], follow.yaw[i],
				DriftEvent.HALF_LENGTH, DriftEvent.HALF_WIDTH))
	var name: String = "giriş %s, %s" % [line.entry_dir, "sola" if line.turn > 0 else "sağa"]
	check(off_road == 0, "%s: iki araç da yolda (taşan köşe %d)" % [name, off_road])
	check(min_gap > 0.05, "%s: araçlar birbirine değmez (gövdeler arası en az %.2f)" % [name, min_gap])
	check(behind, "%s: arkadaki öndekini izler" % name)
	# Arkadaki araç hoplamaz (2026-11-02 kullanıcı: "arkadaki araç zıplar gibi bozuk geliyor"): hız ve gövde yunuslaması
	# kare kare sıçramaz, yunuslama titremez
	for pair: Array in [["öndeki", lead], ["arkadaki", follow]]:
		var track: DriftLine.Track = pair[1]
		var jump: float = 0.0
		var pitch_jump: float = 0.0
		var flips: int = 0
		for i: int in range(2, track.s.size()):
			jump = maxf(jump, absf(track.speed[i] - track.speed[i - 1]))
			var d1: float = track.pitch[i] - track.pitch[i - 1]
			var d0: float = track.pitch[i - 1] - track.pitch[i - 2]
			pitch_jump = maxf(pitch_jump, absf(d1))
			if signf(d1) != signf(d0) and absf(d1) > 0.003:
				flips += 1
		check(jump < 0.08 and pitch_jump < 0.006 and flips == 0, "%s: %s araç pürüzsüz (hız sıçraması %.3f, yunuslama %.4f, titreme %d)" % [
			name, pair[0], jump, pitch_jump, flips])
	check(rad_to_deg(corner_slip) > 35.0 and rad_to_deg(max_slip) < 55.0,
		"%s: virajda büyük açı (%.0f°), en çok %.0f°" % [name, rad_to_deg(corner_slip), rad_to_deg(max_slip)])


func _finish() -> void:
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
