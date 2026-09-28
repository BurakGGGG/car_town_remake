extends SceneTree
## Avlu dekorasyonu: seviyeye bağlı yuvalar, dünyada yerleşim, tıklama → pano.
var _hud: Node
func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null
func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()
func _frames(n: int) -> void:
	for i: int in n: await process_frame
func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(70)
	var decor: DecorManager = get_first_node_in_group("decor")
	var view: Node3D = get_first_node_in_group("garage_decor_view")
	var eco: EconomyManager = get_first_node_in_group("economy")
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	_hud = _find(current_scene, "HUD")
	eco.set_money(2000000)
	print("görünüm: %s | avlu %s" % [view != null, view.call("lot_rect")])
	print("seviye 1 açık yuva: %d" % decor.open_slots().size())
	for i: int in 3:
		upgrades.buy(GarageUpgradeManager.GARAGE_ID)
	await _frames(10)
	print("seviye %d açık yuva: %d | avlu %s" % [upgrades.garage_level(),
		decor.open_slots().size(), view.call("lot_rect")])
	# Tüm eşyaları al (rütbe yeterli olsun diye garaj değeri zaten yükseldi)
	var bought: int = 0
	for item: Dictionary in GarageDecor.all():
		if decor.purchase(item["id"]):
			bought += 1
	print("alınan %d/%d | yerleşen %d | garaj değeri %d" % [bought, GarageDecor.all().size(),
		decor.placements().size(), GarageValue.compute(self)])
	await _frames(10)
	print("avluda kurulan gövde: %d" % (view.get_node("DecorBodies") as Node3D).get_child_count())
	for body: Node in (view.get_node("DecorBodies") as Node3D).get_children():
		var n: Node3D = body
		var box: AABB = AABB()
		var first: bool = true
		for m: Node in n.get_children():
			if m is MeshInstance3D:
				var b: AABB = (m as Node3D).transform * (m as MeshInstance3D).get_aabb()
				box = b if first else box.merge(b)
				first = false
		print("   %-16s konum (%5.2f,%5.2f) kutu %.2f x %.2f x %.2f (dünya %.2f x %.2f)" % [n.name,
			n.position.x, n.position.z, box.size.x, box.size.y, box.size.z,
			box.size.x * n.scale.x, box.size.z * n.scale.z])
	# Tıklama → pano
	view.emit_signal("lot_clicked")
	await _frames(20)
	var panel: Control = _hud.get("decor_panel")
	print("pano açık: %s | ızgara görünür: %s" % [panel.visible,
		(get_first_node_in_group("garage_system").get_node("BuildGrid/BuildGrid") as Node3D).visible])
	# Kadrajı avlunun tamamına al (dünya kamerası oyuncu kontrollü; testte elle kuruyoruz)
	var cam: Camera3D = null
	for n: Node in current_scene.get_children():
		if n is Camera3D:
			cam = n
	if cam:
		var rect: Rect2 = view.call("lot_rect")
		var mid: Vector3 = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
		var basis: Basis = cam.global_transform.basis
		cam.size = 7.4
		cam.position = mid + basis.z * 12.0
		await _frames(4)
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/decor/")
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/decor/avlu.png")
	quit(0)
