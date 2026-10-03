extends SceneTree
## Giriş / çıkış / hesap değiştirme testi — sahte Firebase ile, PC'de, izole user:// klasöründe.
## Çalıştırma: tools/run_tests.sh login_flow_test
##
## Sahte Firebase gerçek Firebase'in "son giriş" kuralını uygular: Google girişinin üzerinden zaman
## geçtiyse (fresh = false) deleteUser başarısız olur. Silme akışı önce girişi tazelemezse test düşer.

class FakeFB extends Object:
	signal auth_success(d: Dictionary)
	signal auth_failure(m: String)
	signal sign_out_success(b: bool)
	signal user_deleted(b: bool)
	signal firestore_get_task_completed(r: Dictionary)
	signal firestore_write_task_completed(r: Dictionary)
	signal firestore_delete_task_completed(r: Dictionary)

	var user: Dictionary = {}
	var account: String = "alice"          # hesap seçicide seçilecek Google hesabı
	var linked: Dictionary = {}            # google hesabı -> uid (silinen hesap buradan çıkar)
	var docs: Dictionary = {}              # uid -> doküman
	var online: bool = true
	var fresh: bool = false                # son giriş yeni mi (Firebase recent-login kuralı)
	var cancel_next: bool = false          # hesap seçiciden vazgeçilecek
	var fail_delete_user: bool = false     # Auth silme başka bir nedenle başarısız
	var writes: int = 0
	var deletes: int = 0
	var anon_counter: int = 0              # signInAnonymously ÇAĞRILMAMALI (misafir = oturumsuz)
	var uid_counter: int = 0

	func isSignedIn() -> bool:
		return not user.is_empty()

	func getCurrentUser() -> Dictionary:
		return user.duplicate() if not user.is_empty() else {"error": "No user signed in"}

	func signInAnonymously() -> void:
		anon_counter += 1
		user = {"uid": "anon%d" % anon_counter, "isAnonymous": true, "name": null, "email": null, "photoUrl": null}
		call_deferred("emit_signal", "auth_success", user.duplicate())

	func signInWithGoogle() -> void:
		if cancel_next:
			cancel_next = false
			call_deferred("emit_signal", "auth_failure", "16: Cancelled by user.")
			return
		if not linked.has(account):
			uid_counter += 1
			linked[account] = "g_%s_%d" % [account, uid_counter]
		_google_user(linked[account])
		call_deferred("emit_signal", "auth_success", user.duplicate())

	func _google_user(uid: String) -> void:
		fresh = true
		user = {"uid": uid, "isAnonymous": false, "name": account.capitalize(), "email": account + "@gmail.com", "photoUrl": null}

	func signOut() -> void:
		user = {}
		call_deferred("emit_signal", "sign_out_success", true)

	func deleteUser() -> void:
		if user.is_empty() or not online or not fresh or fail_delete_user:
			call_deferred("emit_signal", "user_deleted", false)
			call_deferred("emit_signal", "auth_failure", "Delete failed: This operation is sensitive and requires recent authentication.")
			return
		for g: String in linked.keys():
			if linked[g] == user["uid"]:
				linked.erase(g)
		user = {}
		call_deferred("emit_signal", "user_deleted", true)

	func firestoreGetDocument(_c: String, id: String) -> void:
		var r: Dictionary
		if not online:
			r = {"status": false, "docID": id, "error": "Failed to get document because the client is offline."}
		elif docs.has(id):
			r = {"status": true, "docID": id, "data": docs[id].duplicate(true)}
		else:
			r = {"status": false, "docID": id, "error": "Document does not exist"}
		call_deferred("emit_signal", "firestore_get_task_completed", r)

	func firestoreSetDocument(_c: String, id: String, data: Dictionary, _merge: bool) -> void:
		if not online:
			call_deferred("emit_signal", "firestore_write_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		writes += 1
		docs[id] = data.duplicate(true)
		call_deferred("emit_signal", "firestore_write_task_completed", {"status": true, "docID": id})

	func firestoreDeleteDocument(_c: String, id: String) -> void:
		if not online:
			call_deferred("emit_signal", "firestore_delete_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		deletes += 1
		docs.erase(id)   # Firestore: olmayan dokümanı silmek de başarılıdır
		call_deferred("emit_signal", "firestore_delete_task_completed", {"status": true, "docID": id})


const SIGNALS: Array[StringName] = [
	&"auth_success", &"auth_failure",
	&"sign_out_success", &"user_deleted", &"firestore_get_task_completed",
	&"firestore_write_task_completed", &"firestore_delete_task_completed",
]

var fb: FakeFB = FakeFB.new()
var w: Dictionary = {}
var fails: int = 0
var deleted_results: Array[bool] = []
var notices: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	if OS.get_user_data_dir().ends_with("/CarTownRemake") or OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func user_file(name: String) -> String:
	return OS.get_user_data_dir().path_join(name)


func wipe_files() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "savegame.before_cloud.json", "cloud_backup.json"]:
		DirAccess.remove_absolute(user_file(f))


func make_world() -> void:
	var root_node: Node = Node.new()
	var eco: EconomyManager = EconomyManager.new()
	var prog: PlayerProgress = PlayerProgress.new()
	var upg: GarageUpgradeManager = GarageUpgradeManager.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	for n: Node in [eco, prog, upg, own, save, cloud]:
		root_node.add_child(n)
	root.add_child(root_node)
	# Plugin PC'de yok: _ready bağlantı kurmadı, sahte Firebase'i gerçek bağlantı adlarıyla bağla
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.user_deleted.connect(cloud._on_user_deleted)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	cloud.account_deleted.connect(func(ok: bool) -> void: deleted_results.append(ok))
	cloud.notice.connect(func(t: String) -> void: notices.append(t))
	w = {"root": root_node, "eco": eco, "prog": prog, "own": own, "save": save, "cloud": cloud}
	await frames(6)


func close_app() -> void:
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].free()
	w = {}
	await frames(2)


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func eco() -> EconomyManager:
	return w["eco"]


func cloud() -> CloudSaveManager:
	return w["cloud"]


## Misafir ilerleme yapar, Google'a bağlanır, SYNCED olur. Google UID'ini döndürür.
func play_and_sign_in(money: int) -> String:
	eco().set_money(money)
	(w["own"] as VehicleOwnership).add_vehicle(&"hyundai_getz")
	(w["save"] as SaveManager).save_game()
	cloud().sign_in()
	await frames(8)
	fb.fresh = false   # zaman geçti: Firebase artık "son giriş" istemez sayılır
	return cloud().get_uid()


func own() -> VehicleOwnership:
	return w["own"]


func vehicles() -> Array:
	var out: Array = []
	for id: StringName in own().owned_vehicle_ids():
		out.append(String(id))
	out.sort()
	return out


func get_json(name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://" + name))
	return parsed if parsed is Dictionary else {}


func sign_in_as(acct: String) -> void:
	fb.account = acct
	cloud().sign_in()
	await frames(10)


func _run() -> void:
	wipe_files()
	await make_world()
	var conflicts: Array[Dictionary] = []
	cloud().conflict_found.connect(func(l: Dictionary, c: Dictionary) -> void: conflicts.append({"local": l, "cloud": c}))

	print("Misafir: Firebase oturumu açılmaz")
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and fb.user.is_empty(), "misafir oturumsuz, SIGNED_OUT")
	check(fb.anon_counter == 0, "anonim hesap açılmadı")

	print("Dana: ilk giriş, ilerleme buluta gider")
	eco().set_money(20000)
	own().add_vehicle(&"hyundai_getz")
	(w["save"] as SaveManager).save_game()
	await sign_in_as("dana")
	var dana: String = cloud().get_uid()
	check(dana != "" and cloud().get_state() == CloudSaveManager.State.SYNCED, "Dana SYNCED")
	check(fb.docs.has(dana) and conflicts.is_empty(), "bulutta Dana'nın kaydı var, çakışma sorulmadı")
	check(fb.anon_counter == 0, "giriş sırasında da anonim hesap açılmadı")
	var dana_cars: Array = vehicles()

	print("Çıkış: cihaz yeni misafir oyununa döner, hesap bulutta kalır")
	cloud().sign_out()
	await frames(8)
	check(not cloud().is_authenticated() and fb.user.is_empty(), "oturum kapandı")
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT, "SIGNED_OUT")
	check(eco().money == 5000 and vehicles() == ["tofas_sahin"], "cihaz yeni misafir oyunu (5000, yalnızca Şahin)")
	check(int(get_json("savegame.json").get("economy", {}).get("money", -1)) == 5000, "local kayıt dosyası da sıfırlandı")
	check(int(get_json("savegame.before_signout.json").get("economy", {}).get("money", -1)) == 20000, "çıkıştan önceki kayıt yedeklendi (20000)")
	check(fb.docs.has(dana), "Dana'nın bulut kaydı duruyor")
	var meta: Dictionary = get_json("cloud_sync.json")
	check(not meta.has("uid") and not meta.has("synced_json"), "cihaz artık Dana'ya bağlı değil")
	check(fb.anon_counter == 0, "çıkıştan sonra anonim hesap açılmadı")

	print("Başka hesap (Erik): Dana'nın ilerlemesi sızmaz")
	await sign_in_as("erik")
	var erik: String = cloud().get_uid()
	check(erik != dana and cloud().get_state() == CloudSaveManager.State.SYNCED, "Erik SYNCED")
	check(eco().money == 5000 and vehicles() == ["tofas_sahin"], "Erik temiz oyunla başladı (5000, Şahin)")
	check(fb.docs.has(erik) and conflicts.is_empty(), "Erik'in kaydı oluştu, çakışma yok")
	eco().set_money(1234)
	await seconds(2.2)
	check(String(fb.docs[erik]["save_json"]).contains("1234"), "Erik'in ilerlemesi Erik'in dokümanına yazıldı")
	check(String(fb.docs[dana]["save_json"]).contains("20000"), "Dana'nın dokümanı değişmedi")
	cloud().sign_out()
	await frames(8)

	print("Dana'ya tekrar giriş: hesabı yüklenir")
	await sign_in_as("dana")
	check(cloud().get_uid() == dana, "Dana'nın UID'i aynı")
	check(eco().money == 20000 and vehicles() == dana_cars, "Dana'nın oyunu geri geldi (20000, araçlar)")
	check(conflicts.is_empty(), "çakışma sorulmadı (misafir boştu)")
	cloud().sign_out()
	await frames(8)

	print("Dolu misafir + mevcut hesap → seçim; bulutu seç")
	eco().set_money(777)
	(w["save"] as SaveManager).save_game()
	await sign_in_as("dana")
	check(cloud().get_state() == CloudSaveManager.State.CONFLICT and conflicts.size() == 1, "çakışma soruldu")
	check(int(conflicts[0]["local"]["money"]) == 777 and int(conflicts[0]["cloud"]["money"]) == 20000, "özetler doğru (777 ↔ 20000)")
	check(eco().money == 777, "seçim yapılana kadar hiçbir şey değişmedi")
	cloud().resolve_conflict(true)
	await frames(4)
	check(eco().money == 20000 and cloud().get_state() == CloudSaveManager.State.SYNCED, "bulut seçildi: hesap yüklendi")
	check(int(get_json("savegame.before_cloud.json").get("economy", {}).get("money", -1)) == 777, "ezilen misafir kaydı yedeklendi")
	cloud().sign_out()
	await frames(8)

	print("Dolu misafir + mevcut hesap → seçim; bu cihazı seç")
	eco().set_money(777)
	(w["save"] as SaveManager).save_game()
	conflicts.clear()
	await sign_in_as("dana")
	check(cloud().get_state() == CloudSaveManager.State.CONFLICT, "yine çakışma")
	cloud().resolve_conflict(false)
	await frames(8)
	check(eco().money == 777 and String(fb.docs[dana]["save_json"]).contains("777"), "cihaz seçildi: 777 buluta yazıldı")
	check(int(get_json("cloud_backup.json").get("economy", {}).get("money", -1)) == 20000, "ezilen bulut kaydı yedeklendi")

	print("Çevrimdışıyken eşitlenmemiş değişiklik varsa çıkış reddedilir")
	notices.clear()
	fb.online = false
	eco().set_money(999)
	await seconds(2.5)   # yazma denenir ve başarısız olur → OFFLINE
	check(cloud().get_state() == CloudSaveManager.State.OFFLINE, "OFFLINE")
	cloud().sign_out()
	await frames(6)
	check(cloud().is_authenticated() and eco().money == 999, "çıkış yapılmadı, ilerleme duruyor")
	check(notices.size() >= 1 and notices[notices.size() - 1].contains("çıkış yapılmadı"), "açıklama verildi: %s" % ", ".join(notices))
	fb.online = true
	cloud()._on_retry_timeout()
	await frames(8)
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and String(fb.docs[dana]["save_json"]).contains("999"), "internet gelince eşitlendi")
	cloud().sign_out()
	await frames(8)
	check(not cloud().is_authenticated() and eco().money == 5000, "şimdi çıkış yapıldı, yeni misafir oyunu")
	check(String(fb.docs[dana]["save_json"]).contains("999"), "ilerleme kaybolmadı, bulutta")

	print("Hesap seçiciden vazgeçme")
	fb.cancel_next = true
	notices.clear()
	cloud().sign_in()
	await frames(6)
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and notices.is_empty(), "vazgeçmede SIGNED_OUT, hata mesajı yok")
	check(fb.anon_counter == 0, "yine anonim hesap yok")

	print("Uygulama yeniden açılır: oturum ve oyun korunur")
	await sign_in_as("dana")
	check(eco().money == 999, "Dana geri geldi")
	await close_app()
	await make_world()
	await frames(8)
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and cloud().get_uid() == dana, "açılışta oturum sürüyor, SYNCED")
	check(eco().money == 999, "oyun aynı")
	await close_app()

	print("Yeni cihaz: local yok, bulut var → hesap yüklenir")
	wipe_files()
	await make_world()
	conflicts.clear()
	cloud().conflict_found.connect(func(l: Dictionary, c: Dictionary) -> void: conflicts.append({"local": l, "cloud": c}))
	await frames(4)
	check(eco().money == 999, "bulut kaydı otomatik yüklendi (999), soru sorulmadı")
	check(conflicts.is_empty(), "çakışma yok")
	await close_app()

	print("Local kayıt silinmiş ama cloud_sync.json kalmış → boş kayıt buluta yazılmaz")
	DirAccess.remove_absolute(user_file("savegame.json"))
	var writes_before: int = fb.writes
	await make_world()
	await frames(4)
	check(eco().money == 999 and fb.writes == writes_before, "bulut geri geldi, başlangıç kaydı buluta yazılmadı")
	check(String(fb.docs[dana]["save_json"]).contains("999"), "bulut kaydı sağlam")
	await close_app()

	print("Bulut kaydı bu sürümden yeni / bozuk → bulut ve local korunur")
	fb.docs[dana]["save_json"] = "{\"version\": 99}"
	notices.clear()
	await make_world()
	await frames(4)
	check(cloud().get_state() == CloudSaveManager.State.ERROR, "ERROR durumu")
	check(eco().money == 999 and fb.docs[dana]["save_json"] == "{\"version\": 99}", "iki taraf da değişmedi")
	eco().add_money(5)
	await seconds(2.2)
	check(fb.docs[dana]["save_json"] == "{\"version\": 99}", "ERROR'da buluta yazılmaz")
	cloud().sign_out()
	await frames(8)
	check(not cloud().is_authenticated() and eco().money == 5000, "ERROR'dayken çıkış yapılabilir (yeni misafir)")
	check(int(get_json("savegame.before_signout.json").get("economy", {}).get("money", -1)) == 1004, "yerel ilerleme yedeklendi (1004)")
	await close_app()

	print("RESULT fails=%d" % fails)
	fb.free()
	quit(1 if fails > 0 else 0)
