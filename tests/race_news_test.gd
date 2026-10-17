extends SceneTree
## ARKADAŞ YARIŞI aşama 3 (başsız): arkadaş bonusu (+%20, arkadaş başına günde bir), iki yönlü skor, İNTİKAM (doğrudan
## pist), yarış haberleri (sahte Firebase: yazma, okuma, skorun karşı yönü, silme, engellenen, hesap silme).
## tools/run_tests.sh race_news_test

const SocialTest: GDScript = preload("res://tests/social_test.gd")
const SIGNALS: Array[StringName] = [&"auth_success", &"auth_failure", &"sign_out_success", &"user_deleted",
	&"firestore_get_task_completed", &"firestore_write_task_completed", &"firestore_delete_task_completed"]

var fails: int = 0
var fb: Object
var w: Dictionary = {}
var news: Array[Dictionary] = []


func _initialize() -> void:
	if OS.get_user_data_dir().ends_with("/CarTownRemake") or OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	fb = SocialTest.FakeFB.new()
	fb.tree = self
	seed(99)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func until(cond: Callable, limit: float = 5.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func wipe_device() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))


func open_session(account: String, fresh_device: bool = true) -> void:
	if fresh_device:
		wipe_device()
	fb.account = account
	fb.user = {}
	news.clear()
	var root_node: Node = Node.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var race: RaceManager = RaceManager.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	social.use_firebase(fb)
	social.publish_delay = 0.3
	social.request_timeout = 1.0
	var push: PushService = PushService.new()
	for n: Node in [EconomyManager.new(), PlayerProgress.new(), GarageUpgradeManager.new(), own, JunkyardManager.new(),
			PlayerProfile.new(), race, save, cloud, social, push]:
		root_node.add_child(n)
	root.add_child(root_node)
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.user_deleted.connect(cloud._on_user_deleted)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	social.race_news.connect(func(e: Dictionary) -> void: news.append(e))
	w = {"root": root_node, "own": own, "race": race, "save": save, "cloud": cloud, "social": social, "push": push}
	await frames(6)
	cloud.sign_in()
	await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED)
	await until(func() -> bool: return social.get_state() not in [SocialManager.State.SIGNED_OUT, SocialManager.State.LOADING])
	await until(func() -> bool: return not social.is_busy())


func close_session() -> void:
	await until(func() -> bool: return not social().is_busy() and not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	(w["save"] as SaveManager).save_game()
	(w["cloud"] as CloudSaveManager).upload_save()
	await frames(2)
	await until(func() -> bool: return not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].queue_free()
	w = {}
	await frames(2)


func social() -> SocialManager:
	return w["social"]


func race() -> RaceManager:
	return w["race"]


func economy() -> EconomyManager:
	return get_first_node_in_group("economy") as EconomyManager


## Arkadaşın aracıyla yarışı simüle eder (yoldan gelen rakip olmadan: sahibi + model elle kurulur).
func race_against(owner: Dictionary, car: StringName, won: bool) -> Dictionary:
	race()._rival_id = car
	race()._rival_owner = owner
	race()._reward_paid = false
	var reward: Dictionary = race().finish_race(won)
	race().end_race_session()
	return reward


func _run() -> void:
	print("== 1) Bonus, skor, İNTİKAM (yerel) ==")
	await open_session("solo")
	var bob_owner: Dictionary = {"uid": "bob", "name": "Bob Usta", "featured": false, "paint": "", "build": {}}
	var base: int = int(race().reward_for(&"seat_leon", true)["money"])
	var money0: int = economy().money
	var r1: Dictionary = race_against(bob_owner, &"seat_leon", true)
	check(int(r1.get("friend_bonus", 0)) == int(round(base * RaceManager.FRIEND_BONUS)) and economy().money == money0 + int(r1["money"]),
		"gerçek arkadaşı yenince +%%20 (%d → %d)" % [base, int(r1["money"])])
	var r2: Dictionary = race_against(bob_owner, &"seat_leon", true)
	check(not r2.has("friend_bonus") and int(r2["money"]) == base, "aynı gün aynı arkadaştan ikinci bonus yok")
	var r3: Dictionary = race_against(FeaturedFriends.rival_owner("featured_elif"), &"tofas_sahin", true)
	check(not r3.has("friend_bonus"), "Emre / Elif'e bonus yok")
	race_against(bob_owner, &"seat_leon", false)
	check(race().score_with("bob") == Vector2i(2, 1) and race().my_counts("bob") == Vector2i(2, 1), "skor: 2 galibiyet, 1 mağlubiyet")
	race().set_their_counts("bob", 4, 3)   # Bob benim aracıma karşı: 4 kazandı, 3 kaybetti
	check(race().score_with("bob") == Vector2i(2 + 3, 1 + 4), "iki yön toplamı: 5–5")
	check(race().score_with("featured_elif") == Vector2i(1, 0), "Elif'e karşı da kendi yönüm sayılır")
	var state: Dictionary = race().state()
	var copy: RaceManager = RaceManager.new()
	copy.load_state(state)
	check(copy.score_with("bob") == Vector2i(5, 5) and copy.state()["bonus"] == state["bonus"], "skor ve bonus günü kayıtta")
	copy.load_state({"rivals": {"x": {"mw": 2}}, "races": 3})   # "best" bölümü olmayan kayıt
	check(copy.score_with("x") == Vector2i(2, 0), "rekoru olmayan kayıtta da skor okunur")
	copy.free()
	check(race().start_revenge(bob_owner, &"seat_leon") and race().is_revenge() and race().rival_id() == &"seat_leon",
		"İNTİKAM: pist doğrudan, rakip Bob'un Leon'u")
	check(not race().can_rematch(), "İNTİKAM'da rövanş yok")
	race().finish_race(true)
	check(not race().rival_owner().is_empty(), "sonuç panosu için sahip, oturum bitene kadar kalır")
	race().end_race_session()
	check(race().rival_owner().is_empty() and not race().is_revenge(), "oturum bitince temizlendi")
	await close_session()

	print("== 2) Haber: Alice Bob'un aracını yener ==")
	await open_session("bob")
	check(await social().create_profile("Bob Usta"), "bob profil")
	var bob_code: String = social().my_code()
	await close_session()
	await open_session("alice")
	check(await social().create_profile("Usta Ali"), "alice profil")
	(w["own"] as VehicleOwnership).add_vehicle(&"vw_golf_7")
	(w["own"] as VehicleOwnership).set_race_vehicle(&"vw_golf_7")
	PerformanceMods.set_build(&"vw_golf_7", {&"motor": 2})
	check(await social().send_request(bob_code), "alice → bob istek")
	await close_session()
	await open_session("bob", false)
	await social().refresh(true)
	check(await social().accept("alice"), "bob kabul")
	(w["own"] as VehicleOwnership).add_vehicle(&"seat_leon")
	(w["own"] as VehicleOwnership).set_race_vehicle(&"seat_leon")
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)
	var bob_entry: Dictionary = social().person("bob")
	var owner: Dictionary = {"uid": "bob", "name": "Bob Usta", "featured": false, "paint": "", "build": {}}
	race_against(owner, &"seat_leon", true)
	await until(func() -> bool: return fb.store.has("users/bob/races/e_alice"), 3.0)
	var e: Dictionary = fb.store.get("users/bob/races/e_alice", {})
	check(e.get("won") == true and e.get("car") == "vw_golf_7" and e.get("their_car") == "seat_leon" and int(e.get("mw", -1)) == 1
		and int(e.get("ml", -1)) == 0 and (e.get("build") as Dictionary).get("motor") == 2, "Bob'a haber: Alice Golf'le kazandı (motor 2) %s" % [e])
	race_against(FeaturedFriends.rival_owner("featured_emre"), &"bmw_e46", false)
	await frames(10)
	check(not fb.store.keys().any(func(k: String) -> bool: return k.contains("featured")), "Emre / Elif'e haber yazılmaz")
	await close_session()

	print("== 3) Bob haberi görür, İNTİKAM alır ==")
	await open_session("bob", false)
	await social().refresh(true)
	check(social().race_events.size() == 1 and social().race_events[0]["uid"] == "alice" and bool(social().race_events[0]["won"]),
		"Bob'un haberi: Alice kazandı")
	check(news.size() == 1, "yeni haber bildirimi (race_news)")
	check(race().score_with("alice") == Vector2i(0, 1), "Bob'da skor 0–1 (haberden)")
	var revenge: Dictionary = social().revenge_owner("alice")
	check(revenge.get("build") == {&"motor": 2}, "İNTİKAM rakibi Alice'in modifiyeli Golf'ü")
	check(race().start_revenge(revenge, social().race_event("alice")["car"]), "İNTİKAM başladı")
	await social().dismiss_event("alice")
	check(not fb.store.has("users/bob/races/e_alice") and social().race_events.is_empty(), "haber kullanıldı (silindi)")
	race().finish_race(true)
	race().end_race_session()
	await until(func() -> bool: return fb.store.has("users/alice/races/e_bob"), 3.0)
	var back: Dictionary = fb.store.get("users/alice/races/e_bob", {})
	check(back.get("revenge") == true and back.get("won") == true and int(back.get("mw", -1)) == 1, "Alice'e İNTİKAM haberi")
	check(race().score_with("alice") == Vector2i(1, 1), "Bob'da skor 1–1")
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)
	check(race().score_with("bob") == Vector2i(1, 1), "Alice'te de skor 1–1 (tabelalar aynı)")
	check(news.size() == 1 and bool(news[0]["revenge"]), "Alice'e İNTİKAM bildirimi")
	await social().refresh(true)
	check(news.size() == 1, "aynı haber ikinci kez bildirilmez")

	print("== 4) Engellenen ve hesap silme ==")
	fb.store["users/alice/races/e_bob"] = back
	await social().block("bob")
	await social().refresh(true)
	check(not fb.store.has("users/alice/races/e_bob") and social().race_events.is_empty(), "engellenenin haberi silindi")
	await close_session()
	await open_session("dave")
	check(await social().create_profile("Dave"), "dave profil")
	var dave_code: String = social().my_code()
	await close_session()
	await open_session("alice", false)
	check(await social().send_request(dave_code), "alice → dave")
	await close_session()
	await open_session("dave", false)
	await social().refresh(true)
	check(await social().accept("alice"), "dave kabul")
	race_against({"uid": "alice", "name": "Usta Ali", "featured": false, "paint": "", "build": {}}, &"vw_golf_7", true)
	await until(func() -> bool: return fb.store.has("users/alice/races/e_dave"), 3.0)
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)
	race_against({"uid": "dave", "name": "Dave", "featured": false, "paint": "", "build": {}}, &"tofas_sahin", true)
	await until(func() -> bool: return fb.store.has("users/dave/races/e_alice"), 3.0)

	print("== 5) Telefon bildirimi jetonu ==")
	PushService.force_available = true   # masaüstü: izin / jeton yerine QA değeri
	var push: PushService = w["push"]
	check(push.available() and not push.is_enabled() and not fb.store.has("push/p_alice"), "kapalı başlar: rızasız jeton yazılmaz")
	check(await push.enable() and push.is_enabled(), "AÇ: izin + jeton")
	var stored: Dictionary = fb.store.get("push/p_alice", {})
	check(SaveSafe.s(stored.get("token", "")).length() > 20 and stored.get("lang") == Loc.current(), "push/p_alice = {token, lang: %s}" % stored.get("lang"))
	await push.disable()
	check(not push.is_enabled() and not fb.store.has("push/p_alice"), "KAPAT: sunucudan silindi")
	check(await push.enable(), "yeniden AÇ")
	var poll_event: Dictionary = (fb.store["users/alice/races/e_dave"] as Dictionary).duplicate()
	poll_event["at"] = int(poll_event["at"]) + 50
	fb.store["users/alice/races/e_dave"] = poll_event
	news.clear()
	await social()._on_news_poll()
	check(news.size() == 1 and news[0]["uid"] == "dave", "oyun açıkken yoklama yeni haberi bildirir")
	(w["cloud"] as CloudSaveManager).delete_account()
	await until(func() -> bool: return not fb.store.has("players/alice"), 8.0)
	check(not fb.store.has("users/alice/races/e_dave") and not fb.store.has("users/dave/races/e_alice"),
		"hesap silinince gelen ve gönderilen haberler silindi")
	check(not fb.store.has("push/p_alice"), "hesap silinince bildirim jetonu silindi")
	PushService.force_available = false
	await close_session()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
