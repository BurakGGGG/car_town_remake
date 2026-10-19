extends SceneTree
## TÜM ARAÇLAR (docs/GARAJLAR_TASARIM.md §1) — araç başına yarış / galibiyet sayacı (RaceManager + kayıt turu),
## VehicleSort süzgeç ve sıralama kuralları, garajın TÜM ARAÇLAR plakası ve panonun kendisi (kart = sonuç,
## karta dokununca araç lifte çıkar).
## Çalıştırma: tools/run_tests.sh all_cars_test
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

	print("== 1) Sayaç kaydı: JSON turu ve bozuk veri ==")
	var race: RaceManager = RaceManager.new()
	race.load_state({"races": 9, "wins": 4, "cars": {
		"tofas_sahin": {"r": 5, "w": 2},
		"lambo_huracan": {"r": 3, "w": 9},     # galibiyet yarıştan çok olamaz
		"bmw_e46": {"r": -2, "w": 1},         # eksi → yok
		"yok_boyle_arac": {"r": 4, "w": 1},   # katalogda yok
		"renault_toros": "bozuk",
	}})
	check(race.vehicle_races(&"tofas_sahin") == 5 and race.vehicle_wins(&"tofas_sahin") == 2, "geçerli sayaç yüklendi")
	check(race.vehicle_races(&"lambo_huracan") == 3 and race.vehicle_wins(&"lambo_huracan") == 3, "galibiyet yarışla sınırlı")
	check(race.vehicle_races(&"bmw_e46") == 0, "eksi sayı yok sayılır")
	check(race.vehicle_races(&"yok_boyle_arac") == 0, "katalogda olmayan araç yok sayılır")
	check(race.vehicle_races(&"renault_toros") == 0, "bozuk satır yok sayılır")
	var copy: RaceManager = RaceManager.new()
	copy.load_state(JSON.parse_string(JSON.stringify(race.state())))
	check(copy.vehicle_races(&"tofas_sahin") == 5 and copy.vehicle_wins(&"lambo_huracan") == 3, "JSON turundan sonra aynı")
	copy.load_state({"races": 2})
	check(copy.vehicle_races(&"tofas_sahin") == 0, "bölümsüz kayıt → sayaçsız")
	race.reset()
	check(race.vehicle_races(&"tofas_sahin") == 0, "reset sayaçları siler")
	race.free()
	copy.free()

	print("== 2) Oyun içinde: yarış sayılır, kayda yazılır ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var live: RaceManager = get_first_node_in_group("race") as RaceManager
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	save.new_game()
	await frames(2)
	for id: StringName in [&"tofas_sahin", &"bmw_e46", &"lambo_huracan", &"renault_toros"]:
		own.add_vehicle(id)
	var owned: Array[StringName] = own.owned_vehicle_ids()
	check(owned.size() >= 4, "dört araç garajda (%d)" % owned.size())
	own.set_race_vehicle(&"bmw_e46")
	for won: bool in [true, false, true]:
		live._reward_paid = false
		live.finish_race(won)
	own.set_race_vehicle(&"renault_toros")
	live._reward_paid = false
	live.finish_race(false)
	check(live.vehicle_races(&"bmw_e46") == 3 and live.vehicle_wins(&"bmw_e46") == 2, "yarış aracına yazıldı (3 yarış, 2 galibiyet)")
	check(live.vehicle_races(&"renault_toros") == 1 and live.vehicle_wins(&"renault_toros") == 0, "araç değişince yenisine yazıldı")
	check(live.races() == 4 and live.wins() == 2, "toplam sayaç da işledi")
	save.save_game()
	live.reset()
	save.load_game()
	check(live.vehicle_races(&"bmw_e46") == 3 and live.vehicle_wins(&"bmw_e46") == 2, "kayıttan geri geldi")

	print("== 3) VehicleSort ==")
	var newest: Array[StringName] = VehicleSort.sort(owned, VehicleSort.NEWEST, live)
	check(newest[0] == owned.back() and newest.back() == owned[0], "SON EKLENEN: en son alınan önde")
	var fastest: Array[StringName] = VehicleSort.sort(owned, VehicleSort.FASTEST, live)
	var ordered: bool = true
	for i: int in fastest.size() - 1:
		if PerformanceMods.time_300(fastest[i]) > PerformanceMods.time_300(fastest[i + 1]):
			ordered = false
	check(ordered and fastest[0] == &"lambo_huracan", "EN HIZLI: 300 m süresi küçük önde (%s)" % fastest[0])
	var raced: Array[StringName] = VehicleSort.sort(owned, VehicleSort.MOST_RACED, live)
	check(raced[0] == &"bmw_e46" and raced[1] == &"renault_toros", "EN ÇOK YARIŞILAN: 3 > 1 > 0")
	var winners: Array[StringName] = VehicleSort.sort(owned, VehicleSort.MOST_WINS, live)
	check(winners[0] == &"bmw_e46", "EN ÇOK KAZANAN: bmw önde")
	var valued: Array[StringName] = VehicleSort.sort(owned, VehicleSort.VALUE, live)
	ordered = true
	for i: int in valued.size() - 1:
		if own.price(valued[i]) < own.price(valued[i + 1]):
			ordered = false
	check(ordered, "EN DEĞERLİ: fiyat azalan")
	# Eşitlik: sıfır yarışlılar ada göre (her açılışta aynı sıra)
	var zero: Array[StringName] = []
	for id: StringName in raced:
		if live.vehicle_races(id) == 0:
			zero.append(id)
	var names_sorted: bool = true
	for i: int in zero.size() - 1:
		var a: String = String(CarCatalog.get_entry(zero[i])["display_name"])
		var b: String = String(CarCatalog.get_entry(zero[i + 1])["display_name"])
		if a.naturalnocasecmp_to(b) > 0:
			names_sorted = false
	check(names_sorted, "eşitlikte ada göre")
	var klass: String = PerformanceMods.class_of(&"lambo_huracan")
	var by_class: Array[StringName] = VehicleSort.filter(owned, klass, &"")
	check(by_class.has(&"lambo_huracan") and not by_class.has(&"tofas_sahin"), "SINIF süzgeci (%s)" % klass)
	var rarity: StringName = CrateCatalog.rarity_of(&"bmw_e46")
	var by_rarity: Array[StringName] = VehicleSort.filter(owned, "", rarity)
	var rarity_ok: bool = by_rarity.has(&"bmw_e46")
	for id: StringName in by_rarity:
		rarity_ok = rarity_ok and CrateCatalog.rarity_of(id) == rarity
	check(rarity_ok, "NADİRLİK süzgeci (%s)" % rarity)
	check(VehicleSort.filter(owned, "", &"") == owned, "süzgeçsiz → hepsi, sıra korunur")
	check(VehicleSort.metric_text(&"bmw_e46", VehicleSort.MOST_RACED, live) == Loc.t("%d YARIŞ") % 3, "kart ölçüsü: yarış sayısı")

	print("== 4) Garaj: TÜM ARAÇLAR plakası ve pano ==")
	var hud: Hud = main.find_child("HUD", true, false)
	var garage: GarageScreen = hud.garage_screen
	hud.router.open(&"garage")
	await frames(20)
	var button: PlateButton = garage.find_child("AllCarsButton", true, false)
	check(button != null and button.is_visible_in_tree(), "TÜM ARAÇLAR plakası şeridin yanında")
	check(button != null and button.text.ends_with(str(owned.size())), "plakada araç sayısı (%s)" % (button.text if button else ""))
	var strip: Control = garage.find_child("StripRow", true, false)
	check(strip != null and strip.is_ancestor_of(garage.car_list), "şerit ve plaka aynı satırda")
	button.pressed.emit()
	await frames(20)
	var board: AllCarsScreen = hud.all_cars_screen
	check(hud.router.top() == &"all_cars" and board.visible, "pano açıldı, garaj altta")
	check(hud.router.current_place() == &"garage", "garaj YER olarak açık kaldı")
	board.set_query("", &"", VehicleSort.MOST_RACED)
	await frames(2)
	check(board.listed_ids() == VehicleSort.sort(owned, VehicleSort.MOST_RACED, live), "kartlar = sıralama sonucu")
	var metric: Label = board.find_child("bmw_e46", true, false).find_child("Metric", true, false)
	check(metric != null and metric.text.contains(Loc.t("%d YARIŞ") % 3), "kartta yarış sayısı")
	board.set_query(klass, &"", VehicleSort.FASTEST)
	await frames(2)
	check(board.listed_ids() == VehicleSort.sort(by_class, VehicleSort.FASTEST, live), "süzgeçli kartlar")
	board.set_query("S" if klass != "S" else "D", &"legendary", VehicleSort.NEWEST)
	await frames(2)
	var empty: Array[StringName] = VehicleSort.filter(owned, "S" if klass != "S" else "D", &"legendary")
	var empty_label: bool = false
	for label: Node in board.find_children("*", "Label", true, false):
		if (label as Label).text == Loc.t("BU FİLTREYE UYAN ARAÇ YOK"):
			empty_label = (label as Label).is_visible_in_tree()
	check(board.listed_ids().size() == empty.size() and (empty_label == empty.is_empty()), "boş sonuçta 'araç yok' yazısı")
	# Açılır liste: SIRALA plakası seçenekleri açar, seçim panoyu yeniler
	board.set_query("", &"", VehicleSort.NEWEST)
	await frames(2)
	(board.find_child("SortButton", true, false) as PlateButton).pressed.emit()
	await frames(2)
	var catcher: Control = board.find_child("MenuCatcher", true, false)
	check(catcher.visible, "SIRALA listesi açıldı")
	var option: PlateButton = board.find_child("Option_value", true, false)
	check(option != null and option.is_visible_in_tree(), "EN DEĞERLİ seçeneği görünüyor")
	option.pressed.emit()
	await frames(2)
	check(not catcher.visible and board.listed_ids() == valued, "seçilince liste kapandı, EN DEĞERLİ sırası")
	# Karta dokun: pano kapanır, araç lifte çıkar
	var target: StringName = &"renault_toros" if garage.shown_vehicle() != &"renault_toros" else &"tofas_sahin"
	var card: Control = board.find_child(String(target), true, false)
	(card.find_child("Hit", true, false) as Button).pressed.emit()
	await frames(30)
	check(not board.visible and hud.router.top() == &"garage", "karta dokununca pano kapandı")
	check(garage.shown_vehicle() == target, "seçilen araç lifte çıktı (%s)" % garage.shown_vehicle())
	check(garage.car_list.selected_vehicle() == target, "alt şeritte de seçili")
	# Modifiye kipinde şerit ve plaka birlikte gizlenir
	garage.open_mods()
	await frames(5)
	check(not button.is_visible_in_tree(), "MODİFİYE kipinde TÜM ARAÇLAR gizli")
	garage.call("_close_mods")
	await frames(5)
	check(button.is_visible_in_tree(), "modifiyeden çıkınca geri geldi")
	save.new_game()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
