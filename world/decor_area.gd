class_name DecorArea
extends RefCounted
## DEKOR YERLEŞİM ALANI — garajın geometrisi ve yerleşim KURALLARI. Saftır: sahneye dokunmaz,
## GarageDecorView sahneden ölçüp kurar, testler elle kurup doğrudan çağırır.
##
## Koordinat: dünya X/Z düzlemi, Vector2(x, z). Garaj sağdan (x = -0.2) ve önden (z = -0.2)
## sabittir, seviyeyle -x ve -z yönüne büyür; iki duvarı vardır: SOL (iç yüzü +X'e bakar) ve
## ARKA (iç yüzü +Z'ye bakar). İzometrik kamera tam bu iki yüzü görür.
##
## İzler YÖNLENDİRİLMİŞ dikdörtgendir (döndürülmüş), çakışma SAT ile sınanır. Eksen hizalı kutu
## 45°'de uzun eşyayı şişirirdi (römork 0,58×0,28 → 0,61×0,61) ve geçerli yerleri reddederdi.

## Duvar iç yüzü ile zemin eşyası arasında bırakılan pay (eşya duvara gömülmesin).
const WALL_GAP: float = 0.012
## Garajın açık kenarlarında (ön/sağ) bırakılan pay.
const EDGE_GAP: float = 0.006
## İki izin "değiyor" sayılması için tolerans: tam bitişik eşyalar çakışma sayılmaz.
const TOUCH_EPS: float = 0.002
## Duvar eşyasının duvar yüzünden ayrılması (z-fighting olmasın).
const WALL_OFFSET: float = 0.002

## Zemin yerleşimine uygun dikdörtgen (duvar iç yüzlerinden ve açık kenarlardan içeride).
var floor_rect: Rect2 = Rect2()
## Zemin üst yüzünün y'si (ölçüldü: 0,01).
var floor_y: float = 0.0
## Arka duvarın iç yüzü (z) ve üzerinde eşya asılabilen x aralığı.
var back_face_z: float = 0.0
var back_span: Vector2 = Vector2.ZERO
## Sol duvarın iç yüzü (x) ve üzerinde eşya asılabilen z aralığı.
var left_face_x: float = 0.0
var left_span: Vector2 = Vector2.ZERO
## Duvar yüksekliği ve duvar eşyasının dikey merkezi.
var wall_top: float = 0.4
var wall_mount_y: float = 0.25
## Zemin eşyasının giremeyeceği yerler (tamir alanları, genişletme tabelası…), dünya X/Z.
var obstacles: Array[Rect2] = []
## İç duvar segmentlerinin zemin izleri (dekorasyon v2). Zemin eşyası ve tamir alanı bunlara binemez;
## ayrı tutulur çünkü düzenleme modunda "yasak alan" örtüsüyle boyanmazlar (duvarın kendisi görünür).
var wall_rects: Array[Rect2] = []
## Duvar eşyası asılabilen İÇ DUVAR yüzleri (yalnızca kameraya bakan yüz, düz duvar koşuları):
## {"id": String, "axis": &"x" | &"z" (yüzün uzandığı eksen), "plane": float (dik koordinat),
##  "span": Vector2 (eksen boyunca aralık), "yaw": 0 (+Z'ye bakar) | 90 (+X'e bakar)}.
## Dış duvarlar (arka / sol) bu listede değildir; aşağıdaki işlevler onları da "back" / "left" olarak katar.
var inner_faces: Array[Dictionary] = []
## Görünen ızgaranın ilk çizgisi (dünya X/Z). Izgara garaj merkezine ortalanır ve göz sayısı
## yuvarlanır, yani çizgiler zemin kenarından BAŞLAMAZ (seviye 1'de 0,0375 içeride) — oturtma
## bu noktaya göre yapılmazsa eşya çizilen ızgaradan kaymış görünür.
var grid_origin: Vector2 = Vector2.ZERO


# --- Zemin ---------------------------------------------------------------------------

## Zemin izinin 4 köşesi (dünya X/Z). size = (genişlik x, derinlik z), yaw derece.
## Godot'ta Y ekseni etrafında +θ dönüş yerel (x, z)'yi (x·cosθ + z·sinθ, −x·sinθ + z·cosθ) yapar.
static func corners(center: Vector2, size: Vector2, yaw_deg: float) -> PackedVector2Array:
	var t: float = deg_to_rad(yaw_deg)
	var c: float = cos(t)
	var s: float = sin(t)
	var h: Vector2 = size * 0.5
	var out: PackedVector2Array = PackedVector2Array()
	for local: Vector2 in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		out.append(center + Vector2(local.x * c + local.y * s, -local.x * s + local.y * c))
	return out


## İki dışbükey dörtgen çakışıyor mu? (Ayırıcı eksen teoremi: kenar normallerinden biri ikisini
## ayırıyorsa çakışma yoktur.) Tam değme çakışma sayılmaz.
static func overlaps(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for poly: PackedVector2Array in [a, b]:
		for i: int in poly.size():
			var edge: Vector2 = poly[(i + 1) % poly.size()] - poly[i]
			var axis: Vector2 = Vector2(-edge.y, edge.x)
			if axis.length_squared() < 1e-12:
				continue
			axis = axis.normalized()
			var ra: Vector2 = _project(a, axis)
			var rb: Vector2 = _project(b, axis)
			if ra.y <= rb.x + TOUCH_EPS or rb.y <= ra.x + TOUCH_EPS:
				return false
	return true


static func rect_corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])


## İz zemin alanının içinde mi (dört köşe de)?
func inside_floor(poly: PackedVector2Array) -> bool:
	for p: Vector2 in poly:
		if p.x < floor_rect.position.x - 1e-4 or p.x > floor_rect.end.x + 1e-4 \
				or p.y < floor_rect.position.y - 1e-4 or p.y > floor_rect.end.y + 1e-4:
			return false
	return true


## Bu iz bir engele (tamir alanı vb.) biniyor mu?
func hits_obstacle(poly: PackedVector2Array) -> bool:
	for rect: Rect2 in obstacles:
		if overlaps(poly, rect_corners(rect)):
			return true
	return false


## Bu iz bir iç duvar segmentine biniyor mu?
func hits_wall(poly: PackedVector2Array) -> bool:
	for rect: Rect2 in wall_rects:
		if overlaps(poly, rect_corners(rect)):
			return true
	return false


# --- Duvar ---------------------------------------------------------------------------

## Bütün asılabilir yüzler: dış arka ("back"), dış sol ("left") ve iç duvar yüzleri.
func faces() -> Array[Dictionary]:
	var out: Array[Dictionary] = [
		{"id": "back", "axis": &"x", "plane": back_face_z, "span": back_span, "yaw": 0.0},
		{"id": "left", "axis": &"z", "plane": left_face_x, "span": left_span, "yaw": 90.0},
	]
	out.append_array(inner_faces)
	return out


func face(id: String) -> Dictionary:
	for f: Dictionary in faces():
		if f["id"] == id:
			return f
	return {}


## Zemin noktasının yüze uzaklığı: yüze dik mesafe + yüz aralığının dışında kalan kısım. İç yüz
## yalnızca ÖNÜNDEN seçilir (arkası görünmez; arkasındaki noktaya en yakın yüz o değildir).
static func _face_distance(f: Dictionary, near: Vector2) -> float:
	var perp: float = (near.y if f["axis"] == &"x" else near.x) - float(f["plane"])
	var along: float = near.x if f["axis"] == &"x" else near.y
	var span: Vector2 = f["span"]
	var outside: float = maxf(span.x - along, 0.0) + maxf(along - span.y, 0.0)
	if f["id"] != "back" and f["id"] != "left" and perp < -0.02:
		return INF
	return absf(perp) + outside


## Duvar eşyasının hangi yüze ve nereye oturacağı: zemindeki işaret noktasına EN YAKIN yüz.
## Dönüş: {"wall": yüz kimliği, "along": float, "yaw": float, "position": Vector3}.
func wall_mount(near: Vector2, width: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for f: Dictionary in faces():
		if (f["span"] as Vector2).y - (f["span"] as Vector2).x < width - 1e-4:
			continue   # eşya bu yüze sığmaz
		var d: float = _face_distance(f, near)
		if d < best_d:
			best_d = d
			best = f
	if best.is_empty():
		best = faces()[0]
	return mount_on(best["id"], near.x if best["axis"] == &"x" else near.y, width)


## Belirli yüze, yüz boyunca `along` noktasına asar (yüz aralığına sıkıştırılır).
func mount_on(side: Variant, along: float, width: float) -> Dictionary:
	var f: Dictionary = face(String(side))
	if f.is_empty():
		f = face("back")
	var span: Vector2 = f["span"]
	var a: float = clampf(along, span.x + width * 0.5, span.y - width * 0.5)
	var id: Variant = StringName(f["id"]) if f["id"] == "back" or f["id"] == "left" else f["id"]
	if f["axis"] == &"x":
		return {"wall": id, "along": a, "yaw": 0.0,
			"position": Vector3(a, wall_mount_y, float(f["plane"]) + WALL_OFFSET)}
	return {"wall": id, "along": a, "yaw": 90.0,
		"position": Vector3(float(f["plane"]) + WALL_OFFSET, wall_mount_y, a)}


## Kayıtlı bir duvar eşyasının bulunduğu yüz: aynı yöndeki yüzlerden düzlemi konuma en yakın olan
## (iç duvar düzlemi kalınlığın yarısı kadar öndedir; tolerans içinde eşleşir). Bulunamazsa dış duvar.
func face_of(position: Vector3, yaw: float) -> Dictionary:
	var axis: StringName = &"x" if wall_side(yaw) == &"back" else &"z"
	var perp: float = position.z if axis == &"x" else position.x
	var along: float = position.x if axis == &"x" else position.z
	for f: Dictionary in inner_faces:
		if f["axis"] != axis:
			continue
		var span: Vector2 = f["span"]
		if absf(perp - (float(f["plane"]) + WALL_OFFSET)) < 0.008 and along >= span.x - 0.01 and along <= span.y + 0.01:
			return f
	return face("back" if axis == &"x" else "left")


## Kayıtlı bir duvar eşyasını GÜNCEL yüzüne yeniden oturtur (garaj büyüyünce dış duvar geriye kayar;
## eşya havada kalmasın diye duvar boyunca konumu korunur, duvara dik bileşen yeniden hesaplanır).
## Yüz yönden ve düzlemden okunur, "en yakın duvar" kuralından değil: köşede yanlış duvara atlamasın.
func reattach_wall(position: Vector3, yaw: float, width: float) -> Vector3:
	var f: Dictionary = face_of(position, yaw)
	return mount_on(f["id"], position.x if f["axis"] == &"x" else position.z, width)["position"]


## Duvar eşyasının duvardaki aralığı (1B): aynı duvardaki iki eşya bu aralıklarla çakışmamalı.
static func wall_interval(position: Vector3, yaw: float, width: float) -> Vector2:
	var along: float = position.x if is_equal_approx(fposmod(yaw, 180.0), 0.0) else position.z
	return Vector2(along - width * 0.5, along + width * 0.5)


static func wall_side(yaw: float) -> StringName:
	return &"back" if is_equal_approx(fposmod(yaw, 180.0), 0.0) else &"left"


# --- Izgara ---------------------------------------------------------------------------

## Konumu ızgaraya oturtur. Adım, görünen ızgaranın YARISI: merkez ya göz ortasına ya çizgiye
## düşer, böylece her boydaki eşyanın kenarı bir çizgiyle hizalanabilir.
func snap(point: Vector2, step: float) -> Vector2:
	if step <= 0.0:
		return point
	return Vector2(grid_origin.x + roundf((point.x - grid_origin.x) / step) * step,
		grid_origin.y + roundf((point.y - grid_origin.y) / step) * step)


static func _project(poly: PackedVector2Array, axis: Vector2) -> Vector2:
	var lo: float = INF
	var hi: float = -INF
	for p: Vector2 in poly:
		var d: float = p.dot(axis)
		lo = minf(lo, d)
		hi = maxf(hi, d)
	return Vector2(lo, hi)
