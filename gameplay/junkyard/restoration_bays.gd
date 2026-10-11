class_name RestorationBays
extends Node
## Restorasyon projelerinin GARAJDAKİ görünümü: her proje kendi tamir alanının liftinde bir
## RestorationDisplay olarak durur (çıplak şasi → paslı araç → temiz araç). JunkyardManager'ın
## sinyallerini izler; kayıttan yüklenen projeler de kurulur. Projeye dokunulunca (CarHitbox seçimi)
## project_selected yayılır, HUD restorasyon panosunu açar.
## Kodla kurulur (GarageSystem), "restoration_bays" grubundan bulunur. Kare başına yalnızca seçim okunur.

signal project_selected(vehicle_id: StringName)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")

var _displays: Dictionary = {}   # vehicle_id → RestorationDisplay
var _selected: StringName = &""


func _ready() -> void:
	add_to_group("restoration_bays")
	_connect.call_deferred()


func _connect() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null:
		return
	jy.junkyard_changed.connect(sync)
	jy.project_progress.connect(func(id: StringName, value: float) -> void:
		var display: RestorationDisplay = _displays.get(id) as RestorationDisplay
		if display:
			display.set_progress(value))
	sync()


## Görünümü projelerle eşitler: yeni projeye görünüm kurulur, biten / bırakılanınki kaldırılır.
func sync() -> void:
	var jy: JunkyardManager = _jy()
	if jy == null:
		return
	var alive: Dictionary = {}
	for project: Dictionary in jy.projects():
		var id: StringName = project["car"]
		alive[id] = true
		var display: RestorationDisplay = _displays.get(id) as RestorationDisplay
		if display and is_instance_valid(display) and display.bay == int(project["bay"]):
			display.set_progress(jy.progress(id), false)
			continue
		if display and is_instance_valid(display):
			_remove(id)
		_add(id, int(project["bay"]), jy.progress(id))
	for id: StringName in _displays.keys():
		if not alive.has(id):
			_remove(id)


func display_of(vehicle_id: StringName) -> RestorationDisplay:
	return _displays.get(vehicle_id) as RestorationDisplay


func _add(id: StringName, bay: int, value: float) -> void:
	var spot: Node3D = _spot(bay)
	if spot == null:
		return
	var display: RestorationDisplay = RestorationDisplay.new()
	display.setup(id, bay, value)
	spot.add_child(display)
	display.position = Vector3(0.0, RepairLift.REST_TOP, 0.0)
	_displays[id] = display
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.raise_lift(bay, display)


func _remove(id: StringName) -> void:
	var display: RestorationDisplay = _displays.get(id) as RestorationDisplay
	_displays.erase(id)
	if display == null or not is_instance_valid(display):
		return
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.release_lift(display.bay)
	if CarHitboxScript.get(&"selected_car") == display:
		CarHitboxScript.set(&"selected_car", null)
	display.queue_free()


func _process(_delta: float) -> void:
	var selected: Node = CarHitboxScript.get(&"selected_car")
	var id: StringName = (selected as RestorationDisplay).vehicle_id if selected is RestorationDisplay else &""
	if id != _selected:
		_selected = id
		if id != &"":
			project_selected.emit(id)


## Seçimi bırakır (pano kapandı): halka söner, aynı projeye tekrar dokunmak panoyu yeniden açar.
func clear_selection() -> void:
	var selected: Node = CarHitboxScript.get(&"selected_car")
	if selected is RestorationDisplay:
		var ring: Node3D = (selected as Node3D).get_node_or_null("SelectionRing") as Node3D
		if ring:
			ring.visible = false
		CarHitboxScript.set(&"selected_car", null)
	_selected = &""


func _spot(bay: int) -> Node3D:
	var repair: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repair == null or bay < 0 or bay >= repair.repair_car_spots.size():
		return null
	return repair.repair_car_spots[bay]


func _jy() -> JunkyardManager:
	return get_tree().get_first_node_in_group("junkyard") as JunkyardManager
