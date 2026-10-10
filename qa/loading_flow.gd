extends SceneTree
## YÜKLEME EKRANI AKIŞI: ilk sahneden (yükleme ekranı) oyuna geçiş — zaman çizelgesi, kareler,
## sonunda geçerli sahnenin Main olması ve yükleme ekranının kalkması.
## Kullanım: tools/qa_isolated.sh res://qa/loading_flow.gd --resolution 1152x648 [-- en|es]
const OUT: String = "/home/burak/Projects/ct_shots/loading/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		var cfg: ConfigFile = ConfigFile.new()
		cfg.load(GameSettings.PATH)
		cfg.set_value("general", "language", args[0])
		cfg.save(GameSettings.PATH)
	_run.call_deferred()


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await process_frame
	await process_frame
	print("AKIŞ ilk sahne: %s" % current_scene.name if current_scene else "yok")
	var shots: int = 0
	var main_at: int = -1
	var gone_at: int = -1
	var worst: int = 0
	while Time.get_ticks_msec() - t0 < 12000:
		var f0: int = Time.get_ticks_msec()
		await process_frame
		worst = maxi(worst, Time.get_ticks_msec() - f0)
		var loading: Node = root.find_child("LoadingScreen", false, false)
		if main_at < 0 and current_scene and current_scene.name != "LoadingScreen":
			main_at = Time.get_ticks_msec() - t0
		if loading and shots < 3 and Time.get_ticks_msec() - t0 > 150 + shots * 250:
			_shot("yukleme_%d" % shots)
			shots += 1
		if main_at >= 0 and loading == null and gone_at < 0:
			gone_at = Time.get_ticks_msec() - t0
			for i: int in 30:
				await process_frame
			_shot("oyun")
			break
	print("AKIŞ oyun sahnesi geçerli oldu: %d ms | yükleme ekranı kalktı: %d ms | en uzun kare: %d ms | geçerli sahne: %s | kök çocukları: %s" % [
		main_at, gone_at, worst, current_scene.name if current_scene else "yok",
		root.get_children().map(func(n: Node) -> String: return String(n.name))])
	quit(0)
