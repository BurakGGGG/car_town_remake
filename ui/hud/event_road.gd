class_name EventRoad
extends Container
## ARACA GİDEN YOL (ETKİNLİK PANOSU, taslak B — kullanıcı 2026-10-26: "B iyi ama yol gibi olan yerin çizimi daha cool
## olsun"): etkinlik görevleri kıvrımlı bir yarış pistinin durakları, finişte etkinlik aracı bekler. Pist kodla çizilir:
## gölge, kırmızı-beyaz kerb, beyaz kenar çizgisi, asfalt, orta şerit; biten kısım altın gibi parlar, şu anki durakta
## üstten görünen küçük araç durur. Başta dama bayrak çizgisi, finişte ışıklı FİNİŞ kapısı, yol kenarında koniler.
## Duraklar biten (altın + onay) / şu anki (halka + araç) / sıradaki (numara). Görev plakaları durakların altına / üstüne
## dönüşümlü dizilir (kesik çizgiyle bağlı); ödülü alınmamış biten görevde ÖDÜLÜ AL. Sağda finiş kartı: aracın resmi, adı
## ve durumu (FİNİŞTE ARAÇ SENİN / ARAÇ SENİN! / teselli ödülü); araçsız etkinlikte kupa.
## Yerleşim kendi sıralamasıdır (Container: plakalar durak konumuna göre fit_child_in_rect). EventScreen kurar.

## Biten görevin ödülü istendi (MissionManager.claim_event).
signal claim_requested(mission_id: String)

## Asfaltın kalınlığı (tuval birimi; kerb her yandan KERB).
const ROAD_W: float = 40.0
const KERB: float = 5.0
const KERB_DASH: float = 9.0
const MARKER_R: float = 13.0
const PLATE_MAX_W: float = 190.0
const PLATE_GAP: float = 10.0
## Finiş kartının genişliği (sağda): araç resmi 176 × 110.
const FINISH_W: float = 196.0
const ASPHALT: Color = Color("33363A")
const EDGE_LINE: Color = Color("E9E2D2")
const GLOW: Color = Color("FFD978")
const CONE: Color = Color("F28C28")
## Pistin şekli (taslaktaki eğri): yol alanına göre 0–1, art arda kübik Bezier'ler (başlangıç + 3'er nokta).
const PATH: PackedVector2Array = [
	Vector2(0.026, 0.756),
	Vector2(0.147, 0.756), Vector2(0.172, 0.415), Vector2(0.284, 0.415),
	Vector2(0.397, 0.415), Vector2(0.431, 0.646), Vector2(0.534, 0.598),
	Vector2(0.638, 0.549), Vector2(0.672, 0.293), Vector2(0.776, 0.317),
	Vector2(0.879, 0.341), Vector2(0.897, 0.537), Vector2(0.991, 0.488),
]
const SAMPLES_PER_CURVE: int = 40
## Durakların pist boyunca yeri: ilk durak bu kadar içeride, son durak finişten bu kadar önce.
const STOP_FROM: float = 0.08
const STOP_TO: float = 0.9
const CONES: PackedFloat32Array = [0.22, 0.57, 0.84]
## FİNİŞ kapısının pist sonundan geriliği.
const GANTRY_BACK: float = 26.0

## Duraklar: {id, text, progress, target, done, claimed, ready (ödül alınabilir), reward (metin)}.
var _stops: Array[Dictionary] = []
## Finiş: {car: StringName (&"" = araçsız), name, state: &"loan" | &"won" | &"owned" | &"reward", note}.
var _finish: Dictionary = {}
var _plates: Array[Control] = []
var _finish_card: Control
## Örneklenmiş pist (yerel koordinat) ve birikmiş uzunluklar.
var _points: PackedVector2Array = PackedVector2Array()
var _lengths: PackedFloat32Array = PackedFloat32Array()
var _stop_at: PackedFloat32Array = PackedFloat32Array()   # durağın pist üstündeki uzunluğu
var _done_len: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false


func setup(stops: Array[Dictionary], finish: Dictionary) -> void:
	_stops = stops
	_finish = finish
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_plates.clear()
	for i: int in _stops.size():
		var plate: Control = _plate(_stops[i], i == _current())
		add_child(plate)
		_plates.append(plate)
	_finish_card = _finish_box()
	add_child(_finish_card)
	queue_sort()


## Şu anki durak: ilk bitmemiş görev (hepsi bittiyse -1).
func _current() -> int:
	for i: int in _stops.size():
		if not bool(_stops[i]["done"]):
			return i
	return -1


func _get_minimum_size() -> Vector2:
	return Vector2(560.0, 220.0)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		_layout()


# --- Yerleşim ------------------------------------------------------------------

func _road_rect() -> Rect2:
	return Rect2(Vector2.ZERO, Vector2(maxf(size.x - FINISH_W, 200.0), size.y))


func _layout() -> void:
	_sample()
	var road: Rect2 = _road_rect()
	var n: int = _stops.size()
	_stop_at.resize(n)
	var total: float = _lengths[_lengths.size() - 1] if not _lengths.is_empty() else 0.0
	for i: int in n:
		var f: float = STOP_FROM + (STOP_TO - STOP_FROM) * (float(i) / float(maxi(n - 1, 1)) if n > 1 else 0.5)
		_stop_at[i] = total * f
	var current: int = _current()
	_done_len = total if current < 0 else (_stop_at[current] if current < n else 0.0)
	# Plakalar tercihen dönüşümlü (çiftler durağın altında, tekler üstünde); o yan pisti ya da önceki plakayı örtüyorsa
	# öbür yan denenir (pist dönemeçte plakanın altından geçiyordu).
	var per_side: int = int(ceil(float(n) / 2.0))
	var width: float = minf(PLATE_MAX_W, road.size.x / float(maxi(per_side, 1)) - PLATE_GAP)
	var placed: Array[Rect2] = []
	for i: int in n:
		var plate: Control = _plates[i]
		plate.custom_minimum_size.x = width
		var h: float = plate.get_combined_minimum_size().y
		var p: Vector2 = _point_at(_stop_at[i])
		var x: float = clampf(p.x - width * 0.5, 0.0, road.size.x - width)
		var best: Rect2 = Rect2()
		var best_score: float = INF
		for below: bool in [i % 2 == 0, i % 2 != 0]:
			var y: float = p.y + MARKER_R + 12.0 if below else p.y - MARKER_R - 12.0 - h
			var rect: Rect2 = Rect2(x, clampf(y, 0.0, size.y - h), width, h)
			var score: float = float(_road_hits(rect)) * 10.0 + (0.0 if below == (i % 2 == 0) else 1.0)
			for other: Rect2 in placed:
				if other.intersects(rect.grow(-2.0)):
					score += 100.0
			if score < best_score:
				best_score = score
				best = rect
		placed.append(best)
		fit_child_in_rect(plate, best)
	if _finish_card:
		var end: Vector2 = _points[_points.size() - 1] if not _points.is_empty() else Vector2(road.size.x, size.y * 0.5)
		var card: Vector2 = _finish_card.get_combined_minimum_size()
		var cx: float = clampf(end.x + 14.0, road.size.x - 10.0, size.x - card.x)
		fit_child_in_rect(_finish_card, Rect2(cx, clampf(end.y - card.y * 0.55, 0.0, size.y - card.y), card.x, card.y))
	queue_redraw()


## Plakanın örttüğü pist noktası sayısı (kenar dahil).
func _road_hits(rect: Rect2) -> int:
	var grown: Rect2 = rect.grow(ROAD_W * 0.5 + KERB)
	var hits: int = 0
	for i: int in range(0, _points.size(), 3):
		if grown.has_point(_points[i]):
			hits += 1
	return hits


func _sample() -> void:
	_points = PackedVector2Array()
	_lengths = PackedFloat32Array()
	var road: Rect2 = _road_rect()
	var scale_v: Vector2 = road.size
	var start: Vector2 = PATH[0] * scale_v
	_points.append(start)
	_lengths.append(0.0)
	var i: int = 1
	while i + 2 < PATH.size():
		var a: Vector2 = PATH[i - 1] * scale_v
		var b: Vector2 = PATH[i] * scale_v
		var c: Vector2 = PATH[i + 1] * scale_v
		var d: Vector2 = PATH[i + 2] * scale_v
		for s: int in range(1, SAMPLES_PER_CURVE + 1):
			var t: float = float(s) / float(SAMPLES_PER_CURVE)
			var q: Vector2 = a.bezier_interpolate(b, c, d, t)
			_lengths.append(_lengths[_lengths.size() - 1] + q.distance_to(_points[_points.size() - 1]))
			_points.append(q)
		i += 3


## Pist üstünde `length` uzunluğundaki nokta.
func _point_at(length: float) -> Vector2:
	if _points.is_empty():
		return Vector2.ZERO
	for i: int in range(1, _points.size()):
		if _lengths[i] >= length:
			var seg: float = _lengths[i] - _lengths[i - 1]
			var t: float = (length - _lengths[i - 1]) / seg if seg > 0.0 else 0.0
			return _points[i - 1].lerp(_points[i], t)
	return _points[_points.size() - 1]


func _tangent_at(length: float) -> Vector2:
	var a: Vector2 = _point_at(maxf(length - 4.0, 0.0))
	var b: Vector2 = _point_at(length + 4.0)
	return (b - a).normalized() if a != b else Vector2.RIGHT


## Pistin [from, to] uzunluk aralığı (çizim için alt yol).
func _sub_path(from: float, to: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array([_point_at(from)])
	for i: int in _points.size():
		if _lengths[i] > from and _lengths[i] < to:
			out.append(_points[i])
	out.append(_point_at(to))
	return out


# --- Çizim ---------------------------------------------------------------------

func _draw() -> void:
	if _points.size() < 2:
		return
	var total: float = _lengths[_lengths.size() - 1]
	var shadow: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in _points:
		shadow.append(p + Vector2(0.0, 6.0))
	draw_polyline(shadow, HudPalette.SHADOW, ROAD_W + KERB * 2.0 + 6.0, true)
	# Kerb: beyaz zemin üstüne kırmızı parçalar
	draw_polyline(_points, HudPalette.TEXT_LIGHT, ROAD_W + KERB * 2.0, true)
	var s: float = 0.0
	while s < total:
		draw_polyline(_sub_path(s, minf(s + KERB_DASH, total)), HudPalette.DANGER, ROAD_W + KERB * 2.0, false)
		s += KERB_DASH * 2.0
	draw_polyline(_points, EDGE_LINE, ROAD_W + 2.0, true)
	draw_polyline(_points, ASPHALT, ROAD_W - 3.0, true)
	# Biten kısım: yumuşak altın parıltı + parlak orta çizgi; kalan kısımda kesik beyaz şerit
	if _done_len > 0.0:
		var done: PackedVector2Array = _sub_path(0.0, _done_len)
		draw_polyline(done, Color(HudPalette.COIN, 0.25), ROAD_W - 5.0, true)
		draw_polyline(done, Color(HudPalette.COIN, 0.45), 12.0, true)
		draw_polyline(done, GLOW, 4.0, true)
	s = _done_len + 6.0
	while s < total:
		draw_polyline(_sub_path(s, minf(s + 10.0, total)), Color(HudPalette.TEXT_LIGHT, 0.7), 2.5, true)
		s += 19.0
	_draw_start()
	_draw_cones(total)
	_draw_gantry()
	_draw_leaders()
	for i: int in _stops.size():
		_draw_stop(i)


func _draw_start() -> void:
	var p: Vector2 = _point_at(6.0)
	var t: Vector2 = _tangent_at(6.0)
	draw_set_transform(p, t.angle())
	var cell: float = (ROAD_W + KERB * 2.0) / 6.0
	for row: int in 6:
		for col: int in 2:
			var dark: bool = (row + col) % 2 == 0
			draw_rect(Rect2(Vector2(-cell + col * cell, -cell * 3.0 + row * cell), Vector2(cell, cell)),
				HudPalette.INK if dark else HudPalette.TEXT_LIGHT)
	draw_set_transform(Vector2.ZERO)
	# Başlangıç bayrağı
	var n: Vector2 = Vector2(t.y, -t.x)
	var pole: Vector2 = p + n * (ROAD_W * 0.5 + KERB + 6.0)
	draw_line(pole, pole - Vector2(0.0, 34.0), HudPalette.SIDEWALK, 3.0, true)
	draw_colored_polygon(PackedVector2Array([pole - Vector2(0.0, 34.0), pole + Vector2(20.0, -28.0),
		pole - Vector2(0.0, 22.0)]), HudPalette.COIN)


func _draw_cones(total: float) -> void:
	for k: int in CONES.size():
		var at: float = total * CONES[k]
		var p: Vector2 = _point_at(at)
		var t: Vector2 = _tangent_at(at)
		var n: Vector2 = Vector2(-t.y, t.x) * (1.0 if k % 2 == 0 else -1.0)
		var base: Vector2 = p + n * (ROAD_W * 0.5 + KERB + 11.0)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-7.0, 0.0), base + Vector2(0.0, -18.0),
			base + Vector2(7.0, 0.0)]), CONE)
		draw_line(base + Vector2(-4.0, -7.0), base + Vector2(4.0, -7.0), HudPalette.TEXT_LIGHT, 2.5)
		draw_rect(Rect2(base + Vector2(-9.0, -1.0), Vector2(18.0, 4.0)), HudPalette.INK)


func _draw_gantry() -> void:
	# Kapı pistin sonundan biraz önce: finiş kartındaki aracın üstüne binmesin
	var end: Vector2 = _point_at(_lengths[_lengths.size() - 1] - GANTRY_BACK)
	var half: float = ROAD_W * 0.5 + KERB + 4.0
	var top: float = end.y - 74.0
	for side: float in [-1.0, 1.0]:
		var x: float = end.x - 8.0 + side * half
		draw_rect(Rect2(x - 3.0, top, 6.0, end.y + half - top), HudPalette.SIDEWALK)
		draw_rect(Rect2(x - 3.0, top, 6.0, end.y + half - top), HudPalette.INK, false, 1.5)
	var beam: Rect2 = Rect2(end.x - 8.0 - half - 12.0, top - 6.0, (half + 12.0) * 2.0, 30.0)
	draw_rect(beam.grow(2.0), HudPalette.COIN)
	draw_rect(beam, Color("23262B"))
	var cell: float = beam.size.x / 14.0
	for c: int in 14:
		for r: int in 2:
			draw_rect(Rect2(beam.position + Vector2(c * cell, r * cell * 0.5), Vector2(cell, cell * 0.5)),
				HudPalette.INK if (c + r) % 2 == 0 else HudPalette.TEXT_LIGHT)
	var font: Font = get_theme_default_font()
	var text: String = Loc.t("FİNİŞ")
	var w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, Vector2(beam.get_center().x - w * 0.5, beam.end.y - 5.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
		HudPalette.TEXT_LIGHT)
	for k: int in 2:
		draw_circle(Vector2(beam.position.x + 6.0 + k * (beam.size.x - 12.0), beam.end.y - 9.0), 2.6, HudPalette.COIN)


func _draw_leaders() -> void:
	for i: int in mini(_plates.size(), _stop_at.size()):
		var p: Vector2 = _point_at(_stop_at[i])
		var rect: Rect2 = _plates[i].get_rect()
		var target: Vector2 = Vector2(clampf(p.x, rect.position.x + 8.0, rect.end.x - 8.0),
			rect.position.y if rect.position.y > p.y else rect.end.y)
		var dir: Vector2 = target - p
		var len: float = dir.length()
		if len <= MARKER_R + 2.0:
			continue
		dir /= len
		var color: Color = HudPalette.COIN if bool(_stops[i]["done"]) or i == _current() else Color(HudPalette.TEXT_LIGHT, 0.6)
		var d: float = MARKER_R
		while d < len:
			draw_line(p + dir * d, p + dir * minf(d + 4.0, len), color, 1.5)
			d += 8.0


func _draw_stop(i: int) -> void:
	var p: Vector2 = _point_at(_stop_at[i])
	var done: bool = bool(_stops[i]["done"])
	if i == _current():
		draw_circle(p, MARKER_R + 9.0, Color(HudPalette.COIN, 0.18), true, -1.0, true)
		draw_arc(p, MARKER_R + 4.0, 0.0, TAU, 32, Color(HudPalette.COIN, 0.75), 2.5, true)
		_draw_car_marker(p, _tangent_at(_stop_at[i]))
		return
	draw_circle(p + Vector2(0.0, 2.0), MARKER_R, HudPalette.SHADOW, true, -1.0, true)
	draw_circle(p, MARKER_R, HudPalette.INK, true, -1.0, true)
	draw_circle(p, MARKER_R - 2.5, HudPalette.COIN if done else HudPalette.PLATE, true, -1.0, true)
	if done:
		draw_polyline(PackedVector2Array([p + Vector2(-5.5, 0.5), p + Vector2(-1.5, 4.5), p + Vector2(6.0, -4.0)]),
			HudPalette.INK, 3.0, true)
	else:
		var font: Font = get_theme_default_font()
		var number: String = str(i + 1)
		var w: float = font.get_string_size(number, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, p + Vector2(-w * 0.5, 4.5), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, HudPalette.INK)


## Üstten görünen küçük araç (şu anki durak): gövde, ön cam, dört teker, farlar; pistin yönüne döner.
func _draw_car_marker(p: Vector2, tangent: Vector2) -> void:
	draw_set_transform(p, tangent.angle())
	for wheel: Vector2 in [Vector2(-9.0, -10.0), Vector2(5.0, -10.0), Vector2(-9.0, 7.0), Vector2(5.0, 7.0)]:
		draw_rect(Rect2(wheel, Vector2(6.0, 3.0)), HudPalette.INK)
	draw_rect(Rect2(-14.0, -8.0, 28.0, 16.0), HudPalette.INK)
	draw_rect(Rect2(-12.5, -6.5, 25.0, 13.0), HudPalette.TEXT_LIGHT)
	draw_rect(Rect2(-1.0, -5.0, 7.0, 10.0), HudPalette.INK)
	draw_rect(Rect2(11.0, -5.5, 2.5, 3.0), HudPalette.COIN)
	draw_rect(Rect2(11.0, 2.5, 2.5, 3.0), HudPalette.COIN)
	draw_set_transform(Vector2.ZERO)


# --- Plakalar --------------------------------------------------------------------

func _plate(stop: Dictionary, current: bool) -> Control:
	var done: bool = bool(stop["done"])
	var plate: PanelContainer = PanelContainer.new()
	plate.name = "Stop_%s" % String(stop["id"])
	plate.mouse_filter = Control.MOUSE_FILTER_PASS
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = HudPalette.COIN if current else (Color("FBF1D6") if done else HudPalette.PLATE)
	box.set_corner_radius_all(7)
	box.border_width_bottom = 3
	box.border_color = HudPalette.PLATE_SELECTED_EDGE if current or done else HudPalette.PLATE_EDGE
	box.shadow_color = HudPalette.SHADOW
	box.shadow_size = 3
	box.shadow_offset = Vector2(0.0, 2.0)
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 4.0
	box.content_margin_bottom = 5.0
	plate.add_theme_stylebox_override(&"panel", box)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override(&"separation", 1)
	plate.add_child(column)
	if current:
		column.add_child(_label(Loc.t("ŞU AN"), 9, HudPalette.INK))
	var text: Label = _label(String(stop["text"]), 11, HudPalette.INK)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.max_lines_visible = 2
	column.add_child(text)
	var target: int = maxi(int(stop["target"]), 1)
	var progress: int = mini(int(stop["progress"]), target)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override(&"separation", 5)
	column.add_child(row)
	if not done:
		var bar: _Bar = _Bar.new()
		bar.value = float(progress) / float(target)
		bar.dark = current
		bar.custom_minimum_size = Vector2(0.0, 5.0)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bar)
	var count: Label = _label(("✔ " if done else "") + "%s / %s" % [Hud.format_thousands(progress),
		Hud.format_thousands(target)], 10, HudPalette.PLATE_SELECTED_EDGE if done and not current else HudPalette.INK)
	row.add_child(count)
	var reward: String = String(stop.get("reward", ""))
	if bool(stop.get("ready", false)):
		var claim: PlateButton = PlateButton.new()
		claim.name = "Claim_%s" % String(stop["id"])
		claim.theme_type_variation = &"HudPlateSmall"
		claim.text = Loc.t("ÖDÜLÜ AL")
		claim.highlight = true
		claim.focus_mode = Control.FOCUS_NONE
		var mission_id: String = String(stop["id"])
		claim.pressed.connect(func() -> void: claim_requested.emit(mission_id))
		column.add_child(claim)
	elif not reward.is_empty() and not bool(stop.get("claimed", false)):
		var line: Label = _label(reward, 9, HudPalette.INK_SOFT)
		line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		line.clip_text = true
		column.add_child(line)
	return plate


func _finish_box() -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.name = "Finish"
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override(&"separation", 2)
	var car: StringName = StringName(_finish.get("car", &""))
	var state: StringName = StringName(_finish.get("state", &"loan"))
	if car != &"":
		if state == &"loan":
			var tag: PanelContainer = _pill(Loc.t("ÖDÜNÇ"), HudPalette.COIN, HudPalette.INK)
			tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			column.add_child(tag)
		var stage: Control = Control.new()
		stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stage.custom_minimum_size = Vector2(176.0, 110.0)
		column.add_child(stage)
		var spot: _Spot = _Spot.new()
		spot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		stage.add_child(spot)
		var photo: TextureRect = TextureRect.new()
		photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var path: String = ProfileCard.THUMB_DIR + String(car) + ".png"
		if ResourceLoader.exists(path):
			photo.texture = load(path) as Texture2D
		stage.add_child(photo)
		var title: Label = _label(String(_finish.get("name", "")), 14, HudPalette.TEXT_LIGHT)
		title.theme_type_variation = &"HudOutlined"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(title)
	else:
		var trophy: HudIcon = HudIcon.new()
		trophy.kind = HudIcon.Kind.TROPHY
		trophy.icon_size = 48.0
		trophy.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trophy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(trophy)
	var note: String = String(_finish.get("note", ""))
	if not note.is_empty():
		var pill: PanelContainer = _pill(note, HudPalette.COIN if state != &"won" else HudPalette.PLATE,
			HudPalette.INK)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		column.add_child(pill)
	column.custom_minimum_size.x = FINISH_W - 10.0
	return column


func _pill(text: String, color: Color, ink: Color) -> PanelContainer:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(6)
	box.border_width_bottom = 2
	box.border_color = HudPalette.PLATE_SELECTED_EDGE
	box.content_margin_left = 7.0
	box.content_margin_right = 7.0
	box.content_margin_top = 1.0
	box.content_margin_bottom = 2.0
	pill.add_theme_stylebox_override(&"panel", box)
	pill.add_child(_label(text, 11, ink))
	return pill


func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.theme_type_variation = &"HudInkValue"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## İlerleme çubuğu.
class _Bar extends Control:
	var value: float = 0.0
	var dark: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(HudPalette.INK, 0.2), true)
		if value > 0.0:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size.x * clampf(value, 0.0, 1.0), size.y)),
				HudPalette.INK if dark else HudPalette.COIN, true)


## Finişteki aracın altında spot ışığı (yumuşak altın elips).
class _Spot extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = Vector2(size.x * 0.5, size.y * 0.86)
		draw_set_transform(c, 0.0, Vector2(1.0, 0.24))
		draw_circle(Vector2.ZERO, size.x * 0.48, Color(HudPalette.COIN, 0.22), true, -1.0, true)
		draw_circle(Vector2.ZERO, size.x * 0.34, Color(HudPalette.COIN, 0.25), true, -1.0, true)
		draw_set_transform(Vector2.ZERO)
