@tool
class_name PartIcon
extends Control
## HURDALIK PARÇA İKONLARI — kodla çizilir (asset yok), HudIcon'un para / gem ikonlarıyla aynı dil:
## tombul, dolgulu, altında koyu bir "gölge" kopyası. Dokuz parça türü (vehicles/restorations.json).
## draw_part() statik: başka CanvasItem'lar (uçan ikon, reçete satırı) da kullanır.

@export var part_id: StringName = &"bolt":
	set(value):
		part_id = value
		queue_redraw()

## Kilitli / eksik parça: soluk çizilir.
@export var dim: bool = false:
	set(value):
		dim = value
		queue_redraw()

const STEEL: Color = Color("A9B2BA")
const STEEL_DARK: Color = Color("5D666E")
const STEEL_LIGHT: Color = Color("DCE3E8")
const HOLE: Color = Color("2E2A27")


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(32.0, 32.0)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	draw_part(self, part_id, size * 0.5, s)
	if dim:
		draw_rect(Rect2(Vector2.ZERO, size), Color(HudPalette.PLATE, 0.55))


## Parçayı c merkezli, s boyutlu kareye çizer.
static func draw_part(ci: CanvasItem, id: StringName, c: Vector2, s: float) -> void:
	match id:
		&"bolt":
			_bolt(ci, c, s)
		&"nut":
			_nut(ci, c, s)
		&"paint":
			_paint_can(ci, c, s)
		&"spark_plug":
			_spark_plug(ci, c, s)
		&"piston":
			_piston(ci, c, s)
		&"gear":
			_gear(ci, c, s)
		&"motor_oil":
			_oil(ci, c, s)
		&"belt":
			_belt(ci, c, s)
		&"fiberglass":
			_fiberglass(ci, c, s)
		_:
			ci.draw_circle(c, s * 0.3, STEEL, true, -1.0, true)


static func _hex(c: Vector2, r: float, rot: float = 0.0) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 6:
		pts.append(c + Vector2.from_angle(rot + TAU * i / 6.0) * r)
	return pts


static func _shadowed(ci: CanvasItem, pts: PackedVector2Array, color: Color, dark: Color, s: float) -> void:
	var shifted: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in pts:
		shifted.append(p + Vector2(0.0, 0.045 * s))
	ci.draw_colored_polygon(shifted, dark)
	ci.draw_colored_polygon(pts, color)


static func _bolt(ci: CanvasItem, c: Vector2, s: float) -> void:
	# Altıgen baş üstte, yivli gövde aşağı
	var shank: Rect2 = Rect2(c + Vector2(-0.10, -0.10) * s, Vector2(0.20, 0.56) * s)
	ci.draw_rect(Rect2(shank.position + Vector2(0.0, 0.04 * s), shank.size), STEEL_DARK)
	ci.draw_rect(shank, STEEL)
	for k: int in 6:
		var y: float = -0.04 + k * 0.08
		ci.draw_line(c + Vector2(-0.10, y) * s, c + Vector2(0.10, y + 0.04) * s, STEEL_DARK, maxf(1.0, s * 0.03), true)
	_shadowed(ci, _hex(c + Vector2(0.0, -0.22) * s, 0.28 * s, PI / 6.0), STEEL, STEEL_DARK, s)
	ci.draw_line(c + Vector2(-0.16, -0.30) * s, c + Vector2(0.06, -0.30) * s, STEEL_LIGHT, maxf(1.0, s * 0.05), true)


static func _nut(ci: CanvasItem, c: Vector2, s: float) -> void:
	_shadowed(ci, _hex(c, 0.42 * s), STEEL, STEEL_DARK, s)
	ci.draw_circle(c, 0.19 * s, HOLE, true, -1.0, true)
	ci.draw_arc(c, 0.19 * s, 0.0, TAU, 20, STEEL_DARK, maxf(1.0, s * 0.04), true)
	ci.draw_line(c + Vector2(-0.30, -0.26) * s, c + Vector2(0.0, -0.36) * s, STEEL_LIGHT, maxf(1.0, s * 0.05), true)


static func _paint_can(ci: CanvasItem, c: Vector2, s: float) -> void:
	var red: Color = Color("D2452F")
	var red_dark: Color = Color("8E2A1E")
	var body: Rect2 = Rect2(c + Vector2(-0.32, -0.20) * s, Vector2(0.64, 0.62) * s)
	ci.draw_rect(Rect2(body.position + Vector2(0.0, 0.045 * s), body.size), red_dark)
	ci.draw_rect(body, red)
	ci.draw_rect(Rect2(c + Vector2(-0.32, -0.02) * s, Vector2(0.64, 0.22) * s), Color("F2E6D0"))   # etiket
	ci.draw_circle(c + Vector2(0.0, 0.09) * s, 0.07 * s, red, true, -1.0, true)
	# Kapak (elips) ve sap
	ci.draw_colored_polygon(_ellipse(c + Vector2(0.0, -0.20) * s, Vector2(0.32, 0.10) * s), STEEL)
	ci.draw_arc(c + Vector2(0.0, -0.22) * s, 0.30 * s, PI * 1.08, PI * 1.92, 14, STEEL_DARK, maxf(1.0, s * 0.05), true)
	# Damla
	ci.draw_circle(c + Vector2(0.20, -0.08) * s, 0.06 * s, red, true, -1.0, true)


static func _spark_plug(ci: CanvasItem, c: Vector2, s: float) -> void:
	var ceramic: Color = Color("F1ECE2")
	var ceramic_dark: Color = Color("B5ADA0")
	# Üst uç, seramik gövde, altıgen somun, yivli metal uç, elektrot
	ci.draw_rect(Rect2(c + Vector2(-0.05, -0.48) * s, Vector2(0.10, 0.10) * s), STEEL_DARK)
	_shadowed(ci, PackedVector2Array([c + Vector2(-0.10, -0.40) * s, c + Vector2(0.10, -0.40) * s,
		c + Vector2(0.15, -0.02) * s, c + Vector2(-0.15, -0.02) * s]), ceramic, ceramic_dark, s)
	for k: int in 3:
		ci.draw_line(c + Vector2(-0.12, -0.30 + k * 0.08) * s, c + Vector2(0.12, -0.30 + k * 0.08) * s,
			ceramic_dark, maxf(1.0, s * 0.025), true)
	_shadowed(ci, _hex(c + Vector2(0.0, 0.08) * s, 0.20 * s, PI / 6.0), STEEL, STEEL_DARK, s)
	ci.draw_rect(Rect2(c + Vector2(-0.09, 0.18) * s, Vector2(0.18, 0.20) * s), STEEL)
	for k: int in 3:
		ci.draw_line(c + Vector2(-0.09, 0.22 + k * 0.06) * s, c + Vector2(0.09, 0.25 + k * 0.06) * s,
			STEEL_DARK, maxf(1.0, s * 0.025), true)
	ci.draw_line(c + Vector2(0.0, 0.38) * s, c + Vector2(0.0, 0.46) * s, STEEL_DARK, maxf(1.0, s * 0.05), true)
	ci.draw_line(c + Vector2(-0.07, 0.46) * s, c + Vector2(0.06, 0.46) * s, STEEL_DARK, maxf(1.0, s * 0.05), true)


static func _piston(ci: CanvasItem, c: Vector2, s: float) -> void:
	# Kafa (segman çizgili), pim, biyel kolu
	var head: Rect2 = Rect2(c + Vector2(-0.30, -0.44) * s, Vector2(0.60, 0.42) * s)
	ci.draw_rect(Rect2(head.position + Vector2(0.0, 0.045 * s), head.size), STEEL_DARK)
	ci.draw_rect(head, STEEL)
	for k: int in 3:
		ci.draw_line(c + Vector2(-0.30, -0.36 + k * 0.07) * s, c + Vector2(0.30, -0.36 + k * 0.07) * s,
			STEEL_DARK, maxf(1.0, s * 0.03), true)
	ci.draw_line(c + Vector2(-0.24, -0.43) * s, c + Vector2(0.10, -0.43) * s, STEEL_LIGHT, maxf(1.0, s * 0.04), true)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.08, -0.10) * s, c + Vector2(0.08, -0.10) * s,
		c + Vector2(0.11, 0.32) * s, c + Vector2(-0.11, 0.32) * s]), STEEL_DARK)
	ci.draw_circle(c + Vector2(0.0, 0.36) * s, 0.14 * s, STEEL_DARK, true, -1.0, true)
	ci.draw_circle(c + Vector2(0.0, 0.36) * s, 0.07 * s, HOLE, true, -1.0, true)
	ci.draw_circle(c + Vector2(0.0, -0.14) * s, 0.06 * s, HOLE, true, -1.0, true)


static func _gear(ci: CanvasItem, c: Vector2, s: float) -> void:
	var bronze: Color = Color("D8923A")
	var bronze_dark: Color = Color("8A5420")
	for pass_i: int in 2:
		var o: Vector2 = c + (Vector2(0.0, 0.045 * s) if pass_i == 0 else Vector2.ZERO)
		var color: Color = bronze_dark if pass_i == 0 else bronze
		for i: int in 10:
			var a: float = TAU * float(i) / 10.0
			var dir: Vector2 = Vector2.from_angle(a)
			var side: Vector2 = Vector2(-dir.y, dir.x) * 0.07 * s
			ci.draw_colored_polygon(PackedVector2Array([o + dir * 0.30 * s - side, o + dir * 0.46 * s - side * 0.7,
				o + dir * 0.46 * s + side * 0.7, o + dir * 0.30 * s + side]), color)
		ci.draw_circle(o, 0.35 * s, color, true, -1.0, true)
	ci.draw_circle(c, 0.14 * s, HOLE, true, -1.0, true)
	ci.draw_arc(c, 0.24 * s, 0.0, TAU, 24, bronze_dark, maxf(1.0, s * 0.03), true)


static func _oil(ci: CanvasItem, c: Vector2, s: float) -> void:
	var amber: Color = Color("E9A93A")
	var amber_dark: Color = Color("9C6418")
	# Bidon: gövde + omuz + kapak + sap
	var body: PackedVector2Array = PackedVector2Array([c + Vector2(-0.30, -0.16) * s, c + Vector2(-0.06, -0.30) * s,
		c + Vector2(0.30, -0.30) * s, c + Vector2(0.30, 0.44) * s, c + Vector2(-0.30, 0.44) * s])
	_shadowed(ci, body, amber, amber_dark, s)
	ci.draw_rect(Rect2(c + Vector2(-0.28, -0.42) * s, Vector2(0.16, 0.14) * s), Color("2F3236"))   # kapak
	ci.draw_rect(Rect2(c + Vector2(0.06, -0.44) * s, Vector2(0.24, 0.18) * s), amber_dark)       # sap
	ci.draw_rect(Rect2(c + Vector2(0.11, -0.39) * s, Vector2(0.14, 0.09) * s), HudPalette.PLATE)
	ci.draw_rect(Rect2(c + Vector2(-0.22, 0.02) * s, Vector2(0.44, 0.26) * s), Color("2F3236"))  # etiket
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, 0.06) * s, c + Vector2(0.07, 0.17) * s,
		c + Vector2(0.0, 0.24) * s, c + Vector2(-0.07, 0.17) * s]), amber)   # yağ damlası


static func _belt(ci: CanvasItem, c: Vector2, s: float) -> void:
	var rubber: Color = Color("3A3735")
	var rubber_light: Color = Color("6E6A66")
	ci.draw_colored_polygon(_ellipse(c + Vector2(0.0, 0.045) * s, Vector2(0.46, 0.34) * s), Color("1E1C1B"))
	ci.draw_colored_polygon(_ellipse(c, Vector2(0.46, 0.34) * s), rubber)
	ci.draw_colored_polygon(_ellipse(c, Vector2(0.30, 0.19) * s), HudPalette.PLATE)
	for i: int in 14:
		var a: float = TAU * float(i) / 14.0
		var inner: Vector2 = c + Vector2(cos(a) * 0.32, sin(a) * 0.21) * s
		var outer: Vector2 = c + Vector2(cos(a) * 0.44, sin(a) * 0.32) * s
		ci.draw_line(inner, outer, rubber_light, maxf(1.0, s * 0.03), true)


static func _fiberglass(ci: CanvasItem, c: Vector2, s: float) -> void:
	var teal: Color = Color("5FB2A8")
	var teal_dark: Color = Color("2F6E68")
	# Kavisli panel (çamurluk parçası) + dokuma deseni
	var panel: PackedVector2Array = PackedVector2Array([c + Vector2(-0.44, 0.30) * s, c + Vector2(-0.40, -0.10) * s,
		c + Vector2(-0.20, -0.36) * s, c + Vector2(0.20, -0.40) * s, c + Vector2(0.44, -0.24) * s,
		c + Vector2(0.44, 0.38) * s])
	_shadowed(ci, panel, teal, teal_dark, s)
	for k: int in 4:
		var x: float = -0.30 + k * 0.20
		ci.draw_line(c + Vector2(x, -0.30) * s, c + Vector2(x + 0.12, 0.34) * s, teal_dark, maxf(1.0, s * 0.025), true)
		ci.draw_line(c + Vector2(-0.40, -0.04 + k * 0.10) * s, c + Vector2(0.44, -0.14 + k * 0.12) * s,
			teal_dark, maxf(1.0, s * 0.025), true)
	ci.draw_line(c + Vector2(-0.30, -0.20) * s, c + Vector2(0.12, -0.34) * s, Color("BDE6E0"), maxf(1.0, s * 0.05), true)


static func _ellipse(c: Vector2, r: Vector2, steps: int = 24) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in steps:
		var a: float = TAU * float(i) / steps
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts
