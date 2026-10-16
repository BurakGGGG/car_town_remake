extends SceneTree
## ARAÇ SERGİSİ — sahip olunan araç garajda dekor gibi sergilenir: yerleşir, taşınır, kaydedilir,
## satılınca kalkar, boyası güncellenir. Çalıştırma: tools/run_tests.sh vehicle_display_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


## Gövdedeki herhangi bir parçada (gizli parçalar dahil: birleşik mesh arka planda yenilenir) boya
## shader'ı bu tonda mı?
func _tinted(body: Node3D, color: Color) -> bool:
	if body == null:
		return false
	for node: Node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node
		if mesh.mesh == null:
			continue
		for s: int in mesh.mesh.get_surface_count():
			var mat: ShaderMaterial = mesh.get_surface_override_material(s) as ShaderMaterial
			if mat and mat.get_shader_parameter(&"tint") is Color \
					and (mat.get_shader_parameter(&"tint") as Color).is_equal_approx(color):
				return true
	return false


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
	var decor: DecorManager = get_first_node_in_group("decor")
	var view: GarageDecorView = get_first_node_in_group("garage_decor_view")
	var save: SaveManager = get_first_node_in_group("save_manager")
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership")
	var economy: EconomyManager = get_first_node_in_group("economy")
	save.new_game()
	await frames(4)
	own.add_vehicle(&"tofas_sahin")   # yeni oyunda araç yok (HOŞ GELDİN KUTUSU bekliyor): sergi için ilk aracı ver
	var first: StringName = own.owned_vehicle_ids()[0]
	var item: StringName = GarageDecor.vehicle_item_id(first)

	print("== katalog ==")
	check(GarageDecor.exists(item) and GarageDecor.is_vehicle(item), "araç sergi eşyası var (%s)" % item)
	check(GarageDecor.vehicle_of(item) == first, "araç kimliği geri çözülür")
	check(not GarageDecor.exists(GarageDecor.vehicle_item_id(&"yok_boyle_arac")), "olmayan araç sergilenemez")
	check(GarageDecor.placement(item) == GarageDecor.PLACE_FLOOR and not GarageDecor.is_surface(item), "zemin eşyası")
	check(not GarageDecor.all().any(func(i: Dictionary) -> bool: return GarageDecor.is_vehicle(i["id"])), "araçlar katalog listesinde değil (mağazada çıkmaz)")
	check(decor.owned_of(item) == 1 and decor.available_of(item) == 1, "sahip olunan araç 1 kez sergilenebilir")
	check(not decor.can_purchase(item), "sergi eşyası satın alınmaz")
	check(decor.value() == 0, "sergi garaj değerine eklenmez")

	print("== yerleştirme ==")
	var size: Vector2 = view.footprint_size(item)
	check(size.x > 0.1 and size.y > 0.1 and maxf(size.x, size.y) < 1.2, "iz ölçüsü araç boyunda (%s)" % size)
	var rect: Rect2 = view.area().floor_rect
	var pos: Vector3 = Vector3(rect.get_center().x, view.area().floor_y, rect.get_center().y)
	var found: bool = false
	for step: int in 40:
		var p: Vector3 = pos + Vector3((step % 8) * 0.12 - 0.4, 0.0, (step / 8) * 0.12 - 0.3)
		if view.is_valid(item, p, 0.0):
			pos = p
			found = true
			break
	check(found, "garajda araca yer var")
	var iid: String = decor.add_instance(item, pos, 30.0)
	check(iid != "", "sergilendi (%s)" % iid)
	await frames(3)
	check(view.body_of(iid) != null, "dünyada araç gövdesi var")
	check(decor.available_of(item) == 0 and decor.add_instance(item, pos, 0.0) == "", "aynı araç iki kez sergilenmez")

	print("== kayıt ==")
	check(save.save_game(), "kaydedildi")
	decor.reset()
	check(decor.instance_count() == 0, "temizlendi")
	check(save.load_game(), "yüklendi")
	await frames(4)
	check(decor.instance_count() == 1 and decor.instances()[0]["item"] == item, "sergi yüklemede geri geldi")
	check(is_equal_approx(float((decor.instances()[0]["rot"] as Vector3).y), 30.0), "yön korundu")

	print("== boya ==")
	# VehicleOwnership._apply_paint gibi: renk paylaşılan görünüme yazılır, sonra sinyal
	var before: Node3D = view.body_of(decor.instances()[0]["iid"])
	var appearance: CarAppearance = CarAppearance.get_for(CarCatalog.scene_path(first))
	var factory: Color = appearance.body_color
	appearance.body_color = Color.RED
	own.paint_changed.emit(first, Color.RED)
	await frames(3)
	var after: Node3D = view.body_of(decor.instances()[0]["iid"])
	check(after != null and after == before, "boya değişince sergi gövdesi baştan kurulmadı (görünüm yerinde)")
	check(_tinted(after, Color.RED), "sergi aracı yeni renkte")
	appearance.body_color = factory
	own.paint_changed.emit(first, factory)
	await frames(3)
	check(not _tinted(view.body_of(decor.instances()[0]["iid"]), Color.RED), "fabrika rengine döndü")

	print("== satış ==")
	var second: StringName = &"hyundai_getz"
	if CarCatalog.get_entry(second).is_empty():
		second = CarCatalog.all()[1]["id"]
	economy.add_money(1000000)
	own.add_vehicle(second)
	check(own.sell_vehicle(first), "araç satıldı")
	await frames(3)
	check(decor.instance_count() == 0, "satılan aracın sergisi kalktı")
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
