extends SceneTree
## ALT BAR TASLAKLARI için referans (2026-10-23, kullanıcı: "alt barı daha güzel yap, en az 5 tasarım"): telefon ölçeğinde
## (content_scale 1,35) dünya görüntüsü — bugünkü alt barla (simdi.png) ve alt barsız (temiz.png) — ve HUD ikonlarının
## maskeleri: her ikon siyah ve beyaz zeminde iki kez çizilir (oyuk yerler zeminin renginde), iki çizimin farkından
## saydamlık çıkarılır (tools: python, bu betik yalnız siyah_/beyaz_ çizimlerini yazar).
## Kullanım: CT_NO_TUTORIAL=1 QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/alt_bar_ref.gd --display-driver x11 \
##   --resolution 1440x648 -- <klasör>

const ICONS: Dictionary = {
	"garage": HudIcon.Kind.GARAGE, "car": HudIcon.Kind.CAR, "shop": HudIcon.Kind.SHOP, "helmet": HudIcon.Kind.HELMET,
	"map": HudIcon.Kind.MAP, "gem": HudIcon.Kind.GEM, "coin": HudIcon.Kind.COIN, "wrench": HudIcon.Kind.WRENCH,
	"trophy": HudIcon.Kind.TROPHY, "flag": HudIcon.Kind.FLAG, "camera": HudIcon.Kind.CAMERA, "gear": HudIcon.Kind.GEAR,
	"box": HudIcon.Kind.BOX, "paint": HudIcon.Kind.PAINT, "heart": HudIcon.Kind.HEART, "play": HudIcon.Kind.PLAY,
}
const ICON_PX: int = 128

var _out: String = "/home/burak/Projects/ct_shots/alt_bar_ref/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func wait(t: float) -> void:
	await create_timer(t).timeout


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 120:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	await wait(4.0)
	hud.router.close_all()
	await wait(3.0)   # açılış bildirimleri sönsün
	(hud.get("_notice_queue") as Array).clear()
	var notice: Control = hud.get("_notice_plate") as Control
	if notice:
		notice.hide()
	await wait(0.3)
	await shot("simdi")
	var nav: Control = hud.get_node_or_null("Root/Bottom/Column/NavRow") as Control
	if nav:
		nav.visible = false
	if hud.map_button:
		hud.map_button.visible = false
	await wait(0.4)
	await shot("temiz")
	for name: String in ICONS:
		for bg: Color in [Color.BLACK, Color.WHITE]:
			await _icon(name, ICONS[name], bg)
	quit()


func _icon(name: String, kind: HudIcon.Kind, bg: Color) -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(ICON_PX, ICON_PX)
	viewport.transparent_bg = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var back: ColorRect = ColorRect.new()
	back.color = bg
	back.size = Vector2(ICON_PX, ICON_PX)
	viewport.add_child(back)
	var canvas: Control = Control.new()
	canvas.size = Vector2(ICON_PX, ICON_PX)
	canvas.draw.connect(func() -> void:
		HudIcon.draw_icon(canvas, kind, Vector2(ICON_PX, ICON_PX) * 0.5, ICON_PX * 0.8, Color.WHITE, bg))
	viewport.add_child(canvas)
	get_root().add_child(viewport)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png(_out + "%s_%s.png" % ["siyah" if bg == Color.BLACK else "beyaz", name])
	viewport.queue_free()
