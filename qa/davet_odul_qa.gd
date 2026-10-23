extends SceneTree
## ARKADAŞ DAVETİ ödülü QA (2026-10-23, docs/ARKADAS_DAVET.md Faz 2): DAVET ET sekmesi (4/10, 4. basamak hazır, davet
## edilenler), yeni hesapta kod girişi, 10. basamakta seçim hakkı, POSTA'nın davet görünümleri (hoş geldin, basamak),
## efsanevi araç seçimi ve DAVETÇİ / ELÇİ çerçeveleri. Masaüstünde Firebase yok: oturum ve veri taklit edilir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/davet_odul_qa.gd --display-driver x11 --disable-vsync --resolution 853x480
##   Telefon tuvali: --resolution 1152x648 -- mobil
## Kareler: /home/burak/Projects/ct_shots/davet/<genişlik>x<yükseklik>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/davet/"
const NAMES: Array[String] = ["Mert", "Zeynep", "Can", "Ece", "Kaan"]
const CARS: Array[String] = ["bmw_e60", "vw_golf_7", "hyundai_getz", "tofas_sahin", "ford_focus"]

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("mobil"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _person(uid: String, name: String, level: int, car: String, av: String) -> Dictionary:
	var e: Dictionary = (FeaturedFriends.all()[0] as Dictionary).duplicate(true)
	e.merge({"uid": uid, "name": name, "level": level, "car": car, "flag": "TR", "featured": false, "code": "ABC%03d" % level,
		"av": av, "frame": "", "ask_part": "", "ask_at": 0}, true)
	return e


func _tier_mail(n: int, friend: String, name: String) -> Dictionary:
	var doc: Dictionary = (ReferralRewards.tier(n) as Dictionary).duplicate(true)
	doc.merge({"title": "%s katıldı! %d. davet ödülün" % [name, n],
		"text": "Davet ettiğin arkadaşın oyuna katıldı ve 3. seviyeye ulaştı. Teşekkürler!", "from": "AUTO YARD",
		"referral": "tier_%d" % n, "friend": friend, "at": 600 + n}, true)
	return MailService.normalize("ref_%d" % n, doc)


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s" % [roundi(canvas.x), roundi(canvas.y), "tuval_" if OS.get_cmdline_user_args().has("mobil") else ""]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var router: UiRouter = hud.router
	var screen: FriendsScreen = hud.friends_screen
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	var referral: ReferralManager = get_first_node_in_group("referral") as ReferralManager
	var mail: MailService = get_first_node_in_group("mail") as MailService
	check(referral != null and mail != null and hud.legendary_pick_screen != null, "ReferralManager, posta, seçim ekranı kurulu")

	# Oturum + arkadaşlar (davet edilenler otomatik arkadaş)
	social._uid = "qa"
	social._meta = {"uid": "qa", "name": "Burak", "code": "K7P2QX"}
	social.friends.clear()
	for i: int in NAMES.size():
		social.friends.append(_person("f%d" % i, NAMES[i], [7, 5, 4, 3, 2][i], CARS[i], "p%02d" % (2 + i * 2)))
	social.incoming.clear()
	social.outgoing.clear()
	social.race_events.clear()
	social._state = SocialManager.State.READY
	social.changed.emit()   # ReferralManager yeni oturumu görsün (sayaçları sıfırlar); sahte veri ondan sonra
	await process_frame
	referral._loaded_at = Time.get_ticks_msec() / 1000.0 + 3600.0   # sahte veri: sunucudan okumasın
	referral.count = 4
	referral.joined_total = 5
	referral.invited.clear()
	for i: int in NAMES.size():
		referral.invited.append({"uid": "f%d" % i, "at": 100 + i, "state": "qualified" if i < 4 else "joined",
			"tier": i + 1 if i < 4 else 0, "src": "link"})
	mail._pending = [_tier_mail(4, "f3", "Ece")]

	print("1) DAVET ET sekmesi")
	router.open(&"friends")
	await create_timer(0.4).timeout
	check((screen._tabs[FriendsScreen.Tab.INVITE] as PlateButton).button_pressed, "ödül bekliyorken DAVET ET'te açıldı")
	check((screen._tabs[FriendsScreen.Tab.INVITE] as PlateButton).badge == 1, "sekme rozeti 1 (4. basamak)")
	var tab: ReferralTab = screen.find_child("ReferralTab", true, false) as ReferralTab
	check(tab != null and tab.visible and not screen.find_child("Showcase", true, false).visible, "sekme görünür, vitrin gizli")
	check(tab.find_child("Tiles", true, false).get_child_count() == 9 and tab.find_child("Take4", true, false) != null,
		"9 basamak + 4. basamakta AL")
	check((tab.find_child("Counter", true, false) as Label).text == "4 / 10", "sayaç 4 / 10")
	check((tab.find_child("MyCode", true, false) as Label).text == "AY-K7P2QX", "davet kodu")
	check(tab.find_child("Invited", true, false).get_child_count() == 5, "5 davet edilen")
	check(hud.friends_button.badge >= 1, "alt sıradaki ARKADAŞLAR rozetinde davet ödülü")
	await _fits(screen, "DAVET ET")
	await shot("01_davet_et")

	print("2) Yeni hesap: kod girişi")
	mail._pending = []
	referral.count = 0
	referral.invited.clear()
	referral.status = ""
	ReferralManager._write_meta({})
	screen._refresh()
	await create_timer(0.3).timeout
	check(tab.find_child("ReferralCodeEdit", true, false) != null, "SENİ BİR ARKADAŞIN MI ÇAĞIRDI? kod alanı")
	await _fits(screen, "kod girişi")
	await shot("02_kod_gir")

	print("3) 10. basamak: seçim hakkı")
	referral.count = 10
	referral.car_choices = 1
	for i: int in NAMES.size():
		referral.invited.append({"uid": "f%d" % i, "at": 100 + i, "state": "qualified", "tier": i + 6, "src": "link"})
	screen._refresh()
	await create_timer(0.3).timeout
	check(tab.find_child("PickButton", true, false) != null, "ARACINI SEÇ düğmesi")
	await shot("03_secim_hakki")
	router.close_all()
	await create_timer(0.4).timeout

	print("4) POSTA: hoş geldin")
	var notice: MailNotice = hud.mail_notice
	referral.status = "ok"
	referral.referrer = "f0"
	var welcome: Dictionary = MailService.normalize("ref_welcome", {"title": "Davet hediyen!",
		"text": "Mert seni Auto Yard'a çağırdı. Hoş geldin usta!", "from": "AUTO YARD", "gems": 50, "money": 5000,
		"referral": "welcome", "at": 500})
	notice._open(welcome)
	await create_timer(0.5).timeout
	check((notice.find_child("SignTitle", true, false) as Label).text == Loc.t("DAVETLE GELDİN!"), "tabela DAVETLE GELDİN!")
	await shot("04_hos_geldin")
	notice.hide()
	notice._current = ""

	print("5) POSTA: basamak ödülü")
	notice._open(_tier_mail(4, "f3", "Ece"))
	await create_timer(0.5).timeout
	check(notice.find_child("ReferralDots", true, false) != null, "basamak ilerlemesi")
	await shot("05_basamak")
	notice.hide()
	notice._current = ""
	notice._open(_tier_mail(10, "f4", "Kaan"))
	await create_timer(0.5).timeout
	await shot("05b_basamak_10")
	notice.hide()
	notice._current = ""

	print("6) Efsanevi araç seçimi")
	router.open(&"legendary_pick")
	await create_timer(0.5).timeout
	var pick: LegendaryPickScreen = hud.legendary_pick_screen
	var choices: Array[StringName] = pick.choices()
	check(pick.visible and choices.size() == referral.car_pool().size() and not choices.is_empty(), "%d araç kartı" % choices.size())
	await shot("06_arac_sec")
	pick.pick(choices[mini(2, choices.size() - 1)])
	await create_timer(0.3).timeout
	check(not (pick.find_child("ConfirmButton", true, false) as PlateButton).disabled, "seçince AL açılır")
	await shot("07_secildi")
	router.close_all()
	await create_timer(0.4).timeout

	print("7) Çerçeveler")
	var host: HBoxContainer = HBoxContainer.new()
	host.add_theme_constant_override(&"separation", 40)
	host.position = Vector2(60.0, 120.0)
	hud.get_node("Root").add_child(host)
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	for frame: String in ["silver", "inviter", "gold", "envoy"]:
		var avatar: AvatarView = AvatarView.new()
		avatar.custom_minimum_size = Vector2(150.0, 150.0)
		avatar.show_avatar(profile.my_texture(), profile.my_illustrated(), frame, "TR")
		host.add_child(avatar)
	await shot("08_cerceveler")
	host.queue_free()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Pencere tuvale sığıyor mu (taşan düğüm yok).
func _fits(screen: FriendsScreen, what: String) -> void:
	await process_frame
	var view: Rect2 = root.get_visible_rect()
	var window: Control = screen.find_child("Window", true, false) as Control
	var rect: Rect2 = window.get_global_rect()
	check(view.encloses(rect.grow(-1.0)), "%s: pencere tuvalde (%s ⊂ %s)" % [what, rect, view])
	var tab: Control = screen.find_child("ReferralTab", true, false) as Control
	var tab_rect: Rect2 = tab.get_global_rect()
	check(rect.encloses(tab_rect.grow(-1.0)), "%s: sekme pencerenin içinde" % what)
