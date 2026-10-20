extends SceneTree
## GEM → ₺ ÇEVİRİ (MARKET · PARAYA ÇEVİR) — GemExchange kuru (seviyeye bağlı, büyük teklifte bonus), çeviri
## (gem düşer, ₺ eklenir; gem yetmezse hiçbir şey değişmez; tek yön) ve MARKET ekranı: başlık, sekmeler, bilgi
## satırı yok, pano tam ortada ve ekran oranına sığar (iki sekmede aynı boy), iki dokunuşlu onay, onay süresi,
## gem yetmeyince bildirim + GEM AL sekmesi, ödül penceresi.
## Gerçek düğümlerle koşar (Main.tscn).
##   tools/run_tests.sh gem_exchange_test

var fails: int = 0
var hud: Hud
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
	hud = main.find_child("HUD", true, false) as Hud
	economy = get_first_node_in_group("economy")
	player = get_first_node_in_group("player_progress")
	_rate()
	_exchange()
	await _screen()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _rate() -> void:
	print("== 1) Kur ==")
	check(GemExchange.rate(1) == GemExchange.RATE_PER_LEVEL and GemExchange.rate(0) == GemExchange.rate(1),
		"seviye 1 (ve geçersiz 0): 1 GEM = %d ₺" % GemExchange.rate(1))
	var rising: bool = true
	for level: int in range(1, 40):
		rising = rising and GemExchange.rate(level + 1) > GemExchange.rate(level)
	check(rising, "kur seviyeyle artar")
	var last: float = 0.0
	var better: bool = true
	for offer: Dictionary in GemExchange.OFFERS:
		var per_gem: float = float(GemExchange.money_for(offer, 10)) / float(int(offer["gems"]))
		better = better and per_gem >= last
		last = per_gem
	check(better, "büyük teklif gem başına daha çok ₺ verir")
	check(GemExchange.money_for(GemExchange.OFFERS[0], 10) == 10 * 1000, "10 GEM, seviye 10 = 10.000 ₺")
	check(GemExchange.money_for(GemExchange.OFFERS[1], 10) == 52500, "50 GEM (+%5), seviye 10 = 52.500 ₺")


func _exchange() -> void:
	print("== 2) Çeviri ==")
	player.load_state(10, 0, 60)
	economy.set_money(1000)
	var got: int = GemExchange.exchange(self, GemExchange.OFFERS[1])
	check(got == 52500 and player.gems == 10 and economy.money == 53500, "50 GEM → +52.500 ₺ (gem %d, ₺ %d)" % [
		player.gems, economy.money])
	got = GemExchange.exchange(self, GemExchange.OFFERS[1])
	check(got == 0 and player.gems == 10 and economy.money == 53500, "gem yetmezse hiçbir şey değişmez")
	check(not GemExchange.new().has_method("money_to_gems") and not GemExchange.new().has_method("buy_gems"),
		"tek yön: ₺ → gem yolu yok")


func _screen() -> void:
	print("== 3) MARKET ekranı ==")
	player.load_state(10, 0, 25)
	economy.set_money(0)
	hud.router.open(&"gem_store")
	await frames(20)
	var screen: GemStoreScreen = hud.gem_store_screen
	check(screen.visible, "MARKET açıldı")
	var title: Label = _find_label(screen, "MARKET")
	check(title != null, "başlık MARKET")
	check(screen.get("_tab") == GemStoreScreen.TAB_GEMS, "GEM AL sekmesiyle açılır")
	check(_find_label(screen, "GEMLE ARAÇ KASASI VE ÖZEL BOYA ALINIR") == null, "bilgi satırı yok")
	await frames(30)   # açılış animasyonu bitsin
	var column: Control = screen.get("_column")
	var to_canvas: Transform2D = column.get_global_transform()   # get_global_rect ölçeği yok sayar
	var drawn: Vector2 = column.size * to_canvas.get_scale() / screen.get_global_transform().get_scale()
	var center: Vector2 = to_canvas * (column.size * 0.5)
	var gem_width: float = drawn.x
	var screen_center: Vector2 = screen.get_global_transform() * (screen.size * 0.5)
	check(center.distance_to(screen_center) < 1.0, "pano tam ortada (%s ↔ %s)" % [center, screen_center])
	var fill: Vector2 = drawn / screen.size
	check(is_equal_approx(fill.x, GemStoreScreen.FILL.x) or is_equal_approx(fill.y, GemStoreScreen.FILL.y),
		"pano ekranın sabit oranını kaplar (%.3f x %.3f)" % [fill.x, fill.y])
	check(fill.x <= GemStoreScreen.FILL.x + 0.001 and fill.y <= GemStoreScreen.FILL.y + 0.001, "ekrana sığar")
	screen._on_tab_pressed(GemStoreScreen.TAB_CASH)
	await frames(4)
	var list: HBoxContainer = screen.get("_list")
	check(list.get_child_count() == GemExchange.OFFERS.size(), "PARAYA ÇEVİR: %d kart" % list.get_child_count())
	check(absf(column.size.x * column.get_global_transform().get_scale().x / screen.get_global_transform().get_scale().x
		- gem_width) < 1.0, "sekme değişince pano genişliği aynı")
	check(_find_label(screen, "+10.000 ₺") != null, "10 GEM kartı +10.000 ₺ yazar (seviye 10)")

	screen._on_cash_pressed(0)
	await frames(2)
	check(player.gems == 25 and economy.money == 0, "ilk dokunuş yalnızca onay ister")
	check(_find_button(screen, "ONAYLA") != null, "düğme ONAYLA oldu")
	screen._on_cash_pressed(0)
	await frames(4)
	check(player.gems == 15 and economy.money == 10000, "ikinci dokunuş çevirdi (gem %d, ₺ %d)" % [player.gems, economy.money])
	var popup: RewardPopup = screen.get("_reward_popup")
	check(popup.visible, "ödül penceresi açıldı")
	popup.close()
	await frames(40)

	screen.set("_confirm_at", Time.get_ticks_msec() - 10000)   # eski onay: süresi geçmiş
	screen.set("_confirm_offer", 0)
	screen._on_cash_pressed(0)
	await frames(2)
	check(player.gems == 15, "süresi geçen onay yeniden onay ister")
	screen.set("_confirm_offer", -1)

	screen._on_cash_pressed(1)   # 50 GEM, 15 var
	await frames(4)
	check(player.gems == 15 and economy.money == 10000, "gem yetmedi: hiçbir şey değişmedi")
	check(screen.get("_tab") == GemStoreScreen.TAB_GEMS, "GEM AL sekmesine geçti")
	var notice: Control = screen.get("_notice")
	check(notice.visible and (screen.get("_notice_label") as Label).text.begins_with("GEM YETERSİZ"),
		"GEM YETERSİZ bildirimi")
	hud.router.close_all()
	await frames(20)


func _find_label(node: Node, text: String) -> Label:
	for n: Node in node.find_children("*", "Label", true, false):
		if (n as Label).text == text and (n as Label).is_visible_in_tree():
			return n as Label
	return null


func _find_button(node: Node, text: String) -> Button:
	for n: Node in node.find_children("*", "Button", true, false):
		if (n as Button).text == text:
			return n as Button
	return null
