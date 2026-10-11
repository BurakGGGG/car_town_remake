extends SceneTree
## YENİDEN AÇILIŞ KARELERİ — 3D ekranlar (garaj, showroom, drag) kapanınca çizim hedefini bırakır, açılınca
## kapsayıcıdan geri alır (2026-10-11). Her ekran İKİ kez açılır; ikinci açılışın karesi ve görüntü alanı
## boyutu alınır (4×4 / 64×36 kalırsa bulanık / boş kare olur).
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/reopen_shots.gd --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/reopen/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(150)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var screens: Dictionary = {&"garage": hud.garage_screen, &"showroom": hud.showroom, &"drag_race": hud.drag_race_screen}
	var fails: int = 0
	for id: StringName in screens:
		var screen: Control = screens[id]
		var viewport: SubViewport = screen.find_children("*", "SubViewport", true, false)[0] as SubViewport
		print("%s kapalıyken görüntü alanı: %s" % [id, viewport.size])
		for round: int in 2:
			hud.router.open(id)
			await _frames(40)
			if round == 1:
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png(OUT + String(id) + ".png")
				var ok: bool = viewport.size.x >= 1000 and viewport.size.y >= 600
				print("%s ikinci açılış: görüntü alanı %s %s" % [id, viewport.size, "OK" if ok else "FAIL"])
				if not ok:
					fails += 1
			hud.router.close_all()
			await _frames(40)
		print("%s kapandıktan sonra: %s" % [id, viewport.size])
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
