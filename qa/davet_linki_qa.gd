extends SceneTree
## ARKADAŞ DAVET LİNKİ QA (2026-10-17): linkle açılış (`-- --davet=<jeton>`) davet ekranını açıyor mu; ekranın durumları
## (eklenebilir / eklendi / süresi dolmuş / giriş gerekli / PC) ve ARKADAŞLAR'daki DAVET LİNKİ GÖNDER düğmesi; PC'de
## paylaşım panoya kopyalıyor mu. Masaüstünde Firebase yok: durumlar örnek profille (Emre) taklit edilir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/davet_linki_qa.gd --display-driver x11 --resolution 1170x540 \
##     -- --davet=ABCDEFGHJKLM
## Kareler: /home/burak/Projects/ct_shots/davet/<genişlik>x<yükseklik>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/davet/"

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await create_timer(0.45).timeout
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
	var screen: InviteScreen = hud.invite_screen

	print("1) Linkle açılış")
	await create_timer(1.0).timeout
	check(router.top() == &"invite" and screen.token() == "ABCDEFGHJKLM", "link davet ekranını açtı (%s)" % router.top())
	check(screen.state() == "unavailable", "PC: arkadaşlık yok durumu (%s)" % screen.state())
	await shot("01_pc")

	print("2) Durumlar (örnek profil)")
	var person: Dictionary = FeaturedFriends.all()[0]
	screen._invite = {"status": "ok", "token": "ABCDEFGHJKLM", "uid": person["uid"], "name": person["name"], "person": person}
	for state: String in ["ok", "done", "expired", "signin"]:
		screen._show(state)
		check(screen.state() == state and screen._primary.visible, "durum %s: %s" % [state, screen._primary.text])
		await shot("02_" + state)
	screen.close()
	await create_timer(0.5).timeout
	check(router.top() == &"" and InviteLinks.pending.is_empty(), "kapatınca davet beklemede kalmadı")

	print("3) ARKADAŞLAR: DAVET LİNKİ GÖNDER")
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	social._uid = "qa"
	social._meta = {"uid": "qa", "name": "Burak", "code": "ABC234"}
	social._state = SocialManager.State.READY   # QA taklidi: profil hazır
	router.open(&"friends")
	await create_timer(0.5).timeout
	var friends: FriendsScreen = router.screen(&"friends") as FriendsScreen
	friends._refresh()
	check(friends._invite_button.visible and friends._invite_button.is_visible_in_tree(), "davet düğmesi görünür")
	await shot("03_arkadaslar")
	router.close_all()

	print("4) Paylaşım (PC: panoya)")
	var how: String = LinkShare.share("deneme " + SocialManager.INVITE_URL + "ABCDEFGHJKLM", "başlık")
	check(how == "copied" and DisplayServer.clipboard_get().ends_with("ABCDEFGHJKLM"), "PC'de link panoya kopyalandı")
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
