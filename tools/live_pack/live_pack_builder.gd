class_name LivePackBuilder
## İÇERİK PAKETİ KURUCU (oyunda değil: tools/ dışa aktarılmaz). Kaynak klasör tools/live_pack/content/<kimlik>/:
##   pack.json   {"banner": "banner.png" (isteğe bağlı), "decor": [decorations.json kaydı + "model": "models/x.glb"
##               (klasöre göre ya da res:// yolu) + "title": {dil} + "event_only": true/false]}
##   models/     .glb modeller — Godot editörü (ya da `godot --headless --import`) içe aktarmış olmalı
##   banner.png  etkinlik panosunun afişi (ham PNG; önerilen 960x240)
## Çıktı: Godot .pck — oyunun bağlayacağı yollar res://live/<kimlik>/… (oyundaki LivePacks):
##   res://live/<kimlik>/pack.json, banner.png (ham), models/x.glb.import (yönlendirme) ve
##   res://live/<kimlik>/.imported/<içe aktarılmış dosya> (yönlendirmenin gösterdiği .scn / .ctex).
## Paket yalnızca İÇERİK taşır: .gd / .gdc kabul edilmez; modelin bağımlılığı paketin dışındaysa oyunun kendi dosyası olmalı.
## Kullanım: tools/live_pack/build_pack.sh <kimlik>   (testler build() çağırır)

const CONTENT: String = "res://tools/live_pack/content/"
const KINDS: Array[String] = ["luxury", "workshop", "lounge", "wall_item", "yard", "plant"]


## Kaynak tanımdan paketi kurar. source: pack.json'un sözlüğü (model yolları `base`e göre); out: .pck'nin yazılacağı yer
## (mutlak ya da user://). Dönen: {ok, error, sha256, size, files, decor}.
static func build(pack_id: String, source: Dictionary, base: String, out: String) -> Dictionary:
	if not RegEx.create_from_string("^[a-z0-9_]{1,40}$").search(pack_id):
		return _fail("kimlik küçük harf / rakam / _ olmalı (en çok 40)")
	var root: String = "res://live/%s/" % pack_id
	var packer: PCKPacker = PCKPacker.new()
	if packer.pck_start(out) != OK:
		return _fail("çıktı açılamadı: %s" % out)
	var files: PackedStringArray = PackedStringArray()
	var manifest: Dictionary = {"id": pack_id, "decor": []}
	var seen: Dictionary = {}
	for raw: Variant in source.get("decor", []):
		if not raw is Dictionary:
			return _fail("decor listesinde sözlük olmayan kayıt")
		var item: Dictionary = (raw as Dictionary).duplicate(true)
		var item_id: String = str(item.get("id", ""))
		if item_id.is_empty() or seen.has(item_id) or not GarageDecor.get_item(StringName(item_id)).is_empty():
			return _fail("eşya kimliği boş, yinelenmiş ya da oyunda zaten var: '%s'" % item_id)
		if not KINDS.has(str(item.get("kind", ""))):
			return _fail("'%s': tür %s olmalı" % [item_id, ", ".join(KINDS)])
		seen[item_id] = true
		var model: String = str(item.get("model", ""))
		var src: String = model if model.begins_with("res://") else base.path_join(model)
		var target: String = root + "models/" + src.get_file()
		var error: String = _add_imported(packer, src, target, root, files)
		if not error.is_empty():
			return _fail("'%s': %s" % [item_id, error])
		item.erase("model")
		item["scene_path"] = target
		(manifest["decor"] as Array).append(item)
	var banner: String = str(source.get("banner", ""))
	if not banner.is_empty():
		var banner_src: String = banner if banner.begins_with("res://") or banner.begins_with("user://") else base.path_join(banner)
		var bytes: PackedByteArray = FileAccess.get_file_as_bytes(banner_src)
		if bytes.size() < 8 or bytes.slice(1, 4).get_string_from_ascii() != "PNG":
			return _fail("afiş PNG değil: %s" % banner_src)
		packer.add_file_from_buffer(root + "banner.png", bytes)
		files.append(root + "banner.png")
		manifest["banner"] = "banner.png"
	packer.add_file_from_buffer(root + "pack.json", JSON.stringify(manifest, "\t").to_utf8_buffer())
	files.append(root + "pack.json")
	if packer.flush() != OK:
		return _fail("paket yazılamadı")
	var size: int = FileAccess.get_file_as_bytes(out).size()
	return {"ok": true, "error": "", "sha256": FileAccess.get_sha256(out), "size": size, "files": files,
		"decor": (manifest["decor"] as Array).size()}


## İçe aktarılmış dosyayı (model / doku) pakete koyar: yönlendirme (.import) hedef yola, içe aktarılmış veri paketin
## .imported klasörüne. Bağımlılıklar oyunun kendi dosyaları olmalı.
static func _add_imported(packer: PCKPacker, src: String, target: String, root: String, files: PackedStringArray) -> String:
	if src.get_extension() in ["gd", "gdc", "cs"]:
		return "kod dosyası pakete giremez"
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(src + ".import") != OK:
		return "içe aktarılmamış (önce editörde ya da --import ile içe aktar): %s" % src
	for dep: String in ResourceLoader.get_dependencies(src):
		var path: String = dep.get_slice("::", 2) if dep.contains("::") else dep
		if path.begins_with("res://tools/") or path.begins_with("res://live/"):
			return "bağımlılık paketin dışında ve oyunda yok: %s" % path
	var dests: PackedStringArray = PackedStringArray()
	for key: String in cfg.get_section_keys("remap"):
		if not key.begins_with("path"):
			continue
		var imported: String = str(cfg.get_value("remap", key))
		var dest: String = root + ".imported/" + imported.get_file()
		if packer.add_file(dest, ProjectSettings.globalize_path(imported)) != OK:
			return "içe aktarılmış dosya okunamadı: %s" % imported
		cfg.set_value("remap", key, dest)
		dests.append(dest)
		files.append(dest)
	if dests.is_empty():
		return "yönlendirme (.import [remap] path) yok"
	if cfg.has_section_key("remap", "uid"):
		cfg.erase_section_key("remap", "uid")   # yolla yüklenir; oyunun UID tablosuna karışmasın
	cfg.set_value("deps", "source_file", target)
	cfg.set_value("deps", "dest_files", dests)
	packer.add_file_from_buffer(target + ".import", cfg.encode_to_text().to_utf8_buffer())
	files.append(target + ".import")
	return ""


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "sha256": "", "size": 0, "files": PackedStringArray(), "decor": 0}
