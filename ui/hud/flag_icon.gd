class_name FlagIcon
extends Control
## KÜÇÜK PİKSEL BAYRAK (kullanıcı isteği 2026-10-16: "pixel pixel çiz, daha sempatik olsun, yer kaplamasın").
## Her bayrak 16x11 piksellik ızgarada KODLA boyanır (resim dosyası yok), etrafına 1 px mürekkep kenar ve
## kesik köşe, üst sırasına açık / alt sırasına koyu ton (minik kabartma) eklenir; ekrana en yakın komşu
## büyütmesiyle çizilir. Doku ilk istenişte bir kez üretilir ve paylaşılır (bayrak başına ~0,8 KB).
## Kodlar ve adlar ProfileCatalog.FLAGS'ta; bilinmeyen kod boş bayrak (gri) çizer.

const W: int = 16
const H: int = 11
const INK: Color = Color("2F3236")

@export var code: String = "":
	set(value):
		code = value
		update_minimum_size()
		queue_redraw()
## Ekrandaki piksel boyu (tuval birimi). 2 → 36x26.
@export var pixel: float = 2.0:
	set(value):
		pixel = value
		update_minimum_size()
		queue_redraw()

static var _cache: Dictionary = {}


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _get_minimum_size() -> Vector2:
	return Vector2(W + 2, H + 2) * pixel


func _draw() -> void:
	var tex: Texture2D = texture(code)
	if tex == null:
		return
	var target: Vector2 = Vector2(W + 2, H + 2) * pixel
	draw_texture_rect(tex, Rect2((size - target) * 0.5, target), false)


## Paylaşılan doku (kenarlı, 18x13). Kod boşsa null.
static func texture(flag_code: String) -> Texture2D:
	if flag_code.is_empty():
		return null
	if not _cache.has(flag_code):
		_cache[flag_code] = ImageTexture.create_from_image(image(flag_code))
	return _cache[flag_code]


## Kenarlı bayrak görüntüsü (W+2 x H+2).
static func image(flag_code: String) -> Image:
	var p: _Painter = _Painter.new()
	_paint(p, flag_code)
	return p.framed()


# --- Bayraklar -------------------------------------------------------------------

static func _paint(p: _Painter, flag_code: String) -> void:
	var white: Color = Color("FFFFFF")
	match flag_code:
		"TR":
			p.fill(Color("E30A17"))
			p.sprite(3, 2, ["..###", ".##..", "##...", "##...", "##...", ".##..", "..###"], white)
			p.sprite(8, 4, [".#.", "###", ".#."], white)
		"AZ":
			p.rows([3, 5, 3], [Color("00B5E2"), Color("EF3340"), Color("509E2F")])
			p.sprite(5, 3, [".##", "#..", "#..", "#..", ".##"], white)
			p.sprite(8, 4, [".#.", "###", ".#."], white)
		"DE":
			p.rows([4, 3, 4], [Color("202020"), Color("DD0000"), Color("FFCE00")])
		"NL":
			p.rows([4, 3, 4], [Color("AE1C28"), white, Color("21468B")])
		"RU":
			p.rows([4, 3, 4], [white, Color("0039A6"), Color("D52B1E")])
		"BG":
			p.rows([4, 3, 4], [white, Color("00966E"), Color("D62612")])
		"AT":
			p.rows([4, 3, 4], [Color("ED2939"), white, Color("ED2939")])
		"UA":
			p.rows([6, 5], [Color("0057B7"), Color("FFD700")])
		"PL":
			p.rows([6, 5], [white, Color("DC143C")])
		"ID":
			p.rows([6, 5], [Color("FF0000"), white])
		"FR":
			p.cols([5, 6, 5], [Color("0055A4"), white, Color("EF4135")])
		"IT":
			p.cols([5, 6, 5], [Color("009246"), white, Color("CE2B37")])
		"IE":
			p.cols([5, 6, 5], [Color("169B62"), white, Color("FF883E")])
		"PE":
			p.cols([5, 6, 5], [Color("D91023"), white, Color("D91023")])
		"BE":
			p.cols([5, 6, 5], [Color("202020"), Color("FDDA24"), Color("EF3340")])
		"RO":
			p.cols([5, 6, 5], [Color("002B7F"), Color("FCD116"), Color("CE1126")])
		"MX":
			p.cols([5, 6, 5], [Color("006847"), white, Color("CE1126")])
			p.sprite(7, 3, [".##.", "####", ".##."], Color("8C5A2B"))
			p.sprite(6, 6, ["#..#", ".##."], Color("4A8C3A"))
		"ES":
			p.rows([3, 5, 3], [Color("AA151B"), Color("F1BF00"), Color("AA151B")])
			p.sprite(3, 4, ["##", "##", "##"], Color("AA151B"))
			p.px(3, 3, Color("C79A2E"))
			p.px(4, 3, Color("C79A2E"))
		"AR":
			p.rows([4, 3, 4], [Color("74ACDF"), white, Color("74ACDF")])
			p.sprite(7, 4, [".#.", "###", ".#."], Color("F6B40E"))
		"CO":
			p.rows([6, 3, 2], [Color("FCD116"), Color("003893"), Color("CE1126")])
		"VE":
			p.rows([4, 3, 4], [Color("FFCC00"), Color("00247D"), Color("CF142B")])
			for x: int in [4, 6, 9, 11]:
				p.px(x, 5, white)
			p.px(7, 4, white)
			p.px(8, 4, white)
		"CL":
			p.rows([6, 5], [white, Color("D52B1E")])
			p.rect(0, 0, 6, 6, Color("0039A6"))
			p.sprite(2, 2, [".#.", "###", ".#."], white)
		"GB":
			_union_jack(p, Rect2i(0, 0, W, H))
		"US":
			for y: int in H:
				p.rect(0, y, W, 1, Color("B22234") if y % 2 == 0 else white)
			p.rect(0, 0, 7, 6, Color("3C3B6E"))
			for y: int in range(1, 6, 2):
				for x: int in range(1, 7, 2):
					p.px(x, y, white)
			for y: int in range(2, 5, 2):
				for x: int in range(2, 6, 2):
					p.px(x, y, white)
		"BR":
			p.fill(Color("009C3B"))
			for y: int in H:
				for x: int in W:
					if absf(x + 0.5 - 8.0) / 7.0 + absf(y + 0.5 - 5.5) / 4.6 <= 1.0:
						p.px(x, y, Color("FFDF00"))
			p.disk(8.0, 5.5, 2.6, Color("002776"))
			p.rect(6, 5, 4, 1, white)
		"PT":
			p.cols([6, 10], [Color("006600"), Color("FF0000")])
			p.disk(6.0, 5.5, 2.4, Color("FFE000"))
			p.rect(5, 4, 2, 3, white)
			p.px(5, 5, Color("FF0000"))
			p.px(6, 5, Color("FF0000"))
		"GR":
			for y: int in H:
				p.rect(0, y, W, 1, Color("0D5EAF") if y % 2 == 0 else white)
			p.rect(0, 0, 5, 5, Color("0D5EAF"))
			p.rect(2, 0, 1, 5, white)
			p.rect(0, 2, 5, 1, white)
		"CH":
			p.fill(Color("DA291C"))
			p.rect(7, 2, 2, 7, white)
			p.rect(5, 4, 6, 3, white)
		"SE":
			p.fill(Color("006AA7"))
			p.rect(4, 0, 3, H, Color("FECC00"))
			p.rect(0, 4, W, 3, Color("FECC00"))
		"NO":
			p.fill(Color("BA0C2F"))
			p.rect(3, 0, 5, H, white)
			p.rect(0, 3, W, 5, white)
			p.rect(4, 0, 3, H, Color("00205B"))
			p.rect(0, 4, W, 3, Color("00205B"))
		"DK":
			p.fill(Color("C8102E"))
			p.rect(4, 0, 3, H, white)
			p.rect(0, 4, W, 3, white)
		"FI":
			p.fill(white)
			p.rect(4, 0, 3, H, Color("003580"))
			p.rect(0, 4, W, 3, Color("003580"))
		"GE":
			p.fill(white)
			p.rect(6, 0, 4, H, Color("FF0000"))
			p.rect(0, 4, W, 3, Color("FF0000"))
			for at: Vector2i in [Vector2i(2, 1), Vector2i(12, 1), Vector2i(2, 7), Vector2i(12, 7)]:
				p.sprite(at.x, at.y, [".#.", "###", ".#."], Color("FF0000"))
		"KZ":
			p.fill(Color("00AFCA"))
			p.rect(1, 0, 1, H, Color("FEC50C"))
			p.disk(9.0, 4.0, 1.9, Color("FEC50C"))
			for at: Vector2i in [Vector2i(9, 0), Vector2i(12, 4), Vector2i(6, 4), Vector2i(11, 1), Vector2i(7, 1)]:
				p.px(at.x, at.y, Color("FEC50C"))
			p.sprite(5, 7, ["##....##", ".######."], Color("FEC50C"))
		"UZ":
			p.rows([4, 1, 2, 1, 3], [Color("0099B5"), Color("CE1126"), white, Color("CE1126"), Color("1EB53A")])
			p.sprite(1, 0, [".##", "#..", ".##"], white)
			for x: int in [5, 7, 9]:
				p.px(x, 1, white)
			p.px(6, 2, white)
			p.px(8, 2, white)
		"JP":
			p.fill(white)
			p.disk(8.0, 5.5, 3.0, Color("BC002D"))
		"KR":
			p.fill(white)
			p.disk(8.0, 5.5, 2.7, Color("0047A0"))
			for y: int in H:
				for x: int in W:
					if Vector2(x + 0.5 - 8.0, y + 0.5 - 5.5).length() <= 2.7 and y + 0.5 < 5.5 + (x + 0.5 - 8.0) * 0.4:
						p.px(x, y, Color("CD2E3A"))
			var black: Color = Color("202020")
			p.sprite(1, 1, ["##.", ".##"], black)
			p.sprite(12, 1, [".##", "##."], black)
			p.sprite(1, 8, [".##", "##."], black)
			p.sprite(12, 8, ["##.", ".##"], black)
		"CN":
			p.fill(Color("EE1C25"))
			p.sprite(1, 1, ["..#..", "#####", ".###.", ".#.#."], Color("FFFF00"))
			for at: Vector2i in [Vector2i(7, 1), Vector2i(8, 3), Vector2i(8, 5), Vector2i(7, 6)]:
				p.px(at.x, at.y, Color("FFFF00"))
		"IN":
			p.rows([4, 3, 4], [Color("FF9933"), white, Color("138808")])
			p.sprite(7, 4, ["##", "##"], Color("000080"))
			p.px(7, 4, Color("4A4AB0"))
		"SA":
			p.fill(Color("006C35"))
			p.sprite(3, 2, ["#.##.#.##.", "##.##.##.#"], white)
			p.rect(3, 7, 10, 1, white)
			p.px(12, 6, white)
			p.px(4, 8, white)
		"AE":
			p.rows([4, 3, 4], [Color("00732F"), white, Color("202020")])
			p.rect(0, 0, 4, H, Color("FF0000"))
		"EG":
			p.rows([4, 3, 4], [Color("CE1126"), white, Color("202020")])
			p.sprite(7, 4, ["##", "##"], Color("C09300"))
		"CA":
			p.cols([4, 8, 4], [Color("D80621"), white, Color("D80621")])
			p.sprite(5, 2, ["...#...", "#.###.#", "#######", ".#####.", "..###..", "...#..."], Color("D80621"))
		"AU":
			p.fill(Color("012169"))
			_union_jack(p, Rect2i(0, 0, 8, 6))
			p.sprite(3, 7, [".#.", "###", ".#."], white)
			for at: Vector2i in [Vector2i(12, 1), Vector2i(10, 4), Vector2i(14, 4), Vector2i(12, 8)]:
				p.px(at.x, at.y, white)
		_:
			p.fill(Color("B9BDC4"))
			p.sprite(7, 3, ["##", "..", "##", "##"], Color("8A8F98"))


## Birleşik Krallık bayrağı (Avustralya'nın köşesinde de): mavi zemin, beyaz + kırmızı çaprazlar, haç.
static func _union_jack(p: _Painter, r: Rect2i) -> void:
	var white: Color = Color("FFFFFF")
	var red: Color = Color("C8102E")
	p.rect(r.position.x, r.position.y, r.size.x, r.size.y, Color("012169"))
	for y: int in r.size.y:
		for x: int in r.size.x:
			var u: float = (x + 0.5) / r.size.x
			var v: float = (y + 0.5) / r.size.y
			var d: float = minf(absf(u - v), absf(u + v - 1.0)) * r.size.y
			if d < 1.1:
				p.px(r.position.x + x, r.position.y + y, red if d < 0.45 else white)
	var cx: int = r.position.x + r.size.x / 2
	var cy: int = r.position.y + r.size.y / 2
	var big: bool = r.size.x >= 12
	p.rect(cx - (2 if big else 1), r.position.y, 4 if big else 2, r.size.y, white)
	p.rect(r.position.x, cy - (1 if big else 1), r.size.x, 3 if big else 2, white)
	p.rect(cx - 1, r.position.y, 2, r.size.y, red)
	p.rect(r.position.x, cy, r.size.x, 1, red)


## Piksel tuvali: W x H boyar, sonra kenar + ton ekleyip çerçeveli görüntü verir.
class _Painter:
	var img: Image = Image.create(W, H, false, Image.FORMAT_RGBA8)

	func fill(c: Color) -> void:
		img.fill(c)

	func px(x: int, y: int, c: Color) -> void:
		if x >= 0 and y >= 0 and x < W and y < H:
			img.set_pixel(x, y, c)

	func rect(x: int, y: int, w: int, h: int, c: Color) -> void:
		for yy: int in range(y, y + h):
			for xx: int in range(x, x + w):
				px(xx, yy, c)

	## Yatay şeritler: yükseklikler (toplam H) ve renkler.
	func rows(heights: Array, colors: Array) -> void:
		var y: int = 0
		for i: int in heights.size():
			rect(0, y, W, int(heights[i]), colors[i])
			y += int(heights[i])

	## Dikey şeritler: genişlikler (toplam W) ve renkler.
	func cols(widths: Array, colors: Array) -> void:
		var x: int = 0
		for i: int in widths.size():
			rect(x, 0, int(widths[i]), H, colors[i])
			x += int(widths[i])

	func disk(cx: float, cy: float, r: float, c: Color) -> void:
		for y: int in H:
			for x: int in W:
				if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
					px(x, y, c)

	## "#" olan hücreler boyanır.
	func sprite(x: int, y: int, pattern: Array, c: Color) -> void:
		for row: int in pattern.size():
			var line: String = pattern[row]
			for col: int in line.length():
				if line[col] == "#":
					px(x + col, y + row, c)

	## 1 px mürekkep kenar (köşeler kesik), üst sıra açık, alt sıra koyu, sol üstte bir parıltı pikseli.
	func framed() -> Image:
		var out: Image = Image.create(W + 2, H + 2, false, Image.FORMAT_RGBA8)
		out.fill(Color(0, 0, 0, 0))
		for y: int in H + 2:
			for x: int in W + 2:
				var corner: bool = (x == 0 or x == W + 1) and (y == 0 or y == H + 1)
				if corner:
					continue
				if x == 0 or y == 0 or x == W + 1 or y == H + 1:
					out.set_pixel(x, y, INK)
					continue
				var c: Color = img.get_pixel(x - 1, y - 1)
				if y == 1:
					c = c.lerp(Color.WHITE, 0.28)
				elif y == H:
					c = c.lerp(Color.BLACK, 0.22)
				out.set_pixel(x, y, c)
		out.set_pixel(1, 1, out.get_pixel(1, 1).lerp(Color.WHITE, 0.6))
		out.set_pixel(2, 1, out.get_pixel(2, 1).lerp(Color.WHITE, 0.35))
		return out
