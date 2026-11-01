class_name PileOutline
extends Node2D
## HURDALIK — ARANABİLİR YIĞININ DIŞ HATTI: dolu yığının yalnızca EN DIŞ kenarı parlak sarı çizgiyle çevrilir
## (2026-11-01, kullanıcı: "yalnız dış çizgisinde olsun, iç taraflarında değil"; eski sarı kesik halkaların yerine).
##
## Neden 2B: malzemenin stencil "outline" kipi her parçayı ayrı büyütüyor, yığının içinden görünen zemin
## boşluklarını da sarıya boyuyordu; ayrıca AgX tonlaması sarıyı soluk kreme çeviriyordu. Burada hat görüntü
## alanının 2B tuvaline (tonlamasız) çizilir.
##
## Hat ÖNCEDEN hesaplanır (tools/world/bake_pile_outlines.gd → DATA_PATH; hurdalık sahnesi yeniden dışa
## aktarılınca yeniden koşulmalı, junkyard_test glb MD5'iyle denetler):
##   1) Yığının üçgenleri kameranın düzlemine izdüşürülüp bir ızgaraya derinlikle boyanır (kamera açısı sabit,
##      ortografik: pan / zoom hattı değiştirmez, yalnız taşır ve ölçekler).
##   2) İnce çatlaklar kapanır, dışarıdan ulaşılamayan iç boşluklar dolu sayılır; en büyük parçanın dış sınırı izlenir.
##   3) Hurda tepesine GÖMÜLÜ yığın (kendi hattının %40'ından fazlası başka hurdaya yaslanıyor): hat yığından
##      başlayıp ona yüzeyce bitişik bütün tepeyi sarar (ince halat / direk uzantıları kırpılır); aynı tepedeki
##      yığınlar bu tek hattı paylaşır (grup), biri doluysa tepe parlar, tepeye dokunmak dolu olanı seçer.
##   4) Hattın önünden bir şey geçiyorsa (fener direği, varil, figür) o kısım gizlenir; arkada duran hurda kesmez.
## Veri yoksa / sahneye uymuyorsa hat çalışma anında gizlemesiz hesaplanır (yalnız geliştirme yedeği).

const DATA_PATH: String = "res://assets/world/junkyard_outlines.json"
const SCENE_PATH: String = "res://assets/world/junkyard.glb"
const COLOR: Color = Color("FFD21F")
const GLOW: Color = Color(1.0, 0.86, 0.2, 0.35)
const WIDTH: float = 2.6        # görüntü alanı pikseli
const GLOW_WIDTH: float = 7.0
const GRID: int = 120           # ızgaranın uzun kenarı (hücre)
const CLOSE_CELLS: int = 2      # çatlak kapatma yarıçapı (hücre); hat yığının bu kadar dışından geçer
const SIMPLIFY: float = 0.7     # sadeleştirme toleransı (hücre)
const TOUCH: float = 1.5        # bu kadar arkadaki komşu hurda da "yaslanmış" sayılır (metre, kamera derinliği)
const FRONT: float = 0.3        # hattın kenarından bu kadar öndeki nesne çizgiyi örter (gizlenir)
const HEAP_RATIO: float = 0.4   # hattının bu oranından fazlası hurdaya yaslanan yığın tepeye gömülüdür
const HEAP_REACH: float = 6.0   # tepe aranırken yığının çevresinde bakılan alan (metre)
const HEAP_GRID: int = 200
const JUMP: float = 0.8         # tepe yüzeyinde komşu hücreler arası en büyük derinlik farkı (metre)
const THIN_CELLS: int = 3       # tepe bölgesinden kırpılan ince uzantı yarıçapı (hücre; ~0,3 m)
const LOW: float = 0.25         # bu yükseklikten alçak üçgenler (zemin lekesi, iz) engel sayılmaz (metre)
const MIN_RUN: int = 4          # bundan kısa görünür parça atılır, bundan kısa gizli boşluk kapanır (nokta)

## 8 komşu, y aşağı koordinatta saat yönünde: D, GD, G, GB, B, KB, K, KD.
const RING: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)]
const NONE: float = -1.0e9

static var _fallback_cache: Dictionary = {}   # yığın adı → çokgen (veri yokken çalışma anında hesaplanan)

var _camera: Camera3D
var _polygons: Array[PackedVector2Array] = []   # kamera düzleminde (u = kamera sağı, v = kamera yukarısı; metre)
var _shown: Array[PackedByteArray] = []         # nokta başına: 1 = hat burada görünür
var _group: PackedInt32Array = PackedInt32Array()   # aynı tepedeki yığınlar tek hattı paylaşır (temsilcinin indeksi)
var _ready: Array[bool] = []
var _time: float = 0.0


## Hatlar veriden (ya da yedek olarak çalışma anında) kurulur. `camera` hurdalığın ortografik kamerası.
func setup(camera: Camera3D, piles: Array[Node3D]) -> void:
	_camera = camera
	_polygons.clear()
	_shown.clear()
	_group.clear()
	_ready.clear()
	var data: Array = load_data(camera.global_basis, piles.size())
	for i: int in piles.size():
		var points: PackedVector2Array = PackedVector2Array()
		var shown: PackedByteArray = PackedByteArray()
		var group: int = i
		if not data.is_empty():
			var entry: Dictionary = data[i]
			points = entry["points"]
			shown = entry["shown"]
			group = clampi(int(entry["group"]), 0, piles.size() - 1)
		else:
			var key: String = String(piles[i].name)
			if not _fallback_cache.has(key):
				_fallback_cache[key] = silhouette(piles[i], camera.global_basis)
			points = _fallback_cache[key]
			shown.resize(points.size())
			shown.fill(1)
		_polygons.append(points)
		_shown.append(shown)
		_group.append(group)
		_ready.append(false)


func set_ready(index: int, on: bool) -> void:
	if index >= 0 and index < _ready.size() and _ready[index] != on:
		_ready[index] = on
		queue_redraw()


## Yığın dolu ve hattı çiziliyor (tepedeyse tepenin ortak hattı).
func is_shown(index: int) -> bool:
	return index >= 0 and index < _ready.size() and _ready[index] and _polygons[index].size() >= 3


## Aynı tepedeki dolu yığın (yoksa -1): tepenin boş kısmına dokunulunca dolu olan aranır.
func ready_mate(index: int) -> int:
	if index < 0 or index >= _group.size():
		return -1
	for i: int in _group.size():
		if _group[i] == _group[index] and _ready[i]:
			return i
	return -1


func polygon(index: int) -> PackedVector2Array:
	return _polygons[index] if index >= 0 and index < _polygons.size() else PackedVector2Array()


func shown_flags(index: int) -> PackedByteArray:
	return _shown[index] if index >= 0 and index < _shown.size() else PackedByteArray()


func _process(delta: float) -> void:
	_time += delta
	if _ready.has(true):
		queue_redraw()   # kamera kayar / yaklaşır, çizgi nefes alır


## Ekran noktası bir yığının hattının içindeyse o yığın (tepedeyse dolu olanı tercih edilir); yoksa -1.
func hit(screen_point: Vector2) -> int:
	if _camera == null or not _camera.is_inside_tree():
		return -1
	for i: int in _polygons.size():
		if _group[i] != i or _polygons[i].size() < 3:
			continue
		if Geometry2D.is_point_in_polygon(screen_point, _to_screen(_polygons[i])):
			var mate: int = ready_mate(i)
			return mate if mate >= 0 else i
	return -1


## Ortografik izdüşüm doğrusal: kamera düzlemindeki (u, v) → ekran = köken + u·ex + v·ey.
func _to_screen(points: PackedVector2Array) -> PackedVector2Array:
	var basis: Basis = _camera.global_basis
	var origin: Vector2 = _camera.unproject_position(Vector3.ZERO)
	var ex: Vector2 = _camera.unproject_position(basis.x) - origin
	var ey: Vector2 = _camera.unproject_position(basis.y) - origin
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(points.size())
	for k: int in points.size():
		out[k] = origin + ex * points[k].x + ey * points[k].y
	return out


func _draw() -> void:
	if _camera == null or not _camera.is_inside_tree():
		return
	var wave: float = 0.5 + 0.5 * sin(_time * 3.4)
	var glow: Color = Color(GLOW, GLOW.a * (0.6 + 0.4 * wave))
	var core: Color = COLOR.lerp(Color.WHITE, 0.25 * wave)
	for i: int in _polygons.size():
		if _group[i] != i or ready_mate(i) < 0 or _polygons[i].size() < 3:
			continue   # her hat bir kez (grubun temsilcisi), gruptan biri doluysa
		var screen: PackedVector2Array = _to_screen(_polygons[i])
		for run: PackedVector2Array in _runs(screen, _shown[i]):
			draw_polyline(run, glow, GLOW_WIDTH, true)
			draw_polyline(run, core, WIDTH, true)


## Görünür ardışık noktalar → ayrı çizgiler. Hepsi görünürse kapalı tek çizgi.
static func _runs(points: PackedVector2Array, shown: PackedByteArray) -> Array[PackedVector2Array]:
	var n: int = points.size()
	var out: Array[PackedVector2Array] = []
	var first_hidden: int = shown.find(0)
	if first_hidden < 0:
		var loop: PackedVector2Array = points.duplicate()
		loop.append(points[0])
		out.append(loop)
		return out
	var run: PackedVector2Array = PackedVector2Array()
	for k: int in range(1, n + 1):
		var i: int = (first_hidden + k) % n
		if shown[i] == 1:
			run.append(points[i])
		elif run.size() >= 2:
			out.append(run)
			run = PackedVector2Array()
		else:
			run.clear()
	if run.size() >= 2:
		out.append(run)
	return out


# --- Veri ----------------------------------------------------------------------------------------

## Önceden hesaplanmış hatlar: [{points, shown}] yığın sırasıyla. Yoksa, yığın sayısı ya da kamera açısı
## uymuyorsa boş dizi (çağıran yedeğe düşer).
static func load_data(view: Basis, pile_count: int) -> Array:
	if not FileAccess.file_exists(DATA_PATH):
		return []
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary:
		return []
	var data: Dictionary = parsed
	var piles: Array = data.get("piles", [])
	var right: Array = data.get("right", [])
	var up: Array = data.get("up", [])
	if piles.size() != pile_count or right.size() != 3 or up.size() != 3:
		return []
	if Vector3(right[0], right[1], right[2]).dot(view.x.normalized()) < 0.999 \
			or Vector3(up[0], up[1], up[2]).dot(view.y.normalized()) < 0.999:
		push_warning("PileOutline: kamera açısı değişmiş, hatlar yeniden hesaplanmalı (tools/world/bake_pile_outlines.gd)")
		return []
	var out: Array = []
	for raw: Variant in piles:
		var entry: Dictionary = raw
		var flat: Array = entry.get("points", [])
		var flags: Array = entry.get("shown", [])
		var points: PackedVector2Array = PackedVector2Array()
		var shown: PackedByteArray = PackedByteArray()
		for k: int in range(0, flat.size() - 1, 2):
			points.append(Vector2(float(flat[k]), float(flat[k + 1])))
		for f: Variant in flags:
			shown.append(1 if int(f) != 0 else 0)
		if shown.size() != points.size():
			shown.resize(points.size())
			shown.fill(1)
		out.append({"points": points, "shown": shown, "group": int(entry.get("group", out.size()))})
	return out


## Hurdalık sahnesinden (Yard kökü) bütün yığınların hattı + görünürlüğü + grubu; DATA_PATH biçiminde sözlük.
## Hurda tepesine GÖMÜLÜ yığın (yalnız kendi hattının HEAP_RATIO'dan fazlası başka hurdaya değiyor): hat yığının
## değil, ona yüzeyce bitişik bütün tepenin dış hattıdır; aynı tepedeki yığınlar o hattı paylaşır (aynı grup).
static func bake(yard: Node3D, piles: Array[Node3D], view: Basis) -> Dictionary:
	var right: Vector3 = view.x.normalized()
	var up: Vector3 = view.y.normalized()
	var forward: Vector3 = view.z.normalized()   # kameraya doğru: büyük = yakın
	var pile_meshes: Array[MeshInstance3D] = []
	for pile: Node3D in piles:
		var found: Array[MeshInstance3D] = _meshes(pile)
		pile_meshes.append(found[0] if not found.is_empty() else null)
	# Engeller: yığınların kendisi hariç (öteki yığınlar engeldir) sahnede kalan her şey; zemin / tepe ve halkalar hariç
	var blockers: Array[Dictionary] = []   # {"pile": int (yığınsa indeksi, değilse -1), "tris": PackedVector3Array (u, v, derinlik)}
	for mi: MeshInstance3D in _meshes(yard):
		var mesh_name: String = String(mi.name)
		if mesh_name == "Terrain" or mesh_name.begins_with("SearchRing_") or not mi.is_visible_in_tree():
			continue
		blockers.append({"pile": pile_meshes.find(mi), "tris": _project(mi, right, up, forward, LOW)})
	var results: Array[Dictionary] = []
	for i: int in piles.size():
		var own: PackedVector3Array = _project(pile_meshes[i], right, up, forward, -INF) if pile_meshes[i] else PackedVector3Array()
		var others: Array = []
		for b: Dictionary in blockers:
			if int(b["pile"]) != i:
				others.append(b["tris"])
		var result: Dictionary = _outline_with_flags(own, others, false)
		result["group"] = i
		result["center"] = _centroid(own)
		if float(result.get("touch", 0.0)) > HEAP_RATIO:
			var heap: Dictionary = _outline_with_flags(own, others, true)   # tepeye gömülü: bütün tepenin hattı
			if (heap["points"] as PackedVector2Array).size() >= 3:
				heap["group"] = i
				heap["center"] = result["center"]
				heap["heap"] = true
				result = heap
		results.append(result)
	# Aynı tepedeki yığınlar: her gömülü yığın, merkezini içine alan EN BÜYÜK tepe hattına bağlanır (sıradan bağımsız)
	for i: int in results.size():
		if not bool(results[i].get("heap", false)):
			continue
		var best: int = i
		var best_area: float = absf(_area(results[i]["points"]))
		for j: int in results.size():
			if j == i or not bool(results[j].get("heap", false)):
				continue
			var area: float = absf(_area(results[j]["points"]))
			if area > best_area and Geometry2D.is_point_in_polygon(results[i]["center"], results[j]["points"]):
				best = j
				best_area = area
		results[i]["group"] = best
	for i: int in results.size():
		var g: int = int(results[i]["group"])
		if g != i:
			results[i]["points"] = results[g]["points"]
			results[i]["shown"] = results[g]["shown"]
	var out: Array = []
	for result: Dictionary in results:
		var flat: Array = []
		for p: Vector2 in result["points"]:
			flat.append(snappedf(p.x, 0.001))
			flat.append(snappedf(p.y, 0.001))
		out.append({"points": flat, "shown": Array(result["shown"]), "group": int(result["group"])})
	return {"version": 2, "scene_md5": FileAccess.get_md5(SCENE_PATH),
		"right": [right.x, right.y, right.z], "up": [up.x, up.y, up.z], "piles": out}


## Yığının dış silüeti (gizleme yok), kamera düzleminde. Veri yokken çalışma anı yedeği.
static func silhouette(pile: Node3D, view: Basis) -> PackedVector2Array:
	var own: PackedVector3Array = PackedVector3Array()
	for mi: MeshInstance3D in _meshes(pile):
		own.append_array(_project(mi, view.x.normalized(), view.y.normalized(), view.z.normalized(), -INF))
	return _outline_with_flags(own, [], false)["points"]


# --- Hesap ---------------------------------------------------------------------------------------

static func _meshes(root_node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root_node is MeshInstance3D:
		out.append(root_node)
	for node: Node in root_node.find_children("*", "MeshInstance3D", true, false):
		out.append(node as MeshInstance3D)
	return out


## Üçgenler kamera düzlemine: üçer üçer (u, v, derinlik). En yüksek köşesi `min_height`'tan alçak üçgen atlanır.
static func _project(mi: MeshInstance3D, right: Vector3, up: Vector3, forward: Vector3, min_height: float) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if mi == null or mi.mesh == null:
		return out
	var xf: Transform3D = mi.global_transform
	for s: int in mi.mesh.get_surface_count():
		var arrays: Array = mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var world: PackedVector3Array = PackedVector3Array()
		world.resize(verts.size())
		for k: int in verts.size():
			world[k] = xf * verts[k]
		var count: int = index.size() if not index.is_empty() else verts.size()
		for t: int in range(0, count - 2, 3):
			var a: Vector3 = world[index[t] if not index.is_empty() else t]
			var b: Vector3 = world[index[t + 1] if not index.is_empty() else t + 1]
			var c: Vector3 = world[index[t + 2] if not index.is_empty() else t + 2]
			if maxf(a.y, maxf(b.y, c.y)) < min_height:
				continue
			for p: Vector3 in [a, b, c]:
				out.append(Vector3(p.dot(right), p.dot(up), p.dot(forward)))
	return out


## Dış hat (kamera düzlemi) + nokta başına görünürlük + "touch" (hattın başka hurdaya değen oranı).
## `heap`: yığından başlayıp ona YÜZEYCE bitişik (komşu hücreler arası derinlik farkı < JUMP) hurda da katılır →
## bütün tepenin hattı; arkadaki nesneler derinlikte kopuk olduğu için katılmaz.
## Görünürlük: hattın hemen dışında (1 hücre) bir engel, hattın oradaki kenarından FRONT kadar ÖNDEYSE (direk,
## varil önünden geçiyor) o kısım gizli; yalnız arkada duran / yaslanan hurda çizgiyi kesmez.
static func _outline_with_flags(own: PackedVector3Array, blockers: Array, heap: bool) -> Dictionary:
	var empty: Dictionary = {"points": PackedVector2Array(), "shown": PackedByteArray(), "touch": 0.0}
	if own.size() < 3:
		return empty
	var lo: Vector2 = Vector2(own[0].x, own[0].y)
	var hi: Vector2 = lo
	for p: Vector3 in own:
		lo = lo.min(Vector2(p.x, p.y))
		hi = hi.max(Vector2(p.x, p.y))
	if heap:
		lo -= Vector2(HEAP_REACH, HEAP_REACH)
		hi += Vector2(HEAP_REACH, HEAP_REACH)
	var margin: int = CLOSE_CELLS + 4
	var cell: float = maxf(hi.x - lo.x, hi.y - lo.y) / float(HEAP_GRID if heap else GRID)
	if cell <= 0.0:
		return empty
	var w: int = int(ceil((hi.x - lo.x) / cell)) + margin * 2
	var h: int = int(ceil((hi.y - lo.y) / cell)) + margin * 2
	# Izgara: x = (u - lo.x) / hücre, y = (hi.y - v) / hücre (satır aşağı inince v azalır); z = derinlik
	var pile_depth: PackedFloat32Array = _depth_buffer(w, h)
	_rasterize(pile_depth, w, h, own, lo, hi, cell, margin)
	var block_depth: PackedFloat32Array = _depth_buffer(w, h)
	for tris: PackedVector3Array in blockers:
		_rasterize(block_depth, w, h, tris, lo, hi, cell, margin)
	var mask: PackedByteArray = PackedByteArray()
	mask.resize(w * h)
	for i: int in w * h:
		if pile_depth[i] > NONE:
			mask[i] = 1
	if heap:
		var seed: PackedByteArray = mask.duplicate()
		_grow_surface(mask, pile_depth, block_depth, w, h)
		# Açma (aşındır + genişlet): tepeye değen ince uzantılar (vinç halatı, direk) bölgeden kırpılır
		mask = _dilate(_erode(mask, w, h, THIN_CELLS), w, h, THIN_CELLS)
		for i: int in w * h:
			mask[i] = mask[i] | seed[i]
	var contour: PackedVector2Array = outer_contour(_dilate(mask, w, h, CLOSE_CELLS), w, h)
	if contour.size() < 3:
		return empty
	# Hattın kenar derinliği: içerideki (yığın / tepe) en yakın yüzey; engel: içeride olmayan hurda
	var inside_depth: PackedFloat32Array = _depth_buffer(w, h)
	var outside_depth: PackedFloat32Array = _depth_buffer(w, h)
	for i: int in w * h:
		if mask[i] == 1:
			inside_depth[i] = maxf(pile_depth[i], block_depth[i])
		else:
			outside_depth[i] = block_depth[i]
	var shown: PackedByteArray = PackedByteArray()
	shown.resize(contour.size())
	var touching: int = 0
	for k: int in contour.size():
		var c: Vector2i = Vector2i(contour[k])
		var edge: float = _nearest_depth(inside_depth, w, h, c, 4)
		var block: float = _nearest_depth(outside_depth, w, h, c, 1)
		if edge > NONE and block > NONE and block > edge - TOUCH:
			touching += 1
		shown[k] = 0 if edge > NONE and block > NONE and block > edge + FRONT else 1
	_clean_runs(shown)
	# Sadeleştirme: görünürlük değişen noktalar korunur; sonra yumuşatma (nokta başına bayrak taşınır)
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(contour.size())
	for k: int in contour.size():
		if shown[k] != shown[(k + 1) % contour.size()] or shown[k] != shown[(k - 1 + contour.size()) % contour.size()]:
			keep[k] = 1
	var kept: PackedInt32Array = simplify_indices(contour, SIMPLIFY, keep)
	var points: PackedVector2Array = PackedVector2Array()
	var flags: PackedByteArray = PackedByteArray()
	for j: int in kept.size():
		var a: int = kept[j]
		var b: int = kept[(j + 1) % kept.size()]
		var pa: Vector2 = contour[a]
		var pb: Vector2 = contour[b]
		points.append(pa.lerp(pb, 0.25))
		flags.append(shown[a])
		points.append(pa.lerp(pb, 0.75))
		flags.append(shown[b] if shown[a] == 1 else 0)
	var world: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in points:
		world.append(Vector2(lo.x + (p.x + 0.5 - margin) * cell, hi.y - (p.y + 0.5 - margin) * cell))
	return {"points": world, "shown": flags, "touch": float(touching) / float(contour.size())}


## Yığın hücrelerinden başlayıp yüzeyce bitişik hurda hücrelerine yayılır (8 komşu, derinlik farkı < JUMP).
static func _grow_surface(mask: PackedByteArray, pile_depth: PackedFloat32Array, block_depth: PackedFloat32Array,
		w: int, h: int) -> void:
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(w * h)
	for i: int in w * h:
		depth[i] = maxf(pile_depth[i], block_depth[i])
	var stack: PackedInt32Array = PackedInt32Array()
	for i: int in w * h:
		if mask[i] == 1:
			stack.append(i)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		var x: int = i % w
		var y: int = i / w
		for d: Vector2i in RING:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var n: int = ny * w + nx
			if mask[n] == 0 and depth[n] > NONE and absf(depth[n] - depth[i]) < JUMP:
				mask[n] = 1
				stack.append(n)


static func _area(points: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5


static func _centroid(tris: PackedVector3Array) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for p: Vector3 in tris:
		sum += Vector2(p.x, p.y)
	return sum / maxf(tris.size(), 1.0)


static func _depth_buffer(w: int, h: int) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(w * h)
	buffer.fill(NONE)
	return buffer


## Üçgenleri ızgaraya derinlikle (hücre başına en yakın) boyar; köşe hücreleri de işaretlenir (ince parçalar).
static func _rasterize(buffer: PackedFloat32Array, w: int, h: int, tris: PackedVector3Array, lo: Vector2, hi: Vector2,
		cell: float, margin: int) -> void:
	var limit: Vector2 = Vector2(w, h)
	for t: int in range(0, tris.size() - 2, 3):
		var a: Vector3 = Vector3((tris[t].x - lo.x) / cell + margin, (hi.y - tris[t].y) / cell + margin, tris[t].z)
		var b: Vector3 = Vector3((tris[t + 1].x - lo.x) / cell + margin, (hi.y - tris[t + 1].y) / cell + margin, tris[t + 1].z)
		var c: Vector3 = Vector3((tris[t + 2].x - lo.x) / cell + margin, (hi.y - tris[t + 2].y) / cell + margin, tris[t + 2].z)
		var x0: int = maxi(int(floor(minf(a.x, minf(b.x, c.x)))), 0)
		var x1: int = mini(int(ceil(maxf(a.x, maxf(b.x, c.x)))), w - 1)
		var y0: int = maxi(int(floor(minf(a.y, minf(b.y, c.y)))), 0)
		var y1: int = mini(int(ceil(maxf(a.y, maxf(b.y, c.y)))), h - 1)
		if x0 > x1 or y0 > y1:
			continue   # ızgaranın dışında
		for p: Vector3 in [a, b, c]:
			if p.x >= 0.0 and p.y >= 0.0 and p.x < limit.x and p.y < limit.y:
				var i: int = int(p.y) * w + int(p.x)
				buffer[i] = maxf(buffer[i], p.z)
		var area: float = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x)
		if absf(area) < 1.0e-6:
			continue
		for y: int in range(y0, y1 + 1):
			var py: float = y + 0.5
			for x: int in range(x0, x1 + 1):
				var px: float = x + 0.5
				var w0: float = ((b.x - px) * (c.y - py) - (b.y - py) * (c.x - px)) / area
				var w1: float = ((c.x - px) * (a.y - py) - (c.y - py) * (a.x - px)) / area
				var w2: float = 1.0 - w0 - w1
				if w0 < -0.001 or w1 < -0.001 or w2 < -0.001:
					continue
				var i: int = y * w + x
				buffer[i] = maxf(buffer[i], w0 * a.z + w1 * b.z + w2 * c.z)


static func _nearest_depth(buffer: PackedFloat32Array, w: int, h: int, at: Vector2i, radius: int) -> float:
	var best: float = NONE
	for y: int in range(maxi(at.y - radius, 0), mini(at.y + radius, h - 1) + 1):
		for x: int in range(maxi(at.x - radius, 0), mini(at.x + radius, w - 1) + 1):
			best = maxf(best, buffer[y * w + x])
	return best


## Kısa gizli boşluklar kapanır, kısa görünür kırıntılar atılır (kapalı dizi; titrek kesik çizgi olmasın).
static func _clean_runs(shown: PackedByteArray) -> void:
	for value: int in [0, 1]:   # önce kısa boşluklar (0) dolar, sonra kısa parçalar (1) silinir
		var n: int = shown.size()
		var start: int = shown.find(1 - value)
		if start < 0:
			continue
		var k: int = 0
		while k < n:
			var i: int = (start + k) % n
			if shown[i] != value:
				k += 1
				continue
			var length: int = 0
			while length < n and shown[(i + length) % n] == value:
				length += 1
			if length < MIN_RUN:
				for j: int in length:
					shown[(i + j) % n] = 1 - value
			k += length


## Kare aşındırma: bir hücre, r yarıçaplı karesinin hepsi doluysa dolu kalır (genişletmenin tersi).
static func _erode(mask: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var inverted: PackedByteArray = PackedByteArray()
	inverted.resize(w * h)
	for i: int in w * h:
		inverted[i] = 1 - mask[i]
	var grown: PackedByteArray = _dilate(inverted, w, h, r)
	for i: int in w * h:
		grown[i] = 1 - grown[i]
	return grown


## Kare genişletme (ayrık: önce yatay, sonra dikey), yarıçap r hücre.
static func _dilate(mask: PackedByteArray, w: int, h: int, r: int) -> PackedByteArray:
	var horizontal: PackedByteArray = PackedByteArray()
	horizontal.resize(w * h)
	for y: int in h:
		var row: int = y * w
		for x: int in w:
			if mask[row + x] == 0:
				continue
			for k: int in range(maxi(x - r, 0), mini(x + r, w - 1) + 1):
				horizontal[row + k] = 1
	var out: PackedByteArray = PackedByteArray()
	out.resize(w * h)
	for y: int in h:
		for x: int in w:
			if horizontal[y * w + x] == 0:
				continue
			for k: int in range(maxi(y - r, 0), mini(y + r, h - 1) + 1):
				out[k * w + x] = 1
	return out


## İkili ızgaranın (1 = dolu) EN BÜYÜK parçasının dış sınırı, hücre koordinatlarında. İç delikler (dışarıdan
## ulaşılamayan boşluklar) dolu sayılır: sınır hiçbir zaman yığının içine girmez.
static func outer_contour(mask: PackedByteArray, w: int, h: int) -> PackedVector2Array:
	# 1) Dış boşluk: kenarlardan 4-komşulukla taşma
	var outside: PackedByteArray = PackedByteArray()
	outside.resize(w * h)
	var stack: PackedInt32Array = PackedInt32Array()
	for x: int in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y: int in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	while not stack.is_empty():
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if outside[i] == 1 or mask[i] == 1:
			continue
		outside[i] = 1
		var x: int = i % w
		var y: int = i / w
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)
	# 2) Parçalar (8-komşu): en büyüğü
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(w * h)
	var best_label: int = 0
	var best_size: int = 0
	var best_start: int = -1
	var next: int = 0
	for i: int in w * h:
		if outside[i] == 1 or label[i] != 0:
			continue
		next += 1
		var count: int = 0
		stack.append(i)
		label[i] = next
		while not stack.is_empty():
			var j: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			count += 1
			var jx: int = j % w
			var jy: int = j / w
			for d: Vector2i in RING:
				var nx: int = jx + d.x
				var ny: int = jy + d.y
				if nx < 0 or ny < 0 or nx >= w or ny >= h:
					continue
				var n: int = ny * w + nx
				if outside[n] == 0 and label[n] == 0:
					label[n] = next
					stack.append(n)
		if count > best_size:
			best_size = count
			best_label = next
			best_start = i   # satır sırasıyla ilk hücre: solu ve üstü parçanın dışında
	if best_start < 0:
		return PackedVector2Array()
	# 3) Moore komşu izleme (saat yönü). Durma: başlangıçtan İLK adımla aynı hücreye yeniden çıkılınca
	#    (başlangıç hücresi sınırda iki kez geçilebilir; yalnız "yerinde dönüş" yetmez).
	var start: Vector2i = Vector2i(best_start % w, best_start / w)
	var contour: PackedVector2Array = PackedVector2Array([Vector2(start)])
	var cur: Vector2i = start
	var back: int = 4   # başlangıca batıdan (boş hücreden) girildi
	var second: Vector2i = Vector2i(-1, -1)
	for step: int in w * h * 2:
		var from: Vector2i = cur
		var moved: bool = false
		for k: int in range(1, 9):
			var d: int = (back + k) % 8
			var p: Vector2i = cur + RING[d]
			if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or label[p.y * w + p.x] != best_label:
				continue
			var prev: Vector2i = cur + RING[(back + k - 1) % 8]
			back = RING.find(prev - p)
			cur = p
			moved = true
			break
		if not moved:
			break   # tek hücrelik parça
		if step == 0:
			second = cur
		elif from == start and cur == second:
			break
		contour.append(Vector2(cur))
	if contour.size() > 1 and contour[contour.size() - 1] == contour[0]:
		contour.resize(contour.size() - 1)   # başlangıca dönüş: kapalı çokgende tekrar etmez
	return contour


## Ramer–Douglas–Peucker, kapalı çokgen: korunacak noktaların indeksleri (artan). `force` = 1 olanlar hep kalır.
static func simplify_indices(points: PackedVector2Array, epsilon: float, force: PackedByteArray = PackedByteArray()) -> PackedInt32Array:
	var n: int = points.size()
	var keep: PackedByteArray = PackedByteArray()
	keep.resize(n)
	if n < 4:
		keep.fill(1)
	else:
		var far: int = 0
		var far_d: float = 0.0
		for i: int in n:
			var d: float = points[0].distance_squared_to(points[i])
			if d > far_d:
				far_d = d
				far = i
		keep[0] = 1
		keep[far] = 1
		var ranges: Array[Vector2i] = [Vector2i(0, far), Vector2i(far, n)]   # n = 0'a dönüş
		while not ranges.is_empty():
			var r: Vector2i = ranges.pop_back()
			var a: Vector2 = points[r.x]
			var b: Vector2 = points[r.y % n]
			var worst: int = -1
			var worst_d: float = epsilon
			for i: int in range(r.x + 1, r.y):
				var d: float = Geometry2D.get_closest_point_to_segment(points[i], a, b).distance_to(points[i])
				if d > worst_d:
					worst_d = d
					worst = i
			if worst >= 0:
				keep[worst] = 1
				ranges.append(Vector2i(r.x, worst))
				ranges.append(Vector2i(worst, r.y))
	var out: PackedInt32Array = PackedInt32Array()
	for i: int in n:
		if keep[i] == 1 or (i < force.size() and force[i] == 1):
			out.append(i)
	return out
