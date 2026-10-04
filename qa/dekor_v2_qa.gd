extends SceneTree
## DEKORASYON v2 GÖRSEL QA — gerçek Main.tscn'de, GERÇEK fare olaylarıyla (dünya noktası → ekran) karo boyar,
## duvar örer, kaplama uygular, iç duvara eşya asar; düzenleme sekmelerinin ve bitmiş garajın ekran
## görüntülerini alır. Yalıtılmış kayıt klasöründe koşturulmalı (geliştirme kaydını kirletmesin):
##   printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_qa_dekor"\n' > override.cfg
##   godot-4 --path . --resolution 1040x480 -s res://qa/dekor_v2_qa.gd -- telefon ; rm override.cfg
## Çıktı: ~/Projects/ct_shots/dekor_v2/<önek>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/dekor_v2/"
var _prefix: String = "pc"
var _fails: int = 0
var hud: Hud
var decor: DecorManager
var editor: GarageEditor
var view: GarageDecorView
var camera: Camera3D


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + "%s_%s.png" % [_prefix, name])


## Dünya noktasının pencere koordinatı (tuval ölçeği dahil).
func screen_of(p: Vector3) -> Vector2:
	return get_root().get_final_transform() * camera.unproject_position(p)


func mouse(at: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = at
	e.global_position = at
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(e)


func move(at: Vector2, rel: Vector2) -> void:
	var e: InputEventMouseMotion = InputEventMouseMotion.new()
	e.position = at
	e.global_position = at
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(e)


## Zeminde iki nokta arasında gerçek sürükleme (basış → adım adım hareket → bırakış).
func drag(a: Vector2, b: Vector2, steps: int = 12, hold_shot: String = "") -> void:
	var sa: Vector2 = screen_of(Vector3(a.x, 0.01, a.y))
	var sb: Vector2 = screen_of(Vector3(b.x, 0.01, b.y))
	mouse(sa, true)
	await frames(2)
	var last: Vector2 = sa
	for k: int in range(1, steps + 1):
		var p: Vector2 = sa.lerp(sb, float(k) / float(steps))
		move(p, p - last)
		last = p
		await frames(1)
	if hold_shot != "":
		await shot(hold_shot)
	mouse(sb, false)
	await frames(3)


func tap(a: Vector2) -> void:
	var s: Vector2 = screen_of(Vector3(a.x, 0.01, a.y))
	mouse(s, true)
	await frames(2)
	mouse(s, false)
	await frames(3)


func cell_pos(i: float, j: float) -> Vector2:
	return DecorGrid.CORNER - Vector2(i, j) * DecorGrid.CELL


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("telefon"):
		_prefix = "tel"
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	Input.use_accumulated_input = false
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(90)
	hud = main.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	editor = get_first_node_in_group("garage_editor") as GarageEditor
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pp.load_state(30, 0, 500)
	for entry: Dictionary in CarCatalog.all():
		ownership.add_vehicle(entry["id"])   # garaj değeri → rütbe: kilitli desen / parça açılsın
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	economy.set_money(30_000_000)
	await frames(30)
	print("rütbe %d, garaj sv.%d" % [GarageValue.current_rank(self), upgrades.garage_level()])

	hud.router.open(&"garage_edit")
	await frames(40)
	camera = get_root().get_camera_3d()
	var es: GarageEditScreen = hud.garage_edit_screen

	# --- 1) ZEMİN: gerçek fareyle boyama ------------------------------------------------
	await open_tab(es, GarageDecor.Kind.FLOOR_PATTERN)
	es._on_card_pressed(&"concrete_light")
	editor.set_paint_mode(&"rect")
	await fold(es)
	var money0: int = economy.money
	await drag(cell_pos(1.2, 1.2), cell_pos(25.5, 15.8), 16)
	await drag(cell_pos(1.2, 1.2), cell_pos(0.2, 0.2), 4)   # ön-sağ köşe gözü: dikdörtgenin içine
	check(decor.tile_count() > 300, "dikdörtgen: bütün zemin açık beton (%d göz)" % decor.tile_count())
	check(economy.money < money0, "karo başına ücret alındı (%d ₺)" % (money0 - economy.money))
	es._on_card_pressed(&"checker_bw")
	editor.set_paint_mode(&"rect")
	await drag(cell_pos(25.5, 6.5), cell_pos(13.5, 1.2), 12, "zemin_dikdortgen_onizleme")
	es._on_card_pressed(&"hazard")
	editor.set_paint_mode(&"brush")
	await drag(cell_pos(12.5, 15.5), cell_pos(12.5, 1.2), 20)
	await drag(cell_pos(0.5, 7.5), cell_pos(12.5, 7.5), 16)
	check(decor.tile(Vector2i(12, 5)) == &"hazard", "fırça: sürüklenen çizgi boyandı")
	await unfold(es)
	await shot("zemin_sekmesi")

	# --- 2) DUVAR ÖR: dinlenme odası (arka-sol) ve cam ofis (arka-sağ) -------------------
	await open_tab(es, GarageDecor.Kind.WALL_PIECE)
	es._on_card_pressed(&"wall_plain")
	await fold(es)
	await drag(cell_pos(13, 9), cell_pos(26, 9), 14, "duvar_cizim_onizleme")
	check(decor.wall_count() >= 12, "sürükleyerek duvar örüldü (%d segment)" % decor.wall_count())
	await drag(cell_pos(13, 9), cell_pos(13, 16.6), 10)
	es._on_card_pressed(&"wall_door")
	await tap(cell_pos(16.5, 9))
	check(decor.wall_at(DecorGrid.edge_key(&"x", 16, 9)).get("piece", &"") == &"wall_door", "dokunarak kapı konuldu")
	es._on_card_pressed(&"wall_window")
	await tap(cell_pos(20.5, 9))
	await tap(cell_pos(22.5, 9))
	es._on_card_pressed(&"wall_glass")
	await drag(cell_pos(0.6, 10), cell_pos(7, 10), 8)
	await drag(cell_pos(7, 10), cell_pos(7, 16.6), 8)
	es._on_card_pressed(&"wall_door")
	await tap(cell_pos(3.5, 10))
	await unfold(es)
	await shot("duvar_sekmesi")

	# --- 3) ZEMİN odalara: kova duvarla sınırlı doldurur ---------------------------------
	await open_tab(es, GarageDecor.Kind.FLOOR_PATTERN)
	es._on_card_pressed(&"wood_light")
	await fold(es)
	editor.set_paint_mode(&"fill")
	await tap(cell_pos(18.5, 12.5))
	check(decor.tile(Vector2i(18, 12)) == &"wood_light" and decor.tile(Vector2i(18, 7)) != &"wood_light",
		"kova odayı doldurdu, duvarın dışına taşmadı")
	es._on_card_pressed(&"tile_white")
	await tap(cell_pos(3.5, 13.5))
	es._on_card_pressed(&"epoxy_blue")
	await tap(cell_pos(10.0, 12.0))

	# --- 4) DUVAR KAPLAMASI -------------------------------------------------------------
	await open_tab(es, GarageDecor.Kind.WALL_SURFACE)
	for f: StringName in [&"wall_yellow", &"wall_brick_grey"]:
		es._on_card_pressed(f)
		es._on_card_pressed(f)   # iki dokunuşta satın al
	es._on_card_pressed(&"wall_yellow")
	await fold(es)
	await drag(cell_pos(13, 9), cell_pos(26, 9), 12)
	es._on_card_pressed(&"wall_brick_grey")
	var back: Vector2 = Vector2(cell_pos(18, 0).x, view.area().back_face_z - 0.01)
	await tap_wall(Vector3(back.x, 0.25, back.y))
	check(decor.surface(DecorManager.SURFACE_WALL) == &"wall_brick_grey", "dış duvara dokununca dış duvar kaplandı")
	await unfold(es)
	await shot("kaplama_sekmesi")

	# --- 5) DUVAR EŞYASI: iç duvarın yüzüne -----------------------------------------------
	await open_tab(es, GarageDecor.Kind.WALL_ITEM)
	var hung: int = 0
	for spot: Array in [[&"neon_open", 19.5], [&"poster_red", 15.0], [&"sign_service", 24.4]]:
		decor.purchase(spot[0])
		var mount: Dictionary = view.area().wall_mount(cell_pos(spot[1], 8.6), view.wall_width(spot[0]))
		if view.is_valid(spot[0], mount["position"], float(mount["yaw"])):
			decor.add_instance(spot[0], mount["position"], float(mount["yaw"]))
			hung += 1
	check(hung >= 2, "iç duvarın yüzüne eşya asıldı (%d)" % hung)
	for spot2: Array in [[&"pegboard", 4.0], [&"neon_car", 11.0], [&"wall_tv", 20.0], [&"trophy_shelf", 23.5], [&"checkered_flags", 16.0]]:
		decor.purchase(spot2[0])
		var m2: Dictionary = view.area().mount_on(&"back", cell_pos(spot2[1], 0).x, view.wall_width(spot2[0]))
		if view.is_valid(spot2[0], m2["position"], float(m2["yaw"])):
			decor.add_instance(spot2[0], m2["position"], float(m2["yaw"]))
	var blocked: Array[String] = view.items_on_walls([DecorGrid.edge_key(&"x", 19, 9)])
	check(not blocked.is_empty(), "eşya asılı duvar sökülemez (%s)" % [blocked])
	await place_floor_items()
	await shot("duvar_esyasi_sekmesi")

	# --- 6) Bitmiş garaj: düzenlemeden çık ----------------------------------------------
	es.close()
	hud.router.close_all()
	await frames(40)
	await shot("garaj_bitmis")
	var cam: WorldCamera = camera as WorldCamera
	if cam:
		cam.frame_box(AABB(Vector3(-4.8, 0.0, -3.1), Vector3(2.4, 0.4, 1.5)), 0.12, 0.88)
		await frames(50)
		await shot("garaj_yakin_oda")
		cam.frame_box(AABB(Vector3(-2.2, 0.0, -1.6), Vector3(2.0, 0.4, 1.4)), 0.12, 0.88)
		await frames(50)
		await shot("garaj_yakin_sergi")

	# --- 7) Kayıt gidiş-dönüş --------------------------------------------------------------
	var state: Dictionary = decor.state()
	var tiles_before: int = decor.tile_count()
	var walls_before: int = decor.wall_count()
	decor.load_state(JSON.parse_string(JSON.stringify(state)))
	check(decor.tile_count() == tiles_before and decor.wall_count() == walls_before,
		"kayıt → yükleme: karolar (%d) ve duvarlar (%d) aynı" % [tiles_before, walls_before])
	print("RESULT fails=%d" % _fails)
	quit()


## Telefonda kart seçildikten sonra şerit katlanır (kullanıcı gibi): garaj boşalan alana yeniden sığar.
func fold(es: GarageEditScreen) -> void:
	if _prefix != "tel" or not es._strip_panel.visible:
		return
	es._on_tab_pressed(es._kind)
	await frames(60)


## Ekran görüntüsü için şeridi yeniden açar.
func unfold(es: GarageEditScreen) -> void:
	if not es._strip_panel.visible:
		es._on_tab_pressed(es._kind)
		await frames(50)


## Sekmeyi kullanıcı yolundan açar (katlıysa şerit açılır, garaj yeniden sığar).
func open_tab(es: GarageEditScreen, kind: int) -> void:
	es._on_tab_pressed(kind)
	await frames(40)


func tap_wall(p: Vector3) -> void:
	var s: Vector2 = screen_of(p)
	mouse(s, true)
	await frames(2)
	mouse(s, false)
	await frames(3)


## Dinlenme odasına ve sergi alanına birkaç zemin eşyası (geçerli ilk yere).
func place_floor_items() -> void:
	var wishes: Array = [[&"sofa", 18.0, 14.5], [&"jukebox", 25.0, 14.8], [&"coffee_table", 18.0, 12.8],
		[&"vending", 15.0, 15.0], [&"foosball", 22.0, 12.0], [&"potted_plant", 14.2, 10.2],
		[&"tool_cabinet", 9.0, 15.2], [&"tyre_rack", 11.0, 15.2], [&"workbench", 4.0, 15.0]]
	for w: Array in wishes:
		decor.purchase(w[0])
		var near: Vector2 = cell_pos(w[1], w[2])
		for r: int in 6:
			var placed: bool = false
			for dx: int in range(-r, r + 1):
				for dz: int in range(-r, r + 1):
					var p: Vector2 = near + Vector2(dx, dz) * 0.0875
					var pos: Vector3 = Vector3(p.x, 0.0, p.y)
					if view.is_valid(w[0], pos, 0.0):
						decor.add_instance(w[0], pos, 0.0)
						placed = true
						break
				if placed:
					break
			if placed:
				break
	await frames(10)
