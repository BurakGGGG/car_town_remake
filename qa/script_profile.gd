extends SceneTree
## BETİK PROFİLİ — GDScript fonksiyonlarının gerçek süresi (Godot'nun yerel hata ayıklayıcı profilleyicisi).
## Her ölçüm aralığının sonunda profilleyici kapatılır: motor o aralığın BİRİKMİŞ dökümünü stdout'a
## basar ("ACCUMULATED:"), hemen önce bu betik bir "=== PROF <etiket>" satırı yazar. Dökümü
## tools/prof_report.py etiket etiket özetler (kendi süresi / toplam / çağrı).
##
## Kullanım (-d ŞART: yerel hata ayıklayıcı yoksa profilleyici yoktur; --disable-vsync ŞART: örtülü
## XWayland penceresinde takas 1 Hz'e kısılıp kareleri 1 sn yapıyor):
##   QA_SAVE=~/Projects/ct_shots/bench_saves/featured.json CT_NO_TUTORIAL=1 tools/qa_isolated.sh \
##     res://qa/script_profile.gd -d --display-driver x11 --disable-vsync --resolution 1152x648 \
##     -- <senaryo> < /dev/null > prof.log 2>&1
##   python3 tools/prof_report.py prof.log
## Senaryolar: startup (ilk 6 kare ayrı ayrı + açılış toplamı) · world (oturmuş dünya, 300 kare) ·
##   open:<ekran> (router.open + 40 kare; ikinci açılış ayrıca) · repair (tamir sürerken 300 kare)
## Profilleyici her GDScript çağrısını zamanladığı için mutlak süreler şişer; kıyas göreli okunur.

const SETTLE: int = 180

var _scenario: String = "startup"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_scenario = args[0]
	if not EngineDebugger.is_active():
		push_error("script_profile: -d bayrağı yok, profilleyici çalışmaz")
		quit(1)
		return
	_run.call_deferred()


func _begin() -> void:
	EngineDebugger.profiler_enable(&"scripts", true)


func _end(label: String, wall_ms: float) -> void:
	print("=== PROF %s wall=%.1f" % [label, wall_ms])
	EngineDebugger.profiler_enable(&"scripts", false)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	if _scenario == "startup":
		await _startup()
	else:
		change_scene_to_file("res://Main.tscn")
		await _frames(SETTLE)
		Engine.max_fps = 0
		OS.low_processor_usage_mode = false
		if _scenario == "world":
			await _span("world", 300)
		elif _scenario == "repair":
			await _repair()
		elif _scenario == "mods":
			await _mods()
		elif _scenario.begins_with("open:"):
			await _open(StringName(_scenario.substr(5)))
	quit(0)


## Eleme deneyi (2. betik argümanı, virgülle): no3d = ana görünüm 3D çizmez · nosub = SubViewport'lar
## (ön ısıtmalar) çizmez · nophys = fizik durur. İlk karelerin MOTOR süresinin kaynağını ayırmak için.
func _startup() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var mods: PackedStringArray = args[1].split(",") if args.size() > 1 else PackedStringArray()
	_begin()
	var t0: int = Time.get_ticks_usec()
	var packed: PackedScene = load("res://Main.tscn")
	var main: Node = packed.instantiate()
	root.add_child(main)
	current_scene = main
	_end("startup/0 load+instantiate+ready", (Time.get_ticks_usec() - t0) / 1000.0)
	if "no3d" in mods:
		root.disable_3d = true
	if "nophys" in mods:
		PhysicsServer3D.set_active(false)
	# hide:<Düğüm> — o addaki düğüm (sonradan eklenirse de) ilk karelerden itibaren gizli
	for mod: String in mods:
		if mod.begins_with("hide:"):
			var target: StringName = StringName(mod.substr(5))
			node_added.connect(func(n: Node) -> void:
				if n.name == target and (n is Node3D or n is CanvasItem or n is CanvasLayer):
					n.set(&"visible", false))
			for n: Node in root.find_children(String(target), "", true, false):
				n.set(&"visible", false)
	if "nosub" in mods:
		# Ön ısıtmalar güncelleme kipini kendileri UPDATE_ONCE yapıyor; 3D'yi kapatmak kalıcı
		node_added.connect(func(n: Node) -> void:
			if n is SubViewport:
				(n as SubViewport).disable_3d = true)
		for n: Node in root.find_children("*", "SubViewport", true, false):
			(n as SubViewport).disable_3d = true
	for i: int in 6:
		_begin()
		var f0: int = Time.get_ticks_usec()
		await process_frame
		_end("startup/kare %d" % (i + 1), (Time.get_ticks_usec() - f0) / 1000.0)
	_begin()
	var r0: int = Time.get_ticks_usec()
	await _frames(SETTLE)
	_end("startup/sonraki %d kare" % SETTLE, (Time.get_ticks_usec() - r0) / 1000.0)


func _span(label: String, frames: int) -> void:
	_begin()
	var t0: int = Time.get_ticks_usec()
	await _frames(frames)
	_end("%s (%d kare)" % [label, frames], (Time.get_ticks_usec() - t0) / 1000.0)


func _open(id: StringName) -> void:
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	for round: int in 2:
		_begin()
		var t0: int = Time.get_ticks_usec()
		hud.router.open(id)
		await _frames(40)
		_end("open:%s/%d. açılış (+40 kare)" % [id, round + 1], (Time.get_ticks_usec() - t0) / 1000.0)
		hud.router.close_all()
		await _frames(40)


## Garaj → MODİFİYE (lifteki araç) → ilk kategori.
func _mods() -> void:
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.open(&"garage")
	await _frames(60)
	for round: int in 2:
		_begin()
		var t0: int = Time.get_ticks_usec()
		hud.garage_screen.open_mods()
		await _frames(40)
		_end("mods/%d. açılış (+40 kare)" % (round + 1), (Time.get_ticks_usec() - t0) / 1000.0)
		hud.garage_screen.call(&"_close_mods")
		await _frames(30)


func _repair() -> void:
	var repairs: RepairManager = get_first_node_in_group("repair_manager")
	for node: Node in root.find_children("*", "TrafficVehicle", true, false):
		var car: TrafficVehicle = node as TrafficVehicle
		if car.mode == TrafficVehicle.Mode.TRAFFIC:
			car.fault = RepairType.by_id(&"body")
			car.mode = TrafficVehicle.Mode.REPAIR_WAITING
			if repairs.start_repair(car):
				break
	await _frames(30)
	await _span("repair", 300)
