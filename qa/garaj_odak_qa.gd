extends SceneTree
## GARAJ DÜZENLEME ODAĞI — telefondaki geri bildirimin sınaması: düzenlerken yarış rakibinin balonu
## ve tamir alanındaki araç garajın önünü kapatmamalı; garajın dışı bulanık / soluk / koyu olmalı.
##
## Sahne: rakip davetini açar (🏁 balonu), bir trafik aracı 1. tamir alanına girer (TAMİR balonu).
## Normal mod → düzenleme → BİTİR; her adımda ölçer ve fotoğraflar:
##   - tamir alanındaki araç düzenlerken gizli, sonra geri
##   - balon katmanı (WorldCamera.LAYER_WORLD_UI) düzenlerken kamerada kapalı, sonra açık; balonun
##     araç mantığındaki görünürlüğüne dokunulmuyor
##   - odak AYNI karede kapalı / açık ölçülür: garajın dışındaki bölge belirgin kararır ve
##     bulanıklaşır, garaj zemininin ortası değişmez
##   godot-4 --path . --resolution 1170x540 -s res://qa/garaj_odak_qa.gd
## Görüntüler: /home/burak/Projects/ct_shots/editor/odak/

const OUT: String = "/home/burak/Projects/ct_shots/editor/odak/"

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


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
	(get_first_node_in_group("garage_upgrades") as GarageUpgradeManager).apply_levels(
		{GarageUpgradeManager.GARAGE_ID: 2})
	await frames(20)
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	var editor: GarageEditor = get_first_node_in_group("garage_editor")
	var race: Node = get_first_node_in_group("race")
	var repair: RepairManager = get_first_node_in_group("repair_manager")
	var traffic: TrafficManager = _find_traffic(current_scene)

	print("== SAHNE: rakip daveti + tamir alanında araç ==")
	# Rakibin modeli arka planda yüklenir: gelene kadar yeniden dene (en çok ~10 sn)
	for attempt: int in 30:
		race.call("request_challenge_now")
		if bool(race.call("has_challenge")):
			break
		await frames(20)
	check(bool(race.call("has_challenge")), "rakip geldi, davet açık")
	await frames(10)
	var challenger: TrafficVehicle = race.call("challenger")
	check(challenger != null and challenger.bubble_visible(), "rakibin 🏁 balonu açık")
	var bay_car: TrafficVehicle = null
	for vehicle: TrafficVehicle in traffic.vehicles:
		if vehicle != challenger and vehicle.mode == TrafficVehicle.Mode.TRAFFIC:
			bay_car = vehicle
			break
	var spot: Node3D = repair.repair_car_spots[0]
	bay_car.enter_bay(spot.global_position, spot.global_rotation.y)
	await frames(10)
	check(bay_car.in_bay() and bay_car.visible, "1. tamir alanında araç var (TAMİR balonu)")
	# Balonları ve aracı kadraja alan görünüm: garajın önü
	camera.frame_box(AABB(Vector3(-4.3, 0.0, -3.3), Vector3(4.3, 0.5, 3.5)), 0.1, 0.9, 0.05)
	await frames(40)
	await _shot("01_normal")

	print("== DÜZENLEME ==")
	var edit_button: Control = hud.get("edit_button")
	router.open(&"garage_edit")
	await frames(40)
	check(editor.active, "düzenleme açık")
	check(not bay_car.visible, "tamir alanındaki araç gizlendi")
	check(challenger == null or not challenger.visible, "yoldaki rakip aracı da gizlendi")
	check(bay_car.in_bay() and bay_car.mode == TrafficVehicle.Mode.REPAIR_BAY, "aracın tamiri sürüyor (mantık değişmedi)")
	check(camera.cull_mask & WorldCamera.LAYER_WORLD_UI == 0, "balon katmanı kamerada kapalı")
	check(challenger != null and challenger.bubble_visible(), "rakibin balonu mantıkta hâlâ açık (yalnızca çizilmiyor)")
	var focus: GarageFocus = editor.get("_focus")
	check(focus.visible and focus.strength() > 0.99, "odak açık (güç %.2f)" % focus.strength())
	await _shot("02_duzenleme")

	print("== ODAK ETKİSİ: aynı karede kapalı / açık ==")
	var area: DecorArea = (get_first_node_in_group("garage_decor_view") as GarageDecorView).area()
	var floor_center: Vector2 = camera.unproject_position(Vector3(area.floor_rect.get_center().x, area.floor_y,
		area.floor_rect.get_center().y))
	var size: Vector2 = get_root().get_visible_rect().size
	var k: float = float(DisplayServer.window_get_size().y) / size.y
	var inside: Rect2i = Rect2i(Vector2i((floor_center - Vector2(30, 20)) * k), Vector2i(Vector2(60, 40) * k))
	var outside: Rect2i = Rect2i(Vector2i(Vector2(10, 10) * k), Vector2i(Vector2(size.x * 0.18, size.y * 0.25) * k))
	focus.set_strength(0.0)
	await frames(3)
	var off: Image = await _grab()
	focus.set_strength(1.0)
	await frames(3)
	var on: Image = await _grab()
	var lum_out_off: float = _mean_luma(off, outside)
	var lum_out_on: float = _mean_luma(on, outside)
	var lum_in_off: float = _mean_luma(off, inside)
	var lum_in_on: float = _mean_luma(on, inside)
	var sharp_off: float = _detail(off, outside)
	var sharp_on: float = _detail(on, outside)
	print("   dış bölge parlaklık %.3f → %.3f · ayrıntı %.4f → %.4f" % [lum_out_off, lum_out_on, sharp_off, sharp_on])
	print("   garaj zemini ortası parlaklık %.3f → %.3f" % [lum_in_off, lum_in_on])
	check(lum_out_on < lum_out_off * 0.7, "garajın dışı belirgin karardı (%%%d)" % int(100.0 * (1.0 - lum_out_on / maxf(lum_out_off, 0.001))))
	check(sharp_on < sharp_off * 0.6, "garajın dışı bulanıklaştı (ayrıntı %%%d azaldı)" % int(100.0 * (1.0 - sharp_on / maxf(sharp_off, 0.0001))))
	check(absf(lum_in_on - lum_in_off) < 0.01, "garajın içi değişmedi (fark %.4f)" % absf(lum_in_on - lum_in_off))

	print("== BİTİR ==")
	(router.screen(&"garage_edit") as GarageEditScreen).close()
	await frames(40)
	check(not editor.active, "düzenleme kapandı")
	check(bay_car.visible, "tamir alanındaki araç geri geldi")
	check(challenger == null or challenger.visible, "rakip aracı geri geldi")
	check(camera.cull_mask & WorldCamera.LAYER_WORLD_UI != 0, "balon katmanı geri açıldı")
	check(not focus.visible, "odak katmanı kapandı (çizilmiyor)")
	await _shot("03_normal_geri")
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


func _grab() -> Image:
	await RenderingServer.frame_post_draw
	return get_root().get_texture().get_image()


func _shot(name: String) -> void:
	await frames(3)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("   görüntü: %s%s.png" % [OUT, name])


static func _mean_luma(img: Image, rect: Rect2i) -> float:
	var sum: float = 0.0
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y, 2):
		for x: int in range(rect.position.x, rect.end.x, 2):
			var c: Color = img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))
			sum += c.get_luminance()
			n += 1
	return sum / maxf(n, 1)


## Komşu pikseller arası ortalama fark: bulanıklık bunu düşürür.
static func _detail(img: Image, rect: Rect2i) -> float:
	var sum: float = 0.0
	var n: int = 0
	for y: int in range(rect.position.y, rect.end.y - 1, 2):
		for x: int in range(rect.position.x, rect.end.x - 1, 2):
			var a: float = img.get_pixel(x, y).get_luminance()
			sum += absf(a - img.get_pixel(x + 1, y).get_luminance()) + absf(a - img.get_pixel(x, y + 1).get_luminance())
			n += 1
	return sum / maxf(n, 1)


func _find_traffic(node: Node) -> TrafficManager:
	if node is TrafficManager:
		return node
	for child: Node in node.get_children():
		var found: TrafficManager = _find_traffic(child)
		if found:
			return found
	return null
