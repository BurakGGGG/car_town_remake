extends SceneTree
## TRAFİK MODEL HAVUZU — trafiğe kapalı (traffic=false, S sınıfı) araçlar şehirde rastgele doğmaz.
## Eskiden yarış rakibi için yüklenen model şehir havuzuna giriyordu: oyuncu A sınıfıyla yarışırken
## sokakta doğan araçların dörtte biri GT3 / Huracán / 488 oluyordu. Rakip yine o modelle gelmeli.
## Çalıştırma: tools/run_tests.sh traffic_pool_test (pencereli: başsız sahte çizici arka planda
## aynı anda yüklenen mesh'leri bozuyor — RID_Owner<DummyMesh> iş parçacığına korumasız; telefon GLES3)

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Koşul sağlanana ya da süre dolana kadar bekler (arka plan yüklemesi gerçek zaman ister).
func wait_until(cond: Callable, seconds: float) -> bool:
	var left: float = seconds
	while left > 0.0:
		if cond.call():
			return true
		await create_timer(0.1).timeout
		left -= 0.1
	return cond.call()


func _find_traffic(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null


func _clear(traffic: TrafficManager) -> void:
	for v: TrafficVehicle in traffic.vehicles.duplicate():
		traffic._on_vehicle_despawn(v)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var traffic: TrafficManager = _find_traffic(main)
	check(traffic != null, "TrafficManager bulundu")
	if traffic == null:
		print("RESULT fails=%d" % fails)
		quit(1)
		return
	traffic.max_vehicles = 0   # sınama sırasında kendi kendine araç doğurmasın
	check(await wait_until(func() -> bool: return not traffic.city_model_ids().is_empty(), 20.0),
		"şehir havuzu yüklendi")

	print("== yarışa özel modeller şehir havuzuna girmez ==")
	var supers: Array[StringName] = [&"porsche_gt3", &"lambo_huracan", &"ferrari_488_pista"]
	for id: StringName in supers:
		check(not bool(CarCatalog.get_entry(id).get("traffic", true)), "%s trafiğe kapalı (katalog)" % id)
	traffic.request_model(&"porsche_gt3")
	check(await wait_until(func() -> bool: return traffic.loaded_model_ids().has(&"porsche_gt3"), 20.0),
		"GT3 rakip için yüklendi")
	check(not traffic.city_model_ids().has(&"porsche_gt3"), "GT3 şehir havuzunda DEĞİL")
	traffic.request_model(&"lambo_huracan")
	traffic.request_model(&"ferrari_488_pista")
	check(await wait_until(func() -> bool:
		return traffic.loaded_model_ids().has(&"lambo_huracan") and traffic.loaded_model_ids().has(&"ferrari_488_pista"), 30.0),
		"Huracán ve 488 yüklendi")
	var race_only: int = traffic.loaded_model_ids().size() - traffic.city_model_ids().size()
	check(race_only <= TrafficManager.RACE_MODEL_LIMIT, "bellekte en fazla %d yarışa özel model (%d)" % [TrafficManager.RACE_MODEL_LIMIT, race_only])
	check(not traffic.loaded_model_ids().has(&"porsche_gt3"), "en eski yarış modeli (GT3) bırakıldı")
	for id: StringName in traffic.city_model_ids():
		check(bool(CarCatalog.get_entry(id).get("traffic", false)), "şehir havuzundaki %s trafiğe açık" % id)

	print("== şehirde doğan araçlar ==")
	_clear(traffic)
	var seen: Dictionary = {}
	var closed: Array[StringName] = []
	for i: int in 60:
		var v: TrafficVehicle = traffic._spawn_at(traffic.spawn_points[i % traffic.spawn_points.size()])
		seen[v.vehicle_id] = true
		if not bool(CarCatalog.get_entry(v.vehicle_id).get("traffic", false)):
			closed.append(v.vehicle_id)
		traffic._on_vehicle_despawn(v)
	await frames(2)
	check(closed.is_empty(), "60 şehir aracında trafiğe kapalı model yok %s (görülen: %s)" % [closed, seen.keys()])

	print("== rakip yine istenen modelle gelir ==")
	var rival: TrafficVehicle = null
	for attempt: int in 50:
		_clear(traffic)
		await frames(2)
		rival = traffic.spawn_challenger(&"ferrari_488_pista")
		if rival != null:
			break
		await create_timer(0.1).timeout
	check(rival != null and rival.vehicle_id == &"ferrari_488_pista", "yarış şeridine 488 çıktı")
	check(rival != null and rival.race_lane, "488 yarış şeridinde")
	_clear(traffic)
	await frames(2)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
