class_name TutorialHand
extends Control
## EĞİTİM PARMAĞI — hedefe dokunmayı gösteren eldivenli el (asset yok, HudIcon gibi kodla çizilir).
## Düğümün konumu PARMAK UCUDUR: el ucun sağ altına uzanır, böylece gösterdiği şeyi örtmez.
## Döngü: el yaklaşır, bastırır (ucunda dalga halkası açılır), geri çekilir.

const PERIOD: float = 1.25
const ANGLE: float = -0.42
const SKIN: Color = Color("FFF6E5")
const CUFF: Color = HudPalette.PLATE_SELECTED
const OUTLINE: float = 3.0

## Dokunma döngüsü oynasın mı (false: el yalnızca hafifçe süzülür).
var tapping: bool = true
var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var phase: float = fmod(_t, PERIOD) / PERIOD
	var approach: float = 0.0   # 1 = uzakta, 0 = parmak ucu hedefte
	var press: float = 0.0
	if tapping:
		if phase < 0.35:
			approach = 1.0 - _ease(phase / 0.35)
		elif phase < 0.5:
			press = sin((phase - 0.35) / 0.15 * PI)
		else:
			approach = _ease((phase - 0.5) / 0.5)
	else:
		approach = 0.4 + sin(_t * 3.0) * 0.2
	# Dalga halkası: basıştan sonra parmak ucunda açılır
	if tapping and phase >= 0.4:
		var k: float = (phase - 0.4) / 0.6
		draw_arc(Vector2.ZERO, lerpf(8.0, 34.0, k), 0.0, TAU, 40, Color(1.0, 1.0, 1.0, (1.0 - k) * 0.9), 3.0, true)
		draw_arc(Vector2.ZERO, lerpf(4.0, 22.0, k), 0.0, TAU, 32, Color(HudPalette.COIN, (1.0 - k) * 0.7), 2.0, true)
	var offset: Vector2 = Vector2(16.0, 18.0) * approach
	var scale_value: float = 1.0 - press * 0.1
	# Gölge
	draw_set_transform(offset + Vector2(5.0, 7.0), ANGLE, Vector2.ONE * scale_value)
	_hand(Color(0.0, 0.0, 0.0, 0.22), Color(0.0, 0.0, 0.0, 0.22), 0.0)
	draw_set_transform(offset, ANGLE, Vector2.ONE * scale_value)
	_hand(HudPalette.INK, HudPalette.INK, OUTLINE)
	_hand(SKIN, CUFF, 0.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## El parçaları (parmak ucu orijinde, el aşağı uzanır). grow > 0: dış çizgi için büyütülmüş hâli.
func _hand(skin: Color, cuff: Color, grow: float) -> void:
	_capsule(Vector2(0.0, 7.0), Vector2(0.0, 32.0), 7.0 + grow, skin)            # işaret parmağı
	_capsule(Vector2(-6.0, 42.0), Vector2(-16.0, 31.0), 6.0 + grow, skin)        # başparmak
	_round_rect(Rect2(-9.0, 26.0, 35.0, 34.0).grow(grow), 11.0 + grow, skin)      # avuç
	for knuckle: Array in [[Vector2(7.0, 30.0), Vector2(22.0, 31.0)], [Vector2(8.0, 40.0), Vector2(25.0, 41.0)],
			[Vector2(8.0, 50.0), Vector2(23.0, 50.0)]]:
		_capsule(knuckle[0], knuckle[1], 5.5 + grow, skin)                       # kıvrık parmaklar
	_round_rect(Rect2(-8.0, 57.0, 35.0, 13.0).grow(grow), 4.0 + grow, cuff)       # manşet
	if grow == 0.0 and skin == SKIN:
		# Kıvrık parmak aralarındaki ince çizgiler ve tırnak parıltısı
		for y: float in [35.5, 45.5]:
			draw_line(Vector2(12.0, y), Vector2(26.0, y), Color(HudPalette.INK, 0.45), 1.5, true)
		draw_circle(Vector2(-2.0, 6.0), 2.2, Color(1.0, 1.0, 1.0, 0.9))


func _capsule(a: Vector2, b: Vector2, radius: float, color: Color) -> void:
	draw_circle(a, radius, color)
	draw_circle(b, radius, color)
	var side: Vector2 = (b - a).orthogonal().normalized() * radius
	draw_colored_polygon(PackedVector2Array([a + side, b + side, b - side, a - side]), color)


func _round_rect(rect: Rect2, radius: float, color: Color) -> void:
	var r: float = minf(radius, minf(rect.size.x, rect.size.y) * 0.5)
	var points: PackedVector2Array = PackedVector2Array()
	var corners: Array[Vector2] = [rect.end - Vector2(r, r), Vector2(rect.position.x + r, rect.end.y - r),
		rect.position + Vector2(r, r), Vector2(rect.end.x - r, rect.position.y + r)]
	for i: int in 4:
		for step: int in 7:
			var angle: float = PI * 0.5 * float(i) + PI * 0.5 * float(step) / 6.0
			points.append(corners[i] + Vector2.from_angle(angle) * r)
	draw_colored_polygon(points, color)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
