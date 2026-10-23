extends SceneTree
## ÖDÜLLÜ REKLAM TEKLİFLERİ (2026-10-23, kullanıcı: "hepsi olsun, ücretsiz elmas 3 dk") — oyunun içinde, masaüstündeki
## sahte reklam sağlayıcıyla (MockAdProvider: gösterir ve ödülü verir):
##   1 MARKET › ÜCRETSİZ ELMAS (+5, sonra 3 dk geri sayım, günde 5)  2 OTO MANŞET kazanç ×2  3 süre kısaltma (modifiye,
##   depo inşası, iç yükseltme: yarısı / en çok 30 dk, iş başına bir)  4 günlük giriş elması ×2 (GÖREVLER › GÜNLÜK)
##   5 SEVİYE ATLADIN ₺ ×2  6 günlük görevi değiştir  7 hurdalık yığını doldur  8 panel ayarı (config/app.ads)
## Her teklif yalnızca oyuncu düğmeye basınca reklam açar; kendiliğinden reklam yok.
##   tools/run_tests.sh ad_offers_test

var fails: int = 0
var hud: Hud
var ads: AdService
var config: AppConfig


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	config = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	config.learning_url = ""
	root.add_child(config)   # oyundan önce: AdService panel ayarını dinlesin
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	ads = g(&"ads") as AdService
	(g(&"player_progress") as PlayerProgress).load_state(8, 0, 0)
	await _ready_ads()
	await _free_gems()
	await _offline_double()
	await _time_skip()
	await _daily_double()
	await _levelup_double()
	await _mission_reroll()
	await _junk_refill()
	await _remote()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## İki reklam arası 45 sn bekleme testte unutulur, reklam yuvaları yeniden yüklenir.
func _ready_ads() -> void:
	ads.forget_last_ad()
	ads.ensure_loaded()
	await frames(4)


func _press(button: AdOfferButton) -> void:
	button.refresh()
	button.pressed.emit()
	await frames(8)


func _offer(where: Node, offer: StringName) -> AdOfferButton:
	return where.find_child("AdOffer_%s" % offer, true, false) as AdOfferButton


func _free_gems() -> void:
	print("== 1) MARKET › ÜCRETSİZ ELMAS ==")
	var pp: PlayerProgress = g(&"player_progress")
	pp.load_state(8, 0, 10)
	hud.router.open(&"gem_store")
	await seconds(0.6)
	var store: Control = hud.router.screen(&"gem_store")
	var card: Control = store.find_child("FreeGemsCard", true, false) as Control
	var button: AdOfferButton = _offer(store, AdPolicy.FREE_GEMS)
	check(card != null and button != null and button.visible and not button.disabled, "GEM AL'da ÜCRETSİZ ELMAS kartı, REKLAM İZLE açık")
	check(pp.gems == 10 and ads.used_today(AdPolicy.FREE_GEMS) == 0, "kart açılınca reklam kendiliğinden açılmadı")
	await _press(button)
	check(pp.gems == 10 + AdPolicy.FREE_GEMS_AMOUNT, "reklam sonrası +%d elmas (%d)" % [AdPolicy.FREE_GEMS_AMOUNT, pp.gems])
	button = _offer(store, AdPolicy.FREE_GEMS)
	button.refresh()
	check(ads.block_reason(AdPolicy.FREE_GEMS) == AdPolicy.COOLDOWN and button.visible and button.disabled
		and button.text.contains(":") , "3 dk geri sayım (%s)" % button.text.replace("\n", " "))
	check(ads.cooldown_left(AdPolicy.FREE_GEMS) > 170 and ads.cooldown_left(AdPolicy.FREE_GEMS) <= 180, "bekleme 3 dk")
	var saved: Dictionary = ads.state()
	ads.load_state(saved)
	check(ads.cooldown_left(AdPolicy.FREE_GEMS) > 170, "bekleme kayıtta (uygulamayı kapatıp açmak sıfırlamaz)")
	ads.set_test_clock(Time.get_unix_time_from_system() + 181.0)
	await _ready_ads()
	check(ads.block_reason(AdPolicy.FREE_GEMS) == AdPolicy.OK, "3 dk sonra yeniden izlenebilir")
	ads.set_test_clock(-1.0)
	(g(&"player_progress") as PlayerProgress).load_state(8, 0, 0)
	hud.router.close_all()
	await seconds(0.5)


func _offline_double() -> void:
	print("== 2) OTO MANŞET kazanç ×2 ==")
	await _ready_ads()
	var away: OfflineEarnings = g(&"offline_earnings") as OfflineEarnings
	var eco: EconomyManager = g(&"economy")
	away.bank_money = 4000
	away.bank_minutes = 60.0
	away.bank_jobs = 3
	eco.set_money(0)
	check(hud.news_flow.present(), "gazete açıldı")
	await seconds(1.4)
	var screen: NewsScreen = hud.router.screen(&"news") as NewsScreen
	var button: AdOfferButton = _offer(screen, AdPolicy.OFFLINE_DOUBLE)
	check(button != null and button.visible and button.text.contains("4.000"), "TAMAM'ın yanında REKLAM İZLE +4.000 ₺")
	await _press(button)
	check(screen.doubled and not button.visible, "reklam izlendi: kazanç ×2 işaretli, teklif kalktı")
	screen.close()
	await seconds(1.6)
	check(eco.money == 8000, "kapanınca iki katı verildi (%d ₺)" % eco.money)
	away.bank_money = 1000
	away.bank_minutes = 30.0
	hud.news_flow.present()
	await seconds(1.4)
	check(not screen.doubled, "yeni gazetede ×2 sıfırdan")
	screen.close()
	await seconds(1.6)


func _time_skip() -> void:
	print("== 3) Süre kısaltma ==")
	await _ready_ads()
	var mods: PerformanceModManager = g(&"performance_mods") as PerformanceModManager
	var now: float = mods.now()
	mods._jobs.append({"car": &"ford_focus", "category": &"motor", "stage": 3, "bay": 9, "start": now, "end": now + 1200.0})
	check(absf(mods.ad_cut(&"ford_focus") - 600.0) < 2.0, "modifiye: 20 dk kalan → 10 dk düşer")
	check(mods.apply_ad_cut(&"ford_focus") and absf(mods.remaining(&"ford_focus") - 600.0) < 2.0, "kalan 10 dk")
	check(mods.ad_cut(&"ford_focus") == 0.0 and not mods.apply_ad_cut(&"ford_focus"), "aynı takma ikinci kez kısalmaz")
	var saved: Dictionary = mods.state()
	mods.load_state(saved)
	check(mods.ad_cut(&"ford_focus") == 0.0, "kayıt: kısaltıldı işareti kalır")
	mods._jobs.clear()
	var garages: CarGarageManager = g(&"car_garages") as CarGarageManager
	var depot: StringName = CarGarageCatalog.MAHALLE
	garages._building[depot] = garages.now() + 7200.0
	check(is_equal_approx(garages.build_ad_cut(depot), 1800.0), "depo inşası: 2 sa kalan → en çok 30 dk düşer")
	check(garages.apply_build_ad_cut(depot) and garages.build_ad_cut(depot) == 0.0, "inşaat başına bir kez")
	var gsaved: Dictionary = garages.state()
	check((gsaved.get("build_cut", []) as Array).has(String(depot)), "kayıtta inşaat işareti")
	garages._building.erase(depot)
	garages._build_cut.clear()
	check(not garages.state().has("build_cut"), "kısaltma yokken kayıt biçimi eskisiyle aynı")
	# Arayüz: modifiye ekranında süren takmada REKLAM İZLE (kısa kalan sürede yok)
	var cut: AdOfferButton = AdOfferButton.new(AdPolicy.TIME_SKIP)
	cut.condition = func() -> bool: return false
	hud.add_child(cut)
	await frames(2)
	check(not cut.visible, "koşul tutmuyorsa (kısaltılacak süre yok) düğme gizli")
	cut.queue_free()


func _daily_double() -> void:
	print("== 4) Günlük giriş merdiveni ×2 ==")
	await _ready_ads()
	var gem: GemRewards = g(&"gem_rewards") as GemRewards
	var pp: PlayerProgress = g(&"player_progress")
	gem.check_day()
	check(gem.ladder_double().is_empty(), "basamak alınmadan ×2 teklifi yok")
	pp.load_state(8, 0, 0)
	hud.router.open(&"login_ladder")
	await seconds(0.6)
	(hud.login_ladder_screen.get("_claim") as PlateButton).pressed.emit()
	await frames(4)
	(hud.login_ladder_screen.get("_reward_popup") as RewardPopup).close()
	await seconds(0.6)
	var extra: Dictionary = gem.ladder_double()
	var gems: int = pp.gems
	check(not extra.is_empty() and int(extra["gems"]) > 0, "basamak alındı, ×2 teklifi var (+%d gem)" % int(extra.get("gems", 0)))
	var button: AdOfferButton = _offer(hud.login_ladder_screen, AdPolicy.DAILY_DOUBLE)
	check(button != null and button.visible, "merdiven panosunda GÜNLÜK GİRİŞ ×2")
	await _press(button)
	check(pp.gems == gems + int(extra["gems"]) and gem.ladder_double().is_empty(), "reklam sonrası +%d elmas, bugün bir daha yok" % int(extra["gems"]))
	var saved: Dictionary = gem.state()
	gem.load_state(saved)
	check(gem.ladder_double().is_empty(), "kayıt: ikiye katlandı işareti kalır")
	hud.router.close_all()
	await seconds(0.5)


func _levelup_double() -> void:
	print("== 5) SEVİYE ATLADIN ₺ ×2 ==")
	await _ready_ads()
	var eco: EconomyManager = g(&"economy")
	var screen: LevelUpScreen = hud.level_up_screen
	eco.set_money(0)
	screen.add_level(9, 2500)
	screen._open()
	await seconds(0.8)
	var button: AdOfferButton = _offer(screen, AdPolicy.LEVELUP_DOUBLE)
	check(button != null and button.visible and button.text.contains("2.500"), "DEVAM ET'in yanında REKLAM İZLE +2.500 ₺")
	check(eco.money == 0, "ekran açılınca reklam kendiliğinden açılmadı")
	await _press(button)
	check(eco.money == 2500 and not button.visible, "reklam sonrası +2.500 ₺, teklif kalktı")
	screen.close()
	await seconds(0.6)


func _mission_reroll() -> void:
	print("== 6) Günlük görevi değiştir ==")
	await _ready_ads()
	var missions: MissionManager = g(&"missions") as MissionManager
	missions.ensure_current()
	var tasks: Array[Dictionary] = missions.daily_tasks()
	var index: int = -1
	for i: int in tasks.size():
		if not bool(tasks[i].get("done", false)):
			index = i
			break
	check(index >= 0, "bitmemiş günlük görev var")
	if index < 0:
		return
	var old_metric: StringName = tasks[index]["metric"]
	var others: Array = []
	for i: int in tasks.size():
		if i != index:
			others.append(tasks[i]["metric"])
	hud.router.open(&"quests")
	await seconds(0.6)
	hud.quest_screen._on_tab_pressed(MissionScreen.Tab.DAILY)
	await frames(4)
	var buttons: Array = hud.quest_screen.find_children("AdOffer_mission_reroll", "", true, false)
	check(not buttons.is_empty() and (buttons[0] as AdOfferButton).visible, "bitmemiş görevde GÖREVİ DEĞİŞTİR teklifi")
	# İlk bitmemiş görevin düğmesi (plakalar sırayla)
	await _press(buttons[0] as AdOfferButton)
	var after: Dictionary = missions.daily_tasks()[index]
	check(after["metric"] != old_metric and not others.has(after["metric"]), "görev değişti (%s → %s), öteki görevlerle çakışmıyor"
		% [old_metric, after["metric"]])
	check(int(missions.progress_of(after, false)) == 0, "yeni görev sıfırdan başlar")
	await frames(4)
	var left: Array = hud.quest_screen.find_children("AdOffer_mission_reroll", "", true, false).filter(
		func(n: Node) -> bool: return (n as AdOfferButton).visible)
	check(left.is_empty(), "günde bir: başka DEĞİŞTİR teklifi yok")
	hud.router.close_all()
	await seconds(0.5)


func _junk_refill() -> void:
	print("== 7) Hurdalık yığını doldur ==")
	var jy: JunkyardManager = g(&"junkyard") as JunkyardManager
	check(jy.refill_pile() == -1, "boş yığın yokken bir şey olmaz")
	var result: Dictionary = jy.search_pile(0)
	check(bool(result["ok"]) and not jy.pile_ready(0), "aranan yığın boşaldı")
	check(jy.refill_pile() == 0 and jy.pile_ready(0), "reklam ödülü: yığın hemen doldu")


func _remote() -> void:
	print("== 8) Panel ayarı (config/app.ads) ==")
	config.apply({"ads": {"free_gems": 9, "free_gems_cooldown": 30, "caps": {"junk_refill": 0}}})
	await frames(2)
	check(AdPolicy.free_gems() == 9 and AdPolicy.cooldown_sec(AdPolicy.FREE_GEMS) == 30, "panel: elmas 9, bekleme 30 sn")
	check(ads.block_reason(AdPolicy.JUNK_REFILL) == AdPolicy.DAILY_CAP, "panelde kapatılan teklif sunulmuyor")
	config.apply({})
	await frames(2)
	check(AdPolicy.free_gems() == AdPolicy.FREE_GEMS_AMOUNT and AdPolicy.daily_cap(AdPolicy.JUNK_REFILL) == 2, "ayar kalkınca varsayılan")
