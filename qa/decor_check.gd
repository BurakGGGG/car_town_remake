extends SceneTree
## Dekorasyon akışı: satın al → garaja otur → garaj değeri artsın → kaydet/yükle.
var _hud: Node
var _drag: Node

func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(70)
	var decor: DecorManager = get_first_node_in_group("decor")
	var eco: EconomyManager = get_first_node_in_group("economy")
	print("yönetici bulundu: %s | katalog %d eşya" % [decor != null, GarageDecor.all().size()])
	eco.set_money(500000)
	var before: int = GarageValue.compute(self)
	var bought: int = 0
	for item: Dictionary in GarageDecor.all():
		if decor.purchase(item["id"]):
			bought += 1
		else:
			print("  alınamadı: %-14s rütbe %d gerekli (şu an %d)" % [item["id"],
				int(item["min_rank"]), GarageValue.current_rank(self)])
	print("alınan: %d/%d | garaj değeri %d → %d (+%d)" % [bought, GarageDecor.all().size(),
		before, GarageValue.compute(self), GarageValue.compute(self) - before])
	print("yerleşen yuvalar: %s" % str(decor.placements()))
	# TÜM eşyaları zorla sahiplen + yerleştir (yerleşim ayarı için görsel tur)
	if OS.get_cmdline_user_args().has("hepsi"):
		for item: Dictionary in GarageDecor.all():
			if not decor.is_owned(item["id"]):
				(decor.get("_owned") as Array).append(item["id"])
		# Her yuvaya FARKLI bir eşya: yerleşim ayarı için tüm yuvalar dolsun
		var by_kind: Dictionary = {}
		for item: Dictionary in GarageDecor.all():
			var k: StringName = GarageDecor.slot_kind(item["id"])
			if not by_kind.has(k):
				by_kind[k] = []
			(by_kind[k] as Array).append(item["id"])
		for slot: StringName in GarageDecor.slots():
			var k2: StringName = GarageDecor.slot_of(slot)
			var pool: Array = by_kind.get(k2, [])
			if not pool.is_empty():
				decor.place(slot, pool.pop_front())
		decor.placement_changed.emit()
		print("zorla yerleşim: %s" % str(decor.placements()))
	# Garajı aç ve gövdeleri say
	_hud = _find(current_scene, "HUD")
	_hud.get("router").call("open", &"garage")
	await _frames(90)
	var garage: Control = _hud.get("garage_screen")
	var root: Node3D = garage.get("_decor_root")
	print("garajda kurulan gövde: %d" % root.get_child_count())
	RenderingServer.force_draw()
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/decor/")
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/decor/garaj.png")
	# DÜZENLE panosu
	garage.call("_open_decor")
	await _frames(20)
	var panel: Control = garage.get("_decor_panel")
	print("pano görünür: %s | satır: %d" % [panel.visible, (panel.get("_rows") as Dictionary).size()])
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/decor/pano.png")
	# Kayıt turu
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.save_game()
	var disk: Dictionary = save.peek()
	print("kayıt sürümü %s | decor.owned %d | decor.placed %d" % [disk.get("version"),
		(disk.get("decor", {}).get("owned", []) as Array).size(),
		(disk.get("decor", {}).get("placed", {}) as Dictionary).size()])
	quit(0)
