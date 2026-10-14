extends SceneTree
## DEKOR DESENLERİNİ PİŞİRİR → res://vfx/decor_patterns.res (DecorTextures.BAKE_PATH).
## Bütün katalog zemin desenleri ve dokulu duvar kaplamaları KODLA üretilir (DecorTextures.generate_*), tek
## bir şerit Image'a dizilir (mipmap'siz; oyun yüklerken motor üretir), anahtarlar ve sürüm meta'da durur.
## Ne zaman: kataloğa zemin deseni / dokulu kaplama eklenince ya da çizim kodu değişince (o durumda önce
## DecorTextures.GENERATOR_VERSION artırılır). Eskiyse decor_v2_test FAIL verir.
## Kullanım: godot-4 --headless --path . --script res://tools/bake_floor_patterns.gd


func _initialize() -> void:
	DecorTextures.use_bake = false
	var keys: PackedStringArray = PackedStringArray()
	var images: Array[Image] = []
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.FLOOR_PATTERN):
		keys.append(String(item["id"]))
		images.append(DecorTextures.generate_pattern(item["id"]))
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.WALL_SURFACE):
		var img: Image = DecorTextures.generate_wall(item["id"])
		if img:
			keys.append("wall:" + String(item["id"]))
			images.append(img)
	var size: int = DecorTextures.SIZE
	var strip: Image = Image.create(size, size * images.size(), false, Image.FORMAT_RGBA8)
	for i: int in images.size():
		strip.blit_rect(images[i], Rect2i(0, 0, size, size), Vector2i(0, i * size))
	strip.set_meta(&"version", DecorTextures.GENERATOR_VERSION)
	strip.set_meta(&"size", size)
	strip.set_meta(&"keys", keys)
	var err: Error = ResourceSaver.save(strip, DecorTextures.BAKE_PATH, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("bake_floor_patterns: kaydedilemedi (%d)" % err)
		quit(1)
		return
	print("bake_floor_patterns: %d görüntü (%d zemin deseni + duvar kaplamaları) → %s" % [images.size(),
		GarageDecor.items_in(GarageDecor.Kind.FLOOR_PATTERN).size(), DecorTextures.BAKE_PATH])
	quit(0)
