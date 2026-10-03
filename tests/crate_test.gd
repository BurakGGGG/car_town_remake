extends SceneTree
## KASA / KOLEKSİYON TESTİ — büyük araç teslimat kasası akışı, kayıt güvenliği, kopya, keşif,
## showroom geri alma, yarış aracı, garaj değeri, dekor yalıtımı, gem ödülleri ve oran istatistiği.
## Çalıştırma: tools/run_tests.sh crate_test   (yalıtılmış user dizini)
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
	await create_timer(1.6).timeout


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func disk_crate(uid: int) -> Dictionary:
	for item: Variant in (disk().get("crates", {}) as Dictionary).get("items", []):
		if int((item as Dictionary)["uid"]) == uid:
			return item
	return {}


func wait_state(crates: CrateManager, uid: int, state: int, seconds: float) -> bool:
	var t: float = 0.0
	while t < seconds:
		if crates.state_of(uid) == state:
			return true
		await create_timer(0.1).timeout
		t += 0.1
	return crates.state_of(uid) == state


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))

	print("== 1) İLK AÇILIŞ: ŞAHİN ==")
	await reload()
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var pp: PlayerProgress = g(&"player_progress")
	var save: SaveManager = g(&"save_manager")
	var crates: CrateManager = g(&"crates")
	var delivery: CrateDelivery = g(&"crate_delivery")
	var race: RaceManager = g(&"race")
	check(crates != null and delivery != null and g(&"gem_rewards") != null, "kasa yöneticisi, teslimat alanı ve gem ödülleri kodla kuruldu")
	check(own.owned_vehicle_ids() == [&"tofas_sahin"], "yeni oyunda yalnızca Tofaş Şahin")
	check(own.is_discovered(&"tofas_sahin") and own.discovered_count() == 1, "Şahin koleksiyonun ilk parçası")
	check(race.player_vehicle_id() == &"tofas_sahin", "ilk yarış aracı Şahin")
	check(pp.gems == 50, "40 başlangıç + 10 ilk gün girişi = 50 gem (%d)" % pp.gems)
	check(not save.has_progress(), "yeni kurulum 'ilerleme yok' sayılır (bulut kaydı otomatik gelsin)")
	check(int(disk()["version"]) == SaveManager.SAVE_VERSION and SaveManager.SAVE_VERSION == 10, "kayıt v10")

	print("== 2) ŞAHİN İKİNCİ KEZ VERİLMEZ ==")
	await reload()
	own = g(&"vehicle_ownership"); pp = g(&"player_progress")
	check(own.owned_count() == 1, "yeniden açılışta hâlâ 1 araç")
	check(pp.gems == 50, "aynı gün ikinci giriş gemi yok (%d)" % pp.gems)

	print("== 3) İLK ÜCRETSİZ KASA (Sv 2 görevi) ==")
	var quests: QuestManager = g(&"quests")
	crates = g(&"crates")
	check(not quests.claim(&"first_crate"), "Sv 1'de alınamaz")
	pp.add_xp(pp.xp_to_next())
	check(pp.level == 2, "seviye 2")
	check(quests.claim(&"first_crate"), "İLK KASA ödülü alındı")
	check(crates.pending_count() == 1, "garaja 1 kasa geldi")
	var free_uid: int = crates.crates()[0]["uid"]
	check(String(crates.get_crate(free_uid)["source"]).begins_with("quest"), "kaynak: görev")
	check(not quests.claim(&"first_crate"), "ikinci kez alınamaz")
	await reload()
	quests = g(&"quests"); crates = g(&"crates")
	check(not quests.claim(&"first_crate") and crates.pending_count() == 1, "yeniden açılışta da alınamaz, kasa tek")

	print("== 4) 30 GEM İLE ŞEHİR KASASI ==")
	pp = g(&"player_progress"); own = g(&"vehicle_ownership"); delivery = g(&"crate_delivery")
	pp.load_state(pp.level, pp.xp, 30)
	check(crates.buy_block_reason(&"family_crate") == "level", "AİLE kasası Sv 10 ister")
	var uid: int = crates.buy(&"city_crate")
	check(uid > 0, "satın alındı (uid %d)" % uid)
	check(pp.gems == 0, "30 gem düştü")
	var on_disk: Dictionary = disk_crate(uid)
	check(not on_disk.is_empty() and int(disk()["progress"]["gems"]) == 0, "gem ve kasa AYNI yazımda diskte")
	var rolled: StringName = StringName(str(on_disk.get("vehicle", "")))
	check(CrateCatalog.pool(&"city_crate").has(rolled), "sonuç satın almada çekildi ve kayıtlı: %s" % rolled)
	check(crates.buy(&"city_crate") == 0 and pp.gems == 0, "gem yetmezse hiçbir şey değişmez")
	check(await wait_state(crates, uid, CrateManager.State.WAITING_TO_OPEN, 3.0), "kasa teslim edildi, açılmayı bekliyor")
	var visual: CrateVisual = delivery.visual_of(uid)
	check(visual != null, "garajda FİZİKSEL kasa var")
	check(visual != null and visual.size().x >= 0.6 and visual.size().z >= 0.4, "kasa araç sığacak büyüklükte (%s)" % (visual.size() if visual else Vector3.ZERO))
	check(delivery.find_child("RevealedVehicle", true, false) == null, "açılmadan araç dünyada görünmez")

	print("== 5) İKİ KASA AYNI ANDA ==")
	check(crates.pending_count() == 2, "iki kasa bekliyor")
	var a: CrateVisual = delivery.visual_of(free_uid)
	var rects: Array[Rect2] = delivery.occupied_rects()
	check(a != null and rects.size() == 2 and not rects[0].intersects(rects[1]), "iki kasa ayrı noktalarda, çakışmıyor")

	print("== 6) DEKORASYONDAN YALITIM ==")
	var decor: DecorManager = g(&"decor")
	var view: GarageDecorView = g(&"garage_decor_view")
	check(decor.instance_count() == 0, "kasalar DecorManager'a girmedi")
	var floor_item: StringName = &""
	for item: Dictionary in GarageDecor.all():
		if GarageDecor.placement(item["id"]) == GarageDecor.PLACE_FLOOR:
			floor_item = item["id"]
			break
	var cpos: Vector3 = visual.global_position if visual else Vector3.ZERO
	check(floor_item != &"" and not view.is_valid(floor_item, cpos, 0.0), "dekor kasanın üstüne konamaz (%s)" % floor_item)
	check(view.body_of(str(uid)) == null and view.body_of(visual.name if visual else "") == null,
		"düzenleyicinin seçebileceği dekor gövdeleri arasında kasa yok")

	print("== 7) KAYDET / KAPAT / AÇ: SONUÇ DEĞİŞMEZ ==")
	var pos_before: Vector2 = crates.get_crate(uid)["pos"]
	for i: int in 3:
		await reload()
		crates = g(&"crates")
		check(crates.get_crate(uid).get("vehicle", &"") == rolled, "açılış %d: içerik hâlâ %s" % [i + 1, rolled])
	delivery = g(&"crate_delivery")
	check(crates.get_crate(uid)["pos"] == pos_before and delivery.visual_of(uid) != null, "kasa aynı yerde duruyor")
	save = g(&"save_manager")
	var snap: Dictionary = save.snapshot()
	check(save.apply_snapshot(snap) and crates.get_crate(uid).get("vehicle", &"") == rolled, "bulut geri yükleme sonucu değiştirmedi")

	print("== 8) KASAYI AÇ ==")
	own = g(&"vehicle_ownership")
	var gv_before: int = GarageValue.vehicles_value(self)
	var was_owned: bool = own.is_owned(rolled)
	var got: Array = []
	delivery.reveal_ready.connect(func(u: int, r: Dictionary) -> void: got.append([u, r]))
	check(delivery.open_crate(uid), "AÇ")
	check(not delivery.open_crate(uid), "açılırken ikinci kez açılamaz")
	check(crates.state_of(uid) == CrateManager.State.REVEALED and int(disk_crate(uid).get("state", -1)) == CrateManager.State.REVEALED, "ödül verildi, REVEALED hemen kaydedildi")
	var waited: float = 0.0
	while got.is_empty() and waited < 8.0:
		await create_timer(0.1).timeout
		waited += 0.1
	check(not got.is_empty() and got[0][1]["vehicle"] == rolled, "ortaya çıkan araç kayıtlı sonuç: %s" % rolled)
	check(delivery.find_child("RevealedVehicle", true, false) != null, "araç dünyada 3D olarak çıktı")
	check(own.is_owned(rolled), "araç koleksiyonda")
	var expected_gv: int = gv_before + (0 if was_owned else int(CarCatalog.get_entry(rolled)["price"]))
	check(GarageValue.vehicles_value(self) == expected_gv, "garaj değeri doğru (%d)" % GarageValue.vehicles_value(self))
	delivery.finish_reveal(uid)
	await create_timer(0.8).timeout
	check(crates.state_of(uid) == CrateManager.State.CLAIMED and delivery.visual_of(uid) == null, "kasa kaldırıldı (CLAIMED)")

	print("== 9) AÇILIŞ SIRASINDA UYGULAMA KAPANIRSA ÇİFT ÖDÜL YOK ==")
	var owned_before: int = own.owned_count()
	check(delivery.open_crate(free_uid), "ikinci kasa açıldı")
	await frames(2)
	await reload()   # sahne bitmeden kapat-aç
	crates = g(&"crates"); own = g(&"vehicle_ownership")
	check(crates.state_of(free_uid) == CrateManager.State.CLAIMED, "REVEALED kasa yüklemede kapandı")
	check(own.owned_count() <= owned_before + 1, "ödül bir kez verildi")

	print("== 10) KOPYA: YILDIZ + GEM HURDASI, İKİNCİ ARAÇ YOK ==")
	pp = g(&"player_progress"); delivery = g(&"crate_delivery")
	var dup_uid: int = crates.grant_free(&"city_crate", "test")
	var owned_id: StringName = &"hyundai_getz"
	if not own.is_owned(owned_id):
		own.add_vehicle(owned_id)
	crates._find(dup_uid)["vehicle"] = owned_id   # testte sonucu sahip olunan araca sabitle
	await wait_state(crates, dup_uid, CrateManager.State.WAITING_TO_OPEN, 3.0)
	var count_before: int = own.owned_count()
	var gv2: int = GarageValue.vehicles_value(self)
	var gems_before: int = pp.gems
	var res: Dictionary = crates.open(dup_uid)
	check(bool(res.get("duplicate", false)) and int(res["stars"]) == 1, "kopya → ★1")
	check(pp.gems == gems_before + int(CrateManager.DUP_SCRAP[&"common"]), "common hurdası +2 gem")
	check(own.owned_count() == count_before and own.duplicate_count(owned_id) == 1, "satılabilir ikinci araç oluşmadı")
	check(GarageValue.vehicles_value(self) == gv2, "garaj değeri kopyayla şişmedi")
	crates.claim(dup_uid)

	print("== 11) SATILAN ARAÇ KEŞFEDİLMİŞ KALIR, SHOWROOM GERİ SATAR ==")
	var eco: EconomyManager = g(&"economy")
	check(own.sell_vehicle(owned_id), "Getz satıldı")
	check(own.is_discovered(owned_id) and not own.is_owned(owned_id), "keşfedilmiş kaldı")
	eco.set_money(100000)
	check(own.status(&"bmw_e60") == VehicleOwnership.Status.UNDISCOVERED and not own.purchase_vehicle(&"bmw_e60"), "keşfedilmemiş E60 showroom'da alınamaz")
	check(own.status(owned_id) == VehicleOwnership.Status.PURCHASABLE and own.purchase_vehicle(owned_id), "keşfedilmiş Getz geri alındı")
	check(own.duplicate_count(owned_id) == 1, "yıldız geri almada korunur")

	print("== 12) YARIŞ SEÇİLİ ARACI KULLANIR ==")
	race = g(&"race")
	check(own.set_race_vehicle(owned_id) and race.player_vehicle_id() == owned_id, "yarış aracı Getz")
	check(not own.set_race_vehicle(&"bmw_e60"), "sahip olunmayan araç seçilemez")
	save = g(&"save_manager"); save.save_game()
	await reload()
	own = g(&"vehicle_ownership"); race = g(&"race")
	check(race.player_vehicle_id() == owned_id, "seçim kayıttan geri geldi")
	check(own.sell_vehicle(owned_id) and race.player_vehicle_id() == &"tofas_sahin", "yarış aracı satılınca Şahin'e düşer")

	print("== 13) ESKİ KAYIT (v9) GÖÇÜ ==")
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 9, "economy": {"money": 1000}, "progress": {"xp": 0, "level": 5, "gems": 7},
		"vehicles": {"owned": ["bmw_e46", "hyundai_era", "hyundai_getz", "ford_focus", "renault_toros"], "paint": {}},
		"job_mastery": {"engine": 300, "tires": 20}}))
	f.close()
	await reload()
	own = g(&"vehicle_ownership"); crates = g(&"crates"); quests = g(&"quests"); pp = g(&"player_progress")
	check(pp.gems == 7 + GemRewards.login_gems(1), "eski kayıt: yalnızca günün girişi, geriye dönük tamir/koleksiyon gemi yok (%d)" % pp.gems)
	check(quests.is_claimed(&"first_crate") and not quests.claim(&"first_crate") and crates.pending_count() == 0, "eski oyuncuya bedava İLK KASA verilmez")
	var legacy_gems: int = pp.gems
	own.add_vehicle(&"hyundai_accent_blue")   # 6. araç: 5'lik koleksiyon taşı eski kayıtta ödenmiş sayılır
	crates.mark_passed_milestones(0)
	check(crates._pay_milestones(own.discovered_count()) == 0 and pp.gems == legacy_gems, "geçilmiş koleksiyon taşı yeni keşifte geriye dönük ödenmez")
	check(own.is_owned(&"bmw_e46") and own.is_discovered(&"bmw_e46") and own.is_discovered(&"hyundai_era") and own.owned_count() == 6, "v9: sahiplik korundu, sahip olunanlar keşfedilmiş sayıldı")
	check(not own.is_owned(&"tofas_sahin"), "eski oyuncuya Şahin sonradan verilmez")
	check(crates.pending_count() == 0 and int(disk()["version"]) == 10, "bekleyen kasa yok, v10 olarak yeniden yazıldı")

	print("== 14) GEM ÖDÜLLERİ: İKİ KEZ YOK, SAAT İSTİSMARI YOK ==")
	var gr: GemRewards = g(&"gem_rewards")
	pp = g(&"player_progress")
	check(gr._repair_step == 2, "eski kayıttaki 320 tamir: 50/250 taşları ödenmiş sayıldı (adım %d)" % gr._repair_step)
	pp.load_state(5, 0, 0)
	gr.load_state({})
	var t0: int = 1_800_000_000
	gr.test_now = t0
	gr.check_day()
	check(pp.gems == 10 and gr.streak() == 1, "1. gün girişi +10")
	gr.check_day()
	check(pp.gems == 10, "aynı gün ikinci kez verilmez")
	gr.test_now = t0 + 86400
	gr.check_day()
	check(pp.gems == 20 and gr.streak() == 2, "2. gün +10, seri 2")
	gr.test_now = t0 - 86400 * 3
	gr.check_day()
	check(pp.gems == 20 and gr.is_clock_rolled_back(), "saat geri alındı: ödül yok, tespit edildi")
	gr.test_now = t0 + 86400 * 6
	gr.check_day()
	check(gr.streak() == 1 and pp.gems == 30, "saat ileri alındı: yalnızca o günün ödülü, seri sıfırlandı")
	gr.test_now = t0 + 86400 * 2
	gr.check_day()
	check(pp.gems == 30, "gerçek güne dönünce kilit: kaçırılan günler telafi edilmez")
	gr.test_now = t0 + 86400 * 6
	var tasks: Array[Dictionary] = gr.daily_tasks()
	check(tasks.size() == 3, "3 günlük görev (Sv 3+)")
	check(String(tasks[0]["text"]).begins_with(str(tasks[0]["target"])), "görev metni doğru: %s" % tasks[0]["text"])
	var repairs_target: int = int(tasks[0]["target"])
	var before_tasks: int = pp.gems
	for i: int in repairs_target:
		gr._on_repair_collected(null, 0, 0)
	check(pp.gems >= before_tasks + GemRewards.TASK_GEMS, "tamir görevi tamam +10")
	var after_one: int = pp.gems
	for i: int in repairs_target:
		gr._count(&"repairs", 1)
	check(pp.gems == after_one, "aynı görev iki kez ödemez")
	gr._count(&"repair_money", 99999)
	gr._count(&"races", 9)
	check(gr.daily_tasks().all(func(t: Dictionary) -> bool: return bool(t["done"])), "üç görev tamam")
	var bonus_gems: int = pp.gems
	gr._count(&"races", 9)
	check(pp.gems == bonus_gems, "bütün görevler bonusu bir kez")
	gr.test_now = t0 - 86400
	gr.check_day()
	check(gr.daily_tasks().all(func(t: Dictionary) -> bool: return bool(t["done"])), "saat geri alınınca görevler sıfırlanmaz (yeniden yapılamaz)")
	var round_trip: Dictionary = gr.state()
	gr.load_state(JSON.parse_string(JSON.stringify(round_trip)))
	check(JSON.stringify(gr.state(), "", true) == JSON.stringify(round_trip, "", true), "gem ödül durumu kayıt turunda aynı")
	gr.test_now = t0 + 86400 * 20
	gr.check_day()
	for i: int in GemRewards.TIP_EVERY * (GemRewards.TIP_DAILY_CAP + 10):
		gr._on_repair_collected(null, 0, 0)
	check(gr._tip_count == GemRewards.TIP_DAILY_CAP, "bahşiş günlük tavanda durur (%d / %d)" % [gr._tip_count, GemRewards.TIP_DAILY_CAP])
	# Haftalık hedef: 12. görevde bir kez +100
	gr.test_now = t0 + 86400 * 27
	gr.check_day()
	gr._week_count = GemRewards.WEEKLY_NEED - 1
	gr._week_paid = false
	var week_before: int = pp.gems
	gr._count(&"races", 9)
	check(pp.gems == week_before + GemRewards.TASK_GEMS + GemRewards.WEEKLY_GEMS, "haftalık hedef +%d bir kez (görev +%d ile)" % [GemRewards.WEEKLY_GEMS, GemRewards.TASK_GEMS])
	var week_after: int = pp.gems
	gr._count(&"repairs", 99)
	check(pp.gems == week_after + GemRewards.TASK_GEMS, "haftalık hedef ikinci kez ödenmez (yalnızca görev gemi)")
	# Ustalık yıldızı: JobMastery.mastery_up → +10 gem
	var mastery: JobMastery = g(&"job_mastery")
	var star_before: int = pp.gems
	var stars_before: int = mastery.stars(&"brakes")
	while mastery.stars(&"brakes") == stars_before:
		mastery.record(&"brakes")
	check(pp.gems == star_before + GemRewards.MASTERY_STAR_GEMS, "ustalık yıldızı +%d gem" % GemRewards.MASTERY_STAR_GEMS)
	# Tamir kilometre taşları: 320 tamirlik sayaç → 50 ve 250 taşları (10 + 20) bir kez
	gr._repair_step = 0
	var ms_before: int = pp.gems
	gr.check_repair_milestones()
	check(pp.gems == ms_before + 30 and gr._repair_step == 2, "tamir taşları 50/250 → +30 gem (%d)" % (pp.gems - ms_before))
	gr.check_repair_milestones()
	check(pp.gems == ms_before + 30, "tamir taşları ikinci kez ödenmez")
	gr.test_now = -1

	print("== 15) ORANLAR: GÖZLENEN = İLAN EDİLEN (200.000 çekiliş / kasa) ==")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20260929
	for crate: Dictionary in CrateCatalog.all():
		var rows: Array[Dictionary] = CrateCatalog.odds(crate["id"])
		var total: float = 0.0
		for row: Dictionary in rows:
			total += float(row["chance"])
		check(absf(total - 1.0) < 1e-6, "%s oranları toplam 1" % crate["id"])
		var counts: Dictionary = {}
		var n: int = 200000
		for i: int in n:
			var id: StringName = CrateCatalog.roll(crate["id"], rng)
			counts[id] = int(counts.get(id, 0)) + 1
		var worst: float = 0.0
		for row: Dictionary in rows:
			var p: float = float(row["chance"])
			var sigma: float = sqrt(n * p * (1.0 - p))
			worst = maxf(worst, absf(float(counts.get(row["id"], 0)) - n * p) / sigma)
		check(worst < 4.5, "%s: en büyük sapma %.2f σ (< 4,5)" % [crate["id"], worst])
	var e60: float = 0.0
	for row: Dictionary in CrateCatalog.odds(&"prestige_crate"):
		if row["id"] == &"bmw_e60":
			e60 = float(row["chance"])
	check(absf(e60 - 4.0 / 144.0) < 1e-6, "E60 = 4/144 = yüzde 2,78 (tasarım belgesiyle aynı)")

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
