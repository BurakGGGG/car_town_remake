extends SceneTree
## ÖNCEDEN ÇİZİLMİŞ ARAÇ KÜÇÜK RESİMLERİ (tools/make_car_thumbs.gd → assets/cars/thumbs/):
## her katalog aracının resmi var, model / sahne değişmemiş (MD5), galeri fabrika görünümünde resmi
## dosyadan alıyor, boyalı araçta almıyor (o an çizer).
## Kullanım: tools/run_tests.sh car_thumbs_test

const MakeThumbs: GDScript = preload("res://tools/make_car_thumbs.gd")

var fails: int = 0


func check(cond: bool, what: String) -> void:
	if cond:
		print("  OK   ", what)
	else:
		fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var index: Variant = JSON.parse_string(FileAccess.get_file_as_string(MakeThumbs.INDEX))
	check(index is Dictionary, "thumbs.json okunuyor")
	if not (index is Dictionary):
		_finish()
		return
	print("== dosyalar ==")
	var missing: Array[String] = []
	var stale: Array[String] = []
	for entry: Dictionary in CarCatalog.all():
		var id: String = String(entry["id"])
		if not ResourceLoader.exists(CarGallery.BAKED_DIR + id + ".png") or not (index as Dictionary).has(id):
			missing.append(id)
		elif String(index[id]) != MakeThumbs.fingerprint(entry["scene_path"]):
			stale.append(id)
	check(missing.is_empty(), "her aracın küçük resmi var (eksikse: tools/make_car_thumbs.gd) %s" % [missing])
	check(stale.is_empty(), "küçük resimler güncel (model / sahne değiştiyse: tools/make_car_thumbs.gd <id>) %s" % [stale])

	print("== galeri ==")
	var gallery: CarGallery = CarGallery.new()
	root.add_child(gallery)
	var id: StringName = CarCatalog.all()[0]["id"]
	var scene_path: String = CarCatalog.scene_path(id)
	var appearance: CarAppearance = CarAppearance.get_for(scene_path)
	appearance.reset(scene_path)
	CarGallery._thumbnails.erase(id)
	var baked: bool = gallery._use_baked(id)
	for i: int in 300:   # resim arka planda yüklenir (ana iş parçacığı beklemez)
		if CarGallery.cached_thumbnail(id) != null:
			break
		await process_frame
	check(baked and CarGallery.cached_thumbnail(id) != null
		and CarGallery.cached_thumbnail(id).resource_path.begins_with(CarGallery.BAKED_DIR),
		"fabrika görünümü: resim dosyadan, arka planda (%s)" % id)
	CarGallery._thumbnails.erase(id)
	appearance.body_color = Color(0.9, 0.1, 0.1)
	check(not gallery._use_baked(id) and CarGallery.cached_thumbnail(id) == null, "boyalı araç: dosya kullanılmaz (o an çizilir)")
	appearance.reset(scene_path)
	gallery.free()
	_finish()


func _finish() -> void:
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
