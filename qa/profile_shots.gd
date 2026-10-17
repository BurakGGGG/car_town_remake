extends SceneTree
## PROFİL + ARKADAŞ KARTI görüntüleri, sahte Firebase'le (fotoğraflı arkadaş, hazır avatarlı arkadaş, gelen istek).
## Telefon ölçeği (16:9, 853x480 tuval): tools/qa_isolated.sh res://qa/profile_shots.gd --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/profile/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/profile/"
var fb: Object


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func shot(name: String, settle: int = 40) -> void:
	for i: int in settle:
		await process_frame
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("görüntü: ", name)


## Araç küçük resminden kare "fotoğraf" (gerçek fotoğraf yerine).
func square(car: String) -> Image:
	var image: Image = (load("res://assets/cars/thumbs/%s.png" % car) as Texture2D).get_image()
	image.decompress()
	var side: int = mini(image.get_width(), image.get_height())
	return image.get_region(Rect2i((image.get_width() - side) / 2, (image.get_height() - side) / 2, side, side))


func fake_photo(car: String) -> Dictionary:
	var bytes: PackedByteArray = ProfileCatalog.encode_photo(square(car))
	return {"hash": ProfileCatalog.hash_of(bytes), "img": Marshalls.raw_to_base64(bytes)}


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	var bob_photo: Dictionary = fake_photo("porsche_gt3")
	var garage: String = PublicGarage.to_json(PublicGarage.from_snapshot({"version": SaveManager.SAVE_VERSION,
		"progress": {"level": 30}, "garage_upgrades": {"garage_level": 3}, "repair_bays": {"unlocked": 2, "layout": []},
		"decor": {}, "vehicles": {"owned": ["porsche_gt3"], "paint": {}}}))
	fb.store = {
		"garages/g_alice": {"name": "Usta Ali", "code": "ALC234", "level": 1, "value": 0, "garage_json": "{}", "updated_at": 1},
		"garages/g_bob": {"name": "Bob Usta", "code": "BQB234", "level": 30, "value": 1250000, "garage_json": garage,
			"updated_at": 1, "av": "img:" + bob_photo["hash"], "frame": "gold", "flag": "DE", "title": "Bob Racing",
			"car": "porsche_gt3", "stats": {"wins": 57, "races": 80, "cars": 14, "best": 9122, "best_car": "porsche_gt3"}},
		"avatars/a_bob": {"img": bob_photo["img"], "hash": bob_photo["hash"], "at": 1},
		"garages/g_carol": {"name": "Şahin Çağrı", "code": "CRL234", "level": 12, "value": 90000, "garage_json": "{}",
			"updated_at": 1, "av": "p04", "frame": "checker", "flag": "TR", "title": "Çağrı Oto", "car": "tofas_sahin",
			"stats": {"wins": 9, "races": 21, "cars": 5, "best": 13650, "best_car": "tofas_sahin"}},
		"garages/g_dave": {"name": "Dave", "code": "DVE234", "level": 4, "value": 8000, "garage_json": "{}", "updated_at": 1,
			"av": "p07", "frame": "plate", "flag": "AZ", "title": "", "car": "", "stats": {"wins": 0, "races": 2, "cars": 1, "best": 0, "best_car": ""}},
		"users/alice/friends/f_bob": {"since": 1},
		"users/alice/friends/f_carol": {"since": 1},
		"users/alice/inbox/r_dave": {"name": "Dave", "code": "DVE234", "at": 5},
		"users/alice/outbox/o_eve": {"name": "Eve Garage", "code": "EVE234", "at": 3},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	change_scene_to_file("res://Main.tscn")
	for i: int in 90:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	ownership.add_vehicle(&"vw_golf_7")
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(22, 0, 500)
	profile.set_photo(square("vw_golf_7"))
	profile.set_frame("gold")
	profile.set_flag("TR")
	profile.set_title("Mavi Garaj")
	profile.set_showcase(&"vw_golf_7")
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	await social.refresh(true)
	for i: int in 60:
		await process_frame
	await shot("1_hud")
	hud.router.open(&"profile")
	await shot("2_profil")
	hud.router.open(&"friends")
	await shot("3_arkadaslar", 80)
	hud.friends_screen.person_requested.emit("bob")
	await shot("4_kart_bob")
	hud.friend_card_screen.call("_set_confirm", &"report")
	await shot("5_kart_sikayet")
	hud.router.back()
	hud.friends_screen.person_requested.emit("dave")
	await shot("6_kart_istek")
	hud.router.back()
	hud.friends_screen.person_requested.emit("featured_elif")
	await shot("7_kart_elif")
	quit(0)
