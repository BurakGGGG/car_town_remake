extends SceneTree
## ÇERÇEVE SAYFASI: yeni çerçeveler gerçek AvatarView ile üç boyda (profil kartı 140, HUD 76, liste 48), taşan süsler
## dahil. Hareketli çerçeveler birkaç karede ilerletilip çekilir.
## godot-4 --path . --script res://qa/frame_sheet.gd -- [çerçeve,çerçeve,...] [avatar]   (ekrandan bağımsız SubViewport)
## Çıktı: ~/Projects/ct_shots/frames_v2/cerceveler.png
const OUT: String = "/home/burak/Projects/ct_shots/frames_v2/"
const NEW: Array[String] = ["hazard", "tire", "wheel", "stripe", "gauge", "wood", "rust", "copper", "chrome", "velvet",
	"laurel", "crown", "winged", "flame_cup", "diamond_crown"]
const SIZES: Array[float] = [140.0, 76.0, 48.0]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var ids: Array[String] = NEW
	if args.size() > 0 and not args[0].is_empty():
		ids.assign(args[0].split(","))
	var av: String = args[1] if args.size() > 1 else "p05"
	var vp: SubViewport = SubViewport.new()
	vp.size = Vector2i(1440, 1400)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("EFE7D8")
	bg.size = Vector2(vp.size)
	vp.add_child(bg)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.position = Vector2(24, 20)
	grid.add_theme_constant_override(&"h_separation", 40)
	grid.add_theme_constant_override(&"v_separation", 8)
	bg.add_child(grid)
	for id: String in ids:
		var cell: VBoxContainer = VBoxContainer.new()
		var label: Label = Label.new()
		label.text = "%s · %s" % [Loc.t(String(ProfileCatalog.frame(id).get("name", id))), id]
		label.add_theme_color_override(&"font_color", Color("33262F"))
		label.add_theme_font_size_override(&"font_size", 18)
		cell.add_child(label)
		var row: HBoxContainer = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_BEGIN
		row.add_theme_constant_override(&"separation", 0)
		for d: float in SIZES:
			var pad: MarginContainer = MarginContainer.new()   # taşan süse yer
			var m: int = int(d * 0.32)
			for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
				pad.add_theme_constant_override(side, m)
			var view: AvatarView = AvatarView.new()
			view.custom_minimum_size = Vector2(d, d)
			view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pad.add_child(view)
			row.add_child(pad)
			view.show_avatar(ProfileCatalog.preset_texture(av), true, id, "TR" if d > 100.0 else "")
		cell.add_child(row)
		grid.add_child(cell)
	for i: int in 50:
		await process_frame
	RenderingServer.force_draw()
	await process_frame
	vp.get_texture().get_image().save_png(OUT + "cerceveler.png")
	print("görüntü: ", OUT + "cerceveler.png")
	quit(0)
