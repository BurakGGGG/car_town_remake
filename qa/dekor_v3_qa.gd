extends SceneTree
## DEKORASYON v3 GÖRSEL QA — gerçek Main.tscn'de yeni desenleri boyar, yeni kaplamayı uygular, yeni eşyaları
## (salon / atölye / avlu / bitki / duvar) iki tur hâlinde garaja dizer; düzenleme paletinin sekmelerini ve
## bitmiş garajı çeker. Yalıtılmış kayıtla çalıştırılır:
##   CT_NO_TUTORIAL=1 xvfb-run -a -s "-screen 0 1280x720x24" tools/qa_isolated.sh res://qa/dekor_v3_qa.gd \
##     --rendering-driver opengl3 --resolution 1152x648 -- <çıktı klasörü> [telefon]

const NEW_PATTERNS: Array[StringName] = [&"turf", &"brick_paver", &"cobblestone", &"terracotta", &"hex_tile",
	&"checker_yellow", &"terrazzo", &"steel_grate", &"parquet_basket", &"marble"]
const ROUND_A: Array[StringName] = [&"diner_booth", &"bar_stools", &"round_table", &"leather_sofa", &"ping_pong",
	&"air_hockey", &"pinball", &"arcade_cabinet", &"soda_machine", &"gumball", &"drum_kit", &"dj_booth",
	&"grand_piano", &"water_cooler", &"pool_table", &"manager_desk", &"cactus", &"fern_pot", &"topiary",
	&"sunflowers", &"bamboo", &"tree_blossom", &"xmas_tree", &"pumpkins"]
const ROUND_B: Array[StringName] = [&"wheel_chocks", &"oil_drain", &"creeper", &"utility_sink", &"battery_charger",
	&"tire_changer", &"wheel_balancer", &"drill_press", &"engine_hoist", &"diagnostic_cart", &"rim_stack",
	&"fire_hydrant", &"a_barrier", &"traffic_drums", &"stop_sign", &"mailbox", &"concrete_barrier", &"tyre_wall",
	&"phone_booth", &"traffic_light", &"ice_cream_cart", &"kiddie_car", &"kiddie_rocket", &"start_lights",
	&"podium"]
const WALL_ITEMS: Array[StringName] = [&"wall_calendar", &"dartboard", &"wall_fan", &"poster_race", &"sign_tires",
	&"license_plates", &"exhaust_rack", &"steering_rack", &"helmet_shelf", &"neon_wrench", &"race_suit",
	&"neon_flame", &"neon_speed"]

var out: String = "user://dekor_v3_qa/"
var _fails: int = 0
var hud: Hud
var decor: DecorManager
var view: GarageDecorView


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	await frames(4)
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out.path_join(file))
	print("  foto: ", file)


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.has("telefon"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(out)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	hud = current_scene.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pp.load_state(30, 0, 500)
	for entry: Dictionary in CarCatalog.all():
		ownership.add_vehicle(entry["id"])   # garaj değeri → rütbe: bütün eşyalar açılsın
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	economy.set_money(90_000_000)
	await frames(30)
	print("rütbe %d" % GarageValue.current_rank(self))

	# --- Katalog: her yeni eşyanın modeli var ve açık --------------------------------------
	var missing: Array[StringName] = []
	for id: StringName in ROUND_A + ROUND_B + WALL_ITEMS:
		if not DecorBuilder.has_model(id) or not decor.is_unlocked(id):
			missing.append(id)
	check(missing.is_empty(), "62 yeni eşyanın modeli var ve rütbe kilidi açık %s" % [missing])

	# --- Zemin: 10 yeni desen, şerit şerit --------------------------------------------------
	for k: int in NEW_PATTERNS.size():
		var cells: Array[Vector2i] = []
		for x: int in range(k * 3, k * 3 + 3):
			for y: int in DecorGrid.MAX_ROWS:
				cells.append(Vector2i(x, y))
		decor.paint_tiles(cells, NEW_PATTERNS[k])
	var painted: Dictionary = {}
	for p: StringName in decor.tiles().values():
		painted[p] = true
	check(painted.size() == NEW_PATTERNS.size(), "10 yeni desen zemine boyandı (%d)" % painted.size())
	decor.purchase(&"wall_stone")
	decor.apply_surface(DecorManager.SURFACE_WALL, &"wall_stone")
	await frames(20)
	await shot("00_zemin_desenleri.png")

	# --- Duvar eşyaları: arka ve sol duvar boyunca ----------------------------------------
	var hung: int = 0
	var slots: Array = []
	for side: String in ["back", "left"]:
		var f: Dictionary = view.area().face(side)
		var span: Vector2 = f["span"]
		var along: float = span.x + 0.12
		while along < span.y - 0.12:
			slots.append([side, along])
			along += 0.06
	var slot_i: int = 0
	for id: StringName in WALL_ITEMS:
		decor.purchase(id)
		while slot_i < slots.size():
			var m: Dictionary = view.area().mount_on(slots[slot_i][0], slots[slot_i][1], view.wall_width(id))
			slot_i += 1
			if view.is_valid(id, m["position"], float(m["yaw"])):
				decor.add_instance(id, m["position"], float(m["yaw"]))
				hung += 1
				slot_i += 2
				break
	check(hung == WALL_ITEMS.size(), "13 yeni duvar eşyası asıldı (%d)" % hung)

	# --- Tur A: salon + bitki --------------------------------------------------------------
	var placed_a: int = await place_all(ROUND_A)
	check(placed_a >= ROUND_A.size() - 2, "tur A yerleşti (%d / %d)" % [placed_a, ROUND_A.size()])
	await frames(30)
	await shot("01_tur_a_genel.png")
	var cam: WorldCamera = get_root().get_camera_3d() as WorldCamera
	if cam:
		cam.frame_box(AABB(Vector3(-2.6, 0.0, -2.8), Vector3(1.6, 0.4, 1.3)), 0.12, 0.88)
		await frames(50)
		await shot("02_tur_a_yakin_1.png")
		cam.frame_box(AABB(Vector3(-4.6, 0.0, -2.8), Vector3(1.8, 0.4, 1.3)), 0.12, 0.88)
		await frames(50)
		await shot("03_tur_a_yakin_2.png")

	# --- Tur B: atölye + avlu --------------------------------------------------------------
	for inst: Dictionary in decor.instances().duplicate():
		if not WALL_ITEMS.has(StringName(inst["item"])) and not GarageDecor.is_vehicle(StringName(inst["item"])):
			decor.remove_instance(inst["iid"])
	var placed_b: int = await place_all(ROUND_B)
	check(placed_b >= ROUND_B.size() - 2, "tur B yerleşti (%d / %d)" % [placed_b, ROUND_B.size()])
	await frames(30)
	if cam:
		cam.frame_box(AABB(Vector3(-4.8, 0.0, -3.2), Vector3(4.6, 0.4, 3.0)), 0.06, 0.94)
		await frames(50)
	await shot("04_tur_b_genel.png")
	if cam:
		cam.frame_box(AABB(Vector3(-2.6, 0.0, -2.8), Vector3(1.6, 0.4, 1.3)), 0.12, 0.88)
		await frames(50)
		await shot("05_tur_b_yakin_1.png")
		cam.frame_box(AABB(Vector3(-4.6, 0.0, -2.8), Vector3(1.8, 0.4, 1.3)), 0.12, 0.88)
		await frames(50)
		await shot("06_tur_b_yakin_2.png")

	# --- Düzenleme paleti: yeni kartlar rütbe / fiyat sırasıyla ------------------------------
	hud.router.open(&"garage_edit")
	await frames(50)
	var es: GarageEditScreen = hud.garage_edit_screen
	var tabs: Array = [[GarageDecor.Kind.LOUNGE, "07_palet_salon.png"], [GarageDecor.Kind.YARD, "08_palet_avlu.png"],
		[GarageDecor.Kind.WALL_ITEM, "09_palet_duvar.png"], [GarageDecor.Kind.FLOOR_PATTERN, "10_palet_zemin.png"],
		[GarageDecor.Kind.WALL_SURFACE, "11_palet_kaplama.png"]]
	for t: Array in tabs:
		es._on_tab_pressed(int(t[0]))
		await frames(40)
		await shot(String(t[1]))
	var order: Array[Dictionary] = GarageDecor.shop_order(GarageDecor.Kind.YARD)
	var sorted: bool = true
	for k: int in range(1, order.size()):
		if int(order[k]["min_rank"]) < int(order[k - 1]["min_rank"]):
			sorted = false
	check(sorted, "palet rütbe sırasında (%d avlu eşyası)" % order.size())
	print("SONUC: fails=%d" % _fails)
	quit()


## Eşyaları sırayla, garajın arkasından öne tarayarak ilk geçerli yere koyar (aralarında bir göz boşluk).
func place_all(ids: Array[StringName]) -> int:
	var placed: int = 0
	for id: StringName in ids:
		decor.purchase(id)
		var done: bool = false
		for j: int in range(1, 40):
			for i: int in range(1, 60):
				var p: Vector2 = DecorGrid.CORNER - Vector2(float(i) * 0.5, float(j) * 0.5) * DecorGrid.CELL
				var pos: Vector3 = Vector3(p.x, 0.0, p.y)
				if view.is_valid(id, pos, 0.0) and _clear_of_others(id, pos):
					decor.add_instance(id, pos, 0.0)
					placed += 1
					done = true
					break
			if done:
				break
		if not done:
			print("  yer yok: ", id)
	await frames(10)
	return placed


## Komşu eşyaya yapışmasın: çevresinde yarım göz boşluk kalsın (fotoğrafta ayırt edilsin).
func _clear_of_others(id: StringName, pos: Vector3) -> bool:
	var pad: float = DecorGrid.CELL * 0.5
	for offset: Vector3 in [Vector3(pad, 0, 0), Vector3(-pad, 0, 0), Vector3(0, 0, pad), Vector3(0, 0, -pad)]:
		if not view.is_valid(id, pos + offset, 0.0):
			return false
	return true
