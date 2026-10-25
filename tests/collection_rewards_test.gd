extends SceneTree
## KOLEKSİYON ÖDÜLLERİ — CollectionRewards (set ödülü nadirliğe göre, kilometre taşları 10 / 20 / 35 / 50 / 72, TAM
## KOLEKSİYON: çerçeve + kupa + unvan), kayıt (ödenen bir daha ödenmez, bölümü olmayan eski kayıtta tamam olanlar ödülsüz),
## SET TAMAMLANDI! ekranı (oyun sakinleşince, ödüller birleşir, sayaçlar TOPLA'ya dek bekler) ve KOLEKSİYON panosu
## (sayaç 72 üzerinden, set satırları, ALINDI). Gerçek düğümlerle koşar (Main.tscn).
##   tools/run_tests.sh collection_rewards_test

var fails: int = 0
var main: Node
var entries: Array[Dictionary] = []


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(value: float) -> void:
	await create_timer(value).timeout


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func reload() -> void:
	if main:
		main.free()
	await frames(4)
	main = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	await seconds(1.0)
	entries.clear()
	(g(&"collection_rewards") as CollectionRewards).rewarded.connect(func(entry: Dictionary) -> void: entries.append(entry))
	var hud: Hud = main.find_child("HUD", true, false) as Hud
	hud.router.close_all()


func hud() -> Hud:
	return main.find_child("HUD", true, false) as Hud


func _initialize() -> void:
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	_rules()
	await reload()
	await _set_reward()
	await _screen()
	await _milestones()
	await _save_and_legacy()
	await _full_collection()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _obtainable() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = StringName(String(entry["id"]))
		if CarCatalog.is_obtainable(id):
			out.append(id)
	return out


func _rules() -> void:
	print("== 1) Kurallar ==")
	var cars: Array[StringName] = _obtainable()
	check(CollectionRewards.total_count() == cars.size(), "toplanabilir araç: %d" % cars.size())
	check(CollectionRewards.final_milestone() == CollectionRewards.total_count(),
		"son kilometre taşı (%d) = bütün koleksiyon (%d): katalog büyürse MILESTONES güncellenmeli"
		% [CollectionRewards.final_milestone(), CollectionRewards.total_count()])
	check(CollectionRewards.milestone_list() == [10, 20, 35, 50, 72], "taşlar 10 / 20 / 35 / 50 / 72")
	var in_sets: Dictionary = {}
	var ids: Dictionary = {}
	var bad: Array[String] = []
	for set_entry: Dictionary in CrateCatalog.sets():
		if ids.has(set_entry["id"]) or (set_entry["cars"] as Array).size() < 2 or String(set_entry["name"]).is_empty():
			bad.append(String(set_entry["id"]))
		ids[set_entry["id"]] = true
		for car: StringName in set_entry["cars"]:
			in_sets[car] = true
			if not CarCatalog.is_obtainable(car):
				bad.append("%s:%s" % [set_entry["id"], car])
	check(bad.is_empty(), "setler: kimlik tekil, en az 2 araç, adlı, hepsi edinilebilir %s" % [bad])
	var missing: Array[StringName] = cars.filter(func(car: StringName) -> bool: return not in_sets.has(car))
	check(missing.is_empty(), "her araç en az bir sette (hurdalık klasikleri dahil) %s" % [missing])
	check(CrateCatalog.sets().size() == 21, "21 set (%d)" % CrateCatalog.sets().size())
	check(CollectionRewards.car_rarity(&"anadol_a1") == CollectionRewards.RESTORATION_RARITY[RestorationCatalog.tier_of(&"anadol_a1")],
		"hurdalık klasiğinin nadirliği kademesinden (%s)" % CollectionRewards.car_rarity(&"anadol_a1"))
	var yerli: Dictionary = CrateCatalog.get_set(&"yerli_klasikler")
	var gems: int = 0
	var money: int = 0
	for car: StringName in yerli["cars"]:
		gems += int(CollectionRewards.SET_GEMS[CollectionRewards.car_rarity(car)])
		money += int(CollectionRewards.SET_MONEY[CollectionRewards.car_rarity(car)])
	var reward: Dictionary = CollectionRewards.set_reward(yerli)
	check(int(reward["gems"]) == gems and int(reward["money"]) == money and gems > 0,
		"set ödülü araç başına nadirliğe göre: YERLİ KLASİKLER +%d GEM +%d ₺" % [gems, money])
	check(CrateCatalog.get_set(&"yok_boyle").is_empty(), "olmayan set boş")


func _set_reward() -> void:
	print("== 2) Set tamamlanınca ödül ==")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var rewards: CollectionRewards = g(&"collection_rewards")
	var economy: EconomyManager = g(&"economy")
	var pp: PlayerProgress = g(&"player_progress")
	check(rewards != null and rewards.state() == {"sets": [], "milestones": []}, "kodla kuruldu, yeni oyunda boş")
	var yerli: Dictionary = CrateCatalog.get_set(&"yerli_klasikler")
	var cars: Array = yerli["cars"]
	var money0: int = economy.money
	var gems0: int = pp.gems
	for i: int in cars.size() - 1:
		own.add_vehicle(cars[i])
	check(entries.is_empty() and not rewards.is_set_paid(&"yerli_klasikler"), "eksik set ödenmez")
	own.add_vehicle(cars.back())
	var reward: Dictionary = CollectionRewards.set_reward(yerli)
	check(entries.size() == 1 and (entries[0]["sets"] as Array).has(&"yerli_klasikler"), "son araçla set tamamlandı: %s" % [entries])
	check(economy.money == money0 + int(reward["money"]) and pp.gems == gems0 + int(reward["gems"]),
		"ödül hesapta: +%d ₺ +%d GEM" % [economy.money - money0, pp.gems - gems0])
	check(rewards.is_set_paid(&"yerli_klasikler"), "set ödendi işaretli")
	own.sell_vehicle(cars[0])
	own.add_vehicle(cars[0])
	check(entries.size() == 1 and pp.gems == gems0 + int(reward["gems"]), "satıp geri alınca ikinci kez ödenmez")


func _screen() -> void:
	print("== 3) SET TAMAMLANDI! ekranı ==")
	var screen: CollectionRewardScreen = hud().collection_reward_screen
	check(screen != null, "HUD'da kurulu")
	check(screen.is_pending(), "ödül bekliyor (oyun sakinleşince açılır)")
	check(int(hud().get("_coin_hold")) > 0 and int(hud().get("_gem_hold")) > 0, "sayaçlar eski değerde bekliyor")
	hud().router.open(&"profile")
	await seconds(1.6)
	check(not screen.visible, "pano açıkken açılmaz")
	hud().router.close_all()
	await seconds(1.6)
	check(screen.visible, "sakin anda açıldı")
	check((screen.get("_title") as Label).text == "SET TAMAMLANDI!", "başlık: %s" % (screen.get("_title") as Label).text)
	var cards: HBoxContainer = screen.get("_cards")
	check(cards.get_child_count() == 1, "tek kart: set (%d)" % cards.get_child_count())
	var photos: int = 0
	for node: Node in cards.find_children("*", "TextureRect", true, false):
		if (node as TextureRect).texture != null:
			photos += 1
	check(photos == CollectionRewardScreen.SET_PHOTOS, "set kartında %d araç fotoğrafı (%d)" % [CollectionRewardScreen.SET_PHOTOS, photos])
	var reward: Dictionary = CollectionRewards.set_reward(CrateCatalog.get_set(&"yerli_klasikler"))
	check((screen.get("_money_label") as Label).text == "+%s ₺" % Hud.format_thousands(int(reward["money"])),
		"para hapı: %s" % (screen.get("_money_label") as Label).text)
	(screen.get("_collect") as PlateButton).pressed.emit()
	await seconds(3.0)
	check(not screen.visible and not screen.is_pending(), "TOPLA ile kapandı")
	check(int(hud().get("_coin_hold")) == 0 and int(hud().get("_gem_hold")) == 0, "paralar sayaçlara vardı")


func _milestones() -> void:
	print("== 4) Kilometre taşı (10 araç) ==")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var rewards: CollectionRewards = g(&"collection_rewards")
	var pp: PlayerProgress = g(&"player_progress")
	entries.clear()
	var gems0: int = pp.gems
	for car: StringName in _obtainable():
		if CollectionRewards.found_count(own) >= 10:
			break
		own.add_vehicle(car)
	var paid: int = 0
	var milestone: bool = false
	for entry: Dictionary in entries:
		paid += int(entry["gems"])
		milestone = milestone or (entry["milestones"] as Array).has(10)
	check(milestone and rewards.is_milestone_paid(10), "10. araçta taş ödendi")
	check(pp.gems == gems0 + paid and paid >= int(CollectionRewards.MILESTONES[10]), "taş elması hesapta (+%d)" % paid)
	check(not rewards.is_milestone_paid(20), "20 henüz değil")
	var screen: CollectionRewardScreen = hud().collection_reward_screen
	await seconds(1.6)
	check(screen.visible, "ekran açıldı")
	var titles: PackedStringArray = PackedStringArray()
	for card: Node in (screen.get("_cards") as HBoxContainer).get_children():
		var label: Label = card.get_meta(&"name_label", null) as Label
		titles.append(label.text if label else "?")
	check(titles.has("10 ARAÇ"), "kilometre taşı kartı: %s" % [titles])
	screen.close()
	await seconds(2.5)

	print("== 5) KOLEKSİYON panosu ==")
	hud().router.open(&"collection")
	await seconds(1.0)
	var panel: CollectionScreen = hud().collection_screen
	var found: int = CollectionRewards.found_count(own)
	check((panel.get("_title") as Label).text == "KOLEKSİYON   %d / %d" % [found, CollectionRewards.total_count()],
		"sayaç bütün koleksiyon üzerinden: %s" % (panel.get("_title") as Label).text)
	var grid: GridContainer = panel.get("_sets_grid")
	check(grid != null and grid.get_child_count() == CrateCatalog.sets().size(), "set satırları (%d)" % (grid.get_child_count() if grid else -1))
	var done_rows: int = 0
	for label: Node in grid.find_children("*", "Label", true, false):
		if (label as Label).text == "✔ ALINDI":
			done_rows += 1
	var paid_sets: int = (rewards.state()["sets"] as Array).size()
	check(done_rows == paid_sets and paid_sets >= 1, "ödenen setlerde ALINDI (%d / %d)" % [done_rows, paid_sets])
	hud().router.close_all()
	await seconds(0.5)


func _save_and_legacy() -> void:
	print("== 6) Kayıt ve bölümü olmayan eski kayıt ==")
	var rewards: CollectionRewards = g(&"collection_rewards")
	var state: Dictionary = rewards.state()
	(g(&"save_manager") as SaveManager).save_game()
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	check(data.has("collection") and (data["collection"]["sets"] as Array).has("yerli_klasikler"), "kayıtta collection bölümü")
	await reload()
	rewards = g(&"collection_rewards")
	check(rewards.state() == state, "yeniden açılışta ödenenler geri geldi")
	check(entries.is_empty() and not hud().collection_reward_screen.is_pending(), "açılışta yeniden ödenmez")

	data.erase("collection")
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	var gems: int = int(data["progress"]["gems"])
	await reload()
	rewards = g(&"collection_rewards")
	check(rewards.is_set_paid(&"yerli_klasikler") and rewards.is_milestone_paid(10), "eski kayıt: tamam olanlar ödenmiş sayıldı")
	check((g(&"player_progress") as PlayerProgress).gems == gems and entries.is_empty(), "eski kayıtta geriye dönük ödül yok")


func _full_collection() -> void:
	print("== 7) TAM KOLEKSİYON ==")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	var rewards: CollectionRewards = g(&"collection_rewards")
	var profile: PlayerProfile = g(&"player_profile")
	var decor: DecorManager = g(&"decor")
	check(not profile.frames_owned.has(CollectionRewards.FINAL_FRAME) and decor.owned_of(CollectionRewards.FINAL_DECOR) == 0,
		"öncesinde çerçeve / kupa yok")
	for car: StringName in _obtainable():
		own.add_vehicle(car)
	var final_entries: Array = entries.filter(func(entry: Dictionary) -> bool: return entry["final"])
	check(final_entries.size() == 1, "TAM KOLEKSİYON bir kez")
	check(CollectionRewards.found_count(own) == CollectionRewards.total_count(), "72 / 72")
	for count: int in CollectionRewards.milestone_list():
		check(rewards.is_milestone_paid(count), "taş %d ödendi" % count)
	var all_paid: bool = true
	for set_entry: Dictionary in CrateCatalog.sets():
		all_paid = all_paid and rewards.is_set_paid(set_entry["id"])
	check(all_paid, "bütün setler ödendi")
	check(profile.frames_owned.has(CollectionRewards.FINAL_FRAME), "KOLEKSİYONER çerçevesi verildi")
	check(profile.honors.has(CollectionRewards.FINAL_HONOR) and profile.public_fields().get("honor", "") == CollectionRewards.FINAL_HONOR,
		"unvan verildi, profilde yayınlanır")
	check(decor.owned_of(CollectionRewards.FINAL_DECOR) == 1, "KOLEKSİYONER KUPASI depoda")
	check(not GarageDecor.get_item(CollectionRewards.FINAL_DECOR).is_empty() and GarageDecor.is_exclusive(CollectionRewards.FINAL_DECOR),
		"kupa mağazada yok (exclusive)")
	var screen: CollectionRewardScreen = hud().collection_reward_screen
	await seconds(1.6)
	check(screen.visible and (screen.get("_title") as Label).text == "TAM KOLEKSİYON!", "ekran: %s" % (screen.get("_title") as Label).text)
	var cards: int = (screen.get("_cards") as HBoxContainer).get_child_count()
	check(cards <= CollectionRewardScreen.MAX_CARDS and cards >= 3, "kartlar sığar (%d ≤ %d): çerçeve + kupa + unvan" % [cards, CollectionRewardScreen.MAX_CARDS])
	screen.close()
	await seconds(2.5)
