extends SceneTree
## ZEMİN BOYAMA GÖRSELİ — düzenleyicide zemin boyama aracı açıkken garaj nasıl görünüyor?
## Eşyalı bir garaj kurar, düzenleyiciyi açar; eşya kipinde ve boyama kipinde ekran görüntüsü alır.
##   godot-4 --path . --resolution 1152x648 -s res://qa/zemin_boya_gorsel.gd   (override.cfg ile yalıtılmış kayıt)

const OUT: String = "/home/burak/Projects/ct_shots/zemin_boya/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	await create_timer(1.2).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + name + ".png")


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	(get_first_node_in_group("save_manager") as SaveManager).new_game()
	await frames(10)
	(get_first_node_in_group("economy") as EconomyManager).set_money(5_000_000)
	var garage: Node = get_first_node_in_group("garage_system")
	garage.call("set_level", 1)
	await frames(5)
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var editor: GarageEditor = get_first_node_in_group("garage_editor")
	var decor: DecorManager = get_first_node_in_group("decor")
	view.refresh()
	# birkaç zemin eşyası: garajın farklı yerlerine
	var lot: Rect2 = view.lot_rect()
	var placed: int = 0
	var pattern: StringName = &""
	for d: Dictionary in GarageDecor.all():
		var id: StringName = StringName(d["id"])
		if GarageDecor.is_pattern(id) and pattern == &"":
			pattern = id
		if placed >= 8 or GarageDecor.placement(id) != GarageDecor.PLACE_FLOOR or GarageDecor.is_vehicle(id):
			continue
		if not decor.purchase(id):
			continue
		var t: Vector2 = lot.position + lot.size * Vector2(0.1 + 0.8 * fmod(placed * 0.37, 1.0), 0.15 + 0.1 * placed)
		var p: Dictionary = view.place_point(id, t, 0.0, editor.snap_step())
		if view.is_valid(id, p["pos"], 0.0) and decor.add_instance(id, p["pos"], 0.0) != "":
			placed += 1
	print("yerleşen eşya %d · desen %s" % [placed, pattern])
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	router.open(&"garage_edit")
	await frames(30)
	await shot("1_esya_kipi")
	editor.begin_paint(pattern)
	await frames(10)
	var first: Node3D = view.body_of(String(decor.instances()[0]["iid"]))
	var geo: Array[Node] = first.find_children("*", "GeometryInstance3D", true, false)
	print("aktif=%s araç=%s odak=%s · ilk gövde %s geo=%d saydamlık=%s" % [editor.active, editor.tool,
		view.get("_floor_focus"), first, geo.size(), (geo[0] as GeometryInstance3D).transparency if geo.size() > 0 else -1.0])
	await shot("2_boya_kipi")
	editor.end_tool()
	await frames(5)
	print("geri döndü: override=%s" % (geo[0] as GeometryInstance3D).material_override)
	await shot("3_esya_kipine_donus")
	quit(0)
