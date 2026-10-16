extends SceneTree
## KAMERA MENÜSÜ + FOTOĞRAF MODU — sağ üstteki kamera tabelasının açtığı menü, FOTOĞRAF ÇEK (logolu JPEG,
## galeri kaydı), HUD'U GİZLE ve SİNEMA MODU. Çekim gerçek kare okuduğu için PENCERELİ çalışır.
## Çalıştırma: tools/run_tests.sh photo_mode_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventMouseButton = InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		root.push_input(event, true)
		await process_frame


func _drag(from: Vector2, by: Vector2) -> void:
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	press.global_position = from
	root.push_input(press, true)
	var at: Vector2 = from
	for i: int in 10:
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.relative = by / 10.0
		at += by / 10.0
		motion.position = at
		motion.global_position = at
		root.push_input(motion, true)
		await process_frame
	var release: InputEventMouseButton = press.duplicate() as InputEventMouseButton
	release.pressed = false
	release.position = at
	release.global_position = at
	root.push_input(release, true)
	await process_frame


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(20)
	var hud: Hud = main.find_child("HUD", true, false)
	var router: UiRouter = hud.router
	var camera: WorldCamera = root.get_camera_3d() as WorldCamera
	var menu: CameraMenu = hud.camera_menu
	var photo: PhotoMode = hud.photo_mode
	check(camera != null, "dünya kamerası WorldCamera")
	var home: Vector3 = camera.view_state()["focus"]

	print("== LOGO / DOSYA ==")
	var gray: Image = Image.create_empty(400, 200, false, Image.FORMAT_RGB8)
	gray.fill(Color(0.5, 0.5, 0.5))
	var logo: Image = PhotoCapture.load_logo()
	check(logo != null and logo.get_size() == Vector2i(2048, 475), "logo yüklendi (2048×475, kayıpsız)")
	var stamped: Image = PhotoCapture.compose(gray, logo)
	var rect: Rect2 = PhotoCapture.logo_rect(Vector2(400, 200), Vector2(logo.get_size()))
	check(stamped.get_size() == gray.get_size() and stamped.get_format() == Image.FORMAT_RGB8, "çıktı aynı boyda, RGB8")
	check(rect.position.x < 40.0 and rect.end.y > 170.0 and absf(rect.size.x - 96.0) < 0.5, "logo sol altta, genişliğin %%24'ü (%s)" % rect)
	var changed: int = 0
	var samples: int = 0
	for x: int in range(int(rect.position.x), int(rect.end.x), 4):
		for y: int in range(int(rect.position.y), int(rect.end.y), 4):
			samples += 1
			if not stamped.get_pixel(x, y).is_equal_approx(gray.get_pixel(x, y)):
				changed += 1
	# Logonun harf araları saydam: alanın tamamı değil, en az yarısı boyanır
	check(changed * 2 > samples, "logo alanı boyandı (%d / %d nokta)" % [changed, samples])
	check(stamped.get_pixel(390, 10).is_equal_approx(gray.get_pixel(390, 10)) and stamped.get_pixel(200, 30).is_equal_approx(gray.get_pixel(200, 30)),
		"logo dışı (sağ üst / orta) aynen kaldı")
	check(gray.get_pixel(int(rect.get_center().x), int(rect.get_center().y)).is_equal_approx(gray.get_pixel(390, 190)), "girdi fotoğraf değişmedi")
	var tall: Rect2 = PhotoCapture.logo_rect(Vector2(400, 1000), Vector2(2048, 475))
	check(tall.size.y <= 1000.0 * PhotoCapture.LOGO_MAX_HEIGHT + 0.01 and tall.size.x <= 400.0 * PhotoCapture.LOGO_WIDTH + 0.01, "dikey kadrajda da logo taşmaz")
	var jpeg: PackedByteArray = PhotoCapture.render_jpeg(gray, logo)
	check(jpeg.size() > 1000 and jpeg[0] == 0xFF and jpeg[1] == 0xD8, "JPEG baytları (FF D8)")
	var when: Dictionary = {"year": 2026, "month": 10, "day": 16, "hour": 9, "minute": 5, "second": 2}
	check(PhotoCapture.file_name(when) == "AutoYard_20261016_090502.jpg" and PhotoCapture.file_name(when, 2) == "AutoYard_20261016_090502_2.jpg",
		"dosya adı tarih-saat (aynı saniyede sıra no)")
	check(not GallerySaver.needs_legacy_permission() and GallerySaver.android_sdk() == 0, "masaüstü: izin gerekmez, SDK 0")
	check(not bool(GallerySaver.save_jpeg(PackedByteArray(), "x.jpg").get("ok", true)), "boş fotoğraf kaydedilmez")
	var shots: String = ProjectSettings.globalize_path("user://test_photos")
	DirAccess.make_dir_recursive_absolute(shots)
	for old: String in DirAccess.get_files_at(shots):
		DirAccess.remove_absolute(shots.path_join(old))
	GallerySaver.override_dir = shots

	print("== KAMERA MENÜSÜ ==")
	var sign_row: Node = hud.camera_button.get_parent()
	check(menu != null and not menu.visible, "menü kapalı başlar")
	check(menu.get_parent() == sign_row.get_parent() and menu.get_index() == sign_row.get_index() + 1,
		"menü tabela sırasının hemen altında (sağ üst sütun)")
	check(hud.quest_button.get_index() > menu.get_index(), "GÖREVLER menünün altında kalır")
	var camera_at: Vector2 = hud.camera_button.get_global_rect().position
	hud.camera_button.button_pressed = true
	await frames(3)
	check(menu.visible and menu.photo_button.is_visible_in_tree() and menu.hide_hud_button.is_visible_in_tree()
		and menu.cinema_button.is_visible_in_tree(), "kamera tabelası → kutu: fotoğraf / HUD'u gizle / sinema")
	check(hud.zoom_in_button.get_parent().get_parent() == menu and hud.zoom_in_button.is_visible_in_tree()
		and hud.zoom_out_button.is_visible_in_tree() and menu.recenter_button.is_visible_in_tree(), "uzaklaş / yakınlaş / ortala kutuda")
	var signs: Array[PlateButton] = menu.signs()
	var round_signs: bool = signs.size() == 6
	for button: PlateButton in signs:
		round_signs = round_signs and button.shape == PlateButton.Shape.ROUND and button.text.is_empty() \
			and is_equal_approx(button.global_position.y, signs[0].global_position.y)
	check(round_signs, "kutuda 6 yazısız yuvarlak tabela, tek sırada")
	check(signs == [menu.photo_button, menu.hide_hud_button, menu.cinema_button, hud.zoom_out_button, hud.zoom_in_button,
		menu.recenter_button], "sıra: fotoğraf · gizle · sinema | − · + · ortala")
	check(not hud.camera_controls.visible, "eski kamera şeridi gizli")
	check(hud.camera_button.get_global_rect().position.distance_to(camera_at) < 0.5, "kutu açılınca kamera tabelası yerinden kaymaz")
	check(menu.get_global_rect().end.y - hud.camera_button.get_global_rect().end.y < 90.0, "kutu küçük: tek sıra yüksekliğinde (%.0f)" % menu.size.y)
	var menu_rect: Rect2 = menu.get_global_rect()
	var viewport_rect: Rect2 = root.get_visible_rect()
	check(viewport_rect.encloses(menu_rect), "menü ekranın içinde (%s)" % menu_rect)
	var zooms: Array[int] = []
	hud.camera_zoom_requested.connect(func(direction: int) -> void: zooms.append(direction))
	hud.zoom_in_button.pressed.emit()
	hud.zoom_out_button.pressed.emit()
	check(zooms == [1, -1] and menu.visible, "yakınlaştırma tabelaları çalışır, menü açık kalır")
	await _drag(viewport_rect.size * Vector2(0.35, 0.5), Vector2(-160, -60))
	await frames(5)
	check(not menu.visible and not hud.camera_button.button_pressed, "menü dışına dokununca kapandı")
	var moved: Vector3 = camera.view_state()["focus"]
	check(moved.distance_to(home) > 0.3, "dünya kaydırıldı (%.2f)" % moved.distance_to(home))
	hud.camera_button.button_pressed = true
	await frames(2)
	menu.recenter_button.pressed.emit()
	await create_timer(0.6).timeout
	check((camera.view_state()["focus"] as Vector3).distance_to(home) < 0.05 and menu.visible, "ORTALA → açılış görünümüne döndü, menü açık")
	router.open(&"settings")
	await frames(3)
	check(not menu.visible, "bir ekran açılınca menü kapanır")
	router.back()
	await create_timer(0.4).timeout

	print("== FOTOĞRAF MODU ==")
	hud.camera_button.button_pressed = true
	await frames(2)
	menu.photo_button.pressed.emit()
	await frames(4)
	check(router.top() == &"photo" and photo.visible and photo.mode == PhotoMode.Mode.PHOTO, "FOTOĞRAF ÇEK → fotoğraf modu (router 'photo')")
	check(not hud.top_left.visible and not hud.top_right.visible and not hud.bottom.visible and not menu.visible, "oyun HUD'u ve menü gizli")
	check(not camera.world_ui_visible(), "araç balonları gizli")
	check(photo._shutter.is_visible_in_tree() and photo._close_button.is_visible_in_tree() and not photo._show_hud_button.visible, "deklanşör + KAPAT görünür")
	var preview: Rect2 = photo._logo_preview.get_global_rect()
	var expected: Rect2 = PhotoCapture.logo_rect(photo.size, photo._logo_preview.texture.get_size())
	check(preview.position.distance_to(expected.position) < 1.5 and preview.size.distance_to(expected.size) < 1.5,
		"logo önizlemesi fotoğraftaki yerinde (%s ~ %s)" % [preview, expected])
	var before_pan: Vector3 = camera.view_state()["focus"]
	await _drag(viewport_rect.size * Vector2(0.4, 0.5), Vector2(140, 50))
	check((camera.view_state()["focus"] as Vector3).distance_to(before_pan) > 0.3, "fotoğraf modunda kamera kaydırılır")
	await _click(viewport_rect.size * Vector2(0.5, 0.45))
	await frames(3)
	check(router.top() == &"photo", "dünyaya dokunmak araç / bina açmaz")
	photo._grid_button.button_pressed = true
	await frames(1)
	check(photo._grid.visible and photo.grid_on, "ızgara açıldı")

	var chrome_seen: Array = []
	var probe: Callable = func() -> void: chrome_seen.append(photo._chrome.visible)
	RenderingServer.frame_post_draw.connect(probe, CONNECT_ONE_SHOT)
	var results: Array = []
	photo.photo_saved.connect(func(result: Dictionary) -> void: results.append(result))
	# Kare yalnızca pencere çizilirken alınır: masaüstünde küçültülmüş test penceresinde (can_draw false) çekim bekler
	var pre_state: String = "görünür %s, meşgul %s, router %s, pencere çizilebilir %s" % [photo.visible, photo.is_busy(), router.top(),
		DisplayServer.window_can_draw()]
	photo._shutter.pressed.emit()
	var deadline: int = Time.get_ticks_msec() + 15000
	while results.is_empty() and Time.get_ticks_msec() < deadline:
		await process_frame
	check(chrome_seen == [false], "çekilen karede fotoğraf arayüzü (deklanşör, ızgara, logo önizlemesi) yok (%s; %s)" % [chrome_seen, pre_state])
	check(results.size() == 1 and bool(results[0].get("ok", false)), "fotoğraf kaydedildi (%s)" % [results])
	var files: PackedStringArray = DirAccess.get_files_at(shots)
	check(files.size() == 1 and files[0].begins_with("AutoYard_") and files[0].ends_with(".jpg"), "galeri klasöründe 1 JPEG (%s)" % [files])
	if files.size() >= 1:
		var saved: Image = Image.load_from_file(shots.path_join(files[0]))
		var screen_px: Vector2i = root.get_texture().get_image().get_size()
		check(saved != null and saved.get_size() == screen_px, "fotoğraf ekran çözünürlüğünde (%s)" % (saved.get_size() if saved else Vector2i.ZERO))
	check(photo._toast.visible and photo._toast_label.text == "GALERİYE KAYDEDİLDİ", "bildirim: GALERİYE KAYDEDİLDİ")
	check(photo._thumb_frame.visible and photo._thumb.texture != null, "son fotoğrafın küçük resmi köşede")
	check(photo._chrome.visible and photo._shutter.is_visible_in_tree(), "çekimden sonra arayüz geri geldi")
	photo._shutter.pressed.emit()
	photo._shutter.pressed.emit()   # sürerken ikinci basış yok sayılır
	deadline = Time.get_ticks_msec() + 15000
	while results.size() < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	await frames(5)
	check(results.size() == 2 and DirAccess.get_files_at(shots).size() == 2, "ikinci çekim ayrı dosya, çift basış tek çekim (%d dosya)" % DirAccess.get_files_at(shots).size())
	router.handle_android_back()
	await frames(4)
	check(router.top() == &"" and not photo.visible and hud.top_left.visible and hud.top_right.visible and hud.bottom.visible,
		"Android GERİ → fotoğraf modu kapandı, HUD geri geldi")
	check(camera.world_ui_visible(), "araç balonları geri açıldı")

	print("== HUD'U GİZLE ==")
	hud.camera_button.button_pressed = true
	await frames(2)
	menu.hide_hud_button.pressed.emit()
	await frames(4)
	check(router.top() == &"photo" and photo.mode == PhotoMode.Mode.CLEAN and not hud.top_right.visible, "HUD'U GİZLE → HUD'suz görünüm")
	check(photo._show_hud_button.is_visible_in_tree() and not photo._shutter.is_visible_in_tree() and not photo._logo_slot.visible,
		"yalnızca HUD'U GÖSTER gözü var (deklanşör / logo yok)")
	await create_timer(PhotoMode.FADE_DELAY + 1.0).timeout
	check(photo._show_hud_button.modulate.a < 0.5, "göz bir süre sonra soluklaşır (%.2f)" % photo._show_hud_button.modulate.a)
	await _click(viewport_rect.size * Vector2(0.3, 0.6))
	await frames(10)
	check(photo._show_hud_button.modulate.a > 0.5, "dokununca yeniden belirginleşir")
	photo._show_hud_button.pressed.emit()
	await frames(4)
	check(router.top() == &"" and hud.top_left.visible and hud.bottom.visible, "göz → HUD geri geldi")

	print("== SİNEMA MODU ==")
	hud.camera_button.button_pressed = true
	await frames(2)
	menu.cinema_button.pressed.emit()
	await frames(2)
	check(router.top() == &"photo" and photo.mode == PhotoMode.Mode.CINEMA and not hud.bottom.visible, "SİNEMA MODU açıldı, HUD gizli")
	var start: Vector3 = camera.view_state()["focus"]
	await create_timer(2.0).timeout
	var drift: float = (camera.view_state()["focus"] as Vector3).distance_to(start)
	check(drift > 0.1, "kamera kendiliğinden süzülüyor (%.2f birim / 2 sn)" % drift)
	var view: Rect2 = Rect2(camera.world_min, camera.world_max - camera.world_min)
	var focus: Vector3 = camera.view_state()["focus"]
	check(view.has_point(Vector2(focus.x, focus.z)), "odak dünya sınırları içinde")
	router.back()
	await frames(4)
	check(router.top() == &"" and hud.top_right.visible and camera.world_ui_visible(), "GERİ → sinema kapandı")

	GallerySaver.override_dir = ""
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
