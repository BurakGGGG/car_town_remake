extends SceneTree
## ARKADAŞ DAVETİ (ReferralManager + ReferralRewards + MailService davet postaları) — sahte Firebase ile, izole user://.
##   tools/run_tests.sh referral_test
## Sunucunun kendisi (functions/referral.js) ayrıca sınanır: firebase/functions npm test. Buradaki sahte sunucu onun
## sadeleştirilmiş taklididir; amaç oyunun akışı (talep, sonuç, seviye işareti, posta, kayıt).
## 1) Tablo, link ayrıştırma, cihazda bekleyen kod. 2) Misafir → hesap: talep, hoş geldin postası, 3. seviye işareti.
## 3) Aynı telefonda ikinci hesap / eski hesap / başka telefon. 4) Davet eden: cihaz özeti, sayaç + liste.
## 5) Basamak postaları: gelir dakikası, özel çerçeve, efsanevi araç seçimi (+ elmas yedeği). 6) Kayıt.

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
	var calls: Array[String] = []
	## Sahte Auth: UID → hesabın yaşı (gün; yoksa yeni).
	var age_days: Dictionary = {}

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
		if not _mine(col, id):
			r = {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."}
		elif store.has(path):
			r = {"status": true, "docID": id, "data": (store[path] as Dictionary).duplicate(true)}
		else:
			r = {"status": false, "docID": id, "error": "Document does not exist"}
		_later("firestore_get_task_completed", r)

	func firestoreGetDocumentsInCollection(col: String) -> void:
		calls.append("list %s" % col)
		var me: String = uid()
		var p: PackedStringArray = col.split("/")
		var ok: bool = (p.size() == 3 and p[0] == "users" and p[1] == me) or col == "referrals/r_%s/invited" % me
		if me.is_empty() or not ok:
			_later("firestore_get_task_completed", {"status": false, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		var data: Dictionary = {}
		for path: String in store:
			if path.get_base_dir() == col:
				data[path.get_file()] = (store[path] as Dictionary).duplicate(true)
		_later("firestore_get_task_completed", {"status": true, "data": data})

	## firestore.rules (sadeleştirilmiş): kayıt, garaj, kod; davet talebi ve seviye işareti BİR KEZ, cihaz özeti her zaman.
	func firestoreSetDocument(col: String, id: String, data: Dictionary, _merge: bool) -> void:
		calls.append("set %s/%s" % [col, id])
		var me: String = uid()
		var path: String = col + "/" + id
		var referral: bool = col == "users/%s/referral" % me
		var ok: bool = not me.is_empty() and ((col == "players" and id == me) or (col == "garages" and id == "g_" + me)
			or (col == "players/%s/history" % me)
			or (referral and id == "ref_owner" and data.keys().size() == 2 and SaveSafe.s(data.get("dev", "")).length() == 64)
			or (referral and id == "ref_claim" and not store.has(path) and data.keys().size() == 4)
			or (referral and id == "ref_lvl3" and not store.has(path) and store.has(col + "/ref_claim")))
		if not ok:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store[path] = data.duplicate(true)
		_later("firestore_write_task_completed", {"status": true, "docID": id})
		if referral and id == "ref_claim":
			_join(me)
		elif referral and id == "ref_lvl3":
			_qualify(me, true)

	func firestoreDeleteDocument(col: String, id: String) -> void:
		calls.append("delete %s/%s" % [col, id])
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
			"referrals":
				return p.size() == 1 and id == "r_" + me
			"users":
				return p.size() == 3 and p[1] == me
		return false

	## functions/referral.js handleJoin taklidi (tetikleyici gibi biraz gecikmeyle).
	func _join(me: String) -> void:
		await tree.create_timer(0.25).timeout
		var claim_path: String = "users/%s/referral/ref_claim" % me
		var claim: Dictionary = store[claim_path]
		var code: String = SaveSafe.s(claim.get("code", ""))
		var dev: String = SaveSafe.s(claim.get("dev", ""))
		var inviter: String = SaveSafe.s((store.get("codes/" + code, {}) as Dictionary).get("uid", ""))
		var owner: Dictionary = store.get("users/%s/referral/ref_owner" % inviter, {})
		var status: String = "ok"
		if inviter.is_empty():
			status = "no_code"
		elif inviter == me or SaveSafe.s(owner.get("dev", "")) == dev:
			status = "self"
		elif int(age_days.get(me, 0)) > ReferralRewards.JOIN_DAYS:
			status = "old_account"
		elif store.has("ref_devices/" + dev):
			status = "device_used"
		if status != "ok":
			claim["status"] = status
			return
		store["ref_devices/" + dev] = {"at": 1}
		var stats: Dictionary = store.get("referrals/r_" + inviter, {})
		stats["joined"] = int(stats.get("joined", 0)) + 1
		store["referrals/r_" + inviter] = stats
		store["referrals/r_%s/invited/f_%s" % [inviter, me]] = {"at": 100 + int(stats["joined"]), "state": "joined",
			"src": claim["src"]}
		store["users/%s/friends/f_%s" % [inviter, me]] = {"since": 1}
		store["users/%s/friends/f_%s" % [me, inviter]] = {"since": 1}
		store["users/%s/mail/ref_welcome" % me] = {"title": {"tr": "Davet hediyen!"}, "text": {"tr": "Hoş geldin usta!"},
			"from": "AUTO YARD", "gems": ReferralRewards.WELCOME_GEMS, "money": ReferralRewards.WELCOME_MONEY, "at": 500}
		claim.merge({"status": "ok", "referrer": inviter}, true)
		if store.has("users/%s/referral/ref_lvl3" % me):
			_qualify(me, false)

	## handleQualify taklidi: davet sayılır, basamak postası davet edene.
	func _qualify(me: String, delayed: bool) -> void:
		if delayed:
			await tree.create_timer(0.25).timeout
		var claim: Dictionary = store.get("users/%s/referral/ref_claim" % me, {})
		if SaveSafe.s(claim.get("status", "")) != "ok":
			return   # katılmadan önce: bekler (katılınca _join çağırır)
		var inviter: String = claim["referrer"]
		var entry: Dictionary = store["referrals/r_%s/invited/f_%s" % [inviter, me]]
		if entry["state"] == "qualified":
			return
		var stats: Dictionary = store["referrals/r_" + inviter]
		stats["count"] = int(stats.get("count", 0)) + 1
		var n: int = int(stats["count"])
		entry.merge({"state": "qualified", "tier": n if n <= ReferralRewards.max_tier() else 0}, true)
		var tier: Dictionary = ReferralRewards.tier(n)
		if not tier.is_empty():
			var doc: Dictionary = {"title": {"tr": "%d. davet ödülün geldi!" % n}, "from": "AUTO YARD", "at": 600 + n,
				"referral": "tier_%d" % n, "friend": me}
			doc.merge(tier.duplicate(true), true)
			store["users/%s/mail/ref_%d" % [inviter, n]] = doc

	func _later(sig: String, value: Variant) -> void:
		await tree.create_timer(randf() * 0.05).timeout
		emit_signal(sig, value)


const SIGNALS: Array[StringName] = [
	&"auth_success", &"auth_failure", &"sign_out_success", &"user_deleted",
	&"firestore_get_task_completed", &"firestore_write_task_completed", &"firestore_delete_task_completed",
]
const CODE: String = "K7P2QX"

var fb: FakeFB = FakeFB.new()
var w: Dictionary = {}
var fails: int = 0


func _initialize() -> void:
	if OS.get_user_data_dir().ends_with("/AUTO YARD"):
		print("  FAIL izole user:// klasörü yok (tools/run_tests.sh ile çalıştır)")
		quit(1)
		return
	fb.tree = self
	seed(777)
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
	fb.store["codes/" + CODE] = {"uid": "alice"}
	_table()
	_links()
	await _guest_then_account()
	await _same_phone()
	await _inviter()
	await _tier_mail()
	await _save_state()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


## new_phone: cihaz dosyası (bekleyen kod, kurulum kimliği) da silinir — başka bir telefon.
func open_session(account: String, new_phone: bool, sign_in: bool = true) -> void:
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	if new_phone:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join("referral.json"))
	fb.account = account
	fb.user = {}
	fb.calls.clear()
	var root_node: Node = Node.new()
	var eco: EconomyManager = EconomyManager.new()
	var prog: PlayerProgress = PlayerProgress.new()
	var upg: GarageUpgradeManager = GarageUpgradeManager.new()
	var own: VehicleOwnership = VehicleOwnership.new()
	var decor: DecorManager = DecorManager.new()
	var crates: CrateManager = CrateManager.new()
	var profile: PlayerProfile = PlayerProfile.new()
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	var mail: MailService = MailService.new()
	var referral: ReferralManager = ReferralManager.new()
	social.use_firebase(fb)
	social.request_timeout = 1.0
	for n: Node in [eco, prog, upg, own, decor, crates, profile, mail, referral, save, cloud, social]:
		root_node.add_child(n)
	root.add_child(root_node)
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	w = {"root": root_node, "eco": eco, "prog": prog, "own": own, "profile": profile, "save": save, "cloud": cloud,
		"social": social, "mail": mail, "ref": referral}
	await frames(6)
	if sign_in:
		await sign_in_now()


func sign_in_now() -> void:
	var cloud: CloudSaveManager = w["cloud"]
	var social: SocialManager = w["social"]
	cloud.sign_in()
	await until(func() -> bool: return cloud.get_state() == CloudSaveManager.State.SYNCED)
	await until(func() -> bool: return social.get_state() not in [SocialManager.State.SIGNED_OUT, SocialManager.State.LOADING])
	await until(func() -> bool: return not social.is_busy())


func close_session() -> void:
	await until(func() -> bool: return not (w["social"] as SocialManager).is_busy() and not (w["cloud"] as CloudSaveManager).is_busy(), 3.0)
	await until(func() -> bool: return not (w["ref"] as ReferralManager)._running, 6.0)
	for s: StringName in SIGNALS:
		for c: Dictionary in fb.get_signal_connection_list(s):
			fb.disconnect(s, c["callable"])
	w["root"].queue_free()
	w = {}
	await frames(2)


func ref() -> ReferralManager:
	return w["ref"]


func level_to(target: int) -> void:
	var prog: PlayerProgress = w["prog"]
	while prog.level < target:
		prog.add_xp(prog.xp_to_next())


func _table() -> void:
	print("== 1a) Ödül tablosu ==")
	check(ReferralRewards.max_tier() == 10 and ReferralRewards.tier(0).is_empty() and ReferralRewards.tier(11).is_empty(),
		"10 basamak (0 ve 11 boş)")
	check(ReferralRewards.tier(10).get("choice") == ReferralRewards.CHOICE_LEGENDARY
		and ReferralRewards.tier(10).get("frame") == ReferralRewards.FRAME_ENVOY, "10. basamak: efsanevi araç seçimi + ELÇİ")
	check(ReferralRewards.tier(5).get("frame") == ReferralRewards.FRAME_INVITER, "5. basamak: DAVETÇİ çerçevesi")
	for n: int in range(1, 11):
		var tier: Dictionary = ReferralRewards.tier(n)
		for crate: Variant in (tier.get("crates", {}) as Dictionary):
			check(CrateCatalog.exists(StringName(crate)), "%d. basamağın kasası katalogda (%s)" % [n, crate])
	check(ReferralRewards.money_for(12, 991.0) == 12000 and ReferralRewards.money_for(0, 991.0) == 0,
		"12 dk gelir, garaj 2 (991 ₺/dk) → 12.000 ₺ (giriş merdiveni yuvarlaması)")
	check(not ReferralRewards.car_pool(null).is_empty()
		and ReferralRewards.car_pool(null).all(func(id: StringName) -> bool: return CrateCatalog.rarity_of(id) != &""),
		"efsanevi seçim havuzu SÜPER KASA'dan")
	check(ProfileCatalog.frame_exclusive("inviter") and ProfileCatalog.frame_exclusive("envoy")
		and not ProfileCatalog.frame_exclusive("gold"), "DAVETÇİ / ELÇİ yalnız verilen çerçeve")
	check(not LevelUnlocks.between(1, 99).any(func(u: Dictionary) -> bool:
		return u["kind"] == LevelUnlocks.Kind.FRAME and ProfileCatalog.frame_exclusive(String(u["id"]))),
		"seviye açılış ekranı davet çerçevelerini göstermez")
	check(MailService.normalize("x", {"frame": "gold"}).is_empty() and MailService.normalize("x", {"choice": "lambo"}).is_empty(),
		"posta satılık çerçeve / bilinmeyen seçim vermez")
	var tier_mail: Dictionary = MailService.normalize("ref_10", ReferralRewards.tier(10))
	check(MailService.has_reward(tier_mail) and tier_mail["frame"] == "envoy" and tier_mail["choice"] == "legendary_car",
		"10. basamağın postası ödüllü sayılır")
	check(int(MailService.normalize("m", {"money_min": 9999})["money_min"]) == ReferralRewards.MAX_MONEY_MIN,
		"gelir dakikası üst sınırla")
	var welcome: Dictionary = MailService.normalize("ref_welcome", {"gems": 50, "referral": "welcome"})
	var t4: Dictionary = MailService.normalize("ref_4", {"gems": 75, "referral": "tier_4", "friend": "f3"})
	check(welcome["ref_kind"] == "welcome" and t4["ref_kind"] == "tier" and int(t4["ref_tier"]) == 4 and t4["friend"] == "f3",
		"davet postası türü / basamağı / arkadaşı (POSTA penceresinin özel görünümü)")
	check(MailService.normalize("m", {"gems": 1, "referral": "tier_x"})["ref_kind"] == ""
		and MailService.normalize("m", {"gems": 1, "referral": "hack"})["ref_kind"] == "", "bozuk davet türü sıradan posta")
	check(ReferralRewards.label(1, null) == "+50 GEM" and ReferralRewards.label(2, null) == "+4.500 ₺"
		and ReferralRewards.label(3, null) == MailService.crate_name(&"sport_crate")
		and ReferralRewards.label(10, null).begins_with("EFSANEVİ ARAÇ SEÇİMİ"), "basamak adları (yedek gelirle)")


func _links() -> void:
	print("== 1b) Link + cihazda bekleyen kod ==")
	check(InviteLinks.parse_ref("autoyard://davet/ABCDEFGH2345?r=k7p2qx") == CODE, "jetonlu link ?r= (küçük harf)")
	check(InviteLinks.parse_ref("autoyard://davet/r/K7P2QX") == CODE, "jetonsuz kalıcı link davet/r/KOD")
	check(InviteLinks.parse_ref("https://autoyard.online/d/ABCDEFGH2345?x=1&r=AY-K7P2QX#a") == CODE, "site linki, AY- öneki")
	check(InviteLinks.parse_ref("autoyard://davet/ABCDEFGH2345") == "" and InviteLinks.parse_ref("autoyard://davet/x?r=BAD") == "",
		"kodsuz / geçersiz kod boş")
	check(InviteLinks.parse_token("autoyard://davet/ABCDEFGH2345?r=K7P2QX") == "ABCDEFGH2345", "arkadaş jetonu bozulmadı")
	check(InstallReferrer.parse("ref=K7P2QX&inv=ABCDEFGH2345") == CODE and InstallReferrer.parse("ref%3Dk7p2qx%26inv%3DX") == CODE,
		"Play yükleme kaynağı: ref= (URL kodlu da)")
	check(InstallReferrer.parse("utm_source=google-play&utm_medium=organic") == "" and InstallReferrer.parse("ref=12") == "",
		"organik kurulum / geçersiz kod: kod yok")
	DirAccess.remove_absolute(OS.get_user_data_dir().path_join("referral.json"))
	check(not ReferralManager.remember("abc", "link") and not ReferralManager.remember(CODE, "hack"), "geçersiz kod / kaynak")
	check(ReferralManager.remember("ay-" + CODE.to_lower(), "play"), "kod cihazda bekler")
	check(not ReferralManager.remember("ABC234", "link") and ReferralManager.pending_code().get("src") == "play",
		"ilk gelen kaynak kazanır")


func _guest_then_account() -> void:
	print("== 2) Misafir → hesap ==")
	fb.age_days["bob"] = 0
	await open_session("bob", false, false)   # 1b'deki bekleyen kod bu telefonda
	await seconds(0.3)
	check(not fb.calls.any(func(c: String) -> bool: return c.contains("referral")), "misafir talep yazmaz (UID yok)")
	check(ref().can_enter_code() == false, "bekleyen kod varken elle kod alanı gizli")
	var joined_from: Array[String] = []
	ref().joined.connect(func(from: String) -> void: joined_from.append(from))
	await sign_in_now()
	await until(func() -> bool: return ref().status == "ok", 6.0)
	check(ref().status == "ok" and ref().referrer == "alice", "hesapla girince talep yazıldı, sonuç ok (davet eden alice)")
	check(joined_from == ["alice"], "joined yayıldı (karşılama ekranı)")
	var claim: Dictionary = fb.store.get("users/bob/referral/ref_claim", {})
	check(claim.get("code") == CODE and claim.get("src") == "play" and SaveSafe.s(claim.get("dev", "")).length() == 64,
		"talep: kod, kaynak, cihaz özeti (64 onaltılık)")
	check(ReferralManager.pending_code().is_empty() and SaveSafe.b(ReferralManager._read_meta().get("done", false)),
		"cihazdaki kod kullanıldı")
	check(fb.store.has("users/alice/friends/f_bob") and fb.store.has("users/bob/friends/f_alice"), "otomatik arkadaşlık")
	await until(func() -> bool: return (w["mail"] as MailService).pending().any(func(m: Dictionary) -> bool: return m["id"] == "ref_welcome"), 6.0)
	var mail: MailService = w["mail"]
	check(mail.pending().any(func(m: Dictionary) -> bool: return m["id"] == "ref_welcome" and int(m["gems"]) == 50),
		"hoş geldin postası okundu (+50 GEM)")
	check(not fb.store.has("users/bob/referral/ref_lvl3"), "seviye 1: işaret yazılmaz")
	level_to(ReferralRewards.QUALIFY_LEVEL)
	await until(func() -> bool: return ref().lvl3_sent, 4.0)
	check(ref().lvl3_sent and fb.store.has("users/bob/referral/ref_lvl3"), "3. seviye: işaret yazıldı")
	await until(func() -> bool: return fb.store.has("users/alice/mail/ref_1"), 3.0)
	check(fb.store.has("users/alice/mail/ref_1"), "davet sayıldı: alice'e 1. basamak postası")
	var writes: int = fb.calls.filter(func(c: String) -> bool: return c.begins_with("set users/bob/referral/ref_lvl3")).size()
	level_to(ReferralRewards.QUALIFY_LEVEL + 1)
	await seconds(0.4)
	check(fb.calls.filter(func(c: String) -> bool: return c.begins_with("set users/bob/referral/ref_lvl3")).size() == writes,
		"sonraki seviyede işaret yeniden yazılmaz")
	await close_session()


func _same_phone() -> void:
	print("== 3) Aynı telefon / eski hesap / başka telefon ==")
	fb.age_days["carol"] = 1
	await open_session("carol", false)   # bob'un telefonu
	check(ref().can_enter_code(), "yeni hesap: elle kod alanı açık")
	check(not ReferralManager.remember(CODE, "link"), "bu telefonun kodu kullanıldı: link yeniden bekletmez")
	var r: String = await ref().submit_code("ay " + CODE)
	check(r == "device_used" and ref().status == "device_used", "aynı telefonda ikinci hesap: device_used")
	check(not fb.store.has("users/carol/mail/ref_welcome") and not fb.store.has("users/alice/friends/f_carol"), "ödül / arkadaşlık yok")
	r = await ref().submit_code(CODE)
	check(r == "already", "talebi olan hesap yeniden deneyemez")
	check(ReferralManager.status_text("device_used") != ReferralManager.status_text("ok")
		and ReferralManager.status_text("old_account").contains(str(ReferralRewards.JOIN_DAYS)), "sonuç metinleri")
	await close_session()
	fb.age_days["olddan"] = 30
	await open_session("olddan", true)
	r = await ref().submit_code(CODE)
	check(r == "old_account", "7 günden eski hesap: old_account")
	await close_session()
	fb.age_days["dave"] = 2
	await open_session("dave", true)
	check((await ref().submit_code("12")) == "invalid", "biçimsiz kod sunucuya gitmez")
	r = await ref().submit_code(CODE)
	check(r == "ok" and fb.store.has("users/dave/mail/ref_welcome"), "başka telefonda yeni hesap: ok")
	await close_session()


func _inviter() -> void:
	print("== 4) Davet eden ==")
	await open_session("alice", true)
	await until(func() -> bool: return fb.store.has("users/alice/referral/ref_owner"), 3.0)
	var owner: Dictionary = fb.store.get("users/alice/referral/ref_owner", {})
	check(SaveSafe.s(owner.get("dev", "")) == ref().device_hash(), "oturumda bu telefonun özeti yazıldı (ref_owner)")
	var ok: bool = await ref().load_progress(true)
	check(ok and ref().count == 1 and ref().joined_total == 2, "sayaç: 2 katıldı, 1 sayıldı")
	check(ref().invited.size() == 2 and ref().invited[0]["uid"] == "bob" and ref().invited[0]["state"] == "qualified"
		and int(ref().invited[0]["tier"]) == 1 and ref().invited[1]["uid"] == "dave" and ref().invited[1]["state"] == "joined",
		"liste: bob sayıldı (1. basamak), dave katıldı")
	check(ref().tiers_reached() == 1, "merdivende 1 basamak")
	var reads: int = fb.calls.size()
	await ref().load_progress()
	check(fb.calls.size() == reads, "yeni okuma %d sn içinde tekrarlanmaz" % int(ReferralManager.REFRESH_MIN_SEC))
	# Aynı telefonda yeni hesapla kendini davet: cihaz özeti davet edeninkiyle aynı
	var phone: String = ref().device_hash()
	await close_session()
	fb.age_days["alt"] = 0
	await open_session("alt", false)
	ref().device_override = ""
	check(ref().device_hash() == phone, "aynı telefon aynı özet")
	fb.store.erase("ref_devices/" + phone)   # bu telefon daha önce davetle gelmemiş olsun
	var r: String = await ref().submit_code(CODE)
	check(r == "self", "davet edenin telefonunda ikinci hesap: self")
	await close_session()


func _tier_mail() -> void:
	print("== 5) Basamak postaları ==")
	for n: int in [2, 5, 10]:
		fb.store["users/alice/mail/ref_%d" % n] = (ReferralRewards.tier(n) as Dictionary).merged(
			{"title": {"tr": str(n)}, "at": 600 + n, "referral": "tier_%d" % n, "friend": "bob"})
	await open_session("alice", true)
	var mail: MailService = w["mail"]
	await until(func() -> bool: return mail.pending().size() >= 4, 4.0)
	var ready: Array[int] = ref().ready_tiers()
	ready.sort()
	check(ready == [1, 2, 5, 10] and ref().attention() == 4, "AL bekleyen basamaklar 1, 2, 5, 10 (ARKADAŞLAR rozeti 4)")
	var eco: EconomyManager = w["eco"]
	var money0: int = eco.money
	var summary: Dictionary = mail.claim("ref_2")
	var expected: int = ReferralRewards.money_for(12, LoginLadder.FALLBACK_INCOME)
	check(eco.money == money0 + expected and int(summary["money"]) == expected,
		"gelir dakikası: 12 dk × aktif gelir = %d ₺" % expected)
	var profile: PlayerProfile = w["profile"]
	check(not profile.frame_unlocked("inviter"), "DAVETÇİ çerçevesi önce kilitli")
	summary = mail.claim("ref_5")
	check(profile.frame_unlocked("inviter") and profile.frames_owned.has("inviter") and profile.frame_id != "inviter",
		"5. basamak: DAVETÇİ çerçevesi verildi (takılmadı)")
	check((summary["items"] as Array).any(func(s: String) -> bool: return s.contains("DAVETÇİ ÇERÇEVESİ")), "ödül penceresinde çerçeve")
	check(profile.set_frame("inviter"), "verilen çerçeve takılır")
	summary = mail.claim("ref_10")
	check(ref().car_choices == 1 and summary.get("choice") == ReferralRewards.CHOICE_LEGENDARY and profile.frames_owned.has("envoy"),
		"10. basamak: efsanevi araç seçme hakkı + ELÇİ")
	check(ref().ready_tiers() == [1] and ref().attention() == 2, "alınanlar düştü; seçim hakkı rozette (1 posta + 1 hak)")
	var pool: Array[StringName] = ref().car_pool()
	var own: VehicleOwnership = w["own"]
	check(not ref().choose_car(&"tofas_sahin"), "havuz dışı araç seçilemez")
	check(ref().choose_car(pool[0]) and own.is_owned(pool[0]) and ref().car_choices == 0, "seçilen araç verildi: %s" % pool[0])
	check(not ref().car_pool().has(pool[0]) and not ref().choose_car(pool[1]), "sahip olunan havuzdan düşer, hak bitince seçilemez")
	ref().add_car_choice()
	for id: StringName in ref().car_pool():
		own.add_vehicle(id)
	var gems0: int = (w["prog"] as PlayerProgress).gems
	check(ref().car_pool().is_empty() and ref().take_fallback()
		and (w["prog"] as PlayerProgress).gems == gems0 + ReferralRewards.LEGENDARY_FALLBACK_GEMS and ref().car_choices == 0,
		"havuzun hepsine sahipse %d GEM" % ReferralRewards.LEGENDARY_FALLBACK_GEMS)
	await close_session()


func _save_state() -> void:
	print("== 6) Kayıt ==")
	var node: ReferralManager = ReferralManager.new()
	node.load_state({"status": "ok", "referrer": "alice", "lvl3": true, "owner": "a".repeat(64), "car_choices": 2})
	var copy: Dictionary = node.state()
	check(copy == {"status": "ok", "referrer": "alice", "lvl3": true, "owner": "a".repeat(64), "car_choices": 2}, "durum geri yüklenir")
	node.load_state({"status": "hack", "referrer": "x", "lvl3": "evet", "owner": "kısa", "car_choices": 99})
	check(node.status == "" and node.referrer == "" and node.state()["owner"] == "" and node.car_choices == 10,
		"bozuk kayıt: bilinmeyen sonuç atılır, hak sınırlı")
	node.reset()
	check(node.state() == {"status": "", "referrer": "", "lvl3": false, "owner": "", "car_choices": 0}, "sıfırlama")
	node.free()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://savegame.json"))
	check(saved is Dictionary and (saved as Dictionary).has("referral"), "kayıt dosyasında \"referral\" bölümü")
