extends SceneTree
## ARKADAŞLAR ekranı ve ziyaret çubuğunun görüntüleri (sahte Firebase; izole user:// ile çalıştır).
## Çıktı: ~/Projects/ct_shots/social/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/social/"
var fb: Object


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func shot(name: String) -> void:
	for i: int in 30:
		await process_frame
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	var garage: Dictionary = PublicGarage.from_snapshot({"version": SaveManager.SAVE_VERSION, "progress": {"level": 30},
		"garage_upgrades": {"garage_level": 4}, "repair_bays": {"unlocked": 3, "layout": []}, "decor": {},
		"vehicles": {"owned": ["hyundai_getz", "porsche_gt3", "audi_rs6"], "paint": {}}})
	fb.store = {
		"garages/g_alice": {"name": "Usta Ali", "code": "ALC234", "level": 1, "value": 0, "garage_json": "{}", "updated_at": 1},
		"garages/g_bob": {"name": "Bob Usta", "code": "BQB234", "level": 30, "value": 1250000, "garage_json": PublicGarage.to_json(garage), "updated_at": 1},
		"garages/g_carol": {"name": "Şahin Çağrı", "code": "CRL234", "level": 12, "value": 90000, "garage_json": "{}", "updated_at": 1},
		"users/alice/friends/f_bob": {"since": 1},
		"users/alice/friends/f_carol": {"since": 1},
		"users/alice/inbox/r_dave": {"name": "Dave", "code": "DVE234", "at": 5},
		"users/alice/outbox/o_eve": {"name": "Eve Garage", "code": "EVE234", "at": 3},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	change_scene_to_file("res://Main.tscn")
	for i: int in 60:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	await shot("1_hud")
	hud.friends_button.pressed.emit()
	await shot("2_friends")
	(current_scene.find_child("Visit_bob", true, false) as PlateButton).pressed.emit()
	for i: int in 60:
		await process_frame
	await shot("3_visit")
	GarageVisit.end(self)
	for i: int in 10:
		await process_frame
	for uid: String in ["featured_emre", "featured_elif"]:
		(current_scene.find_child("Visit_" + uid, true, false) as PlateButton).pressed.emit()
		for i: int in 60:
			await process_frame
		await shot("4_" + uid)
		GarageVisit.end(self)
		for i: int in 10:
			await process_frame
	quit(0)
