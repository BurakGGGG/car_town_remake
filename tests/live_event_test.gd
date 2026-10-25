extends SceneTree
## CANLI ETKİNLİK MODÜLLERİ (LiveEvent, 2026-10-23) — belge doğrulama ve sınırlar; İNDİRİM (kasa gemi, GERİ AL, dekor,
## modifiye: görünen = düşen); ETKİNLİK KASASI (oranlar gerçek, çarpılan araçlar artar); ETKİNLİK GÖREVLERİ (yalnız
## etkinlikte sayar, ödül, etkinlik bitince alınmamış ödül kendiliğinden, kayıt); ÖZEL RAKİP (doğrudan pist, yapı, özel
## ödül bir kez, görev sayacı); İÇERİK PAKETİ (LivePackBuilder ile gerçek .pck kurulur, LivePacks bağlar: eşya katalogda,
## model paketten yüklenir, etkinlik eşyası yalnız etkinlikte satılır, oyunun dosyası ezilemez, bozuk dosya bağlanmaz);
## BEKLEYEN EŞYA (paketi inmemiş eşya kayıttan silinmez, paket gelince yerine konur); tabela + ETKİNLİK PANOSU + GÖREVLER
## sekmesi. Ağ yok: belge AppConfig.apply ile verilir.
##   tools/run_tests.sh live_event_test

var fails: int = 0
var hud: Hud
var config: AppConfig
var now: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _initialize() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	hud = main.find_child("HUD", true, false) as Hud
	config = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	config.learning_url = ""
	root.add_child(config)
	await frames(2)
	now = int(Time.get_unix_time_from_system())
	_normalize()
	_sale()
	_crate_boost()
	await _missions()
	await _rival()
	await _pack()
	await _ui()
	config.apply({})
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _event(fields: Dictionary) -> void:
	var e: Dictionary = {"id": "t1", "start": now - 60, "end": now + 7200}
	e.merge(fields, true)
	config.apply({"event": e})


func _normalize() -> void:
	print("== 1) Belge doğrulama ==")
	_event({"sale": {"crates": 80, "decor": 20, "bogus": 30}, "crate_boost": {"crate": "city_crate",
		"cars": ["ford_focus", "yok_boyle_arac", "ford_focus"], "mult": 9},
		"missions": [{"id": "m1", "metric": "repairs", "target": 5, "money": 99999999},
			{"id": "m2", "metric": "uydurma", "target": 3}, {"id": "m1", "metric": "races", "target": 1}],
		"rival": {"car": "tofas_sahin", "stage": 9, "name": {"tr": "Kral"}, "paint": "#ff0000", "gems": 5000}})
	var e: Dictionary = LiveEvent.current()
	check(not e.is_empty() and LiveEvent.id() == "t1", "çarpansız ama modüllü etkinlik etkin")
	check(LiveEvent.sale_percent(&"crates") == LiveEvent.SALE_MAX and LiveEvent.sale_percent(&"decor") == 20
		and not (e["sale"] as Dictionary).has(&"bogus"), "indirim en çok %%50, bilinmeyen tür atlanır")
	check((e["crate_boost"]["cars"] as Array) == [&"ford_focus"] and float(e["crate_boost"]["mult"]) == LiveEvent.BOOST_MAX,
		"etkinlik kasası: havuzda olmayan / yinelenen araç atlanır, çarpan en çok 5")
	var missions: Array = e["missions"]
	check(missions.size() == 1 and missions[0]["id"] == "m1" and int(missions[0]["money"]) == LiveEvent.REWARD_MONEY_MAX,
		"görev: bilinmeyen metrik ve yinelenen kimlik atlanır, ödül sınırlanır")
	var rival: Dictionary = e["rival"]
	check(rival["car"] == &"tofas_sahin" and int(rival["stage"]) == LiveEvent.RIVAL_STAGE_MAX and rival["name"] == "Kral"
		and int(rival["gems"]) == LiveEvent.REWARD_GEMS_MAX, "rakip: kademe en çok 5, ad dilden, gem sınırlı")
	_event({"rival": {"car": "police_car"}})
	check(LiveEvent.current().is_empty() or (LiveEvent.rival().is_empty()), "edinilemeyen araç rakip olmaz")
	_event({})
	check(LiveEvent.current().is_empty(), "hiç modülü olmayan etkinlik etkin değil")
	config.apply({"event": {"id": "t1", "start": now + 600, "end": now + 7200, "sale": {"crates": 10}}})
	check(not LiveEvent.active() and LiveEvent.sale_price(&"crates", 40) == 40, "başlamamış etkinlikte indirim yok")


func _sale() -> void:
	print("== 2) İndirim: görünen = düşen ==")
	var pp: PlayerProgress = g(&"player_progress")
	var eco: EconomyManager = g(&"economy")
	var crates: CrateManager = g(&"crates")
	var decor: DecorManager = g(&"decor")
	var own: VehicleOwnership = g(&"vehicle_ownership")
	_event({"sale": {"crates": 25, "cars": 50, "decor": 30, "mods": 40}})
	check(CrateCatalog.price(&"city_crate") == 40 and CrateCatalog.sale_price(&"city_crate") == 30, "kasa 40 → 30 gem")
	pp.load_state(5, 0, 30)
	var uid: int = crates.buy(&"city_crate")
	check(uid > 0 and pp.gems == 0, "30 gemle alındı (%d gem kaldı)" % pp.gems)
	check(LiveEvent.apply_sale(1, 50) == 1 and LiveEvent.apply_sale(0, 50) == 0, "ücretli şey indirimle bedava olmaz")
	check(own.buy_price(&"ford_focus") == int(round(own.price(&"ford_focus") * 0.5)) and own.sell_price(&"ford_focus") < own.buy_price(&"ford_focus"),
		"GERİ AL %50; satış fiyatı indirimli alıştan düşük (kâr yok)")
	var item: StringName = &"hedge"
	var base: int = int(GarageDecor.get_item(item).get("price", 0))
	check(decor.price_of(item) == int(round(base * 0.7)), "dekor %%30: %d → %d ₺" % [base, decor.price_of(item)])
	eco.set_money(decor.price_of(item))
	pp.load_state(30, 0, 0)
	check(decor.purchase(item) and eco.money == 0, "dekor indirimli fiyatla alındı")
	var mod_base: int = 0
	config.apply({})
	mod_base = PerformanceMods.price(&"ford_focus", &"motor", 3)
	_event({"sale": {"mods": 40}})
	var mod_sale: int = PerformanceMods.price(&"ford_focus", &"motor", 3)
	check(mod_sale < mod_base and mod_sale % 50 == 0 and absi(mod_sale - int(mod_base * 0.6)) <= 50,
		"modifiye %%40: %d → %d ₺ (50'nin katı)" % [mod_base, mod_sale])
	config.apply({})
	check(CrateCatalog.sale_price(&"city_crate") == 40 and decor.price_of(item) == base, "etkinlik bitince eski fiyat")


func _crate_boost() -> void:
	print("== 3) Etkinlik kasası ==")
	var before: Dictionary = {}
	for row: Dictionary in CrateCatalog.odds(&"city_crate"):
		before[row["id"]] = float(row["chance"])
	_event({"crate_boost": {"crate": "city_crate", "cars": ["ford_focus"], "mult": 3}})
	var total: float = 0.0
	var after: Dictionary = {}
	for row: Dictionary in CrateCatalog.odds(&"city_crate"):
		total += float(row["chance"])
		after[row["id"]] = float(row["chance"])
	check(absf(total - 1.0) < 0.0001, "oranların toplamı yine 1")
	check(float(after[&"ford_focus"]) > float(before[&"ford_focus"]) * 2.0 and float(after[&"hyundai_getz"]) < float(before[&"hyundai_getz"]),
		"FOCUS %s → %s, ötekiler azaldı" % [Loc.decimal(before[&"ford_focus"] * 100.0), Loc.decimal(after[&"ford_focus"] * 100.0)])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var hits: int = 0
	for i: int in 4000:
		if CrateCatalog.roll(&"city_crate", rng) == &"ford_focus":
			hits += 1
	check(absf(float(hits) / 4000.0 - float(after[&"ford_focus"])) < 0.03, "çekiliş gösterilen oranla tutuyor (%d / 4000)" % hits)
	check(LiveEvent.crate_boost(&"sport_crate").is_empty(), "başka kasa etkilenmez")
	config.apply({})


func _missions() -> void:
	print("== 4) Etkinlik görevleri ==")
	var missions: MissionManager = g(&"missions")
	var eco: EconomyManager = g(&"economy")
	var pp: PlayerProgress = g(&"player_progress")
	var crates: CrateManager = g(&"crates")
	missions.count(&"repairs", 3)   # etkinlik yokken sayılmaz
	_event({"missions": [{"id": "rep", "metric": "repairs", "target": 4, "money": 1000, "gems": 7, "crate": "city_crate"},
		{"id": "win", "metric": "event_rival_wins", "target": 1, "xp": 50}]})
	missions.ensure_current()
	var tasks: Array[Dictionary] = missions.event_tasks()
	check(tasks.size() == 2 and int(tasks[0]["progress"]) == 0, "iki görev, etkinlik öncesi tamirler sayılmadı")
	missions.count(&"repairs", 4)
	tasks = missions.event_tasks()
	check(bool(tasks[0]["done"]) and missions.claimable_event() == 1, "4 tamir: görev bitti, ödül hazır")
	eco.set_money(0)
	pp.load_state(5, 0, 0)
	var pending: int = crates.pending_count()
	check(missions.claim_event("rep") and eco.money == 1000 and pp.gems == 7 and crates.pending_count() == pending + 1,
		"ÖDÜLÜ AL: +1.000 ₺ +7 gem +1 kasa")
	check(not missions.claim_event("rep"), "ikinci kez alınmaz")
	var saved: Dictionary = missions.state()
	missions.load_state(saved)
	check(bool(missions.event_tasks()[0]["claimed"]) and int(missions.event_tasks()[0]["progress"]) == 4, "kayıt: ilerleme ve alınan ödül")
	# Bitmiş ama alınmamış ödül: etkinlik değişince kendiliğinden verilir
	missions.count(&"event_rival_wins", 1)
	var xp_before: int = pp.xp + pp.level * 100000
	config.apply({})
	missions.ensure_current()
	check(missions.event_tasks().is_empty() and pp.xp + pp.level * 100000 > xp_before, "etkinlik bitti: alınmamış ödül verildi, görevler kalktı")
	missions.count(&"repairs", 10)
	check(missions.event_tasks().is_empty(), "etkinlik yokken sayaç yazılmaz")
	await frames(1)


func _rival() -> void:
	print("== 5) Özel rakip ==")
	var race: RaceManager = g(&"race")
	var pp: PlayerProgress = g(&"player_progress")
	var missions: MissionManager = g(&"missions")
	check(not race.start_event_rival(), "etkinlikte rakip yokken açılmaz")
	_event({"rival": {"car": "ford_focus", "stage": 2, "name": "Kral Rıza", "paint": "#2255ff", "money": 5000, "gems": 15},
		"missions": [{"id": "boss", "metric": "event_rival_wins", "target": 2, "gems": 1}]})
	missions.ensure_current()
	check(race.start_event_rival() and race.is_event_rival() and race.rival_id() == &"ford_focus", "pist doğrudan: rakip FOCUS")
	check(int(race.rival_build().get(&"motor", 0)) == 2 and race.rival_owner().get("name") == "Kral Rıza"
		and race.rival_appearance() != null, "yapı (her kategori 2), ad, boya")
	var rec: DragRaceSim.Recording = race.rival_recording(race.player_vehicle_id())
	check(rec != null and rec.time > 3.0, "rakip koşusu yapay zekâdan (%.2f sn)" % (rec.time if rec else 0.0))
	pp.load_state(5, 0, 0)
	var normal: Dictionary = race.reward_for(&"ford_focus", true)
	var reward: Dictionary = race.finish_race(true)
	check(reward.get("event_bonus") is Dictionary and int(reward["money"]) == int(normal["money"]) + 5000 and pp.gems == 15,
		"ilk galibiyet: normal ödül + 5.000 ₺ + 15 gem")
	check(race.event_reward_taken(), "özel ödül alındı işareti")
	race.end_race_session()
	check(race.start_event_rival(), "yeniden yarışılabilir")
	race.rival_recording(race.player_vehicle_id())
	var second: Dictionary = race.finish_race(true)
	check(not second.has("event_bonus") and pp.gems == 15, "ikinci galibiyette özel ödül yok")
	race.end_race_session()
	check(int(missions.event_tasks()[0]["progress"]) == 2, "görev sayacı: ETKİNLİK RAKİBİNİ 2 KEZ YEN")
	var saved: Dictionary = race.state()
	race.load_state(saved)
	check(race.event_reward_taken(), "kayıt: özel ödül alındı kalır")
	config.apply({})
	await frames(1)


func _pack() -> void:
	print("== 6) İçerik paketi ==")
	var image: Image = Image.create(64, 16, false, Image.FORMAT_RGBA8)
	image.fill(Color("F5BE4C"))
	image.save_png("user://live_test_banner.png")
	var source: Dictionary = {"banner": "user://live_test_banner.png", "decor": [
		{"id": "event_tree", "kind": "plant", "title": {"tr": "Yılbaşı Çamı", "en": "Holiday Pine"}, "price": 5000,
			"value": 2500, "min_level": 1, "model": "res://assets/decor/tree_pine.glb", "event_only": true},
		{"id": "event_hedge", "kind": "plant", "title": "Kar Çiti", "price": 1000, "value": 500,
			"model": "res://assets/decor/hedge.glb"}]}
	var out: String = ProjectSettings.globalize_path("user://live_test.pck")
	var built: Dictionary = LivePackBuilder.build("live_test", source, "res://", out)
	check(bool(built["ok"]) and int(built["decor"]) == 2 and String(built["sha256"]).length() == 64,
		"paket kuruldu (%d bayt) %s" % [int(built["size"]), built["error"]])
	var bad: Dictionary = LivePackBuilder.build("live_test_bad", {"decor": [{"id": "hedge", "kind": "plant", "model": "res://assets/decor/hedge.glb"}]},
		"res://", ProjectSettings.globalize_path("user://live_bad.pck"))
	check(not bool(bad["ok"]), "oyunda olan kimlikle eşya eklenemez (%s)" % bad["error"])
	var code: Dictionary = LivePackBuilder.build("live_test_code", {"decor": [{"id": "x_item", "kind": "plant", "model": "res://gameplay/save_safe.gd"}]},
		"res://", ProjectSettings.globalize_path("user://live_code.pck"))
	check(not bool(code["ok"]), "kod dosyası pakete giremez")
	# Önbellek dizini: özeti tutmayan dosya bağlanmaz
	DirAccess.make_dir_recursive_absolute(LivePacks.DIR)
	DirAccess.copy_absolute(out, ProjectSettings.globalize_path(LivePacks.DIR + "live_test-x.pck"))
	LivePacks._write_index({"live_test": {"sha256": "0".repeat(64), "file": "live_test-x.pck"}})
	check(LivePacks.mount_cached() == 0 and not LivePacks.is_mounted("live_test"), "özet tutmuyorsa bağlanmaz")
	# Kayıtta paketin eşyası var, paket henüz yok: silinmez, bekler
	var decor: DecorManager = g(&"decor")
	var state: Dictionary = decor.state()
	(state["owned"] as Dictionary)["event_tree"] = 1
	(state["instances"] as Array).append({"instance_id": "dec_9001", "catalog_id": "event_tree",
		"position": {"x": 0.4, "y": 0.0, "z": 0.4}, "rotation": {"x": 0.0, "y": 0.0, "z": 0.0}, "scale": {"x": 1, "y": 1, "z": 1}})
	decor.load_state(state)
	check(decor.owned_of(&"event_tree") == 0 and decor.dormant_count() == 1, "paketi inmemiş eşya bekliyor")
	var resaved: Dictionary = decor.state()
	check((resaved["owned"] as Dictionary).has("event_tree") and str(resaved["instances"]).contains("dec_9001"),
		"bekleyen eşya kayda aynen geri yazılır (silinmez)")
	LivePacks._write_index({"live_test": {"sha256": built["sha256"], "file": "live_test-x.pck"}})
	check(LivePacks.mount_cached() == 1 and LivePacks.is_mounted("live_test"), "doğru özetle bağlandı")
	check(GarageDecor.exists(&"event_tree") and GarageDecor.pack_of(&"event_tree") == "live_test"
		and ["YILBAŞI ÇAMI", "HOLIDAY PINE"].has(GarageDecor.get_item(&"event_tree").get("title")), "eşya katalogda (dil sözlüğünden, BÜYÜK harf başlık)")
	check(ResourceLoader.exists("res://live/live_test/models/tree_pine.glb")
		and load("res://live/live_test/models/tree_pine.glb") is PackedScene, "model paketten yükleniyor")
	check(DecorBuilder.build_placeable(&"event_tree") != null, "dekor gövdesi kuruluyor")
	check(LivePacks.banner("live_test") != null and LivePacks.banner("live_test").get_width() == 64, "afiş paketten okunuyor")
	check(FileAccess.get_file_as_string("res://decor/decorations.json").contains("\"hedge\""), "oyunun kendi dosyası ezilmedi")
	check(decor.revive_dormant() == 1 and decor.owned_of(&"event_tree") == 1 and decor.dormant_count() == 0
		and str(decor.instances()).contains("dec_9001"), "paket gelince bekleyen eşya yerine kondu")
	GarageDecor.load_from()
	check(GarageDecor.exists(&"event_tree"), "katalog yeniden okununca paket eşyası kaybolmaz")
	var eco: EconomyManager = g(&"economy")
	eco.set_money(1_000_000)
	check(not GarageDecor.on_sale(&"event_tree") and not decor.can_purchase(&"event_tree"), "etkinlik eşyası etkinlik dışında satılmaz")
	check(GarageDecor.on_sale(&"event_hedge") and decor.can_purchase(&"event_hedge"), "paketin normal eşyası her zaman satılır")
	_event({"pack": "live_test"})
	check(decor.can_purchase(&"event_tree") and decor.purchase(&"event_tree"), "etkinlik sürerken satılıyor")
	var in_palette: bool = false
	config.apply({})
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.PLANT):
		in_palette = in_palette or item["id"] == &"event_tree"
	check(in_palette, "etkinlik bitince sahibinin paletinde kalır")
	await frames(1)


func _ui() -> void:
	print("== 7) Tabela, pano, GÖREVLER sekmesi ==")
	_event({"title": {"tr": "Kış etkinliği"}, "money_mult": 2, "sale": {"crates": 30},
		"crate_boost": {"crate": "city_crate", "cars": ["ford_focus"], "mult": 3},
		"missions": [{"id": "rep", "metric": "repairs", "target": 2, "money": 100}],
		"rival": {"car": "ford_focus", "stage": 1, "money": 100}, "pack": "live_test"})
	(g(&"missions") as MissionManager).ensure_current()
	await seconds(1.3)
	var banner: EventBanner = hud.find_child("EventBanner", true, false) as EventBanner
	var texts: String = " ".join(banner.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(banner.visible and texts.contains(Loc.t("ÇİFTE PARA")) and RegEx.create_from_string("· \\+\\d").search(texts) != null,
		"tabela modülleri özetliyor, sığmayan +N (%s)" % texts)
	var plate: Control = banner.find_child("Plate", true, false) as Control
	var tap: InputEventMouseButton = InputEventMouseButton.new()
	tap.pressed = true
	tap.button_index = MOUSE_BUTTON_LEFT
	plate.gui_input.emit(tap)
	await seconds(0.6)
	check(hud.router.top() == &"event" and hud.event_screen.visible, "tabelaya dokununca ETKİNLİK PANOSU")
	for kind: String in ["showroom", "missions", "race", "decor"]:
		check(hud.event_screen.find_child("Action_%s" % kind, true, false) != null, "panoda %s düğmesi" % kind)
	# Görevli etkinlikte pano ARACA GİDEN YOL'dur (taslak B, 2026-10-26); afiş görevsiz etkinliğin satır görünümünde
	check((hud.event_screen.find_child("Road", true, false) as Control).visible, "görevli etkinlik: araca giden yol")
	(hud.event_screen.find_child("Action_missions", true, false) as PlateButton).pressed.emit()
	await seconds(0.6)
	check(hud.router.top() == &"quests" and hud.quest_screen._tab == MissionScreen.Tab.EVENT, "GÖREVLER → ETKİNLİK sekmesi")
	hud.router.close_all()
	await seconds(0.5)
	hud.router.open(&"event")
	await seconds(0.5)
	(hud.event_screen.find_child("Action_race", true, false) as PlateButton).pressed.emit()
	await seconds(0.8)
	var race: RaceManager = g(&"race")
	check(hud.router.top() == &"drag_race" and race.is_event_rival(), "YARIŞ: pist etkinlik rakibiyle açıldı")
	hud.call(&"_on_race_exit")
	await seconds(0.6)
	_event({"title": {"tr": "Kış etkinliği"}, "money_mult": 2, "pack": "live_test"})
	await seconds(1.3)
	hud.router.open(&"event")
	await seconds(0.6)
	check(hud.event_screen.find_child("Banner", true, false) != null and not (hud.event_screen.find_child("Road", true, false)
		as Control).visible, "görevsiz etkinlik: satırlar ve paketin afişi")
	hud.router.close_all()
	await seconds(0.5)
	config.apply({})
	await seconds(1.3)
	check(not banner.visible, "etkinlik bitince tabela söner")
