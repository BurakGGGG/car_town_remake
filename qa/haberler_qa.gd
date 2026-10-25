extends SceneTree
## HABERLER kutusu görsel denetimi (2026-10-25): telefon tuvalinde (pencere 1152x648 + content_scale 1,35 = 853x480; geniş
## telefon 1440x648 → 1067x480) sağ üst tabela sırası, HEDİYEN VAR yazısı ve kutunun her tür haberle görünümü.
##   tools/qa_isolated.sh res://qa/haberler_qa.gd --resolution 1152x648 [--display-driver x11]
##   QA_LANG=en tools/qa_isolated.sh … (diğer diller)
## Kareler ~/Projects/ct_shots/haberler/. Ağ yok: haberler NewsFeed.apply ile, kapak resimleri dokudan verilir.

const OUT: String = "/home/burak/Projects/ct_shots/haberler/"
const POSTER_EVENT: String = "https://firebasestorage.googleapis.com/v0/b/qa/o/news%2Fetkinlik.jpg?alt=media&token=qa"
const POSTER_CAR: String = "https://firebasestorage.googleapis.com/v0/b/qa/o/news%2Farac.jpg?alt=media&token=qa"

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
	if not OS.get_cmdline_user_args().has("masaustu"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var config: AppConfig = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""   # ağ yok
	root.add_child(config)
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current()]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var mail: MailService = get_first_node_in_group("mail") as MailService
	var feed: NewsFeed = NewsFeed.of(self)
	check(hud.inbox_button != null and feed != null and mail != null, "tabela, akış ve posta kurulu")
	var now: int = int(Time.get_unix_time_from_system())
	var screen: InboxScreen = hud.inbox_screen
	var images: InboxImages = screen.get("_images") as InboxImages
	images.set("_textures", {POSTER_EVENT: load("res://assets/world/billboard/porsche_gt3.jpg"),
		POSTER_CAR: load("res://assets/world/billboard/bugatti_chiron.jpg")})

	feed.apply([
		{"id": "n_event", "kind": "event", "pinned": true, "image": POSTER_EVENT, "at": now - 3 * 3600, "end": now + 86400 + 14 * 3600,
			"title": {"tr": "HAFTA SONU ETKİNLİĞİ: ÇİFTE PARA", "en": "WEEKEND EVENT: DOUBLE CASH"},
			"text": {"tr": "Cuma 20:00'den pazar gece yarısına kadar bütün tamirlerden 2 kat para.",
				"en": "From Friday 8 PM to Sunday midnight, every repair pays double."},
			"action": {"kind": "event"}},
		{"id": "n_notes", "kind": "update", "code": 0, "at": now - 86400 - 3600,
			"title": {"tr": "1.2.0 · YENİ NELER VAR?", "en": "1.2.0 · WHAT'S NEW?"},
			"text": {"tr": "• HABERLER kutusu: hediyeler, etkinlikler ve duyurular tek yerde\n• Posta hediyeleri artık her zaman geliyor\n• Şehirde daha akıcı görüntü (pişmiş gölgeler)\n• Teker ve lastik görünümü düzeltildi\n• Küçük hata düzeltmeleri",
				"en": "• NEWS box: gifts, events and announcements in one place\n• Mail gifts now always arrive\n• Smoother city (baked shadows)\n• Wheel and tire fixes\n• Small bug fixes"}},
		{"id": "n_car", "kind": "notice", "image": POSTER_CAR, "at": now - 2 * 86400,
			"title": {"tr": "YENİ SÜPER ARAÇ SHOWROOM'DA", "en": "NEW SUPERCAR IN THE SHOWROOM"},
			"text": {"tr": "OVALE TONNERRE 16 artık showroom'da. Kim ilk alacak?", "en": "OVALE TONNERRE 16 is now in the showroom. Who gets it first?"},
			"action": {"kind": "showroom"}},
		{"id": "n_bakim", "kind": "notice", "at": now - 3 * 86400,
			"title": {"tr": "28 EKİM 03:00 · KISA BAKIM", "en": "OCT 28 03:00 · SHORT MAINTENANCE"},
			"text": {"tr": "Sunucularımızı güçlendiriyoruz; bir saatliğine bulut kaydı ve arkadaş özellikleri kapalı olacak.",
				"en": "We're upgrading our servers; cloud save and friend features will be off for an hour."}},
	])
	var decor: String = "tool_cabinet"
	var crate: String = String(CrateCatalog.all()[0]["id"])
	mail._remember(MailService.normalize("m_welcome", {"title": {"tr": "HOŞ GELDİN HEDİYESİ", "en": "WELCOME GIFT"},
		"text": {"tr": "Garajına hoş geldin usta!", "en": "Welcome to your garage!"}, "from": "AUTO YARD", "money": 5000,
		"at": now - 12 * 86400}), {"money": 5000, "items": []})
	mail._pending = [
		MailService.normalize("m_gift", {"title": {"tr": "HAFTA SONU HEDİYESİ", "en": "WEEKEND GIFT"},
			"text": {"tr": "Garajına küçük bir sürpriz bıraktık. İyi tamirler usta!", "en": "We left a little surprise in your garage. Happy repairs!"},
			"from": "AUTO YARD", "money": 5000, "gems": 20, "decor": {decor: 1}, "at": now - 2 * 3600, "expires": now + 30 * 86400}),
		MailService.normalize("m_kupon", {"title": {"tr": "KUPON ÖDÜLÜ: GARAJ50", "en": "COUPON REWARD: GARAJ50"},
			"text": {"tr": "GARAJ50 kodunun ödülü seni bekliyor.", "en": "Your GARAJ50 reward is waiting."},
			"from": "AUTO YARD", "crates": {crate: 1}, "at": now - 5 * 3600, "expires": now + 2 * 86400 - 600}),
	]
	mail.arrived.emit()
	await create_timer(0.7).timeout
	check(hud.inbox_button.badge >= 6, "rozet: hediyeler + yeni haberler (%d)" % hud.inbox_button.badge)
	await shot("01_tabela_hediyen_var")

	hud.router.open(&"inbox")
	await create_timer(0.8).timeout
	var column: Control = screen.find_child("Column", true, false) as Control
	var view: Rect2 = root.get_visible_rect()
	check(view.encloses(column.get_global_rect().grow(-1.0)), "kutu ekrana sığıyor (%s / %s)" % [column.get_global_rect(), view])
	check(screen.selected() == "m_gift", "alınmamış ilk hediye seçili")
	await shot("02_kutu_hediye")
	for pair: Array in [["n_event", "03_etkinlik"], ["n_notes", "04_guncelleme_notu"], ["n_car", "05_resimli_duyuru"],
			["m_kupon", "06_son_gunler"], ["m_welcome", "07_alinmis"]]:
		screen.select(pair[0])
		await create_timer(0.3).timeout
		await shot(pair[1])
	screen.select("m_gift")
	await create_timer(0.2).timeout
	(screen.find_child("ActionButton", true, false) as PlateButton).pressed.emit()
	await create_timer(1.2).timeout
	await shot("08_al_odul")
	check(bool(hud.inbox.item("m_gift").get("claimed", false)), "AL: hediye alındı")
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)
