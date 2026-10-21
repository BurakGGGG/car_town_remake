extends SceneTree
## SEVİYE ATLADIN — LevelUnlocks (seviyede açılanlar sistemlerin kendi kilitlerinden: müşteri işi, depo, kasa, modifiye
## kademesi, görevler, dekor; aralık birleştirme, sıradaki açılış) ve LevelUpScreen (oyun sakinken açılır, pano açıkken
## bekler, atlanan seviyeler tek ekranda birleşir, ödül toplamı, AÇILANLAR / SIRADAKİ kartları, DEVAM ile kapanır,
## eski küçük seviye bildirimi yok). Gerçek düğümlerle koşar (Main.tscn).
##   tools/run_tests.sh level_up_test

var fails: int = 0
var hud: Hud
var player: PlayerProgress
var economy: EconomyManager
var screen: LevelUpScreen


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(value: float) -> void:
	await create_timer(value).timeout


func _initialize() -> void:
	_unlocks()
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	player = get_first_node_in_group("player_progress")
	economy = get_first_node_in_group("economy")
	hud.router.close_all()
	await _screen()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _kinds(entries: Array[Dictionary]) -> Dictionary:
	var out: Dictionary = {}
	for entry: Dictionary in entries:
		out[int(entry["kind"])] = entry
	return out


func _unlocks() -> void:
	print("== 1) Seviyede açılanlar (LevelUnlocks) ==")
	var at2: Dictionary = _kinds(LevelUnlocks.between(1, 2))
	check(at2.size() == 1 and at2.has(LevelUnlocks.Kind.DECOR), "seviye 2: yalnız dekor (ilk seviye atlamasında da kart var)")
	var empty: Array[int] = []
	for level: int in range(2, 31):
		if LevelUnlocks.between(level - 1, level).is_empty():
			empty.append(level)
	check(empty.is_empty(), "2–30 arasında açılanı olmayan seviye yok %s" % [empty])
	var at5: Dictionary = _kinds(LevelUnlocks.between(4, 5))
	check(at5.has(LevelUnlocks.Kind.FRAME) and StringName(at5[LevelUnlocks.Kind.FRAME]["id"]) == &"bronze",
		"seviye 5: BRONZ çerçeve (elmaslı çerçeveler seviyeyle açılmaz)")
	var at3: Dictionary = _kinds(LevelUnlocks.between(2, 3))
	check(at3.has(LevelUnlocks.Kind.MISSIONS) and at3.has(LevelUnlocks.Kind.MOD_TIER) and at3.size() == 2,
		"seviye 3: görevler + modifiye 1. kademe")
	var at10: Dictionary = _kinds(LevelUnlocks.between(9, 10))
	check(at10.has(LevelUnlocks.Kind.CRATE) and StringName(at10[LevelUnlocks.Kind.CRATE]["id"]) == &"family_crate",
		"seviye 10: AİLE KASASI")
	var at12: Dictionary = _kinds(LevelUnlocks.between(11, 12))
	check(at12.has(LevelUnlocks.Kind.CUSTOMER) and StringName(at12[LevelUnlocks.Kind.CUSTOMER]["id"]) == &"brake_overhaul",
		"seviye 12: FREN REVİZYONU müşterisi")
	check(at12.has(LevelUnlocks.Kind.DEPOT) and StringName(at12[LevelUnlocks.Kind.DEPOT]["id"]) == CarGarageCatalog.NEON,
		"seviye 12: YERALTI DEPOSU")
	var decor12: Array[StringName] = []
	if at12.has(LevelUnlocks.Kind.DECOR):
		decor12 = at12[LevelUnlocks.Kind.DECOR]["items"]
	var all_twelve: bool = not decor12.is_empty()
	var by_price: bool = true
	for i: int in decor12.size():
		all_twelve = all_twelve and GarageDecor.required_level(decor12[i]) == 12
		if i > 0:
			by_price = by_price and int(GarageDecor.get_item(decor12[i - 1])["price"]) >= int(GarageDecor.get_item(decor12[i])["price"])
	check(all_twelve, "seviye 12: dekorun hepsi o seviyenin eşyası (%d)" % decor12.size())
	check(by_price, "dekor pahalıdan ucuza (küçük resimde en gösterişliler)")
	var at4: Array[StringName] = _kinds(LevelUnlocks.between(3, 4))[LevelUnlocks.Kind.DECOR]["items"]
	var placed_first: bool = true
	for i: int in range(1, at4.size()):
		placed_first = placed_first and (GarageDecor.is_placeable(at4[i - 1]) or not GarageDecor.is_placeable(at4[i]))
	check(placed_first, "küçük resmi olan (garaja konan) eşyalar kaplamalardan önce")

	# Aralık: atlanan seviyelerin hepsi tek listede, dekor tek kayıtta
	var jump: Array[Dictionary] = LevelUnlocks.between(11, 14)
	var crates: int = 0
	var decor_cards: int = 0
	for entry: Dictionary in jump:
		if int(entry["kind"]) == LevelUnlocks.Kind.CRATE:
			crates += 1
		if int(entry["kind"]) == LevelUnlocks.Kind.DECOR:
			decor_cards += 1
	check(crates == 1 and decor_cards == 1, "11 → 14: SPOR KASASI + tek dekor kartı")

	# Kapsam: kataloglardaki her seviye kilidi (seviye > 1) listede tam bir kez
	var expected: int = 0
	for type: RepairType in RepairType.defaults():
		expected += 1 if type.min_level > 1 else 0
	for garage: StringName in CarGarageCatalog.ids():
		expected += 1 if CarGarageCatalog.required_level(garage) > 1 else 0
	for crate: Dictionary in CrateCatalog.all():
		expected += 1 if int(crate["min_level"]) > 1 else 0
	for stage: int in range(1, PerformanceMods.STAGES + 1):
		expected += 1 if PerformanceMods.required_level(stage) > 1 else 0
	expected += 1 if MissionCatalog.MIN_LEVEL > 1 else 0
	for frame: Dictionary in ProfileCatalog.FRAMES:
		expected += 1 if int(frame["gems"]) == 0 and int(frame["level"]) > 1 else 0
	var decor_expected: int = 0
	for item: Dictionary in GarageDecor.all():
		decor_expected += 1 if int(item["min_level"]) > 1 else 0
	var found: int = 0
	var decor_found: int = 0
	for level: int in range(2, LevelUnlocks.MAX_LEVEL + 1):
		for entry: Dictionary in LevelUnlocks.between(level - 1, level):
			if int(entry["kind"]) == LevelUnlocks.Kind.DECOR:
				decor_found += (entry["items"] as Array).size()
			else:
				found += 1
	check(found == expected, "her müşteri / depo / kasa / kademe / görev / çerçeve kilidi bir kez (%d / %d)" % [found, expected])
	check(decor_found == decor_expected, "her dekor eşyası bir kez (%d / %d)" % [decor_found, decor_expected])

	var next: Dictionary = LevelUnlocks.next_after(2)
	check(int(next.get("level", 0)) == 3 and (next["unlocks"] as Array).size() == 2, "2'den sonra ilk açılış seviye 3 (görevler + kademe)")
	check(LevelUnlocks.next_after(LevelUnlocks.MAX_LEVEL).is_empty(), "en üst seviyeden sonra açılış yok")


func _screen() -> void:
	print("== 2) SEVİYE ATLADIN ekranı ==")
	screen = hud.level_up_screen
	check(screen != null and not screen.visible, "HUD'da kurulu, kapalı")
	var money: int = economy.money
	var need: int = player.xp_to_next() - player.xp + int(round(player.xp_base * PlayerProgress.XP_GROWTH))   # 1 → 3
	player.add_xp(need)
	check(player.level == 3, "XP ile 1 → 3 (iki seviye birden)")
	check(economy.money == money + 500 + 750, "seviye ödülleri ödendi (+1.250 ₺)")
	check(not screen.visible and screen.is_pending(), "hemen açılmaz: oyun sakinleşince")
	check(not (hud.get("_notice_label") as Label).text.contains("SEVİYE"), "eski küçük seviye bildirimi yok")
	await seconds(1.6)
	check(screen.visible, "sakin anda açıldı")
	var badge: Control = screen.get("_badge")
	check((badge.get("_number") as Label).text == "3", "rozet: 3 (atlanan seviyeler tek ekranda)")
	check((screen.get("_money_label") as Label).text == "+1.250 ₺", "para toplamı: %s" % (screen.get("_money_label") as Label).text)
	check((screen.get("_gem_label") as Label).text == "+%d GEM" % (PlayerProgress.LEVEL_GEMS * 2), "gem toplamı: %s" % (screen.get("_gem_label") as Label).text)
	check((screen.get("_divider_label") as Label).text == "AÇILANLAR", "başlık AÇILANLAR")
	var cards: HBoxContainer = screen.get("_cards")
	check(cards.get_child_count() == 3, "3 kart: dekor (sv2) + görevler + modifiye (%d)" % cards.get_child_count())
	(screen.get("_continue") as PlateButton).pressed.emit()
	await seconds(0.4)
	check(not screen.visible and not screen.is_pending(), "DEVAM ile kapandı")

	print("== 3) Açılan yoksa SIRADAKİ, pano açıkken bekler ==")
	hud.router.open(&"profile")
	await frames(5)
	screen.add_level(4, 1000)   # 4: dekor, 5: müşteri + depo + kademe → tek ekranda 3 → 5
	screen.add_level(5, 1500)
	await seconds(1.6)
	check(not screen.visible, "pano açıkken açılmaz (%s)" % hud.router.top())
	hud.router.close_all()
	await seconds(1.6)
	check(screen.visible, "pano kapanınca açıldı")
	check((badge.get("_number") as Label).text == "5", "rozet 5")
	check(cards.get_child_count() == 5, "3 → 5 aralığı: BOYA İŞİ + SANAYİ DEPOSU + 2. kademe + BRONZ + dekor (%d kart)" % cards.get_child_count())
	screen.close()
	await seconds(0.4)

	screen.add_level(31, 7750)   # 30'dan sonra açılan yok, sıradaki de yok
	await seconds(1.6)
	check(screen.visible and cards.get_child_count() == 0 and not (screen.get("_divider") as Control).visible,
		"30 sonrası: yalnız rozet + ödül, kart yok")
	screen.close()
	await seconds(0.4)
	check(not screen.visible, "kapandı")
