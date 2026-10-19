extends SceneTree
## OTO MANŞET QA (2026-10-17, adım 1: sahte veriyle görünüm): kalabalık / sade / tek arkadaş / ziyaret / garaj manşetli gazeteler,
## fırlatmanın ortası, sayfa ekrana sığıyor mu, TAMAM durunca mı açılıyor, kapanınca router boşalıyor mu.
## Seslerin dinleme dosyaları da yazılır (zil, pat, hışırtı).
## Telefon tuvali (scale 1,35, bkz. qa/ekran_tarama.gd): pencere 1152x648 → 853x480 (16:9), 1440x648 → 1067x480 (20:9).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/oto_manset_qa.gd --display-driver x11 --resolution 1152x648
##   (QA_LANG=es ile İspanyolca; "-- masaustu" ölçeksiz)
## Kareler: /home/burak/Projects/ct_shots/oto_manset/<tuval genişliği>x<yüksekliği>_<dil>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/oto_manset/"

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


func _person(uid: String, name: String, av: String, flag: String = "TR") -> Dictionary:
	return {"uid": uid, "name": name, "av": av, "frame": "", "flag": flag}


func _crowded() -> Array[Dictionary]:
	var elif_usta: Dictionary = _person("featured_elif", "Elif Usta", "")
	var emre: Dictionary = _person("featured_emre", "Emre Usta", "")
	return [
		{"kind": NewsDigest.RACE_LOST, "people": [elif_usta], "count": 4, "car": &"vw_golf_7"},
		{"kind": NewsDigest.RACE_LOST, "people": [_person("f1", "Mert", "p04")], "count": 2, "car": &"bmw_e60"},
		{"kind": NewsDigest.EARNINGS, "money": 2300, "jobs": 7, "minutes": 480, "full": true, "finished": 2,
			"finished_money": 780, "finished_xp": 25},
		{"kind": NewsDigest.GIFT, "people": [emre], "parts": {&"bolt": 1}},
		{"kind": NewsDigest.GIFT, "people": [_person("f2", "Ayşe", "p07")], "parts": {&"spark_plug": 2}},
		{"kind": NewsDigest.VISIT, "people": [_person("f3", "Zeynep", "p02")], "likes": 1},
		{"kind": NewsDigest.VISIT, "people": [_person("f4", "Can", "p09")], "likes": 0},
		{"kind": NewsDigest.FRIEND_NEW, "people": [_person("f5", "Deniz", "p05", "DE")]},
		{"kind": NewsDigest.FRIEND_REQUEST, "people": [_person("r1", "Tolga", "p11"), _person("r2", "Melis", "p03")]},
		{"kind": NewsDigest.ASK, "people": [_person("f1", "Mert", "p04")], "part": &"piston"},
		{"kind": NewsDigest.PILES, "count": 3},
		{"kind": NewsDigest.MOD_READY, "car": &"bmw_e60", "category": &"motor"},
		{"kind": NewsDigest.MISSIONS, "daily": true},
	]


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current()]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var router: UiRouter = hud.router
	var news: NewsScreen = hud.news_screen
	var view: Rect2 = root.get_visible_rect()

	print("0) Boş gazete açılmaz")
	check(not news.prepare([], 1), "haber yoksa prepare false")

	var cases: Array = [
		["01_kalabalik", _crowded(), 12],
		["02_sade_kazanc", [{"kind": NewsDigest.EARNINGS, "money": 640, "jobs": 2, "minutes": 95}] as Array[Dictionary], 3],
		["03_tek_arkadas", [
			{"kind": NewsDigest.RACE_LOST, "people": [_person("featured_elif", "Elif Usta", "")], "count": 1, "car": &"fiat_500_1965"},
			{"kind": NewsDigest.GIFT, "people": [_person("featured_emre", "Emre Usta", "")], "parts": {&"bolt": 1}},
			{"kind": NewsDigest.EARNINGS, "money": 1180, "jobs": 4, "minutes": 210},
		] as Array[Dictionary], 5],
		["04_ziyaret", [
			{"kind": NewsDigest.VISIT, "people": [_person("f3", "Zeynep", "p02")], "likes": 1},
			{"kind": NewsDigest.VISIT, "people": [_person("f4", "Can", "p09")], "likes": 1},
			{"kind": NewsDigest.VISIT, "people": [_person("f6", "Selin", "p06")], "likes": 0},
			{"kind": NewsDigest.PILES, "count": 6},
			{"kind": NewsDigest.MISSIONS, "daily": true, "weekly": true},
		] as Array[Dictionary], 8],
		# GARAJLARIM (2026-10-19): arkadaşın lüks garajı manşette, kendi inşaatın sütunda, iç yükseltme KISA KISA'da
		["05_garajlar", [
			{"kind": NewsDigest.FRIEND_GARAGE, "people": [_person("featured_elif", "Elif Usta", "")], "garage": CarGarageCatalog.HANGAR},
			{"kind": NewsDigest.GARAGE_BUILT, "garage": CarGarageCatalog.NEON},
			{"kind": NewsDigest.GARAGE_UPGRADED, "garage": CarGarageCatalog.SANAYI, "item": CarGarageCatalog.FLOOR},
			{"kind": NewsDigest.GARAGE_UPGRADED, "garage": CarGarageCatalog.MAHALLE, "item": CarGarageCatalog.PARK},
			{"kind": NewsDigest.EARNINGS, "money": 1800, "jobs": 5, "minutes": 300},
		] as Array[Dictionary], 9],
		["06_insaat", [
			{"kind": NewsDigest.GARAGE_BUILT, "garage": CarGarageCatalog.SHOWROOM},
			{"kind": NewsDigest.MOD_READY, "car": &"bmw_e60", "category": &"motor"},
		] as Array[Dictionary], 10],
	]
	for case: Array in cases:
		print("%s" % case[0])
		check(news.prepare(case[1], case[2]), "gazete hazır")
		router.open(&"news")
		check(router.top() == &"news", "router'da açık")
		check(not hud.top_left.visible, "sol üst HUD gizli (tam sayfa)")
		if case[0] == "01_kalabalik":
			await create_timer(0.47).timeout
			await shot(case[0] + "_firlatma")
			check(news._ok.disabled, "uçarken TAMAM kapalı")
		await create_timer(1.3).timeout
		check(not news._ok.disabled, "durunca TAMAM açık")
		check(is_equal_approx(news._dim.color.a, NewsScreen.DIM_ALPHA), "arka plan karardı (%.2f)" % news._dim.color.a)
		var paper: Control = news._paper
		var corners: Array[Vector2] = []
		var xf: Transform2D = paper.get_global_transform()
		for c: Vector2 in [Vector2.ZERO, Vector2(paper.size.x, 0.0), paper.size, Vector2(0.0, paper.size.y)]:
			corners.append(xf * c)
		var inside: bool = true
		for c: Vector2 in corners:
			inside = inside and view.grow(1.0).has_point(c)
		check(inside, "sayfa ekranda (%.0fx%.0f, sığdırma %.2f)" % [paper.size.x, paper.size.y, news._fit])
		var ok_rect: Rect2 = Hud.screen_rect(news._ok)
		check(view.encloses(ok_rect), "TAMAM ekranda")
		var headline: Label = paper.find_child("Headline", true, false) as Label
		check(headline != null and headline.get_line_count() <= 3, "manşet en çok 3 satır (%d)" % (headline.get_line_count() if headline else -1))
		var briefs: Label = paper.find_child("Briefs", true, false) as Label
		check(briefs == null or briefs.max_lines_visible < 0 or briefs.get_line_count() <= briefs.max_lines_visible,
			"KISA KISA sığıyor (%d satır)" % (briefs.get_line_count() if briefs else 0))
		await shot(case[0])
		news._ok.pressed.emit()
		await create_timer(0.6).timeout
		check(router.top() == &"" and not news.visible, "TAMAM kapattı")
		check(hud.top_left.visible, "sol üst HUD geri geldi")

	if Loc.current() == "tr":
		for pair: Array in [["ses_zil", NewsSfx.bell_samples()], ["ses_pat", NewsSfx.slap_samples()],
				["ses_hisirti", NewsSfx.rustle_samples()]]:
			NewsSfx._wav(pair[1]).save_to_wav(OUT + String(pair[0]) + ".wav")
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
