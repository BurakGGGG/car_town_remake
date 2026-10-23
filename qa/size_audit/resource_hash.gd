extends SceneTree
## Kaynakların İÇERİK özeti (kayıpsız paket küçültmenin doğrulaması, 2026-10-23): listedeki her yolu yükler, sahnenin
## paketlenmiş durumunu nesneleriyle (mesh köşe / indeks / LOD verisi, materyal özellikleri) var_to_bytes_with_objects
## ile baytlara döker ve MD5'ini yazar. tools/size/rscc_repack.py öncesi ve sonrası iki çıktı aynı olmalı.
## Kullanım: godot-4 --headless --path . --script res://qa/size_audit/resource_hash.gd -- <liste.txt> <çıktı.txt>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var paths: PackedStringArray = FileAccess.get_file_as_string(args[0]).strip_edges().split("\n")
	var out: FileAccess = FileAccess.open(args[1], FileAccess.WRITE)
	var failed: int = 0
	for path: String in paths:
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		if res == null:
			out.store_line("%s\tYÜKLENEMEDİ" % path)
			failed += 1
			continue
		var data: Variant = res.get("_bundled") if res is PackedScene else res
		out.store_line("%s\t%s" % [path, _md5(var_to_bytes_with_objects(data))])
	out.close()
	print("özet: %d kaynak, %d yüklenemedi" % [paths.size(), failed])
	quit(1 if failed > 0 else 0)


func _md5(bytes: PackedByteArray) -> String:
	var ctx: HashingContext = HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	ctx.update(bytes)
	return ctx.finish().hex_encode()
