extends SceneTree
## ŞEHİR ÖNİZLEMESİNİ PİŞİRİR → res://.godot/editor_preview/sehir.scn (editörde CityPreview gösterir; bkz. world/city_preview.gd).
## Oyunun kendi kodu kurar: Main.tscn betiklerinden arındırılır (kayıt, HUD, garaj, trafik çalışmaz — oyuncu kaydına
## dokunulmaz), yalnız WorldDressing eklenir. Sonuç: WorldDressing'in kurduğu her şey (yol uzantıları, showroom binası,
## peyzaj, kavşak çizgileri, trafik lambaları, billboard) + oyunun sahne düğümlerinde yaptığı değişiklikler (gizlenen eski
## showroom / çizgiler / yerleştirme ızgarası, çimenin materyali).
## Gerçek çizici gerekir (başsızda mesh / MultiMesh verisi boş kaydedilir): editör 64x64 pencerede çalıştırır, betik
## pencereyi hemen küçültür.
## Elle: godot-4 --path . --resolution 64x64 --script res://tools/world/bake_city_preview.gd

const SETTLE_FRAMES: int = 90   # şerit çizgisi birleştirmesi (ertelenmiş) ve billboard afişinin arka planda yüklenmesi
const GARAGE_SYSTEM: Script = preload("res://garage_system.gd")


func _initialize() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)   # editörün açtığı küçük pencere görünmesin
	_run.call_deferred()


func _run() -> void:
	var started: int = Time.get_ticks_msec()
	var scene: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	_strip_scripts(scene)
	root.add_child(scene)
	current_scene = scene
	var before: Dictionary = _snapshot(scene)
	StaticBatch.enabled = false   # toplu çizim önizlemede gereksiz; asıl parçalar görünür kalsın
	var dressing: WorldDressing = WorldDressing.new()
	scene.add_child(dressing)
	var shadow: Node = dressing.get_node_or_null("WorldShadow")
	if shadow:
		shadow.free()   # gölge haritası (ayrı dünya, disk önbelleği) önizlemeye girmez
	for i: int in SETTLE_FRAMES:
		await process_frame
	# Şerit kesiklerinin tek mesh'e birleştirilmesi görüntüyü değiştirmez: önizlemede kesikler kendi düğümleriyle kalır
	# (yoksa editörün Sahne panelinde 62 düğüm gizli görünürdü)
	var lane_batch: Node = dressing.get_node_or_null("LaneLinesScene")
	if lane_batch:
		lane_batch.free()
	var overrides: Array = _diff(scene, before)
	var grid: Node = scene.get_node_or_null("GarageSystem")
	if grid:
		for path: NodePath in GARAGE_SYSTEM.RUNTIME_HIDDEN:   # oyunda GarageSystem gizler (kayıttan bağımsız)
			var node: Node3D = grid.get_node_or_null(path) as Node3D
			if node and node.visible:
				overrides.append([scene.get_path_to(node), &"visible", false])
	_strip_scripts(dressing)
	for node: Node in dressing.find_children("*", "", true, false):
		if node.owner == null:
			node.owner = dressing   # kodla kurulanlar; GLB içindekiler kendi sahnesinin (örnekle gelir)
	dressing.set_meta(&"overrides", overrides)
	dressing.set_meta(&"source_hash", CityPreview.source_hash())
	var packed: PackedScene = PackedScene.new()
	var err: Error = packed.pack(dressing)
	if err == OK:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CityPreview.FILE.get_base_dir()))
		err = ResourceSaver.save(packed, CityPreview.FILE, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_error("bake_city_preview: kaydedilemedi (%d)" % err)
	else:
		print("ŞEHİR ÖNİZLEMESİ %s: %d düğüm, %d sahne değişikliği, %d ms" % [CityPreview.FILE,
			dressing.find_children("*", "", true, false).size(), overrides.size(), Time.get_ticks_msec() - started])
	quit(0 if err == OK else 1)


## Betikler sökülür: oyun sistemleri (_ready'leri) çalışmaz, sahnenin görselleri kalır.
func _strip_scripts(node: Node) -> void:
	for child: Node in node.get_children():
		_strip_scripts(child)
	if node.get_script() != null:
		node.set_script(null)


## Sahnedeki düğümlerin görünürlüğü ve materyali (WorldDressing'in değiştirdiklerini bulmak için).
func _snapshot(scene: Node) -> Dictionary:
	var out: Dictionary = {}
	for node: Node in scene.find_children("*", "Node3D", true, false):
		var entry: Array = [(node as Node3D).visible, null]
		if node is GeometryInstance3D:
			entry[1] = (node as GeometryInstance3D).material_override
		out[scene.get_path_to(node)] = entry
	return out


## Değişenler: [yol, özellik, yeni değer].
func _diff(scene: Node, before: Dictionary) -> Array:
	var out: Array = []
	for path: NodePath in before:
		var node: Node3D = scene.get_node_or_null(path) as Node3D
		if node == null:
			continue
		var old: Array = before[path]
		if node.visible != bool(old[0]) and not node.has_meta(&"batched"):
			out.append([path, &"visible", node.visible])
		if node is GeometryInstance3D and (node as GeometryInstance3D).material_override != old[1]:
			out.append([path, &"material_override", (node as GeometryInstance3D).material_override])
	return out
