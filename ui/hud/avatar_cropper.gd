class_name AvatarCropper
extends Control
## PROFİL FOTOĞRAFI KIRPMA (UiRouter alt pano &"avatar_crop"): galeriden / kameradan gelen görüntü yuvarlak
## çerçevede gösterilir; oyuncu parmakla kaydırır, iki parmakla (masaüstünde tekerlekle) yakınlaştırır, gerekirse
## DÖNDÜR'e basar (Godot JPEG'in EXIF yönünü okumaz: telefonla dik çekilen fotoğraf yan gelebilir). TAMAM →
## cropped(kare görüntü, ProfileCatalog.PHOTO_SIZE). Görüntü her zaman daireyi doldurur (boşluk kalmaz).

signal closed
signal cropped(image: Image)

const VIEW: float = 280.0
const MAX_SOURCE: int = 1280
const MAX_ZOOM: float = 5.0

var _view: _CropView
var _column: VBoxContainer
var _closing: bool = false
## Açılış / kapanış sayacı: kapanış animasyonu sürerken yeniden açılırsa eski kapanış (gizle + closed) iptal olur.
var _gen: int = 0


func _ready() -> void:
	name = "AvatarCropper"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


## Kırpılacak görüntü (router.open'dan önce). Çok büyükse küçültülür.
func set_image(image: Image) -> void:
	var img: Image = image.duplicate() as Image
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var longest: int = maxi(img.get_width(), img.get_height())
	if longest > MAX_SOURCE:
		var k: float = float(MAX_SOURCE) / longest
		img.resize(maxi(roundi(img.get_width() * k), 1), maxi(roundi(img.get_height() * k), 1), Image.INTERPOLATE_LANCZOS)
	_view.set_image(img)


func open() -> void:
	_gen += 1
	_closing = false
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	_gen += 1
	var gen: int = _gen
	PlateAnim.pop_out(self, _column, func() -> void:
		if gen != _gen:
			return
		hide()
		_closing = false
		closed.emit())


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center: CenterContainer = FitScroll.center_in(self)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	center.add_child(_column)

	var sign: PlatePanel = PlatePanel.new()
	sign.theme_type_variation = &"HudCarPlate"
	sign.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var title: Label = Label.new()
	title.theme_type_variation = &"HudSignTitle"
	title.text = Loc.t("FOTOĞRAFI YERLEŞTİR")
	sign.add_child(title)
	_column.add_child(sign)

	var body: HBoxContainer = HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override(&"separation", 10)
	_column.add_child(body)
	_view = _CropView.new()
	_view.name = "CropView"
	_view.custom_minimum_size = Vector2(VIEW, VIEW)
	body.add_child(_view)

	var side: VBoxContainer = VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_theme_constant_override(&"separation", 6)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(side)
	var hint: Label = Label.new()
	hint.theme_type_variation = &"HudInkCaption"
	hint.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT)
	hint.text = Loc.t("Kaydır, iki parmakla\nyakınlaştır.")
	side.add_child(hint)
	var rotate: PlateButton = _button(Loc.t("DÖNDÜR"), func() -> void: _view.rotate_quarter())
	rotate.kind = HudIcon.Kind.ROTATE
	rotate.icon_left = true
	side.add_child(rotate)
	var zoom_row: HBoxContainer = HBoxContainer.new()
	zoom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zoom_row.add_theme_constant_override(&"separation", 6)
	var zoom_out: PlateButton = _button("–", func() -> void: _view.zoom_by(1.0 / 1.2))
	zoom_out.custom_minimum_size = Vector2(66.0, 0.0)
	var zoom_in: PlateButton = _button("+", func() -> void: _view.zoom_by(1.2))
	zoom_in.custom_minimum_size = Vector2(66.0, 0.0)
	zoom_row.add_child(zoom_out)
	zoom_row.add_child(zoom_in)
	side.add_child(zoom_row)
	side.add_child(_button(Loc.t("VAZGEÇ"), close))
	var done: PlateButton = _button(Loc.t("TAMAM"), _on_done)
	done.name = "DoneButton"
	done.highlight = true
	side.add_child(done)


func _on_done() -> void:
	var image: Image = _view.crop()
	if image:
		cropped.emit(image)
	close()


func _button(text: String, callback: Callable) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.theme_type_variation = &"HudPlateSmall"
	button.text = text
	button.bolts = false
	button.custom_minimum_size = Vector2(138.0, 0.0)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button


## Kırpma alanı: görüntü daireyi kaplayacak ölçekte çizilir, dairenin dışı karartılır.
class _CropView:
	extends Control

	var _image: Image
	var _tex: ImageTexture
	var _zoom: float = 1.0
	var _offset: Vector2 = Vector2.ZERO   # görüntü merkezinin alan merkezinden kayması (tuval birimi)
	var _touches: Dictionary = {}         # dokunma indeksi → konum

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		clip_contents = true

	func set_image(image: Image) -> void:
		_image = image
		_tex = ImageTexture.create_from_image(image)
		_zoom = 1.0
		_offset = Vector2.ZERO
		queue_redraw()

	func rotate_quarter() -> void:
		if _image == null:
			return
		_image.rotate_90(CLOCKWISE)
		set_image(_image)

	func zoom_by(factor: float) -> void:
		_zoom = clampf(_zoom * factor, 1.0, AvatarCropper.MAX_ZOOM)
		_clamp()
		queue_redraw()

	## Alanı kaplayan ölçek × yakınlaştırma (tuval birimi / kaynak pikseli).
	func _scale() -> float:
		if _image == null:
			return 1.0
		return minf(size.x, size.y) / float(mini(_image.get_width(), _image.get_height())) * _zoom

	func _clamp() -> void:
		if _image == null:
			return
		var shown: Vector2 = Vector2(_image.get_size()) * _scale()
		var room: Vector2 = ((shown - size) * 0.5).max(Vector2.ZERO)
		_offset = _offset.clamp(-room, room)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventScreenTouch:
			var touch: InputEventScreenTouch = event
			if touch.pressed:
				_touches[touch.index] = touch.position
			else:
				_touches.erase(touch.index)
			accept_event()
		elif event is InputEventScreenDrag:
			var drag: InputEventScreenDrag = event
			if _touches.size() >= 2 and _touches.has(drag.index):
				var other: Vector2 = Vector2.ZERO
				for index: int in _touches:
					if index != drag.index:
						other = _touches[index]
						break
				var before: float = (_touches[drag.index] as Vector2).distance_to(other)
				var after: float = drag.position.distance_to(other)
				if before > 4.0:
					zoom_by(after / before)
				_offset += drag.relative * 0.5
			else:
				_offset += drag.relative
			_touches[drag.index] = drag.position
			_clamp()
			queue_redraw()
			accept_event()
		elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
			var motion: InputEventMouseMotion = event
			if motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_offset += motion.relative
				_clamp()
				queue_redraw()
				accept_event()
		elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
			var button: InputEventMouseButton = event
			if button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom_by(1.1)
				accept_event()
			elif button.pressed and button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(1.0 / 1.1)
				accept_event()
		elif event is InputEventMagnifyGesture:
			zoom_by((event as InputEventMagnifyGesture).factor)
			accept_event()

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2F3236"))
		if _tex == null:
			return
		var shown: Vector2 = Vector2(_image.get_size()) * _scale()
		draw_texture_rect(_tex, Rect2(size * 0.5 + _offset - shown * 0.5, shown), false)
		# Dairenin dışı karartılır (kare kırpılır, oyunda daire içinde görünür): köşelere kadar uzanan kalın halka;
		# alanın dışına taşan kısmı clip_contents keser. (Delikli çokgen üçgenlenirken delik kayboluyordu.)
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 2.0
		var outer: float = size.length() * 0.5 + 2.0
		draw_arc(c, (r + outer) * 0.5, 0.0, TAU, 64, Color(0.0, 0.0, 0.0, 0.55), outer - r)
		draw_arc(c, r, 0.0, TAU, 64, HudPalette.PLATE_SELECTED, 3.0, true)

	## Görünen kare (daireyi çevreleyen) kaynak pikselinde kesilir ve PHOTO_SIZE'a getirilir.
	func crop() -> Image:
		if _image == null:
			return null
		var s: float = _scale()
		var shown: Vector2 = Vector2(_image.get_size()) * s
		var top_left: Vector2 = size * 0.5 + _offset - shown * 0.5
		var side: float = minf(size.x, size.y)
		var origin: Vector2 = (size * 0.5 - Vector2(side, side) * 0.5 - top_left) / s
		var rect: Rect2i = Rect2i(Vector2i(origin.round()), Vector2i(roundi(side / s), roundi(side / s)))
		rect = rect.intersection(Rect2i(Vector2i.ZERO, _image.get_size()))
		if rect.size.x < 8 or rect.size.y < 8:
			return null
		var out: Image = _image.get_region(rect)
		out.resize(ProfileCatalog.PHOTO_SIZE, ProfileCatalog.PHOTO_SIZE, Image.INTERPOLATE_LANCZOS)
		return out
