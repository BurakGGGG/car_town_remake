@tool
class_name PlatePanel
extends PanelContainer
## Buton olmayan plaka (araç bilgi alanı gibi). Zemin temadan; cıvatalar burada çizilir.

@export var bolt_color: Color = Color(HudPalette.INK, 0.45):
	set(value):
		bolt_color = value
		queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(8.0, 8.0), 1.8, bolt_color, true, -1.0, true)
	draw_circle(Vector2(size.x - 8.0, 8.0), 1.8, bolt_color, true, -1.0, true)
