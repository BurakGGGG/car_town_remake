extends SceneTree
## HURDALIK / RESTORASYON TESTİ — parça envanteri, proje tamir alanını kaplar, envanterden takma,
## gemle eksik alma, bitirme / bırakma, usta kademesinin açılması, kayıt (diske + yeniden yükleme),
## bozuk kayıt temizliği, yeni oyun.
## Restorasyon modelleri henüz olmadığı için mevcut araçlarla kurulan tests/fixtures/restorations_test.json
## kullanılır; gerçek katalog yalnızca 1. bölümde (yapı) denetlenir.
## Çalıştırma: tools/run_tests.sh junkyard_test   (yalıtılmış user dizini)
const FIXTURE: String = "res://tests/fixtures/restorations_test.json"

var fails: int = 0
var main: Node


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func load_main() -> Node:
	var node: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await frames(10)
	return node


func reload() -> void:
	if main:
		main.free()
	await frames(4)
	main = await load_main()
	await create_timer(1.2).timeout


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))

	print("== 1) GERÇEK KATALOG ==")
	check(RestorationCatalog.load_from(), "vehicles/restorations.json okundu")
	check(RestorationCatalog.parts().size() == 9 and RestorationCatalog.tiers().size() == 3, "9 parça türü, 3 kademe")
	check(RestorationCatalog.all_planned().size() == 28, "28 plan aracı (12 temel + 8 klasik + 8 yarış)")
	check(RestorationCatalog.total_required(&"tofas_murat_124") == 6, "ilk temel araç 6 parça (orijinal Fiat 500: 6×1)")
	check(RestorationCatalog.total_required(&"lamborghini_miura") == 78, "klasiğin sonuncusu 78 parça (orijinal XJ220: 78)")
	check(RestorationCatalog.tier_requirement(&"classic") == 10 and RestorationCatalog.tier_requirement(&"race") == 10, "usta kademeleri 10 temel restorasyonla açılır")
	for entry: Dictionary in RestorationCatalog.all_planned():
		if RestorationCatalog.has_model(entry["id"]):
			continue
		check(RestorationCatalog.cars().all(func(e: Dictionary) -> bool: return e["id"] != entry["id"]), "%s modeli yok → oyunda görünmez" % entry["id"])
		break

	print("== 2) İLK AÇILIŞ ==")
	await reload()
	var jy: JunkyardManager = g(&"junkyard")
	var rm: RepairManager = g(&"repair_manager")
	var bays: RepairBayManager = g(&"repair_bays")
	var pp: PlayerProgress = g(&"player_progress")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var save: SaveManager = g(&"save_manager")
	check(jy != null and rm != null and bays != null, "JunkyardManager kodla kuruldu")
	check(jy.total_parts() == 0 and jy.project_count() == 0, "yeni oyunda envanter boş, proje yok")
	check(jy.status(&"lancia_delta_integrale") == JunkyardManager.Status.TIER_LOCKED, "yarış dalının son aracı: modeli var, kademe kilitli")
	check(jy.status(&"tofas_murat_124") == JunkyardManager.Status.AVAILABLE, "modeli gelen temel araç: AVAILABLE")
	check(RestorationCatalog.cars().size() == 28, "28 restorasyon aracının hepsinin modeli hazır")
	check(not VehicleOwnership.is_paintable(&"tofas_murat_124") and VehicleOwnership.is_paintable(&"tofas_sahin"), "restorasyon aracı boyanamaz, kasa aracı boyanır")
	# 2026-10-20: sekizinci parti (15 araç) koleksiyonu 29 → 44 yaptı
	check(VehicleOwnership.collection_ids().size() == 44 and not VehicleOwnership.collection_ids().has(&"anadol_a1") \
		and VehicleOwnership.collection_ids().has(&"vw_beetle") and VehicleOwnership.collection_ids().has(&"togg_t10f")
		and not VehicleOwnership.collection_ids().has(&"police_bentley"),
		"kasa koleksiyonu 44 araç (Beetle ve Togg'lar dahil), restorasyon ve polis hariç")
	check(RaceManager.rival_pool(&"tofas_sahin").all(func(id: StringName) -> bool: return not RestorationCatalog.is_restoration(id)), "restorasyon aracı yarış rakibi olmaz")
	save.save_game()
	check(disk().has("junkyard"), "kayıtta junkyard bölümü var")

	print("== 3) TEST KATALOĞU, PROJE ALANI KAPLAR ==")
	check(RestorationCatalog.load_from(FIXTURE), "test kataloğu yüklendi")
	check(RestorationCatalog.total_required(&"hyundai_getz") == 4, "reçetedeki bilinmeyen parça atlandı")
	check(RestorationCatalog.cars().size() == 3, "modeli olmayan plan aracı listede yok")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.AVAILABLE, "temel araç başlatılabilir")
	check(jy.status(&"mercedes_cls") == JunkyardManager.Status.TIER_LOCKED, "usta aracı kilitli")
	check(not jy.start(&"mercedes_cls"), "kilitli kademedeki araç başlamaz")
	bays.load_state(1)
	check(rm.free_bay() == 0 and not rm.is_busy(), "tek alan açık ve boş")
	var started: Array = []
	jy.project_started.connect(func(id: StringName, bay: int) -> void: started.append([id, bay]))
	check(jy.start(&"opel_corsa"), "Corsa restorasyonu başladı")
	check(started == [[&"opel_corsa", 0]] and jy.bay_of(&"opel_corsa") == 0, "proje 0. tamir alanında")
	check(rm.free_bay() == -1 and rm.is_busy() and not rm.is_bay_free(0), "alan dolu: müşteri gönderilmez")
	check(not jy.start(&"opel_corsa"), "aynı araç ikinci kez başlamaz")
	check(not jy.start(&"hyundai_getz"), "boş alan yokken ikinci proje başlamaz")
	bays.load_state(2)
	check(rm.free_bay() == 1 and not rm.is_busy(), "ikinci alan açılınca boş")
	check(jy.start(&"hyundai_getz") and jy.bay_of(&"hyundai_getz") == 1, "Getz 1. alanda")
	check(not jy.start(&"no_model_car"), "modeli olmayan araç başlamaz")

	print("== 4) ENVANTER VE TAKMA ==")
	check(jy.install(&"opel_corsa", &"bolt") == 0, "envanter boşken takılmaz")
	check(not jy.add_parts(&"made_up", 3) and not jy.add_parts(&"bolt", 0), "bilinmeyen parça / 0 adet eklenmez")
	var gained: Array = []
	jy.parts_gained.connect(func(id: StringName, n: int, src: StringName) -> void: gained.append([id, n, src]))
	check(jy.add_parts(&"bolt", 3, &"pile"), "3 civata hurda yığınından")
	check(gained == [[&"bolt", 3, &"pile"]], "parts_gained kaynağıyla geldi")
	check(jy.install(&"opel_corsa", &"bolt") == 1 and jy.part_count(&"bolt") == 2, "Corsa'ya 1 civata (gereken kadar) takıldı, 2 kaldı")
	check(is_equal_approx(jy.progress(&"opel_corsa"), 0.25), "ilerleme %25 (1 / 4)")
	check(jy.install(&"opel_corsa", &"bolt") == 0, "tamamlanmış parça yeniden takılmaz")

	print("== 5) GEMLE EKSİK ==")
	pp.load_state(pp.level, pp.xp, 0)
	check(jy.missing_gem_cost(&"opel_corsa", &"nut") == 2, "1 somun = 2 gem")
	check(not jy.buy_missing(&"opel_corsa", &"nut") and jy.installed(&"opel_corsa", &"nut") == 0, "gem yokken alınmaz, hiçbir şey değişmez")
	pp.add_gems(100)
	check(jy.buy_missing(&"opel_corsa", &"nut") and pp.gems == 98, "somun gemle alındı (98 gem kaldı)")
	check(jy.all_missing_gem_cost(&"opel_corsa") == 6, "kalan eksik bedeli: piston 3 + dişli 3")
	check(jy.buy_all_missing(&"opel_corsa") and pp.gems == 92, "hepsini al tek ödeme: 6 gem")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.READY and is_equal_approx(jy.progress(&"opel_corsa"), 1.0), "Corsa %100: READY")
	jy.add_parts(&"piston", 1)   # Getz: 2 civata + 1 piston envanterden, 1 piston (3 gem) eksik
	pp.load_state(pp.level, pp.xp, 2)
	check(not jy.buy_all_missing(&"hyundai_getz") and pp.gems == 2, "gem yetmezse hiç gem harcanmaz")
	check(jy.installed(&"hyundai_getz", &"bolt") == 2 and jy.installed(&"hyundai_getz", &"piston") == 1, "...ama envanterdekiler takıldı")
	check(jy.part_count(&"bolt") == 0 and jy.part_count(&"piston") == 0, "envanter düştü")

	print("== 6) KAYIT VE YENİDEN YÜKLEME ==")
	jy.add_parts(&"gear", 7, &"repair")
	save.save_game()
	var data: Dictionary = disk().get("junkyard", {})
	check((data.get("projects", []) as Array).size() == 2 and int((data.get("parts", {}) as Dictionary).get("gear", 0)) == 7, "diskte 2 proje ve 7 dişli")
	await reload()
	jy = g(&"junkyard")
	rm = g(&"repair_manager")
	own = g(&"vehicle_ownership")
	pp = g(&"player_progress")
	save = g(&"save_manager")
	check(jy.project_count() == 2 and jy.bay_of(&"opel_corsa") == 0 and jy.bay_of(&"hyundai_getz") == 1, "projeler alanlarıyla geri geldi")
	check(jy.part_count(&"gear") == 7 and jy.installed(&"hyundai_getz", &"piston") == 1, "envanter ve takılı parçalar geri geldi")
	check(rm.is_busy() and rm.free_bay() == -1, "yüklemeden sonra da alanlar dolu")

	print("== 7) BİTİRME VE BIRAKMA ==")
	var done: Array = []
	jy.project_completed.connect(func(id: StringName) -> void: done.append(id))
	check(not jy.finish(&"hyundai_getz"), "eksik proje bitmez")
	check(jy.finish(&"opel_corsa") and done == [&"opel_corsa"], "Corsa bitti")
	check(own.is_owned(&"opel_corsa") and jy.is_completed(&"opel_corsa"), "Corsa garajda, tamamlananlarda")
	# Alan, garajdaki teslim töreni (RestorationFinale) bitene kadar dolu: müşteri aracı lifte girmesin
	var bays_node: RestorationBays = g(&"restoration_bays")
	check(jy.status(&"opel_corsa") == JunkyardManager.Status.COMPLETED and not rm.is_bay_free(0)
		and bays_node.is_celebrating(), "Corsa tamamlandı; teslim töreni sürerken 0. alan dolu")
	bays_node.skip_finales()
	await frames(2)
	check(rm.is_bay_free(0) and not bays_node.is_celebrating(), "tören bitince 0. alan boşaldı")
	check(not jy.start(&"opel_corsa"), "sahip olunan restorasyon aracı yeniden başlamaz")
	check(jy.quit(&"hyundai_getz") and rm.is_bay_free(1), "Getz bırakıldı, 1. alan boşaldı")
	check(jy.part_count(&"bolt") == 2 and jy.part_count(&"piston") == 1, "takılı parçalar envantere döndü")

	print("== 8) USTA KADEMESİ ==")
	var tiers: Array = []
	jy.tier_unlocked.connect(func(id: StringName) -> void: tiers.append(id))
	check(jy.start(&"hyundai_getz"), "Getz yeniden başladı")
	pp.add_gems(50)
	check(jy.buy_all_missing(&"hyundai_getz") and jy.finish(&"hyundai_getz"), "Getz bitti")
	check(jy.basic_completed_count() == 2 and tiers == [&"classic"], "2 temel → USTA · KLASİK açıldı (sinyal bir kez)")
	check(jy.status(&"mercedes_cls") == JunkyardManager.Status.AVAILABLE, "CLS artık başlatılabilir")
	check(own.sell_vehicle(&"opel_corsa") and jy.status(&"opel_corsa") == JunkyardManager.Status.AVAILABLE, "satılan restorasyon aracı yeniden restore edilebilir")
	check(jy.basic_completed_count() == 2, "...tamamlanan sayısı düşmez")

	print("== 9) BOZUK KAYIT ==")
	jy.load_state({
		"parts": {"bolt": -4, "gear": 99999999, "made_up": 5, "belt": "abc"},
		"completed": ["opel_corsa", "opel_corsa", "not_a_car"],
		"projects": [
			{"car": "mercedes_cls", "bay": 0, "installed": {"gear": 10, "belt": 2}},
			{"car": "hyundai_getz", "bay": 0, "installed": {"bolt": 2}},
			{"car": "ghost", "bay": 1, "installed": {"piston": 1}},
			"bozuk",
		],
	})
	check(jy.part_count(&"bolt") == 2 and jy.part_count(&"gear") == JunkyardManager.MAX_STACK, "negatif adet atıldı, aşırı adet sınıra çekildi; çakışan projenin civatası iade")
	check(jy.inventory().size() == 3 and jy.part_count(&"piston") == 1, "bilinmeyen parça atlandı, bilinmeyen araçlı projenin pistonu iade")
	check(jy.completed_ids() == [&"opel_corsa"], "tamamlananlar tekilleşti, bilinmeyen atıldı")
	check(jy.project_count() == 1 and jy.installed(&"mercedes_cls", &"gear") == 3 and jy.installed(&"mercedes_cls", &"belt") == 2, "tek geçerli proje; reçeteden fazla dişli kırpıldı")

	print("== 10) YENİ OYUN ==")
	save.new_game()
	jy = g(&"junkyard")
	check(jy.total_parts() == 0 and jy.project_count() == 0 and jy.completed_ids().is_empty(), "yeni oyun hurdalığı sıfırladı")
	check((disk().get("junkyard", {}) as Dictionary).get("projects", [1]).is_empty(), "diskteki kayıt da boş")

	print("== 11) SAHA: GÜNÜN ARAÇLARI ==")
	var gem: GemRewards = g(&"gem_rewards")
	var t0: int = 1_800_000_000
	gem.test_now = t0
	var yard: Array[StringName] = jy.yard_cars()
	check(yard.size() == 2 and yard.has(&"opel_corsa") and yard.has(&"hyundai_getz"),
		"sahada havuzun 2 temel aracı (usta kilitli, modelsiz yok)")
	check(jy.yard_cars() == yard, "aynı gün aynı araçlar")
	jy.load_state(jy.state())
	check(jy.yard_cars() == yard, "kayıttan yüklenince aynı saha (gün + tuz kayıtta)")
	var left: int = jy.seconds_to_yard_refresh()
	check(left > 0 and left <= 86400, "yenilenmeye kalan süre bir günü aşmaz (%d sn)" % left)
	check(jy.start(&"opel_corsa"), "sahadaki araç başlatıldı")
	var after: Array[StringName] = jy.yard_cars()
	check(after.size() == 2 and after[yard.find(&"opel_corsa")] == &"", "başlatılan araç sahadan kalktı, yeri boş")
	gem.test_now = t0 + 86400
	var only_getz: Array[StringName] = [&"hyundai_getz"]
	check(jy.yard_cars() == only_getz, "ertesi gün yeniden çekildi; projedeki araç havuzda yok")
	check(jy.quit(&"opel_corsa") and jy.yard_cars() == only_getz,
		"bırakılan araç aynı gün sahaya dönmez (çekiliş günde bir)")
	gem.test_now = t0 - 86400
	check(jy.yard_cars() == only_getz, "saat geri alınınca saha geri gitmez")

	print("== 12) SAHA: HURDA YIĞINLARI ==")
	gem.test_now = t0 + 86400
	var refill: int = RestorationCatalog.yard_int("refill_minutes") * 60
	check(jy.pile_count() == 6 and jy.ready_pile_count() == 6, "6 yığın, hepsi dolu")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var parts_before: int = jy.total_parts()
	var first: Dictionary = jy.search_pile(0, rng)
	check(first["ok"] and not (first["parts"] as Dictionary).is_empty(), "ilk arama her zaman dolu (Cemo'nun dersi)")
	var got: int = 0
	for n: Variant in (first["parts"] as Dictionary).values():
		got += int(n)
	check(jy.total_parts() == parts_before + got, "bulunanlar envantere girdi")
	check(not jy.pile_ready(0) and jy.pile_seconds_left(0) == refill, "aranan yığın dolma süresi kadar boş")
	check(not jy.search_pile(0, rng)["ok"], "boş yığın aranamaz")
	check(jy.next_pile_seconds() == refill and jy.ready_pile_count() == 5, "en yakın dolma süresi, 5 dolu yığın")
	var empty: int = 0
	var seen: Dictionary = {}
	var runs: int = 2000
	for k: int in runs:
		gem.test_now += refill
		var result: Dictionary = jy.search_pile(1, rng)
		if (result["parts"] as Dictionary).is_empty():
			empty += 1
		for part_id: StringName in result["parts"]:
			seen[part_id] = int(seen.get(part_id, 0)) + int(result["parts"][part_id])
	var rate: float = float(empty) / float(runs)
	check(absf(rate - RestorationCatalog.yard_rule("empty_chance")) < 0.04, "boş çıkma oranı kurala uyuyor (%.3f)" % rate)
	check(seen.keys().all(func(p: StringName) -> bool: return p in [&"bolt", &"nut", &"piston", &"gear"]),
		"yalnız açık kademenin reçete parçaları düştü %s" % [seen.keys()])
	check(seen.size() == 4, "açık kademenin her parçası düşebiliyor")
	jy.search_pile(2, rng)
	var searches: int = jy.search_count()
	var st: Dictionary = jy.state()
	jy.load_state(st)
	check(not jy.pile_ready(2) and jy.pile_ready(3) and jy.search_count() == searches, "yığın zamanlayıcıları kayıtta")
	(st["yard"] as Dictionary)["piles"] = [9_999_999_999, 0]
	jy.load_state(st)
	check(jy.pile_seconds_left(0) <= refill and jy.pile_ready(1), "bozuk kayıttan gelen ileri zaman süreyi aşamaz")
	print("== 12b) TAMİRDEN PARÇA DÜŞMESİ ==")
	var bay_manager: RepairBayManager = g(&"repair_bays")
	bay_manager.load_state(1)
	var drop_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	drop_rng.seed = 11
	var closed_drops: int = 0
	for k: int in 300:
		if jy.roll_repair_drop(drop_rng) != &"":
			closed_drops += 1
	check(not jy.is_open() and closed_drops == 0, "hurdalık kapalıyken tamirden parça düşmez")
	bay_manager.load_state(2)
	var drops: int = 0
	var before_parts: int = jy.total_parts()
	for k: int in 3000:
		if jy.roll_repair_drop(drop_rng) != &"":
			drops += 1
	var drop_rate: float = float(drops) / 3000.0
	check(jy.is_open() and absf(drop_rate - RestorationCatalog.yard_rule("repair_drop")) < 0.02,
		"hurdalık açıkken tamirde %%%d olasılıkla parça (%.3f)" % [int(RestorationCatalog.yard_rule("repair_drop") * 100), drop_rate])
	check(jy.total_parts() == before_parts + drops, "düşen parçalar envantere girdi")
	gem.test_now = -1

	print("== 13) HARİTA ROTASI ==")
	# Yolculuk animasyonu yolun ortasında donuyordu: kesik çizgi döngüsü kayan nokta hatasıyla bitmiyordu.
	var map_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MapScreen.MAP_DATA))
	var route: PackedVector2Array = PackedVector2Array()
	for p: Variant in map_data["route"]:
		route.append(Vector2(float(p[0]), float(p[1])) * Vector2(1152.0, 648.0))
	check(route.size() >= 4 and (map_data["places"] as Dictionary).has("junkyard"), "harita verisi: rota + mekânlar")
	var route_started: int = Time.get_ticks_msec()
	var monotonic: bool = true
	var previous: int = 0
	var end_head: Vector2 = Vector2.ZERO
	for dash: float in [6.0, 13.824, 7.3333333, 0.37, 41.0]:
		previous = 0
		for k: int in 3001:
			var drawn: Dictionary = MapScreen.dashes(route, float(k) / 3000.0, dash)
			var count: int = (drawn["spans"] as PackedVector2Array).size()
			if count < previous:
				monotonic = false
			previous = count
			end_head = drawn["head"]
	var elapsed: int = Time.get_ticks_msec() - route_started
	check(elapsed < 20000, "15.000 kare rota çizimi takılmadan bitti (%d ms)" % elapsed)
	check(monotonic, "ilerledikçe çizgi sayısı azalmıyor")
	check(end_head.distance_to(route[route.size() - 1]) < 0.01, "%100'de araç işareti yolun sonunda")
	var reversed_route: PackedVector2Array = route.duplicate()
	reversed_route.reverse()
	check((MapScreen.dashes(reversed_route, 1.0, 13.8)["head"] as Vector2).distance_to(route[0]) < 0.01, "ters yön (şehre dönüş) de sona varıyor")
	var pose: Dictionary = MapScreen.route_pose(route, 0.5)
	check((pose["head"] as Vector2).distance_to(route[0]) > 0.01 and (pose["direction"] as Vector2).length() > 0.99,
		"rota aracı ara noktada konum ve yön alıyor")
	var hud: Hud = main.find_child("HUD", true, false) as Hud
	var map: MapScreen = hud.map_screen if hud else null
	if map:
		map.open()
		await frames(2)
		(map.get("_route_layer") as Control).set("progress", 0.5)
		var traveller: Control = map.get("_traveller_marker") as Control
		check(is_instance_valid(map.get("_traveller_car")) and traveller.visible,
			"harita yolculuğunda seçili yarış aracı üstten görünüm olarak hazırlanıyor")
		# Şehirden hurdalığa rota batıya (ekranda sola) gider: 3B aracın önü (+Z) -X'e dönmüş olmalı
		var car: Node3D = map.get("_traveller_car") as Node3D
		check(is_instance_valid(car) and car.global_basis.z.x < -0.7,
			"yolculuk aracı 3B olarak gidiş yönüne dönüyor (ön: %s)" % (car.global_basis.z if is_instance_valid(car) else Vector3.ZERO))
		# YAKINDA mekânları (OTO ŞOV, LİMAN): simgesi var, altında YAKINDA, dokununca yolculuk başlamaz
		var pins: Dictionary = map.get("_pins")
		var hints: Dictionary = map.get("_hints")
		var soon_ok: bool = true
		for place: StringName in MapScreen.SOON:
			soon_ok = soon_ok and pins.has(place) and (hints[place] as Label).text == Loc.t("YAKINDA")
		check(soon_ok, "haritada YAKINDA mekânları: OTO ŞOV + LİMAN")
		(pins[&"port"] as PlateButton).pressed.emit()
		await frames(1)
		check(not map.get("_travelling") and (map.get("_card_label") as Label).text.contains(Loc.t("LİMAN")),
			"YAKINDA mekânına dokunmak yolculuk başlatmaz, kart yazar")
		map.close()
	else:
		check(false, "harita ekranı HUD'a bağlandı")

	print("== 13b) HURDALIK DÜNYASI: YIĞIN MERKEZLERİ ==")
	var yard_world: JunkyardWorld = JunkyardWorld.new()
	root.add_child(yard_world)
	await frames(2)
	# Blender'daki arama yığınları (junkyard.py search_piles) → Godot (x, 0, -y)
	var expected: Array[Vector2] = [Vector2(17, 26), Vector2(30, 33), Vector2(44, 34.5), Vector2(16, 9), Vector2(38.5, 30), Vector2(21, 37.5)]
	var near: bool = yard_world.piles.size() == expected.size()
	for i: int in mini(yard_world.piles.size(), expected.size()):
		var p: Vector3 = yard_world.pile_position(i)
		near = near and Vector2(p.x, -p.z).distance_to(expected[i]) < 2.5
	check(near, "her yığının seçim / sallanma merkezi kendi yerinde (eskiden hepsi sahne köşesindeydi)")
	check(yard_world.spots.size() == JunkyardWorld.DAILY_COUNT, "günün araçları için 3 yer")
	yard_world.show_player_car(RaceManager.FALLBACK_VEHICLE)
	var parked: Node3D = yard_world.player_car()
	var parked_model: Node3D = parked.get_child(0) as Node3D if parked and parked.get_child_count() > 0 else null
	# Kapı: doğu çiti Blender X 64, Y 16–26 → araç çitin DIŞINDA (x > 64), kapı aralığının hizasında
	check(parked != null and parked.global_position.x > 66.0 and absf(-parked.global_position.z - 21.0) < 5.0,
		"oyuncunun aracı kapının önünde park etti")
	# Önü (+Z) batıya (kapıya) bakar ama tam dik değil: çapraz
	var nose: Vector3 = parked_model.global_basis.z.normalized() if parked_model else Vector3.ZERO
	check(nose.x < -0.7 and absf(nose.z) > 0.25, "araç kapıya çapraz dönük (ön: %s)" % nose)

	print("== 13c) RESTORASYON ÇEKME SAHNESİ ==")
	# Yol, her hurda yeri için: engellere (lamba, varil, lastik, Cemo...) ve hurdalara çarpmaz.
	# Araç yarı genişliği 1 m + pay; hurdalar 2,2 × 4,2 m, burnu güneye.
	var hits: PackedStringArray = PackedStringArray()
	var spots_xy: Array[Vector2] = []
	for i: int in yard_world.spots.size():
		spots_xy.append(yard_world.spot_blender(i))
	for i: int in spots_xy.size():
		var routes: Dictionary = {"giriş": JunkyardTow.entry_route(JunkyardWorld.PLAYER_CAR_SPOT, spots_xy[i]),
			"çıkış": JunkyardTow.exit_route(spots_xy[i])}
		for route_name: String in routes:
			for p: Vector2 in JunkyardTow.sample_points(routes[route_name]):
				for o: Vector3 in JunkyardTow.OBSTACLES:
					if p.distance_to(Vector2(o.x, o.y)) < o.z + 1.2:
						hits.append("yer %d %s: %s engel %s" % [i, route_name, p, o])
				for k: int in spots_xy.size():
					if route_name == "çıkış" and k == i:
						continue   # çekilen hurda yerinde değil
					if absf(p.x - spots_xy[k].x) < 1.1 + 1.1 and absf(p.y - spots_xy[k].y) < 2.1 + 1.1:
						hits.append("yer %d %s: %s hurda %d" % [i, route_name, p, k])
	check(hits.is_empty(), "çekme yolu engellere ve hurdalara çarpmıyor %s" % (hits.slice(0, 3) if not hits.is_empty() else ""))
	# Sahne oynar: araç hurdaya gider, halat, çekip çıkar; sonunda hurda kalkar, araç kapıya döner
	yard_world.show_daily([&"anadol_a1", &"anadol_a1", &"anadol_a1"] as Array[StringName])
	var towed: Node3D = yard_world.take_daily(1)
	check(towed != null and yard_world.daily_ids()[1] == &"", "hurda sahneye devredildi, saha yeri boş")
	var tow: JunkyardTow = JunkyardTow.new()
	tow.setup(yard_world, towed, yard_world.spot_blender(1), 6.0)
	var tow_state: Dictionary = {"hitched": false, "done": false}
	tow.hitched.connect(func() -> void: tow_state["hitched"] = true)
	tow.finished.connect(func() -> void: tow_state["done"] = true)
	yard_world.add_child(tow)
	tow.play()
	for k: int in 600:
		if tow_state["done"]:
			break
		await process_frame
	await frames(2)
	check(tow_state["hitched"] and tow_state["done"], "çekme sahnesi halatla bağlandı ve bitti")
	check(not is_instance_valid(towed), "çekilen hurda sahneden kalktı")
	check(parked.global_position.distance_to(JunkyardWorld.blender(JunkyardWorld.PLAYER_CAR_SPOT.x,
		JunkyardWorld.PLAYER_CAR_SPOT.y, 0.0)) < 0.01, "oyuncunun aracı kapıdaki yerine döndü")
	# Dokununca atlanır: aynı bitiş (hurda kalkar, araç yerinde)
	var skipped: Node3D = yard_world.take_daily(2)
	var tow_skip: JunkyardTow = JunkyardTow.new()
	tow_skip.setup(yard_world, skipped, yard_world.spot_blender(2))
	var skip_state: Dictionary = {"done": false}
	tow_skip.finished.connect(func() -> void: skip_state["done"] = true)
	yard_world.add_child(tow_skip)
	tow_skip.play()
	await frames(20)
	tow_skip.skip()
	await frames(2)
	check(skip_state["done"] and not is_instance_valid(skipped) and parked.global_position.distance_to(
		JunkyardWorld.blender(JunkyardWorld.PLAYER_CAR_SPOT.x, JunkyardWorld.PLAYER_CAR_SPOT.y, 0.0)) < 0.01,
		"sahne atlanınca da hurda kalkar, araç yerine döner")
	yard_world.free()

	print("== 14) GARAJDA PROJE: 3 AŞAMA + PANO ==")
	var restoration_bays: RestorationBays = g(&"restoration_bays")
	check(restoration_bays != null, "RestorationBays kodla kuruldu")
	jy.reset()
	for p: StringName in [&"bolt", &"nut", &"piston", &"gear"]:
		jy.add_parts(p, 1, &"debug")
	check(jy.start(&"opel_corsa"), "proje başladı")
	await frames(3)
	var display: RestorationDisplay = restoration_bays.display_of(&"opel_corsa")
	check(display != null and display.is_inside_tree(), "projenin görünümü tamir alanında kuruldu")
	if display:
		check(display.get_parent() == rm.repair_car_spots[jy.bay_of(&"opel_corsa")], "görünüm alanın (CarSpot) çocuğu: alan taşınınca birlikte gider")
		check(display.stage == 0 and display.chassis != null and display.chassis.visible and not display.model.visible, "%0: yalnız çıplak şasi")
		jy.install(&"opel_corsa", &"bolt")
		jy.install(&"opel_corsa", &"nut")
		check(display.stage == 1 and display.model.visible and display.chassis.visible, "%50: araç şasinin üstünde")
		var overlay: bool = false
		for node: Node in display.model.find_children("*", "MeshInstance3D", true, false):
			overlay = overlay or (node as MeshInstance3D).material_overlay != null
		check(overlay, "%50: pas katmanı takılı")
		var wheels_hidden: bool = true
		for role: StringName in [&"tires", &"rims", &"wheels"]:
			for mesh: MeshInstance3D in display.rig.get_meshes(role):
				wheels_hidden = wheels_hidden and not mesh.visible
		check(wheels_hidden, "%50: tekerlekler gizli")
	var hud_node: Hud = main.find_child("HUD", true, false) as Hud
	hud_node.restoration_panel.vehicle_id = &"opel_corsa"
	hud_node.router.open(&"restoration")
	await frames(3)
	var rows: VBoxContainer = hud_node.restoration_panel.get("_rows")
	check(rows.get_child_count() == RestorationCatalog.recipe(&"opel_corsa").size(), "panoda reçete satırları")
	check(not (hud_node.restoration_panel.get("_install_all") as PlateButton).disabled, "HEPSİNİ TAK açık (envanterde parça var)")
	jy.install_all(&"opel_corsa")
	await frames(2)
	if display:
		check(display.stage == 2 and display.model.visible and not display.chassis.visible, "%100: temiz araç, şasi gizli")
		var overlay_left: bool = false
		for node: Node in display.model.find_children("*", "MeshInstance3D", true, false):
			overlay_left = overlay_left or (node as MeshInstance3D).material_overlay != null
		check(not overlay_left, "%100: pas katmanı kalktı")
	check((hud_node.restoration_panel.get("_finish") as PlateButton).visible, "panoda BİTİR göründü")
	var finished_bay: int = jy.bay_of(&"opel_corsa")
	hud_node.restoration_panel.call("_on_finish")
	await frames(3)
	# Kayıt hemen: araç garajda. Görünüm teslim törenine devredilir, alan tören bitene kadar dolu
	check(jy.is_completed(&"opel_corsa") and own.is_owned(&"opel_corsa"), "BİTİR: araç garaja girdi (kayıt hemen)")
	check(restoration_bays.display_of(&"opel_corsa") == null and restoration_bays.is_celebrating(),
		"teslim töreni başladı (görünüm projeden törene geçti)")
	check(not rm.is_bay_free(finished_bay), "tören sürerken alana müşteri girmez")
	check(display != null and is_instance_valid(display) and display.is_inside_tree(), "araç törende liftte duruyor")
	var waited: int = 0
	while not hud_node.restoration_result.visible and waited < 600:
		await process_frame
		waited += 1
	check(hud_node.restoration_result.visible and hud_node.restoration_result.vehicle_id == &"opel_corsa",
		"efektler bitti: sonuç plakası (%d kare)" % waited)
	hud_node.restoration_result.confirm()
	waited = 0
	while restoration_bays.is_celebrating() and waited < 600:
		await process_frame
		waited += 1
	await frames(2)
	check(not restoration_bays.is_celebrating() and not is_instance_valid(display), "GARAJA AL: araç alandan çıktı")
	check(rm.is_bay_free(finished_bay), "tören bitti, alan boşaldı")
	hud_node.router.close_all()

	print("== 15) HURDALIK EKRANI + MÜZİK ==")
	var music: GameMusic = root.get_node_or_null(GameMusic.NODE_NAME) as GameMusic
	hud_node.router.open(&"junkyard")
	await frames(5)
	check(hud_node.junkyard_screen.world() != null and hud_node.junkyard_screen.world().spots.size() == 3,
		"hurdalık ekranı dünyayı kurdu")
	var yard_theme: AudioStreamPlayer = music.get_node_or_null("JunkyardTheme") as AudioStreamPlayer if music else null
	check(yard_theme != null and yard_theme.playing, "hurdalıkta hurdalık teması çalıyor")
	hud_node.router.close_all()
	await create_timer(1.6).timeout
	check(hud_node.junkyard_screen.world() == null, "kapanınca hurdalık dünyası bellekten silindi")
	check(yard_theme != null and not yard_theme.playing and not music.stream_paused, "çıkınca garaj teması geri geldi")

	RestorationCatalog.load_from()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
