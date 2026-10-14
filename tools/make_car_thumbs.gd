extends SceneTree
## ARAÇ KÜÇÜK RESİMLERİNİ ÖNCEDEN ÇİZER → res://assets/cars/thumbs/<id>.png (CarGallery.BAKED_DIR).
## Oyunun kendi çizim kodu kullanılır (CarGallery._render_thumbnails, fabrika görünümü): oyunda o an çizilen
## resimle aynıdır. thumbs.json her aracın model / sahne dosyalarının MD5'ini tutar; vehicle_asset_test
## model değişip resim eskiyince FAIL verir.
## Ne zaman: kataloğa araç eklenince ya da araç modeli / sahnesi değişince. Sonra --import (yeni PNG'ler).
## Kullanım (PENCERELİ — başsızda çizim yok):
##   godot-4 --path . --display-driver x11 --disable-vsync --resolution 640x360 \
##     --script res://tools/make_car_thumbs.gd [-- <araç_id> ...]
##   godot-4 --headless --path . --import

const OUT: String = "res://assets/cars/thumbs/"
const INDEX: String = "res://assets/cars/thumbs/thumbs.json"


func _initialize() -> void:
	_run.call_deferred()


## Resmi belirleyen dosyalar: araç sahnesi (.tscn) ve bağımlılıklarındaki modeller (.glb).
static func fingerprint(scene_path: String) -> String:
	var parts: PackedStringArray = PackedStringArray([FileAccess.get_md5(scene_path)])
	for dep: String in ResourceLoader.get_dependencies(scene_path):
		var path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if path.ends_with(".glb"):
			parts.append(FileAccess.get_md5(path))
	return ",".join(parts)


func _run() -> void:
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var index: Dictionary = {}
	if FileAccess.file_exists(INDEX):
		var old: Variant = JSON.parse_string(FileAccess.get_file_as_string(INDEX))
		if old is Dictionary:
			index = old
	var gallery: CarGallery = CarGallery.new()
	root.add_child(gallery)
	var done: int = 0
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = entry["id"]
		if not wanted.is_empty() and not wanted.has(String(id)):
			continue
		var scene_path: String = entry["scene_path"]
		CarAppearance.get_for(scene_path).reset(scene_path)
		CarGallery._thumbnails.erase(id)
		var batch: Array[StringName] = [id]
		await gallery._render_thumbnails(batch)
		var texture: Texture2D = CarGallery._thumbnails.get(id)
		if texture == null:
			push_error("make_car_thumbs: %s çizilemedi" % id)
			continue
		var image: Image = texture.get_image()
		var err: Error = image.save_png(ProjectSettings.globalize_path(OUT + String(id) + ".png"))
		if err != OK:
			push_error("make_car_thumbs: %s kaydedilemedi (%d)" % [id, err])
			continue
		index[String(id)] = fingerprint(scene_path)
		done += 1
	var file: FileAccess = FileAccess.open(INDEX, FileAccess.WRITE)
	file.store_string(JSON.stringify(index, "\t", true))
	file.close()
	print("make_car_thumbs: %d araç → %s (sonra: godot-4 --headless --path . --import)" % [done, OUT])
	quit(0)
