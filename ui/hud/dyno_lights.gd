class_name DynoLights
extends Control
## DİNAMOMETRE vites ışıkları: 10 LED, devirle yanar (yeşil → sarı → kırmızı); devir kesicide hepsi yanıp söner.

const COUNT: int = 10

var ratio: float = 0.0:
	set(value):
		if not is_equal_approx(value, ratio):
			ratio = value
			queue_redraw()
var flashing: bool = false:
	set(value):
		if value != flashing:
			flashing = value
			queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(COUNT * 14.0, 14.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if flashing:
		queue_redraw()


func _draw() -> void:
	var lit: int = roundi(ratio * COUNT)
	var blink: bool = flashing and int(Time.get_ticks_msec() / 70) % 2 == 0
	var step: float = size.x / COUNT
	for i: int in COUNT:
		var color: Color = Color("40AA5A") if i < 5 else (Color("F0B428") if i < 8 else Color("DC3C32"))
		var on: bool = (i < lit and not flashing) or blink
		var c: Vector2 = Vector2(step * (i + 0.5), size.y * 0.5)
		draw_circle(c, minf(step, size.y) * 0.38, color if on else Color(HudPalette.INK, 0.14), true, -1.0, true)
