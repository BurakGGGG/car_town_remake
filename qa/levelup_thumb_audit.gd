extends SceneTree
## SEVİYE ATLADIN dekor küçük resmi denetimi: 2–30 her seviyenin dekor kartındaki ilk 3 eşyayı DecorThumbs ile üretir,
## resim yok / boş (saydam) olanları yazar. Kullanım: godot-4 --path . --script res://qa/levelup_thumb_audit.gd

const OUT: String = "/home/burak/Projects/ct_shots/levelup_thumbs/"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var thumbs: DecorThumbs = DecorThumbs.new()
	root.add_child(thumbs)
	var shown: Dictionary = {}
	for level: int in range(2, 31):
		for entry: Dictionary in LevelUnlocks.between(level - 1, level):
			if int(entry["kind"]) != LevelUnlocks.Kind.DECOR:
				continue
			var items: Array[StringName] = entry["items"]
			var line: PackedStringArray = PackedStringArray()
			for i: int in items.size():
				var id: StringName = items[i]
				var first: bool = i < 3
				var placeable: bool = GarageDecor.is_placeable(id)
				var built: bool = DecorBuilder.build_placeable(id) != null
				line.append("%s%s[%s%s]" % ["*" if first else "", id, "P" if placeable else "-", "B" if built else "-"])
				if first:
					shown[id] = level
			print("SV %2d: %s" % [level, " ".join(line)])
	for id: StringName in shown:
		thumbs.request(id)
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		await process_frame
		var pending: bool = false
		for id: StringName in shown:
			if DecorThumbs.cached(id) == null and DecorBuilder.build_placeable(id) != null:
				pending = true
		if not pending:
			break
	var bad: int = 0
	for id: StringName in shown:
		var tex: Texture2D = DecorThumbs.cached(id)
		var coverage: float = 0.0
		if tex:
			var img: Image = tex.get_image()
			var opaque: int = 0
			for y: int in range(0, img.get_height(), 2):
				for x: int in range(0, img.get_width(), 2):
					if img.get_pixel(x, y).a > 0.1:
						opaque += 1
			coverage = float(opaque) / float((img.get_width() / 2) * (img.get_height() / 2))
		var verdict: String = "OK" if tex and coverage > 0.02 else "SORUN"
		if verdict != "OK":
			bad += 1
		print("%s sv%d %s resim=%s kaplama=%.1f%%" % [verdict, shown[id], id, tex != null, coverage * 100.0])
		if tex:
			DirAccess.make_dir_recursive_absolute(OUT)
			tex.get_image().save_png(OUT + "sv%02d_%s.png" % [shown[id], id])
	print("SORUNLU %d / %d" % [bad, shown.size()])
	quit(0)
