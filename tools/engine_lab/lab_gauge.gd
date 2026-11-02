extends Control
## MOTOR SES LABORATUVARI — gösterge: devir saati (kırmızı bölge), gaz / turbo çubukları, vites, devir kesici ve
## pişmiş devir katmanları (o an çalan iki katman parlak, karışım payıyla).

var idle: float = 850.0
var red: float = 6500.0
var rpm: float = 850.0
var throttle: float = 0.0
var boost: float = 0.0
var has_turbo: bool = false
var gear_text: String = "N"
var limiter: bool = false
var layers: PackedFloat32Array = PackedFloat32Array()
var status: String = ""


func _ready() -> void:
	custom_minimum_size = Vector2(0, 190)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font: Font = get_theme_default_font()
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), Color("15171C"))
	# Devir saati
	var radius: float = minf(h * 0.62, w * 0.16)
	var center: Vector2 = Vector2(radius + 24.0, h * 0.5 + radius * 0.32)
	var top_rpm: float = ceilf(red * 1.08 / 1000.0) * 1000.0
	var a0: float = PI * 0.8
	var a1: float = PI * 2.2
	draw_arc(center, radius, a0, a1, 64, Color("2C313A"), 10.0, true)
	var red_from: float = lerpf(a0, a1, red / top_rpm)
	draw_arc(center, radius, red_from, a1, 24, Color("C0392B"), 10.0, true)
	for k: int in int(top_rpm / 1000.0) + 1:
		var a: float = lerpf(a0, a1, float(k) * 1000.0 / top_rpm)
		var dir: Vector2 = Vector2(cos(a), sin(a))
		draw_line(center + dir * (radius - 16.0), center + dir * (radius - 4.0), Color("8A93A3"), 2.0)
		draw_string(font, center + dir * (radius - 30.0) + Vector2(-5, 5), str(k), HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color("8A93A3"))
	var needle: float = lerpf(a0, a1, clampf(rpm / top_rpm, 0.0, 1.0))
	var tip: Vector2 = center + Vector2(cos(needle), sin(needle)) * (radius - 6.0)
	draw_line(center, tip, Color("FF5A36") if limiter else Color("F2C14E"), 3.0, true)
	draw_circle(center, 6.0, Color("F2C14E"))
	draw_string(font, center + Vector2(-radius * 0.5, radius * 0.42), "%d d/dk" % roundi(rpm),
		HORIZONTAL_ALIGNMENT_CENTER, radius, 16, Color.WHITE)
	draw_string(font, center + Vector2(-20, radius * 0.75), gear_text, HORIZONTAL_ALIGNMENT_CENTER, 40, 22,
		Color("F2C14E"))
	if limiter:
		draw_string(font, center + Vector2(-radius * 0.6, -radius * 0.25), "DEVİR KESİCİ", HORIZONTAL_ALIGNMENT_CENTER,
			radius * 1.2, 13, Color("FF5A36"))
	# Çubuklar
	var bx: float = center.x + radius + 34.0
	_bar(Rect2(bx, 22.0, 22.0, h - 54.0), throttle, Color("4CAF50"), "GAZ")
	if has_turbo:
		_bar(Rect2(bx + 44.0, 22.0, 22.0, h - 54.0), boost, Color("29B6F6"), "TURBO")
	# Katmanlar: log devir ekseni, çalan ikili parlak
	var lx: float = bx + (100.0 if has_turbo else 56.0)
	var lw: float = w - lx - 16.0
	if lw > 60.0 and layers.size() >= 2:
		var y: float = h * 0.5
		draw_string(font, Vector2(lx, 26.0), "PİŞMİŞ DEVİR KATMANLARI (çalan ikili parlak)", HORIZONTAL_ALIGNMENT_LEFT, -1,
			13, Color("8A93A3"))
		var low: float = log(layers[0])
		var high: float = log(layers[layers.size() - 1])
		draw_line(Vector2(lx, y), Vector2(lx + lw, y), Color("2C313A"), 2.0)
		var lo: int = 0
		while lo < layers.size() - 2 and rpm > layers[lo + 1]:
			lo += 1
		var mix: float = clampf(log(maxf(rpm, 1.0) / layers[lo]) / log(layers[lo + 1] / layers[lo]), 0.0, 1.0)
		for i: int in layers.size():
			var x: float = lx + lw * (log(layers[i]) - low) / maxf(high - low, 1e-4)
			var weight: float = 0.0
			if i == lo:
				weight = cos(mix * PI * 0.5)
			elif i == lo + 1:
				weight = sin(mix * PI * 0.5)
			var col: Color = Color("3A404C").lerp(Color("F2C14E"), weight)
			draw_circle(Vector2(x, y), 7.0 + 6.0 * weight, col)
			draw_string(font, Vector2(x - 24.0, y + 30.0), str(roundi(layers[i])), HORIZONTAL_ALIGNMENT_CENTER, 48, 12,
				Color("A8B0BE"))
		var rx: float = lx + lw * (log(clampf(rpm, layers[0], layers[layers.size() - 1])) - low) / maxf(high - low, 1e-4)
		draw_line(Vector2(rx, y - 22.0), Vector2(rx, y + 12.0), Color("FF5A36"), 2.0)
	if status != "":
		draw_string(font, Vector2(lx, h - 14.0), status, HORIZONTAL_ALIGNMENT_LEFT, maxf(lw, 100.0), 13, Color("A8B0BE"))


func _bar(rect: Rect2, value: float, color: Color, label: String) -> void:
	var font: Font = get_theme_default_font()
	draw_rect(rect, Color("2C313A"))
	var fill: float = rect.size.y * clampf(value, 0.0, 1.0)
	draw_rect(Rect2(rect.position.x, rect.end.y - fill, rect.size.x, fill), color)
	draw_string(font, Vector2(rect.position.x - 12.0, rect.end.y + 18.0), label, HORIZONTAL_ALIGNMENT_CENTER,
		rect.size.x + 24.0, 12, Color("A8B0BE"))
