extends SceneTree
## YARIŞ HABERLERİ / İNTİKAM / SKOR / ARKADAŞ BONUSU görüntüleri (sahte Firebase).
## Bob (fotoğraflı, mavi modifiyeli Leon) Alice'in Golf'ünü yenmiş; Carol'ın aracı Alice'in Golf'üne yenilmiş.
## Telefon ölçeği: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/race_news_shots.gd --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/race_news/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/race_news/"
var fb: Object


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	get_root().content_scale_factor = 1.35
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String, settle: int = 30) -> void:
	await frames(settle)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + name + ".png")
	print("görüntü: ", name)


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	var thumb: Image = (load("res://assets/cars/thumbs/seat_leon.png") as Texture2D).get_image()
	thumb.decompress()
	var side: int = mini(thumb.get_width(), thumb.get_height())
	var bytes: PackedByteArray = ProfileCatalog.encode_photo(thumb.get_region(Rect2i((thumb.get_width() - side) / 2, 0, side, side)))
	var hash: String = ProfileCatalog.hash_of(bytes)
	var bob_garage: String = PublicGarage.to_json(PublicGarage.from_snapshot({"version": SaveManager.SAVE_VERSION,
		"progress": {"level": 14}, "vehicles": {"owned": ["seat_leon"], "paint": {"seat_leon": "1e6fd9"}},
		"performance": {"builds": {"seat_leon": {"motor": 2, "turbo": 1}}}}))
	fb.store = {
		"garages/g_alice": {"name": "Usta Ali", "code": "ALC234", "level": 1, "value": 0, "garage_json": "{}", "updated_at": 1},
		"garages/g_bob": {"name": "Bob Usta", "code": "BQB234", "level": 14, "value": 250000, "garage_json": bob_garage,
			"updated_at": 1, "av": "img:" + hash, "frame": "gold", "flag": "DE", "title": "Bob Racing", "car": "seat_leon",
			"stats": {"wins": 12, "races": 20, "cars": 6, "best": 10900, "best_car": "seat_leon"}},
		"avatars/a_bob": {"img": Marshalls.raw_to_base64(bytes), "hash": hash, "at": 1},
		"garages/g_carol": {"name": "Şahin Çağrı", "code": "CRL234", "level": 12, "value": 90000, "garage_json": "{}",
			"updated_at": 1, "av": "p04", "frame": "checker", "flag": "TR", "title": "Çağrı Oto", "car": "tofas_sahin",
			"stats": {"wins": 9, "races": 21, "cars": 5, "best": 13650, "best_car": "tofas_sahin"}},
		"users/alice/friends/f_bob": {"since": 1},
		"users/alice/friends/f_carol": {"since": 1},
		"users/bob/friends/f_alice": {"since": 1},   # arkadaşlığın Bob tarafı (İNTİKAM haberi ona yazılabilsin)
		"users/alice/races/e_bob": {"name": "Bob Usta", "car": "seat_leon", "paint": "1e6fd9", "build": {"motor": 2, "turbo": 1},
			"their_car": "vw_golf_7", "won": true, "revenge": false, "mw": 4, "ml": 2, "at": 200},
		"users/alice/races/e_carol": {"name": "Şahin Çağrı", "car": "tofas_sahin", "paint": "", "build": {},
			"their_car": "vw_golf_7", "won": false, "revenge": false, "mw": 1, "ml": 3, "at": 100},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	change_scene_to_file("res://Main.tscn")
	await frames(60)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	ownership.add_vehicle(&"vw_golf_7")
	ownership.set_race_vehicle(&"vw_golf_7")
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}
	race._rivals["bob"] = {"mw": 3, "ml": 1, "tw": 0, "tl": 0}
	(get_first_node_in_group("traffic") as TrafficManager).chase._timer = 99999.0
	race.challenge_timeout = 600.0
	race._timer = 9999.0
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	social._meta["events_seen"] = {}
	PushService.force_available = true   # YARIŞ BİLDİRİMLERİ satırı masaüstünde de görünsün
	await social.refresh(true)
	await shot("1_bildirim", 20)
	hud.router.open(&"friends")
	await shot("2_arkadaslar_haber", 60)
	hud.friends_screen.person_requested.emit("bob")
	await shot("3_kart_skor")
	hud.router.back()
	await frames(20)
	# Davet: gerçek arkadaş rakip (bonus notu)
	hud.router.close_all()
	race._rival_id = &"seat_leon"
	race._rival_owner = {"uid": "bob", "name": "Bob Usta", "av": "img:" + hash, "frame": "gold", "flag": "DE",
		"featured": false, "paint": "1e6fd9", "build": {&"motor": 2, &"turbo": 1}}
	hud.router.open(&"race_challenge")
	await shot("4_davet_bonus")
	hud.router.close_all()
	race._rival_owner = {}
	race._rival_id = &""
	await frames(20)
	# İNTİKAM: ARKADAŞLAR'dan
	hud.router.open(&"friends")
	await frames(40)
	hud.friends_screen.revenge_requested.emit("bob")
	await create_timer(2.6).timeout
	await shot("5_intikam_pist", 5)
	hud.drag_race_screen.race_completed.emit(true, 11.2, 11.6)
	await create_timer(0.8).timeout
	await shot("6_intikam_sonuc", 20)
	print("haber kaldı mı: ", fb.store.has("users/alice/races/e_bob"), "  bob'a haber: ", fb.store.get("users/bob/races/e_alice", {}))
	quit(0)
