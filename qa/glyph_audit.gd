extends SceneTree
## Oyun metinlerinde varsayılan yazı tipinde (ThemeDB.fallback_font) OLMAYAN karakterler.
## Eksik karakter → Godot sistem yazı tiplerinde yedek arar (yavaş, cihaza göre farklı görünüm).
func _initialize() -> void:
	var font: Font = ThemeDB.fallback_font
	var chars: Dictionary = {}
	var sources: Array[String] = ["res://locale/strings.json", "res://locale/en.json", "res://locale/es.json",
		"res://vehicles/crates.json", "res://decor/decorations.json", "res://vehicles/cars.json"]
	var texts: Array[String] = []
	for path: String in sources:
		texts.append(FileAccess.get_file_as_string(path))
	# Kod içindeki dizgeler (Loc'a girmeyen semboller: ★, →, ✓ …)
	for dir: String in ["res://ui", "res://gameplay", "res://world", "res://vfx", "res://race", "res://traffic"]:
		_collect(dir, texts)
	for text: String in texts:
		for i: int in text.length():
			var c: int = text.unicode_at(i)
			if c < 128:
				continue
			if not font.has_char(c):
				chars[c] = int(chars.get(c, 0)) + 1
	var line: String = ""
	for c: int in chars:
		line += "%s U+%04X (%d)  " % [String.chr(c), c, chars[c]]
	print("YAZI TİPİ: ", font.get_font_name(), " | EKSİK: ", line)
	quit()

func _collect(dir: String, out: Array[String]) -> void:
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".gd"):
			out.append(FileAccess.get_file_as_string(dir.path_join(f)))
	for sub: String in d.get_directories():
		_collect(dir.path_join(sub), out)
