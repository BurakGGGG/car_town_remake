extends SceneTree
## TAŞINABİLİR TAMİR ALANLARI — seçim, taşıma, döndürme, geçersiz yer, geri al, kayıt, seviye.
## Çalıştırma: tools/run_tests.sh bay_move_test

var fails: int = 0
var bays: RepairBayManager
var view: GarageDecorView
var editor: GarageEditor
var save: SaveManager
var upgrades: GarageUpgradeManager
var decor: DecorManager


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
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	bays = get_first_node_in_group("repair_bays")
	view = get_first_node_in_group("garage_decor_view")
	editor = get_first_node_in_group("garage_editor")
	save = get_first_node_in_group("save_manager")
	upgrades = get_first_node_in_group("garage_upgrades")
	decor = get_first_node_in_group("decor")
	save.new_game()
	await frames(4)
	var router: UiRouter = (current_scene.find_child("HUD", true, false)).get("router")
	router.open(&"garage_edit")
	await frames(6)

	print("== varsayılan yerler ==")
	check(bays.bay_position(0).is_equal_approx(RepairBayManager.DEFAULT_POSITIONS[0]), "1. alan varsayılan yerinde")
	var spot0: Node3D = bays.bay_node(0)
	check(Vector2(spot0.global_position.x, spot0.global_position.z).is_equal_approx(bays.bay_position(0)), "CarSpot dünyada kayıtlı yerde")
	check(view.is_bay_valid(0, bays.bay_position(0), bays.bay_yaw(0)), "varsayılan yer geçerli")

	print("== taşıma ==")
	var from: Vector2 = bays.bay_position(0)
	var to: Vector2 = from + Vector2(0.3, 0.2)
	check(editor.move_bay(0, to, 90.0), "geçerli yere taşındı")
	check(bays.bay_position(0).is_equal_approx(to), "yeni konum kayıtlı")
	check(Vector2(spot0.global_position.x, spot0.global_position.z).is_equal_approx(to), "CarSpot düğümü de taşındı")
	check(not editor.move_bay(0, Vector2(-9.0, -9.0), 90.0), "garaj dışına taşınamaz")
	check(bays.bay_position(0).is_equal_approx(to), "reddedilince yer değişmedi")
	var wall: Vector2 = Vector2(view.area().floor_rect.end.x + 0.5, to.y)
	check(not editor.move_bay(0, wall, 90.0), "zemin dışı (ön kenar) reddedildi")

	print("== döndürme ==")
	editor.select("bay:0")
	check(editor.selected_is_bay(), "bay:0 seçildi")
	var yaw: float = bays.bay_yaw(0)
	var rotated: bool = editor.rotate_selected(1)
	check(rotated == view.is_bay_valid(0, bays.bay_position(0), fposmod(yaw - 90.0, 360.0)), "döndürme geçerliliğe bağlı")
	check(not editor.delete_selected(), "tamir alanı silinemez")

	print("== geri al ==")
	if rotated:
		editor.undo()
		check(is_equal_approx(bays.bay_yaw(0), yaw) and bays.bay_position(0).is_equal_approx(to), "döndürme geri alındı")
	editor.undo()
	check(bays.bay_position(0).is_equal_approx(from), "taşıma geri alındı")

	print("== eşya ile çakışma ==")
	var a: DecorArea = view.area()
	check(not view.is_bay_valid(0, Vector2(a.floor_rect.position.x - 1.0, from.y), 90.0), "sınır dışı geçersiz")

	print("== seçim ==")
	var camera: Camera3D = get_root().get_camera_3d()
	var screen: Vector2 = camera.unproject_position(Vector3(bays.bay_position(0).x, 0.02, bays.bay_position(0).y))
	check(view.pick_all(camera, screen).has("bay:0"), "ekrandaki tamir alanı seçilebiliyor")

	print("== kayıt ==")
	check(editor.move_bay(0, from + Vector2(0.2, 0.0), 0.0), "kayıt için taşındı")
	var moved: Vector2 = bays.bay_position(0)
	check(save.save_game(), "kaydedildi")
	bays.set_layout(0, from, 90.0)
	check(save.load_game(), "yüklendi")
	await frames(3)
	check(bays.bay_position(0).is_equal_approx(moved) and is_equal_approx(bays.bay_yaw(0), 0.0), "yer ve yön yüklemede geri geldi")
	bays.load_layout("bozuk")
	check(bays.bay_position(1).is_equal_approx(RepairBayManager.DEFAULT_POSITIONS[1]), "bozuk kayıt varsayılana düşer")
	bays.load_layout([{"x": 999.0, "z": 0.0}])
	check(bays.bay_position(0).is_equal_approx(RepairBayManager.DEFAULT_POSITIONS[0]), "aralık dışı konum yok sayılır")

	print("== seviye: alanlar kendi şeridinde ==")
	router.close_all() if router.has_method("close_all") else null
	for i: int in 3:
		var lot_ok: bool = true
		upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: i + 1})
		await frames(3)
		check(bays.is_bay_revealed(i), "Sv.%d: %d. alan görünür" % [i + 1, i + 1])
		check(view.is_bay_valid(i, RepairBayManager.DEFAULT_POSITIONS[i], RepairBayManager.DEFAULT_YAW),
			"Sv.%d: %d. alanın varsayılan yeri zeminin içinde" % [i + 1, i + 1])
	print("== lift ==")
	var lift: RepairLift = bays.lift(0)
	check(lift != null, "1. alanın lifti kuruldu (CarSpot çocuğu)")
	var car: Node3D = Node3D.new()
	current_scene.add_child(car)
	car.global_position = Vector3(0, 0.0, 0)
	bays.raise_lift(0, car)
	check(is_equal_approx(car.global_position.y, lift.car_y()), "araç lift yürüme yoluna oturdu")
	await create_timer(RepairLift.RAISE_TIME + 0.3).timeout
	check(is_equal_approx(lift.raised_fraction(), 1.0), "lift tamamen kalktı")
	check(is_equal_approx(car.global_position.y, lift.global_position.y + RepairLift.REST_TOP + RepairLift.RAISE_HEIGHT), "araç liftle birlikte yükseldi")
	bays.lower_lift(0)
	await create_timer(RepairLift.LOWER_TIME + 0.3).timeout
	check(is_zero_approx(lift.raised_fraction()), "lift indi")
	check(is_equal_approx(car.global_position.y, lift.car_y()), "araç alçak liftte")
	bays.release_lift(0)
	check(is_zero_approx(car.global_position.y), "ayrılınca eski kotuna döndü")
	check(not GarageDecor.all().any(func(i: Dictionary) -> bool: return i["id"] == &"car_lift")
		and GarageDecor.exists(&"car_lift"), "dekor lifti mağazadan kalktı ama eski kayıtta yüklenebilir")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
