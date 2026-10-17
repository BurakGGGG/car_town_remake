extends SceneTree
## ARKADAŞ RAKİP görüntüleri: yoldan gelen rakibin fotoğraflı balonu, davet panosu, pist, sonuç panosu.
## 1) Bob (sahte Firebase: fotoğraflı, mavi boyalı + modifiyeli Seat Leon)  2) Elif (öne çıkan, fabrika renginde).
## Telefon ölçeği: CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/friend_race_shots.gd --resolution 1152x648
## Çıktı: ~/Projects/ct_shots/friend_race/
const SocialTest: GDScript = preload("res://tests/social_test.gd")
const OUT: String = "/home/burak/Projects/ct_shots/friend_race/"
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
		"progress": {"level": 14}, "garage_upgrades": {"garage_level": 2}, "repair_bays": {"unlocked": 2, "layout": []},
		"decor": {}, "vehicles": {"owned": ["seat_leon"], "paint": {"seat_leon": "1e6fd9"}},
		"performance": {"builds": {"seat_leon": {"motor": 2, "turbo": 1}}}}))
	fb.store = {
		"garages/g_alice": {"name": "Usta Ali", "code": "ALC234", "level": 1, "value": 0, "garage_json": "{}", "updated_at": 1},
		"garages/g_bob": {"name": "Bob Usta", "code": "BQB234", "level": 14, "value": 250000, "garage_json": bob_garage,
			"updated_at": 1, "av": "img:" + hash, "frame": "gold", "flag": "DE", "title": "Bob Racing", "car": "seat_leon",
			"stats": {"wins": 12, "races": 20, "cars": 6, "best": 10900, "best_car": "seat_leon"}},
		"avatars/a_bob": {"img": Marshalls.raw_to_base64(bytes), "hash": hash, "at": 1},
		"users/alice/friends/f_bob": {"since": 1},
	}
	fb.user = {"uid": "alice", "isAnonymous": false, "name": "Alice", "email": "alice@gmail.com", "photoUrl": null}
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var race: RaceManager = get_first_node_in_group("race") as RaceManager
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	ownership.add_vehicle(&"vw_golf_7")
	ownership.set_race_vehicle(&"vw_golf_7")
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}   # ilk yarış değil: gerçek arkadaş gelebilir
	var traffic: TrafficManager = get_first_node_in_group("traffic") as TrafficManager
	traffic.chase._timer = 99999.0
	race.challenge_timeout = 600.0
	var social: SocialManager = get_first_node_in_group("social") as SocialManager
	await social.refresh(true)
	for round: Array in [["bob", 1.0], ["elif", 1.0]]:
		race.release_challenger()
		await frames(10)
		race.friend_chance = round[1]
		if round[0] == "elif":
			social.friends = []   # gerçek arkadaş yok: Emre / Elif gelir
			ownership.add_vehicle(&"tofas_sahin")
			ownership.set_race_vehicle(&"tofas_sahin")
			race._records[&"tofas_sahin"] = {"time": 14.0, "trace": PackedFloat32Array()}
		race._rival_id = &""
		race._timer = 0.0
		var until: int = Time.get_ticks_msec() + 40000
		while Time.get_ticks_msec() < until and not race.has_challenge():
			await process_frame
			race.request_challenge_now()
		var car: TrafficVehicle = race.challenger()
		print("rakip: %s  sahibi: %s" % [car.vehicle_id if car else &"yok", race.rival_owner().get("name", "-")])
		if car == null:
			continue
		var camera: WorldCamera = root.get_camera_3d() as WorldCamera
		camera.follow(car.global_position, 1.6)
		await shot("%s_1_balon" % round[0], 50)
		hud.call("_on_challenge_clicked", car)
		await shot("%s_2_davet" % round[0], 40)
		hud.race_challenge_screen.race_accepted.emit()
		await create_timer(2.6).timeout
		await shot("%s_3_pist" % round[0], 5)
		hud.drag_race_screen.race_completed.emit(round[0] == "bob", 11.2, 11.6)
		await create_timer(0.8).timeout
		await shot("%s_4_sonuc" % round[0], 20)
		hud.race_result_screen.exit_requested.emit()
		await create_timer(0.6).timeout
		if is_instance_valid(car):
			traffic._on_vehicle_despawn(car)   # eski rakip duruş noktasında kalmasın (yenisi oraya ışınlanıyor)
		await frames(5)
	quit(0)
