extends SceneTree
## KASA GÖRSEL QA — büyük araç teslimat kasasının dünyadaki görünümü ve açılış sahnesi.
## Çalıştırma: godot-4 --path . --resolution 1170x540 -s res://qa/crate_qa.gd -- [etiket]
## Görüntüler: /home/burak/Projects/ct_shots/crate/<etiket>_*.png
## Kayıt: override.cfg ile yalıtılmış kullanıcı dizininde çalıştırın (tools/run_tests.sh gibi); betik
## yeni oyun başlatır.

const OUT: String = "/home/burak/Projects/ct_shots/crate/"
var _tag: String = "crate"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	_run()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + _tag + "_" + name + ".png")
	print("  shot ", name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	await process_frame
	change_scene_to_file("res://Main.tscn")
	await create_timer(3.0).timeout
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await create_timer(0.8).timeout
	var crates: CrateManager = get_first_node_in_group("crates")
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery")
	var hud: Hud = get_first_node_in_group("hud") if get_first_node_in_group("hud") else root.get_node("World/HUD")
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	pp.load_state(20, 0, 500)

	print("== teslimat ==")
	var a: int = crates.buy(&"city_crate")
	delivery.focus_on_arrival(a)
	await create_timer(0.25).timeout
	await shot("arriving")
	await create_timer(1.2).timeout
	await shot("delivered")
	var b: int = crates.buy(&"prestige_crate")
	await create_timer(1.4).timeout
	await shot("two_crates")
	var v: CrateVisual = delivery.visual_of(b)
	print("  kasa A: %s  kasa B: %s" % [crates.get_crate(a)["pos"], crates.get_crate(b)["pos"]])

	print("== açılış ==")
	delivery.crate_clicked.emit(b)
	await create_timer(0.3).timeout
	await shot("prompt")
	hud.crate_panel._action.pressed.emit()
	await create_timer(0.55).timeout
	await shot("opening_lid")
	await create_timer(0.6).timeout
	await shot("opening_panels")
	var t: float = 0.0
	while hud.crate_panel.mode() != &"result" and t < 8.0:
		await create_timer(0.1).timeout
		t += 0.1
	await shot("revealed")
	hud.crate_panel._action.pressed.emit()
	await create_timer(1.2).timeout
	await shot("after_claim")

	print("== showroom ve koleksiyon ==")
	hud.router.open(&"showroom")
	await create_timer(1.4).timeout
	await shot("showroom_city")
	hud.showroom._show_crate(&"prestige_crate")
	await create_timer(0.8).timeout
	await shot("showroom_prestige")
	hud.router.open(&"collection")
	await create_timer(1.8).timeout
	await shot("collection")
	quit()
