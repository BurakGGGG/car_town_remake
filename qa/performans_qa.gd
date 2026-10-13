extends SceneTree
## PERFORMANS MODİFİYESİ — görsel QA: ARAÇLAR → MODİFİYE (alt parça şeridi, parça plakası), YÜKSELT → ana dünya,
## araç alana girip liftle kalkar, kalan süre balonu, HAZIR, takma bildirimi, çok kademeli Passat.
##   CT_NO_TUTORIAL=1 xvfb-run -a -s "-screen 0 1280x720x24" tools/qa_isolated.sh res://qa/performans_qa.gd \
##     --rendering-driver opengl3 --resolution 1152x648 -- <çıktı klasörü>

var out: String = "user://performans_qa/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(file))
	print("  foto: ", out.path_join(file))


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await frames(10)
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	var eco: EconomyManager = get_first_node_in_group("economy")
	var mods: PerformanceModManager = get_first_node_in_group("performance_mods")
	var view: PerformanceBays = get_first_node_in_group("performance_bays")
	var passat: StringName = &"vw_passat_b55"
	pp.level = 9
	eco.set_money(60000)
	own.add_vehicle(passat)
	own.set_race_vehicle(passat)
	await frames(10)

	print("== ARAÇLAR ==")
	router.open(&"garage")
	await frames(90)
	var garage: GarageScreen = hud.get("garage_screen")
	garage.call(&"_on_vehicle_selected", passat)
	await frames(40)
	await shot("00_araclar.png")

	print("== MODİFİYE ==")
	garage.open_mods()
	await frames(60)
	await shot("01_modifiye_genel.png")
	(garage.find_child("Part_motor", true, false) as PlateButton).pressed.emit()
	await frames(40)
	await shot("02_motor.png")
	(garage.find_child("Stage_3", true, false) as PlateButton).button_pressed = true
	await frames(20)
	await shot("02b_motor_yaris.png")
	garage.call(&"_on_exit_pressed")
	(garage.find_child("Part_tire", true, false) as PlateButton).pressed.emit()
	await frames(40)
	await shot("02c_lastik.png")
	garage.call(&"_on_exit_pressed")
	await frames(10)

	print("== YÜKSELT ==")
	(garage.find_child("Part_motor", true, false) as PlateButton).pressed.emit()
	await frames(10)
	(garage.find_child("UpgradeButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.9).timeout
	await shot("03_dunya_giris.png")
	await create_timer(1.0).timeout
	await shot("04_dunya_lift.png")
	await create_timer(2.5).timeout
	await shot("05_dunya_sayac.png")

	print("== HAZIR → TAKILDI ==")
	mods.finish_now(passat)
	await create_timer(0.6).timeout
	await shot("06_hazir.png")
	(load("res://car_hitbox.gd") as GDScript).set(&"selected_car", view.display_of(passat))
	await create_timer(0.5).timeout
	await shot("07_takildi.png")
	await create_timer(2.0).timeout

	print("== ÇOK KADEMELİ PASSAT ==")
	eco.set_money(400000)
	pp.level = 20
	for category: StringName in [&"motor", &"turbo", &"air", &"gear", &"tire", &"body"]:
		while PerformanceMods.stage_of(passat, category) < (5 if category == &"motor" else 3):
			if not mods.purchase(passat, category):
				break
			mods.finish_now(passat)
			mods.collect(passat)
			await create_timer(1.6).timeout
	router.open(&"garage")
	await frames(60)
	garage.call(&"_on_vehicle_selected", passat)
	await frames(30)
	garage.open_mods()
	await frames(60)
	await shot("08_modifiye_ilerlemis.png")
	(garage.find_child("Part_motor", true, false) as PlateButton).pressed.emit()
	await frames(40)
	await shot("09_motor_tamam.png")
	garage.call(&"_on_exit_pressed")
	(garage.find_child("Part_turbo", true, false) as PlateButton).pressed.emit()
	await frames(40)
	await shot("10_turbo_ilerlemis.png")
	print("SONUC: bitti")
	quit()
