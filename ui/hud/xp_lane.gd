@tool
class_name XpLane
extends Control
## XP göstergesi: asfalt zemin üstünde kesikli şerit çizgisi. Dolan kısım amber "boya",
## kalan kısım solgun beyaz — yoldaki şerit çizgileriyle aynı dil.

@export_range(0.0, 1.0, 0.01) var ratio: float = 0.35:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

@export_range(2, 16) var segments: int = 6:
	set(value):
		segments = value
		queue_redraw()

@export var track_color: Color = HudPalette.LANE_TRACK
@export var paint_color: Color = HudPalette.LANE_PAINT
@export var faded_color: Color = HudPalette.LANE_FADED


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(60.0, 10.0)


func _draw() -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = track_color
	track.set_corner_radius_all(3)
	track.anti_aliasing = true
	track.draw(get_canvas_item(), Rect2(Vector2.ZERO, size))

	var gap: float = 3.0
	var inset: float = 3.0
	var seg_w: float = (size.x - inset * 2.0 - gap * (segments - 1)) / segments
	var seg_h: float = size.y - 5.0
	var filled: float = ratio * segments
	for i: int in segments:
		var x: float = inset + i * (seg_w + gap)
		var rect: Rect2 = Rect2(x, 2.5, seg_w, seg_h)
		draw_rect(rect, faded_color, true)
		var part: float = clampf(filled - i, 0.0, 1.0)
		if part > 0.0:
			draw_rect(Rect2(x, 2.5, seg_w * part, seg_h), paint_color, true)
