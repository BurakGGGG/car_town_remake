class_name TriBatch
extends RefCounted
## TOPLU 2B ÇİZİM — CanvasItem'ın draw_circle / draw_line / draw_polyline / draw_arc / draw_colored_polygon / draw_rect /
## draw_dashed_line çağrılarını aynı imzalarla alır, hepsini TEK üçgen dizisinde biriktirir; flush() tek çizim komutu
## olarak gönderir (RenderingServer.canvas_item_add_triangle_array). Çizim sırası korunur (üçgenler sırayla karışır).
##
## Neden (ölçüldü 2026-10-25, qa/hud_icon_sheet.gd): GL Compatibility'nin 2B çizicisi her poligonu ve her kenar yumuşatma
## şeridini ayrı çizim çağrısı yapıyor. HudIcon'un bir ikonu 3–12 çağrı; dünya görünümünde HUD'un 185 çağrısının çoğu
## buydu (alt sırada plaka başına 17). Toplanınca ikon başına 1 çağrı.
##
## Geometri Godot 4.7'nin kendi tessellation'ının kopyası (servers/rendering/renderer_canvas_cull.cpp,
## scene/main/canvas_item.cpp, scene/resources/style_box_flat.cpp): kenar yumuşatma şeridi FEATHER_SIZE 1,25, kalın
## çizginin genişlik telafisi, köşe birleşimleri, 64 dilimli daire, çokgen Geometry2D.triangulate_polygon. Fark yalnızca
## ince (genişliği negatif) çizgilerde: Godot 1 piksellik GL çizgisi çizer, burada 1 birim kalın şerit.

const FEATHER_SIZE: float = 1.25
const ELLIPSE_SEGMENTS: int = 64
## StyleBoxFlat varsayılanları (yuvarlak köşe: köşe başına 8 dilim, 1 birim kenar yumuşatma).
const CORNER_DETAIL: int = 8
const BOX_AA: float = 1.0

var points: PackedVector2Array = PackedVector2Array()
var colors: PackedColorArray = PackedColorArray()
var indices: PackedInt32Array = PackedInt32Array()


func is_empty() -> bool:
	return indices.is_empty()


## Biriken üçgenleri `ci`'ye tek çizim komutu olarak ekler ve tamponu boşaltır. `ci` o an _draw içinde olmalı.
func flush(ci: CanvasItem) -> void:
	if not indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(ci.get_canvas_item(), indices, points, colors)
	points.clear()
	colors.clear()
	indices.clear()


# --- CanvasItem eşleri ---------------------------------------------------------------------------

func draw_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	if width < 0.0:
		_line_quad(from, to, color, 1.0)   # Godot: 1 piksellik GL çizgisi
		return
	var diff: Vector2 = from - to
	var dir: Vector2 = diff.orthogonal().normalized()
	if antialiased:
		width = _compensated(width)
	var t: Vector2 = dir * width * 0.5
	var begin_left: Vector2 = from + t
	var begin_right: Vector2 = from - t
	var end_left: Vector2 = to + t
	var end_right: Vector2 = to - t
	_quad(begin_left, begin_right, end_right, end_left, color, color, color, color)
	if not antialiased:
		return
	var border_size: float = FEATHER_SIZE * (width if width < 1.0 else 1.0)
	var border: Vector2 = dir * border_size
	var border2: Vector2 = diff.normalized() * border_size
	var clear: Color = Color(color, 0.0)
	_quad(begin_left, begin_left + border, end_left + border, end_left, color, clear, clear, color)
	_quad(begin_right, begin_right - border, end_right - border, end_right, color, clear, clear, color)
	_quad(begin_left, begin_left + border2, begin_right + border2, begin_right, color, clear, clear, color)
	_quad(end_left, end_left - border2, end_right - border2, end_right, color, clear, clear, color)
	_quad(begin_left, begin_left + border2, begin_left + border + border2, begin_left + border, color, clear, clear, clear)
	_quad(begin_right, begin_right + border2, begin_right - border + border2, begin_right - border, color, clear, clear, clear)
	_quad(end_left, end_left - border2, end_left + border - border2, end_left + border, color, clear, clear, clear)
	_quad(end_right, end_right - border2, end_right - border - border2, end_right - border, color, clear, clear, clear)


func draw_polyline(line: PackedVector2Array, color: Color, width: float = -1.0, antialiased: bool = false) -> void:
	var count: int = line.size()
	if count < 2:
		return
	if width < 0.0:
		for i: int in count - 1:
			_line_quad(line[i], line[i + 1], color, 1.0)
		return
	if antialiased:
		width = _compensated(width)
	var loop: bool = line[0].is_equal_approx(line[count - 1])
	var first_dir: Vector2 = Vector2.ZERO
	for i: int in range(1, count):
		first_dir = (line[i] - line[i - 1]).normalized()
		if not first_dir.is_zero_approx():
			break
	var last_dir: Vector2 = Vector2.ZERO
	for i: int in range(count - 1, 0, -1):
		last_dir = (line[i] - line[i - 1]).normalized()
		if not last_dir.is_zero_approx():
			break
	var pc: int = count * 2
	var caps: bool = antialiased and not loop
	var main_pts: PackedVector2Array = PackedVector2Array()
	main_pts.resize(pc + (4 if caps else 0))
	var main_cols: PackedColorArray = PackedColorArray()
	main_cols.resize(main_pts.size())
	var left_pts: PackedVector2Array = PackedVector2Array()
	var left_cols: PackedColorArray = PackedColorArray()
	var right_pts: PackedVector2Array = PackedVector2Array()
	var right_cols: PackedColorArray = PackedColorArray()
	var border_size: float = FEATHER_SIZE * (width if width < 1.0 else 1.0)
	if antialiased:
		left_pts.resize(pc + (0 if loop else 5))
		right_pts.resize(left_pts.size())
		left_cols.resize(left_pts.size())
		right_cols.resize(left_pts.size())
	var clear: Color = Color(color, 0.0)
	var prev_dir: Vector2 = Vector2.ZERO
	for i: int in count:
		var first: bool = i == 0
		var last: bool = i == count - 1
		var seg_dir: Vector2 = _segment_dir(line, i, prev_dir)
		if first and loop:
			prev_dir = last_dir
		elif last and loop:
			prev_dir = first_dir
		var base_edge: Vector2
		if first and not loop:
			base_edge = first_dir.orthogonal()
		elif last and not loop:
			base_edge = last_dir.orthogonal()
		else:
			base_edge = _edge_offset(seg_dir, prev_dir)
		var edge: Vector2 = base_edge * (width * 0.5)
		var pos: Vector2 = line[i]
		var j: int = i * 2 + (2 if caps else 0)
		main_pts[j] = pos + edge
		main_pts[j + 1] = pos - edge
		main_cols[j] = color
		main_cols[j + 1] = color
		if antialiased:
			var border: Vector2 = base_edge * border_size
			var k: int = i * 2 + (0 if loop else 2)
			left_pts[k] = pos + edge
			left_pts[k + 1] = pos + edge + border
			right_pts[k] = pos - edge
			right_pts[k + 1] = pos - edge - border
			left_cols[k] = color
			left_cols[k + 1] = clear
			right_cols[k] = color
			right_cols[k + 1] = clear
			if first and not loop:
				var begin: Vector2 = -seg_dir * border_size
				main_pts[0] = pos + edge + begin
				main_pts[1] = pos - edge + begin
				main_cols[0] = clear
				main_cols[1] = clear
				left_pts[0] = pos + edge + begin
				left_pts[1] = pos + edge + begin + border
				left_cols[0] = clear
				left_cols[1] = clear
				right_pts[0] = pos - edge + begin
				right_pts[1] = pos - edge + begin - border
				right_cols[0] = clear
				right_cols[1] = clear
			if last and not loop:
				var end: Vector2 = prev_dir * border_size
				var e: int = pc + 2
				main_pts[e] = pos + edge + end
				main_pts[e + 1] = pos - edge + end
				main_cols[e] = clear
				main_cols[e + 1] = clear
				left_pts[e] = pos + edge
				left_pts[e + 1] = pos + edge + end + border
				left_pts[e + 2] = pos + edge + end
				left_cols[e] = color
				left_cols[e + 1] = clear
				left_cols[e + 2] = clear
				right_pts[e] = pos - edge
				right_pts[e + 1] = pos - edge + end - border
				right_pts[e + 2] = pos - edge + end
				right_cols[e] = color
				right_cols[e + 1] = clear
				right_cols[e + 2] = clear
		prev_dir = seg_dir
	_strip(main_pts, main_cols)
	if antialiased:
		_strip(left_pts, left_cols)
		_strip(right_pts, right_cols)


func draw_arc(center: Vector2, radius: float, start_angle: float, end_angle: float, point_count: int, color: Color,
		width: float = -1.0, antialiased: bool = false) -> void:
	if point_count < 2:
		return
	var arc: PackedVector2Array = PackedVector2Array()
	arc.resize(point_count)
	var delta: float = clampf(end_angle - start_angle, -TAU, TAU)
	for i: int in point_count:
		var theta: float = (float(i) / (point_count - 1.0)) * delta + start_angle
		arc[i] = center + Vector2(radius * cos(theta), radius * sin(theta))
	draw_polyline(arc, color, width, antialiased)


func draw_circle(position: Vector2, radius: float, color: Color, filled: bool = true, width: float = -1.0,
		antialiased: bool = false) -> void:
	if filled:
		_ellipse(position, radius, color, antialiased)
	elif width >= 2.0 * radius:
		_ellipse(position, radius + 0.5 * width, color, antialiased)
	else:
		var ring: PackedVector2Array = PackedVector2Array()
		ring.resize(ELLIPSE_SEGMENTS + 1)
		for i: int in ELLIPSE_SEGMENTS:
			var angle: float = i * TAU / ELLIPSE_SEGMENTS
			ring[i] = position + Vector2(cos(angle), sin(angle)) * radius
		ring[ELLIPSE_SEGMENTS] = ring[0]
		draw_polyline(ring, color, width, antialiased)


func draw_colored_polygon(polygon: PackedVector2Array, color: Color) -> void:
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(polygon)
	if tris.is_empty():
		return
	var base: int = points.size()
	points.append_array(polygon)
	var fill: PackedColorArray = PackedColorArray()
	fill.resize(polygon.size())
	fill.fill(color)
	colors.append_array(fill)
	for index: int in tris:
		indices.append(base + index)


func draw_rect(rect: Rect2, color: Color, filled: bool = true, width: float = -1.0, antialiased: bool = false) -> void:
	rect = rect.abs()
	if filled:
		_rect(rect, color, antialiased)
	elif width >= rect.size.x or width >= rect.size.y:
		_rect(rect.grow(0.5 * width), color, antialiased)
	else:
		draw_polyline(PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end,
			rect.position + Vector2(0.0, rect.size.y), rect.position]), color, width, antialiased)


func draw_dashed_line(from: Vector2, to: Vector2, color: Color, width: float = -1.0, dash: float = 2.0,
		aligned: bool = true, antialiased: bool = false) -> void:
	var length: float = (to - from).length()
	var step: Vector2 = dash * (to - from).normalized()
	if length < dash or step == Vector2.ZERO:
		draw_line(from, to, color, width, antialiased)
		return
	var steps: int = ceili(length / dash) if aligned else floori(length / dash)
	if steps % 2 == 0:
		steps -= 1
	var off: Vector2 = from
	if aligned:
		off += (to - from).normalized() * (length - steps * dash) / 2.0
	var i: int = 0
	while i < steps:
		var a: Vector2 = from if i == 0 else off
		var b: Vector2 = to if aligned and i == steps - 1 else off + step
		draw_line(a, b, color, width, antialiased)
		off += step * 2.0
		i += 2


## Kenarları yumuşatılmış dolu yuvarlak köşeli dikdörtgen (StyleBoxFlat: bg_color, köşe yarıçapı, anti_aliasing).
func draw_round_rect(rect: Rect2, radius: float, color: Color) -> void:
	if is_zero_approx(rect.size.x) or is_zero_approx(rect.size.y):
		return
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)   # StyleBoxFlat.adapt_values
	if r <= 0.0:
		_rect(rect, color, false)
		return
	var half: float = BOX_AA * 0.5
	var colored: Rect2 = rect.grow(-half)
	var ring: Rect2 = rect.grow(half)
	var inner: PackedVector2Array = _round_outline(colored, maxf(r - half, 0.0))
	var outer: PackedVector2Array = _round_outline(ring, r + half)
	# Dolgu: StyleBoxFlat gibi karşılıklı kenarlar arasında dikey şeritler
	var base: int = points.size()
	points.append_array(inner)
	var fill: PackedColorArray = PackedColorArray()
	fill.resize(inner.size())
	fill.fill(color)
	colors.append_array(fill)
	var n: int = inner.size()
	var last: int = n - 1
	for i: int in n / 2 - 1:
		indices.append_array(PackedInt32Array([base + i, base + last - i - 1, base + i + 1,
			base + i, base + last - i, base + last - i - 1]))
	# Kenar yumuşatma halkası: iç (renkli) → dış (saydam)
	var ring_base: int = points.size()
	var clear: Color = Color(color, 0.0)
	for i: int in n:
		points.append(inner[i])
		colors.append(color)
		points.append(outer[i])
		colors.append(clear)
	var count: int = n * 2
	for i: int in count:
		indices.append_array(PackedInt32Array([ring_base + i % count, ring_base + (i + 2) % count, ring_base + (i + 1) % count]))


# --- Yardımcılar ------------------------------------------------------------------------------------

func _compensated(width: float) -> float:
	if width <= 0.0:
		return width
	if width <= FEATHER_SIZE * 2.0 + 0.00001:
		return width * 0.5
	if width <= FEATHER_SIZE * 4.0 + 0.00001:
		return remap(width, FEATHER_SIZE * 2.0, FEATHER_SIZE * 4.0, width * 0.5, width - FEATHER_SIZE * 0.5)
	return width - FEATHER_SIZE * 0.5


func _segment_dir(line: PackedVector2Array, index: int, prev_dir: Vector2) -> Vector2:
	if index == line.size() - 1:
		return prev_dir
	var dir: Vector2 = (line[index + 1] - line[index]).normalized()
	return prev_dir if dir.is_zero_approx() else dir


func _edge_offset(seg_dir: Vector2, prev_dir: Vector2) -> Vector2:
	var length: float = 1.0
	var bisector: Vector2 = (prev_dir * seg_dir.length() - seg_dir * prev_dir.length()).normalized()
	var angle: float = atan2(bisector.cross(prev_dir), bisector.dot(prev_dir))
	var sin_angle: float = sin(angle)
	if not is_zero_approx(sin_angle) and not seg_dir.is_equal_approx(prev_dir):
		length = clampf(1.0 / sin_angle, -3.0, 3.0)
	else:
		bisector = seg_dir.orthogonal()
	if bisector.is_zero_approx():
		bisector = seg_dir.orthogonal()
	return bisector * length


## Dört köşeli komut (Godot'nun CommandPrimitive'i): (0, 1, 2) ve (0, 2, 3) üçgenleri.
func _quad(a: Vector2, b: Vector2, c: Vector2, d: Vector2, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var base: int = points.size()
	points.append_array(PackedVector2Array([a, b, c, d]))
	colors.append_array(PackedColorArray([ca, cb, cc, cd]))
	indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _line_quad(from: Vector2, to: Vector2, color: Color, width: float) -> void:
	var t: Vector2 = (from - to).orthogonal().normalized() * width * 0.5
	_quad(from + t, from - t, to - t, to + t, color, color, color, color)


## Üçgen şeridi (GL TRIANGLE_STRIP): ardışık her üç köşe bir üçgen.
func _strip(strip: PackedVector2Array, strip_colors: PackedColorArray) -> void:
	var base: int = points.size()
	points.append_array(strip)
	colors.append_array(strip_colors)
	for i: int in strip.size() - 2:
		indices.append_array(PackedInt32Array([base + i, base + i + 1, base + i + 2]))


func _rect(rect: Rect2, color: Color, antialiased: bool) -> void:
	if not antialiased:
		_quad(rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y),
			color, color, color, color)
		return
	var r: Rect2 = rect.grow(-FEATHER_SIZE * 0.25)
	_quad(r.position, r.position + Vector2(r.size.x, 0.0), r.end, r.position + Vector2(0.0, r.size.y), color, color, color, color)
	var size: float = minf(r.size.x, r.size.y)
	var border_size: float = FEATHER_SIZE * (size if size < 1.0 else 1.0)
	var clear: Color = Color(color, 0.0)
	var bl: Vector2 = r.position
	var br: Vector2 = r.position + Vector2(0.0, r.size.y)
	var el: Vector2 = r.position + Vector2(r.size.x, 0.0)
	var er: Vector2 = r.end
	var border: Vector2 = Vector2(0.0, -1.0) * border_size
	var border2: Vector2 = Vector2(-1.0, 0.0) * border_size
	_quad(bl, bl + border, el + border, el, color, clear, clear, color)
	_quad(br, br - border, er - border, er, color, clear, clear, color)
	_quad(bl, bl + border2, br + border2, br, color, clear, clear, color)
	_quad(el, el - border2, er - border2, er, color, clear, clear, color)
	_quad(bl, bl + border2, bl + border + border2, bl + border, color, clear, clear, clear)
	_quad(br, br + border2, br - border + border2, br - border, color, clear, clear, clear)
	_quad(el, el - border2, el + border - border2, el + border, color, clear, clear, clear)
	_quad(er, er - border2, er - border - border2, er - border, color, clear, clear, clear)


func _ellipse(center: Vector2, radius: float, color: Color, antialiased: bool) -> void:
	var r: float = maxf(0.0, radius - FEATHER_SIZE * 0.25) if antialiased else radius
	var base: int = points.size()
	for i: int in ELLIPSE_SEGMENTS + 1:
		var angle: float = i * TAU / ELLIPSE_SEGMENTS
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
		colors.append(color)
	points.append(center)
	colors.append(color)
	var middle: int = base + ELLIPSE_SEGMENTS + 1
	for i: int in ELLIPSE_SEGMENTS:
		indices.append_array(PackedInt32Array([middle, base + i, base + i + 1]))
	if not antialiased:
		return
	var border_size: float = FEATHER_SIZE
	if r * 2.0 < 1.0:
		border_size *= r
	var clear: Color = Color(color, 0.0)
	var strip: PackedVector2Array = PackedVector2Array()
	var strip_colors: PackedColorArray = PackedColorArray()
	for i: int in ELLIPSE_SEGMENTS + 1:
		var dir: Vector2 = Vector2(cos(i * TAU / ELLIPSE_SEGMENTS), sin(i * TAU / ELLIPSE_SEGMENTS))
		strip.append(center + dir * r)
		strip.append(center + dir * (r + border_size))
		strip_colors.append(color)
		strip_colors.append(clear)
	_strip(strip, strip_colors)


## Yuvarlak köşeli dikdörtgenin dış çizgisi (StyleBoxFlat sırası: sol üst, sağ üst, sağ alt, sol alt; köşe başına
## CORNER_DETAIL dilim).
func _round_outline(rect: Rect2, radius: float) -> PackedVector2Array:
	var centers: Array[Vector2] = [rect.position + Vector2(radius, radius),
		Vector2(rect.end.x - radius, rect.position.y + radius), rect.end - Vector2(radius, radius),
		Vector2(rect.position.x + radius, rect.end.y - radius)]
	var out: PackedVector2Array = PackedVector2Array()
	for corner: int in 4:
		for detail: int in CORNER_DETAIL + 1:
			var angle: float = (corner + float(detail) / CORNER_DETAIL) * PI * 0.5 + PI
			out.append(centers[corner] + Vector2(cos(angle), sin(angle)) * radius)
	return out
