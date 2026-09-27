extends SceneTree
## Drag yarışı uçtan uca: hazırlık, kalkış, vites, bitiş kareleri.
const OUT: String = "/home/burak/Projects/ct_shots/drag/"
var _f: int = 0
var _hud: Node
var _drag: Node
var _shots: int = 0

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.max_fps = 0

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _shot(name: String) -> void:
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	_shots += 1

func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn"); return false
	if _f == 70:
		_hud = _find(current_scene, "HUD")
		_hud.get("router").call("open", &"drag_race")
		return false
	if _f == 140:
		_drag = _hud.get("drag_race_screen")
		if _drag == null:
			for n: String in ["DragRaceScreen", "DragRace"]:
				_drag = _find(_hud, n)
				if _drag: break
		print("ekran: %s | görünür: %s" % [_drag, (_drag as Control).visible if _drag else "-"])
		var pc: Node3D = _drag.get("_player_car")
		var rc: Node3D = _drag.get("_rival_car")
		var cam: Camera3D = _drag.get("_camera")
		print("oyuncu=%s (%s) rakip=%s (%s)" % [
			pc.global_position if pc else "YOK", _drag.get("_player_id"),
			rc.global_position if rc else "YOK", _drag.get("_rival_id")])
		if cam and pc and rc:
			print("ekranda: oyuncu=%s rakip=%s | kadraj=%s" % [
				cam.unproject_position(pc.global_position),
				cam.unproject_position(rc.global_position),
				get_root().get_visible_rect().size])
			print("kamera pos=%s boy=%.2f" % [cam.global_position, cam.size])
		_shot("1_hazirlik")
		return false
	if _f == 200:
		print("durum: %s" % [_drag.get("_state") if _drag else "-"])
		_shot("2_geri_sayim")
		return false
	if _f == 280:
		_shot("3_kalkis")
		if _drag and _drag.has_method("_register_shift"):
			_drag.call("_register_shift")
		return false
	if _f == 420:
		_shot("4_yaris")
		return false
	if _f == 700:
		_shot("5_son")
		print("kare sayısı: %d" % _shots)
		quit(0)
	return false
