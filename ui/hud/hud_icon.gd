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
	MAP,    ## katlanmış harita + iğne (HARİTA) — sona eklendi
	# GARAJI DÜZENLE ikonları — sona eklendi (sahnelerdeki kayıtlı numaralar değişmez)
	GRID,      ## ızgara (yapış)
	UNDO,      ## geri al oku
	CHECK,     ## onay (yerleştir / bitir)
	CROSS,     ## iptal (vazgeç / sök)
	BOX,       ## depo kutusu (depoya kaldır)
	ROLLER,    ## boya rulosu (fırça)
	AREA,      ## kesik çizgili alan (dikdörtgen)
	BUCKET,    ## boya kovası (doldur)
	PICKER,    ## damlalık (desen al)
	ERASER,    ## silgi
	BRICKS,    ## tuğla duvar (ör)
	HAMMER,    ## çekiç (sök)
	LOCK,      ## kilit (rütbede açılır)
	CHAIR,     ## koltuk (eşyalar)
	TILES,     ## dama karo (zemin)
	# KAMERA MENÜSÜ ikonları — sona eklendi
	EYE,       ## göz (HUD'u göster)
	EYE_OFF,   ## üstü çizili göz (HUD'u gizle)
	FILM,      ## klaket (sinema modu)
	TARGET,    ## nişangâh (kamerayı ortala)
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
		Kind.MAP:
			_map(ci, c, s, ink, cutout, w)
		Kind.GRID:
			_grid(ci, c, s, ink, w)
		Kind.UNDO:
			_undo(ci, c, s, ink, w)
		Kind.CHECK:
			_check(ci, c, s, ink)
		Kind.CROSS:
			_cross(ci, c, s, ink)
		Kind.BOX:
			_box(ci, c, s, ink, cutout, w)
		Kind.ROLLER:
			_roller(ci, c, s, ink, cutout, w)
		Kind.AREA:
			_area(ci, c, s, ink, w)
		Kind.BUCKET:
			_bucket(ci, c, s, ink, cutout, w)
		Kind.PICKER:
			_picker(ci, c, s, ink, w)
		Kind.ERASER:
			_eraser(ci, c, s, ink, cutout)
		Kind.BRICKS:
			_bricks(ci, c, s, ink, cutout, w)
		Kind.HAMMER:
			_hammer(ci, c, s, ink)
		Kind.LOCK:
			_lock(ci, c, s, ink, cutout, w)
		Kind.CHAIR:
			_chair(ci, c, s, ink, cutout)
		Kind.TILES:
			_tiles(ci, c, s, ink, cutout)
		Kind.EYE:
			_eye(ci, c, s, ink, cutout, w, false)
		Kind.EYE_OFF:
			_eye(ci, c, s, ink, cutout, w, true)
		Kind.FILM:
			_film(ci, c, s, ink, cutout)
		Kind.TARGET:
			_target(ci, c, s, ink, w)
		_:
			pass


## Harita: üç katlı kâğıt (orta kat içe kırık) + üstünde iğne.
static func _map(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_poly(ci, c, s, PackedVector2Array([
		Vector2(-0.48, -0.26), Vector2(-0.16, -0.36), Vector2(0.16, -0.26), Vector2(0.48, -0.36),
		Vector2(0.48, 0.30), Vector2(0.16, 0.40), Vector2(-0.16, 0.30), Vector2(-0.48, 0.40),
	]), ink)
	# Kat çizgileri ve rota
	ci.draw_line(c + Vector2(-0.16, -0.30) * s, c + Vector2(-0.16, 0.24) * s, cutout, w * 0.5, true)
	ci.draw_line(c + Vector2(0.16, -0.20) * s, c + Vector2(0.16, 0.34) * s, cutout, w * 0.5, true)
	for k: int in 3:
		var a: Vector2 = c + Vector2(-0.38 + k * 0.2, 0.18 - k * 0.1) * s
		ci.draw_line(a, a + Vector2(0.1, -0.05) * s, cutout, w * 0.55, true)
	# İğne: sağ üstte
	var pin: Vector2 = c + Vector2(0.24, -0.12) * s
	ci.draw_circle(pin, s * 0.15, cutout, true, -1.0, true)
	ci.draw_circle(pin, s * 0.10, ink, true, -1.0, true)
	ci.draw_circle(pin, s * 0.04, cutout, true, -1.0, true)


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


## Göz: iki yaydan badem, ortada iris ve bebek. `crossed`: sol üstten sağ alta, zemin renginde boşluklu çizgi.
static func _eye(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float, crossed: bool) -> void:
	var upper: PackedVector2Array = _dome(c + Vector2(0.0, 0.30) * s, s * 0.58, deg_to_rad(-145.0), deg_to_rad(-35.0), 16)
	var lower: PackedVector2Array = _dome(c + Vector2(0.0, -0.30) * s, s * 0.58, deg_to_rad(35.0), deg_to_rad(145.0), 16)
	upper.append_array(lower)
	ci.draw_colored_polygon(upper, ink)
	ci.draw_circle(c, s * 0.17, cutout, true, -1.0, true)
	ci.draw_circle(c, s * 0.09, ink, true, -1.0, true)
	if crossed:
		ci.draw_line(c + Vector2(-0.40, -0.40) * s, c + Vector2(0.40, 0.40) * s, cutout, w * 2.4, true)
		ci.draw_line(c + Vector2(-0.40, -0.40) * s, c + Vector2(0.40, 0.40) * s, ink, w * 1.1, true)


## Klaket: gövde + üstte eğik açılmış çubuk; çubuklarda zemin renginde eğik şeritler.
static func _film(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	_round_rect(ci, c, s, Vector2(-0.44, -0.06), Vector2(0.88, 0.48), 0.06, ink)
	_rect(ci, c, s, Vector2(-0.44, -0.06), Vector2(0.88, 0.12), ink)
	for x: float in [-0.30, -0.06, 0.18]:   # alt çubuğun şeritleri
		_poly(ci, c, s, PackedVector2Array([Vector2(x, -0.06), Vector2(x + 0.10, -0.06), Vector2(x + 0.02, 0.06), Vector2(x - 0.08, 0.06)]), cutout)
	# Üst çubuk: sol uçtan menteşeli, ~14° açık
	var pivot: Vector2 = c + Vector2(-0.44, -0.12) * s
	var along: Vector2 = Vector2.from_angle(deg_to_rad(-14.0))
	var up: Vector2 = Vector2(along.y, -along.x)
	var bar: PackedVector2Array = PackedVector2Array([pivot, pivot + along * 0.88 * s, pivot + (along * 0.88 + up * 0.13) * s, pivot + up * 0.13 * s])
	ci.draw_colored_polygon(bar, ink)
	for k: float in [0.16, 0.40, 0.64]:
		var a: Vector2 = pivot + along * k * s
		ci.draw_colored_polygon(PackedVector2Array([a, a + along * 0.10 * s, a + (along * 0.18 + up * 0.13) * s, a + (along * 0.08 + up * 0.13) * s]), cutout)


## Nişangâh: halka, ortada nokta ve dört yöne kısa çentik.
static func _target(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	ci.draw_arc(c, s * 0.30, 0.0, TAU, 32, ink, w * 1.2, true)
	ci.draw_circle(c, s * 0.09, ink, true, -1.0, true)
	for dir: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		ci.draw_line(c + dir * 0.20 * s, c + dir * 0.48 * s, ink, w * 1.2, true)


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


# --- Garajı düzenle ----------------------------------------------------------

static func _grid(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	var r: Rect2 = Rect2(c - Vector2(0.40, 0.40) * s, Vector2(0.80, 0.80) * s)
	ci.draw_rect(r, ink, false, w, true)
	for k: float in [1.0 / 3.0, 2.0 / 3.0]:
		ci.draw_line(r.position + Vector2(r.size.x * k, 0.0), r.position + Vector2(r.size.x * k, r.size.y), ink, w * 0.6, true)
		ci.draw_line(r.position + Vector2(0.0, r.size.y * k), r.position + Vector2(r.size.x, r.size.y * k), ink, w * 0.6, true)


## Geri al: üstten sola dönen yay, ucu solda aşağı bakan ok.
static func _undo(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	var o: Vector2 = c + Vector2(0.06, 0.10) * s
	var r: float = s * 0.30
	ci.draw_arc(o, r, deg_to_rad(-200.0), deg_to_rad(40.0), 24, ink, w * 1.1, true)
	var tip: Vector2 = o + Vector2.from_angle(deg_to_rad(-200.0)) * r
	ci.draw_colored_polygon(PackedVector2Array([
		tip + Vector2(-0.18, -0.02) * s, tip + Vector2(0.14, -0.06) * s, tip + Vector2(-0.04, 0.20) * s,
	]), ink)


static func _check(ci: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	ci.draw_polyline(_pts(c, s, PackedVector2Array([Vector2(-0.36, 0.0), Vector2(-0.10, 0.26), Vector2(0.38, -0.28)])),
		ink, s * 0.16, true)


static func _cross(ci: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	ci.draw_line(c + Vector2(-0.30, -0.30) * s, c + Vector2(0.30, 0.30) * s, ink, s * 0.15, true)
	ci.draw_line(c + Vector2(0.30, -0.30) * s, c + Vector2(-0.30, 0.30) * s, ink, s * 0.15, true)


## Depo kutusu: gövde + açık kapak kanatları, içine inen ok.
static func _box(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_rect(ci, c, s, Vector2(-0.40, -0.02), Vector2(0.80, 0.46), ink)
	_poly(ci, c, s, PackedVector2Array([Vector2(-0.40, -0.02), Vector2(-0.50, -0.20), Vector2(-0.10, -0.20), Vector2(0.0, -0.02)]), ink)
	_poly(ci, c, s, PackedVector2Array([Vector2(0.40, -0.02), Vector2(0.50, -0.20), Vector2(0.10, -0.20), Vector2(0.0, -0.02)]), ink)
	_rect(ci, c, s, Vector2(-0.14, 0.08), Vector2(0.28, 0.08), cutout)   # tutamak
	ci.draw_line(c + Vector2(0.0, -0.52) * s, c + Vector2(0.0, -0.26) * s, ink, w * 1.1, true)
	_poly(ci, c, s, PackedVector2Array([Vector2(-0.12, -0.30), Vector2(0.12, -0.30), Vector2(0.0, -0.16)]), ink)


## Boya rulosu: üstte rulo, sapı aşağı iner.
static func _roller(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_round_rect(ci, c, s, Vector2(-0.42, -0.42), Vector2(0.70, 0.26), 0.08, ink)
	_rect(ci, c, s, Vector2(-0.34, -0.34), Vector2(0.10, 0.10), cutout)  # parlama
	ci.draw_polyline(_pts(c, s, PackedVector2Array([Vector2(0.28, -0.29), Vector2(0.40, -0.29), Vector2(0.40, -0.06),
		Vector2(-0.04, -0.06), Vector2(-0.04, 0.12)])), ink, w, true)
	_round_rect(ci, c, s, Vector2(-0.10, 0.10), Vector2(0.12, 0.36), 0.05, ink)


static func _area(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	var r: Rect2 = Rect2(c - Vector2(0.36, 0.32) * s, Vector2(0.72, 0.64) * s)
	var corners: PackedVector2Array = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position])
	for i: int in 4:
		ci.draw_dashed_line(corners[i], corners[i + 1], ink, w * 0.9, s * 0.12, true, true)
	for i: int in 4:
		ci.draw_rect(Rect2(corners[i] - Vector2.ONE * s * 0.07, Vector2.ONE * s * 0.14), ink, true)


## Kova: eğik gövde, ağzından damla.
static func _bucket(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_poly(ci, c, s, PackedVector2Array([Vector2(-0.44, -0.12), Vector2(0.12, -0.38), Vector2(0.30, 0.14), Vector2(-0.16, 0.36)]), ink)
	ci.draw_line(c + Vector2(-0.38, -0.10) * s, c + Vector2(0.08, -0.32) * s, cutout, w * 0.6, true)  # ağız
	ci.draw_arc(c + Vector2(-0.10, -0.30) * s, s * 0.22, PI, TAU * 0.92, 12, ink, w * 0.8, true)    # sap
	ci.draw_circle(c + Vector2(0.38, 0.30) * s, s * 0.10, ink, true, -1.0, true)                      # damla
	_poly(ci, c, s, PackedVector2Array([Vector2(0.30, 0.26), Vector2(0.46, 0.26), Vector2(0.38, 0.10)]), ink)


## Damlalık: çapraz cam tüp + üstte lastik puar.
static func _picker(ci: CanvasItem, c: Vector2, s: float, ink: Color, w: float) -> void:
	ci.draw_line(c + Vector2(-0.38, 0.38) * s, c + Vector2(0.10, -0.10) * s, ink, s * 0.13, true)
	ci.draw_line(c + Vector2(-0.44, 0.44) * s, c + Vector2(-0.34, 0.34) * s, ink, w * 0.6, true)
	ci.draw_line(c + Vector2(0.0, -0.20) * s, c + Vector2(0.20, 0.0) * s, ink, s * 0.12, true)   # bilezik
	ci.draw_circle(c + Vector2(0.24, -0.24) * s, s * 0.17, ink, true, -1.0, true)                 # puar


## Silgi: eğik dikdörtgen, ucu açık renkli.
static func _eraser(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	var body: PackedVector2Array = PackedVector2Array([Vector2(-0.46, 0.12), Vector2(0.06, -0.40), Vector2(0.40, -0.06), Vector2(-0.12, 0.46)])
	_poly(ci, c, s, body, ink)
	_poly(ci, c, s, PackedVector2Array([Vector2(-0.40, 0.12), Vector2(-0.20, -0.08), Vector2(0.10, 0.22), Vector2(-0.10, 0.40)]), cutout)
	ci.draw_line(c + Vector2(-0.10, 0.46) * s, c + Vector2(0.42, 0.46) * s, ink, s * 0.06, true)   # zemin çizgisi


## Tuğla duvar: üç sıra, aralar oyuk.
static func _bricks(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	_rect(ci, c, s, Vector2(-0.46, -0.36), Vector2(0.92, 0.72), ink)
	for row: int in 2:
		var y: float = -0.12 + row * 0.24
		ci.draw_line(c + Vector2(-0.46, y) * s, c + Vector2(0.46, y) * s, cutout, w * 0.55, true)
	for x: float in [-0.10, 0.26]:
		ci.draw_line(c + Vector2(x, -0.36) * s, c + Vector2(x, -0.12) * s, cutout, w * 0.55, true)
		ci.draw_line(c + Vector2(x, 0.12) * s, c + Vector2(x, 0.36) * s, cutout, w * 0.55, true)
	for x: float in [-0.28, 0.08]:
		ci.draw_line(c + Vector2(x, -0.12) * s, c + Vector2(x, 0.12) * s, cutout, w * 0.55, true)


## Çekiç: çapraz sap + başlık.
static func _hammer(ci: CanvasItem, c: Vector2, s: float, ink: Color) -> void:
	ci.draw_line(c + Vector2(-0.36, 0.40) * s, c + Vector2(0.12, -0.08) * s, ink, s * 0.14, true)
	_poly(ci, c, s, PackedVector2Array([Vector2(-0.10, -0.24), Vector2(0.18, -0.52), Vector2(0.46, -0.24), Vector2(0.18, 0.04)]), ink)


static func _lock(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color, w: float) -> void:
	ci.draw_arc(c + Vector2(0.0, -0.08) * s, s * 0.22, PI, TAU, 16, ink, w * 1.4, true)
	ci.draw_line(c + Vector2(-0.22, -0.08) * s, c + Vector2(-0.22, 0.04) * s, ink, w * 1.4, true)
	ci.draw_line(c + Vector2(0.22, -0.08) * s, c + Vector2(0.22, 0.04) * s, ink, w * 1.4, true)
	_round_rect(ci, c, s, Vector2(-0.36, 0.0), Vector2(0.72, 0.46), 0.08, ink)
	ci.draw_circle(c + Vector2(0.0, 0.16) * s, s * 0.07, cutout, true, -1.0, true)
	_rect(ci, c, s, Vector2(-0.03, 0.18), Vector2(0.06, 0.14), cutout)


## Koltuk: arkalık + kolçaklar + oturak + ayaklar.
static func _chair(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	_round_rect(ci, c, s, Vector2(-0.32, -0.40), Vector2(0.64, 0.44), 0.10, ink)   # arkalık
	_round_rect(ci, c, s, Vector2(-0.48, -0.10), Vector2(0.20, 0.42), 0.08, ink)   # kolçaklar
	_round_rect(ci, c, s, Vector2(0.28, -0.10), Vector2(0.20, 0.42), 0.08, ink)
	_round_rect(ci, c, s, Vector2(-0.30, 0.04), Vector2(0.60, 0.22), 0.06, ink)    # oturak
	ci.draw_line(c + Vector2(-0.30, 0.10) * s, c + Vector2(0.30, 0.10) * s, cutout, maxf(1.0, s * 0.04), true)
	_rect(ci, c, s, Vector2(-0.42, 0.30), Vector2(0.08, 0.14), ink)
	_rect(ci, c, s, Vector2(0.34, 0.30), Vector2(0.08, 0.14), ink)


## Dama karo: 3 × 3, köşeleri dolu.
static func _tiles(ci: CanvasItem, c: Vector2, s: float, ink: Color, cutout: Color) -> void:
	var cell: float = 0.27
	_rect(ci, c, s, Vector2(-0.43, -0.43), Vector2(0.86, 0.86), ink)
	for i: int in 3:
		for j: int in 3:
			if (i + j) % 2 == 1:
				_rect(ci, c, s, Vector2(-0.405 + i * cell, -0.405 + j * cell), Vector2(cell - 0.03, cell - 0.03), cutout)


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
