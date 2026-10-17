extends SceneTree
## PROFİL PORTRELERİ: tools/avatars/src/*.svg → PNG (Godot'un kendi SVG okuyucusuyla; sistemde rsvg / inkscape
## gerekmez). Kaynak klasörde .gdignore var: SVG'ler oyuna doku olarak alınmaz, yalnız bu betik okur.
## Kullanım: godot-4 --headless --path . --script res://tools/avatars/render_avatars.gd -- <çıktı_klasörü> [boyut] [ad]
## Boyut varsayılan 512 (kaynak 512 tuval). `ad` verilirse yalnız o dosya (uzantısız).

const SRC: String = "res://tools/avatars/src/"
const CANVAS: float = 512.0


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_avatars: çıktı klasörü gerekli")
		quit(1)
		return
	var out_dir: String = args[0]
	var size: int = int(args[1]) if args.size() > 1 else int(CANVAS)
	var only: String = args[2] if args.size() > 2 else ""
	DirAccess.make_dir_recursive_absolute(out_dir)
	var count: int = 0
	for file: String in DirAccess.get_files_at(SRC):
		if file.get_extension() != "svg" or (only != "" and file.get_basename() != only):
			continue
		var image: Image = Image.new()
		var err: Error = image.load_svg_from_string(FileAccess.get_file_as_string(SRC + file), float(size) / CANVAS)
		if err != OK:
			push_error("render_avatars: %s okunamadı (%s)" % [file, error_string(err)])
			continue
		var path: String = out_dir.path_join(file.get_basename() + ".png")
		image.save_png(path)
		print("%s  %dx%d" % [path, image.get_width(), image.get_height()])
		count += 1
	quit(0 if count > 0 else 1)
