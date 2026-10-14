extends SceneTree
## DEKORASYON v2 — zemin karoları, iç duvarlar, duvar kaplaması, iç duvara eşya asma (docs/DEKORASYON_V2_ARASTIRMA.md).
## Gerçek düğümlerle koşar (Main.tscn). Düzenleyici araçları ekran noktasıyla çağrılır (basış / sürükle /
## bırak), yani boyama, duvar örme ve geri al oyundaki yoldan geçer. Görsel QA ve gerçek fare girdisi:
## qa/dekor_v2_qa.gd.
##   tools/run_tests.sh decor_v2_test

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var editor: GarageEditor
var economy: EconomyManager
var upgrades: GarageUpgradeManager
var camera: Camera3D


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	decor = get_first_node_in_group("decor")
	view = get_first_node_in_group("garage_decor_view")
	editor = get_first_node_in_group("garage_editor")
	economy = get_first_node_in_group("economy")
	upgrades = get_first_node_in_group("garage_upgrades")
	camera = get_root().get_camera_3d()
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 2})
	await frames(4)
	_grid()
	_tiles()
	_tile_save()
	_legacy()
	_walls()
	await _rules()
	await _fading()
	await _editor_tools()
	await _hold_to_move()
	_catalog_v3()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func cell_pos(i: float, j: float) -> Vector2:
	return DecorGrid.CORNER - Vector2(i, j) * DecorGrid.CELL


func _grid() -> void:
	print("== 1) IZGARA: sabit ön-sağ köşe ==")
	var c: Vector2i = DecorGrid.cell_of(cell_pos(3.5, 2.5))
	check(c == Vector2i(3, 2), "dünya noktası → göz (%s)" % c)
	check(DecorGrid.cell_of(DecorGrid.cell_center(Vector2i(7, 5))) == Vector2i(7, 5), "göz merkezi gidiş-dönüş")
	check(DecorGrid.parse_edge("x:3:4") == {"axis": &"x", "a": 3, "b": 4} and DecorGrid.parse_edge("q:1").is_empty(),
		"kenar anahtarı ayrıştırılır, bozuğu reddedilir")
	check(DecorGrid.run_edges(Vector2i(2, 3), Vector2i(6, 4)) == ["x:2:3", "x:3:3", "x:4:3", "x:5:3"],
		"düğümden düğüme koşu baskın eksende kenarlara bölünür")
	check(DecorGrid.nearest_edge(cell_pos(4.5, 3.02)) == "x:4:3" and DecorGrid.nearest_edge(cell_pos(5.03, 2.5)) == "z:5:2",
		"dokunulan noktaya en yakın kenar")
	check(view.area().grid_origin == DecorGrid.CORNER, "eşya oturtma ızgarası da köşeye bağlı")
	var grid: Node = get_first_node_in_group("garage_system").get_node_or_null("BuildGrid/BuildGrid") \
		if get_first_node_in_group("garage_system") else null
	check(grid != null and bool(grid.get("anchor_corner")), "görünen ızgara köşeden çiziliyor")


func _tiles() -> void:
	print("== 2) KARO BOYAMA: göz başına ücret ==")
	economy.set_money(100000)
	var cells: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(1, 2), Vector2i(2, 2)]
	var price: int = decor.tile_price(&"concrete_light")
	var value_before: int = GarageValue.compute(self)
	var r: Dictionary = decor.paint_tiles(cells, &"concrete_light")
	check((r["changes"] as Array).size() == 5 and int(r["cost"]) == price * 5 and economy.money == 100000 - price * 5,
		"5 göz boyandı, 5 × %d ₺ ödendi" % price)
	check(GarageValue.compute(self) == value_before + int(GarageDecor.get_item(&"concrete_light")["value"]) * 5,
		"karolar garaj değerine sayılır")
	var r2: Dictionary = decor.paint_tiles(cells, &"concrete_light")
	check((r2["changes"] as Array).is_empty() and int(r2["cost"]) == 0, "aynı desene yeniden boyamak ücretsiz / değişiklik yok")
	var money: int = economy.money
	var r3: Dictionary = decor.paint_tiles([Vector2i(1, 1)] as Array[Vector2i], &"")
	check((r3["changes"] as Array).size() == 1 and economy.money == money and decor.tile(Vector2i(1, 1)) == &"",
		"silgi ücretsiz")
	decor.revert_tiles(r3["changes"], 0)
	check(decor.tile(Vector2i(1, 1)) == &"concrete_light", "geri al: silinen karo geri geldi")
	var locked: Dictionary = decor.paint_tiles([Vector2i(5, 5)] as Array[Vector2i], &"carbon")
	check((locked["changes"] as Array).is_empty() and decor.tile(Vector2i(5, 5)) == &"",
		"rütbesi yetmeyen desen boyanmaz")
	economy.set_money(price * 2 + 10)
	var short: Dictionary = decor.paint_tiles([Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1)] as Array[Vector2i], &"concrete_light")
	check((short["changes"] as Array).size() == 2 and bool(short["short"]) and economy.money == 10,
		"para yetmeyince yetecek kadar göz boyandı (%d)" % (short["changes"] as Array).size())
	decor.revert_tiles(short["changes"], int(short["cost"]))
	check(economy.money == price * 2 + 10 and decor.tile(Vector2i(6, 1)) == &"", "geri al ödenen parayı iade etti")
	var out: Dictionary = decor.paint_tiles([Vector2i(-1, 0), Vector2i(40, 3)] as Array[Vector2i], &"concrete_light")
	check((out["changes"] as Array).is_empty(), "ızgara dışı göz boyanmaz")


func _tile_save() -> void:
	print("== 3) KARO KAYDI (palet + satır) ==")
	economy.set_money(100000)
	decor.paint_tiles([Vector2i(0, 0), Vector2i(31, 20)] as Array[Vector2i], &"asphalt")
	var state: Dictionary = decor.state()
	var tiles: Dictionary = state["tiles"]
	check((tiles["palette"] as Array).has("asphalt") and (tiles["rows"] as Array).size() == DecorGrid.MAX_ROWS,
		"palet ve satırlar yazıldı (%d satır)" % (tiles["rows"] as Array).size())
	var count: int = decor.tile_count()
	decor.load_state(JSON.parse_string(JSON.stringify(state)))
	check(decor.tile_count() == count and decor.tile(Vector2i(31, 20)) == &"asphalt" and decor.tile(Vector2i(2, 2)) == &"concrete_light",
		"JSON gidiş-dönüşünde karolar aynı (%d)" % count)
	decor.load_state({"tiles": {"palette": ["olmayan_desen", "tile_grey"], "rows": ["ab#", 5, "..b"]}})
	check(decor.tile(Vector2i(0, 0)) == &"" and decor.tile(Vector2i(1, 0)) == &"tile_grey" and decor.tile(Vector2i(2, 2)) == &"tile_grey"
		and decor.tile_count() == 2, "bozuk palet / satır parçaları atlandı (%d)" % decor.tile_count())
	decor.reset()
	var empty: Dictionary = decor.state()
	check((empty["tiles"]["rows"] as Array).is_empty(), "boş zeminde satır yazılmaz")


func _legacy() -> void:
	print("== 4) v1 TÜM-ZEMİN KAPLAMASI → KAROLAR ==")
	decor.load_state({"owned": {"floor_epoxy": 1}, "surfaces": {"floor": "floor_epoxy"}})
	check(decor.surface(DecorManager.SURFACE_FLOOR) == &"" and decor.tile_count() == DecorGrid.MAX_COLS * DecorGrid.MAX_ROWS
		and decor.tile(Vector2i(10, 10)) == &"asphalt", "asfalt kaplama → bütün gözler ASFALT (ücretsiz)")
	check(decor.is_owned(&"floor_epoxy"), "eski kaplamanın sahipliği (değeri) korunur")
	decor.load_state({"owned": {"floor_tile": 1}, "surfaces": {"floor": "floor_tile"}, "tiles": {"palette": [], "rows": []}})
	check(decor.tile_count() == 0, "karo kaydı olan v2 dosyasında eski kaplama yeniden yayılmaz")
	decor.reset()


func _walls() -> void:
	print("== 5) İÇ DUVAR: depo mantığı ==")
	economy.set_money(100000)
	var keys: Array[String] = ["x:4:3", "x:5:3", "x:6:3"]
	var price: int = decor.price_of(&"wall_plain")
	var r: Dictionary = decor.build_walls(keys, &"wall_plain")
	check(int(r["bought"]) == 3 and economy.money == 100000 - price * 3 and decor.wall_count() == 3,
		"3 segment örüldü, 3 kopya satın alındı")
	var removed: Array = decor.remove_walls(["x:5:3"] as Array[String])
	check(removed.size() == 1 and decor.available_of(&"wall_plain") == 1 and decor.owned_of(&"wall_plain") == 3,
		"sökülen parça depoya döndü")
	var money: int = economy.money
	var r2: Dictionary = decor.build_walls(["x:5:3"] as Array[String], &"wall_plain")
	check(int(r2["bought"]) == 0 and economy.money == money, "depodaki parça ücretsiz kullanıldı")
	var r3: Dictionary = decor.build_walls(["x:5:3"] as Array[String], &"wall_door")
	check(decor.wall_at("x:5:3")["piece"] == &"wall_door" and decor.available_of(&"wall_plain") == 1,
		"kapıyla değiştirilen düz duvar depoya döndü")
	decor.revert_walls(r3["changes"], &"wall_door", int(r3["bought"]), int(r3["spent"]))
	check(decor.wall_at("x:5:3")["piece"] == &"wall_plain" and decor.owned_of(&"wall_door") == 0 and economy.money == money,
		"geri al: kapı kalktı, satın alınan kopya iade edildi")
	check(decor.build_walls(["x:7:3"] as Array[String], &"wall_glass").is_empty(), "rütbesi yetmeyen parça örülmez")
	economy.set_money(10)
	check(decor.build_walls(["x:7:3", "x:8:3"] as Array[String], &"wall_plain").is_empty() and decor.wall_count() == 3,
		"para yetmezse hiçbiri örülmez")
	economy.set_money(100000)
	check(decor.set_wall_finish(keys, &"wall_yellow").is_empty(), "sahip olunmayan kaplama uygulanmaz")
	decor.purchase(&"wall_yellow")
	check(decor.set_wall_finish(keys, &"wall_yellow").size() == 3 and decor.wall_at("x:4:3")["finish"] == &"wall_yellow",
		"kaplama segmentlere uygulandı")
	var state: Dictionary = decor.state()
	decor.load_state(JSON.parse_string(JSON.stringify(state)))
	check(decor.wall_count() == 3 and decor.wall_at("x:6:3")["finish"] == &"wall_yellow", "duvarlar kayıttan geri geldi")
	decor.load_state({"owned": {"wall_plain": 1}, "walls": [{"edge": "x:1:1", "piece": "wall_plain"},
		{"edge": "x:2:1", "piece": "wall_plain"}, {"edge": "bozuk", "piece": "wall_plain"}, {"edge": "z:1:1", "piece": "olmayan"}]})
	check(decor.wall_count() == 1, "sahip olunandan fazla / bozuk duvar kaydı atlandı (%d)" % decor.wall_count())
	decor.reset()


func _rules() -> void:
	print("== 6) YERLEŞİM KURALLARI ==")
	await frames(2)
	var a: DecorArea = view.area()
	var back_line: int = floori((DecorGrid.CORNER.y - a.back_face_z) / DecorGrid.CELL + 0.2)
	check(not view.wall_edge_valid(DecorGrid.edge_key(&"x", 3, back_line + 1)), "garaj dışı kenar reddedilir")
	check(view.wall_edge_valid("x:4:5") and view.wall_edge_valid("z:6:4"), "garaj içinde boş kenar geçerli")
	var bays: RepairBayManager = get_first_node_in_group("repair_bays")
	var bay_cell: Vector2i = DecorGrid.cell_of(bays.bay_position(0))
	check(not view.wall_edge_valid(DecorGrid.edge_key(&"x", bay_cell.x, bay_cell.y)), "tamir alanının içinden duvar geçmez")
	economy.set_money(1000000)
	decor.build_walls(["x:4:5", "x:5:5", "x:6:5", "z:4:5", "z:4:6", "z:7:5", "z:7:6"] as Array[String], &"wall_plain")
	await frames(2)
	a = view.area()
	check(a.wall_rects.size() == 7, "duvar izleri alana girdi (%d)" % a.wall_rects.size())
	decor.purchase(&"deck_chair")
	var on_wall: Vector3 = Vector3(cell_pos(5.5, 5).x, 0.0, cell_pos(5.5, 5).y)
	check(not view.is_valid(&"deck_chair", on_wall, 0.0), "zemin eşyası duvarın üstüne konamaz")
	check(not view.is_bay_valid(0, Vector2(on_wall.x, on_wall.z), 0.0), "tamir alanı duvarın üstüne taşınamaz")
	decor.paint_tiles([Vector2i(5, 5), Vector2i(5, 6), Vector2i(5, 4)] as Array[Vector2i], &"tile_grey")
	var fill: Array[Vector2i] = view.flood_cells(Vector2i(5, 5))
	check(fill.has(Vector2i(5, 6)) and not fill.has(Vector2i(5, 4)), "kova duvarla sınırlı (oda)")
	check(a.inner_faces.size() >= 1, "düz duvar koşusu asılabilir yüz oldu (%d)" % a.inner_faces.size())
	decor.purchase(&"first_aid")
	var mount: Dictionary = a.wall_mount(cell_pos(5.5, 4.7), view.wall_width(&"first_aid"))
	check(String(mount["wall"]).begins_with("x@"), "iç duvarın önündeki nokta → iç duvar yüzü (%s)" % mount["wall"])
	check(view.is_valid(&"first_aid", mount["position"], float(mount["yaw"])), "ilk yardım dolabı iç duvara asılabilir")
	var iid: String = decor.add_instance(&"first_aid", mount["position"], float(mount["yaw"]))
	await frames(2)
	var body: Node3D = view.body_of(iid)
	var plane: float = float(view.area().face(String(mount["wall"]))["plane"])
	check(body != null and absf(GarageDecorView._tree_box(body).position.z - plane) < 0.008,
		"dolap iç duvarın yüzüne yaslı (boşluk %.4f)" % (GarageDecorView._tree_box(body).position.z - plane if body else -1.0))
	check(view.items_on_walls(["x:5:5"] as Array[String]) == [iid], "üstünde dolap olan segment bulunur (sökülemez)")
	decor.remove_instance(iid)
	decor.reset()
	await frames(2)


func _fading() -> void:
	print("== 7) OYUNDA ARACIN ÖNÜNDEKİ DUVAR YARI SAYDAM ==")
	economy.set_money(1000000)
	var bays: RepairBayManager = get_first_node_in_group("repair_bays")
	var bay: Vector2 = bays.bay_position(0)
	var cam: Camera3D = get_root().get_camera_3d()
	var toward: Vector3 = cam.global_transform.basis.z
	var flat: Vector2 = Vector2(toward.x, toward.z).normalized()
	# Kameraya doğru ve tersine, alanın dışında kalan ilk geçerli kenarlar
	var front: String = ""
	var back: String = ""
	for k: int in range(3, 30):
		var p: Vector2 = bay + flat * (0.06 * k)
		var key: String = DecorGrid.nearest_edge(p)
		if front == "" and view.wall_edge_valid(key):
			front = key
		var q: Vector2 = bay - flat * (0.06 * k)
		var key2: String = DecorGrid.nearest_edge(q)
		if back == "" and view.wall_edge_valid(key2):
			back = key2
	check(front != "" and back != "", "alanın önünde ve arkasında boş kenar bulundu (%s / %s)" % [front, back])
	decor.build_walls([front, back] as Array[String], &"wall_plain")
	await frames(2)
	var faded: Array = view.interior_walls().faded_keys()
	check(faded.has(front), "kamerayla tamir alanı arasındaki duvar yarı saydam (%s)" % [faded])
	check(not faded.has(back), "alanın arkasındaki duvar opak")
	view.set_editing(true)
	await frames(1)
	check(view.interior_walls().faded_keys().is_empty(), "düzenleme modunda bütün duvarlar opak")
	view.set_editing(false)
	await frames(1)
	check(view.interior_walls().faded_keys().has(front), "düzenlemeden çıkınca yeniden yarı saydam")
	decor.reset()
	await frames(2)


func _editor_tools() -> void:
	print("== 8) DÜZENLEYİCİ ARAÇLARI (ekran noktasıyla) ==")
	var router: UiRouter = (current_scene.find_child("HUD", true, false) as Hud).router
	router.open(&"garage_edit")
	await frames(30)
	check(editor.active, "düzenleyici açık")
	economy.set_money(100000)
	editor.begin_paint(&"tile_grey")
	editor.set_paint_mode(&"brush")
	var price: int = decor.tile_price(&"tile_grey")
	editor._tool_press(_screen(cell_pos(2.5, 2.5)))
	editor._tool_move(_screen(cell_pos(4.5, 2.5)))
	editor._tool_release(_screen(cell_pos(4.5, 2.5)))
	check(decor.tile(Vector2i(2, 2)) == &"tile_grey" and decor.tile(Vector2i(3, 2)) == &"tile_grey"
		and decor.tile(Vector2i(4, 2)) == &"tile_grey", "fırça sürüklenen gözleri boyadı (atlamadan)")
	var spent: int = 100000 - economy.money
	check(spent == price * 3 and editor.history_size() == 1, "tek vuruş = tek geri al adımı (%d ₺)" % spent)
	editor.undo()
	check(decor.tile_count() == 0 and economy.money == 100000, "geri al: karolar silindi, para iade edildi")
	editor.set_paint_mode(&"rect")
	editor._tool_press(_screen(cell_pos(1.5, 1.5)))
	editor._tool_move(_screen(cell_pos(3.5, 3.5)))
	check(editor.stroke_preview_cost() == price * 9, "dikdörtgen önizleme maliyeti (%d)" % editor.stroke_preview_cost())
	editor._tool_release(_screen(cell_pos(3.5, 3.5)))
	check(decor.tile_count() == 9, "dikdörtgen 3×3 göz boyadı")
	editor.set_paint_mode(&"pick")
	editor.begin_paint(&"concrete_dark")
	editor.set_paint_mode(&"pick")
	editor._tool_press(_screen(cell_pos(2.5, 2.5)))
	editor._tool_release(_screen(cell_pos(2.5, 2.5)))
	check(editor.paint_pattern == &"tile_grey" and editor.paint_mode == &"brush", "damlalık deseni aldı, fırçaya döndü")

	editor.begin_walls(&"wall_plain")
	var money: int = economy.money
	# Dört kenarı da boş bir koşu (tamir alanı / kasa izine değmeyen) bulunur
	var start: Vector2i = Vector2i(-1, -1)
	for bb: int in range(2, 12):
		for aa: int in range(1, 16):
			var ok: bool = true
			for k: int in 4:
				ok = ok and view.wall_edge_valid(DecorGrid.edge_key(&"x", aa + k, bb))
			if ok:
				start = Vector2i(aa, bb)
				break
		if start.x >= 0:
			break
	check(start.x >= 0, "boş bir koşu bulundu (%s)" % start)
	editor._tool_press(_screen(DecorGrid.node_pos(start)))
	editor._tool_move(_screen(DecorGrid.node_pos(start + Vector2i(1, 0)) + Vector2(0.01, 0.0)))
	editor._tool_move(_screen(DecorGrid.node_pos(start + Vector2i(4, 0))))
	editor._tool_release(_screen(DecorGrid.node_pos(start + Vector2i(4, 0))))
	check(decor.wall_count() == 4 and decor.wall_at(DecorGrid.edge_key(&"x", start.x, start.y)).get("piece", &"") == &"wall_plain",
		"sürükleyerek 4 segment örüldü (%d)" % decor.wall_count())
	check(economy.money == money - decor.price_of(&"wall_plain") * 4, "eksik parçalar satın alındı")
	editor.undo()
	check(decor.wall_count() == 0 and decor.owned_of(&"wall_plain") == 0 and economy.money == money,
		"geri al: duvar söküldü, satın alma iade edildi")
	editor.set_wall_mode(&"build")
	editor._tool_press(_screen(cell_pos(start.x + 0.5, start.y)))
	editor._tool_release(_screen(cell_pos(start.x + 0.5, start.y)))
	check(decor.wall_count() == 1 and decor.wall_at(DecorGrid.edge_key(&"x", start.x, start.y)).get("piece", &"") == &"wall_plain",
		"dokunuş tek segment koydu")
	editor.end_tool()
	check(editor.tool == GarageEditor.Tool.OBJECT, "eşya düzenine dönüldü")
	router.close_all()
	await frames(4)


## Oyun modunda eşyaya BASILI TUT → düzenleyici o eşya tutulmuş açılır, parmak kalkmadan taşınır.
## Gerçek fare olaylarıyla (root.push_input): HUD'daki DecorHoldGesture → GarageEditScreen → GarageEditor.
func _hold_to_move() -> void:
	print("== 9) BASILI TUT → TAŞI ==")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	check(hud.decor_hold != null, "HUD'da basılı tutma algılayıcısı var")
	decor.reset()
	economy.set_money(100000)
	var item: StringName = &"tool_cabinet"
	check(decor.purchase(item), "dolap alındı")
	# Biri eşyanın, biri taşınacağı yer: iki geçerli göz, arada en az 2 göz
	var spots: Array[Vector3] = []
	for j: int in range(2, 10):
		for i: int in range(2, 14):
			var p: Vector2 = cell_pos(i + 0.5, j + 0.5)
			var pos: Vector3 = Vector3(p.x, 0.0, p.y)
			if view.is_valid(item, pos, 0.0) and (spots.is_empty() or Vector2(spots[0].x, spots[0].z).distance_to(p) > DecorGrid.CELL * 2.5):
				spots.append(pos)
			if spots.size() == 2:
				break
		if spots.size() == 2:
			break
	check(spots.size() == 2, "iki boş yer bulundu")
	if spots.size() < 2:
		return
	var iid: String = decor.add_instance(item, spots[0], 0.0)
	await frames(4)
	var body: Node3D = view.body_of(iid)
	var at: Vector2 = camera.unproject_position(body.global_position + Vector3.UP * 0.05)
	var to: Vector2 = camera.unproject_position(spots[1] + Vector3.UP * 0.05)
	var router: UiRouter = hud.router
	# Kısa dokunuş: düzenleyici açılmaz
	_mouse(at, true)
	await frames(2)
	_mouse(at, false)
	await create_timer(DecorHoldGesture.HOLD_TIME + 0.2).timeout
	check(not editor.active and router.top() == &"", "kısa dokunuş düzenleyiciyi açmadı")
	# Boş zemine basılı tutmak: açılmaz
	var empty: Vector2 = camera.unproject_position(spots[1])
	_mouse(empty, true)
	await create_timer(DecorHoldGesture.HOLD_TIME + 0.2).timeout
	_mouse(empty, false)
	await frames(2)
	check(not editor.active, "boş zemine basılı tutmak düzenleyiciyi açmadı")
	# Eşyaya basılı tut: düzenleyici açılır, eşya tutulmuş (kalkmış), kamera kıpırdamaz
	var cam_before: Vector3 = camera.global_position
	_mouse(at, true)
	await create_timer(DecorHoldGesture.HOLD_TIME + 0.2).timeout
	await frames(3)
	check(router.top() == &"garage_edit" and editor.active, "basılı tutunca düzenleme modu açıldı")
	check(editor.selected() == iid and bool(editor.get("_dragging")), "eşya seçili ve parmağın altında tutuluyor")
	check(camera.global_position.distance_to(cam_before) < 0.001, "kamera kıpırdamadı (eşya parmağın altında kaldı)")
	# Parmak kalkmadan sürükle, bırak: yeni yerine kaydedilir
	for k: int in range(1, 9):
		_motion(at.lerp(to, k / 8.0))
		await frames(1)
	_mouse(to, false)
	await frames(3)
	var moved: Vector3 = decor.instance(iid).get("pos", Vector3.ZERO)
	check(Vector2(moved.x, moved.z).distance_to(Vector2(spots[1].x, spots[1].z)) < DecorGrid.CELL * 0.6,
		"bırakınca eşya yeni yerine kondu (%s → %s)" % [spots[0], moved])
	check(not bool(editor.get("_dragging")) and editor.active, "sürükleme bitti, düzenleyici açık kaldı")
	router.close_all()
	await frames(4)
	check(not editor.active, "BİTİR: oyuna dönüldü")


## Dekorasyon v3: katalog ~1,5 kat; her yeni desen / kaplama gerçekten çiziliyor, her eşyanın modeli var,
## desen sayısı zemin shader'ının dizilerine sığıyor, palet rütbe → fiyat sırasında.
func _catalog_v3() -> void:
	print("== 10) DEKORASYON v3 KATALOĞU ==")
	var active: int = GarageDecor.all().size()   # emekli kayıtlar all()'da yok
	check(active >= 216, "katalog v2'nin 1,5 katı (%d eşya, v2: 144)" % active)
	var patterns: Array[Dictionary] = GarageDecor.items_in(GarageDecor.Kind.FLOOR_PATTERN)
	check(patterns.size() <= GarageDecorView.MAX_PATTERNS,
		"desenler zemin shader'ına sığıyor (%d / %d)" % [patterns.size(), GarageDecorView.MAX_PATTERNS])
	var plain: Array[StringName] = []
	for item: Dictionary in patterns:
		var img: Image = DecorTextures.pattern_image(item["id"])
		if img.get_pixel(5, 5) == Color("777777") and img.get_pixel(70, 40) == Color("777777"):
			plain.append(item["id"])
	check(plain.is_empty(), "her zemin deseninin kendi dokusu var %s" % [plain])
	# Oyun desenleri pişmiş dosyadan okur (DecorTextures.BAKE_PATH): kodla üretilenle bit bit aynı olmalı.
	# Çizim kodu / katalog değişip araç çalıştırılmadıysa oyun eski görüntüyü gösterirdi.
	var stale: Array[String] = []
	for item: Dictionary in patterns:
		var baked: Image = DecorTextures._baked(String(item["id"]))
		if baked == null or baked.get_data() != DecorTextures.generate_pattern(item["id"]).get_data():
			stale.append(String(item["id"]))
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.WALL_SURFACE):
		var made: Image = DecorTextures.generate_wall(item["id"])
		if made == null:
			continue
		var baked_wall: Image = DecorTextures._baked("wall:" + String(item["id"]))
		if baked_wall == null or baked_wall.get_data() != made.get_data():
			stale.append("wall:" + String(item["id"]))
	check(stale.is_empty(), "pişmiş desenler kodla aynı (eskiyse: tools/bake_floor_patterns.gd) %s" % [stale])
	var grey: Array[StringName] = []
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.WALL_SURFACE):
		if DecorTextures.wall_color(item["id"]).is_equal_approx(Color(0.6, 0.6, 0.6)):
			grey.append(item["id"])
	check(grey.is_empty(), "her duvar kaplamasının kendi rengi var %s" % [grey])
	var no_model: Array[StringName] = []
	for item: Dictionary in GarageDecor.all():
		if not GarageDecor.is_placeable(item["id"]) or DecorBuilder.has_model(item["id"]):
			continue
		var body: Node3D = DecorBuilder.build(item["id"])   # model yoksa kodla üretilen gövde
		if body == null or body.get_child_count() == 0:
			no_model.append(item["id"])
		if body:
			body.free()
	check(no_model.is_empty(), "her eşyanın gövdesi var %s" % [no_model])
	var unsorted: Array[int] = []
	for kind: int in GarageDecor.categories():
		var order: Array[Dictionary] = GarageDecor.shop_order(kind)
		for k: int in range(1, order.size()):
			var a: Dictionary = order[k - 1]
			var b: Dictionary = order[k]
			if int(a["min_rank"]) > int(b["min_rank"]) \
					or (int(a["min_rank"]) == int(b["min_rank"]) and int(a["price"]) > int(b["price"])):
				unsorted.append(kind)
				break
	check(unsorted.is_empty(), "palet kartları rütbe → fiyat sırasında %s" % [unsorted])


func _mouse(at: Vector2, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	root.push_input(event, true)   # görünüm alanı koordinatı (headless pencere boyutundan bağımsız)


func _motion(at: Vector2) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = at
	event.global_position = at
	root.push_input(event, true)


func _screen(p: Vector2) -> Vector2:
	return camera.unproject_position(Vector3(p.x, 0.01, p.y))
