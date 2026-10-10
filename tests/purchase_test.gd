extends SceneTree
## GEM SATIN ALMA TESTİ — GemProducts kataloğu, PurchaseManager ödeme sözleşmesi (sahte Play ile):
## başarılı / iptal / hata / bekleyen ödeme, tek seferlik paket, yarıda kalan tüketme, cihaz defteri,
## bulut kaydında satın almanın korunması (SaveManager.apply_snapshot). Gerçek eklenti gerekmez.
## Çalıştırma: tools/run_tests.sh purchase_test
var fails: int = 0

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _make(mock: MockBillingClient) -> PurchaseManager:
	var pm: PurchaseManager = PurchaseManager.new()
	pm.use_client(mock)
	root.add_child(pm)
	return pm

func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PurchaseManager.DEVICE_LEDGER_PATH))

	print("== 1) Katalog ==")
	var ids: PackedStringArray = GemProducts.ids()
	var unique: Dictionary = {}
	for id: String in ids:
		unique[id] = true
	check(unique.size() == ids.size() and ids.size() >= 4, "ürün kimlikleri benzersiz (%d)" % ids.size())
	var name_ok: bool = true
	for id: String in ids:
		name_ok = name_ok and id == id.to_lower() and not " " in id   # Play kimlik kuralı: küçük harf, rakam, _ .
	check(name_ok, "kimlikler Play biçiminde")
	check(GemProducts.is_once(GemProducts.STARTER) and not GemProducts.is_once(&"gems_pack_1"), "yalnızca başlangıç paketi tek seferlik")
	var last_rate: float = 0.0
	var rate_ok: bool = true
	for entry: Dictionary in GemProducts.PRODUCTS:
		if bool(entry["once"]):
			continue
		var rate: float = float(entry["gems"]) / float(entry["usd"])
		rate_ok = rate_ok and rate > last_rate
		last_rate = rate
	check(rate_ok, "büyük pakette gem başına fiyat daha ucuz")

	print("== 2) Bağlantı ve fiyatlar ==")
	var pp: PlayerProgress = PlayerProgress.new()
	root.add_child(pp)
	pp.load_state(5, 0, 0)
	var mock: MockBillingClient = MockBillingClient.new()
	var pm: PurchaseManager = _make(mock)
	check(not pm.is_available(), "bağlanmadan mağaza kapalı")
	await frames(4)
	check(pm.is_available(), "bağlanınca ürünler geldi")
	check(pm.price_text(&"gems_pack_1") == "$0.99", "fiyat Play'den (%s)" % pm.price_text(&"gems_pack_1"))
	check(pm.block_reason(&"gems_pack_1") == "", "paket alınabilir")
	check(pm.block_reason(&"yok_boyle") == "unavailable", "bilinmeyen ürün alınamaz")

	var finished: Array = []
	pm.purchase_finished.connect(func(id: StringName, status: StringName) -> void: finished.append([id, status]))

	print("== 3) Başarılı satın alma ==")
	check(pm.buy(&"gems_pack_1"), "satın alma penceresi açıldı")
	check(pm.is_busy() and pm.block_reason(&"gems_pack_2") == "busy", "pencere açıkken ikinci satın alma yok")
	check(not pm.buy(&"gems_pack_2"), "çift dokunuş ikinci pencere açmaz")
	await frames(4)
	check(pp.gems == 100, "+100 gem (%d)" % pp.gems)
	check(finished.size() == 1 and finished[0][1] == &"granted", "sonuç: granted")
	check(mock.owned.is_empty(), "Play'de tüketildi")
	var led: Dictionary = pm.state()["ledger"]
	var entry0: Dictionary = led.values()[0] if led.size() == 1 else {}
	check(led.size() == 1 and bool(entry0.get("consumed")) and String(entry0.get("token")) == "", "defterde tüketildi, ham anahtar silindi")
	check(not pm.is_busy(), "pencere kapandı")

	print("== 4) İptal / hata ==")
	finished.clear()
	mock.outcome = MockBillingClient.Outcome.CANCELED
	pm.buy(&"gems_pack_2")
	await frames(3)
	check(pp.gems == 100 and finished.size() == 1 and finished[0][1] == &"canceled", "iptal: gem yok")
	mock.outcome = MockBillingClient.Outcome.ERROR
	pm.buy(&"gems_pack_2")
	await frames(3)
	check(pp.gems == 100 and finished[-1][1] == &"error" and not pm.is_busy(), "hata: gem yok, pencere serbest")

	print("== 5) Bekleyen ödeme ==")
	mock.outcome = MockBillingClient.Outcome.PENDING
	pm.buy(&"gems_pack_2")
	await frames(3)
	check(pp.gems == 100 and finished[-1][1] == &"pending" and pm.pending_payment, "bekleyen ödemede gem VERİLMEZ")
	check(mock.owned.size() == 1, "bekleyen satın alma tüketilmedi")
	mock.complete_pending(String(mock.owned[0]["purchase_token"]))
	await frames(4)
	check(pp.gems == 650, "ödeme onaylanınca +550 (%d)" % pp.gems)
	check(mock.owned.is_empty(), "onaylanan satın alma tüketildi")

	print("== 6) Başlangıç paketi tek sefer ==")
	mock.outcome = MockBillingClient.Outcome.PURCHASED
	check(pm.block_reason(GemProducts.STARTER) == "", "başlangıç paketi alınabilir")
	pm.buy(GemProducts.STARTER)
	await frames(4)
	check(pp.gems == 1050 and pm.was_bought(GemProducts.STARTER), "+400 başlangıç paketi")
	check(pm.block_reason(GemProducts.STARTER) == "owned" and not pm.buy(GemProducts.STARTER), "ikinci kez alınamaz")

	print("== 7) Kayıt turu ==")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(pm.state()))
	pm.load_state(saved)
	check(pm.was_bought(GemProducts.STARTER) and (pm.state()["ledger"] as Dictionary).size() == 3, "defter JSON turundan sağ çıkar")
	pm.load_state({"ledger": {"x": "bozuk", 5: {}}})
	check((pm.state()["ledger"] as Dictionary).is_empty(), "bozuk defter yok sayılır")
	pm.load_state(saved)

	print("== 8) Yarıda kalan tüketme ==")
	mock.consume_ok = false
	pm.buy(&"gems_pack_1")
	await frames(4)
	check(pp.gems == 1150 and mock.owned.size() == 1, "gem verildi ama Play'de tüketilemedi")
	var after_fail: Dictionary = pm.state()
	var still_owned: Array[Dictionary] = mock.owned.duplicate(true)
	pm.queue_free()   # istemci (mock) de onunla gider
	await frames(2)
	# Uygulama yeniden açıldı: aynı kayıt, Play aynı satın almayı yine getirir
	var mock2: MockBillingClient = MockBillingClient.new()
	mock2.owned = still_owned
	var pm2: PurchaseManager = _make(mock2)
	pm2.load_state(after_fail)
	await frames(5)
	check(pp.gems == 1150, "yeniden açılışta gem İKİNCİ kez verilmedi (%d)" % pp.gems)
	check(mock2.owned.is_empty(), "takılı satın alma tüketildi")

	print("== 9) Gem verilmeden ölen uygulama ==")
	var mock3: MockBillingClient = MockBillingClient.new()
	mock3.owned.append(mock3.make_purchase("gems_pack_3"))
	pm2.queue_free()
	await frames(2)
	var pm3: PurchaseManager = _make(mock3)
	pm3.load_state(after_fail)
	await frames(5)
	check(pp.gems == 2350 and mock3.owned.is_empty(), "açılışta tamamlanmamış satın alma verildi ve tüketildi (%d)" % pp.gems)

	print("== 10) Cihaz defteri (hesap değişti, oyun sıfırlandı) ==")
	var stuck: Dictionary = mock3.make_purchase("gems_pack_1")
	mock3.consume_ok = false
	mock3.owned.clear()
	mock3.owned.append(stuck)
	mock3.query_purchases(BillingClient.ProductType.INAPP)
	await frames(4)
	var gems_before_reset: int = pp.gems
	pm3.reset()   # SaveManager.new_game: defter bu oyuna aitti
	pp.load_state(1, 0, 0)
	mock3.consume_ok = true
	mock3.query_purchases(BillingClient.ProductType.INAPP)
	await frames(4)
	check(gems_before_reset == 2450 and pp.gems == 0, "yeni oyuna aynı satın alma gem VERMEDİ (%d)" % pp.gems)
	check(mock3.owned.is_empty(), "yalnızca tüketildi")

	print("== 11) Bulut kaydı satın almayı silmez ==")
	pm3.queue_free()
	await frames(2)
	var econ: EconomyManager = EconomyManager.new()
	root.add_child(econ)
	var pm4: PurchaseManager = _make(MockBillingClient.new())
	var save: SaveManager = SaveManager.new()
	save.load_on_start = false
	save.auto_save = false
	root.add_child(save)
	await frames(5)
	pp.load_state(4, 0, 30)
	pm4.buy(&"gems_pack_2")
	await frames(4)
	check(pp.gems == 580, "misafirken alındı (+550 → %d)" % pp.gems)
	var cloud: Dictionary = JSON.parse_string(JSON.stringify(save.snapshot()))
	(cloud["progress"] as Dictionary)["gems"] = 70
	cloud["purchases"] = {}
	check(save.apply_snapshot(cloud), "eski bulut kaydı uygulandı")
	check(pp.gems == 620, "buluttaki 70 + satın alınan 550 (%d)" % pp.gems)
	check(pm4.was_bought(&"gems_pack_2"), "defter de taşındı")
	var cloud2: Dictionary = JSON.parse_string(JSON.stringify(save.snapshot()))
	check(save.apply_snapshot(cloud2) and pp.gems == 620, "satın almayı içeren kayıtta gem İKİ kez eklenmez")
	check((save.snapshot() as Dictionary).has("purchases"), "defter kayda yazılıyor")
	save.new_game()
	check(not pm4.was_bought(&"gems_pack_2"), "yeni oyun defteri sıfırlar")
	save.delete_save()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(PurchaseManager.DEVICE_LEDGER_PATH))
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
