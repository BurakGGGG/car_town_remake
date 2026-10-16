extends SceneTree
## OFİS DEKORU GÖRSEL QA — gerçek Main.tscn'de 12 ofis zemin eşyasını garaja dizer, 4 duvar eşyasını arka duvara
## asar; genel + yakın plan ve düzenleme paletinin YAŞAM ALANI / DUVAR EŞYASI sekmelerini çeker.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/ofis_dekor_qa.gd --display-driver x11 --resolution 1152x648 \
##     -- <çıktı klasörü> [telefon]

const FLOOR_ITEMS: Array[StringName] = [&"meeting_table", &"reception_desk", &"office_desk", &"visitor_chairs",
	&"drafting_table", &"coffee_station", &"bookcase", &"copier", &"office_safe", &"filing_cabinet", &"floor_lamp",
	&"flip_chart"]
const WALL_ITEMS: Array[StringName] = [&"office_whiteboard", &"certificates", &"world_map", &"wall_ac"]

var out: String = "/home/burak/Projects/ct_shots/ofis/"
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
	RenderingServer.force_draw()
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
	decor.purchase(&"parquet_basket")
	var cells: Array[Vector2i] = []
	for x: int in DecorGrid.MAX_ROWS:
		for y: int in DecorGrid.MAX_ROWS:
			cells.append(Vector2i(x, y))
	decor.paint_tiles(cells, &"parquet_basket")   # ofis zemini: örgü parke
	decor.purchase(&"wall_brick_white")
	decor.apply_surface(DecorManager.SURFACE_WALL, &"wall_brick_white")

	var hung: int = 0
	var f: Dictionary = view.area().face("back")
	var span: Vector2 = f["span"]
	var along: float = span.x + 0.15
	for id: StringName in WALL_ITEMS:
		decor.purchase(id)
		while along < span.y - 0.1:
			var m: Dictionary = view.area().mount_on("back", along, view.wall_width(id))
			along += 0.04
			if view.is_valid(id, m["position"], float(m["yaw"])):
				decor.add_instance(id, m["position"], float(m["yaw"]))
				hung += 1
				along += view.wall_width(id) + 0.06
				break
	check(hung == WALL_ITEMS.size(), "4 ofis duvar eşyası arka duvara asıldı (%d)" % hung)
	var placed: int = await place_all(FLOOR_ITEMS)
	check(placed == FLOOR_ITEMS.size(), "12 ofis zemin eşyası yerleşti (%d)" % placed)
	await frames(30)
	await shot("01_ofis_genel.png")
	var cam: WorldCamera = get_root().get_camera_3d() as WorldCamera
	if cam:
		hud.visible = false
		var groups: Array = [[FLOOR_ITEMS.slice(0, 4), "02_ofis_yakin_masalar.png"],
			[FLOOR_ITEMS.slice(4, 8), "03_ofis_yakin_cizim_kahve.png"],
			[FLOOR_ITEMS.slice(8, 12), "04_ofis_yakin_kasa_dolap.png"], [WALL_ITEMS, "05_ofis_duvar.png"]]
		for g: Array in groups:
			cam.frame_box(_box_of(g[0]), 0.10, 0.90)
			await frames(50)
			await shot(String(g[1]))
		hud.visible = true

	hud.router.open(&"garage_edit")
	await frames(50)
	var es: GarageEditScreen = hud.garage_edit_screen
	for t: Array in [[GarageDecor.Kind.LOUNGE, "06_palet_yasam.png"], [GarageDecor.Kind.WALL_ITEM, "07_palet_duvar.png"]]:
		es._on_tab_pressed(int(t[0]))
		await frames(40)
		await shot(String(t[1]))
	# Ucuz ofis kartları rütbe / fiyat sırasında öne gelir: şeridi ofis kartlarının başladığı yere kaydır
	es._on_tab_pressed(GarageDecor.Kind.LOUNGE)
	await frames(30)
	var cards: Dictionary = es.get("_cards")
	var card: Control = cards.get(&"office_desk") as Control
	var scroll: ScrollContainer = es.get("_scroll") as ScrollContainer
	if card and scroll:
		scroll.scroll_horizontal = int(card.position.x - 40.0)
		await frames(30)
		await shot("08_palet_yasam_ofis_kartlari.png")
	print("SONUC: fails=%d" % _fails)
	quit()


## Verilen eşyaların garajdaki gövdelerini saran kutu (yakın plan için).
func _box_of(ids: Array) -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for inst: Dictionary in decor.instances():
		if ids.has(StringName(inst["item"])):
			var b: AABB = GarageDecorView._tree_box(view.body_of(inst["iid"]))
			box = b if first else box.merge(b)
			first = false
	return box


## Eşyaları sırayla, garajın arkasından öne tarayarak ilk geçerli yere koyar (aralarında yarım göz boşluk).
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


func _clear_of_others(id: StringName, pos: Vector3) -> bool:
	var pad: float = DecorGrid.CELL * 0.5
	for offset: Vector3 in [Vector3(pad, 0, 0), Vector3(-pad, 0, 0), Vector3(0, 0, pad), Vector3(0, 0, -pad)]:
		if not view.is_valid(id, pos + offset, 0.0):
			return false
	return true
