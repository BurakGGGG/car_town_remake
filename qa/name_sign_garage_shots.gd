extends SceneTree
## ANA GARAJ İSİM TABELASI görsel QA: arka ve sol duvara iki tabela, şehir görünümü + düzenleme kipinde YAZI panosu.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/name_sign_garage_shots.gd --resolution 1170x540 -- [klasör]
var _out: String = "/home/burak/Projects/ct_shots/name_sign_garage/"


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
	var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	economy.set_money(5000000)
	upgrades.buy(GarageUpgradeManager.GARAGE_ID)   # sv.2: duvarlar uzasın
	await create_timer(0.5).timeout
	decor.grant(GarageDecor.NAME_SIGN, 2)
	await process_frame
	var a: DecorArea = view.area()
	var back: Dictionary = view.place_point(GarageDecor.NAME_SIGN, Vector2(a.floor_rect.get_center().x, a.back_face_z + 0.15), 0.0, 0.0)
	var back_iid: String = decor.add_instance(GarageDecor.NAME_SIGN, back["pos"], float(back["yaw"]))
	decor.set_instance_sign(back_iid, {"t": "Burak Garaj", "s": 0, "c": 0})
	var left: Dictionary = view.place_point(GarageDecor.NAME_SIGN,
		Vector2(a.floor_rect.position.x + 0.1, a.floor_rect.get_center().y), 0.0, 0.0)
	var left_iid: String = decor.add_instance(GarageDecor.NAME_SIGN, left["pos"], float(left["yaw"]))
	decor.set_instance_sign(left_iid, {"t": "Neon Gece", "s": 1, "c": 0})
	print("tabelalar: ", back_iid, " ", left_iid)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	await create_timer(1.5).timeout
	await shot("1_sehir")
	hud.router.open(&"garage_edit")
	await create_timer(1.5).timeout
	var editor: GarageEditor = get_first_node_in_group("garage_editor") as GarageEditor
	editor.select(back_iid)
	await create_timer(0.5).timeout
	await shot("2_duzenle_secili")
	for node: Node in hud.garage_edit_screen.find_children("*", "PlateButton", true, false):
		if (node as PlateButton).text == Loc.t("YAZI"):
			(node as PlateButton).pressed.emit()
	await create_timer(0.8).timeout
	var panel: NameSignPanel = hud.garage_edit_screen.find_child("NameSignPanel", true, false) as NameSignPanel
	(panel.find_child("Style_2", true, false) as PlateButton).pressed.emit()
	(panel.find_child("Color_4", true, false) as Button).pressed.emit()
	await create_timer(0.8).timeout
	await shot("3_yazi_panosu")
	quit()
