extends SceneTree
## DEPOLARIM (docs/GARAJLAR_TASARIM.md §10; §2–5) — katalog, kapasite, otomatik yerleşim, OTOPARK ve günlük ücreti,
## GARAJIM sergisi, satın alma / inşaat / elmasla bitirme, iç yükseltme işleri, TAŞI, her yerden yarış, kayıt turu ve
## bozuk kayıt, arayüz (DEPOLARIM, YERLEŞTİR), 3D iç mekân ve prestij (garaj değeri, rütbe 11–15, açık özet / profil
## şeridi, OTO MANŞET haberleri).
## Çalıştırma: tools/run_tests.sh car_garage_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


## Tipli / tipsiz dizi karşılaştırması (Array[StringName] == [..] tipe bakabilir): öğe öğe.
func same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if StringName(a[i]) != StringName(b[i]):
			return false
	return true


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))

	print("== 1) Katalog ve elmas eğrisi ==")
	var ids: Array[StringName] = CarGarageCatalog.ids()
	check(ids.size() == 5 and ids[0] == CarGarageCatalog.MAHALLE and ids[4] == CarGarageCatalog.HANGAR, "5 garaj, merdiven sırası")
	check(CarGarageCatalog.max_capacity(CarGarageCatalog.MAHALLE) == 6 and CarGarageCatalog.max_capacity(CarGarageCatalog.HANGAR) == 30,
		"MAHALLE 4→6, HANGAR 18→30")
	check(CarGarageCatalog.display_name(CarGarageCatalog.MAHALLE) == Loc.t("MAHALLE DEPOSU")
		and CarGarageCatalog.display_name(CarGarageCatalog.HANGAR) == Loc.t("HANGAR DEPOSU"), "adlar depo (§10)")
	var obtainable: int = 0
	for entry: Dictionary in CarCatalog.all():
		if entry["obtainable"]:
			obtainable += 1
	check(CarGarageCatalog.total_max_capacity() >= obtainable,
		"toplam kapasite (%d) edinilebilir araçlara (%d) yetiyor" % [CarGarageCatalog.total_max_capacity(), obtainable])
	var full: int = 0
	for id: StringName in ids:
		full += CarGarageCatalog.full_cost(id)
	check(full > 23000000 and full < 28000000, "hepsi ≈ 25 M ₺ (%s)" % full)
	check(GemSkip.cost_long(600.0) == 20 and GemSkip.cost_long(3600.0) == 120, "kısa iş eski kural (10 dk 20, 1 sa 120)")
	check(GemSkip.cost_long(4 * 3600.0) == 276 and GemSkip.cost_long(24 * 3600.0) == 808,
		"uzun iş azalan oran (4 sa %d, 24 sa %d)" % [GemSkip.cost_long(4 * 3600.0), GemSkip.cost_long(24 * 3600.0)])

	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var garages: CarGarageManager = get_first_node_in_group("car_garages") as CarGarageManager
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	check(garages != null, "yönetici kodla kuruldu")
	save.new_game()
	await frames(2)

	print("== 2) Yerleşim: otopark, ücret, sergi (§10) ==")
	var mahalle: StringName = CarGarageCatalog.MAHALLE
	check(garages.owned_garages().is_empty(), "yeni oyun: hiç depo yok")
	var waited: Array[StringName] = []
	garages.vehicle_waiting.connect(func(id: StringName) -> void: waited.append(id))
	var parked_events: Array = []
	garages.waiting_parked.connect(func(list: Array[StringName]) -> void: parked_events.append(list))
	var cars: Array[StringName] = [&"tofas_sahin", &"bmw_e46", &"lambo_huracan", &"renault_toros", &"hyundai_getz", &"porsche_gt3"]
	for id: StringName in cars:
		own.add_vehicle(id)
	check(same(garages.waiting_ids(), cars), "depo yok: hepsi OTOPARK'ta, geliş sırasıyla")
	check(same(waited, cars), "otopark sinyali her araç için")
	check(garages.garage_of(&"porsche_gt3") == CarGarageManager.WAITING, "garage_of → WAITING")
	check(own.set_race_vehicle(&"porsche_gt3") and own.race_vehicle_id() == &"porsche_gt3", "otoparktaki araç yarışır")
	check(own.sell_vehicle(&"renault_toros") and not garages.waiting_ids().has(&"renault_toros"), "otoparktaki araç satılabilir")
	check(CarGarageManager.fee_of(&"tofas_sahin") == 750 and CarGarageManager.fee_of(&"lambo_huracan") == 20000,
		"ücret araç değerinin %5'i (Bursan 750, Lambo 20.000)")
	var daily: int = 0
	for id: StringName in garages.waiting_ids():
		daily += CarGarageManager.fee_of(id)
	check(garages.daily_fee() == daily and daily > 0, "günlük ücret otoparktakilerin toplamı (%d)" % daily)
	var charged: Array = []
	garages.fee_charged.connect(func(amount: int, count: int, periods: int) -> void: charged.append([amount, count, periods]))
	economy.set_money(1000000)
	garages.clock_offset = 0.0
	garages._check_timers()
	check(charged.is_empty() and economy.money == 1000000, "gün dolmadan ücret yok")
	check(garages.next_fee_in() > CarGarageManager.FEE_PERIOD - 60.0, "sıradaki faturaya ~1 gün")
	garages.clock_offset = CarGarageManager.FEE_PERIOD + 1.0
	garages._check_timers()
	check(charged.size() == 1 and int(charged[0][0]) == daily and economy.money == 1000000 - daily, "bir gün: günlük ücret kesildi")
	garages.clock_offset += 10.0 * CarGarageManager.FEE_PERIOD   # oyuncu 10 gün girmedi
	garages._check_timers()
	check(charged.size() == 2 and int(charged[1][2]) == 3 and int(charged[1][0]) == daily * 3,
		"10 gün yoktu: en çok 3 günlük kesildi")
	economy.set_money(100)
	garages.clock_offset += CarGarageManager.FEE_PERIOD
	garages._check_timers()
	check(economy.money == 0 and int(charged[2][0]) == 100, "para yetmezse sıfıra iner, eksiye düşmez")
	check(garages.fees_between(0.0, garages.now() + 1.0).size() == 3, "faturalar günlüğü (OTO MANŞET)")
	var mission_spent: Array = []
	economy.money_spent.connect(func(amount: int) -> void: mission_spent.append(amount))
	economy.set_money(1000000)
	garages.clock_offset += CarGarageManager.FEE_PERIOD
	garages._check_timers()
	check(mission_spent.is_empty(), "fatura harcama sayılmaz (görev sayacı ilerlemez)")
	# İlk depo: MAHALLE DEPOSU satın alınır
	economy.set_money(10000000)
	check(CarGarageCatalog.price(mahalle) == 50000 and is_equal_approx(CarGarageCatalog.build_time(mahalle), 1800.0)
		and garages.status(mahalle) == CarGarageManager.Status.BUYABLE, "MAHALLE DEPOSU 50.000 ₺, 30 dk, satılık")
	var order: Array[StringName] = garages.waiting_ids()
	check(garages.purchase(mahalle) and garages.is_building(mahalle) and economy.money == 10000000 - 50000, "MAHALLE alındı, inşaat başladı")
	garages.clock_offset += 1801.0
	garages._check_timers()
	check(garages.is_owned(mahalle) and same(garages.cars_in(mahalle), order.slice(0, 4)),
		"inşaat bitti: otoparktakiler geliş sırasıyla depoya geçti")
	check(parked_events.size() == 1 and (parked_events[0] as Array).size() == 4, "otoparktan depoya sinyali")
	check(same(garages.waiting_ids(), order.slice(4)), "kalan araç otoparkta")
	check(garages.move_targets(&"tofas_sahin").has(CarGarageManager.WAITING), "depolar doluyken otopark hedef")
	# GARAJIM: sergiye konan araç depoda / otoparkta yer kaplamaz
	var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
	var lone: StringName = garages.waiting_ids()[0]
	var exhibit: StringName = GarageDecor.vehicle_item_id(lone)
	var iid: String = decor.add_instance(exhibit, Vector3(1.0, 0.0, 1.0), 0.0)
	check(iid != "" and garages.garage_of(lone) == CarGarageManager.HOME and garages.waiting_ids().is_empty(),
		"sergiye konan araç otoparktan çıktı")
	check(same(garages.cars_in(CarGarageManager.HOME), [lone]), "GARAJIM: sergidekiler")
	decor.remove_instance(iid)
	check(garages.is_waiting(lone), "sergiden kalkan araç varsayılan yere (depo dolu: otopark)")
	var mover0: StringName = garages.cars_in(mahalle)[0]
	iid = decor.add_instance(GarageDecor.vehicle_item_id(mover0), Vector3(2.0, 0.0, 1.0), 0.0)
	check(garages.garage_of(mover0) == CarGarageManager.HOME and garages.used(mahalle) == 4
		and garages.cars_in(mahalle).has(lone) and garages.waiting_ids().is_empty(),
		"depodaki araç sergiye: boşalan yere otoparktaki geçti")
	check(garages.move(mover0, CarGarageManager.WAITING) and decor.placed_of(GarageDecor.vehicle_item_id(mover0)) == 0
		and garages.is_waiting(mover0), "TAŞI: sergiden otoparka (sergi kalktı)")

	print("== 3) Satın alma ve inşaat ==")
	progress.load_state(4, 0, 2000)
	economy.set_money(10000000)
	check(garages.status(CarGarageCatalog.SANAYI) == CarGarageManager.Status.NEEDS_LEVEL, "SANAYİ seviye 5 ister")
	check(not garages.purchase(CarGarageCatalog.SANAYI) and economy.money == 10000000, "kilitliyken para düşmez")
	progress.load_state(5, 0, 2000)
	check(garages.status(CarGarageCatalog.SANAYI) == CarGarageManager.Status.BUYABLE, "seviye 5: alınabilir")
	economy.set_money(100)
	check(garages.status(CarGarageCatalog.SANAYI) == CarGarageManager.Status.TOO_EXPENSIVE, "para yetmiyor")
	economy.set_money(10000000)
	check(garages.purchase(CarGarageCatalog.SANAYI), "SANAYİ alındı")
	check(economy.money == 10000000 - 150000 and garages.is_building(CarGarageCatalog.SANAYI), "para düştü, inşaat başladı")
	check(absf(garages.build_remaining(CarGarageCatalog.SANAYI) - 3600.0) < 2.0, "1 saat sürüyor")
	check(garages.build_gem_cost(CarGarageCatalog.SANAYI) == 120, "elmasla bitirme 120")
	check(garages.is_waiting(mover0), "inşaat bitmeden otoparktaki girmez")
	garages.clock_offset += 3601.0
	garages._check_timers()
	check(garages.is_owned(CarGarageCatalog.SANAYI) and not garages.is_building(CarGarageCatalog.SANAYI), "süre doldu: depo açıldı")
	check(garages.garage_of(mover0) == CarGarageCatalog.SANAYI, "otoparktaki yeni depoya geçti")
	check(not garages.move_targets(&"tofas_sahin").has(CarGarageManager.WAITING), "depoda yer varken otopark hedef değil")
	own.add_vehicle(&"vw_golf_7")
	check(garages.garage_of(&"vw_golf_7") == CarGarageCatalog.SANAYI, "yeni araç EN ÜST boş depoya")
	progress.load_state(12, 0, 2000)
	check(garages.purchase(CarGarageCatalog.NEON), "NEON alındı (4 sa)")
	var gems: int = progress.gems
	var neon_cost: int = garages.build_gem_cost(CarGarageCatalog.NEON)
	check(neon_cost >= 270 and neon_cost <= 276, "4 saatlik inşaat ≈ 276 elmas (%d)" % neon_cost)
	check(garages.finish_build_with_gems(CarGarageCatalog.NEON) and progress.gems == gems - neon_cost, "elmasla bitti")
	check(garages.is_owned(CarGarageCatalog.NEON) and garages.capacity(CarGarageCatalog.NEON) == 8, "NEON açık, 8 yer")
	progress.load_state(12, 0, 0)
	garages.purchase(CarGarageCatalog.SHOWROOM)
	check(garages.status(CarGarageCatalog.SHOWROOM) == CarGarageManager.Status.NEEDS_LEVEL, "VİTRİN seviye 20 ister")

	print("== 4) İç yükseltmeler ==")
	check(garages.item_level(mahalle, CarGarageCatalog.PARK) == 1, "PARK YERİ seviye 1")
	var money_before: int = economy.money
	check(garages.upgrade_item(mahalle, CarGarageCatalog.PARK), "PARK YERİ yükseltmesi başladı")
	check(economy.money == money_before - 40000, "40.000 ₺ düştü")
	check(garages.item_status(mahalle, CarGarageCatalog.FLOOR) == CarGarageManager.ItemStatus.BUSY, "aynı depoda ikinci iş yok")
	check(garages.item_status(CarGarageCatalog.SANAYI, CarGarageCatalog.FLOOR) == CarGarageManager.ItemStatus.BUYABLE,
		"başka depoda iş başlatılabilir")
	check(garages.capacity(mahalle) == 4, "süre dolmadan kapasite aynı")
	garages.clock_offset += 601.0
	garages._check_timers()
	check(garages.item_level(mahalle, CarGarageCatalog.PARK) == 2 and garages.capacity(mahalle) == 5, "süre doldu: 5 yer")
	garages.upgrade_item(mahalle, CarGarageCatalog.LIGHTS)
	progress.load_state(12, 0, 100)
	var job_cost: int = garages.job_gem_cost(mahalle)
	check(job_cost == 10, "5 dakikalık iş 10 elmas (%d)" % job_cost)
	check(garages.finish_job_with_gems(mahalle) and garages.item_level(mahalle, CarGarageCatalog.LIGHTS) == 2, "elmasla bitti")
	garages.upgrade_item(mahalle, CarGarageCatalog.LIGHTS)
	garages.clock_offset += 700.0
	garages._check_timers()
	check(garages.item_status(mahalle, CarGarageCatalog.LIGHTS) == CarGarageManager.ItemStatus.MAXED, "IŞIKLAR en üstte")
	check(not garages.upgrade_item(mahalle, CarGarageCatalog.LIGHTS), "en üstteki kalem yükseltilmez")

	print("== 5) TAŞI ==")
	var free_target: StringName = CarGarageCatalog.NEON
	check(garages.move(&"tofas_sahin", free_target) and garages.garage_of(&"tofas_sahin") == free_target, "araç NEON'a taşındı")
	check(not garages.move(&"tofas_sahin", free_target), "aynı depoya taşınmaz")
	check(not garages.move(&"tofas_sahin", CarGarageCatalog.HANGAR), "alınmamış depoya taşınmaz")
	check(garages.move_targets(&"bmw_e46").has(free_target), "boş yeri olan depo hedeflerde")

	print("== 6) Kayıt turu ==")
	garages.upgrade_item(CarGarageCatalog.SANAYI, CarGarageCatalog.WALLS)
	var spent: int = garages.spent_total()
	check(spent == 50000 + 150000 + 900000 + 40000 + 10000 + 20000 + 40000, "harcanan toplam (%d)" % spent)
	var before: Dictionary = JSON.parse_string(JSON.stringify(garages.state()))
	save.save_game()
	garages.reset()
	check(garages.owned_garages().is_empty(), "sıfırlandı")
	save.load_game()
	var after: Dictionary = JSON.parse_string(JSON.stringify(garages.state()))
	check(JSON.stringify(after["garages"]) == JSON.stringify(before["garages"]), "depolar ve park yerleri geri geldi")
	check(after["jobs"].has(String(CarGarageCatalog.SANAYI)), "süren iş geri geldi")
	check(garages.spent_total() == spent, "harcanan toplam aynı")
	check(absf(float(after["fee_since"]) - float(before["fee_since"])) < 2.0 and (after["fees"] as Array).size() == 4,
		"ücret dönemi ve faturalar kayıtta")
	var legacy: Dictionary = save.snapshot()
	legacy.erase("car_garages")
	check(save.apply_snapshot(legacy), "bölümsüz (eski) kayıt yüklenir")
	check(garages.owned_garages().is_empty() and garages.waiting_ids().size() + garages.cars_in(CarGarageManager.HOME).size()
		== own.owned_count(), "bölümsüz kayıt: depo yok, araçlar otoparkta (sergidekiler hariç)")

	print("== 7) Bozuk kayıt ==")
	garages.load_state({"garages": {
		"mahalle": {"levels": {"park": 99, "floor": -3}, "slots": ["bmw_e46", "bmw_e46", "yok_boyle", "", "lambo_huracan", "x", "y", "z"]},
		"uzay_ussu": {"levels": {}, "slots": []},
		"neon": "bozuk"},
		"building": {"mahalle": 1.0, "hangar": 9.9e12},
		"jobs": {"mahalle": {"item": "park", "level": 2, "end": 0.0}},
		"waiting": ["bmw_e46", "tofas_sahin", "tofas_sahin"],
		"fee_since": 9.9e12, "fees": ["bozuk", {"at": 1.0, "amount": -5}]})
	check(garages.item_level(mahalle, CarGarageCatalog.PARK) == 3 and garages.item_level(mahalle, CarGarageCatalog.FLOOR) == 1,
		"seviyeler sınırlandı")
	check(garages.capacity(mahalle) == 6, "park yerleri kapasiteye göre kesildi")
	var slots: Array[StringName] = garages.slots_of(mahalle)
	check(slots[0] == &"bmw_e46" and slots[1] == &"" and slots[2] == &"" and slots[4] == &"lambo_huracan", "çift / bilinmeyen araç atıldı")
	check(not garages.is_owned(&"uzay_ussu") and not garages.is_owned(CarGarageCatalog.NEON), "bilinmeyen / bozuk depo atıldı")
	check(not garages.is_building(mahalle), "alınmış depo inşaatta olamaz")
	check(garages.build_remaining(CarGarageCatalog.HANGAR) <= CarGarageCatalog.build_time(CarGarageCatalog.HANGAR) + 1.0,
		"saat ileri alınmış bitiş adımın süresine çekildi")
	check(garages.job_of(mahalle).is_empty(), "seviyeyle uyuşmayan iş atıldı")
	check(same(garages.waiting_ids(), [&"tofas_sahin"]), "otoparkta çift / depodaki araç yok")
	check(garages.next_fee_in() <= CarGarageManager.FEE_PERIOD + 1.0, "ileri alınmış ücret dönemi şimdiye çekildi")
	check(garages.fees_between(-1.0, 2.0).size() == 1 and int(garages.fees_between(-1.0, 2.0)[0]["amount"]) == 0,
		"bozuk fatura atıldı / eksi tutar sıfırlandı")
	garages.reconcile()
	var placed: int = garages.waiting_ids().size() + garages.cars_in(CarGarageManager.HOME).size()
	for id: StringName in garages.owned_garages():
		placed += garages.used(id)
	check(placed == own.owned_count(), "uzlaştırma: her araç tam bir yerde (%d / %d)" % [placed, own.owned_count()])

	print("== 8) Arayüz: otopark, DEPOLARIM, TAŞI, boş depo, iç yükseltmeler, TÜM ARAÇLAR, YERLEŞTİR ==")
	save.new_game()
	await frames(2)
	garages.clock_offset = 0.0
	progress.load_state(30, 0, 5000)
	economy.set_money(20000000)
	for id: StringName in cars:
		own.add_vehicle(id)
	var hud: Hud = main.find_child("HUD", true, false)
	var screen: GarageScreen = hud.garage_screen
	hud.router.open(&"garage")
	await frames(20)
	var title: Label = screen.find_child("TitleLabel", true, false)
	check(screen.current_garage() == CarGarageManager.WAITING and title.text.begins_with(Loc.t("OTOPARK")),
		"depo yokken ARAÇLAR otoparkta açılır (%s)" % title.text)
	check((screen.find_child("WaitingNote", true, false) as Control).is_visible_in_tree(), "otopark ücret notu")
	for allowed: String in ["RacePickButton", "ModifyButton"]:
		check((screen.find_child(allowed, true, false) as Control).is_visible_in_tree(), "otoparktaki araçta %s var" % allowed)
	screen.open_mods()
	check(screen.is_modding(), "otoparktaki araç modifiyeye girer")
	screen.call("_close_mods")
	await frames(5)
	# DEPOLARIM: MAHALLE'yi al, elmasla bitir → otoparktakiler girer, ekran aracı izler
	(screen.find_child("GaragesHit", true, false) as Button).pressed.emit()
	await frames(20)
	var board: CarGaragesScreen = hud.car_garages_screen
	check(hud.router.top() == &"car_garages", "başlığa basınca DEPOLARIM açıldı")
	check(board.selected() == CarGarageManager.WAITING, "panoda OTOPARK basamağı seçili")
	board.main_button(mahalle).pressed.emit()
	await frames(3)
	check(garages.is_building(mahalle), "SATIN AL → inşaat")
	board.main_button(mahalle).pressed.emit()
	await frames(2)
	var mahalle_gems: int = garages.build_gem_cost(mahalle)
	check(garages.is_building(mahalle) and board.main_button(mahalle).text.contains(Loc.t("ONAYLA: %d") % mahalle_gems),
		"ilk dokunuş elmas harcamaz, onay ister (%d)" % mahalle_gems)
	board.main_button(mahalle).pressed.emit()
	await frames(10)
	check(garages.is_owned(mahalle) and garages.used(mahalle) == 4 and garages.waiting_ids().size() == 2,
		"elmasla bitti, ilk dört araç MAHALLE'ye geçti")
	check(screen.current_garage() == mahalle, "ekran depoya geçen aracı izledi")
	board.main_button(CarGarageCatalog.SANAYI).pressed.emit()
	board.main_button(CarGarageCatalog.SANAYI).pressed.emit()
	board.main_button(CarGarageCatalog.SANAYI).pressed.emit()
	await frames(10)
	check(garages.is_owned(CarGarageCatalog.SANAYI) and garages.waiting_ids().is_empty(), "SANAYİ alındı: otopark boşaldı")
	board.main_button(mahalle).pressed.emit()
	await frames(20)
	check(hud.router.top() == &"garage" and screen.current_garage() == mahalle, "GİT / BURADASIN → MAHALLE")
	# TAŞI: MAHALLE'den SANAYİ'ye (yer var)
	var mover: StringName = screen.shown_vehicle()
	(screen.find_child("MoveButton", true, false) as PlateButton).pressed.emit()
	await frames(3)
	var target_button: PlateButton = screen.find_child("MoveTo_%s" % CarGarageCatalog.SANAYI, true, false)
	check(target_button != null and not target_button.disabled, "TAŞI panosunda SANAYİ (yer var)")
	check(screen.find_child("MoveTo_%s" % CarGarageManager.HOME, true, false) != null, "TAŞI panosunda GARAJIMA KOY")
	check(screen.find_child("MoveTo_%s" % CarGarageManager.WAITING, true, false) == null, "depoda yer varken TAŞI'da otopark yok")
	target_button.pressed.emit()
	await frames(10)
	check(garages.garage_of(mover) == CarGarageCatalog.SANAYI and screen.current_garage() == CarGarageCatalog.SANAYI
		and screen.shown_vehicle() == mover, "taşındı, ekran aracı izledi")
	# SERGİLE (2026-10-21): depodaki aracın rafında; basınca HUD düzenleme kipini aracı parmakta açar (burada yalnız sinyal)
	var exhibit_sign: PlateButton = screen.find_child("ExhibitButton", true, false) as PlateButton
	check(exhibit_sign != null and exhibit_sign.is_visible_in_tree(), "depodaki araçta SERGİLE")
	var homed: Array[StringName] = []
	var place_at_home: Callable = Callable(hud, &"_place_at_home")
	screen.home_requested.disconnect(place_at_home)
	screen.home_requested.connect(func(id: StringName) -> void: homed.append(id))
	exhibit_sign.pressed.emit()
	check(same(homed, [mover]), "SERGİLE → GARAJIMA KOY isteği (%s)" % [homed])
	screen.home_requested.connect(place_at_home)
	# İSİM TABELASI (2026-10-21): TABELA → pano önizler, KAYDET yazar; süzgeç, kayıt, açık garaj
	var sanayi: StringName = CarGarageCatalog.SANAYI
	var sign_button: PlateButton = screen.find_child("NameSignButton", true, false) as PlateButton
	check(sign_button != null and sign_button.is_visible_in_tree(), "depo iç mekânında TABELA tabelası")
	sign_button.pressed.emit()
	await frames(3)
	var sign_panel: NameSignPanel = screen.find_child("NameSignPanel", true, false) as NameSignPanel
	check(sign_panel != null and sign_panel.visible, "TABELA → İSİM TABELASI panosu")
	var sign_edit: LineEdit = sign_panel.find_child("SignText", true, false) as LineEdit
	sign_edit.text = "Burak Garaj"
	sign_edit.text_changed.emit(sign_edit.text)
	(sign_panel.find_child("Style_1", true, false) as PlateButton).pressed.emit()
	await frames(2)
	var interior_view: GarageInteriorView = screen.find_child("InteriorView", true, false) as GarageInteriorView
	check(interior_view.name_sign() != null and interior_view.name_sign().tile_count() == 10,
		"önizleme: harf başına bir karo, boşluk karosuz (%d)" % (interior_view.name_sign().tile_count() if interior_view.name_sign() else -1))
	check(String(garages.sign_of(sanayi)["t"]).is_empty(), "önizleme kaydetmez")
	(sign_panel.find_child("SaveButton", true, false) as PlateButton).pressed.emit()
	await frames(2)
	check(not sign_panel.visible and garages.sign_of(sanayi) == {"t": "Burak Garaj", "s": 1, "c": 0}, "KAYDET yazdı (%s)" % garages.sign_of(sanayi))
	check(not garages.set_sign(sanayi, {"t": "amk garaj"}) and garages.sign_of(sanayi)["t"] == "Burak Garaj", "küfür reddedilir")
	check(not garages.set_sign(CarGarageCatalog.HANGAR, {"t": "Hangar"}), "alınmamış depoya tabela yazılmaz")
	check(garages.set_sign(CarGarageManager.WAITING, {"t": "otopark 1", "s": 9, "c": 99})
		and garages.sign_of(CarGarageManager.WAITING) == {"t": "otopark 1", "s": NameSign.STYLES.size() - 1, "c": NameSign.COLORS.size() - 1},
		"otoparka tabela; stil / renk sınırlanır")
	check(NameSign.clean_text("  çok    uzun bir garaj adı burada  ").length() <= NameSign.MAX_CHARS, "yazı en çok %d harf" % NameSign.MAX_CHARS)
	var sign_state: Dictionary = garages.state()
	garages.load_state(JSON.parse_string(JSON.stringify(sign_state)))
	check(garages.sign_of(sanayi)["t"] == "Burak Garaj" and garages.sign_of(CarGarageManager.WAITING)["t"] == "otopark 1",
		"tabelalar kayıttan geri gelir")
	var sign_layout: Dictionary = PublicGarage.depot_layout(save.snapshot())
	check(String((sign_layout[String(sanayi)] as Dictionary).get("sign", {}).get("t", "")) == "Burak Garaj"
		and not sign_layout.has(String(CarGarageManager.WAITING)), "açık garajda deponun tabelası (otopark ziyarette yok)")
	check(garages.set_sign(sanayi, {"t": ""}) and String(garages.sign_of(sanayi)["t"]).is_empty(), "boş yazı tabelayı söker")
	await frames(3)
	# Boş depo: NEON al, bitir (otopark boş → boş)
	garages.purchase(CarGarageCatalog.NEON)
	garages.finish_build_with_gems(CarGarageCatalog.NEON)
	screen.go_to_garage(CarGarageCatalog.NEON)
	await frames(10)
	check(screen.shown_vehicle() == &"" and (screen.find_child("EmptyPanel", true, false) as Control).is_visible_in_tree(),
		"boş depo: araç yok, BURASI BOŞ notu")
	screen.go_to_garage(CarGarageCatalog.SANAYI)
	await frames(10)
	check(screen.shown_vehicle() != &"" and not (screen.find_child("EmptyPanel", true, false) as Control).is_visible_in_tree(),
		"dolu depoya dönünce araç ve plakalar geri geldi")
	# İç yükseltmeler: MAHALLE PARK YERİ
	hud.router.open(&"car_garages")
	await frames(10)
	(board.find_child("Garage_%s" % mahalle, true, false) as PlateButton).button_pressed = true   # merdivenden seç
	await frames(2)
	(board.find_child("Upgrades", true, false) as PlateButton).pressed.emit()
	await frames(15)
	var upgrades: CarGarageUpgradeScreen = hud.car_garage_upgrade_screen
	check(hud.router.top() == &"car_garage_upgrades" and upgrades.garage == mahalle, "İÇ YÜKSELTMELER açıldı (alt pano)")
	upgrades.main_button(CarGarageCatalog.PARK).pressed.emit()
	await frames(3)
	check(not garages.job_of(mahalle).is_empty(), "YÜKSELT → iş başladı")
	check(upgrades.main_button(CarGarageCatalog.FLOOR).disabled, "öteki kalemler İŞ SÜRÜYOR")
	upgrades.close()
	await frames(15)
	check(hud.router.top() == &"car_garages", "GERİ → DEPOLARIM")
	board.close()
	await frames(15)
	# TÜM ARAÇLAR: depo rozeti ve BU GARAJ
	hud.router.open(&"all_cars")
	await frames(15)
	var all_board: AllCarsScreen = hud.all_cars_screen
	all_board.set_query("", &"", VehicleSort.NEWEST)
	all_board.set_this_garage(false)
	await frames(2)
	var badge: Label = all_board.find_child(String(mover), true, false).find_child("GarageBadge", true, false)
	check(badge != null and badge.text == CarGarageCatalog.display_name(CarGarageCatalog.SANAYI), "kartta depo rozeti")
	all_board.set_this_garage(true)
	await frames(2)
	var in_sanayi: Array[StringName] = []
	for id: StringName in own.owned_vehicle_ids():   # pano edinme sırasından süzer
		if garages.garage_of(id) == CarGarageCatalog.SANAYI:
			in_sanayi.append(id)
	check(same(all_board.listed_ids(), VehicleSort.sort(in_sanayi, VehicleSort.NEWEST,
		get_first_node_in_group("race") as RaceManager)), "BU GARAJ: yalnız SANAYİ'nin araçları")
	all_board.set_this_garage(false)
	var outside: StringName = garages.cars_in(mahalle)[0]
	(all_board.find_child(String(outside), true, false).find_child("Hit", true, false) as Button).pressed.emit()
	await frames(25)
	check(screen.current_garage() == mahalle and screen.shown_vehicle() == outside,
		"başka depodaki araca dokununca o depoya geçildi")
	# YERLEŞTİR: yeni araç gelince yer sorulur
	hud.placement_prompts = true
	own.add_vehicle(&"vw_golf_7")
	var placement: CarPlacementScreen = hud.car_placement_screen
	for i: int in 120:
		if hud.router.top() == &"car_placement":
			break
		await process_frame
	check(hud.router.top() == &"car_placement" and placement.vehicle_id == &"vw_golf_7", "yeni araç: YERLEŞTİR açıldı")
	var here: StringName = garages.garage_of(&"vw_golf_7")
	check(placement.option(CarGarageManager.HOME) != null and placement.option(here) != null and placement.option(here).highlight,
		"seçenekler: GARAJIMA KOY + şu anki depo (amber)")
	check(placement.option(CarGarageManager.WAITING) == null, "depoda yer varken otopark seçeneği yok")
	var other_depot: StringName = CarGarageCatalog.SANAYI if here != CarGarageCatalog.SANAYI else CarGarageCatalog.NEON
	placement.option(other_depot).pressed.emit()
	await frames(20)
	check(garages.garage_of(&"vw_golf_7") == other_depot and hud.router.top() != &"car_placement", "depo seçildi, pano kapandı")
	own.add_vehicle(&"audi_a3")
	for i: int in 120:
		if hud.router.top() == &"car_placement":
			break
		await process_frame
	var default_place: StringName = garages.garage_of(&"audi_a3")
	placement.option(CarGarageManager.HOME).pressed.emit()
	await frames(30)
	var editor: GarageEditor = get_first_node_in_group("garage_editor") as GarageEditor
	check(hud.router.top() == &"garage_edit" and editor != null and editor.placing_item() == GarageDecor.vehicle_item_id(&"audi_a3"),
		"GARAJIMA KOY: düzenleme kipi, araç parmakta")
	editor.cancel_ghost()
	hud.router.close_all()
	await frames(20)
	check(garages.garage_of(&"audi_a3") == default_place, "vazgeçilince araç varsayılan yerinde kaldı")
	# GARAJ DOLU: zemine sığmayan yeni araç YERLEŞTİR açmaz, varsayılan yerinde kalır; DEPO DERSİ yapıldıysa basılabilir
	# bildirim çıkar, dokununca ARAÇLAR o araçla açılır
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var filler: Array[String] = []
	var was: Dictionary = {}   # dolgu aracı → önceki deposu (test sonra eski düzene döner)
	for id: StringName in own.owned_vehicle_ids():
		var item: StringName = GarageDecor.vehicle_item_id(id)
		if garages.garage_of(id) != CarGarageManager.HOME and view.has_room_for(item):
			was[id] = garages.garage_of(id)
			filler.append(view.place_free(item))
	var newcomer: StringName = &""
	for entry: Dictionary in CarCatalog.all():
		if not own.is_owned(entry["id"]) and CarCatalog.is_obtainable(entry["id"]):
			newcomer = entry["id"]
			break
	check(not filler.is_empty() and not view.has_room_for(GarageDecor.vehicle_item_id(newcomer)) and not hud.fits_home(newcomer),
		"zemin doldu: %d araç sergide, yeni araca yer yok" % garages.home_ids().size())
	(get_first_node_in_group("tutorial") as TutorialManager).mark_done(TutorialManager.GARAGES)
	own.add_vehicle(newcomer)
	# YERLEŞTİR sırası 0,4 sn'de bir bakar (başsızda kareler çok kısa); bildirim, sıradaki eski bildirimlerin ardından çıkar
	for i: int in 150:
		if hud.router.top() == &"car_placement" or (hud.get("_notice_action") as Callable).is_valid():
			break
		await create_timer(0.1).timeout
	check(hud.router.top() != &"car_placement" and garages.garage_of(newcomer) != CarGarageManager.HOME,
		"garaj dolu: YERLEŞTİR açılmadı, araç varsayılan yerinde (%s)" % garages.garage_of(newcomer))
	check((hud.get("_notice_action") as Callable).is_valid(), "garaj dolu bildirimi basılabilir")
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	hud.call("_on_notice_input", tap)
	await frames(25)
	check(hud.router.top() == &"garage" and screen.shown_vehicle() == newcomer, "bildirime dokununca ARAÇLAR yeni araçla açıldı")
	hud.router.close_all()
	await frames(20)
	for placed_iid: String in filler:
		decor.remove_instance(placed_iid)
	await frames(2)
	for id: StringName in was:
		if garages.garage_of(id) != was[id]:
			garages.move(id, was[id])
	hud.placement_prompts = false
	hud.router.open(&"garage")
	await frames(20)
	screen.go_to_garage(mahalle)
	await frames(10)

	print("== 9) 3D iç mekân (MAHALLE, SANAYİ, OTOPARK) ==")
	var iv: GarageInteriorView = screen.find_child("InteriorView", true, false)
	var room: Node3D = screen.car_viewport.get_node("Environment")
	check(iv != null and iv.active and iv.interior.garage == &"mahalle", "MAHALLE'de pişmiş iç mekân açık")
	check(not room.visible and not screen.car_slot.visible, "eski oda ve lift gizli")
	var all_parked: bool = true
	for id: StringName in garages.cars_in(CarGarageCatalog.MAHALLE):
		all_parked = all_parked and iv.has_car(id)
	check(all_parked, "garajın araçları park yerlerinde (%d)" % garages.used(CarGarageCatalog.MAHALLE))
	check(iv.get("_focused") == screen.shown_vehicle(), "gösterilen araca odaklanıldı")
	var biases: Dictionary = iv.get("_bias")
	var near_count: int = biases.values().filter(func(b: float) -> bool: return b > GarageInteriorView.LOD_BIAS_FAR).size()
	check(is_equal_approx(float(biases.get(screen.shown_vehicle(), 0.0)), CarRig.LOD_BIAS_GARAGE)
		and near_count <= GarageInteriorView.NEAR_CARS + 1 and biases.size() == (iv.get("_cars") as Dictionary).size(),
		"odaktaki araç tam detay, yakındakiler dışı en kaba LOD")
	check(screen.preview_camera.projection == Camera3D.PROJECTION_PERSPECTIVE, "perspektif kamera")
	var park_before: int = garages.item_level(CarGarageCatalog.MAHALLE, CarGarageCatalog.PARK)
	garages.clock_offset += 4000.0
	garages._check_timers()
	await frames(5)
	var park_now: int = garages.item_level(CarGarageCatalog.MAHALLE, CarGarageCatalog.PARK)
	var model: Node3D = iv.interior.get_child(0) as Node3D
	check(park_now > park_before and (model.get_node("Park_L%d" % park_now) as Node3D).visible
		and not (model.get_node("Park_L%d" % park_before) as Node3D).visible, "PARK YERİ seviyesi sahnede (sv.%d)" % park_now)
	var other: StringName = &""
	for id: StringName in garages.cars_in(CarGarageCatalog.MAHALLE):
		if id != screen.shown_vehicle():
			other = id
	if other != &"":
		iv.car_tapped.emit(other)
		await frames(5)
		check(screen.shown_vehicle() == other and screen.car_list.selected_vehicle() == other, "araca dokununca seçildi")
	var all_scenes: bool = true
	for g: StringName in CarGarageCatalog.ids():
		all_scenes = all_scenes and GarageInterior.has_scene(screen.call("_interior_id", g))
	check(all_scenes, "her deponun pişmiş iç mekânı var")
	screen.go_to_garage(CarGarageCatalog.SANAYI)
	await frames(5)
	check(iv.active and iv.interior.garage == &"sanayi" and not room.visible, "SANAYİ'ye geçince kendi iç mekânı açıldı")
	var own_only: bool = true
	for id: StringName in garages.cars_in(CarGarageCatalog.SANAYI):
		own_only = own_only and iv.has_car(id)
	for id: StringName in garages.cars_in(CarGarageCatalog.MAHALLE):
		own_only = own_only and not iv.has_car(id)
	check(own_only, "SANAYİ'de yalnız kendi araçları")
	check(GarageInterior.has_scene(&"waiting") and screen.call("_interior_id", CarGarageManager.WAITING) == &"waiting",
		"OTOPARK çatı katı sahnesi")
	screen.go_to_garage(CarGarageCatalog.MAHALLE)
	await frames(5)
	check(iv.active, "MAHALLE'ye dönünce iç mekân yeniden açıldı")
	hud.router.close_all()
	await frames(30)
	check(not iv.active and iv.interior == null, "garaj kapanınca iç mekân serbest")
	hud.router.close_all()
	await frames(10)

	print("== 10) Prestij: garaj değeri, rütbe 11–15, açık özet, OTO MANŞET ==")
	check(GarageValue.garages_value(self) == garages.spent_total() and garages.spent_total() > 0,
		"garaj değerinde ARAÇ GARAJLARI kalemi (%d)" % garages.spent_total())
	check(GarageValue.compute(self) == GarageValue.vehicles_value(self) + GarageValue.upgrades_value(self)
		+ GarageValue.bays_value(self) + GarageValue.paint_value(self) + GarageValue.decor_value(self)
		+ GarageValue.garages_value(self) + GarageValue.showcase_value(self), "toplam değer kalemlerin toplamı")
	var showcase: int = 0
	for depot: StringName in garages.owned_garages():
		for id: StringName in garages.cars_in(depot):
			showcase += ceili(float(CarCatalog.get_entry(id).get("price", 0)) * GarageValue.SHOWCASE_RATE)
	check(GarageValue.showcase_value(self) == showcase and showcase > 0, "DEPO VİTRİNİ: depodaki araçların %%10'u (%d)" % showcase)
	check(GarageValue.THRESHOLDS.size() == 15 and GarageValue.RANK_NAMES.size() == 15, "15 rütbe")
	check(GarageValue.rank(1999999) == 10 and GarageValue.rank(2000000) == 11 and GarageValue.rank(5000000) == 12
		and GarageValue.rank(10000000) == 13 and GarageValue.rank(20000000) == 14 and GarageValue.rank(32000000) == 15,
		"eşikler 2 / 5 / 10 / 20 / 32 M")
	check(GarageValue.next_threshold(40000000) == 0 and is_equal_approx(GarageValue.rank_ratio(40000000), 1.0), "15. rütbe en üst")
	check(GarageValue.rank_name(11).ends_with("★") and GarageValue.rank_name(15).ends_with("★★★★★"), "yıldızlı adlar")

	var public: Dictionary = PublicGarage.parse(PublicGarage.to_json(PublicGarage.from_snapshot(save.snapshot())))
	var summary: Dictionary = PublicGarage.car_garage_summary(public)
	check(JSON.stringify(summary) == JSON.stringify(garages.public_summary()), "açık garajda özet (%s)" % JSON.stringify(summary))
	var public_depots: Dictionary = public.get("car_garages", {})
	check(public_depots.keys() == ["garages"] and JSON.stringify(PublicGarage.depot_layout(public))
		== JSON.stringify(PublicGarage.depot_layout(save.snapshot())), "açık garajda depo yerleşimi (ziyaret); süren iş / otopark yok")
	check(not PublicGarage.without_depots(public).has("car_garages")
		and PublicGarage.without_depots(public).has(PublicGarage.SUMMARY_KEY), "JSON sınırında yerleşim düşer, özet kalır")
	var forged: Dictionary = PublicGarage.car_garage_summary({PublicGarage.SUMMARY_KEY: {"own": ["hangar", "uzay_ussu", "mahalle", 7],
		"cap": 99999}})
	check(same(forged.get("own", []), [&"mahalle", &"hangar"]) and int(forged.get("cap", 0)) == CarGarageCatalog.total_max_capacity(),
		"sunucudan gelen özet süzülür")
	check(PublicGarage.car_garage_summary({}).is_empty(), "özetsiz (eski sürüm) garaj: boş")
	var top_name: String = Loc.upper(CarGarageCatalog.display_name(garages.owned_garages().back()))
	check(ProfileCard.garage_text(garages.public_summary()).begins_with(top_name), "profil kartı şeridi en üst garajla başlar")
	check(ProfileCard.garage_text({}).is_empty(), "özetsiz kartta garaj şeridi yok")

	garages.load_state({})
	garages.reconcile()
	progress.load_state(30, 0, 0)
	economy.set_money(30000000)
	garages.purchase(CarGarageCatalog.MAHALLE)   # ilk depo artık satın alınır (§10)
	garages.clock_offset += 1801.0
	garages._check_timers()
	var t0: float = garages.now()
	check(garages.purchase(CarGarageCatalog.SANAYI) and garages.upgrade_item(CarGarageCatalog.MAHALLE, CarGarageCatalog.FLOOR),
		"inşaat ve iç yükseltme başladı")
	var planned: float = t0 + CarGarageCatalog.build_time(CarGarageCatalog.SANAYI)
	garages.clock_offset += 8.0 * 3600.0   # oyun kapalıyken ikisi de bitti
	garages._check_timers()
	var done: Array[Dictionary] = garages.finished_between(t0, garages.now())
	var built: Array[Dictionary] = done.filter(func(d: Dictionary) -> bool: return StringName(d["item"]) == &"")
	check(done.size() == 2 and built.size() == 1 and absf(float(built[0]["at"]) - planned) < 2.0,
		"biten işler günlüğü: planlanan bitişle (açılış anı değil)")
	var garage_kinds: Callable = func(list: Array[Dictionary]) -> Array:
		return list.filter(func(n: Dictionary) -> bool: return [NewsDigest.GARAGE_BUILT, NewsDigest.GARAGE_UPGRADED].has(n["kind"])) \
			.map(func(n: Dictionary) -> StringName: return StringName(n["kind"]))
	var kinds: Array = garage_kinds.call(NewsSources.local(self, int(t0), int(garages.now()) + 1))
	check(kinds.has(NewsDigest.GARAGE_BUILT) and kinds.has(NewsDigest.GARAGE_UPGRADED), "OTO MANŞET: biten inşaat ve iç yükseltme")
	check((garage_kinds.call(NewsSources.local(self, int(garages.now()) + 10, int(garages.now()) + 100)) as Array).is_empty(),
		"pencere dışındaki iş haber olmaz")
	save.save_game()
	garages.reset()
	save.load_game()
	check(garages.finished_between(t0, garages.now()).size() == 2, "biten işler günlüğü kayıtta")

	var samples: Array[Dictionary] = [{"kind": NewsDigest.GARAGE_BUILT, "garage": CarGarageCatalog.SANAYI},
		{"kind": NewsDigest.GARAGE_UPGRADED, "garage": CarGarageCatalog.MAHALLE, "item": CarGarageCatalog.FLOOR},
		{"kind": NewsDigest.FRIEND_GARAGE, "people": [{"uid": "u1", "name": "Elif"}], "garage": CarGarageCatalog.HANGAR}]
	for sample: Dictionary in samples:
		var one: Array[Dictionary] = [sample]
		var item: Dictionary = NewsDigest.merge(one)[0]
		check(not NewsDigest.title(item, 0).is_empty() and not NewsDigest.title(item, 1).is_empty() and not NewsDigest.deck(item).is_empty()
			and not NewsDigest.brief(item).is_empty() and not NewsDigest.section(item).is_empty()
			and not NewsDigest.caption(item).is_empty(), "%s metinleri (%s)" % [sample["kind"], NewsDigest.title(item, 0)])
	var hangar_name: String = Loc.upper(CarGarageCatalog.display_name(CarGarageCatalog.HANGAR))
	var friend_item: Array[Dictionary] = [samples[2]]
	check(NewsDigest.title(NewsDigest.merge(friend_item)[0], 0).contains(hangar_name), "arkadaş haberinde garajın adı")
	var two_built: Array[Dictionary] = [samples[0], {"kind": NewsDigest.GARAGE_BUILT, "garage": CarGarageCatalog.NEON}]
	var merged_built: Dictionary = NewsDigest.merge(two_built)[0]
	check(int(merged_built["count"]) == 2 and StringName(merged_built["garage"]) == CarGarageCatalog.NEON,
		"iki inşaat tek haber, en üst garaj öne çıkar")

	var person: Callable = func(uid: String, entry: Dictionary) -> Dictionary:
		return {"uid": uid, "name": SaveSafe.s(entry.get("name", ""))}
	var friend: Dictionary = {"uid": "u1", "name": "Elif", "garages": {"own": ["mahalle", "sanayi", "showroom"], "cap": 30}}
	var friend_news: Array[Dictionary] = []
	var base1: Dictionary = SocialManager.friend_garage_news([friend], {}, friend_news, person)
	check(friend_news.is_empty() and same(base1.get("u1", []), [&"showroom"]), "yeni arkadaş: haber yok, lüks garajları tabana")
	(friend["garages"]["own"] as Array).append("hangar")
	var base2: Dictionary = SocialManager.friend_garage_news([friend], base1, friend_news, person)
	check(friend_news.size() == 1 and friend_news[0]["kind"] == NewsDigest.FRIEND_GARAGE
		and StringName(friend_news[0]["garage"]) == CarGarageCatalog.HANGAR, "arkadaş UÇAK HANGARI aldı: haber")
	friend_news.clear()
	SocialManager.friend_garage_news([friend], base2, friend_news, person)
	check(friend_news.is_empty(), "aynı garaj ikinci kez haber olmaz")
	var base3: Dictionary = SocialManager.friend_garage_news([{"uid": "u1"}], base2, friend_news, person)
	check(friend_news.is_empty() and same(base3.get("u1", []), base2["u1"]), "özeti okunamayan arkadaşın tabanı korunur")
	SocialManager.friend_garage_news([{"uid": "u2", "garages": {"own": ["mahalle", "sanayi", "neon"], "cap": 20}}], {"u2": []},
		friend_news, person)
	check(friend_news.is_empty(), "SANAYİ / NEON haber olmaz")
	save.new_game()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
