extends SceneTree
## BİLDİRİM ÖNERİSİ + AYARLAR QA (2026-10-17; 2026-10-21 genel bildirim): ilk yarıştan sonra öneri (PushPrompt) yalnızca
## oyuncu şehre dönüp boşta kalınca açılıyor mu, TAMAM izin + jeton + DUYURU konusu akışını başlatıyor mu, bir kez mi
## soruluyor; AYARLAR → SES VE BİLDİRİMLER: BİLDİRİMLER ana anahtarı + üç tür (misafirde YARIŞ / HEDİYE kilitli, DUYURU
## konuya abonelik). Kareler alınır.
## Masaüstünde Google oturumu yok: PushService.force_available + sosyal oturum taklidi (yalnız QA).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/bildirim_onerisi_qa.gd --display-driver x11 --resolution 1170x540
## Kareler: /home/burak/Projects/ct_shots/bildirim/<genişlik>x<yükseklik>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/bildirim/"

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var size: Vector2i = root.get_window().size
	prefix = "%dx%d_" % [size.x, size.y]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var router: UiRouter = hud.router
	var push: PushService = get_first_node_in_group("push") as PushService
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	var welcome: int = crates.welcome_uid()
	if welcome > 0 and not crates.open(welcome).is_empty():
		crates.claim(welcome)
	PushService.force_available = true
	push._state = {}

	print("1) Misafir: yarış sonrası öneri, boşta kalınca")
	check(push.available() and push.should_ask() and not push.has_account(), "misafir de bildirim açabilir (duyurular)")
	hud._arm_push_prompt()
	router.open(&"quests")   # sonuç / rövanş ekranı yerine: pano açıkken öneri ÇIKMAZ
	await create_timer(2.5).timeout
	check(router.top() == &"quests", "pano açıkken öneri beklemede")
	router.close_all()
	await create_timer(Hud.PUSH_PROMPT_IDLE + 1.0).timeout
	check(router.top() == &"push_prompt", "şehre dönüp boşta kalınca öneri açıldı")
	check(not push.should_ask(), "gösterildi: bir daha sorulmaz")
	await create_timer(0.4).timeout
	await shot("01_oneri")

	print("2) AÇ → izin + jeton + DUYURU konusu → 20 gem ödül penceresi (2026-11-04)")
	var prompt: PushPrompt = router.screen(&"push_prompt") as PushPrompt
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var community: CommunityLinks = get_first_node_in_group("community") as CommunityLinks
	community.load_state({})
	var gems_before: int = progress.gems
	check(prompt._pill.visible, "öneride +20 GEM etiketi")
	prompt._ok.pressed.emit()
	await create_timer(3.0).timeout
	check(router.top() != &"push_prompt", "AÇ sonrası öneri kapandı")
	check(push.is_enabled() and push.fake_topic == "news_" + Loc.current(), "açık, konu %s" % push.fake_topic)
	check(hud.push_reward_popup.visible and progress.gems == gems_before + CommunityLinks.PUSH_GEMS,
		"ödül penceresi + %d gem (%d → %d)" % [CommunityLinks.PUSH_GEMS, gems_before, progress.gems])
	await create_timer(1.2).timeout
	await shot("01b_odul")
	hud.push_reward_popup.close()
	await create_timer(1.5).timeout
	check(not community.push_reward_open(), "ödül alındı: bir daha verilmez")
	hud._arm_push_reward()
	check(not is_instance_valid(hud._push_reward_timer), "ikinci ödül zamanlayıcısı kurulmadı")
	hud._arm_push_prompt()
	check(not is_instance_valid(hud._push_prompt_timer), "ikinci yarıştan sonra öneri yok")

	print("3) AYARLAR (misafir)")
	router.open(&"settings")
	await create_timer(0.6).timeout
	var settings: SettingsScreen = router.screen(&"settings") as SettingsScreen
	settings._show_page(SettingsScreen.Page.AUDIO)
	await create_timer(0.3).timeout
	var race: PlateButton = settings._push_kinds[PushService.RACE]
	var gift: PlateButton = settings._push_kinds[PushService.GIFT]
	var news: PlateButton = settings._push_kinds[PushService.NEWS]
	check(settings._push_toggle.button_pressed and race.is_visible_in_tree(), "ana anahtar AÇIK, türler görünür")
	check(race.disabled and gift.disabled and not news.disabled and news.button_pressed, "misafir: YARIŞ / HEDİYE kilitli, DUYURU açık")
	await shot("02_ayarlar_misafir")
	news.button_pressed = false
	news.pressed.emit()
	await create_timer(0.4).timeout
	check(not push.pref(PushService.NEWS) and push.fake_topic == "", "DUYURU kapatıldı: konudan çıkıldı")
	news.button_pressed = true
	news.pressed.emit()
	await create_timer(0.4).timeout
	check(push.fake_topic == "news_" + Loc.current(), "DUYURU yeniden açık: konuya abone")

	print("4) AYARLAR (hesaplı taklidi)")
	social._uid = "qa_uid"
	settings._refresh()
	await create_timer(0.3).timeout
	check(not race.disabled and not gift.disabled, "hesaplı: YARIŞ / HEDİYE kullanılabilir")
	await shot("03_ayarlar_hesapli")
	settings._push_toggle.button_pressed = false
	settings._push_toggle.pressed.emit()
	await create_timer(0.6).timeout
	check(not push.is_enabled() and push.fake_topic == "" and not race.is_visible_in_tree(), "KAPAT: konudan çıkıldı, türler gizli")
	await shot("04_ayarlar_kapali")
	print("5) Güncellemeden sonra: eski öneriyi görmüş, bildirimi kapalı oyuncuya bir kez daha")
	social._uid = ""
	router.close_all()
	push._state = {"asked": true}
	check(push.wants_reask(), "eski öneriyi görmüş: yeniden sorulacak")
	hud._arm_push_reask()
	await create_timer(Hud.PUSH_PROMPT_IDLE + 1.0).timeout
	check(router.top() == &"push_prompt", "sakin anda yeni öneri açıldı")
	await create_timer(0.5).timeout
	(router.screen(&"push_prompt") as PushPrompt)._later.pressed.emit()
	await create_timer(0.6).timeout
	check(not push.should_ask() and not push.wants_reask(), "ŞİMDİ DEĞİL: bu sürüm bir daha sorulmaz")
	print("6) Önceden açmış oyuncu: güncellemeden sonra 20 gem kendiliğinden")
	community.load_state({})
	push._state = {"asked": true, "enabled": true}
	gems_before = progress.gems
	hud._arm_push_reward()
	await create_timer(2.0).timeout
	check(hud.push_reward_popup.visible and progress.gems == gems_before + CommunityLinks.PUSH_GEMS, "ödül penceresi açıldı")
	hud.push_reward_popup.close()
	await create_timer(1.0).timeout
	router.close_all()
	PushService.force_available = false
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
