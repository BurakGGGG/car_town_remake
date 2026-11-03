extends SceneTree
## CAM BÖLME GÖRSEL QA — cam bölmeyi (wall_glass) farklı yerlere örer: tamir alanının önü (yarı saydam
## gövde), köşe, dış duvar yanı, düz bölme; oyun ve düzenleme modunda yakından görüntü alır.
##   printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_qa_cam"\n' > override.cfg
##   godot-4 --path . --resolution 1040x480 -s res://qa/cam_bolme_qa.gd ; rm override.cfg
## Çıktı: ~/Projects/ct_shots/cam_bolme/*.png

const OUT: String = "/home/burak/Projects/ct_shots/cam_bolme/"
var decor: DecorManager
var view: GarageDecorView
var cam: Node


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	await frames(20)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("shot ", name)


func node_world(a: int, b: int) -> Vector3:
	var p: Vector2 = DecorGrid.node_pos(Vector2i(a, b))
	return Vector3(p.x, 0.0, p.y)


func run(axis: StringName, a0: int, b0: int, n: int) -> Array[String]:
	var out: Array[String] = []
	for k: int in n:
		out.append(DecorGrid.edge_key(axis, a0 + (k if axis == &"x" else 0), b0 + (k if axis == &"z" else 0)))
	return out


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(90)
	var hud: Hud = main.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pp.load_state(30, 0, 500)
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	economy.set_money(30_000_000)
	await frames(30)
	cam = get_root().get_camera_3d()
	var bays: RepairBayManager = get_first_node_in_group("repair_bays") as RepairBayManager
	for i: int in bays.bay_count():
		print("bay %d %s revealed=%s" % [i, bays.bay_position(i), bays.is_bay_revealed(i)])
	print("clip ", view.wall_clip(), " floor ", view.area().floor_y, " top ", view.area().wall_top)

	var keys: Array[String] = []
	keys.append_array(run(&"x", 0, 6, 14))    # ön tarafta uzun düz bölme (aracın önü)
	keys.append_array(run(&"z", 14, 0, 6))    # dik bölme, x-bölmeyle köşe
	keys.append_array(run(&"x", 16, 10, 8))   # arkada, dış duvara kadar
	keys.append_array(run(&"z", 16, 10, 12))  # arka-sol oda
	var res: Dictionary = decor.build_walls(keys, &"wall_glass")
	print("build ", res, " count ", decor.wall_count())
	await frames(20)
	print("faded ", view.interior_walls().faded_keys())

	cam.call("follow", Vector3(-1.6, 0, -1.6), 3.4)
	await shot("01_genel")
	for spot: Array in [[node_world(4, 6), "02_on_bolme"], [node_world(14, 6), "03_kose"],
			[node_world(16, 10), "04_arka_kose"], [node_world(24, 10), "05_arka_duvar"],
			[node_world(0, 6), "06_sag_uc"]]:
		cam.call("follow", spot[0], 2.2)
		await shot(spot[1])

	hud.router.open(&"garage_edit")
	await frames(40)
	cam.call("follow", node_world(4, 6), 2.2)
	await shot("07_duzenleme_on")
	cam.call("follow", node_world(14, 6), 2.2)
	await shot("08_duzenleme_kose")
	quit(0)
