class_name DecorGrid
## DEKORASYON IZGARASI — zemin karolarının ve iç duvarların ortak koordinatı (saf, sahneye dokunmaz).
##
## Izgara garajın SABİT ön-sağ köşesine bağlıdır (x = −0,2, z = −0,2) ve −x / −z yönüne sayar.
## Garaj seviyeyle yalnızca −x ve −z'ye büyüdüğü için bir karonun ya da duvarın göz indeksi
## genişlemede DEĞİŞMEZ: seviye 1'de boyanan karo seviye 4'te de aynı yerdedir. (Eski görünür ızgara
## garaj ortasına ortalanıyordu; her genişlemede çizgiler kayıyordu.)
##
##   göz (cell)   Vector2i(i, j): ön-sağ köşeden i göz −x'e, j göz −z'ye. i, j ≥ 0.
##   düğüm (node) Vector2i(a, b): ızgara çizgilerinin kesiştiği nokta, dünya = KÖŞE − (a, b) · GÖZ.
##   kenar (edge) duvar segmentinin yeri, iki komşu düğüm arası:
##       "x:a:b"  X boyunca, z-çizgisi b üzerinde, düğüm (a, b) ile (a+1, b) arası
##       "z:a:b"  Z boyunca, x-çizgisi a üzerinde, düğüm (a, b) ile (a, b+1) arası

## Göz boyu: tamir alanının (0,5 × 0,7) uzun kenarının dörtte biri (garage_system.gd GRID_CELL ile aynı).
const CELL: float = 0.175
## Sabit ön-sağ köşe (dünya X/Z) — garage_system.gd FIXED_RIGHT_X / FIXED_FRONT_Z.
const CORNER: Vector2 = Vector2(-0.2, -0.2)
## En büyük garajın (seviye 4: 5,6 × 3,6) göz sayısı; kayıt ve veri dokusu bu boyuttadır.
const MAX_COLS: int = 32
const MAX_ROWS: int = 21


static func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori((CORNER.x - p.x) / CELL), floori((CORNER.y - p.y) / CELL))


static func cell_center(c: Vector2i) -> Vector2:
	return CORNER - (Vector2(c) + Vector2(0.5, 0.5)) * CELL


static func cell_rect(c: Vector2i) -> Rect2:
	var hi: Vector2 = CORNER - Vector2(c) * CELL
	return Rect2(hi - Vector2(CELL, CELL), Vector2(CELL, CELL))


static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < MAX_COLS and c.y < MAX_ROWS


static func node_pos(n: Vector2i) -> Vector2:
	return CORNER - Vector2(n) * CELL


static func nearest_node(p: Vector2) -> Vector2i:
	return Vector2i(roundi((CORNER.x - p.x) / CELL), roundi((CORNER.y - p.y) / CELL))


## Garaj zemin dikdörtgeninin kapladığı göz sayısı (son sıra / sütun kısmi olabilir, duvarın altında kalır).
static func lot_cells(lot: Rect2) -> Vector2i:
	return Vector2i(mini(ceili(lot.size.x / CELL - 1e-4), MAX_COLS), mini(ceili(lot.size.y / CELL - 1e-4), MAX_ROWS))


# --- Kenarlar ------------------------------------------------------------------------

static func edge_key(axis: StringName, a: int, b: int) -> String:
	return "%s:%d:%d" % [axis, a, b]


## "x:3:4" → {"axis": &"x", "a": 3, "b": 4}; bozuksa boş sözlük.
static func parse_edge(key: String) -> Dictionary:
	var parts: PackedStringArray = key.split(":")
	if parts.size() != 3 or not (parts[0] == "x" or parts[0] == "z") \
			or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return {}
	return {"axis": StringName(parts[0]), "a": int(parts[1]), "b": int(parts[2])}


## Kenarın iki ucu (dünya X/Z): ilki ön-sağa yakın düğüm.
static func edge_ends(key: String) -> PackedVector2Array:
	var e: Dictionary = parse_edge(key)
	if e.is_empty():
		return PackedVector2Array()
	var n0: Vector2i = Vector2i(e["a"], e["b"])
	var n1: Vector2i = n0 + (Vector2i(1, 0) if e["axis"] == &"x" else Vector2i(0, 1))
	return PackedVector2Array([node_pos(n0), node_pos(n1)])


## İki düğüm arasındaki düz koşunun kenarları (düğümler aynı satır / sütunda değilse baskın eksen alınır).
static func run_edges(from: Vector2i, to: Vector2i) -> Array[String]:
	var out: Array[String] = []
	var d: Vector2i = to - from
	if d == Vector2i.ZERO:
		return out
	if absi(d.x) >= absi(d.y):
		for a: int in range(mini(from.x, to.x), maxi(from.x, to.x)):
			out.append(edge_key(&"x", a, from.y))
	else:
		for b: int in range(mini(from.y, to.y), maxi(from.y, to.y)):
			out.append(edge_key(&"z", from.x, b))
	return out


## Dünya noktasına en yakın kenar (dokunuşla tek segment koymak için).
static func nearest_edge(p: Vector2) -> String:
	var fx: float = (CORNER.x - p.x) / CELL
	var fz: float = (CORNER.y - p.y) / CELL
	# Yatay çizgiye (z sabit) uzaklık ile dikey çizgiye (x sabit) uzaklık: hangisi yakınsa o eksen
	var dz: float = absf(fz - roundf(fz))
	var dx: float = absf(fx - roundf(fx))
	if dz <= dx:
		return edge_key(&"x", floori(fx), roundi(fz))
	return edge_key(&"z", roundi(fx), floori(fz))
