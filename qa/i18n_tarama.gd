extends SceneTree
## DİL TARAMASI: oyunu verilen dilde açar, ekranları dolaşır, çevrilmeden kalan metinleri (Türkçe harf ya da
## çevirisi olduğu hâlde ham kalan kaynak metin) listeler ve ekran görüntüsü alır (user://i18n_<dil>_*.png).
## Kullanım: godot-4 --path . --resolution 1152x648 --script res://qa/i18n_tarama.gd -- en
## (1040x480 verilirse telefon ölçeği 1,35 uygulanır). Araç adları özel isimdir, listede kalabilir.
var _source: Dictionary = {}
var _lang: String = "en"
var _found: Dictionary = {}
func frames(n: int) -> void:
	for i: int in n:
		await process_frame
func _initialize() -> void:
	_lang = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "en"
	_source = JSON.parse_string(FileAccess.get_file_as_string("res://locale/strings.json"))
	_run.call_deferred()
func _scan(tag: String, node: Node) -> void:
	for n: Node in node.find_children("*", "", true, false):
		var text: String = ""
		if n is Label:
			text = (n as Label).text
		elif n is Button:
			text = (n as Button).text
		elif n is Label3D:
			text = (n as Label3D).text
		else:
			continue
		if n is Control and not (n as Control).is_visible_in_tree():
			continue
		if n.auto_translate_mode == Node.AUTO_TRANSLATE_MODE_DISABLED:
			continue
		var shown: String = n.atr(text) if n is Control else n.atr(text)
		var bad: bool = RegEx.create_from_string("[ÇĞİÖŞÜçğıöşü]").search(shown) != null or (_source.has(shown) and Loc.t(shown) != shown)
		if bad:
			_found["%s | %s" % [tag, shown.replace("\n", " / ")]] = true
func _shot(name: String) -> void:
	await frames(20)
	get_root().get_texture().get_image().save_png("user://i18n_%s_%s.png" % [_lang, name])
func _run() -> void:
	if DisplayServer.window_get_size().y < 600:
		get_root().content_scale_factor = 1.35
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(60)
	var settings: GameSettings = get_first_node_in_group("settings")
	settings.reload_on_language_change = false
	settings.set_language(_lang)
	# sahneyi yeni dille kur (gerçek akış yeniden yükler)
	main.free()
	main = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(90)
	var hud: Hud = main.find_child("HUD", true, false)
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	pp.load_state(12, 0, 300)
	get_first_node_in_group("economy").add_money(200000)
	var mm: MissionManager = get_first_node_in_group("missions")
	mm.ensure_current()
	await frames(10)
	_scan("dünya", hud)
	await _shot("00_dunya")
	hud.garage_button.pressed.emit()
	await frames(10)
	_scan("garaj paneli", hud)
	await _shot("01_garaj_panel")
	hud.garage_panel.bay_requested.emit(1)
	await frames(10)
	_scan("alan plakası", hud)
	hud.hide_bay_plate()
	for id: StringName in [&"quests", &"garage", &"showroom", &"collection", &"garage_value", &"mastery", &"profile", &"account", &"settings", &"garage_edit"]:
		hud.router.close_all()
		await frames(8)
		hud.router.open(id)
		await frames(20)
		_scan(String(id), hud.router.screen(id))
		await _shot("10_" + String(id))
		if id == &"quests":
			for tab: int in [1, 2]:
				hud.quest_screen._on_tab_pressed(tab)
				await frames(10)
				_scan("quests/%d" % tab, hud.quest_screen)
				await _shot("10_quests_%d" % tab)
	hud.router.close_all()
	await frames(5)
	_scan("dünya 3B", main)
	var keys: Array = _found.keys()
	keys.sort()
	for k: String in keys:
		print("KALAN ", k)
	print("TOPLAM KALAN %d" % keys.size())
	(get_first_node_in_group("settings") as GameSettings).set_language("tr")
	quit()
