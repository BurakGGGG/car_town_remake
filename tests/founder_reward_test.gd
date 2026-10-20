extends SceneTree
## ÖN KAYIT ÖDÜLÜ — FounderReward + kurucu eşyası TAŞTAKİ ALTIN ANAHTAR: katalogda var ama SATILMAZ, sahibi
## olmayanın paletinde görünmez; Play'den gelen ödül (sahte Play) 10.000 ₺ + 100 elmas + eşyayı BİR KEZ verir,
## eşya garaja kendiliğinden konur ve ışıltı alır, satın alma Play'de tüketilir. İkinci belirteç, kayıt turu,
## yeni oyun (cihaz defteri) ve buluttan eski kayıt (carry_over) kuralları.
## Gerçek düğümlerle koşar (Main.tscn; masaüstü debug'da PurchaseManager sahte Play kullanır).
##   tools/run_tests.sh founder_reward_test

const D: StringName = FounderReward.DECOR

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var economy: EconomyManager
var player: PlayerProgress
var pm: PurchaseManager
var mock: MockBillingClient
var granted: Array[Dictionary] = []
var first_purchase: Dictionary = {}
var ledger_after_grant: Dictionary = {}


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PurchaseManager.DEVICE_LEDGER_PATH))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	decor = get_first_node_in_group("decor")
	view = get_first_node_in_group("garage_decor_view")
	economy = get_first_node_in_group("economy")
	player = get_first_node_in_group("player_progress")
	pm = get_first_node_in_group("purchases")
	mock = pm.client() as MockBillingClient if pm else null
	_catalog()
	_not_for_sale()
	await _grant()
	await _second_token()
	_save_load()
	await _new_game()
	_carry_over()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _in_palette() -> bool:
	return GarageDecor.shop_order(GarageDecor.Kind.LUXURY).any(func(i: Dictionary) -> bool: return i["id"] == D)


func _catalog() -> void:
	print("== 1) Katalog ==")
	check(GarageDecor.exists(D) and GarageDecor.is_exclusive(D), "kurucu eşyası katalogda, exclusive")
	check(DecorBuilder.has_model(D), "modeli var (assets/decor/%s.glb)" % D)
	check(GarageDecor.placement(D) == GarageDecor.PLACE_FLOOR, "zemine konur")
	check(not GarageDecor.all().any(func(i: Dictionary) -> bool: return i["id"] == D), "mağaza listesinde (all) yok")
	check(not _in_palette(), "sahibi olmayanın paletinde (LÜKS) yok")
	var size: Vector2 = view.footprint_size(D)
	check(size.x <= DecorGrid.CELL and size.y <= DecorGrid.CELL, "tek kareye sığar (%.3f x %.3f, kare %.3f)" % [
		size.x, size.y, DecorGrid.CELL])
	check(not GarageDecor.is_exclusive(&"lux_gold_gas_pump"), "sıradan lüks eşya exclusive değil")


func _not_for_sale() -> void:
	print("== 2) Satılmaz ==")
	var money: int = economy.money
	var gems: int = player.gems
	check(not decor.can_purchase(D), "satın alınamaz")
	check(not decor.purchase(D) and decor.owned_of(D) == 0, "satın alma reddedildi, depoya girmedi")
	check(economy.money == money and player.gems == gems, "para / elmas değişmedi")


func _grant() -> void:
	print("== 3) Play'den ödül ==")
	check(mock != null, "sahte Play bağlı")
	if mock == null:
		return
	pm.founder_reward_granted.connect(func(summary: Dictionary) -> void: granted.append(summary))
	var money: int = economy.money
	var gems: int = player.gems
	var value: int = decor.value()
	first_purchase = mock.make_purchase(String(FounderReward.PRODUCT_ID))
	first_purchase["order_id"] = ""   # Play şartı: ödülde sipariş no'su olmayabilir
	mock.owned.append(first_purchase.duplicate(true))
	mock.query_purchases(BillingClient.ProductType.INAPP)
	await frames(8)
	check(economy.money == money + FounderReward.MONEY, "+10.000 ₺ (%d → %d)" % [money, economy.money])
	check(player.gems == gems + FounderReward.GEMS, "+100 elmas (%d → %d)" % [gems, player.gems])
	check(decor.owned_of(D) == 1 and decor.value() == value + 30000, "kurucu eşyası depoda, garaj değeri +30.000")
	check(pm.was_bought(FounderReward.PRODUCT_ID), "deftere yazıldı")
	check(mock.owned.is_empty(), "Play'de tüketildi")
	check(granted.size() == 1 and String(granted[0].get("title", "")) == "ÖN KAYIT ÖDÜLÜ!" \
		and (granted[0].get("crates", []) as Array).has("TAŞTAKİ ALTIN ANAHTAR"), "duyuru özeti %s" % [granted])
	check(decor.placed_of(D) == 1, "garaja kendiliğinden kondu")
	for inst: Dictionary in decor.instances():
		if inst["item"] == D:
			check(view.is_valid(D, inst["pos"], float((inst["rot"] as Vector3).y), String(inst["iid"])),
				"konduğu yer geçerli %s" % [inst["pos"]])
	check(_in_palette(), "sahibinin paletinde görünür")
	await frames(4)
	var sparkles: LuxurySparkles = view.find_child("LuxurySparkles", true, false) as LuxurySparkles
	check(sparkles != null and sparkles.multimesh.instance_count >= LuxurySparkles.PER_ITEM, "lüks ışıltısı alır")
	ledger_after_grant = JSON.parse_string(JSON.stringify(pm.state()))


func _second_token() -> void:
	print("== 4) İkinci belirteç ödülü yinelemez ==")
	if mock == null:
		return
	var money: int = economy.money
	var gems: int = player.gems
	mock.owned.append(mock.make_purchase(String(FounderReward.PRODUCT_ID)))
	mock.query_purchases(BillingClient.ProductType.INAPP)
	await frames(8)
	check(economy.money == money and player.gems == gems and decor.owned_of(D) == 1, "para / elmas / eşya aynı")
	check(mock.owned.is_empty() and granted.size() == 1, "yalnızca tüketildi, duyuru yok")


func _save_load() -> void:
	print("== 5) Kayıt ==")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(decor.state()))
	var forged: Dictionary = saved.duplicate(true)
	(forged["owned"] as Dictionary)[String(D)] = 5
	decor.load_state(forged)
	check(decor.owned_of(D) == 1, "kayıtta 5 yazsa da tek kopya")
	decor.reset()
	check(decor.owned_of(D) == 0 and not _in_palette(), "yeni oyun: eşya ve palet kartı gitti")
	decor.load_state(saved)
	check(decor.owned_of(D) == 1 and decor.placed_of(D) == 1 and _in_palette(), "kayıttan geri geldi, yerinde")


func _new_game() -> void:
	print("== 6) Yeni oyun: aynı satın alma ikinci kez vermez (cihaz defteri) ==")
	if mock == null:
		return
	pm.reset()
	decor.reset()
	economy.set_money(0)
	player.load_state(1, 0, 0)
	mock.owned.append(first_purchase.duplicate(true))   # Play aynı (tüketilmemiş görünen) ödülü yine getirdi
	mock.query_purchases(BillingClient.ProductType.INAPP)
	await frames(8)
	check(economy.money == 0 and player.gems == 0 and decor.owned_of(D) == 0, "ödül yeni oyuna verilmedi")
	check(mock.owned.is_empty(), "yalnızca tüketildi")


func _carry_over() -> void:
	print("== 7) Buluttan eski kayıt: ödül korunur (carry_over) ==")
	if ledger_after_grant.is_empty():
		check(false, "defter yok")
		return
	var added: int = pm.carry_over(ledger_after_grant)
	check(added == FounderReward.GEMS and player.gems == FounderReward.GEMS, "elması geri geldi (%d)" % player.gems)
	check(economy.money == FounderReward.MONEY and decor.owned_of(D) == 1, "parası ve eşyası geri geldi")
	check(pm.carry_over(ledger_after_grant) == 0 and decor.owned_of(D) == 1, "ikinci kez eklenmez")
