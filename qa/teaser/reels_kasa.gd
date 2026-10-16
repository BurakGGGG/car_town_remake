extends SceneTree
## REELS KASA — dikey oynanış kaydı: showroom'da kasa seçimi + SATIN AL → garajda kasa açılışı, içinden araç.
## Oyunun KENDİSİ çalışır (Main.tscn, gerçek HUD, gerçek kasa akışı, gerçek çekiliş fonksiyonu); kayıt
## yalıtılmış kopyadan okunur. Tüm etkileşimler gerçek DOKUNMA olayıdır (buton / kasa ekran konumuna).
## Kareler kök pencereden (arayüz + 3B) her kare alınır; pencere 9:16 olmalı → masaüstü ekranı yetmediği
## için sanal X (Xephyr) kullanılır. Telefon arayüz ölçeği (scale.mobile) uygulanır; SS kat büyük pencerede
## çizilip 1080x1920'ye indirilir (kenar yumuşatma).
##   Xephyr :7 -screen 2160x3840x24 -ac -br -noreset -nolisten tcp &
##   DISPLAY=:7 QA_SAVE=<savegame.json> CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/teaser/reels_kasa.gd \
##       --display-driver x11 --resolution 2160x3840 --position 0,0 --fixed-fps 30 -- <çıktı>
## Çıktı: <çıktı>/NNNNN.png (kayıt başından itibaren her kare) + işaretler (İŞARET satırları: kurgu için).
const OUT_W: int = 1080
const OUT_H: int = 1920
## Seçilip açılan kasa ve çekilişin tohumu: gerçek CrateCatalog.roll bu tohumla bu aracı verir.
const CRATE: StringName = &"sport_crate"
const ROLL_SEED: int = 4

var out_dir: String = ""
var hud: Hud
var router: UiRouter
var crates: CrateManager
var delivery: CrateDelivery
var _frame: int = 0
var _recording: bool = false


func _initialize() -> void:
	out_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	# Telefondaki arayüz ölçeği (masaüstünde motor uygulamaz). Pencere büyüklüğü canvas_items ölçeğine zaten
	# girer: 2160x3840'ta da tuval 853x1517 kalır (yalnızca çizim çözünürlüğü artar).
	root.content_scale_factor = float(ProjectSettings.get_setting("display/window/stretch/scale.mobile", 1.0))
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func mark(label: String) -> void:
	print("İŞARET %s %d" % [label, _frame])


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	hud = current_scene.find_child("HUD", true, false) as Hud
	router = hud.router
	crates = get_first_node_in_group("crates") as CrateManager
	delivery = get_first_node_in_group("crate_delivery") as CrateDelivery
	print("KASA pencere ", DisplayServer.window_get_size(), " tuval ", root.get_visible_rect().size,
		" çizici ", RenderingServer.get_video_adapter_name())
	await wait(3.0)
	router.open(&"showroom")
	await wait(1.6)
	_capture.call()   # her kareyi yazan döngü (arka planda)
	mark("showroom")
	await wait(0.55)
	await tap_control(hud.showroom._plates["crate:" + String(CRATE)])
	mark("kasa_secildi")
	await wait(1.0)
	crates.set_rng_seed(ROLL_SEED)
	await tap_control(hud.showroom._buy_button)
	mark("satin_al")
	var uid: int = -1
	var t: float = 0.0
	while uid < 0 and t < 20.0:
		for c: Dictionary in crates.crates():
			if crates.can_open(int(c["uid"])) and delivery.visual_of(int(c["uid"])) != null:
				uid = int(c["uid"])
		await wait(0.1)
		t += 0.1
	print("KASA geldi uid=", uid, " içerik ", crates.get_crate(uid).get("vehicle", &""))
	mark("kasa_garajda")
	await wait(1.2)
	var v: CrateVisual = delivery.visual_of(uid)
	await tap_screen(root.get_camera_3d().unproject_position(v.global_position + Vector3(0.0, v.size().y * 0.6, 0.0)))
	mark("ac_plakasi")
	await wait(0.7)
	await tap_control(hud.crate_panel._action)
	mark("ac")
	await wait(5.5)
	mark("son")
	_recording = false
	await frames(3)
	print("KASA bitti: %d kare" % _frame)
	quit(0)


func _capture() -> void:
	_recording = true
	while _recording:
		await RenderingServer.frame_post_draw
		if not _recording:
			break
		var img: Image = root.get_texture().get_image()
		if img.get_width() != OUT_W:
			img.resize(OUT_W, OUT_H, Image.INTERPOLATE_LANCZOS)
		img.save_png("%s/%05d.png" % [out_dir, _frame])
		_frame += 1


## Butonun ortasına gerçek dokunuş (CanvasLayer dahil tuval konumu → pencere).
func tap_control(c: Control) -> void:
	await tap_screen(c.get_global_transform_with_canvas() * (c.size * 0.5))


## Tuval (görüntü alanı) noktasına dokunuş: olay PENCERE koordinatı ister (canvas_items ölçeği).
func tap_screen(p: Vector2) -> void:
	var pos: Vector2 = root.get_final_transform() * p
	for pressed: bool in [true, false]:
		var e: InputEventScreenTouch = InputEventScreenTouch.new()
		e.index = 0
		e.position = pos
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(4)
