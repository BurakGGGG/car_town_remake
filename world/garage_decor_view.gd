class_name GarageDecorView
extends Node3D
## DIŞ AVLUDAKİ dekorasyon: satın alınan eşyaları garajın avlusuna yerleştirir.
##
## Car Town'daki "Edit Garage" karşılığı, ama bizde garajın İÇİ değil yukarıdan görünen AVLU
## döşeniyor (kullanıcı kararı): avlu garaj seviyesiyle büyüyor ve boş kalıyordu, artık
## büyütmek yeni yerleştirme yeri açıyor.
##
## Kodla kurulur (GarageSystem altına), sahne dosyası düzenlenmez. Eşya gövdeleri
## vfx/decor_builder.gd'den gelir; yuvalar gameplay/garage_decor.gd'de.

## Avluya dokunma kutusunun yerden yüksekliği.
const PICK_HEIGHT: float = 0.14
## Eşya gövdeleri garaj İÇİ ölçüsünde üretilir (orada araç ~1,0 birim). Dünyada araç 0,6 birim
## olduğu için aynı gövdeler aracın boyuna yaklaşıyordu (ölçüldü: kanepe 0,62 birim ≈ 4,5 m).
## Bu katsayı onları dünya ölçeğine indirir: kanepe ≈ 2,2 m, dolap ≈ 1,6 m.
const WORLD_SCALE: float = DecorBuilder.PLACER_SCALE

## Avluya dokunuldu (HUD düzenleme panosunu açar).
signal lot_clicked

var _decor: DecorManager
var _garage: Node3D
var _bodies: Node3D
var _pick: StaticBody3D
var _pick_shape: CollisionShape3D
var _editing: bool = false


func _ready() -> void:
	name = "GarageDecorView"
	add_to_group("garage_decor_view")
	_bodies = Node3D.new()
	_bodies.name = "DecorBodies"
	add_child(_bodies)
	_build_pick()
	_connect.call_deferred()


func _connect() -> void:
	_garage = get_tree().get_first_node_in_group("garage_system") as Node3D
	_decor = get_tree().get_first_node_in_group("decor") as DecorManager
	if _decor and not _decor.placement_changed.is_connected(refresh):
		_decor.placement_changed.connect(refresh)
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	if upgrades and not upgrades.levels_changed.is_connected(refresh):
		upgrades.levels_changed.connect(refresh)
	refresh()


# --- Avluya dokunma ------------------------------------------------------------------

func _build_pick() -> void:
	_pick = StaticBody3D.new()
	_pick.name = "LotPick"
	_pick.input_ray_pickable = true
	_pick_shape = CollisionShape3D.new()
	_pick_shape.shape = BoxShape3D.new()
	_pick.add_child(_pick_shape)
	_pick.input_event.connect(_on_pick_input)
	add_child(_pick)


func _on_pick_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3,
		_shape: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			lot_clicked.emit()


## Düzenleme modu: yerleştirme ızgarası görünür olur (normalde gizli prototip yardımcısı).
func set_editing(value: bool) -> void:
	_editing = value
	if _garage == null:
		return
	for path: String in ["BuildGrid/BuildGrid", "BuildGrid/BuildGrid/GridPreview"]:
		var node: Node = _garage.get_node_or_null(path)
		if node is Node3D:
			(node as Node3D).visible = value


# --- Yerleştirme ---------------------------------------------------------------------

## Avlunun dünya sınırları: sağ/ön kenar sabit, garaj seviyesiyle -x ve -z yönüne büyür.
func lot_rect() -> Rect2:
	if _garage == null:
		return Rect2(Vector2(-2.2, -1.7), Vector2(2.0, 1.5))
	var level: int = int(_garage.get("current_level"))
	var widths: Array = _garage.get("level_widths")
	var depths: Array = _garage.get("level_depths")
	var w: float = float(widths[clampi(level, 0, widths.size() - 1)])
	var d: float = float(depths[clampi(level, 0, depths.size() - 1)])
	return Rect2(Vector2(-0.2 - w, -0.2 - d), Vector2(w, d))


func refresh() -> void:
	if _decor == null:
		return
	for child: Node in _bodies.get_children():
		child.queue_free()
	var rect: Rect2 = lot_rect()
	_pick.position = Vector3(rect.get_center().x, PICK_HEIGHT * 0.5, rect.get_center().y)
	(_pick_shape.shape as BoxShape3D).size = Vector3(rect.size.x, PICK_HEIGHT, rect.size.y)

	var open: Array[StringName] = _decor.open_slots()
	for slot: StringName in _decor.placements():
		var id: StringName = _decor.item_at(slot)
		var kind: StringName = GarageDecor.slot_of(slot)
		if kind == GarageDecor.SLOT_FLOOR_SURFACE:
			_apply_floor(id)
			continue
		if kind == GarageDecor.SLOT_WALL_SURFACE:
			_apply_walls(id)
			continue
		if not open.has(slot):
			continue   # avlu henüz o kadar büyük değil: eşya depoda bekler
		var body: Node3D = DecorBuilder.build(id)
		if body == null:
			continue
		body.scale = Vector3.ONE * WORLD_SCALE
		if kind == GarageDecor.SLOT_FLOOR:
			body.position = _snap(GarageDecor.FLOOR_SLOTS[slot])
			body.rotation_degrees = Vector3(0.0, float(GarageDecor.FLOOR_SLOT_YAW[slot]), 0.0)
		else:
			body.position = _wall_slot_position(slot)
			body.rotation_degrees = Vector3(0.0, float(GarageDecor.WALL_SLOT_YAW[slot]), 0.0)
		_bodies.add_child(body)
		body.name = String(id)


## Eşyayı yerleştirme ızgarasının göz MERKEZİNE oturtur (ızgara avlunun ortasından kurulur).
func _snap(position: Vector3) -> Vector3:
	if _garage == null:
		return position
	# Göz boyu ızgara düğümünden okunur: `get()` sabitleri (const GRID_CELL) göremiyor,
	# bu yüzden eşyalar 0,0875'e göre hizalanıp ızgarayla (0,175) uyuşmuyordu.
	var grid: Node = _garage.get_node_or_null("BuildGrid/BuildGrid")
	var cell: float = float(grid.get("cell_size")) if grid else 0.175
	var rect: Rect2 = lot_rect()
	var origin: Vector2 = rect.position
	var gx: float = origin.x + (floorf((position.x - origin.x) / cell) + 0.5) * cell
	var gz: float = origin.y + (floorf((position.z - origin.y) / cell) + 0.5) * cell
	return Vector3(gx, position.y, gz)


## Duvar yuvası garajın ARKA duvarıyla birlikte kayar (duvar seviyeyle geriye gider).
func _wall_slot_position(slot: StringName) -> Vector3:
	var base: Vector3 = GarageDecor.WALL_SLOTS[slot]
	var rect: Rect2 = lot_rect()
	return Vector3(rect.position.x + rect.size.x * 0.5, base.y, rect.position.y + 0.06)


func _apply_floor(id: StringName) -> void:
	var material: StandardMaterial3D = DecorBuilder.floor_material(id)
	if material == null or _garage == null:
		return
	var floor_node: Node = _garage.get_node_or_null("Floor/GarageFloor")
	if floor_node is GeometryInstance3D:
		(floor_node as GeometryInstance3D).material_override = material


func _apply_walls(id: StringName) -> void:
	var material: StandardMaterial3D = DecorBuilder.wall_material(id)
	if material == null or _garage == null:
		return
	for path: String in ["Walls/GarageLeftWall", "Walls/GarageBackWall"]:
		var node: Node = _garage.get_node_or_null(path)
		if node is GeometryInstance3D:
			(node as GeometryInstance3D).material_override = material
