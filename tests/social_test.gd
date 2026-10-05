extends SceneTree
## ARKADAŞLIK testi — sahte Firebase ile, PC'de, izole user:// klasöründe.
## Çalıştırma: tools/run_tests.sh social_test
##
## Sahte Firebase belgeleri yol ("koleksiyon/kimlik") ile tutar ve firestore.rules'un sosyal kısmını
## sadeleştirilmiş olarak uygular (asıl kurallar emülatörde: firebase/rules_test). Yanıtlar RASTGELE
## gecikmeyle ve sırasız gelir: bulut kaydı (players/{uid}) ile SocialManager'ın istekleri aynı
## sinyalleri paylaştığı için birbirinin yanıtını almadıkları da böyle sınanır.
## Oyuncular (alice / bob / carol) aynı "sunucuyu" sırayla, ayrı oturumlarla kullanır.

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
	var hang: bool = false              # yanıt hiç gelmez (zaman aşımı)
	var deny_codes: int = 0             # sonraki N kod alma "alınmış" diye reddedilir
	var calls: Array[String] = []
	var max_delay: float = 0.06

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

	func deleteUser() -> void:
		user = {}
		_later("user_deleted", true)

	func uid() -> String:
		return SaveSafe.s(user.get("uid", ""))

	# --- Firestore ---

	func firestoreGetDocument(col: String, id: String) -> void:
		calls.append("get %s/%s" % [col, id])
		var path: String = col + "/" + id
		var r: Dictionary
		if not online:
			r = {"status": false, "docID": id, "error": "Failed to get document because the client is offline."}
		elif not _can_read(col, id):
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
		if not _can_list(col):
			_later("firestore_get_task_completed", {"status": false, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		var data: Dictionary = {}
		for path: String in store:
			if path.get_base_dir() == col:
				data[path.get_file()] = (store[path] as Dictionary).duplicate(true)
		_later("firestore_get_task_completed", {"status": true, "data": data})

	func firestoreSetDocument(col: String, id: String, data: Dictionary, _merge: bool) -> void:
		calls.append("set %s/%s" % [col, id])
		if not online:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		if not _can_write(col, id, data):
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store[col + "/" + id] = data.duplicate(true)
		_later("firestore_write_task_completed", {"status": true, "docID": id})

	func firestoreDeleteDocument(col: String, id: String) -> void:
		calls.append("delete %s/%s" % [col, id])
		if not online:
			_later("firestore_delete_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		if not _can_delete(col, id):
			_later("firestore_delete_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store.erase(col + "/" + id)
		_later("firestore_delete_task_completed", {"status": true, "docID": id})

	# --- firestore.rules (sadeleştirilmiş) ---

	func _parts(col: String) -> PackedStringArray:
		return col.split("/")

	func _can_read(col: String, id: String) -> bool:
		var me: String = uid()
		if me.is_empty():
			return false
		var p: PackedStringArray = _parts(col)
		match p[0]:
			"players":
				return id == me
			"garages", "codes":
				return true
			"users":
				if p[2] == "inbox":
					return p[1] == me or id == "r_" + me
				return p[1] == me
		return false

	func _can_list(col: String) -> bool:
		var p: PackedStringArray = _parts(col)
		return p.size() == 3 and p[0] == "users" and p[1] == uid()

	func _can_write(col: String, id: String, data: Dictionary) -> bool:
		var me: String = uid()
		if me.is_empty():
			return false
		var p: PackedStringArray = _parts(col)
		match p[0]:
			"players":
				return id == me
			"garages":
				return id == "g_" + me and SocialNames.is_valid_name(SaveSafe.s(data.get("name", ""))) \
					and not data.has("money")
			"codes":
				if deny_codes > 0:
					deny_codes -= 1
					return false
				return not store.has(col + "/" + id) and SaveSafe.s(data.get("uid", "")) == me \
					and SocialNames.is_valid_code(id)
			"users":
				var owner: String = p[1]
				match p[2]:
					"inbox":
						return id == "r_" + me and owner != me
					"outbox":
						return owner == me and id != "o_" + me
					"friends":
						var other: String = id.trim_prefix("f_")
						return (me == owner and store.has("users/%s/inbox/r_%s" % [owner, other])) \
							or (other == me and store.has("users/%s/inbox/r_%s" % [me, owner]))
		return false

	func _can_delete(col: String, id: String) -> bool:
		var me: String = uid()
		if me.is_empty():
			return false
		var p: PackedStringArray = _parts(col)
		match p[0]:
			"players":
				return id == me
			"garages":
				return id == "g_" + me
			"codes":
				return not store.has(col + "/" + id) or SaveSafe.s(store[col + "/" + id].get("uid", "")) == me
			"users":
				match p[2]:
					"inbox":
						return p[1] == me or id == "r_" + me
					"outbox":
						return p[1] == me or id == "o_" + me
					"friends":
						return p[1] == me or id == "f_" + me
		return false

	## Yanıt rastgele gecikmeyle gelir (sırasız): gerçek eklentide de ağ sırası garanti değil.
	func _later(sig: String, value: Variant) -> void:
		if hang and sig.begins_with("firestore"):
			return
		_emit_after(sig, value, randf() * max_delay)

	func _emit_after(sig: String, value: Variant, delay: float) -> void:
		await tree.create_timer(delay).timeout
		emit_signal(sig, value)


const SIGNALS: Array[StringName] = [
	&"auth_success", &"auth_failure", &"sign_out_success", &"user_deleted",
	&"firestore_get_task_completed", &"firestore_write_task_completed", &"firestore_delete_task_completed",
]

var fb: FakeFB = FakeFB.new()
var w: Dictionary = {}
var fails: int = 0
var notices: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	print("USERDIR=", OS.get_user_data_dir())
	if OS.get_user_data_dir().ends_with("/CarTownRemake") or OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	fb.tree = self
	seed(int(OS.get_environment("SOCIAL_SEED")) if OS.has_environment("SOCIAL_SEED") else 4242)
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


## Koşul doğru olana kadar (en çok `limit` sn) bekler.
func until(cond: Callable, limit: float = 5.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(limit * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return cond.call()


func wipe_files() -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))


## Bir cihazda oturum: dünya kurulur, `account` Google ile girer, bulut SYNCED olur.
func open_session(account: String, fresh_device: bool = true) -> void:
	if fresh_device:
		wipe_files()
	fb.account = account
	fb.user = {}
	var root_node: Node = Node.new()
	var eco: EconomyManager = EconomyManager.new()
	var prog: PlayerProgress = PlayerProgress.new()
	var upg: GarageUpgradeManager = GarageUpgradeManager.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	social.use_firebase(fb)
	social.publish_delay = 0.3
	social.request_timeout = 1.0
	for n: Node in [eco, prog, upg, own, save, cloud, social]:
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
	social.notice.connect(func(t: String) -> void: notices.append(t))
	w = {"root": root_node, "eco": eco, "own": own, "save": save, "cloud": cloud, "social": social}
	await frames(6)
	cloud.sign_in()
	await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED)
	await until(func() -> bool: return social.get_state() not in [SocialManager.State.SIGNED_OUT, SocialManager.State.LOADING])
	await until(func() -> bool: return not social.is_busy())   # açılıştaki liste yüklemesi


func close_session() -> void:
	await until(func() -> bool: return not social().is_busy() and not cloud().is_busy(), 3.0)
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].queue_free()
	w = {}
	await frames(2)


func social() -> SocialManager:
	return w["social"]


func cloud() -> CloudSaveManager:
	return w["cloud"]


func last_notice() -> String:
	return notices[notices.size() - 1] if not notices.is_empty() else ""


func garage_doc(uid: String) -> Dictionary:
	return fb.store.get("garages/g_" + uid, {})


func _run() -> void:
	print("== 0) Adlar ve kodlar ==")
	check(SocialNames.is_valid_name("Usta Ali"), "'Usta Ali' geçerli")
	check(SocialNames.is_valid_name("Şahin Çağrı"), "Türkçe harfler geçerli")
	check(not SocialNames.is_valid_name("Al"), "2 harf geçersiz")
	check(not SocialNames.is_valid_name("O.r.o.s.p.u"), "noktayla ayrılmış küfür yakalanır")
	check(not SocialNames.is_valid_name("amk usta"), "kısa küfür kelime olarak yakalanır")
	check(SocialNames.is_valid_name("Basikal"), "masum kelime içindeki kısa kök engellenmez")
	check(not SocialNames.is_valid_name("<b>x</b>"), "işaretler geçersiz")
	check(SocialNames.normalize_code(" ay-7k2q4m ") == "7K2Q4M", "kod normalleşir (AY-, küçük harf, boşluk)")
	check(SocialNames.is_valid_code(SocialNames.random_code()), "rastgele kod geçerli")
	check(not SocialNames.is_valid_code("7K2Q40"), "0 içeren kod geçersiz")

	print("== 1) Açık garaj: yalnızca görsel veri ==")
	var snap: Dictionary = {"version": SaveManager.SAVE_VERSION, "economy": {"money": 999}, "progress": {"xp": 5, "level": 7, "gems": 50},
		"garage_upgrades": {"garage_level": 2}, "repair_bays": {"unlocked": 2, "layout": []}, "decor": {"items": {}},
		"vehicles": {"owned": ["hyundai_getz"], "paint": {}, "discovered": ["a"], "dups": {}}, "crates": {"x": 1}, "ads": {}}
	var pub: Dictionary = PublicGarage.from_snapshot(snap)
	check(not pub.has("economy") and not pub.has("crates") and not pub.has("ads"), "para / kasa / reklam yok")
	check(not (pub["progress"] as Dictionary).has("gems") and not (pub["progress"] as Dictionary).has("xp"), "gem / XP yok")
	check(not (pub["vehicles"] as Dictionary).has("discovered"), "koleksiyon yok")
	check(PublicGarage.level_of(pub) == 7, "seviye var")
	check(not PublicGarage.parse(PublicGarage.to_json(pub)).is_empty(), "JSON geri okunur")
	var future: Dictionary = pub.duplicate(true)
	future["version"] = SaveManager.SAVE_VERSION + 1
	check(PublicGarage.parse(PublicGarage.to_json(future)).is_empty(), "daha yeni sürüm reddedilir")

	print("== 2) Alice: profil ==")
	await open_session("alice")
	check(social().get_state() == SocialManager.State.NO_PROFILE, "girişten sonra profil yok")
	check(not await social().create_profile("Al"), "kısa ad reddedilir")
	check(not await social().create_profile("orospu"), "küfürlü ad reddedilir")
	check(not fb.store.has("garages/g_alice"), "  ...sunucuya hiçbir şey gitmedi")
	fb.deny_codes = 2
	check(await social().create_profile("  Usta   Ali "), "profil oluşturuldu (iki kod çakışmasından sonra)")
	check(social().is_ready(), "READY")
	check(social().my_name() == "Usta Ali", "ad temizlendi: '%s'" % social().my_name())
	var alice_code: String = social().my_code()
	check(SocialNames.is_valid_code(alice_code) and fb.store.get("codes/" + alice_code, {}).get("uid") == "alice", "kod sunucuda: %s" % alice_code)
	var gdoc: Dictionary = garage_doc("alice")
	check(gdoc.get("name") == "Usta Ali" and gdoc.get("code") == alice_code, "açık garaj yazıldı")
	check(not SaveSafe.s(gdoc.get("garage_json", "")).contains("money"), "açık garajda para yok")
	check(not fb.store.has("garages/alice") and not fb.store.has("codes/alice"), "çıplak UID kimlikli belge yok")

	print("== 3) Yayın: kayıttan sonra açık garaj güncellenir, bulut kaydıyla karışmaz ==")
	(w["own"] as VehicleOwnership).add_vehicle(&"hyundai_getz")
	(w["eco"] as EconomyManager).set_money(12345)
	(w["save"] as SaveManager).save_game()
	var published: bool = await until(func() -> bool:
		return SaveSafe.s(garage_doc("alice").get("garage_json", "")).contains("hyundai_getz"), 5.0)
	check(published, "yeni araç açık garajda")
	await until(func() -> bool: return not cloud().is_busy() and cloud().get_state() == CloudSaveManager.State.SYNCED, 5.0)
	var cloud_ok: bool = await until(func() -> bool:
		return SaveSafe.s(fb.store.get("players/alice", {}).get("save_json", "")).contains("12345"), 5.0)
	check(cloud_ok, "bulut kaydı da güncel (iki sistem aynı sinyalleri paylaşıyor)")
	check(cloud().get_state() == CloudSaveManager.State.SYNCED, "bulut SYNCED kaldı")
	var writes_before: int = fb.calls.filter(func(c: String) -> bool: return c.begins_with("set garages")).size()
	(w["save"] as SaveManager).save_game()
	await seconds(0.8)
	var writes_after: int = fb.calls.filter(func(c: String) -> bool: return c.begins_with("set garages")).size()
	check(writes_after == writes_before, "değişiklik yoksa yeniden yazılmaz")
	await close_session()

	print("== 4) Bob: istek gönderir ==")
	await open_session("bob")
	check(await social().create_profile("Bob Usta"), "bob profil")
	var bob_code: String = social().my_code()
	check(not await social().send_request(bob_code), "kendi koduna istek atılamaz")
	check(not await social().send_request("ZZZZZZ"), "bilinmeyen kod")
	check(last_notice().contains("bulunamadı"), "  ...mesaj: %s" % last_notice())
	check(not await social().send_request("12"), "biçimsiz kod")
	check(await social().send_request(" ay-" + alice_code.to_lower()), "alice'e istek gönderildi (küçük harf, AY- önekiyle)")
	check(fb.store.has("users/alice/inbox/r_bob") and fb.store.has("users/bob/outbox/o_alice"), "gelen + giden kayıtları")
	check(social().outgoing.size() == 1 and social().outgoing[0]["name"] == "Usta Ali", "bob'un bekleyen listesinde alice")
	check(not await social().send_request(alice_code), "aynı kişiye ikinci istek atılmaz")
	await close_session()

	print("== 5) Alice: kabul eder ==")
	await open_session("alice")
	check(social().is_ready() and social().my_code() == alice_code, "yeni cihazda profil sunucudan geri geldi")
	await social().refresh(true)
	check(social().incoming.size() == 1 and social().incoming[0]["uid"] == "bob", "gelen istek: bob")
	check(await social().accept("bob"), "kabul")
	check(fb.store.has("users/alice/friends/f_bob") and fb.store.has("users/bob/friends/f_alice"), "iki taraflı arkadaşlık")
	check(not fb.store.has("users/alice/inbox/r_bob") and not fb.store.has("users/bob/outbox/o_alice"), "istek kayıtları silindi")
	check(social().friends.size() == 1 and social().friends[0]["name"] == "Bob Usta", "listede bob")
	check(social().incoming.is_empty(), "gelen kutusu boş")
	await close_session()

	print("== 6) Bob: listede alice ==")
	await open_session("bob", false)
	await social().refresh(true)
	check(social().friends.size() == 1 and social().friends[0]["uid"] == "alice", "bob'un listesinde alice")
	check(social().outgoing.is_empty(), "bekleyen istek kalmadı")
	check(social().is_friend("alice"), "is_friend")
	check(not await social().send_request(alice_code), "arkadaşa tekrar istek atılmaz")
	await close_session()

	print("== 7) Karşılıklı istek: ikinci gönderen doğrudan arkadaş olur ==")
	await open_session("carol")
	check(await social().create_profile("Carol"), "carol profil")
	var carol_code: String = social().my_code()
	check(await social().send_request(alice_code), "carol → alice")
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)
	check(await social().send_request(carol_code), "alice → carol (carol zaten istemişti)")
	check(social().is_friend("carol") and social().incoming.is_empty(), "doğrudan arkadaş oldular")
	check(not fb.store.has("users/carol/outbox/o_alice"), "carol'ın bekleyeni temizlendi")

	print("== 8) Ret, geri alma, çıkarma ==")
	await close_session()
	await open_session("bob", false)
	await social().refresh(true)
	check(await social().send_request(carol_code), "bob → carol")
	check(await social().cancel("carol"), "bob geri aldı")
	check(not fb.store.has("users/carol/inbox/r_bob") and not fb.store.has("users/bob/outbox/o_carol"), "iki kayıt da silindi")
	check(await social().send_request(carol_code), "bob → carol (yeniden)")
	await close_session()
	await open_session("carol", false)
	await social().refresh(true)
	check(await social().reject("bob"), "carol reddetti")
	check(not fb.store.has("users/carol/inbox/r_bob") and not fb.store.has("users/bob/outbox/o_carol"), "ret: iki kayıt da silindi")
	check(await social().remove_friend("alice"), "carol alice'i çıkardı")
	check(not fb.store.has("users/carol/friends/f_alice") and not fb.store.has("users/alice/friends/f_carol"), "iki taraftan silindi")

	print("== 9) Ad değiştirme ==")
	check(await social().rename("Carol Usta"), "ad değişti")
	check(garage_doc("carol").get("name") == "Carol Usta" and garage_doc("carol").get("code") == carol_code, "sunucuda yeni ad, kod aynı")
	check(not await social().rename("x"), "geçersiz ad reddedilir")
	await close_session()

	print("== 10) Çevrimdışı / zaman aşımı ==")
	await open_session("bob", false)
	fb.online = false
	await social().refresh(true)
	check(social().is_ready() and last_notice().contains("yüklenemedi"), "çevrimdışı: liste yüklenemedi, profil duruyor")
	fb.online = true
	fb.hang = true
	var started: int = Time.get_ticks_msec()
	check(not await social().send_request(carol_code), "yanıt gelmezse istek başarısız")
	check(Time.get_ticks_msec() - started < 3000, "  ...zaman aşımıyla döndü (%d ms)" % (Time.get_ticks_msec() - started))
	fb.hang = false
	await social().refresh(true)
	check(social().friends.size() == 1, "sonra normal çalışır")
	await close_session()

	print("== 11) Hesap silme: sosyal veriler de silinir ==")
	await open_session("alice", false)
	await social().refresh(true)
	check(social().friends.size() == 1 and social().friends[0]["uid"] == "bob", "alice'in arkadaşı: bob")
	await open_bob_request_to_alice(alice_code)
	await open_session("alice", false)
	cloud().delete_account()
	var gone: bool = await until(func() -> bool: return not fb.store.has("players/alice"), 8.0)
	check(gone, "bulut kaydı silindi")
	var leftovers: Array = fb.store.keys().filter(func(k: String) -> bool:
		return k.contains("alice") or k == "codes/" + alice_code)
	check(leftovers.is_empty(), "alice'e ait belge kalmadı: %s" % [leftovers])
	check(not fb.store.has("users/bob/friends/f_alice"), "bob'un listesinden de silindi")
	check(fb.store.has("garages/g_bob") and fb.store.has("garages/g_carol"), "başkalarının garajı duruyor")
	await close_session()

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Bob alice'e (silinmeden önce) bir istek daha bıraksın diye yeni bir oyuncu (dave) istek atar.
func open_bob_request_to_alice(alice_code: String) -> void:
	await close_session()
	await open_session("dave")
	check(await social().create_profile("Dave"), "dave profil")
	check(await social().send_request(alice_code), "dave → alice (bekleyen istek)")
	await close_session()
