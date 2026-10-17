extends SceneTree
## Giriş / çıkış / hesap değiştirme testi — sahte Firebase ile, PC'de, izole user:// klasöründe.
## Çalıştırma: tools/run_tests.sh login_flow_test
##
## Sahte Firebase gerçek Firebase'in "son giriş" kuralını uygular: girişin üzerinden zaman
## geçtiyse (fresh = false) deleteUser başarısız olur. Silme akışı önce girişi tazelemezse test düşer.
## Facebook girişi ve HESAP BAĞLAMA da sahtelenir (Firebase "e-posta başına tek hesap"): aynı e-postalı
## Facebook girişi Google hesabına bağlanır, PLAYER ekranından elle bağlama, başka hesaba bağlı kimlik,
## e-postası farklı hesap, silmede hesabın KENDİ yoluyla tazelenmesi, uygulama kimliği yokken "hazır değil".

class FakeFB extends Object:
	signal auth_success(d: Dictionary)
	signal auth_failure(m: String)
	signal sign_out_success(b: bool)
	signal user_deleted(b: bool)
	signal firestore_get_task_completed(r: Dictionary)
	signal firestore_write_task_completed(r: Dictionary)
	signal firestore_delete_task_completed(r: Dictionary)
	signal account_link_success(d: Dictionary)
	signal account_link_failure(m: String)

	var user: Dictionary = {}
	var account: String = "alice"          # hesap seçicide seçilecek Google hesabı
	var linked: Dictionary = {}            # giriş kimliği -> uid: Google "hesap", Facebook "fb:hesap" (silinen hesap çıkar)
	var uid_emails: Dictionary = {}        # uid -> hesabın e-postası (Firebase "e-posta başına tek hesap")
	var docs: Dictionary = {}              # uid -> doküman
	var online: bool = true
	var fresh: bool = false                # son giriş yeni mi (Firebase recent-login kuralı)
	var cancel_next: bool = false          # hesap seçiciden vazgeçilecek
	var fail_delete_user: bool = false     # Auth silme başka bir nedenle başarısız
	var writes: int = 0
	var deletes: int = 0
	var anon_counter: int = 0              # signInAnonymously ÇAĞRILMAMALI (misafir = oturumsuz)
	var uid_counter: int = 0
	var fb_account: String = "fiona"       # Facebook onayında seçilecek hesap
	var fb_emails: Dictionary = {}         # Facebook hesabı -> e-posta (yoksa <hesap>@example.com)
	var fb_cancel_next: bool = false
	var fb_configured: bool = true         # false: manifest'te Facebook uygulama kimliği yok
	var pending: Dictionary = {}           # e-posta çakışmasında bekletilen kimlik {key, email}
	var google_calls: int = 0
	var facebook_calls: int = 0
	var rule_denials: int = 0              # kurallara uymayan yazma (profilde fazladan alan vb.)

	func isSignedIn() -> bool:
		return not user.is_empty()

	func getCurrentUser() -> Dictionary:
		return user.duplicate() if not user.is_empty() else {"error": "No user signed in"}

	func signInAnonymously() -> void:
		anon_counter += 1
		user = {"uid": "anon%d" % anon_counter, "isAnonymous": true, "name": null, "email": null, "photoUrl": null}
		call_deferred("emit_signal", "auth_success", user.duplicate())

	func signInWithGoogle() -> void:
		google_calls += 1
		if cancel_next:
			cancel_next = false
			call_deferred("emit_signal", "auth_failure", "16: Cancelled by user.")
			return
		_sign_in(account, account + "@gmail.com", "g_%s")

	func signInWithFacebook() -> void:
		facebook_calls += 1
		if not fb_configured:
			call_deferred("emit_signal", "auth_failure", "Facebook login not configured")
			return
		if fb_cancel_next:
			fb_cancel_next = false
			call_deferred("emit_signal", "auth_failure", "Facebook login cancelled")
			return
		_sign_in("fb:" + fb_account, _fb_email(), "f_%s")

	## Kimlik bağlıysa o hesaba girer; değilse e-posta başka hesabınsa ÇAKIŞMA (kimlik bekletilir), yoksa yeni hesap.
	func _sign_in(key: String, email: String, uid_format: String) -> void:
		if not linked.has(key):
			var owner: String = _uid_of_email(email)
			if not owner.is_empty():
				pending = {"key": key, "email": email}
				call_deferred("emit_signal", "auth_failure", "ERROR_ACCOUNT_EXISTS_WITH_DIFFERENT_CREDENTIAL: An account already exists with the same email address but different sign-in credentials.")
				return
			uid_counter += 1
			var uid: String = (uid_format % key.trim_prefix("fb:")) + "_%d" % uid_counter
			linked[key] = uid
			uid_emails[uid] = email
		fresh = true
		_set_user(linked[key])
		call_deferred("emit_signal", "auth_success", user.duplicate())

	func _fb_email() -> String:
		return String(fb_emails.get(fb_account, fb_account + "@example.com"))

	func _uid_of_email(email: String) -> String:
		for uid: String in uid_emails:
			if uid_emails[uid] == email:
				return uid
		return ""

	## Kullanıcı sözlüğü: plugin getCurrentUser gibi "provider" (ilk yol) + "providers" (virgüllü).
	func _set_user(uid: String) -> void:
		var providers: PackedStringArray = PackedStringArray()
		for key: String in linked:
			if linked[key] == uid:
				providers.append("facebook.com" if key.begins_with("fb:") else "google.com")
		var email: String = String(uid_emails.get(uid, ""))
		user = {"uid": uid, "isAnonymous": false, "name": email.get_slice("@", 0).capitalize(), "email": email,
			"photoUrl": null, "provider": providers[0] if not providers.is_empty() else "", "providers": ",".join(providers)}

	func linkGoogle() -> void:
		if cancel_next:
			cancel_next = false
			call_deferred("emit_signal", "account_link_failure", "12501: ")
			return
		_link(account, account + "@gmail.com")

	func linkFacebook() -> void:
		if fb_cancel_next:
			fb_cancel_next = false
			call_deferred("emit_signal", "account_link_failure", "Facebook login cancelled")
			return
		_link("fb:" + fb_account, _fb_email())

	func linkPendingCredential() -> void:
		var p: Dictionary = pending
		pending = {}
		if p.is_empty() or user.is_empty():
			call_deferred("emit_signal", "account_link_failure", "No pending credential")
		elif String(p["email"]) != String(uid_emails.get(user["uid"], "")):
			call_deferred("emit_signal", "account_link_failure", "ERROR_EMAIL_MISMATCH: signed-in account email differs")
		else:
			_link(p["key"], p["email"])

	func clearPendingCredential() -> void:
		pending = {}

	## Firebase linkWithCredential: kimlik başka hesaba bağlıysa / e-postası başka hesabınsa reddeder.
	func _link(key: String, email: String) -> void:
		var uid: String = user.get("uid", "")
		if linked.has(key) and linked[key] != uid:
			call_deferred("emit_signal", "account_link_failure", "ERROR_CREDENTIAL_ALREADY_IN_USE: This credential is already associated with a different user account.")
			return
		var owner: String = _uid_of_email(email)
		if not owner.is_empty() and owner != uid:
			call_deferred("emit_signal", "account_link_failure", "ERROR_EMAIL_ALREADY_IN_USE: The email address is already in use by another account.")
			return
		linked[key] = uid
		_set_user(uid)
		call_deferred("emit_signal", "account_link_success", user.duplicate())

	func signOut() -> void:
		user = {}
		pending = {}
		call_deferred("emit_signal", "sign_out_success", true)

	func deleteUser() -> void:
		if user.is_empty() or not online or not fresh or fail_delete_user:
			call_deferred("emit_signal", "user_deleted", false)
			call_deferred("emit_signal", "auth_failure", "Delete failed: This operation is sensitive and requires recent authentication.")
			return
		for g: String in linked.keys():
			if linked[g] == user["uid"]:
				linked.erase(g)
		uid_emails.erase(user["uid"])
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
		# firestore.rules isValidPlayer / isValidProfile: fazladan alan → PERMISSION_DENIED
		var profile: Variant = data.get("profile", {})
		if not data.keys().all(func(k: String) -> bool: return k in ["profile", "save_version", "save_json", "updated_at"]) \
				or not (profile is Dictionary and (profile as Dictionary).keys().all(func(k: String) -> bool: return k in ["display_name", "email", "photo_url"])):
			rule_denials += 1
			call_deferred("emit_signal", "firestore_write_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
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
	&"account_link_success", &"account_link_failure",
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
	var crates: CrateManager = CrateManager.new()   # yeni oyunda HOŞ GELDİN KUTUSU (ilk araç ondan çıkar)
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	for n: Node in [eco, prog, upg, own, crates, save, cloud]:
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
	fb.account_link_success.connect(cloud._on_link_success)
	fb.account_link_failure.connect(cloud._on_link_failure)
	cloud.account_deleted.connect(func(ok: bool) -> void: deleted_results.append(ok))
	cloud.notice.connect(func(t: String) -> void: notices.append(t))
	w = {"root": root_node, "eco": eco, "prog": prog, "own": own, "crates": crates, "save": save, "cloud": cloud}
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
	check(eco().money == 5000 and vehicles().is_empty() and (w["crates"] as CrateManager).welcome_uid() > 0,
		"cihaz yeni misafir oyunu (5000, araç yok, HOŞ GELDİN KUTUSU bekliyor)")
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
	check(eco().money == 5000 and vehicles().is_empty() and (w["crates"] as CrateManager).welcome_uid() > 0,
		"Erik temiz oyunla başladı (5000, HOŞ GELDİN KUTUSU)")
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

	print("Facebook: yapılandırılmamış / vazgeçme")
	wipe_files()
	await make_world()
	notices.clear()
	fb.fb_configured = false
	cloud().sign_in_facebook()
	await frames(6)
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and notices == PackedStringArray([Loc.t("Facebook girişi henüz hazır değil")]),
		"uygulama kimliği yok → SIGNED_OUT, \"hazır değil\": %s" % ", ".join(notices))
	fb.fb_configured = true
	notices.clear()
	fb.fb_cancel_next = true
	cloud().sign_in_facebook()
	await frames(6)
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and notices.is_empty(), "Facebook'tan vazgeçme: SIGNED_OUT, mesaj yok")

	print("Aynı e-posta: Facebook girişi Google hesabına bağlanır (ilerleme Google hesabınınki)")
	fb.account = "hank"
	eco().set_money(7100)
	own().add_vehicle(&"hyundai_getz")
	(w["save"] as SaveManager).save_game()
	cloud().sign_in()
	await frames(10)
	var hank: String = cloud().get_uid()
	check(hank.begins_with("g_hank") and String(fb.docs[hank]["save_json"]).contains("7100"), "Hank Google'la girdi, 7100 bulutta")
	cloud().sign_out()
	await frames(8)
	check(eco().money == 5000, "çıkış: cihaz misafir (5000)")
	fb.fb_account = "hankfb"
	fb.fb_emails["hankfb"] = "hank@gmail.com"
	notices.clear()
	var google_before: int = fb.google_calls
	cloud().sign_in_facebook()
	await frames(14)
	check(fb.google_calls == google_before + 1, "çakışmada Google seçicisi kendiliğinden açıldı")
	check(notices.size() >= 1 and notices[0].contains("Google"), "oyuncuya neden Google açıldığı söylendi: %s" % notices[0] if not notices.is_empty() else "-")
	check(cloud().get_uid() == hank and cloud().get_state() == CloudSaveManager.State.SYNCED, "aynı hesap (Hank), SYNCED")
	check(Array(cloud().get_providers()) == ["google.com", "facebook.com"], "hesapta iki yol: %s" % ", ".join(cloud().get_providers()))
	check(eco().money == 7100, "Google hesabındaki ilerleme geldi (7100)")
	check(notices[notices.size() - 1].contains(Loc.t("Artık iki yolla da aynı hesaba girebilirsin.")), "\"bağlandı\" denildi")
	cloud().sign_out()
	await frames(8)
	google_before = fb.google_calls
	cloud().sign_in_facebook()
	await frames(10)
	check(cloud().get_uid() == hank and fb.google_calls == google_before and eco().money == 7100,
		"sonraki Facebook girişi doğrudan Hank'in hesabına, Google sorulmadan")
	check(cloud().get_provider() == CloudSaveManager.PROVIDER_FACEBOOK, "bu cihazda giriş yolu Facebook (silmede Facebook'la doğrulanır)")
	cloud().sign_out()
	await frames(8)

	print("Aynı e-posta ama Google seçicisinde BAŞKA hesap seçildi → bağlanmaz, o hesapla girilir")
	fb.account = "ivy"
	cloud().sign_in()
	await frames(10)
	cloud().sign_out()
	await frames(8)
	fb.fb_account = "ivyfb"
	fb.fb_emails["ivyfb"] = "ivy@gmail.com"
	fb.account = "jack"
	notices.clear()
	cloud().sign_in_facebook()
	await frames(14)
	check(cloud().get_uid().begins_with("g_jack") and Array(cloud().get_providers()) == ["google.com"], "Jack'in hesabıyla girildi, Facebook bağlanmadı")
	check(notices.size() == 2 and notices[1].contains("Facebook"), "e-posta farklı denildi: %s" % ", ".join(notices))
	check(fb.pending.is_empty(), "bekleyen kimlik bırakıldı")
	cloud().sign_out()
	await frames(8)

	print("Çakışmadan sonra Google seçicisinden de vazgeçildi")
	fb.cancel_next = true
	notices.clear()
	cloud().sign_in_facebook()
	await frames(10)
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and not cloud().is_authenticated(), "SIGNED_OUT")
	check(fb.pending.is_empty() and cloud()._pending_link_provider.is_empty(), "bekleyen kimlik temizlendi")

	print("PLAYER ekranından elle bağlama: Google hesabına Facebook")
	fb.account = "kate"
	cloud().sign_in()
	await frames(10)
	var kate: String = cloud().get_uid()
	check(cloud().can_link(CloudSaveManager.PROVIDER_FACEBOOK) and not cloud().can_link(CloudSaveManager.PROVIDER_GOOGLE),
		"Facebook bağlanabilir, Google zaten bağlı")
	fb.fb_account = "katefb"
	fb.fb_cancel_next = true
	notices.clear()
	cloud().link_provider(CloudSaveManager.PROVIDER_FACEBOOK)
	await frames(6)
	check(not cloud().is_linking() and notices.is_empty() and Array(cloud().get_providers()) == ["google.com"], "vazgeçme: mesaj yok, bağlanmadı")
	cloud().link_provider(CloudSaveManager.PROVIDER_FACEBOOK)
	check(cloud().is_linking(), "bağlama sürüyor")
	await frames(6)
	check(not cloud().is_linking() and Array(cloud().get_providers()) == ["google.com", "facebook.com"] and cloud().get_uid() == kate,
		"Facebook bağlandı, aynı hesap")
	check(not cloud().can_link(CloudSaveManager.PROVIDER_FACEBOOK), "artık bağlanacak yol yok")
	eco().set_money(6200)
	await seconds(2.2)
	check(String(fb.docs[kate]["save_json"]).contains("6200"), "bağlamadan sonra kayıt buluta yazılmaya devam ediyor")
	cloud().sign_out()
	await frames(8)
	cloud().sign_in_facebook()
	await frames(10)
	check(cloud().get_uid() == kate and eco().money == 6200, "Facebook'la Kate'in hesabına girildi (6200)")
	cloud().sign_out()
	await frames(8)

	print("Elle bağlama: Facebook hesabı başka oyun hesabına bağlı → bağlanmaz")
	fb.account = "liam"
	cloud().sign_in()
	await frames(10)
	notices.clear()
	cloud().link_provider(CloudSaveManager.PROVIDER_FACEBOOK)   # katefb Kate'e bağlı
	await frames(6)
	check(Array(cloud().get_providers()) == ["google.com"] and notices.size() == 1 and notices[0].contains("başka bir oyun hesabına bağlı"),
		"başka hesaba bağlı denildi: %s" % ", ".join(notices))
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and not cloud().is_linking(), "oturum ve senkron etkilenmedi")
	cloud().sign_out()
	await frames(8)

	print("Facebook ile açılan hesap: giriş, ilerleme buluta, hesap Facebook'la silinir")
	fb.fb_account = "fiona"
	eco().set_money(4321)
	own().add_vehicle(&"hyundai_getz")
	(w["save"] as SaveManager).save_game()
	cloud().sign_in_facebook()
	await frames(10)
	var fiona: String = cloud().get_uid()
	check(fiona.begins_with("f_") and cloud().get_state() == CloudSaveManager.State.SYNCED, "Facebook hesabı SYNCED")
	check(cloud().get_provider() == CloudSaveManager.PROVIDER_FACEBOOK and cloud().get_profile().get("provider") == "facebook.com",
		"sağlayıcı facebook.com")
	check(fb.docs.has(fiona) and String(fb.docs[fiona]["save_json"]).contains("4321"), "misafir ilerlemesi Facebook hesabına yazıldı")
	fb.fresh = false
	google_before = fb.google_calls
	var facebook_before: int = fb.facebook_calls
	deleted_results.clear()
	cloud().delete_account()
	await frames(14)
	check(fb.facebook_calls == facebook_before + 1 and fb.google_calls == google_before,
		"silmeden önce giriş FACEBOOK ile tazelendi (Google açılmadı)")
	check(deleted_results == [true] and not fb.docs.has(fiona) and fb.user.is_empty(), "Facebook hesabı ve bulut kaydı silindi")

	print("İki yolu bağlı hesap Google'la girilmişse silmede Google'la doğrulanır")
	fb.account = "kate"
	cloud().sign_in()
	await frames(10)
	fb.fresh = false
	google_before = fb.google_calls
	facebook_before = fb.facebook_calls
	deleted_results.clear()
	cloud().delete_account()
	await frames(14)
	check(fb.google_calls == google_before + 1 and fb.facebook_calls == facebook_before, "bu cihazdaki giriş yolu (Google) ile tazelendi")
	check(deleted_results == [true] and not fb.linked.has("fb:katefb") and not fb.linked.has("kate"), "hesap ve iki giriş yolu silindi")
	await close_app()

	check(fb.rule_denials == 0, "hiçbir yazma Firestore kuralına takılmadı (profilde yalnız izinli alanlar)")
	print("RESULT fails=%d" % fails)
	fb.free()
	quit(1 if fails > 0 else 0)
