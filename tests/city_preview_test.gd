extends SceneTree
## ŞEHİR ÖNİZLEMESİ (world/city_preview.gd, tools/world/bake_city_preview.gd): pişirilen önizleme yüklenir, oyunun sahne
## düğümlerinde yaptığı değişiklikler (gizlenen eski showroom, ızgara) uygulanır; kaydederken (EDITOR_PRE_SAVE) özgün
## hâl kaydedilir, sonra (POST_SAVE) yeniden uygulanır; sekme değişince (ağaçtan çıkış) özgün hâle döner, dönünce yeniden
## uygulanır; kapatınca iz kalmaz. Editörün yaptığını taklit eder (sahne betiksiz, GarageSystem gibi). PENCERELİ.
##   tools/run_tests.sh city_preview_test        (CT_PREVIEW_SHOT=<png>: önizlemeli sahnenin görüntüsü)

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _strip(node: Node) -> void:
	for child: Node in node.get_children():
		_strip(child)
	if node.get_script() != null:
		node.set_script(null)


func _run() -> void:
	print("== 1) PİŞİRME ==")
	if not FileAccess.file_exists(CityPreview.FILE) or _stale():
		var out: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--path", ProjectSettings.globalize_path("res://"),
			"--resolution", "64x64", "--script", CityPreview.BAKER], out, true)
		check(code == 0, "pişirici çalıştı (%s)" % "".join(out).strip_edges().get_slice("\n", 0))
	check(FileAccess.file_exists(CityPreview.FILE), "önizleme dosyası var")
	check(not _stale(), "önizleme kaynaklarla güncel (özet tutuyor)")

	# Editördeki gibi: sahne betiksiz (araç betiği olmayanlar editörde çalışmaz)
	var scene: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	_strip(scene)
	root.add_child(scene)
	var gallery_wall: Node3D = scene.get_node("GrassArea/Gallery/FrontWall") as Node3D
	var grid: Node3D = scene.get_node("GarageSystem/BuildGrid/BuildGrid/GridPreview") as Node3D
	var hitbox: Node = scene.get_node("GrassArea/Gallery/ShowroomHitbox")
	check(gallery_wall.visible and grid.visible, "önizlemesiz: eski showroom ve ızgara görünür (editördeki hâl)")

	print("== 2) ÖNİZLEME ==")
	var preview: CityPreview = CityPreview.new()
	preview.top_level = true
	scene.get_node("GarageSystem").add_child(preview, false, Node.INTERNAL_MODE_BACK)
	preview.show_preview(scene)
	await _frames(3)
	var content: Node = preview.get_child(0) if preview.get_child_count() > 0 else null
	check(content != null and content.find_child("Showroom", true, false) != null, "yeni showroom binası önizlemede")
	check(content != null and content.find_child("TrafficLights", true, false) != null, "trafik lambaları önizlemede")
	check(not gallery_wall.visible and not grid.visible, "oyundaki gibi eski showroom ve ızgara gizli")
	check(hitbox.get_parent() != null, "showroom'un tıklama alanı yerinde")
	var owned: bool = false
	for node: Node in preview.find_children("*", "", true, false):
		if node.owner == scene:
			owned = true
	check(not owned, "önizleme düğümlerinin hiçbiri sahneye ait değil (kaydedilmez)")
	if OS.get_environment("CT_PREVIEW_SHOT") != "":
		var camera: Camera3D = scene.get_node("MainCamera") as Camera3D
		camera.make_current()
		await _frames(4)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("CT_PREVIEW_SHOT"))

	print("== 3) KAYDETME ==")
	scene.propagate_notification(Node.NOTIFICATION_EDITOR_PRE_SAVE)
	var packed: PackedScene = PackedScene.new()
	packed.pack(scene)
	var saved: Node = packed.instantiate()
	check((saved.get_node("GrassArea/Gallery/FrontWall") as Node3D).visible
		and (saved.get_node("GarageSystem/BuildGrid/BuildGrid/GridPreview") as Node3D).visible,
		"kaydedilen sahnede eski showroom / ızgara özgün hâlinde (görünür)")
	check(saved.get_node("GarageSystem").find_child("CityPreview", true, false) == null, "önizleme kaydedilen sahnede yok")
	saved.free()
	scene.propagate_notification(Node.NOTIFICATION_EDITOR_POST_SAVE)
	check(not gallery_wall.visible, "kayıttan sonra önizleme yeniden uygulanır")

	print("== 4) SEKME DEĞİŞİMİ / KAPATMA ==")
	root.remove_child(scene)
	check(gallery_wall.visible, "sahne ağaçtan çıkınca (sekme değişti) özgün hâl")
	root.add_child(scene)
	check(not gallery_wall.visible, "sekmeye dönünce önizleme yeniden uygulanır")
	preview.dispose()
	await _frames(2)
	check(gallery_wall.visible and grid.visible, "önizleme kapanınca sahne özgün hâline döner")
	scene.free()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _stale() -> bool:
	if not FileAccess.file_exists(CityPreview.FILE):
		return true
	var packed: PackedScene = ResourceLoader.load(CityPreview.FILE, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	var node: Node = packed.instantiate() if packed else null
	var stale: bool = node == null or String(node.get_meta(&"source_hash", "")) != CityPreview.source_hash()
	if node:
		node.free()
	return stale
