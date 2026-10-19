extends SceneTree
## EGZOTİK TRAFİK + TAMİR SESLERİ (2026-10-17) — kullanıcı: "trafikte tek tük egzotik araç geçsin 20'de 1, bu egzotik
## araçlara trafikte motor uğultusu ekle; tamirdeki aracın altınını toplama sesi ve elmasla geçme sesi ekle".
## Denetlenen: katalogdaki egzotikler, ortalama 20 doğumda bir + en az 8 araç ara, gerçek doğum akışı (model yüklenir,
## doğar, listeden düşer), egzotik müşteri olmaz, CityAmbience egzotiğe motor kurar, motorun vites / devir / düzey
## davranışı, motor döngüsü dikişsiz, HudSfx sesleri üretilir ve HUD'da kurulu.
## Çalıştırma: tools/run_tests.sh exotic_traffic_test (pencereli: araç modelleri arka planda yüklenir, bkz.
## traffic_pool_test)

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


func _clear(traffic: TrafficManager) -> void:
	for v: TrafficVehicle in traffic.vehicles.duplicate():
		traffic._on_vehicle_despawn(v)


func _find_hud(node: Node) -> Hud:
	if node is Hud:
		return node
	for child: Node in node.get_children():
		var found: Hud = _find_hud(child)
		if found:
			return found
	return null


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	print("== katalog ==")
	var exotics: Array[StringName] = CarCatalog.exotic_ids()
	check(exotics.size() == 6 and exotics.has(&"porsche_gt3") and exotics.has(&"lambo_huracan")
		and exotics.has(&"ferrari_488_pista") and exotics.has(&"bugatti_chiron") and exotics.has(&"bugatti_veyron")
		and exotics.has(&"ferrari_laferrari"), "egzotikler GT3 / Huracán / 488 Pista / iki Bugatti / LaFerrari (%s)" % [exotics])
	for id: StringName in exotics:
		check(not bool(CarCatalog.get_entry(id)["traffic"]), "%s normal trafiğe kapalı" % id)
	check(not CarCatalog.is_exotic(&"chevrolet_camaro") and not CarCatalog.is_exotic(&"police_bentley"),
		"Camaro / polis egzotik değil")
	check(ExoticEngine.cylinders_of(&"lambo_huracan") == 10 and ExoticEngine.cylinders_of(&"ferrari_488_pista") == 8
		and ExoticEngine.cylinders_of(&"porsche_gt3") == 6 and ExoticEngine.cylinders_of(&"bugatti_chiron") == 10
		and ExoticEngine.cylinders_of(&"ferrari_laferrari") == 10,
		"motor tınısı: Huracán V10, 488 V8, GT3 düz altı, W16 / V12 en tiz profil")

	print("== motor döngüsü ==")
	for cylinders: int in [6, 8, 10]:
		var wav: AudioStreamWAV = ExoticEngine.make_stream(cylinders)
		var n: int = wav.data.size() / 2
		var max_step: int = 0
		for i: int in range(1, n):
			max_step = maxi(max_step, absi(wav.data.decode_s16(i * 2) - wav.data.decode_s16((i - 1) * 2)))
		var seam: int = absi(wav.data.decode_s16(0) - wav.data.decode_s16((n - 1) * 2))
		var peak: int = 0
		for i: int in n:
			peak = maxi(peak, absi(wav.data.decode_s16(i * 2)))
		check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end == n, "%d silindir: döngü tam arabellek" % cylinders)
		check(seam <= max_step, "%d silindir: döngü dikişi içerideki en büyük adımdan küçük (%d ≤ %d)" % [cylinders, seam, max_step])
		check(peak > 8000 and peak < 32767, "%d silindir: düzey makul, kırpılma yok (tepe %d)" % [cylinders, peak])

	print("== motor sürüşü ==")
	var engine: ExoticEngine = ExoticEngine.new()
	root.add_child(engine)
	engine.setup(ExoticEngine.make_stream(8), 8, 1.0, &"Master")
	engine.play()   # duraklatma durumu yalnızca çalan (ses sunucusuna kaydolmuş) oynatıcıda okunur
	await frames(2)
	var dt: float = 1.0 / 60.0
	var speed: float = 0.0
	var top_gear: int = 0
	var loud: float = -100.0
	for i: int in 120:   # 2 sn: 0 → 0,8 birim/sn (0,6 birim/sn² — trafiğin hızlanması)
		speed = minf(speed + 0.6 * dt, 0.8)
		engine.drive(speed, dt)
		top_gear = maxi(top_gear, engine.gear())
		loud = maxf(loud, engine.volume_db)
	check(top_gear >= 2, "hızlanırken vites büyür (en yüksek %d)" % (top_gear + 1))
	check(loud > ExoticEngine.ENGINE_DB, "gaz verirken seyirden gür (%.1f dB)" % loud)
	for i: int in 120:   # 2 sn sabit hız
		engine.drive(speed, dt)
	var cruise_rpm: float = engine.rpm()
	check(cruise_rpm > 1500.0 and cruise_rpm < ExoticEngine.CRUISE_SHIFT_RPM + 200.0,
		"sabit hızda sakin devir (%.0f d/dk, %d. vites)" % [cruise_rpm, engine.gear() + 1])
	check(absf(engine.pitch_scale - cruise_rpm / ExoticEngine.BASE_RPM) < 0.05, "perde = devir / döngü devri")
	var cruise_db: float = engine.volume_db
	for i: int in 90:   # 1,5 sn fren
		speed = maxf(speed - 0.7 * dt, 0.0)
		engine.drive(speed, dt)
	check(engine.gear() == 0 and absf(engine.rpm() - ExoticEngine.IDLE_RPM) < 50.0, "durunca 1. vites, rölanti")
	for i: int in 60:
		engine.drive(0.0, dt)
	check(engine.volume_db < cruise_db and not engine.stream_paused, "kırmızıda rölanti: kısık ama duyulur")
	for i: int in int((ExoticEngine.IDLE_SILENCE + 2.0) / dt):
		engine.drive(0.0, dt)
	check(engine.stream_paused, "uzun bekleyişte rölanti de söner")
	for i: int in 30:
		engine.drive(minf(float(i) * 0.6 * dt, 0.8), dt)
	check(not engine.stream_paused, "kalkınca yeniden duyulur")
	engine.queue_free()

	print("== tamir sesleri ==")
	var collect: PackedFloat32Array = HudSfx.collect_samples()
	var gem: PackedFloat32Array = HudSfx.gem_samples()
	for pair: Array in [["para toplama", collect, 1.0], ["elmasla bitirme", gem, 1.3]]:
		var samples: PackedFloat32Array = pair[1]
		var finite: bool = true
		var peak: float = 0.0
		for v: float in samples:
			finite = finite and is_finite(v)
			peak = maxf(peak, absf(v))
		check(finite and peak > 0.1, "%s: üretildi (tepe %.2f)" % [pair[0], peak])
		check(float(samples.size()) / float(HudSfx.MIX_RATE) >= float(pair[2]), "%s: %.2f sn" % [pair[0], float(samples.size()) / HudSfx.MIX_RATE])
	var late: float = 0.0   # altın şıngırtısı paraların yere düştüğü aralıkta (RepairFx.coins: 0,4–0,9 sn)
	for i: int in range(int(0.45 * HudSfx.MIX_RATE), int(0.85 * HudSfx.MIX_RATE)):
		late = maxf(late, absf(collect[i]))
	check(late > 0.05, "para toplama: 0,45–0,85 sn'de düşen altınlar duyulur (%.2f)" % late)
	check(RepairManager.new().has_signal(&"gem_finished") and PerformanceModManager.new().has_signal(&"gem_finished"),
		"tamir ve parça takma elmasla bitince sinyal verir")

	print("== şehirde ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	check(traffic != null, "TrafficManager bulundu")
	if traffic == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	var hud: Hud = _find_hud(main)
	check(hud != null and hud._sfx != null and hud._sfx.is_inside_tree(), "HUD'da tamir sesleri kurulu")
	check(await wait_until(func() -> bool: return hud != null and hud._sfx._ready_streams(), 20.0),
		"tamir sesleri arka planda üretildi")
	traffic.max_vehicles = 0
	check(await wait_until(func() -> bool: return not traffic.city_model_ids().is_empty(), 20.0), "şehir havuzu yüklendi")

	print("-- oran: ortalama %d doğumda bir, en az %d araç ara --" % [TrafficManager.EXOTIC_EVERY, TrafficManager.EXOTIC_MIN_GAP])
	traffic._rng.seed = 20261017
	traffic._since_exotic = 0
	traffic._exotic_next = &""
	var normal: StringName = traffic.city_model_ids()[0]
	var gaps: Array[int] = []
	var last: int = 0
	for n: int in range(1, 8001):
		if traffic._exotic_next != &"":
			gaps.append(n - last)
			last = n
			traffic._count_spawn(traffic._exotic_next)
		else:
			traffic._count_spawn(normal)
	var total: int = 0
	var shortest: int = 1 << 30
	for g: int in gaps:
		total += g
		shortest = mini(shortest, g)
	var mean: float = float(total) / maxf(float(gaps.size()), 1.0)
	check(mean > 18.5 and mean < 21.5, "8000 doğumda %d egzotik, ortalama aralık %.1f" % [gaps.size(), mean])
	check(shortest >= TrafficManager.EXOTIC_MIN_GAP + 1, "art arda gelmez: en kısa aralık %d" % shortest)
	await create_timer(1.0).timeout   # benzetim sırasında başlayan yüklemeler bitsin

	print("-- gerçek doğum --")
	_clear(traffic)
	await frames(2)
	traffic._exotic_next = &"lambo_huracan"
	traffic._request_model(&"lambo_huracan")
	var exotic: Array[TrafficVehicle] = []
	check(await wait_until(func() -> bool:
		if traffic._try_spawn():
			var v: TrafficVehicle = traffic.vehicles.back()
			if v.vehicle_id == &"lambo_huracan":
				exotic.append(v)
			else:
				traffic._on_vehicle_despawn(v)
		return not exotic.is_empty(), 20.0), "sırası gelen Huracán yüklendi ve şehre girdi")
	check(traffic._since_exotic == 0 and traffic._exotic_next == &"", "egzotik doğunca sayaç sıfırlandı")
	check(not traffic.loaded_model_ids().has(&"lambo_huracan"), "egzotik modeli listeden düştü (sahnesini araç tutuyor)")
	check(traffic._pick_exotic() != &"lambo_huracan", "şehirdeki egzotik ikinci kez seçilmez")
	if not exotic.is_empty():
		var car: TrafficVehicle = exotic[0]
		var repairs: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
		if repairs:
			var offered: bool = false
			for option: Dictionary in repairs._candidates():
				offered = offered or option["vehicle"] == car
			check(not offered, "egzotik tamir müşterisi adayı değil")
		var ambience: CityAmbience = traffic.ambience
		check(await wait_until(func() -> bool: return ambience.is_running(), 20.0), "şehir sesleri çalışıyor")
		check(await wait_until(func() -> bool: return ambience.exotic_engines().size() == 1, 3.0),
			"Huracán'a motor sesi kuruldu (%d)" % ambience.exotic_engines().size())
		var engines: Array[ExoticEngine] = ambience.exotic_engines()
		if not engines.is_empty():
			check(engines[0].bus == CityAmbience.BUS, "motor Ambience bus'ında (garaj / mağazada susar)")
			check(await wait_until(func() -> bool: return engines[0].global_position.distance_to(car.global_position) < 0.3, 2.0),
				"motor sesi aracı izliyor")
		var normal_car: TrafficVehicle = null
		for attempt: int in 30:
			normal_car = traffic._spawn_at(traffic.spawn_points[0])
			if normal_car:
				break
			await create_timer(0.2).timeout
		await frames(3)
		check(ambience.exotic_engines().size() == 1, "normal araca motor sesi kurulmaz")
		traffic._on_vehicle_despawn(car)
		await frames(3)
		check(ambience.exotic_engines().is_empty(), "egzotik gidince motor sesi kalkar")
	_clear(traffic)
	await frames(2)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
