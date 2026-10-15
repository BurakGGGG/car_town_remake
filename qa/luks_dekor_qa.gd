extends SceneTree
## LÜKS DEKOR GÖRSEL QA — elmasla satılan 24 eşyayı gerçek Main.tscn'de garaja dizer (zemindekiler iki tur,
## duvardakiler arka / sol duvara), genel ve yakın kareleri çeker; düzenleme paletinde LÜKS sekmesini ve
## ilk dokunuştaki onay yazısını gösterir. Yalıtılmış kayıtla:
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/luks_dekor_qa.gd --display-driver x11 --disable-vsync \
##     --resolution 1152x648 [-- telefon]
## Çıktı: ~/Projects/ct_shots/luks_dekor/
const OUT: String = "/home/burak/Projects/ct_shots/luks_dekor/"

var _fails: int = 0
var hud: Hud
var decor: DecorManager
var view: GarageDecorView


func check(ok: bool, what: String) -> void:
	print(("  OK   " if ok else "  FAIL ") + what)
	if not ok:
		_fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(file: String) -> void:
	await frames(4)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + file)
	print("  foto: ", file)


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("telefon"):
		get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _luxury(placement: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for item: Dictionary in GarageDecor.shop_order(GarageDecor.Kind.LUXURY):
		if GarageDecor.placement(item["id"]) == placement:
			out.append(item["id"])
	return out


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	hud = current_scene.find_child("HUD", true, false)
	decor = get_first_node_in_group("decor") as DecorManager
	view = get_first_node_in_group("garage_decor_view") as GarageDecorView
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	var pp: PlayerProgress = get_first_node_in_group("player_progress") as PlayerProgress
	pp.load_state(12, 0, 20000)
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 3})
	await frames(30)

	var floor_items: Array[StringName] = _luxury(GarageDecor.PLACE_FLOOR)
	var wall_items: Array[StringName] = _luxury(GarageDecor.PLACE_WALL)
	check(floor_items.size() + wall_items.size() >= 20, "en az 20 lüks eşya (%d zemin + %d duvar)" % [
		floor_items.size(), wall_items.size()])
	var bad: Array[StringName] = []
	for id: StringName in floor_items + wall_items:
		if not DecorBuilder.has_model(id) or GarageDecor.gem_price(id) <= 0 or not decor.is_unlocked(id):
			bad.append(id)
	check(bad.is_empty(), "her lüks eşyanın modeli, elmas fiyatı var ve kilitsiz %s" % [bad])

	# --- Duvar: arka ve sol duvar boyunca ------------------------------------------------
	var slots: Array = []
	for side: String in ["back", "left"]:
		var f: Dictionary = view.area().face(side)
		var span: Vector2 = f["span"]
		var along: float = span.x + 0.15
		while along < span.y - 0.15:
			slots.append([side, along])
			along += 0.06
	var slot_i: int = 0
	var hung: int = 0
	for id: StringName in wall_items:
		check(decor.purchase(id), "satın alındı: %s (%d GEM)" % [id, GarageDecor.gem_price(id)])
		while slot_i < slots.size():
			var m: Dictionary = view.area().mount_on(slots[slot_i][0], slots[slot_i][1], view.wall_width(id))
			slot_i += 1
			if view.is_valid(id, m["position"], float(m["yaw"])):
				decor.add_instance(id, m["position"], float(m["yaw"]))
				hung += 1
				slot_i += 3
				break
	check(hung == wall_items.size(), "duvar eşyaları asıldı (%d / %d)" % [hung, wall_items.size()])

	# --- Zemin: büyükten küçüğe, garajın arkasından öne ------------------------------------
	var big_first: Array[StringName] = floor_items.duplicate()
	big_first.reverse()
	var placed: int = await place_all(big_first)
	check(placed >= floor_items.size() - 2, "zemin eşyaları yerleşti (%d / %d)" % [placed, floor_items.size()])
	await frames(40)
	await shot("01_genel.png")
	var cam: WorldCamera = get_root().get_camera_3d() as WorldCamera
	if cam:
		var boxes: Array = []
		for inst: Dictionary in decor.instances():
			if GarageDecor.is_gem_item(StringName(inst["item"])):
				var pos: Vector3 = inst["pos"]
				boxes.append(pos)
		# Yakın plan: eşyaları dörder dörder çerçevele
		var k: int = 0
		while k < boxes.size():
			var box: AABB = AABB(boxes[k], Vector3(0.05, 0.05, 0.05))
			for j: int in range(k, mini(k + 4, boxes.size())):
				box = box.expand(boxes[j])
			box = box.grow(0.35)
			box.size.y = 0.5
			cam.frame_box(box, 0.10, 0.90)
			await frames(50)
			await shot("%02d_yakin.png" % (2 + k / 4))
			k += 4

	# --- Tek tek yakın plan: oyunun ışığında, eşyaya bakan geçici kamera ----------------------
	var world_cam: Camera3D = get_root().get_camera_3d()
	var close: Camera3D = Camera3D.new()
	close.fov = 32.0
	current_scene.add_child(close)
	var sheet: Array[Image] = []
	for inst: Dictionary in decor.instances():
		var id: StringName = StringName(inst["item"])
		if not GarageDecor.is_gem_item(id):
			continue
		var size: Vector3 = DecorBuilder.local_size(id) * GarageDecorView.WORLD_SCALE
		var center: Vector3 = view.to_global(inst["pos"]) + Vector3(0.0, size.y * 0.5, 0.0)
		var reach: float = maxf(maxf(size.x, size.z), size.y) * 2.3 + 0.05
		var dir: Vector3 = Vector3(0.55, 0.62, 0.95).normalized()   # oyun kamerasına yakın açı (önden, yukarıdan)
		if GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			var yaw: float = deg_to_rad(float(inst["rot"].y if inst["rot"] is Vector3 else 0.0))
			dir = (Basis(Vector3.UP, yaw) * Vector3(0.25, 0.35, 1.0)).normalized()
		close.position = center + dir * reach
		close.look_at(center, Vector3.UP)
		close.make_current()
		await frames(8)
		RenderingServer.force_draw()
		var img: Image = get_root().get_texture().get_image()
		img.resize(384, 216)
		sheet.append(img)
	if world_cam:
		world_cam.make_current()
	close.queue_free()
	var cols: int = 4
	var rows: int = ceili(float(sheet.size()) / cols)
	var page: Image = Image.create(384 * cols, 216 * rows, false, Image.FORMAT_RGBA8)
	for k: int in sheet.size():
		sheet[k].convert(Image.FORMAT_RGBA8)
		page.blit_rect(sheet[k], Rect2i(Vector2i.ZERO, sheet[k].get_size()), Vector2i((k % cols) * 384, (k / cols) * 216))
	page.save_png(OUT + "09_tek_tek.png")
	print("  foto: 09_tek_tek.png (%d eşya)" % sheet.size())

	# --- Düzenleme paleti: LÜKS sekmesi, ilk dokunuş onayı, elmas yetmeyince ---------------
	hud.router.open(&"garage_edit")
	await frames(50)
	var es: GarageEditScreen = hud.garage_edit_screen
	es._on_tab_pressed(GarageDecor.Kind.LUXURY)
	await frames(40)
	await shot("10_palet_luks.png")
	es.call("_on_card_pressed", &"lux_helicopter")
	await frames(20)
	await shot("11_onay.png")
	pp.load_state(12, 0, 30)
	es.set("_confirm_buy", &"")
	es.call("_on_card_pressed", &"lux_marble_fountain")
	await frames(40)
	check(hud.router.top() == &"gem_store", "elmas yetmeyince GEM MAĞAZASI açıldı (%s)" % hud.router.top())
	await shot("12_elmas_yetmedi.png")
	print("SONUC: fails=%d" % _fails)
	quit()


## Eşyaları sırayla, garajın arkasından öne tarayarak ilk geçerli yere koyar (aralarında boşluk).
func place_all(ids: Array[StringName]) -> int:
	var placed: int = 0
	for id: StringName in ids:
		if not decor.purchase(id):
			print("  alınamadı: ", id)
			continue
		var done: bool = false
		for j: int in range(1, 60):
			for i: int in range(1, 70):
				var p: Vector2 = DecorGrid.CORNER - Vector2(float(i) * 0.5, float(j) * 0.5) * DecorGrid.CELL
				var pos: Vector3 = Vector3(p.x, 0.0, p.y)
				if view.is_valid(id, pos, 0.0) and _clear_of_others(id, pos):
					decor.add_instance(id, pos, 0.0)
					placed += 1
					done = true
					break
			if done:
				break
		if not done:
			print("  yer yok: ", id)
	await frames(10)
	return placed


func _clear_of_others(id: StringName, pos: Vector3) -> bool:
	var pad: float = DecorGrid.CELL * 0.6
	for offset: Vector3 in [Vector3(pad, 0, 0), Vector3(-pad, 0, 0), Vector3(0, 0, pad), Vector3(0, 0, -pad)]:
		if not view.is_valid(id, pos + offset, 0.0):
			return false
	return true
