extends SceneTree
## REKLAM ALTYAPISI TESTİ — AdPolicy kuralları, AdConfig kimlik güvenliği, AdService ödül sözleşmesi
## (sahte sağlayıcıyla), kayıt turu ve bozuk kayıt. Gerçek reklam / eklenti gerekmez.
## Çalıştırma: tools/run_tests.sh ads_test
var fails: int = 0

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _make_service(level: int, provider: MockAdProvider) -> AdService:
	var pp: PlayerProgress = PlayerProgress.new()
	root.add_child(pp)
	pp.load_state(level, 0, 0)
	var svc: AdService = AdService.new()
	svc.use_provider(provider)
	root.add_child(svc)
	return svc

func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))

	print("== 1) AdPolicy ==")
	var st: Dictionary = {"day": 100, "counts": {}}
	check(AdPolicy.block_reason(&"nope", st, 99, 0, -1) == AdPolicy.UNKNOWN_KIND, "bilinmeyen tür engellenir")
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 1, 0, -1) == AdPolicy.LEVEL_LOW, "düşük seviyede teklif yok (ilk deneyim reklamsız)")
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 3, 0, -1) == AdPolicy.OK, "seviye yetince uygun")
	st["counts"] = {AdPolicy.RACE_DOUBLE: 5}
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, 0, -1) == AdPolicy.DAILY_CAP, "tür günlük sınırı")
	st["counts"] = {AdPolicy.RACE_DOUBLE: 4, AdPolicy.REPAIR_BOOST: 8, AdPolicy.FREE_GEMS: 5, AdPolicy.LEVELUP_DOUBLE: 2}
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, 0, -1) == AdPolicy.OK, "toplam 20 altında (19) uygun")
	st["counts"] = {AdPolicy.RACE_DOUBLE: 4, AdPolicy.REPAIR_BOOST: 8, AdPolicy.FREE_GEMS: 5, AdPolicy.LEVELUP_DOUBLE: 3}
	check(AdPolicy.total_today(st) == 20 and AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, 0, -1) == AdPolicy.TOTAL_CAP, "toplam günlük sınır (20)")
	st["counts"] = {}
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, 10_000, 0) == AdPolicy.TOO_SOON, "iki reklam arası bekleme")
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, AdPolicy.MIN_GAP_MS + 1, 0) == AdPolicy.OK, "bekleme bitince uygun")
	# ÜCRETSİZ ELMAS: iki izleme arası 3 dk (kayıtta, gece yarısını geçer)
	st = {"day": 100, "counts": {AdPolicy.FREE_GEMS: 1}, "last": {AdPolicy.FREE_GEMS: 1_000_000}}
	check(AdPolicy.cooldown_sec(AdPolicy.FREE_GEMS) == 180, "ücretsiz elmas beklemesi 3 dk")
	check(AdPolicy.block_reason(AdPolicy.FREE_GEMS, st, 9, 0, -1, 1_000_100) == AdPolicy.COOLDOWN
		and AdPolicy.cooldown_left(AdPolicy.FREE_GEMS, st, 1_000_100) == 80, "beklemede: 80 sn kaldı")
	check(AdPolicy.block_reason(AdPolicy.FREE_GEMS, st, 9, 0, -1, 1_000_181) == AdPolicy.OK, "3 dk dolunca uygun")
	check(AdPolicy.block_reason(AdPolicy.RACE_DOUBLE, st, 9, 0, -1, 1_000_100) == AdPolicy.OK, "bekleme yalnız kendi türünde")
	check((AdPolicy.roll_day(st, 101)["last"] as Dictionary).has(AdPolicy.FREE_GEMS), "yeni günde bekleme sürer (gece yarısı hilesi yok)")
	# Süre kısaltma: yarısı, en çok 30 dk, 2 dk'dan kısa kalanda yok
	check(AdPolicy.time_cut(600.0) == 300.0 and AdPolicy.time_cut(7200.0) == 1800.0 and AdPolicy.time_cut(100.0) == 0.0,
		"süre kısaltma: yarısı / en çok 30 dk / kısa işte yok")
	# Panel ayarı (config/app.ads)
	AdPolicy.remote = AdPolicy.normalize_remote({"total_cap": 999, "free_gems": 10, "free_gems_cooldown": 60,
		"caps": {"free_gems": 2, "junk_refill": 0, "uydurma": 9}})
	check(AdPolicy.total_cap() == AdPolicy.REMOTE_TOTAL_MAX and AdPolicy.free_gems() == 10
		and AdPolicy.cooldown_sec(AdPolicy.FREE_GEMS) == 60, "panel: toplam sınırlı, elmas 10, bekleme 1 dk")
	check(AdPolicy.daily_cap(AdPolicy.FREE_GEMS) == 2 and AdPolicy.daily_cap(AdPolicy.JUNK_REFILL) == 0
		and AdPolicy.daily_cap(AdPolicy.RACE_DOUBLE) == 5, "panel: tür sınırı (0 = kapalı), verilmeyen varsayılan")
	check(AdPolicy.block_reason(AdPolicy.JUNK_REFILL, {"day": 1, "counts": {}}, 9, 0, -1) == AdPolicy.DAILY_CAP, "panelde kapatılan teklif sunulmaz")
	AdPolicy.remote = {}
	var fwd: Dictionary = AdPolicy.roll_day({"day": 100, "counts": {&"race_double": 4}}, 101)
	check(fwd["day"] == 101 and (fwd["counts"] as Dictionary).is_empty(), "gün ilerleyince sayaç sıfırlanır")
	var back: Dictionary = AdPolicy.roll_day({"day": 100, "counts": {&"race_double": 4}}, 99)
	check(back["day"] == 100 and int(back["counts"][&"race_double"]) == 4, "saat geri alınınca sayaç SIFIRLANMAZ")
	check(AdPolicy.day_number(86400.0 * 10.0, 0) == 10 and AdPolicy.day_number(86400.0 * 10.0 - 1.0, 180) == 10, "gün numarası saat dilimine göre")

	print("== 2) AdConfig kimlik güvenliği ==")
	check(AdConfig.unit_is_safe(AdConfig.TEST_REWARDED), "debug derlemede test kimliği güvenli")
	check(not AdConfig.unit_is_safe("ca-app-pub-1234567890123456/1111111111"), "debug derlemede GERÇEK kimlik reddedilir")
	check(not AdConfig.unit_is_safe(""), "boş kimlik güvensiz (reklam kapalı)")
	check(AdConfig.rewarded_unit(AdConfig.SLOT_RACE) == AdConfig.TEST_REWARDED and AdConfig.rewarded_unit(AdConfig.SLOT_REPAIR) == AdConfig.TEST_REWARDED, "debug derleme her yuvada test kimliğini seçer")
	var seen: Dictionary = {}
	var real_ok: bool = true
	for slot: StringName in AdConfig.slots():
		var real: String = String(AdConfig.REAL_REWARDED.get(slot, ""))
		real_ok = real_ok and real.begins_with("ca-app-pub-") and "/" in real and not real.begins_with("ca-app-pub-3940256099942544/")
		seen[real] = true
	check(real_ok and seen.size() == AdConfig.slots().size(), "her yuvanın GERÇEK birimi var, ayrı ve test kimliği değil")
	var slot_kinds_ok: bool = true
	for k: StringName in AdPolicy.kinds():
		slot_kinds_ok = slot_kinds_ok and AdConfig.slots().has(AdPolicy.slot_of(k))
	check(slot_kinds_ok and AdPolicy.slot_of(AdPolicy.REPAIR_BOOST) == AdConfig.SLOT_REPAIR and AdPolicy.slot_of(AdPolicy.RACE_DOUBLE) == AdConfig.SLOT_RACE, "her teklif türü geçerli bir yuvaya bağlı")

	print("== 3) AdService ödül sözleşmesi ==")
	var mock: MockAdProvider = MockAdProvider.new()
	var svc: AdService = _make_service(5, mock)
	await frames(4)
	check(svc.is_ready(), "başlatma + yükleme sonrası hazır")
	check(svc.can_offer(AdPolicy.RACE_DOUBLE), "teklif sunulabilir")
	var rewards: Array[int] = [0]
	var finished: Array[int] = [0]
	svc.reward_earned.connect(func(_k: StringName) -> void: rewards[0] += 1)
	svc.ad_finished.connect(func(_k: StringName, _r: bool) -> void: finished[0] += 1)
	var first: bool = svc.show_rewarded(AdPolicy.RACE_DOUBLE)
	var second: bool = svc.show_rewarded(AdPolicy.RACE_DOUBLE)
	check(first and not second, "çift dokunuş: ikinci show reddedilir")
	await frames(6)
	check(rewards[0] == 1, "ödül tam BİR kez verildi (%d)" % rewards[0])
	check(finished[0] == 1 and mock.shows == 1, "tek gösterim, tek bitiş")
	check(svc.used_today(AdPolicy.RACE_DOUBLE) == 1 and svc.remaining_today(AdPolicy.RACE_DOUBLE) == 4, "sayaç 1, kalan 4")
	check(svc.block_reason(AdPolicy.RACE_DOUBLE) == AdPolicy.TOO_SOON, "hemen ardından bekleme süresi devrede")
	svc.forget_last_ad()
	await frames(4)
	check(svc.is_ready(), "gösterimden sonra bir sonraki reklam yüklendi")
	# oyuncu reklamı erken kapattı
	mock.earns = false
	rewards[0] = 0
	svc.show_rewarded(AdPolicy.RACE_DOUBLE)
	await frames(6)
	check(rewards[0] == 0 and svc.used_today(AdPolicy.RACE_DOUBLE) == 1, "erken kapatma: ödül yok, hak harcanmadı")
	mock.earns = true
	# yükleme başarısız: eldeki reklam gösterilir, sonraki yükleme düşer → teklif çıkmaz, çökme yok
	svc.forget_last_ad()
	mock.load_ok = false
	await frames(4)
	svc.show_rewarded(AdPolicy.RACE_DOUBLE)
	await frames(8)
	svc.forget_last_ad()
	check(not svc.is_ready(AdPolicy.RACE_DOUBLE) and not svc.can_offer(AdPolicy.RACE_DOUBLE), "yükleme düşünce o yuvanın teklifi çıkmaz")
	check(not svc.show_rewarded(AdPolicy.RACE_DOUBLE), "hazır reklam yokken show false (sonsuz bekleme yok)")
	# günlük sınıra kadar
	mock.load_ok = true
	svc.ensure_loaded()
	svc.reset()
	mock.earns = true
	for i: int in 5:
		svc.forget_last_ad()
		svc.ensure_loaded()
		await frames(4)
		if svc.is_ready():
			svc.show_rewarded(AdPolicy.RACE_DOUBLE)
		await frames(6)
	svc.forget_last_ad()
	await frames(4)
	check(svc.used_today(AdPolicy.RACE_DOUBLE) == 5 and svc.block_reason(AdPolicy.RACE_DOUBLE) == AdPolicy.DAILY_CAP, "5. izlemeden sonra günlük sınır")
	check(not svc.show_rewarded(AdPolicy.RACE_DOUBLE), "sınır aşılınca show reddedilir")

	print("== 3b) Yuvalar bağımsız ==")
	mock.earns = true
	svc.reset()
	svc.forget_last_ad()
	svc.ensure_loaded()
	await frames(4)
	check(svc.is_ready(AdPolicy.RACE_DOUBLE) and svc.is_ready(AdPolicy.REPAIR_BOOST), "iki yuva da yüklü")
	svc.show_rewarded(AdPolicy.RACE_DOUBLE)
	await frames(6)
	check(mock.last_shown_slot == AdConfig.SLOT_RACE, "yarış teklifi YARIŞ yuvasından gösterildi")
	check(mock.has_rewarded(AdConfig.SLOT_REPAIR), "yarış reklamı tamir yuvasındaki reklamı tüketmedi")
	svc.forget_last_ad()
	svc.ensure_loaded()
	await frames(4)
	svc.show_rewarded(AdPolicy.REPAIR_BOOST)
	await frames(6)
	check(mock.last_shown_slot == AdConfig.SLOT_REPAIR, "tamir teklifi TAMİR yuvasından gösterildi")

	print("== 4) Saat oyunu + kayıt turu ==")
	svc.set_test_clock(86400.0 * 200.0)
	svc.reset()
	svc.set_test_clock(86400.0 * 200.0)
	svc.forget_last_ad()
	svc.ensure_loaded()
	await frames(4)
	svc.show_rewarded(AdPolicy.REPAIR_BOOST)
	await frames(6)
	check(svc.used_today(AdPolicy.REPAIR_BOOST) == 1, "bugün 1 izleme")
	var saved: Dictionary = svc.state()
	svc.set_test_clock(86400.0 * 199.0)   # saati geri al
	check(svc.used_today(AdPolicy.REPAIR_BOOST) == 1, "saat geri alınınca hak geri gelmedi")
	svc.set_test_clock(86400.0 * 201.0)
	check(svc.used_today(AdPolicy.REPAIR_BOOST) == 0, "ertesi gün sayaç sıfır")
	svc.set_test_clock(86400.0 * 200.0)
	svc.load_state(saved)
	check(svc.used_today(AdPolicy.REPAIR_BOOST) == 1, "state → load_state turu aynı")

	print("== 5) Bozuk reklam kaydı ==")
	for raw: Variant in [{}, {"day": null}, {"day": "x", "counts": 5}, {"counts": {"race_double": -9}}, {"counts": {"race_double": 9.0e30}}, {"counts": {"yok_tur": 3, "race_double": "abc"}}, {"counts": null}]:
		svc.load_state(raw as Dictionary)
		check(svc.used_today(AdPolicy.RACE_DOUBLE) >= 0 and svc.used_today(AdPolicy.RACE_DOUBLE) <= 1000, "bozuk kayıt güvenle okundu: %s" % str(raw))

	print("== 6) Oyun içinde (Main.tscn) ==")
	svc.queue_free()
	await frames(2)
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var game_ads: AdService = get_first_node_in_group("ads") as AdService
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	check(game_ads != null, "AdService oyunda kurulu (\"ads\" grubu)")
	check(save != null and save.snapshot().has("ads"), "kayıt 'ads' bölümünü içeriyor")
	var progress_before: bool = save.has_progress()
	game_ads.load_state({"day": 1_000_000, "counts": {"race_double": 3}})
	check(save.has_progress() == progress_before, "reklam sayaçları ilerleme sayılmıyor (has_progress değişmedi)")
	game_ads.reset()
	save.save_game()
	game_ads.load_state({"day": 1_000_000, "counts": {"repair_boost": 2}})
	save.save_game()
	save.load_game()
	check(game_ads.used_today(AdPolicy.REPAIR_BOOST) == 2 or game_ads.state()["day"] != 1_000_000, "kaydet → yükle sayaç turu")
	print("== 7) Yarış sonucu bonusu (HUD + AdService + ekonomi) ==")
	var hud: Node = main.find_child("HUD", true, false)
	var eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var pp2: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	check(hud != null and eco != null and pp2 != null, "HUD / ekonomi / ilerleme bulundu")
	pp2.load_state(6, 0, 0)
	game_ads.reset()
	game_ads.forget_last_ad()
	game_ads.ensure_loaded()
	await frames(4)
	check(game_ads.is_ready(), "oyundaki AdService hazır (masaüstünde sahte sağlayıcı)")
	var result: Control = hud.get("race_result_screen") as Control
	var bonus_button: Button = result.find_child("BonusButton", true, false) as Button
	check(bonus_button != null and not bonus_button.visible, "bonus plakası başta gizli")
	var money0: int = eco.money
	hud.call("_on_race_completed", true, 9.0, 10.0)
	await frames(2)
	var base_reward: int = eco.money - money0
	check(base_reward > 0 and bonus_button.visible, "galibiyet: ödül verildi (+%d) ve REKLAM İZLE teklifi göründü" % base_reward)
	check(eco.money == money0 + base_reward, "teklif görününce reklam kendiliğinden gösterilmedi / para değişmedi")
	bonus_button.pressed.emit()
	bonus_button.pressed.emit()   # çift dokunuş
	await frames(8)
	check(eco.money == money0 + base_reward * 2, "reklam sonrası bonus TAM bir kez eklendi (%d → %d)" % [money0, eco.money])
	check(not bonus_button.visible, "bonus alındıktan sonra plaka kapandı")
	bonus_button.pressed.emit()
	await frames(4)
	check(eco.money == money0 + base_reward * 2, "alınmış bonus tekrar tetiklenemez")
	check(game_ads.used_today(AdPolicy.RACE_DOUBLE) == 1, "günlük sayaç 1")
	# kayıp: para yok → teklif yok
	game_ads.forget_last_ad()
	game_ads.ensure_loaded()
	await frames(4)
	hud.call("_on_race_exit")
	hud.call("_on_race_completed", false, 12.0, 10.0)
	await frames(2)
	check(not bonus_button.visible, "kayıpta (₺ ödülü yok) teklif yok")
	# düşük seviye: teklif yok
	pp2.load_state(1, 0, 0)
	game_ads.forget_last_ad()
	hud.call("_on_race_exit")
	hud.call("_on_race_completed", true, 9.0, 10.0)
	await frames(2)
	check(not bonus_button.visible, "seviye 1'de teklif yok (ilk deneyim reklamsız)")
	print("== 8) Tamir süresi kısaltma (RepairState / RepairManager / HUD) ==")
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	var tm: TrafficManager = main.get_node("Traffic") as TrafficManager
	var long_type: RepairType = null
	for t: RepairType in RepairType.defaults():
		if t.id == &"paint_job":
			long_type = t
	check(long_type != null and rm != null and tm != null and not tm.vehicles.is_empty(), "uzun iş türü, tamir yöneticisi ve araç bulundu")
	var veh: TrafficVehicle = tm.vehicles[0]
	var st2: RepairState = RepairState.new(veh, long_type)
	st2.start()
	st2.advance(10.0)
	var rem0: float = st2.remaining
	check(st2.boost(0.5) and absf(st2.remaining - rem0 * 0.5) < 0.01, "kısaltma kalan süreyi yarıya indirdi (%.1f → %.1f)" % [rem0, st2.remaining])
	check(not st2.boost(0.5), "aynı iş ikinci kez kısaltılamaz")
	var short_type: RepairType = RepairType.defaults()[0]
	var st3: RepairState = RepairState.new(veh, short_type)
	st3.start()
	rm._active.append(st3)
	st3.car = veh
	check(not rm.can_boost(veh), "kısa işte (%.0f sn) kısaltma sunulmaz" % st3.remaining)
	rm._active.erase(st3)
	var st4: RepairState = RepairState.new(veh, long_type)
	st4.start()
	rm._active.append(st4)
	check(rm.can_boost(veh) and rm.boost_repair(veh) and not rm.can_boost(veh), "uzun işte bir kez kısaltılır, sonra sunulmaz")
	rm._active.erase(st4)
	# HUD akışı
	var st5: RepairState = RepairState.new(veh, long_type)
	st5.start()
	rm._active.append(st5)
	hud.set("_repair_target", veh)
	pp2.load_state(8, 0, 0)
	game_ads.reset()
	game_ads.forget_last_ad()
	game_ads.ensure_loaded()
	await frames(4)
	var before_rem: float = st5.remaining
	var used0: int = game_ads.used_today(AdPolicy.REPAIR_BOOST)
	hud.call("_on_repair_boost_pressed")
	hud.call("_on_repair_boost_pressed")   # çift dokunuş
	await frames(8)
	check(st5.boosted and absf(st5.remaining - before_rem * 0.5) < 1.0, "reklam sonrası süre yarıya indi (%.1f → %.1f)" % [before_rem, st5.remaining])
	check(game_ads.used_today(AdPolicy.REPAIR_BOOST) == used0 + 1, "tek reklam hakkı harcandı")
	rm._active.erase(st5)

	print("== 9) AppLovin yapılandırması + gizlilik ==")
	check(AdConfig.NETWORK == AdConfig.Network.APPODEAL, "reklam ağı Appodeal (AdMob reddedildi, AppLovin yeni yayıncı almıyor)")
	print("== 9a) Appodeal yapılandırması ==")
	var app_key: String = AdConfig.APPODEAL_APP_KEY
	check(app_key.length() == 48 and app_key.is_valid_hex_number(), "Appodeal uygulama anahtarı 48 haneli onaltılık")
	var deps_ok: bool = true
	var has_core: bool = false
	for dep: String in AdConfig.APPODEAL_DEPENDENCIES:
		deps_ok = deps_ok and dep.count(":") == 2 and not dep.ends_with(":") and not dep.contains("+")
		has_core = has_core or dep.begins_with("com.appodeal.ads.sdk:core:")
		# AdMob kimliği yok → Google reklam SDK'sını getiren adaptör açılışta çöker; Firebase adaptörü sürüm kümemizi bozar
		deps_ok = deps_ok and not dep.contains("admob") and not dep.contains("google-adapter") \
			and not dep.contains("google-ad-manager") and not dep.contains("adapters:firebase")
	check(has_core and deps_ok, "Appodeal bağımlılıkları sabit sürümlü, AdMob / Firebase adaptörü yok")
	var app_unique: Dictionary = {}
	for dep: String in AdConfig.APPODEAL_DEPENDENCIES:
		app_unique[dep.rsplit(":", true, 1)[0]] = true
	check(app_unique.size() == AdConfig.APPODEAL_DEPENDENCIES.size(), "bağımlılık listesinde tekrar yok")
	var app_shared: bool = true
	for slot: StringName in AdConfig.slots():
		app_shared = app_shared and AdConfig.appodeal_unit(slot) == AdConfig.APPODEAL_UNIT
	check(app_shared and AdConfig.appodeal_unit(&"yok") == "", "yuvalar Appodeal önbelleğini paylaşır, bilinmeyen yuva kapalı")
	check(not AppodealProvider.available(), "masaüstünde Appodeal yok (sağlayıcı seçilmez, sahte sağlayıcı kalır)")
	var al_unit: String = AdConfig.APPLOVIN_REWARDED_UNIT.strip_edges()
	check(al_unit == "" or (al_unit.length() == 16 and al_unit.is_valid_hex_number() and not al_unit.begins_with("ca-app-pub-")), "AppLovin birimi boş ya da 16 haneli onaltılık (AdMob kimliği değil)")
	var al_shared: bool = true
	for slot: StringName in AdConfig.slots():
		al_shared = al_shared and AdConfig.applovin_unit(slot) == al_unit
	check(al_shared and AdConfig.applovin_unit(&"yok") == "", "yuvalar tek birimi paylaşır (AppLovin önerisi), bilinmeyen yuvada birim yok")
	check(AdConfig.applovin_ready() == (AdConfig.APPLOVIN_SDK_KEY.strip_edges() != "" and al_unit != ""), "anahtar ya da birim eksikse AppLovin başlatılmaz (reklam kapalı)")
	check(AdConfig.applovin_units().size() == (1 if al_unit != "" else 0), "başlatmaya verilen birim listesi tekrarsız")
	var gaids_ok: bool = true
	for gaid: String in AdConfig.APPLOVIN_TEST_DEVICES:
		gaids_ok = gaids_ok and gaid.length() == 36 and gaid.count("-") == 4
	check(gaids_ok, "test cihazı reklam kimlikleri GAID biçiminde (8-4-4-4-12)")
	var mock_units: MockAdProvider = MockAdProvider.new()
	check(AdProvider.new().unit_for(AdConfig.SLOT_RACE) == "" and mock_units.unit_for(AdConfig.SLOT_RACE) != "", "kapalı sağlayıcıda birim yok, sahte sağlayıcıda var")
	check(AdPrivacy.locale_country("tr_TR") == "TR" and AdPrivacy.locale_country("de-DE") == "DE" and AdPrivacy.locale_country("en") == "", "cihaz dilinden ülke")
	check(AdPrivacy.is_gdpr_country("de") and AdPrivacy.is_gdpr_country("GB") and AdPrivacy.is_gdpr_country("CH") and AdPrivacy.is_gdpr_country("NO"), "AEA + BK + İsviçre onay bölgesi")
	check(not AdPrivacy.is_gdpr_country("TR") and not AdPrivacy.is_gdpr_country("US"), "Türkiye / ABD onay bölgesi değil")
	check(AdPrivacy.region("fr", "tr_TR") == "FR" and AdPrivacy.region("", "tr_TR") == "TR", "SDK'nın bildirdiği ülke cihaz dilinden önce gelir")
	check(AdPrivacy.personalized(AdPrivacy.Choice.UNSET, "TR") and not AdPrivacy.personalized(AdPrivacy.Choice.UNSET, "DE"), "varsayılan: Türkiye'de açık, AEA'da kapalı")
	check(not AdPrivacy.personalized(AdPrivacy.Choice.UNSET, ""), "ülke bilinmiyorsa kişiselleştirme kapalı (güvenli taraf)")
	check(AdPrivacy.personalized(AdPrivacy.Choice.ON, "DE") and not AdPrivacy.personalized(AdPrivacy.Choice.OFF, "TR"), "oyuncunun seçimi varsayılanı ezer")
	AdPrivacy.save_state({"choice": AdPrivacy.Choice.OFF, "country": "de"})
	var priv: Dictionary = AdPrivacy.load_state()
	check(int(priv["choice"]) == AdPrivacy.Choice.OFF and String(priv["country"]) == "DE", "gizlilik kaydı turu (ülke büyük harfe çevrilir)")
	var cfg_bad: ConfigFile = ConfigFile.new()
	cfg_bad.set_value("ads", "choice", 7)
	cfg_bad.set_value("ads", "country", 42)
	cfg_bad.save(AdPrivacy.PATH)
	priv = AdPrivacy.load_state()
	check(int(priv["choice"]) == AdPrivacy.Choice.UNSET and String(priv["country"]) == "", "bozuk seçim UNSET'e, bozuk ülke boşa düşer (varsayılan kapalı)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AdPrivacy.PATH))
	check(int(AdPrivacy.load_state()["choice"]) == AdPrivacy.Choice.UNSET, "dosya yoksa seçim yok")
	var toggle_mock: MockAdProvider = MockAdProvider.new()
	toggle_mock.toggle = true
	var tsvc: AdService = AdService.new()
	tsvc.use_provider(toggle_mock)
	root.add_child(tsvc)
	await frames(2)
	check(tsvc.personalization_toggle() and tsvc.personalized_ads(), "AYARLAR düğmesi sağlayıcının durumunu okur")
	tsvc.set_personalized_ads(false)
	check(not toggle_mock.personalized and not tsvc.personalized_ads(), "AYARLAR'dan kapatma sağlayıcıya iletilir")
	tsvc.queue_free()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
