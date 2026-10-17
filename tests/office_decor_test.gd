extends SceneTree
## OFİS DEKORU — garaja ofis kurmak için 16 eşya (12 zemin YAŞAM ALANI'nda, 4 duvar DUVAR EŞYASI'nda):
## katalog (tür, yerleşim, model, fiyat / garaj değeri, rütbe), model ölçüsü (gerçek metre) ve üçgen bütçesi,
## İngilizce / İspanyolca çeviri, garajda yerleşim (zemin eşyası boş yere, duvar eşyası duvara), palette kart.
## Gerçek düğümlerle koşar (Main.tscn). Modeller: tools/decor/props_v5_ofis.py.
##   tools/run_tests.sh office_decor_test

const FLOOR_ITEMS: Array[StringName] = [&"office_desk", &"filing_cabinet", &"bookcase", &"visitor_chairs", &"copier",
	&"coffee_station", &"meeting_table", &"office_safe", &"drafting_table", &"reception_desk", &"floor_lamp",
	&"flip_chart"]
const WALL_ITEMS: Array[StringName] = [&"office_whiteboard", &"certificates", &"world_map", &"wall_ac"]
## Modellerin üçgen sınırı (en kalabalığı 6 koltuklu toplantı masası).
const MAX_TRIANGLES: int = 3500

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView


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
	_catalog()
	_models()
	_translations()
	await _placement()
	await _palette()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _all() -> Array[StringName]:
	var out: Array[StringName] = []
	out.append_array(FLOOR_ITEMS)
	out.append_array(WALL_ITEMS)
	return out


func _catalog() -> void:
	print("== 1) KATALOG ==")
	check(_all().size() >= 10, "en az 10 ofis eşyası (%d)" % _all().size())
	var bad: Array[StringName] = []
	for id: StringName in FLOOR_ITEMS:
		var item: Dictionary = GarageDecor.get_item(id)
		if item.is_empty() or int(item["kind"]) != GarageDecor.Kind.LOUNGE or GarageDecor.placement(id) != GarageDecor.PLACE_FLOOR:
			bad.append(id)
	check(bad.is_empty(), "zemin eşyaları YAŞAM ALANI'nda, yere konur %s" % [bad])
	bad.clear()
	for id: StringName in WALL_ITEMS:
		var item: Dictionary = GarageDecor.get_item(id)
		if item.is_empty() or int(item["kind"]) != GarageDecor.Kind.WALL_ITEM or GarageDecor.placement(id) != GarageDecor.PLACE_WALL:
			bad.append(id)
	check(bad.is_empty(), "duvar eşyaları DUVAR EŞYASI'nda, duvara asılır %s" % [bad])
	bad.clear()
	for id: StringName in _all():
		var item: Dictionary = GarageDecor.get_item(id)
		var price: int = int(item.get("price", 0))
		var value: int = int(item.get("value", 0))
		if price <= 0 or value * 5 != price * 2 or GarageDecor.is_gem_item(id) or int(item.get("min_rank", 0)) < 1 \
				or int(item.get("min_rank", 0)) > 4 or String(item.get("desc", "")) == "":
			bad.append(id)
	check(bad.is_empty(), "₺ fiyatı, garaj değeri %%40, rütbe 1–4, açıklama %s" % [bad])
	var early: int = 0
	for id: StringName in _all():
		if int(GarageDecor.get_item(id)["min_rank"]) == 1:
			early += 1
	check(early >= 6, "yeni oyuncu ofise hemen başlayabilir: %d eşya rütbe 1'de" % early)
	check(not GarageDecor.KIND_KEYS.has("office"), "ayrı OFİS sekmesi yok: ofis YAŞAM ALANI'nda (kullanıcı kararı)")


func _models() -> void:
	print("== 2) MODELLER ==")
	var missing: Array[StringName] = []
	var heavy: Array[String] = []
	var odd: Array[String] = []
	for id: StringName in _all():
		if not DecorBuilder.has_model(id):
			missing.append(id)
			continue
		var tris: int = _triangles((load(DecorBuilder.model_path(id)) as PackedScene).instantiate())
		if tris > MAX_TRIANGLES:
			heavy.append("%s %d" % [id, tris])
		# Gerçek metre: yerleşim ölçüsü × dünya ölçeği / (1 m'nin dünya karşılığı)
		var meters: Vector3 = DecorBuilder.local_size(id) * GarageDecorView.WORLD_SCALE / DecorBuilder.METER
		var wall: bool = WALL_ITEMS.has(id)
		var ok: bool = meters.y > 0.25 and meters.y < 2.0 and meters.x < 2.5 and meters.z < 2.5
		if wall:
			ok = ok and meters.z < 0.3   # duvara yaslı, ince
		if not ok:
			odd.append("%s %.2fx%.2fx%.2f" % [id, meters.x, meters.y, meters.z])
	check(missing.is_empty(), "her eşyanın Blender modeli var %s" % [missing])
	check(heavy.is_empty(), "üçgen bütçesi ≤ %d %s" % [MAX_TRIANGLES, heavy])
	check(odd.is_empty(), "ölçüler gerçekçi (yükseklik 0,25–2 m, taban ≤ 2,5 m, duvar eşyası ince) %s" % [odd])
	var desk: float = DecorBuilder.local_size(&"office_desk").y * GarageDecorView.WORLD_SCALE / DecorBuilder.METER
	check(desk > 1.0 and desk < 1.4, "çalışma masası monitörüyle ~1,26 m (%.2f)" % desk)


func _triangles(node: Node) -> int:
	var total: int = 0
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		var mesh: Mesh = (node as MeshInstance3D).mesh
		for s: int in mesh.get_surface_count():
			var arrays: Array = mesh.surface_get_arrays(s)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count: int = indices.size() if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			total += int(count / 3.0)
	for child: Node in node.get_children():
		total += _triangles(child)
	if node.get_parent() == null:
		node.free()
	return total


func _translations() -> void:
	print("== 3) ÇEVİRİ ==")
	for lang: String in ["en", "es", "de", "fr"]:
		var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://locale/%s.json" % lang))
		var missing: Array[String] = []
		for id: StringName in _all():
			var item: Dictionary = GarageDecor.get_item(id)
			for key: String in [String(item["title"]), String(item["desc"])]:
				if String(table.get(key, "")) == "":
					missing.append(key)
		check(missing.is_empty(), "%s: başlık ve açıklamalar çevrili %s" % [lang, missing])


func _placement() -> void:
	print("== 4) GARAJDA YERLEŞİM ==")
	for inst: Dictionary in decor.instances().duplicate():
		decor.remove_instance(inst["iid"])
	var owned: Dictionary = {}
	for id: StringName in _all():
		owned[id] = 1
	decor.load_state({"owned": owned})
	await frames(2)
	var unplaced: Array[StringName] = []
	for id: StringName in FLOOR_ITEMS:
		var iid: String = ""
		for j: int in range(1, 24):
			for i: int in range(1, 30):
				if iid != "":
					break
				var p: Vector2 = DecorGrid.CORNER - Vector2(float(i), float(j)) * DecorGrid.CELL
				if view.is_valid(id, Vector3(p.x, view.area().floor_y, p.y), 0.0):
					iid = decor.add_instance(id, Vector3(p.x, view.area().floor_y, p.y), 0.0)
		await frames(1)
		if iid == "" or view.body_of(iid) == null:
			unplaced.append(id)
		elif iid != "":
			decor.remove_instance(iid)
	check(unplaced.is_empty(), "her zemin eşyası garajda boş bir yere konur %s" % [unplaced])
	var a: DecorArea = view.area()
	var hung: Array[String] = []
	var x: float = a.floor_rect.position.x + 0.5   # sol duvardan uzak: en yakın duvar arka duvar olsun
	for id: StringName in WALL_ITEMS:
		var spot: Dictionary = view.place_point(id, Vector2(x, a.back_face_z + 0.2), 0.0, 0.0)
		var pos: Vector3 = spot["pos"]
		if view.is_valid(id, pos, float(spot["yaw"])):
			var iid: String = decor.add_instance(id, pos, float(spot["yaw"]))
			await frames(1)
			var body: Node3D = view.body_of(iid)
			if body:
				var box: AABB = GarageDecorView._tree_box(body)
				if absf(box.position.z - a.back_face_z) < 0.01 and box.position.y > a.floor_y + 0.05:
					hung.append(String(id))
		x += view.wall_width(id) + 0.05
	check(hung.size() == WALL_ITEMS.size(), "duvar eşyaları arka duvara yaslı asılır (%s)" % [hung])
	for inst: Dictionary in decor.instances().duplicate():
		decor.remove_instance(inst["iid"])


func _palette() -> void:
	print("== 5) DÜZENLEME PALETİ ==")
	var lounge: Array[StringName] = []
	for item: Dictionary in GarageDecor.shop_order(GarageDecor.Kind.LOUNGE):
		lounge.append(item["id"])
	var listed: bool = true
	for id: StringName in FLOOR_ITEMS:
		listed = listed and lounge.has(id)
	check(listed, "YAŞAM ALANI mağaza sırasında 12 ofis eşyası (%d kart)" % lounge.size())
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"garage_edit")
	await frames(20)
	var es: GarageEditScreen = hud.garage_edit_screen
	es._on_tab_pressed(GarageDecor.Kind.LOUNGE)
	await frames(6)
	var cards: Dictionary = es.get("_cards")
	var shown: Array[StringName] = []
	for id: StringName in FLOOR_ITEMS:
		if cards.has(id):
			shown.append(id)
	check(shown.size() == FLOOR_ITEMS.size(), "YAŞAM ALANI sekmesinde ofis kartları (%d / %d)" % [shown.size(), FLOOR_ITEMS.size()])
	es._on_tab_pressed(GarageDecor.Kind.WALL_ITEM)
	await frames(6)
	cards = es.get("_cards")
	var wall_shown: int = 0
	for id: StringName in WALL_ITEMS:
		if cards.has(id):
			wall_shown += 1
	check(wall_shown == WALL_ITEMS.size(), "DUVAR EŞYASI sekmesinde ofis duvar kartları (%d / %d)" % [wall_shown, WALL_ITEMS.size()])
	hud.router.close_all()
	await frames(6)
