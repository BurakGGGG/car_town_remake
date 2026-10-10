class_name RepairFxDirector
extends Node
## Tamir efektlerinin yöneticisi: RepairManager'ın sinyallerini dinler, her aktif işe bir RepairFx
## kurar (araç TAMİRE ALINDI → iş efektleri, sayaç BİTTİ → parıltı, PARA TOPLANDI → altın paralar).
## RepairManager kendi çocuğu olarak kurar (sahne dosyası değişmez); oyun mantığına dokunmaz.

var _manager: RepairManager
var _fx: Dictionary = {}   # araç → RepairFx


func _ready() -> void:
	name = "RepairFxDirector"
	_manager = get_parent() as RepairManager
	if _manager == null:
		return
	_manager.repair_started.connect(_on_started)
	_manager.repair_ready.connect(_on_ready)
	_manager.repair_collected.connect(_on_collected)
	_manager.repair_cancelled.connect(_drop)
	_manager.repair_slot_freed.connect(func(car: Node3D) -> void: _fx.erase(car))


func _on_started(car: Node3D) -> void:
	if not is_instance_valid(car) or _fx.has(car):
		return
	var state: RepairState = _manager.get_state(car)
	var fx: RepairFx = RepairFx.new()
	fx.setup(car, state.repair_type.id if state and state.repair_type else &"")
	car.get_parent().add_child(fx)
	_fx[car] = fx


func _on_ready(car: Node3D) -> void:
	var fx: RepairFx = _fx.get(car)
	if is_instance_valid(fx):
		fx.complete()


func _on_collected(car: Node3D, reward: int, _xp: int) -> void:
	var fx: RepairFx = _fx.get(car)
	_fx.erase(car)
	if is_instance_valid(fx):
		fx.coins(reward)


func _drop(car: Node3D) -> void:
	var fx: RepairFx = _fx.get(car)
	_fx.erase(car)
	if is_instance_valid(fx):
		fx.stop()
