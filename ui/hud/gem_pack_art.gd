class_name GemPackArt
extends Control
## GEM PAKETİ ÇİZİMİ — MARKET kartlarının ve HUD'daki MARKET düğmesinin hareketli görseli. Tamamen
## koddan çizilir (doku yok): yüzeyli gemler, ışık hüzmesi, parıltı, gölge. Paket büyüdükçe sahne
## zenginleşir: avuç → kese → sandık → kasa dairesi; başlangıç paketi hediye kutusudur.
## PARAYA ÇEVİR kartları (CASH_1..4, GemExchange): gemden altın sikkeye — tek deste → iki → üç deste ve
## saçılmış sikkeler → ₺ amblemli para kesesi. ÜCRETSİZ ELMAS (FREE, ödüllü reklam): tek gem + oynat rozeti.
## ÜCRETSİZ sekmesinin takip kartları (INSTAGRAM, TIKTOK; CommunityLinks): uygulama simgesi + köşede gem rozeti.
## Ölçü kutunun kısa kenarına (s) göre: her boyutta aynı oranla çizilir.

enum Kind { STARTER, HANDFUL, POUCH, CHEST, VAULT, BUTTON, CASH_1, CASH_2, CASH_3, CASH_4, FREE, INSTAGRAM, TIKTOK }

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
	Kind.CASH_1: Color("1F5A3A"),
	Kind.CASH_2: Color("21634A"),
	Kind.CASH_3: Color("2A5A2A"),
	Kind.CASH_4: Color("173A28"),
	Kind.FREE: Color("4A2A6E"),
	Kind.INSTAGRAM: Color("5A2350"),
	Kind.TIKTOK: Color("262838"),
}
## Instagram simgesinin sol alttan (sarı) sağ üste (mor) radyal renk geçişi.
const INSTAGRAM_COLORS: PackedColorArray = [Color("FEDA75"), Color("FA7E1E"), Color("D62976"), Color("962FBF"),
	Color("4F5BD5")]
const TIKTOK_CYAN: Color = Color("25F4EE")
const TIKTOK_RED: Color = Color("FE2C55")
## Mağaza kartları saniyede en çok bu kadar yeniden çizilir: hareketler yavaş (1,8–3 rad/sn), 20 Hz akıcı; kart
## çizimi ağır (yığın, ışın, gem) ve mağaza açıkken beş kart her karede baştan çiziliyordu (masaüstü ~3,8 ms/kare).
## 2026-10-24: 30 → 20 (hareketler yavaş; telefonda kart başına çizim betik süresi belirgindi).
const CARD_REDRAW_HZ: float = 20.0
## TOPLU ÇİZİM (2026-10-24, kullanıcı: "market ekranı FPS düşürüyor"): her çokgen / çember / çizgi ayrı bir çizim çağrısıydı;
## MARKET'in GEM AL sekmesi açılınca çizim çağrısı 385 → 1262 (qa/market_perf.gd), telefonda (GL Compatibility) darboğaz tam
## buydu. Artık kartın bütün şekilleri tek üçgen dizisinde toplanır ve kart başına tek komutla gönderilir (yazılar ve dokulu
## Instagram simgesi araya girer). Kenar yumuşatma çember / çizgilerde eskisi gibi: dışa FEATHER kadar saydamlaşan şerit.
const FEATHER: float = 1.0

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
## Instagram simgesinin renk geçişi (ilk çizimde kurulur).
var _ig_texture: GradientTexture2D
## Toplu çizim tamponu (bkz. FEATHER) ve şekillere uygulanan dönüşüm (eski draw_set_transform yerine).
var _pts: PackedVector2Array = PackedVector2Array()
var _cols: PackedColorArray = PackedColorArray()
var _idx: PackedInt32Array = PackedInt32Array()
var _xf: Transform2D = Transform2D.IDENTITY
## Birim çember yönleri (parça sayısı → PackedVector2Array): her köşede sin / cos hesaplanmasın.
static var _units: Dictionary = {}


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
		Kind.CASH_1, Kind.CASH_2, Kind.CASH_3:
			_draw_cash(c, s)
		Kind.CASH_4:
			_draw_cash_bag(c, s)
		Kind.FREE:
			_draw_free(c, s)
		Kind.INSTAGRAM:
			_draw_instagram(c, s)
		Kind.TIKTOK:
			_draw_tiktok(c, s)
	if not badge_text.is_empty():
		_draw_badge(Vector2(size.x - s * 0.2, s * 0.19), s * 0.17)
	_flush()


# --- Sahneler -------------------------------------------------------------------------------

## ÜCRETSİZ ELMAS: tek büyük gem, altında oynat rozeti (reklam izleyerek kazanılır).
func _draw_free(c: Vector2, s: float) -> void:
	_glow(c, s * 0.4, GEM_VIOLET, 0.35)
	_shadow(c + Vector2(0.0, s * 0.3), s * 0.3)
	var bob: float = sin(_t * 2.0) * s * 0.02
	_gem(c + Vector2(0.0, -s * 0.06 + bob), s * 0.5, GEM_CYAN, 0.0)
	var badge: Vector2 = c + Vector2(s * 0.27, s * 0.22)
	_disc(badge, s * 0.14, Color.WHITE)
	_disc(badge, s * 0.115, GIFT)
	var r: float = s * 0.055
	_poly(PackedVector2Array([badge + Vector2(-r * 0.7, -r), badge + Vector2(r * 1.1, 0.0),
		badge + Vector2(-r * 0.7, r)]), Color.WHITE)
	_twinkles(c, s, [Vector2(-0.3, -0.24), Vector2(0.3, -0.22), Vector2(-0.22, 0.24)])

## INSTAGRAM: renk geçişli yuvarlak kare üstünde beyaz kamera çizgisi (oda + mercek + flaş noktası).
func _draw_instagram(c: Vector2, s: float) -> void:
	_glow(c, s * 0.42, Color("F58529"), 0.3)
	_shadow(c + Vector2(0.0, s * 0.32), s * 0.3)
	var p: Vector2 = c + Vector2(0.0, -s * 0.04 + sin(_t * 2.0) * s * 0.02)
	var half: float = s * 0.28
	var tile: PackedVector2Array = _rounded_square(p, half, half * 0.56)
	var uvs: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in tile:
		uvs.append((v - p) / (half * 2.0) + Vector2(0.5, 0.5))
	_flush()   # dokulu çokgen toplu diziye girmez: önceki şekiller önce gitsin (sıra korunur)
	draw_polygon(tile, PackedColorArray([Color.WHITE]), uvs, _instagram_gradient())
	var w: float = half * 0.15
	var room: PackedVector2Array = _rounded_square(p, half * 0.62, half * 0.62 * 0.6)
	room.append(room[0])
	_polyline(room, Color.WHITE, w)
	_arc(p, half * 0.29, 0.0, TAU, 40, Color.WHITE, w)
	_disc(p + Vector2(half * 0.33, -half * 0.33), w * 0.62, Color.WHITE)
	_reward_gem(c, s)


## TIKTOK: siyah yuvarlak kare üstünde nota; camgöbeği ve kırmızı kopyası iki yana kaymış (logodaki titreşim).
func _draw_tiktok(c: Vector2, s: float) -> void:
	_glow(c, s * 0.42, TIKTOK_CYAN, 0.22)
	_shadow(c + Vector2(0.0, s * 0.32), s * 0.3)
	var p: Vector2 = c + Vector2(0.0, -s * 0.04 + sin(_t * 2.0) * s * 0.02)
	var half: float = s * 0.28
	_poly(_rounded_square(p, half, half * 0.56), Color("010101"))
	var h: float = half * 1.2   # nota boyu
	var o: float = h * 0.035
	_note(p + Vector2(-o, -o), h, TIKTOK_CYAN)
	_note(p + Vector2(o, o), h, TIKTOK_RED)
	_note(p, h, Color.WHITE)
	_reward_gem(c, s)


## Nota: halka baş + gövde + üstten sağa kıvrılan bayrak. `p` simgenin ortası, `h` nota boyu.
func _note(p: Vector2, h: float, color: Color) -> void:
	var w: float = h * 0.13
	var stem_x: float = p.x + h * 0.08
	var head: Vector2 = Vector2(stem_x - h * 0.17, p.y + h * 0.26)
	_arc(head, h * 0.17, 0.0, TAU, 36, color, w)
	_line(Vector2(stem_x, head.y), Vector2(stem_x, p.y - h * 0.46), color, w)
	_arc(Vector2(stem_x, p.y - h * 0.46 + h * 0.26), h * 0.26, -PI * 0.5, 0.0, 16, color, w)


## Takip kartlarının sağ alt köşesindeki gem rozeti (ödül gemle).
func _reward_gem(c: Vector2, s: float) -> void:
	var badge: Vector2 = c + Vector2(s * 0.29, s * 0.2)
	_disc(badge, s * 0.15, Color.WHITE)
	_gem(badge + Vector2(0.0, s * 0.01), s * 0.19, GEM_BLUE, 0.0)
	_twinkles(c, s, [Vector2(-0.34, -0.26), Vector2(0.34, -0.24), Vector2(-0.3, 0.26)])


## Yuvarlak köşeli kare çevresi (saat yönünde). `half` yarım kenar, `radius` köşe yarıçapı.
func _rounded_square(p: Vector2, half: float, radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var inner: float = half - radius
	var corners: Array[Vector2] = [Vector2(inner, inner), Vector2(-inner, inner), Vector2(-inner, -inner),
		Vector2(inner, -inner)]
	for i: int in corners.size():
		for k: int in 7:
			var a: float = PI * 0.5 * (float(i) + float(k) / 6.0)
			pts.append(p + corners[i] + Vector2(cos(a), sin(a)) * radius)
	return pts


func _instagram_gradient() -> GradientTexture2D:
	if _ig_texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		gradient.colors = INSTAGRAM_COLORS
		_ig_texture = GradientTexture2D.new()
		_ig_texture.gradient = gradient
		_ig_texture.fill = GradientTexture2D.FILL_RADIAL
		_ig_texture.fill_from = Vector2(0.2, 1.05)
		_ig_texture.fill_to = Vector2(1.15, -0.05)
		_ig_texture.width = 64
		_ig_texture.height = 64
	return _ig_texture

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
	_poly(neck, LEATHER)
	_line(body + Vector2(-s * 0.15, -s * 0.2), body + Vector2(s * 0.15, -s * 0.2), GOLD, s * 0.045)
	_line(body + Vector2(s * 0.1, -s * 0.2), body + Vector2(s * 0.16, -s * 0.06), GOLD_DARK, s * 0.025)
	_disc(body + Vector2(s * 0.16, -s * 0.06), s * 0.025, GOLD)
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
	_poly(lid, WOOD_DARK)
	_poly(PackedVector2Array([
		Vector2(left + s * 0.05, top - s * 0.02), Vector2(left + s * 0.09, top - s * 0.26),
		Vector2(right - s * 0.09, top - s * 0.26), Vector2(right - s * 0.05, top - s * 0.02)]), WOOD_DARK.darkened(0.35))
	_polyline(PackedVector2Array([lid[0], lid[1], lid[2], lid[3]]), GOLD_DARK, s * 0.025)
	# Gem yığını (kapağın önünde, gövdenin arkasında)
	_pile(Vector2(c.x, top + s * 0.02), s * 0.7, s * 0.2, 3, s * 0.13, 11, [GEM_BLUE, GEM_CYAN, GEM_DEEP, GEM_VIOLET])
	var bob: float = sin(_t * 2.0) * s * 0.012
	_gem(Vector2(c.x, top - s * 0.17 + bob), s * 0.24, GEM_PINK, 0.0)
	# Gövde: tahtalar, altın kuşaklar, kilit
	_rect(Rect2(left, top, right - left, bottom - top), WOOD)
	for i: int in 3:
		var y: float = top + (bottom - top) * (float(i) + 1.0) / 4.0
		_line(Vector2(left, y), Vector2(right, y), WOOD_DARK, maxf(s * 0.012, 1.0))
	_rect(Rect2(left, top, right - left, s * 0.045), WOOD.lightened(0.2))
	for x: float in [left + s * 0.1, right - s * 0.16]:
		_rect(Rect2(x, top, s * 0.06, bottom - top), GOLD)
		_rect(Rect2(x + s * 0.045, top, s * 0.015, bottom - top), GOLD_DARK)
	_rect(Rect2(c.x - s * 0.06, top + s * 0.04, s * 0.12, s * 0.13), GOLD)
	_disc(Vector2(c.x, top + s * 0.09), s * 0.022, WOOD_DARK.darkened(0.4))
	_rect(Rect2(c.x - s * 0.008, top + s * 0.09, s * 0.016, s * 0.045), WOOD_DARK.darkened(0.4))
	_rect_outline(Rect2(left, top, right - left, bottom - top), WOOD_DARK, maxf(s * 0.015, 1.0))
	_twinkles(c, s, [Vector2(-0.34, -0.36), Vector2(0.36, -0.3), Vector2(-0.1, -0.44), Vector2(0.2, -0.42), Vector2(0.42, 0.05)])


func _draw_vault(c: Vector2, s: float) -> void:
	_rays(c + Vector2(0.0, -s * 0.05), s * 0.75, 14, Color(GEM_CYAN, 0.25), -_t * 0.3)
	_rays(c + Vector2(0.0, -s * 0.05), s * 0.6, 7, Color(GOLD, 0.2), _t * 0.2)
	_glow(c + Vector2(0.0, -s * 0.05), s * 0.45, GEM_CYAN, 0.4)
	_shadow(c + Vector2(0.0, s * 0.38), s * 0.46)
	# Çelik kasa: içi rafta gemler, kapı sola açık
	var box: Rect2 = Rect2(c.x - s * 0.24, c.y - s * 0.38, s * 0.5, s * 0.56)
	_rect(box, STEEL)
	_rect(box.grow(-s * 0.04), STEEL_DARK.darkened(0.45))
	for row: int in 2:
		var shelf_y: float = box.position.y + s * (0.2 + 0.17 * float(row))
		for i: int in 4:
			var colors: Array[Color] = [GEM_BLUE, GEM_VIOLET, GEM_CYAN, GEM_PINK]
			_gem(Vector2(box.position.x + s * (0.1 + 0.1 * float(i)), shelf_y - s * 0.05), s * 0.1, colors[(i + row) % 4], 0.0)
		_rect(Rect2(box.position.x + s * 0.04, shelf_y, box.size.x - s * 0.08, s * 0.02), STEEL)
	_rect_outline(box, STEEL_DARK, maxf(s * 0.015, 1.0))
	var door: PackedVector2Array = PackedVector2Array([
		box.position, box.position + Vector2(-s * 0.2, s * 0.06),
		box.position + Vector2(-s * 0.2, box.size.y - s * 0.06), box.position + Vector2(0.0, box.size.y)])
	_poly(door, STEEL.darkened(0.08))
	_polyline(PackedVector2Array([door[0], door[1], door[2], door[3]]), STEEL_DARK, maxf(s * 0.015, 1.0))
	var dial: Vector2 = box.position + Vector2(-s * 0.1, box.size.y * 0.5)
	_disc(dial, s * 0.06, STEEL_DARK)
	_disc(dial, s * 0.045, STEEL.lightened(0.3))
	for i: int in 3:
		var a: float = _t * 0.8 + TAU * float(i) / 3.0
		_line(dial, dial + Vector2(cos(a), sin(a)) * s * 0.05, STEEL_DARK, maxf(s * 0.012, 1.0))
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
	_rect(Rect2(c.x - half, top, half * 2.0, bottom - top), GIFT)
	_rect(Rect2(c.x + half * 0.45, top, half * 0.55, bottom - top), GIFT_DARK)
	_rect(Rect2(c.x - s * 0.045, top, s * 0.09, bottom - top), GOLD)
	_rect(Rect2(c.x + s * 0.025, top, s * 0.02, bottom - top), GOLD_DARK)
	# Kutunun ağzı: içi koyu, gemler ağızdan fışkırır
	_rect(Rect2(c.x - half, top - s * 0.02, half * 2.0, s * 0.04), GIFT_DARK.darkened(0.4))
	var lift: float = s * (0.18 + 0.02 * sin(_t * 3.0))
	_glow(Vector2(c.x, top - s * 0.06), s * 0.24, GOLD, 0.7)
	_gem(Vector2(c.x - s * 0.15, top - s * 0.06), s * 0.17, GEM_CYAN, -0.45)
	_gem(Vector2(c.x + s * 0.16, top - s * 0.05), s * 0.16, GEM_VIOLET, 0.45)
	_gem(Vector2(c.x + s * 0.02, top - s * 0.11 + sin(_t * 3.0) * s * 0.012), s * 0.24, GEM_BLUE, 0.0)
	# Kapak: yana yatmış, havada süzülür (sola kaçık: gemleri örtmesin)
	_xf = Transform2D(-0.32 + 0.04 * sin(_t * 3.0), Vector2(0.8, 0.8), 0.0, Vector2(c.x - s * 0.17, top - lift))
	var lid: Rect2 = Rect2(-half - s * 0.04, -s * 0.11, (half + s * 0.04) * 2.0, s * 0.12)
	_rect(lid, GIFT.lightened(0.08))
	_rect(Rect2(lid.position.x, lid.position.y + lid.size.y - s * 0.03, lid.size.x, s * 0.03), GIFT_DARK)
	_rect(Rect2(-s * 0.05, lid.position.y, s * 0.1, lid.size.y), GOLD)
	# Fiyonk
	_ellipse(Vector2(-s * 0.1, lid.position.y - s * 0.05), s * 0.1, s * 0.06, GOLD)
	_ellipse(Vector2(s * 0.1, lid.position.y - s * 0.05), s * 0.1, s * 0.06, GOLD)
	_ellipse(Vector2(-s * 0.1, lid.position.y - s * 0.05), s * 0.05, s * 0.025, GOLD_DARK)
	_ellipse(Vector2(s * 0.1, lid.position.y - s * 0.05), s * 0.05, s * 0.025, GOLD_DARK)
	_disc(Vector2(0.0, lid.position.y - s * 0.04), s * 0.045, GOLD.lightened(0.15))
	_xf = Transform2D.IDENTITY
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
## PARAYA ÇEVİR: küçük teklifte tek deste, büyüdükçe deste ve saçılmış sikke artar; sol üstte "çevrilen" gem.
func _draw_cash(c: Vector2, s: float) -> void:
	var step: int = kind - Kind.CASH_1   # 0, 1, 2
	if step >= 2:
		_rays(c + Vector2(0.0, -s * 0.05), s * 0.6, 10, Color(GOLD, 0.2), _t * 0.25)
	_glow(c + Vector2(0.0, s * 0.02), s * 0.4, GOLD, 0.3 + 0.08 * step)
	_shadow(c + Vector2(0.0, s * 0.36), s * (0.26 + 0.07 * step))
	var r: float = s * 0.15
	var base: Vector2 = c + Vector2(0.0, s * 0.33)
	match step:
		0:
			_coin_stack(base + Vector2(s * 0.06, 0.0), r, 5)
		1:
			_coin_stack(base + Vector2(-s * 0.1, 0.0), r, 4)
			_coin_stack(base + Vector2(s * 0.17, s * 0.02), r, 7)
		_:
			_coin_stack(base + Vector2(-s * 0.26, -s * 0.02), r * 0.9, 4)
			_coin_stack(base + Vector2(s * 0.27, 0.0), r * 0.9, 5)
			_coin_stack(base + Vector2(0.0, s * 0.03), r, 8)
			_coin_flat(c + Vector2(-s * 0.12, s * 0.36), r * 0.8)
			_coin_flat(c + Vector2(s * 0.14, s * 0.38), r * 0.75)
	var bob: float = sin(_t * 2.2) * s * 0.015
	_gem(c + Vector2(-s * 0.26, -s * 0.24 + bob), s * (0.2 + 0.02 * step), GEM_BLUE, -0.25)
	_twinkles(c, s, [Vector2(0.3, -0.3), Vector2(-0.05, -0.36), Vector2(0.36, 0.05)])


## En büyük çeviri: ağzından sikke taşan, ₺ amblemli para kesesi; arkada dönen hüzme.
func _draw_cash_bag(c: Vector2, s: float) -> void:
	_rays(c + Vector2(0.0, -s * 0.06), s * 0.62, 12, Color(GOLD, 0.24), _t * 0.25)
	_glow(c + Vector2(0.0, -s * 0.02), s * 0.42, GOLD, 0.42)
	_shadow(c + Vector2(0.0, s * 0.37), s * 0.42)
	var body: Vector2 = c + Vector2(0.0, s * 0.12)
	_ellipse(body + Vector2(0.0, s * 0.02), s * 0.31, s * 0.25, LEATHER_DARK)
	_ellipse(body, s * 0.29, s * 0.23, LEATHER)
	_ellipse(body + Vector2(-s * 0.13, -s * 0.08), s * 0.06, s * 0.09, LEATHER.lightened(0.25))
	var neck: PackedVector2Array = PackedVector2Array([
		body + Vector2(-s * 0.13, -s * 0.18), body + Vector2(s * 0.13, -s * 0.18),
		body + Vector2(s * 0.2, -s * 0.3), body + Vector2(-s * 0.2, -s * 0.3)])
	_poly(neck, LEATHER)
	_line(body + Vector2(-s * 0.15, -s * 0.2), body + Vector2(s * 0.15, -s * 0.2), GOLD, s * 0.045)
	# ₺ amblemi
	_coin_face(body + Vector2(0.0, s * 0.03), s * 0.12)
	var mouth: Vector2 = body + Vector2(0.0, -s * 0.3)
	_ellipse(mouth, s * 0.2, s * 0.06, LEATHER_DARK.darkened(0.3))
	var bob: float = sin(_t * 2.0) * s * 0.012
	_coin_flat(mouth + Vector2(-s * 0.09, -s * 0.03), s * 0.08)
	_coin_flat(mouth + Vector2(s * 0.1, -s * 0.02), s * 0.08)
	_coin_flat(mouth + Vector2(0.0, -s * 0.08 + bob), s * 0.09)
	# yanına dökülmüş deste ve sikke
	_coin_stack(c + Vector2(s * 0.37, s * 0.36), s * 0.1, 4)
	_coin_flat(c + Vector2(-s * 0.36, s * 0.34), s * 0.09)
	_gem(c + Vector2(-s * 0.3, -s * 0.28 + bob), s * 0.2, GEM_BLUE, -0.25)
	_twinkles(c, s, [Vector2(-0.32, -0.3), Vector2(0.3, -0.34), Vector2(-0.38, 0.12), Vector2(0.12, -0.42)])


## Üst üste altın sikkeler: her sikke koyu kenar bandı + açık yüz; en üsttekinin yüzünde ₺.
func _coin_stack(base: Vector2, r: float, count: int) -> void:
	var h: float = r * 0.26
	var ry: float = r * 0.42
	for i: int in count:
		var bottom: Vector2 = base - Vector2(0.0, h * float(i))
		_ellipse(bottom, r, ry, GOLD_DARK)
		_rect(Rect2(bottom.x - r, bottom.y - h, r * 2.0, h), GOLD_DARK)
		_ellipse(bottom - Vector2(0.0, h), r, ry, GOLD if i % 2 == 0 else GOLD.darkened(0.06))
	var top: Vector2 = base - Vector2(0.0, h * float(count))
	_ellipse(top, r * 0.74, ry * 0.74, GOLD.lightened(0.16))
	_lira(top, r * 0.8, ry / r)


## Yere yatmış tek sikke.
func _coin_flat(p: Vector2, r: float) -> void:
	var ry: float = r * 0.42
	_ellipse(p + Vector2(0.0, r * 0.12), r, ry, GOLD_DARK)
	_ellipse(p, r, ry, GOLD)
	_ellipse(p, r * 0.74, ry * 0.74, GOLD.lightened(0.16))


## Dik duran sikke yüzü (kesedeki amblem): halka, iç daire, ₺.
func _coin_face(p: Vector2, r: float) -> void:
	_disc(p, r, GOLD_DARK)
	_disc(p, r * 0.86, GOLD)
	_disc(p, r * 0.66, GOLD.lightened(0.16))
	_lira(p, r * 1.1, 1.0)


## "₺" işareti, `squash` dikey basıklık (yatık sikke yüzünde < 1).
func _lira(p: Vector2, size_px: float, squash: float) -> void:
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(size_px), 8)
	var w: float = font.get_string_size("₺", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	_flush()   # yazı toplu diziye girmez: önceki şekiller önce gitsin
	draw_set_transform(p, 0.0, Vector2(1.0, squash))
	draw_string(font, Vector2(-w * 0.5, font_size * 0.35), "₺", HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, GOLD_DARK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _backdrop(color: Color) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(10)
	sb.border_color = color.darkened(0.35)
	sb.set_border_width_all(2)
	sb.anti_aliasing = true
	_flush()
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	_glow(Vector2(size.x * 0.5, size.y * 0.42), minf(size.x, size.y) * 0.62, color.lightened(0.45), 0.55)

func _gem(p: Vector2, sz: float, base: Color, rot: float) -> void:
	var parts: Dictionary = gem_parts(p, sz, base, rot)
	for face: Array in parts["faces"]:
		_poly(face[0], face[1])
	_polyline(parts["outline"], parts["outline_color"], parts["outline_width"])
	_line(parts["girdle"][0], parts["girdle"][1], parts["girdle_color"], parts["girdle_width"])
	_poly(parts["shine"], Color(1.0, 1.0, 1.0, 0.75))


## Yüzeyli gem (yandan pırlanta): üstte tabla + taç yüzeyleri, altta köşk; ışık sol üstten. `ci` üzerine
## çizer (yalnızca onun çizim bildirimi içinde çağrılır) — GEM AL düğmesinin _Piece'i de kullanır.
static func draw_gem(ci: CanvasItem, p: Vector2, sz: float, base: Color, rot: float) -> void:
	var parts: Dictionary = gem_parts(p, sz, base, rot)
	for face: Array in parts["faces"]:
		ci.draw_colored_polygon(face[0], face[1])
	ci.draw_polyline(parts["outline"], parts["outline_color"], parts["outline_width"], true)
	ci.draw_line(parts["girdle"][0], parts["girdle"][1], parts["girdle_color"], parts["girdle_width"], true)
	ci.draw_colored_polygon(parts["shine"], Color(1.0, 1.0, 1.0, 0.75))


## Gemin yüzeyleri, dış çizgisi, kuşak çizgisi ve tabla parıltısı (kart: toplu çizim, GEM AL düğmesi: doğrudan).
static func gem_parts(p: Vector2, sz: float, base: Color, rot: float) -> Dictionary:
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
	return {
		"faces": [
			[PackedVector2Array([w[3], w[0], w[4]]), base.lightened(0.25)],
			[PackedVector2Array([w[0], w[1], w[5], w[4]]), light],
			[PackedVector2Array([w[1], w[2], w[5]]), mid],
			[PackedVector2Array([w[3], w[4], w[6]]), mid],
			[PackedVector2Array([w[4], w[5], w[6]]), base.lightened(0.12)],
			[PackedVector2Array([w[5], w[2], w[6]]), dark],
		],
		"outline": PackedVector2Array([w[0], w[1], w[2], w[6], w[3], w[0]]),
		"outline_color": deep,
		"outline_width": maxf(sz * 0.045, 1.0),
		"girdle": [w[3], w[2]],
		"girdle_color": Color(deep, 0.5),
		"girdle_width": maxf(sz * 0.025, 1.0),
		# Tabla parıltısı
		"shine": PackedVector2Array([
			tr * (Vector2(-0.22, -0.3) * sz), tr * (Vector2(-0.08, -0.3) * sz),
			tr * (Vector2(-0.16, -0.14) * sz), tr * (Vector2(-0.3, -0.14) * sz)]),
	}


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
		_poly(PackedVector2Array([c,
			c + Vector2(cos(a - half), sin(a - half)) * r,
			c + Vector2(cos(a + half), sin(a + half)) * r]), color)


## Yumuşak ışık halkası. Eskiden iç içe 6 yarı saydam daireydi (her biri ayrı çizim + 6 kat örtüşen doldurma); şimdi
## tek katman: merkez + üç halka, aynı birikimli saydamlık (n daire üst üste = 1 − (1 − a)^n; 1/3 R'yi 4, 2/3 R'yi 2
## daire örter, kenarda 0) köşe renkleriyle.
func _glow(c: Vector2, r: float, color: Color, strength: float) -> void:
	var a: float = strength * 0.16
	var n: int = clampi(int(r * 0.35), 12, 24)
	var unit: PackedVector2Array = _unit(n)
	var base: int = _pts.size()
	_pts.append(_xf * c)
	_cols.append(Color(color, 1.0 - pow(1.0 - a, 6.0)))
	for k: int in 3:
		var f: float = float(k + 1) / 3.0
		var col: Color = Color(color, 1.0 - pow(1.0 - a, 6.0 - 6.0 * f))
		for u: Vector2 in unit:
			_pts.append(_xf * (c + u * (r * f)))
			_cols.append(col)
	for i: int in n:
		var j: int = (i + 1) % n
		_idx.append(base)
		_idx.append(base + 1 + i)
		_idx.append(base + 1 + j)
	for k: int in 2:
		var inner: int = base + 1 + k * n
		var outer: int = inner + n
		for i: int in n:
			var j: int = (i + 1) % n
			_idx.append(inner + i)
			_idx.append(outer + i)
			_idx.append(outer + j)
			_idx.append(inner + i)
			_idx.append(outer + j)
			_idx.append(inner + j)


func _shadow(c: Vector2, r: float) -> void:
	_ellipse(c, r, r * 0.22, Color(0.0, 0.0, 0.0, 0.22))


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var n: int = clampi(int(maxf(rx, ry) * 0.5), 12, 28)   # eskiden hep 28; küçük sikkede fark görünmez
	var base: int = _pts.size()
	for u: Vector2 in _unit(n):
		_pts.append(_xf * (c + Vector2(u.x * rx, u.y * ry)))
		_cols.append(color)
	for i: int in range(1, n - 1):
		_idx.append(base)
		_idx.append(base + i)
		_idx.append(base + i + 1)


func _sparkle(p: Vector2, r: float, alpha: float) -> void:
	if r < 0.75:
		return
	_star(p, sparkle_points(p, r), Color(1.0, 1.0, 1.0, alpha))


## Dört köşeli parıltı yıldızı (`ci` üzerine).
static func draw_sparkle(ci: CanvasItem, p: Vector2, r: float, alpha: float) -> void:
	# Sönerken yarıçap ~0'a iner: noktalar çakışır ve çokgen üçgenlenemez ("triangulation failed").
	if r < 0.75:
		return
	ci.draw_colored_polygon(sparkle_points(p, r), Color(1.0, 1.0, 1.0, alpha))


static func sparkle_points(p: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i: int in 8:
		var a: float = TAU * float(i) / 8.0 - PI * 0.5
		var rr: float = r if i % 2 == 0 else r * 0.22
		pts.append(p + Vector2(cos(a), sin(a)) * rr)
	return pts


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
	_star(p, pts, BADGE.darkened(0.25))
	var pulse: float = 1.0 + 0.05 * sin(_t * 4.0)
	_disc(p, r * 0.8 * pulse, BADGE)
	_flush()   # yazı toplu diziye girmez
	var font: Font = get_theme_default_font()
	var font_size: int = maxi(int(r * 0.62), 8)
	var width: float = font.get_string_size(badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var at: Vector2 = p + Vector2(-width * 0.5, font_size * 0.35)
	draw_string_outline(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, maxi(int(font_size * 0.25), 2), BADGE.darkened(0.45))
	draw_string(font, at, badge_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)


# --- Toplu çizim (bkz. FEATHER) ---------------------------------------------------------------

## Biriken üçgenleri tek çizim komutu olarak gönderir.
func _flush() -> void:
	if not _idx.is_empty():
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), _idx, _pts, _cols)
	_pts.clear()
	_cols.clear()
	_idx.clear()


static func _unit(n: int) -> PackedVector2Array:
	if not _units.has(n):
		var dirs: PackedVector2Array = PackedVector2Array()
		for i: int in n:
			var a: float = TAU * float(i) / float(n)
			dirs.append(Vector2(cos(a), sin(a)))
		_units[n] = dirs
	return _units[n]


func _add(p: Vector2, color: Color) -> void:
	_pts.append(_xf * p)
	_cols.append(color)


func _tri(a: int, b: int, c: int) -> void:
	_idx.append(a)
	_idx.append(b)
	_idx.append(c)


## Dışbükey çokgen (ilk köşeden yelpaze); eski draw_colored_polygon gibi kenar yumuşatması yok.
func _poly(points: PackedVector2Array, color: Color) -> void:
	var base: int = _pts.size()
	for v: Vector2 in points:
		_pts.append(_xf * v)
		_cols.append(color)
	for i: int in range(1, points.size() - 1):
		_idx.append(base)
		_idx.append(base + i)
		_idx.append(base + i + 1)


## Merkeze göre yıldız biçimli (içbükey olabilir) çokgen: merkezden yelpaze.
func _star(center: Vector2, points: PackedVector2Array, color: Color) -> void:
	var base: int = _pts.size()
	_add(center, color)
	for v: Vector2 in points:
		_add(v, color)
	var n: int = points.size()
	for i: int in n:
		_tri(base, base + 1 + i, base + 1 + (i + 1) % n)


## Dolu daire + dışında FEATHER kadar saydamlaşan şerit (eski draw_circle antialiased).
func _disc(c: Vector2, r: float, color: Color) -> void:
	var n: int = clampi(int(r * 0.7), 12, 32)
	var base: int = _pts.size()
	var clear: Color = Color(color, 0.0)
	_pts.append(_xf * c)
	_cols.append(color)
	for u: Vector2 in _unit(n):
		_pts.append(_xf * (c + u * r))
		_cols.append(color)
		_pts.append(_xf * (c + u * (r + FEATHER)))
		_cols.append(clear)
	for i: int in n:
		var j: int = (i + 1) % n
		var a: int = base + 1 + i * 2
		var b: int = base + 1 + j * 2
		_idx.append(base)
		_idx.append(a)
		_idx.append(b)
		_idx.append(a)
		_idx.append(a + 1)
		_idx.append(b + 1)
		_idx.append(a)
		_idx.append(b + 1)
		_idx.append(b)


## Kalın çizgi parçası + iki yanda yumuşak kenar (eski draw_line antialiased).
func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	var d: Vector2 = b - a
	if d.length_squared() < 1e-8:
		return
	var n: Vector2 = Vector2(-d.y, d.x).normalized()
	var h: float = width * 0.5
	var clear: Color = Color(color, 0.0)
	var base: int = _pts.size()
	var o: Vector2 = n * (h + FEATHER)
	var m: Vector2 = n * h
	_pts.append_array(PackedVector2Array([_xf * (a + o), _xf * (b + o), _xf * (a + m), _xf * (b + m), _xf * (a - m),
		_xf * (b - m), _xf * (a - o), _xf * (b - o)]))
	_cols.append_array(PackedColorArray([clear, clear, color, color, color, color, clear, clear]))
	_idx.append_array(PackedInt32Array([base, base + 1, base + 3, base, base + 3, base + 2,
		base + 2, base + 3, base + 5, base + 2, base + 5, base + 4,
		base + 4, base + 5, base + 7, base + 4, base + 7, base + 6]))


## Kırık çizgi: her parça iki ucundan yarım kalınlık uzar (köşede çentik kalmasın; köşeye daire koymak gem başına
## ~100 köşe noktası ekliyordu — kasa kartında 40 gem).
func _polyline(points: PackedVector2Array, color: Color, width: float) -> void:
	var h: float = width * 0.5
	for i: int in points.size() - 1:
		var d: Vector2 = (points[i + 1] - points[i]).normalized() * h
		_line(points[i] - d, points[i + 1] + d, color, width)


## Yay (halka parçası) + iki kenarda yumuşak şerit (eski draw_arc antialiased).
func _arc(c: Vector2, r: float, from: float, to: float, segments: int, color: Color, width: float) -> void:
	var h: float = width * 0.5
	var radii: PackedFloat32Array = PackedFloat32Array([r - h - FEATHER, r - h, r + h, r + h + FEATHER])
	var clear: Color = Color(color, 0.0)
	var base: int = _pts.size()
	for i: int in segments + 1:
		var ang: float = lerpf(from, to, float(i) / float(segments))
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		for k: int in 4:
			_add(c + dir * maxf(radii[k], 0.0), color if k == 1 or k == 2 else clear)
	for i: int in segments:
		var a: int = base + i * 4
		var b: int = a + 4
		for k: int in 3:
			_tri(a + k, b + k, b + k + 1)
			_tri(a + k, b + k + 1, a + k + 1)


func _rect(rect: Rect2, color: Color) -> void:
	_poly(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)]), color)


## Dikdörtgen çerçeve (eski draw_rect(..., false, width): kenar çizgisi dikdörtgenin sınırında ortalanır).
func _rect_outline(rect: Rect2, color: Color, width: float) -> void:
	var h: float = width * 0.5
	var outer: Rect2 = rect.grow(h)
	_rect(Rect2(outer.position, Vector2(outer.size.x, width)), color)
	_rect(Rect2(Vector2(outer.position.x, outer.end.y - width), Vector2(outer.size.x, width)), color)
	_rect(Rect2(Vector2(outer.position.x, outer.position.y + width), Vector2(width, outer.size.y - width * 2.0)), color)
	_rect(Rect2(Vector2(outer.end.x - width, outer.position.y + width), Vector2(width, outer.size.y - width * 2.0)), color)


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
