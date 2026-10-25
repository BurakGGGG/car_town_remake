class_name MailService
extends Node
## POSTA KUTUSU (2026-10-21): yönetim panelinin (firebase/admin) gönderdiği hediye / mesaj. Sunucu users/{uid}/mail/{id}
## belgesini yazar (istemci yazamaz, firestore.rules); oyun oturum açıkken listeler: bulut senkronu bitince, öne gelince
## ve POLL_SEC'te bir. Yalnızca HESAPLI oyuncu (kullanıcı kararı 2026-10-21: misafirin UID'si yok). Belge:
##   {title, text: dil sözlüğü ya da düz metin, from: gönderen adı, money, gems, crates: {kasa: adet},
##    decor: {eşya: adet}, at, expires (unix sn, 0 = süresiz)}
## Akış: yeni posta → `arrived` → HABERLER kutusunda bekler (Inbox; 2026-10-25'ten beri pencere kendiliğinden açılmaz,
## tabelada rozet + "HEDİYEN VAR") → AL → claim(): ödül hesaba geçer, kimlik kayda yazılır (SaveManager "mail") → kayıt
## diske → belge silinir. Silme başarısız olsa da kimlik
## kayıtta olduğundan ödül ikinci kez verilmez; sonraki listede belge yeniden silinir. Süresi dolan posta ödülsüz silinir.
## Değerler istemcide de sınırlanır (MAX_*): panelde yanlış yazılmış bir sıfır oyunu bozmasın.
## ARKADAŞ DAVETİ postaları (2026-10-23, functions/referral.js): money_min (₺ = oyuncunun o anki aktif gelirinin dakikası,
## ReferralRewards.money_for), frame (yalnız verilen profil çerçevesi, PlayerProfile.grant_frame), choice "legendary_car"
## (efsanevi araç seçme hakkı ReferralManager'a eklenir; oyuncu sonra seçer, hak kayıtta durur).
## ARAÇ HEDİYESİ (2026-10-25, kullanıcı: "araba da hediye edebileyim"): cars {araç: 1} — edinilebilir (katalogda,
## obtainable) her araç bir kez verilir (VehicleOwnership.add_vehicle); oyuncuda zaten varsa aracın SATIŞ değeri ₺ olarak
## verilir (sell_price; kartta "ZATEN VARDI"). Alınan postanın özeti "cards" listesini de taşır: ödül ekranı (GiftScreen)
## araç fotoğrafı, dönen kasa, dekor resmi, çerçeve kartlarını buradan kurar.
## DESTEK postaları (2026-10-21): adjust {money, gems} BAKİYE DÜZELTMESİ (eksi de olabilir, 0'ın altına inmez; harcama
## sayılmaz) ve restore {save_json, at} KAYIT GERİ YÜKLEME (AL → CloudSaveManager.restore_snapshot: kayıt o hâline döner,
## dünya yeniden kurulur; postanın kimliği geri yüklenen kayda da yazılır, ikinci kez uygulanmaz).
## Firestore'a SocialManager'ın sıralı kuyruğuyla gider (list_mail / delete_mail). GarageSystem kurar; ziyarette yok.
## HABERLER KUTUSU durumu da burada (kayıtta "mail", 2026-10-25): alınan postaların GEÇMİŞİ (ALINDI damgalı, en yeni
## KEEP_HISTORY) ve kutuda GÖRÜLEN haberlerin kimlikleri (okunmamış sayısı). Postada isteğe bağlı image (kapak resmi) ve
## action {kind, url} (düğme) — NewsFeed ile aynı süzgeç; ödülsüz posta "tek oyuncuya haber"dir.

## Yeni (alınmamış) postalar geldi: pencere sırası güncellendi.
signal arrived
## Posta alındı (geçmişe yazıldı) ya da kutuda haberler görüldü: kutu ve rozet yenilenir.
signal history_changed

const POLL_SEC: float = 600.0
## Öne gelince (ör. "hediyen var" bildirimine dokunup dönünce) son okumadan bu kadar geçtiyse hemen okunur.
const RESUME_SEC: float = 15.0
## Kayıtta tutulan alınmış kimlik sayısı (eskiler düşer; belge çoktan silinmiş olur).
const KEEP_CLAIMED: int = 200
const MAX_MONEY: int = 50_000_000
const MAX_GEMS: int = 50_000
const MAX_COUNT: int = 20
## Kutuda tutulan alınmış posta sayısı (kullanıcı kararı: en yeni 50 kayıt) ve görülen kimlik sayısı.
const KEEP_HISTORY: int = 50
const KEEP_SEEN: int = 200
const MAX_TEXT: int = 600

var _social: SocialManager
var _cloud: CloudSaveManager
var _save: SaveManager
var _claimed: Dictionary = {}     # kimlik → alındığı unix sn (kayıtta)
var _pending: Array[Dictionary] = []   # alınmamış postalar (normalize edilmiş, eskisi önde)
var _history: Array[Dictionary] = []   # alınmış postalar, en yeni önde (kayıtta)
var _seen: Dictionary = {}        # kutuda görülen haber / posta kimliği → görüldüğü unix sn (kayıtta)
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
		return _restore(id, mail)
	var summary: Dictionary = _grant(mail)
	_claimed[id] = int(Time.get_unix_time_from_system())
	_trim_claimed()
	_remember(mail, summary)
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
	var cards: Array[Dictionary] = []   # ödül ekranının kartları (GiftScreen)
	var ownership: VehicleOwnership = tree.get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for car: StringName in mail["cars"]:
		if ownership == null:
			break
		if ownership.add_vehicle(car):
			names.append("+1 " + car_name(car))
			cards.append({"kind": "car", "id": car})
			continue
		var refund: int = ownership.sell_price(car)   # zaten var: satış değeri ₺ olarak
		if economy and refund > 0:
			economy.add_money(refund)
			money += refund
		cards.append({"kind": "car", "id": car, "owned": true, "money": refund})
	var crates: CrateManager = tree.get_first_node_in_group("crates") as CrateManager
	var crate_map: Dictionary = mail["crates"]
	for crate_id: StringName in crate_map:
		var given: int = 0
		for i: int in int(crate_map[crate_id]):
			if crates and crates.grant_free(crate_id, "mail") > 0:
				given += 1
		if given > 0:
			names.append("+%d %s" % [given, crate_name(crate_id)])
			cards.append({"kind": "crate", "id": crate_id, "count": given})
	var decor: DecorManager = tree.get_first_node_in_group("decor") as DecorManager
	var decor_map: Dictionary = mail["decor"]
	for item: StringName in decor_map:
		var count: int = int(decor_map[item])
		if decor and decor.grant(item, count):
			names.append("+%d %s" % [count, decor_name(item)])
			cards.append({"kind": "decor", "id": item, "count": count})
	var frame: String = mail["frame"]
	var profile: PlayerProfile = tree.get_first_node_in_group("player_profile") as PlayerProfile
	if not frame.is_empty() and profile and profile.grant_frame(frame):
		names.append("+1 " + frame_name(frame))
		cards.append({"kind": "frame", "id": frame})
	var choice: String = mail["choice"]
	var referral: ReferralManager = tree.get_first_node_in_group("referral") as ReferralManager
	if choice == ReferralRewards.CHOICE_LEGENDARY and referral:
		referral.add_car_choice()
		names.append("+1 " + Loc.t("EFSANEVİ ARAÇ SEÇİMİ"))
		cards.append({"kind": "choice", "id": choice})
	if money <= 0 and gems <= 0 and names.is_empty() and cards.is_empty():
		return {}
	var summary: Dictionary = {"title": Loc.t("HEDİYEN GELDİ!"), "money": money, "gems": gems, "items": names,
		"cards": cards, "subtitle": mail["title"], "from": mail["from"]}
	if choice == ReferralRewards.CHOICE_LEGENDARY and referral:
		summary["choice"] = choice   # ödül penceresinden sonra araç seçimi açılır
	return summary


## Kayıt geri yükleme: postanın kimliği geri yüklenen kayda da yazılır (yeni sahnede ikinci kez uygulanmasın), belge
## silinir, kayıt o hâline döner. Dönüş hep boş (ödül penceresi yok; dünya yeniden kurulur, mesajı CloudSaveManager verir).
func _restore(id: String, mail: Dictionary) -> Dictionary:
	var restore: Dictionary = mail["restore"]
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
	_claimed[id] = claimed[id]
	_remember(mail, {"items": [Loc.t("KAYIT GERİ YÜKLENDİ")]})
	mail_state["history"] = _history.duplicate(true)   # kutunun geçmişi geri yüklenen kayıtta da kalsın
	mail_state["seen"] = _seen.duplicate()
	data["mail"] = mail_state
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
	var cars: Array[StringName] = []
	var raw_cars: Variant = doc.get("cars", {})
	for key: Variant in ((raw_cars as Dictionary).keys() if raw_cars is Dictionary else (raw_cars if raw_cars is Array else [])):
		var car: StringName = StringName(SaveSafe.s(key))
		var wanted: bool = SaveSafe.i((raw_cars as Dictionary)[key]) > 0 if raw_cars is Dictionary else true
		if wanted and not cars.has(car) and cars.size() < MAX_COUNT and CarCatalog.is_obtainable(car):
			cars.append(car)
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
		"title": AppConfig.text_of(doc.get("title")).left(MAX_TEXT),
		"text": AppConfig.text_of(doc.get("text")).left(MAX_TEXT),
		"from": SaveSafe.s(doc.get("from", "")).strip_edges().left(24),
		"money": clampi(SaveSafe.i(doc.get("money", 0)), 0, MAX_MONEY),
		"gems": clampi(SaveSafe.i(doc.get("gems", 0)), 0, MAX_GEMS),
		"money_min": clampi(SaveSafe.i(doc.get("money_min", 0)), 0, ReferralRewards.MAX_MONEY_MIN),
		"crates": crates,
		"decor": decor,
		"cars": cars,
		"frame": frame,
		"choice": choice,
		"ref_kind": ref_kind,
		"ref_tier": ref_tier,
		"friend": SaveSafe.s(doc.get("friend", "")).left(128),
		"adjust": adjust,
		"restore": restore,
		"at": SaveSafe.i(doc.get("at", 0)),
		"expires": SaveSafe.i(doc.get("expires", 0)),
		"image": NewsFeed.clean_image(doc.get("image", "")),
		"action": NewsFeed.clean_action(doc.get("action", {})),
	}
	if mail["text"] == "" and mail["title"] == "" and not has_reward(mail) and adjust.is_empty() and restore.is_empty():
		return {}
	return mail


## Kutuda HEDİYE mi (alınana kadar rozette sayılır, düğmeyle alınır): ödül, bakiye düzeltmesi ya da kayıt geri yükleme.
## Değilse "tek oyuncuya haber": kutu açılınca okunmuş sayılır ve geçmişe geçer (Inbox).
static func is_gift(mail: Dictionary) -> bool:
	return has_reward(mail) or not (mail.get("adjust", {}) as Dictionary).is_empty() \
		or not (mail.get("restore", {}) as Dictionary).is_empty()


## Oyuncunun eline bir şey geçiyor mu (AL düğmesi): ödül ya da artı düzeltme. Eksi düzeltme ve mesaj: TAMAM.
static func has_reward(mail: Dictionary) -> bool:
	var adjust: Dictionary = mail.get("adjust", {}) if mail.get("adjust") is Dictionary else {}
	return int(mail.get("money", 0)) > 0 or int(mail.get("gems", 0)) > 0 or int(mail.get("money_min", 0)) > 0 \
		or not (mail.get("crates", {}) as Dictionary).is_empty() or not (mail.get("decor", {}) as Dictionary).is_empty() \
		or not (mail.get("cars", []) as Array).is_empty() \
		or not SaveSafe.s(mail.get("frame", "")).is_empty() or not SaveSafe.s(mail.get("choice", "")).is_empty() \
		or int(adjust.get("money", 0)) > 0 or int(adjust.get("gems", 0)) > 0


static func car_name(car: StringName) -> String:
	return String(CarCatalog.get_entry(car).get("display_name", car)).to_upper()


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


# --- HABERLER kutusu: geçmiş ve görülenler ---------------------------------------------

## Alınmış postalar, en yeni alınan önde: {id, title, text, from, at, claimed_at, image, action, gift, money, gems, items}.
func history() -> Array[Dictionary]:
	return _history


func is_seen(id: String) -> bool:
	return _seen.has(id)


## Kutuda görüldüğü unix sn (görülmediyse 0).
func seen_at(id: String) -> int:
	return int(_seen.get(id, 0))


## Kutu açıldı: verilen kimlikler görüldü (rozet düşer). Kayıt diske yazılmaz — sonraki kayıtla gider (okundu bilgisi).
func mark_seen(ids: Array) -> void:
	var now: int = int(Time.get_unix_time_from_system())
	var added: bool = false
	for id: Variant in ids:
		var key: String = SaveSafe.s(id)
		if not key.is_empty() and not _seen.has(key):
			_seen[key] = now
			added = true
	if not added:
		return
	if _seen.size() > KEEP_SEEN:
		var keys: Array = _seen.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_seen[a]) < int(_seen[b]))
		for i: int in _seen.size() - KEEP_SEEN:
			_seen.erase(keys[i])
	history_changed.emit()


func _remember(mail: Dictionary, summary: Dictionary) -> void:
	if mail.is_empty():
		return
	var items: Array = summary.get("items", []) if summary.get("items") is Array else []
	_history.push_front(_clean_history({
		"id": mail.get("id", ""), "title": mail.get("title", ""), "text": mail.get("text", ""), "from": mail.get("from", ""),
		"at": mail.get("at", 0), "claimed_at": int(Time.get_unix_time_from_system()), "image": mail.get("image", ""),
		"action": mail.get("action", {}), "gift": is_gift(mail), "money": summary.get("money", 0),
		"gems": summary.get("gems", 0), "items": items,
	}))
	if _history.size() > KEEP_HISTORY:
		_history.resize(KEEP_HISTORY)
	history_changed.emit()


## Geçmiş kaydı (kayıttan da gelir: bozuk / eksik alanlar güvenli değere iner).
static func _clean_history(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var e: Dictionary = entry
	var id: String = SaveSafe.s(e.get("id", ""))
	if id.is_empty():
		return {}
	var items: Array = []
	for item: Variant in (e.get("items", []) if e.get("items") is Array else []):
		if items.size() < 12:
			items.append(SaveSafe.s(item).left(80))
	return {
		"id": id, "title": SaveSafe.s(e.get("title", "")).left(MAX_TEXT), "text": SaveSafe.s(e.get("text", "")).left(MAX_TEXT),
		"from": SaveSafe.s(e.get("from", "")).left(24), "at": SaveSafe.i(e.get("at", 0)),
		"claimed_at": SaveSafe.i(e.get("claimed_at", 0)), "image": NewsFeed.clean_image(e.get("image", "")),
		"action": NewsFeed.clean_action(e.get("action", {})), "gift": e.get("gift", false) == true,
		"money": maxi(SaveSafe.i(e.get("money", 0)), 0), "gems": maxi(SaveSafe.i(e.get("gems", 0)), 0), "items": items,
	}


# --- Kayıt (SaveManager) -------------------------------------------------------------

func state() -> Dictionary:
	return {"claimed": _claimed.duplicate(), "history": _history.duplicate(true), "seen": _seen.duplicate()}


func load_state(data: Dictionary) -> void:
	_claimed.clear()
	var raw: Variant = data.get("claimed", {})
	if raw is Dictionary:
		for key: Variant in raw:
			_claimed[SaveSafe.s(key)] = SaveSafe.i((raw as Dictionary)[key])
	_history.clear()
	var raw_history: Variant = data.get("history", [])
	for entry: Variant in (raw_history if raw_history is Array else []):
		var clean: Dictionary = _clean_history(entry)
		if not clean.is_empty() and _history.size() < KEEP_HISTORY:
			_history.append(clean)
	_seen.clear()
	var raw_seen: Variant = data.get("seen", {})
	if raw_seen is Dictionary:
		for key: Variant in raw_seen:
			_seen[SaveSafe.s(key)] = SaveSafe.i((raw_seen as Dictionary)[key])
	_pending.clear()
	history_changed.emit()


func reset() -> void:
	_claimed.clear()
	_pending.clear()
	_history.clear()
	_seen.clear()
	_polled_uid = ""
