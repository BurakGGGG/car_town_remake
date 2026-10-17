extends SceneTree
## YARIŞ BİLDİRİMİ ÖNERİSİ + AYARLAR QA (2026-10-17): ilk yarıştan sonra öneri (PushPrompt) yalnızca oyuncu şehre dönüp
## boşta kalınca açılıyor mu, TAMAM izin + jeton akışını başlatıyor mu, bir kez mi soruluyor; AYARLAR → SES VE
## BİLDİRİMLER satırı (açık / kapalı, girişsiz kilit, son hatanın nedeni). Kareler alınır.
## Masaüstünde Google oturumu yok: PushService.force_available + sosyal durum READY taklidi (yalnız QA).
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

	print("1) Girişsiz: ayarlarda kilitli, öneri kurulmaz")
	PushService.force_available = true
	push._state = {}
	check(push.unavailable_reason() == "signin" and not push.should_ask(), "misafirde öneri yok (neden: %s)" % push.unavailable_reason())
	hud._arm_push_prompt()
	check(not is_instance_valid(hud._push_prompt_timer), "misafirde yarış sonrası öneri kurulmadı")
	router.open(&"settings")
	await create_timer(0.6).timeout
	var settings: SettingsScreen = router.screen(&"settings") as SettingsScreen
	settings._show_page(SettingsScreen.Page.AUDIO)
	await create_timer(0.3).timeout
	check(settings._push_row.visible and settings._push_toggle.disabled, "AYARLAR: satır görünür, girişsiz kilitli")
	await shot("01_ayarlar_girissiz")
	router.close_all()
	await create_timer(0.5).timeout

	print("2) Girişli: yarış sonrası öneri, boşta kalınca")
	social._state = SocialManager.State.READY   # QA taklidi: Google oturumu açık
	check(push.should_ask(), "girişli ve henüz sorulmadı: öneri sorulabilir")
	hud._arm_push_prompt()
	router.open(&"quests")   # sonuç / rövanş ekranı yerine: pano açıkken öneri ÇIKMAZ
	await create_timer(2.5).timeout
	check(router.top() == &"quests", "pano açıkken öneri beklemede")
	router.close_all()
	await create_timer(Hud.PUSH_PROMPT_IDLE + 1.0).timeout
	check(router.top() == &"push_prompt", "şehre dönüp boşta kalınca öneri açıldı")
	check(not push.should_ask(), "gösterildi: bir daha sorulmaz")
	await create_timer(0.4).timeout
	await shot("02_oneri")

	print("3) TAMAM → izin + jeton akışı")
	var prompt: PushPrompt = router.screen(&"push_prompt") as PushPrompt
	prompt._ok.pressed.emit()
	await create_timer(3.0).timeout
	check(router.top() != &"push_prompt", "TAMAM sonrası öneri kapandı")
	note_state(push)
	hud._arm_push_prompt()
	check(not is_instance_valid(hud._push_prompt_timer), "ikinci yarıştan sonra öneri yok")

	print("4) AYARLAR satırı")
	router.open(&"settings")
	await create_timer(0.6).timeout
	settings._show_page(SettingsScreen.Page.AUDIO)
	await create_timer(0.3).timeout
	check(settings._push_row.visible and not settings._push_toggle.disabled, "girişli: anahtar kullanılabilir")
	check(settings._push_toggle.button_pressed == push.is_enabled(), "anahtar durumu doğru (%s)" % ("AÇIK" if push.is_enabled() else "KAPALI"))
	await shot("03_ayarlar")
	router.close_all()
	PushService.force_available = false
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)


func note_state(push: PushService) -> void:
	print("  ·    bildirim %s; son hata: \"%s\"" % ["AÇIK" if push.is_enabled() else "KAPALI", push.last_failure])
