class_name InteriorWalls
extends Node3D
## GARAJ İÇİ DUVARLAR — DecorManager'daki segmentlerin dünyadaki gövdesi (dekorasyon v2).
##
## Segmentler ızgara kenarına oturur (DecorGrid). Hepsi TEK bir ArrayMesh'tir; yüzeyler malzemeye göre
## gruplanır (kaplama başına bir yüzey + kapı / cam / çerçeve), yani 40 segmentlik bir garaj bir avuç
## çizim çağrısıdır. Kaplama malzemesi dünya uzayında üç düzlemli eşlendiği için segmentler arası ek
## yeri görünmez (vfx/decor_textures.gd). Dış duvarlarla aynı boydadır (kullanıcı kararı: orijinaldeki gibi).
##
## Oyun sırasında tamir alanının / sergilenen aracın ÖNÜNE düşen segmentler ayrı bir gövdede yarı saydam
## çizilir (OCCLUDER_FADE); hangilerinin önde kaldığını GarageDecorView hesaplar. Düzenlemede hepsi opaktır.
##
## Segment boyu garajın zemin dikdörtgenine kırpılır: son göz kısmi olduğundan dış duvara değen
## segment duvarın iç yüzüne kadar uzar (arada boşluk kalmaz).

## Duvar kalınlığı (dış duvar 0,05; iç duvar biraz ince).
const THICKNESS: float = 0.03
## Kapı / geçit açıklığı (birim): ~0,9 m genişlik, ~2,1 m yükseklik.
const DOOR_WIDTH: float = 0.12
const DOOR_HEIGHT: float = 0.29
const ARCH_WIDTH: float = 0.14
## Pencerenin alt duvarı ve üst kenarı (zemin üstü yükseklik oranı).
const WINDOW_LOW: float = 0.40
const WINDOW_HIGH: float = 0.82
const HALF_HEIGHT: float = 0.45
const FRAME: float = 0.012

const DOOR_COLOR: Color = Color("4A4F57")
const FRAME_COLOR: Color = Color("2B2E33")
const GLASS_COLOR: Color = Color(0.72, 0.86, 0.95, 0.32)
## Aracın önündeki duvarın saydamlığı (0 opak, 1 görünmez): duvar belli olsun, arkası okunsun.
const OCCLUDER_FADE: float = 0.62

static var _default_wall: StandardMaterial3D
static var _door_mat: StandardMaterial3D
static var _frame_mat: StandardMaterial3D
static var _glass_mat: StandardMaterial3D

var _mesh: MeshInstance3D
## Önde kalan (yarı saydam) segmentlerin gövdesi.
var _faded_mesh: MeshInstance3D
var _faded: Dictionary = {}
var _preview: MeshInstance3D
## Son kurulan segmentlerin dünya kutuları (seçim için): anahtar → AABB.
var _boxes: Dictionary = {}
var _signature: String = ""


func _ready() -> void:
	name = "InteriorWalls"
	_mesh = MeshInstance3D.new()
	_mesh.name = "WallMesh"
	add_child(_mesh)
	_faded_mesh = MeshInstance3D.new()
	_faded_mesh.name = "FadedWallMesh"
	_faded_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_faded_mesh)


## Segmentleri yeniden kurar (değişmediyse hiçbir şey yapmaz).
## floor_y / top: zemin üstü ve duvar tepesi; lot: zemin dikdörtgeni (kırpma için, iç yüzlerden).
## faded: yarı saydam çizilecek segment anahtarları (aracın önündekiler).
func rebuild(walls: Dictionary, floor_y: float, top: float, clip: Rect2, faded: Dictionary = {}) -> void:
	var sig: String = "%s|%.4f|%.4f|%s|%s" % [str(walls), floor_y, top, str(clip), str(faded.keys())]
	if sig == _signature:
		return
	_signature = sig
	_boxes.clear()
	_faded = faded.duplicate()
	var tools: Dictionary = {}   # malzeme anahtarı → [SurfaceTool, Material]
	var faded_tools: Dictionary = {}
	for key: String in walls:
		var rec: Dictionary = walls[key]
		var seg: Dictionary = segment(key, walls, clip)
		if seg.is_empty():
			continue
		_boxes[key] = _segment_box(seg, floor_y, top)
		_add_piece(faded_tools if faded.has(key) else tools, rec["piece"], rec.get("finish", &""), seg, floor_y, top)
	var mesh: ArrayMesh = _commit(tools)
	_mesh.mesh = mesh if mesh.get_surface_count() > 0 else null
	# Saydamlık MALZEMEDE: GeometryInstance3D.transparency mobil (Compatibility) çizicide bu duvarları
	# simsiyah çiziyordu (ölçüldü). Önde kalan yüzeyler malzemenin saydam kopyasıyla yazılır.
	for mat_key: String in faded_tools:
		var pair: Array = faded_tools[mat_key]
		pair[1] = _faded_material(pair[1])
	var faded_mesh: ArrayMesh = _commit(faded_tools)
	_faded_mesh.mesh = faded_mesh if faded_mesh.get_surface_count() > 0 else null


## Şu an yarı saydam çizilen segmentler.
func faded_keys() -> Array:
	return _faded.keys()


## Segmentin dünya kutusu (geometri kurulmadan, kural hesabı için).
static func segment_box(key: String, walls: Dictionary, clip: Rect2, floor_y: float, top: float) -> AABB:
	var seg: Dictionary = segment(key, walls, clip)
	return _segment_box(seg, floor_y, top) if not seg.is_empty() else AABB()


## Ekran ışınının değdiği en yakın segment ("" yoksa). Kutu düzeyinde: segment ince ve düz.
func pick(origin: Vector3, dir: Vector3) -> String:
	var best: String = ""
	var best_t: float = INF
	for key: String in _boxes:
		var box: AABB = _boxes[key]
		# İnce duvarı parmakla tutmak için kalınlık şişirilir
		var t: float = GarageDecorView._ray_box(origin, dir, box.grow(0.012))
		if t < best_t:
			best_t = t
			best = key
	return best


func box_of(key: String) -> AABB:
	return _boxes.get(key, AABB())


## Önizleme: verilen kenarlarda yarı saydam kutular (ok: kehribar, değil: kiremit).
func show_preview(keys: Array[String], ok: Array[bool], floor_y: float, top: float, clip: Rect2, walls: Dictionary) -> void:
	clear_preview()
	if keys.is_empty():
		return
	var good: SurfaceTool = SurfaceTool.new()
	good.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bad: SurfaceTool = SurfaceTool.new()
	bad.begin(Mesh.PRIMITIVE_TRIANGLES)
	var any_good: bool = false
	var any_bad: bool = false
	for i: int in keys.size():
		var seg: Dictionary = segment(keys[i], walls, clip, false)
		if seg.is_empty():
			continue
		var box: AABB = _segment_box(seg, floor_y, top).grow(0.004)
		if ok[i]:
			_box_aabb(good, box)
			any_good = true
		else:
			_box_aabb(bad, box)
			any_bad = true
	var mesh: ArrayMesh = ArrayMesh.new()
	if any_good:
		good.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _preview_mat(Color(0.98, 0.71, 0.18, 0.45)))
	if any_bad:
		bad.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _preview_mat(Color(0.86, 0.32, 0.26, 0.5)))
	_preview = MeshInstance3D.new()
	_preview.name = "WallPreview"
	_preview.mesh = mesh
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_preview)


func clear_preview() -> void:
	if _preview and is_instance_valid(_preview):
		_preview.queue_free()
	_preview = null


## Düzenleme sırasında duvarların saydamlığı (0 opak).
func set_fade(fade: float) -> void:
	if _mesh:
		_mesh.transparency = fade


# --- Geometri --------------------------------------------------------------------------

## Kenarın dünya geometrisi: {"axis", "from": float, "to": float (eksen boyunca, from < to), "line": float
## (dik koordinat), "ext0", "ext1": uç uzatmaları}. Kırpma sonrası boyu yoksa boş sözlük.
## extend: köşelerde X yönlü segment, dik segmentle buluşan uçta kalınlığın yarısı kadar uzar (köşe dolar).
static func segment(key: String, walls: Dictionary, clip: Rect2, extend: bool = true) -> Dictionary:
	var e: Dictionary = DecorGrid.parse_edge(key)
	if e.is_empty():
		return {}
	var ends: PackedVector2Array = DecorGrid.edge_ends(key)
	var axis: StringName = e["axis"]
	var from: float
	var to: float
	var line: float
	var lo: float
	var hi: float
	if axis == &"x":
		from = minf(ends[0].x, ends[1].x)
		to = maxf(ends[0].x, ends[1].x)
		line = ends[0].y
		lo = clip.position.x
		hi = clip.end.x
	else:
		from = minf(ends[0].y, ends[1].y)
		to = maxf(ends[0].y, ends[1].y)
		line = ends[0].x
		lo = clip.position.y
		hi = clip.end.y
	from = maxf(from, lo)
	to = minf(to, hi)
	if to - from < 0.01:
		return {}
	var ext0: float = 0.0
	var ext1: float = 0.0
	if extend and axis == &"x":
		var a: int = e["a"]
		var b: int = e["b"]
		# from ucu = düğüm (a+1, b) tarafı (x küçük), to ucu = düğüm (a, b)
		if not walls.has(DecorGrid.edge_key(&"x", a + 1, b)):
			ext0 = THICKNESS * 0.5
		if not walls.has(DecorGrid.edge_key(&"x", a - 1, b)):
			ext1 = THICKNESS * 0.5
	return {"axis": axis, "from": from - ext0, "to": to + ext1, "line": line}


static func _segment_box(seg: Dictionary, floor_y: float, top: float) -> AABB:
	var h: float = top - floor_y
	var t: float = THICKNESS
	if seg["axis"] == &"x":
		return AABB(Vector3(seg["from"], floor_y, float(seg["line"]) - t * 0.5),
			Vector3(float(seg["to"]) - float(seg["from"]), h, t))
	return AABB(Vector3(float(seg["line"]) - t * 0.5, floor_y, seg["from"]),
		Vector3(t, h, float(seg["to"]) - float(seg["from"])))


## Segmentin eksen boyunca [u0, u1] ve yükseklikte [y0, y1] parçasının kutusu (kalınlık oranı k).
static func _part(seg: Dictionary, u0: float, u1: float, y0: float, y1: float, k: float = 1.0) -> AABB:
	var t: float = THICKNESS * k
	if seg["axis"] == &"x":
		return AABB(Vector3(u0, y0, float(seg["line"]) - t * 0.5), Vector3(u1 - u0, y1 - y0, t))
	return AABB(Vector3(float(seg["line"]) - t * 0.5, y0, u0), Vector3(t, y1 - y0, u1 - u0))


func _add_piece(tools: Dictionary, piece: StringName, finish: StringName, seg: Dictionary,
		floor_y: float, top: float) -> void:
	var wall: SurfaceTool = _tool(tools, "wall:" + String(finish), wall_material(finish))
	var h: float = top - floor_y
	var u0: float = seg["from"]
	var u1: float = seg["to"]
	var mid: float = (u0 + u1) * 0.5
	match piece:
		&"wall_half":
			_box_aabb(wall, _part(seg, u0, u1, floor_y, floor_y + h * HALF_HEIGHT))
		&"wall_door", &"wall_arch":
			var w: float = minf(DOOR_WIDTH if piece == &"wall_door" else ARCH_WIDTH, (u1 - u0) * 0.8)
			var dh: float = floor_y + minf(DOOR_HEIGHT, h * 0.8)
			_box_aabb(wall, _part(seg, u0, mid - w * 0.5, floor_y, top))
			_box_aabb(wall, _part(seg, mid + w * 0.5, u1, floor_y, top))
			_box_aabb(wall, _part(seg, mid - w * 0.5, mid + w * 0.5, dh, top))
			var frame: SurfaceTool = _tool(tools, "frame", _frame())
			_box_aabb(frame, _part(seg, mid - w * 0.5 - FRAME, mid - w * 0.5, floor_y, dh, 1.15))
			_box_aabb(frame, _part(seg, mid + w * 0.5, mid + w * 0.5 + FRAME, floor_y, dh, 1.15))
			_box_aabb(frame, _part(seg, mid - w * 0.5 - FRAME, mid + w * 0.5 + FRAME, dh, dh + FRAME, 1.15))
			if piece == &"wall_door":
				var door: SurfaceTool = _tool(tools, "door", _door())
				_box_aabb(door, _part(seg, mid - w * 0.5, mid + w * 0.5, floor_y, dh, 0.45))
				_box_aabb(frame, _part(seg, mid + w * 0.28, mid + w * 0.36, floor_y + (dh - floor_y) * 0.48,
					floor_y + (dh - floor_y) * 0.53, 0.9))
		&"wall_window":
			var low: float = floor_y + h * WINDOW_LOW
			var high: float = floor_y + h * WINDOW_HIGH
			_box_aabb(wall, _part(seg, u0, u1, floor_y, low))
			_box_aabb(wall, _part(seg, u0, u1, high, top))
			var frame2: SurfaceTool = _tool(tools, "frame", _frame())
			_box_aabb(frame2, _part(seg, u0, u1, low, low + FRAME, 1.2))
			_box_aabb(frame2, _part(seg, u0, u1, high - FRAME, high, 1.2))
			_box_aabb(frame2, _part(seg, mid - FRAME * 0.5, mid + FRAME * 0.5, low, high, 1.1))
			_box_aabb(_tool(tools, "glass", _glass()), _part(seg, u0, u1, low + FRAME, high - FRAME, 0.25))
		&"wall_glass":
			var frame3: SurfaceTool = _tool(tools, "frame", _frame())
			_box_aabb(frame3, _part(seg, u0, u0 + FRAME, floor_y, top, 1.1))
			_box_aabb(frame3, _part(seg, u1 - FRAME, u1, floor_y, top, 1.1))
			_box_aabb(frame3, _part(seg, u0, u1, floor_y, floor_y + FRAME * 2.0, 1.2))
			_box_aabb(frame3, _part(seg, u0, u1, top - FRAME, top, 1.2))
			_box_aabb(_tool(tools, "glass", _glass()), _part(seg, u0 + FRAME, u1 - FRAME,
				floor_y + FRAME * 2.0, top - FRAME, 0.25))
		_:
			_box_aabb(wall, _part(seg, u0, u1, floor_y, top))


## Kartlarda / küçük resimde gösterilecek tek parça: bir göz boyunda segment. Dünya biriminde kurulur ve
## garaj-içi ölçüsüne büyütülür (yerleştiren / küçük resim tarafı WORLD_SCALE uygular).
static func build_piece_preview(piece: StringName) -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = String(piece)
	var tools: Dictionary = {}
	var seg: Dictionary = {"axis": &"x", "from": -DecorGrid.CELL * 0.5, "to": DecorGrid.CELL * 0.5, "line": 0.0}
	var builder: InteriorWalls = InteriorWalls.new()
	builder._add_piece(tools, piece, &"", seg, 0.0, 0.395)
	builder.free()
	var body: MeshInstance3D = MeshInstance3D.new()
	body.mesh = _commit(tools)
	body.scale = Vector3.ONE / GarageDecorView.WORLD_SCALE
	root.add_child(body)
	return root


# --- Malzemeler ------------------------------------------------------------------------

## Kaplamanın malzemesi; "" = dış duvarla aynı varsayılan gri.
static func wall_material(finish: StringName) -> Material:
	if finish != &"":
		return DecorTextures.wall_material(finish)
	if _default_wall == null:
		_default_wall = StandardMaterial3D.new()
		_default_wall.albedo_color = Color(0.6, 0.6, 0.6)
		_default_wall.roughness = 0.82
	return _default_wall


static func _door() -> Material:
	if _door_mat == null:
		_door_mat = StandardMaterial3D.new()
		_door_mat.albedo_color = DOOR_COLOR
		_door_mat.roughness = 0.55
		_door_mat.metallic = 0.2
	return _door_mat


static func _frame() -> Material:
	if _frame_mat == null:
		_frame_mat = StandardMaterial3D.new()
		_frame_mat.albedo_color = FRAME_COLOR
		_frame_mat.roughness = 0.45
		_frame_mat.metallic = 0.5
	return _frame_mat


static func _glass() -> Material:
	if _glass_mat == null:
		_glass_mat = StandardMaterial3D.new()
		_glass_mat.albedo_color = GLASS_COLOR
		_glass_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass_mat.roughness = 0.08
		_glass_mat.metallic = 0.1
	return _glass_mat


static var _faded_cache: Dictionary = {}


## Malzemenin yarı saydam kopyası (önbellekli; kaplama başına bir kez).
static func _faded_material(material: Material) -> Material:
	if material == null or not (material is BaseMaterial3D):
		return material
	if _faded_cache.has(material):
		return _faded_cache[material]
	var copy: BaseMaterial3D = (material as BaseMaterial3D).duplicate() as BaseMaterial3D
	copy.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	copy.albedo_color.a = (material as BaseMaterial3D).albedo_color.a * (1.0 - OCCLUDER_FADE)
	copy.cull_mode = BaseMaterial3D.CULL_BACK
	_faded_cache[material] = copy
	return copy


static func _preview_mat(color: Color) -> Material:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	return mat


## Araçları tek ArrayMesh'e yüzey yüzey yazar. Boş kalan araç (ör. cam parçasında hiç kullanılmayan
## kaplama) yüzey EKLEMEZ; malzeme yalnızca gerçekten eklenen yüzeye atanır (yoksa bir önceki
## yüzeyin — camın — malzemesi kaplamayla değişiyordu).
static func _commit(tools: Dictionary) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	for mat_key: String in tools:
		var pair: Array = tools[mat_key]
		var before: int = mesh.get_surface_count()
		(pair[0] as SurfaceTool).commit(mesh)
		if mesh.get_surface_count() > before:
			mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	return mesh


static func _tool(tools: Dictionary, key: String, material: Material) -> SurfaceTool:
	if not tools.has(key):
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = [st, material]
	return (tools[key] as Array)[0]


## Eksen hizalı kutu: 6 yüz, dışa bakan normaller, yüz başına UV (triplanar malzemede kullanılmaz).
static func _box_aabb(st: SurfaceTool, box: AABB) -> void:
	if box.size.x <= 0.0 or box.size.y <= 0.0 or box.size.z <= 0.0:
		return
	var p: Vector3 = box.position
	var e: Vector3 = box.end
	var faces: Array = [
		[Vector3(1, 0, 0), [Vector3(e.x, p.y, e.z), Vector3(e.x, p.y, p.z), Vector3(e.x, e.y, p.z), Vector3(e.x, e.y, e.z)]],
		[Vector3(-1, 0, 0), [Vector3(p.x, p.y, p.z), Vector3(p.x, p.y, e.z), Vector3(p.x, e.y, e.z), Vector3(p.x, e.y, p.z)]],
		[Vector3(0, 1, 0), [Vector3(p.x, e.y, e.z), Vector3(e.x, e.y, e.z), Vector3(e.x, e.y, p.z), Vector3(p.x, e.y, p.z)]],
		[Vector3(0, -1, 0), [Vector3(p.x, p.y, p.z), Vector3(e.x, p.y, p.z), Vector3(e.x, p.y, e.z), Vector3(p.x, p.y, e.z)]],
		[Vector3(0, 0, 1), [Vector3(p.x, p.y, e.z), Vector3(e.x, p.y, e.z), Vector3(e.x, e.y, e.z), Vector3(p.x, e.y, e.z)]],
		[Vector3(0, 0, -1), [Vector3(e.x, p.y, p.z), Vector3(p.x, p.y, p.z), Vector3(p.x, e.y, p.z), Vector3(e.x, e.y, p.z)]],
	]
	var uvs: Array[Vector2] = [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)]
	for face: Array in faces:
		var n: Vector3 = face[0]
		var q: Array = face[1]
		for idx: int in [0, 2, 1, 0, 3, 2]:   # Godot: ön yüz SAAT YÖNÜNDE (kameradan bakınca)
			st.set_normal(n)
			st.set_uv(uvs[idx])
			st.add_vertex(q[idx])
