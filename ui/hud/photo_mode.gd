class_name PhotoMode
extends Control
## FOTOĞRAF MODU · HUD GİZLİ · SİNEMA — kamera menüsünden açılan, oyun HUD'u olmadan dünyayı gösteren katman.
## UiRouter'da "photo" (PLACE): açılınca oyun HUD'u gizlenir, araç / tamir plakaları kapanır, Android GERİ
## kapatır. Dünya çizilmeye devam eder (WORLD_COVERING_PLACES'te değil); araç balonları (🔧 / ₺) gizlenir.
##
## Katman tam ekran STOP'tur: dünyadaki araç / bina / kasa seçimi yanlışlıkla açılmaz. Kaydırma ve
## yakınlaştırma olayları WorldCamera.view_input'a aynen verilir — kamera her zamanki gibi gezer.
##   PHOTO  — sağda deklanşör, ızgara anahtarı, KAPAT ve son çekilen fotoğrafın küçük resmi; sol altta
##            logonun fotoğrafta çıkacağı yer önizlenir. Deklanşör: arayüz bir kare gizlenir, ekran
##            okunur, logo basılıp JPEG'e çevrilir (arka planda) ve galeriye yazılır (GallerySaver).
##   CLEAN  — yalnızca sağ üstte HUD'U GÖSTER gözü (biraz sonra soluklaşır, dokununca belirginleşir).
##   CINEMA — CLEAN gibi; kamera şehrin üstünde kendiliğinden yavaşça süzülür (kaydırma kapalı).

signal opened
signal closed
## Bir çekim bitti: GallerySaver sonucu ({"ok", "where", "error"}).
signal photo_saved(result: Dictionary)

enum Mode { PHOTO, CLEAN, CINEMA }

const MARGIN: int = 14
## HUD gizli / sinema: göz tabelası bu kadar saniye dokunulmazsa soluklaşır.
const FADE_DELAY: float = 2.5
const FADED_ALPHA: float = 0.3
const HINT_TIME: float = 3.0
const TOAST_TIME: float = 1.8
const THUMB_WIDTH: float = 112.0
## Sinema: sekiz çizen yolun bir turu (sn), dünyanın yarı boyuna göre genişliği, odak takibi (1/sn), zoom aralığı.
const CINEMA_LOOP: float = 80.0
const CINEMA_REACH: float = 0.42
const CINEMA_FOLLOW: float = 0.5
const CINEMA_ZOOM_NEAR: float = 2.7
const CINEMA_ZOOM_FAR: float = 3.7

## Açılmadan önce seçilir (Hud.open_photo_mode).
var mode: Mode = Mode.PHOTO
## Izgara tercihi oturum boyunca kalır.
var grid_on: bool = false

var _camera: WorldCamera
var _world_ui_was_visible: bool = true
var _busy: bool = false
var _last_stamp: String = ""
var _serial: int = 0
var _logo: Image
var _idle: float = 0.0
var _cinema_time: float = 0.0
var _cinema_focus: Vector3

var _chrome: Control
var _margin: MarginContainer
var _grid: _ThirdsGrid
var _logo_slot: MarginContainer
var _logo_preview: TextureRect
var _hint: Label
var _toast: PlatePanel
var _toast_label: Label
var _close_button: PlateButton
var _show_hud_button: PlateButton
var _shutter: _Shutter
var _grid_button: PlateButton
var _thumb_frame: PanelContainer
var _thumb: TextureRect
var _flash: ColorRect
var _sfx: AudioStreamPlayer
var _hint_tween: Tween
var _toast_tween: Tween
var _flash_tween: Tween
static var _click_stream: AudioStreamWAV


func _ready() -> void:
	name = "PhotoMode"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout_logo_preview)


func open() -> void:
	_camera = get_viewport().get_camera_3d() as WorldCamera
	if _camera:
		_world_ui_was_visible = _camera.world_ui_visible()
		_camera.set_world_ui_visible(false)
		_cinema_focus = _camera.view_state().get("focus", Vector3.ZERO)
	_cinema_time = 0.0
	_idle = 0.0
	_busy = false
	_apply_mode()
	show()
	_layout_logo_preview()
	if mode == Mode.PHOTO:
		_show_hint()
	opened.emit()


func close() -> void:
	if not visible:
		return
	hide()
	if _camera and is_instance_valid(_camera):
		_camera.set_world_ui_visible(_world_ui_was_visible)
	_camera = null
	closed.emit()


## Deklanşör: arayüzsüz kareyi okur, logoyu basar, galeriye yazar. Bitince photo_saved yayılır.
func capture() -> void:
	if _busy or not visible:
		return
	_busy = true
	if _flash_tween:
		_flash_tween.kill()
	_flash.color.a = 0.0
	_chrome.visible = false
	await RenderingServer.frame_post_draw   # arayüzsüz kare çizildi
	_chrome.visible = true
	if not visible:   # beklerken GERİ ile kapandı: karede artık oyun HUD'u var, çekilmez
		_busy = false
		return
	var shot: Image = get_viewport().get_texture().get_image()
	_play_flash()
	_play_click()
	if _logo == null:
		_logo = PhotoCapture.load_logo()
	var logo: Image = _logo
	var out: Array = []
	var task: int = WorkerThreadPool.add_task(func() -> void:
		out.append(PhotoCapture.render_jpeg(shot, logo))
		out.append(PhotoCapture.thumbnail(shot, int(THUMB_WIDTH * 2.0))))
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task)
	var bytes: PackedByteArray = out[0] if out.size() > 0 else PackedByteArray()
	# Android 7–9: depolama izni GİRİŞTE değil, ilk fotoğraf çekildikten sonra (kaydederken) istenir (kullanıcı kararı
	# 2026-10-17). Reddedilirse çekim kaydedilmez, oyuncuya neden söylenir; sonraki çekimde yeniden sorulur.
	if GallerySaver.needs_legacy_permission():
		await _request_legacy_permission()
		if GallerySaver.needs_legacy_permission():
			_show_toast(Loc.t("GALERİYE KAYDETMEK İÇİN İZİN GEREKİYOR"), HudPalette.DANGER)
			_busy = false
			photo_saved.emit({"ok": false, "where": "", "error": "permission"})
			return
	var result: Dictionary = GallerySaver.save_jpeg(bytes, _next_file_name())
	if bool(result.get("ok", false)):
		print("PhotoMode: fotoğraf kaydedildi → %s" % result.get("where", ""))
		_show_toast(Loc.t("GALERİYE KAYDEDİLDİ"), HudPalette.INK)
		if out.size() > 1 and out[1] is Image:
			_show_thumb(out[1])
	else:
		push_warning("PhotoMode: fotoğraf kaydedilemedi (%s)" % result.get("error", ""))
		_show_toast(Loc.t("FOTOĞRAF KAYDEDİLEMEDİ"), HudPalette.DANGER)
	_busy = false
	photo_saved.emit(result)


func is_busy() -> bool:
	return _busy


# --- Girdi / kare ----------------------------------------------------------------

## Boş alana gelen dokunuşlar kameraya verilir (sinemada kamera kendisi gezer, yalnızca göz uyanır).
func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
			or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed):
		_wake()
	if mode != Mode.CINEMA and _camera and is_instance_valid(_camera):
		_camera.view_input(event)
	accept_event()


func _process(delta: float) -> void:
	if not visible:
		return
	if mode != Mode.PHOTO:
		_idle += delta
		var target: float = 1.0 if _idle < FADE_DELAY else FADED_ALPHA
		_show_hud_button.modulate.a = move_toward(_show_hud_button.modulate.a, target, delta * 2.5)
	if mode == Mode.CINEMA and _camera and is_instance_valid(_camera):
		_cinema_step(delta)


## Sekiz çizen yol (x = sin φ, z = sin 2φ) dünyanın ortasında; odak ona yumuşakça yetişir, zoom yavaşça nefes alır.
func _cinema_step(delta: float) -> void:
	_cinema_time += delta
	var phase: float = _cinema_time / CINEMA_LOOP * TAU
	var center: Vector2 = (_camera.world_min + _camera.world_max) * 0.5
	var reach: Vector2 = (_camera.world_max - _camera.world_min) * 0.5 * CINEMA_REACH
	var target: Vector3 = Vector3(center.x + reach.x * sin(phase), 0.0, center.y + reach.y * sin(phase * 2.0))
	_cinema_focus = _cinema_focus.lerp(target, 1.0 - exp(-CINEMA_FOLLOW * delta))
	var breath: float = 0.5 - 0.5 * cos(phase * 3.0)
	_camera.follow(_cinema_focus, lerpf(CINEMA_ZOOM_NEAR, CINEMA_ZOOM_FAR, breath))


func _wake() -> void:
	_idle = 0.0


# --- Kurulum ---------------------------------------------------------------------

func _build() -> void:
	_chrome = _full_rect(Control.new(), "Chrome")
	add_child(_chrome)
	_grid = _full_rect(_ThirdsGrid.new(), "Grid") as _ThirdsGrid
	_chrome.add_child(_grid)

	# Sol alt: logonun fotoğraftaki yeri (oranlar PhotoCapture.logo_rect ile aynı)
	_logo_slot = _full_rect(MarginContainer.new(), "LogoSlot") as MarginContainer
	_chrome.add_child(_logo_slot)
	_logo_preview = TextureRect.new()
	_logo_preview.name = "LogoPreview"
	_logo_preview.texture = load(PhotoCapture.LOGO_PATH) as Texture2D
	_logo_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_logo_preview.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_logo_preview.size_flags_vertical = Control.SIZE_SHRINK_END
	_logo_slot.add_child(_logo_preview)

	_margin = _full_rect(MarginContainer.new(), "Margin") as MarginContainer
	_chrome.add_child(_margin)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin.add_child(row)

	# Orta: üstte ipucu + bildirim
	var top: VBoxContainer = VBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_theme_constant_override(&"separation", 8)
	row.add_child(top)
	_hint = Label.new()
	_hint.name = "Hint"
	_hint.theme_type_variation = &"HudOutlined"
	_hint.text = Loc.t("KADRAJI AYARLA, SONRA ÇEK")
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_hint)
	_toast = PlatePanel.new()
	_toast.name = "Toast"
	_toast.theme_type_variation = &"HudCarPlate"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast.visible = false
	var toast_margin: MarginContainer = MarginContainer.new()
	toast_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: StringName in [&"margin_left", &"margin_right"]:
		toast_margin.add_theme_constant_override(side, 18)
	for side: StringName in [&"margin_top", &"margin_bottom"]:
		toast_margin.add_theme_constant_override(side, 6)
	_toast.add_child(toast_margin)
	_toast_label = Label.new()
	_toast_label.theme_type_variation = &"HudInkValue"
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_margin.add_child(_toast_label)
	top.add_child(_toast)

	# Sağ sütun: KAPAT / HUD'U GÖSTER üstte, deklanşör + ızgara ortada, son fotoğraf altta
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Controls"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 10)
	column.custom_minimum_size.x = THUMB_WIDTH + 6.0   # küçük resim gelince deklanşör yerinden kaymasın
	row.add_child(column)
	_close_button = _sign(HudIcon.Kind.CROSS, &"HudSign")
	_close_button.pressed.connect(close)
	column.add_child(_close_button)
	_show_hud_button = _sign(HudIcon.Kind.EYE, &"HudSign")
	_show_hud_button.pressed.connect(close)
	column.add_child(_show_hud_button)
	column.add_child(_spacer())
	_shutter = _Shutter.new()
	_shutter.name = "Shutter"
	_shutter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_shutter.pressed.connect(capture)
	column.add_child(_shutter)
	_grid_button = _sign(HudIcon.Kind.GRID, &"HudSignSmall")
	_grid_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_grid_button.toggle_mode = true
	_grid_button.toggled.connect(_on_grid_toggled)
	column.add_child(_grid_button)
	column.add_child(_spacer())
	_thumb_frame = PanelContainer.new()
	_thumb_frame.name = "LastPhoto"
	_thumb_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb_frame.size_flags_horizontal = Control.SIZE_SHRINK_END
	_thumb_frame.visible = false
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = HudPalette.SIGN
	frame.set_content_margin_all(3)
	frame.set_corner_radius_all(4)
	frame.shadow_color = HudPalette.SHADOW
	frame.shadow_size = 3
	frame.shadow_offset = Vector2(0, 2)
	_thumb_frame.add_theme_stylebox_override(&"panel", frame)
	_thumb = TextureRect.new()
	_thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_thumb.custom_minimum_size = Vector2(THUMB_WIDTH, THUMB_WIDTH * 9.0 / 16.0)
	_thumb_frame.add_child(_thumb)
	column.add_child(_thumb_frame)

	_flash = _full_rect(ColorRect.new(), "Flash") as ColorRect
	_flash.color = Color(1.0, 1.0, 1.0, 0.0)
	add_child(_flash)
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = GameSettings.SFX_BUS
	_sfx.volume_db = -6.0
	add_child(_sfx)
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _apply_mode() -> void:
	var photo: bool = mode == Mode.PHOTO
	_close_button.visible = photo
	_show_hud_button.visible = not photo
	_show_hud_button.modulate.a = 1.0
	_shutter.visible = photo
	_grid_button.visible = photo
	_grid_button.set_pressed_no_signal(grid_on)
	_grid.visible = photo and grid_on
	_logo_slot.visible = photo
	_thumb_frame.visible = photo and _thumb.texture != null
	_hint.visible = false
	_toast.visible = false
	_chrome.visible = true


## Logo önizlemesi fotoğraftakiyle aynı yerde ve boyda (tuval ekranın tamamını kaplar, oranlar aynı).
func _layout_logo_preview() -> void:
	if _logo_preview == null or _logo_preview.texture == null:
		return
	var rect: Rect2 = PhotoCapture.logo_rect(size, _logo_preview.texture.get_size())
	_logo_preview.custom_minimum_size = rect.size
	_logo_slot.add_theme_constant_override(&"margin_left", int(round(rect.position.x)))
	_logo_slot.add_theme_constant_override(&"margin_bottom", int(round(size.y - rect.end.y)))


## Çentikli telefonlarda düğmeler kesik alana girmesin (HUD ile aynı hesap).
func _apply_safe_area() -> void:
	var insets: PackedInt32Array = Hud.safe_area_insets(get_viewport())
	_margin.add_theme_constant_override(&"margin_left", MARGIN + insets[0])
	_margin.add_theme_constant_override(&"margin_top", MARGIN + insets[1])
	_margin.add_theme_constant_override(&"margin_right", MARGIN + insets[2])
	_margin.add_theme_constant_override(&"margin_bottom", MARGIN + insets[3])


func _sign(icon: HudIcon.Kind, variation: StringName) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = variation
	button.shape = PlateButton.Shape.ROUND
	button.kind = icon
	button.icon_size = 18.0 if variation == &"HudSign" else 15.0
	button.custom_minimum_size = Vector2(32, 32) if variation == &"HudSign" else Vector2(26, 26)
	button.bolts = false
	button.lift_when_pressed = 0.0
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button


func _spacer() -> Control:
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return spacer


func _full_rect(node: Control, node_name: String) -> Control:
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return node


func _on_grid_toggled(on: bool) -> void:
	grid_on = on
	_grid.visible = on


# --- Geri bildirim ---------------------------------------------------------------

func _show_hint() -> void:
	if _hint_tween:
		_hint_tween.kill()
	_hint.visible = true
	_hint.modulate.a = 1.0
	_hint_tween = create_tween()
	_hint_tween.tween_interval(HINT_TIME)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 0.4)
	_hint_tween.tween_callback(_hint.hide)


func _show_toast(text: String, color: Color) -> void:
	if _toast_tween:
		_toast_tween.kill()
	_hint.visible = false
	_toast_label.text = text
	_toast_label.add_theme_color_override(&"font_color", color)
	_toast.visible = true
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(TOAST_TIME)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(_toast.hide)


func _show_thumb(image: Image) -> void:
	_thumb.texture = ImageTexture.create_from_image(image)
	_thumb.custom_minimum_size = Vector2(THUMB_WIDTH, THUMB_WIDTH * float(image.get_height()) / maxf(float(image.get_width()), 1.0))
	_thumb_frame.visible = mode == Mode.PHOTO
	_thumb_frame.pivot_offset = _thumb_frame.size * 0.5
	_thumb_frame.scale = Vector2(0.6, 0.6)
	create_tween().tween_property(_thumb_frame, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _play_flash() -> void:
	_flash.color.a = 0.85
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color:a", 0.0, 0.35).set_ease(Tween.EASE_OUT)


func _play_click() -> void:
	if _click_stream == null:
		_click_stream = _make_click()
	_sfx.stream = _click_stream
	_sfx.play()


## Deklanşör sesi KODLA: iki kısa, hızla sönen gürültü patlaması (perde açılır · kapanır).
static func _make_click() -> AudioStreamWAV:
	const RATE: int = 22050
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var samples: PackedFloat32Array = PackedFloat32Array()
	samples.resize(int(0.16 * RATE))
	for burst: Vector2 in [Vector2(0.0, 1.0), Vector2(0.075, 0.7)]:   # başlangıç (sn), şiddet
		var start: int = int(burst.x * RATE)
		for i: int in range(start, samples.size()):
			var t: float = float(i - start) / float(RATE)
			samples[i] += rng.randf_range(-1.0, 1.0) * burst.y * exp(-t * 90.0) * minf(t / 0.0015, 1.0)
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i: int in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * 0.6, -1.0, 1.0) * 32767.0))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = bytes
	return stream


func _next_file_name() -> String:
	var now: Dictionary = Time.get_datetime_dict_from_system()
	var name_now: String = PhotoCapture.file_name(now)
	_serial = _serial + 1 if name_now == _last_stamp else 0
	_last_stamp = name_now
	return PhotoCapture.file_name(now, _serial)


## Android 7–9: depolama iznini ister ve yanıtı bekler. İzin manifeste yalnızca API ≤ 28 için eklenir
## (addons/GodotFirebaseAndroid/export_plugin.gd, maxSdkVersion=28).
func _request_legacy_permission() -> void:
	if OS.request_permission(GallerySaver.LEGACY_PERMISSION):
		return
	var answered: Array = [false]
	var on_result: Callable = func(permission: String, _granted: bool) -> void:
		if permission == GallerySaver.LEGACY_PERMISSION:
			answered[0] = true
	get_tree().on_request_permissions_result.connect(on_result)
	var deadline: int = Time.get_ticks_msec() + 60000
	while not bool(answered[0]) and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	get_tree().on_request_permissions_result.disconnect(on_result)


# --- İç sınıflar -----------------------------------------------------------------

## Üçte bir ızgarası: ince yarı saydam beyaz çizgiler (fotoğrafa girmez — çekimde arayüzle gizlenir).
class _ThirdsGrid:
	extends Control

	func _draw() -> void:
		var line: Color = Color(1.0, 1.0, 1.0, 0.45)
		for k: float in [1.0 / 3.0, 2.0 / 3.0]:
			draw_line(Vector2(size.x * k, 0.0), Vector2(size.x * k, size.y), line, 1.5, true)
			draw_line(Vector2(0.0, size.y * k), Vector2(size.x, size.y * k), line, 1.5, true)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()


## Deklanşör: beyaz halka, içinde basılınca küçülen dolu daire (telefon kamerası gibi).
class _Shutter:
	extends BaseButton

	const DIAMETER: float = 68.0

	func _init() -> void:
		custom_minimum_size = Vector2(DIAMETER, DIAMETER)
		focus_mode = Control.FOCUS_NONE
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		draw_circle(c + Vector2(0.0, 2.0), r, HudPalette.SHADOW, true, -1.0, true)
		draw_circle(c, r, HudPalette.SIGN, true, -1.0, true)
		draw_circle(c, r * 0.80, HudPalette.INK, true, -1.0, true)
		var held: bool = get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
		var inner: float = r * (0.62 if held else 0.70)
		draw_circle(c, inner, HudPalette.SIGN, true, -1.0, true)
