class_name PerformanceBayDisplay
extends Node3D
## PARÇA TAKILAN ARAÇ — tamir alanının liftinde oyuncunun aracı (kendi boyasıyla), üstünde kalan süre balonu
## ("12:34"); süre dolunca "HAZIR" ve hafif parıltı. Oyuncu dokununca (CarHitbox seçimi) PerformanceBays
## parçayı takar ve finish() oynar: kıvılcım, lift iner, araç küçülerek alandan çıkar.
## CarSpot'un çocuğudur: alan taşınınca / döndürülünce birlikte gider (RestorationDisplay gibi).

signal left      # alan boşaldı (çıkış animasyonu bitti)
signal arrived   # alana girdi (giriş animasyonu bitti; lift kalkabilir)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")
## Şehirde araç ölçeği (TrafficManager.model_scale): lifteki müşteri araçlarıyla aynı boy.
const CITY_SCALE: float = 0.6
const BUBBLE_GAP: float = 0.04
const DRIVE_DISTANCE: float = 0.55
const DRIVE_TIME: float = 0.6

var vehicle_id: StringName = &""
var bay: int = -1
var model: Node3D
var rig: CarRig
var _box: AABB = AABB(Vector3(-0.15, 0.0, -0.3), Vector3(0.3, 0.25, 0.6))
var _bubble: CarBubble
var _text: String = ""
var _ready_shown: bool = false
var _leaving: bool = false
## Giriş animasyonu bekleniyor / sürüyor: balon gizli (PerformanceBays.present).
var arriving: bool = false


func setup(id: StringName, bay_index: int) -> void:
	vehicle_id = id
	bay = bay_index
	name = "PerformanceInstall_%s" % id


func _ready() -> void:
	var path: String = CarCatalog.scene_path(vehicle_id)
	if path != "":
		model = (load(path) as PackedScene).instantiate() as Node3D
		model.scale = Vector3.ONE * CITY_SCALE * CarCatalog.model_scale(vehicle_id)
		add_child(model)
		rig = CarRig.new(model)
		rig.apply(CarAppearance.get_for(path))
		rig.set_lod_bias(CarRig.LOD_BIAS_NPC)
		CarShadow.attach(self, model)   # liftteki araç pişmiş haritaya girmez (giriş / çıkış animasyonu)
		_box = _model_box()
	_add_hitbox()
	_bubble = CarBubble.new()
	_bubble.position = Vector3(0.0, _box.end.y + BUBBLE_GAP + CarBubble.HEIGHT * 0.5, 0.0)
	add_child(_bubble)


## Kalan süre (sn) ve HAZIR durumu: balon yalnızca yazı değişince yeniden kurulur.
func show_time(remaining: float) -> void:
	if _leaving or arriving or _bubble == null:
		return
	var text: String = Loc.t("HAZIR") if remaining <= 0.0 else countdown(remaining)
	if text == _text:
		return
	_text = text
	_bubble.show_text(text, CarBubble.GLYPH_WRENCH)
	if remaining <= 0.0 and not _ready_shown:
		_ready_shown = true
		sparkle()


## YÜKSELT sonrası giriş: araç alanın önünden küçükten büyüyerek lifte sürülür → arrived (lift sonra kalkar).
func arrive() -> void:
	arriving = true
	visible = true
	var rest: Vector3 = position
	var forward: Vector3 = basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.001 else Vector3.BACK
	position = rest + forward * DRIVE_DISTANCE
	var full: Vector3 = scale
	scale = full * 0.01
	var tween: Tween = create_tween()
	tween.tween_property(self, "position", rest, DRIVE_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", full, DRIVE_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tween.finished
	arrived.emit()


## Lift kalktı: balon görünür, kısa kıvılcım.
func settle() -> void:
	arriving = false
	_text = ""
	sparkle()


## "4:05" / "1:02:30" (saat varsa).
static func countdown(seconds: float) -> String:
	var total: int = ceili(seconds)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	return "%d:%02d:%02d" % [h, m, s] if h > 0 else "%d:%02d" % [m, s]


## Parça takıldı: kıvılcım, lift iner, araç burnunun yönünde küçülerek çıkar → left.
func finish() -> void:
	if _leaving:
		return
	_leaving = true
	_clear_selection()
	if _bubble:
		_bubble.queue_free()
		_bubble = null
	sparkle()
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.lower_lift(bay)
		await get_tree().create_timer(RepairLift.LOWER_TIME).timeout
	if not is_inside_tree():
		return
	var forward: Vector3 = global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.001 else Vector3.BACK
	var tween: Tween = create_tween()
	tween.tween_property(self, "global_position", global_position + forward * DRIVE_DISTANCE, DRIVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "scale", scale * 0.01, DRIVE_TIME) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	left.emit()


func is_leaving() -> bool:
	return _leaving


func world_box() -> AABB:
	return global_transform * _box


func _clear_selection() -> void:
	for node_name: String in ["CarHitbox", "SelectionRing"]:
		var node: Node = get_node_or_null(node_name)
		if node:
			node.queue_free()
	if CarHitboxScript.get(&"selected_car") == self:
		CarHitboxScript.set(&"selected_car", null)


## Aracın kutusu (bu düğümün uzayında): seçim kutusu, balon yüksekliği.
func _model_box() -> AABB:
	var box: AABB = AABB()
	var first: bool = true
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = node as MeshInstance3D
		var local: Transform3D = global_transform.affine_inverse() * mi.global_transform if is_inside_tree() \
			else model.transform * mi.transform
		var b: AABB = local * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box if not first else _box


## Seçim: TrafficVehicle._add_hitbox ile aynı (SelectionRing önce eklenmeli: car_hitbox _ready'de arar).
func _add_hitbox() -> void:
	var ring: MeshInstance3D = MeshInstance3D.new()
	ring.name = "SelectionRing"
	ring.position = Vector3(0.0, _box.size.y, 0.0)
	ring.visible = false
	add_child(ring)
	var hitbox: StaticBody3D = StaticBody3D.new()
	hitbox.name = "CarHitbox"
	hitbox.set_script(CarHitboxScript)
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = _box.size
	shape.shape = box_shape
	shape.position = _box.get_center()
	hitbox.add_child(shape)
	add_child(hitbox)


## Aracın üstünde kısa kıvılcım yağmuru (amber).
func sparkle() -> void:
	var sparks: CPUParticles3D = CPUParticles3D.new()
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.025, 0.025)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	quad.material = material
	sparks.mesh = quad
	sparks.one_shot = true
	sparks.amount = 40
	sparks.lifetime = 1.2
	sparks.explosiveness = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 60.0
	sparks.initial_velocity_min = 0.4
	sparks.initial_velocity_max = 0.9
	sparks.gravity = Vector3(0.0, -1.2, 0.0)
	var ramp: Gradient = Gradient.new()
	ramp.set_color(0, Color("FFE08A"))
	ramp.set_color(1, Color(1.0, 0.75, 0.3, 0.0))
	sparks.color_ramp = ramp
	sparks.position = Vector3(0.0, _box.end.y, 0.0)
	add_child(sparks)
	sparks.emitting = true
	sparks.finished.connect(sparks.queue_free)
