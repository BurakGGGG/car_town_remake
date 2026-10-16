extends SceneTree
## RÖVANŞ — kaybedilen drag yarışından sonra sonuç panosunda RÖVANŞ: aynı rakiple yeniden yarış.
##   - kayıpta rakip şeritte bekler, RÖVANŞ plakası görünür; teselli XP'si yalnızca ilk kayıpta
##   - RÖVANŞ → sonuç kapanır, pist aynı rakiple baştan; rakip başına TEK rövanş: ona da yenilince plaka çıkmaz
##   - rövanş kaybı ödülsüz, rövanş galibiyeti tam ödül; hak bitince / GARAJA DÖN'de rakip yola döner
##   - KAÇAN KAYBEDEN (oyunda ~7'de 1; burada flee_chance 1): oyuncu dünyaya dönünce kaçar — kırmızıda kavşağa dalar, karşı yön
##     yeşilde bile bekletilir, orta çizgide normal trafikten hızlı gider
## Yarışın kendisi oynatılmaz: pistin bitiş sinyali (race_completed) sonuçla gönderilir.
## Çalıştırma: tools/run_tests.sh race_rematch_test (pencereli: trafik modelleri arka planda yüklenir)

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


func _challenge(race: RaceManager) -> bool:
	var until: int = Time.get_ticks_msec() + 40000
	while Time.get_ticks_msec() < until and not race.has_challenge():
		await process_frame
		race.request_challenge_now()
	return race.has_challenge()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var hud: Hud = main.find_child("HUD", true, false)
	var router: UiRouter = hud.router
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership.owned_count() == 0:
		ownership.add_vehicle(&"tofas_sahin")   # araçsız oyuncuya rakip gelmez (ilk araç HOŞ GELDİN KUTUSU'ndan)
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var result: RaceResultScreen = hud.race_result_screen
	var track: DragRaceScreen = hud.drag_race_screen
	race.flee_chance = 1.0   # kaçış normalde ~7'de 1: senaryo için her zaman
	race.challenge_interval_min = 0.1
	race.challenge_interval_max = 0.2
	race.challenge_timeout = 600.0

	print("== KAYIP → RÖVANŞ TEKLİFİ ==")
	check(await _challenge(race), "rakip geldi, davet açık")
	var challenger: TrafficVehicle = race.challenger()
	var rival: StringName = race.rival_id()
	hud.race_challenge_screen.race_accepted.emit()
	await create_timer(0.6).timeout
	check(router.top() == &"drag_race" and track.visible, "pist açıldı")
	var xp_before: int = progress.xp
	var loss_xp: int = int(race.reward_for(rival, false)["xp"])
	track.race_completed.emit(false, 12.4, 11.9)
	await create_timer(0.5).timeout
	check(router.top() == &"race_result", "sonuç panosu açıldı")
	check(result._rematch_button.visible and not result._rematch_button.disabled, "kaybedince RÖVANŞ plakası görünür")
	check(result._head.text == "YARIŞ BİTTİ", "ilk yarışın başlığı")
	var xp_after: int = progress.xp
	check(xp_after - xp_before == loss_xp or progress.level > 1, "ilk kayıpta teselli XP'si (+%d)" % loss_xp)
	check(race.can_rematch() and race.challenger() == challenger and challenger.mode == TrafficVehicle.Mode.RACE_CHALLENGE,
		"rakip şeritte rövanş için bekliyor")

	print("== RÖVANŞ (tek hak) ==")
	result._rematch_button.pressed.emit()
	await create_timer(0.6).timeout
	check(router.top() == &"drag_race" and not result.visible and track.visible, "sonuç kapandı, pist açık")
	check(track._phase in [DragRaceScreen.Phase.READY, DragRaceScreen.Phase.COUNTDOWN] and track._rival_id == rival,
		"pist aynı rakiple baştan, geri sayımda (%s)" % track._rival_id)
	check(race.rematch_count() == 1 and not race.can_rematch(), "rövanş sürüyor, ikinci hak yok")
	check(is_instance_valid(track._player_car) and is_instance_valid(track._rival_car), "iki araç da pistte")
	var money_before: int = economy.money
	var xp_mid: int = progress.xp
	track.race_completed.emit(false, 12.1, 11.8)
	await create_timer(0.5).timeout
	check(economy.money == money_before and progress.xp == xp_mid, "rövanş kaybı ödülsüz (bilerek kaybedip XP toplanmaz)")
	check(result._head.text == "RÖVANŞ" and result._reward.text == "ÖDÜL YOK", "başlık RÖVANŞ, ödül yok")
	check(not result._rematch_button.visible and not race.can_rematch(), "rövanşa da yenilince RÖVANŞ çıkmaz")
	check(race.challenger() == null and race.rematch_count() == 0, "rakip yola döndü, sayaç sıfır")
	result.exit_requested.emit()
	await create_timer(0.5).timeout
	check(router.top() == &"" and hud.bottom.visible, "garaja dönüldü")
	if is_instance_valid(challenger):
		check(challenger.mode == TrafficVehicle.Mode.TRAFFIC and not challenger.bubble_visible(), "rakip normal trafikte, balon kapalı")

	print("== RÖVANŞI KAZANMAK ==")
	await create_timer(1.0).timeout
	check(await _challenge(race), "yeni rakip geldi")
	var rival_b: StringName = race.rival_id()
	var loser: TrafficVehicle = race.challenger()
	hud.race_challenge_screen.race_accepted.emit()
	await create_timer(0.6).timeout
	track.race_completed.emit(false, 12.3, 11.9)
	await create_timer(0.5).timeout
	check(result._rematch_button.visible, "ilk kayıpta RÖVANŞ sunuldu")
	result._rematch_button.pressed.emit()
	await create_timer(0.6).timeout
	var win: Dictionary = race.reward_for(rival_b, true)
	money_before = economy.money
	track.race_completed.emit(true, 11.2, 11.6)
	await create_timer(0.5).timeout
	check(economy.money - money_before == int(win["money"]), "rövanş galibiyeti tam ödül (+%d ₺)" % int(win["money"]))
	check(result._head.text == "RÖVANŞ" and not result._rematch_button.visible, "kazanınca rövanş yok")
	check(race.loser_waiting() and race.loser_flees() and loser.mode == TrafficVehicle.Mode.RACE_CHALLENGE,
		"kaybeden rakip şeritte oyuncunun dönüşünü bekliyor (yarış ekranında dünya çizilmez)")
	var defaults: RaceManager = RaceManager.new()
	check(is_equal_approx(defaults.flee_chance, 1.0 / 7.0), "oyunda kaçış nadir: kazanılan yarışların 7'de 1'i")
	defaults.free()

	print("== KAÇAN KAYBEDEN ==")
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	var lights: TrafficLights = main.find_child("TrafficLights", true, false) as TrafficLights
	if lights:
		lights.set_process(false)
		lights.set_phase(TrafficLights.Phase.GREEN, 1 - loser.axis)   # kaçağın yönü KIRMIZI
	result.exit_requested.emit()
	await create_timer(0.3).timeout
	check(router.top() == &"", "garaja dönüldü")
	check(race.challenger() == null and loser.mode == TrafficVehicle.Mode.TRAFFIC and loser.fleeing, "kaybeden kaçıyor")
	check(loser.max_speed > 1.5 and loser.busy_after_race(), "normal trafikten hızlı, müşteri olmaz (%.2f)" % loser.max_speed)
	var entered_on_red: bool = false
	var shifted: float = 0.0
	var top_speed: float = 0.0
	var cross_denied: bool = false
	var claim_seen: bool = false
	var cross_car: TrafficVehicle = null
	var cross_point: TrafficWaypoint = null
	for point: TrafficWaypoint in traffic.spawn_points:
		if (loser.axis == 1 and point.name == &"W_in_spawn") or (loser.axis == 0 and point.name == &"S_in_spawn"):
			cross_point = point
	for attempt: int in 8:
		cross_car = traffic._spawn_at(cross_point) if cross_point else null
		if cross_car or cross_point == null:
			break
		# Bir modelden tek araç: boş model yoksa kaçak dışındaki bir trafik aracı yoldan alınır, modeli boşalır
		for other: TrafficVehicle in traffic.vehicles.duplicate():
			if other != loser and is_instance_valid(other) and not other.fleeing:
				traffic._on_vehicle_despawn(other)
				break
	check(cross_car != null, "karşı yönde yeşilde bekleyen araç kuruldu")
	if cross_car:
		cross_car.set_physics_process(false)   # karşı yönün yeşilinde, giriş çizgisinde bekleyen araç
	var start_lateral: float = loser.yield_shift()
	var start_yaw: float = loser.global_rotation.y
	for i: int in 12:
		await physics_frame
	check(absf(loser.yield_shift() - start_lateral) < 0.06 and absf(angle_difference(loser.global_rotation.y, start_yaw)) > deg_to_rad(4.0),
		"durduğu yerden kalktı: yana ışınlanmadı, burnunu çevirdi (yanal %+.2f, dönüş %.0f°)" % [
			loser.yield_shift() - start_lateral, rad_to_deg(absf(angle_difference(loser.global_rotation.y, start_yaw)))])
	for i: int in 600:
		await physics_frame
		shifted = minf(shifted, loser.yield_shift())
		top_speed = maxf(top_speed, loser.speed)
		# Karşı yön, kaçak kavşağı TALEP ETTİKTEN sonra yeşilde bile bekletilmeli. Verilen izin hemen bırakılır:
		# kavşakta tutulan araç sonraki soruda zaten içeride sayılır, "reddedildi" hiç görülemezdi.
		if traffic.get("_runner_claim") == loser:
			claim_seen = true
		if cross_car and not cross_denied and traffic.get("_runner_claim") == loser:
			cross_denied = not traffic.request_crossing(cross_car)
			if not cross_denied:
				traffic.finish_crossing(cross_car)
		if loser.is_in_intersection():
			entered_on_red = lights == null or lights.light_of(loser.axis) != &"green"
			break
	for i: int in 90:   # direksiyonla kayma zaman alır: orta çizgi kavşaktan geçerken de ölçülür
		await physics_frame
		shifted = minf(shifted, loser.yield_shift())
		top_speed = maxf(top_speed, loser.speed)
	check(entered_on_red, "kırmızıda kavşağa daldı")
	check(cross_denied, "karşı yön yeşilde bile kavşağa giremedi (kaçak geçiyor; talep görüldü: %s, karşı araç: %s, kavşakta: %s)" % [
		claim_seen, cross_car != null, (traffic.get("_crossing") as Array).has(cross_car) if cross_car else false])
	check(shifted < -0.15, "orta çizgiye taştı (%.2f)" % shifted)
	check(top_speed > 1.0, "hızlı gidiyor (%.2f > normal en çok 0,9)" % top_speed)
	if cross_car:
		traffic._on_vehicle_despawn(cross_car)
	if lights:
		lights.set_process(true)

	print("== KAYIP → GARAJA DÖN ==")
	await create_timer(1.0).timeout
	check(await _challenge(race), "yeni rakip geldi")
	var second: TrafficVehicle = race.challenger()
	hud.race_challenge_screen.race_accepted.emit()
	await create_timer(0.6).timeout
	track.race_completed.emit(false, 12.6, 11.7)
	await create_timer(0.5).timeout
	check(result._rematch_button.visible, "RÖVANŞ sunuldu")
	result.exit_requested.emit()
	await create_timer(0.5).timeout
	check(router.top() == &"" and not race.can_rematch() and race.challenger() == null, "GARAJA DÖN: rövanş yok, rakip gitti")
	if is_instance_valid(second):
		check(second.mode == TrafficVehicle.Mode.TRAFFIC, "rakip trafiğe döndü")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
