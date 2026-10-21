extends SceneTree
## İSİM TABELASI panosu + SERGİLE görsel QA (gerçek oyun, ARAÇLAR ekranı): otopark ve MAHALLE deposu.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/name_sign_panel_shots.gd --resolution 1170x540 -- [çıktı klasörü]
## (1170x540 ≈ telefon tuvali: content_scale 1,35 ile 867x400 birim)
var _out: String = "/home/burak/Projects/ct_shots/name_sign_panel/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func shot(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var garages: CarGarageManager = get_first_node_in_group("car_garages") as CarGarageManager
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	progress.load_state(12, 0, 500)
	economy.set_money(2000000)
	for id: StringName in [&"bmw_e46", &"hyundai_getz", &"renault_toros"]:
		own.add_vehicle(id)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	await create_timer(1.0).timeout
	var screen: GarageScreen = hud.garage_screen
	hud.router.open(&"garage")
	await create_timer(1.5).timeout
	screen.go_to_garage(CarGarageManager.WAITING)
	await create_timer(1.0).timeout
	await shot("1_otopark_raf_sergile")
	(screen.find_child("NameSignButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.4).timeout
	var panel: NameSignPanel = screen.find_child("NameSignPanel", true, false) as NameSignPanel
	var edit: LineEdit = panel.find_child("SignText", true, false) as LineEdit
	edit.text = "Burak Garaj"
	edit.text_changed.emit(edit.text)
	(panel.find_child("Style_1", true, false) as PlateButton).pressed.emit()
	await create_timer(1.2).timeout
	await shot("2_otopark_pano_neon")
	(panel.find_child("SaveButton", true, false) as PlateButton).pressed.emit()
	await create_timer(1.0).timeout
	await shot("3_otopark_kaydedildi")
	garages.purchase(CarGarageCatalog.MAHALLE)
	garages.finish_build_with_gems(CarGarageCatalog.MAHALLE)
	await create_timer(0.5).timeout
	screen.go_to_garage(CarGarageCatalog.MAHALLE)
	await create_timer(1.2).timeout
	(screen.find_child("NameSignButton", true, false) as PlateButton).pressed.emit()
	await create_timer(0.4).timeout
	edit.text = "Usta Atölyesi"
	edit.text_changed.emit(edit.text)
	(panel.find_child("Style_2", true, false) as PlateButton).pressed.emit()
	(panel.find_child("Color_4", true, false) as Button).pressed.emit()
	await create_timer(1.2).timeout
	await shot("4_mahalle_pano_ahsap")
	quit()
