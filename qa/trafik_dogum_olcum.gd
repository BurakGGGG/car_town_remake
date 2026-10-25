extends SceneTree
## TRAFİK DOĞUM MALİYETİ — bir trafik aracının doğuşu (TrafficManager._spawn_at: sahne kurulumu, CarRig, görünüm,
## birleştirme isteği, çarpışma kutusu, balon, gölge) ana iş parçacığında ne kadar sürüyor; sonraki karelerin süresi.
## Telefonda bu sürenin ~5-8 katı tek karede takılma olarak görünür (şehirde birkaç saniyede bir araç doğar).
##   QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/trafik_dogum_olcum.gd \
##     --display-driver x11 --disable-vsync --resolution 1152x648

const ROUNDS: int = 16


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(300)
	Engine.max_fps = 0
	var traffic: TrafficManager = current_scene.find_child("Traffic", true, false) as TrafficManager
	traffic.set_physics_process(false)   # kendiliğinden doğum olmasın
	var spawn_ms: PackedFloat32Array = []
	var next_ms: PackedFloat32Array = []
	for i: int in ROUNDS:
		var t0: int = Time.get_ticks_usec()
		var vehicle: TrafficVehicle = traffic._spawn_at(traffic.spawn_points[i % traffic.spawn_points.size()])
		var t1: int = Time.get_ticks_usec()
		if vehicle == null:
			await _frames(30)
			continue
		await process_frame
		var t2: int = Time.get_ticks_usec()
		spawn_ms.append((t1 - t0) / 1000.0)
		next_ms.append((t2 - t1) / 1000.0)
		await _frames(20)
		traffic._on_vehicle_despawn(vehicle)
		await _frames(10)
	print("DOĞUM %d araç: _spawn_at ort %.2f ms, en çok %.2f ms · sonraki kare ort %.2f ms, en çok %.2f ms" % [spawn_ms.size(),
		_avg(spawn_ms), _max(spawn_ms), _avg(next_ms), _max(next_ms)])
	quit(0)


func _avg(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total / maxf(values.size(), 1.0)


func _max(values: PackedFloat32Array) -> float:
	var best: float = 0.0
	for v: float in values:
		best = maxf(best, v)
	return best
