extends SceneTree
## Garaj DETAY paneli: genel puan (0-1000) görünür, tüm araçlarda aralıkta, panel açılıp kapanır.
var _fails: int = 0

func _check(label: String, ok: bool) -> void:
	print(("  OK " if ok else "  FAIL ") + label)
	if not ok: _fails += 1

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = StringName(entry["id"])
		var o: int = DragRaceSim.overall_of(id)
		_check("%s overall %d aralıkta" % [id, o], o > 0 and o <= 1000)
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	var hud: Node = _find(current_scene, "HUD")
	var router: Node = hud.get("router")
	router.call("open", &"garage")
	for i: int in 30:
		await process_frame
	var g: Node = hud.get("garage_screen")
	g.call("_show_vehicle", g.get("_shown_vehicle") if g.get("_shown_vehicle") != &"" else StringName(CarCatalog.all()[0]["id"]), false)
	await process_frame
	(g.get("detail_button") as Button).button_pressed = true
	for i: int in 20:
		await process_frame
	var panel: Control = g.get("_detail_panel")
	_check("DETAY paneli açık", panel.visible)
	_check("aksiyon sütunu gizli", not (g.get("action_column") as Control).visible)
	_check("genel yazısı: " + (g.get("_detail_overall") as Label).text, (g.get("_detail_overall") as Label).text.ends_with("/ 1000"))
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/detail.png")
	g.call("_close_detail")
	_check("kapatınca aksiyonlar geri", (g.get("action_column") as Control).visible and not panel.visible)
	print("FAILS: ", _fails)
	quit(_fails)
