class_name WorldDressing
extends Node3D
## DÜNYANIN TAMAMLANMASI — sahne dosyası düzenlenmeden (CLAUDE.md) kodla kurulur, GarageSystem ekler.
##
## Garaj büyüdükçe kamera daha geniş alanı gösteriyor ve iki eksik görünüyordu (telefonda denendi):
##   1) YOLLAR dünyanın ortasında bitiyordu (batı / kuzey x, z = −6; 4. seviye garaj −8,2'ye uzanıyor).
##      Dört yol kolu, mevcut yollarla aynı ölçü ve renkte (asfalt, kaldırım, şerit çizgisi) kameranın
##      gidebileceği sınırın (WorldCamera.world_min/max) ötesine kadar uzatılır.
##   2) SHOWROOM binası yarımdı (doğu duvarı, arkası yoktu). Eski CSG galerinin görselleri gizlenir,
##      yerine Blender'da baştan kurulan bina gelir (assets/world/showroom.glb ← tools/world/showroom.py).
##      Tıklama kutusu (ShowroomHitbox) yeni binaya uydurulur, showroom ekranı eskisi gibi açılır.
##
## Trafiğin doğma / kaybolma noktaları yeni yol uçlarına taşınır; eski yerleri `core_position` olarak
## saklanır. TrafficManager kamera eski noktayı görmüyorsa aracı orada doğurur / siler: varsayılan
## görünümde yolculuk süresi ve müşteri sıklığı değişmez, oyuncu uzaklaşıp kenara baktığında da araç
## yolun ortasında birden belirmez.

## Dünya birimi / metre (araç 4,4 m = 0,6 birim) — showroom modeli metre ile kuruldu.
const METER: float = DecorBuilder.METER
## Parselin güneybatı köşesi (kavşağın kuzeydoğusu, iki kaldırımın hemen dışı).
const LOT_ORIGIN: Vector3 = Vector3(1.45, 0.0, -0.25)
const SHOWROOM_SCENE: String = "res://assets/world/showroom.glb"

## Mevcut yol ağı (Main.tscn): doğu-batı yolu z 0–1,2, kuzey-güney yolu x 0–1,2; genişlik 1,2.
const ROAD_CENTER: float = 0.6
const ROAD_HALF: float = 0.6
const SIDEWALK_OFFSET: float = 0.7
const SIDEWALK_SIZE: Vector2 = Vector2(0.2, 0.01)   # genişlik, yükseklik
const DASH_SIZE: Vector3 = Vector3(0.2, 0.002, 0.05)  # boy, yükseklik, en (doğu-batı yönünde)
const DASH_STEP: float = 0.4
## Yol kolları: [eksen (0 = x, 1 = z), yön (−1 / +1), asfaltın bittiği yer, kaldırımın bittiği yer,
## yeni uç]. Yeni uçlar kameranın gösterebildiği sınırın (x −10,8…8,9; z −9,2…10,5) ötesinde.
const ARMS: Array[Array] = [
	[0, -1, -6.0, -6.0, -11.6],   # batı
	[0, 1, 8.4, 7.2, 9.7],        # doğu
	[1, -1, -6.0, -6.0, -10.0],   # kuzey
	[1, 1, 7.2, 7.2, 11.2],       # güney
]
## Trafik uç noktası yeni yol ucundan bu kadar içeride durur.
const TRAFFIC_END_INSET: float = 0.3

## Tabelalar (dünya konumu, yön [derece, Y ekseni], yazı, renk, yazı boyu). Konumlar showroom.py'deki
## levhalardan: parsel metresi → dünya (x + LOT_ORIGIN.x, −y + LOT_ORIGIN.z) × METER.
const INK: Color = Color("2F3236")
const AMBER: Color = Color("F5BE4C")

var _traffic: TrafficManager
var _showroom: Node3D


func _ready() -> void:
	name = "WorldDressing"
	_build_roads()
	_traffic = _find_traffic(get_tree().current_scene)
	if _traffic:
		move_traffic_ends(_traffic)
	_build_showroom()
	add_child(CityScenery.new())


# --- Yollar ----------------------------------------------------------------------------------

func _build_roads() -> void:
	var asphalt: Material = _scene_material("RoadRight", Color("444444"))
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	# Mevcut CSG çizgileri malzemesiz (motorun varsayılanı); aynı ışıkta aynı tonu veren değer
	# ölçülerek bulundu (ekranda mevcut 128, 0,8 albedo 195 veriyordu).
	paint.albedo_color = Color(0.53, 0.53, 0.53)
	var dashes: Array[Transform3D] = []
	for arm: Array in ARMS:
		var axis: int = arm[0]
		var sign_dir: float = float(arm[1])
		var road_end: float = arm[2]
		var far: float = arm[4]
		# Asfalt: yolun bittiği yerden yeni uca
		var length: float = absf(far - road_end)
		var mid: float = (road_end + far) * 0.5
		_add_box("RoadExt", asphalt, _arm_size(axis, length, ROAD_HALF * 2.0, 0.0),
			_arm_pos(axis, mid, ROAD_CENTER, 0.0), true)
		# Kaldırımlar: iki yanda (doğu kolunda mevcut kaldırım asfalttan önce, 7,2'de bitiyor)
			# (Kaldırımlar artık CityScenery'de, yolun tamamı boyunca yükseltilmiş olarak kuruluyor.)
		# Şerit çizgileri: mevcut çizgilerin adımıyla (0,4) aynı dizide devam eder
		var first: float = _next_dash(axis, road_end, sign_dir)
		var at: float = first
		while (at - far) * sign_dir < -DASH_SIZE.x:
			var basis: Basis = Basis.IDENTITY if axis == 0 else Basis(Vector3.UP, PI * 0.5)
			dashes.append(Transform3D(basis, _arm_pos(axis, at, ROAD_CENTER, 0.001)))
			at += DASH_STEP * sign_dir
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	var dash_mesh: BoxMesh = BoxMesh.new()
	dash_mesh.size = DASH_SIZE
	dash_mesh.material = paint
	multi.mesh = dash_mesh
	multi.instance_count = dashes.size()
	for i: int in dashes.size():
		multi.set_instance_transform(i, dashes[i])
	var lines: MultiMeshInstance3D = MultiMeshInstance3D.new()
	lines.name = "LaneLinesExt"
	lines.multimesh = multi
	lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lines)


## Mevcut çizgilerin dizisi: doğu-batı çizgi merkezleri x ≡ −0,0137 (mod 0,4), kuzey-güney z ≡ 0,0104.
## Yolun bittiği yerden dışarı doğru ilk çizginin merkezi.
func _next_dash(axis: int, road_end: float, sign_dir: float) -> float:
	var phase: float = -0.0137 if axis == 0 else 0.0104
	var k: float = floorf((road_end - phase) / DASH_STEP)
	var at: float = phase + k * DASH_STEP
	while (at - road_end) * sign_dir < DASH_SIZE.x * 0.5 + 0.02:
		at += DASH_STEP * sign_dir
	return at


func _arm_size(axis: int, along: float, across: float, height: float) -> Vector3:
	return Vector3(along, height, across) if axis == 0 else Vector3(across, height, along)


func _arm_pos(axis: int, along: float, across: float, y: float) -> Vector3:
	return Vector3(along, y, across) if axis == 0 else Vector3(across, y, along)


func _add_box(label: String, material: Material, size: Vector3, pos: Vector3, flat: bool) -> void:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = label
	if flat:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(size.x, size.z)
		mesh_instance.mesh = plane
	else:
		var box: BoxMesh = BoxMesh.new()
		box.size = size
		mesh_instance.mesh = box
	mesh_instance.material_override = material
	mesh_instance.position = pos
	add_child(mesh_instance)


## Sahnedeki yolun kendi malzemesi (renk birebir tutsun); yoksa verilen renk.
func _scene_material(node_name: String, fallback: Color) -> Material:
	var road: MeshInstance3D = get_tree().current_scene.get_node_or_null(node_name) as MeshInstance3D
	if road:
		var material: Material = road.get_surface_override_material(0)
		if material == null:
			material = road.material_override
		if material:
			return material
	var made: StandardMaterial3D = StandardMaterial3D.new()
	made.albedo_color = fallback
	return made


# --- Trafik uç noktaları -------------------------------------------------------------------

## Doğma / kaybolma noktalarını yeni yol uçlarına taşır; eski konum `core_position` olur.
func move_traffic_ends(traffic: TrafficManager) -> void:
	for point: TrafficWaypoint in traffic.waypoints:
		if not (point.is_spawn or point.is_despawn) or point.has_meta(TrafficManager.CORE_META):
			continue
		var p: Vector3 = point.global_position
		var on_east_west: bool = absf(p.z - ROAD_CENTER) <= ROAD_HALF + 0.2
		var on_north_south: bool = absf(p.x - ROAD_CENTER) <= ROAD_HALF + 0.2
		var target: Vector3 = p
		for arm: Array in ARMS:
			var axis: int = arm[0]
			var sign_dir: float = float(arm[1])
			var coord: float = p.x if axis == 0 else p.z
			var on_arm: bool = on_east_west if axis == 0 else on_north_south
			if on_arm and (coord - ROAD_CENTER) * sign_dir > 1.0:
				var end: float = float(arm[4]) - TRAFFIC_END_INSET * sign_dir
				target = Vector3(end, p.y, p.z) if axis == 0 else Vector3(p.x, p.y, end)
		if not target.is_equal_approx(p):
			point.set_meta(TrafficManager.CORE_META, p)
			point.global_position = target


func _find_traffic(node: Node) -> TrafficManager:
	if node == null:
		return null
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null


# --- Showroom ------------------------------------------------------------------------------

func _build_showroom() -> void:
	var packed: PackedScene = load(SHOWROOM_SCENE) as PackedScene
	if packed == null:
		push_warning("WorldDressing: %s yüklenemedi; eski galeri kalıyor" % SHOWROOM_SCENE)
		return
	_showroom = packed.instantiate() as Node3D
	_showroom.name = "Showroom"
	_showroom.position = LOT_ORIGIN
	_showroom.scale = Vector3.ONE * METER
	add_child(_showroom)
	_add_signs()
	_retire_old_gallery()


## Tabela yazıları (levhalar modelde; yazı oyunun kalın yazısıyla, ışıktan etkilenmez).
func _add_signs() -> void:
	# Salonun güney ve doğu tabela bandı (çatı kenarında, koyu bant üstünde kehribar)
	_sign(Loc.t("SHOWROOM"), _lot(28.0, 9.52, 7.37), 0.0, AMBER, 0.00142, 64)
	_sign(Loc.t("SHOWROOM"), _lot(44.0, 23.0, 7.37), 90.0, AMBER, 0.00142, 64)
	# CAR PARTS bloğunun kehribar bandı (servis kapılarının üstü)
	_sign(Loc.t("CAR PARTS"), _lot(9.0, 12.72, 4.95), 0.0, INK, 0.00118, 64)
	# Köşe totemi: iki yüzde dikey, sıkı dizili harfler
	_sign("S\nH\nO\nW\nR\nO\nO\nM", _lot(3.1, 1.6, 4.1), 0.0, INK, 0.0013, 64, -0.18)
	_sign("C\nA\nR\n \nP\nA\nR\nT\nS", _lot(4.0, 2.3, 4.1), 90.0, INK, 0.00108, 64, -0.18)


func _sign(text: String, pos: Vector3, yaw: float, color: Color, pixel: float, size: int,
		line_spacing: float = 0.0) -> void:
	var font: FontVariation = FontVariation.new()
	font.variation_embolden = 0.8
	font.spacing_glyph = 3
	var label: Label3D = Label3D.new()
	label.text = text
	label.font = font
	label.font_size = size
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.double_sided = false
	label.line_spacing = line_spacing * size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Levhanın 3 mm önünde (z-kavgası olmasın); Label3D kendi +Z yönüne okunur
	label.basis = Basis(Vector3.UP, deg_to_rad(yaw))
	label.position = pos + label.basis.z * 0.003
	add_child(label)


## Parsel metresi (showroom.py: X doğu, Y kuzey, Z yukarı) → dünya konumu.
func _lot(x: float, y: float, z: float) -> Vector3:
	return LOT_ORIGIN + Vector3(x, z, -y) * METER


## Eski galerinin CSG görselleri gizlenir (Main.tscn'de duruyor; editörde silinebilir). Tıklama
## kutusu korunur ve yeni binanın salon + CAR PARTS gövdesine uydurulur.
func _retire_old_gallery() -> void:
	var gallery: Node = get_tree().current_scene.get_node_or_null("GrassArea/Gallery")
	if gallery == null:
		return
	for child: Node in gallery.get_children():
		if child is CSGShape3D:
			(child as CSGShape3D).visible = false
	var shape: CollisionShape3D = gallery.get_node_or_null("ShowroomHitbox/CollisionShape3D") as CollisionShape3D
	if shape and shape.shape is BoxShape3D:
		# Bina gövdesi (çatı dahil): parsel X 3–44, Y 9,6–33,6, Z 0–7,85
		var low: Vector3 = _lot(3.0, 33.6, 0.0)
		var high: Vector3 = _lot(44.2, 9.6, 7.85)
		var box: BoxShape3D = (shape.shape as BoxShape3D).duplicate() as BoxShape3D
		box.size = (high - low).abs()
		shape.shape = box
		shape.global_position = (low + high) * 0.5
