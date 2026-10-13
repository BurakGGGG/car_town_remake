extends SceneTree
## ELMASLA BİTİR — görsel QA: tamir alanında parça takılan araca dokununca araç plakası (kalan süre + BİTİR),
## ilk dokunuşta ONAYLA; ARAÇLAR → MODİFİYE'de HEMEN BİTİR; uzun tamirde (BOYA İŞİ) plakadaki BİTİR.
##   CT_NO_TUTORIAL=1 xvfb-run -a -s "-screen 0 1280x720x24" tools/qa_isolated.sh res://qa/elmas_qa.gd \
##     --rendering-driver opengl3 --resolution 1152x648 -- <çıktı klasörü>

var out: String = "user://elmas_qa/"


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
	pp.level = 12
	pp.gems = 40
	eco.set_money(80000)
	own.add_vehicle(passat)
	await frames(10)

	print("== MODİFİYE: süren takmada HEMEN BİTİR ==")
	mods.purchase(passat, &"turbo")
	router.open(&"garage")
	await frames(90)
	var garage: GarageScreen = hud.get("garage_screen")
	garage.call(&"_on_vehicle_selected", passat)
	await frames(30)
	garage.open_mods()
	(garage.find_child("Part_turbo", true, false) as PlateButton).button_pressed = true
	await frames(30)
	await shot("01_modifiye_hemen_bitir.png")
	router.close_all()
	await create_timer(4.0).timeout

	print("== DÜNYA: araca dokun → plaka ==")
	var display: PerformanceBayDisplay = view.display_of(passat)
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	if display and camera:
		camera.frame_box(display.world_box().grow(0.5), 0.1, 0.45, 0.1, 1.0)
	await frames(30)
	(load("res://car_hitbox.gd") as GDScript).set(&"selected_car", display)
	await frames(20)
	await shot("02_dunya_arac_plakasi.png")
	var gem_button: PlateButton = hud.find_child("GemFinishButton", true, false)
	gem_button.pressed.emit()
	await frames(5)
	await shot("03_onayla.png")
	gem_button.pressed.emit()
	await create_timer(0.6).timeout
	await shot("04_elmasla_takildi.png")
	await create_timer(2.0).timeout

	print("== UZUN TAMİR ==")
	var rm: RepairManager = get_first_node_in_group("repair_manager")
	var traffic: TrafficManager = get_first_node_in_group("traffic")
	var car: TrafficVehicle = traffic.vehicles[0] if not traffic.vehicles.is_empty() else null
	if car:
		car.request_repair(rm.repair_wait_spots[0], RepairType.by_id(&"paint_job"))
		rm.start_repair(car)
		await frames(20)
		(load("res://car_hitbox.gd") as GDScript).set(&"selected_car", car)
		await frames(20)
		await shot("05_uzun_tamir.png")
	print("SONUC: bitti")
	quit()
