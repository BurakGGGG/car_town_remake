class_name ShiftDial
extends Control
## YUVARLAK VİTES GÖSTERGESİ — drag yarışında vites zamanlaması için kadran.
## Plaka dili: krem yüzey, koyu kontur, amber hedef yayı ve koyu ibre; ekstra ikon/gradyan yok.
##
## `ratio` ibrenin yeri (0-1, saat 8 → saat 4 yönünde süpürür), `target` + `window` isabet
## bölgesidir — oyuncu hedefi GÖREREK dokunur (eskiden şerit göstergede hedef görünmüyordu).
## Yalnızca çizim yapar; zamanlama ve isabet kararı DragRaceScreen'dedir.

## Kadranın açık ucu (derece): DEVİR BANDI sanatıyla (dial_band.png) birebir ölçüldü — yay
## -165°'de başlar, 150° süpürür ve en sağdaki kırmızı çizgide biter. İbre oradan öteye GEÇMEZ.
const START_ANGLE: float = 195.0
const SWEEP: float = 150.0
const RING_WIDTH: float = 7.0

## İdeal devir halesi: kaç halka, kaç ışın ve hangi amberler.
const GLOW_RINGS: int = 9
const GLOW_RAYS: int = 8
const GLOW_WARM: Color = Color(1.0, 0.74, 0.22)
const GLOW_BRIGHT: Color = Color(1.0, 0.92, 0.58)
## Devir sınırı (kırmızı) halesi.
const GLOW_RED: Color = Color(0.95, 0.20, 0.15)
const GLOW_RED_BRIGHT: Color = Color(1.0, 0.55, 0.42)
const RED_ZONE: Color = Color(0.85, 0.16, 0.13)

@export_range(0.0, 1.0, 0.001) var ratio: float = 0.0:
	set(value):
		ratio = clampf(value, 0.0, 1.0)
		queue_redraw()

## YEŞİL DİLİM (iyi vites) — banttaki yeşilin yay oranı.
@export_range(0.0, 1.0, 0.001) var zone_start: float = 0.46:
	set(value):
		zone_start = clampf(value, 0.0, 1.0)
		queue_redraw()

@export_range(0.0, 1.0, 0.001) var zone_end: float = 0.54:
	set(value):
		zone_end = clampf(value, 0.0, 1.0)
		queue_redraw()

## KIRMIZI BÖLGE başlangıcı (yay oranı): sağdaki kırmızı dilim, sonu devir sınırı.
@export_range(0.0, 1.0, 0.001) var redline: float = 0.75:
	set(value):
		redline = clampf(value, 0.0, 1.0)
		queue_redraw()

## İsabet ettiğinde kısa bir amber parlama (DragRaceScreen tetikler).
@export var flash: bool = false:
	set(value):
		flash = value
		queue_redraw()

## İDEAL DEVİR: ibre YEŞİL dilimde. Kadran amber bir halka ile yanar ve nabız gibi atar —
## oyuncu ibreyi milimetrik takip etmek yerine "yandı, bas" diyebilsin.
@export var hot: bool = false:
	set(value):
		hot = value
		queue_redraw()

## DEVİR SINIRI: ibre kırmızı bölgede. Hale KIRMIZI yanar — "geç kaldın, hemen vites at".
@export var over: bool = false:
	set(value):
		over = value
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(108.0, 108.0)


## Asset'ler varsa onlar kullanılır (yüz sabit, yay ve ibre kodla döndürülür); yoksa kadran
## tamamen kodla çizilir — eksik dosya hiçbir şeyi bozmaz.
const FACE_PATH: String = "res://ui/hud/art/dial_face.png"
const NEEDLE_PATH: String = "res://ui/hud/art/dial_needle.png"
## Devir bandı: kırmızı-amber-YEŞİL-amber-kırmızı tam yay (kullanıcı çizimi). Yerinde durur;
## dönen tek parça ibredir.
const BAND_PATH: String = "res://ui/hud/art/dial_band.png"

## Görsellerin 256² tuvallerindeki GERÇEK geometrisi (ölçüldü, alfa kutusu + yay uydurma):
##   yüz : opak kutu (13,17)-(233,237) → merkez (123,127), yarıçap 110
##   bant: yay merkezi (128,162), dış yarıçap 145
## İkisi aynı dikdörtgene çizilince bant yüzün 23 px ALTINA düşüyor ve yanlardan 11 px taşıyordu.
## Bu yüzden bant kendi ölçüsüne göre yerleştirilir: yay merkezi yüzün merkezine, dış yarıçapı
## kadranın yarıçapına oturur — bant yüzün üstüne tam eş merkezli basar.
const FACE_CENTER: Vector2 = Vector2(123.0 / 256.0, 127.0 / 256.0)
const BAND_CENTER: Vector2 = Vector2(128.0 / 256.0, 161.9 / 256.0)
const BAND_FIT: float = 128.0 / 144.9

static var _face: Texture2D
static var _needle: Texture2D
static var _band: Texture2D
static var _loaded: bool = false


static func _load_art() -> void:
	if _loaded:
		return
	_loaded = true
	if ResourceLoader.exists(FACE_PATH):
		_face = load(FACE_PATH)
	if ResourceLoader.exists(NEEDLE_PATH):
		_needle = load(NEEDLE_PATH)
	if ResourceLoader.exists(BAND_PATH):
		_band = load(BAND_PATH)


func _draw() -> void:
	_load_art()
	if _face:
		_draw_art()
	else:
		_draw_procedural()


## Görsellerle: yüz sabit, amber yay hedef açısına, ibre ratio açısına döndürülür.
## Görseller saat 12'yi merkez alarak çizildiği için açıya +90° eklenir.
func _draw_art() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5
	var face_tint: Color = Color.WHITE
	var grow: float = 1.0
	if flash:
		_draw_burst(center, radius)      # İSABET: kısa, beyaza çalan tam patlama
	if hot or over:
		var pulse: float = pulse()
		_draw_glow(center, radius, pulse, over)
		face_tint = Color(1.0, 0.94, 0.92) if over else Color(1.0, 0.99, 0.94)
		grow = 1.0 + (0.06 if over else 0.045) * pulse
	radius *= grow
	var rect: Rect2 = Rect2(-Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	draw_texture_rect(_face, Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0),
		false, face_tint)
	# Yüzün GÖRSEL merkezi tuvalin ortası değil: bant ve ibre buna göre hizalanır.
	var face_center: Vector2 = center + (FACE_CENTER - Vector2(0.5, 0.5)) * radius * 2.0
	if _band:
		# Bant SABİT durur: yeşil dilim gerçekten "iyi vites" noktasıdır, ibre ona gelince yanar.
		var band_tint: Color = Color.WHITE
		if flash:
			band_tint = Color(1.15, 1.15, 1.05)
		elif hot:
			band_tint = Color.WHITE.lerp(Color(1.18, 1.18, 1.05), pulse())
		var band_size: float = radius * 2.0 * BAND_FIT
		draw_texture_rect(_band, Rect2(face_center - BAND_CENTER * band_size,
			Vector2(band_size, band_size)), false, band_tint)
	if _needle:
		var needle_angle: float = deg_to_rad(START_ANGLE + SWEEP * ratio + 90.0)
		draw_set_transform(face_center, needle_angle, Vector2.ONE)
		draw_texture_rect(_needle, rect, false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## İDEAL DEVİR HALESİ — kadranın DIŞINA taşan yumuşak parıltı + dönen kısa ışınlar.
## `danger` ise amber yerine KIRMIZI yanar (devir sınırı).
## Hepsi kadranın arkasına çizilir; dolu daire kullanılmaz (ortayı boyayıp rakamları söndürüyordu).
func _draw_glow(center: Vector2, radius: float, pulse: float, danger: bool = false) -> void:
	var warm: Color = GLOW_RED if danger else GLOW_WARM
	var bright: Color = GLOW_RED_BRIGHT if danger else GLOW_BRIGHT
	# Halkalar ÜST ÜSTE biner (genişlik aradan büyük): beş ayrı halka bant bant görünüyordu,
	# dokuz geniş halka yumuşak bir geçiş veriyor.
	for i: int in GLOW_RINGS:
		var t: float = float(i) / float(GLOW_RINGS - 1)          # 0 = en dış, 1 = jantın dibi
		var ring: float = radius * lerpf(1.30 + 0.08 * pulse, 0.99, t)
		var alpha: float = lerpf(0.035, 0.22, t) * (0.70 + 0.50 * pulse) * (1.35 if danger else 1.0)
		draw_arc(center, ring, 0.0, TAU, 44, Color(warm, alpha), radius * 0.16, true)
	draw_arc(center, radius * 0.99, 0.0, TAU, 48, Color(bright, 0.70 + 0.30 * pulse),
		radius * 0.035 + radius * 0.03 * pulse, true)
	# Dönen kısa ışınlar: duran bir halkadan daha "canlı" duruyor
	var spin: float = float(Time.get_ticks_msec()) * (0.0030 if danger else 0.0015)
	for i: int in GLOW_RAYS:
		var angle: float = spin + TAU * float(i) / float(GLOW_RAYS)
		var dir: Vector2 = Vector2(cos(angle), sin(angle))
		draw_line(center + dir * radius * (1.07 + 0.04 * pulse),
			center + dir * radius * (1.22 + 0.10 * pulse),
			Color(bright, 0.30 + 0.40 * pulse), maxf(radius * 0.045, 2.0), true)


## İSABET PATLAMASI — vites tuttuğunda haleden daha parlak, beyaza çalan tek seferlik halka.
func _draw_burst(center: Vector2, radius: float) -> void:
	for i: int in 4:
		var t: float = float(i) / 3.0
		draw_arc(center, radius * lerpf(1.34, 1.0, t), 0.0, TAU, 44,
			Color(1.0, 0.98, 0.86, lerpf(0.10, 0.55, t)), radius * 0.18, true)
	draw_arc(center, radius * 1.02, 0.0, TAU, 48, Color(1.0, 1.0, 0.94, 0.9), radius * 0.05, true)


## Nabız (0-1): kadran yanarken hale bu değerle büyüyüp küçülür. Ekran da aynı nabzı
## kullanır (buton), böylece efektler birbirinden kaymaz.
func pulse() -> float:
	return 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.011)


## Asset yokken: plaka dilinde kodla çizilen kadran (yedek).
func _draw_procedural() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 4.0
	if hot or over:
		_draw_glow(center, radius + 4.0, pulse(), over)
	draw_circle(center, radius, HudPalette.PLATE)
	draw_arc(center, radius, 0.0, TAU, 48, HudPalette.PLATE_EDGE, 3.0, true)
	var from: float = deg_to_rad(START_ANGLE)
	var to: float = deg_to_rad(START_ANGLE + SWEEP)
	draw_arc(center, radius - 9.0, from, to, 40, HudPalette.INK.lerp(HudPalette.PLATE, 0.55), RING_WIDTH, true)
	var t_from: float = deg_to_rad(START_ANGLE + SWEEP * zone_start)
	var t_to: float = deg_to_rad(START_ANGLE + SWEEP * zone_end)
	var target_color: Color = Color("3FA34D") if not flash else Color("8FE29B")
	draw_arc(center, radius - 9.0, t_from, t_to, 20, target_color,
		RING_WIDTH + (5.0 if hot else 2.0), true)
	draw_arc(center, radius - 9.0, deg_to_rad(START_ANGLE + SWEEP * redline),
		deg_to_rad(START_ANGLE + SWEEP), 12, RED_ZONE, RING_WIDTH + (5.0 if over else 2.0), true)
	for i: int in 9:
		var angle: float = deg_to_rad(START_ANGLE + SWEEP * float(i) / 8.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 3.0)
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius - 13.0)
		draw_line(inner, outer, HudPalette.PLATE_EDGE, 2.0, true)
	var needle: float = deg_to_rad(START_ANGLE + SWEEP * ratio)
	var tip: Vector2 = center + Vector2(cos(needle), sin(needle)) * (radius - 12.0)
	var tail: Vector2 = center - Vector2(cos(needle), sin(needle)) * 8.0
	draw_line(tail, tip, HudPalette.INK, 4.0, true)
	draw_circle(center, 6.0, HudPalette.INK)
	draw_circle(center, 3.0, HudPalette.PLATE)
