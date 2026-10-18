extends SceneTree
## Açılıştan hemen sonra arkadaş garajı ziyareti: kendi sahne ağaçtan çıkarken SceneTree zamanlayıcıları işlemeye devam
## eder. Görev yöneticisinin açılış zamanlayıcısı (1,2 sn + ANNOUNCE_QUIET) ziyarette dolunca get_tree() null oluyor,
## oyun hata verip başarım duyuruları o oturum kapalı kalıyordu (2026-10-18, Emre Usta'nın garajı).
## Çalıştırma: tools/run_tests.sh visit_early_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await create_timer(2.0).timeout
	var missions: MissionManager = get_first_node_in_group("missions") as MissionManager
	check(missions != null and not missions._announce_live, "açılış: görev yöneticisi var, duyurular henüz sessiz")
	var uid: String = String(FeaturedFriends.all()[0]["uid"])
	check(FeaturedFriends.visit(self, uid) and GarageVisit.is_visiting(), "öne çıkan garaj açıldı (%s)" % uid)
	check(not missions.is_inside_tree(), "kendi sahne ağaçtan çıktı")
	await create_timer(MissionManager.ANNOUNCE_QUIET + 2.0).timeout   # açılış zamanlayıcıları ziyaretteyken dolar
	check(not missions._announce_live, "ziyaret sürerken duyuru açılmadı (dönüş bekleniyor)")
	GarageVisit.end(self)
	await create_timer(1.0).timeout
	check(missions.is_inside_tree() and missions._announce_live,
		"dönünce zamanlayıcı işini bitirdi: duyurular açık (hata olsaydı kapalı kalırdı)")
	print("RESULT fails=%d" % fails)
	quit(1 if fails else 0)
