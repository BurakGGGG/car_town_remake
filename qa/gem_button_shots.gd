extends SceneTree
## GEM AL DÜĞMESİ GÖRSEL DENETİMİ: düğme animasyonun belirli anlarına (_t) sabitlenir, bölgesi kaydedilir.
## Çizim yöntemi değişince ÖNCE / SONRA çekimleri piksel piksel kıyaslanır (rozetli ve rozetsiz).
## Kullanım: tools/qa_isolated.sh res://qa/gem_button_shots.gd --display-driver x11 --disable-vsync \
##   --resolution 1152x648 -- <etiket>
const OUT: String = "/home/burak/Projects/ct_shots/gem_button/"
const TIMES: Array[float] = [0.0, 0.35, 0.6, 0.95, 1.7, 2.3, 2.6, 3.25, 3.5, 3.85, 5.1, 7.0]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "shot"
	change_scene_to_file("res://Main.tscn")
	for i: int in 200:
		await process_frame
	var button: GemShopButton = current_scene.find_child("GemShopButton", true, false) as GemShopButton
	var art: GemPackArt = button.find_children("*", "GemPackArt", true, false)[0] as GemPackArt
	button.set("_next_pulse", 1e9)   # nefes alma tween'i çekimi bozmasın
	button.scale = Vector2.ONE
	for badge: bool in [false, true]:
		button.show_badge = badge
		for t: float in TIMES:
			button.set("_t", t)
			art.set("_t", t)
			button._process(0.0)
			art._process(0.0)
			for i: int in 3:
				await process_frame
			RenderingServer.force_draw()
			var img: Image = root.get_texture().get_image()
			var rect: Rect2i = Rect2i(Vector2i(button.get_global_rect().position) - Vector2i(14, 14),
				Vector2i(button.get_global_rect().size) + Vector2i(28, 28))
			img.get_region(rect).save_png(OUT + "%s_%s_t%.2f.png" % [tag, "rozet" if badge else "duz", t])
	print("GEMBTN %d çekim → %s" % [TIMES.size() * 2, OUT])
	quit(0)
