extends SceneTree
## AÇILIŞ DÖKÜMÜ: Main.tscn yükle / örnekle / ağaca ekle (_ready zinciri) ve ilk karelerin süreleri.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/startup_profile.gd --resolution 1152x648
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var t0: int = Time.get_ticks_usec()
	var packed: PackedScene = load("res://Main.tscn")
	var t1: int = Time.get_ticks_usec()
	var main: Node = packed.instantiate()
	var t2: int = Time.get_ticks_usec()
	root.add_child(main)
	current_scene = main
	var t3: int = Time.get_ticks_usec()
	print("AÇILIŞ load %.0f ms | instantiate %.0f ms | add_child (_ready'ler) %.0f ms" % [(t1 - t0) / 1000.0, (t2 - t1) / 1000.0, (t3 - t2) / 1000.0])
	var line: String = "AÇILIŞ ilk kareler:"
	for i: int in 12:
		var f0: int = Time.get_ticks_usec()
		await process_frame
		line += " %.0f" % ((Time.get_ticks_usec() - f0) / 1000.0)
	print(line)
	var save: SaveManager = get_first_node_in_group("save_manager")
	var decor_view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	for i: int in 2:
		var s0: int = Time.get_ticks_usec()
		save.load_game()
		var s1: int = Time.get_ticks_usec()
		decor_view.refresh()
		var s2: int = Time.get_ticks_usec()
		print("AÇILIŞ load_game() yeniden: %.0f ms | dekor refresh tek başına: %.0f ms" % [(s1 - s0) / 1000.0, (s2 - s1) / 1000.0])
		await process_frame
	quit(0)
