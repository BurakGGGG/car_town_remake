class_name AvatarView
extends Control
## YUVARLAK PROFİL RESMİ + ÇERÇEVE (+ isteğe bağlı piksel bayrak rozeti). Profil kartı, arkadaş satırı, HUD
## avatar düğmesi, yarış davet / sonuç panosu hep bunu kullanır. Tamamen _draw ile çizilir (çocuk yok, shader yok):
## resim 48 kenarlı dokulu çokgen, çerçeve onun kenarını örten kalın yay.
##
## ÇİZİMLER (hazır avatarlar, Emre / Elif) 512 tuvalde tam portredir: küçük boyda (TIGHT_BELOW altı) yüze yakın
## kırpılır, yoksa 48 px balonda yüz kaybolur (2026-10-16 taslak karşılaştırması). Fotoğraflar zaten kırpılmış.
## Çerçeveler ProfileCatalog.FRAMES; hareketli olanlar (neon / alev / gökkuşağı) yalnızca görünürken çizilir.
## Hareketli çerçevede her kare YALNIZ halka katmanı (_RingLayer çocuğu) değişir; gölge + fotoğraf bu düğümde, değişince
## bir kez (hareketli çerçeveli avatar her karede 48 kenarlı resmi yeniden kuruyordu — betik profili 2026-10-23). Yalnız rengi /
## saydamlığı oynayan çerçevelerde (gökkuşağı, neon: SEGMENTED) yaylar bir kez beyaz / taban renkte çizilir, her kare
## yalnız self_modulate değişir — beyaz yay × renk = o renkte yay, piksel aynı; gökkuşağı avatar başına 0,42 → ~0,02 ms.

const TIGHT_BELOW: float = 100.0
## Çizimlerde yüze yakın kırpım bölgesi (512 tuvalde ~123..389 x 108..374): göz çizgisi (~250) dairenin ortasına
## gelir. (İlk sürüm 72..328'di; kullanıcı "küçük avatarlarda yüzler çok aşağıda kalıyor" dedi.)
const TIGHT_REGION: Rect2 = Rect2(0.24, 0.21, 0.52, 0.52)
const SEGMENTS: int = 48
## Geometrisi sabit, yalnız rengi / saydamlığı zamanla değişen çerçeveler (bkz. _RingLayer).
const SEGMENTED: Array[String] = ["rainbow", "neon"]
const RAINBOW_STEPS: int = 36

@export var texture: Texture2D:
	set(value):
		texture = value
		queue_redraw()
@export var illustrated: bool = false:
	set(value):
		illustrated = value
		queue_redraw()
@export var frame_id: String = ProfileCatalog.DEFAULT_FRAME:
	set(value):
		frame_id = value if ProfileCatalog.is_frame(value) else ProfileCatalog.DEFAULT_FRAME
		_update_process()
		_redraw_ring()
## Sağ altta piksel bayrak (boş = yok). Ayrı FlagIcon çocuğu: pikseller en yakın komşu süzgeciyle keskin kalsın
## (bu düğümün süzgeci fotoğraf için yumuşak).
@export var flag_code: String = "":
	set(value):
		flag_code = value
		_update_flag()
## Bayrak sol altta: sağ alt köşesinde başka rozet olan avatar (HUD — seviye rozeti sağ altta, kullanıcı kararı;
## ikisi üst üste biniyordu, 2026-10-17).
@export var flag_left: bool = false:
	set(value):
		flag_left = value
		_update_flag()
## Çerçeve kalınlığı çarpanı (1 = çapın %7'si).
@export var ring_scale: float = 1.0:
	set(value):
		ring_scale = value
		queue_redraw()
		_redraw_ring()

var _t: float = 0.0
var _flag: FlagIcon
var _ring: _RingLayer
## Halka çizimlerinin hedef tuvali (_RingLayer çizerken o, yoksa bu düğüm).
var _canvas: CanvasItem = self


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = _RingLayer.new()
	_ring.owner_view = self
	add_child(_ring)
	move_child(_ring, 0)   # bayrak (FlagIcon) halkanın üstünde kalsın
	visibility_changed.connect(_update_process)
	resized.connect(_update_flag)
	_update_process()
	_update_flag()


## Tek seferde resim + çizim mi + çerçeve + bayrak.
func show_avatar(tex: Texture2D, is_illustrated: bool, frame: String = ProfileCatalog.DEFAULT_FRAME, flag: String = "") -> void:
	texture = tex
	illustrated = is_illustrated
	frame_id = frame
	flag_code = flag


func _process(delta: float) -> void:
	_t += delta
	if _ring:
		_ring.tick(_t)


func _redraw_ring() -> void:
	if _ring:
		_ring.rebuild()


func _update_process() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and ProfileCatalog.frame_animated(frame_id))


func _draw() -> void:
	var d: float = minf(size.x, size.y)
	if d < 4.0:
		return
	var c: Vector2 = size * 0.5
	var r: float = d * 0.5
	var ring: float = clampf(d * 0.07 * ring_scale, 2.0, 10.0)
	draw_circle(c + Vector2(0.0, maxf(d * 0.025, 1.5)), r, HudPalette.SHADOW, true, -1.0, true)
	draw_circle(c, r, Color("2F3236"), true, -1.0, true)
	_draw_photo(c, r - ring + 0.5, d)


## Halka katmanı çağırır: aynı ölçüler, kendi tuvaline (çocuk, fotoğrafın üstünde).
func _draw_ring_on(layer: CanvasItem) -> void:
	var m: Array = _ring_metrics()
	if m.is_empty():
		return
	_canvas = layer
	_draw_ring(m[0], m[1], m[2])
	_canvas = self


## [merkez, halka yarıçapı, kalınlık] ya da boş (çok küçük).
func _ring_metrics() -> Array:
	var d: float = minf(size.x, size.y)
	if d < 4.0:
		return []
	var ring: float = clampf(d * 0.07 * ring_scale, 2.0, 10.0)
	return [size * 0.5, d * 0.5 - ring * 0.5, ring]


## SEGMENTED çerçevenin yayları (_draw_ring'deki çağrılarla birebir aynı geometri, renk sonra modulate ile):
## [[yaylar...], kip] — kip: &"hue" (gökkuşağı i. dilim), &"glow" (neon hale), &"shine" (neon parıltı), &"" (sabit).
func _segment_recipe() -> Array:
	var m: Array = _ring_metrics()
	if m.is_empty():
		return []
	var c: Vector2 = m[0]
	var rr: float = m[1]
	var w: float = m[2]
	var out: Array = []
	match frame_id:
		"rainbow":
			for i: int in RAINBOW_STEPS:
				var a: float = TAU * i / RAINBOW_STEPS
				out.append([[[c, rr, a, a + TAU / RAINBOW_STEPS + 0.01, 3, Color.WHITE, w]], &"hue"])
			var edge: Color = Color(0.18, 0.2, 0.22, 0.6)
			out.append([[[c, rr + w * 0.5, 0.0, TAU, SEGMENTS, edge, 1.0], [c, rr - w * 0.5, 0.0, TAU, SEGMENTS, edge, 1.0]], &""])
		"neon":
			out.append([[[c, rr, 0.0, TAU, SEGMENTS, Color("1A1030"), w]], &""])
			for half: int in 2:
				var col: Color = Color("FF4FB8") if half == 0 else Color("5CF2FF")
				var a0: float = PI * 0.5 + PI * half
				out.append([[[c, rr, a0, a0 + PI, 24, col, w * 1.8]], &"glow"])
				out.append([[[c, rr, a0, a0 + PI, 24, col, w * 0.45]], &""])
				out.append([[[c, rr, a0, a0 + PI, 24, Color.WHITE, w * 0.15]], &"shine"])
	return out


## Bir dilimin o anki çarpanı (_draw_ring'deki renk / saydamlık formülleri).
func _segment_modulate(mode: StringName, index: int, t: float) -> Color:
	match mode:
		&"hue":
			return Color.from_hsv(fposmod(float(index) / RAINBOW_STEPS + t * 0.12, 1.0), 0.5, 1.0)
		&"glow":
			return Color(1.0, 1.0, 1.0, 0.25 * (0.6 + 0.4 * sin(t * 3.2)))
		&"shine":
			return Color(1.0, 1.0, 1.0, 0.7 * (0.6 + 0.4 * sin(t * 3.2)))
	return Color.WHITE


## Bayrak rozeti: dairenin sağ (flag_left: sol) alt kenarına (merkezden 0,62 r) çapalanır; piksel boyu çapa göre tam sayıya yakın.
func _update_flag() -> void:
	if not is_inside_tree():
		return
	if flag_code.is_empty():
		if _flag:
			_flag.hide()
		return
	if _flag == null:
		_flag = FlagIcon.new()
		_flag.name = "Flag"
		add_child(_flag)
	_flag.show()
	_flag.code = flag_code
	var d: float = minf(size.x, size.y)
	_flag.pixel = maxf(roundf(d * 0.26 / float(FlagIcon.H + 2)), 1.0)
	var anchor_x: float = 0.5 - 0.31 if flag_left else 0.5 + 0.31
	_flag.anchor_left = anchor_x
	_flag.anchor_right = anchor_x
	_flag.anchor_top = 0.5 + 0.31
	_flag.anchor_bottom = 0.5 + 0.31
	_flag.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_flag.grow_vertical = Control.GROW_DIRECTION_BOTH
	var half: Vector2 = _flag.get_combined_minimum_size() * 0.5
	_flag.offset_left = -half.x
	_flag.offset_right = half.x
	_flag.offset_top = -half.y
	_flag.offset_bottom = half.y


func _draw_photo(c: Vector2, r: float, d: float) -> void:
	var tex: Texture2D = texture if texture else ProfileCatalog.default_texture()
	var region: Rect2 = TIGHT_REGION if (illustrated or texture == null) and d < TIGHT_BELOW else Rect2(0, 0, 1, 1)
	var points: PackedVector2Array = PackedVector2Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i: int in SEGMENTS:
		var dir: Vector2 = Vector2.from_angle(TAU * float(i) / SEGMENTS)
		points.append(c + dir * r)
		uvs.append(region.position + (dir * 0.5 + Vector2(0.5, 0.5)) * region.size)
	draw_colored_polygon(points, Color.WHITE, uvs, tex)


# --- Çerçeveler ------------------------------------------------------------------

func _draw_ring(c: Vector2, rr: float, w: float) -> void:
	match frame_id:
		"bronze":
			_metal(c, rr, w, Color("8C5A2B"), Color("D9955A"), Color("5E3A1A"))
		"silver":
			_metal(c, rr, w, Color("8E99A6"), Color("E6EBF0"), Color("5E6670"))
		"gold":
			_metal(c, rr, w, Color("C08A1E"), Color("FFE08A"), Color("85600F"))
		"platinum":
			_metal(c, rr, w, Color("7C9CB5"), Color("EAF6FF"), Color("4D6B82"))
			for k: int in 4:
				_gem(c + Vector2.from_angle(PI * 0.25 + PI * 0.5 * k) * rr, w * 0.85)
		"checker":
			var n: int = 24
			for i: int in n:
				var a0: float = TAU * i / n
				_canvas.draw_arc(c, rr, a0, a0 + TAU / n + 0.01, 4, Color("202124") if i % 2 == 0 else Color("FFFFFF"), w, true)
			_edge(c, rr, w, Color("202124"))
		"carbon":
			_canvas.draw_arc(c, rr, 0.0, TAU, SEGMENTS, Color("2B2E33"), w, true)
			var n2: int = 36
			for i: int in n2:
				if i % 2 == 0:
					var a: float = TAU * i / n2
					_canvas.draw_arc(c, rr - w * 0.2, a, a + TAU / n2 * 0.7, 3, Color("40454D"), w * 0.45, true)
			_canvas.draw_arc(c, rr + w * 0.15, -PI * 0.85, -PI * 0.35, 16, Color(1, 1, 1, 0.35), w * 0.3, true)
			_edge(c, rr, w, Color("15171A"))
		"neon":
			var pulse: float = 0.6 + 0.4 * sin(_t * 3.2)
			_canvas.draw_arc(c, rr, 0.0, TAU, SEGMENTS, Color("1A1030"), w, true)
			for half: int in 2:
				var col: Color = Color("FF4FB8") if half == 0 else Color("5CF2FF")
				var a0: float = PI * 0.5 + PI * half
				_canvas.draw_arc(c, rr, a0, a0 + PI, 24, Color(col, 0.25 * pulse), w * 1.8, true)
				_canvas.draw_arc(c, rr, a0, a0 + PI, 24, col, w * 0.45, true)
				_canvas.draw_arc(c, rr, a0, a0 + PI, 24, Color(1, 1, 1, 0.7 * pulse), w * 0.15, true)
		"flame":
			_canvas.draw_arc(c, rr, 0.0, TAU, SEGMENTS, Color("E8501C"), w, true)
			var tongues: int = 14
			for i: int in tongues:
				var a: float = TAU * i / tongues + sin(_t * 2.0 + i) * 0.04
				var flick: float = 0.75 + 0.25 * sin(_t * 9.0 + i * 1.7)
				var base: Vector2 = c + Vector2.from_angle(a) * (rr + w * 0.3)
				var tip: Vector2 = c + Vector2.from_angle(a + 0.08) * (rr + w * (0.9 + 0.9 * flick))
				var side: Vector2 = Vector2.from_angle(a + PI * 0.5) * w * 0.55
				_canvas.draw_colored_polygon(PackedVector2Array([base - side, tip, base + side]), Color("FF8A1C"))
				_canvas.draw_colored_polygon(PackedVector2Array([base - side * 0.5, base.lerp(tip, 0.6), base + side * 0.5]), Color("FFD24A"))
			_canvas.draw_arc(c, rr - w * 0.15, 0.0, TAU, SEGMENTS, Color("FFB43A"), w * 0.35, true)
		"rainbow":
			var n3: int = 36
			for i: int in n3:
				var a: float = TAU * i / n3
				var hue: float = fposmod(float(i) / n3 + _t * 0.12, 1.0)
				_canvas.draw_arc(c, rr, a, a + TAU / n3 + 0.01, 3, Color.from_hsv(hue, 0.5, 1.0), w, true)
			_edge(c, rr, w, Color(0.18, 0.2, 0.22, 0.6))
		_:
			_canvas.draw_arc(c, rr, 0.0, TAU, SEGMENTS, HudPalette.PLATE_SELECTED_EDGE, w, true)
			_canvas.draw_arc(c, rr - w * 0.5 + 0.75, 0.0, TAU, SEGMENTS, HudPalette.PLATE_SELECTED, maxf(w * 0.25, 1.0), true)


## Metal halka: düz renk, üstte parlak, altta koyu yay.
func _metal(c: Vector2, rr: float, w: float, base: Color, light: Color, dark: Color) -> void:
	_canvas.draw_arc(c, rr, 0.0, TAU, SEGMENTS, base, w, true)
	_canvas.draw_arc(c, rr, PI * 1.1, PI * 1.9, 24, light, w * 0.55, true)
	_canvas.draw_arc(c, rr, PI * 0.15, PI * 0.85, 24, dark, w * 0.4, true)
	_edge(c, rr, w, dark)


## İnce iç / dış kenar çizgisi.
func _edge(c: Vector2, rr: float, w: float, color: Color) -> void:
	_canvas.draw_arc(c, rr + w * 0.5, 0.0, TAU, SEGMENTS, color, 1.0, true)
	_canvas.draw_arc(c, rr - w * 0.5, 0.0, TAU, SEGMENTS, color, 1.0, true)


## Platin çerçevedeki küçük elmas.
func _gem(at: Vector2, s: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array([at + Vector2(0, -s), at + Vector2(s * 0.8, 0), at + Vector2(0, s), at + Vector2(-s * 0.8, 0)])
	_canvas.draw_colored_polygon(pts, HudPalette.GEM)
	_canvas.draw_colored_polygon(PackedVector2Array([pts[0], pts[1], at]), HudPalette.GEM_LIGHT)
	_canvas.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), HudPalette.GEM_DARK, 1.0, true)


## Halka katmanı (fotoğrafın üstü, bayrağın altı). Sabit çerçeveyi değişince bir kez, alevi her kare çizer; SEGMENTED
## çerçevede yayları _Arc çocuklarına bir kez çizdirir ve her kare yalnız onların self_modulate'ini değiştirir.
class _RingLayer:
	extends Control
	var owner_view: AvatarView
	var _arcs: Array[_Arc] = []
	var _modes: Array[StringName] = []
	var _segmented: bool = false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(rebuild)
		rebuild()

	## Çerçeve / boyut / kalınlık değişti.
	func rebuild() -> void:
		for arc: _Arc in _arcs:
			remove_child(arc)
			arc.queue_free()
		_arcs.clear()
		_modes.clear()
		_segmented = owner_view != null and owner_view.frame_id in AvatarView.SEGMENTED
		if _segmented:
			var index: int = 0
			for part: Array in owner_view._segment_recipe():
				var arc: _Arc = _Arc.new()
				arc.arcs = part[0]
				arc.index = index if part[1] == &"hue" else 0
				add_child(arc)
				_arcs.append(arc)
				_modes.append(part[1])
				if part[1] == &"hue":
					index += 1
			tick(owner_view._t)
		queue_redraw()

	func tick(t: float) -> void:
		if not _segmented:
			queue_redraw()
			return
		for i: int in _arcs.size():
			if _modes[i] != &"":
				_arcs[i].self_modulate = owner_view._segment_modulate(_modes[i], _arcs[i].index, t)

	func _draw() -> void:
		if owner_view and not _segmented:
			owner_view._draw_ring_on(self)


## Bir kez çizilen yay(lar): [merkez, yarıçap, başlangıç, bitiş, nokta, renk, kalınlık].
class _Arc:
	extends Node2D
	var arcs: Array = []
	var index: int = 0

	func _draw() -> void:
		for a: Array in arcs:
			draw_arc(a[0], a[1], a[2], a[3], a[4], a[5], a[6], true)
