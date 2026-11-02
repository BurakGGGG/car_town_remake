class_name DynoGraph
extends Control
## DİNAMOMETRE eğrisi (2026-11-02): yatay devir (rölanti … kırmızı), düşey güç. Yeşil = son tam gaz çekişin gücü,
## turuncu = torku (kendi tepesine göre ölçekli), soluk kesik = FABRİKA güç eğrisi (modifiye farkı görünür), ince yatay
## çizgi = en iyi ölçülen tepe güç. Çekiş sürerken eğri ileri yürür; uçta nokta.

const POWER: Color = Color("2F9E52")
const TORQUE: Color = Color("E8801E")

var idle_rpm: float = 800.0
var redline_rpm: float = 6500.0
var power: PackedVector2Array = PackedVector2Array()
var torque: PackedVector2Array = PackedVector2Array()
var factory: PackedVector2Array = PackedVector2Array()
var best_hp: float = 0.0
var scale_hp: float = 100.0


func _ready() -> void:
	custom_minimum_size = Vector2(264.0, 96.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(curve_power: PackedVector2Array, curve_torque: PackedVector2Array, best: float) -> void:
	power = curve_power
	torque = curve_torque
	best_hp = best
	queue_redraw()


func _draw() -> void:
	var area: Rect2 = Rect2(Vector2.ZERO, size)
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color("E2E8D6")
	bg.set_corner_radius_all(6)
	draw_style_box(bg, area)
	for k: int in range(1, 4):
		var y: float = area.size.y * float(k) / 4.0
		draw_line(Vector2(4.0, y), Vector2(area.size.x - 4.0, y), Color("CDD4C4"), 1.0)
	var top: float = maxf(scale_hp, best_hp) * 1.12
	if not factory.is_empty():
		var pts: PackedVector2Array = _map(factory, top)
		for i: int in range(0, pts.size() - 1, 2):
			draw_line(pts[i], pts[i + 1], Color(0.45, 0.45, 0.42, 0.7), 2.0, true)
	if best_hp > 0.0:
		var y: float = area.size.y - 6.0 - (area.size.y - 12.0) * best_hp / top
		draw_dashed_line(Vector2(6.0, y), Vector2(area.size.x - 6.0, y), Color(HudPalette.INK_SOFT, 0.6), 1.0, 5.0)
	if torque.size() >= 2:
		var peak_t: float = 0.0
		for p: Vector2 in torque:
			peak_t = maxf(peak_t, p.y)
		var scaled: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in torque:
			scaled.append(Vector2(p.x, p.y / maxf(peak_t, 1.0) * top * 0.82))
		draw_polyline(_map(scaled, top), TORQUE, 2.5, true)
	if power.size() >= 2:
		var pts: PackedVector2Array = _map(power, top)
		draw_polyline(pts, POWER, 3.5, true)
		draw_circle(pts[pts.size() - 1], 4.5, POWER)


func _map(points: PackedVector2Array, top: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var w: float = size.x - 12.0
	var h: float = size.y - 12.0
	for p: Vector2 in points:
		var x: float = 6.0 + w * clampf((p.x - idle_rpm) / maxf(redline_rpm - idle_rpm, 1.0), 0.0, 1.0)
		out.append(Vector2(x, size.y - 6.0 - h * clampf(p.y / maxf(top, 1.0), 0.0, 1.0)))
	return out
