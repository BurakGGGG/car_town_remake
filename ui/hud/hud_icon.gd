@tool
class_name HudIcon
extends Control
## Kod ile çizilen, dolgulu ve tombul HUD ikonları (asset yok).
## draw_icon() statik: PlateButton gibi başka CanvasItem'lar da kullanır.
## Node olarak eklendiğinde (coin/gem gibi) kendi alanına çizer.

enum Kind {
	NONE,
	GARAGE,
	CAR,
	SHOP,
	HELMET,
	CAMERA,
	SPEAKER,
	SPEAKER_OFF,
	WRENCH,
	ZOOM_IN,
	ZOOM_OUT,
	ROTATE,
	COIN,
	GEM,
	PAINT,  ## sprey boya kutusu (boya atölyesi) — sona eklendi: sahnelerdeki kayıtlı numaralar değişmez
	GEAR,   ## dişli (AYARLAR) — sona eklendi
}

@export var kind: Kind = Kind.COIN:
	set(value):
		kind = value
		queue_redraw()

## Ana mürekkep rengi (COIN ve GEM kendi renklerini kullanır).
@export var color: Color = HudPalette.INK:
	set(value):
		color = value
		queue_redraw()

## Pencere, kapı gibi "boşluk" alanlarının rengi (zemin rengi).
@export var cutout: Color = HudPalette.PLATE:
	set(value):
		cutout = value
		queue_redraw()

@export_range(8.0, 64.0, 1.0) var icon_size: float = 16.0:
	set(value):
		icon_size = value
		update_minimum_size()
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(icon_size, icon_size)


func _draw() -> void:
	draw_icon(self, kind, size * 0.5, icon_size, color, cutout)


# --- Statik çizim ------------------------------------------------------------

## `c` merkez, `s` ikon boyutu (piksel). Şekiller [-0.5, 0.5] birim karede tanımlı.
static func draw_icon(ci: CanvasItem, kind: Kind, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	var w: float = maxf(1.5, s * 0.11)  # çizgi kalınlığı ikonla ölçeklenir
	match kind:
		Kind.GARAGE:
			_garage(ci, c, s, ink, cutout, w)
		Kind.CAR:
			_car(ci, c, s, ink, cutout, w)
		Kind.SHOP:
			_shop(ci, c, s, ink, cutout)
		Kind.HELMET:
			_helmet(ci, c, s, ink, cutout)
		Kind.CAMERA:
			_camera(ci, c, s, ink, cutout)
		Kind.SPEAKER:
			_speaker(ci, c, s, ink, false, w)
		Kind.SPEAKER_OFF:
			_speaker(ci, c, s, ink, true, w)
		Kind.WRENCH:
			_wrench(ci, c, s, ink, cutout)
		Kind.ZOOM_IN:
			_zoom(ci, c, s, ink, true, w)
		Kind.ZOOM_OUT:
			_zoom(ci, c, s, ink, false, w)
		Kind.ROTATE:
			_rotate(ci, c, s, ink, w)
		Kind.COIN:
			_coin(ci, c, s, w)
		Kind.GEM:
			_gem(ci, c, s)
		Kind.PAINT:
			_paint(ci, c, s, ink, cutout)
		Kind.GEAR:
			_gear(ci, c, s, ink, cutout)
		_:
			pass


## Dişli: 8 diş + gövde + ortada delik.
static func _gear(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	for i: int in 8:
		var angle: float = TAU * float(i) / 8.0
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		var side: Vector2 = Vector2(-dir.y, dir.x) * 0.075 * s
		var inner: Vector2 = c + dir * 0.26 * s
		var outer: Vector2 = c + dir * 0.46 * s
		ci.draw_colored_polygon(PackedVector2Array([inner - side, outer - side * 0.8, outer + side * 0.8, inner + side]), ink)
	ci.draw_circle(c, 0.33 * s, ink, true, -1.0, true)
	ci.draw_circle(c, 0.13 * s, cutout, true, -1.0, true)


static func _pts(c: Vector2, s: float, raw: PackedVector2Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in raw:
		out.append(c + p * s)
	return out


static func _poly(ci: CanvasItem, c: Vector2, s: float, raw: PackedVector2Array, color: Color) -> void:
	ci.draw_colored_polygon(_pts(c, s, raw), color)


static func _rect(ci: CanvasItem, c: Vector2, s: float, pos: Vector2, sz: Vector2, color: Color) -> void:
	ci.draw_rect(Rect2(c + pos * s, sz * s), color, true)


static func _round_rect(ci: CanvasItem, c: Vector2, s: float, pos: Vector2, sz: Vector2, radius: float, color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(int(round(radius * s)))
	sb.anti_aliasing = true
	sb.draw(ci.get_canvas_item(), Rect2(c + pos * s, sz * s))


static func _dome(c: Vector2, r: float, from: float, to: float, steps: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in steps + 1:
		pts.append(c + Vector2.from_angle(lerpf(from, to, float(i) / steps)) * r)
	return pts


# --- Navigasyon ikonları -----------------------------------------------------

static func _garage(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_poly(ci, c, s, PackedVector2Array([
		Vector2(-0.48, 0.44), Vector2(-0.48, -0.10), Vector2(0.0, -0.46),
		Vector2(0.48, -0.10), Vector2(0.48, 0.44),
	]), ink)
	_rect(ci, c, s, Vector2(-0.28, 0.02), Vector2(0.56, 0.42), cutout)  # kepenk
	ci.draw_line(c + Vector2(-0.28, 0.16) * s, c + Vector2(0.28, 0.16) * s, ink, w * 0.6, true)
	ci.draw_line(c + Vector2(-0.28, 0.30) * s, c + Vector2(0.28, 0.30) * s, ink, w * 0.6, true)


static func _car(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_poly(ci, c, s, PackedVector2Array([
		Vector2(-0.50, 0.22), Vector2(-0.50, -0.02), Vector2(-0.34, -0.06), Vector2(-0.20, -0.30),
		Vector2(0.22, -0.30), Vector2(0.40, -0.06), Vector2(0.50, -0.02), Vector2(0.50, 0.22),
	]), ink)
	_poly(ci, c, s, PackedVector2Array([  # camlar
		Vector2(-0.16, -0.24), Vector2(0.18, -0.24), Vector2(0.30, -0.08), Vector2(-0.26, -0.08),
	]), cutout)
	ci.draw_line(c + Vector2(0.02, -0.24) * s, c + Vector2(0.02, -0.08) * s, ink, w * 0.5, true)  # B direği
	for x: float in [-0.28, 0.28]:
		var wheel: Vector2 = c + Vector2(x, 0.20) * s
		ci.draw_circle(wheel, s * 0.14, ink, true, -1.0, true)
		ci.draw_circle(wheel, s * 0.055, cutout, true, -1.0, true)


static func _shop(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	# Tente: bar + altında dalgalı uçlar
	_rect(ci, c, s, Vector2(-0.48, -0.42), Vector2(0.96, 0.16), ink)
	for x: float in [-0.36, -0.12, 0.12, 0.36]:
		ci.draw_circle(c + Vector2(x, -0.26) * s, s * 0.12, ink, true, -1.0, true)
	# Gövde
	_rect(ci, c, s, Vector2(-0.42, -0.06), Vector2(0.84, 0.50), ink)
	_rect(ci, c, s, Vector2(-0.09, 0.12), Vector2(0.18, 0.32), cutout)   # kapı
	_rect(ci, c, s, Vector2(-0.34, 0.08), Vector2(0.17, 0.16), cutout)   # vitrin sol
	_rect(ci, c, s, Vector2(0.17, 0.08), Vector2(0.17, 0.16), cutout)    # vitrin sağ


static func _helmet(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	var pts: PackedVector2Array = _dome(c + Vector2(0.0, -0.02) * s, s * 0.44, PI, TAU, 20)
	pts.append(c + Vector2(0.44, 0.36) * s)
	pts.append(c + Vector2(0.30, 0.44) * s)
	pts.append(c + Vector2(-0.30, 0.44) * s)
	pts.append(c + Vector2(-0.44, 0.36) * s)
	ci.draw_colored_polygon(pts, ink)
	_round_rect(ci, c, s, Vector2(-0.30, -0.12), Vector2(0.72, 0.28), 0.08, cutout)  # vizör
	_rect(ci, c, s, Vector2(-0.44, 0.10), Vector2(0.16, 0.06), ink)  # vizör menteşesi


# --- Araç butonları ----------------------------------------------------------

static func _camera(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	_round_rect(ci, c, s, Vector2(-0.46, -0.22), Vector2(0.92, 0.60), 0.10, ink)
	_rect(ci, c, s, Vector2(-0.22, -0.36), Vector2(0.32, 0.16), ink)   # üst çıkıntı
	ci.draw_circle(c + Vector2(0.02, 0.08) * s, s * 0.18, cutout, true, -1.0, true)
	ci.draw_circle(c + Vector2(0.02, 0.08) * s, s * 0.09, ink, true, -1.0, true)


static func _speaker(ci: CanvasItem, c: Vector2, s: float, ink: Color, muted: bool, w: float) -> void:
	_poly(ci, c, s, PackedVector2Array([
		Vector2(-0.46, -0.16), Vector2(-0.28, -0.16), Vector2(-0.06, -0.38),
		Vector2(-0.06, 0.38), Vector2(-0.28, 0.16), Vector2(-0.46, 0.16),
	]), ink)
	if muted:
		ci.draw_line(c + Vector2(0.12, -0.16) * s, c + Vector2(0.42, 0.16) * s, ink, w, true)
		ci.draw_line(c + Vector2(0.42, -0.16) * s, c + Vector2(0.12, 0.16) * s, ink, w, true)
	else:
		var o: Vector2 = c + Vector2(-0.04, 0.0) * s
		ci.draw_arc(o, s * 0.20, -PI / 4.0, PI / 4.0, 12, ink, w, true)
		ci.draw_arc(o, s * 0.36, -PI / 4.0, PI / 4.0, 16, ink, w, true)


static func _wrench(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	# Sap: sol-alttan sağ-üste kalın çizgi
	ci.draw_line(c + Vector2(-0.36, 0.36) * s, c + Vector2(0.10, -0.10) * s, ink, s * 0.24, true)
	ci.draw_circle(c + Vector2(-0.36, 0.36) * s, s * 0.12, ink, true, -1.0, true)
	# Baş ve ağız
	ci.draw_circle(c + Vector2(0.18, -0.18) * s, s * 0.28, ink, true, -1.0, true)
	_poly(ci, c, s, PackedVector2Array([
		Vector2(0.12, -0.12), Vector2(0.36, -0.58), Vector2(0.58, -0.36),
	]), cutout)
	ci.draw_circle(c + Vector2(0.16, -0.16) * s, s * 0.07, cutout, true, -1.0, true)


static func _paint(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	# Kutu gövdesi, etiket bandı, kapak ve memeden çıkan üç sprey noktası
	_round_rect(ci, c, s, Vector2(-0.30, -0.12), Vector2(0.40, 0.56), 0.06, ink)
	_rect(ci, c, s, Vector2(-0.30, 0.04), Vector2(0.40, 0.14), cutout)   # etiket bandı
	_rect(ci, c, s, Vector2(-0.22, -0.26), Vector2(0.24, 0.12), ink)     # kapak
	_rect(ci, c, s, Vector2(-0.14, -0.36), Vector2(0.08, 0.10), ink)     # meme
	for dot: Vector2 in [Vector2(0.14, -0.40), Vector2(0.28, -0.32), Vector2(0.24, -0.48)]:
		ci.draw_circle(c + dot * s, s * 0.045, ink, true, -1.0, true)


static func _zoom(ci: CanvasItem, c: Vector2, s: float, ink: Color, plus: bool, w: float) -> void:
	var lens: Vector2 = c + Vector2(-0.08, -0.08) * s
	var r: float = s * 0.28
	ci.draw_arc(lens, r, 0.0, TAU, 28, ink, w * 1.1, true)
	ci.draw_line(lens + Vector2.ONE.normalized() * r, c + Vector2(0.42, 0.42) * s, ink, w * 1.5, true)
	ci.draw_line(lens + Vector2(-0.14, 0.0) * s, lens + Vector2(0.14, 0.0) * s, ink, w, true)
	if plus:
		ci.draw_line(lens + Vector2(0.0, -0.14) * s, lens + Vector2(0.0, 0.14) * s, ink, w, true)


static func _rotate(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	var r: float = s * 0.32
	var start: float = deg_to_rad(-40.0)
	var end: float = deg_to_rad(235.0)
	ci.draw_arc(c, r, start, end, 28, ink, w * 1.1, true)
	var radial: Vector2 = Vector2.from_angle(end)
	var tangent: Vector2 = Vector2.from_angle(end + PI / 2.0)
	var base: Vector2 = c + radial * r
	ci.draw_colored_polygon(PackedVector2Array([
		base + tangent * s * 0.20, base + radial * s * 0.14, base - radial * s * 0.14,
	]), ink)


# --- Para birimleri ----------------------------------------------------------

static func _coin(ci: CanvasItem, c: Vector2, s: float, w: float) -> void:
	ci.draw_circle(c + Vector2(0.0, 0.04) * s, s * 0.48, HudPalette.COIN_DARK, true, -1.0, true)
	ci.draw_circle(c, s * 0.44, HudPalette.COIN, true, -1.0, true)
	ci.draw_arc(c, s * 0.30, 0.0, TAU, 24, HudPalette.COIN_DARK, w * 0.7, true)
	ci.draw_arc(c, s * 0.36, PI * 1.15, PI * 1.55, 10, Color(1.0, 1.0, 1.0, 0.7), w * 0.7, true)


static func _gem(ci: CanvasItem, c: Vector2, s: float) -> void:
	var shape: PackedVector2Array = PackedVector2Array([
		Vector2(-0.30, -0.36), Vector2(0.30, -0.36), Vector2(0.50, -0.06),
		Vector2(0.0, 0.48), Vector2(-0.50, -0.06),
	])
	_poly(ci, c + Vector2(0.0, 0.04) * s, s, shape, HudPalette.GEM_DARK)
	_poly(ci, c, s * 0.92, shape, HudPalette.GEM)
	_poly(ci, c, s * 0.92, PackedVector2Array([
		Vector2(-0.30, -0.36), Vector2(0.30, -0.36), Vector2(0.38, -0.06), Vector2(-0.38, -0.06),
	]), HudPalette.GEM_LIGHT)
