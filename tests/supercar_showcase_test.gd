extends SceneTree
## SÜPER ARABA TANITIMI (2026-10-23): 2 yarışı biten yeni oyuncunun 3. rakibi öne çıkan arkadaşın BEYAZ OVALE ÉCLAIR'i —
## kusursuz sürer (ezici fark), rövanş yok, öğrenen zorluğa yazılmaz; kaybedip GARAJA DÖN'de "BİR GÜN SENİN DE OLACAK!"
## ekranı açılır. Bir kez gelir (kayıtta), davet geri çevrilirse araç şehirden çıkınca yine gelir, eski oyuncuya / testlerde
## gelmez.
## Çalıştırma: tools/run_tests.sh supercar_showcase_test (pencereli: rakip modeli arka planda yüklenir)

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
		ownership.add_vehicle(&"tofas_sahin")   # araçsız oyuncuya rakip gelmez
	var result: RaceResultScreen = hud.race_result_screen
	var track: DragRaceScreen = hud.drag_race_screen
	var tease: SupercarTeaseScreen = hud.supercar_tease_screen
	race.challenge_interval_min = 0.1
	race.challenge_interval_max = 0.2
	race.challenge_timeout = 600.0

	print("== KAPALI / AÇIK ==")
	check(not race.showcase_enabled, "testlerde (CT_NO_TUTORIAL) tanıtım kapalı")
	race.showcase_enabled = true
	race.load_state({"races": 1, "wins": 1})
	check(not race.showcase_due(), "1 yarıştan sonra henüz gelmez")
	race.load_state({"races": RaceManager.SHOWCASE_AFTER, "wins": 1})
	check(race.showcase_due(), "2 yarıştan sonra sıradaki rakip tanıtım")

	print("== 3. RAKİP: BEYAZ OVALE ÉCLAIR ==")
	check(await _challenge(race), "rakip geldi, davet açık")
	check(race.rival_id() == RaceManager.SHOWCASE_CAR and race.is_showcase(), "rakip %s" % race.rival_id())
	check(bool(race.rival_owner().get("featured", false)), "sahibi öne çıkan arkadaş (%s)" % race.rival_owner().get("name", ""))
	var look: CarAppearance = race.rival_appearance()
	check(look != null and look.body_color.is_equal_approx(RaceManager.SHOWCASE_COLOR), "beyaz")
	var challenger: TrafficVehicle = race.challenger()
	check(challenger != null and challenger.vehicle_id == RaceManager.SHOWCASE_CAR, "yoldan gelen araç da o")

	print("== EZİCİ FARK ==")
	hud.race_challenge_screen.race_accepted.emit()
	await create_timer(0.6).timeout
	check(router.top() == &"drag_race" and track._rival_id == RaceManager.SHOWCASE_CAR, "pistte rakip o")
	var recording: DragRaceSim.Recording = track.rival_recording()
	var mine: float = PerformanceMods.time_300(race.player_vehicle_id())
	check(recording != null and recording.time < mine * 0.75,
		"rakip kusursuz ve çok önde: %.2f sn (oyuncunun kusursuz süresi %.2f)" % [recording.time if recording else -1.0, mine])
	check(recording != null and recording.time <= DragRaceSim.base_time(RaceManager.SHOWCASE_CAR) + 0.25, "gün formu / ıskalama yok")
	var learn_before: Dictionary = race.learning().counts_state().duplicate(true)
	track.race_completed.emit(false, mine + 0.4, recording.time if recording else 7.0)
	await create_timer(0.5).timeout
	check(router.top() == &"race_result", "sonuç panosu")
	check(not result._rematch_button.visible and not race.can_rematch(), "rövanş yok")
	check(race.challenger() == null, "rakip yola döndü")
	check(race.showcase_done() and bool(race.state().get("showcase", false)), "tanıtım bir kez: kayıtta")
	check(int(race.history().back()["a"]) == -1, "geçmişte zorluk kolu yok (senaryolu)")
	check(race.learning().counts_state() == learn_before, "öğrenen zorluğa yazılmadı")

	print("== BİR GÜN SENİN DE OLACAK! ==")
	result.exit_requested.emit()
	await create_timer(0.8).timeout
	check(router.top() == &"supercar_tease" and tease.visible, "GARAJA DÖN → hedef ekranı")
	check(tease._name.text.contains("ÉCLAIR"), "araç adı: %s" % tease._name.text)
	check(tease._chips.get_child_count() == 3, "BG / 0-100 / son hız hapları")
	check(tease._source.visible and tease._source.text.contains(Loc.t("SÜPER KASA")),
		"nereden çıkar: %s" % tease._source.text)
	check(is_instance_valid(tease._pivot) and tease._pivot.get_child_count() >= 2, "döner tablada araç")
	check(not race.take_showcase_tease(), "ekran bir kez")
	tease._button.pressed.emit()
	await create_timer(0.6).timeout
	check(router.top() == &"" and not tease.visible and not is_instance_valid(tease._stage), "HEDEFİM BU! kapatır, sahne silinir")

	print("== SONRAKİ RAKİP NORMAL ==")
	check(not race.showcase_due(), "tanıtım bitti")
	check(await _challenge(race), "yeni rakip geldi")
	check(not race.is_showcase() and race.rival_id() != RaceManager.SHOWCASE_CAR, "normal rakip (%s)" % race.rival_id())
	var saved: Dictionary = race.state()
	race.release_challenger()
	race.load_state(saved)
	check(race.showcase_done() and not race.showcase_due(), "kayıttan geri yüklenince yine gelmez")

	print("== GERİ ÇEVRİLİRSE YİNE GELİR / ESKİ OYUNCUYA GELMEZ ==")
	var traffic: TrafficManager = race.get("_traffic")
	if is_instance_valid(challenger):
		traffic.call("_on_vehicle_despawn", challenger)   # tanıtım yarışının aracı şehirden çıktı
	await frames(2)
	race.load_state({"races": RaceManager.SHOWCASE_AFTER})
	check(await _challenge(race), "rakip geldi")
	check(race.is_showcase(), "tanıtım rakibi")
	var declined: TrafficVehicle = race.challenger()
	race.release_challenger()   # oyuncu ilgilenmedi: araç şehre karışır (bir modelden tek araç: o çıkana dek gelmez)
	if is_instance_valid(declined):
		traffic.call("_on_vehicle_despawn", declined)   # şehirden çıktı
	await frames(2)
	check(await _challenge(race), "sıradaki rakip geldi")
	check(race.is_showcase() and race.rival_id() == RaceManager.SHOWCASE_CAR, "yine tanıtım rakibi")
	race.release_challenger()
	race.load_state({"races": RaceManager.SHOWCASE_UNTIL + 2, "wins": 5})
	check(not race.showcase_due(), "eski oyuncuya gelmez")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
