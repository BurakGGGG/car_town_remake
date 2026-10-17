extends SceneTree
## PİKSEL BAYRAKLAR önizleme: ProfileCatalog.FLAGS'taki bütün bayraklar, en yakın komşu büyütmeyle tek sayfa.
## godot-4 --headless --path . --script res://qa/flag_sheet.gd -- <çıktı.png> [ölçek]

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else OS.get_environment("HOME") + "/Projects/ct_shots/avatars/bayraklar.png"
	var scale: int = int(args[1]) if args.size() > 1 else 6
	var codes: Array[String] = ProfileCatalog.flag_codes()
	var cols: int = 8
	var cell: Vector2i = Vector2i((FlagIcon.W + 2) * scale + 24, (FlagIcon.H + 2) * scale + 24)
	var rows: int = ceili(float(codes.size()) / cols)
	var sheet: Image = Image.create(cols * cell.x, rows * cell.y, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("F3E8CF"))
	for i: int in codes.size():
		var flag: Image = FlagIcon.image(codes[i])
		flag.resize(flag.get_width() * scale, flag.get_height() * scale, Image.INTERPOLATE_NEAREST)
		var at: Vector2i = Vector2i((i % cols) * cell.x + 12, (i / cols) * cell.y + 12)
		sheet.blend_rect(flag, Rect2i(Vector2i.ZERO, flag.get_size()), at)
	sheet.save_png(out)
	print(out, "  ", codes.size(), " bayrak")
	quit()
