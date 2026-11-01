extends SceneTree
## YENİ TAKMA AD önerisi + ZAR görüntüleri, sahte Firebase'le: adı eski otomatik "Usta4821" olan oyuncu açılışta
## kendiliğinden kartı görür (Hud._tick_rename_prompt), zar atar; sonra PROFİL › DÜZENLE › TAKMA AD satırındaki zar.
## tools/qa_isolated.sh res://qa/rename_shots.gd --resolution 1152x648   (QA_LANG=en ile İngilizce)
## Çıktı: ~/Projects/ct_shots/rename/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/rename/"
var fb: Object


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func shot(name: String, settle: int = 40) -> void:
	for i: int in settle:
		await process_frame
	RenderingServer.force_draw()
	var lang: String = Loc.current()
	get_root().get_texture().get_image().save_png(OUT + "%s_%s.png" % [name, lang])
	print("görüntü: ", name)


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json", "rename_offer.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	fb.store = {
		"garages/g_alice": {"name": "Usta4821", "code": "ALC234", "level": 6, "value": 0, "garage_json": "{}", "updated_at": 1},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	OS.set_environment("CT_NO_TUTORIAL", "1")   # eski oyuncu: dersler bitmiş
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.rename_prompt_session = 0.0   # oturumun ilk 20 sn'si beklenmez
	hud.router.close_all()
	var waited: int = 0
	while hud.router.top() != &"rename_prompt" and waited < 900:
		await process_frame
		waited += 1
	print("kart kendiliğinden açıldı: ", hud.router.top() == &"rename_prompt", " (", waited, " kare)")
	await shot("1_kart")
	(hud.rename_prompt.find_child("DiceButton", true, false) as PlateButton).pressed.emit()
	await shot("2_kart_zar", 10)
	(hud.rename_prompt.find_child("KeepButton", true, false) as PlateButton).pressed.emit()
	for i: int in 30:
		await process_frame
	hud.router.open(&"profile")
	await shot("3_profil", 20)
	hud.router.open(&"profile_edit")
	await shot("4_duzenle", 10)
	hud.profile_edit_screen.call("_select_tab", 4)   # TAKMA AD
	await shot("5_takma_ad", 20)
	quit(0)
