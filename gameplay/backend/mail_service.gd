class_name MailService
extends Node
## POSTA KUTUSU (2026-10-21): yönetim panelinin (firebase/admin) gönderdiği hediye / mesaj. Sunucu users/{uid}/mail/{id}
## belgesini yazar (istemci yazamaz, firestore.rules); oyun oturum açıkken listeler: bulut senkronu bitince, öne gelince
## ve POLL_SEC'te bir. Yalnızca HESAPLI oyuncu (kullanıcı kararı 2026-10-21: misafirin UID'si yok). Belge:
##   {title, text: dil sözlüğü ya da düz metin, from: gönderen adı, money, gems, crates: {kasa: adet},
##    decor: {eşya: adet}, at, expires (unix sn, 0 = süresiz)}
## Akış: yeni posta → `arrived` → HUD oyun sakinken POSTA penceresini açar (MailNotice) → AL → claim(): ödül hesaba
## geçer, kimlik kayda yazılır (SaveManager "mail") → kayıt diske → belge silinir. Silme başarısız olsa da kimlik
## kayıtta olduğundan ödül ikinci kez verilmez; sonraki listede belge yeniden silinir. Süresi dolan posta ödülsüz silinir.
## Değerler istemcide de sınırlanır (MAX_*): panelde yanlış yazılmış bir sıfır oyunu bozmasın.
## ARKADAŞ DAVETİ postaları (2026-10-23, functions/referral.js): money_min (₺ = oyuncunun o anki aktif gelirinin dakikası,
## ReferralRewards.money_for), frame (yalnız verilen profil çerçevesi, PlayerProfile.grant_frame), choice "legendary_car"
## (efsanevi araç seçme hakkı ReferralManager'a eklenir; oyuncu sonra seçer, hak kayıtta durur).
## DESTEK postaları (2026-10-21): adjust {money, gems} BAKİYE DÜZELTMESİ (eksi de olabilir, 0'ın altına inmez; harcama
## sayılmaz) ve restore {save_json, at} KAYIT GERİ YÜKLEME (AL → CloudSaveManager.restore_snapshot: kayıt o hâline döner,
## dünya yeniden kurulur; postanın kimliği geri yüklenen kayda da yazılır, ikinci kez uygulanmaz).
## Firestore'a SocialManager'ın sıralı kuyruğuyla gider (list_mail / delete_mail). GarageSystem kurar; ziyarette yok.

## Yeni (alınmamış) postalar geldi: pencere sırası güncellendi.
signal arrived

const POLL_SEC: float = 600.0
## Öne gelince (ör. "hediyen var" bildirimine dokunup dönünce) son okumadan bu kadar geçtiyse hemen okunur.
const RESUME_SEC: float = 15.0
## Kayıtta tutulan alınmış kimlik sayısı (eskiler düşer; belge çoktan silinmiş olur).
const KEEP_CLAIMED: int = 200
const MAX_MONEY: int = 50_000_000
const MAX_GEMS: int = 50_000
const MAX_COUNT: int = 20

var _social: SocialManager
var _cloud: CloudSaveManager
var _save: SaveManager
var _claimed: Dictionary = {}     # kimlik → alındığı unix sn (kayıtta)
var _pending: Array[Dictionary] = []   # alınmamış postalar (normalize edilmiş, eskisi önde)
var _busy: bool = false
var _last_poll: float = -1.0e9
var _polled_uid: String = ""      # son okunan hesabın UID'si: sosyal oturum yeni açıldıysa hemen okunur
var _timer: Timer


func _ready() -> void:
	add_to_group("mail")
	_timer = Timer.new()
	_timer.wait_time = POLL_SEC
	_timer.timeout.connect(poll)
	add_child(_timer)
	_timer.start()
	_connect.call_deferred()


func _connect() -> void:
	_social = get_tree().get_first_node_in_group("social") as SocialManager
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	_save = get_tree().get_first_node_in_group("save_manager") as SaveManager
	# Sosyal oturum (UID) bulut SYNCED olduktan SONRA açılır: o anda okumak boşa düşerdi. Oturum açılınca / hesap
	# değişince hemen, sonra POLL_SEC'te bir okunur (changed sık yayılır: aynı hesap için yeniden okunmaz).
	if _social:
		_social.changed.connect(func() -> void:
			if _social.uid() != _polled_uid:
				poll())
	if _cloud:
		_cloud.state_changed.connect(func(state: CloudSaveManager.State) -> void:
			if state == CloudSaveManager.State.SYNCED:
				poll.call_deferred())
		_cloud.user_changed.connect(func(_profile: Dictionary) -> void:
			_pending.clear()
			arrived.emit())
	poll()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_RESUMED and Time.get_ticks_msec() / 1000.0 - _last_poll > RESUME_SEC:
		poll()


## Bekleyen (alınmamış) postalar, eskisi önde: {id, title, text, from, money, gems, crates, decor}.
func pending() -> Array[Dictionary]:
	return _pending


## Postaları okur. Kayıt bulutla eşitlenmeden okunmaz (alınmış kimlikler o kayıtta).
func poll() -> void:
	if _busy or _social == null or _social.uid().is_empty():
		return
	if _cloud == null or _cloud.get_state() != CloudSaveManager.State.SYNCED:
		return
	_busy = true
	_last_poll = Time.get_ticks_msec() / 1000.0
	var uid: String = _social.uid()
	var result: Dictionary = await _social.list_mail()
	_busy = false
	if not is_inside_tree() or not bool(result.get("ok", false)) or uid != _social.uid():
		return   # sahne yenilendi, hata ya da okurken hesap değişti
	_polled_uid = uid
	var docs: Dictionary = result.get("docs", {})
	var now: int = int(Time.get_unix_time_from_system())
	var fresh: Array[Dictionary] = []
	var stale: Array[String] = []
	for key: Variant in docs:
		var id: String = SaveSafe.s(key)
		var doc: Dictionary = docs[key] if docs[key] is Dictionary else {}
		var expires: int = SaveSafe.i(doc.get("expires", 0))
		if _claimed.has(id) or (expires > 0 and now > expires):
			stale.append(id)   # alınmış (silme önceden başarısız olmuş) ya da süresi dolmuş
			continue
		var mail: Dictionary = normalize(id, doc)
		if not mail.is_empty():
			fresh.append(mail)
	fresh.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	var changed: bool = fresh.size() != _pending.size()
	for i: int in mini(fresh.size(), _pending.size()):
		changed = changed or fresh[i]["id"] != _pending[i]["id"]
	_pending = fresh
	if changed:
		arrived.emit()
	for id: String in stale:
		await _social.delete_mail(id)


## Postayı alır: ödül hesaba geçer, kimlik kayda yazılır, kayıt diske, sonra belge silinir. Dönüş: RewardPopup özeti
## ({title, money, gems, items: ["+2 TAKIM DOLABI", …]}); ödülsüz mesajda ya da posta yoksa boş.
func claim(id: String) -> Dictionary:
	var index: int = -1
	for i: int in _pending.size():
		if _pending[i]["id"] == id:
			index = i
	if index < 0 or _claimed.has(id):
		return {}
	var mail: Dictionary = _pending[index]
	_pending.remove_at(index)
	if not (mail["restore"] as Dictionary).is_empty():
		return _restore(id, mail["restore"])
	var summary: Dictionary = _grant(mail)
	_claimed[id] = int(Time.get_unix_time_from_system())
	_trim_claimed()
	if _save:
		_save.save_game()
	if _social:
		_social.delete_mail(id)   # sonucu beklenmez: başarısızsa sonraki listede yeniden silinir
	return summary


func _grant(mail: Dictionary) -> Dictionary:
	var tree: SceneTree = get_tree()
	var names: Array = []
	var money: int = int(mail["money"])
	var gems: int = int(mail["gems"])
	money += income_money(tree, int(mail["money_min"]))
	var economy: EconomyManager = tree.get_first_node_in_group("economy") as EconomyManager
	if economy and money > 0:
		economy.add_money(money)
	var progress: PlayerProgress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	if progress and gems > 0:
		progress.add_gems(gems)
	# Bakiye düzeltmesi: artı ödül gibi uçar, eksi sessizce düşer (POSTA penceresi miktarı zaten gösterdi)
	var adjust: Dictionary = mail["adjust"]
	var adjust_money: int = int(adjust.get("money", 0))
	var adjust_gems: int = int(adjust.get("gems", 0))
	if economy and adjust_money != 0:
		if adjust_money > 0:
			economy.add_money(adjust_money)
		else:
			economy.set_money(maxi(economy.money + adjust_money, 0))   # spend_money değil: harcama sayılmasın
	if progress and adjust_gems != 0:
		progress.add_gems(adjust_gems)   # eksi: 0'da durur
	money += maxi(adjust_money, 0)
	gems += maxi(adjust_gems, 0)
	var crates: CrateManager = tree.get_first_node_in_group("crates") as CrateManager
	var crate_map: Dictionary = mail["crates"]
	for crate_id: StringName in crate_map:
		var given: int = 0
		for i: int in int(crate_map[crate_id]):
			if crates and crates.grant_free(crate_id, "mail") > 0:
				given += 1
		if given > 0:
			names.append("+%d %s" % [given, crate_name(crate_id)])
	var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
	var decor_map: Dictionary = mail["decor"]
	for item: StringName in decor_map:
		var count: int = int(decor_map[item])
		if decor and decor.grant(item, count):
			names.append("+%d %s" % [count, decor_name(item)])
	var frame: String = mail["frame"]
	var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
	if not frame.is_empty() and profile and profile.grant_frame(frame):
		names.append("+1 " + frame_name(frame))
	var choice: String = mail["choice"]
	var referral: ReferralManager = tree.get_first_node_in_group("referral") as ReferralManager
	if choice == ReferralRewards.CHOICE_LEGENDARY and referral:
		referral.add_car_choice()
		names.append("+1 " + Loc.t("EFSANEVİ ARAÇ SEÇİMİ"))
	if money <= 0 and gems <= 0 and names.is_empty():
		return {}
	var summary: Dictionary = {"title": Loc.t("HEDİYEN GELDİ!"), "money": money, "gems": gems, "items": names}
	if choice == ReferralRewards.CHOICE_LEGENDARY and referral:
		summary["choice"] = choice   # ödül penceresinden sonra araç seçimi açılır
	return summary


## Kayıt geri yükleme: postanın kimliği geri yüklenen kayda da yazılır (yeni sahnede ikinci kez uygulanmasın), belge
## silinir, kayıt o hâline döner. Dönüş hep boş (ödül penceresi yok; dünya yeniden kurulur, mesajı CloudSaveManager verir).
func _restore(id: String, restore: Dictionary) -> Dictionary:
	var cloud: CloudSaveManager = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	var parsed: Variant = JSON.parse_string(CloudPack.unpack(SaveSafe.s(restore.get("save_json", ""))))
	if cloud == null or not parsed is Dictionary:
		return {}
	var data: Dictionary = parsed
	var mail_state: Dictionary = data.get("mail", {}) if data.get("mail") is Dictionary else {}
	var claimed: Dictionary = mail_state.get("claimed", {}) if mail_state.get("claimed") is Dictionary else {}
	claimed.merge(_claimed)
	claimed[id] = int(Time.get_unix_time_from_system())
	mail_state["claimed"] = claimed
	data["mail"] = mail_state
	_claimed[id] = claimed[id]
	if _social:
		_social.delete_mail(id)
	cloud.restore_snapshot(JSON.stringify(data, "", true))
	return {}


## Belgeden güvenli posta: sınırlanmış miktarlar, katalogda olmayan kasa / eşya atılır. Boş metinli ve ödülsüz posta boş.
static func normalize(id: String, doc: Dictionary) -> Dictionary:
	var crates: Dictionary = {}
	var raw_crates: Variant = doc.get("crates", {})
	if raw_crates is Dictionary:
		for key: Variant in raw_crates:
			var crate_id: StringName = StringName(SaveSafe.s(key))
			var count: int = clampi(SaveSafe.i((raw_crates as Dictionary)[key]), 0, MAX_COUNT)
			if count > 0 and CrateCatalog.exists(crate_id):
				crates[crate_id] = count
	var decor: Dictionary = {}
	var raw_decor: Variant = doc.get("decor", {})
	if raw_decor is Dictionary:
		for key: Variant in raw_decor:
			var item: StringName = StringName(SaveSafe.s(key))
			var count: int = clampi(SaveSafe.i((raw_decor as Dictionary)[key]), 0, MAX_COUNT)
			if count > 0 and GarageDecor.exists(item) and not GarageDecor.is_vehicle(item) and GarageDecor.is_placeable(item):
				decor[item] = count
	var adjust: Dictionary = {}
	var raw_adjust: Variant = doc.get("adjust", {})
	if raw_adjust is Dictionary:
		var adjust_money: int = clampi(SaveSafe.i((raw_adjust as Dictionary).get("money", 0)), -MAX_MONEY, MAX_MONEY)
		var adjust_gems: int = clampi(SaveSafe.i((raw_adjust as Dictionary).get("gems", 0)), -MAX_GEMS, MAX_GEMS)
		if adjust_money != 0 or adjust_gems != 0:
			adjust = {"money": adjust_money, "gems": adjust_gems}
	var restore: Dictionary = {}
	var raw_restore: Variant = doc.get("restore", {})
	if raw_restore is Dictionary:
		var save_json: String = SaveSafe.s((raw_restore as Dictionary).get("save_json", ""))
		if not save_json.is_empty() and save_json.length() <= 300000:
			restore = {"save_json": save_json, "at": SaveSafe.i((raw_restore as Dictionary).get("at", 0))}
	var frame: String = SaveSafe.s(doc.get("frame", ""))
	if not ProfileCatalog.frame_exclusive(frame):
		frame = ""   # posta yalnız davetle açılan çerçeveyi verir (satılık / seviyeli çerçeve verilmez)
	var choice: String = SaveSafe.s(doc.get("choice", ""))
	if choice != ReferralRewards.CHOICE_LEGENDARY:
		choice = ""
	# Davet postası (functions/referral.js "referral": welcome | tier_<n>, "friend": sayılan arkadaş): pencere özel görünür
	var ref_kind: String = ""
	var ref_tier: int = 0
	var referral: String = SaveSafe.s(doc.get("referral", ""))
	if referral == "welcome":
		ref_kind = "welcome"
	elif referral.begins_with("tier_") and referral.trim_prefix("tier_").is_valid_int():
		ref_tier = clampi(referral.trim_prefix("tier_").to_int(), 0, ReferralRewards.max_tier())
		ref_kind = "tier" if ref_tier > 0 else ""
	var mail: Dictionary = {
		"id": id,
		"title": AppConfig.text_of(doc.get("title")),
		"text": AppConfig.text_of(doc.get("text")),
		"from": SaveSafe.s(doc.get("from", "")).strip_edges().left(24),
		"money": clampi(SaveSafe.i(doc.get("money", 0)), 0, MAX_MONEY),
		"gems": clampi(SaveSafe.i(doc.get("gems", 0)), 0, MAX_GEMS),
		"money_min": clampi(SaveSafe.i(doc.get("money_min", 0)), 0, ReferralRewards.MAX_MONEY_MIN),
		"crates": crates,
		"decor": decor,
		"frame": frame,
		"choice": choice,
		"ref_kind": ref_kind,
		"ref_tier": ref_tier,
		"friend": SaveSafe.s(doc.get("friend", "")).left(128),
		"adjust": adjust,
		"restore": restore,
		"at": SaveSafe.i(doc.get("at", 0)),
	}
	if mail["text"] == "" and mail["title"] == "" and not has_reward(mail) and adjust.is_empty() and restore.is_empty():
		return {}
	return mail


## Oyuncunun eline bir şey geçiyor mu (AL düğmesi): ödül ya da artı düzeltme. Eksi düzeltme ve mesaj: TAMAM.
static func has_reward(mail: Dictionary) -> bool:
	var adjust: Dictionary = mail.get("adjust", {}) if mail.get("adjust") is Dictionary else {}
	return int(mail.get("money", 0)) > 0 or int(mail.get("gems", 0)) > 0 or int(mail.get("money_min", 0)) > 0 \
		or not (mail.get("crates", {}) as Dictionary).is_empty() or not (mail.get("decor", {}) as Dictionary).is_empty() \
		or not SaveSafe.s(mail.get("frame", "")).is_empty() or not SaveSafe.s(mail.get("choice", "")).is_empty() \
		or int(adjust.get("money", 0)) > 0 or int(adjust.get("gems", 0)) > 0


static func crate_name(crate_id: StringName) -> String:
	return Loc.t(SaveSafe.s(CrateCatalog.get_entry(crate_id).get("display_name", crate_id)))


static func decor_name(item: StringName) -> String:
	return Loc.t(SaveSafe.s(GarageDecor.get_item(item).get("title", item)))


## `minutes` dakikalık aktif gelirin şu anki ₺ karşılığı (davet postası money_min; POSTA penceresi de gösterir).
static func income_money(tree: SceneTree, minutes: int) -> int:
	if minutes <= 0:
		return 0
	var offline: OfflineEarnings = tree.get_first_node_in_group("offline_earnings") as OfflineEarnings if tree else null
	return ReferralRewards.money_for(minutes, offline.current_active_rate() if offline else LoginLadder.FALLBACK_INCOME)


static func frame_name(frame: String) -> String:
	return Loc.t("%s ÇERÇEVESİ") % Loc.t(SaveSafe.s(ProfileCatalog.frame(frame).get("name", frame)))


func _trim_claimed() -> void:
	if _claimed.size() <= KEEP_CLAIMED:
		return
	var ids: Array = _claimed.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_claimed[a]) < int(_claimed[b]))
	for i: int in ids.size() - KEEP_CLAIMED:
		_claimed.erase(ids[i])


# --- Kayıt (SaveManager) -------------------------------------------------------------

func state() -> Dictionary:
	return {"claimed": _claimed.duplicate()}


func load_state(data: Dictionary) -> void:
	_claimed.clear()
	var raw: Variant = data.get("claimed", {})
	if raw is Dictionary:
		for key: Variant in raw:
			_claimed[SaveSafe.s(key)] = SaveSafe.i((raw as Dictionary)[key])
	_pending.clear()


func reset() -> void:
	_claimed.clear()
	_pending.clear()
	_polled_uid = ""
