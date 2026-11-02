extends SceneTree
## GARAJ DOSTLARI (2026-10-31) — kedi verisi ve garajdaki kedi:
##   - kedisiz başlar; sv5'e YENİ ulaşınca geliş hazır olur (arrival_ready); sv5'i geçmiş eski oyuncuya açılışta gelmez,
##     bir sonraki seviye atlayışında gelir
##   - ad zorunlu (boş ad reddedilir), sahiplenince PetWorld kediyi garaja koyar
##   - sevme bekleme süresi puanı şişirmez; numaralar eşiklerde açılır (trick_unlocked bir kez)
##   - kayıt / yükleme: ad, dostluk, aksesuar, takılı aksesuar; bozuk kayıt güvenli
##   - kedi zeminde, garaj sınırları içinde; yol bulma engelleri (dekor) içinden geçmez
##   - ad kuralları (en az 2 harf, harf/rakam, uygunsuz ad süzgeci); gelişte ad ekranı GERİ ile kapanmaz
##   - aksesuar: elmasla alınır (yetmezse hiçbir şey değişmez), yuva başına bir (boyun / baş), tak / çıkar; kedinin
##     iskeletine DERİLİ takılır (bağlar adla çözülür), raftaki deneme geçicidir
##   - kedi eşyaları (yatak / kule / kap): kedi yatağa çıkıp uyur, kulenin tablasına çıkar, kabın önünde yer; üstünde
##     durduğu eşya kaldırılınca yere iner
##   - yakın kamera (PLACE pet_closeup) açılır / kapanır, kedi hayatına döner
##   - kedi sesi (PetVoice): kayıtlar var, mırlama döngülü; yalnız yakın kamerada konuşur, ilk sevmede mrrp + mırlama,
##     ağız doluyken yeni ses atlanır, kapanınca susar
##   tools/run_tests.sh pet_test

var fails: int = 0
var pets: PetManager
var world: PetWorld
var progress: PlayerProgress
var save: SaveManager


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Sıra ve içerik aynı mı (türlü / türsüz dizi karşılaştırması için).
func same(a: Array[StringName], b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i: int in a.size():
		if a[i] != b[i]:
			return false
	return true


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _initialize() -> void:
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	pets = g(&"pets") as PetManager
	world = g(&"pet_world") as PetWorld
	progress = g(&"player_progress") as PlayerProgress
	save = g(&"save_manager") as SaveManager
	check(pets != null and world != null, "PetManager ve PetWorld kuruldu")
	if pets == null or world == null:
		quit(1)
		return
	_arrival()
	await _adopt()
	_friendship()
	_save_roundtrip()
	await _world_bounds()
	await _walls_block()
	await _furniture()
	await _accessories()
	await _wear_and_fur()
	_names()
	await _voice()
	await _closeup()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _arrival() -> void:
	print("== Geliş: sv5 ödülü, eski oyuncu bir sonraki seviyede ==")
	pets.reset()
	check(not pets.is_adopted() and not pets.is_arrival_pending(), "yeni oyuncu kedisiz")
	var fired: Array[int] = [0]
	var cb: Callable = func() -> void: fired[0] += 1
	pets.arrival_ready.connect(cb)
	progress.level_up.emit(4)
	check(fired[0] == 0 and not pets.is_arrival_pending(), "sv4'te gelmez")
	progress.level_up.emit(5)
	check(fired[0] == 1 and pets.is_arrival_pending(), "sv5'e ulaşınca geliş hazır")
	progress.level_up.emit(6)
	check(fired[0] == 1, "bekleyen geliş varken tekrar yayınlanmaz")
	# Eski oyuncu: kayıtta sv12, kedi yok → yüklemede geliş YOK, ilk seviye atlayışında var
	pets.load_state({})
	check(not pets.is_arrival_pending(), "sv5'i geçmiş eski kayıt yüklenince geliş yok")
	progress.level_up.emit(13)
	check(fired[0] == 2 and pets.is_arrival_pending(), "eski oyuncu bir sonraki seviyede kediyi alır")
	pets.arrival_ready.disconnect(cb)


func _adopt() -> void:
	print("== Ad zorunlu, sahiplenince garajda ==")
	check(not pets.adopt("   "), "boş ad reddedildi")
	check(not pets.is_adopted(), "boş adla sahiplenilmedi")
	check(pets.adopt("Paşa"), "ad verilip sahiplenildi")
	check(pets.is_adopted() and pets.pet_name() == "Paşa" and not pets.is_arrival_pending(), "ad kayıtlı, geliş kapandı")
	await frames(6)
	check(world.actor() != null, "PetWorld kediyi garaja koydu")
	check(pets.adopt("Uzun Bir Kedi Adı Deneme") and pets.pet_name().length() <= PetManager.NAME_MAX, "ad sınırı")
	pets.adopt("Paşa")


func _friendship() -> void:
	print("== Sevme ve numaralar ==")
	var start: int = pets.friendship()
	check(pets.pet(), "ilk sevme sayıldı")
	check(not pets.pet(), "bekleme süresinde ikinci dokunuş sayılmadı")
	check(pets.friendship() == start + 1, "dostluk +1")
	# Günlük sınır: aynı gün en çok DAILY_LOVE puan, sonra sevmek sayılmaz; ertesi gün yeniden
	for i: int in 10:
		pets._last_pet_msec = -100000
		pets.pet()
	check(pets.friendship() == start + PetManager.DAILY_LOVE and pets.love_left() == 0,
		"aynı gün en çok %d sevgi sayıldı (%d)" % [PetManager.DAILY_LOVE, pets.friendship() - start])
	pets._last_pet_msec = -100000
	check(not pets.pet(), "sınır dolunca sevme puan saymadı")
	var snap: Dictionary = pets.state()
	check(snap.get("love_today") == PetManager.DAILY_LOVE and String(snap.get("love_day", "")) != "",
		"günlük sayaç kayda giriyor")
	pets._love_day = "2000-01-01"   # ertesi gün
	pets._last_pet_msec = -100000
	check(pets.pet() and pets.love_today() == 1, "ertesi gün sevgi yeniden sayıldı")
	var unlocked: Array[StringName] = []
	pets.trick_unlocked.connect(func(t: StringName) -> void: unlocked.append(t))
	for i: int in 70:
		pets._last_pet_msec = -100000   # bekleme süresini atla
		pets._love_day = ""             # her dokunuş yeni gün (sınırı atla)
		pets.pet()
	check(pets.is_trick_unlocked(&"trick_paw") and pets.is_trick_unlocked(&"trick_beg") and pets.is_trick_unlocked(&"trick_roll"),
		"üç numara açıldı")
	check(unlocked.size() == 3 and unlocked[0] == &"trick_paw", "her numara bir kez, sırayla duyuruldu")
	check(pets.next_trick().is_empty(), "sıradaki numara kalmadı")


func _save_roundtrip() -> void:
	print("== Kayıt / yükleme ==")
	pets.grant_accessory(&"collar_red")
	pets.equip(&"neck", &"collar_red")
	pets.equip(&"head", &"helmet")   # sahip olunmayan takılamaz
	var snap: Dictionary = save.snapshot()
	check(snap.has("pets") and (snap["pets"] as Dictionary).get("name") == "Paşa", "kayıtta pets bölümü")
	var data: Dictionary = (snap["pets"] as Dictionary).duplicate(true)
	pets.reset()
	check(not pets.is_adopted() and pets.friendship() == 0, "sıfırlandı")
	pets.load_state(data)
	check(pets.is_adopted() and pets.pet_name() == "Paşa" and pets.friendship() >= 71, "ad ve dostluk geri geldi")
	check(pets.owns_accessory(&"collar_red") and pets.equipped(&"neck") == &"collar_red", "aksesuar ve takılı olan geri geldi")
	check(pets.equipped(&"head") == &"", "sahip olunmayan aksesuar takılmadı")
	pets.load_state({"adopted": true, "name": 42, "friendship": "x", "accessories": "bozuk", "equipped": [1, 2]})
	check(pets.is_adopted() and not pets.pet_name().is_empty() and pets.friendship() == 0 and pets.equipped(&"neck") == &"",
		"bozuk kayıt güvenli (sayı ad metne döner, bozuk alanlar varsayılan)")
	pets.load_state({"adopted": true, "name": ""})
	check(pets.pet_name() == PetManager.DEFAULT_NAME, "sahiplenilmiş ama adsız kayıtta varsayılan ad")
	pets.load_state(data)


func _world_bounds() -> void:
	print("== Kedi garajın içinde, engellerin dışında ==")
	var view: GarageDecorView = g(&"garage_decor_view") as GarageDecorView
	var cat: PetActor = world.actor()
	check(cat != null and view != null, "kedi ve dekor görünümü var")
	if cat == null or view == null:
		return
	var floor: Rect2 = view.area().floor_rect
	var bad: int = 0
	for i: int in 40:
		var p: Vector2 = world._random_free(world._pos2(), 0.0, 9.0)
		if not floor.has_point(p):
			bad += 1
	check(bad == 0, "rastgele hedefler zemin dikdörtgeninde")
	check(absf(cat.global_position.y - view.area().floor_y) < 0.01, "kedi zemin yüksekliğinde")
	var path: PackedVector2Array = world._find_path(world._pos2(), world._random_free(world._pos2(), 0.5, 2.0))
	var blocked: int = 0
	for k: int in range(1, path.size()):
		if not world._clear_line(path[k - 1], path[k]):
			blocked += 1
	check(not path.is_empty() and blocked == 0, "yol engellerin içinden geçmiyor (%d nokta)" % path.size())


## İç duvar ince ve ızgara çizgisinde: kedinin yolu ve yakın kamera bakışı içinden geçmemeli.
func _walls_block() -> void:
	print("== İç duvar kediyi ve yakın kamerayı keser ==")
	var decor: DecorManager = g(&"decor") as DecorManager
	var economy: EconomyManager = g(&"economy") as EconomyManager
	var view: GarageDecorView = g(&"garage_decor_view") as GarageDecorView
	if decor == null or economy == null or view == null or world.actor() == null:
		check(false, "duvar denemesi kurulamadı")
		return
	var before: Dictionary = decor.state()
	var money: int = economy.money
	economy.set_money(10000000)
	# Zeminin ortasından derinlemesine (z ekseni boyunca) baştan sona duvar: garaj ikiye bölünür
	var floor: Rect2 = view.area().floor_rect
	var col: int = DecorGrid.cell_of(floor.get_center()).x
	var keys: Array[String] = []
	var rows: int = DecorGrid.cell_of(Vector2(floor.get_center().x, floor.position.y)).y + 2
	for r: int in rows:
		keys.append(DecorGrid.edge_key(&"z", col, r))
	var built: Dictionary = decor.build_walls(keys, &"wall_plain")
	await frames(3)
	world._rebuild_nav()
	var line_x: float = DecorGrid.node_pos(Vector2i(col, 0)).x
	var a: Vector2 = world._nearest_free(Vector2(line_x + 0.3, floor.get_center().y))
	var b: Vector2 = world._nearest_free(Vector2(line_x - 0.3, floor.get_center().y))
	check(not built.is_empty() and decor.wall_count() >= rows, "duvar örüldü (%d segment)" % decor.wall_count())
	check(not world._clear_line(a, b), "duvarın iki yanı arasında görüş / yol kapalı")
	var path: PackedVector2Array = world._find_path(a, b)
	var crosses: bool = false
	for k: int in range(1, path.size()):
		if (path[k - 1].x - line_x) * (path[k].x - line_x) < 0.0:
			crosses = true
	check(not crosses, "kedinin yolu duvarı kesmiyor (%d nokta)" % path.size())
	decor.load_state(before)
	economy.set_money(money)
	await frames(2)
	world._rebuild_nav()


func _until(cond: Callable, limit: float) -> bool:
	var until: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < until:
		if cond.call():
			return true
		await process_frame
	return false


## Eşyayı zeminde geçerli ilk yere koyar (iid; olmadıysa "").
func _place_item(decor: DecorManager, view: GarageDecorView, item: StringName) -> String:
	decor.grant(item)
	var floor: Rect2 = view.area().floor_rect
	var y: float = view.area().floor_y
	var step: float = DecorGrid.CELL
	var x: float = floor.position.x + step
	while x < floor.end.x - step:
		var z: float = floor.position.y + step
		while z < floor.end.y - step:
			var p: Vector3 = Vector3(x, y, z)
			if view.is_valid(item, p, 0.0):
				return decor.add_instance(item, p, 0.0)
			z += step
		x += step
	return ""


func _furniture() -> void:
	print("== Kedi eşyaları: yatak, kule, kap ==")
	var decor: DecorManager = g(&"decor") as DecorManager
	var view: GarageDecorView = g(&"garage_decor_view") as GarageDecorView
	var cat: PetActor = world.actor()
	if decor == null or view == null or cat == null:
		check(false, "kedi eşyası denemesi kurulamadı")
		return
	var before: Dictionary = decor.state()
	for item: StringName in PetWorld.PET_FURNITURE:
		check(GarageDecor.exists(item) and DecorBuilder.has_model(item), "%s katalogda ve modeli var" % item)
	var bed: String = _place_item(decor, view, &"cat_bed")
	var tower: String = _place_item(decor, view, &"cat_tower")
	var bowls: String = _place_item(decor, view, &"cat_bowls")
	await frames(4)
	check(bed != "" and tower != "" and bowls != "", "yatak, kule ve kap garaja kondu")
	var kinds: Dictionary = {}
	for f: Dictionary in world._furniture():
		kinds[f["kind"]] = f
	check(kinds.has(&"bed") and kinds.has(&"tower") and kinds.has(&"bowl"), "kedi üç eşyayı da görüyor")
	if kinds.size() < 3:
		decor.load_state(before)
		return
	var floor_y: float = view.area().floor_y
	var bed_spot: Vector3 = (kinds[&"bed"]["spots"] as Array)[0]
	var bed_h: float = 0.086 * PetWorld.PET_FURNITURE_SCALE * DecorBuilder.METER   # dekor ŞEHİR ölçeğinde
	check(absf(bed_spot.y - (floor_y + bed_h)) < 0.002 and (kinds[&"bed"]["rect"] as Rect2).has_point(
		Vector2(bed_spot.x, bed_spot.z)), "yatak noktası minderin üstünde ve yatağın içinde (%.4f / %.4f)"
		% [bed_spot.y - floor_y, bed_h])
	var tower_spots: Array = kinds[&"tower"]["spots"]
	check(tower_spots.size() == 2 and (tower_spots[1] as Vector3).y > (tower_spots[0] as Vector3).y
		+ 0.4 * PetWorld.PET_FURNITURE_SCALE * DecorBuilder.METER, "kulede tabla ve ~0,46 m yukarıda direğin tepesi")
	var curl: float = 0.30 * PetActor.METER   # kıvrılmış kedinin çapı (~0,30 m, tekir_clips SLEEP_CURL)
	var bed_w: float = (kinds[&"bed"]["rect"] as Rect2).size.x
	check(bed_w > curl * 1.4, "kıvrılan kedi yatağa sığar (yatak %.3f, kıvrılmış kedi %.3f birim)" % [bed_w, curl])
	# Yatak: yanına koy, işi ver → içine atlayıp kıvrılır
	world.hold(world._land_near(kinds[&"bed"]["rect"]), 0.0, &"idle")
	world.debug_do(&"bed")
	var t0: int = Time.get_ticks_msec()
	var in_bed: bool = await _until(func() -> bool: return world.on_roof() and world.is_asleep(), 25.0)
	check(in_bed and absf(cat.global_position.y - bed_spot.y) < 0.002 and (cat.current_clip() == &"sleep"
		or cat.current_clip() == &"doze"), "kedi yatağa çıkıp kıvrılarak uyudu (%.1f sn, üstte %s, uyku %s, y farkı %.4f, klip %s)"
		% [(Time.get_ticks_msec() - t0) / 1000.0, world.on_roof(), world.is_asleep(), cat.global_position.y - bed_spot.y,
		cat.current_clip()])
	var pose: StringName = &"sleep" if cat.current_clip() == &"sleep" else &"loaf"
	var body_c: Vector3 = cat.global_position + Basis(Vector3.UP, cat.rotation.y) * Vector3(
		(PetWorld.POSE_CENTER[pose] as Vector2).x * PetActor.METER, 0.0, (PetWorld.POSE_CENTER[pose] as Vector2).y * PetActor.METER)
	var off_c: float = Vector2(body_c.x, body_c.z).distance_to(Vector2(bed_spot.x, bed_spot.z))
	check(off_c < 0.004, "uyuyan kedinin gövdesi yatağın ortasında (%.4f birim)" % off_c)
	decor.remove_instance(bed)
	await frames(3)
	check(not world.on_roof() and absf(cat.global_position.y - floor_y) < 0.002, "yatak kaldırılınca kedi yere indi")
	# Küçük eşya yolda engel: kabın gözleri kapalı, kabın bir yanından öbürüne yol kabın içinden geçmez
	var bowl_rect: Rect2 = kinds[&"bowl"]["rect"]
	check(not world._cell_free(world._ncell(bowl_rect.get_center())), "küçük kabın gözü yolda kapalı")
	var w_side: Vector2 = world._nearest_free(bowl_rect.get_center() + Vector2(-bowl_rect.size.x, 0.0))
	var e_side: Vector2 = world._nearest_free(bowl_rect.get_center() + Vector2(bowl_rect.size.x, 0.0))
	var bowl_path: PackedVector2Array = world._find_path(w_side, e_side)
	var through: bool = false
	for k: int in range(1, bowl_path.size()):
		for t: float in [0.25, 0.5, 0.75]:
			if bowl_rect.has_point(bowl_path[k - 1].lerp(bowl_path[k], t)):
				through = true
	check(not bowl_path.is_empty() and not through, "yol kabın içinden geçmiyor (%d nokta)" % bowl_path.size())
	# Kule
	world.hold(world._land_near(kinds[&"tower"]["rect"]), 0.0, &"idle")
	world.debug_do(&"tower")
	var up: bool = await _until(func() -> bool: return world.on_roof() and absf(cat.global_position.y
		- (tower_spots[0] as Vector3).y) < 0.002, 12.0)
	check(up, "kedi kulenin tablasına çıktı")
	# Kap
	world.hold(world._land_near(kinds[&"bowl"]["rect"]), 0.0, &"idle")
	world.debug_do(&"eat")
	var eating: bool = await _until(func() -> bool: return cat.current_clip() == &"eat", 12.0)
	var food: Vector3 = (kinds[&"bowl"]["spots"] as Array)[0]
	var d: float = Vector2(cat.global_position.x, cat.global_position.z).distance_to(Vector2(food.x, food.z))
	check(eating and absf(d - PetWorld.BOWL_STAND_M * PetActor.METER) < 0.01, "kedi kabın önünde yiyor (%.3f)" % d)
	decor.load_state(before)
	await frames(3)
	world.resume()
	await _editor_hides(decor, view)


## GARAJI DÜZENLE açıkken kedi gizli; kedinin durduğu yere eşya konursa düzenleyici kapanınca kedi dışarı çıkar.
func _editor_hides(decor: DecorManager, view: GarageDecorView) -> void:
	print("== Düzenleyicide kedi gizli, çıkışta engelden kaçar ==")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var cat: PetActor = world.actor()
	if hud == null or cat == null:
		check(false, "düzenleyici denemesi kurulamadı")
		return
	var before: Dictionary = decor.state()
	var spot: Vector2 = world._nearest_free(world._center())
	world.hold(spot, 0.0, &"idle")
	hud.router.open(&"garage_edit")
	await frames(6)
	check(world.is_editing() and not cat.visible, "düzenleyici açılınca kedi gizlendi")
	decor.grant(&"cat_tower")
	var iid: String = decor.add_instance(&"cat_tower", Vector3(spot.x, view.area().floor_y, spot.y), 0.0)
	await frames(2)
	hud.router.close_all()
	await frames(8)
	var poly: PackedVector2Array = view.footprint(&"cat_tower", Vector3(spot.x, 0.0, spot.y), 0.0)
	var p: Vector2 = Vector2(cat.global_position.x, cat.global_position.z)
	check(not world.is_editing() and cat.visible, "düzenleyici kapanınca kedi göründü")
	check(iid != "" and not Geometry2D.is_point_in_polygon(p, poly) and world._cell_free(world._ncell(p)),
		"kedinin üstüne konan kuleden sonra kedi boş bir yere geçti")
	decor.load_state(before)
	await frames(3)


func _accessories() -> void:
	print("== Aksesuar: elmasla al, yuva başına bir, kediye takılır ==")
	var keep: Dictionary = pets.state()
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 80})
	progress.load_state(progress.level, progress.xp, 100)
	check(not pets.buy_accessory(&"bandana") and not pets.owns_accessory(&"bandana") and progress.gems == 100,
		"elmas yetmezse alınmaz, elmas düşmez")
	progress.load_state(progress.level, progress.xp, 1000)
	check(pets.buy_accessory(&"collar_red") and progress.gems == 850 and pets.is_worn(&"collar_red"),
		"TASMA 150 elmasa alındı ve hemen takıldı")
	check(not pets.buy_accessory(&"collar_red") and progress.gems == 850, "aynı aksesuar ikinci kez alınmaz")
	check(pets.buy_accessory(&"bandana") and pets.is_worn(&"bandana") and not pets.is_worn(&"collar_red")
		and progress.gems == 650, "BANDANA boyun yuvasında tasmanın yerine geçti")
	check(pets.buy_accessory(&"helmet") and same(pets.worn(), [&"bandana", &"helmet"]),
		"KASK baş yuvasında, boyundakiyle birlikte")
	pets.toggle_accessory(&"helmet")
	check(not pets.is_worn(&"helmet") and pets.owns_accessory(&"helmet"), "dokununca çıkar, sahiplik kalır")
	pets.toggle_accessory(&"collar_red")
	check(pets.is_worn(&"collar_red") and not pets.is_worn(&"bandana"), "sahip olunan tasma yeniden takıldı")
	pets.toggle_accessory(&"cap")
	check(not pets.is_worn(&"cap"), "alınmamış aksesuar dokunmayla takılmaz")
	await frames(2)
	var cat: PetActor = world.actor()
	check(cat != null and same(cat.worn_accessories(), [&"collar_red"]), "kedinin üstünde yalnız takılı olan")
	if cat == null:
		pets.load_state(keep)
		return
	world.set_accessory_preview(&"cap")
	check(cat.worn_accessories().has(&"cap") and cat.worn_accessories().has(&"collar_red"), "deneme: USTA KEPİ geçici takıldı")
	world.set_accessory_preview(&"bandana")
	check(cat.worn_accessories().has(&"bandana") and not cat.worn_accessories().has(&"collar_red"),
		"boyun denemesi boyundakinin yerine geçer")
	world.set_accessory_preview(&"")
	check(same(cat.worn_accessories(), [&"collar_red"]), "deneme bitince eski hâli")
	var skel: Skeleton3D = cat.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	for a: Dictionary in PetManager.ACCESSORIES:
		var id: StringName = a["id"]
		var one: Array[StringName] = [id]
		cat.set_accessories(one)
		var mesh: MeshInstance3D = skel.get_node_or_null(NodePath("Acc_%s" % id)) as MeshInstance3D
		var binds_ok: bool = mesh != null and mesh.skin != null and mesh.skin.get_bind_count() > 0
		if binds_ok:
			for i: int in mesh.skin.get_bind_count():
				binds_ok = binds_ok and skel.find_bone(String(mesh.skin.get_bind_name(i))) >= 0
		check(binds_ok and mesh.get_node_or_null(mesh.skeleton) == skel,
			"%s kedinin iskeletine derili takıldı (bağlar adla)" % id)
		check(ResourceLoader.exists("res://assets/pets/acc/icon_%s.png" % id), "%s raf simgesi var" % id)
	cat.set_accessories(pets.worn())
	pets.load_state({"adopted": true, "name": "Paşa"})
	check(cat.worn_accessories().is_empty(), "kayıt yeniden yüklenince kedinin üstü tazelendi (aksesuarsız)")
	pets.load_state(keep)


func _wear_and_fur() -> void:
	print("== Kıyafet (gövde yuvası) ve tüy rengi ==")
	var keep: Dictionary = pets.state()
	pets.load_state({"adopted": true, "name": "Paşa", "friendship": 80})
	progress.load_state(progress.level, progress.xp, 2000)
	await frames(2)
	var cat: PetActor = world.actor()
	check(cat != null and not cat.skin_hidden(), "kıyafetsiz kedide deri gizlenmez")
	if cat == null:
		pets.load_state(keep)
		return
	var body: Array[StringName] = []
	for a: Dictionary in PetManager.ACCESSORIES:
		if a["slot"] == &"body":
			body.append(a["id"])
			check(int(a["gems"]) >= 150 and int(a["gems"]) <= 400, "%s fiyatı 150–400 elmas" % a["id"])
			check(ResourceLoader.exists("res://assets/pets/acc/%s_mask.png" % a["id"]), "%s deri gizleme maskesi var" % a["id"])
	check(same(body, [&"vest", &"sweater", &"race_jacket", &"leather_jacket"]), "dört kıyafet gövde yuvasında")
	check(pets.buy_accessory(&"vest") and pets.is_worn(&"vest") and progress.gems == 1800, "İKAZ YELEĞİ 200 elmasa alındı, giyildi")
	await frames(1)
	check(cat.worn_accessories().has(&"vest") and cat.skin_hidden(), "yelek kedinin üstünde, altındaki deri gizli")
	pets.grant_accessory(&"collar_red")
	pets.equip(&"neck", &"collar_red")
	check(pets.is_worn(&"collar_red") and pets.is_worn(&"vest"), "tasma kıyafetle birlikte giyilir")
	pets.grant_accessory(&"bandana")
	pets.equip(&"neck", &"bandana")
	check(pets.is_worn(&"bandana") and not pets.is_worn(&"vest") and not pets.is_worn(&"collar_red"),
		"bandana takılınca kıyafet çıkar (üçgeni kıyafetin altında kalıyordu)")
	await frames(1)
	check(not cat.skin_hidden(), "kıyafet çıkınca deri yine görünür")
	check(pets.buy_accessory(&"sweater") and pets.is_worn(&"sweater") and not pets.is_worn(&"bandana"),
		"ÖRGÜ KAZAK alınınca bandana çıktı")
	check(PetManager.clashes(&"bandana", &"race_jacket") and not PetManager.clashes(&"collar_red", &"race_jacket")
		and PetManager.clashes(&"vest", &"sweater") and not PetManager.clashes(&"cap", &"vest"), "çakışma kuralı")
	world.set_accessory_preview(&"race_jacket")
	check(cat.worn_accessories().has(&"race_jacket") and not cat.worn_accessories().has(&"sweater"),
		"kıyafet denemesi giyilen kıyafetin yerine geçer")
	world.set_accessory_preview(&"bandana")
	check(cat.worn_accessories().has(&"bandana") and not cat.worn_accessories().has(&"sweater") and not cat.skin_hidden(),
		"bandana denemesi kıyafeti geçici çıkarır")
	world.set_accessory_preview(&"")
	check(cat.worn_accessories().has(&"sweater") and cat.skin_hidden(), "deneme bitince kazak geri")
	# Tüy rengi: ücretsiz, anında, kayda girer
	var orange_tex: Texture2D = cat.body_texture()
	var seen: Array[StringName] = []
	var cb: Callable = func(f: StringName) -> void: seen.append(f)
	pets.fur_changed.connect(cb)
	var gems_before: int = progress.gems
	check(pets.fur() == &"orange" and cat.fur() == &"orange", "varsayılan tüy turuncu tekir")
	pets.set_fur(&"white")
	check(pets.fur() == &"white" and cat.fur() == &"white" and cat.body_texture() != orange_tex
		and cat.body_texture().resource_path.ends_with("tekir_white.jpg"), "beyaz seçildi, gövde dokusu değişti")
	check(progress.gems == gems_before, "tüy rengi elmas düşürmez")
	cat.set_eyes_shut(true)
	check(cat.body_texture().resource_path.ends_with("tekir_white_eyes_closed.jpg"), "beyazın kapalı göz dokusu")
	cat.set_eyes_shut(false)
	pets.set_fur(&"black")
	check(cat.body_texture().resource_path.ends_with("tekir_black.jpg"), "siyah seçildi")
	pets.set_fur(&"zebra")
	check(pets.fur() == &"black", "bilinmeyen renk yok sayıldı")
	pets.set_fur(&"black")
	check(same(seen, [&"white", &"black"]), "aynı renk ve bilinmeyen renk sinyal yaymaz")
	var data: Dictionary = pets.state()
	check(data.get("fur") == "black", "tüy rengi kayda girer")
	pets.load_state({"adopted": true, "name": "Paşa"})
	check(pets.fur() == &"orange" and cat.fur() == &"orange" and cat.body_texture() == orange_tex,
		"renksiz eski kayıt turuncu, kedi tazelendi")
	pets.load_state(data)
	check(pets.fur() == &"black" and cat.fur() == &"black" and pets.is_worn(&"sweater"), "kayıttan siyah + kazak geri geldi")
	pets.load_state({"adopted": true, "name": "Paşa", "fur": 7})
	check(pets.fur() == &"orange", "bozuk renk kaydı güvenli")
	pets.load_state({"adopted": true, "name": "Paşa", "accessories": ["vest", "bandana"],
		"equipped": {"body": "vest", "neck": "bandana", "head": "vest"}})
	check(pets.worn().size() == 1 and pets.equipped(&"head") == &"", "kayıtta çakışan / yanlış yuvadaki takılmaz")
	pets.fur_changed.disconnect(cb)
	pets.load_state(keep)
	await frames(1)


func _names() -> void:
	print("== Ad kuralları ==")
	check(PetNameScreen.problem("a") != "", "tek harf reddedilir")
	check(PetNameScreen.problem("Paşa") == "", "Paşa geçerli")
	check(PetNameScreen.problem("Kedi<3") != "", "izinsiz karakter reddedilir")
	check(PetNameScreen.problem("o.r.o.s.p.u") != "", "uygunsuz ad süzülür")
	check(PetNameScreen.clean("  Boncuk   Hanım ") == "Boncuk Hanım", "boşluklar toparlanır")


func _closeup() -> void:
	print("== Yakın kamera ve ad ekranı ==")
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	check(hud != null and hud.pet_closeup_screen != null, "Hud yakın kamera ekranını kurdu")
	if hud == null:
		return
	hud.router.close_all()
	var name_screen: PetNameScreen = hud.pet_closeup_screen.name_screen()
	name_screen.mandatory = true
	hud.router.open(&"pet_name")
	await frames(3)
	hud.router.back()
	await frames(3)
	check(hud.router.is_open(&"pet_name") and name_screen.visible, "zorunlu ad ekranı GERİ ile kapanmadı")
	name_screen.mandatory = false
	hud.router.back()
	await create_timer(0.4).timeout
	check(not hud.router.is_open(&"pet_name"), "ad değiştirme ekranı GERİ ile kapandı")
	var voice: PetVoice = hud.pet_closeup_screen.find_child("PetVoice", false, false) as PetVoice
	check(voice != null and not voice.active(), "kedi sesi kurulu, garajda sessiz")
	hud.router.open(&"pet_closeup")
	await create_timer(1.0).timeout
	check(hud.router.current_place() == &"pet_closeup" and world.in_closeup(), "yakın kamera açıldı, kedi yakın kamerada")
	check(voice != null and voice.active(), "yakın kamerada kedi sesi açık")
	var music: GameMusic = root.get_node_or_null(GameMusic.NODE_NAME) as GameMusic
	check(music == null or absf(music.volume_db - GameMusic.PET_DB) < 0.5,
		"yakın kamerada müzik kısık (%.1f dB)" % (music.volume_db if music else 0.0))
	hud.router.back()
	await create_timer(0.8).timeout
	check(not hud.router.is_open(&"pet_closeup") and not world.in_closeup(), "kapandı, kedi hayatına döndü")
	check(voice != null and not voice.active() and not voice.purring(), "kapanınca kedi sustu")
	if music:
		await create_timer(GameMusic.SWAP_TIME + 0.2).timeout
		check(absf(music.volume_db - GameMusic.BASE_DB) < 0.5, "kapanınca müzik geri geldi (%.1f dB)" % music.volume_db)


func _voice() -> void:
	print("== Kedi sesi (yalnız yakın kamera) ==")
	var missing: Array[String] = []
	for kind: StringName in PetVoice.POOLS:
		for clip: StringName in PetVoice.POOLS[kind]:
			if not ResourceLoader.exists(PetVoice.DIR + String(clip) + ".wav"):
				missing.append(String(clip))
	check(missing.is_empty(), "bütün kedi kayıtları var %s" % [missing])
	var purr: AudioStreamWAV = load(PetVoice.DIR + "purr.wav") as AudioStreamWAV
	check(purr != null and purr.loop_mode == AudioStreamWAV.LOOP_FORWARD, "mırlama ileri döngülü")
	var v: PetVoice = PetVoice.new()
	root.add_child(v)
	await frames(1)
	v.petted()
	v.greet()
	check(v.last_clip() == &"" and not v.purring(), "yakın kamera dışında ses yok")
	v.begin()
	v.petted()
	check(String(v.last_clip()).begins_with("trill") and v.purring(), "ilk sevme: mrrp + mırlama")
	check(not v.say(&"hello"), "ağız doluyken yeni ses atlanır")
	await create_timer(PetVoice.PURR_IN + 0.2).timeout
	check(v.purr_level() > 0.99, "mırlama tam düzeye çıktı")
	v.end()
	check(not v.say(&"hello"), "kapanınca konuşmaz")
	await create_timer(PetVoice.PURR_OUT_FAST + 0.3).timeout
	check(v.purr_level() == 0.0 and not v.purring(), "kapanınca mırlama söndü")
	v.begin()
	await create_timer(0.8).timeout
	check(v.say(&"chirp") and String(v.last_clip()).begins_with("chirp"), "olta cıvıltısı çalar")
	v.end()
	v.queue_free()
