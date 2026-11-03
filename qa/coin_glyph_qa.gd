extends SceneTree
## ALTIN PARA GLİFİ QA (2026-11-03): ₺ karakteri yazılarda altın para olarak çiziliyor mu (FontFallback → autoyard_coin.ttf,
## COLR renk katmanları) — koyu yazı (plaka), konturlu beyaz yazı, farklı boylar, düğme. Kare
## ~/Projects/ct_shots/para_simgesi/deneme.png. Kullanım: tools/qa_isolated.sh res://qa/coin_glyph_qa.gd --resolution 1100x620
const OUT: String = "/home/burak/Projects/ct_shots/para_simgesi/"


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void: quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	FontFallback.install()
	var theme: Theme = load("res://ui/theme/hud_theme.tres") as Theme
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("7d8187")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var col: VBoxContainer = VBoxContainer.new()
	col.theme = theme
	col.position = Vector2(24, 16)
	col.add_theme_constant_override(&"separation", 10)
	root.add_child(col)
	var plate: PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override(&"panel", PetCloseupScreen.plate_box())
	col.add_child(plate)
	var inner: VBoxContainer = VBoxContainer.new()
	plate.add_child(inner)
	for row: Array in [[&"HudPlateTitle", 30, "12.500 ₺"], [&"HudInkValue", 18, "TAMİRDEN 3.000 ₺ KAZAN · +480 ₺   +60 XP"],
			[&"HudInkCaption", 12, "OTOPARK GÜNLÜK 2.500 ₺ · 1,2 b ₺"], [&"HudInkValue", 14, "₺ HARCA · 95.000 ₺"]]:
		var l: Label = Label.new()
		l.theme_type_variation = row[0]
		l.add_theme_font_size_override(&"font_size", row[1])
		l.text = row[2]
		inner.add_child(l)
	for size: int in [16, 22, 34]:
		var o: Label = Label.new()
		o.theme_type_variation = &"HudOutlined"
		o.add_theme_font_size_override(&"font_size", size)
		o.text = "+%s ₺  KAZANDIN" % Hud.format_thousands(15000)
		col.add_child(o)
	var b: PlateButton = PlateButton.new()
	b.theme_type_variation = &"HudPlate"
	b.text = "TAMİR ALANI 2\nAL 15.000 ₺"
	b.custom_minimum_size = Vector2(280, 70)
	col.add_child(b)
	for i: int in 6:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + "deneme.png")
	print("QA kare deneme")
	quit(0)
