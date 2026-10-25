extends SceneTree
## POSTA KUTUSU (MailService + MailNotice) — sahte Firebase ile, izole user:// klasöründe.
##   tools/run_tests.sh mail_test
## 1) Belgenin süzülmesi (sınırlar, katalogda olmayan kasa / eşya, araç / kaplama verilmez, dil yedeği).
## 2) Misafir posta okumaz; hesaplı oyuncu bulut eşitlenince listeler, süresi dolan posta ödülsüz silinir, sıra eskiden yeniye.
## 3) AL: ₺ / elmas / kasa / eşya hesaba geçer, kimlik kayda yazılır, belge silinir; silme başarısızsa ödül ikinci kez
##    verilmez (sonraki listede belge silinir); aynı kimlik yeniden gönderilse de kayıtta olduğu için verilmez.
## 4) Hesap değişince yalnız o hesabın postası. 5) HUD penceresi (Main.tscn): oyun sakinken açılır, AL → ödül penceresi.

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
	## Sunucunun kupon doğrulaması (functions/promo.js taklidi): KOD → {gems, max_uses, uses}
	var promo: Dictionary = {}

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
		# Gerçek eklenti gibi: koleksiyon okuması iç içe alanları çevirmez (motorda JavaObject olur); get çevirir
		var data: Dictionary = {}
		for path: String in store:
			if path.get_base_dir() == col:
				var doc: Dictionary = {}
				for field: Variant in store[path]:
					var value: Variant = (store[path] as Dictionary)[field]
					doc[field] = RefCounted.new() if value is Dictionary or value is Array else value
				data[path.get_file()] = doc
		_later("firestore_get_task_completed", {"status": true, "data": data})

	## firestore.rules (sadeleştirilmiş): oyuncu kendi kaydını ve garajını yazar; POSTAYI istemci HİÇ yazamaz.
	func firestoreSetDocument(col: String, id: String, data: Dictionary, _merge: bool) -> void:
		calls.append("set %s/%s" % [col, id])
		if not online:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "offline"})
			return
		var me: String = uid()
		var ok: bool = (col == "players" and id == me) or (col == "garages" and id == "g_" + me) \
			or (col == "codes" and SaveSafe.s(data.get("uid", "")) == me and not store.has(col + "/" + id)) \
			or (col == "players/%s/history" % me and RegEx.create_from_string("^(h([01][0-9]|2[0-3])|d[0-6])$").search(id) != null) \
			or (col == "users/%s/redeem" % me and not store.has(col + "/" + id) and data.keys() == ["at"])
		if not ok:
			_later("firestore_write_task_completed", {"status": false, "docID": id, "error": "PERMISSION_DENIED: Missing or insufficient permissions."})
			return
		store[col + "/" + id] = data.duplicate(true)
		_later("firestore_write_task_completed", {"status": true, "docID": id})
		if col.ends_with("/redeem"):
			_redeem(me, id)

	## promo.js taklidi: sonuç belgeye, ödül postaya (biraz gecikmeyle: tetikleyici gibi)
	func _redeem(me: String, code: String) -> void:
		await tree.create_timer(0.3).timeout
		var path: String = "users/%s/redeem/%s" % [me, code]
		var status: String = "not_found"
		if promo.has(code):
			var p: Dictionary = promo[code]
			if (p.get("used", []) as Array).has(me):
				status = "already"
			elif int(p["max_uses"]) > 0 and int(p["uses"]) >= int(p["max_uses"]):
				status = "used_up"
			else:
				status = "ok"
				p["uses"] = int(p["uses"]) + 1
				p["used"] = (p.get("used", []) as Array) + [me]
				store["users/%s/mail/p_%s" % [me, code.to_lower()]] = {"title": {"tr": "Kupon ödülü"}, "gems": int(p["gems"]), "at": 900}
		(store[path] as Dictionary).merge({"status": status, "title": {"tr": "Kupon ödülü"}}, true)

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
var crate_id: StringName = &""
var decor_id: StringName = &""
var car_id: StringName = &""       # edinilebilir bir araç (araç hediyesi)
var other_car: StringName = &""
var locked_car: StringName = &""   # edinilemeyen (polis gibi)


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
	crate_id = StringName(String(CrateCatalog.all()[0]["id"]))
	for entry: Dictionary in CarCatalog.all():
		var id: StringName = StringName(String(entry.get("id", "")))
		if CarCatalog.is_obtainable(id):
			if car_id == &"":
				car_id = id
			elif other_car == &"":
				other_car = id
		elif locked_car == &"":
			locked_car = id
	for item: Dictionary in GarageDecor.all():
		var id: StringName = StringName(String(item.get("id", "")))
		if GarageDecor.is_placeable(id) and not GarageDecor.is_exclusive(id) and not GarageDecor.is_gem_item(id):
			decor_id = id
			break
	_normalize()
	await _guest()
	await _account()
	await _support()
	await _promo()
	await _hud_popup()
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func _normalize() -> void:
	print("== 1) Belgenin süzülmesi ==")
	var mail: Dictionary = MailService.normalize("m1", {
		"title": {"tr": "Hoş geldin!", "en": "Welcome!"}, "text": "Garajına hediye.", "from": "AUTO YARD",
		"money": 999_999_999, "gems": -5, "crates": {String(crate_id): 3, "yok_boyle_kasa": 1},
		"decor": {String(decor_id): 2, "floor_tile": 1, "yok_boyle_esya": 1}, "at": 7})
	check(int(mail["money"]) == MailService.MAX_MONEY and int(mail["gems"]) == 0, "₺ üst sınırla, eksi elmas 0")
	check((mail["crates"] as Dictionary).size() == 1 and int(mail["crates"][crate_id]) == 3, "katalogda olmayan kasa atılır")
	check((mail["decor"] as Dictionary).size() == 1 and int(mail["decor"][decor_id]) == 2,
		"kaplama (floor_tile) ve katalogda olmayan eşya atılır")
	check(mail["title"] == "Hoş geldin!" and mail["text"] == "Garajına hediye.", "dil sözlüğü / düz metin")
	check(MailService.normalize("m2", {"money": 0}).is_empty(), "metinsiz, ödülsüz posta yok sayılır")
	var cars: Dictionary = MailService.normalize("m_car", {"title": "Araç", "cars": {String(car_id): 1, String(locked_car): 1,
		"yok_boyle_arac": 1, String(other_car): 0}})
	check(cars["cars"] == [car_id] and MailService.has_reward(cars), "araç: edinilemeyen / bilinmeyen / adedi 0 atılır")
	check(MailService.normalize("m_car2", {"title": "Araç", "cars": [String(car_id), String(car_id)]})["cars"] == [car_id],
		"araç listesi de olur, aynı araç bir kez")
	check(not MailService.normalize("m3", {"text": "Sadece mesaj"}).is_empty()
		and not MailService.has_reward(MailService.normalize("m3", {"text": "Sadece mesaj"})), "ödülsüz mesaj geçer")
	check(MailService.normalize("m4", {"crates": {String(crate_id): 99}})["crates"][crate_id] == MailService.MAX_COUNT,
		"adet sınırı (%d)" % MailService.MAX_COUNT)


func open_session(account: String, fresh_device: bool = true, sign_in: bool = true) -> void:
	if fresh_device:
		for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
			DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
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
	var save: SaveManager = SaveManager.new()
	var cloud: CloudSaveManager = CloudSaveManager.new()
	var social: SocialManager = SocialManager.new()
	var mail: MailService = MailService.new()
	social.use_firebase(fb)
	social.request_timeout = 1.0
	for n: Node in [eco, prog, upg, own, decor, crates, mail, save, cloud, social]:
		root_node.add_child(n)
	root.add_child(root_node)
	cloud._fb = fb
	fb.auth_success.connect(cloud._on_auth_success)
	fb.auth_failure.connect(cloud._on_auth_failure)
	fb.sign_out_success.connect(cloud._on_sign_out_result)
	fb.firestore_get_task_completed.connect(cloud._on_get_completed)
	fb.firestore_write_task_completed.connect(cloud._on_write_completed)
	fb.firestore_delete_task_completed.connect(cloud._on_delete_completed)
	w = {"root": root_node, "eco": eco, "prog": prog, "decor": decor, "crates": crates, "save": save, "cloud": cloud,
		"social": social, "mail": mail}
	await frames(6)
	if not sign_in:
		return
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


func mail() -> MailService:
	return w["mail"]


func gift(over: Dictionary = {}) -> Dictionary:
	var doc: Dictionary = {"title": {"tr": "Açılış hediyesi"}, "text": {"tr": "Hoş geldin usta!"}, "from": "AUTO YARD",
		"money": 1500, "gems": 40, "crates": {String(crate_id): 1}, "decor": {String(decor_id): 2}, "at": 100}
	doc.merge(over, true)
	return doc


func _guest() -> void:
	print("== 2a) Misafir ==")
	fb.store["users/alice/mail/m_guest"] = gift()
	await open_session("alice", true, false)
	mail().poll()
	await seconds(0.3)
	check(mail().pending().is_empty() and not fb.calls.any(func(c: String) -> bool: return c.contains("/mail")),
		"misafir posta listelemez (hediye yalnız hesaplıya)")
	await close_session()
	fb.store.erase("users/alice/mail/m_guest")


func _account() -> void:
	print("== 2b) Hesaplı oyuncu ==")
	var now: int = int(Time.get_unix_time_from_system())
	fb.store["users/alice/mail/m_gift"] = gift({"at": 200})
	fb.store["users/alice/mail/m_note"] = {"text": {"tr": "Yeni sürüm yarın!"}, "at": 100}
	fb.store["users/alice/mail/m_old"] = gift({"expires": now - 60, "at": 50})
	fb.store["users/bob/mail/m_bob"] = gift({"gems": 7})
	await open_session("alice")
	await until(func() -> bool: return mail().pending().size() == 2)
	var ids: Array = mail().pending().map(func(m: Dictionary) -> String: return m["id"])
	check(ids == ["m_note", "m_gift"], "senkrondan sonra listelendi, eskisi önde (%s)" % str(ids))
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_old"))
	check(not fb.store.has("users/alice/mail/m_old"), "süresi dolan posta ödülsüz silindi")

	print("== 3) AL ==")
	var eco: EconomyManager = w["eco"]
	var prog: PlayerProgress = w["prog"]
	var decor: DecorManager = w["decor"]
	var crates: CrateManager = w["crates"]
	var money0: int = eco.money
	var gems0: int = prog.gems
	var crates0: int = crates.crates().size()
	var decor0: int = decor.owned_of(decor_id)
	var summary: Dictionary = mail().claim("m_gift")
	check(eco.money == money0 + 1500 and prog.gems == gems0 + 40, "₺ ve elmas hesaba geçti")
	check(crates.crates().size() == crates0 + 1 and decor.owned_of(decor_id) == decor0 + 2, "kasa + 2 eşya (depoya)")
	check(int(summary.get("money", 0)) == 1500 and int(summary.get("gems", 0)) == 40
		and summary.get("items", []) == ["+1 %s" % MailService.crate_name(crate_id), "+2 %s" % MailService.decor_name(decor_id)],
		"ödül penceresi özeti (adetli satırlar)")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://savegame.json"))
	check(((saved.get("mail", {}) as Dictionary).get("claimed", {}) as Dictionary).has("m_gift"), "alınan kimlik kayıtta")
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_gift"))
	check(not fb.store.has("users/alice/mail/m_gift"), "belge silindi")
	check(mail().claim("m_gift").is_empty() and eco.money == money0 + 1500, "ikinci AL bir şey vermez")
	var note: Dictionary = mail().claim("m_note")
	check(note.is_empty() and mail().pending().is_empty(), "ödülsüz mesaj okununca kapanır (ödül penceresi yok)")
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_note"))

	print("== 3b) Silme başarısız → ikinci kez verilmez ==")
	fb.store["users/alice/mail/m_net"] = gift({"money": 300, "gems": 0, "crates": {}, "decor": {}})
	mail().poll()
	await until(func() -> bool: return mail().pending().size() == 1)
	fb.online = false
	var money1: int = eco.money
	mail().claim("m_net")
	await seconds(0.3)
	check(eco.money == money1 + 300 and fb.store.has("users/alice/mail/m_net"), "çevrimdışı: ödül verildi, belge duruyor")
	fb.online = true
	mail().poll()
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_net"))
	check(not fb.store.has("users/alice/mail/m_net") and mail().pending().is_empty() and eco.money == money1 + 300,
		"internet gelince belge silindi, ödül tekrar verilmedi")
	await close_session()

	print("== 3c) Aynı kimlik yeniden gönderilirse (yeni açılış) ==")
	fb.store["users/alice/mail/m_gift"] = gift({"at": 300})
	await open_session("alice", false)
	var money2: int = (w["eco"] as EconomyManager).money
	await seconds(0.5)
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_gift"))
	check(mail().pending().is_empty() and (w["eco"] as EconomyManager).money == money2, "kayıttaki kimlik: verilmez, belge silinir")
	await close_session()

	print("== 4) Başka hesap ==")
	await open_session("bob")
	await until(func() -> bool: return mail().pending().size() == 1)
	check(mail().pending().size() == 1 and mail().pending()[0]["id"] == "m_bob", "bob yalnız kendi postasını görür")
	await close_session()
	fb.store.erase("users/bob/mail/m_bob")


func _support() -> void:
	print("== 6) Destek: bakiye düzeltme, kayıt geçmişi, geri yükleme ==")
	await open_session("alice")
	var eco: EconomyManager = w["eco"]
	var prog: PlayerProgress = w["prog"]
	var cloud: CloudSaveManager = w["cloud"]
	var mission_spent: Array[int] = []
	eco.money_spent.connect(func(amount: int) -> void: mission_spent.append(amount))
	eco.set_money(1000)
	prog.add_gems(-prog.gems + 30)
	fb.store["users/alice/mail/m_adj"] = {"title": {"tr": "Hesap düzeltmesi"}, "text": {"tr": "Hile iadesi"},
		"adjust": {"money": -400, "gems": -50}, "at": 400}
	fb.store["users/alice/mail/m_plus"] = {"title": {"tr": "Hesap düzeltmesi"}, "adjust": {"money": 250, "gems": 5}, "at": 401}
	mail().poll()
	await until(func() -> bool: return mail().pending().size() == 2)
	var adj: Dictionary = mail().pending()[0]
	check(adj["id"] == "m_adj" and not MailService.has_reward(adj) and int(adj["adjust"]["money"]) == -400,
		"eksi düzeltme: ödül sayılmaz (TAMAM)")
	check(MailService.has_reward(mail().pending()[1]), "artı düzeltme: AL")
	check(mail().claim("m_adj").is_empty() and eco.money == 600 and prog.gems == 0, "eksi düzeltme uygulandı, elmas 0'da durdu")
	check(mission_spent.is_empty(), "düzeltme harcama sayılmadı (görev sayaçları)")
	var plus: Dictionary = mail().claim("m_plus")
	check(eco.money == 850 and prog.gems == 5 and int(plus.get("money", 0)) == 250 and int(plus.get("gems", 0)) == 5,
		"artı düzeltme: hesaba geçti, ödül penceresinde görünür")

	print("== 6b) Kayıt geçmişi ==")
	eco.add_money(7)
	await until(func() -> bool: return fb.store.keys().any(func(k: String) -> bool: return k.begins_with("players/alice/history/h")), 4.0)
	var now: int = int(Time.get_unix_time_from_system())
	var hour_slot: String = "players/alice/history/h%02d" % ((now / 3600) % 24)
	var day_slot: String = "players/alice/history/d%d" % ((now / 86400) % 7)
	check(fb.store.has(hour_slot) and fb.store.has(day_slot), "başarılı yazmadan sonra saat + gün dilimi yazıldı")
	var hist: Dictionary = fb.store.get(hour_slot, {})
	var hist_money: int = int((hist.get("stats", {}) as Dictionary).get("money", -1))
	var hist_save: Variant = JSON.parse_string(CloudPack.unpack(SaveSafe.s(hist.get("save_json", ""))))
	check(SaveSafe.s(hist.get("save_json", "")).begins_with(CloudPack.PREFIX) and hist_save is Dictionary
		and int(((hist_save as Dictionary).get("economy", {}) as Dictionary).get("money", -2)) == hist_money,
		"geçmiş: sıkışık kayıt + tutarlı özet (saatin ilk yazması, %d ₺)" % hist_money)
	var history_writes: int = fb.calls.filter(func(c: String) -> bool: return c.contains("/history ")).size()
	eco.add_money(1)
	await seconds(2.2)
	check(fb.calls.filter(func(c: String) -> bool: return c.contains("/history ")).size() == history_writes, "aynı saat içinde yeniden yazılmaz")

	print("== 6c) Geri yükleme ==")
	var old_save: String = SaveSafe.s(hist["save_json"])
	eco.set_money(99999)
	(w["save"] as SaveManager).save_game()
	fb.store["users/alice/mail/m_restore"] = {"title": {"tr": "Kaydın geri yüklendi"}, "restore": {"save_json": old_save, "at": now}, "at": 500}
	mail().poll()
	await until(func() -> bool: return mail().pending().size() == 1)
	check(mail().pending()[0]["id"] == "m_restore" and not (mail().pending()[0]["restore"] as Dictionary).is_empty(), "geri yükleme postası geldi")
	mail().claim("m_restore")
	await frames(3)
	check(eco.money == hist_money, "kayıt geçmişteki hâline döndü (99999 → %d)" % hist_money)
	var backup: Variant = JSON.parse_string(FileAccess.get_file_as_string("user://savegame.before_cloud.json"))
	check(backup is Dictionary and int(((backup as Dictionary).get("economy", {}) as Dictionary).get("money", -1)) == 99999, "şimdiki kayıt cihazda yedeklendi")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://savegame.json"))
	check(((saved.get("mail", {}) as Dictionary).get("claimed", {}) as Dictionary).has("m_restore"), "postanın kimliği geri yüklenen kayıtta (ikinci kez uygulanmaz)")
	await until(func() -> bool: return not fb.store.has("users/alice/mail/m_restore"))
	check(not fb.store.has("users/alice/mail/m_restore"), "geri yükleme postası silindi")
	await close_session()


func _promo() -> void:
	print("== 7) Kupon kodu ==")
	check(PromoService.normalize(" reels-50 ") == "REELS50" and PromoService.is_valid("REELS50") and not PromoService.is_valid("AB"),
		"kod biçimi (büyük harf, tire / boşluk atılır, 4–16)")
	fb.promo = {"REELS50": {"gems": 50, "max_uses": 1, "uses": 0}}
	await open_session("alice")
	var r: Dictionary = await PromoService.redeem(self, "reels50")
	check(r.get("status") == "ok", "geçerli kod: ok")
	await until(func() -> bool: return mail().pending().any(func(m: Dictionary) -> bool: return m["id"] == "p_reels50"), 4.0)
	check(mail().pending().any(func(m: Dictionary) -> bool: return m["id"] == "p_reels50" and int(m["gems"]) == 50),
		"ödül postaya düştü (posta hemen okundu)")
	r = await PromoService.redeem(self, "REELS50")
	check(r.get("status") == "already", "aynı kod ikinci kez: zaten kullandın (belge yeniden yazılamaz)")
	r = await PromoService.redeem(self, "YOKBOYLE")
	check(r.get("status") == "not_found", "olmayan kod")
	r = await PromoService.redeem(self, "a!")
	check(r.get("status") == "invalid" and not fb.calls.any(func(c: String) -> bool: return c.contains("redeem a")), "biçimsiz kod sunucuya gitmez")
	check(PromoService.status_text("ok").contains("POSTA") and PromoService.status_text("used_up") != PromoService.status_text("ok"), "sonuç metinleri")
	await close_session()
	await open_session("bob")
	r = await PromoService.redeem(self, "REELS50")
	check(r.get("status") == "used_up", "başka hesap, sınır dolu: used_up")
	await close_session()
	fb.user = {}


func _hud_popup() -> void:
	print("== 5) HABERLER kutusu (HUD) ==")
	for f: String in ["savegame.json", "cloud_sync.json", "social.json"]:
		DirAccess.remove_absolute(OS.get_user_data_dir().path_join(f))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var hud: Hud = main.find_child("HUD", true, false) as Hud
	var service: MailService = get_first_node_in_group("mail") as MailService
	var notice: MailNotice = hud.mail_notice
	check(service != null and notice != null and hud.inbox != null and hud.inbox_screen != null and hud.inbox_button != null,
		"MailService + HABERLER tabelası ve kutusu kurulu")
	if service == null or notice == null or hud.inbox == null:
		return
	check(hud.inbox_button.get_parent() == hud.camera_button.get_parent()
		and hud.inbox_button.get_index() == hud.camera_button.get_index() + 1, "tabela kameranın hemen sağında")
	var economy: EconomyManager = get_first_node_in_group("economy")
	var money0: int = economy.money
	service._pending = [MailService.normalize("m_ui", gift({"money": 2500, "gems": 0}))]
	service.arrived.emit()
	await frames(3)
	check(hud.inbox_button.badge == 1, "rozette 1 (alınmamış hediye)")
	await seconds(2.5)
	check(hud.router.top() == &"", "posta penceresi kendiliğinden açılmaz (kullanıcı kararı)")
	hud.router.open(&"inbox")
	await seconds(0.5)
	var screen: InboxScreen = hud.inbox_screen
	check(screen.visible and screen.selected() == "m_ui", "kutu açıldı, alınmamış hediye seçili")
	var texts: String = " ".join(screen.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(texts.contains("Açılış hediyesi") and texts.contains("Hoş geldin usta!") and texts.contains("AUTO YARD"),
		"başlık, mesaj, gönderen")
	var button: PlateButton = screen.find_child("ActionButton", true, false) as PlateButton
	check(button != null and button.visible and button.text == Loc.t("AL"), "ödüllü postada AL")
	button.pressed.emit()
	await seconds(0.5)
	var gift: GiftScreen = notice.gift_screen()
	check(economy.money == money0 + 2500, "AL: ₺ hesaba geçti (%d → %d)" % [money0, economy.money])
	check(gift != null and gift.visible and gift.get_index() > screen.get_index(), "HEDİYEN GELDİ! ekranı kutunun üstünde açıldı")
	var gift_cards: HBoxContainer = gift.get("_cards")
	check(gift_cards.get_child_count() == 2 and (gift.get("_money_label") as Label).text == "+2.500 ₺",
		"kartlar: kasa + dekor (%d), ₺ hapı" % gift_cards.get_child_count())
	(gift.find_child("CollectButton", true, false) as PlateButton).pressed.emit()
	await seconds(0.5)
	check(not gift.visible, "TOPLA: ekran kapandı")
	check(bool(hud.inbox.item("m_ui").get("claimed", false)) and hud.inbox_button.badge == 0, "hediye ALINDI, rozet söndü")
	check(not service.history().is_empty() and service.history()[0]["id"] == "m_ui" and int(service.history()[0]["money"]) == 2500,
		"geçmişte ödülüyle duruyor")
	check(not button.visible, "alınmış hediyede düğme yok")

	print("-- araç hediyesi --")
	var ownership: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	if ownership.is_owned(car_id):
		ownership.remove_vehicle(car_id)
	var owned_before: bool = ownership.is_owned(car_id)
	service._pending = [MailService.normalize("m_car", {"title": {"tr": "Araç hediyesi"}, "cars": {String(car_id): 1}})]
	service.arrived.emit()
	await frames(2)
	screen.select("m_car")
	await frames(2)
	button.pressed.emit()
	await seconds(0.5)
	check(not owned_before and ownership.is_owned(car_id), "araç garaja eklendi")
	var labels: String = " ".join(gift.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(gift.visible and gift_cards.get_child_count() == 1 and labels.contains(MailService.car_name(car_id)),
		"HEDİYEN GELDİ!: araç kartı (%s)" % MailService.car_name(car_id))
	check(gift_cards.get_child(0).find_children("*", "TextureRect", true, false).any(
		func(n: Node) -> bool: return (n as TextureRect).texture != null), "kartta aracın fotoğrafı")
	gift.close()
	await seconds(0.5)
	var money1: int = economy.money
	service._pending = [MailService.normalize("m_car_again", {"title": {"tr": "Yine aynı araç"}, "cars": {String(car_id): 1}})]
	service.arrived.emit()
	await frames(2)
	screen.select("m_car_again")
	await frames(2)
	button.pressed.emit()
	await seconds(0.5)
	check(economy.money == money1 + ownership.sell_price(car_id), "zaten olan araç: satış değeri ₺ (+%d)" % ownership.sell_price(car_id))
	labels = " ".join(gift.find_children("*", "Label", true, false).map(func(n: Node) -> String: return (n as Label).text))
	check(labels.contains(Loc.t("ZATEN VARDI · +%s ₺").split(" ·")[0]), "kartta ZATEN VARDI")
	gift.close()
	await seconds(0.5)
	main.queue_free()
	await frames(4)
