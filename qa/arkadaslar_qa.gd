extends SceneTree
## ARKADAŞLAR ekranı QA (2026-10-17 yeniden tasarım): kalabalık sahte veriyle (10 arkadaş, istek, haber) vitrin, sekmeler,
## KODLA EKLE penceresi ve misafir durumu. Yalnızca vitrin kayıyor mu, başlık / ✕ yerinde mi; düğüm adları
## (Visit_ / Gift_ / Revenge_ / Person_) duruyor mu. Masaüstünde Firebase yok: oturum ve veri taklit edilir.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/arkadaslar_qa.gd --display-driver x11 --resolution 853x480
## Kareler: /home/burak/Projects/ct_shots/arkadas/<genişlik>x<yükseklik>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/arkadas/"
const CARS: Array[String] = ["bmw_e60", "vw_golf_7", "hyundai_getz", "lambo_huracan", "tofas_sahin", "renault_fluence",
	"anadol_a1", "alfa_romeo_159", "aston_martin_db5", "ford_focus"]

var fails: int = 0
var prefix: String = ""


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + prefix + file + ".png")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _person(uid: String, name: String, level: int, car: String) -> Dictionary:
	var e: Dictionary = (FeaturedFriends.all()[0] as Dictionary).duplicate(true)
	e.merge({"uid": uid, "name": name, "level": level, "car": car, "flag": "TR", "featured": false, "code": "ABC%03d" % level,
		"av": "", "ask_part": "", "ask_at": 0}, true)
	return e


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var size: Vector2i = root.get_window().size
	prefix = "%dx%d_" % [size.x, size.y]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var router: UiRouter = hud.router
	var screen: FriendsScreen = hud.friends_screen

	print("1) Misafir")
	router.open(&"friends")
	await create_timer(0.6).timeout
	check(screen.find_child("Visit_featured_emre", true, false) != null, "ustalar vitrinde")
	await shot("01_misafir")
	router.close_all()

	print("2) Kalabalık liste")
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	social._uid = "qa"
	social._meta = {"uid": "qa", "name": "Burak", "code": "ABC234"}
	var names: Array[String] = ["Ayşe", "Mert", "Zeynep", "Can", "Deniz", "Ece", "Kaan", "Selin", "Onur", "Ufuk"]
	social.friends.clear()
	for i: int in names.size():
		social.friends.append(_person("f%d" % i, names[i], 5 + i * 3, CARS[i]))
		social.friends[i]["stats"] = {"wins": 3 + i * 4, "races": 8 + i * 5, "cars": 6 + i * 2, "best": 11200 + i * 310}
	social.friends[1]["ask_part"] = "bolt"   # hurdalık isteği: GÖNDER
	social.friends[1]["ask_at"] = int(Time.get_unix_time_from_system())
	social.incoming.clear()
	social.incoming.append(_person("r1", "Tolga", 9, "ford_focus"))
	social.incoming.append(_person("r2", "Melis", 14, ""))
	social.outgoing.clear()
	social.outgoing.append(_person("o1", "Berk", 7, ""))
	var event: Dictionary = _person("f1", "Mert", 8, "vw_golf_7")
	event.merge({"their_car": &"bmw_e60", "won": true, "revenge": false}, true)
	social.race_events.clear()
	social.race_events.append(event)
	social._state = SocialManager.State.READY
	router.open(&"friends")
	await create_timer(0.6).timeout
	screen._notice_text = ""   # PC'de yenileme Firebase'e ulaşamaz: taklit verinin üstüne hata yazmasın
	screen._refresh()
	check((screen._tabs[FriendsScreen.Tab.NEWS] as PlateButton).button_pressed, "haber varken HABERLER sekmesinde açıldı")
	check(screen.find_child("Revenge_f1", true, false) != null, "İNTİKAM AL düğmesi")
	await shot("02_haberler")
	screen._select_tab(FriendsScreen.Tab.FRIENDS)
	await create_timer(0.3).timeout
	check(screen.find_child("Visit_f9", true, false) != null and screen.find_child("Gift_f1", true, false) != null,
		"arkadaş kartları: GARAJA GİT ve GÖNDER")
	check((screen._tabs[FriendsScreen.Tab.REQUESTS] as PlateButton).badge == 2, "İSTEKLER rozeti 2")
	var tallest: float = 0.0
	for card: Control in screen._cards.get_children():
		tallest = maxf(tallest, card.get_combined_minimum_size().y)
	check(tallest <= screen._scroll.size.y + 0.5, "en kalabalık kart vitrine sığıyor (%.0f / %.0f)" % [tallest, screen._scroll.size.y])
	var avatar_y: Array[float] = []
	var body_share: float = 1.0
	for card: Control in screen._cards.get_children():
		var avatars: Array[Node] = card.find_children("*", "AvatarView", true, false)
		if not avatars.is_empty():
			avatar_y.append((avatars[0] as Control).get_global_rect().position.y)
		var body: Control = card.find_child("Person_*", true, false) as Control
		if body:
			body_share = minf(body_share, body.size.y / card.size.y)
	check(avatar_y.size() > 2 and avatar_y.max() - avatar_y.min() < 0.5, "avatarlar aynı hizada")
	check(body_share > 0.6, "kartın gövdesi dokunulabilir (en az %%%.0f)" % (body_share * 100.0))
	check(screen.find_child("Stats", true, false) != null, "istatistik kutusu")
	var close_before: Rect2 = (screen.find_child("CloseButton", true, false) as Control).get_global_rect()
	await shot("03_arkadaslar")
	screen._scroll.scroll_horizontal = 100000
	await create_timer(0.4).timeout
	var close_after: Rect2 = (screen.find_child("CloseButton", true, false) as Control).get_global_rect()
	check(screen._scroll.scroll_horizontal > 0, "vitrin kayıyor (%d)" % screen._scroll.scroll_horizontal)
	check(close_after == close_before and close_after.end.y < root.get_visible_rect().size.y * 0.3, "✕ sabit, üstte")
	await shot("04_arkadaslar_sonu")
	screen._select_tab(FriendsScreen.Tab.REQUESTS)
	await shot("05_istekler")
	screen._select_tab(FriendsScreen.Tab.FRIENDS)
	screen._open_popup()
	await shot("06_kodla_ekle")
	check(hud._android_back_for_crate_panel() and not screen._popup.visible and screen.visible, "GERİ önce pencereyi kapatır")
	var asked: Array[String] = []
	screen.person_requested.connect(func(uid: String) -> void: asked.append(uid))
	(screen.find_child("Person_f3", true, false) as Button).pressed.emit()
	check(asked == ["f3"], "karta dokununca profil istendi")
	await shot("07_profil")
	router.close_all()
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
