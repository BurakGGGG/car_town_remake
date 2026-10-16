extends SceneTree
## TRAFİK MODEL HAVUZU — trafiğe kapalı (traffic=false, S sınıfı) araçlar şehirde rastgele doğmaz; şehirde
## bir modelden aynı anda en fazla bir araç olur (yarış rakibi ve kovalamaca şüphelisi dahil).
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


func _unique(cars: Array[TrafficVehicle]) -> bool:
	var seen: Dictionary = {}
	for car: TrafficVehicle in cars:
		if seen.has(car.vehicle_id):
			return false
		seen[car.vehicle_id] = true
	return true


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

	print("== aynı modelden tek araç ==")
	_clear(traffic)
	await frames(2)
	var pool_ids: Array[StringName] = traffic.city_model_ids()
	var spawned: Array[TrafficVehicle] = []
	for i: int in pool_ids.size():
		var car: TrafficVehicle = traffic._spawn_at(traffic.spawn_points[i % traffic.spawn_points.size()])
		if car:
			car.set_physics_process(false)   # beklerken yolun sonuna varıp silinmesin (model boşa çıkardı)
			spawned.append(car)
	check(spawned.size() == pool_ids.size() and _unique(traffic.vehicles), "havuzdaki %d model → %d farklı araç" % [pool_ids.size(), spawned.size()])
	check(traffic._spawn_at(traffic.spawn_points[0]) == null, "havuzun her modeli şehirde: aynısından ikinci araç doğmaz")
	check(traffic.random_city_model().is_empty(), "kovalamaca şüphelisi de şehirdeki modeli almaz")
	check(traffic.spawn_challenger(spawned[0].vehicle_id) == null, "şehirdeki model yarış şeridine ikinci kez çıkmaz")
	var fresh: Array[TrafficVehicle] = []
	check(await wait_until(func() -> bool:
		var car: TrafficVehicle = traffic._spawn_at(traffic.spawn_points[0])
		if car:
			fresh.append(car)
		return not fresh.is_empty(), 20.0), "boştaki bir model yüklendi, yeni araç onunla doğdu")
	check(not fresh.is_empty() and not pool_ids.has(fresh[0].vehicle_id), "yeni araç farklı bir model (%s)" % (fresh[0].vehicle_id if not fresh.is_empty() else &""))
	check(_unique(traffic.vehicles), "şehirde aynı modelden iki araç yok")
	check(traffic.city_model_ids().size() <= traffic.pool_size, "havuz sınırı aşılmadı (%d)" % traffic.city_model_ids().size())
	var gone: StringName = spawned[0].vehicle_id
	traffic._on_vehicle_despawn(spawned[0])
	await frames(2)
	check(not traffic.is_model_in_use(gone), "araç gidince model yeniden boşa çıkar")
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	if race:
		var player: StringName = race.player_vehicle_id()
		var rivals: Array[StringName] = RaceManager.rival_pool(player)
		var busy: Dictionary = {}
		for id: StringName in rivals.slice(1):
			busy[id] = true
		race._records = {&"x": 1.0}   # ilk yarış değil (ilk yarışta en yavaş rakip kuralı ayrı)
		check(race.rival_id_for(player, busy) == rivals[0], "rakip şehirde OLMAYAN modelden seçilir")
		for id: StringName in rivals:
			busy[id] = true
		check(rivals.has(race.rival_id_for(player, busy)), "havuzun hepsi şehirdeyse yine havuzdan (model boşalınca gelir)")
		race._records = {}
	_clear(traffic)
	await frames(2)

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
