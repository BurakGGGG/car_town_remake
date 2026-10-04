class_name GarageDecorView
extends Node3D
## GARAJDAKİ DEKORASYONUN DÜNYADAKİ KARŞILIĞI.
##
## Burası ana ekrandaki gerçek oyuncu garajıdır (yukarıdan izometrik görülen avlu + sol ve arka
## duvar); ayrı bir dekor sahnesi yok. DecorManager'daki her örnek burada bir gövdedir.
## Görev dağılımı:
##   DecorManager      — depo + örnek kayıtları (geometri bilmez)
##   DecorArea         — yerleşim geometrisi ve kuralları (saf)
##   GarageDecorView   — sahneden ölçüm, gövdeler, seçim, geçerlilik (bu dosya)
##   GarageEditor      — düzenleme modu: girdi, hayalet, seçim, geri al
## Kodla kurulur (GarageSystem altına), sahne dosyası düzenlenmez.

## Eşya gövdeleri garaj İÇİ ölçüsünde üretilir (orada araç ~1,0 birim); dünyada araç 0,6 birim
## olduğu için bu katsayı onları dünya ölçeğine indirir (kanepe ≈ 2,2 m, dolap ≈ 1,6 m).
const WORLD_SCALE: float = DecorBuilder.PLACER_SCALE
## Seçim kutusunun en küçük kenarı (dünya birimi). Varsayılan zumda 1 birim ≈ 200 tuval birimi;
## 0,07'lik bir bidon 14 birim olurdu — parmakla seçilemez. Şişirilmiş kutular çakışırsa gerçek
## kutusuna ilk değen, o da yoksa merkezi dokunuşa en yakın eşya seçilir.
const MIN_PICK: float = 0.16
## Tamir alanı çevresinde bırakılan pay (park eden araç alanın biraz dışına taşıyor).
const OBSTACLE_MARGIN: float = 0.03
## İç duvar, dış duvara bu kadardan yakın paralel örülemez (iki duvar üst üste binerdi).
const WALL_CLEARANCE: float = 0.04
const FLOOR_SHADER: Shader = preload("res://vfx/floor_tiles.gdshader")

signal area_changed

var _decor: DecorManager
var _garage: Node3D
var _root: Node3D
var _bodies: Dictionary = {}   # iid → Node3D
var _area: DecorArea = DecorArea.new()
var _editing: bool = false
var _blocked: Node3D
## Tamir alanı OLMAYAN engeller (tabela izi, teslimat kasaları): tamir alanı taşınırken kendi
## izi engel sayılmasın diye ayrı tutulur.
var _fixed_obstacles: Array[Rect2] = []
var _content_top: float = 0.4
## Dekorasyon v2: zemin karoları (tek shader + veri dokusu) ve iç duvarlar.
var _walls: InteriorWalls
var _floor_mat: ShaderMaterial
var _tile_image: Image
var _tile_texture: ImageTexture
var _pattern_ids: Array[StringName] = []


func _ready() -> void:
	name = "GarageDecorView"
	add_to_group("garage_decor_view")
	_root = Node3D.new()
	_root.name = "DecorBodies"
	add_child(_root)
	_walls = InteriorWalls.new()
	add_child(_walls)
	_connect.call_deferred()


func _connect() -> void:
	_garage = get_tree().get_first_node_in_group("garage_system") as Node3D
	_decor = get_tree().get_first_node_in_group("decor") as DecorManager
	if _decor and not _decor.placement_changed.is_connected(refresh):
		_decor.placement_changed.connect(refresh)
	if _decor and not _decor.tiles_changed.is_connected(_update_tiles):
		_decor.tiles_changed.connect(_update_tiles)
	_setup_floor()
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	if upgrades and not upgrades.levels_changed.is_connected(refresh):
		upgrades.levels_changed.connect(refresh)
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership and not ownership.paint_changed.is_connected(_on_paint_changed):
		ownership.paint_changed.connect(_on_paint_changed)
	var bays: Node = get_tree().get_first_node_in_group("repair_bays")
	if bays and bays.has_signal(&"bays_changed") and not bays.is_connected(&"bays_changed", refresh):
		bays.connect(&"bays_changed", refresh)
	if bays and bays.has_signal(&"layout_changed") and not bays.is_connected(&"layout_changed", refresh):
		bays.connect(&"layout_changed", refresh)
	refresh()


# --- Alan ----------------------------------------------------------------------------

func area() -> DecorArea:
	return _area


## Garajın zemin dikdörtgeni (dünya X/Z): sağ/ön kenar sabit, seviyeyle -x ve -z yönüne büyür.
func lot_rect() -> Rect2:
	if _garage == null:
		return Rect2(Vector2(-2.2, -1.7), Vector2(2.0, 1.5))
	var level: int = int(_garage.get("current_level"))
	var widths: Array = _garage.get("level_widths")
	var depths: Array = _garage.get("level_depths")
	var w: float = float(widths[clampi(level, 0, widths.size() - 1)])
	var d: float = float(depths[clampi(level, 0, depths.size() - 1)])
	return Rect2(Vector2(-0.2 - w, -0.2 - d), Vector2(w, d))


## Yerleşim alanını SAHNEDEN ölçer: duvarların gerçek iç yüzleri, zeminin üst yüzü, engeller.
## (Formülden türetmek yerine ölçüm: duvar kalınlığı / konumu sahnede değişirse kurallar izler.)
func _rebuild_area() -> void:
	var a: DecorArea = DecorArea.new()
	var lot: Rect2 = lot_rect()
	a.floor_y = 0.01
	a.left_face_x = lot.position.x + 0.025
	a.back_face_z = lot.position.y + 0.05
	a.wall_top = 0.405
	if _garage:
		var floor_box: AABB = _tree_box(_garage.get_node_or_null("Floor/GarageFloor"))
		if floor_box.size != Vector3.ZERO:
			a.floor_y = floor_box.end.y
		var left: AABB = _tree_box(_garage.get_node_or_null("Walls/GarageLeftWall"))
		if left.size != Vector3.ZERO:
			a.left_face_x = left.end.x
			a.wall_top = left.end.y
		var back: AABB = _tree_box(_garage.get_node_or_null("Walls/GarageBackWall"))
		if back.size != Vector3.ZERO:
			a.back_face_z = back.end.z
	a.back_span = Vector2(a.left_face_x, lot.end.x)
	a.left_span = Vector2(a.back_face_z, lot.end.y)
	a.wall_mount_y = a.floor_y + (a.wall_top - a.floor_y) * 0.62
	a.floor_rect = Rect2(
		Vector2(a.left_face_x + DecorArea.WALL_GAP, a.back_face_z + DecorArea.WALL_GAP),
		Vector2(lot.end.x - DecorArea.EDGE_GAP - (a.left_face_x + DecorArea.WALL_GAP),
			lot.end.y - DecorArea.EDGE_GAP - (a.back_face_z + DecorArea.WALL_GAP)))
	var obstacles: Array[Rect2] = []
	var fixed: Array[Rect2] = []
	var bays: Node = get_tree().get_first_node_in_group("repair_bays")
	if bays and bays.has_method("revealed_spots"):
		for spot: Node3D in bays.call("revealed_spots"):
			var box: AABB = _tree_box(spot)
			if box.size != Vector3.ZERO:
				obstacles.append(Rect2(Vector2(box.position.x, box.position.z),
					Vector2(box.size.x, box.size.z)).grow(OBSTACLE_MARGIN))
	# Teslimat kasaları dekorasyon DEĞİLDİR (DecorManager'da yoktur) ama yer kaplar: dekor onların
	# üstüne konamaz. Kasa açılınca iz kalkar (CrateDelivery refresh çağırır).
	var delivery: Node = get_tree().get_first_node_in_group("crate_delivery")
	if delivery and delivery.has_method("occupied_rects"):
		for rect: Rect2 in delivery.call("occupied_rects"):
			obstacles.append(rect.grow(OBSTACLE_MARGIN))
			fixed.append(rect.grow(OBSTACLE_MARGIN))
	a.obstacles = obstacles
	_fixed_obstacles = fixed
	# Izgara sabit ön-sağ köşeye bağlı (DecorGrid): karolar, duvarlar ve eşya oturtma aynı çizgileri kullanır
	a.grid_origin = DecorGrid.CORNER
	if _decor:
		var walls: Dictionary = _decor.walls()
		for key: String in walls:
			var seg: Dictionary = InteriorWalls.segment(key, walls, wall_clip(a), false)
			if not seg.is_empty():
				a.wall_rects.append(_seg_rect(seg))
		a.inner_faces = _inner_faces(walls, a)
	_area = a


# --- Eşitleme -------------------------------------------------------------------------

## Sergilenen aracın boyası değişti: gövdesi yeniden kurulur (refresh yeni boyayla üretir).
func _on_paint_changed(_vehicle: StringName, _color: Color) -> void:
	for iid: String in _bodies.keys():
		var inst: Dictionary = _decor.instance(iid) if _decor else {}
		if not inst.is_empty() and GarageDecor.is_vehicle(inst["item"]):
			var body: Node3D = _bodies[iid]
			if is_instance_valid(body):
				body.queue_free()
			_bodies.erase(iid)
	refresh()


## Gövdeleri DecorManager ile eşitler: yeni örnek kurulur, silinen kaldırılır, hepsinin dönüşümü
## güncellenir (duvar eşyası güncel duvara yeniden oturur). Baştan kurmaz.
func refresh() -> void:
	if _decor == null:
		return
	_rebuild_area()
	_apply_surfaces()
	if _walls:
		_walls.rebuild(_decor.walls(), _area.floor_y, _area.wall_top, wall_clip())
	var alive: Dictionary = {}
	for inst: Dictionary in _decor.instances():
		var iid: String = inst["iid"]
		alive[iid] = true
		var body: Node3D = _bodies.get(iid)
		if body == null or not is_instance_valid(body):
			body = make_body(inst["item"])
			if body == null:
				continue
			body.name = iid
			_root.add_child(body)
			_bodies[iid] = body
		body.transform = transform_for(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y),
			(inst["scale"] as Vector3).x)
	for iid: String in _bodies.keys():
		if not alive.has(iid):
			var body: Node3D = _bodies[iid]
			if is_instance_valid(body):
				body.queue_free()
			_bodies.erase(iid)
	_content_top = _area.wall_top
	for iid: String in _bodies:
		var placed: Node3D = body_of(iid)
		if placed:
			_content_top = maxf(_content_top, _tree_box(placed).end.y)
	if _editing:
		_draw_blocked()
	area_changed.emit()


## Garajdaki en yüksek şeyin üst kotu: duvar tepesi ya da en uzun eşya (hayalet dahil). Düzenleme
## odağı garajın ekrandaki çizgisini bu yüksekliğe kadar alır — uzun ağacın tepesi bulanıklaşmasın.
func content_top() -> float:
	var ghost: Node3D = get_node_or_null("DecorGhost") as Node3D
	return maxf(_content_top, _tree_box(ghost).end.y) if ghost else _content_top


func body_of(iid: String) -> Node3D:
	var body: Node3D = _bodies.get(iid)
	return body if body != null and is_instance_valid(body) else null


## Yerleşime hazır gövde (dünya ölçeğinde). Hayalet de bununla kurulur.
func make_body(item: StringName) -> Node3D:
	var body: Node3D = DecorBuilder.build_placeable(item)
	if body == null:
		return null
	var scene_path: String = String(GarageDecor.get_item(item).get("gameplay_scene", ""))
	if scene_path != "" and ResourceLoader.exists(scene_path):
		# İşlevli eşya: oyun düğümü gövdenin ÇOCUĞU olur, dönüşümü onunla paylaşır.
		var packed: PackedScene = load(scene_path)
		if packed:
			body.add_child(packed.instantiate())
	return body


## Örneğin dünya dönüşümü. Zemin eşyası zemin üst yüzüne oturur; duvar eşyası GÜNCEL duvara
## yeniden asılır (garaj büyüyünce duvar geriye kayar, eşya havada kalmaz).
func transform_for(item: StringName, pos: Vector3, yaw: float, scale: float = 1.0) -> Transform3D:
	var p: Vector3 = pos
	if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
		p = _area.reattach_wall(pos, yaw, wall_width(item))
	else:
		p.y = _area.floor_y
	var basis: Basis = Basis(Vector3.UP, deg_to_rad(yaw)).scaled(Vector3.ONE * WORLD_SCALE * scale)
	return Transform3D(basis, p)


# --- Ölçüler ve kurallar ----------------------------------------------------------------

## Zemin izinin boyu (dünya birimi; x genişlik, y = z derinlik), yön 0°'de.
func footprint_size(item: StringName) -> Vector2:
	var s: Vector3 = DecorBuilder.local_size(item) * WORLD_SCALE
	return Vector2(s.x, s.z)


## Duvar eşyasının duvar boyunca genişliği (dünya birimi).
func wall_width(item: StringName) -> float:
	return DecorBuilder.local_size(item).x * WORLD_SCALE


func footprint(item: StringName, pos: Vector3, yaw: float) -> PackedVector2Array:
	return DecorArea.corners(Vector2(pos.x, pos.z), footprint_size(item), yaw)


## Bu eşya bu konum ve yönde yerleşebilir mi? `ignore` taşınan örneğin kendisidir.
func is_valid(item: StringName, pos: Vector3, yaw: float, ignore: String = "") -> bool:
	if _decor == null or not GarageDecor.exists(item):
		return false
	if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
		return _wall_valid(item, pos, yaw, ignore)
	var poly: PackedVector2Array = footprint(item, pos, yaw)
	if not _area.inside_floor(poly) or _area.hits_obstacle(poly) or _area.hits_wall(poly):
		return false
	for inst: Dictionary in _decor.instances():
		if inst["iid"] == ignore or GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
			continue
		var other: PackedVector2Array = footprint(inst["item"], inst["pos"],
			float((inst["rot"] as Vector3).y))
		if DecorArea.overlaps(poly, other):
			return false
	return true


## Tamir alanı bu konum ve yönde durabilir mi? Zemin içinde, tabela / kasa izine değmeden, başka
## görünen tamir alanına ya da zemin eşyasına binmeden. `index` taşınan alanın kendisidir.
func is_bay_valid(index: int, pos: Vector2, yaw: float) -> bool:
	var poly: PackedVector2Array = DecorArea.corners(pos, RepairBayManager.BAY_SIZE, yaw)
	if not _area.inside_floor(poly) or _area.hits_wall(poly):
		return false
	for rect: Rect2 in _fixed_obstacles:
		if DecorArea.overlaps(poly, DecorArea.rect_corners(rect)):
			return false
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		for i: int in bays.bay_count():
			if i != index and bays.is_bay_revealed(i) and DecorArea.overlaps(poly,
					DecorArea.corners(bays.bay_position(i), RepairBayManager.BAY_SIZE, bays.bay_yaw(i))):
				return false
	if _decor:
		for inst: Dictionary in _decor.instances():
			if GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
				continue
			if DecorArea.overlaps(poly, footprint(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y))):
				return false
	return true


## Satın alınan tamir alanı için ilk geçerli yer: önce varsayılan yeri, sonra zemini ızgara adımıyla
## (ön-sağ köşeden arka-sola) iki yönde tarar. Yer yoksa boş sözlük döner.
func find_bay_spot(index: int) -> Dictionary:
	_rebuild_area()
	var defaults: Array[Vector2] = RepairBayManager.DEFAULT_POSITIONS
	var default_pos: Vector2 = defaults[mini(index, defaults.size() - 1)]
	if is_bay_valid(index, default_pos, RepairBayManager.DEFAULT_YAW):
		return {"pos": default_pos, "yaw": RepairBayManager.DEFAULT_YAW}
	var rect: Rect2 = _area.floor_rect
	var step: float = 0.1
	for yaw: float in [RepairBayManager.DEFAULT_YAW, 0.0]:
		var z: float = rect.end.y
		while z > rect.position.y:
			var x: float = rect.end.x
			while x > rect.position.x:
				var p: Vector2 = _area.snap(Vector2(x, z), step)
				if is_bay_valid(index, p, yaw):
					return {"pos": p, "yaw": yaw}
				x -= step
			z -= step
	return {}


## Seçim kimliği "bay:N" ise N, değilse -1 (tamir alanları dekor örnekleriyle aynı seçim yolundan geçer).
static func bay_index_of(iid: String) -> int:
	return int(iid.substr(4)) if iid.begins_with("bay:") else -1


func _wall_valid(item: StringName, pos: Vector3, yaw: float, ignore: String) -> bool:
	var width: float = wall_width(item)
	var f: Dictionary = _area.face_of(pos, yaw)
	var span: Vector2 = f["span"]
	var mine: Vector2 = DecorArea.wall_interval(pos, yaw, width)
	if mine.x < span.x - 1e-4 or mine.y > span.y + 1e-4:
		return false
	for inst: Dictionary in _decor.instances():
		if inst["iid"] == ignore or GarageDecor.placement(inst["item"]) != GarageDecor.PLACE_WALL:
			continue
		var other_yaw: float = float((inst["rot"] as Vector3).y)
		if String(_area.face_of(_area.reattach_wall(inst["pos"], other_yaw, wall_width(inst["item"])),
				other_yaw)["id"]) != String(f["id"]):
			continue
		var other: Vector2 = DecorArea.wall_interval(
			_area.reattach_wall(inst["pos"], other_yaw, wall_width(inst["item"])), other_yaw,
			wall_width(inst["item"]))
		if mine.x < other.y - DecorArea.TOUCH_EPS and other.x < mine.y - DecorArea.TOUCH_EPS:
			return false
	return true


## Zemindeki işaret noktasından eşyanın konumu (ve duvar eşyasında yönü).
## Zemin eşyası: ızgara açıksa ızgaraya oturur, yön değişmez. Duvar eşyası: en yakın duvara asılır.
func place_point(item: StringName, ground: Vector2, yaw: float, snap_step: float) -> Dictionary:
	if GarageDecor.placement(item) == GarageDecor.PLACE_WALL:
		var mount: Dictionary = _area.wall_mount(ground, wall_width(item))
		return {"pos": mount["position"], "yaw": float(mount["yaw"])}
	var p: Vector2 = _area.snap(ground, snap_step)
	return {"pos": Vector3(p.x, _area.floor_y, p.y), "yaw": yaw}


# --- Seçim ---------------------------------------------------------------------------

## Ekran noktasının altındaki örnek (yoksa ""). Önce ışının GERÇEKTEN değdiği (üçgen düzeyinde)
## en öndeki eşya; hiçbirine değmiyorsa şişirilmiş kutusuna değenler içinde merkezi ışına en
## yakın olan (küçük / ince eşya parmakla da tutulsun).
## Kutu seçimi yetmiyordu: sıkışık dizilişte uzun ya da içi boş eşyaların (araç lifti, su deposu)
## kutusu arkadakinin üstüne biniyor, dokunulan eşya yerine öndeki seçiliyordu — görsel QA'da
## 29 eşyanın 15'i ekrandaki ortasından seçilemiyordu.
func pick(camera: Camera3D, screen: Vector2) -> String:
	var all: Array[String] = pick_all(camera, screen)
	return all[0] if not all.is_empty() else ""


## Ekran noktasının altındaki BÜTÜN örnekler, önden arkaya: önce ışının gerçekten değdikleri
## (değme mesafesine göre), sonra yalnızca şişirilmiş kutusuna değenler (merkezi ışına yakınlığa
## göre). Düzenleyici aynı noktaya yeniden dokunulunca sıradakini seçer: sıkışık dizilişte
## öndekilerin tamamen örttüğü küçük eşyaya da ulaşılır (görsel QA'da 29 eşyanın 3'ü böyleydi).
func pick_all(camera: Camera3D, screen: Vector2) -> Array[String]:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	var hits: Array[Array] = []   # [t, iid]
	var near: Array[Array] = []   # [uzaklık, iid]
	for iid: String in _bodies:
		var body: Node3D = body_of(iid)
		if body == null or not body.is_visible_in_tree():
			continue
		var box: AABB = _tree_box(body)
		var t: float = _ray_body(origin, dir, body) if _ray_box(origin, dir, box) < INF else INF
		if t < INF:
			hits.append([t, iid])
			continue
		var grow: Vector3 = (Vector3.ONE * MIN_PICK - box.size).max(Vector3.ZERO) * 0.5
		if _ray_box(origin, dir, AABB(box.position - grow, box.size + grow * 2.0)) < INF:
			near.append([(box.get_center() - origin).cross(dir).length(), iid])
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		for i: int in bays.bay_count():
			var node: Node3D = bays.bay_node(i)
			if node == null or not bays.is_bay_revealed(i) or not node.is_visible_in_tree():
				continue
			var bay_box: AABB = _tree_box(node)
			var bt: float = _ray_box(origin, dir, bay_box)
			if bt < INF:
				hits.append([bt, "bay:%d" % i])
	hits.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	near.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var out: Array[String] = []
	for entry: Array in hits + near:
		out.append(entry[1])
	return out


## Işının y = zemin düzlemini kestiği nokta (X/Z). Kesmiyorsa Vector2.INF.
func ground_point(camera: Camera3D, screen: Vector2) -> Vector2:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	if absf(dir.y) < 1e-5:
		return Vector2.INF
	var t: float = (_area.floor_y - origin.y) / dir.y
	if t < 0.0:
		return Vector2.INF
	var hit: Vector3 = origin + dir * t
	return Vector2(hit.x, hit.z)


# --- Düzenleme görünümü ----------------------------------------------------------------

## Düzenleme modu: yerleştirme ızgarası ve eşya konamayan alanlar görünür olur, genişletme
## tabelası gizlenir (eşyaların önüne biniyor; izi yine de engel sayılır).
func set_editing(value: bool) -> void:
	_editing = value
	if _garage == null:
		return
	for path: String in ["BuildGrid/BuildGrid", "BuildGrid/BuildGrid/GridPreview"]:
		var node: Node = _garage.get_node_or_null(path)
		if node is Node3D:
			(node as Node3D).visible = value
	_draw_blocked()


## Eşya konamayan alanlar (tamir alanları, tabela izi): zeminde soluk kiremit rengi dikdörtgenler.
## Yalnızca düzenleme modunda; oyuncu "neden buraya koyamıyorum" diye tahmin etmek zorunda kalmasın.
func _draw_blocked() -> void:
	if _blocked and is_instance_valid(_blocked):
		_blocked.queue_free()
	_blocked = null
	if not _editing:
		return
	_blocked = Node3D.new()
	_blocked.name = "BlockedZones"
	add_child(_blocked)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.22, 0.18, 0.28)
	for rect: Rect2 in _area.obstacles:
		var zone: MeshInstance3D = MeshInstance3D.new()
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = rect.size
		zone.mesh = plane
		zone.material_override = mat
		zone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Kilitli tamir alanının koyu zemini (üstü zeminden 0,004 yukarıda) örtüyü yutuyordu:
		# örtü onun üstünde, sarı bariyer çıtalarının altında durur.
		zone.position = Vector3(rect.get_center().x, _area.floor_y + 0.008, rect.get_center().y)
		_blocked.add_child(zone)


func is_editing() -> bool:
	return _editing


## Görünen ızgaranın göz boyu (garage_system.gd GRID_CELL); ızgara düğümünden okunur.
func grid_cell() -> float:
	var grid: Node = _garage.get_node_or_null("BuildGrid/BuildGrid") if _garage else null
	return float(grid.get("cell_size")) if grid else 0.175


# --- Kaplamalar -----------------------------------------------------------------------

func _apply_surfaces() -> void:
	if _garage == null or _decor == null:
		return
	var floor_node: Node = _garage.get_node_or_null("Floor/GarageFloor")
	if floor_node is GeometryInstance3D and _floor_mat:
		(floor_node as GeometryInstance3D).material_override = _floor_mat
	var wall_id: StringName = _decor.surface(DecorManager.SURFACE_WALL)
	for path: String in ["Walls/GarageLeftWall", "Walls/GarageBackWall"]:
		var node: Node = _garage.get_node_or_null(path)
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).material_override = \
					DecorTextures.wall_material(wall_id) if wall_id != &"" else null


# --- Zemin karoları --------------------------------------------------------------------

## Zemin shader'ını kurar: desen dizisi katalog sırasıyla, varsayılan renk sahnedeki zeminden okunur.
func _setup_floor() -> void:
	if _floor_mat != null or _garage == null:
		return
	_pattern_ids.clear()
	for item: Dictionary in GarageDecor.items_in(GarageDecor.Kind.FLOOR_PATTERN):
		_pattern_ids.append(item["id"])
	_floor_mat = ShaderMaterial.new()
	_floor_mat.shader = FLOOR_SHADER
	_floor_mat.set_shader_parameter(&"patterns", DecorTextures.pattern_array(_pattern_ids))
	var rough: PackedFloat32Array = PackedFloat32Array()
	var metal: PackedFloat32Array = PackedFloat32Array()
	rough.resize(32)
	metal.resize(32)
	for k: int in mini(_pattern_ids.size(), 32):
		var sm: Vector2 = DecorTextures.pattern_surface(_pattern_ids[k])
		rough[k] = sm.x
		metal[k] = sm.y
	_floor_mat.set_shader_parameter(&"roughness_of", rough)
	_floor_mat.set_shader_parameter(&"metallic_of", metal)
	_floor_mat.set_shader_parameter(&"corner", DecorGrid.CORNER)
	_floor_mat.set_shader_parameter(&"cell", DecorGrid.CELL)
	_floor_mat.set_shader_parameter(&"grid_size", Vector2(DecorGrid.MAX_COLS, DecorGrid.MAX_ROWS))
	var floor_node: GeometryInstance3D = _garage.get_node_or_null("Floor/GarageFloor") as GeometryInstance3D
	if floor_node and floor_node.material_override is StandardMaterial3D:
		_floor_mat.set_shader_parameter(&"base_color",
			(floor_node.material_override as StandardMaterial3D).albedo_color)
	_tile_image = Image.create(DecorGrid.MAX_COLS, DecorGrid.MAX_ROWS, false, Image.FORMAT_R8)
	_tile_texture = ImageTexture.create_from_image(_tile_image)
	_floor_mat.set_shader_parameter(&"tile_index", _tile_texture)
	_update_tiles()


## Karo veri dokusunu DecorManager'dan yeniden yazar (32 × 21 bayt; boyama başına bir kez).
func _update_tiles() -> void:
	if _tile_image == null or _decor == null:
		return
	_tile_image.fill(Color(0, 0, 0))
	var tiles: Dictionary = _decor.tiles()
	for cell: Vector2i in tiles:
		var k: int = _pattern_ids.find(tiles[cell])
		if k >= 0 and DecorGrid.in_bounds(cell):
			_tile_image.set_pixel(cell.x, cell.y, Color8(k + 1, 0, 0))
	_tile_texture.update(_tile_image)


## Boyama önizlemesi: bu göz dikdörtgeni (dahil) zeminde vurgulanır. Boş dikdörtgen = kapalı.
func set_tile_preview(from: Vector2i, to: Vector2i, active: bool) -> void:
	if _floor_mat == null:
		return
	if not active:
		_floor_mat.set_shader_parameter(&"preview_rect", Vector4(-1, -1, -2, -2))
		return
	_floor_mat.set_shader_parameter(&"preview_rect", Vector4(mini(from.x, to.x), mini(from.y, to.y),
		maxi(from.x, to.x), maxi(from.y, to.y)))


## Bu göz boyanabilir mi? (Garaj zemininin içinde kalan ya da ona değen gözler.)
func tile_valid(cell: Vector2i) -> bool:
	if not DecorGrid.in_bounds(cell):
		return false
	var lot: Rect2 = lot_rect()
	var r: Rect2 = DecorGrid.cell_rect(cell)
	return r.end.x > lot.position.x + 0.01 and r.end.y > lot.position.y + 0.01 \
		and r.position.x < lot.end.x - 0.001 and r.position.y < lot.end.y - 0.001


## Zemindeki noktanın gözü (garaj dışındaysa Vector2i(-1, -1)).
func tile_at(ground: Vector2) -> Vector2i:
	var c: Vector2i = DecorGrid.cell_of(ground)
	return c if tile_valid(c) else Vector2i(-1, -1)


## Kova: aynı desenli, birbirine komşu gözleri doldurur; iç duvarlar sınırdır (oda doldurma).
func flood_cells(start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not tile_valid(start) or _decor == null:
		return out
	var target: StringName = _decor.tile(start)
	var walls: Dictionary = _decor.walls()
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		out.append(c)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + step
			if seen.has(n) or not tile_valid(n) or _decor.tile(n) != target:
				continue
			if walls.has(_edge_between(c, n)):
				continue
			seen[n] = true
			queue.append(n)
	return out


## İki komşu gözü ayıran kenarın anahtarı.
static func _edge_between(a: Vector2i, b: Vector2i) -> String:
	if a.x != b.x:   # yan yana (x'te): aradaki dikey çizgi = x-çizgisi max(a.x, b.x), z boyunca
		return DecorGrid.edge_key(&"z", maxi(a.x, b.x), a.y)
	return DecorGrid.edge_key(&"x", a.x, maxi(a.y, b.y))


# --- İç duvarlar -----------------------------------------------------------------------

func interior_walls() -> InteriorWalls:
	return _walls


## Segmentlerin kırpıldığı dikdörtgen: dış duvarların iç yüzlerinden garajın açık ön / sağ kenarına.
func wall_clip(a: DecorArea = null) -> Rect2:
	var area: DecorArea = a if a else _area
	var lot: Rect2 = lot_rect()
	return Rect2(Vector2(area.left_face_x, area.back_face_z),
		Vector2(lot.end.x - area.left_face_x, lot.end.y - area.back_face_z))


static func _seg_rect(seg: Dictionary) -> Rect2:
	var t: float = InteriorWalls.THICKNESS
	if seg["axis"] == &"x":
		return Rect2(Vector2(seg["from"], float(seg["line"]) - t * 0.5), Vector2(float(seg["to"]) - float(seg["from"]), t))
	return Rect2(Vector2(float(seg["line"]) - t * 0.5, seg["from"]), Vector2(t, float(seg["to"]) - float(seg["from"])))


## Duvar eşyası asılabilen iç yüzler: aynı çizgideki ardışık DÜZ duvar segmentleri tek yüz olur.
func _inner_faces(walls: Dictionary, a: DecorArea) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var clip: Rect2 = wall_clip(a)
	var lines: Dictionary = {}   # "x:b" / "z:a" → [[from, to], ...]
	for key: String in walls:
		if (walls[key] as Dictionary)["piece"] != &"wall_plain":
			continue
		var seg: Dictionary = InteriorWalls.segment(key, walls, clip, false)
		if seg.is_empty():
			continue
		var line_key: String = "%s:%.4f" % [seg["axis"], seg["line"]]
		if not lines.has(line_key):
			lines[line_key] = []
		(lines[line_key] as Array).append([float(seg["from"]), float(seg["to"]), seg["axis"], float(seg["line"])])
	for line_key: String in lines:
		var parts: Array = lines[line_key]
		parts.sort_custom(func(p: Array, q: Array) -> bool: return float(p[0]) < float(q[0]))
		var start: float = parts[0][0]
		var end: float = parts[0][1]
		for i: int in range(1, parts.size() + 1):
			if i < parts.size() and float(parts[i][0]) <= end + 1e-3:
				end = maxf(end, float(parts[i][1]))
				continue
			var axis: StringName = parts[0][2]
			var plane: float = float(parts[0][3]) + InteriorWalls.THICKNESS * 0.5
			out.append({"id": "%s@%.4f:%.4f" % [axis, plane, start], "axis": axis, "plane": plane,
				"span": Vector2(start, end), "yaw": 0.0 if axis == &"x" else 90.0})
			if i < parts.size():
				start = parts[i][0]
				end = parts[i][1]
	return out


## Bu kenara duvar örülebilir mi? Kenar garajın içinde (dış duvara paralel çok yakın değil), tamir
## alanı / kasa / zemin eşyası izine binmiyor. Kenarın başka parçayla değiştirilmesi serbesttir.
func wall_edge_valid(key: String) -> bool:
	if _decor == null:
		return false
	var e: Dictionary = DecorGrid.parse_edge(key)
	if e.is_empty() or int(e["a"]) < 0 or int(e["b"]) < 0:
		return false
	var seg: Dictionary = InteriorWalls.segment(key, {}, wall_clip(), false)
	if seg.is_empty():
		return false
	var line: float = seg["line"]
	if seg["axis"] == &"x":
		if line < _area.back_face_z + WALL_CLEARANCE or line > DecorGrid.CORNER.y + 1e-4:
			return false
	elif line < _area.left_face_x + WALL_CLEARANCE or line > DecorGrid.CORNER.x + 1e-4:
		return false
	var poly: PackedVector2Array = DecorArea.rect_corners(_seg_rect(seg).grow(-0.002))
	if _area.hits_obstacle(poly):
		return false
	for inst: Dictionary in _decor.instances():
		if GarageDecor.placement(inst["item"]) == GarageDecor.PLACE_WALL:
			continue
		if DecorArea.overlaps(poly, footprint(inst["item"], inst["pos"], float((inst["rot"] as Vector3).y))):
			return false
	return true


## Bu segmentlerin üstünde asılı duvar eşyaları (sökülmeden önce kaldırılmalı).
func items_on_walls(keys: Array[String]) -> Array[String]:
	var out: Array[String] = []
	if _decor == null:
		return out
	var walls: Dictionary = _decor.walls()
	for inst: Dictionary in _decor.instances():
		if GarageDecor.placement(inst["item"]) != GarageDecor.PLACE_WALL:
			continue
		var yaw: float = float((inst["rot"] as Vector3).y)
		var pos: Vector3 = inst["pos"]
		var f: Dictionary = _area.face_of(pos, yaw)
		if f["id"] == "back" or f["id"] == "left":
			continue
		var mine: Vector2 = DecorArea.wall_interval(pos, yaw, wall_width(inst["item"]))
		for key: String in keys:
			var seg: Dictionary = InteriorWalls.segment(key, walls, wall_clip(), false)
			if seg.is_empty() or seg["axis"] != f["axis"] \
					or absf(float(seg["line"]) + InteriorWalls.THICKNESS * 0.5 - float(f["plane"])) > 0.004:
				continue
			if mine.x < float(seg["to"]) - 1e-3 and float(seg["from"]) < mine.y - 1e-3:
				out.append(inst["iid"])
				break
	return out


## Ekran noktasındaki duvar: iç segment anahtarı, dış duvar ise "back" / "left", hiçbiri ise "".
func pick_wall(camera: Camera3D, screen: Vector2) -> String:
	var origin: Vector3 = camera.project_ray_origin(screen)
	var dir: Vector3 = camera.project_ray_normal(screen)
	var key: String = _walls.pick(origin, dir) if _walls else ""
	var best_t: float = _ray_box(origin, dir, _walls.box_of(key).grow(0.012)) if key != "" else INF
	for pair: Array in [["back", "Walls/GarageBackWall"], ["left", "Walls/GarageLeftWall"]]:
		var node: Node3D = _garage.get_node_or_null(pair[1]) as Node3D if _garage else null
		if node == null:
			continue
		var t: float = _ray_box(origin, dir, _tree_box(node))
		if t < best_t:
			best_t = t
			key = pair[0]
	return key


# --- Yardımcılar ----------------------------------------------------------------------

## Işının gövdenin üçgenlerine ilk değdiği mesafe (ışın parametresi; değmiyorsa INF). Her parça
## kendi yerel uzayında sınanır: önce parçanın kutusu, tutarsa üçgenleri. Dekor modelleri küçük
## (ölçüldü: en büyüğü 2.160 üçgen, ortalama 357) ve yalnızca kutusu ışınla kesişen birkaç eşya
## sınanır — dokunuş başına bir kez.
static func _ray_body(origin: Vector3, dir: Vector3, body: Node3D) -> float:
	var best: float = INF
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		var part: MeshInstance3D = node as MeshInstance3D
		if part == null or part.mesh == null or not part.is_visible_in_tree():
			continue
		var inv: Transform3D = part.global_transform.affine_inverse()
		var o: Vector3 = inv * origin
		var d: Vector3 = inv.basis * dir   # normalleştirilmez: t dünyadaki ışınla aynı ölçekte kalır
		if _ray_box(o, d, part.mesh.get_aabb()) == INF:
			continue
		var faces: PackedVector3Array = _faces_of(part.mesh)
		for i: int in range(0, faces.size() - 2, 3):
			var hit: Variant = Geometry3D.ray_intersects_triangle(o, d, faces[i], faces[i + 1], faces[i + 2])
			if hit != null:
				var t: float = ((hit as Vector3) - o).dot(d) / d.length_squared()
				if t >= 0.0 and t < best:
					best = t
	return best


## Modelin üçgenleri. .glb'den gelen ağlar örnekler arasında paylaşılır, bir kez okunur (en çok
## katalogdaki model sayısı kadar kayıt); kodla kurulan küçük ilkel ağlar önbelleğe alınmaz.
static var _faces: Dictionary = {}


static func _faces_of(mesh: Mesh) -> PackedVector3Array:
	if not (mesh is ArrayMesh):
		return mesh.get_faces()
	if not _faces.has(mesh):
		_faces[mesh] = mesh.get_faces()
	return _faces[mesh]


## Işın-kutu kesişimi (slab yöntemi): giriş mesafesi, kesmiyorsa INF.
static func _ray_box(origin: Vector3, dir: Vector3, box: AABB) -> float:
	var t0: float = -INF
	var t1: float = INF
	for axis: int in 3:
		var o: float = origin[axis]
		var d: float = dir[axis]
		var lo: float = box.position[axis]
		var hi: float = box.end[axis]
		if absf(d) < 1e-9:
			if o < lo or o > hi:
				return INF
			continue
		var a: float = (lo - o) / d
		var b: float = (hi - o) / d
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
		if t0 > t1:
			return INF
	return t0 if t1 >= 0.0 else INF


## Düğüm ağacındaki görünür geometrinin DÜNYA kutusu (8 köşe dönüştürülerek; ağaç sahnede olmalı).
static func _tree_box(root: Node) -> AABB:
	if root == null or not (root is Node3D) or not (root as Node3D).is_inside_tree():
		return AABB()
	var out: AABB = AABB()
	var first: bool = true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if not (node is VisualInstance3D):
			continue
		var vi: VisualInstance3D = node
		var local: AABB = vi.get_aabb()
		var xf: Transform3D = vi.global_transform
		for i: int in 8:
			var p: Vector3 = xf * (local.position + Vector3(
				local.size.x if (i & 1) else 0.0, local.size.y if (i & 2) else 0.0,
				local.size.z if (i & 4) else 0.0))
			if first:
				out = AABB(p, Vector3.ZERO)
				first = false
			else:
				out = out.expand(p)
	return out
