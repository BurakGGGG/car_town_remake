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
			"garages", "codes", "avatars", "invites":
				return true
			"reports":
				return false   # yalnız konsoldan
			"push":
				return id == "p_" + me
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
					and not data.has("money") and ProfileCatalog.is_valid_av(SaveSafe.s(data.get("av", "")))
			"push":
				return id == "p_" + me and SaveSafe.s(data.get("token", "")).length() > 20
			"avatars":
				return id == "a_" + me and SaveSafe.s(data.get("img", "")).length() <= 40000 \
					and ProfileCatalog.is_hash(SaveSafe.s(data.get("hash", "")))
			"reports":
				var target: String = SaveSafe.s(data.get("target", ""))
				return target != me and id == "x_%s_%s" % [me, target] \
					and ["photo", "name", "garage"].has(SaveSafe.s(data.get("reason", "")))
			"invites":
				# davet: sahibi, üzerine yazılamaz, jeton biçimi, saat sunucuya ±10 dk
				return not store.has(col + "/" + id) and SaveSafe.s(data.get("uid", "")) == me \
					and SocialNames.is_valid_token(id) and absi(int(data.get("at", 0)) - int(Time.get_unix_time_from_system())) < 600
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
						# davet linki: geçerli (1 saati dolmamış) davet, diğer taraf oluşturmuş
						var invite: Dictionary = store.get("invites/" + SaveSafe.s(data.get("inv", "")), {})
						var fresh: bool = not invite.is_empty() \
							and int(invite.get("at", 0)) + 3600 > int(Time.get_unix_time_from_system())
						var inviter: String = SaveSafe.s(invite.get("uid", ""))
						return other != owner and ((me == owner and store.has("users/%s/inbox/r_%s" % [owner, other])) \
							or (other == me and store.has("users/%s/inbox/r_%s" % [me, owner])) \
							or (fresh and me == owner and inviter == other) or (fresh and other == me and inviter == owner))
					"races":
						# yarış haberi: yalnız arkadaş, kendi adına (e_{ben}), kendine değil
						return owner != me and id == "e_" + me and store.has("users/%s/friends/f_%s" % [owner, me])
					"gifts":
						# yalnız arkadaş, günde bir (üzerine yazılamaz), yalnız istenen parça
						var day: int = floori(Time.get_unix_time_from_system() / 86400.0)
						var ask: Dictionary = store.get("garages/g_" + owner, {}).get("ask", {})
						return owner != me and id == "p_%s_%d" % [me, day] and int(data.get("day", -1)) == day \
							and not store.has(col + "/" + id) and store.has("users/%s/friends/f_%s" % [owner, me]) \
							and SaveSafe.s(ask.get("part", "")) == SaveSafe.s(data.get("part", ""))
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
			"avatars", "push":
				return id == ("a_" if p[0] == "avatars" else "p_") + me
			"invites":
				return not store.has(col + "/" + id) or SaveSafe.s(store[col + "/" + id].get("uid", "")) == me
			"codes":
				return not store.has(col + "/" + id) or SaveSafe.s(store[col + "/" + id].get("uid", "")) == me
			"users":
				match p[2]:
					"inbox":
						return p[1] == me or id == "r_" + me
					"outbox":
						return p[1] == me or id == "o_" + me
					"gifts":
						var today: int = floori(Time.get_unix_time_from_system() / 86400.0)
						return p[1] == me and (int(store.get(col + "/" + id, {}).get("day", today)) < today \
							or not store.has("garages/g_" + me))
					"friends":
						return p[1] == me or id == "f_" + me
					"races":
						return p[1] == me or id == "e_" + me
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
## offline_start: internetsiz açılış (bulut OFFLINE kalır, sosyal oturum açılmaz); with_profile: PlayerProfile da kurulur.
func open_session(account: String, fresh_device: bool = true, offline_start: bool = false, with_profile: bool = false) -> void:
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
	var junkyard: JunkyardManager = JunkyardManager.new()   # hurdalık hediyesi (istek / toplama)
	social.use_firebase(fb)
	social.publish_delay = 0.3
	social.request_timeout = 1.0
	var nodes: Array[Node] = [eco, prog, upg, own, junkyard, save, cloud, social]   # hurdalık kayıttan önce (oyundaki sıra)
	if with_profile:
		nodes.insert(nodes.find(save), PlayerProfile.new())
	for n: Node in nodes:
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
	if offline_start:
		fb.online = false
		cloud.sign_in()
		await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.OFFLINE)
		return
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
	SocialManager.auto_profile = false   # profil elle kurulur (otomatik profil social_test §15'te denenir)
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
	# Elle yazılmış belge: oyunu atlayan biri açık garaja gizli bölümler / tutarsız sayılar / yanlış türler koyabilir
	var injected: Dictionary = PublicGarage.parse(JSON.stringify(snap))
	check(not injected.has("economy") and not injected.has("crates") and not (injected["progress"] as Dictionary).has("xp"),
		"elle eklenmiş ekonomi / kasa / XP bölümleri okunurken de atılır (ziyaret modunda yüklenmez)")
	var fields: Dictionary = SocialManager.profile_fields({"stats": {"wins": 50, "races": 10, "cars": 99999, "likes": -5}})
	check(fields["stats"]["wins"] == 10 and fields["stats"]["cars"] == CarCatalog.size() and fields["stats"]["likes"] == 0,
		"istatistikler tutarlı sınırlanır (galibiyet <= yarış, araç <= katalog, beğeni >= 0)")
	var build: Dictionary = PerformanceMods.normalized({"motor": null, "turbo": {"x": 1}, "air": "3", "tire": 99})
	check(build.size() == 2 and int(build.get(&"air", 0)) == 3 and int(build.get(&"tire", 0)) == PerformanceMods.STAGES,
		"yanlış türdeki modifiye kademeleri hata vermeden 0..5'e iner")

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
	check(SaveSafe.s(gdoc.get("garage_json", "")).begins_with(CloudPack.PREFIX), "açık garaj sıkışık yazılır")
	check(not CloudPack.unpack(SaveSafe.s(gdoc.get("garage_json", ""))).contains("money"), "açık garajda para yok")
	check(not fb.store.has("garages/alice") and not fb.store.has("codes/alice"), "çıplak UID kimlikli belge yok")

	print("== 3) Yayın: kayıttan sonra açık garaj güncellenir, bulut kaydıyla karışmaz ==")
	(w["own"] as VehicleOwnership).add_vehicle(&"hyundai_getz")
	(w["eco"] as EconomyManager).set_money(12345)
	(w["save"] as SaveManager).save_game()
	var published: bool = await until(func() -> bool:
		return CloudPack.unpack(SaveSafe.s(garage_doc("alice").get("garage_json", ""))).contains("hyundai_getz"), 5.0)
	check(published, "yeni araç açık garajda")
	await until(func() -> bool: return not cloud().is_busy() and cloud().get_state() == CloudSaveManager.State.SYNCED, 5.0)
	var cloud_ok: bool = await until(func() -> bool:
		return CloudPack.unpack(SaveSafe.s(fb.store.get("players/alice", {}).get("save_json", ""))).contains("12345"), 5.0)
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

	print("== 9b) Elle yazılmış istek: ad / kod gönderenin garajından, garajı olmayanın isteği düşer ==")
	fb.store["users/bob/inbox/r_carol"] = {"name": "admin", "code": alice_code, "at": 9999999999}
	fb.store["users/bob/inbox/r_ghost"] = {"name": "Destek Ekibi", "code": "ABC234", "at": 1}
	await open_session("bob", false)
	await social().refresh(true)
	var spoof: Array = social().incoming.filter(func(r: Dictionary) -> bool: return r["uid"] == "carol")
	check(spoof.size() == 1 and spoof[0]["name"] == "Carol Usta" and spoof[0]["code"] == carol_code,
		"istekte yazan 'admin' / alice'in kodu değil, carol'ın garajındaki ad ve kod görünür")
	check(social().incoming.filter(func(r: Dictionary) -> bool: return r["uid"] == "ghost").is_empty()
		and not fb.store.has("users/bob/inbox/r_ghost"), "açık garajı olmayan gönderenin isteği silindi")
	check(SocialManager.their_name("admin", "x").begins_with("Usta") and SocialManager.their_name(" Carol  Usta ", "x") == "Carol Usta"
		and SocialManager.their_name("AutoYard Destek", "x").begins_with("Usta"), "başkasının adı süzgeçten geçer")
	fb.store.erase("users/bob/inbox/r_carol")
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

	print("== 10b) Hurdalık hediyesi: iste → gönder → topla ==")
	await open_session("alice", false)
	await social().refresh(true)
	var jy: JunkyardManager = get_first_node_in_group(&"junkyard") as JunkyardManager
	check(social().friends.size() >= 1 and jy != null, "alice'in arkadaşı (bob) ve hurdalığı var")
	var bolts_before: int = jy.part_count(&"bolt")
	fb.online = false
	check(not await social().ask_part(&"bolt") and last_notice().contains("gönderilemedi"), "internet yokken istek gönderilemedi")
	check(jy.can_ask() and jy.current_ask().is_empty() and not garage_doc("alice").has("ask"),
		"  ...6 saatlik bekleme yanmadı, yeniden istenebilir")
	fb.online = true
	check(await social().ask_part(&"bolt"), "alice arkadaşlarından civata istedi")
	check(SaveSafe.s((garage_doc("alice").get("ask", {}) as Dictionary).get("part", "")) == "bolt", "istek açık garajda")
	check(not await social().ask_part(&"nut") and last_notice().contains("bekle"), "6 saat dolmadan yeniden istenemez")
	check(SaveSafe.s(((jy.state()["yard"] as Dictionary)["ask"] as Dictionary).get("part", "")) == "bolt", "istek kayıtta")
	# Oyun açıkken gelen hediye: istek açıkken haber yoklaması kutuya da bakar (ekran açmayı beklemez). Belge kutuya
	# doğrudan yazılır (toplama sınanıyor; parça bob'un aşağıdaki civatasına karışmasın diye somun).
	var poll_gift: String = "users/alice/gifts/p_dave_%d" % floori(Time.get_unix_time_from_system() / 86400.0)
	fb.store[poll_gift] = {"part": "nut", "name": "Dave Usta", "at": 1, "day": floori(Time.get_unix_time_from_system() / 86400.0)}
	var poll_nuts: int = jy.part_count(&"nut")
	await until(func() -> bool: return not social().is_busy() and not social()._op_busy)   # yoklama meşgulken atlar
	await social()._on_news_poll()
	check(jy.part_count(&"nut") == poll_nuts + 1 and last_notice().contains("HEDİYE"), "oyun içinde gelen hediye yoklamada toplandı")
	fb.store.erase(poll_gift)
	await close_session()
	await open_session("bob", false)
	await social().refresh(true)
	var alice_entry: Dictionary = social().friends[social().friends.find_custom(func(e: Dictionary) -> bool: return e["uid"] == "alice")]
	check(alice_entry.get("ask_part") == "bolt", "bob alice'in civata istediğini görüyor")
	check(social().can_gift("alice") and not social().can_gift("nobody"), "bob gönderebilir")
	# alice bu arada başka parça istedi (bob'un listesi eski): sunucu reddeder; günlük hak yanmaz, kart güncellenir
	var alice_garage: Dictionary = fb.store["garages/g_alice"]
	var bolt_ask: Dictionary = alice_garage["ask"]
	alice_garage["ask"] = {"part": "nut", "at": int(bolt_ask["at"])}
	check(not await social().send_gift("alice") and last_notice().contains("değişti"), "eski istekle gönderim: istek değişti")
	var changed_entry: Dictionary = social().friends[social().friends.find_custom(func(e: Dictionary) -> bool: return e["uid"] == "alice")]
	check(social().can_gift("alice") and changed_entry.get("ask_part") == "nut", "  ...günlük hak yanmadı, kart yeni isteği gösteriyor")
	alice_garage["ask"] = bolt_ask
	await social().refresh(true)
	check(await social().send_gift("alice"), "bob 1 civata gönderdi")
	var day: int = floori(Time.get_unix_time_from_system() / 86400.0)
	check(fb.store.has("users/alice/gifts/p_bob_%d" % day), "hediye alice'in kutusunda")
	check(not social().can_gift("alice"), "aynı gün ikinci hediye düğmesi yok")
	check(not await social().send_gift("alice") and last_notice().contains("zaten"), "  ...zorlansa da sunucu reddeder (günlük sınır)")
	await close_session()
	await open_session("alice", false)
	await social().refresh(true)   # yenileme hediyeleri de toplar
	jy = get_first_node_in_group(&"junkyard") as JunkyardManager
	check(jy.part_count(&"bolt") == bolts_before + 1, "alice civatayı aldı (%d → %d)" % [bolts_before, jy.part_count(&"bolt")])
	check(fb.store.has("users/alice/gifts/p_bob_%d" % day), "bugünün hediyesi sunucuda kalır (günlük sınır)")
	check(await social().collect_gifts() == 0 and jy.part_count(&"bolt") == bolts_before + 1, "tekrar toplamak ikinci kez eklemez")
	fb.store["users/alice/gifts/p_carol_%d" % (day - 3)] = {"part": "nut", "name": "Carol Usta", "at": 1, "day": day - 3}
	var nuts_before: int = jy.part_count(&"nut")
	check(await social().collect_gifts() == 1 and jy.part_count(&"nut") == nuts_before + 1, "eski hediye de toplandı")
	check(not fb.store.has("users/alice/gifts/p_carol_%d" % (day - 3)), "eski hediye belgesi temizlendi")
	check(not jy.gift_seen("p_carol_%d" % (day - 3)) and jy.gift_seen("p_bob_%d" % day), "silinen unutuldu, bugünkü hatırlanıyor")
	# (oyuncular bu düzenekte aynı cihaz klasörünü sırayla kullanır: bob'un oturumu alice'in yerel kaydını ezdi)
	check(((jy.state()["yard"] as Dictionary)["gift_seen"] as Array).has("p_bob_%d" % day), "toplanan hediyeler kayıtta")
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

	print("== 12) Davet linki: gönderen onaylamaz, 1 saat geçerli ==")
	await open_session("gina")
	check(await social().create_profile("Gina"), "gina profil")
	var gina_code: String = social().my_code()
	var link: String = await social().create_invite()
	var token: String = InviteLinks.parse_token(link)
	check(link.begins_with(SocialManager.INVITE_URL) and SocialNames.is_valid_token(token), "gina davet linki: %s" % link)
	var invite_doc: Dictionary = fb.store.get("invites/" + token, {})
	check(invite_doc.get("uid") == "gina" and invite_doc.get("code") == gina_code and invite_doc.get("name") == "Gina",
		"davet belgesi: kim, kod, ad")
	check(InviteLinks.parse_token("autoyard://davet/" + token.to_lower()) == token
		and InviteLinks.parse_token(SocialManager.INVITE_URL + token + "?yok") == token
		and SocialManager.LEGACY_INVITE_URLS.all(func(u: String) -> bool: return InviteLinks.parse_token(u + token) == token)
		and InviteLinks.parse_token("autoyard://davet/KISA") == "", "link biçimleri ayrışır, biçimsiz jeton reddedilir")
	check((await social().read_invite(token)).get("status") == "self", "kendi linki: self")
	await close_session()
	await open_session("hank")
	check(await social().create_profile("Hank"), "hank profil")
	var info: Dictionary = await social().read_invite(token)
	var person: Dictionary = info.get("person", {})
	check(info.get("status") == "ok" and info.get("uid") == "gina" and person.get("name") == "Gina",
		"hank davette gina'nın profilini görüyor")
	check(await social().accept_invite(info), "hank: ARKADAŞ EKLE")
	check(fb.store.has("users/hank/friends/f_gina") and fb.store.has("users/gina/friends/f_hank"),
		"iki taraflı arkadaşlık — gina onaylamadı")
	check(SaveSafe.s((fb.store["users/gina/friends/f_hank"] as Dictionary).get("inv", "")) == token, "belgede davet jetonu")
	check(social().is_friend("gina") and last_notice().contains("Gina"), "hank'in listesinde gina: %s" % last_notice())
	check((await social().read_invite(token)).get("status") == "friend", "aynı link yeniden: zaten arkadaş")
	await close_session()
	var aged: Dictionary = (fb.store["invites/" + token] as Dictionary).duplicate()
	aged["at"] = int(aged["at"]) - SocialManager.INVITE_TTL - 5   # 1 saat geçti
	fb.store["invites/" + token] = aged
	await open_session("ivy")
	check(await social().create_profile("Ivy"), "ivy profil")
	var late: Dictionary = await social().read_invite(token)
	check(late.get("status") == "expired", "1 saat dolunca: expired")
	late["status"] = "ok"   # ekran eski durumda kalmış gibi zorla dene
	check(not await social().accept_invite(late) and not fb.store.has("users/gina/friends/f_ivy")
		and not fb.store.has("users/ivy/friends/f_gina"), "süresi dolmuş davetle eklenemez, yarım kayıt yok")
	check(last_notice().contains("süresi dolmuş"), "  ...mesaj: %s" % last_notice())
	check((await social().read_invite("ABCDEFGHJKLM")).get("status") == "missing", "olmayan davet: missing")
	check((await social().read_invite("kısa")).get("status") == "missing", "biçimsiz jeton: missing (sunucuya gitmez)")
	await close_session()
	await open_session("gina", false)
	var second: String = InviteLinks.parse_token(await social().create_invite())
	check(fb.store.has("invites/" + second), "gina bu cihazda ikinci davet")
	cloud().delete_account()
	check(await until(func() -> bool: return not fb.store.has("players/gina"), 8.0), "gina hesabını sildi")
	check(not fb.store.has("invites/" + second), "hesap silinince bu cihazdaki davetler de silindi")
	await close_session()

	print("== 13) Hesap silme: oyun internetsiz açılmış, sosyal oturum hiç açılmamış ==")
	var ivy_code: String = SaveSafe.s(garage_doc("ivy").get("code", ""))
	await open_session("hank", false)
	check(await social().send_request(ivy_code), "hank → ivy arkadaşlık isteği")
	await close_session()
	await open_session("ivy", true, true)   # yeni cihaz, internet yok
	check(cloud().get_state() == CloudSaveManager.State.OFFLINE and social().get_state() == SocialManager.State.SIGNED_OUT,
		"ivy: bulut çevrimdışı, sosyal oturum kapalı")
	fb.online = true   # internet geldi, oturum henüz açılmadan HESABIMI SİL
	cloud().delete_account()
	check(await until(func() -> bool: return not fb.store.has("players/ivy"), 8.0), "ivy hesabını sildi")
	var ivy_left: Array = fb.store.keys().filter(func(k: String) -> bool:
		return k.contains("ivy") or k == "codes/" + ivy_code)
	check(ivy_left.is_empty(), "oturum açılmadan da sosyal veriler silindi (garaj, kod, istek iki taraftan): %s" % [ivy_left])
	await close_session()

	print("== 14) Profil fotoğrafı: kaldırılınca sunucudan silinir, Google fotoğrafı varsayılan kapalı ==")
	await open_session("jill", true, false, true)
	check(await social().create_profile("Jill"), "jill profil")
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	check(profile != null and not profile.use_google, "Google fotoğrafı varsayılan kapalı (oyuncu açmadıkça avatar olmaz)")
	var photo: Image = Image.create(256, 256, false, Image.FORMAT_RGB8)
	photo.fill(Color(0.8, 0.3, 0.2))
	check(profile.set_photo(photo), "jill fotoğraf koydu")
	await social().publish_now()
	check(fb.store.has("avatars/a_jill") and SaveSafe.s(garage_doc("jill").get("av", "")).begins_with("img:"),
		"fotoğraf yüklendi, açık garajda img:")
	var preset: String = ProfileCatalog.preset_ids()[0]
	profile.set_preset(preset)
	await social().publish_now()
	check(not fb.store.has("avatars/a_jill") and garage_doc("jill").get("av") == preset,
		"hazır avatara geçince eski fotoğraf sunucudan silindi")
	check(profile.set_photo(photo), "yeniden fotoğraf")
	await social().publish_now()
	profile.set_auto()   # KALDIR: Google kapalı → kask
	await social().publish_now()
	check(not fb.store.has("avatars/a_jill") and SaveSafe.s(garage_doc("jill").get("av", "")) == "",
		"KALDIR: fotoğraf sunucudan silindi, kask")
	await close_session()
	var legacy: PlayerProfile = PlayerProfile.new()
	legacy.load_state({"use_google": true})
	var old_default_off: bool = not legacy.use_google
	legacy.load_state({"google_photo": true})
	check(old_default_off and legacy.use_google and legacy.state().get("google_photo") == true,
		"eski kayıttaki varsayılan 'açık' okunmaz; oyuncunun yeni seçimi saklanır")
	legacy.free()

	print("== 15) Otomatik profil: hesapla giren ARKADAŞLAR'a gitmeden rastgele adla profil alır (2026-10-31) ==")
	SocialManager.auto_profile = true
	var said: int = notices.size()
	await open_session("kim")
	check(social().is_ready(), "girişten hemen sonra profil hazır (READY)")
	check(RegEx.create_from_string("^Usta\\d{4}$").search(social().my_name()) != null, "rastgele ad: %s" % social().my_name())
	check(SocialNames.is_valid_code(social().my_code()) and fb.store.get("codes/" + social().my_code(), {}).get("uid") == "kim",
		"arkadaş kodu alındı")
	check(garage_doc("kim").get("name") == social().my_name(), "açık garaj rastgele adla yazıldı")
	check(notices.size() == said, "oyuncuya bildirim gösterilmedi (sessiz)")
	check(await social().rename("Kim Usta") and garage_doc("kim").get("name") == "Kim Usta", "ad sonradan değişir")
	await close_session()
	await open_session("kim", false)   # aynı cihaz, yeniden açılış
	check(social().is_ready() and social().my_name() == "Kim Usta", "yeniden açılışta aynı profil (yeni ad verilmedi)")
	await close_session()
	await open_session("kim")   # yeni cihaz: sunucudaki profil okunur
	check(social().my_name() == "Kim Usta" and garage_doc("kim").get("name") == "Kim Usta",
		"yeni cihazda sunucudaki profil geri geldi (üstüne rastgele ad yazılmadı)")
	await close_session()
	said = notices.size()
	fb.deny_codes = SocialManager.CODE_ATTEMPTS   # kod alınamıyor: profil kurulamaz
	await open_session("lee")
	check(social().get_state() == SocialManager.State.NO_PROFILE and notices.size() == said and not fb.store.has("garages/g_lee"),
		"kurulamazsa NO_PROFILE kalır, hata bildirimi yağmaz (ARKADAŞLAR formu yedek)")
	fb.deny_codes = 0
	await close_session()
	SocialManager.auto_profile = false

	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## Bob alice'e (silinmeden önce) bir istek daha bıraksın diye yeni bir oyuncu (dave) istek atar.
func open_bob_request_to_alice(alice_code: String) -> void:
	await close_session()
	await open_session("dave")
	check(await social().create_profile("Dave"), "dave profil")
	check(await social().send_request(alice_code), "dave → alice (bekleyen istek)")
	await close_session()
