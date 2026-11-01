extends SceneTree
## ÇERÇEVELER oyunda: HUD avatarı (daire küçük, taşan süs kutuda: süssüz / taç / kanat / alevli kupa) + PROFİL › DÜZENLE ›
## ÇERÇEVE seçicisi (28 çerçeve). tools/qa_isolated.sh res://qa/frame_shots.gd --resolution 1152x648  (QA_LANG=de ile dar dil)
## Çıktı: ~/Projects/ct_shots/frames_v2/oyun/
const OUT: String = "/home/burak/Projects/ct_shots/frames_v2/oyun/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func shot(name: String, settle: int = 30, crop: Rect2i = Rect2i()) -> void:
	for i: int in settle:
		await process_frame
	RenderingServer.force_draw()
	var img: Image = root.get_texture().get_image()
	if crop.size != Vector2i.ZERO:
		img = img.get_region(crop)
	img.save_png(OUT + "%s_%s.png" % [name, Loc.current()])
	print("görüntü: ", name)


func _run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: quit(1))   # bekçi
	for f: String in ["savegame.json", "cloud_sync.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	OS.set_environment("CT_NO_TUTORIAL", "1")
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(99, 0, 2000)
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	profile.frames_owned.append_array(["winged", "flame_cup", "wood"])
	profile.set_preset("p05")
	var top: Rect2i = Rect2i(0, 0, 460, 200)
	for frame: String in ["plate", "crown", "winged", "flame_cup", "laurel", "wood"]:
		profile.set_frame(frame)
		await shot("hud_" + frame, 20, top)
	profile.set_frame("crown")
	await shot("hud_tam_ekran", 10)
	hud.router.open(&"profile")
	await shot("profil_karti", 30)
	hud.router.open(&"profile_edit")
	hud.profile_edit_screen.call("_select_tab", 1)   # ÇERÇEVE
	await shot("cerceve_secici", 30)
	var scroll: ScrollContainer = hud.profile_edit_screen.get("_scroll")
	scroll.scroll_vertical = 400
	await shot("cerceve_secici_2", 10)
	scroll.scroll_vertical = 2000
	await shot("cerceve_secici_3", 10)
	quit(0)
