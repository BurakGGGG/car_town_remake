extends SceneTree
## İçerik paketini kurar (LivePackBuilder): tools/live_pack/content/<kimlik>/pack.json → <çıktı>/<kimlik>.pck
## godot --headless --path . --script res://tools/live_pack/build_pack.gd -- <kimlik> <çıktı klasörü (mutlak)>


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("kullanım: -- <kimlik> <çıktı klasörü>")
		quit(2)
		return
	var pack_id: String = args[0]
	var base: String = LivePackBuilder.CONTENT + pack_id
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(base.path_join("pack.json")))
	if not parsed is Dictionary:
		printerr("PAKET KURULAMADI: %s/pack.json yok ya da JSON değil" % base)
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var out: String = args[1].path_join(pack_id + ".pck")
	var result: Dictionary = LivePackBuilder.build(pack_id, parsed, base, out)
	if not bool(result["ok"]):
		printerr("PAKET KURULAMADI: %s" % result["error"])
		quit(1)
		return
	var sidecar: FileAccess = FileAccess.open(args[1].path_join(pack_id + ".json"), FileAccess.WRITE)
	sidecar.store_string(JSON.stringify({"id": pack_id, "sha256": result["sha256"], "size": result["size"],
		"decor": result["decor"], "built_at": int(Time.get_unix_time_from_system())}, "\t"))
	sidecar.close()
	print("PAKET HAZIR: %s" % out)
	print("  eşya: %d · boyut: %d bayt · sha256: %s" % [result["decor"], result["size"], result["sha256"]])
	for file: String in result["files"]:
		print("  " + file)
	quit(0)
