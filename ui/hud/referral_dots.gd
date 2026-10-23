class_name ReferralDots
extends Control
## DAVET İLERLEMESİ (POSTA penceresindeki davet ödülü, 2026-10-23): dokuz yuvarlak + sonda "10" rozeti. Ulaşılan
## basamaklar altın; şimdiki basamak büyük ve koyu kenarlı; 10. basamak koyu zeminde altın (büyük ödül). Kodla çizilir.

const DOT: float = 18.0
const GAP: float = 7.0
const FINAL: Vector2 = Vector2(30.0, 24.0)

## Kaçıncı basamağa ulaşıldı (0–10).
var reached: int = 0:
	set(value):
		reached = value
		queue_redraw()
## Vurgulanan basamak (yeni alınan; 0 = yok).
var current: int = 0:
	set(value):
		current = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(_width(), FINAL.y + 6.0)


func _width() -> float:
	return float(ReferralRewards.max_tier() - 1) * (DOT + GAP) + FINAL.x


func _draw() -> void:
	var total: int = ReferralRewards.max_tier()
	var y: float = size.y * 0.5
	var x: float = (size.x - _width()) * 0.5
	for i: int in range(1, total):
		var c: Vector2 = Vector2(x + DOT * 0.5, y)
		var now: bool = i == current
		var filled: bool = i <= reached
		var r: float = DOT * (0.62 if now else 0.5)
		draw_circle(c, r, HudPalette.PLATE_SELECTED if filled else Color(HudPalette.PLATE_EDGE, 0.3))
		var edge: Color = HudPalette.INK if now else (HudPalette.PLATE_SELECTED_EDGE if filled else HudPalette.PLATE_EDGE)
		draw_arc(c, r, 0.0, TAU, 24, edge, 2.0 if now else 1.0, true)
		x += DOT + GAP
	var rect: Rect2 = Rect2(Vector2(x, y - FINAL.y * 0.5), FINAL)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = HudPalette.INK
	style.border_color = HudPalette.PLATE_SELECTED
	style.set_border_width_all(3 if current == total else 2)
	style.set_corner_radius_all(6)
	style.draw(get_canvas_item(), rect)
	var font: Font = get_theme_default_font()
	var font_size: int = 12
	var text: String = str(total)
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var base: Vector2 = rect.get_center() + Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 1.0)
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, HudPalette.PLATE_SELECTED)
