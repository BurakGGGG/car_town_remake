extends SceneTree
## HAFTALIK DRAG TABLOSU görsel denetimi (2026-10-26, taslak B): telefon tuvalinde (1152x648 + content_scale 1,35 = 853x480;
## geniş 1440x648 → 1067x480) DÜNYA tablosu (podyum + liste + kendi satırın + ödül kademeleri), misafir hâli ve İZLE
## (izleme kipi), HARİTA'daki DRAG PİSTİ noktası ve yarış sonucu şeridi. Ağ yok: özet belgesi Leaderboard.inject ile verilir.
## Kip (betik argümanı): hesap | misafir | izle | harita | sonuc.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/lider_tablosu_qa.gd --resolution 1152x648 --display-driver x11 -- hesap
## Kareler ~/Projects/ct_shots/lider_tablosu/.

const OUT: String = "/home/burak/Projects/ct_shots/lider_tablosu/"

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


static func sample_summary(wk: int) -> Dictionary:
	var people: Array = [
		["u1", "Kaan", "TR", "mercedes_cls", "#1F2A4A", 5, 34, 9.81, "p02"],
		["u2", "Lukas", "DE", "bmw_e60", "#B3412E", 5, 29, 9.86, "p03"],
		["u3", "Deniz", "TR", "tesla_model_y", "", 4, 31, 9.93, "p04"],
		["u4", "Mateo", "ES", "cupra_formentor", "#6B6E73", 5, 27, 10.02, "p05"],
		["u5", "Léa", "FR", "bmw_f30", "#2F6FB3", 4, 25, 10.07, "p06"],
		["u6", "Mert", "TR", "audi_a3", "#F5BE4C", 4, 22, 10.11, "p07"],
		["u7", "Jonas", "DE", "volvo_s60", "", 3, 24, 10.15, "p08"],
		["u8", "Ece", "TR", "bmw_e46", "#FFFFFF", 3, 20, 10.22, "p01"],
		["u9", "Hugo", "FR", "mercedes_s400", "", 2, 19, 10.29, "p02"],
		["u10", "Selin", "TR", "audi_a6", "#B3412E", 3, 23, 10.34, "p03"],
	]
	var top: Array = []
	for p: Array in people:
		top.append({"uid": p[0], "name": p[1], "flag": p[2], "car": p[3], "paint": p[4], "stage": p[5], "level": p[6],
			"time": p[7], "av": p[8], "at": 0})
	var hist: Dictionary = {}
	var t: float = 9.8
	for i: int in 312:
		var key: String = str(floori((t + i * 0.012) * Leaderboard.BUCKETS_PER_SEC))
		hist[key] = int(hist.get(key, 0)) + 1
	return {"wk": wk, "cls": "A", "cc": "", "count": 312, "hist": hist, "top": top}


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mode: String = args[0] if not args.is_empty() and args[0] != "masaustu" else "hesap"
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	var canvas: Vector2 = root.get_visible_rect().size
	prefix = "%dx%d_%s_%s_" % [roundi(canvas.x), roundi(canvas.y), Loc.current(), mode]
	var hud: Hud = root.get_node("World/HUD") as Hud
	var board: Leaderboard = get_first_node_in_group("leaderboard") as Leaderboard
	board.base_url = ""
	var wk: int = Leaderboard.current_week()
	board.inject("lb/" + Leaderboard.summary_id(wk, &"A"), sample_summary(wk))
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	ownership.add_vehicle(&"bmw_e46")
	ownership.set_race_vehicle(&"bmw_e46")
	if mode != "misafir":
		var social: SocialManager = get_first_node_in_group("social") as SocialManager
		social.set("_uid", "me_uid")
		social.set("_state", SocialManager.State.READY)
		board.set("_best", {"%d_A" % wk: {"t": 11.42, "car": "bmw_e46"}})
	hud.router.close_all()
	if mode == "harita":
		await _map(hud)
		return
	if mode == "sonuc":
		await _result(hud)
		return
	hud.open_leaderboard(&"A")
	await create_timer(1.6).timeout
	check(hud.leaderboard_screen.visible, "tablo açık")
	check(hud.leaderboard_screen.find_child("Podium_1", true, false) != null, "podyum")
	check(hud.leaderboard_screen.find_child("Row_4", true, false) != null, "liste 4. sıradan")
	var view: Rect2 = root.get_visible_rect()
	for name: String in ["Podium", "List", "OwnRow", "Tiers", "Classes"]:
		var node: Control = hud.leaderboard_screen.find_child(name, true, false) as Control
		check(node != null and view.encloses(node.get_global_rect().grow(-1.0)), "%s ekrana sığıyor (%s)" % [name, node.get_global_rect() if node else Rect2()])
	await shot("01_tablo")
	if mode == "izle":
		var rec: DragRaceSim.Recording = DragRaceSim.ai_recording(&"mercedes_cls", {&"motor": 5, &"turbo": 5}, DragRaceSim.roll_form(&"mercedes_cls", null), RandomNumberGenerator.new())
		board.inject("lb_runs/" + Leaderboard.doc_id(wk, &"A", "u1"), {"run": JSON.stringify(rec.to_dict())})
		(hud.leaderboard_screen.find_child("Watch_u1", true, false) as PlateButton).pressed.emit()
		await create_timer(3.4).timeout
		check(hud.router.top() == &"drag_race", "İZLE: pist izleme kipinde")
		await shot("02_izle_geri_sayim")
		await create_timer(4.5).timeout
		await shot("03_izle_kosu")
		await create_timer(14.0).timeout
		check(hud.router.top() == &"leaderboard", "izleme bitince tabloya dönüldü (%s)" % hud.router.top())
	_finish()


func _finish() -> void:
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## HARİTA: DRAG PİSTİ noktası (sıra satırı özetten), dokununca tablo haritanın üstüne açılır.
func _map(hud: Hud) -> void:
	hud.call("_open_map", &"city")
	await create_timer(2.0).timeout
	var pin: PlateButton = hud.map_screen.get("_pins").get(MapScreen.DRAG) as PlateButton
	check(pin != null and pin.is_visible_in_tree(), "DRAG PİSTİ noktası")
	var hint: Label = hud.map_screen.get("_hints").get(MapScreen.DRAG) as Label
	check(hint != null and hint.text.contains("135"), "sıra satırı (%s)" % (hint.text if hint else ""))
	var view: Rect2 = root.get_visible_rect()
	if pin:
		check(view.encloses(pin.get_parent().get_global_rect()), "nokta ekranda (%s)" % pin.get_parent().get_global_rect())
	await shot("01_harita")
	if pin:
		pin.pressed.emit()
	await create_timer(1.2).timeout
	check(hud.router.top() == &"leaderboard" and hud.router.is_open(&"map"), "tablo haritanın üstünde (%s)" % hud.router.top())
	await shot("02_haritadan_tablo")
	_finish()


## YARIŞ SONUCU: tablo şeridinin üç hâli (sıra yükseldi / ilk kayıt / misafir), TABLO → yarış kapanır, tablo açılır.
func _result(hud: Hud) -> void:
	var screen: RaceResultScreen = hud.race_result_screen
	var wk: int = Leaderboard.current_week()
	var cases: Array = [
		["yukseldi", {"cls": &"A", "wk": wk, "time": 10.31, "best": 10.31, "improved": true, "old_rank": 128, "rank": 97,
			"count": 312, "next_tier": &"p10", "gap": 0.22}],
		["ilk", {"cls": &"A", "wk": wk, "time": 11.42, "best": 11.42, "improved": true, "old_rank": 0, "rank": 135,
			"count": 313, "next_tier": &"p50", "gap": 0.61}],
		["gecemedi", {"cls": &"A", "wk": wk, "time": 11.9, "best": 11.42, "improved": false, "old_rank": 135, "rank": 135,
			"count": 313, "next_tier": &"p50", "gap": 0.61}],
		["misafir", {"cls": &"A", "wk": wk, "time": 11.42, "guest": true}],
	]
	for case: Array in cases:
		screen.show_result(true, 11.42, 11.9, 1200, 40, &"bmw_e46")
		screen.show_record(true, false, 11.42, 11.2)
		screen.show_leaderboard(case[1])
		hud.router.open(&"race_result")
		await create_timer(0.8).timeout
		var strip: Control = screen.find_child("LeaderboardStrip", true, false) as Control
		check(strip != null and strip.visible, "%s: şerit görünür" % case[0])
		var column: Control = screen.get("_column") as Control
		check(root.get_visible_rect().encloses(column.get_global_rect()), "%s: sonuç sütunu ekrana sığıyor (%s)" % [case[0], column.get_global_rect()])
		await shot("sonuc_" + String(case[0]))
	(screen.find_child("LeaderboardButton", true, false) as PlateButton).pressed.emit()
	await create_timer(1.0).timeout
	check(hud.router.top() == &"leaderboard" and not hud.router.is_open(&"race_result"), "TABLO: tablo açıldı (%s)" % hud.router.top())
	_finish()
