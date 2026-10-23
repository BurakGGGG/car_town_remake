extends SceneTree
## YENİ OYUNCU: temiz kayıtla açılır (giriş ekranı çıkarsa misafir), alt sıra ve HARİTA karesi alınır — HARİTA plakası
## hurdalık açılmadan da görünmeli (2026-10-23). Kullanım: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/yeni_oyuncu_harita.gd \
##   --display-driver x11 --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/yeni_oyuncu_harita/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _wait(seconds: float) -> void:
	var until: int = Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await process_frame


func _run() -> void:
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	var until: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < until:
		await process_frame
		var gate: Node = root.find_child("LoginGate", true, false)
		if gate and gate.has_signal(&"finished"):
			gate.emit_signal(&"finished")   # misafir olarak devam
		if current_scene != null and current_scene.name != "LoadingScreen" and root.get_node_or_null("LoadingScreen") == null:
			break
	await _wait(2.0)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var junkyard: JunkyardManager = get_first_node_in_group("junkyard") as JunkyardManager
	print("QA hurdalık açık: %s · HARİTA görünür: %s" % [junkyard.is_open() if junkyard else false, hud.map_button.is_visible_in_tree()])
	root.get_texture().get_image().save_png(OUT + "1_alt_sira.png")
	hud.map_button.pressed.emit()
	await _wait(1.5)
	root.get_texture().get_image().save_png(OUT + "2_harita.png")
	quit()
