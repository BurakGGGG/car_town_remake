extends SceneTree
## DEKOR VERİ + GEOMETRİ KATMANI — sahne yüklemeden hızlı sınama.
## Katalog JSON'dan geliyor mu, gövdeler normalleşiyor mu (taban y=0, iz merkezi 0), yönetici
## adet/örnek tutarlılığını koruyor mu, DecorArea kuralları doğru mu.
## Kullanım: godot-4 --headless --path . -s res://qa/dekor_katman.gd

var _fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		_fails += 1


func _init() -> void:
	print("== KATALOG ==")
	check(GarageDecor.all().size() == 74, "74 kayıt JSON'dan (%d)" % GarageDecor.all().size())
	check(GarageDecor.categories().size() == 7, "7 kategori (%d)" % GarageDecor.categories().size())
	check(GarageDecor.placement(&"sofa") == GarageDecor.PLACE_FLOOR, "kanepe zemine")
	check(GarageDecor.placement(&"wall_clock") == GarageDecor.PLACE_WALL, "saat duvara")
	check(GarageDecor.is_surface(&"floor_tile"), "karo kaplama")
	check(GarageDecor.rotation_step(&"sofa") == 45.0, "varsayılan döndürme adımı 45")
	check(int(GarageDecor.get_item(&"sofa")["kind"]) == GarageDecor.Kind.LOUNGE, "tür enum'a çevrildi")

	print("== GÖVDE NORMALLEŞTİRME ==")
	var worst_floor: float = 0.0
	var worst_center: float = 0.0
	var worst_id: String = ""
	var built: int = 0
	for item: Dictionary in GarageDecor.all():
		var id: StringName = item["id"]
		if GarageDecor.is_surface(id):
			continue
		var body: Node3D = DecorBuilder.build_placeable(id)
		if body == null:
			check(false, "%s üretilemedi" % id)
			continue
		built += 1
		var box: AABB = DecorBuilder._local_bounds(body)
		var wall: bool = GarageDecor.placement(id) == GarageDecor.PLACE_WALL
		var err_y: float = absf(box.get_center().y) if wall else absf(box.position.y)
		var err_c: float = Vector2(box.get_center().x, box.position.z if wall else box.get_center().z).length()
		if err_y > worst_floor:
			worst_floor = err_y
			worst_id = String(id)
		worst_center = maxf(worst_center, err_c)
		body.free()
	check(built == 70, "70 gövde üretildi (%d)" % built)
	check(worst_floor < 0.001, "taban/dikey merkez hizası en kötü %.5f (%s)" % [worst_floor, worst_id])
	check(worst_center < 0.001, "iz merkezi / arka yüz hizası en kötü %.5f" % worst_center)

	print("== DECORAREA ==")
	var a: DecorArea = DecorArea.new()
	a.floor_rect = Rect2(Vector2(-2.16, -1.63), Vector2(1.95, 1.42))
	a.back_face_z = -1.65
	a.left_face_x = -2.175
	a.back_span = Vector2(-2.175, -0.2)
	a.left_span = Vector2(-1.65, -0.2)
	a.obstacles = [Rect2(Vector2(-2.1, -1.33), Vector2(0.76, 0.56))]
	var poly: PackedVector2Array = DecorArea.corners(Vector2(-1.0, -0.5), Vector2(0.4, 0.2), 0.0)
	check(a.inside_floor(poly), "ortadaki iz içeride")
	check(not a.inside_floor(DecorArea.corners(Vector2(-0.25, -0.5), Vector2(0.4, 0.2), 0.0)),
		"sağ kenardan taşan iz dışarıda")
	check(a.hits_obstacle(DecorArea.corners(Vector2(-1.7, -1.05), Vector2(0.2, 0.2), 0.0)),
		"tamir alanı üstü engel")
	var long_poly: PackedVector2Array = DecorArea.corners(Vector2(-1.0, -0.8), Vector2(0.58, 0.28), 45.0)
	var probe: PackedVector2Array = DecorArea.corners(Vector2(-0.62, -0.42), Vector2(0.1, 0.1), 0.0)
	check(not DecorArea.overlaps(long_poly, probe),
		"45° dönük römorkun KÖŞESİNE yakın boşluk serbest (eksen hizalı kutu bunu reddederdi)")
	check(DecorArea.overlaps(long_poly, DecorArea.corners(Vector2(-1.0, -0.8), Vector2(0.1, 0.1), 0.0)),
		"merkezde çakışma yakalanıyor")
	var touching: PackedVector2Array = DecorArea.corners(Vector2(-0.8, -0.5), Vector2(0.4, 0.2), 0.0)
	var neighbour: PackedVector2Array = DecorArea.corners(Vector2(-0.4, -0.5), Vector2(0.4, 0.2), 0.0)
	check(not DecorArea.overlaps(touching, neighbour), "tam bitişik iki eşya çakışma sayılmıyor")
	var m: Dictionary = a.wall_mount(Vector2(-1.0, -1.55), 0.1)
	check(m["wall"] == &"back" and is_equal_approx(float(m["yaw"]), 0.0), "arka duvara yakın → arka duvar, yön 0")
	var m2: Dictionary = a.wall_mount(Vector2(-2.1, -0.6), 0.1)
	check(m2["wall"] == &"left" and is_equal_approx(float(m2["yaw"]), 90.0), "sol duvara yakın → sol duvar, yön 90")
	# garaj büyüdü: duvar geriye kaydı, eşya yeni duvara oturmalı
	var old_pos: Vector3 = m["position"]
	a.back_face_z = -3.15
	a.left_span = Vector2(-3.15, -0.2)
	var moved: Vector3 = a.reattach_wall(old_pos, 0.0, 0.1)
	check(is_equal_approx(moved.x, old_pos.x) and absf(moved.z - (-3.15)) < 0.01,
		"garaj büyüyünce duvar eşyası yeni duvara oturdu (z %.3f → %.3f)" % [old_pos.z, moved.z])
	a.grid_origin = Vector2(-2.1625, -1.6375)
	var snapped: Vector2 = a.snap(Vector2(-1.0, -0.5), 0.0875)
	check(is_equal_approx(fposmod(snapped.x - a.grid_origin.x, 0.0875), 0.0) \
		or is_equal_approx(fposmod(snapped.x - a.grid_origin.x, 0.0875), 0.0875), "ızgara çizgisine göre oturtuldu")

	print("RESULT fails=%d" % _fails)
	quit(0 if _fails == 0 else 1)
