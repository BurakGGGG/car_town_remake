class_name IntersectionMarkings
extends Node3D
## KAVŞAK YOL ÇİZGİLERİ — showroom önündeki kavşağın bütün işaretleri baştan (WorldDressing kurar, sahne düzenlenmez):
## her kolda zebra YAYA GEÇİDİ, gelen şeritte DUR ÇİZGİSİ, dur çizgisinden geriye DÜZ ORTA ÇİZGİ (sonra sahnenin kesik
## çizgileri sürer), şeritte İLERİ OKU ve araçların beklediği yerde yağ / lastik İZLERİ. Kollar aynı yaşta değil:
## showroom önü yeni boyanmış, garaj tarafı aşınmış, kuzey kolu solmuş — gerçek bir kavşak gibi.
##
## Sahnedeki eski işaretler (kavşağın ortasındaki kare, dört kenar çizgisi, kavşağa 1 birimden yakın kesikler) gizlenir.
## Doku: assets/world/road/markings.png (tools/world/road_markings.py üretir; ATLAS dikdörtgenleri onunla aynı).
## Tek gövde, tek malzeme (alpha scissor: saydam sıralama yok, ışık / gölge yolla aynı) — 1 çizim çağrısı.

const ATLAS_PATH: String = "res://assets/world/road/markings.png"
const ATLAS_SIZE: float = 1024.0
## Atlas dikdörtgenleri (px) — road_markings.py ile aynı.
const CROSSWALKS: Array[Rect2] = [Rect2(0, 0, 1024, 256), Rect2(0, 256, 1024, 256), Rect2(0, 512, 1024, 256)]
const STOP_LINES: Array[Rect2] = [Rect2(0, 776, 512, 40), Rect2(0, 824, 512, 40)]
const CENTER_LINES: Array[Rect2] = [Rect2(0, 880, 512, 56), Rect2(0, 944, 512, 56)]
const STAINS: Array[Rect2] = [Rect2(528, 776, 112, 112), Rect2(656, 776, 112, 112), Rect2(528, 900, 112, 112), Rect2(656, 900, 112, 112)]
const ARROWS: Array[Rect2] = [Rect2(784, 776, 104, 240), Rect2(904, 776, 104, 240)]
## Dokuda boyanın kapladığı oran (boş kenar payları): çubuklar yüksekliğin %56'sı, zebra 236/256, ok 80×220 / 104×240.
const BAR_FILL: float = 0.56
const CROSSWALK_FILL: float = 236.0 / 256.0
const ARROW_FILL: Vector2 = Vector2(80.0 / 104.0, 220.0 / 240.0)

## Kavşak kutusu (x, z ∈ [0, 1,2]) ve kenarından dışarı mesafeler.
const BOX_LOW: float = 0.0
const BOX_HIGH: float = 1.2
const CROSSWALK_IN: float = 0.06
const CROSSWALK_OUT: float = 0.36
const STOP_LINE_OUT: float = 0.46       # dur çizgisinin ortası
const STOP_LINE_WIDTH: float = 0.035
const CENTER_LINE_END: float = 0.98     # düz orta çizgi buraya kadar; ötesinde sahnenin kesikleri
const CENTER_LINE_WIDTH: float = 0.05
const ARROW_OUT: Vector2 = Vector2(0.66, 0.96)   # ok (ucu kavşağa bakar)
const ARROW_WIDTH: float = 0.11
const MARK_Y: float = 0.0016
## Kavşağa bu mesafeden yakın sahne kesikleri gizlenir (orta çizgi düz olur).
const HIDE_DASHES_WITHIN: float = 1.0
## Kollar: dışa yön, gelen şerit (enine aralık), zebra / dur / orta / ok dokusu, zebra ters mi.
const ARMS: Array[Dictionary] = [
	{"out": Vector2(-1.0, 0.0), "lane": Vector2(0.6, 1.2), "zebra": 1, "flip": false, "stop": 1, "center": 1, "arrow": 1},   # batı: garaj tarafı, aşınmış
	{"out": Vector2(1.0, 0.0), "lane": Vector2(0.0, 0.6), "zebra": 0, "flip": false, "stop": 0, "center": 0, "arrow": 0},    # doğu: showroom önü, yeni
	{"out": Vector2(0.0, -1.0), "lane": Vector2(0.0, 0.6), "zebra": 2, "flip": true, "stop": 1, "center": 1, "arrow": 1},    # kuzey: solmuş
	{"out": Vector2(0.0, 1.0), "lane": Vector2(0.6, 1.2), "zebra": 1, "flip": true, "stop": 0, "center": 1, "arrow": 0},     # güney: aşınmış (ters)
]
const ROADS: PackedStringArray = ["RoadRight", "RoadRight2", "RoadLeft", "RoadLeft2"]

var _st: SurfaceTool = SurfaceTool.new()
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "IntersectionMarkings"


func _ready() -> void:
	_retire_scene_markings()
	_rng.seed = 2610
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for arm: Dictionary in ARMS:
		_build_arm(arm)
	var marks: MeshInstance3D = MeshInstance3D.new()
	marks.name = "Markings"
	marks.mesh = _st.commit()
	marks.material_override = _material()
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(marks)


## Kavşak girişinden dur çizgisinin ARKA kenarına (yol boyunca) mesafe: bekleyen aracın burnu buraya hizalanır.
static func stop_gap(entry_position: Vector3) -> float:
	var p: Vector3 = entry_position
	var outside: float = maxf(maxf(BOX_LOW - p.x, p.x - BOX_HIGH), maxf(BOX_LOW - p.z, p.z - BOX_HIGH))
	return STOP_LINE_OUT + STOP_LINE_WIDTH * 0.5 - maxf(outside, 0.0)


# --- Kurulum ----------------------------------------------------------------------------------

## Sahnedeki eski kavşak işaretleri: ortadaki kare (Square*), kenar çizgileri (TurnLine*), kavşağa yakın kesikler.
func _retire_scene_markings() -> void:
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return
	for road_name: String in ROADS:
		var road: Node = scene.get_node_or_null(road_name)
		if road == null:
			continue
		for child: Node in road.get_children():
			if not child is Node3D:
				continue
			var mark: Node3D = child
			var label: String = mark.name
			if label.begins_with("Square") or label.begins_with("TurnLine"):
				mark.visible = false
			elif label.begins_with("LaneLine") and _outside(mark.global_position) < HIDE_DASHES_WITHIN:
				mark.visible = false


static func _outside(p: Vector3) -> float:
	return maxf(maxf(BOX_LOW - p.x, p.x - BOX_HIGH), maxf(BOX_LOW - p.z, p.z - BOX_HIGH))


func _build_arm(arm: Dictionary) -> void:
	var out: Vector2 = arm["out"]
	var lane: Vector2 = arm["lane"]
	var road_mid: float = (BOX_LOW + BOX_HIGH) * 0.5
	var lane_mid: float = (lane.x + lane.y) * 0.5
	# Zebra: yolun tam eni; boyalı derinlik CROSSWALK_IN..OUT (dokunun boş kenarı payı kadar büyük dörtgen)
	var depth: float = (CROSSWALK_OUT - CROSSWALK_IN) / CROSSWALK_FILL
	_decal(out, (CROSSWALK_IN + CROSSWALK_OUT) * 0.5, road_mid, depth, BOX_HIGH - BOX_LOW, CROSSWALKS[arm["zebra"]], bool(arm["flip"]))
	# Dur çizgisi: gelen şerit boyunca, orta çizgiye kadar
	var span: float = (lane.y - lane.x - 0.03) / (500.0 / 512.0)
	_bar(out, STOP_LINE_OUT, lane_mid, STOP_LINE_WIDTH / BAR_FILL, span, STOP_LINES[arm["stop"]], false)
	# Düz orta çizgi: dur çizgisinden geriye (karşı yönün şeridiyle arası)
	var center_from: float = STOP_LINE_OUT - STOP_LINE_WIDTH * 0.5
	var length: float = (CENTER_LINE_END - center_from) / (500.0 / 512.0)
	_bar(out, (center_from + CENTER_LINE_END) * 0.5, road_mid, length, CENTER_LINE_WIDTH / BAR_FILL, CENTER_LINES[arm["center"]], true)
	# İleri ok: gelen şeridin ortasında, ucu kavşağa
	var arrow_len: float = (ARROW_OUT.y - ARROW_OUT.x) / ARROW_FILL.y
	_decal(out, (ARROW_OUT.x + ARROW_OUT.y) * 0.5, lane_mid, arrow_len, ARROW_WIDTH / ARROW_FILL.x, ARROWS[arm["arrow"]], false)
	# Yağ / lastik izleri: araçların beklediği yerde (oklarla çakışmadan), şerit içinde hafif savruk
	for k: int in 2:
		var at_out: float = _rng.randf_range(0.50, 0.60) if k == 0 else _rng.randf_range(1.02, 1.3)
		var at_across: float = lane_mid + _rng.randf_range(-0.12, 0.12)
		var size: float = _rng.randf_range(0.09, 0.14) if k == 0 else _rng.randf_range(0.14, 0.22)
		_stain(_ground(out, at_out, at_across), size, _rng.randf_range(0.0, TAU), STAINS[_rng.randi() % STAINS.size()])


## Kolun yerel koordinatı → dünya: `out_dist` kavşak kenarından dışarı, `across` kolun enine ekseni (x ya da z).
func _ground(out: Vector2, out_dist: float, across: float) -> Vector3:
	if absf(out.x) > 0.5:
		var edge: float = BOX_LOW if out.x < 0.0 else BOX_HIGH
		return Vector3(edge + out.x * out_dist, MARK_Y, across)
	var edge_z: float = BOX_LOW if out.y < 0.0 else BOX_HIGH
	return Vector3(across, MARK_Y, edge_z + out.y * out_dist)


## Kola hizalı dörtgen: dokunun ÜSTÜ (v0) kavşağa bakan kenar, sol (u0) enine eksenin küçük ucu (`flip` ters).
func _decal(out: Vector2, out_mid: float, across_mid: float, depth: float, width: float, rect: Rect2, flip: bool) -> void:
	var inner_a: Vector3 = _ground(out, out_mid - depth * 0.5, across_mid - width * 0.5)
	var inner_b: Vector3 = _ground(out, out_mid - depth * 0.5, across_mid + width * 0.5)
	var outer_b: Vector3 = _ground(out, out_mid + depth * 0.5, across_mid + width * 0.5)
	var outer_a: Vector3 = _ground(out, out_mid + depth * 0.5, across_mid - width * 0.5)
	var u0: float = rect.position.x / ATLAS_SIZE
	var u1: float = rect.end.x / ATLAS_SIZE
	if flip:
		var t: float = u0
		u0 = u1
		u1 = t
	var v0: float = rect.position.y / ATLAS_SIZE
	var v1: float = rect.end.y / ATLAS_SIZE
	_quad([inner_a, inner_b, outer_b, outer_a], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


## Çubuk (dur / orta çizgi): dokuda uzun kenar YATAY (u). `lengthwise` true → çubuk kol boyunca uzanır.
func _bar(out: Vector2, out_mid: float, across_mid: float, along: float, across: float, rect: Rect2, lengthwise: bool) -> void:
	var a: Vector3 = _ground(out, out_mid - along * 0.5, across_mid - across * 0.5)
	var b: Vector3 = _ground(out, out_mid - along * 0.5, across_mid + across * 0.5)
	var c: Vector3 = _ground(out, out_mid + along * 0.5, across_mid + across * 0.5)
	var d: Vector3 = _ground(out, out_mid + along * 0.5, across_mid - across * 0.5)
	var u0: float = rect.position.x / ATLAS_SIZE
	var u1: float = rect.end.x / ATLAS_SIZE
	var v0: float = rect.position.y / ATLAS_SIZE
	var v1: float = rect.end.y / ATLAS_SIZE
	if lengthwise:   # dokunun uzun ekseni (u) kol boyunca
		_quad([a, b, c, d], [Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0)])
	else:            # uzun eksen enine
		_quad([a, b, c, d], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


func _stain(center: Vector3, size: float, angle: float, rect: Rect2) -> void:
	var corners: Array[Vector3] = []
	for offset: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var r: Vector2 = offset.rotated(angle) * size * 0.5
		corners.append(Vector3(center.x + r.x, MARK_Y - 0.0003, center.z + r.y))   # boyanın biraz altında
	var u0: float = rect.position.x / ATLAS_SIZE
	var u1: float = rect.end.x / ATLAS_SIZE
	var v0: float = rect.position.y / ATLAS_SIZE
	var v1: float = rect.end.y / ATLAS_SIZE
	_quad(corners, [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])


func _quad(p: Array, uv: Array) -> void:
	for i: int in [0, 1, 2, 0, 2, 3]:
		_st.set_normal(Vector3.UP)
		_st.set_uv(uv[i])
		_st.add_vertex(p[i])


func _material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_texture = load(ATLAS_PATH) as Texture2D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED   # yere yatık; yüz yönü önemsiz
	m.roughness = 0.9
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
