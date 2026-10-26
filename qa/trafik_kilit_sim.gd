extends SceneTree
## TRAFİK KİLİDİ SİMÜLASYONU — oyuncu hiçbir şeye dokunmaz (müşteriler bekleyip sıkılır, kaldırımdan şeride çıkar),
## zaman hızlı akar; kilitler, trafik polisi müdahaleleri ve ÇÖZÜLMEDEN kalan duruşlar sayılır. Telefonda görülen
## garaj önü kilidinin (2026-10-26) gerçek akışta ne sıklıkta oluştuğunu ve polisin çözdüğünü ölçer.
##   QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/trafik_kilit_sim.gd \
##     --display-driver x11 --disable-vsync --resolution 1170x540 -- [gerçek_sn=240] [polissiz]
## polissiz: TrafficPolice kapalı (karşılaştırma: kilit kendiliğinden çözülüyor mu?).

const SPEED: float = 4.0            # Engine.time_scale (≤ 6: daha hızlıda araçlar varış çemberini ıskalar)
## Bu kadar oyun-sn önündeki yüzünden duran araç "çözülmemiş" sayılır (polis ~6 sn'de algılar, ~10 sn'de geçirir).
const STUCK_LIMIT: float = 40.0

var fails: int = 0
var _traffic: TrafficManager
var _jams: int = 0
var _horns: int = 0
var _releases: int = 0
var _give_ups: int = 0


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
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var seconds: float = float(args[0]) if not args.is_empty() and args[0].is_valid_float() else 240.0
	var police_off: bool = args.has("polissiz")
	Engine.max_fps = 60
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	_traffic = _find(current_scene)
	if police_off:
		_traffic.police.process_mode = Node.PROCESS_MODE_DISABLED
	_traffic.police.intervened.connect(func(_head: TrafficVehicle) -> void: _releases += 1)
	_traffic.police.horn_blasted.connect(func() -> void: _horns += 1)
	var rm: RepairManager = get_first_node_in_group("repair_manager") as RepairManager
	if rm and rm.has_signal(&"customer_left"):
		rm.connect(&"customer_left", func(_v: Variant = null) -> void: _give_ups += 1)
	Engine.time_scale = SPEED
	var start: int = Time.get_ticks_msec()
	var worst: float = 0.0
	var worst_what: String = ""
	var unresolved: int = 0
	var reported: Dictionary = {}
	var busy_was: bool = false
	var report_at: float = 30.0
	while Time.get_ticks_msec() - start < seconds * 1000.0:
		await create_timer(0.5 * SPEED).timeout   # gerçekte 0,5 sn
		var busy: bool = _traffic.police.is_busy()
		if busy and not busy_was:
			_jams += 1
		busy_was = busy
		for vehicle: TrafficVehicle in _traffic.vehicles:
			if not is_instance_valid(vehicle) or not vehicle.blocks_traffic():
				continue
			if vehicle.stuck_time > worst:
				worst = vehicle.stuck_time
				worst_what = "%s (%s%s)" % [vehicle.vehicle_id, TrafficVehicle.Mode.keys()[vehicle.mode],
					", çıkıyor" if vehicle.is_merging() else ""]
			if vehicle.stuck_time > STUCK_LIMIT and not reported.has(vehicle):
				reported[vehicle] = true
				unresolved += 1
				print("  ! ÇÖZÜLMEMİŞ: %s %.0f sn duruyor, önündeki %s; polis %s" % [vehicle.vehicle_id, vehicle.stuck_time,
					vehicle.leader.vehicle_id if is_instance_valid(vehicle.leader) else "—",
					TrafficPolice.Phase.keys()[_traffic.police.phase()]])
				_shot("cozulmemis_%d" % unresolved)
		var real: float = (Time.get_ticks_msec() - start) / 1000.0
		if real >= report_at:
			report_at += 30.0
			print("   %4.0f gerçek sn (~%3.0f oyun dk): müdahale %d, korna %d, geçirme %d, sıkılan müşteri %d, en uzun duruş %.0f sn %s" % [
				real, real * SPEED / 60.0, _jams, _horns, _releases, _give_ups, worst, worst_what])
	Engine.time_scale = 1.0
	print("SONUÇ ~%.0f oyun dk: kilit müdahalesi %d, korna %d, geçirme %d, sıkılan müşteri %d, en uzun duruş %.0f sn %s, çözülmemiş %d" % [
		seconds * SPEED / 60.0, _jams, _horns, _releases, _give_ups, worst, worst_what, unresolved])
	if not police_off:
		check(unresolved == 0, "çözülmemiş kilit yok (%d sn'den uzun duran araç)" % int(STUCK_LIMIT))
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


func _shot(name: String) -> void:
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/trafik_polisi_sim")
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/trafik_polisi_sim/%s.png" % name)


func _find(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find(child)
		if found:
			return found
	return null
