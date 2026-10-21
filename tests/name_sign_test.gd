extends SceneTree
## İSİM TABELASI (ana garaj duvar eşyası, 2026-10-21): katalog, gövde (pano + harf karoları, ölçü yazıdan bağımsız),
## örnek başına yazı (süzgeç, kayıt turu, bozuk kayıt), açık garajla arkadaşa giden yazı, düzenleme kipinde YAZI panosu.
## Gerçek düğümlerle koşar (Main.tscn).
##   tools/run_tests.sh name_sign_test

const ID: StringName = GarageDecor.NAME_SIGN

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
	_body()
	var iid: String = await _instance()
	_save_round(iid)
	_public(iid)
	await _editor(iid)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _catalog() -> void:
	print("== 1) KATALOG ==")
	var item: Dictionary = GarageDecor.get_item(ID)
	check(not item.is_empty() and int(item["kind"]) == GarageDecor.Kind.WALL_ITEM and GarageDecor.placement(ID) == GarageDecor.PLACE_WALL,
		"İSİM TABELASI duvar eşyası")
	check(int(item.get("min_level", 0)) == 1 and int(item.get("price", 0)) > 0 and not GarageDecor.is_gem_item(ID),
		"ilk seviyeden ₺ ile alınır (%d ₺)" % int(item.get("price", 0)))


func _body() -> void:
	print("== 2) GÖVDE ==")
	var body: Node3D = DecorBuilder.build_placeable(ID)
	var name_sign: NameSign = NameSign.find_in(body)
	check(name_sign != null and name_sign.find_child("Board", true, false) != null, "pano + tabela düğümü")
	check(name_sign != null and name_sign.tile_count() == Loc.t("GARAJIM").replace(" ", "").length(),
		"yazısız tabela GARAJIM yazar (%d karo)" % (name_sign.tile_count() if name_sign else -1))
	var box_default: AABB = DecorBuilder._local_bounds(body)
	if name_sign:
		name_sign.build_decor({"t": "ABCDEFGHIJKLMNOP", "s": 1, "c": 3})
	var box_long: AABB = DecorBuilder._local_bounds(body)
	check(box_default.size.x > 0.0 and box_long.size.is_equal_approx(box_default.size),
		"gövdenin ölçüsü yazıdan bağımsız (%s / %s)" % [box_default.size, box_long.size])
	check(name_sign != null and name_sign.tile_count() == 16, "16 harf panoya sığar (%d)" % (name_sign.tile_count() if name_sign else -1))
	body.free()


func _instance() -> String:
	print("== 3) ÖRNEK: YAZI, SÜZGEÇ ==")
	for inst: Dictionary in decor.instances().duplicate():
		decor.remove_instance(inst["iid"])
	decor.load_state({"owned": {String(ID): 2, "sign_oil": 1}})
	await frames(2)
	var a: DecorArea = view.area()
	var spot: Dictionary = view.place_point(ID, Vector2(a.floor_rect.position.x + 0.6, a.back_face_z + 0.2), 0.0, 0.0)
	var pos: Vector3 = spot["pos"]
	check(view.is_valid(ID, pos, float(spot["yaw"])), "arka duvara konabilir")
	var iid: String = decor.add_instance(ID, pos, float(spot["yaw"]))
	await frames(2)
	var body: Node3D = view.body_of(iid)
	check(body != null and NameSign.find_in(body) != null, "garajda tabela gövdesi")
	check(String(decor.instance_sign(iid)["t"]).is_empty(), "yeni tabelanın yazısı yok (GARAJIM görünür)")
	check(decor.set_instance_sign(iid, {"t": "Burak Usta", "s": 2, "c": 4}), "yazı yazıldı")
	await frames(2)
	body = view.body_of(iid)
	check(body != null and NameSign.find_in(body).tile_count() == 9, "gövde yeni yazıyla kuruldu (9 karo)")
	check(not decor.set_instance_sign(iid, {"t": "amk usta"}) and decor.instance_sign(iid)["t"] == "Burak Usta", "küfür reddedilir")
	check(not decor.set_instance_sign(iid, {"t": "<b>"}), "izinsiz karakter reddedilir")
	var oil: String = decor.add_instance(&"sign_oil", pos + Vector3(0.6, 0.0, 0.0), float(spot["yaw"]))
	check(oil != "" and not decor.set_instance_sign(oil, {"t": "Yağ"}), "başka eşyaya yazı yazılmaz")
	view.preview_sign(iid, {"t": "Önizleme", "s": 1, "c": 0})
	check(NameSign.find_in(view.body_of(iid)).tile_count() == 8 and decor.instance_sign(iid)["t"] == "Burak Usta",
		"önizleme gövdeyi değiştirir, kaydı değiştirmez")
	view.preview_sign(iid, decor.instance_sign(iid))
	return iid


func _save_round(iid: String) -> void:
	print("== 4) KAYIT ==")
	var state: Dictionary = JSON.parse_string(JSON.stringify(decor.state()))
	var recs: Array = (state["instances"] as Array).filter(func(r: Dictionary) -> bool: return r["instance_id"] == iid)
	check(recs.size() == 1 and (recs[0] as Dictionary).get("sign", {}).get("t", "") == "Burak Usta", "yazı kayıtta")
	decor.load_state(state)
	check(decor.instance_sign(iid) == {"t": "Burak Usta", "s": 2, "c": 4}, "kayıttan geri geldi")
	var bad: Dictionary = state.duplicate(true)
	for rec: Dictionary in bad["instances"]:
		if rec["instance_id"] == iid:
			rec["sign"] = {"t": "bu yazı on altı harften çok uzun", "s": 99, "c": -5}
	decor.load_state(bad)
	var loaded: Dictionary = decor.instance_sign(iid)
	check(String(loaded["t"]).length() <= NameSign.MAX_CHARS and int(loaded["s"]) == NameSign.STYLES.size() - 1 and int(loaded["c"]) == 0,
		"elle bozulmuş kayıt sınırlanır (%s)" % loaded)
	for rec: Dictionary in bad["instances"]:
		if rec["instance_id"] == iid:
			rec["sign"] = {"t": "amk", "s": "x"}
	decor.load_state(bad)
	check(String(decor.instance_sign(iid)["t"]).is_empty(), "küfürlü kayıt yazısız yüklenir")
	decor.load_state(state)


func _public(iid: String) -> void:
	print("== 5) ARKADAŞ ZİYARETİ ==")
	var save: SaveManager = get_first_node_in_group("save_manager") as SaveManager
	var public: Dictionary = JSON.parse_string(JSON.stringify(PublicGarage.from_snapshot(save.snapshot())))
	var found: String = ""
	for rec: Dictionary in ((public.get("decor", {}) as Dictionary).get("instances", []) as Array):
		if rec.get("instance_id") == iid:
			found = String((rec.get("sign", {}) as Dictionary).get("t", ""))
	check(found == "Burak Usta", "açık garajda tabelanın yazısı (%s)" % found)


func _editor(iid: String) -> void:
	print("== 6) DÜZENLEME: YAZI ==")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"garage_edit")
	await frames(20)
	var editor: GarageEditor = get_first_node_in_group("garage_editor") as GarageEditor
	var screen: Control = hud.garage_edit_screen
	editor.select(iid)
	await frames(3)
	var button: PlateButton = null
	for node: Node in screen.find_children("*", "PlateButton", true, false):
		if (node as PlateButton).text == Loc.t("YAZI"):
			button = node
	check(button != null and button.is_visible_in_tree(), "seçili tabelada YAZI düğmesi")
	if button == null:
		return
	button.pressed.emit()
	await frames(4)
	var panel: NameSignPanel = screen.find_child("NameSignPanel", true, false) as NameSignPanel
	check(panel != null and panel.visible, "YAZI → İSİM TABELASI panosu")
	if panel == null:
		return
	var rect: Rect2 = Hud.screen_rect(panel)
	var visible_rect: Rect2 = screen.get_viewport().get_visible_rect()
	check(visible_rect.encloses(rect.grow(-1.0)), "pano ekranın içinde (%s / %s)" % [rect, visible_rect.size])
	var edit: LineEdit = panel.find_child("SignText", true, false) as LineEdit
	check(edit.text == "Burak Usta", "kayıttaki yazıyla açılır")
	edit.text = "Garaj 34"
	edit.text_changed.emit(edit.text)
	await frames(2)
	check(NameSign.find_in(view.body_of(iid)).tile_count() == 7 and decor.instance_sign(iid)["t"] == "Burak Usta", "yazarken önizleme")
	(panel.find_child("CancelButton", true, false) as PlateButton).pressed.emit()
	await frames(2)
	check(not panel.visible and NameSign.find_in(view.body_of(iid)).tile_count() == 9, "VAZGEÇ eski yazıya döner")
	button.pressed.emit()
	await frames(4)
	edit.text = "Garaj 34"
	edit.text_changed.emit(edit.text)
	(panel.find_child("SaveButton", true, false) as PlateButton).pressed.emit()
	await frames(3)
	check(not panel.visible and decor.instance_sign(iid)["t"] == "Garaj 34", "KAYDET yazdı")
	hud.router.close_all()
	await frames(5)
