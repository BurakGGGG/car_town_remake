class_name InboxCover
extends Control
## HABERLER kutusunda bir haberin kapağı (2026-10-25): panelden resim geldiyse o (kırpılarak doldurur), yoksa türün hazır
## çizimi açık renkli zemin üstünde — HEDİYE kutu, GÜNCELLEME "YENİ" rozeti, ETKİNLİK dama bayrak, DUYURU megafon,
## MESAJ zarf, MİSAFİR kask. Çizimler oyunun 2B dilinde: düz renk + tek gölge tonu + koyu kontur. Alınmış hediye soluk.

const TINTS: Dictionary = {
	&"gift": Color("F4D6CF"), &"update": Color("CFE0DE"), &"event": Color("F7E3B0"), &"notice": Color("E2DCCD"),
	&"message": Color("E9E0CC"), &"guest": Color("D7E6F2"),
}
const RED: Color = Color("D9534F")
const RED_DARK: Color = Color("B5453F")
const RED_LIGHT: Color = Color("E46A5F")
const TEAL: Color = Color("4F8F94")
const OUTLINE: float = 2.0

var kind: StringName = &"notice":
	set(value):
		kind = value
		queue_redraw()
var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
## Alınmış hediye: soluk çizim.
var faded: bool = false:
	set(value):
		faded = value
		queue_redraw()
var corner: int = 8
## Zeminsiz: yalnız çizim (hediye ekranının rozetinde).
var bare: bool = false
## Resmi kırpmadan sığdır (saydam araç resmi: kırpılınca tavanı / tekerleri kesiliyordu).
var fit: bool = false:
	set(value):
		fit = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _draw() -> void:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = TINTS.get(kind, TINTS[&"notice"])
	box.set_corner_radius_all(corner)
	if faded:
		box.bg_color = box.bg_color.lerp(HudPalette.PLATE, 0.6)
	if not bare:
		draw_style_box(box, Rect2(Vector2.ZERO, size))
	if texture:
		_draw_cover_texture()
		return
	var s: float = minf(size.x, size.y) * 0.78
	var c: Vector2 = size * 0.5
	var ink: Color = HudPalette.INK
	match kind:
		&"gift":
			_gift(c, s, ink)
		&"update":
			_badge(c, s, ink)
		&"event":
			HudIcon.draw_icon(self, HudIcon.Kind.FLAG, c, s * 0.92, ink, Color.WHITE)
		&"message":
			_envelope(c, s, ink)
		&"guest":
			HudIcon.draw_icon(self, HudIcon.Kind.HELMET, c, s * 0.9, ink, box.bg_color)
		_:
			_megaphone(c, s, ink)
	if faded:
		draw_style_box(_veil(), Rect2(Vector2.ZERO, size))


## Resim kapağı: kutuyu taşmadan doldurur (ortadan kırpar).
func _draw_cover_texture() -> void:
	var tex_size: Vector2 = texture.get_size()
	if tex_size.x <= 0.0 or tex_size.y <= 0.0:
		return
	if fit:
		var shown: Vector2 = tex_size * minf(size.x / tex_size.x, size.y / tex_size.y) * 0.92
		draw_texture_rect(texture, Rect2((size - shown) * 0.5, shown), false, Color(1, 1, 1, 0.55) if faded else Color.WHITE)
		return
	var k: float = maxf(size.x / tex_size.x, size.y / tex_size.y)
	var src_size: Vector2 = size / k
	var src: Rect2 = Rect2((tex_size - src_size) * 0.5, src_size)
	draw_texture_rect_region(texture, Rect2(Vector2.ZERO, size), src, Color(1, 1, 1, 0.55) if faded else Color.WHITE)


func _veil() -> StyleBoxFlat:
	var veil: StyleBoxFlat = StyleBoxFlat.new()
	veil.bg_color = Color(HudPalette.PLATE, 0.45)
	veil.set_corner_radius_all(corner)
	return veil


func _p(c: Vector2, s: float, x: float, y: float) -> Vector2:
	return c + Vector2(x, y) * s


func _shape(points: PackedVector2Array, fill: Color, ink: Color) -> void:
	draw_colored_polygon(points, fill)
	var loop: PackedVector2Array = points.duplicate()
	loop.append(points[0])
	draw_polyline(loop, ink, OUTLINE, true)


func _box(c: Vector2, s: float, x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([_p(c, s, x, y), _p(c, s, x + w, y), _p(c, s, x + w, y + h), _p(c, s, x, y + h)])


## Hediye: kırmızı kutu (alt gölge bandı), kapak, amber kurdele, iki dolu ilmek ve düğüm.
func _gift(c: Vector2, s: float, ink: Color) -> void:
	for side: float in [-1.0, 1.0]:
		var loop: PackedVector2Array = PackedVector2Array()
		for i: int in 18:
			var a: float = TAU * float(i) / 18.0
			var p: Vector2 = Vector2(cos(a) * 0.15, sin(a) * 0.08).rotated(-side * 0.45)   # dış ucu yukarı kalkık
			loop.append(_p(c, s, side * 0.13 + p.x, -0.31 + p.y))
		_shape(loop, HudPalette.COIN, ink)
		draw_circle(_p(c, s, side * 0.14, -0.31), s * 0.035, HudPalette.COIN_DARK, true, -1.0, true)
	_shape(_box(c, s, -0.34, -0.06, 0.68, 0.44), RED, ink)
	draw_colored_polygon(_box(c, s, -0.32, 0.24, 0.64, 0.12), RED_DARK)
	_shape(_box(c, s, -0.40, -0.22, 0.80, 0.18), RED_LIGHT, ink)
	_shape(_box(c, s, -0.07, -0.22, 0.14, 0.60), HudPalette.COIN, ink)
	_shape(_box(c, s, -0.06, -0.35, 0.12, 0.10), HudPalette.COIN, ink)   # düğüm


## Güncelleme: 12 köşeli teal yıldız rozet, içinde YENİ.
func _badge(c: Vector2, s: float, ink: Color) -> void:
	var star: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var r: float = 0.46 if i % 2 == 0 else 0.36
		var a: float = TAU * float(i) / 24.0 - PI * 0.5
		star.append(c + Vector2(cos(a), sin(a)) * r * s)
	_shape(star, TEAL, ink)
	var font: Font = get_theme_font(&"font", &"Label")
	if font:
		var text: String = Loc.t("YENİ")
		var font_size: int = maxi(int(s * 0.2), 8)
		var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
		draw_string(font, c + Vector2(-w * 0.5, font_size * 0.36), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


## Duyuru: krem gövdeli megafon, kırmızı ağız ve arka, sap, ses çizgileri.
func _megaphone(c: Vector2, s: float, ink: Color) -> void:
	_shape(PackedVector2Array([_p(c, s, -0.17, 0.12), _p(c, s, -0.12, 0.36), _p(c, s, -0.02, 0.36), _p(c, s, -0.05, 0.16)]),
		Color("8A7F68"), ink)
	_shape(_box(c, s, -0.40, -0.14, 0.14, 0.28), RED, ink)
	_shape(PackedVector2Array([_p(c, s, -0.28, -0.12), _p(c, s, -0.18, -0.12), _p(c, s, 0.16, -0.32), _p(c, s, 0.16, 0.32),
		_p(c, s, -0.18, 0.12), _p(c, s, -0.28, 0.12)]), HudPalette.PLATE, ink)
	var mouth: PackedVector2Array = PackedVector2Array()
	for i: int in 16:
		var a: float = TAU * float(i) / 16.0
		mouth.append(_p(c, s, 0.16 + 0.07 * cos(a), 0.32 * sin(a)))
	_shape(mouth, RED, ink)
	for line: Array in [[0.30, -0.18, 0.40, -0.25], [0.32, 0.0, 0.44, 0.0], [0.30, 0.18, 0.40, 0.25]]:
		draw_line(_p(c, s, line[0], line[1]), _p(c, s, line[2], line[3]), ink, OUTLINE * 1.2, true)


## Mesaj: krem zarf, kapak çizgileri ve kırmızı mühür.
func _envelope(c: Vector2, s: float, ink: Color) -> void:
	_shape(_box(c, s, -0.40, -0.26, 0.80, 0.52), HudPalette.PLATE, ink)
	draw_polyline(PackedVector2Array([_p(c, s, -0.40, -0.26), _p(c, s, 0.0, 0.06), _p(c, s, 0.40, -0.26)]), ink, OUTLINE, true)
	draw_circle(_p(c, s, 0.0, 0.06), s * 0.09, RED, true, -1.0, true)
	draw_circle(_p(c, s, 0.0, 0.06), s * 0.09, ink, false, OUTLINE, true)
