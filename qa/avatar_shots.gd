extends SceneTree
## HAZIR AVATAR seçicisi (36 avatar, kilitli / elmaslı / başarım) ve SEVİYE ATLADIN'daki "YENİ PROFİL RESMİ" kartı,
## sahte Firebase'le (sv5, 120 gem, 37 drag galibiyeti). Yüzsüz simgelerin küçük boyda kırpılmadığı da görünür.
## tools/qa_isolated.sh res://qa/avatar_shots.gd --resolution 1152x648   (QA_LANG=en ile İngilizce)
## Çıktı: ~/Projects/ct_shots/avatars_v2/oyun/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/avatars_v2/oyun/"
var fb: Object


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func shot(name: String, settle: int = 40) -> void:
	for i: int in settle:
		await process_frame
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + "%s_%s.png" % [name, Loc.current()])
	print("görüntü: ", name)


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	fb.store = {
		"garages/g_alice": {"name": "TurboSomun", "code": "ALC234", "level": 5, "value": 0, "garage_json": "{}", "updated_at": 1},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	OS.set_environment("CT_NO_TUTORIAL", "1")
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(5, 0, 120)
	(get_first_node_in_group("race") as RaceManager).load_state({"races": 60, "wins": 37})
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	profile.set_preset("p29")   # direksiyon: HUD'da küçük boyda kırpılmadan
	profile.set_frame("bronze")
	await shot("1_hud_simge", 30)
	hud.router.open(&"profile")
	hud.router.open(&"profile_edit")
	await shot("2_avatarlar", 30)
	var scroll: ScrollContainer = hud.profile_edit_screen.get("_scroll")
	scroll.scroll_vertical = 260
	await shot("3_avatarlar_kilitli", 10)
	scroll.scroll_vertical = 600
	await shot("4_avatarlar_basarim", 10)
	var drift: AvatarButton = hud.profile_edit_screen.find_child("Preset_p17", true, false) as AvatarButton
	drift.pressed.emit()
	await shot("5_elmas_onay", 10)
	hud.router.close_all()
	for i: int in 30:
		await process_frame
	hud.level_up_screen.add_level(17, 5000)
	await shot("6_seviye17", 120)
	quit(0)
