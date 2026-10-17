extends SceneTree
## ZİYARET + BEĞENİ QA (2026-10-17, OTO MANŞET adım 4): arkadaş garajında üst çubukta BEĞEN, basınca BEĞENDİN (dolu),
## dönüşte GarageVisit.take_last beğeniyi verir; ustaların garajında düğme yok. Masaüstünde Firebase yok: ziyaret Emre'nin
## garaj verisiyle "gerçek arkadaş" gibi açılır (can_like). Telefon tuvali (scale 1,35).
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/begeni_qa.gd --display-driver x11 --resolution 1152x648
## Kareler: /home/burak/Projects/ct_shots/begeni/

const OUT: String = "/home/burak/Projects/ct_shots/begeni/"

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")


func _initialize() -> void:
	get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _visit(can_like: bool, liked_today: bool) -> void:
	var entry: Dictionary = FeaturedFriends.get_entry("featured_emre")
	GarageVisit.begin(self, {"uid": "f_qa", "name": "Zeynep", "code": "ABC123", "level": 11, "value": 254000,
		"garage": (entry["garage"] as Dictionary).duplicate(true), "can_like": can_like, "liked_today": liked_today})
	await create_timer(2.5).timeout


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout

	print("1) Arkadaş garajı: BEĞEN")
	await _visit(true, false)
	var like: PlateButton = root.find_child("LikeButton", true, false) as PlateButton
	check(like != null and not like.highlight and not GarageVisit.liked, "BEĞEN düğmesi açık")
	await shot("01_begen")
	like.pressed.emit()
	await create_timer(0.4).timeout
	like.pressed.emit()   # ikinci basış bir şey yapmaz
	check(GarageVisit.liked and like.highlight and like.text == Loc.t("BEĞENDİN"), "basınca BEĞENDİN (amber)")
	await shot("02_begendin")
	GarageVisit.end(self)
	await create_timer(0.3).timeout
	# Kendi sahnenin SocialManager'ı (masaüstünde hazır değil) almadıysa beğeni burada bekler
	var last: Dictionary = GarageVisit.take_last()
	check(last.is_empty() or (String(last.get("uid", "")) == "f_qa" and bool(last.get("liked", false))),
		"dönüşte beğeni aktarıldı / SocialManager aldı")

	print("2) Bugün zaten beğenmişsin")
	await _visit(true, true)
	like = root.find_child("LikeButton", true, false) as PlateButton
	check(like != null and like.highlight and like.text == Loc.t("BEĞENDİN"), "düğme dolu başlar")
	GarageVisit.end(self)
	await create_timer(0.3).timeout

	print("3) Usta garajı: düğme yok")
	FeaturedFriends.visit(self, "featured_elif")
	await create_timer(2.5).timeout
	check(root.find_child("LikeButton", true, false) == null, "ustada BEĞEN yok")
	await shot("03_usta")
	GarageVisit.end(self)
	await create_timer(0.3).timeout
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
