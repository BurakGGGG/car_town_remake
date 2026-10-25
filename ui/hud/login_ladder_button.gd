class_name LoginLadderButton
extends PlateButton
## Sağ üstteki GÜNLÜK GİRİŞ tabelası (MARKET'in yanında; 2026-10-23): kamera / ayar dilinde yuvarlak tabela, içinde
## kırmızı başlıklı, halkalı küçük takvim yaprağı ve merdivenin BUGÜNKÜ gün numarası (1..28). Günün basamağı
## alınabilirken kırmızı rozet + birkaç saniyede bir zıplama (hazır ödül köşede dikkat çeker). Basınca merdiven ekranı.

const BOUNCE_EVERY: float = 3.0

## Takvim yaprağındaki gün (merdivenin bugünkü basamağı).
var day: int = 1:
	set(value):
		day = value
		queue_redraw()
## Bugünün basamağı alınabilir mi (rozet + zıplama).
var ready_to_claim: bool = false:
	set(value):
		ready_to_claim = value
		badge = 1 if value else 0
		set_process(value)

var _t: float = 0.0
var _next_bounce: float = 1.0


func _init() -> void:
	shape = Shape.ROUND
	kind = HudIcon.Kind.NONE
	bolts = false
	lift_when_pressed = 0.0
	theme_type_variation = &"HudSign"
	focus_mode = Control.FOCUS_NONE


func _ready() -> void:
	super._ready()
	resized.connect(func() -> void: pivot_offset = size * 0.5)
	pivot_offset = size * 0.5
	set_process(ready_to_claim)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _t >= _next_bounce:
		_next_bounce = _t + BOUNCE_EVERY
		var tween: Tween = create_tween()
		tween.tween_property(self, "scale", Vector2(1.12, 0.92), 0.10).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "scale", Vector2(0.94, 1.08), 0.12).set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5 + Vector2(0.0, 1.0)
	var w: float = s * 0.52
	var h: float = s * 0.50
	var page: Rect2 = Rect2(c - Vector2(w, h) * 0.5, Vector2(w, h))
	var ink: Color = get_theme_color(&"font_color")
	# Yaprak: gölge, krem zemin, kırmızı başlık, iki halka
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = Color(0.0, 0.0, 0.0, 0.25)
	shadow.set_corner_radius_all(int(s * 0.07))
	draw_style_box(shadow, Rect2(page.position + Vector2(1.5, 2.0), page.size))
	var sheet: StyleBoxFlat = StyleBoxFlat.new()
	sheet.bg_color = Color("FFF8EA")
	sheet.set_corner_radius_all(int(s * 0.07))
	sheet.set_border_width_all(2)
	sheet.border_color = ink
	draw_style_box(sheet, page)
	var head: StyleBoxFlat = StyleBoxFlat.new()
	head.bg_color = Color("E2474F")
	head.corner_radius_top_left = int(s * 0.07)
	head.corner_radius_top_right = int(s * 0.07)
	head.set_border_width_all(2)
	head.border_color = ink
	draw_style_box(head, Rect2(page.position, Vector2(w, h * 0.32)))
	for sx: float in [-0.22, 0.22]:
		var ring: Vector2 = Vector2(c.x + w * sx, page.position.y)
		draw_rect(Rect2(ring - Vector2(s * 0.035, s * 0.07), Vector2(s * 0.07, s * 0.12)), ink, true)
	# Gün numarası
	var font: Font = get_theme_font(&"font")
	if font:
		var text: String = str(day)
		var font_size: int = int(h * (0.56 if text.length() < 2 else 0.5))
		var body_top: float = page.position.y + h * 0.32
		var baseline: float = body_top + (page.end.y - body_top) * 0.5 + font_size * 0.36
		draw_string(font, Vector2(page.position.x, baseline), text, HORIZONTAL_ALIGNMENT_CENTER, w, font_size, ink)
	_draw_badge(TriBatch.new())
