extends SceneTree
## Google Play mağaza ekran görüntüleri (yatay 16:9, 1920x1080). İzole kayıtla çalıştırılmalı:
##   override.cfg (custom_user_dir_name="ct_store") + --position 0,0 --resolution 1920x1080
##   --script qa/magaza_goruntuleri.gd
## Oyuncu ilerlemiş gibi kurulur: garaj seviye 3, 3 tamir alanı, dekorlu avlu, birkaç araç.
## Pencere yöneticisi pencereyi büyütebilir (1920x1200): 16:9 içerik KEEP ile ortalanır, kırpılır.
const OUT: String = "/home/burak/Projects/ct_shots/store/raw/"
const DECOR: Array[StringName] = [&"workbench", &"engine_block", &"motorcycle", &"sofa", &"coffee_table",
	&"deck_chair", &"warning_sign", &"wall_clock", &"wall_poster", &"neon_garage"]
var _hud: Node
var _router: UiRouter


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.max_fps = 0
	get_root().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_position(Vector2i(0, 0))
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("çekildi: ", name, " ", get_root().get_visible_rect().size)


func screen(id: StringName, name: String) -> void:
	_router.open(id)
	await frames(90)
	await shot(name)
	_router.close_all()
	await frames(20)


func _run() -> void:
	await frames(2)
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	_hud = current_scene.find_child("HUD", true, false)
	_router = _hud.get("router")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for id: StringName in ["bmw_e60", "hyundai_getz", "skoda_kamiq", "vw_golf_7", "volvo_s60", "audi_a3", "honda_civic"]:
		own.add_vehicle(id)
	(get_first_node_in_group("economy") as EconomyManager).set_money(86400)
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(3)
	await frames(20)

	# Dekor: eşyalar sahip olunur, düzenleyicinin boş yer araması ile yerleştirilir
	var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
	var owned: Dictionary = {"floor_tile": 1, "wall_brick": 1}
	for id: StringName in DECOR:
		owned[String(id)] = 1
	decor.load_state({"owned": owned})
	_router.open(&"garage_edit")
	await frames(40)
	var editor: GarageEditor = get_first_node_in_group("garage_editor") as GarageEditor
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var area: DecorArea = view.area()
	var r: Rect2 = area.floor_rect
	var slots: Array[Vector2] = []
	for row: int in 3:
		for col: int in 4:
			slots.append(Vector2(r.position.x + r.size.x * (0.16 + 0.22 * col), r.position.y + r.size.y * (0.30 + 0.30 * row)))
	slots.shuffle()
	for id: StringName in DECOR:
		if not (editor.begin_place(id) and editor.confirm_ghost()):
			print("yer yok: ", id)
			continue
		if GarageDecor.placement(id) != GarageDecor.PLACE_WALL:
			var pos: Vector3 = view.place_point(id, slots.pop_back(), 0.0, editor.snap_step())["pos"]
			editor.move_to(editor.selected(), pos, 0.0)
	editor.apply_surface(DecorManager.SURFACE_FLOOR, &"floor_tile")
	editor.apply_surface(DecorManager.SURFACE_WALL, &"wall_brick")
	editor.select("")
	await frames(40)
	await shot("4_dekor")
	_router.close_all()
	await frames(30)

	# Müşteri akışı işlesin
	Engine.time_scale = 5.0
	await frames(900)
	Engine.time_scale = 1.0
	await frames(30)
	await shot("1_dunya")

	await screen(&"garage", "2_garaj")
	await screen(&"showroom", "3_galeri")
	await screen(&"collection", "5_koleksiyon")
	await screen(&"quests", "6_gorevler")
	await screen(&"drag_race", "7_drag")
	quit(0)
