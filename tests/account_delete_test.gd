extends SceneTree
## Hesap silme testi (Play şartı) — sahte Firebase ile, PC'de, izole user:// klasöründe.
## Çalıştırma: tools/run_tests.sh account_delete_test
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


func _run() -> void:
	wipe_files()
	await make_world()

	print("Misafirken hesap silme yok")
	check(not cloud().can_delete_account(), "misafir: can_delete_account false")
	cloud().delete_account()
	await frames(4)
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and deleted_results.is_empty(), "misafirde delete_account hiçbir şey yapmaz")

	var alice: String = await play_and_sign_in(15000)
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and fb.docs.has(alice), "Alice SYNCED, bulut kaydı var")
	check(cloud().can_delete_account(), "Google oturumu: can_delete_account true")

	print("Hesap seçiciden vazgeçme → hiçbir şey silinmez, sessizce geri dönülür")
	fb.cancel_next = true
	notices.clear()
	cloud().delete_account()
	check(cloud().get_state() == CloudSaveManager.State.DELETING, "DELETING durumuna geçti")
	await frames(8)
	check(deleted_results == [false], "account_deleted(false)")
	check(notices.is_empty(), "vazgeçmede hata mesajı yok")
	check(fb.docs.has(alice) and fb.linked.has("alice") and eco().money == 15000, "bulut, hesap ve local duruyor")
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and cloud().get_uid() == alice, "yeniden SYNCED, Alice oturumu")

	print("Yeniden girişte başka Google hesabı seçilirse silme iptal")
	deleted_results.clear()
	notices.clear()
	fb.account = "bob"
	cloud().delete_account()
	await frames(10)
	check(deleted_results == [false] and notices.size() == 1 and notices[0].contains("Google hesabını seçmelisin"), "iptal + açıklama: %s" % ", ".join(notices))
	check(fb.docs.has(alice) and fb.linked.has("alice"), "Alice'in kaydı ve hesabı silinmedi")
	check(fb.deletes == 0, "Firestore'da hiçbir doküman silinmedi")
	check(cloud().get_uid() != alice and cloud().is_authenticated(), "oturum artık Bob'un (normal hesap değişimi)")
	cloud().sign_out()
	await frames(6)
	fb.account = "alice"
	cloud().sign_in()
	await frames(8)
	check(cloud().get_uid() == alice and eco().money == 15000, "Alice'e dönüldü, 15000 geri geldi")
	fb.fresh = false

	print("İnternet yok → bulut kaydı silinemez, hiçbir şey silinmez")
	deleted_results.clear()
	notices.clear()
	fb.online = false
	cloud().delete_account()
	await frames(10)
	check(deleted_results == [false] and notices.size() >= 1 and notices[0].contains("İnternet"), "iptal + internet mesajı")
	check(fb.docs.has(alice) and fb.linked.has("alice") and eco().money == 15000, "bulut, hesap ve local duruyor")
	check(FileAccess.file_exists("user://savegame.json"), "local kayıt dosyası duruyor")
	check(cloud().get_state() == CloudSaveManager.State.OFFLINE, "OFFLINE (normal akış)")
	fb.online = true
	cloud()._on_retry_timeout()
	await frames(8)
	check(cloud().get_state() == CloudSaveManager.State.SYNCED, "internet gelince SYNCED")
	fb.fresh = false

	print("Bulut yazması sürerken silme → yazma bulutu geri getirmez")
	deleted_results.clear()
	notices.clear()
	FileAccess.open("user://cloud_backup.json", FileAccess.WRITE).store_string("{}")
	FileAccess.open("user://savegame.before_cloud.json", FileAccess.WRITE).store_string("{}")
	eco().add_money(250)
	cloud().upload_save()   # Op.SET yolda
	check(cloud().can_delete_account(), "yazma sürerken de silme başlatılabilir")
	cloud().delete_account()
	await frames(12)

	print("Başarılı silme")
	check(deleted_results == [true], "account_deleted(true)")
	check(notices.is_empty(), "hata mesajı yok")
	check(not fb.docs.has(alice), "Firestore players/{uid} silindi")
	check(not fb.linked.has("alice"), "Firebase Auth kullanıcısı silindi (son giriş tazelendiği için)")
	check(not cloud().is_authenticated() and cloud().get_profile().is_empty(), "Google oturumu yok")
	check(fb.user.is_empty() and fb.anon_counter == 0, "Firebase oturumu yok (misafir oturumsuz), anonim hesap açılmadı")
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT, "SIGNED_OUT")
	check(eco().money == 5000 and (w["own"] as VehicleOwnership).owned_vehicle_ids() == [&"tofas_sahin"], "cihazdaki ilerleme sıfırlandı (5000, yalnızca Şahin)")
	var local: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://savegame.json"))
	check(local is Dictionary and int(local["economy"]["money"]) == 5000, "local kayıt dosyası da yeni oyun")
	check(not FileAccess.file_exists("user://cloud_backup.json") and not FileAccess.file_exists("user://savegame.before_cloud.json"), "yedek dosyaları silindi")
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://cloud_sync.json"))
	check(meta is Dictionary and not (meta as Dictionary).has("uid") and not (meta as Dictionary).has("synced_json"), "cloud_sync.json'da eski hesap izi yok")
	check(not cloud().should_prompt_login(), "giriş ekranı yeniden dayatılmaz")
	var writes_after: int = fb.writes
	eco().add_money(10)
	await seconds(2.2)
	check(fb.writes == writes_after and not fb.docs.has(alice), "sonraki oyun buluta yazılmaz, silinen kayıt geri gelmez")
	await close_app()

	print("Uygulama yeniden açılır → misafir, yeni oyun")
	await make_world()
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and eco().money == 5010, "misafir, local 5010 (silme sonrası oyun)")
	print("Aynı Google hesabıyla yeniden giriş → sıfırdan hesap")
	cloud().sign_in()
	await frames(8)
	var alice2: String = cloud().get_uid()
	check(alice2 != "" and alice2 != alice, "yeni UID (%s)" % alice2)
	check(fb.docs.has(alice2) and eco().money == 5010, "yeni hesaba bu cihazdaki yeni oyun yüklendi")
	fb.fresh = false

	print("Auth kullanıcısı silinemezse: veriler yine silinir, oturum kapanır, web sitesi gösterilir")
	deleted_results.clear()
	notices.clear()
	fb.fail_delete_user = true
	cloud().delete_account()
	await frames(12)
	check(deleted_results == [false], "account_deleted(false)")
	check(notices.size() == 1 and notices[0].contains(CloudSaveManager.DELETE_ACCOUNT_URL), "mesajda web sitesi adresi: %s" % ", ".join(notices))
	check(not fb.docs.has(alice2), "bulut kaydı silindi")
	check(eco().money == 5000, "cihazdaki ilerleme sıfırlandı")
	check(not FileAccess.file_exists("user://savegame.before_signout.json"), "çıkış yedeği bırakılmadı (veriler zaten silindi)")
	check(not cloud().is_authenticated() and cloud().get_state() == CloudSaveManager.State.SIGNED_OUT, "oturum kapatıldı, misafir")
	var writes_f: int = fb.writes
	eco().add_money(1)
	await seconds(2.2)
	check(fb.writes == writes_f and not fb.docs.has(alice2), "bulut kaydı yeniden oluşmadı")
	fb.fail_delete_user = false
	await close_app()

	await test_login_screen()

	print("RESULT fails=%d" % fails)
	fb.free()
	quit(1 if fails > 0 else 0)


## PLAYER ekranı: silme düğmesi yalnızca Google oturumunda görünür, iki adımlıdır.
func test_login_screen() -> void:
	print("PLAYER ekranı: HESABIMI SİL iki adımlı")
	wipe_files()
	fb.user = {}
	fb.account = "carol"
	await make_world()
	var screen: LoginScreen = LoginScreen.new()
	root.add_child(screen)
	await frames(4)
	screen.open()
	check(not screen._delete.visible, "misafirde silme düğmesi gizli")
	await play_and_sign_in(9000)
	var carol: String = cloud().get_uid()
	screen._refresh()
	check(screen._delete.visible, "Google oturumunda silme düğmesi görünür")
	screen._on_delete_pressed()
	check(screen._title.text == "HESABI SİL" and screen._body.text.contains("GERİ ALINAMAZ"), "ilk basış yalnızca onay görünümü")
	check(screen._primary.text == "EVET, KALICI OLARAK SİL" and screen._secondary.text == "VAZGEÇ" and not screen._delete.visible, "onay butonları")
	check(fb.docs.has(carol) and cloud().get_state() == CloudSaveManager.State.SYNCED, "onaydan önce hiçbir şey başlamadı")
	screen._on_secondary_pressed()
	check(screen.visible and screen._title.text == "PLAYER" and screen._primary.text == "ÇIKIŞ YAP", "VAZGEÇ → hesap görünümüne dönüldü, ekran açık")
	screen._on_delete_pressed()
	deleted_results.clear()
	screen._on_primary_pressed()
	check(cloud().get_state() == CloudSaveManager.State.DELETING and screen._primary.disabled and screen._primary.text == "SİLİNİYOR", "EVET → silme başladı, buton kilitli")
	await frames(12)
	check(deleted_results == [true] and not fb.docs.has(carol), "silindi")
	check(screen._notice.visible and screen._notice.text.contains("silindi") and not screen._delete.visible, "ekranda başarı mesajı, silme düğmesi gizli")
	check(screen._primary.text == "GOOGLE İLE GİRİŞ", "misafir görünümüne dönüldü")
	screen.free()
	await close_app()
