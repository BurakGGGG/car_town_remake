class_name GemPackArt
extends Control
## GEM PAKETİ ÇİZİMİ — mağaza kartlarının ve HUD'daki GEM AL düğmesinin hareketli görseli. Tamamen
## koddan çizilir (doku yok): yüzeyli gemler, ışık hüzmesi, parıltı, gölge. Paket büyüdükçe sahne
## zenginleşir: avuç → kese → sandık → kasa dairesi; başlangıç paketi hediye kutusudur.
## Ölçü kutunun kısa kenarına (s) göre: her boyutta aynı oranla çizilir.

enum Kind { STARTER, HANDFUL, POUCH, CHEST, VAULT, BUTTON }

const GEM_BLUE: Color = Color("6CCBF2")
const GEM_CYAN: Color = Color("8FE3F5")
const GEM_DEEP: Color = Color("3B8FD9")
const GEM_VIOLET: Color = Color("A68BF0")
const GEM_PINK: Color = Color("F28BC4")
const GOLD: Color = Color("F5BE4C")
const GOLD_DARK: Color = Color("B27A1C")
const WOOD: Color = Color("9A6233")
const WOOD_DARK: Color = Color("6B3F1F")
const STEEL: Color = Color("9AA6B2")
const STEEL_DARK: Color = Color("5C6670")
const GIFT: Color = Color("E2474F")
const GIFT_DARK: Color = Color("A42E35")
const LEATHER: Color = Color("B07A4A")
const LEATHER_DARK: Color = Color("7A4E2B")
const BADGE: Color = Color("E2474F")
## Kart çizimlerinin koyu vitrin zemini (gemler koyu zeminde parlar) — pakete göre renk.
const BACKDROP: Dictionary = {
	Kind.STARTER: Color("7E2236"),
	Kind.HANDFUL: Color("23507E"),
	Kind.POUCH: Color("1C5E66"),
	Kind.CHEST: Color("43306E"),
	Kind.VAULT: Color("16243F"),
}
## Mağaza kartları saniyede en çok bu kadar yeniden çizilir: hareketler yavaş (1,8–3 rad/sn), 30 Hz akıcı; kart
## çizimi ağır (yığın, ışın, gem) ve mağaza açıkken beş kart her karede baştan çiziliyordu (masaüstü ~3,8 ms/kare).
const CARD_REDRAW_HZ: float = 30.0

@export var kind: Kind = Kind.HANDFUL:
	set(value):
		kind = value
		queue_redraw()
## Sağ üstte dönen rozet yazısı ("+%30"). Boşsa rozet yok.
var badge_text: String = ""

var _t: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## GEM AL düğmesi (Kind.BUTTON): zıplayan gem ve parıltı ayrı alt öğelerde bir kez çizilir, sonra yalnızca
## konum / ölçek / saydamlıkla oynar. HUD'da hep görünen düğme her karede baştan çiziliyordu: oturmuş dünyada
## kare başı betik süresinin ~%60'ı (qa/script_profile.gd world). Görüntü aynı (qa/gem_button_shots.gd).
var _button_gem: _Piece
var _button_spark: _Piece
var _since_redraw: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = kind != Kind.BUTTON   # hüzmeler vitrin zemininin dışına taşmasın
	_t = randf() * 10.0   # yan yana kartlar aynı anda parlamasın
	if kind == Kind.BUTTON:
		_button_gem = _Piece.new(_Piece.GEM)
		_button_spark = _Piece.new(_Piece.SPARK)
		add_child(_button_gem)
		add_child(_button_spark)
		resized.connect(_layout_button)
		_layout_button()


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		if _button_gem:
			_animate_button()
		else:
			_since_redraw += delta
			if _since_redraw >= 1.0 / CARD_REDRAW_HZ:
				_since_redraw = 0.0
				queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	if BACKDROP.has(kind):
		_backdrop(BACKDROP[kind])
	match kind:
		Kind.STARTER:
			_draw_starter(c, s)
		Kind.HANDFUL:
			_draw_handful(c, s)
		Kind.POUCH:
			_draw_pouch(c, s)
		Kind.CHEST:
			_draw_chest(c, s)
		Kind.VAULT:
			_draw_vault(c, s)
		Kind.BUTTON:
			_draw_button(c, s)
	if not badge_text.is_empty():
		_draw_badge(Vector2(size.x - s * 0.2, s * 0.19), s * 0.17)


# --- Sahneler -------------------------------------------------------------------------------

func _draw_handful(c: Vector2, s: float) -> void:
	_glow(c + Vector2(0.0, 0.0), s * 0.42, GEM_CYAN, 0.35)
	_shadow(c + Vector2(0.0, s * 0.33), s * 0.34)
	var bob: float = sin(_t * 2.2) * s * 0.015
	_gem(c + Vector2(-s * 0.2, s * 0.14), s * 0.3, GEM_CYAN, -0.35)
	_gem(c + Vector2(s * 0.21, s * 0.15), s * 0.28, GEM_DEEP, 0.3)
	_gem(c + Vector2(0.0, -s * 0.02 + bob), s * 0.44, GEM_BLUE, 0.0)
	_twinkles(c, s, [Vector2(-0.3, -0.25), Vector2(0.28, -0.18), Vector2(0.06, 0.3)])


func _draw_pouch(c: Vector2, s: float) -> void:
	_glow(c + Vector2(0.0, -s * 0.12), s * 0.4, GEM_CYAN, 0.3)
	_shadow(c + Vector2(0.0, s * 0.36), s * 0.36)
	var body: Vector2 = c + Vector2(0.0, s * 0.13)
	# Kese gövdesi: alt koyu, üst açık, yan parlaklık
	_ellipse(body + Vector2(0.0, s * 0.02), s * 0.31, s * 0.25, LEATHER_DARK)
	_ellipse(body, s * 0.29, s * 0.23, LEATHER)
	_ellipse(body + Vector2(-s * 0.12, -s * 0.08), s * 0.07, s * 0.1, LEATHER.lightened(0.25))
	# Boyun ve ip
	var neck: PackedVector2Array = PackedVector2Array([
		body + Vector2(-s * 0.13, -s * 0.18), body + Vector2(s * 0.13, -s * 0.18),
		body + Vector2(s * 0.2, -s * 0.3), body + Vector2(-s * 0.2, -s * 0.3)])
	draw_colored_polygon(neck, LEATHER)
	draw_line(body + Vector2(-s * 0.15, -s * 0.2), body + Vector2(s * 0.15, -s * 0.2), GOLD, s * 0.045, true)
	draw_line(body + Vector2(s * 0.1, -s * 0.2), body + Vector2(s * 0.16, -s * 0.06), GOLD_DARK, s * 0.025, true)
	draw_circle(body + Vector2(s * 0.16, -s * 0.06), s * 0.025, GOLD, true, -1.0, true)
	# Ağız: içi koyu, üstünden gemler taşar
	var mouth: Vector2 = body + Vector2(0.0, -s * 0.3)
	_ellipse(mouth, s * 0.2, s * 0.06, LEATHER_DARK.darkened(0.3))
	var bob: float = sin(_t * 2.0) * s * 0.012
	_gem(mouth + Vector2(-s * 0.1, -s * 0.03), s * 0.17, GEM_DEEP, -0.4)
	_gem(mouth + Vector2(s * 0.11, -s * 0.02), s * 0.16, GEM_CYAN, 0.35)
	_gem(mouth + Vector2(0.0, -s * 0.09 + bob), s * 0.22, GEM_BLUE, 0.05)
	# Dışarı dökülmüş tek gem
	_gem(c + Vector2(s * 0.36, s * 0.3), s * 0.13, GEM_VIOLET, 0.6)
	_twinkles(c, s, [Vector2(-0.32, -0.3), Vector2(0.3, -0.34), Vector2(-0.38, 0.12), Vector2(0.12, -0.42)])


func _draw_chest(c: Vector2, s: float) -> void:
	_rays(c + Vector2(0.0, -s * 0.08), s * 0.6, 10, Color(GOLD, 0.22), _t * 0.25)
	_glow(c + Vector2(0.0, -s * 0.1), s * 0.38, GOLD, 0.35)
	_shadow(c + Vector2(0.0, s * 0.37), s * 0.42)
	var top: float = c.y + s * 0.02
	var bottom: float = c.y + s * 0.34
	var left: float = c.x - s * 0.38
	var right: float = c.x + s * 0.38
	# Açık kapak (arkada)
	var lid: PackedVector2Array = PackedVector2Array([
		Vector2(left, top), Vector2(left + s * 0.05, top - s * 0.3),
		Vector2(right - s * 0.05, top - s * 0.3), Vector2(right, top)])
	draw_colored_polygon(lid, WOOD_DARK)
	draw_colored_polygon(PackedVector2Array([
		Vector2(left + s * 0.05, top - s * 0.02), Vector2(left + s * 0.09, top - s * 0.26),
		Vector2(right - s * 0.09, top - s * 0.26), Vector2(right - s * 0.05, top - s * 0.02)]), WOOD_DARK.darkened(0.35))
	draw_polyline(PackedVector2Array([lid[0], lid[1], lid[2], lid[3]]), GOLD_DARK, s * 0.025, true)
	# Gem yığını (kapağın önünde, gövdenin arkasında)
	_pile(Vector2(c.x, top + s * 0.02), s * 0.7, s * 0.2, 3, s * 0.13, 11, [GEM_BLUE, GEM_CYAN, GEM_DEEP, GEM_VIOLET])
	var bob: float = sin(_t * 2.0) * s * 0.012
	_gem(Vector2(c.x, top - s * 0.17 + bob), s * 0.24, GEM_PINK, 0.0)
	# Gövde: tahtalar, altın kuşaklar, kilit
	draw_rect(Rect2(left, top, right - left, bottom - top), WOOD)
	for i: int in 3:
		var y: float = top + (bottom - top) * (float(i) + 1.0) / 4.0
		draw_line(Vector2(left, y), Vector2(right, y), WOOD_DARK, maxf(s * 0.012, 1.0), true)
	draw_rect(Rect2(left, top, right - left, s * 0.045), WOOD.lightened(0.2))
	for x: float in [left + s * 0.1, right - s * 0.16]:
		draw_rect(Rect2(x, top, s * 0.06, bottom - top), GOLD)
		draw_rect(Rect2(x + s * 0.045, top, s * 0.015, bottom - top), GOLD_DARK)
	draw_rect(Rect2(c.x - s * 0.06, top + s * 0.04, s * 0.12, s * 0.13), GOLD)
	draw_circle(Vector2(c.x, top + s * 0.09), s * 0.022, WOOD_DARK.darkened(0.4), true, -1.0, true)
	draw_rect(Rect2(c.x - s * 0.008, top + s * 0.09, s * 0.016, s * 0.045), WOOD_DARK.darkened(0.4))
	draw_rect(Rect2(left, top, right - left, bottom - top), WOOD_DARK, false, maxf(s * 0.015, 1.0))
	_twinkles(c, s, [Vector2(-0.34, -0.36), Vector2(0.36, -0.3), Vector2(-0.1, -0.44), Vector2(0.2, -0.42), Vector2(0.42, 0.05)])


func _draw_vault(c: Vector2, s: float) -> void:
	_rays(c + Vector2(0.0, -s * 0.05), s * 0.75, 14, Color(GEM_CYAN, 0.25), -_t * 0.3)
	_rays(c + Vector2(0.0, -s * 0.05), s * 0.6, 7, Color(GOLD, 0.2), _t * 0.2)
	_glow(c + Vector2(0.0, -s * 0.05), s * 0.45, GEM_CYAN, 0.4)
	_shadow(c + Vector2(0.0, s * 0.38), s * 0.46)
	# Çelik kasa: içi rafta gemler, kapı sola açık
	var box: Rect2 = Rect2(c.x - s * 0.24, c.y - s * 0.38, s * 0.5, s * 0.56)
	draw_rect(box, STEEL)
	draw_rect(box.grow(-s * 0.04), STEEL_DARK.darkened(0.45))
	for row: int in 2:
		var shelf_y: float = box.position.y + s * (0.2 + 0.17 * float(row))
		for i: int in 4:
			var colors: Array[Color] = [GEM_BLUE, GEM_VIOLET, GEM_CYAN, GEM_PINK]
			_gem(Vector2(box.position.x + s * (0.1 + 0.1 * float(i)), shelf_y - s * 0.05), s * 0.1, colors[(i + row) % 4], 0.0)
		draw_rect(Rect2(box.position.x + s * 0.04, shelf_y, box.size.x - s * 0.08, s * 0.02), STEEL)
	draw_rect(box, STEEL_DARK, false, maxf(s * 0.015, 1.0))
	var door: PackedVector2Array = PackedVector2Array([
		box.position, box.position + Vector2(-s * 0.2, s * 0.06),
		box.position + Vector2(-s * 0.2, box.size.y - s * 0.06), box.position + Vector2(0.0, box.size.y)])
	draw_colored_polygon(door, STEEL.darkened(0.08))
	draw_polyline(PackedVector2Array([door[0], door[1], door[2], door[3]]), STEEL_DARK, maxf(s * 0.015, 1.0), true)
	var dial: Vector2 = box.position + Vector2(-s * 0.1, box.size.y * 0.5)
	draw_circle(dial, s * 0.06, STEEL_DARK, true, -1.0, true)
	draw_circle(dial, s * 0.045, STEEL.lightened(0.3), true, -1.0, true)
	for i: int in 3:
		var a: float = _t * 0.8 + TAU * float(i) / 3.0
		draw_line(dial, dial + Vector2(cos(a), sin(a)) * s * 0.05, STEEL_DARK, maxf(s * 0.012, 1.0), true)
	# Önde taşan büyük yığın + tepede dev gem
	_pile(Vector2(c.x + s * 0.04, c.y + s * 0.27), s * 0.86, s * 0.22, 3, s * 0.14, 23,
		[GEM_BLUE, GEM_CYAN, GEM_DEEP, GEM_VIOLET, GEM_PINK])
	for i: int in 5:
		var coin: Vector2 = c + Vector2(s * (-0.38 + 0.19 * float(i)), s * (0.33 + 0.02 * float(i % 2)))
		_ellipse(coin, s * 0.045, s * 0.022, GOLD_DARK)
		_ellipse(coin + Vector2(0.0, -s * 0.008), s * 0.045, s * 0.022, GOLD)
	var bob: float = sin(_t * 1.8) * s * 0.015
	_gem(c + Vector2(s * 0.3, -s * 0.12 + bob), s * 0.3, GEM_BLUE, 0.18)
	_twinkles(c, s, [Vector2(-0.42, -0.4), Vector2(0.42, -0.42), Vector2(0.0, -0.46), Vector2(-0.46, 0.1),
		Vector2(0.44, 0.12), Vector2(0.24, -0.36)])


func _draw_starter(c: Vector2, s: float) -> void:
	_rays(c + Vector2(0.0, -s * 0.05), s * 0.65, 12, Color(GOLD, 0.25), _t * 0.35)
	_glow(c + Vector2(0.0, -s * 0.12), s * 0.4, GOLD, 0.45)
	_shadow(c + Vector2(0.0, s * 0.4), s * 0.36)
	var top: float = c.y + s * 0.06
	var bottom: float = c.y + s * 0.38
	var half: float = s * 0.29
	# Kutu
	draw_rect(Rect2(c.x - half, top, half * 2.0, bottom - top), GIFT)
	draw_rect(Rect2(c.x + half * 0.45, top, half * 0.55, bottom - top), GIFT_DARK)
	draw_rect(Rect2(c.x - s * 0.045, top, s * 0.09, bottom - top), GOLD)
	draw_rect(Rect2(c.x + s * 0.025, top, s * 0.02, bottom - top), GOLD_DARK)
	# Kutunun ağzı: içi koyu, gemler ağızdan fışkırır
	draw_rect(Rect2(c.x - half, top - s * 0.02, half * 2.0, s * 0.04), GIFT_DARK.darkened(0.4))
	var lift: float = s * (0.18 + 0.02 * sin(_t * 3.0))
	_glow(Vector2(c.x, top - s * 0.06), s * 0.24, GOLD, 0.7)
	_gem(Vector2(c.x - s * 0.15, top - s * 0.06), s * 0.17, GEM_CYAN, -0.45)
	_gem(Vector2(c.x + s * 0.16, top - s * 0.05), s * 0.16, GEM_VIOLET, 0.45)
	_gem(Vector2(c.x + s * 0.02, top - s * 0.11 + sin(_t * 3.0) * s * 0.012), s * 0.24, GEM_BLUE, 0.0)
	# Kapak: yana yatmış, havada süzülür (sola kaçık: gemleri örtmesin)
	draw_set_transform(Vector2(c.x - s * 0.17, top - lift), -0.32 + 0.04 * sin(_t * 3.0), Vector2(0.8, 0.8))
	var lid: Rect2 = Rect2(-half - s * 0.04, -s * 0.11, (half + s * 0.04) * 2.0, s * 0.12)
	draw_rect(lid, GIFT.lightened(0.08))
	draw_rect(Rect2(lid.position.x, lid.position.y + lid.size.y - s * 0.03, lid.size.x, s * 0.03), GIFT_DARK)
	draw_rect(Rect2(-s * 0.05, lid.position.y, s * 0.1, lid.size.y), GOLD)
	# Fiyonk
	_ellipse(Vector2(-s * 0.1, lid.position.y - s * 0.05), s * 0.1, s * 0.06, GOLD)
	_ellipse(Vector2(s * 0.1, lid.position.y - s * 0.05), s * 0.1, s * 0.06, GOLD)
	_ellipse(Vector2(-s * 0.1, lid.position.y - s * 0.05), s * 0.05, s * 0.025, GOLD_DARK)
	_ellipse(Vector2(s * 0.1, lid.position.y - s * 0.05), s * 0.05, s * 0.025, GOLD_DARK)
	draw_circle(Vector2(0.0, lid.position.y - s * 0.04), s * 0.045, GOLD.lightened(0.15), true, -1.0, true)
	draw_set_transform(Vector2.ZERO)
	_twinkles(c, s, [Vector2(-0.36, -0.36), Vector2(0.36, -0.38), Vector2(-0.42, 0.06), Vector2(0.42, 0.04), Vector2(0.0, -0.47)])


## Düğmenin durağan kısmı; zıplayan gem ve parıltı _Piece alt öğeleri (_animate_button).
func _draw_button(c: Vector2, s: float) -> void:
	_glow(c, s * 0.5, Color.WHITE, 0.35)


## Düğme parçalarının boyu kutuya bağlı: yalnızca boyut değişince yeniden çizilirler.
func _layout_button() -> void:
	var s: float = minf(size.x, size.y)
	_button_gem.extent = s * 0.78
	_button_spark.extent = s * 0.22
	_button_gem.queue_redraw()
	_button_spark.queue_redraw()
	_animate_button()


## Eski çizimin hareketli kısmı, dönüşümle: gem sin(3t) ile zıplar; parıltı sin(2,6t) ile büyüyüp söner
## (yarıçap × a = ölçek a, beyaz × a = saydamlık a; yarıçap 0,75'in altında çizilmezdi).
func _animate_button() -> void:
	var s: float = minf(size.x, size.y)
	var c: Vector2 = size * 0.5
	_button_gem.position = c + Vector2(0.0, sin(_t * 3.0) * s * 0.03)
	var a: float = clampf(sin(_t * 2.6), 0.0, 1.0)
	_button_spark.visible = s * 0.22 * a >= 0.75
	_button_spark.position = c + Vector2(s * 0.28, -s * 0.22)
	_button_spark.scale = Vector2(a, a)
	_button_spark.modulate.a = a


# --- Yapı taşları -----------------------------------------------------------------------------

## Koyu, köşeleri yuvarlak vitrin zemini + üstten hafif aydınlık.
func _backdrop(color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = color.darkened(0.35)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	_glow(Vector2(size.x * 0.5, size.y * 0.42), minf(size.x, size.y) * 0.62, color.lightened(0.45), 0.55)

func _gem(p: Vector2, sz: float, base: Color, rot: float) -> void:
	draw_gem(self, p, sz, base, rot)


## Yüzeyli gem (yandan pırlanta): üstte tabla + taç yüzeyleri, altta köşk; ışık sol üstten. `ci` üzerine
## çizer (yalnızca onun çizim bildirimi içinde çağrılır) — GEM AL düğmesinin _Piece'i de kullanır.
static func draw_gem(ci: CanvasItem, p: Vector2, sz: float, base: Color, rot: float) -> void:
	var tr: Transform2D = Transform2D(rot, p)
	var pts: Array[Vector2] = [
		Vector2(-0.30, -0.34), Vector2(0.30, -0.34),   # 0,1 tabla
		Vector2(0.50, -0.08), Vector2(-0.50, -0.08),   # 2,3 kuşak
		Vector2(-0.14, -0.08), Vector2(0.14, -0.08),   # 4,5 iç kuşak
		Vector2(0.0, 0.50),                            # 6 uç
	]
	var w: Array[Vector2] = []
	for v: Vector2 in pts:
		w.append(tr * (v * sz))
	var light: Color = base.lightened(0.55)
	var mid: Color = base
	var dark: Color = base.darkened(0.3)
	var deep: Color = base.darkened(0.5)
	ci.draw_colored_polygon(PackedVector2Array([w[3], w[0], w[4]]), base.lightened(0.25))
	ci.draw_colored_polygon(PackedVector2Array([w[0], w[1], w[5], w[4]]), light)
	ci.draw_colored_polygon(PackedVector2Array([w[1], w[2], w[5]]), mid)
	ci.draw_colored_polygon(PackedVector2Array([w[3], w[4], w[6]]), mid)
	ci.draw_colored_polygon(PackedVector2Array([w[4], w[5], w[6]]), base.lightened(0.12))
	ci.draw_colored_polygon(PackedVector2Array([w[5], w[2], w[6]]), dark)
	var outline: PackedVector2Array = PackedVector2Array([w[0], w[1], w[2], w[6], w[3], w[0]])
	ci.draw_polyline(outline, deep, maxf(sz * 0.045, 1.0), true)
	ci.draw_line(w[3], w[2], Color(deep, 0.5), maxf(sz * 0.025, 1.0), true)
	# Tabla parıltısı
	ci.draw_colored_polygon(PackedVector2Array([
		tr * (Vector2(-0.22, -0.3) * sz), tr * (Vector2(-0.08, -0.3) * sz),
		tr * (Vector2(-0.16, -0.14) * sz), tr * (Vector2(-0.3, -0.14) * sz)]), Color(1.0, 1.0, 1.0, 0.75))


## Gem yığını: arkadan öne sıralar, ön sıra daha geniş (tepecik). Aynı tohum = her karede aynı yığın.
func _pile(base: Vector2, width: float, height: float, rows: int, gem: float, seed_value: int, colors: Array) -> void:
	_rng.seed = seed_value
	for row: int in rows:
		var f: float = float(row) / maxf(float(rows - 1), 1.0)   # 0 = arka (tepe), 1 = ön
		var row_w: float = width * (0.45 + 0.55 * f)
		var y: float = base.y - height * (1.0 - f)
		var count: int = maxi(int(row_w / (gem * 0.7)), 2)
		for i: int in count:
			var x: float = base.x - row_w * 0.5 + row_w * (float(i) + 0.5) / float(count)
			var jitter: Vector2 = Vector2(_rng.randf_range(-0.15, 0.15), _rng.randf_range(-0.2, 0.1)) * gem
			var col: Color = colors[_rng.randi() % colors.size()]
			_gem(Vector2(x, y) + jitter, gem * _rng.randf_range(0.85, 1.1), col, _rng.randf_range(-0.5, 0.5))


func _rays(c: Vector2, r: float, count: int, color: Color, rot: float) -> void:
	var half: float = PI / float(count) * 0.45
	for i: int in count:
		var a: float = rot + TAU * float(i) / float(count)
		draw_colored_polygon(PackedVector2Array([c,
			c + Vector2(cos(a - half), sin(a - half)) * r,
			c + Vector2(cos(a + half), sin(a + half)) * r]), color)


## Yumuşak ışık halkası: iç içe yarı saydam daireler.
func _glow(c: Vector2, r: float, color: Color, strength: float) -> void:
	for i: int in 6:
		var f: float = 1.0 - float(i) / 6.0
		draw_circle(c, r * f, Color(color, strength * 0.16), true, -1.0, true)


func _shadow(c: Vector2, r: float) -> void:
	_ellipse(c, r, r * 0.22, Color(0.0, 0.0, 0.0, 0.22))


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 28:
		var a: float = TAU * float(i) / 28.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)


func _sparkle(p: Vector2, r: float, alpha: float) -> void:
	draw_sparkle(self, p, r, alpha)


## Dört köşeli parıltı yıldızı (`ci` üzerine).
static func draw_sparkle(ci: CanvasItem, p: Vector2, r: float, alpha: float) -> void:
	# Sönerken yarıçap ~0'a iner: noktalar çakışır ve çokgen üçgenlenemez ("triangulation failed").
	if r < 0.75:
		return
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 - PI * 0.5
		var rr: float = r if i % 2 == 0 else r * 0.22
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, alpha))


## Göreli konumlarda (kutunun kısa kenarına oranla) sırayla yanıp sönen parıltılar.
func _twinkles(c: Vector2, s: float, spots: Array) -> void:
	for i: int in spots.size():
		var a: float = clampf(sin(_t * 2.4 + float(i) * 1.9), 0.0, 1.0)
		if a > 0.02:
			_sparkle(c + (spots[i] as Vector2) * s, s * 0.07 * a, a * 0.95)


## Dönen kırmızı yıldız rozet + yazı ("+%30").
func _draw_badge(p: Vector2, r: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var rot: float = _t * 0.6
	for i: int in 24:
		var a: float = rot + TAU * float(i) / 24.0
		pts.append(p + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.82))
	draw_colored_polygon(pts, BADGE.darkened(0.25))
	var pulse: float = 1.0 + 0.05 * sin(_t * 4.0)
	draw_circle(p, r * 0.8 * pulse, BADGE, true, -1.0, true)
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(r * 0.62), 8)
	var width: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var at: Vector2 = p + Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, maxi(int(font_size * 0.25), 2), BADGE.darkened(0.45))
	draw_string(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


## GEM AL düğmesinin hareketli parçası (gem ya da parıltı): bir kez çizilir, sonra yalnızca taşınır.
class _Piece:
	extends Node2D
	const GEM: int = 0
	const SPARK: int = 1
	var what: int
	## Çizim boyu: gemde genişlik (sz), parıltıda yarıçap (tam açık hâli; büyüklük ölçekle verilir).
	var extent: float = 0.0

	func _init(what_value: int) -> void:
		what = what_value

	func _draw() -> void:
		if extent <= 0.0:
			return
		if what == GEM:
			GemPackArt.draw_gem(self, Vector2.ZERO, extent, GemPackArt.GEM_BLUE, 0.0)
		else:
			GemPackArt.draw_sparkle(self, Vector2.ZERO, extent, 1.0)
