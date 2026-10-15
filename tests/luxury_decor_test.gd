extends SceneTree
## LÜKS DEKOR — elmasla satılan eşyalar: katalog (≥ 20 eşya, model, elmas fiyatı, garaj değeri), satın alma
## (elmas düşer, ₺ değişmez, kopya depoya girer, garaj değeri artar), yetmeyen elmasta hiçbir şey değişmez,
## kayıt / yükleme, düzenleme paletinde LÜKS sekmesi ve fiyat yazısı, garajdaki ışıltılar.
## Gerçek düğümlerle koşar (Main.tscn). Görsel QA: qa/luks_dekor_qa.gd.
##   tools/run_tests.sh luxury_decor_test

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var economy: EconomyManager
var player: PlayerProgress


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
	economy = get_first_node_in_group("economy")
	player = get_first_node_in_group("player_progress")
	_catalog()
	await _first_open()
	_purchase()
	_save_load()
	await _palette()
	await _sparkles()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _luxury() -> Array[Dictionary]:
	return GarageDecor.items_in(GarageDecor.Kind.LUXURY)


func _catalog() -> void:
	print("== 1) KATALOG ==")
	var items: Array[Dictionary] = _luxury()
	check(items.size() >= 20, "en az 20 lüks eşya (%d)" % items.size())
	var floor_count: int = 0
	var wall_count: int = 0
	var bad: Array[StringName] = []
	for item: Dictionary in items:
		var id: StringName = item["id"]
		if GarageDecor.placement(id) == GarageDecor.PLACE_FLOOR:
			floor_count += 1
		elif GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			wall_count += 1
		if not DecorBuilder.has_model(id) or GarageDecor.gem_price(id) <= 0 or int(item["price"]) != 0 \
				or int(item["value"]) <= 0 or not GarageDecor.is_placeable(id):
			bad.append(id)
	check(bad.is_empty(), "her lüks eşyanın modeli, elmas fiyatı, garaj değeri var; ₺ fiyatı yok %s" % [bad])
	check(floor_count >= 10 and wall_count >= 4, "hem yere konan hem duvara asılan (%d / %d)" % [floor_count, wall_count])
	check(GarageDecor.categories().has(GarageDecor.Kind.LUXURY), "LÜKS palette kategori")
	var order: Array[Dictionary] = GarageDecor.shop_order(GarageDecor.Kind.LUXURY)
	var sorted: bool = true
	for k: int in range(1, order.size()):
		if int(order[k]["price_gems"]) < int(order[k - 1]["price_gems"]):
			sorted = false
	check(sorted, "LÜKS kartları elmas fiyatına göre sıralı (%d → %d GEM)" % [
		int(order[0]["price_gems"]), int(order.back()["price_gems"])])
	check(not GarageDecor.is_gem_item(&"leather_sofa") and GarageDecor.gem_price(&"leather_sofa") == 0,
		"₺ eşyalar elmaslı sayılmaz")


## Depoda lüks eşya yokken düzenleyici elmas vitriniyle açılmaz (yeni oyuncu ₺ eşyalarla başlar).
func _first_open() -> void:
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"garage_edit")
	await frames(20)
	check(hud.garage_edit_screen.get("_kind") != GarageDecor.Kind.LUXURY, "düzenleyici kendiliğinden LÜKS'te açılmaz")
	hud.router.close_all()
	await frames(6)


func _purchase() -> void:
	print("== 2) SATIN ALMA ==")
	var id: StringName = &"lux_marble_fountain"
	var gems: int = GarageDecor.gem_price(id)
	economy.set_money(1000)
	player.load_state(5, 0, gems - 1)
	var owned: int = decor.owned_of(id)
	var value: int = GarageValue.compute(self)
	check(not decor.can_purchase(id), "elmas yetmiyor: satın alınamaz")
	check(not decor.purchase(id) and decor.owned_of(id) == owned and player.gems == gems - 1,
		"başarısız alım hiçbir şeyi değiştirmez")
	player.load_state(5, 0, gems + 25)
	check(decor.can_purchase(id), "elmas yetiyor (₺ yalnızca 1.000)")
	check(decor.purchase(id), "satın alındı")
	check(player.gems == 25, "elmas düştü (%d kaldı)" % player.gems)
	check(economy.money == 1000, "₺ değişmedi (%d)" % economy.money)
	check(decor.owned_of(id) == owned + 1 and decor.available_of(id) == owned + 1, "kopya depoya girdi")
	check(GarageValue.compute(self) == value + int(GarageDecor.get_item(id)["value"]),
		"garaj değeri eşyanın değeri kadar arttı (+%d)" % int(GarageDecor.get_item(id)["value"]))
	# ₺ eşya hâlâ ₺ ile alınır, elmasa dokunmaz
	economy.set_money(1_000_000)
	var before_gems: int = player.gems
	check(decor.purchase(&"round_table") and player.gems == before_gems and economy.money < 1_000_000,
		"₺ eşya parayla alınır, elmas değişmez")


func _save_load() -> void:
	print("== 3) KAYIT ==")
	var state: Dictionary = decor.state()
	var copy: DecorManager = DecorManager.new()
	root.add_child(copy)
	copy.load_state(JSON.parse_string(JSON.stringify(state)))
	check(copy.owned_of(&"lux_marble_fountain") == decor.owned_of(&"lux_marble_fountain"), "lüks eşya kayıttan geri gelir")
	copy.queue_free()


func _palette() -> void:
	print("== 4) DÜZENLEME PALETİ ==")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"garage_edit")
	await frames(20)
	var es: GarageEditScreen = hud.garage_edit_screen
	var tabs: Dictionary = es.get("_tab_buttons")
	check(tabs.has(GarageDecor.Kind.LUXURY), "LÜKS sekmesi var")
	es._on_tab_pressed(GarageDecor.Kind.LUXURY)
	await frames(6)
	var cards: Dictionary = es.get("_cards")
	var card: PlateButton = cards.get(&"lux_helicopter") as PlateButton
	check(card != null and card.text.contains("%d GEM" % GarageDecor.gem_price(&"lux_helicopter")),
		"kartta elmas fiyatı (%s)" % (card.text.replace("\n", " / ") if card else "kart yok"))
	player.load_state(5, 0, 10)
	es.call("_on_card_pressed", &"lux_helicopter")
	await frames(4)
	check(hud.router.top() == &"gem_store", "elmas yetmeyince GEM MAĞAZASI açılır (%s)" % hud.router.top())
	hud.router.back()
	await frames(4)
	check(hud.router.top() == &"garage_edit", "mağaza kapanınca düzenlemeye dönülür")
	player.load_state(5, 0, 5000)
	es.set("_confirm_buy", &"")
	var owned: int = decor.owned_of(&"lux_bonsai")
	es.call("_on_card_pressed", &"lux_bonsai")
	check(decor.owned_of(&"lux_bonsai") == owned, "ilk dokunuş satın almaz (onay)")
	es.call("_on_card_pressed", &"lux_bonsai")
	check(decor.owned_of(&"lux_bonsai") == owned + 1 and player.gems == 5000 - GarageDecor.gem_price(&"lux_bonsai"),
		"ikinci dokunuş elmasla alır")
	hud.router.close_all()
	await frames(6)


func _sparkles() -> void:
	print("== 5) IŞILTI ==")
	for inst: Dictionary in decor.instances().duplicate():
		decor.remove_instance(inst["iid"])
	view.refresh()
	var sparkles: LuxurySparkles = view.find_child("LuxurySparkles", true, false) as LuxurySparkles
	check(sparkles != null and sparkles.multimesh.instance_count == 0, "lüks eşya yokken ışıltı yok")
	var placed: bool = false
	for j: int in range(1, 20):
		for i: int in range(1, 30):
			var p: Vector2 = DecorGrid.CORNER - Vector2(float(i), float(j)) * DecorGrid.CELL
			if not placed and view.is_valid(&"lux_bonsai", Vector3(p.x, 0, p.y), 0.0):
				decor.add_instance(&"lux_bonsai", Vector3(p.x, 0, p.y), 0.0)
				placed = true
	view.refresh()
	check(placed and sparkles.multimesh.instance_count >= LuxurySparkles.PER_ITEM,
		"lüks eşyanın üstünde ışıltı (%d yıldız, tek MultiMesh)" % sparkles.multimesh.instance_count)
	view.set_editing(true)
	check(sparkles.multimesh.instance_count == 0, "düzenlerken ışıltı gizli")
	view.set_editing(false)
	check(sparkles.multimesh.instance_count >= LuxurySparkles.PER_ITEM, "düzenleme bitince geri gelir")
