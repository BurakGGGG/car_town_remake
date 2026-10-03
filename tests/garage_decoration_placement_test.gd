extends SceneTree
## GARAJ DEKORASYON YERLEŞİMİ — şartname §33'teki 24 zorunlu senaryo.
##
## Gerçek düğümlerle koşar: Main.tscn, DecorManager, GarageDecorView, GarageEditor, SaveManager,
## GarageUpgradeManager. Düzenleyici HUD router'ı üzerinden açılır (oyundaki yol). Sahiplik
## load_state ile verilir; satın alma, rütbe kilidi ve garaj değeri decor_test paketinde.
## Gerçek fare / dokunmatik girdiyle oynanış testi ayrıca: qa/garaj_editor_oyun.gd.
##
## Çalıştırma (yalıtılmış kayıt klasöründe):
##   tools/run_tests.sh garage_decoration_placement_test
##   godot-4 --headless --path . -s res://tests/garage_decoration_placement_test.gd
##
## Her kontrol bir senaryo numarasına yazılır; sonda 24 senaryonun GEÇTİ / KALDI tablosu basılır.

const CASES: Array[String] = [
	"",
	"katalog yüklenir",
	"yeni eşya garaja konur (spawn)",
	"taşıma",
	"döndürme",
	"silme",
	"silinen depoya döner",
	"aynı eşyadan birden çok kopya",
	"konum kaydedilir",
	"dönüş kaydedilir",
	"yüklemede konum geri gelir",
	"yüklemede dönüş geri gelir",
	"garaj sınırı",
	"zemine oturma",
	"duvar eşyası verisi ve duvara oturma",
	"normal modda girdi etkilenmez",
	"düzenlemede girdi yalıtılır",
	"geri al: yerleştirme",
	"geri al: taşıma",
	"geri al: döndürme",
	"geri al: silme",
	"garaj büyüyünce alan büyür",
	"yeniden yüklemede yinelenme yok",
	"geçersiz yerleşim reddedilir",
	"eski kayıt (v8) taşınır",
]
const CHAIR: StringName = &"deck_chair"
const TABLE: StringName = &"coffee_table"
const CLOCK: StringName = &"wall_clock"
const FIXTURE: String = "user://katalog_deneme.json"

var fails: int = 0
var _case_ok: Dictionary = {}   # senaryo no → bool

var decor: DecorManager
var view: GarageDecorView
var editor: GarageEditor
var save: SaveManager
var upgrades: GarageUpgradeManager
var economy: EconomyManager
var garage: Node3D
var router: UiRouter
var hud: Node
var _notices: Array[String] = []


func check(n: int, cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + "[%02d] %s" % [n, what])
	_case_ok[n] = bool(_case_ok.get(n, true)) and cond
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	decor = get_first_node_in_group("decor")
	view = get_first_node_in_group("garage_decor_view")
	save = get_first_node_in_group("save_manager")
	upgrades = get_first_node_in_group("garage_upgrades")
	economy = get_first_node_in_group("economy")
	garage = get_first_node_in_group("garage_system")
	editor = get_first_node_in_group("garage_editor")
	hud = current_scene.find_child("HUD", true, false)
	router = hud.get("router") if hud else null
	save.new_game()
	await frames(4)
	editor.notice.connect(func(text: String) -> void: _notices.append(text))

	await _catalog()          # 01
	await _normal_input()     # 15 (düzenleyici kapalı)
	await _open_editor()      # 16
	await _spawn_move_rotate_delete()   # 02–06
	await _copies()           # 07
	await _save_load()        # 08–11
	await _boundary()         # 12
	await _floor_snap()       # 13
	await _wall()             # 14
	await _undo()             # 17–20
	await _no_duplicates()    # 22
	await _invalid()          # 23
	await _migration()        # 24
	await _close_editor()     # 15 / 16 (kapanınca geri gelir)
	await _level_expansion()  # 21 (garajı büyüttüğü için en son)

	print("")
	print("== ÖZET (şartname §33) ==")
	for n: int in range(1, CASES.size()):
		var ok: bool = bool(_case_ok.get(n, false))
		print("  %s  %02d %s%s" % ["GEÇTİ" if ok else "KALDI", n, CASES[n], "" if _case_ok.has(n) else " (koşmadı)"])
		if not _case_ok.has(n):
			fails += 1
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


# --- 01 --------------------------------------------------------------------------------

func _catalog() -> void:
	print("== 01) KATALOG ==")
	check(1, GarageDecor.load_from(), "decor/decorations.json yüklendi")
	var items: Array[Dictionary] = GarageDecor.all()
	check(1, items.size() >= 70, "70+ eşya (%d)" % items.size())
	var bad: Array[String] = []
	var kinds: Dictionary = {}
	var glb: int = 0
	for item: Dictionary in items:
		var id: StringName = item["id"]
		kinds[int(item["kind"])] = true
		var placement: StringName = GarageDecor.placement(id)
		if String(item.get("title", "")) == "" or int(item["price"]) <= 0 or int(item["value"]) <= 0 \
				or int(item["value"]) >= int(item["price"]) or int(item["min_rank"]) < 1 \
				or not [GarageDecor.PLACE_FLOOR, GarageDecor.PLACE_WALL, GarageDecor.PLACE_SURFACE].has(placement):
			bad.append(String(id))
		elif not GarageDecor.is_surface(id):
			var size: Vector3 = DecorBuilder.local_size(id)   # boyut veriden değil modelden ölçülür
			if size.x <= 0.0 or size.y <= 0.0 or size.z <= 0.0:
				bad.append(String(id) + " (model ölçülemedi)")
			elif DecorBuilder.has_model(id):
				glb += 1
	check(1, bad.is_empty(), "her kayıtta ad, fiyat > değer > 0, rütbe, yerleşim türü; her eşyanın ölçülebilen gövdesi var %s" % [bad])
	print("   %d eşya .glb modelli, %d eşya kodla kurulan gövdeli, %d kaplama" % [glb,
		items.filter(func(i: Dictionary) -> bool: return not GarageDecor.is_surface(i["id"])).size() - glb,
		items.filter(func(i: Dictionary) -> bool: return GarageDecor.is_surface(i["id"])).size()])
	var cats: Array[int] = GarageDecor.categories()
	check(1, cats.size() == kinds.size(), "palet kategorileri = katalogdaki türler (%d)" % cats.size())
	for kind: int in cats:
		if GarageDecor.items_in(kind).is_empty():
			check(1, false, "boş kategori %d" % kind)
	check(1, is_equal_approx(GarageDecor.rotation_step(CHAIR), 45.0), "varsayılan dönüş adımı 45°")

	# Veri güdümlü: yeni eşya = JSON kaydı. Kod değişmeden scene_path / rotation_step / functional.
	var fixture: Dictionary = {"version": 1, "defaults": {"rotation_step": 45, "functional": false}, "items": [
		{"id": "deneme_raf", "title": "DENEME RAF", "kind": "workshop", "price": 100, "value": 40,
			"scene_path": "res://assets/decor/tool_cabinet.glb", "rotation_step": 90, "functional": true},
		{"id": "bozuk", "title": "X", "kind": "boyle_tur_yok", "price": 1, "value": 1},
		{"id": "deneme_raf", "title": "YİNELENEN", "kind": "lounge", "price": 1, "value": 1},
		{"id": "deneme_saat", "title": "DENEME SAAT", "kind": "wall_item", "price": 10, "value": 4},
	]}
	var f: FileAccess = FileAccess.open(FIXTURE, FileAccess.WRITE)
	f.store_string(JSON.stringify(fixture))
	f.close()
	check(1, GarageDecor.load_from(FIXTURE), "başka katalog dosyası yüklenebiliyor")
	check(1, GarageDecor.all().size() == 2, "geçersiz tür ve yinelenen id atlandı (%d kayıt)" % GarageDecor.all().size())
	check(1, String(GarageDecor.get_item(&"deneme_raf").get("title", "")) == "DENEME RAF", "ilk kayıt korundu")
	check(1, is_equal_approx(GarageDecor.rotation_step(&"deneme_raf"), 90.0)
		and is_equal_approx(GarageDecor.rotation_step(&"deneme_saat"), 45.0), "kayıttaki dönüş adımı, yoksa varsayılan")
	check(1, GarageDecor.is_functional(&"deneme_raf") and not GarageDecor.is_functional(&"deneme_saat"), "functional alanı")
	check(1, DecorBuilder.model_path(&"deneme_raf") == "res://assets/decor/tool_cabinet.glb", "scene_path modeli seçer")
	check(1, GarageDecor.placement(&"deneme_saat") == GarageDecor.PLACE_WALL, "yerleşim türü kategoriden çıkarılır")
	check(1, GarageDecor.categories() == [GarageDecor.Kind.WORKSHOP, GarageDecor.Kind.WALL_ITEM],
		"kategoriler yalnızca veride olanlar")
	GarageDecor.load_from()
	DirAccess.remove_absolute(FIXTURE)
	check(1, GarageDecor.all().size() == items.size(), "asıl katalog geri yüklendi")


# --- 15 / 16 -----------------------------------------------------------------------------

var _grid_visible_before: bool = false


func _normal_input() -> void:
	print("== 15) NORMAL MOD (düzenleyici kapalı) ==")
	check(15, editor != null and not editor.active, "düzenleyici sahnede ve kapalı")
	check(15, get_root().physics_object_picking, "dünya tıklaması (araç, tabela, tamir alanı) açık")
	check(15, not editor.is_processing_unhandled_input(), "düzenleyici girdi dinlemiyor")
	check(15, not view.is_editing() and view.get_node_or_null("BlockedZones") == null,
		"düzenleme görselleri (yasak alan örtüsü) kapalı")
	check(15, not bool(garage.get("_sign_hidden")), "genişletme tabelası görünür")
	var grid: Node3D = garage.get_node_or_null("BuildGrid/BuildGrid")
	_grid_visible_before = grid != null and grid.visible
	# Kapalı düzenleyiciye doğrudan tıklama verilse bile hiçbir şey olmaz
	decor.load_state({"owned": {CHAIR: 1}})
	var before: int = decor.instance_count()
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(576, 324)
	editor._unhandled_input(click)
	click = click.duplicate()
	click.pressed = false
	editor._unhandled_input(click)
	check(15, editor.selected() == "" and decor.instance_count() == before, "kapalıyken tıklama yok sayıldı")


func _open_editor() -> void:
	print("== 16) DÜZENLEME: girdi yalıtımı ==")
	router.open(&"garage_edit")
	await frames(6)
	check(16, router.top() == &"garage_edit" and editor.active, "router 'garage_edit' açtı, düzenleyici etkin")
	check(16, not get_root().physics_object_picking, "dünya tıklaması (fizik seçimi) kapalı: araç/müşteri/tabela tıklanmaz")
	check(16, editor.is_processing_unhandled_input(), "düzenleyici girdiyi alıyor")
	var parent: Node = editor.get_parent()
	check(16, editor.get_index() == parent.get_child_count() - 1,
		"düzenleyici sahne kökünün SON çocuğu: _unhandled_input'u kameradan önce alır")
	var top_right: Control = hud.get("top_right")
	check(16, top_right != null and not top_right.is_visible_in_tree(), "oyun HUD'u gizli (menü / görev açılmaz)")
	var screen: Control = router.screen(&"garage_edit")
	check(16, screen != null and screen.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"düzenleme ekranı dünyaya gelen dokunuşu yutmuyor (yalnızca plakalar)")
	check(16, view.is_editing() and view.get_node_or_null("BlockedZones") != null, "ızgara ve yasak alanlar görünür")
	check(16, bool(garage.get("_sign_hidden")), "genişletme tabelası eşyaların önünden kalktı")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	check(16, camera != null and camera.cull_mask & WorldCamera.LAYER_WORLD_UI == 0,
		"araç balonları / alan plakaları katmanı kamerada kapalı")
	var focus: GarageFocus = editor.get("_focus")
	check(16, focus != null and focus.visible, "garajın dışı odak efektiyle soluklaşıyor")
	var tabs: Dictionary = screen.get("_tab_buttons")
	var tab_kinds: Array = tabs.keys()
	tab_kinds.sort()
	check(16, tab_kinds == Array(GarageDecor.categories()), "sekmeler katalog kategorilerinden (%d)" % tabs.size())


func _close_editor() -> void:
	print("== 15/16) BİTİR → normal oyun ==")
	(router.screen(&"garage_edit") as GarageEditScreen).close()
	await frames(6)
	check(16, router.top() == &"" and not editor.active, "BİTİR düzenleyiciyi kapattı")
	check(15, get_root().physics_object_picking, "dünya tıklaması geri açıldı")
	check(15, not editor.is_processing_unhandled_input(), "düzenleyici girdiyi bıraktı")
	check(15, not view.is_editing() and view.get_node_or_null("BlockedZones") == null, "düzenleme görselleri kalktı")
	check(15, not bool(garage.get("_sign_hidden")), "tabela geri geldi")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	check(15, camera != null and camera.cull_mask & WorldCamera.LAYER_WORLD_UI != 0, "balon katmanı geri açıldı")
	await frames(40)   # odak kapanış geçişi (0,35 sn)
	check(15, not (editor.get("_focus") as GarageFocus).visible, "odak katmanı kapandı, çizilmiyor")
	var grid: Node3D = garage.get_node_or_null("BuildGrid/BuildGrid")
	check(15, (grid != null and grid.visible) == _grid_visible_before, "ızgara normal moddaki haline döndü")
	check(15, editor.history_size() == 0, "geri al geçmişi oturumla bitti")


# --- 02–06 -----------------------------------------------------------------------------

func _spawn_move_rotate_delete() -> void:
	print("== 02) SPAWN ==")
	decor.load_state({"owned": {CHAIR: 5, TABLE: 2, CLOCK: 2, &"sofa": 2, &"neon_sign": 1}})
	await frames(2)
	check(2, editor.begin_place(CHAIR), "depodaki şezlong için hayalet açıldı")
	check(2, editor.is_placing() and editor.ghost_valid(), "hayalet boş ve geçerli bir yerde")
	check(2, editor.confirm_ghost(), "YERLEŞTİR")
	await frames(2)
	var iid: String = editor.selected()
	var inst: Dictionary = decor.instance(iid)
	check(2, iid == "dec_001" and inst.get("item") == CHAIR, "örnek kimliği dec_001 (%s)" % iid)
	var body: Node3D = view.body_of(iid)
	check(2, body != null and _xz(body.global_position).is_equal_approx(_xz(inst["pos"])), "gövde dünyada, kayıtlı konumda")
	check(2, not editor.is_placing(), "hayalet kapandı, yeni eşya seçili")

	print("== 03) TAŞI ==")
	var from: Vector3 = inst["pos"]
	var to: Vector3 = _open_spot(CHAIR, iid, Rect2(_xz(from) - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))
	check(3, to != Vector3.INF and view.is_valid(CHAIR, to, 0.0, iid), "hedef geçerli, çevresi açık (%s)" % to)
	check(3, editor.move_to(iid, to, 0.0), "move_to")
	await frames(1)
	check(3, (decor.instance(iid)["pos"] as Vector3).is_equal_approx(to), "kayıttaki konum yeni yer")
	check(3, _xz(view.body_of(iid).global_position).is_equal_approx(_xz(to)), "gövde yeni yerde")

	print("== 04) DÖNDÜR ==")
	editor.select(iid)
	check(4, editor.rotate_selected(1), "sağa bir adım")
	var yaw: float = float((decor.instance(iid)["rot"] as Vector3).y)
	check(4, is_equal_approx(yaw, 315.0), "yön 45° döndü (%.0f)" % yaw)
	check(4, view.body_of(iid).transform.is_equal_approx(view.transform_for(CHAIR, to, 315.0)), "gövde döndü")
	check(4, editor.rotate_selected(-1) and is_equal_approx(float((decor.instance(iid)["rot"] as Vector3).y), 0.0),
		"sola bir adım geri")
	editor.rotate_selected(1)
	editor.rotate_selected(1)
	check(4, is_equal_approx(float((decor.instance(iid)["rot"] as Vector3).y), 270.0), "iki adım: 90°")

	print("== 05) SİL ==")
	check(5, editor.delete_selected(), "DEPOYA KALDIR")
	await frames(2)
	check(5, decor.instance(iid).is_empty() and view.body_of(iid) == null, "örnek ve gövde kalktı")
	check(5, editor.selected() == "", "seçim kalktı")

	print("== 06) SİLİNEN DEPOYA DÖNER ==")
	check(6, decor.owned_of(CHAIR) == 5, "sahiplik silinmedi (5)")
	check(6, decor.placed_of(CHAIR) == 0 and decor.available_of(CHAIR) == 5, "depoda 5, yerleşik 0")
	check(6, editor.begin_place(CHAIR) and editor.confirm_ghost(), "depodaki kopya yeniden konabiliyor")
	check(6, decor.placed_of(CHAIR) == 1 and decor.available_of(CHAIR) == 4, "yerleşik 1, depoda 4")


# --- 07 --------------------------------------------------------------------------------

func _copies() -> void:
	print("== 07) BİRDEN ÇOK KOPYA ==")
	var iids: Array[String] = []
	while decor.available_of(CHAIR) > 0:
		if not (editor.begin_place(CHAIR) and editor.confirm_ghost()):
			break
		iids.append(editor.selected())
	await frames(2)
	var unique: Dictionary = {}
	for inst: Dictionary in decor.instances():
		unique[inst["iid"]] = true
	check(7, decor.placed_of(CHAIR) == 5, "5 şezlong garajda (%d)" % decor.placed_of(CHAIR))
	check(7, unique.size() == decor.instance_count(), "her kopyanın kendi kimliği (%s)" % [unique.keys()])
	var bodies: int = 0
	for iid: String in unique:
		if view.body_of(iid):
			bodies += 1
	check(7, bodies == decor.instance_count(), "her kopyanın kendi gövdesi")
	check(7, not editor.begin_place(CHAIR), "depoda kalmayınca yeni hayalet açılmaz")
	var overlaps: int = 0
	var list: Array[Dictionary] = decor.instances()
	for i: int in list.size():
		for j: int in range(i + 1, list.size()):
			if DecorArea.overlaps(view.footprint(list[i]["item"], list[i]["pos"], float((list[i]["rot"] as Vector3).y)),
					view.footprint(list[j]["item"], list[j]["pos"], float((list[j]["rot"] as Vector3).y))):
				overlaps += 1
	check(7, overlaps == 0, "kopyalar üst üste binmedi")


# --- 08–11 -----------------------------------------------------------------------------

func _save_load() -> void:
	print("== 08–09) KAYIT ==")
	# Bir örnek 45°'ye döndürülür (sıkışık dizilişte dönüşü sığan ilk örnek): açı kayıtta aynen kalmalı
	var chair_iid: String = decor.instances()[0]["iid"]
	editor.move_to(chair_iid, _open_spot(CHAIR, chair_iid), 0.0)
	editor.select(chair_iid)
	check(9, editor.rotate_selected(-1), "bir örnek 45° döndürüldü (%s)" % chair_iid)
	var expected: Array[Dictionary] = decor.instances()
	check(8, save.save_game(), "save_game")
	var disk: Dictionary = save.peek()
	check(8, int(disk.get("version", 0)) == SaveManager.SAVE_VERSION and SaveManager.SAVE_VERSION == 10, "kayıt v10")
	var records: Array = (disk.get("decor", {}) as Dictionary).get("instances", [])
	check(8, records.size() == expected.size(), "%d örnek yazıldı" % records.size())
	var pos_ok: bool = true
	var rot_ok: bool = true
	var keys_ok: bool = true
	for rec: Dictionary in records:
		keys_ok = keys_ok and rec.has_all(["instance_id", "catalog_id", "position", "rotation", "scale"])
		var inst: Dictionary = decor.instance(String(rec["instance_id"]))
		var p: Dictionary = rec["position"]
		var r: Dictionary = rec["rotation"]
		pos_ok = pos_ok and not inst.is_empty() and _near(Vector3(p["x"], p["y"], p["z"]), inst["pos"], 0.0002)
		rot_ok = rot_ok and not inst.is_empty() and _near(Vector3(r["x"], r["y"], r["z"]), inst["rot"], 0.001)
	check(8, keys_ok, "kayıt biçimi: instance_id, catalog_id, position, rotation, scale")
	check(8, pos_ok, "position {x,y,z} birebir")
	check(9, rot_ok, "rotation {x,y,z} birebir (45° dahil)")
	check(9, records.any(func(rec: Dictionary) -> bool: return is_equal_approx(float(rec["rotation"]["y"]), 45.0)),
		"45° dönüş kayıtta")

	print("== 10–11) YÜKLEME ==")
	decor.reset()
	await frames(2)
	check(10, decor.instance_count() == 0 and view.body_of(chair_iid) == null, "bellek temizlendi")
	check(10, save.load_game(), "load_game")
	await frames(2)
	var same_pos: bool = decor.instance_count() == expected.size()
	var same_rot: bool = same_pos
	for e: Dictionary in expected:
		var inst: Dictionary = decor.instance(e["iid"])
		same_pos = same_pos and not inst.is_empty() and _near(inst["pos"], e["pos"], 0.0002)
		same_rot = same_rot and not inst.is_empty() and _near(inst["rot"], e["rot"], 0.001)
		var body: Node3D = view.body_of(e["iid"])
		same_pos = same_pos and body != null and _near(Vector3(body.global_position.x, 0.0, body.global_position.z),
			Vector3((e["pos"] as Vector3).x, 0.0, (e["pos"] as Vector3).z), 0.0002)
		same_rot = same_rot and body != null and body.transform.is_equal_approx(
			view.transform_for(e["item"], inst["pos"], float((inst["rot"] as Vector3).y)))
	check(10, same_pos, "her örnek ve gövdesi kayıtlı konumda")
	check(11, same_rot, "her örneğin yönü ve gövde dönüşü kayıttaki gibi")


# --- 12 --------------------------------------------------------------------------------

func _boundary() -> void:
	print("== 12) GARAJ SINIRI ==")
	decor.load_state({"owned": {CHAIR: 2, &"sofa": 1}})
	await frames(2)
	var a: DecorArea = view.area()
	var fp: Vector2 = view.footprint_size(CHAIR)
	var corner: Vector3 = Vector3(a.floor_rect.position.x + fp.x * 0.5 + 0.002, a.floor_y,
		a.floor_rect.position.y + fp.y * 0.5 + 0.002)
	check(12, view.is_valid(CHAIR, corner, 0.0), "arka-sol köşeye tam sığan konum geçerli")
	check(12, not view.is_valid(CHAIR, corner - Vector3(0.03, 0.0, 0.0), 0.0), "sol duvara taşan geçersiz")
	check(12, not view.is_valid(CHAIR, corner - Vector3(0.0, 0.0, 0.03), 0.0), "arka duvara taşan geçersiz")
	var front: Vector3 = Vector3(a.floor_rect.end.x - fp.x * 0.5 + 0.03, a.floor_y, a.floor_rect.end.y - 0.3)
	check(12, not view.is_valid(CHAIR, front, 0.0), "garajın açık ön/sağ kenarından taşan geçersiz")
	check(12, not view.is_valid(CHAIR, Vector3(a.floor_rect.end.x + 1.0, a.floor_y, a.floor_rect.get_center().y), 0.0),
		"garaj dışı geçersiz")
	# Yönlü iz: 0°'de duvara yaslı uzun eşya 45° dönünce köşeleri duvara girer
	var long_id: StringName = &"sofa"
	var lfp: Vector2 = view.footprint_size(long_id)
	var snug: Vector3 = Vector3(a.floor_rect.get_center().x, a.floor_y, a.floor_rect.position.y + lfp.y * 0.5 + 0.002)
	check(12, view.is_valid(long_id, snug, 0.0), "kanepe arka duvara yaslı geçerli")
	check(12, not view.is_valid(long_id, snug, 45.0), "45° dönünce duvara giriyor → geçersiz (eksene hizalı kutu değil)")
	var iid: String = decor.add_instance(long_id, snug, 0.0)
	editor.select(iid)
	# Duvara yaslıyken döndürülünce en yakın sığan yere (en çok 2 adım) kayarak döner; tek geri al
	check(12, editor.rotate_selected(1), "duvara yaslı kanepe döndürülebildi (duvardan kayarak)")
	var turned: Dictionary = decor.instance(iid)
	var shift: float = _xz(turned["pos"]).distance_to(_xz(snug))
	check(12, is_equal_approx(float((turned["rot"] as Vector3).y), 315.0) and shift > 0.0
		and shift <= GarageEditor.NUDGE_RINGS * 1.5 * editor.snap_step() + 0.001
		and view.is_valid(long_id, turned["pos"], 315.0, iid), "yeni yer geçerli, en çok %d adım ötede (%.3f)" % [GarageEditor.NUDGE_RINGS, shift])
	check(12, editor.undo() and (decor.instance(iid)["pos"] as Vector3).is_equal_approx(snug)
		and is_equal_approx(float((decor.instance(iid)["rot"] as Vector3).y), 0.0), "tek GERİ AL yeri ve yönü birlikte geri getirdi")
	editor.select("")
	# Dört bir yanı dolu şezlong: dönünce hiçbir yakın yere sığmıyor → reddedilir, söylenir
	decor.load_state({"owned": {CHAIR: 9}})
	await frames(1)
	var cfp: Vector2 = view.footprint_size(CHAIR) + Vector2(0.002, 0.002)
	var center: Vector3 = Vector3.INF
	var z: float = a.floor_rect.position.y + cfp.y * 1.5 + 0.01
	while center == Vector3.INF and z < a.floor_rect.end.y - cfp.y * 1.5:
		var x: float = a.floor_rect.position.x + cfp.x * 1.5 + 0.01
		while center == Vector3.INF and x < a.floor_rect.end.x - cfp.x * 1.5:
			var ok: bool = true
			for dx: int in [-1, 0, 1]:
				for dz: int in [-1, 0, 1]:
					var q: Vector3 = Vector3(x + dx * cfp.x, a.floor_y, z + dz * cfp.y)
					ok = ok and a.inside_floor(view.footprint(CHAIR, q, 0.0)) and not a.hits_obstacle(view.footprint(CHAIR, q, 0.0))
			if ok:
				center = Vector3(x, a.floor_y, z)
			x += 0.05
		z += 0.05
	var middle: String = ""
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			var added: String = decor.add_instance(CHAIR, center + Vector3(dx * cfp.x, 0.0, dz * cfp.y), 0.0)
			if dx == 0 and dz == 0:
				middle = added
	editor.select(middle)
	_notices.clear()
	check(12, center != Vector3.INF and decor.instance_count() == 9, "3×3 sıkışık şezlong bloğu kuruldu")
	check(12, not editor.rotate_selected(1), "ortadaki şezlong dönemiyor (sığacak yakın yer yok)")
	check(12, is_equal_approx(float((decor.instance(middle)["rot"] as Vector3).y), 0.0)
		and (decor.instance(middle)["pos"] as Vector3).is_equal_approx(center) and _notices.has("DÖNÜNCE SIĞMIYOR"),
		"yeri ve yönü değişmedi, oyuncuya söylendi")
	editor.select("")


# --- 13 --------------------------------------------------------------------------------

func _floor_snap() -> void:
	print("== 13) ZEMİNE OTURMA ==")
	decor.load_state({"owned": {CHAIR: 1}})
	await frames(2)
	var a: DecorArea = view.area()
	var step: float = editor.snap_step()
	var p: Dictionary = view.place_point(CHAIR, Vector2(a.floor_rect.get_center().x + 0.037, a.floor_rect.get_center().y - 0.051),
		0.0, step)
	var pos: Vector3 = p["pos"]
	check(13, is_equal_approx(pos.y, a.floor_y), "konumun y'si otomatik: zemin üstü (%.3f)" % pos.y)
	var gx: float = (pos.x - a.grid_origin.x) / step
	var gz: float = (pos.z - a.grid_origin.y) / step
	check(13, absf(gx - roundf(gx)) < 1e-4 and absf(gz - roundf(gz)) < 1e-4, "ızgara açıkken ızgaraya oturdu (adım %.4f)" % step)
	editor.set_snap(false)
	var free: Vector3 = view.place_point(CHAIR, Vector2(a.floor_rect.get_center().x + 0.037, a.floor_rect.get_center().y), 0.0,
		editor.snap_step())["pos"]
	check(13, is_equal_approx(free.x, a.floor_rect.get_center().x + 0.037), "ızgara kapalıyken serbest")
	editor.set_snap(true)
	# Bütün zemin eşyaları: taban zemin üstünde (gömülmez, havada durmaz), kendi ortası etrafında döner
	var sunk: Array[String] = []
	var floating: Array[String] = []
	var off_center: Array[String] = []
	var spot: Vector3 = Vector3(a.floor_rect.get_center().x, a.floor_y, a.floor_rect.get_center().y)
	var count: int = 0
	for item: Dictionary in GarageDecor.all():
		var id: StringName = item["id"]
		if GarageDecor.placement(id) != GarageDecor.PLACE_FLOOR:
			continue
		count += 1
		for yaw: float in [0.0, 45.0]:
			var body: Node3D = view.make_body(id)
			view.add_child(body)
			body.transform = view.transform_for(id, spot, yaw)
			var box: AABB = GarageDecorView._tree_box(body)
			if box.position.y < a.floor_y - 0.001:
				sunk.append("%s %.3f" % [id, box.position.y - a.floor_y])
			elif box.position.y > a.floor_y + 0.004:
				floating.append("%s +%.3f" % [id, box.position.y - a.floor_y])
			# Dönme ekseni izin ortası: 0°'de dünya kutusunun ortası tam konumda olmalı (yamuk
			# modellerde 45°'deki kutu ortası kayar, bu beklenen; eksen yine aynı noktadan geçer).
			if yaw == 0.0 and Vector2(box.get_center().x, box.get_center().z).distance_to(_xz(spot)) > 0.004:
				off_center.append("%s %.3f" % [id, Vector2(box.get_center().x, box.get_center().z).distance_to(_xz(spot))])
			body.free()
	check(13, sunk.is_empty(), "%d zemin eşyasının hiçbiri zemine gömülmüyor %s" % [count, sunk])
	check(13, floating.is_empty(), "hiçbiri havada durmuyor %s" % [floating])
	check(13, off_center.is_empty(), "hepsi kendi iz ortası etrafında döner (konum = iz ortası) %s" % [off_center])
	check(13, sunk.is_empty() and floating.is_empty(), "45° dönükken de tabanı zeminde (yukarıdaki iki kontrol iki yönü de kapsar)")


# --- 14 --------------------------------------------------------------------------------

func _wall() -> void:
	print("== 14) DUVAR EŞYASI ==")
	var wall_items: Array[StringName] = []
	for item: Dictionary in GarageDecor.all():
		if GarageDecor.placement(item["id"]) == GarageDecor.PLACE_WALL:
			wall_items.append(item["id"])
			if int(item["kind"]) != GarageDecor.Kind.WALL_ITEM:
				check(14, false, "%s duvar yerleşimli ama kategori PANO değil" % item["id"])
	check(14, wall_items.size() >= 1 and GarageDecor.placement(CLOCK) == GarageDecor.PLACE_WALL,
		"duvar eşyaları veride işaretli (%s)" % [wall_items])
	decor.load_state({"owned": {CLOCK: 2, &"neon_sign": 1}})
	await frames(2)
	var a: DecorArea = view.area()
	var near_back: Dictionary = view.place_point(CLOCK, Vector2(a.floor_rect.get_center().x, a.back_face_z + 0.2), 0.0, 0.0)
	var bp: Vector3 = near_back["pos"]
	check(14, is_equal_approx(float(near_back["yaw"]), 0.0) and is_equal_approx(bp.z, a.back_face_z + DecorArea.WALL_OFFSET)
		and is_equal_approx(bp.y, a.wall_mount_y), "arka duvara yakın nokta → arka duvara asılır (yön 0°)")
	var near_left: Dictionary = view.place_point(CLOCK, Vector2(a.left_face_x + 0.1, a.floor_rect.get_center().y), 0.0, 0.0)
	var lp: Vector3 = near_left["pos"]
	check(14, is_equal_approx(float(near_left["yaw"]), 90.0) and is_equal_approx(lp.x, a.left_face_x + DecorArea.WALL_OFFSET),
		"sol duvara yakın nokta → sol duvara asılır (yön 90°)")
	var iid: String = decor.add_instance(CLOCK, bp, 0.0)
	await frames(2)
	var box: AABB = GarageDecorView._tree_box(view.body_of(iid))
	check(14, absf(box.position.z - a.back_face_z) < 0.006, "saatin arka yüzü duvara yaslı (boşluk %.4f)" % (box.position.z - a.back_face_z))
	check(14, box.position.y > a.floor_y + 0.05, "duvar eşyası zeminde değil, duvarda (alt kenar y=%.3f)" % box.position.y)
	editor.select(iid)
	check(14, not editor.rotate_selected(1), "duvar eşyası serbest dönmez (yön duvardan gelir)")
	check(14, not view.is_valid(CLOCK, bp, 0.0), "aynı duvarda aynı yere ikinci saat geçersiz")
	check(14, view.is_valid(CLOCK, lp, 90.0), "öbür duvarda geçerli")
	# Duvar eşyası sürüklenince duvardan kopmaz: zeminin ortasına götürülse bile en yakın duvara asılır
	var mid: Dictionary = view.place_point(CLOCK, a.floor_rect.get_center(), 0.0, 0.0)
	var mp: Vector3 = mid["pos"]
	var on_wall: bool = is_equal_approx(mp.z, a.back_face_z + DecorArea.WALL_OFFSET) or is_equal_approx(mp.x, a.left_face_x + DecorArea.WALL_OFFSET)
	check(14, on_wall, "zemin ortası bile olsa duvara asılır (%s)" % mp)
	editor.select("")


# --- 17–20 ------------------------------------------------------------------------------

func _undo() -> void:
	print("== 17–20) GERİ AL ==")
	decor.load_state({"owned": {CHAIR: 3}})
	await frames(2)
	editor.begin_place(CHAIR)
	editor.confirm_ghost()
	var iid: String = editor.selected()
	var h0: int = editor.history_size()
	check(17, decor.instance_count() == 1 and editor.can_undo(), "yerleştirildi, geri alınabilir")
	check(17, editor.undo(), "GERİ AL")
	await frames(1)
	check(17, decor.instance(iid).is_empty() and decor.available_of(CHAIR) == 3 and view.body_of(iid) == null,
		"yerleştirme geri alındı: örnek yok, kopya depoda")
	check(17, editor.history_size() == h0 - 1, "geri alınan işlem geçmişten düştü")

	editor.begin_place(CHAIR)
	editor.confirm_ghost()
	iid = editor.selected()
	var from: Vector3 = decor.instance(iid)["pos"]
	var to: Vector3 = _open_spot(CHAIR, iid, Rect2(_xz(from) - Vector2(0.3, 0.3), Vector2(0.6, 0.6)))
	check(18, editor.move_to(iid, to, 0.0), "taşındı")
	check(18, editor.undo(), "GERİ AL")
	check(18, (decor.instance(iid)["pos"] as Vector3).is_equal_approx(from), "taşıma geri alındı (eski konum)")

	editor.select(iid)
	editor.rotate_selected(1)
	check(19, is_equal_approx(float((decor.instance(iid)["rot"] as Vector3).y), 315.0), "döndü")
	check(19, editor.undo(), "GERİ AL")
	check(19, is_equal_approx(float((decor.instance(iid)["rot"] as Vector3).y), 0.0), "dönüş geri alındı")

	editor.select(iid)
	editor.rotate_selected(1)
	var rec: Dictionary = decor.instance(iid)
	editor.delete_selected()
	await frames(1)
	check(20, decor.instance(iid).is_empty(), "silindi")
	check(20, editor.undo(), "GERİ AL")
	await frames(1)
	var back: Dictionary = decor.instance(iid)
	check(20, not back.is_empty() and (back["pos"] as Vector3).is_equal_approx(rec["pos"])
		and (back["rot"] as Vector3).is_equal_approx(rec["rot"]), "AYNI kimlikle, aynı yer ve yönde geri geldi (%s)" % iid)
	check(20, view.body_of(iid) != null, "gövdesi yeniden kuruldu")
	# Geçmiş sınırlı (son GarageEditor.HISTORY işlem)
	for i: int in GarageEditor.HISTORY + 4:
		editor.select(iid)
		editor.rotate_selected(1 if i % 2 == 0 else -1)
	check(20, editor.history_size() == GarageEditor.HISTORY, "geçmiş son %d işlemi tutuyor" % GarageEditor.HISTORY)


# --- 22 --------------------------------------------------------------------------------

func _no_duplicates() -> void:
	print("== 22) YİNELENME YOK ==")
	decor.load_state({"owned": {CHAIR: 3}})
	await frames(2)
	for i: int in 3:
		editor.begin_place(CHAIR)
		editor.confirm_ghost()
	save.save_game()
	save.load_game()
	save.load_game()
	await frames(2)
	var seen: Dictionary = {}
	for inst: Dictionary in decor.instances():
		seen[inst["iid"]] = true
	check(22, decor.instance_count() == 3 and seen.size() == 3, "iki kez yüklemeden sonra 3 örnek, 3 kimlik")
	check(22, view.get_node("DecorBodies").get_child_count() == 3, "dünyada 3 gövde (eskiler temizlendi)")
	var rec: Callable = func(iid: String, x: float) -> Dictionary:
		return {"instance_id": iid, "catalog_id": String(CHAIR), "position": {"x": x, "y": 0.01, "z": -0.5},
			"rotation": {"x": 0, "y": 0, "z": 0}, "scale": {"x": 1, "y": 1, "z": 1}}
	decor.load_state({"owned": {String(CHAIR): 3},
		"instances": [rec.call("dec_001", -1.0), rec.call("dec_001", -1.5), rec.call("dec_002", -0.6)],
		"next_instance": 1})
	check(22, decor.instance_count() == 2, "bozuk kayıttaki yinelenen kimlik atlandı")
	var fresh: String = decor.add_instance(CHAIR, _spot(CHAIR), 0.0)
	check(22, fresh != "" and fresh != "dec_001" and fresh != "dec_002", "yeni kimlik eskilerle çakışmadı (%s)" % fresh)
	decor.load_state({"owned": {String(CHAIR): 1},
		"instances": [rec.call("dec_001", -1.0), rec.call("dec_002", -1.5), rec.call("dec_003", -0.6)]})
	check(22, decor.instance_count() == 1, "sahip olunandan fazla yerleşim yüklenmez")


# --- 23 --------------------------------------------------------------------------------

func _invalid() -> void:
	print("== 23) GEÇERSİZ YERLEŞİM ==")
	decor.load_state({"owned": {CHAIR: 3}})
	await frames(2)
	var a: DecorArea = view.area()
	var p1: Vector3 = _spot(CHAIR)
	var first: String = decor.add_instance(CHAIR, p1, 0.0)
	var p2: Vector3 = _spot(CHAIR)
	var second: String = decor.add_instance(CHAIR, p2, 0.0)
	check(23, not view.is_valid(CHAIR, p1, 0.0), "başka eşyanın üstü geçersiz")
	check(23, not editor.move_to(second, p1, 0.0) and (decor.instance(second)["pos"] as Vector3).is_equal_approx(p2),
		"üst üste taşıma reddedildi, eşya yerinde")
	var spots: Array[Node3D] = (get_first_node_in_group("repair_bays") as Node).call("revealed_spots")
	var spot_center: Vector3 = spots[0].global_position
	check(23, not view.is_valid(CHAIR, Vector3(spot_center.x, a.floor_y, spot_center.z), 0.0), "tamir alanı geçersiz")
	var sign: Rect2 = garage.call("sign_footprint")
	check(23, not view.is_valid(CHAIR, Vector3(sign.get_center().x, a.floor_y, sign.get_center().y), 0.0),
		"genişletme tabelasının yeri geçersiz")
	# Hayalet geçersiz yerdeyken YERLEŞTİR çalışmaz
	check(23, editor.begin_place(CHAIR), "hayalet açıldı")
	editor.set("_ghost_pos", Vector3(spot_center.x, a.floor_y, spot_center.z))
	editor.call("_refresh_ghost")
	_notices.clear()
	var count: int = decor.instance_count()
	check(23, not editor.ghost_valid() and not editor.confirm_ghost(), "geçersiz hayalet yerleşmedi")
	check(23, decor.instance_count() == count and _notices.has("BURAYA SIĞMIYOR"), "sayı aynı, oyuncuya söylendi")
	editor.cancel_ghost()
	check(23, decor.add_instance(CHAIR, _spot(CHAIR), 0.0) != "", "son kopya konabiliyor")
	check(23, decor.add_instance(CHAIR, _spot(CHAIR), 0.0) == "", "sahip olunandan fazlası konamaz")
	check(23, decor.add_instance(&"olmayan_esya", p2, 0.0) == "", "katalogda olmayan eşya konamaz")
	check(23, decor.add_instance(&"floor_tile", p2, 0.0) == "", "kaplama yerleştirilmez (uygulanır)")
	check(23, not decor.move_instance(first, Vector3(NAN, 0.0, 0.0)), "sayı olmayan konum reddedildi")


# --- 24 --------------------------------------------------------------------------------

func _migration() -> void:
	print("== 24) v8 KAYIT TAŞIMA ==")
	var level: int = upgrades.garage_level()
	var open_slot: StringName = &""
	var closed_slot: StringName = &""
	for slot: StringName in DecorLegacySlots.FLOOR_SLOTS:
		var need: int = int(DecorLegacySlots.FLOOR_SLOT_LEVEL[slot])
		if need <= level and open_slot == &"":
			open_slot = slot
		elif need > level and closed_slot == &"":
			closed_slot = slot
	var v8: Dictionary = {
		"owned": ["tool_cabinet", "sofa", "wall_clock", "floor_tile", "olmayan_esya"],
		"placed": {String(open_slot): "tool_cabinet", String(closed_slot): "sofa", "pano_a": "wall_clock",
			"zemin": "floor_tile"},
	}
	decor.load_state(v8)
	await frames(2)
	check(24, decor.owned_count() == 4 and decor.owned_of(&"tool_cabinet") == 1, "sahiplik dizisi → adet (katalog dışı atlandı)")
	var cabinet: Array[Dictionary] = decor.instances().filter(func(i: Dictionary) -> bool: return i["item"] == &"tool_cabinet")
	var lot: Rect2 = DecorManager._legacy_lot(level)
	var p: Vector3 = DecorLegacySlots.FLOOR_SLOTS[open_slot]
	var cell: float = DecorLegacySlots.LEGACY_CELL
	var expect: Vector2 = Vector2(lot.position.x + (floorf((p.x - lot.position.x) / cell) + 0.5) * cell,
		lot.position.y + (floorf((p.z - lot.position.y) / cell) + 0.5) * cell)
	check(24, cabinet.size() == 1 and _xz(cabinet[0]["pos"]).is_equal_approx(expect),
		"%s yuvasındaki dolap eski yerleştiricinin konumunda (%s)" % [open_slot, expect])
	check(24, cabinet.size() == 1 and is_equal_approx(float((cabinet[0]["rot"] as Vector3).y),
		fposmod(float(DecorLegacySlots.FLOOR_SLOT_YAW.get(open_slot, 0.0)), 360.0)), "eski yuvanın yönü korundu")
	check(24, decor.placed_of(&"sofa") == 0 and decor.available_of(&"sofa") == 1,
		"seviyesi açılmamış yuvadaki (%s) kanepe depoda" % closed_slot)
	var clock: Array[Dictionary] = decor.instances().filter(func(i: Dictionary) -> bool: return i["item"] == CLOCK)
	check(24, clock.size() == 1 and view.body_of(clock[0]["iid"]) != null, "pano yuvasındaki saat duvarda")
	check(24, decor.surface(DecorManager.SURFACE_FLOOR) == &"floor_tile", "zemin yuvası → zemin kaplaması")
	var iids: Dictionary = {}
	for inst: Dictionary in decor.instances():
		iids[inst["iid"]] = true
	check(24, iids.size() == decor.instance_count(), "taşınan örneklerin kimlikleri benzersiz")

	# Dosyadan: v8 kaydı yüklenir, bir sonraki kayıt güncel sürümle yazılır
	var snap: Dictionary = save.snapshot()
	snap["version"] = 8
	snap["decor"] = v8
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(snap))
	f.close()
	decor.reset()
	check(24, save.load_game(), "v8 kayıt dosyası yüklendi")
	await frames(2)
	check(24, decor.placed_of(&"tool_cabinet") == 1 and decor.placed_of(CLOCK) == 1, "dosyadaki yerleşim taşındı")
	save.save_game()
	var disk: Dictionary = save.peek()
	var block: Dictionary = disk.get("decor", {})
	check(24, int(disk.get("version", 0)) == SaveManager.SAVE_VERSION and block.get("owned") is Dictionary and block.get("instances") is Array,
		"bir sonraki kayıt güncel biçimde")


# --- 21 --------------------------------------------------------------------------------

func _level_expansion() -> void:
	print("== 21) GARAJ BÜYÜYÜNCE ==")
	decor.load_state({"owned": {CLOCK: 1, CHAIR: 1}})
	await frames(2)
	economy.set_money(900_000_000)
	var a1: DecorArea = view.area()
	var rect1: Rect2 = a1.floor_rect
	var clock_pos: Vector3 = view.place_point(CLOCK, Vector2(rect1.get_center().x, a1.back_face_z + 0.05), 0.0, 0.0)["pos"]
	var clock: String = decor.add_instance(CLOCK, clock_pos, 0.0)
	var chair_pos: Vector3 = _spot(CHAIR)
	var chair: String = decor.add_instance(CHAIR, chair_pos, 0.0)
	var level: int = upgrades.garage_level()
	var prev: Rect2 = rect1
	var prev_back: float = a1.back_face_z
	while not upgrades.is_max(GarageUpgradeManager.GARAGE_ID):
		check(21, upgrades.buy(GarageUpgradeManager.GARAGE_ID), "garaj %d. seviyeye büyüdü" % (level + 1))
		level += 1
		await frames(3)
		var a: DecorArea = view.area()
		check(21, a.floor_rect.size.x > prev.size.x + 0.5 and a.floor_rect.size.y > prev.size.y + 0.5
			and a.floor_rect.grow(0.001).encloses(prev), "yerleşim alanı büyüdü, eskisini kapsıyor (%s)" % a.floor_rect)
		check(21, a.back_face_z < prev_back - 0.5, "arka duvar geriye kaydı (%.2f)" % a.back_face_z)
		var box: AABB = GarageDecorView._tree_box(view.body_of(clock))
		check(21, absf(box.position.z - a.back_face_z) < 0.006, "saat YENİ arka duvara yeniden asıldı (havada kalmadı)")
		check(21, _xz(view.body_of(chair).global_position).is_equal_approx(_xz(chair_pos)), "zemindeki şezlong yerinde")
		var outside: Vector3 = _spot(CHAIR, 0.0, prev.grow(0.2))
		check(21, outside != Vector3.INF, "yeni açılan alanda geçerli yer var (%s)" % outside)
		prev = a.floor_rect
		prev_back = a.back_face_z
	check(21, level >= 4, "4 seviye de denendi (%d)" % level)


# --- Yardımcılar -----------------------------------------------------------------------------

## Alanda (arka-sol köşeden satır satır) ilk geçerli zemin konumu. `avoid` verilirse merkezi o
## dikdörtgenin DIŞINDA olan ilk yer. Yoksa Vector3.INF.
func _spot(item: StringName, yaw: float = 0.0, avoid: Rect2 = Rect2()) -> Vector3:
	var a: DecorArea = view.area()
	var step: float = 0.0875
	var z: float = a.floor_rect.position.y + step
	while z < a.floor_rect.end.y:
		var x: float = a.floor_rect.position.x + step
		while x < a.floor_rect.end.x:
			var p: Vector3 = Vector3(x, a.floor_y, z)
			if (not avoid.has_area() or not avoid.has_point(Vector2(x, z))) and view.is_valid(item, p, yaw):
				return p
			x += step
		z += step
	return Vector3.INF


## Izgaraya oturan, çevresi açık (eşya 45° adımlarla her yöne dönebilir) ilk konum.
## `ignore` taşınacak örneğin kendisi; `avoid` merkezin düşmemesi gereken dikdörtgen.
func _open_spot(item: StringName, ignore: String = "", avoid: Rect2 = Rect2()) -> Vector3:
	var a: DecorArea = view.area()
	var step: float = editor.snap_step()
	var z: float = a.floor_rect.position.y + step
	while z < a.floor_rect.end.y:
		var x: float = a.floor_rect.position.x + step
		while x < a.floor_rect.end.x:
			var p: Vector3 = view.place_point(item, Vector2(x, z), 0.0, step)["pos"]
			var ok: bool = not avoid.has_area() or not avoid.has_point(_xz(p))
			for yaw: float in [0.0, 45.0, 90.0, 135.0]:
				ok = ok and view.is_valid(item, p, yaw, ignore)
			if ok:
				return p
			x += step
		z += step
	return Vector3.INF


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


static func _near(a: Vector3, b: Vector3, eps: float) -> bool:
	return absf(a.x - b.x) <= eps and absf(a.y - b.y) <= eps and absf(a.z - b.z) <= eps
