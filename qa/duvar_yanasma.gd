extends SceneTree
## DUVARA YANAŞMA ÖLÇÜMÜ — eşyayı sürükleyerek arka-sol köşeye itince duvara ne kadar boşluk kalıyor?
## Editörün kullandığı yolu (place_point + is_valid) taklit eder: işaret köşeye doğru adım adım
## kayar, geçerli kalan en yakın konum alınır. Her seviye için ölçer ve ekran görüntüsü alır.
##   godot-4 --path . --resolution 1152x648 -s res://qa/duvar_yanasma.gd   (override.cfg ile yalıtılmış kayıt)

const OUT: String = "/home/burak/Projects/ct_shots/duvar_yanasma/"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	await frames(10)
	var garage: Node = get_first_node_in_group("garage_system")
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var editor: GarageEditor = get_first_node_in_group("garage_editor")
	var decor: DecorManager = get_first_node_in_group("decor")
	var items: Array[StringName] = []
	for d: Dictionary in GarageDecor.all():
		var id: StringName = StringName(d["id"])
		if GarageDecor.is_placeable(id) and GarageDecor.placement(id) != GarageDecor.PLACE_WALL \
				and not GarageDecor.is_vehicle(id):
			items.append(id)
		if items.size() >= 4:
			break
	for level: int in 4:
		garage.call("set_level", level)
		await frames(5)
		view.refresh()
		await frames(5)
		var a: DecorArea = view.area()
		var lot: Rect2 = view.lot_rect()
		print("== Seviye %d · lot %s · sol yüz x=%.4f · arka yüz z=%.4f · zemin %s" % [level + 1, lot,
			a.left_face_x, a.back_face_z, a.floor_rect])
		for item: StringName in items:
			var size: Vector2 = view.footprint_size(item)
			var step: float = editor.snap_step()
			var best: Vector3 = Vector3.INF
			# işareti köşeye doğru sürükle: geçerli kalan son konum
			var start: Vector2 = Vector2(lot.position.x + 1.0, lot.position.y + 0.8)
			for i: int in 200:
				var ground: Vector2 = start.lerp(lot.position - Vector2(0.3, 0.3), float(i) / 199.0)
				var p: Dictionary = view.place_point(item, ground, 0.0, step)
				if view.is_valid(item, p["pos"], 0.0):
					best = p["pos"]
			if best == Vector3.INF:
				print("   %-18s yerleşemedi" % item)
				continue
			var gap_left: float = (best.x - size.x * 0.5) - a.left_face_x
			var gap_back: float = (best.z - size.y * 0.5) - a.back_face_z
			print("   %-18s iz %.3f×%.3f · sola boşluk %.4f · arkaya boşluk %.4f" % [item, size.x, size.y,
				gap_left, gap_back])
		if level == 0:
			await _place_showcase(view, editor, decor, items)
		await frames(10)
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(OUT + "seviye_%d.png" % (level + 1))
	quit(0)


## Seviye 1'de görsel kanıt: köşeye, arka duvar boyuna ve sol duvar boyuna eşya dayayıp yakın çekim.
func _place_showcase(view: GarageDecorView, editor: GarageEditor, decor: DecorManager,
		items: Array[StringName]) -> void:
	(get_first_node_in_group("economy") as EconomyManager).set_money(1_000_000)
	var lot: Rect2 = view.lot_rect()
	var targets: Array[Vector2] = [lot.position, Vector2(lot.position.x + 0.9, lot.position.y - 0.3),
		Vector2(lot.position.x - 0.3, lot.position.y + 0.8), Vector2(lot.position.x + 1.4, lot.position.y - 0.3)]
	for k: int in mini(items.size(), targets.size()):
		decor.purchase(items[k])
		var p: Dictionary = view.place_point(items[k], targets[k], 0.0, editor.snap_step())
		var ok: bool = view.is_valid(items[k], p["pos"], 0.0)
		print("   vitrin %-14s geçerli=%s konum %s iz %s" % [items[k], ok, p["pos"], view.footprint_size(items[k])])
		if ok:
			decor.add_instance(items[k], p["pos"], 0.0)
	await frames(10)
	var cam: WorldCamera = get_root().get_camera_3d() as WorldCamera
	cam.frame_box(AABB(Vector3(lot.position.x, 0.0, lot.position.y), Vector3(lot.size.x, 0.4, lot.size.y)), 0.1, 0.9, 0.05)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(OUT + "kose_yakin.png")
