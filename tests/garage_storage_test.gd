extends SceneTree
## GARAJI DÜZENLE → DEPO (2026-10-26, kullanıcı: "satın aldığım dekorasyonu bazen kaybediyorum, depo butonu da olsun"):
## depodaki bütün eşyalar tek şeritte, plakada kopya rozeti, karttan yerleştirme, son kopya konunca kart kalkar,
## DEPOYA KALDIR'la geri gelir; paletten kalkmış eşya da listelenir; seviyesi gelmemiş hediye kopyası konabilir.
## Çalıştırma: tools/run_tests.sh garage_storage_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false)
	var decor: DecorManager = get_first_node_in_group("decor")
	var editor: GarageEditor = get_first_node_in_group("garage_editor")
	var player: PlayerProgress = get_first_node_in_group("player_progress")
	decor.reset()
	# Deneme eşyaları: seviyesi açık küçük bir zemin eşyası ve seviyesi gelmemiş bir eşya (hediye gibi verilir)
	var low: StringName = &""
	var high: StringName = &""
	for kind: int in GarageDecor.categories():
		for item: Dictionary in GarageDecor.shop_order(kind):
			var id: StringName = item["id"]
			if not GarageDecor.is_placeable(id) or GarageDecor.is_exclusive(id) or GarageDecor.is_gem_item(id):
				continue
			if low == &"" and GarageDecor.placement(id) == GarageDecor.PLACE_FLOOR and GarageDecor.required_level(id) <= player.level:
				low = id
			if high == &"" and GarageDecor.required_level(id) > player.level:
				high = id
	check(low != &"" and high != &"", "deneme eşyaları bulundu (%s, %s)" % [low, high])
	decor.grant(low, 1)
	decor.grant(high, 2)
	var retired: int = 1 if GarageDecor.exists(&"car_lift") and decor.grant(&"car_lift", 1) else 0

	print("== DEPO PLAKASI ==")
	hud.router.open(&"garage_edit")
	await frames(4)
	var edit: GarageEditScreen = hud.garage_edit_screen
	var depo: PlateButton = (edit.get("_mode_buttons") as Dictionary).get(&"storage")
	check(depo != null and depo.is_visible_in_tree() and (depo.find_child("Caption", true, false) as Label).text == Loc.t("DEPO"),
		"alt menüde DEPO plakası")
	var art: TextureRect = depo.find_child("Content", false, false).get_child(0) as TextureRect if depo else null
	check(art != null and art.texture != null, "DEPO plakasında çizim var")
	check(depo != null and depo.badge == 3 + retired, "rozet depodaki kopya sayısı (%d)" % (depo.badge if depo else -1))
	depo.pressed.emit()
	await frames(2)
	check(int(edit.get("_kind")) == GarageEditScreen.STORAGE_KIND and depo.highlight, "DEPO açık, plaka vurgulu")
	var cards: Dictionary = edit.get("_cards")
	check(cards.has(low) and cards.has(high), "depodaki eşyalar şeritte")
	check(retired == 0 or cards.has(&"car_lift"), "paletten kalkmış eşya (araç lifti) da depoda görünür")
	check(cards.size() == 2 + retired, "şeritte yalnız depodaki eşyalar (%d kart)" % cards.size())
	check(cards.has(high) and not (cards[high] as PlateButton).disabled, "seviyesi gelmemiş hediye kopyası basılabilir")

	print("== YERLEŞTİR / DEPOYA KALDIR ==")
	(cards[low] as PlateButton).pressed.emit()
	await frames(2)
	check(editor.is_placing() and editor.placing_item() == low, "karta dokununca yerleştirme başlar")
	var placed: bool = editor.confirm_ghost()
	await frames(2)
	cards = edit.get("_cards")
	check(placed and decor.placed_of(low) == 1, "eşya garaja kondu")
	check(not cards.has(low), "son kopya konunca kart şeritten kalktı")
	check(depo.badge == 2 + retired, "rozet azaldı")
	check(editor.delete_selected(), "DEPOYA KALDIR")
	await frames(2)
	cards = edit.get("_cards")
	check(cards.has(low) and decor.available_of(low) == 1 and depo.badge == 3 + retired, "kaldırılan eşyanın kartı geri geldi")
	(cards[high] as PlateButton).pressed.emit()
	await frames(2)
	check(editor.is_placing() and editor.placing_item() == high, "kilitli hediye de yerleştirilmeye başlar")
	editor.cancel_ghost()

	print("== YERLEŞTİRİLEN EŞYA ORTALANIR ==")
	# Kullanıcı 2026-10-26: "bastığım eşyayı ortalasın, bazen gözden kayboluyor". Kamera yakın ve garajdan uzakta.
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	camera.zoom_by(-5.0)
	await create_timer(0.6).timeout
	camera.pan_by_pixels(Vector2(-500.0, -400.0))
	await frames(2)
	cards = edit.get("_cards")
	(cards[low] as PlateButton).pressed.emit()
	await create_timer(0.7).timeout
	var screen: Vector2 = root.get_visible_rect().size
	var band: Vector2 = edit.call("_view_band")
	var ghost_at: Vector2 = camera.unproject_position(editor.get("_ghost_pos"))
	var middle: Vector2 = Vector2(screen.x * 0.5, screen.y * (band.x + band.y) * 0.5)
	check(editor.is_placing() and ghost_at.distance_to(middle) < screen.y * 0.08,
		"hayalet görünen alanın ortasında (%s, orta %s)" % [ghost_at.round(), middle.round()])
	editor.cancel_ghost()
	await frames(2)

	print("== KİLİTLİ HEDİYE KENDİ SEKMESİNDE ==")
	edit.call("_select_tab", int(GarageDecor.get_item(high)["kind"]))
	await frames(2)
	cards = edit.get("_cards")
	check(cards.has(high) and not (cards[high] as PlateButton).disabled, "kendi sekmesinde de basılabilir (depoda 2)")

	print("== BOŞ DEPO ==")
	edit.call("_on_mode_pressed", &"storage")
	await frames(1)
	decor.reset()
	await frames(2)
	var strip: HBoxContainer = edit.get("_strip")
	check(strip.find_child("StorageEmpty", false, false) != null and (edit.get("_cards") as Dictionary).is_empty(),
		"boş depoda bilgi kartı")
	check(depo.badge == 0, "boş depoda rozet yok")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
