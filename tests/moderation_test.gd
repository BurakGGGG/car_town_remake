extends SceneTree
## MODERASYON (ModerationWatch + BanNotice) — sahte Firebase ile, izole user:// klasöründe.
##   tools/run_tests.sh moderation_test
## 1) Yasak belgesinin yorumlanması (tür, süre, kalıcı, sebep / bitiş metni).
## 2) SOSYAL yasak: sosyal yazma sunucuya gitmez, oyuncuya bir kez yasak metni söylenir; kayıt buluta yazılmaya devam eder.
## 3) Ad / fotoğraf sıfırlama karar başına bir kez uygulanır. 4) Yasak bitince açık garaj yeniden yayınlanır.
## 5) TAM yasak: pencere istenir, TAMAM'da oturum kapanır (kayıt yazılamasa da), cihazdaki ilerleme yedeklenir.
## 6) HUD penceresi (Main.tscn): sebep, açıklama, bitiş, TAMAM + İTİRAZ ET.

class FakeFB extends Object:
	signal auth_success(d: Dictionary)
	signal auth_failure(m: String)
	signal sign_out_success(b: bool)
	signal user_deleted(b: bool)
	signal firestore_get_task_completed(r: Dictionary)
	signal firestore_write_task_completed(r: Dictionary)
	signal firestore_delete_task_completed(r: Dictionary)

	var tree: SceneTree
	var user: Dictionary = {}
	var account: String = "alice"
	var store: Dictionary = {}          # "yol/kimlik" → belge
	var online: bool = true
	var calls: Array[String] = []

	func isSignedIn() -> bool:
		return not user.is_empty()

	func getCurrentUser() -> Dictionary:
		return user.duplicate() if not user.is_empty() else {"error": "No user signed in"}

	func signInWithGoogle() -> void:
		user = {"uid": account, "isAnonymous": false, "name": account.capitalize(), "email": account + "@gmail.com", "photoUrl": null}
		_later("auth_success", user.duplicate())

	func signOut() -> void:
		user = {}
		_later("sign_out_success", true)

	func uid() -> String:
		return SaveSafe.s(user.get("uid", ""))

	func firestoreGetDocument(col: String, id: String) -> void:
		calls.append("get %s/%s" % [col, id])
		var path: String = col + "/" + id
		var r: Dictionary
		if not online:
			r = {"status": false, "docID": id, "error": "offline"}
		elif not _mine(col, id):
			r = {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."}
		elif store.has(path):
			r = {"status": true, "docID": id, "data": (store[path] as Dictionary).duplicate(true)}
		else:
			r = {"status": false, "docID": id, "error": "Document does not exist"}
		_later("firestore_get_task_completed", r)

	func firestoreGetDocumentsInCollection(col: String) -> void:
		calls.append("list %s" % col)
		if not online:
			_later("firestore_get_task_completed", {"status": false, "error": "offline"})
			return
		var p: PackedStringArray = col.split("/")
		if not (p.size() == 3 and p[0] == "users" and p[1] == uid()):
			_later("firestore_get_task_completed", {"status": false, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		var data: Dictionary = {}
		for path: String in store:
			if path.get_base_dir() == col:
				data[path.get_file()] = (store[path] as Dictionary).duplicate(true)
		_later("firestore_get_task_completed", {"status": true, "data": data})

	## firestore.rules (sadeleştirilmiş): oyuncu kendi kaydını ve garajını yazar; MODERASYONU istemci yazamaz; etkin
	## yasakta sosyal yazma (tamda kayıt da) reddedilir (socialAllowed / saveAllowed).
	func firestoreSetDocument(col: String, id: String, data: Dictionary, _merge: bool) -> void:
		calls.append("set %s/%s" % [col, id])
		if not online:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		var me: String = uid()
		var ban: Dictionary = ModerationWatch.active_ban(store.get("moderation/m_" + me, {}).get("ban", {}), int(Time.get_unix_time_from_system()))
		var social_ok: bool = ban.is_empty()
		var save_ok: bool = ban.is_empty() or ban["kind"] != "full"
		var ok: bool = (col == "players" and id == me and save_ok) or (col == "garages" and id == "g_" + me and social_ok) \
			or (col == "codes" and SaveSafe.s(data.get("uid", "")) == me and not store.has(col + "/" + id) and social_ok)
		if not ok:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store[col + "/" + id] = data.duplicate(true)
		_later("firestore_write_task_completed", {"status": true, "docID": id})

	func firestoreDeleteDocument(col: String, id: String) -> void:
		calls.append("delete %s/%s" % [col, id])
		if not online:
			_later("firestore_delete_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		if not _mine(col, id):
			_later("firestore_delete_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store.erase(col + "/" + id)
		_later("firestore_delete_task_completed", {"status": true, "docID": id})

	func _mine(col: String, id: String) -> bool:
		var me: String = uid()
		var p: PackedStringArray = col.split("/")
		if me.is_empty():
			return false
		match p[0]:
			"players":
				return id == me
			"garages", "codes":
				return true
			"moderation":
				return id == "m_" + me
			"users":
				return p.size() == 3 and p[1] == me
		return false

	func _later(sig: String, value: Variant) -> void:
		await tree.create_timer(randf() * 0.05).timeout
		emit_signal(sig, value)



const SIGNALS: Array[StringName] = [
	&"auth_success", &"auth_failure", &"sign_out_success", &"user_deleted",
	&"firestore_get_task_completed", &"firestore_write_task_completed", &"firestore_delete_task_completed",
]

var fb: FakeFB = FakeFB.new()
var w: Dictionary = {}
var fails: int = 0
var notices: PackedStringArray = PackedStringArray()
var requested: Array[Dictionary] = []


func _initialize() -> void:
	if OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	fb.tree = self
	seed(4242)
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func seconds(t: float) -> void:
	await create_timer(t).timeout


func until(cond: Callable, limit: float = 5.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func _run() -> void:
	Loc.use("tr")
	_parse()
	await _session_flow()
	await _hud_notice()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _parse() -> void:
	print("== 1) Yasak belgesi ==")
	var now: int = 1_800_000_000
	check(ModerationWatch.active_ban({}, now).is_empty(), "belge yok: yasak yok")
	check(ModerationWatch.active_ban({"kind": "x"}, now).is_empty(), "bilinmeyen tür yok sayılır")
	check(ModerationWatch.active_ban({"kind": "social", "until": now - 1}, now).is_empty(), "süresi dolan yasak yok")
	var perm: Dictionary = ModerationWatch.active_ban({"kind": "full", "until": 0, "reason": "cheat", "at": 5}, now)
	check(perm.get("kind") == "full" and int(perm["until"]) == 0, "until 0 = kalıcı")
	check(ModerationWatch.until_text(perm) == Loc.t("Süresiz") and ModerationWatch.reason_text(perm) == "Hile", "kalıcı: Süresiz, sebep Hile")
	check(ModerationWatch.reason_text({"reason": "yok"}) == "Kural ihlali", "bilinmeyen sebep: Kural ihlali")
	var dated: String = ModerationWatch.until_text({"until": now + 86400})
	check(dated.contains(":") and dated.length() > 10, "süreli: tarih + saat (%s)" % dated)


func open_session(account: String, fresh_device: bool = true) -> void:
	if fresh_device:
		for f: String in ["savegame.json", "cloud_sync.json", "social.json", "moderation.json", "savegame.before_signout.json"]:
			DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	fb.account = account
	fb.user = {}
	fb.calls.clear()
	var root_node: Node = Node.new()
	var eco: EconomyManager = EconomyManager.new()
	var prog: PlayerProgress = PlayerProgress.new()
	var upg: GarageUpgradeManager = GarageUpgradeManager.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var profile: PlayerProfile = PlayerProfile.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	var watch: ModerationWatch = ModerationWatch.new()
	social.use_firebase(fb)
	social.publish_delay = 0.3
	social.request_timeout = 1.0
	for n: Node in [eco, prog, upg, own, profile, save, cloud, social, watch]:
		root_node.add_child(n)
	root.add_child(root_node)
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	social.notice.connect(func(t: String) -> void: notices.append(t))
	watch.notice_requested.connect(func(b: Dictionary) -> void: requested.append(b))
	w = {"root": root_node, "eco": eco, "profile": profile, "save": save, "cloud": cloud, "social": social, "watch": watch}
	await frames(6)
	cloud.sign_in()
	await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED)
	await until(func() -> bool: return social.get_state() not in [SocialManager.State.SIGNED_OUT, SocialManager.State.LOADING])
	await until(func() -> bool: return not social.is_busy())


func close_session() -> void:
	await until(func() -> bool: return not (w["social"] as SocialManager).is_busy() and not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].queue_free()
	w = {}
	await frames(2)


func social() -> SocialManager:
	return w["social"]


func watch() -> ModerationWatch:
	return w["watch"]


func _session_flow() -> void:
	var now: int = int(Time.get_unix_time_from_system())
	print("== 2) Sosyal yasak ==")
	await open_session("alice")
	check(await social().create_profile("Alice Usta") and fb.store.has("garages/g_alice"), "profil + açık garaj (yasak yok)")
	fb.store.erase("garages/g_alice")   # panel yasakta açık garajı siler
	fb.store["moderation/m_alice"] = {"ban": {"kind": "social", "reason": "name", "text": "Küfürlü ad", "until": now + 3600, "at": now}}
	notices.clear()
	requested.clear()
	await watch().check()
	check(watch().ban().get("kind") == "social" and not social().restricted_text.is_empty(), "sosyal yasak etkin")
	check(requested.size() == 1 and requested[0]["text"] == "Küfürlü ad", "yasak penceresi istendi (açıklamayla)")
	await watch().check()
	check(requested.size() == 1, "aynı yasak için pencere ikinci kez istenmez")
	fb.calls.clear()
	await social().rename("Alice Yeni")
	check(not fb.calls.any(func(c: String) -> bool: return c.begins_with("set garages")), "sosyal yazma sunucuya gitmedi")
	check(notices.size() == 1 and notices[0].contains("kısıtlandı"), "oyuncuya yasak metni söylendi (bir kez)")
	await social().rename("Alice Baska")
	check(notices.size() == 1, "metin tekrar tekrar söylenmez")
	(w["eco"] as EconomyManager).add_money(321)
	await until(func() -> bool: return CloudPack.unpack(SaveSafe.s(fb.store.get("players/alice", {}).get("save_json", ""))).contains("5321"))
	check(CloudPack.unpack(SaveSafe.s(fb.store.get("players/alice", {}).get("save_json", ""))).contains("5321"), "kayıt buluta yazılmaya devam ediyor")

	print("== 3) Ad / fotoğraf sıfırlama ==")
	var profile: PlayerProfile = w["profile"]
	profile.set_preset("p02")
	var had_avatar: bool = not profile.avatar.is_empty()
	notices.clear()
	var doc: Dictionary = (fb.store["moderation/m_alice"] as Dictionary).duplicate(true)
	doc.merge({"name": "Usta4821", "name_reset": now, "photo_reset": now}, true)
	fb.store["moderation/m_alice"] = doc
	await watch().check()
	check(social().my_name() == "Usta4821", "ad panelin verdiği ada döndü")
	check(not had_avatar or profile.avatar.is_empty(), "profil fotoğrafı / avatar kaldırıldı")
	check(notices.size() >= 2, "oyuncuya ad ve fotoğraf için haber verildi")
	notices.clear()
	await watch().check()
	check(Array(notices).all(func(t: String) -> bool: return t.contains("kısıtlandı")), "aynı karar ikinci kez uygulanmaz")

	print("== 4) Yasak kalktı ==")
	doc.erase("ban")
	fb.store["moderation/m_alice"] = doc
	await watch().check()
	check(watch().ban().is_empty() and social().restricted_text.is_empty(), "yasak bitti")
	await until(func() -> bool: return fb.store.has("garages/g_alice"), 4.0)
	check(SaveSafe.s(fb.store.get("garages/g_alice", {}).get("name", "")) == "Usta4821", "açık garaj yeni adla yeniden yayınlandı")
	await close_session()

	print("== 5) Tam yasak ==")
	fb.store["moderation/m_bob"] = {"ban": {"kind": "full", "reason": "cheat", "until": 0, "at": now}}
	requested.clear()
	await open_session("bob")
	await until(func() -> bool: return not requested.is_empty(), 3.0)
	check(watch().is_full_ban() and requested.size() == 1 and requested[0]["kind"] == "full", "tam yasak penceresi istendi")
	(w["eco"] as EconomyManager).add_money(999)
	(w["save"] as SaveManager).save_game()
	await seconds(2.0)
	check(not CloudPack.unpack(SaveSafe.s(fb.store.get("players/bob", {}).get("save_json", ""))).contains("5999"), "kayıt buluta yazılamadı (kural)")
	watch().acknowledge(requested[0])
	await until(func() -> bool: return not (w["cloud"] as CloudSaveManager).is_authenticated(), 4.0)
	check(not (w["cloud"] as CloudSaveManager).is_authenticated(), "TAMAM: oturum kapandı (yazılamayan kayıt beklenmedi)")
	check(FileAccess.file_exists("user://savegame.before_signout.json"), "cihazdaki ilerleme yedeklendi")
	check(watch().ban().is_empty(), "misafirde yasak yok")
	await close_session()
	fb.store.erase("moderation/m_bob")


func _hud_notice() -> void:
	print("== 6) HUD penceresi ==")
	for f: String in ["savegame.json", "cloud_sync.json", "social.json", "moderation.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false) as Hud
	var mod: ModerationWatch = get_first_node_in_group("moderation") as ModerationWatch
	var notice: BanNotice = hud.find_child("BanNotice", true, false) as BanNotice
	check(mod != null and notice != null, "ModerationWatch + yasak penceresi kurulu")
	if mod == null or notice == null:
		return
	var now: int = int(Time.get_unix_time_from_system())
	mod.apply_doc("qa_uid", {"ban": {"kind": "social", "reason": "photo", "text": "Uygunsuz görsel", "until": now + 7 * 86400, "at": now}})
	await until(func() -> bool: return not notice.shown().is_empty(), 5.0)
	check(notice.visible and notice.shown().get("kind") == "social", "oyun sakinken pencere açıldı")
	var texts: String = " ".join(notice.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(texts.contains(Loc.t("SOSYAL ÖZELLİKLER KISITLANDI")) and texts.contains("Uygunsuz profil fotoğrafı")
		and texts.contains("Uygunsuz görsel") and texts.contains(Loc.t("Bitiş: %s").split(":")[0]), "başlık, sebep, açıklama, bitiş")
	check(notice.find_child("AppealButton", true, false) != null, "İTİRAZ ET düğmesi")
	(notice.find_child("OkButton", true, false) as PlateButton).pressed.emit()
	await seconds(0.4)
	check(not notice.visible, "TAMAM: kapandı")
	main.queue_free()
	await frames(4)
