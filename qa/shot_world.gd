extends SceneTree
## Açılış kadrajı: oyuna girer girmez ne görünüyor (hiçbir ekran açılmadan).
var _f: int = 0
func _initialize() -> void:
	Engine.max_fps = 0
	DirAccess.make_dir_recursive_absolute("/home/burak/Projects/ct_shots/world/")
func _process(_d: float) -> bool:
	_f += 1
	if _f == 2:
		change_scene_to_file("res://Main.tscn")
	if _f in [90, 400]:
		RenderingServer.force_draw()
		get_root().get_texture().get_image().save_png("/home/burak/Projects/ct_shots/world/acilis_%d.png" % _f)
	if _f == 402:
		quit(0)
	return false
