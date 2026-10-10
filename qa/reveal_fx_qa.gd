extends SceneTree
## KASA AÇILIŞI + TAMİR EFEKTLERİ GÖRSEL QA — zaman çizelgesi boyunca kareler.
##  1) kasa: sıradan (rank 0) ve efsanevi (rank 3) — nadirlik doğrudan sahneye verilir (sonuç rastgele
##     olduğu için); ödül akışı (CrateManager) bu QA'da çalışmaz, yalnızca sunum.
##  2) tamir: kaporta (kaynak) ve motor (duman) işleri, bitiş parıltısı, para toplama.
## Kullanım: tools/qa_isolated.sh res://qa/reveal_fx_qa.gd --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/reveal_fx/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("  kare ", name)


func _wait(seconds: float) -> void:
	await create_timer(seconds).timeout


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _wait(3.0)
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await _wait(0.8)
	var pp: PlayerProgress = get_first_node_in_group("player_progress")
	pp.load_state(30, 0, 5000)
	await _crate(&"city_crate", &"hyundai_getz", &"common", "kasa_sradan")
	await _crate(&"super_crate", &"lambo_huracan", &"legendary", "kasa_efsane")
	await _repair(&"body", "tamir_kaporta")
	await _repair(&"engine", "tamir_motor")
	quit(0)


func _crate(crate_id: StringName, vehicle: StringName, rarity: StringName, tag: String) -> void:
	print("== %s ==" % tag)
	var crates: CrateManager = get_first_node_in_group("crates")
	var delivery: CrateDelivery = get_first_node_in_group("crate_delivery")
	var uid: int = crates.buy(crate_id)
	await _wait(2.0)
	var v: CrateVisual = delivery.visual_of(uid)
	if v == null:
		print("  kasa teslim edilmedi")
		return
	delivery.call("_prefetch_vehicle", uid)
	var rank: int = CrateCatalog.rarity_rank(rarity)
	var suspense: float = CrateVisual.suspense_time(rank)
	(delivery.get("_revealing") as Dictionary)[uid] = {}
	delivery.call("_play_reveal", uid, v, {"vehicle": vehicle, "rarity": rarity})
	var clock: float = 0.0
	for at: Array in [[0.15, "1_gerilim_bas"], [suspense - 0.15, "2_gerilim_son"], [suspense + 0.12, "3_patlama"],
			[suspense + 0.45, "4_kapak_havada"], [suspense + 1.25, "5_arac_yukseliyor"],
			[suspense + 1.9, "6_arac_iniyor"], [suspense + 3.4, "7_cikti"]]:
		await _wait(float(at[0]) - clock)
		clock = float(at[0])
		await _shot("%s_%s" % [tag, at[1]])
	var data: Dictionary = (delivery.get("_revealing") as Dictionary).get(uid, {})
	for node: Variant in [data.get("car"), data.get("fx"), v]:
		if is_instance_valid(node):
			(node as Node).queue_free()
	(delivery.get("_revealing") as Dictionary).erase(uid)
	(delivery.get("_visuals") as Dictionary).erase(uid)
	delivery.call("_restore_camera")
	await _wait(0.5)


func _repair(job: StringName, tag: String) -> void:
	print("== %s ==" % tag)
	var repairs: RepairManager = get_first_node_in_group("repair_manager")
	var traffic: Array[Node] = get_root().find_children("*", "TrafficVehicle", true, false)
	var car: TrafficVehicle = null
	for node: Node in traffic:
		var candidate: TrafficVehicle = node as TrafficVehicle
		if candidate.mode == TrafficVehicle.Mode.TRAFFIC and candidate.is_visible_in_tree():
			car = candidate
			break
	if car == null:
		print("  trafik aracı yok")
		return
	car.fault = RepairType.by_id(job)
	car.mode = TrafficVehicle.Mode.REPAIR_WAITING
	if not repairs.start_repair(car):
		print("  tamir başlamadı")
		return
	var camera: WorldCamera = get_root().get_viewport().get_camera_3d() as WorldCamera
	await _wait(1.2)   # lift kalksın
	var view: Dictionary = {}
	if camera:
		var box: AABB = AABB(car.global_position - Vector3(0.45, 0.0, 0.45), Vector3(0.9, 0.7, 0.9))
		view = camera.frame_box(box, 0.12, 0.5)
	await _wait(0.6)
	for i: int in 4:
		await _wait(0.33)
		await _shot("%s_1_is_%d" % [tag, i])
	var state: RepairState = repairs.get_state(car)
	while state and state.is_repairing:
		await _wait(0.1)
	await _wait(0.12)
	await _shot("%s_2_bitti" % tag)
	await _wait(0.9)
	repairs.collect(car)
	await _wait(0.12)
	await _shot("%s_3_para" % tag)
	await _wait(0.3)
	await _shot("%s_4_para_dusuyor" % tag)
	await _wait(1.2)
	if camera and not view.is_empty():
		camera.restore_view(view)
