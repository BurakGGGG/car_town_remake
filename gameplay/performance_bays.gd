class_name PerformanceBays
extends Node
## Parça takılan araçların GARAJDAKİ görünümü: her takma kendi tamir alanının liftinde bir PerformanceBayDisplay
## (araç + kalan süre balonu). PerformanceModManager'ı izler; kayıttan yüklenen takmalar da kurulur.
## Araca dokununca: süre dolduysa parça takılır (collect) ve araç alandan çıkar; dolmadıysa job_selected
## (HUD kalan süreyi söyler). Kodla kurulur (GarageSystem), "performance_bays" grubundan bulunur.

## Süren takmaya dokunuldu (henüz HAZIR değil).
signal job_selected(vehicle_id: StringName)

const CarHitboxScript: GDScript = preload("res://car_hitbox.gd")
## Balon sayacı bu aralıkla güncellenir (sn).
const TICK: float = 0.25

var _displays: Dictionary = {}   # vehicle_id → PerformanceBayDisplay
var _leaving: Array[PerformanceBayDisplay] = []   # parçası takılmış, alandan çıkan araçlar
var _selected: Node = null
var _arrivals: Dictionary = {}   # yeni alınan parçanın aracı: görünüm present()'i bekler (gizli, lift alçakta)
## Giriş sinematiğini kimse başlatmazsa (garaj dışından satın alma, test) bu kadar sonra kendiliğinden girer.
const ARRIVAL_FALLBACK: float = 3.0
## Kamera alana gittikten sonra eski görünümüne dönmeden önce bekler (sn).
const CAMERA_HOLD: float = 1.6
var _tick: float = 0.0


func _ready() -> void:
	add_to_group("performance_bays")
	_connect.call_deferred()


func _connect() -> void:
	var mods: PerformanceModManager = _mods()
	if mods == null:
		return
	mods.install_started.connect(func(id: StringName, _c: StringName, _s: int) -> void: _arrivals[id] = true)
	mods.jobs_changed.connect(sync)
	mods.install_completed.connect(func(id: StringName, _c: StringName, _s: int, _o: String, _n: String) -> void:
		_leave(id))
	sync()


## Görünümü takmalarla eşitler: yeni takmaya görünüm kurulur, biten / silinenin görünümü kalkar.
func sync() -> void:
	var mods: PerformanceModManager = _mods()
	if mods == null:
		return
	var alive: Dictionary = {}
	for job: Dictionary in mods.jobs():
		var id: StringName = job["car"]
		alive[id] = true
		var display: PerformanceBayDisplay = _displays.get(id) as PerformanceBayDisplay
		if display and is_instance_valid(display) and display.bay == int(job["bay"]):
			continue
		if display and is_instance_valid(display):
			_remove(id)
		_add(id, int(job["bay"]))
	for id: StringName in _displays.keys():
		if not alive.has(id):
			_remove(id)
	_refresh_bubbles()


func display_of(vehicle_id: StringName) -> PerformanceBayDisplay:
	return _displays.get(vehicle_id) as PerformanceBayDisplay


## Görünümü duran alanlar (çıkış animasyonu süren dahil): müşteri aracı buraya girmesin.
func busy_bays() -> Array[int]:
	var out: Array[int] = []
	for display: Variant in _displays.values():
		if is_instance_valid(display):
			out.append((display as PerformanceBayDisplay).bay)
	for display: PerformanceBayDisplay in _leaving:
		if is_instance_valid(display) and not out.has(display.bay):
			out.append(display.bay)
	return out


func _process(delta: float) -> void:
	var selected: Node = CarHitboxScript.get(&"selected_car")
	if selected != _selected:
		_selected = selected
		if selected is PerformanceBayDisplay and not (selected as PerformanceBayDisplay).is_leaving():
			_on_tapped((selected as PerformanceBayDisplay).vehicle_id)
	_tick -= delta
	if _tick <= 0.0:
		_tick = TICK
		_refresh_bubbles()


func _on_tapped(vehicle_id: StringName) -> void:
	var mods: PerformanceModManager = _mods()
	if mods == null:
		return
	if mods.is_ready(vehicle_id):
		mods.collect(vehicle_id)   # install_completed → _leave
	else:
		job_selected.emit(vehicle_id)
		_clear_selection()


func _refresh_bubbles() -> void:
	var mods: PerformanceModManager = _mods()
	if mods == null:
		return
	for id: StringName in _displays:
		var display: PerformanceBayDisplay = _displays[id] as PerformanceBayDisplay
		if is_instance_valid(display):
			display.show_time(mods.remaining(id))


func _add(id: StringName, bay: int) -> void:
	var spot: Node3D = _spot(bay)
	if spot == null:
		return
	var display: PerformanceBayDisplay = PerformanceBayDisplay.new()
	display.setup(id, bay)
	spot.add_child(display)
	display.position = Vector3(0.0, RepairLift.REST_TOP, 0.0)
	_displays[id] = display
	if _arrivals.has(id):
		# Yeni alınan parça: araç gizli bekler, YÜKSELT sinematiği (present) alana sokar
		display.visible = false
		display.arriving = true
		get_tree().create_timer(ARRIVAL_FALLBACK).timeout.connect(func() -> void:
			if _arrivals.has(id):
				present(id, false))
		return
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.raise_lift(bay, display)


## YÜKSELT SİNEMATİĞİ: kamera alana döner, araç alana girer, lift kalkar, kıvılcım; kamera sonra eski yerine.
## frame = false: kamera oynamaz (garaj dışından alım / yedek zamanlayıcı).
func present(vehicle_id: StringName, frame: bool = true) -> void:
	if not _arrivals.has(vehicle_id):
		return
	_arrivals.erase(vehicle_id)
	var display: PerformanceBayDisplay = _displays.get(vehicle_id) as PerformanceBayDisplay
	if display == null or not is_instance_valid(display):
		return
	var camera: WorldCamera = get_viewport().get_camera_3d() as WorldCamera if frame else null
	var before: Dictionary = {}
	if camera:
		var box: AABB = display.world_box()
		var reach: float = maxf(box.size.x, box.size.z) * 1.4
		var center: Vector3 = box.get_center()
		before = camera.frame_box(AABB(Vector3(center.x - reach, box.position.y, center.z - reach),
			Vector3(reach * 2.0, box.size.y * 2.2, reach * 2.0)), 0.14, 0.7, 0.08, 1.2)
	display.arrive()
	await display.arrived
	if not is_instance_valid(display) or display.is_leaving():
		return
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.raise_lift(display.bay, display)
		await get_tree().create_timer(RepairLift.RAISE_TIME).timeout
	if is_instance_valid(display):
		display.settle()
		_refresh_bubbles()
	if camera and not before.is_empty():
		await get_tree().create_timer(CAMERA_HOLD).timeout
		if is_instance_valid(camera):
			camera.restore_view(before)


## Parça takıldı: görünüm sync'in elinden alınır, çıkış animasyonu oynar, lift serbest kalır.
func _leave(id: StringName) -> void:
	var display: PerformanceBayDisplay = _displays.get(id) as PerformanceBayDisplay
	_displays.erase(id)
	if display == null or not is_instance_valid(display):
		return
	_leaving.append(display)
	display.left.connect(func() -> void:
		_leaving.erase(display)
		var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
		if bays:
			bays.release_lift(display.bay)
		display.queue_free())
	display.finish()


func _remove(id: StringName) -> void:
	var display: PerformanceBayDisplay = _displays.get(id) as PerformanceBayDisplay
	_displays.erase(id)
	if display == null or not is_instance_valid(display):
		return
	var bays: RepairBayManager = get_tree().get_first_node_in_group("repair_bays") as RepairBayManager
	if bays:
		bays.release_lift(display.bay)
	if CarHitboxScript.get(&"selected_car") == display:
		CarHitboxScript.set(&"selected_car", null)
	display.queue_free()


func _clear_selection() -> void:
	var selected: Node = CarHitboxScript.get(&"selected_car")
	if selected is PerformanceBayDisplay:
		var ring: Node3D = (selected as Node3D).get_node_or_null("SelectionRing") as Node3D
		if ring:
			ring.visible = false
		CarHitboxScript.set(&"selected_car", null)
	_selected = null


func _spot(bay: int) -> Node3D:
	var repair: RepairManager = get_tree().get_first_node_in_group("repair_manager") as RepairManager
	if repair == null or bay < 0 or bay >= repair.repair_car_spots.size():
		return null
	return repair.repair_car_spots[bay]


func _mods() -> PerformanceModManager:
	return get_tree().get_first_node_in_group("performance_mods") as PerformanceModManager
