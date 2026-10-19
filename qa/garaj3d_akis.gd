extends SceneTree
## GARAJLARIM hata ayıklama: ekran taramasında SANAYİ'ye geçince odaktaki araç görünmüyordu (halka var, araç yok).
## Akışı tekrarlar ve odaktaki aracın düğümlerini yazdırır.
## Çalıştırma: QA_SAVE=~/Projects/ct_shots/bench_saves/dev.json tools/qa_isolated.sh res://qa/garaj3d_akis.gd --display-driver x11 --resolution 1152x648


func _initialize() -> void:
	_run.call_deferred()


func wait(t: float) -> void:
	await create_timer(t).timeout


func _run() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await wait(3.0)
	var hud: Hud = main.find_child("HUD", true, false)
	var screen: GarageScreen = hud.garage_screen
	var manager: CarGarageManager = get_first_node_in_group("car_garages") as CarGarageManager
	print("bekleyen ", manager.waiting_ids().size())
	hud.router.open(&"garage")
	await wait(0.8)
	screen.go_to_garage(CarGarageManager.WAITING)
	await wait(1.0)
	print("odak (bekleyenler) ", screen.shown_vehicle())
	hud.router.close_all()
	await wait(0.5)
	# tarama gibi: MAHALLE açık + GARAJLARIM panosu açıkken satın alma
	hud.router.open(&"garage")
	await wait(0.6)
	screen.go_to_garage(CarGarageCatalog.MAHALLE)
	await wait(0.6)
	hud.router.open(&"car_garages")
	await wait(0.6)
	var progress: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	progress.load_state(30, 0, progress.gems)
	economy.set_money(30000000)
	manager.purchase(CarGarageCatalog.SANAYI)
	manager.clock_offset += 4000.0
	manager.call("_check_timers")
	await wait(0.5)
	hud.router.close_all()
	await wait(0.35)
	hud.router.open(&"garage")
	await wait(0.6)
	print("açılış garajı ", screen.current_garage(), " odak ", screen.shown_vehicle())
	screen.go_to_garage(CarGarageCatalog.SANAYI)
	await wait(1.5)
	var view: GarageInteriorView = screen.get("_interior_view")
	var id: StringName = screen.shown_vehicle()
	print("sanayi odak ", id, " var ", view.has_car(id))
	var car: Node3D = (view.get("_cars") as Dictionary).get(id) as Node3D
	if car:
		print("araç ", car.get_path(), " görünür ", car.is_visible_in_tree(), " konum ", car.global_position, " ölçek ", car.scale)
		for mi: Node in car.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = mi as MeshInstance3D
			if m.visible:
				print("  görünür mesh ", m.name, " yüzey ", m.mesh.get_surface_count() if m.mesh else -1)
		var visible: int = 0
		for mi: Node in car.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).is_visible_in_tree():
				visible += 1
		print("  görünür mesh sayısı ", visible)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/home/burak/Projects/ct_shots/garaj3d/akis.png")
	quit(0)
