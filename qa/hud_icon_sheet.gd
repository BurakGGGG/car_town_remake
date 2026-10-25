extends SceneTree
## HUD İKON TABLOSU — HudIcon'un bütün ikonları dört boyda (16 / 24 / 36 / 56 px), krem plaka zemininde koyu mürekkeple
## çizilir; görüntü kaydedilir ve tablonun çizim çağrısı sayısı basılır.
## Toplu çizim (ui/hud/tri_batch.gd) öncesi / sonrası piksel karşılaştırması için.
##   tools/qa_isolated.sh res://qa/hud_icon_sheet.gd --display-driver x11 --disable-vsync --resolution 1152x648 -- <etiket>
## Görüntü: /home/burak/Projects/ct_shots/hud_icons/<etiket>.png

const OUT: String = "/home/burak/Projects/ct_shots/hud_icons/"
const SIZES: Array[float] = [16.0, 24.0, 36.0, 56.0]
const INK: Color = Color("2F3236")
const CREAM: Color = Color("F3E8CF")


class Sheet:
	extends Control

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), CREAM)
		var index: int = 0
		for kind: int in HudIcon.Kind.values():
			for s: float in SIZES:
				var c: Vector2 = Vector2(32.0 + (index % 18) * 62.0, 30.0 + (index / 18) * 62.0)
				HudIcon.draw_icon(self, kind as HudIcon.Kind, c, s, INK, CREAM)
				index += 1


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	var tag: String = OS.get_cmdline_user_args()[0] if not OS.get_cmdline_user_args().is_empty() else "ikonlar"
	var sheet: Sheet = Sheet.new()
	sheet.size = Vector2(1152, 648)
	root.add_child(sheet)
	for i: int in 6:
		await process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	root.get_texture().get_image().save_png(OUT + tag + ".png")
	print("İKON TABLOSU %s: %d ikon, %d çizim çağrısı" % [tag, HudIcon.Kind.size() * SIZES.size(), calls])
	quit(0)
