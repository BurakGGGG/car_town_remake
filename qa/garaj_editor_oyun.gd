extends SceneTree
## GARAJ DÜZENLEYİCİSİ — GERÇEK OYNANIŞ TESTİ (şartname §34–36).
##
## Oyunu açar ve düzenleyiciyi GERÇEK girdiyle (fare ya da dokunmatik olayları) kullanır: HUD
## plakasına basar, sekme seçer, kartla satın alır, hayaleti sürükleyip bırakır, eşyayı seçip
## taşır, düğmeyle döndürür, depoya kaldırır, geri alır, BİTİR'e basar. Kamera eşya sürüklenirken
## kıpırdamamalı; düzenlemede dünya tıklamaları (tabela, tamir alanı) çalışmamalı.
##
## İki aşama, iki ayrı süreç:
##   godot-4 --path . --resolution 1152x648 -s res://qa/garaj_editor_oyun.gd -- kur    [dokun]
##   godot-4 --path . --resolution 1152x648 -s res://qa/garaj_editor_oyun.gd -- dogrula
## "kur" düzeni kurup kaydeder ve beklenen düzeni user://editor_beklenen.json'a yazar; "dogrula"
## yeni bir süreçte kaydı yükleyip örnekleri birebir karşılaştırır. "dokun" verilirse bütün
## işaretçi girdisi DOKUNMATİK olaylarla gönderilir (mobil yol: ScreenTouch/ScreenDrag) ve iki
## ek adım koşar: eşya sürüklenirken ikinci parmakla pinch, paleti parmakla kaydırma. Fare
## yolunda bunların yerine PC kısayolları (R / Shift+R / Delete / Ctrl+Z) ve tekerlek denenir.
## Telefon oranı için: --resolution 1170x540 (19.5:9).

const OUT: String = "/home/burak/Projects/ct_shots/editor/"
const EXPECT_PATH: String = "user://editor_beklenen.json"

var _fails: int = 0
var _hud: Node
var _router: UiRouter
var _screen: GarageEditScreen
var _editor: GarageEditor
var _decor: DecorManager
var _view: GarageDecorView
var _camera: Camera3D
var _touch: bool = false
var _k: float = 1.0   # tuval → pencere koordinatı


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var phase: String = args[0] if args.size() > 0 else "kur"
	_touch = args.has("dokun")
	if _touch:
		# Masaüstünde DisplayServer.is_touchscreen_available() yalnızca bu açıkken true döner;
		# kaydırma kapları parmakla sürüklemeyi ancak dokunmatik ekranda işler (telefondaki gibi).
		Input.emulate_touch_from_mouse = true
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	_hud = current_scene.find_child("HUD", true, false)
	_router = _hud.get("router")
	_editor = get_first_node_in_group("garage_editor")
	_decor = get_first_node_in_group("decor")
	_view = get_first_node_in_group("garage_decor_view")
	_camera = get_root().get_camera_3d()
	_k = float(DisplayServer.window_get_size().y) / get_root().get_visible_rect().size.y
	print("pencere %s · tuval %s · girdi %s" % [DisplayServer.window_get_size(),
		get_root().get_visible_rect().size, "DOKUNMATİK" if _touch else "FARE"])
	if phase == "dogrula":
		await _verify()
	else:
		await _build()
	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)


# --- Aşama 1: taze kayıtla düzen kur ------------------------------------------------------

func _build() -> void:
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	(get_first_node_in_group("economy") as EconomyManager).set_money(1_000_000)
	await frames(10)

	print("== 0) TEST DERLEMESİ: paraya uzun bas → +10.000.000 ₺ (yalnızca debug) ==")
	var economy: EconomyManager = get_first_node_in_group("economy")
	var coin_box: Control = (_hud.get("coin_label") as Control).get_parent() as Control
	var coin_at: Vector2 = coin_box.get_global_rect().get_center()
	var money0: int = economy.money
	await _tap(coin_at)
	await create_timer(1.8).timeout
	check(economy.money == money0, "kısa dokunuş para vermedi")
	await _pointer(coin_at, true)
	await create_timer(1.8).timeout
	await _pointer(coin_at, false)
	await frames(3)
	check(economy.money == money0 + 10_000_000, "1,5 sn basılı tutunca +10.000.000 ₺ (%d)" % economy.money)
	economy.set_money(1_000_000)   # testin geri kalanı eski bakiyeyle
	await frames(5)

	print("== 1) NORMAL MOD: dünya tıklaması çalışıyor ==")
	var sign_center: Vector2 = _world_to_screen(Vector3(-0.52, 0.38, -0.6))
	await _tap(sign_center)
	await frames(10)
	var plate: Node = _hud.get("_bay_plate")
	# hide_bay_plate plakanın EBEVEYN grubunu gizler; plakanın kendi `visible`'ı true kalır
	check(plate != null and (plate as Control).is_visible_in_tree(), "normal modda GARAJI GENİŞLET tabelası tıklanıyor")
	if _hud.has_method("hide_bay_plate"):
		_hud.call("hide_bay_plate")
	await frames(5)

	print("== 2) GARAJI DÜZENLE plakası ==")
	var edit_button: PlateButton = _hud.get("edit_button")
	var cam_before: Vector3 = _camera.global_position
	var min_zoom_before: float = (_camera as WorldCamera).min_zoom
	await _tap(edit_button.get_global_rect().get_center())
	await frames(40)
	_screen = _router.screen(&"garage_edit") as GarageEditScreen
	check(_router.top() == &"garage_edit" and _editor.active, "plakaya basınca düzenleme modu açıldı")
	check(not (_hud.get("top_right") as Control).visible, "oyun HUD'u gizlendi (yanlışlıkla sekme açılmaz)")
	check(not _camera.global_position.is_equal_approx(cam_before), "kamera garaja odaklandı")
	await _shot("01_acilis")

	print("== 3) DÜZENLEMEDE dünya tıklaması YALITILMIŞ ==")
	var garage: Node = get_first_node_in_group("garage_system")
	var expand_hits: Array[int] = [0]
	garage.connect(&"expand_clicked", func() -> void: expand_hits[0] += 1)
	var sign_pos: Vector3 = Vector3(-0.52, 0.38, -0.6)
	await _tap(_world_to_screen(sign_pos))
	await _tap(_world_to_screen(Vector3(-1.72, 0.05, -1.05)))   # tamir alanı
	await frames(8)
	check(expand_hits[0] == 0, "düzenlerken tabela yerine tıklamak expand_clicked YAYMADI (%d)" % expand_hits[0])
	check(not (_hud.get("_bay_plate") as Control).is_visible_in_tree(), "genişletme plakası açılmadı")
	check(_router.top() == &"garage_edit", "düzenleme modunda kalındı")

	print("== 4) ŞEZLONG: sekme → kart → iki dokunuşta satın al → hayalet ==")
	await _open_tab(GarageDecor.Kind.LOUNGE)
	await _tap_card(&"deck_chair")
	check(_decor.owned_of(&"deck_chair") == 0, "ilk dokunuş satın ALMADI (onay istedi)")
	await _tap_card(&"deck_chair")
	check(_decor.owned_of(&"deck_chair") == 1, "ikinci dokunuş satın aldı")
	check(_editor.is_placing(), "hayalet çıktı")

	print("== 5) HAYALETİ SÜRÜKLE-BIRAK ==")
	var target: Vector3 = Vector3(-0.55, 0.01, -1.45)
	var cam_mid: Vector3 = _camera.global_position
	await _drag(_ghost_center(), _world_to_screen(target), 12)
	await frames(6)
	check(_camera.global_position.is_equal_approx(cam_mid), "hayalet sürüklenirken kamera KIPIRDAMADI")
	check(not _editor.is_placing() and _decor.instance_count() == 1, "bırakınca yerleşti")
	var chair1: String = _editor.selected()
	var p1: Vector3 = _decor.instance(chair1)["pos"]
	check(Vector2(p1.x, p1.z).distance_to(Vector2(target.x, target.z)) < 0.12,
		"bırakılan yerde (%.2f, %.2f)" % [p1.x, p1.z])
	check(absf(p1.y - _view.area().floor_y) < 0.001, "zemine oturdu (y=%.3f)" % p1.y)
	await _shot("02_sezlong")

	print("== 6) SEÇ + TAŞI ==")
	await _tap(_world_to_screen(Vector3(-1.9, 0.01, -0.35)))   # boş zemin: seçimi kaldır
	await frames(4)
	check(_editor.selected() == "", "boş zemine dokununca seçim kalktı")
	var body_screen: Vector2 = _world_to_screen(_view.body_of(chair1).global_position + Vector3(0.0, 0.03, 0.0))
	var move_to: Vector3 = Vector3(-0.9, 0.01, -0.4)
	cam_mid = _camera.global_position
	await _drag(body_screen, _world_to_screen(move_to + Vector3(0.0, 0.03, 0.0)), 12)
	await frames(6)
	check(_camera.global_position.is_equal_approx(cam_mid), "eşya sürüklenirken kamera KIPIRDAMADI")
	var p2: Vector3 = _decor.instance(chair1)["pos"]
	check(Vector2(p2.x, p2.z).distance_to(Vector2(move_to.x, move_to.z)) < 0.12,
		"taşındı (%.2f, %.2f) → (%.2f, %.2f)" % [p1.x, p1.z, p2.x, p2.z])
	check(_editor.selected() == chair1, "taşınan eşya seçili")

	print("== 7) DÖNDÜR (düğme) ==")
	await _tap(_button_center(_screen.get("_rot_right")))
	await frames(4)
	var yaw1: float = float((_decor.instance(chair1)["rot"] as Vector3).y)
	check(is_equal_approx(yaw1, 315.0), "sağa bir adım: 45° (yön %.0f)" % yaw1)
	await _tap(_button_center(_screen.get("_rot_right")))
	await frames(4)
	var yaw2: float = float((_decor.instance(chair1)["rot"] as Vector3).y)
	check(is_equal_approx(yaw2, 270.0), "sağa ikinci adım: 90° (yön %.0f)" % yaw2)

	print("== 8) İKİNCİ ŞEZLONG (aynı eşya, ayrı örnek) + YERLEŞTİR düğmesi ==")
	await _tap_card(&"deck_chair")
	await _tap_card(&"deck_chair")
	check(_decor.owned_of(&"deck_chair") == 2, "ikinci kopya alındı")
	check(_editor.is_placing(), "hayalet çıktı")
	await _tap(_button_center(_screen.get("_place_button")))
	await frames(4)
	var chair2: String = _editor.selected()
	check(_decor.instance_count() == 2 and chair2 != chair1, "ikinci şezlong ayrı kimlikle yerleşti (%s)" % chair2)
	await _tap(_button_center(_screen.get("_rot_left")))
	await frames(4)
	check(is_equal_approx(float((_decor.instance(chair2)["rot"] as Vector3).y), 45.0), "sola döndürüldü (45°)")

	print("== 9) SEHPA + UYARI TABELASI ==")
	await _tap_card(&"coffee_table")
	await _tap_card(&"coffee_table")
	await _tap(_button_center(_screen.get("_place_button")))
	await frames(4)
	var table: String = _editor.selected()
	check(_decor.instance(table).get("item") == &"coffee_table", "sehpa yerleşti")
	await _open_tab(GarageDecor.Kind.YARD)
	await _tap_card(&"warning_sign")
	await _tap_card(&"warning_sign")
	await _tap(_button_center(_screen.get("_place_button")))
	await frames(4)
	var sign_iid: String = _editor.selected()
	check(_decor.instance(sign_iid).get("item") == &"warning_sign", "tabela yerleşti")
	await _tap(_button_center(_screen.get("_rot_right")))
	await _tap(_button_center(_screen.get("_rot_right")))
	await frames(4)
	check(is_equal_approx(float((_decor.instance(sign_iid)["rot"] as Vector3).y), 270.0), "tabela 90° döndü")
	await _shot("03_dort_esya")

	print("== 10) DEPOYA KALDIR → depo adedi ==")
	var tbox: AABB = GarageDecorView._tree_box(_view.body_of(table))
	var ttop: Vector2 = _world_to_screen(Vector3(tbox.get_center().x, tbox.end.y, tbox.get_center().z))
	await _tap(ttop)
	await frames(4)
	print("   sehpa %s kutu %s · ekran %s · seçilen '%s' (%s)" % [table, tbox, ttop, _editor.selected(),
		_decor.instance(_editor.selected()).get("item", "-")])
	check(_editor.selected() == table, "sehpaya dokununca seçildi")
	await _tap(_button_center(_screen.get("_delete_button")))
	await frames(4)
	check(_decor.placed_of(&"coffee_table") == 0 and _decor.available_of(&"coffee_table") == 1,
		"sehpa depoya döndü (yerleşik 0, depoda 1)")
	check(_decor.owned_of(&"coffee_table") == 1, "sahiplik silinmedi")

	print("== 11) GERİ AL (silme) → aynı kimlikle geri ==")
	await _tap(_button_center(_screen.get("_undo_button")))
	await frames(4)
	check(_decor.instance(table).get("item") == &"coffee_table", "geri al: sehpa aynı kimlikle döndü (%s)" % table)
	await _tap(_button_center(_screen.get("_delete_button")))
	await frames(4)

	print("== 12) DEPODAKİ SEHPAYI BAŞKA YERE KOY ==")
	await _open_tab(GarageDecor.Kind.LOUNGE)
	check((_screen.get("_cards") as Dictionary)[&"coffee_table"].text.contains("DEPODA 1"), "kart DEPODA 1 gösteriyor")
	await _tap_card(&"coffee_table")
	check(_decor.owned_of(&"coffee_table") == 1, "depodaki kopya kullanıldı, yeniden satın ALINMADI")
	await _drag(_ghost_center(), _world_to_screen(Vector3(-1.9, 0.01, -1.5)), 10)
	await frames(6)
	var table2: String = _editor.selected()
	check(_decor.placed_of(&"coffee_table") == 1, "sehpa yeni yerde (%s)" % table2)

	print("== 13) GEÇERSİZ BIRAKMA reddedilir ==")
	var before_bad: Vector3 = _decor.instance(chair1)["pos"]
	var spot_center: Vector3 = Vector3(-1.72, 0.01, -1.05)   # tamir alanı
	await _drag(_world_to_screen(_view.body_of(chair1).global_position + Vector3(0.0, 0.03, 0.0)),
		_world_to_screen(spot_center), 10)
	await frames(6)
	check((_decor.instance(chair1)["pos"] as Vector3).is_equal_approx(before_bad),
		"tamir alanına bırakılan şezlong ESKİ YERİNE döndü")

	print("== 13b) BOŞ ZEMİN SÜRÜKLENİNCE KAMERA KAYAR (pan), eşyalar yerinde ==")
	var layout_before: Array[Dictionary] = _decor.instances()
	var selected_before: String = _editor.selected()
	var empty: Vector2 = get_root().get_visible_rect().size * Vector2(0.12, 0.35)
	check(_view.pick(_camera, empty) == "", "sürükleme noktası boş zemin")
	var cam_pan: Vector3 = _camera.global_position
	await _drag(empty, empty + Vector2(90.0, 30.0), 8)
	await frames(6)
	check(not _camera.global_position.is_equal_approx(cam_pan), "kamera kaydı")
	check(_editor.selected() == selected_before, "pan seçimi bozmadı")
	check(_same_layout(layout_before), "pan hiçbir eşyayı oynatmadı")
	await _drag(empty + Vector2(90.0, 30.0), empty, 8)   # kadraj geri: sonraki adımlar aynı görünümde
	await frames(6)

	if _touch:
		await _pinch_during_drag(chair1)
		await _palette_swipe()
	else:
		await _keyboard_and_wheel(chair2)

	print("== 14) BİTİR → kayıt ==")
	var expected: Array = []
	for inst: Dictionary in _decor.instances():
		expected.append({"iid": inst["iid"], "item": String(inst["item"]),
			"x": (inst["pos"] as Vector3).x, "z": (inst["pos"] as Vector3).z,
			"yaw": (inst["rot"] as Vector3).y})
	await _shot("04_son_duzen")
	await _tap(_button_center(_screen.get("_done_button")))
	await frames(20)
	check(_router.top() == &"" and not _editor.active, "BİTİR normal oyuna döndürdü")
	check(get_root().physics_object_picking, "dünya tıklaması geri açıldı")
	check(is_equal_approx((_camera as WorldCamera).min_zoom, min_zoom_before),
		"kameranın normal yakınlaşma sınırı geri geldi (%.2f)" % (_camera as WorldCamera).min_zoom)
	var disk: Dictionary = save.peek()
	check(int(disk.get("version", 0)) == SaveManager.SAVE_VERSION, "kayıt güncel sürümde (v%d)" % int(disk.get("version", 0)))
	check(((disk.get("decor", {}) as Dictionary).get("instances", []) as Array).size() == expected.size(),
		"kayıtta %d örnek" % expected.size())
	var f: FileAccess = FileAccess.open(EXPECT_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(expected))
	f.close()
	await _shot("05_normal_mod")

	if not _touch:
		print("== 15) ESC de düzenlemeden çıkar (router) ==")
		await _tap(edit_button.get_global_rect().get_center())
		await frames(30)
		check(_editor.active and not get_root().physics_object_picking, "yeniden açıldı")
		await _key(KEY_ESCAPE)
		await frames(20)
		check(_router.top() == &"" and not _editor.active, "ESC normal oyuna döndürdü")
		check(get_root().physics_object_picking, "ESC sonrası dünya tıklaması açık")
		check(_decor.instance_count() == expected.size(), "ESC düzeni bozmadı (%d örnek)" % _decor.instance_count())


# --- Aşama 2: yeni süreçte doğrula ----------------------------------------------------------

func _verify() -> void:
	print("== YENİDEN AÇILIŞ: düzen birebir korunmuş mu ==")
	var f: FileAccess = FileAccess.open(EXPECT_PATH, FileAccess.READ)
	check(f != null, "beklenen düzen dosyası var")
	if f == null:
		return
	var expected: Array = JSON.parse_string(f.get_as_text())
	f.close()
	var actual: Array[Dictionary] = _decor.instances()
	check(actual.size() == expected.size(), "örnek sayısı aynı (%d)" % actual.size())
	var seen: Dictionary = {}
	for inst: Dictionary in actual:
		check(not seen.has(inst["iid"]), "%s yinelenmemiş" % inst["iid"])
		seen[inst["iid"]] = true
	for e: Dictionary in expected:
		var inst: Dictionary = _decor.instance(String(e["iid"]))
		var ok: bool = not inst.is_empty() and String(inst["item"]) == String(e["item"]) \
			and absf((inst["pos"] as Vector3).x - float(e["x"])) < 0.0002 \
			and absf((inst["pos"] as Vector3).z - float(e["z"])) < 0.0002 \
			and absf(float((inst["rot"] as Vector3).y) - float(e["yaw"])) < 0.01
		check(ok, "%s %s konum (%.3f, %.3f) yön %.0f korunmuş" % [e["iid"], e["item"], e["x"], e["z"], e["yaw"]])
		var body: Node3D = _view.body_of(String(e["iid"]))
		check(body != null and absf(body.global_position.x - float(e["x"])) < 0.001,
			"%s dünyada kurulu" % e["iid"])
	await frames(10)
	await _shot("06_yeniden_acilis")


# --- Mobil / PC'ye özel adımlar ------------------------------------------------------------

## Eşya tek parmakla sürüklenirken ikinci parmak iner ve iki parmak açılır (pinch):
## tek parmak evresinde kamera kıpırdamaz; ikinci parmakla sürükleme biter, kamera yakınlaşır,
## eşya kameraya takılıp kaymaz; parmaklardan biri kalkınca kalan parmak eşyayı yeniden kapmaz.
func _pinch_during_drag(iid: String) -> void:
	print("== 13c) MOBİL: eşya sürüklenirken ikinci parmak → pinch ==")
	var body: Node3D = _view.body_of(iid)
	var start_world: Vector3 = body.global_position
	var from: Vector2 = _world_to_screen(start_world + Vector3(0.0, 0.03, 0.0))
	var cam_start: Vector3 = _camera.global_position
	var size_start: float = _camera.size
	await _finger(0, from, true)
	await frames(2)
	var at: Vector2 = from
	for i: int in 6:
		at += Vector2(-7.0, -3.0)   # garajın içine doğru (alttaki denetim çubuğundan uzağa)
		await _finger_move(0, at, Vector2(-7.0, -3.0))
		await frames(1)
	check(bool(_editor.get("_dragging")), "tek parmak eşyayı sürüklüyor")
	check(not _view.body_of(iid).global_position.is_equal_approx(start_world), "eşya parmağı izliyor")
	check(_camera.global_position.is_equal_approx(cam_start), "eşya sürüklenirken kamera KIPIRDAMADI")
	var second: Vector2 = at + Vector2(170.0, -40.0)
	await _finger(1, second, true)
	await frames(2)
	check(not bool(_editor.get("_dragging")) and not bool(_editor.get("_pressing")),
		"ikinci parmak sürüklemeyi bitirdi")
	var settled: Vector3 = _pos_of(iid)
	var body_settled: Vector3 = _view.body_of(iid).global_position
	for i: int in 8:
		second += Vector2(14.0, -4.0)
		await _finger_move(1, second, Vector2(14.0, -4.0))
		await frames(1)
	await frames(20)
	check(_camera.size < size_start - 0.05, "iki parmak açılınca kamera yakınlaştı (%.2f → %.2f)" % [size_start, _camera.size])
	check(_pos_of(iid).is_equal_approx(settled), "pinch sırasında eşya kaydedilen yerinde")
	check(_view.body_of(iid).global_position.is_equal_approx(body_settled), "eşya kameraya takılıp kaymadı")
	await _finger(1, second, false)
	await frames(2)
	for i: int in 4:
		at += Vector2(10.0, 0.0)
		await _finger_move(0, at, Vector2(10.0, 0.0))
		await frames(1)
	await _finger(0, at, false)
	await frames(4)
	check(_pos_of(iid).is_equal_approx(settled), "kalan parmak eşyayı yeniden KAPMADI")
	var moved: bool = Vector2(settled.x, settled.z).distance_to(Vector2(start_world.x, start_world.z)) > 0.001
	print("   eşya %s: %s" % ["yeni yerinde kaydedildi" if moved else "eski yerinde", settled])


## Palet parmakla kaydırılır: kart basılmaz (satın alma sorulmaz, hayalet çıkmaz), kamera kıpırdamaz.
func _palette_swipe() -> void:
	print("== 13d) MOBİL: palet parmakla kaydırılır ==")
	await _open_tab(GarageDecor.Kind.YARD)   # en kalabalık sekme
	var scroll: ScrollContainer = _screen.get("_scroll")
	scroll.scroll_horizontal = 0
	await frames(4)
	var economy: EconomyManager = get_first_node_in_group("economy")
	var money_before: int = economy.money
	var owned_before: int = _decor.owned_total()
	var cam_before: Vector3 = _camera.global_position
	var card: PlateButton = (_screen.get("_cards") as Dictionary).values()[2]
	var from: Vector2 = _button_center(card)
	await _drag(from, from + Vector2(-330.0, 0.0), 12)
	await frames(60)
	check(scroll.scroll_horizontal > 150, "palet parmakla kaydı (%d birim)" % scroll.scroll_horizontal)
	check(not _editor.is_placing() and _screen.get("_confirm_buy") == &"",
		"kaydırırken kart basılmadı (hayalet yok, satın alma sorulmadı)")
	check(economy.money == money_before and _decor.owned_total() == owned_before, "para / depo değişmedi")
	check(_camera.global_position.is_equal_approx(cam_before), "palet kaydırılırken kamera KIPIRDAMADI")
	await _shot("07_palet_kaydi")
	# Kaydırma durunca kısa dokunuş kartı yine basar (satın alma onayı sorulur)
	var visible_card: PlateButton = null
	var strip_rect: Rect2 = scroll.get_global_rect()
	for c: PlateButton in (_screen.get("_cards") as Dictionary).values():
		if strip_rect.encloses(c.get_global_rect()) and not c.disabled:
			visible_card = c
			break
	if visible_card:
		await _tap(_button_center(visible_card))
		await frames(4)
		check(_screen.get("_confirm_buy") != &"" or _editor.is_placing(), "kaydırmadan sonra kısa dokunuş kartı bastı")
		_screen.set("_confirm_buy", &"")
		if _editor.is_placing():
			_editor.cancel_ghost()


## PC: R / Shift+R döndürür, Delete depoya kaldırır, Ctrl+Z geri alır, tekerlek yakınlaştırır.
func _keyboard_and_wheel(iid: String) -> void:
	print("== 13e) PC: R / Shift+R / Delete / Ctrl+Z / tekerlek ==")
	await _tap(_world_to_screen(_view.body_of(iid).global_position + Vector3(0.0, 0.03, 0.0)))
	await frames(3)
	check(_editor.selected() == iid, "tıklanan eşya seçildi (%s)" % _editor.selected())
	var yaw0: float = float((_decor.instance(iid)["rot"] as Vector3).y)
	var pos0: Vector3 = _decor.instance(iid)["pos"]
	await _key(KEY_R)
	var yaw1: float = float((_decor.instance(iid)["rot"] as Vector3).y)
	check(is_equal_approx(yaw1, fposmod(yaw0 - 45.0, 360.0)), "R: sağa 45° (%.0f → %.0f)" % [yaw0, yaw1])
	await _key(KEY_R, true)
	check(is_equal_approx(float((_decor.instance(iid)["rot"] as Vector3).y), yaw0), "Shift+R: geri döndü")
	var placed: int = _decor.instance_count()
	await _key(KEY_DELETE)
	check(_decor.instance_count() == placed - 1 and _decor.instance(iid).is_empty(), "Delete: depoya kaldırıldı")
	await _key(KEY_Z, false, true)
	var back: Dictionary = _decor.instance(iid)
	check(not back.is_empty() and (back["pos"] as Vector3).is_equal_approx(pos0), "Ctrl+Z: aynı kimlik, aynı yer")
	var size0: float = _camera.size
	var empty: Vector2 = get_root().get_visible_rect().size * Vector2(0.12, 0.35)
	await _wheel(empty, true)
	await _wheel(empty, true)
	await frames(30)
	check(_camera.size < size0 - 0.05, "tekerlek yakınlaştırdı (%.2f → %.2f)" % [size0, _camera.size])


func _pos_of(iid: String) -> Vector3:
	var inst: Dictionary = _decor.instance(iid)
	return inst["pos"] if not inst.is_empty() else Vector3.INF


func _same_layout(before: Array[Dictionary]) -> bool:
	var now: Array[Dictionary] = _decor.instances()
	if now.size() != before.size():
		return false
	for i: int in now.size():
		if now[i]["iid"] != before[i]["iid"] or not (now[i]["pos"] as Vector3).is_equal_approx(before[i]["pos"]) \
				or not (now[i]["rot"] as Vector3).is_equal_approx(before[i]["rot"]):
			return false
	return true


# --- Girdi yardımcıları -----------------------------------------------------------------

## Çoklu dokunuş: belirli parmak (index) iner / kalkar. 0. parmak fare olayı da üretir (emülasyon).
func _finger(index: int, at: Vector2, down: bool) -> void:
	var t: InputEventScreenTouch = InputEventScreenTouch.new()
	t.index = index
	t.pressed = down
	t.position = at * _k
	Input.parse_input_event(t)
	await frames(1)


func _finger_move(index: int, at: Vector2, rel: Vector2) -> void:
	var d: InputEventScreenDrag = InputEventScreenDrag.new()
	d.index = index
	d.position = at * _k
	d.relative = rel * _k
	Input.parse_input_event(d)
	await frames(1)


func _key(code: Key, shift: bool = false, ctrl: bool = false) -> void:
	for down: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = down
		e.shift_pressed = shift
		e.ctrl_pressed = ctrl
		Input.parse_input_event(e)
		await frames(2)
	await frames(2)


func _wheel(at: Vector2, up: bool) -> void:
	for down: bool in [true, false]:
		var e: InputEventMouseButton = InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = down
		e.factor = 1.0
		e.position = at * _k
		e.global_position = at * _k
		Input.parse_input_event(e)
		await frames(1)

func _world_to_screen(p: Vector3) -> Vector2:
	return _camera.unproject_position(p)


func _button_center(b: Control) -> Vector2:
	return b.get_global_rect().get_center()


func _ghost_center() -> Vector2:
	var ghost: Node3D = _view.get_node_or_null("DecorGhost")
	var box: AABB = GarageDecorView._tree_box(ghost)
	return _world_to_screen(box.get_center())


func _open_tab(kind: int) -> void:
	var tabs: Dictionary = _screen.get("_tab_buttons")
	var tab: PlateButton = tabs[kind]
	if not tab.button_pressed:
		await _tap(_button_center(tab))
		await frames(6)


func _tap_card(id: StringName) -> void:
	var cards: Dictionary = _screen.get("_cards")
	var card: PlateButton = cards[id]
	var scroll: ScrollContainer = _screen.get("_scroll")
	scroll.ensure_control_visible(card)
	await frames(3)
	await _tap(_button_center(card))
	await frames(6)


func _tap(at: Vector2) -> void:
	await _pointer(at, true)
	await frames(2)
	await _pointer(at, false)
	await frames(3)


func _drag(from: Vector2, to: Vector2, steps: int) -> void:
	await _move_to(from)
	await _pointer(from, true)
	await frames(2)
	for i: int in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		await _motion(p, (to - from) / float(steps))
		await frames(1)
	await _pointer(to, false)
	await frames(3)


func _move_to(at: Vector2) -> void:
	if _touch:
		return
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at * _k
	m.global_position = at * _k
	Input.parse_input_event(m)
	await frames(1)


func _pointer(at: Vector2, down: bool) -> void:
	if _touch:
		var t: InputEventScreenTouch = InputEventScreenTouch.new()
		t.index = 0
		t.pressed = down
		t.position = at * _k
		Input.parse_input_event(t)
		return
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.position = at * _k
	e.global_position = at * _k
	Input.parse_input_event(e)


func _motion(at: Vector2, rel: Vector2) -> void:
	if _touch:
		var d: InputEventScreenDrag = InputEventScreenDrag.new()
		d.index = 0
		d.position = at * _k
		d.relative = rel * _k
		Input.parse_input_event(d)
		return
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = at * _k
	m.global_position = at * _k
	m.relative = rel * _k
	m.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(m)


func _shot(name: String) -> void:
	await frames(3)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + ("dokun_" if _touch else "") + name + ".png")
