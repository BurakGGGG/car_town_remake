extends SceneTree
## TUR KARELERİ (2026-10-11) — performans v2 ile gelen arayüz parçaları: garaj DETAY paneli (gerçek veri satırı),
## yarış daveti (0-100 satırı), yarış sırasında açılan fark, yarış sonucu, profil.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/tur_shots.gd --resolution WxH -- [<araç_id> [<rakip_id>]]
const OUT: String = "/home/burak/Projects/ct_shots/tur/shots/"
var _tag: String = ""


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + _tag + "_" + name + ".png")
	print("kare: %s" % name)


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var player: StringName = StringName(args[0]) if args.size() > 0 else &"bmw_e46"
	var rival: StringName = StringName(args[1]) if args.size() > 1 else &"chevrolet_camaro"
	change_scene_to_file("res://Main.tscn")
	await _frames(150)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	own.add_vehicle(player)
	own.set_race_vehicle(player)
	# Garaj DETAY
	hud.router.open(&"garage")
	await _frames(30)
	hud.garage_screen.call("_show_vehicle", player, false)
	await _frames(20)
	hud.garage_screen.call("_open_detail")
	await _frames(20)
	await _shot("1_garaj_detay")
	hud.router.close_all()
	await _frames(20)
	# Yarış daveti
	var race: RaceManager = get_first_node_in_group("race")
	race.set("_rival_id", rival)
	hud.router.open(&"race_challenge")
	await _frames(30)
	await _shot("2_davet")
	hud.router.close_all()
	await _frames(10)
	# Yarış: oyuncu ortalama oynar, fark açılırken ve sonuçta kare
	race.set("_rival_id", rival)
	hud.router.open(&"drag_race")
	var drag: DragRaceScreen = hud.drag_race_screen
	var guard: int = 0
	while int(drag.get("_phase")) != DragRaceScreen.Phase.RUNNING and guard < 900:
		await process_frame
		guard += 1
	var shot_mid: bool = false
	while int(drag.get("_phase")) != DragRaceScreen.Phase.DONE and guard < 4000:
		await process_frame
		guard += 1
		var p: DragRaceSim.Runner = drag.get("_player")
		if not p.running and float(drag.get("_time")) > 0.25:
			drag.tap()
		elif p.running and p.gear < p.top_gear() and not p.shifting and p.clutch <= 0.0 \
				and p.rpm >= p.spec.shift_rpm[p.gear] * 0.97:
			drag.tap()
		if not shot_mid and float(drag.get("_time")) > 3.0:
			shot_mid = true
			await _shot("3_yaris_3sn")
	await _frames(200)
	await _shot("4_sonuc")
	hud.router.close_all()
	await _frames(20)
	hud.router.open(&"profile")
	await _frames(30)
	await _shot("5_profil")
	quit(0)
