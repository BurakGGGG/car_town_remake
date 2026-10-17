class_name CameraCapture
extends Control
## KAMERAYLA PROFİL FOTOĞRAFI (UiRouter alt pano &"avatar_camera"). Android'de önce kamera izni istenir
## (export_presets: permissions/camera). CameraServer akışı (ön kamera öncelikli) ekran dışı bir SubViewport'ta
## shader'la RGB'ye çevrilip çizilir; önizleme o dokudur, ÇEK aynı kareyi alır → captured(image). Kırpma
## AvatarCropper'dadır. Ön kamera ayna görüntüsüdür (oyuncu ekranda ne görüyorsa o çekilir).
## Kamera yalnızca bu pano açıkken çalışır; kapanınca akış ve izleme durur.

signal closed
## Çekilen kare; pano tamamen kapandıktan SONRA gelir (dinleyen yeni alt pano açabilsin: router yığını temiz).
signal captured(image: Image)

const SHADER: Shader = preload("res://ui/hud/camera_feed.gdshader")
const PREVIEW: Vector2 = Vector2(360.0, 270.0)
## Kameradan istenen en büyük genişlik (biçim seçimi); çekilen kare zaten 192 px'e iner.
const MAX_WIDTH: int = 1280
const FEED_WAIT: float = 2.5

var _column: VBoxContainer
var _viewport: SubViewport
var _rect: ColorRect
var _material: ShaderMaterial
var _preview: TextureRect
var _status: Label
var _shoot: PlateButton
var _switch: PlateButton
var _feeds: Array[CameraFeed] = []
var _feed: CameraFeed
var _index: int = 0
var _ready_frame: bool = false
var _closing: bool = false
## Açılış / kapanış sayacı: kapanış animasyonu sürerken yeniden açılırsa eski kapanış (gizle + closed) iptal olur.
var _gen: int = 0
var _session: int = 0   # açılış sayacı: eski açılışın gecikmeli işleri yok sayılır
var _shot: Image


func _ready() -> void:
	name = "CameraCapture"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_gen += 1
	_closing = false
	PlateAnim.pop_in(self, _column)
	_start()


func close() -> void:
	if not visible or _closing:
		return
	_stop()
	_closing = true
	_gen += 1
	var gen: int = _gen
	PlateAnim.pop_out(self, _column, func() -> void:
		if gen != _gen:
			return
		hide()
		_closing = false
		closed.emit()
		if _shot:
			var shot: Image = _shot
			_shot = null
			captured.emit(shot))


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_viewport = SubViewport.new()
	_viewport.name = "CameraViewport"
	_viewport.disable_3d = true
	_viewport.transparent_bg = false
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.size = Vector2i(4, 4)
	add_child(_viewport)
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.material = _material
	_viewport.add_child(_rect)

	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)
	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 10)
	_column.add_child(body)

	var frame: PlatePanel = PlatePanel.new()
	frame.theme_type_variation = &"HudCarPlate"
	body.add_child(frame)
	var stack: Control = Control.new()
	stack.custom_minimum_size = PREVIEW
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(stack)
	var black: ColorRect = ColorRect.new()
	black.color = Color("2F3236")
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(black)
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_preview)
	_status = Label.new()
	_status.theme_type_variation = &"HudInkCaption"
	_status.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_status.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stack.add_child(_status)

	var side: VBoxContainer = VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override(&"separation", 6)
	body.add_child(side)
	_shoot = _button(Loc.t("ÇEK"), _on_shoot)
	_shoot.name = "ShootButton"
	_shoot.kind = HudIcon.Kind.CAMERA
	_shoot.icon_left = true
	_shoot.highlight = true
	side.add_child(_shoot)
	_switch = _button(Loc.t("ÖN / ARKA"), _on_switch)
	side.add_child(_switch)
	side.add_child(_button(Loc.t("VAZGEÇ"), close))


# --- Kamera ----------------------------------------------------------------------

func _start() -> void:
	_session += 1
	var session: int = _session
	_ready_frame = false
	_preview.texture = null
	_shoot.disabled = true
	_switch.visible = false
	_status.text = Loc.t("Kamera açılıyor…")
	if OS.has_feature("android") and not OS.request_permission("android.permission.CAMERA"):
		# İzin penceresi açıldı: sonucu beklenir
		var answer: Array = await get_tree().on_request_permissions_result
		if session != _session:
			return
		if answer.size() < 2 or not bool(answer[1]):
			_status.text = Loc.t("Kamera izni verilmedi. İzin vermek için telefonun Ayarlar > Uygulamalar bölümüne bak.")
			return
	CameraServer.monitoring_feeds = true
	var waited: float = 0.0
	while CameraServer.get_feed_count() == 0 and waited < FEED_WAIT:
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if session != _session:
			return
	_feeds.clear()
	for feed: CameraFeed in CameraServer.feeds():
		if feed.get_position() == CameraFeed.FEED_FRONT:
			_feeds.push_front(feed)
		else:
			_feeds.append(feed)
	if _feeds.is_empty():
		_status.text = Loc.t("Kamera bulunamadı.")
		return
	_switch.visible = _feeds.size() > 1
	_use(0)


func _use(index: int) -> void:
	if _feed:
		_feed.feed_is_active = false
	_index = index % _feeds.size()
	_feed = _feeds[_index]
	_ready_frame = false
	_shoot.disabled = true
	_status.text = Loc.t("Kamera açılıyor…")
	_pick_format(_feed)
	if not _feed.frame_changed.is_connected(_on_frame):
		_feed.frame_changed.connect(_on_frame)
	_feed.feed_is_active = true


## Kameranın biçimlerinden MAX_WIDTH'i aşmayan en büyüğü (biçim listesi boşsa kameranın varsayılanı).
static func _pick_format(feed: CameraFeed) -> void:
	var best: int = -1
	var best_width: int = 0
	var formats: Array = feed.get_formats()
	for i: int in formats.size():
		var format: Dictionary = formats[i] if formats[i] is Dictionary else {}
		var width: int = int(format.get("width", 0))
		if width > best_width and width <= MAX_WIDTH:
			best = i
			best_width = width
	if best >= 0:
		feed.set_format(best, {})


## İlk kare geldi: veri türüne göre doku(lar) bağlanır, çizim alanı kameranın (döndürülmüş) boyuna getirilir.
func _on_frame() -> void:
	if _ready_frame or _feed == null:
		return
	_ready_frame = true
	var id: int = _feed.get_id()
	var separate: bool = _feed.get_datatype() == CameraFeed.FEED_YCBCR_SEP
	var main: CameraTexture = CameraTexture.new()
	main.camera_feed_id = id
	main.which_feed = CameraServer.FEED_Y_IMAGE if separate else CameraServer.FEED_RGBA_IMAGE
	_material.set_shader_parameter(&"separate", separate)
	_material.set_shader_parameter(&"y_tex" if separate else &"rgb_tex", main)
	if separate:
		var cbcr: CameraTexture = CameraTexture.new()
		cbcr.camera_feed_id = id
		cbcr.which_feed = CameraServer.FEED_CBCR_IMAGE
		_material.set_shader_parameter(&"cbcr_tex", cbcr)
	var xform: Transform2D = _feed.feed_transform
	_material.set_shader_parameter(&"feed_x", xform.x)
	_material.set_shader_parameter(&"feed_y", xform.y)
	_material.set_shader_parameter(&"feed_o", xform.origin)
	_material.set_shader_parameter(&"mirror", _feed.get_position() == CameraFeed.FEED_FRONT)
	var frame_size: Vector2 = main.get_size()
	if frame_size.x < 2.0 or frame_size.y < 2.0:
		frame_size = Vector2(640.0, 480.0)
	if absf(xform.x.y) > 0.5:   # 90° dönmüş akış: en / boy yer değiştirir
		frame_size = Vector2(frame_size.y, frame_size.x)
	var k: float = minf(1.0, 1024.0 / maxf(frame_size.x, frame_size.y))
	_viewport.size = Vector2i((frame_size * k).round())
	_rect.size = Vector2(_viewport.size)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview.texture = _viewport.get_texture()
	_status.text = ""
	_shoot.disabled = false


func _on_shoot() -> void:
	if not _ready_frame:
		return
	_shoot.disabled = true
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_status.text = Loc.t("Fotoğraf çekilemedi. Tekrar dene.")
		_shoot.disabled = false
		return
	_shot = image
	close()


func _on_switch() -> void:
	if _feeds.size() > 1:
		_use(_index + 1)


func _stop() -> void:
	_session += 1
	if _feed:
		_feed.feed_is_active = false
		if _feed.frame_changed.is_connected(_on_frame):
			_feed.frame_changed.disconnect(_on_frame)
	_feed = null
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_preview.texture = null
	CameraServer.monitoring_feeds = false


func _button(text: String, callback: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.custom_minimum_size = Vector2(150.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button
