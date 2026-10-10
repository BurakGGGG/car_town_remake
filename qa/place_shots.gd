extends SceneTree
## Tam ekran (PLACE) ekranların görüntüsü: dünyayı tamamen örtüyorlar mı?
const OUT: String = "/home/burak/Projects/ct_shots/place/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 150:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false)
	for id: StringName in [&"garage", &"showroom", &"settings", &"drag_race", &"garage_edit"]:
		hud.router.open(id)
		for i: int in 60:
			await process_frame
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png(OUT + String(id) + ".png")
		hud.router.close_all()
		for i: int in 20:
			await process_frame
	quit(0)
