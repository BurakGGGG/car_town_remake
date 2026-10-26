extends SceneTree
## TRAFİK POLİSİ QA — garajın önünde telefonda görülen kilidi kurar ve polisin çözmesini izler / kaydeder.
## Kilit: sıkılıp kaldırımdan şeride kırarak çıkan müşteri (burnu şeride 35° dönük) ile şeritte yanından gelen araç;
## ikisi de öbürünü "önümde" sayar. Beklenen: ~6 sn sonra karşı şeritten sirenli polis gelir, kilidin önünde durur,
## siren susar, bir kez "dat dat" (korna), en öndekini geçirir, kuyruk açılır, polis gider.
##   tools/qa_isolated.sh res://qa/trafik_polisi_qa.gd --display-driver x11 --disable-vsync --resolution 1170x540 \
##     [-- kayit]     (kayit: 0,25 sn'de bir kare → ~/Projects/ct_shots/trafik_polisi/kare_NNNN.png)
## FİLM (sesli video, Godot Movie Maker): kamera kilide yakınlaşır, zaman 30 kare/sn sabit adımla sayılır:
##   tools/qa_isolated.sh res://qa/trafik_polisi_qa.gd --display-driver x11 --resolution 1170x540 \
##     --write-movie ~/Projects/ct_shots/trafik_polisi_film/film.avi --fixed-fps 30 -- film

const OUT: String = "/home/burak/Projects/ct_shots/trafik_polisi"
const MERGE_ANGLE: float = 35.0
const FILM_FPS: float = 30.0

var fails: int = 0
var _traffic: TrafficManager
var _record: bool = false
var _film: bool = false
var _frame: int = 0
var _released: String = ""
var _horn_at: float = -1.0
var _released_at: float = -1.0
var _finished: bool = false
var _t0: float = 0.0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_record = OS.get_cmdline_user_args().has("kayit")
	_film = OS.get_cmdline_user_args().has("film")
	_run.call_deferred()


func _run() -> void:
	Engine.max_fps = 60
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	(get_first_node_in_group("save_manager") as SaveManager).new_game()
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels(
		{GarageUpgradeManager.GARAGE_ID: 4})
	await frames(10)
	_traffic = _find(current_scene)
	check(_traffic != null and _traffic.police != null, "TrafficManager ve TrafficPolice kuruldu")
	_traffic.chase.set("_timer", 1.0e6)   # kovalamaca araya girmesin
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	if rm:
		rm.process_mode = Node.PROCESS_MODE_DISABLED   # yeni müşteri kuyruğu bozmasın
	# İki trafik aracı bekle
	var started: int = Time.get_ticks_msec()
	while _city_traffic().size() < 2 and Time.get_ticks_msec() - started < 20000:
		await frames(10)
	var pair: Array[TrafficVehicle] = _city_traffic()
	check(pair.size() >= 2, "en az iki trafik aracı var (%d)" % pair.size())
	if pair.size() < 2:
		_end()
		return
	var spot: Node3D = rm.repair_wait_spots[1] if rm and rm.repair_wait_spots.size() > 1 else null
	check(spot != null, "bekleme noktası bulundu")
	if spot == null:
		_end()
		return
	var lane_dir: Vector3 = TrafficVehicle._flat(spot.global_transform.basis.z).normalized()
	var right: Vector3 = lane_dir.cross(Vector3.UP)
	var leaver: TrafficVehicle = pair[0]
	var passer: TrafficVehicle = pair[1]
	var lane_center: Vector3 = TrafficVehicle._flat(spot.global_position) - right * 0.32
	_place(passer, lane_center, lane_dir, false)
	_place(leaver, lane_center + right * 0.3 + lane_dir * 0.15, lane_dir.rotated(Vector3.UP, deg_to_rad(MERGE_ANGLE)), true)
	# Kamera: önce yakınlaşma biter (yakınlaşırken odak her karede dünya sınırına çekilir), sonra yolun ortası, kilidin
	# biraz önü (polisin geleceği yer) ekranın ortasına
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	camera.zoom_by(-3.0 if _film else -1.5)
	var guard: int = 0
	while not is_equal_approx(camera.size, float(camera.get("_target_size"))) and guard < 400:
		await process_frame
		guard += 1
	camera.set("_focus", lane_center - right * 0.3 + lane_dir * 0.5)
	camera.call("_apply_focus")
	_traffic.police.intervened.connect(_on_intervened)
	_traffic.police.horn_blasted.connect(_on_horn)
	_traffic.police.finished.connect(_on_finished)
	await frames(30)
	check(leaver.speed < 0.03 and passer.speed < 0.03, "kilit kuruldu: iki araç da duruyor")
	check(leaver.leader == passer and passer.leader == leaver, "ikisi de öbürünü önünde sayıyor (halka)")

	# Polisin gelişi, duruşu, geçirme, gidiş — en çok 60 sn
	var t0: float = _clock()
	_t0 = t0
	var seen: Dictionary = {}
	var stop_gap: float = INF
	var siren_at_stop: bool = false
	var cleared_at: float = -1.0
	var moved_from: Dictionary = {leaver: leaver.global_position, passer: passer.global_position}
	var moved: Dictionary = {}
	var finished_at: float = -1.0
	while _clock() - t0 < 60.0:
		var phase: TrafficPolice.Phase = _traffic.police.phase()
		var now: float = _clock() - t0
		if _finished and finished_at < 0.0:
			finished_at = now
			print("   %5.1f sn  polis ekrandan çıktı" % now)
		if finished_at > 0.0 and (cleared_at > 0.0 or now - finished_at > 10.0):
			break
		if _film and cleared_at > 0.0 and now - cleared_at > 3.0 and phase == TrafficPolice.Phase.LEAVE:
			break   # film: kuyruk açılıp polis yola koyulunca biter (ışıkta beklemesi film dışı)
		if not seen.has(phase):
			seen[phase] = now
			print("   %5.1f sn  %s" % [now, TrafficPolice.Phase.keys()[phase]])
			if phase == TrafficPolice.Phase.STOPPED and _traffic.police.police():
				var cop: TrafficVehicle = _traffic.police.police()
				var head: TrafficVehicle = _traffic.police.head()
				if head:
					var to_cop: Vector3 = TrafficVehicle._flat(cop.global_position - head.global_position)
					stop_gap = absf(to_cop.dot(lane_dir))
					print("          polis, en öndekinin %.2f ilerisinde / %.2f solunda (karşı şerit)" % [
						to_cop.dot(lane_dir), -to_cop.dot(right)])
				siren_at_stop = _traffic.police.siren_playing()
		# İlerleyen araç ekran dışında yolun eski ucunu geçince erken silinir: her aracın ilerlemesi ayrı işaretlenir
		for vehicle: TrafficVehicle in [leaver, passer]:
			if _released != "" and is_instance_valid(vehicle) and vehicle.global_position.distance_to(moved_from[vehicle]) > 1.0:
				moved[vehicle] = true
		if cleared_at < 0.0 and moved.size() == 2:
			cleared_at = now
			print("   %5.1f sn  kuyruk açıldı (iki araç da > 1 birim ilerledi)" % now)
		await _shoot()
	check(seen.has(TrafficPolice.Phase.APPROACH), "polis geldi (APPROACH)")
	check(seen.has(TrafficPolice.Phase.STOPPED), "polis kilidin önünde durdu")
	check(stop_gap < 1.0, "durma yeri kilidin başının hizasında (%.2f)" % stop_gap)
	check(siren_at_stop, "durduğu an siren çalıyor")
	check(_horn_at > 0.0, "durduktan sonra \"dat dat\" çaldı (%.1f sn)" % _horn_at)
	check(_released != "", "en öndeki araç geçirildi (%s, %.1f sn)" % [_released, _released_at])
	check(_horn_at > 0.0 and _released_at > _horn_at, "geçirme kornadan SONRA")
	check(cleared_at > 0.0, "kuyruk açıldı")
	if not _film:
		check(_finished, "polis yoluna devam edip ekrandan çıktı")
		check(_traffic.police.police() == null and not _traffic.police.is_busy(), "polis kaldırıldı, müdahale bitti")
	check(_traffic.find_deadlock(0.5).is_empty(), "kilit kalmadı")
	_end()


## Aracı verilen yere / yöne koyar; `merging`: kaldırımdan çıkan sıkılmış müşteri gibi şeride kırıyor.
func _place(vehicle: TrafficVehicle, at: Vector3, facing: Vector3, merging: bool) -> void:
	if vehicle.is_in_intersection():
		vehicle.set("_in_intersection", false)
		_traffic.finish_crossing(vehicle)
	vehicle.global_position = Vector3(at.x, vehicle.global_position.y, at.z)
	vehicle.call("_face", facing)
	vehicle.speed = 0.0
	vehicle.target = _traffic.nearest_waypoint_ahead(vehicle)
	var previous: TrafficWaypoint = _traffic.previous_waypoint(vehicle.target) if vehicle.target else null
	vehicle.set("_segment_from", previous.global_position if previous else Vector3.INF)
	vehicle.set("_merging", merging)


## Saniye: normalde gerçek saat, filmde sabit adımlı kare sayısı (Movie Maker gerçek zamanda koşmaz).
func _clock() -> float:
	return Engine.get_process_frames() / FILM_FPS if _film else Time.get_ticks_msec() / 1000.0


func _on_intervened(head: TrafficVehicle) -> void:
	_released = String(head.vehicle_id)
	_released_at = _clock() - _t0
	print("   %5.1f sn  geçirildi: %s" % [_released_at, _released])


func _on_horn() -> void:
	_horn_at = _clock() - _t0
	print("   %5.1f sn  DAT DAT (siren çalıyor: %s, korna çalıyor: %s)" % [_horn_at,
		_traffic.police.siren_playing(), _traffic.police.get_node("PoliceSiren").horn_playing()])


func _on_finished() -> void:
	_finished = true


func _city_traffic() -> Array[TrafficVehicle]:
	var out: Array[TrafficVehicle] = []
	for vehicle: TrafficVehicle in _traffic.vehicles:
		if is_instance_valid(vehicle) and vehicle.mode == TrafficVehicle.Mode.TRAFFIC and not vehicle.race_lane:
			out.append(vehicle)
	return out


func _shoot() -> void:
	if _film:
		await process_frame
		return
	await RenderingServer.frame_post_draw
	if not _record:
		await create_timer(0.1).timeout
		return
	if _frame == 0:
		DirAccess.make_dir_recursive_absolute(OUT)
	get_root().get_texture().get_image().save_png("%s/kare_%04d.png" % [OUT, _frame])
	_frame += 1
	await create_timer(0.25).timeout


func _end() -> void:
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find(child)
		if found:
			return found
	return null
