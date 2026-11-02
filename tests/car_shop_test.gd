extends SceneTree
## ARAÇ MAĞAZASI (2026-11-02): fiyatlar (onaylanan tablo + yeni araç formülü), satış kapsamı, durum / engeller, GEMLE hemen
## alım, ₺ SİPARİŞİ (24 saat), ödüllü reklamla 8 saat kısaltma (3 reklam = hemen), zamanla teslim, araç başka yoldan gelince
## iade, kayıt turu ve showroom ARAÇLAR sekmesi (B taslağı: sekme, süzgeç çipleri, kartlar, EMİN MİSİN?, YOLDA çipi).
## Çalıştırma: tools/run_tests.sh car_shop_test

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
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var shop: CarShop = get_first_node_in_group("car_shop")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	var eco: EconomyManager = get_first_node_in_group("economy")
	var progress: PlayerProgress = get_first_node_in_group("player_progress")
	var missions: MissionManager = get_first_node_in_group("missions")
	check(shop != null, "CarShop GarageSystem'de kuruldu")
	shop.test_now = 1_800_000_000

	print("== 1) Katalog ve fiyat ==")
	check(CarShop.ids().size() == 48, "mağazada 48 araç (kasa havuzları; %d)" % CarShop.ids().size())
	check(not CarShop.is_for_sale(&"tofas_murat_124") and not CarShop.is_for_sale(&"tofas_sahin")
		and not CarShop.is_for_sale(&"police_bentley"), "hurdalık klasiği, başlangıç aracı ve polis satılmaz")
	check(CarShop.tl_price(&"opel_corsa") == 32000 and CarShop.gem_price(&"opel_corsa") == 65, "CORSIA 32.000 ₺ / 65 gem")
	check(CarShop.tl_price(&"honda_civic") == 144000 and CarShop.gem_price(&"honda_civic") == 80, "CIVITA 144.000 ₺ / 80 gem")
	check(CarShop.is_gem_only(&"honda_nsx") and CarShop.tl_price(&"honda_nsx") == 0 and CarShop.gem_price(&"honda_nsx") == 550,
		"NZX yalnız gem: 550")
	var only: int = 0
	for id: StringName in CarShop.ids():
		only += 1 if CarShop.is_gem_only(id) else 0
	check(only == 14, "yalnız gem araç sayısı 14 (%d)" % only)
	check(CarShop.gem_price(&"bugatti_chiron") == 5400 and CarShop.is_gem_only(&"audi_rs6"), "CHIRAL 5.400 gem; SÜPER KASA hep gem")
	check(CarShop.family_of(&"honda_civic") == &"sport_crate" and CarShop.delivery_seconds() == 86400
		and CarShop.ad_cut_seconds() == 28800, "aile SPOR, teslim 24 sa, reklam 8 sa")
	# Tabloda olmayan araç formülle fiyatlanır (yeni araç eklenince)
	var formula_path: String = "user://car_shop_formula.json"
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CarShop.DATA_PATH))
	raw["cars"] = {}
	var file: FileAccess = FileAccess.open(formula_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(raw))
	file.close()
	CarShop.load_from(formula_path)
	check(CarShop.tl_price(&"honda_civic") == 144000 and CarShop.gem_price(&"honda_civic") == 80,
		"formül: değer × epik 2 = 144.000; gem = ₺ ÷ (sv18 × 100) → 80")
	check(CarShop.gem_price(&"bugatti_chiron") == 5400 and not CarShop.is_gem_only(&"honda_nsx"),
		"formül: SÜPER KASA yalnız gem (900.000 × 3 ÷ 500); listede olmayan NZX ₺'ye de açık")
	CarShop.load_from()

	print("== 2) Durum ve engeller ==")
	progress.level = 1
	check(shop.state_of(&"honda_civic") == CarShop.State.LOCKED and shop.money_block(&"honda_civic") == CarShop.BLOCK_LEVEL,
		"seviye 1: CIVITA kilitli (sv18)")
	progress.level = 40
	check(shop.state_of(&"honda_civic") == CarShop.State.AVAILABLE, "seviye 40: alınabilir")
	check(shop.money_block(&"honda_nsx") == CarShop.BLOCK_GEM_ONLY and not shop.order_with_money(&"honda_nsx"),
		"yalnız gem araç ₺ ile sipariş edilemez")
	check(shop.state_of(&"tofas_murat_124") == CarShop.State.NOT_FOR_SALE, "hurdalık aracı mağazada yok")

	print("== 3) Gemle hemen ==")
	progress.add_gems(1000 - progress.gems)
	var bought_before: int = missions.value_of(&"cars_bought") if missions else 0
	check(shop.buy_with_gems(&"honda_civic") and own.is_owned(&"honda_civic") and progress.gems == 920,
		"80 gem düştü, CIVITA hemen sende")
	check(missions == null or missions.value_of(&"cars_bought") == bought_before + 1, "görev sayacı: cars_bought +1")
	check(shop.state_of(&"honda_civic") == CarShop.State.OWNED and not shop.buy_with_gems(&"honda_civic"),
		"sahip olunan araç ikinci kez alınmaz")
	progress.spend_gems(progress.gems - 10)
	check(shop.gem_block(&"seat_leon") == CarShop.BLOCK_GEMS and not shop.buy_with_gems(&"seat_leon"), "gem yetmezse alınmaz")

	print("== 4) ₺ siparişi, reklam, teslim ==")
	eco.set_money(500_000)
	check(shop.order_with_money(&"vw_golf_7") and eco.money == 370_000 and not own.is_owned(&"vw_golf_7")
		and shop.is_ordered(&"vw_golf_7"), "130.000 ₺ düştü, GOLFER yolda (henüz sende değil)")
	check(shop.time_left(&"vw_golf_7") == 86400, "teslime 24 saat")
	check(shop.gem_block(&"vw_golf_7") == CarShop.BLOCK_ORDERED and not shop.order_with_money(&"vw_golf_7"),
		"yoldaki araç ikinci kez alınmaz")
	var delivered: Array[StringName] = []
	shop.delivered.connect(func(id: StringName) -> void: delivered.append(id))
	shop.cut_with_ad(&"vw_golf_7")
	check(shop.time_left(&"vw_golf_7") == 57600 and shop.ad_cut_for(&"vw_golf_7") == 28800, "1. reklam: 16 saat kaldı")
	shop.cut_with_ad(&"vw_golf_7")
	check(shop.time_left(&"vw_golf_7") == 28800, "2. reklam: 8 saat kaldı")
	shop.cut_with_ad(&"vw_golf_7")
	check(own.is_owned(&"vw_golf_7") and not shop.is_ordered(&"vw_golf_7") and delivered == [&"vw_golf_7"],
		"3. reklam: GOLFER hemen geldi")
	check(shop.order_with_money(&"seat_leon"), "SEDRA LEONA sipariş edildi")
	shop.test_now += 86399
	shop.check_deliveries()
	check(not own.is_owned(&"seat_leon"), "24 saat dolmadan gelmez")
	shop.test_now += 1
	shop.check_deliveries()
	check(own.is_owned(&"seat_leon") and delivered.has(&"seat_leon"), "24 saat dolunca geldi")

	print("== 5) Başka yoldan gelen araç: iade ==")
	var refunds: Array[int] = []
	shop.refunded.connect(func(_id: StringName, amount: int) -> void: refunds.append(amount))
	var money: int = eco.money
	shop.order_with_money(&"toyota_ae86")
	own.add_vehicle(&"toyota_ae86")   # bu arada kasadan çıktı
	shop.test_now += 86400
	shop.check_deliveries()
	check(refunds == [112000] and eco.money == money, "TRUENZO zaten sende: 112.000 ₺ iade edildi")

	print("== 6) Kayıt ==")
	shop.order_with_money(&"bmw_f30")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(shop.state()))
	shop.reset()
	check(shop.order_count() == 0, "sıfırlandı")
	shop.load_state(saved)
	check(shop.is_ordered(&"bmw_f30") and shop.time_left(&"bmw_f30") == 86400, "kayıt turu: sipariş ve teslim anı korundu")
	shop.load_state({"orders": [{"id": "yok_boyle", "price": 5}, {"id": "bmw_f30", "price": 1, "ordered_at": 100,
		"ready_at": 9_999_999_999}, {"id": "bmw_f30", "price": 2}]})
	await frames(2)
	check(shop.order_count() == 0 and own.is_owned(&"bmw_f30"),
		"bozuk / tekrarlı sipariş atıldı, uzak tarih 24 saate kırpıldı (süresi geçti, geldi)")

	print("== 7) Showroom ARAÇLAR sekmesi ==")
	var hud: Hud = main.find_child("HUD", true, false)
	var showroom: ShowroomScreen = hud.showroom
	progress.level = 16
	eco.set_money(1_000_000)
	progress.add_gems(500)
	hud.router.open(&"showroom")
	await frames(6)
	var tab_cars: PlateButton = showroom.get("_tab_cars")
	tab_cars.button_pressed = true
	await frames(4)
	var tray: Control = showroom.get("_tray")
	var list: Control = showroom.get("_list_group")
	check(showroom.current_tab() == ShowroomScreen.Tab.CARS and tray.visible and not list.visible, "ARAÇLAR: raf açık, kasa listesi gizli")
	var chips: Dictionary = showroom.get("_chips")
	check(chips.has(ShowroomScreen.CHIP_ALL) and chips.has(&"city_crate") and chips.has(&"super_crate"), "süzgeç çipleri: TÜMÜ + kasa aileleri")
	check(showroom.get("_family") == &"sport_crate", "sv16: SPOR ailesi seçili açıldı")
	var cards: Dictionary = showroom.get("_cards")
	check(cards.size() == 12, "SPOR'da 12 kart (%d)" % cards.size())
	(cards[&"bmw_e46"] as PlateButton).button_pressed = true
	await frames(3)
	var cash: PlateButton = showroom.get("_cash_button")
	var gem: PlateButton = showroom.get("_gem_button")
	check(showroom.shown_vehicle() == &"bmw_e46" and cash.visible and gem.visible and cash.text.contains("255.000"),
		"BMR 3.46: ₺ ve gem düğmeleri (%s)" % cash.text.replace("\n", " / "))
	var ordered: Array[StringName] = []
	showroom.vehicle_ordered.connect(func(id: StringName) -> void: ordered.append(id))
	cash.pressed.emit()
	await frames(1)
	check(cash.text.begins_with(Loc.t("EMİN MİSİN?").split("\n")[0]) and not shop.is_ordered(&"bmw_e46"), "ilk dokunuş: EMİN MİSİN?")
	cash.pressed.emit()
	await frames(3)
	check(shop.is_ordered(&"bmw_e46") and ordered == [&"bmw_e46"], "ikinci dokunuş: sipariş verildi")
	chips = showroom.get("_chips")
	check(chips.has(ShowroomScreen.CHIP_ORDERS), "YOLDA çipi geldi")
	var ad: AdOfferButton = showroom.get("_ad_button")
	check(not cash.is_visible_in_tree() and ad.condition.call(), "yoldaki araçta ödeme düğmesi yok, reklam teklifi var")
	for i: int in 3:
		showroom.call("_on_delivery_ad")
	await frames(3)
	check(own.is_owned(&"bmw_e46") and cash.text == Loc.t("SAHİPSİN"), "3 reklam: BMR 3.46 geldi, plaka SAHİPSİN")
	cards = showroom.get("_cards")
	(cards[&"cupra_formentor"] as PlateButton).button_pressed = true
	await frames(2)
	check(cash.disabled and cash.text == Loc.t("SEVİYE %d\nGEREKLİ") % 22, "sv22 araç kilitli")
	(showroom.get("_chips")[&"super_crate"] as PlateButton).button_pressed = true
	await frames(3)
	check(showroom.shown_vehicle() == &"audi_rs6" and cash.text == Loc.t("SEVİYE %d\nGEREKLİ") % 28 and not gem.visible,
		"SÜPER, sv16: ilk araç RX6 kilitli (sv28)")
	progress.level = 40
	progress.add_gems(1000)
	showroom.call("_refresh_state")
	await frames(1)
	check(not cash.visible and gem.visible and gem.text == Loc.t("%d GEM\nHEMEN GELİR") % 550, "sv40: RX6 yalnız gem, 550 GEM")
	var tab_crates: PlateButton = showroom.get("_tab_crates")
	tab_crates.button_pressed = true
	await frames(3)
	check(showroom.current_tab() == ShowroomScreen.Tab.CRATES and list.visible and not tray.visible
		and showroom.shown_crate() != &"", "KASALAR'a dönüş: liste ve kasa geri geldi")
	hud.router.close_all()
	await frames(3)
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
