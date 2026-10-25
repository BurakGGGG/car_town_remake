class_name EventCarSpot
extends Node3D
## ÖDÜNÇ ETKİNLİK ARACI KALDIRIMDA (2026-10-26; kullanıcı: "tamire gelen araçların olduğu kaldırımın köşesinde, tam
## garajın köşesindeki kaldırımda; showrooma bakar şekilde park hâlinde"): süren etkinliğin aracı ödünçken
## (EventCar.is_loan) müşterilerin beklediği kuzey kaldırımda (doğu-batı yolu z 0–1,2; kaldırım z −0,2–0), garajın sağ-ön
## köşesinin dibinde (garaj büyüse de bu köşe (−0,2, −0,2)'de sabit), kavşak köşesine yakın durur; burnu doğuya, kavşağın
## karşısındaki showroom'a dönük. Müşteriler daha batıda (RepairWaitSpot x −2,8…) bekler, tamire ışınlanır: yol kesişmez.
## Gölgesini kendi taşır (CarShadow: pişmiş şehir gölgesine girmez, etkinlik başlayınca / bitince gelip gider). Üstünde koyu, amber kenarlı tabela "ÖDÜNÇ · ETKİNLİK ARACI / YARIŞ ▶ 2 / 3"; araca ya
## da tabelaya dokununca ETKİNLİK PANOSU açılır (clicked → Hud). Etkinlik bitince, araç kazanılınca ya da oyuncu aracın
## sahibiyse (kendi aracı garajında) kalkar. Dekorasyon değildir: garaj zeminine girmez, garaj değerine katılmaz.
## GarageSystem kurar (ziyarette yok), "event_car_spot" grubundan bulunur.

signal clicked

## Park yeri (dünya): kuzey kaldırımın ortası (z −0,1), burun kavşak köşesinin hemen önünde; burun doğuya (+X, showroom).
const PARK: Vector3 = Vector3(-0.34, 0.02, -0.1)
const YAW: float = PI * 0.5   # model önü +Z → doğu
const TAG_HEIGHT: float = 0.42
## Dokunma kutusu (aracın izi: boy doğu-batı yönünde).
const BODY_SIZE: Vector3 = Vector3(0.66, 0.3, 0.32)

var _event_car: EventCar
var _holder: Node3D
var _car: Node3D
var _car_id: StringName = &""
var _tag: Node3D
var _label: Label3D
var _body: StaticBody3D
var _spawning: bool = false


func _ready() -> void:
	name = "EventCarSpot"
	add_to_group("event_car_spot")
	_connect.call_deferred()


func _connect() -> void:
	_event_car = get_tree().get_first_node_in_group("event_car") as EventCar
	if _event_car:
		_event_car.changed.connect(_sync)
	# Etkinlik başlangıcı / bitişi bir sinyalle gelmez (saat): ara ara bakılır
	var timer: Timer = Timer.new()
	timer.wait_time = 2.0
	timer.timeout.connect(_sync)
	add_child(timer)
	timer.start()
	_sync()


func has_car() -> bool:
	return is_instance_valid(_car)


## Park edilmiş aracın dünya konumu (testler).
func car_position() -> Vector3:
	return _car.global_position if is_instance_valid(_car) else Vector3.INF


func _sync() -> void:
	var want: StringName = EventCar.car_id() if _event_car and _event_car.is_loan() else &""
	if want != _car_id and is_instance_valid(_car):
		_remove()
	if want == &"":
		return
	if is_instance_valid(_car):
		_update_tag()
		return
	if not _spawning:
		_spawn(want)


func _spawn(vehicle: StringName) -> void:
	_spawning = true
	var holder: Node3D = Node3D.new()
	holder.name = "EventCarHolder"
	add_child(holder)
	holder.global_position = PARK
	holder.global_rotation = Vector3(0.0, YAW, 0.0)
	var car: Node3D = await CrateDelivery.make_vehicle(holder, vehicle)
	_spawning = false
	if car == null or not is_inside_tree() or EventCar.car_id() != vehicle or not (_event_car and _event_car.is_loan()):
		holder.queue_free()
		return
	car.name = "EventCar"
	CarShadow.attach(holder, car)
	_holder = holder
	_car = car
	_car_id = vehicle
	_build_tag()
	_build_click_body()
	_update_tag()


func _remove() -> void:
	for node: Node in [_holder, _tag, _body]:
		if is_instance_valid(node):
			node.queue_free()
	_holder = null
	_car = null
	_tag = null
	_label = null
	_body = null
	_car_id = &""


## Aracın üstünde havada duran koyu tabela (etkinlik tabelasının dili): amber kenar, açık yazı. Dünya-UI katmanında.
func _build_tag() -> void:
	_tag = Node3D.new()
	_tag.name = "Tag"
	add_child(_tag)
	_tag.global_position = PARK + Vector3(0.0, TAG_HEIGHT, 0.0)
	for layer: Array in [[Vector2(0.72, 0.17), HudPalette.PLATE_SELECTED, 1], [Vector2(0.7, 0.15), Color("2D2A26"), 2]]:
		var board: MeshInstance3D = MeshInstance3D.new()
		var quad: QuadMesh = QuadMesh.new()
		quad.size = layer[0]
		board.mesh = quad
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = layer[1]
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.no_depth_test = true
		mat.render_priority = layer[2]
		board.material_override = mat
		board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		board.layers = WorldCamera.LAYER_WORLD_UI
		_tag.add_child(board)
	_label = Label3D.new()
	_label.name = "Text"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 3
	_label.pixel_size = 0.00105
	_label.font_size = 46
	_label.outline_size = 0
	_label.modulate = HudPalette.TEXT_LIGHT
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.layers = WorldCamera.LAYER_WORLD_UI
	_tag.add_child(_label)


func _update_tag() -> void:
	if _label == null or _event_car == null:
		return
	_label.text = Loc.t("ÖDÜNÇ · ETKİNLİK ARACI\nYARIŞ ▶ %d / %d") % [_event_car.tries_left(), _event_car.tries_total()]


func _build_click_body() -> void:
	_body = StaticBody3D.new()
	_body.name = "ClickBody"
	_body.input_ray_pickable = true
	add_child(_body)
	_body.global_position = PARK
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = BODY_SIZE + Vector3(0.06, 0.12, 0.06)   # mobilde rahat dokunma payı
	shape.shape = box
	shape.position = Vector3(0.0, BODY_SIZE.y * 0.5, 0.0)
	_body.add_child(shape)
	_body.input_event.connect(_on_input)


func _on_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		clicked.emit()
		get_viewport().set_input_as_handled()
