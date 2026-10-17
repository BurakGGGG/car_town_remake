extends SceneTree
## PERFORMANS MODİFİYESİ TESTİ — model (59 araç × 6 kategori × 5 kademe: hiçbir parça 300 m'yi uzatmaz, sınıf en
## fazla bir basamak atlar, gösterge kötüleşmez, profil adları), yarış (oyuncu modifiyeli / rakip fabrika, rakip
## havuzu modifiyeli süreyle, GENEL tavansız), yönetici (seviye kilidi, para, tamir alanını kaplama, süre,
## HAZIR → takma, kayıt + yeniden yükleme, satışta silinme, bozuk kayıt, yeni oyun).
## Çalıştırma: tools/run_tests.sh performance_mod_test   (yalıtılmış user dizini)

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
	PerformanceMods.clear()

	print("== 1) MODEL: BÜTÜN ARAÇLAR ==")
	var worse_300: int = 0
	var jumps: Dictionary = {}
	var two_step: int = 0
	var price_bad: int = 0
	var hp_missing: int = 0
	var invisible: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		if int(entry.get("performance", {}).get("hp", 0)) <= 0:
			hp_missing += 1
		for category: StringName in PerformanceMods.CATEGORIES:
			# Her kademe ekranda en az bir değeri görünür iyileştirir (0-100 / 300 m iki ondalık, son hız, beygir)
			var shown: Dictionary = PerformanceMods.stats_with(id, {})
			for stage: int in range(1, PerformanceMods.STAGES + 1):
				var next: Dictionary = PerformanceMods.stats_with(id, {category: stage}, float(shown["zero_100_ratio"]))
				if "%.2f" % float(shown["zero_100"]) == "%.2f" % float(next["zero_100"]) \
						and "%.2f" % float(shown["time_300"]) == "%.2f" % float(next["time_300"]) \
						and roundi(float(shown["top_speed"])) == roundi(float(next["top_speed"])) \
						and roundi(float(shown["hp"])) == roundi(float(next["hp"])):
					invisible += 1
					print("    görünmez: %s %s %d" % [id, category, stage])
				shown = next
			var previous: float = PerformanceMods.measure(id, {})["t300"]
			var previous_price: int = 0
			for stage: int in range(1, PerformanceMods.STAGES + 1):
				var t: float = PerformanceMods.measure(id, {category: stage})["t300"]
				if t > previous + 0.0001:
					worse_300 += 1
					print("    %s %s %d: %.3f > %.3f" % [id, category, stage, t, previous])
				previous = t
				var p: int = PerformanceMods.price(id, category, stage)
				if p <= previous_price or p % 50 != 0:
					price_bad += 1
				previous_price = p
		var full: Dictionary = {}
		for category: StringName in PerformanceMods.CATEGORIES:
			full[category] = PerformanceMods.STAGES
		var own: String = String(entry.get("class", "D"))
		var reached: String = PerformanceMods.class_for(id, PerformanceMods.measure(id, full)["t300"])
		var steps: int = PerformanceMods.CLASSES.find(own) - PerformanceMods.CLASSES.find(reached)
		if steps >= 2:
			two_step += 1
		if steps == 1:
			jumps[id] = reached
		# Fabrika aracın sınıfı kuralla aynı (bantlar ayrık)
		if PerformanceMods.class_for(id, DragRaceSim.base_time(id)) != own:
			check(false, "%s fabrika sınıfı kuralla aynı" % id)
	check(worse_300 == 0, "59 araç × 30 kademe: hiçbir parça 300 m süresini uzatmıyor")
	check(two_step == 0, "full yükseltmeyle hiçbir araç iki sınıf atlamıyor")
	check(jumps.size() == 22, "full yükseltmeyle 22 araç bir üst sınıfa çıkıyor (%d)" % jumps.size())
	check(price_bad == 0, "fiyatlar kademe kademe artıyor, 50 ₺'ye yuvarlı")
	check(invisible == 0, "her araçta her kademe ekranda en az bir değeri görünür iyileştiriyor")
	check(hp_missing == 0, "bütün araçların beygiri katalogda (gösterge)")

	print("== 2) MODEL: ÖRNEK ARAÇLAR ==")
	var passat: StringName = &"vw_passat_b55"
	var p1: Dictionary = PerformanceMods.stats_with(passat, {&"motor": 1})
	check(absf(float(p1["zero_100"]) - 9.72) < 0.02, "Passat MOTOR · Stage 1 Yazılım: 9,9 → %.2f sn" % p1["zero_100"])
	check(roundi(float(p1["hp"])) == 132, "Passat MOTOR SOKAK 130 → 132 bg")
	var pg: Dictionary = PerformanceMods.stats_with(passat, {&"gear": 5})
	check(roundi(float(pg["top_speed"])) == 218, "Passat ŞANZIMAN EFSANE son hız 208 → 218")
	var pfull: Dictionary = PerformanceMods.stats_with(passat, {&"motor": 5, &"turbo": 5, &"air": 5, &"gear": 5,
		&"tire": 5, &"body": 5})
	check(String(pfull["class"]) == "B" and absf(float(pfull["zero_100"]) - 7.73) < 0.03,
		"Passat FULL: B sınıfı, 0-100 %.2f" % pfull["zero_100"])
	var golf: Dictionary = PerformanceMods.stats_with(&"vw_golf_7", {&"tire": 2})
	check(float(golf["zero_100"]) < 7.5, "Golf 7 SPOR lastik patinajı bitiriyor: 8,2 → %.2f" % golf["zero_100"])
	var hurfull: Dictionary = PerformanceMods.stats_with(&"lambo_huracan", {&"motor": 5, &"turbo": 5, &"air": 5,
		&"gear": 5, &"tire": 5, &"body": 5})
	check(int(hurfull["overall"]) > 1000, "GENEL tavansız: full Huracán %d" % hurfull["overall"])
	check(DragRaceSim.overall_of(&"lambo_huracan") <= 1000, "fabrika Huracán 1000'in altında")
	check(PerformanceMods.profile_of(&"ford_mustang_1967") == &"klasik"
		and PerformanceMods.category_name(&"ford_mustang_1967", &"turbo") == "KOMPRESÖR", "klasikte TURBO → KOMPRESÖR")
	check(PerformanceMods.category_name(&"tesla_model_y", &"air") == "SOĞUTMA"
		and PerformanceMods.part_name(&"tesla_model_y", &"turbo", 5) == "Yarış Bataryası", "elektrikte BATARYA / SOĞUTMA")
	check(PerformanceMods.part_name(passat, &"motor", 1) == "Stage 1 Yazılım"
		and PerformanceMods.part_name(passat, &"tire", 5) == "Karbon Jant & Pro Drag Slik", "parça adları")
	check(PerformanceMods.profile_of(passat) == &"turbo_dizel" and PerformanceMods.profile_of(&"tofas_sahin") == &"atmosferik"
		and PerformanceMods.profile_of(&"mercedes_w123") == &"dizel", "motor profilleri")
	check(PerformanceMods.price(passat, &"motor", 1) == 900 and PerformanceMods.price(&"tofas_sahin", &"motor", 1) == 500,
		"fiyat: Passat SOKAK MOTOR 900 ₺, Şahin 500 ₺ (taban)")

	print("== 3) GÖSTERGE KÖTÜLEŞMEZ ==")
	PerformanceMods.set_build(&"chevrolet_camaro", {})
	var camaro_before: float = PerformanceMods.stats(&"chevrolet_camaro")["zero_100"]
	PerformanceMods.set_build(&"chevrolet_camaro", {})
	var cam_pre: Dictionary = PerformanceMods.preview(&"chevrolet_camaro", &"motor")
	check(float(cam_pre["zero_100"]) <= camaro_before + 0.00001, "Camaro MOTOR önizlemesi 0-100'ü kötüleştirmiyor")
	check(float(cam_pre["hp"]) > 432.0, "... ama beygiri artırıyor (%.0f)" % cam_pre["hp"])
	PerformanceMods.clear()

	print("== 4) YARIŞ: OYUNCU MODİFİYELİ, RAKİP FABRİKA ==")
	var stock_pool: Array[StringName] = RaceManager.rival_pool(passat)
	PerformanceMods.set_build(passat, pfull_build())
	check(PerformanceMods.spec_for(passat) != DragRaceSim.spec_of(passat), "oyuncunun künyesi modifiyeli")
	check(is_equal_approx(DragRaceSim.spec_of(passat).shift_time_scale, 1.0), "rakip Passat fabrika künyesinde")
	check(is_equal_approx(PerformanceMods.spec_for(passat).shift_time_scale, PerformanceMods.GEAR_SHIFT[5]),
		"sıralı şanzıman vites geçişini kısaltıyor")
	var run: DragRaceSim.Runner = DragRaceSim.Runner.new()
	run.setup_spec(PerformanceMods.spec_for(passat), null)
	check(run.spec.peak_torque_nm > DragRaceSim.spec_of(passat).peak_torque_nm, "yarış koşucusu modifiyeli torkla kuruluyor")
	var mod_pool: Array[StringName] = RaceManager.rival_pool(passat)
	var b_rivals: int = 0
	for id: StringName in mod_pool:
		if String(CarCatalog.get_entry(id).get("class", "")) == "B":
			b_rivals += 1
	check(not stock_pool.has(&"seat_leon") and b_rivals > 0, "full Passat B sınıfı rakiplerle eşleşiyor (%d)" % b_rivals)
	check(PerformanceMods.overall(passat) > DragRaceSim.overall_of(passat), "GENEL puan modifiyeyle artıyor")
	check(PerformanceMods.performance_ratio(passat) > DragRaceSim.performance_ratio(passat), "yarış sunumu (alev / ses) güçleniyor")
	PerformanceMods.clear()

	print("== 5) YÖNETİCİ ==")
	await reload()
	var mods: PerformanceModManager = g(&"performance_mods")
	var view: PerformanceBays = g(&"performance_bays")
	var rm: RepairManager = g(&"repair_manager")
	var pp: PlayerProgress = g(&"player_progress")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var eco: EconomyManager = g(&"economy")
	var save: SaveManager = g(&"save_manager")
	check(mods != null and view != null, "PerformanceModManager + görünüm kodla kuruldu")
	var sahin: StringName = &"tofas_sahin"
	if not own.is_owned(sahin):
		own.add_vehicle(sahin)   # yeni oyunda araç HOŞ GELDİN KUTUSU'ndan çıkar; test kutuyu açmadan ekler
	check(own.is_owned(sahin), "başlangıç aracı Şahin")
	pp.level = 1
	check(mods.status(sahin, &"motor") == PerformanceModManager.Status.NEEDS_LEVEL, "seviye 1'de SOKAK kilitli (seviye 3)")
	pp.level = 3
	eco.set_money(100)
	check(mods.status(sahin, &"motor") == PerformanceModManager.Status.TOO_EXPENSIVE, "para yetmiyor")
	check(not mods.purchase(sahin, &"motor") and eco.money == 100, "alınamayan parça para düşürmüyor")
	eco.set_money(50000)
	var free_before: int = rm.free_bay()
	check(mods.purchase(sahin, &"motor"), "SOKAK MOTOR alındı")
	check(eco.money == 50000 - 500, "500 ₺ düştü")
	check(mods.has_job(sahin) and mods.stage_of(sahin, &"motor") == 0, "takma sürüyor, parça henüz takılı değil")
	var bay: int = int(mods.job_of(sahin)["bay"])
	check(bay == free_before and not rm.is_bay_free(bay), "tamir alanını kaplıyor (alan %d)" % bay)
	check(absf(mods.remaining(sahin) - PerformanceMods.install_time(1)) < 2.0, "süre 2 dk")
	check(mods.status(sahin, &"turbo") == PerformanceModManager.Status.INSTALLING, "aynı araca ikinci parça aynı anda takılmaz")
	await frames(3)
	check(view.display_of(sahin) != null and view.display_of(sahin).bay == bay, "araç alanın liftinde görünüyor")
	check(not mods.collect(sahin), "süre dolmadan takılamaz")
	save.save_game()
	var data: Dictionary = disk()
	check((data.get("performance", {}).get("jobs", []) as Array).size() == 1, "süren takma kayıtta")

	print("== 6) KAYIT: SÜREN TAKMA YENİDEN YÜKLENİR ==")
	await reload()
	mods = g(&"performance_mods")
	rm = g(&"repair_manager")
	view = g(&"performance_bays")
	save = g(&"save_manager")
	check(mods.has_job(sahin) and int(mods.job_of(sahin)["bay"]) == bay, "takma yeniden yüklendi, aynı alanda")
	check(not rm.is_bay_free(bay), "alan hâlâ dolu")
	check(view.display_of(sahin) != null, "görünüm yeniden kuruldu")
	mods.finish_now(sahin)
	await frames(2)
	check(mods.is_ready(sahin), "süre doldu: HAZIR")
	var completed: Array = []
	mods.install_completed.connect(func(id: StringName, c: StringName, s: int, o: String, n: String) -> void:
		completed.append([id, c, s, o, n]))
	check(mods.collect(sahin), "dokununca takıldı")
	check(mods.stage_of(sahin, &"motor") == 1 and PerformanceMods.stage_of(sahin, &"motor") == 1, "yapı: MOTOR SOKAK")
	check(completed.size() == 1 and completed[0][3] == "D" and completed[0][4] == "D", "sınıf D'de kaldı")
	check(absf(float(PerformanceMods.stats(sahin)["zero_100"]) - 13.04) < 0.03,
		"Şahin 0-100 13,2 → %.2f" % PerformanceMods.stats(sahin)["zero_100"])
	await create_timer(1.6).timeout
	check(rm.is_bay_free(bay) and view.display_of(sahin) == null, "araç alandan çıktı, alan boşaldı")
	save.save_game()
	data = disk()
	check(int(data["performance"]["builds"]["tofas_sahin"]["motor"]) == 1, "yapı kayıtta")

	print("== 7) KAYIT: YAPI YENİDEN YÜKLENİR, YARIŞ OKUR ==")
	await reload()
	mods = g(&"performance_mods")
	check(mods.stage_of(sahin, &"motor") == 1 and PerformanceMods.is_modified(sahin), "yapı yeniden yüklendi")
	check(PerformanceMods.time_300(sahin) < DragRaceSim.base_time(sahin), "oyuncu Şahin'in 300 m süresi kısaldı")

	print("== 8) SATIŞTA SİLİNİR (PARA DÖNMEZ) ==")
	own = g(&"vehicle_ownership")
	eco = g(&"economy")
	pp = g(&"player_progress")
	save = g(&"save_manager")
	pp.level = 20
	eco.set_money(500000)
	own.add_vehicle(passat)
	check(mods.purchase(passat, &"turbo"), "Passat'a TURBO alındı")
	await frames(2)
	mods.finish_now(passat)
	mods.collect(passat)
	check(mods.status(passat, &"turbo") == PerformanceModManager.Status.NO_BAY, "araç alandan çıkarken alan dolu")
	await create_timer(1.6).timeout
	check(mods.purchase(passat, &"turbo"), "TURBO SPOR alındı (süren takma)")
	var money_before_sale: int = eco.money
	check(own.sell_vehicle(passat), "Passat satıldı")
	check(not PerformanceMods.is_modified(passat) and not mods.has_job(passat), "yapı ve süren takma silindi")
	check(eco.money == money_before_sale + own.sell_price(passat), "yalnızca araç parası geldi (parça parası dönmez)")

	print("== 9) ARAÇLAR → MODİFİYE → YÜKSELT ==")
	var hud: Node = main.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	var garage: GarageScreen = hud.get("garage_screen")
	own.add_vehicle(passat)
	await create_timer(1.6).timeout   # önceki takmanın aracı alandan çıksın
	router.open(&"garage")
	await frames(30)
	garage.call(&"_on_vehicle_selected", passat)
	await frames(10)
	garage.open_mods()
	await frames(5)
	check(garage.is_modding(), "MODİFİYE kipi açıldı")
	var cards: int = 0
	for c: StringName in PerformanceMods.CATEGORIES:
		var card: PlateButton = garage.find_child("Part_%s" % c, true, false)
		if card and card.is_visible_in_tree() and (card.get_node("Icon") as TextureRect).texture != null:
			cards += 1
	check(cards == 6, "altta 6 parça kartı, hepsinde 3D ikon")
	var list_scroll: Control = garage.find_child("CarListScroll", true, false)
	check(list_scroll != null and not list_scroll.is_visible_in_tree(), "araç şeridi gizli")
	for i: int in 40:   # önizlemeler kare kare ölçülür
		await process_frame
	var advice: Control = garage.find_child("ModAdvice", true, false)
	check(advice != null and advice.is_visible_in_tree(), "ÖNERİLEN plakası (₺ başına en çok kazandıran kategori)")
	check(PerformanceMods.CATEGORIES.has(PerformanceMods.recommend(passat)), "öneri: %s" % PerformanceMods.recommend(passat))
	(garage.find_child("Part_gear", true, false) as PlateButton).pressed.emit()
	await frames(2)
	var workshop: ModWorkshop = garage.find_child("ModWorkshop", true, false)
	check(workshop.in_category() and workshop.category == &"gear", "ŞANZIMAN kategorisine girildi")
	var stage_cards: int = 0
	for s: int in range(1, 6):
		var stage_card: PlateButton = garage.find_child("Stage_%d" % s, true, false)
		if stage_card and stage_card.is_visible_in_tree() and (stage_card.get_node("Icon") as TextureRect).texture != null:
			stage_cards += 1
	check(stage_cards == 5, "5 kademe kartı (SOKAK … EFSANE), hepsinde 3D ikon")
	check(workshop.selected_stage == 1, "sıradaki kademe seçili")
	for i: int in 20:
		await process_frame
	var dyno_rows: Array = workshop._dyno.data.get("rows", [])
	check(dyno_rows.size() == 4 and float(dyno_rows[1]["frac_after"]) > float(dyno_rows[1]["frac_now"]),
		"dinamometre: 4 çubuk, son hız çubuğunda yeşil kazanç")
	check(String(dyno_rows[0]["delta"]).begins_with("−"), "0-100 kazancı: %s" % dyno_rows[0]["delta"])
	(garage.find_child("Stage_3", true, false) as PlateButton).button_pressed = true
	await frames(2)
	var upgrade: PlateButton = garage.find_child("UpgradeButton", true, false)
	check(upgrade.disabled and upgrade.text == "ÖNCE SOKAK", "ileri kademe seçilince: ÖNCE SOKAK")
	(garage.find_child("Stage_1", true, false) as PlateButton).button_pressed = true
	await frames(2)
	check(upgrade != null and not upgrade.disabled, "YÜKSELT açık (ŞANZIMAN SOKAK)")
	upgrade.pressed.emit()
	await frames(2)
	check(mods.has_job(passat) and mods.job_of(passat)["category"] == &"gear", "YÜKSELT parçayı aldı")
	await create_timer(0.8).timeout
	check(not garage.visible and router.top() == &"", "garaj kapandı, ana dünya")
	await create_timer(2.2).timeout
	var shown: PerformanceBayDisplay = (g(&"performance_bays") as PerformanceBays).display_of(passat)
	check(shown != null and shown.visible and not shown.arriving, "araç alana girdi, liftte")
	var lift: RepairLift = (g(&"repair_bays") as RepairBayManager).lift(int(mods.job_of(passat)["bay"]))
	check(lift != null and lift.raised_fraction() > 0.95, "lift kalktı")
	router.open(&"garage")
	await frames(30)
	garage.call(&"_on_vehicle_selected", passat)
	await frames(5)
	garage.open_mods()
	await frames(3)
	(garage.find_child("Part_turbo", true, false) as PlateButton).pressed.emit()
	await frames(2)
	check(upgrade.disabled and upgrade.text == "PARÇA TAKILIYOR", "takma sürerken başka parça alınamaz")
	garage.call(&"_on_exit_pressed")
	await frames(2)
	check(garage.is_modding() and not workshop.in_category(), "GERİ: kategoriden genel bakışa")
	(garage.find_child("Part_gear", true, false) as PlateButton).pressed.emit()
	await frames(2)
	check(not upgrade.disabled and upgrade.text == "HEMEN BİTİR", "takılan parçanın kartında HEMEN BİTİR")
	garage.call(&"_on_exit_pressed")
	garage.call(&"_on_exit_pressed")
	await frames(3)
	check(not garage.is_modding() and garage.visible and list_scroll.is_visible_in_tree(), "GERİ: araç listesine döndü")
	router.close_all()
	await frames(20)

	print("== 10) ELMASLA BİTİR ==")
	check(GemSkip.cost(60.0) == 2 and GemSkip.cost(61.0) == 4 and GemSkip.cost(1.0) == 2 and GemSkip.cost(0.0) == 0,
		"fiyat: kalan dakika (yukarı yuvarlı) × 2 elmas")
	check(mods.has_job(passat), "Passat'a ŞANZIMAN takılıyor")
	var mod_cost: int = mods.gem_skip_cost(passat)
	check(mod_cost == GemSkip.cost(mods.remaining(passat)) and mod_cost >= 2, "takmanın elmas fiyatı %d" % mod_cost)
	var gem_sounds: Array[StringName] = []   # HUD elmas sesi bu sinyalle çalar
	mods.gem_finished.connect(func(id: StringName) -> void: gem_sounds.append(id))
	pp.gems = mod_cost - 1
	check(not mods.finish_with_gems(passat) and mods.has_job(passat) and pp.gems == mod_cost - 1,
		"elmas yetmezse hiçbir şey değişmez")
	check(gem_sounds.is_empty(), "elmas yetmezse elmas sesi de yok")
	pp.gems = 50
	var gear_before: int = mods.stage_of(passat, &"gear")
	check(mods.finish_with_gems(passat), "elmasla bitirildi")
	check(gem_sounds == [passat], "takma elmasla bitince gem_finished (ses) bir kez")
	check(not mods.has_job(passat) and mods.stage_of(passat, &"gear") == gear_before + 1 and pp.gems == 50 - mod_cost,
		"parça hemen takıldı, %d elmas düştü" % mod_cost)
	check(mods.gem_skip_cost(passat) == 0, "takma yokken fiyat 0")
	await create_timer(1.6).timeout   # araç alandan çıksın
	# Uzun tamir (BOYA İŞİ, 90 sn)
	var rm2: RepairManager = g(&"repair_manager")
	var traffic: TrafficManager = g(&"traffic")
	for i: int in 600:
		if not traffic.vehicles.is_empty():
			break
		await process_frame
	var long_car: TrafficVehicle = traffic.vehicles[0] if not traffic.vehicles.is_empty() else null
	if long_car:
		long_car.request_repair(rm2.repair_wait_spots[0], RepairType.by_id(&"paint_job"))
	check(long_car != null and rm2.start_repair(long_car), "uzun tamir (BOYA İŞİ) başladı")
	await frames(3)
	var repair_cost: int = rm2.gem_skip_cost(long_car)
	var long_state: RepairState = rm2.get_state(long_car)
	check(repair_cost == GemSkip.cost(long_state.remaining) and repair_cost >= 2, "uzun tamirin elmas fiyatı %d" % repair_cost)
	var gems_before: int = pp.gems
	var repair_gem_sounds: Array[Node3D] = []
	rm2.gem_finished.connect(func(car: Node3D) -> void: repair_gem_sounds.append(car))
	check(rm2.finish_with_gems(long_car), "uzun tamir elmasla bitti")
	check(repair_gem_sounds == [long_car], "tamir elmasla bitince gem_finished (ses) bir kez")
	check(long_state.phase == RepairState.Phase.REWARD_WAITING and pp.gems == gems_before - repair_cost,
		"PARA TOPLA bekliyor, %d elmas düştü" % repair_cost)
	var short_type: RepairType = RepairType.by_id(&"engine")
	check(short_type.duration < GemSkip.MIN_JOB_SECONDS, "kısa tamirlerde (%d sn) elmasla bitirme sunulmaz" % int(short_type.duration))
	# Plaka: iki dokunuşlu onay
	var panel: RepairPanel = RepairPanel.new()
	root.add_child(panel)
	var fired: Array = []
	panel.gem_finish_pressed.connect(func() -> void: fired.append(true))
	panel.show_repairing(0.4, 125.0, false, GemSkip.cost(125.0))
	var gem_button: PlateButton = panel.find_child("GemFinishButton", true, false)
	check(gem_button.visible and gem_button.text == "BİTİR  6", "plakada ELMASLA BİTİR (2:05 → 6 elmas)")
	gem_button.pressed.emit()
	check(fired.is_empty() and gem_button.text == "ONAYLA  6", "ilk dokunuş yalnızca onay ister")
	gem_button.pressed.emit()
	check(fired.size() == 1, "ikinci dokunuş harcar")
	panel.show_repairing(0.4, 10.0, false, 0)
	check(not gem_button.visible, "kısa işte buton yok")
	panel.queue_free()

	print("== 11) BOZUK KAYIT + YENİ OYUN ==")
	mods.load_state({"builds": {"yok_boyle_arac": {"motor": 3}, "tofas_sahin": {"motor": 9, "uydurma": 2, "turbo": "x"}},
		"floors": {"tofas_sahin": 5.0}, "jobs": [{"car": "tofas_sahin", "category": "motor", "stage": 2, "bay": 0,
		"start": 0.0, "end": 1.0e12}, {"car": "tofas_sahin", "category": "turbo", "stage": 1, "bay": 1}, "çöp"]})
	check(mods.build_of(sahin) == {&"motor": 5}, "bilinmeyen araç / kategori atıldı, kademe 5'e kırpıldı")
	check(mods.jobs().size() == 1, "aynı araca ikinci takma atıldı")
	check(mods.remaining(sahin) <= PerformanceMods.install_time(2) + 1.0, "geri alınmış saat süreyi sonsuza uzatmıyor")
	save.new_game()
	check(mods.jobs().is_empty() and mods.build_of(sahin).is_empty() and not PerformanceMods.is_modified(sahin),
		"yeni oyun: yapı ve takma yok")

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func pfull_build() -> Dictionary:
	var full: Dictionary = {}
	for category: StringName in PerformanceMods.CATEGORIES:
		full[category] = PerformanceMods.STAGES
	return full
