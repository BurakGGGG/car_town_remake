class_name DynoPedal
extends Control
## DİNAMOMETRE gaz pedalı (2026-11-02): kauçuk kaplı pedal; basılı tutunca gaz, parmağı aşağı kaydırdıkça daha çok gaz
## (pedalın üstü %35, altı %100), bırakınca kesik. Basınç çubuğu sağda yeşil dolar, pedal basıldıkça içeri yatar.
## Çok dokunuşlu: bir parmak pedalda, öbürü vites düğmesinde olabilir (dokunuş kimliği izlenir).

signal throttle_changed(value: float)

const MIN_PRESS: float = 0.35

var throttle: float = 0.0
var _touch: int = -2     # -2 = yok, -1 = fare, ≥0 = dokunuş kimliği
var _shown: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(128.0, 250.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)


func _process(delta: float) -> void:
	var before: float = _shown
	_shown = move_toward(_shown, throttle, delta * 6.0)
	if not is_equal_approx(before, _shown):
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed and _touch == -2:
			_touch = touch.index
			_set_from(touch.position)
		elif not touch.pressed and touch.index == _touch:
			_release()
		accept_event()
	elif event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index == _touch:
			_set_from(drag.position)
		accept_event()
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button: InputEventMouseButton = event
		if button.pressed and _touch == -2:
			_touch = -1
			_set_from(button.position)
		elif not button.pressed and _touch == -1:
			_release()
		accept_event()
	elif event is InputEventMouseMotion and _touch == -1:
		_set_from((event as InputEventMouseMotion).position)
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_release()


func _set_from(local: Vector2) -> void:
	var pad: Rect2 = _pad_rect(0.0)
	var t: float = clampf((local.y - pad.position.y) / maxf(pad.size.y, 1.0), 0.0, 1.0)
	_apply_throttle(lerpf(MIN_PRESS, 1.0, t))


func _release() -> void:
	_touch = -2
	_apply_throttle(0.0)


func _apply_throttle(value: float) -> void:
	if is_equal_approx(value, throttle):
		return
	throttle = value
	throttle_changed.emit(throttle)
	queue_redraw()


func _pad_rect(press: float) -> Rect2:
	var top: float = 16.0 + 14.0 * press
	return Rect2(18.0, top, size.x - 46.0, size.y - top - 58.0)


func _draw() -> void:
	var plate: StyleBox = get_theme_stylebox(&"panel", &"HudCarPlate")
	if plate:
		draw_style_box(plate, Rect2(Vector2.ZERO, size))
	var pad: Rect2 = _pad_rect(_shown)
	# gölge + kauçuk pedal + oluklar
	draw_rect(Rect2(pad.position + Vector2(2.0, 5.0), pad.size), Color(0.0, 0.0, 0.0, 0.25), true)
	_round_rect(pad, Color("34363C"), 10.0)
	_round_rect(pad.grow(-3.0), Color("2A2C31"), 8.0)
	var y: float = pad.position.y + 14.0
	while y < pad.end.y - 10.0:
		_round_rect(Rect2(pad.position.x + 12.0, y, pad.size.x - 24.0, 5.0), Color("1C1D21"), 2.5)
		y += 14.0
	# basınç çubuğu
	var bar: Rect2 = Rect2(size.x - 22.0, 16.0, 8.0, size.y - 74.0)
	_round_rect(bar, Color(HudPalette.INK, 0.15), 4.0)
	var fill: float = bar.size.y * _shown
	_round_rect(Rect2(bar.position.x, bar.end.y - fill, bar.size.x, fill), Color("3FA45F"), 4.0)
	var font: Font = get_theme_font(&"font", &"Label")
	draw_string(font, Vector2(0.0, size.y - 30.0), Loc.t("GAZ"), HORIZONTAL_ALIGNMENT_CENTER, size.x - 10.0, 20,
		HudPalette.INK)
	draw_string(font, Vector2(0.0, size.y - 12.0), Loc.t("bas, aşağı kaydır"), HORIZONTAL_ALIGNMENT_CENTER,
		size.x - 10.0, 10, HudPalette.INK_SOFT)


func _round_rect(rect: Rect2, color: Color, radius: float) -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(int(radius))
	draw_style_box(box, rect)
