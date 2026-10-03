extends SceneTree
## GARAJ DÜZENLEYİCİSİ — GÖRSEL QA (şartname §37).
##
## Her boy / türden temsilci eşyayı düzenleyicinin kendi yoluyla (hayalet → boş yer → YERLEŞTİR)
## garaja koyar, bazılarını döndürür, duvar eşyalarını iki duvara asar, kaplama uygular; sonra
## genel + yakın plan + normal mod + 4. seviye görüntüleri alır ve ölçer:
##   taban zeminde mi (gömülme / havada durma), iz garajın içinde mi, başka eşyayla / tamir
##   alanıyla çakışıyor mu, duvar eşyası duvara yaslı mı, eşya ekrandaki ortasından seçilebiliyor mu.
##
##   godot-4 --path . --resolution 1152x648 -s res://qa/garaj_gorsel_qa.gd [-- <seviye>]
## Görüntüler: /home/burak/Projects/ct_shots/editor/qa/

const OUT: String = "/home/burak/Projects/ct_shots/editor/qa/"
## Şartnamedeki gruplar → temsilci eşyalar (katalogda gerçekten olanlar).
const GROUPS: Dictionary = {
	"küçük": [&"jerry_cans", &"traffic_cones", &"extinguisher_stand"],
	"orta": [&"tool_cabinet", &"tyre_rack", &"compressor"],
	"büyük": [&"container", &"car_lift", &"water_tower"],
	"uzun": [&"bench", &"barrier", &"speed_bump", &"bollards"],
	"masa": [&"coffee_table", &"picnic_table", &"foosball"],
	"sandalye": [&"deck_chair", &"sofa"],
	"tabela": [&"warning_sign", &"arrow_sign", &"parking_sign"],
	"garaj eşyası": [&"workbench", &"engine_block", &"mechanic", &"motorcycle"],
	"duvar": [&"wall_clock", &"wall_poster", &"neon_garage", &"neon_sign"],
}

var fails: int = 0
var decor: DecorManager
var view: GarageDecorView
var editor: GarageEditor
var camera: WorldCamera
var router: UiRouter


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
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var level: int = int(args[0]) if args.size() > 0 else 3
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	decor = get_first_node_in_group("decor")
	view = get_first_node_in_group("garage_decor_view")
	editor = get_first_node_in_group("garage_editor")
	camera = get_root().get_camera_3d() as WorldCamera
	var hud: Node = current_scene.find_child("HUD", true, false)
	router = hud.get("router")
	var save: SaveManager = get_first_node_in_group("save_manager")
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	save.new_game()
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: level})
	await frames(10)
	var owned: Dictionary = {"floor_tile": 1, "wall_brick": 1}
	for group: String in GROUPS:
		for id: StringName in GROUPS[group]:
			owned[String(id)] = 1
	decor.load_state({"owned": owned})
	router.open(&"garage_edit")
	await frames(30)
	print("== garaj seviyesi %d, alan %s ==" % [level, view.area().floor_rect])

	print("== YERLEŞTİRME (düzenleyicinin boş yer araması) ==")
	var placed: Dictionary = {}   # id → iid
	var worst_ms: float = 0.0
	var worst_id: StringName = &""
	for group: String in GROUPS:
		for id: StringName in GROUPS[group]:
			var t0: int = Time.get_ticks_usec()
			var ok: bool = editor.begin_place(id) and editor.confirm_ghost()
			var ms: float = (Time.get_ticks_usec() - t0) / 1000.0
			if ms > worst_ms:
				worst_ms = ms
				worst_id = id
			if ok:
				placed[id] = editor.selected()
			else:
				editor.cancel_ghost()
			var s: Vector2 = view.footprint_size(id)
			print("   %-13s %-18s iz %.2f×%.2f  %s" % [group, id, s.x, s.y, "YERLEŞTİ " + editor.selected() if ok else "YER YOK"])
	print("   en yavaş yerleştirme (hayalet + boş yer araması + YERLEŞTİR): %.1f ms (%s, %d örnek varken)" % [
		worst_ms, worst_id, decor.instance_count()])
	await frames(4)
	editor.apply_surface(DecorManager.SURFACE_FLOOR, &"floor_tile")
	editor.apply_surface(DecorManager.SURFACE_WALL, &"wall_brick")
	editor.select("")
	await frames(20)
	print("== A) SIKIŞIK DİZİLİŞ (en kötü durum) ==")
	_measure(placed)
	await _shot("01_sikisik")
	await _check_pick(placed, "sıkışık")

	print("== B) DAĞINIK DİZİLİŞ: aralıklı ızgara, bazıları 45° / 90° ==")
	var a: DecorArea = view.area()
	var r: Rect2 = a.floor_rect
	var slots: Array[Vector3] = []
	var z: float = r.position.y + 0.3
	while z < r.end.y - 0.2:
		var x: float = r.position.x + 0.35
		while x < r.end.x - 0.25:
			slots.append(Vector3(x, a.floor_y, z))
			x += 0.62
		z += 0.55
	var turns: Dictionary = {&"bench": 1, &"barrier": 2, &"picnic_table": 1, &"sofa": 2, &"car_lift": 1,
		&"motorcycle": 1, &"speed_bump": 2, &"deck_chair": 3}
	var moved: int = 0
	for id: StringName in placed:
		if GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			continue
		for i: int in slots.size():
			if editor.move_to(placed[id], view.place_point(id, _xz(slots[i]), 0.0, editor.snap_step())["pos"], 0.0):
				slots.remove_at(i)
				moved += 1
				break
		editor.select(placed[id])
		for k: int in int(turns.get(id, 0)):
			if not editor.rotate_selected(1):
				print("   %s döndürülemedi" % id)
	# Duvar eşyaları: ikisi arka, ikisi sol duvara, aralıklı
	var walls: Array[StringName] = [&"wall_clock", &"wall_poster", &"neon_garage", &"neon_sign"]
	for i: int in walls.size():
		if not placed.has(walls[i]):
			continue
		var side: StringName = &"back" if i % 2 == 0 else &"left"
		var span: Vector2 = a.back_span if side == &"back" else a.left_span
		var along: float = lerpf(span.x, span.y, 0.3 if i < 2 else 0.7)
		var mount: Dictionary = a.mount_on(side, along, view.wall_width(walls[i]))
		if not editor.move_to(placed[walls[i]], mount["position"], float(mount["yaw"])):
			print("   %s duvara taşınamadı" % walls[i])
	editor.select("")
	print("   %d zemin eşyası aralıklı dizildi" % moved)
	await frames(10)
	_measure(placed)
	camera.frame_box(AABB(Vector3(r.position.x, a.floor_y, r.position.y), Vector3(r.size.x, a.wall_top - a.floor_y, r.size.y)),
		0.12, 0.62, 0.04)
	await frames(40)
	await _shot("02_daginik_genel")
	await _check_pick(placed, "dağınık")
	# Yakın plan: 3×2 bölge, en yakın zumda
	var cols: int = 3
	var rows: int = 2
	for row: int in rows:
		for col: int in cols:
			var cell: Vector2 = r.size / Vector2(cols, rows)
			var q: Rect2 = Rect2(r.position + cell * Vector2(col, row), cell)
			camera.frame_box(AABB(Vector3(q.position.x, a.floor_y, q.position.y), Vector3(q.size.x, 0.25, q.size.y)),
				0.10, 0.62, 0.02)
			await frames(40)
			await _shot("03_yakin_%d%d" % [row + 1, col + 1])

	print("== NORMAL MOD ==")
	(router.screen(&"garage_edit") as GarageEditScreen).close()
	await frames(40)
	await _shot("04_normal_mod")

	print("== EN BÜYÜK GARAJ: duvar eşyaları yeni duvarda, zemin eşyaları yerinde ==")
	var before: Dictionary = {}
	for id: StringName in placed:
		before[id] = decor.instance(placed[id])["pos"]
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 4})
	await frames(10)
	var a4: DecorArea = view.area()
	var wall_ok: bool = true
	var floor_ok: bool = true
	for id: StringName in placed:
		var body: Node3D = view.body_of(placed[id])
		var box: AABB = GarageDecorView._tree_box(body)
		if GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			var yaw: float = float((decor.instance(placed[id])["rot"] as Vector3).y)
			var gap: float = box.position.z - a4.back_face_z if DecorArea.wall_side(yaw) == &"back" else box.position.x - a4.left_face_x
			wall_ok = wall_ok and absf(gap) < 0.006
		else:
			floor_ok = floor_ok and Vector2(body.global_position.x, body.global_position.z).is_equal_approx(
				Vector2((before[id] as Vector3).x, (before[id] as Vector3).z))
	check(wall_ok, "duvar eşyaları büyüyen garajın duvarına yeniden asıldı")
	check(floor_ok, "zemin eşyaları yerinde kaldı")
	router.open(&"garage_edit")
	await frames(40)
	await _shot("05_seviye4_duzenleme")
	print("RESULT fails=%d" % fails)
	quit(0 if fails == 0 else 1)


## Sayısal kontroller: taban zeminde, iz garajda, çakışma yok, duvar eşyası duvara yaslı.
## Her eşya GÖRÜNEN yüzeyinden seçilebiliyor mu? Eşyanın üçgen ortaları ekrana izdüşürülür ve
## oradan seçim yapılır; en az bir noktadan kendisi seçiliyorsa seçilebilir. (Kutu ortası ölçütü
## yanıltıcıydı: sıkışık dizilişte o piksel öndeki eşyanın gerçekten görünen yüzeyi olabiliyor ve
## öndekini seçmek doğru.) Ayrıca kutu ortasından doğrudan seçilen eşya sayısı da yazılır.
func _check_pick(placed: Dictionary, label: String) -> void:
	await frames(2)
	var hidden: Array[String] = []
	var center_hits: int = 0
	for id: StringName in placed:
		var body: Node3D = view.body_of(placed[id])
		var box: AABB = GarageDecorView._tree_box(body)
		if view.pick(camera, camera.unproject_position(box.get_center())) == placed[id]:
			center_hits += 1
		var found: bool = false
		for point: Vector3 in _surface_samples(body, 48):
			if view.pick(camera, camera.unproject_position(point)) == placed[id]:
				found = true
				break
		if not found:
			hidden.append(String(id))
	var t0: int = Time.get_ticks_usec()
	for i: int in 20:
		view.pick(camera, get_root().get_visible_rect().size * 0.5)
	print("   seçim (pick) ortalaması: %.2f ms · refresh: %.1f ms" % [(Time.get_ticks_usec() - t0) / 20000.0, _time_refresh()])
	print("   %s: kutu ortasından seçilen %d / %d · görünen yüzeyinden seçilemeyen %s" % [label, center_hits,
		placed.size(), hidden])
	# Tamamen örtülen eşyanın görünen yüzeyi yoktur; onlar aşağıda art arda dokunuşla sınanır.
	check(label == "sıkışık" or hidden.is_empty(), "%s dizilişte görünen her eşya görünen yüzeyinden seçiliyor (%d / %d, tamamen örtülü %d)" % [
		label, placed.size() - hidden.size(), placed.size(), hidden.size()])
	# Tamamen örtülenler: aynı noktaya art arda dokunarak seçilip sürüklenebiliyor mu?
	for id: String in hidden:
		var iid: String = placed[StringName(id)]
		var body: Node3D = view.body_of(iid)
		var box: AABB = GarageDecorView._tree_box(body)
		camera.frame_box(box.grow(0.25), 0.15, 0.6, 0.3)
		await frames(40)
		editor.select("")
		var top: Vector2 = camera.unproject_position(Vector3(box.get_center().x, box.end.y, box.get_center().z))
		var taps: int = 0
		while editor.selected() != iid and taps < 8:
			editor._on_press(top)
			editor._on_release(top)
			taps += 1
		check(editor.selected() == iid, "%s: öndekilerin arkasında, aynı noktaya %d dokunuşta seçildi" % [id, taps])
		# Seçildikten sonra aynı noktadan sürüklenince ÖNDEKİ değil bu eşya taşınır
		editor._on_press(top)
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = top + Vector2(0.0, 40.0)
		editor._unhandled_input(motion)
		check(bool(editor.get("_dragging")) and String(editor.get("_press_target")) == iid, "%s: sürüklenen eşya kendisi" % id)
		editor._end_drag(false)
		editor.set("_pressing", false)
		await frames(2)
		await _shot("01_gizli_%s" % id)
		editor.select("")


## Gövdenin üçgen ortalarından en çok `count` tanesi (dünya koordinatı), eşit aralıklı.
static func _surface_samples(body: Node3D, count: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var parts: Array[MeshInstance3D] = []
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		stack.append_array(node.get_children())
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			parts.append(node)
	for part: MeshInstance3D in parts:
		var faces: PackedVector3Array = part.mesh.get_faces()
		var tris: int = faces.size() / 3
		var stride: int = maxi(tris * parts.size() / count, 1)
		for t: int in range(0, tris, stride):
			out.append(part.global_transform * ((faces[t * 3] + faces[t * 3 + 1] + faces[t * 3 + 2]) / 3.0))
	return out


func _time_refresh() -> float:
	var t0: int = Time.get_ticks_usec()
	view.refresh()
	return (Time.get_ticks_usec() - t0) / 1000.0


static func _xz(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _measure(placed: Dictionary) -> void:
	var a: DecorArea = view.area()
	var problems: Array[String] = []
	for id: StringName in placed:
		var inst: Dictionary = decor.instance(placed[id])
		var body: Node3D = view.body_of(placed[id])
		var box: AABB = GarageDecorView._tree_box(body)
		var yaw: float = float((inst["rot"] as Vector3).y)
		if GarageDecor.placement(id) == GarageDecor.PLACE_WALL:
			var gap: float = box.position.z - a.back_face_z if DecorArea.wall_side(yaw) == &"back" else box.position.x - a.left_face_x
			if absf(gap) > 0.006:
				problems.append("%s duvardan %.3f uzak" % [id, gap])
			if box.position.y < a.floor_y + 0.02 or box.end.y > a.wall_top + 0.2:
				problems.append("%s duvarda yanlış yükseklikte (%.2f–%.2f)" % [id, box.position.y, box.end.y])
			continue
		if box.position.y < a.floor_y - 0.001:
			problems.append("%s zemine gömülü (%.3f)" % [id, box.position.y - a.floor_y])
		elif box.position.y > a.floor_y + 0.004:
			problems.append("%s havada (+%.3f)" % [id, box.position.y - a.floor_y])
		var poly: PackedVector2Array = view.footprint(id, inst["pos"], yaw)
		if not a.inside_floor(poly):
			problems.append("%s garaj dışına taşıyor" % id)
		if a.hits_obstacle(poly):
			problems.append("%s tamir alanında / tabelada" % id)
		if not view.is_valid(id, inst["pos"], yaw, placed[id]):
			problems.append("%s geçersiz konumda" % id)
	print("   ölçüm sorunları: %s" % [problems])
	check(problems.is_empty(), "%d eşyada taban, sınır, çakışma ve duvar ölçümleri temiz" % placed.size())


func _shot(name: String) -> void:
	await frames(3)
	# Pencere çizilmiyorsa (arka planda / örtülü) kare sonu sinyali gelmez ve küçük resim kuyruğu
	# bekler; görüntüden önce kuyruk zorla çizdirilerek boşaltılır (yalnızca QA'da).
	var edit_screen: Node = router.screen(&"garage_edit")
	var pump: Node = edit_screen.get("_thumbs") if edit_screen else null
	for i: int in 60:
		if pump == null or not bool(pump.get("_pumping")):
			break
		RenderingServer.force_draw()
		await process_frame
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	var screen: Node = router.screen(&"garage_edit")
	var thumbs: Node = screen.get("_thumbs") if screen else null
	print("   görüntü: %s%s.png · küçük resim önbelleği %d, kuyruk %d, pompa %s" % [OUT, name, DecorThumbs._cache.size(),
		(thumbs.get("_queue") as Array).size() if thumbs else -1, thumbs.get("_pumping") if thumbs else "-"])
