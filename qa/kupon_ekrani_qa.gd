extends SceneTree
## MARKET › KOD GİR görsel QA (2026-10-31, kullanıcı: "kupon kodu girilince hata da başarılı olsa da çok küçük gözüküyor,
## hediyeyi aldım mı almadım mı anlayamıyorum; klavye kodu girdiğimiz yerin üzerine basıyor"). Kareler: misafir (kilitli),
## hata plakası, başarı plakası, ekran klavyesi açıkken yazma (klavye koyu dörtgenle benzetilir: simulate_keyboard), kabul
## edilen kuponun HEDİYEN GELDİ! ekranı MARKET'in üstünde. Ağ yok: sonuçlar doğrudan çizilir, kupon postası enjekte edilir.
## Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/kupon_ekrani_qa.gd --resolution 1200x540 -- <çıktı klasörü>
## (temiz kayıtta eğitim ilk kareyi örter)
var _out: String = "/home/burak/Projects/ct_shots/kupon/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var crates: CrateManager = get_first_node_in_group("crates") as CrateManager
	var welcome: int = crates.welcome_uid()
	if welcome > 0 and not crates.open(welcome).is_empty():
		crates.claim(welcome)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	await create_timer(1.0).timeout
	hud.router.open(&"gem_store")
	await create_timer(0.8).timeout
	var store: GemStoreScreen = hud.router.screen(&"gem_store") as GemStoreScreen
	store._on_tab_pressed(GemStoreScreen.TAB_CODE)
	await create_timer(0.6).timeout
	await shot("1_misafir")
	var result: PanelContainer = store.find_child("CodeResult", true, false) as PanelContainer
	var edit: LineEdit = store.find_child("CodeEdit", true, false) as LineEdit
	edit.editable = true
	edit.text = "REELS5O"
	store._show_result(result, &"error", PromoService.status_text("not_found"))
	await create_timer(0.4).timeout
	await shot("2_hata")
	edit.text = ""
	store._show_result(result, &"ok", Loc.t("KOD KABUL EDİLDİ!"), Loc.t("Hediyen hesabına geçti."))
	await create_timer(0.4).timeout
	await shot("3_basari")
	# Klavye: ekranın alt %45'i (yatay telefonda tipik); koyu dörtgen klavyenin yerini gösterir
	var keyboard: float = store.get_viewport_rect().size.y * 0.45
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 120
	var pad: ColorRect = ColorRect.new()
	pad.color = Color(0.15, 0.16, 0.18, 0.92)
	pad.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	pad.offset_top = -keyboard
	layer.add_child(pad)
	root.add_child(layer)
	GemStoreScreen.simulate_keyboard = keyboard
	result.visible = false
	edit.text = "REELS50"
	edit.grab_focus()
	await create_timer(0.4).timeout
	await shot("4_klavye_acik")
	GemStoreScreen.simulate_keyboard = -1.0
	edit.release_focus()
	layer.queue_free()
	await create_timer(0.4).timeout
	var mail: MailService = get_first_node_in_group("mail") as MailService
	if mail:
		hud.inbox.set_announced("p_reels50", true)
		mail._pending = [MailService.normalize("p_reels50", {"title": {"tr": "Reels kodu"}, "gems": 50, "money": 5000})]
		mail.arrived.emit()
		await process_frame
		await store._open_coupon_gift("p_reels50", false)
		store._show_result(result, &"ok", Loc.t("KOD KABUL EDİLDİ!"), Loc.t("Hediyen hesabına geçti."))
		await create_timer(1.2).timeout
		await shot("5_hediye_ekrani")
	quit()
