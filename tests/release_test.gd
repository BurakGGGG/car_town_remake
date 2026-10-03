extends SceneTree
## YAYIN ADAYI KAYIT / EKONOMİ TESTİ — bozuk kayıt fuzz'ı + ekonomi değişmezleri + katalog meta verisi.
## Çalıştırma: tools/run_tests.sh release_test   (yalıtılmış kullanıcı klasörü; headless)
##
## Fuzz: geçerli bir kaydın HER yaprak alanı sırayla kötü değerlerle (null, metin, negatif, dev sayı,
## dizi, sözlük, bool) değiştirilir ve apply_snapshot'a verilir. Beklenen: çökme yok, para / gem /
## seviye aralıkları korunur, en az bir sahip olunan araç kalır.
var fails: int = 0
var main: Node

const HOSTILE: Array = [null, "abc", -999, 9.0e30, [], {}, true, -0.5, "", 1_000_000_000_000]

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _leaf_paths(node: Variant, path: Array, out: Array) -> void:
	if node is Dictionary:
		for k: Variant in (node as Dictionary):
			_leaf_paths(node[k], path + [k], out)
		out.append(path)   # kapsayıcının kendisi de kötü değerle değiştirilir
	elif node is Array:
		for i: int in (node as Array).size():
			_leaf_paths(node[i], path + [i], out)
		out.append(path)
	else:
		out.append(path)

func _set_path(root_dict: Dictionary, path: Array, value: Variant) -> void:
	var cur: Variant = root_dict
	for i: int in path.size() - 1:
		cur = cur[path[i]]
	cur[path[path.size() - 1]] = value

func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))
	main = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(10)
	var save: SaveManager = get_first_node_in_group("save_manager")
	var eco: EconomyManager = get_first_node_in_group("economy")
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	var crates: CrateManager = get_first_node_in_group("crates")

	print("== 1) EKONOMİ DEĞİŞMEZLERİ ==")
	eco.set_money(100)
	check(not eco.spend_money(101) and eco.money == 100, "yetersiz harcama bakiyeyi değiştirmez")
	eco.add_money(-50)
	check(eco.money == 100, "negatif add_money yok sayılır")
	eco.set_money(-500)
	check(eco.money == 0, "set_money negatifi 0'a çeker")
	check(eco.spend_money(0) and eco.money == 0, "0 harcama sorunsuz")
	eco.set_money(100)
	var a: bool = eco.spend_money(100)
	var b: bool = eco.spend_money(100)
	check(a and not b and eco.money == 0, "aynı 100 ₺ iki kez harcanamaz (çift dokunuş)")

	print("== 2) BOZUK KAYIT FUZZ ==")
	eco.set_money(5000)
	save.save_game()
	var base: Dictionary = save.snapshot()
	var paths: Array = []
	_leaf_paths(base, [], paths)
	paths = paths.filter(func(p: Array) -> bool: return not p.is_empty())
	print("  alan sayısı: %d × %d kötü değer" % [paths.size(), HOSTILE.size()])
	var bad: int = 0
	var applied: int = 0
	for p: Array in paths:
		for h: Variant in HOSTILE:
			var snap: Dictionary = base.duplicate(true)
			_set_path(snap, p, h)
			save.apply_snapshot(snap)
			applied += 1
			var ok: bool = eco.money >= 0 and pp.gems >= 0 and pp.level >= 1 and pp.level <= 99 \
				and pp.xp >= 0 and own.owned_count() >= 1
			if not ok:
				bad += 1
				if bad <= 12:
					print("    ihlal: yol=%s değer=%s para=%d gem=%d sv=%d xp=%d araç=%d" % [str(p), str(h), eco.money, pp.gems, pp.level, pp.xp, own.owned_count()])
	check(bad == 0, "%d bozuk kayıt uygulandı, değişmez ihlali: %d" % [applied, bad])

	print("== 3) KÖK DÜZEYİ BOZUKLUK ==")
	for raw: Variant in [null, "x", 5, [], {}, {"version": "a"}, {"version": 999}, {"version": -1}, {"version": 0}]:
		check(not save.apply_snapshot(raw) and eco.money >= 0, "kök bozuk kayıt reddedilir: %s" % str(raw))

	print("== 4) ESKİ SÜRÜMLER (v1..v9) ==")
	for v: int in range(1, 10):
		var old: Dictionary = {"version": v, "economy": {"money": 1234}, "progress": {"xp": 5, "level": 3, "gems": 7}}
		check(save.apply_snapshot(old) and eco.money == 1234 and pp.level == 3 and own.owned_count() >= 1, "v%d minimal kayıt yüklenir" % v)

	print("== 5) KASA SONUCU KAYITTAN SONRA DEĞİŞMEZ ==")
	if crates:
		var st: Dictionary = crates.state()
		var before: String = JSON.stringify(st)
		save.save_game()
		save.load_game()
		check(JSON.stringify(crates.state()) == before, "kasa durumu kaydet→yükle sonrası birebir aynı")
	else:
		check(false, "CrateManager bulunamadı (grup adı?)")

	print("== 7) KASA RNG DAĞILIMI (20.000 çekiliş / kasa) ==")
	for c: Dictionary in CrateCatalog.all():
		var cid: StringName = StringName(c["id"])
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 12345
		var counts: Dictionary = {}
		var n: int = 20000
		for k: int in n:
			var v: StringName = CrateCatalog.roll(cid, rng)
			counts[v] = int(counts.get(v, 0)) + 1
		var worst: float = 0.0
		for o: Dictionary in CrateCatalog.odds(cid):
			var vid: StringName = StringName(o["vehicle"]) if o.has("vehicle") else StringName(o.get("id", ""))
			var expected: float = float(o.get("p", o.get("chance", 0.0)))
			if expected <= 0.0:
				continue
			var got: float = float(counts.get(vid, 0)) / float(n)
			worst = maxf(worst, absf(got - expected))
		check(worst < 0.012, "%s: en kötü sapma %.4f (< 0.012)" % [cid, worst])
		var pool: Array = CrateCatalog.pool(cid)
		var outside: int = 0
		for v: Variant in counts:
			if not pool.has(v): outside += 1
		check(outside == 0, "%s: havuz dışı araç çıkmadı" % cid)

	print("== 8) KASA ÇİFT İŞLEM ==")
	if crates:
		var cid2: StringName = StringName(CrateCatalog.all()[0]["id"])
		var uid: int = crates.grant_free(cid2, "release_test")
		check(uid > 0, "ücretsiz kasa verildi")
		var veh: StringName = StringName(crates.get_crate(uid).get("vehicle", ""))
		save.save_game()
		save.load_game()
		check(StringName(crates.get_crate(uid).get("vehicle", "")) == veh, "yeniden başlatma sonrası kasa sonucu değişmedi (%s)" % veh)
		crates.mark_delivered(uid, Vector2(1, 1), 0.0)
		var g0: int = pp.gems
		var r1: Dictionary = crates.open(uid)
		var r2: Dictionary = crates.open(uid)
		check(not r1.is_empty() and r2.is_empty(), "aynı kasa iki kez açılamaz")
		var g1: int = pp.gems
		crates.claim(uid)
		crates.claim(uid)
		check(pp.gems == g1 and g1 >= g0, "claim tekrarı gem'i ikinci kez vermez")

	print("== 9) ANDROID GERİ TUŞU (UiRouter.handle_android_back) ==")
	var router: UiRouter = get_first_node_in_group("ui_router")
	if router:
		var hints: Array[int] = [0]
		router.exit_hint_requested.connect(func() -> void: hints[0] += 1)
		router.close_all()
		router.open(&"quests")
		check(router.top() == &"quests", "görevler açıldı")
		router.handle_android_back()
		check(router.top() == &"", "GERİ açık panoyu kapattı, uygulama çıkmadı")
		router.open(&"showroom")
		router.open(&"mastery")
		router.handle_android_back()
		check(router.top() == &"showroom", "GERİ yalnızca üstteki panoyu kapattı (yığın en çok 2)")
		router.handle_android_back()
		check(router.top() == &"" and hints[0] == 0, "GERİ showroom'u kapattı, çıkış ipucu henüz yok")
		router.handle_android_back()
		check(hints[0] == 1, "kökte ilk GERİ → 'tekrar bas' ipucu, uygulama kapanmadı")
	else:
		check(false, "UiRouter bulunamadı")

	print("== 6) KATALOG META VERİSİ ==")
	var ids: Array = CarCatalog.all()
	check(ids.size() >= 16, "katalogda en az 16 araç (%d)" % ids.size())

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
