extends SceneTree
## DİL DESTEĞİ — Türkçe / İngilizce / İspanyolca: çeviri yükleme, biçimli metinler, katalog metinleri,
## bin ayırıcısı, dil seçimi ve kalıcılığı, ekranlarda çevrilmemiş metin kalmaması.
## Çalıştırma: tools/run_tests.sh locale_test

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
	var settings: GameSettings = get_first_node_in_group("settings")
	var hud: Hud = main.find_child("HUD", true, false)
	settings.reload_on_language_change = false

	print("== TÜRKÇE (kaynak dil) ==")
	check(Loc.current() == "tr", "test dili Türkçe (run_tests.sh settings.cfg)")
	check(Loc.t("KAPAT") == "KAPAT", "Türkçede metin olduğu gibi")
	check(Hud.format_thousands(1234567) == "1.234.567", "TR bin ayırıcısı nokta")

	print("== İNGİLİZCE ==")
	settings.set_language("en")
	check(Loc.current() == "en" and settings.language == "en", "dil İngilizce")
	check(Loc.t("KAPAT") == "CLOSE", "KAPAT → CLOSE")
	check(Loc.t("%s TAMİR YAP") % 20 == "MAKE 20 REPAIRS", "biçimli metin: önce çevir sonra biçimle")
	check(MissionCatalog.text_of(&"rep_e", 25) == "MAKE 25 REPAIRS", "görev metni İngilizce")
	check(MissionCatalog.text_of(&"job:brakes", 3) == "COMPLETE 3 JOBS: BRAKES", "iş türü görevi: %s" % MissionCatalog.text_of(&"job:brakes", 3))
	check(GarageValue.rank_name(1) == "MAKESHIFT GARAGE", "rütbe adı İngilizce")
	check(Loc.t(String(GarageDecor.get_item(&"sofa").get("title", ""))) == "SOFA", "dekor kataloğu (JSON) İngilizce")
	check(Hud.format_thousands(1234567) == "1,234,567", "EN bin ayırıcısı virgül")
	var label: Label = Label.new()
	label.text = "GÖREVLER"
	root.add_child(label)
	await frames(2)
	check(label.get_text() == "GÖREVLER" and label.atr("GÖREVLER") == "TASKS", "Control kendi metnini çevirir (atr)")
	label.queue_free()

	print("== İSPANYOLCA ==")
	settings.set_language("es")
	check(Loc.t("KAPAT") == "CERRAR", "KAPAT → CERRAR")
	check(Loc.t("%s YARIŞ KAZAN") % 3 == "GANA 3 CARRERAS", "biçimli metin İspanyolca")
	check(Hud.format_thousands(1500) == "1.500", "ES bin ayırıcısı nokta")
	check(Loc.t("BU METİN YOK") == "BU METİN YOK", "çevirisi olmayan metin olduğu gibi döner")

	print("== KALICILIK ==")
	var copy: GameSettings = GameSettings.new()
	copy.load_settings()
	check(copy.language == "es", "dil seçimi settings.cfg'ye yazıldı")
	copy.free()
	check(Loc.LANGUAGES.has(Loc.device_language()), "cihaz dili desteklenmiyorsa İngilizceye düşer")

	print("== EKRANLAR: çevrilmemiş Türkçe kalmasın ==")
	# Gerçek akış: dil değişince sahne yeniden kurulur (kaydedilir, yeniden yüklenir)
	settings.set_language("tr")
	settings.reload_on_language_change = true
	settings.set_language("en")
	await frames(30)
	current_scene = root.get_node("World") if root.has_node("World") else current_scene
	hud = current_scene.find_child("HUD", true, false)
	settings = get_first_node_in_group("settings")
	check(hud != null and Loc.current() == "en", "dil değişince sahne yeni dille yeniden kuruldu")
	settings.reload_on_language_change = false
	var leftovers: Array[String] = []
	for id: StringName in [&"quests", &"settings", &"profile", &"garage_value", &"mastery"]:
		hud.router.close_all()
		await frames(4)
		hud.router.open(id)
		await frames(8)
		var screen: Control = hud.router.screen(id)
		for node: Node in screen.find_children("*", "", true, false):
			var text: String = ""
			if node is Label:
				text = (node as Label).text
			elif node is Button:
				text = (node as Button).text
			else:
				continue
			if not (node as Control).is_visible_in_tree() or (node as Control).auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
				continue
			var shown: String = (node as Control).atr(text)
			if RegEx.create_from_string("[ÇĞİÖŞÜçğıöşü]").search(shown):
				leftovers.append("%s: %s" % [id, shown.replace("\n", " / ")])
	for line: String in leftovers:
		print("     kalan: ", line)
	check(leftovers.is_empty(), "İngilizce ekranlarda Türkçe harf kalmadı (%d)" % leftovers.size())
	settings.set_language("tr")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
