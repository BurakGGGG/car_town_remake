extends SceneTree
## GÜNLÜK GİRİŞ MERDİVENİ (2026-10-23, docs/GIRIS_MERDIVENI.md): 28 basamaklı ödül tablosu, hafta / ay dekorları ve yedek
## elmas, AL ile alma, bir gün kaçırınca 1. güne dönüş, alınmadan dönen günün kendiliğinden verilmesi, 28. günde ayın
## tamamlanması, ×2, kayıt; sağ üstteki tabela ve pano. Çalıştırma: tools/run_tests.sh login_ladder_test

var fails: int = 0
const T0: int = 1_800_000_000


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
	print("== ÖDÜL TABLOSU ==")
	# ₺ = aktif oyun gelirinin dakikası (OfflineEarnings ölçümü: garaj 1 = 372 ₺/dk, garaj 3 / 3 alan = 1.666 ₺/dk)
	var d1: Dictionary = LoginLadder.reward(1, 1, 372.0)
	var d2: Dictionary = LoginLadder.reward(2, 1, 372.0)
	check(int(d1["gems"]) == 10 and int(d1["money"]) == 0, "1. gün 10 gem")
	check(int(d2["money"]) == 2200 and int(d2["gems"]) == 0, "2. gün yeni oyuncuya 6 dakikalık gelir: 2.200 ₺ (%d)" % int(d2["money"]))
	var mid: Dictionary = LoginLadder.reward(20, 1, 1666.0)
	check(int(mid["money"]) == 27000, "20. gün garaj 3 oyuncusuna ~16 dakikalık gelir: 27.000 ₺ (%d)" % int(mid["money"]))
	check(int(LoginLadder.reward(27, 1, 372.0)["money"]) > int(LoginLadder.reward(6, 1, 372.0)["money"]),
		"aynı para günü ay ilerledikçe büyür")
	var minutes: float = 0.0
	for day: int in range(1, LoginLadder.DAYS + 1):
		minutes += float(LoginLadder.reward(day, 1, 1000.0)["money"]) / 1000.0
	check(minutes > 120.0 and minutes < 160.0, "ayda ~2,3 saatlik gelir (%.0f dk): ne abartı ne az" % minutes)
	var weeks: Array[StringName] = []
	for day: int in [7, 14, 21, 28]:
		weeks.append(LoginLadder.reward(day, 1, 372.0)["decor"])
	check(weeks == [&"login_m01_w1", &"login_m01_w2", &"login_m01_w3", &"login_m01_cup"], "1. ayın dekorları: %s" % [weeks])
	check(int(LoginLadder.reward(7, 1, 372.0)["gems"]) == 40 and int(LoginLadder.reward(28, 1, 372.0)["gems"]) == LoginLadder.MONTH_GEMS,
		"hafta sonu 40 gem, ay sonu 50 gem")
	for id: StringName in weeks:
		check(GarageDecor.is_exclusive(id) and GarageDecor.is_placeable(id) and ResourceLoader.exists("res://assets/decor/%s.glb" % id),
			"%s: mağazada yok, yerleştirilebilir, modeli var" % id)
	var m2: Dictionary = LoginLadder.reward(7, 2, 372.0)
	check(m2["decor"] == &"" and int(m2["gems"]) == 40 + LoginLadder.FALLBACK_WEEK_GEMS, "2. ayın dekoru yoksa yerine elmas")
	var total: int = 0
	for day: int in range(1, 8):
		total += int(LoginLadder.reward(day, 1, 372.0)["gems"])
	check(total == 80, "haftada 80 gem (eski seri 110 + ₺ / dekor yoktu)")

	print("== AKIŞ ==")
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false)
	var gem: GemRewards = get_first_node_in_group("gem_rewards") as GemRewards
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var decor: DecorManager = get_first_node_in_group("decor") as DecorManager
	gem.load_state({})
	pp.load_state(5, 0, 0)
	var ready_days: Array[int] = []
	gem.ladder_ready.connect(func(day: int) -> void: ready_days.append(day))
	var autos: Array[Dictionary] = []
	gem.ladder_claimed.connect(func(r: Dictionary) -> void:
		if bool(r["auto"]):
			autos.append(r))
	gem.test_now = T0
	gem.check_day()
	check(ready_days == [1] and gem.can_claim() and pp.gems == 0, "yeni gün: ladder_ready, 1. basamak bekliyor, kendiliğinden verilmez")
	check(hud.login_ladder_button.day == 1 and hud.login_ladder_button.badge == 1, "tabela: 1. gün, rozet")
	var r1: Dictionary = gem.claim_ladder()
	check(pp.gems == 10 and not gem.can_claim() and gem.claim_ladder().is_empty(), "AL → +10 gem, bir kez")
	check(hud.login_ladder_button.badge == 0, "tabelanın rozeti kalktı")
	check(gem.ladder_double() == {"gems": 10, "money": 0}, "×2 teklifi: +10 gem")
	gem.double_ladder(false)
	check(pp.gems == 20 and gem.ladder_double().is_empty(), "×2 bir kez")
	# 2. gün alınmaz: ertesi gün kendiliğinden verilir
	gem.test_now = T0 + 86400
	gem.check_day()
	var money: int = eco.money
	gem.test_now = T0 + 86400 * 2
	gem.check_day()
	check(autos.size() == 1 and int(autos[0]["day"]) == 2 and eco.money > money, "alınmayan 2. gün ertesi gün kendiliğinden verildi")
	check(gem.ladder_day() == 3 and gem.can_claim(), "3. gün")
	gem.claim_ladder()
	# Bir gün kaçırıldı: merdiven 1. güne döner
	gem.test_now = T0 + 86400 * 4
	gem.check_day()
	check(gem.ladder_day() == 1 and gem.streak() == 1, "bir gün kaçırınca 1. güne döner")
	gem.claim_ladder()
	# 7 gün aralıksız: hafta dekoru
	for i: int in range(1, 7):
		gem.test_now = T0 + 86400 * (4 + i)
		gem.check_day()
		gem.claim_ladder()
	check(gem.ladder_day() == 7 and decor.owned_of(&"login_m01_w1") == 1, "7. gün: ALTIN KRİKO verildi")
	# 28. gün: ay kupası, ay tamamlandı
	for i: int in range(7, 28):
		gem.test_now = T0 + 86400 * (4 + i)
		gem.check_day()
		gem.claim_ladder()
	check(gem.ladder_day() == 28 and decor.owned_of(&"login_m01_cup") == 1 and gem.months_done() == 1 and gem.ladder_month() == 1,
		"28. gün: 1. AY KUPASI, ay tamamlandı")
	gem.test_now = T0 + 86400 * 32
	gem.check_day()
	check(gem.ladder_day() == 1 and gem.ladder_month() == 2, "29. gün: yeni merdiven, 2. ay")
	var saved: Dictionary = gem.state()
	gem.load_state(saved)
	check(gem.ladder_month() == 2 and gem.can_claim() and gem.ladder_day() == 1, "kayıttan aynı durum")
	gem.load_state({"login": {"day": 5, "streak": 3}})
	check(not gem.can_claim(), "eski kayıt (merdiven alanı yok): son giriş günü alınmış sayılır")

	print("== PANO ==")
	gem.load_state({})
	gem.test_now = T0 + 86400 * 40
	gem.check_day()
	hud.login_ladder_button.pressed.emit()
	await frames(6)
	var screen: LoginLadderScreen = hud.login_ladder_screen
	check(hud.router.top() == &"login_ladder" and screen.visible, "tabela → merdiven panosu")
	var rows: Array = screen.get("_rows")
	var tiles: int = 0
	for row: Dictionary in rows:
		tiles += (row["tiles"] as Array).size()
	check(rows.size() == 4 and tiles == 28, "4 basamak, 28 gün")
	check(((rows[0]["tiles"] as Array)[0]).state == 1, "bugünün kartı parlıyor")
	var gems: int = pp.gems
	(screen.get("_claim") as PlateButton).pressed.emit()
	await frames(3)
	check(pp.gems == gems + 10 and not (screen.get("_claim") as PlateButton).visible, "AL → ödül, düğme kalktı")
	check((screen.get("_tomorrow") as Label).visible and (screen.get("_tomorrow") as Label).text.contains(":"), "yarının ödülü + geri sayım")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
