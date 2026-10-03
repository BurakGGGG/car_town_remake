extends SceneTree
## Giriş / çıkış sonrası GERÇEK Main.tscn'nin yeniden yüklendiğini doğrular (sahte Firebase, izole user://).
## Çalıştırma: tools/run_tests.sh login_reload_test
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


var fails: int = 0
var fb: FakeFB = FakeFB.new()


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


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func scene_ready() -> void:
	# yeniden yükleme + Main.tscn _ready + SaveManager._setup + açılış senkronu
	await frames(20)


func eco() -> EconomyManager:
	return get_first_node_in_group("economy") as EconomyManager


func cloud() -> CloudSaveManager:
	return get_first_node_in_group("cloud_save") as CloudSaveManager


func _run() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "savegame.before_cloud.json", "cloud_backup.json", "savegame.before_signout.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	Engine.register_singleton("GodotFirebaseAndroid", fb)
	change_scene_to_file("res://Main.tscn")
	await scene_ready()
	var first_scene: Node = current_scene
	check(first_scene != null and cloud() != null and cloud().is_available(), "Main.tscn açıldı, CloudSaveManager sahte Firebase'e bağlı")
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and fb.user.is_empty(), "misafir, oturumsuz")

	print("Giriş: Dana ilerler, buluta yazılır")
	eco().set_money(54321)
	(get_first_node_in_group("save_manager") as SaveManager).save_game()
	fb.account = "dana"
	cloud().sign_in()
	await frames(12)
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and fb.docs.size() == 1, "Dana SYNCED, kaydı bulutta")
	check(current_scene == first_scene, "ilk girişte (çakışma yok, local→bulut) sahne yenilenmedi")

	print("Çıkış: sahne yenilenir, yeni misafir oyunu")
	cloud().sign_out()
	await scene_ready()
	check(current_scene != first_scene and is_instance_valid(current_scene), "sahne yeniden yüklendi")
	var second_scene: Node = current_scene
	check(eco().money == 5000, "dünya yeni misafir oyununda (5000)")
	check(cloud().get_state() == CloudSaveManager.State.SIGNED_OUT and not cloud().is_authenticated(), "yeni sahnede SIGNED_OUT")
	var screen: LoginScreen = get_first_node_in_group("login_screen") as LoginScreen
	check(screen != null and screen.visible and screen._notice.text.contains("Çıkış yapıldı"), "PLAYER ekranı çıkış mesajını gösterdi")
	check(cloud().take_pending_notice() == "", "mesaj bir kez gösterilir")
	var hud_name: String = ""
	for n: Node in get_nodes_in_group("hud"):
		hud_name = str(n.get("player_name"))
	print("  (hud player_name=%s)" % hud_name)

	print("Giriş: Dana'nın hesabı yüklenir, sahne yenilenir")
	fb.account = "dana"
	cloud().sign_in()
	await scene_ready()
	check(current_scene != second_scene and is_instance_valid(current_scene), "sahne yeniden yüklendi")
	check(eco().money == 54321, "dünya Dana'nın oyunuyla kuruldu (54321)")
	check(cloud().get_state() == CloudSaveManager.State.SYNCED and cloud().is_authenticated(), "yeni sahnede SYNCED, oturum sürüyor")
	screen = get_first_node_in_group("login_screen") as LoginScreen
	check(screen != null and screen._notice.text.contains("yüklendi"), "PLAYER ekranı 'hesabın yüklendi' dedi")
	var scene_count: int = current_scene.get_child_count()
	await frames(30)
	check(current_scene.get_child_count() == scene_count and cloud().get_state() == CloudSaveManager.State.SYNCED, "yenileme döngüsü yok, sahne kararlı")

	print("RESULT fails=%d" % fails)
	Engine.unregister_singleton("GodotFirebaseAndroid")
	quit(1 if fails > 0 else 0)
