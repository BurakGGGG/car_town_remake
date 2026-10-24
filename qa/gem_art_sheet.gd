extends SceneTree
## MARKET KART ÇİZİMLERİ: her GemPackArt türü iki boyda (kartta 166x132, büyük 332x264), sabit animasyon anında (_t),
## animasyon anı başına bir sayfa (<çıktı>_<an>.png). Çizim yöntemi değişince ÖNCE / SONRA sayfaları piksel piksel
## kıyaslanır; konsola sayfanın çizim çağrısı sayısı yazar.
## Kullanım: godot-4 --path . --display-driver x11 --resolution 640x360 -s res://qa/gem_art_sheet.gd -- <çıktı öneki>

const KINDS: Array[int] = [GemPackArt.Kind.STARTER, GemPackArt.Kind.HANDFUL, GemPackArt.Kind.POUCH, GemPackArt.Kind.CHEST,
	GemPackArt.Kind.VAULT, GemPackArt.Kind.CASH_1, GemPackArt.Kind.CASH_2, GemPackArt.Kind.CASH_3, GemPackArt.Kind.CASH_4,
	GemPackArt.Kind.FREE, GemPackArt.Kind.INSTAGRAM, GemPackArt.Kind.TIKTOK, GemPackArt.Kind.BUTTON]
const TIMES: Array[float] = [0.4, 2.1]
const PAGE: Vector2i = Vector2i(1400, 1360)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var prefix: String = OS.get_cmdline_user_args()[0]
	for t: float in TIMES:
		var vp: SubViewport = SubViewport.new()
		vp.size = PAGE
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var bg: ColorRect = ColorRect.new()
		bg.color = Color(0.93, 0.89, 0.8)
		bg.size = Vector2(PAGE)
		vp.add_child(bg)
		for i: int in KINDS.size():
			_add(vp, KINDS[i], Vector2(166, 132), Vector2(4 + (i % 8) * 172, 4 + (i / 8) * 138), t)
			_add(vp, KINDS[i], Vector2(332, 264), Vector2(4 + (i % 4) * 338, 290 + (i / 4) * 270), t)
		for f: int in 4:
			await process_frame
		await RenderingServer.frame_post_draw
		var calls: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		vp.get_texture().get_image().save_png("%s_%.1f.png" % [prefix, t])
		print("SAYFA t=%.1f çizim çağrısı %d" % [t, calls])
		vp.queue_free()
		await process_frame
	quit()


func _add(vp: SubViewport, kind: int, sz: Vector2, at: Vector2, t: float) -> void:
	var art: GemPackArt = GemPackArt.new()
	art.kind = kind as GemPackArt.Kind
	art.size = sz
	art.position = at
	if kind == GemPackArt.Kind.CHEST or kind == GemPackArt.Kind.CASH_3:
		art.badge_text = "+%30"
	vp.add_child(art)
	art.set_process(false)
	art.set("_t", t)
	if kind == GemPackArt.Kind.BUTTON:
		art.call("_animate_button")
	art.queue_redraw()
