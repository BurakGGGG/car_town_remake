extends SceneTree
## TRAFİK UÇ NOKTALARI QA — yollar dünyanın kenarına uzatılınca araçlar yolun ortasında belirip
## kayboluyor mu? Her araç doğduğu ve silindiği anda kameradan görünüyor muydu, sayar.
## Üç görünüm: varsayılan (eski uç noktalar ekran dışında → araç ESKİ yerinde doğmalı, tempo aynı),
## en uzak zumda batı kenarı ve güneydoğu kenarı (eski noktalar görünür → araç dışarıda doğmalı).
##   godot-4 --path . --resolution 1170x540 -s res://qa/trafik_kenar_qa.gd

const SPEED: float = 3.0      # Engine.time_scale: trafik 3 kat hızlı
const SECONDS: float = 25.0   # görünüm başına gerçek süre

var fails: int = 0
var _traffic: TrafficManager
var _spawns: int = 0
var _seen_spawns: int = 0
var _despawns: int = 0
var _seen_despawns: int = 0
var _core_spawns: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	(get_first_node_in_group("save_manager") as SaveManager).new_game()
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels(
		{GarageUpgradeManager.GARAGE_ID: 4})
	await frames(10)
	_traffic = _find(current_scene)
	check(_traffic != null, "TrafficManager bulundu")
	var moved: int = 0
	for point: TrafficWaypoint in _traffic.waypoints:
		if point.has_meta(TrafficManager.CORE_META):
			moved += 1
	check(moved == 8, "8 doğma / kaybolma noktası yeni yol uçlarına taşındı (%d)" % moved)
	_traffic.vehicle_spawned.connect(_on_spawned)
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	Engine.time_scale = SPEED
	for view: Array in [["varsayılan", Vector3.ZERO, false], ["uzak batı", Vector3(-9.0, 0.0, 0.5), true],
			["uzak güneydoğu", Vector3(6.0, 0.0, 6.0), true]]:
		camera.zoom_by(10.0 if view[2] else -10.0)
		camera.set("_focus", view[1])
		camera.call("_apply_focus")
		await frames(30)
		_spawns = 0
		_seen_spawns = 0
		_despawns = 0
		_seen_despawns = 0
		_core_spawns = 0
		await create_timer(SECONDS * SPEED).timeout   # zaman ölçekli sayaç: gerçekte SECONDS sn
		print("   %s: %d doğdu (%d eski noktada), %d görünürken doğdu · %d silindi, %d görünürken" % [
			view[0], _spawns, _core_spawns, _seen_spawns, _despawns, _seen_despawns])
		check(_seen_spawns == 0, "%s: hiçbir araç görünürken doğmadı" % view[0])
		check(_seen_despawns == 0, "%s: hiçbir araç görünürken silinmedi" % view[0])
		if not view[2]:
			check(_spawns > 0 and _core_spawns == _spawns,
				"%s: eski noktalar ekran dışı → bütün araçlar eski yerinde doğdu (tempo aynı)" % view[0])
	Engine.time_scale = 1.0
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


func _on_spawned(vehicle: TrafficVehicle) -> void:
	_spawns += 1
	if not _traffic.is_hidden(vehicle.global_position):
		_seen_spawns += 1
	for point: TrafficWaypoint in _traffic.waypoints:
		if point.has_meta(TrafficManager.CORE_META):
			var core: Vector3 = point.get_meta(TrafficManager.CORE_META)
			if Vector2(core.x, core.z).distance_to(Vector2(vehicle.global_position.x, vehicle.global_position.z)) < 0.05:
				_core_spawns += 1
				break
	vehicle.reached_despawn.connect(func(v: TrafficVehicle) -> void:
		_despawns += 1
		if not _traffic.is_hidden(v.global_position):
			_seen_despawns += 1)


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find(child)
		if found:
			return found
	return null
