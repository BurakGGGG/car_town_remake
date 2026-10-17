class_name SocialManager
extends Node
## ARKADAŞLIK: takma ad + arkadaş kodu, istek / kabul, arkadaş listesi, herkese açık garaj ve ziyaret.
## GarageSystem kodla kurar (sahne dosyası düzenlenmez); arayanlar "social" grubundan bulur.
## Firebase'e CloudSaveManager gibi doğrudan eklentinin singleton'ı üzerinden bağlanır. Oturum
## CloudSaveManager'ındır: Google hesabıyla giriş yapılmamışsa (misafir) sosyal özellik kapalıdır.
##
## FIRESTORE (kurallar: firebase/firestore.rules)
##   garages/g_{uid}              {name, code, level, value, garage_json, updated_at}  herkese açık garaj
##   codes/{KOD}                  {uid}                     arkadaş kodu → oyuncu (bir kez alınır)
##   users/{alıcı}/inbox/r_{gön}  {name, code, at}          gelen istek (gönderen yazar)
##   users/{gön}/outbox/o_{alıcı} {name, code, at}          giden istek (gönderenin bekleyen listesi)
##   users/{a}/friends/f_{b}      {since}                   arkadaşlık; iki belgeyi de KABUL EDEN yazar
##   users/{alıcı}/gifts/p_{gön}_{gün} {part, name, at, day} hurdalık hediyesi (arkadaş yazar, günde bir)
##   avatars/a_{uid}              {img, hash, at}           profil fotoğrafı (192 px JPEG, base64; sahibi yazar)
##   reports/x_{şikâyetçi}_{hedef} {target, reason, av, img, name, at}  şikâyet (yalnız yazılır; konsoldan okunur)
##   users/{alıcı}/races/e_{gön}  {name, car, paint, build, their_car, won, revenge, mw, ml, at}  YARIŞ HABERİ
##   users/{sahip}/visits/v_{ziy} {name, at, day, liked}   ZİYARET + BEĞENİ (ziyaretçi dönüşte yazar; sahip okur, siler)
##   invites/{jeton}              {uid, name, code, at}     ARKADAŞ DAVETİ (link; 1 saat; jetonla okunur)
## ARKADAŞ DAVETİ (2026-10-17, kullanıcı isteği): kod yazmak yerine link. A create_invite ile link üretir ve paylaşır
## (ARKADAŞLAR → DAVET LİNKİ GÖNDER); B linke dokunur → oyun açılır (InviteLinks) → A'nın profil kartı → ARKADAŞ
## EKLE (accept_invite) → iki arkadaşlık belgesini B yazar, belgede davet jetonu (inv) durur, kural daveti doğrular.
## A ONAYLAMAZ: linki kendisi gönderdi. Link INVITE_TTL (1 saat) geçerli, o sürede linki alan herkes kullanabilir.
## YARIŞ HABERİ (aşama 3): gerçek arkadaşın aracıyla yarış bitince (RaceManager.friend_race_finished) arkadaşa yazılır —
## kazansan da kaybetsen de. Gönderen başına tek belge (en son yarış). Alıcı listeyi okurken haberleri alır, skorun
## karşı yönünü (mw / ml) RaceManager'a yazar, yeni haber için race_news yayar (HUD bildirimi). Gönderen kazandıysa
## alıcı İNTİKAM AL ile onun o aracına (boya + modifiye) karşı yarışır; haber kullanılınca / TAMAM'da silinir.
## PROFİL (PlayerProfile): açık garaj belgesine av / frame / flag / title / car / stats da yazılır. Avatar resmi ayrı
## belgede: garaj belgesindeki "av" = "img:<hash>"; arkadaş hash değişmedikçe yeniden indirmez (cihazda
## user://avatars/ önbelleği). Şikâyet edilen fotoğraf şikâyetçinin ekranında hemen gizlenir; ENGELLE arkadaşlıktan
## çıkarır, isteklerini yok sayar (PlayerProfile.blocked).
## HURDALIK HEDİYESİ (orijinal "Ask Friends"): oyuncu bir parçayı İSTER → açık garaj belgesine
## "ask" {part, at} yazılır (arkadaşlar listeyi okurken zaten bu belgeyi okuyor: ek okuma yok). Arkadaşı
## GÖNDER'e basar → alıcının gifts koleksiyonuna 1 parça. Alıcı toplar (collect_gifts); sunucu bugünün
## hediyesini silmeye izin vermez (günlük sınır), toplananlar JunkyardManager'da hatırlanır.
## Belge kimlikleri hiçbir zaman çıplak UID değildir: eklenti sonuçları yalnızca belge kimliğiyle
## bildirir (koleksiyon yok) ve CloudSaveManager kendi sonucunu "kimlik == UID" diye tanır. Önek iki
## sistemin yanıtlarını ayırır. Bu node'un istekleri SIRAYLA gider (aynı anda tek istek), sonuç
## kimlik + istek türüyle eşlenir; koleksiyon listesinin sonucunda kimlik yoktur.
##
## GARAJ YAYINI: profil varken her local kayıttan PUBLISH_DEBOUNCE sn sonra açık garaj (PublicGarage)
## değiştiyse yazılır. Yalnızca bulut kaydı SYNCED iken: kayıt seçimi (CONFLICT) sürerken cihazdaki
## kayıt henüz bu hesabın olmayabilir.
##
## Cihazda tutulan: user://social.json = {uid, name, code, published}. Başka cihazda / yeniden kurulumda
## profil garages/g_{uid}'den geri okunur.
##
## OTO MANŞET (açılış gazetesi, 2026-10-17): news_items() son gazeteden bu yana olanları NewsDigest ham haberleri olarak
## verir — arkadaşın senin aracına karşı kazandığı / kaybettiği yarış sayısı (haberdeki skorun son gazetedeki tabandan
## farkı), gelen hediye parçalar, yeni arkadaş, gelen istek, arkadaşın yeni parça isteği. Taban social.json "news"
## anahtarında (cihaza özel), news_shown() ile ilerler. Gazete toplanırken (quiet) hediye bildirimi gösterilmez, hediye
## "gift_log"a yazılır; oyun içinde bildirimi görülen yarış haberi tabana hemen işlenir (gazete tekrarlamasın).

## Profil / listeler / durum değişti (ekran yenilensin).
signal changed
## Oyuncuya gösterilecek kısa mesaj.
signal notice(text: String)
## Bir oyuncunun avatar resmi indi (ekranlar o satırı yeniler).
signal avatar_ready(uid: String)
## Yeni yarış haberi geldi (HUD kısa bildirim gösterir).
signal race_news(event: Dictionary)

enum State {
	UNAVAILABLE,  ## eklenti yok (PC / editör)
	SIGNED_OUT,   ## Google girişi yok (misafir) ya da bulut kaydı henüz hazır değil
	LOADING,      ## profil okunuyor / oluşturuluyor
	NO_PROFILE,   ## giriş var, takma ad + kod henüz seçilmedi
	READY,        ## profil hazır
	OFFLINE,      ## sunucuya ulaşılamadı (tekrar denenebilir)
}

const PLUGIN_NAME: String = "GodotFirebaseAndroid"
const META_PATH: String = "user://social.json"
const NOT_FOUND_ERROR: String = "Document does not exist"
const REQUEST_TIMEOUT: float = 12.0
## Local kayıttan sonra açık garajı yazmadan önce beklenen süre (sn); aradaki kayıtlar birleşir.
const PUBLISH_DEBOUNCE: float = 20.0
## Listeler bu süreden yeniyse ekran açılınca yeniden okunmaz (okuma kotası).
const REFRESH_MIN_INTERVAL: float = 30.0
const MAX_FRIENDS: int = 100
## Kod çakışırsa (sunucu reddeder) en fazla bu kadar yeni kod denenir.
const CODE_ATTEMPTS: int = 6

const GARAGES: String = "garages"
const CODES: String = "codes"
const AVATARS: String = "avatars"
const REPORTS: String = "reports"
## Telefon bildirimi jetonu: push/p_{uid} = {token, lang, at} (PushService yazar; sunucu okur).
const PUSH: String = "push"
## ARKADAŞ DAVETİ: koleksiyon, ömür (sn; kural aynı süreyi sunucu saatiyle uygular) ve paylaşılan linkin başı. Web
## sayfası (auto_yard_website /d/<jeton>) oyunu autoyard://davet/<jeton> ile açar; oyun yüklü değilse mağazaya yollar.
const INVITES: String = "invites"
const INVITE_TTL: int = 3600
const INVITE_URL: String = "https://autoyardwebsite.vercel.app/d/"
## Oyun açıkken yarış haberlerine bu aralıkla bakılır (tek liste okuması; telefon bildirimi ön planda görünmez).
const NEWS_POLL: float = 120.0
const AVATAR_CACHE_DIR: String = "user://avatars/"
const AVATAR_CACHE_INDEX: String = "user://avatars/index.json"
## Şikâyet nedenleri (kuralla aynı).
const REPORT_REASONS: Array[String] = ["photo", "name", "garage"]

## Eşleşme için bekleyen isteğin sonucu (iç kullanım).
signal _op_result(result: Dictionary)
signal _op_slot_free

## Gazete topluyor (NewsFlow): hediye bildirimi yerine gazete.
var quiet: bool = false
## Testler kısaltır.
var publish_delay: float = PUBLISH_DEBOUNCE
var request_timeout: float = REQUEST_TIMEOUT
var friends: Array[Dictionary] = []   ## {uid, name, code, level, value, ask_part, ask_at} + profil (profile_fields)
var incoming: Array[Dictionary] = []  ## {uid, name, code, at} + profil (garajı okunabildiyse)
## Yarış haberleri: {uid (gönderen), name, car, paint, build, their_car, won, revenge, mw, ml, at} + arkadaşın profili.
var race_events: Array[Dictionary] = []
var outgoing: Array[Dictionary] = []  ## {uid, name, code, at}

var _fb: Object
var _cloud: CloudSaveManager
var _save: SaveManager
var _state: State = State.UNAVAILABLE
var _uid: String = ""
var _meta: Dictionary = {}
var _op_busy: bool = false
var _current: Dictionary = {}         # {kind, id} — yanıtı beklenen istek
var _busy: int = 0                    # oyuncunun başlattığı süren işlem sayısı (butonlar kilitlenir)
var _refreshed_at: float = -1000.0
var _op_timer: Timer
var _publish_timer: Timer
var _news_timer: Timer
var _profile: PlayerProfile
## Avatar önbelleği: uid → {hash, tex}; diskte user://avatars/<uid>.jpg + index (uid → hash).
var _avatars: Dictionary = {}
var _avatar_index: Dictionary = {}
var _avatar_pending: Dictionary = {}   # uid → hash (indiriliyor)
var _news_next: Dictionary = {}        # gazetede gösterilen durum (news_shown tabana yazar)
var _news_gifts: int = 0               # gösterilen hediye kaydı sayısı
var _news_visits: int = 0              # gösterilen ziyaret kaydı sayısı


func _ready() -> void:
	add_to_group("social")
	_op_timer = _make_timer(REQUEST_TIMEOUT, _on_op_timeout)
	_publish_timer = _make_timer(PUBLISH_DEBOUNCE, _on_publish_timeout)
	_news_timer = _make_timer(NEWS_POLL, _on_news_poll)
	_news_timer.one_shot = false
	_news_timer.start()
	if Engine.has_singleton(PLUGIN_NAME):
		_fb = Engine.get_singleton(PLUGIN_NAME)
	_setup.call_deferred()


## Testler sahte Firebase verir (eklenti yokken). _ready'den önce çağrılmalı.
func use_firebase(fb: Object) -> void:
	_fb = fb


func _setup() -> void:
	if _fb == null:
		_set_state(State.UNAVAILABLE)
		return
	_fb.connect("firestore_get_task_completed", _on_get_completed)
	_fb.connect("firestore_write_task_completed", _on_write_completed)
	_fb.connect("firestore_delete_task_completed", _on_delete_completed)
	_save = get_tree().get_first_node_in_group("save_manager") as SaveManager
	_cloud = get_tree().get_first_node_in_group("cloud_save") as CloudSaveManager
	_profile = get_tree().get_first_node_in_group("player_profile") as PlayerProfile
	_load_avatar_index()
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	if race:
		race.friend_race_finished.connect(_on_friend_race_finished)
	if _save:
		_save.game_saved.connect(_on_local_saved)
	if _cloud:
		_cloud.state_changed.connect(func(_s: CloudSaveManager.State) -> void: _sync_session())
	_set_state(State.SIGNED_OUT)
	_sync_session()


# --- Dış API ---------------------------------------------------------------------

func get_state() -> State:
	return _state


func is_ready() -> bool:
	return _state == State.READY


## Oyuncunun başlattığı bir işlem sürüyor mu (butonlar kilitli).
## Arkadaş listesi / istekler / haberler bu oturumda en az bir kez okundu mu (gazete bunu bekler).
func has_loaded() -> bool:
	return _refreshed_at > 0.0


func is_busy() -> bool:
	return _busy > 0 or _state == State.LOADING


## Oturumun Firebase kimliği (yoksa boş).
func uid() -> String:
	return _uid


## Telefon bildirimi jetonunu yazar (PushService). Başarılıysa true.
func write_push_token(token: String, lang: String) -> bool:
	if not is_ready() or token.is_empty():
		return false
	return _ok(await _call(&"set", PUSH, "p_" + _uid, {"token": token, "lang": lang, "at": _now()}))


func delete_push_token() -> void:
	if not _uid.is_empty() and _fb != null:
		await _call(&"delete", PUSH, "p_" + _uid)


## Oyun açıkken yarış haberleri (yeni haber → race_news → HUD bildirimi). Oyuncunun işlemi sürüyorsa beklenir.
func _on_news_poll() -> void:
	if not is_ready() or _busy > 0 or _op_busy:
		return
	await _load_race_events()
	await _load_visits()
	changed.emit()


func my_name() -> String:
	return SaveSafe.s(_meta.get("name", ""))


func my_code() -> String:
	return SaveSafe.s(_meta.get("code", ""))


func is_friend(uid: String) -> bool:
	return _index_of(friends, uid) >= 0


## Profil oluşturur: takma ad + yeni arkadaş kodu, ardından açık garaj yayınlanır.
func create_profile(raw_name: String) -> bool:
	var name: String = SocialNames.clean_name(raw_name)
	if not _check_name(name) or _state != State.NO_PROFILE:
		return false
	_set_state(State.LOADING)
	_busy += 1
	var code: String = my_code() if SaveSafe.s(_meta.get("uid", "")) == _uid else ""
	if code.is_empty():
		code = await _claim_code()
	var ok: bool = false
	if not code.is_empty():
		_meta = {"uid": _uid, "code": code, "name": ""}
		_write_meta()
		ok = await _publish(name)
	_busy -= 1
	if ok:
		_meta["name"] = name
		_write_meta()
		_set_state(State.READY)
		notice.emit(Loc.t("Profilin hazır! Kodunu arkadaşlarınla paylaş."))
	else:
		_set_state(State.NO_PROFILE)
		notice.emit(Loc.t("Profil oluşturulamadı. İnternet bağlantını kontrol edip tekrar dene."))
	return ok


## Takma adı değiştirir (açık garaj yeni adla yazılır).
func rename(raw_name: String) -> bool:
	var name: String = SocialNames.clean_name(raw_name)
	if not is_ready() or not _check_name(name):
		return false
	if name == my_name():
		return true
	_busy += 1
	changed.emit()
	var ok: bool = await _publish(name)
	_busy -= 1
	if ok:
		_meta["name"] = name
		_write_meta()
		notice.emit(Loc.t("Takma adın değişti."))
	else:
		notice.emit(Loc.t("Takma ad değiştirilemedi. Tekrar dene."))
	changed.emit()
	return ok


## Arkadaş listesi + gelen / giden istekler sunucudan okunur. force değilse kısa aralıkla tekrar okunmaz.
func refresh(force: bool = false) -> void:
	if not is_ready() or _busy > 0:
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	if not force and now - _refreshed_at < REFRESH_MIN_INTERVAL:
		return
	_busy += 1
	changed.emit()
	var ok: bool = await _load_lists()
	_busy -= 1
	if ok:
		_refreshed_at = now
		await collect_gifts()
	else:
		notice.emit(Loc.t("Arkadaş listesi yüklenemedi. İnternet bağlantını kontrol et."))
	changed.emit()


## Koda arkadaşlık isteği gönderir. Karşı taraf zaten istek göndermişse doğrudan kabul edilir.
func send_request(raw_code: String) -> bool:
	if not is_ready() or _busy > 0:
		return false
	var code: String = SocialNames.normalize_code(raw_code)
	if not SocialNames.is_valid_code(code):
		notice.emit(Loc.t("Kod 6 karakter olmalı (ör. AY-7K2Q4M)."))
		return false
	if code == my_code():
		notice.emit(Loc.t("Bu senin kendi kodun."))
		return false
	if friends.size() >= MAX_FRIENDS:
		notice.emit(Loc.t("Arkadaş listen dolu."))
		return false
	_busy += 1
	changed.emit()
	var ok: bool = await _send_request(code)
	_busy -= 1
	changed.emit()
	return ok


func accept(uid: String) -> bool:
	if _index_of(incoming, uid) < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = await _accept(uid)
	_busy -= 1
	changed.emit()
	return ok


func reject(uid: String) -> bool:
	var at: int = _index_of(incoming, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _inbox_of(_uid), "r_" + uid))
	if ok:
		await _call(&"delete", _outbox_of(uid), "o_" + _uid)
		incoming.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


## Gönderilmiş isteği geri çeker.
func cancel(uid: String) -> bool:
	var at: int = _index_of(outgoing, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _inbox_of(uid), "r_" + _uid))
	if ok:
		await _call(&"delete", _outbox_of(_uid), "o_" + uid)
		outgoing.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


func remove_friend(uid: String) -> bool:
	var at: int = _index_of(friends, uid)
	if at < 0 or _busy > 0:
		return false
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"delete", _friends_of(_uid), "f_" + uid))
	if ok:
		await _call(&"delete", _friends_of(uid), "f_" + _uid)   # karşı tarafın listesi (kural izin verir)
		friends.remove_at(at)
	_busy -= 1
	changed.emit()
	return ok


# --- Arkadaş daveti (link) ---------------------------------------------------------

## DAVET LİNKİ: yeni davet yazar, paylaşılacak linki döner (olmazsa boş; nedeni notice ile). Süresi dolmuş eski
## davetler önce silinir. Link INVITE_TTL boyunca geçerli; linki kime gönderdiyse o kişiler kullanabilir.
func create_invite() -> String:
	if not is_ready() or _busy > 0 or my_code().is_empty():
		return ""
	_busy += 1
	changed.emit()
	await _prune_invites()
	var link: String = ""
	var denied: bool = false
	var at: int = _now()
	for attempt: int in CODE_ATTEMPTS:
		var token: String = SocialNames.random_token()
		var result: Dictionary = await _call(&"set", INVITES, token,
			{"uid": _uid, "name": my_name(), "code": my_code(), "at": at})
		if _ok(result):
			var mine: Array = _meta.get("invites", []) if _meta.get("invites") is Array else []
			mine.append({"token": token, "at": at})
			_meta["invites"] = mine
			_write_meta()
			link = INVITE_URL + token
			break
		denied = _permission_denied(result)
		if not denied:
			break   # çevrimdışı vb.: yeni jeton denemek boşuna
	if link.is_empty():
		# Kural reddi: jeton çakışması çok olası değil; asıl neden telefonun saatinin 10 dk'dan fazla kayık olması
		notice.emit(Loc.t("Davet linki oluşturulamadı. Telefonunun saatini kontrol et.") if denied
			else Loc.t("Davet linki oluşturulamadı. İnternet bağlantını kontrol et."))
	_busy -= 1
	changed.emit()
	return link


## Linkteki daveti okur: {status, token, uid, at, person (davet edenin profil kartı girdisi)}. status: "ok" (eklenebilir),
## "friend" (zaten arkadaş), "self" (kendi linki), "expired" (süresi dolmuş), "missing" (yok / hesap silinmiş),
## "error" (okunamadı), "signin" (sosyal oturum yok: Google girişi gerekir).
func read_invite(raw_token: String) -> Dictionary:
	var token: String = raw_token.strip_edges().to_upper()
	if not SocialNames.is_valid_token(token):
		return {"status": "missing", "token": token}
	if not is_ready():
		return {"status": "signin", "token": token}
	_busy += 1
	changed.emit()
	var out: Dictionary = await _read_invite(token)
	_busy -= 1
	changed.emit()
	return out


## DAVETİ KABUL: iki arkadaşlık belgesini de bu oyuncu yazar (belgede davet jetonu; kural daveti doğrular). Davet eden
## onaylamaz. Aradaki bekleyen istekler silinir. `invite`: read_invite sonucu.
func accept_invite(invite: Dictionary) -> bool:
	var uid: String = SaveSafe.s(invite.get("uid", ""))
	var token: String = SaveSafe.s(invite.get("token", ""))
	if not is_ready() or _busy > 0 or uid.is_empty() or uid == _uid or not SocialNames.is_valid_token(token):
		return false
	if is_friend(uid):
		notice.emit(Loc.t("Zaten arkadaşsınız."))
		return true
	if friends.size() >= MAX_FRIENDS:
		notice.emit(Loc.t("Arkadaş listen dolu."))
		return false
	_busy += 1
	changed.emit()
	if _profile and _profile.is_blocked(uid):
		_profile.unblock(uid)   # engellediği oyuncunun davetini kendisi kabul ediyor: engel kalkar
	var since: Dictionary = {"since": _now(), "inv": token}
	var mine: Dictionary = await _call(&"set", _friends_of(_uid), "f_" + uid, since)
	var theirs: Dictionary = await _call(&"set", _friends_of(uid), "f_" + _uid, since) if _ok(mine) else {}
	var ok: bool = _ok(mine) and _ok(theirs)
	if ok:
		if _index_of(incoming, uid) >= 0:
			await _call(&"delete", _inbox_of(_uid), "r_" + uid)
			await _call(&"delete", _outbox_of(uid), "o_" + _uid)
			incoming.remove_at(_index_of(incoming, uid))
		if _index_of(outgoing, uid) >= 0:
			await _call(&"delete", _inbox_of(uid), "r_" + _uid)
			await _call(&"delete", _outbox_of(_uid), "o_" + uid)
			outgoing.remove_at(_index_of(outgoing, uid))
		var person: Dictionary = invite.get("person", {}) if invite.get("person") is Dictionary else {}
		if person.is_empty():
			person = await _friend_entry(uid, {})
		if not person.is_empty():
			friends.append(person)
		notice.emit(Loc.t("%s artık arkadaşın!") % SaveSafe.s(person.get("name", invite.get("name", ""))))
	else:
		var failed: Dictionary = theirs if _ok(mine) else mine
		if _ok(mine):
			await _call(&"delete", _friends_of(_uid), "f_" + uid)   # yarım kalmasın: karşı taraf yazılamadıysa geri al
		# Kural reddi = davet geçersiz (süresi doldu / silindi); başka hata = bağlantı
		notice.emit(Loc.t("Bu davetin süresi dolmuş. Arkadaşından yeni bir link iste.") if _permission_denied(failed)
			else Loc.t("Arkadaş eklenemedi. İnternet bağlantını kontrol et."))
	_busy -= 1
	changed.emit()
	return ok


func _read_invite(token: String) -> Dictionary:
	var result: Dictionary = await _call(&"get", INVITES, token)
	if not _ok(result):
		return {"status": "missing" if _not_found(result) else "error", "token": token}
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var uid: String = SaveSafe.s(data.get("uid", ""))
	var at: int = SaveSafe.i(data.get("at", 0))
	if uid.is_empty():
		return {"status": "missing", "token": token}
	var person: Dictionary = await _friend_entry(uid, {"name": SaveSafe.s(data.get("name", "")),
		"code": SaveSafe.s(data.get("code", ""))})
	if person.is_empty():
		return {"status": "missing", "token": token}   # davet edenin hesabı silinmiş
	var status: String = "ok"
	if uid == _uid:
		status = "self"
	elif is_friend(uid):
		status = "friend"
	elif _now() >= at + INVITE_TTL:
		status = "expired"
	return {"status": status, "token": token, "uid": uid, "at": at, "name": SaveSafe.s(person.get("name", "")),
		"person": person}


## Kendi süresi dolmuş davetlerini siler (cihazdaki listeden; liste sunucuda okunamaz). `all`: hepsi (hesap silme).
func _prune_invites(all: bool = false) -> bool:
	var mine: Array = _meta.get("invites", []) if _meta.get("invites") is Array else []
	var keep: Array = []
	var ok: bool = true
	for entry: Variant in mine:
		var item: Dictionary = entry if entry is Dictionary else {}
		var token: String = SaveSafe.s(item.get("token", ""))
		if not all and _now() < SaveSafe.i(item.get("at", 0)) + INVITE_TTL:
			keep.append(item)
			continue
		if SocialNames.is_valid_token(token):
			var r: Dictionary = await _call(&"delete", INVITES, token)
			if not (_ok(r) or _not_found(r)):
				ok = false
				keep.append(item)   # sonra yeniden denenir
	_meta["invites"] = keep
	_write_meta()
	return ok


## Oyuncunun açık garajını okur ve ziyaret modunu açar. Başarısızsa false (mesaj notice ile).
func visit(uid: String) -> bool:
	if not is_ready() or _busy > 0:
		return false
	if _cloud and _cloud.is_busy():
		notice.emit(Loc.t("Kayıt buluta yazılıyor, birazdan tekrar dene."))
		return false
	_busy += 1
	changed.emit()
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	_busy -= 1
	changed.emit()
	if not _ok(result):
		notice.emit(Loc.t("Garaj açılamadı. İnternet bağlantını kontrol et.") if not _not_found(result)
			else Loc.t("Bu oyuncunun garajı bulunamadı."))
		return false
	var doc: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var garage: Dictionary = PublicGarage.parse(SaveSafe.s(doc.get("garage_json", "")))
	if garage.is_empty():
		notice.emit(Loc.t("Bu garaj oyunun daha yeni bir sürümüyle kaydedilmiş. Oyunu güncelle."))
		return false
	if _save:
		_save.save_game()   # kendi garajın donmadan önce son durum diskte olsun
	return GarageVisit.begin(get_tree(), {
		"uid": uid,
		"name": SaveSafe.s(doc.get("name", "")),
		"code": SaveSafe.s(doc.get("code", "")),
		"level": SaveSafe.i(doc.get("level", 1)),
		"value": SaveSafe.i(doc.get("value", 0)),
		"garage": garage,
		# BEĞEN yalnız gerçek arkadaşta (ustalara ziyaret yazılmaz); bugün beğendiysen düğme dolu gelir
		"can_like": is_friend(uid) and not FeaturedFriends.is_featured(uid),
		"liked_today": SaveSafe.i((_meta.get("likes_sent", {}) as Dictionary).get(uid, -1)) == _today()
			if _meta.get("likes_sent") is Dictionary else false,
	})


## Arkadaş garajından dönüldü (kendi sahne ağaca geri takıldı): ziyaret (ve beğeni) sahibine yazılır.
func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and not GarageVisit.is_visiting():
		var last: Dictionary = GarageVisit.take_last()
		if not last.is_empty():
			_send_visit.call_deferred(SaveSafe.s(last.get("uid", "")), bool(last.get("liked", false)))


func _send_visit(uid: String, liked: bool) -> void:
	if not is_ready() or uid.is_empty() or not is_friend(uid) or FeaturedFriends.is_featured(uid):
		return
	var sent: Dictionary = _meta.get("likes_sent", {}) if _meta.get("likes_sent") is Dictionary else {}
	var result: Dictionary = await _call(&"set", _visits_of(uid), "v_" + _uid,
		{"name": my_name(), "at": _now(), "day": _today(), "liked": liked})
	if _ok(result) and liked and SaveSafe.i(sent.get(uid, -1)) != _today():
		sent[uid] = _today()
		_meta["likes_sent"] = sent
		_write_meta()


## HESAP SİLME: bu oyuncunun bütün sosyal belgeleri silinir (arkadaşlıklar iki taraftan, istekler,
## açık garaj, kod). Auth kullanıcısı silinmeden ÖNCE çağrılmalı (sonra yetki kalmaz).
## Herhangi bir silme başarısızsa false; çağıran hesabı silmeyi durdurur.
## `uid`: oturumdaki Google hesabı. Sosyal oturum hiç açılmadıysa (oyun internetsiz açıldı, bulut kaydı hata
## durumunda) silme yine bu kimlikle yapılır; arkadaş kodu bu cihazda yoksa açık garajdan okunur (2026-10-17:
## önceden bu durumda sosyal veriler silinmeden kalıyordu).
func delete_all(uid: String = "") -> bool:
	if _fb == null:
		return true
	var borrowed: bool = _uid.is_empty()
	if borrowed:
		if uid.is_empty():
			return true
		_uid = uid
		_meta = _read_json(META_PATH)
		if SaveSafe.s(_meta.get("uid", "")) != uid:
			_meta = {"uid": uid}
		if my_code().is_empty():
			var own: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
			if _ok(own) and own.get("data") is Dictionary:
				_meta["code"] = SaveSafe.s((own["data"] as Dictionary).get("code", ""))
			elif not _not_found(own):
				_uid = ""   # garaja ulaşılamadı: silme başarısız, oturum açılmamış hâliyle kalır
				return false
	_publish_timer.stop()
	_busy += 1
	var ok: bool = true
	var lists: Array[Dictionary] = [
		await _call(&"list", _friends_of(_uid)), await _call(&"list", _inbox_of(_uid)),
		await _call(&"list", _outbox_of(_uid)),
	]
	for r: Dictionary in lists:
		ok = ok and _ok(r)
	if ok:
		for doc_id: String in _ids(lists[0]):
			var other: String = doc_id.trim_prefix("f_")
			await _call(&"delete", _friends_of(other), "f_" + _uid)
			ok = _ok(await _call(&"delete", _friends_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[1]):
			await _call(&"delete", _outbox_of(doc_id.trim_prefix("r_")), "o_" + _uid)
			ok = _ok(await _call(&"delete", _inbox_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[2]):
			await _call(&"delete", _inbox_of(doc_id.trim_prefix("o_")), "r_" + _uid)
			ok = _ok(await _call(&"delete", _outbox_of(_uid), doc_id)) and ok
		ok = _ok(await _call(&"delete", GARAGES, "g_" + _uid)) and ok
		# Yarış haberleri: bana gelenler ve arkadaşlara yazdıklarım (lists[0] arkadaş listesi)
		var news: Dictionary = await _call(&"list", _races_of(_uid))
		ok = _ok(news) and ok
		for doc_id: String in _ids(news):
			ok = _ok(await _call(&"delete", _races_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[0]):
			var sent: Dictionary = await _call(&"delete", _races_of(doc_id.trim_prefix("f_")), "e_" + _uid)
			ok = (_ok(sent) or _not_found(sent) or _permission_denied(sent)) and ok
		# Ziyaretler: bana gelenler ve arkadaşlara yazdıklarım
		var visits: Dictionary = await _call(&"list", _visits_of(_uid))
		ok = _ok(visits) and ok
		for doc_id: String in _ids(visits):
			ok = _ok(await _call(&"delete", _visits_of(_uid), doc_id)) and ok
		for doc_id: String in _ids(lists[0]):
			var mine: Dictionary = await _call(&"delete", _visits_of(doc_id.trim_prefix("f_")), "v_" + _uid)
			ok = (_ok(mine) or _not_found(mine) or _permission_denied(mine)) and ok
		var push_doc: Dictionary = await _call(&"delete", PUSH, "p_" + _uid)
		ok = (_ok(push_doc) or _not_found(push_doc)) and ok
		var avatar_doc: Dictionary = await _call(&"delete", AVATARS, "a_" + _uid)
		ok = (_ok(avatar_doc) or _not_found(avatar_doc)) and ok
		# Hurdalık hediyeleri GARAJDAN SONRA: sunucu bugünün hediyesini yalnızca garajı olmayan oyuncuya
		# sildirir (günlük sınır; bkz. firestore.rules gifts)
		var gifts: Dictionary = await _call(&"list", _gifts_of(_uid))
		ok = _ok(gifts) and ok
		for doc_id: String in _ids(gifts):
			ok = _ok(await _call(&"delete", _gifts_of(_uid), doc_id)) and ok
		var code: String = my_code()
		if not code.is_empty():
			var r: Dictionary = await _call(&"delete", CODES, code)
			ok = (_ok(r) or _permission_denied(r)) and ok   # kod başkasınınsa (eski meta) sorun değil
		ok = await _prune_invites(true) and ok   # davet linkleri (cihazda listelenenler)
	_busy -= 1
	if ok:
		_meta = {}
		DirAccess.remove_absolute(ProjectSettings.globalize_path(META_PATH))
		friends.clear()
		incoming.clear()
		outgoing.clear()
		_uid = ""   # hesap siliniyor: sonraki kayıtlar artık yayınlanmaz
		_set_state(State.SIGNED_OUT)
	elif borrowed:
		_uid = ""   # oturum açılmamıştı: başarısız silmeden sonra da öyle kalsın (sonra normal açılabilsin)
	return ok


# --- Oturum ----------------------------------------------------------------------

## Bulut kaydının durumuna göre sosyal oturumu açar / kapatır.
func _sync_session() -> void:
	var uid: String = _cloud.get_uid() if _cloud and _cloud.is_authenticated() else ""
	var synced: bool = _cloud != null and _cloud.get_state() == CloudSaveManager.State.SYNCED
	if uid.is_empty():
		if _uid != "" or _state != State.SIGNED_OUT:
			_uid = ""
			friends.clear()
			incoming.clear()
			outgoing.clear()
			_publish_timer.stop()
			_set_state(State.SIGNED_OUT)
		return
	if uid == _uid or not synced:
		return
	_uid = uid
	_start_session()


func _start_session() -> void:
	_meta = _read_json(META_PATH)
	if SaveSafe.s(_meta.get("uid", "")) == _uid and not my_code().is_empty() and not my_name().is_empty():
		_set_state(State.READY)
		await _restore_own_photo()
		_request_publish()   # bu cihazda değişmiş olabilir
		refresh(true)   # gelen istek sayısı HUD plakasında ekran açılmadan da görünsün
		return
	# Bu cihazda profil yok: başka cihazda / önceki kurulumda oluşturulmuş olabilir
	_set_state(State.LOADING)
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + _uid)
	if _ok(result):
		var doc: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
		_meta = {"uid": _uid, "name": SaveSafe.s(doc.get("name", "")), "code": SaveSafe.s(doc.get("code", "")),
			"published": SaveSafe.s(doc.get("garage_json", ""))}
		_write_meta()
		_set_state(State.READY)
		await _restore_own_photo()
		_request_publish()
		refresh(true)
	elif _not_found(result):
		_set_state(State.NO_PROFILE)
	else:
		_set_state(State.OFFLINE)


## OFFLINE'dan yeniden dener (ekran açılınca).
func retry() -> void:
	if _state == State.OFFLINE and not _uid.is_empty():
		_start_session()


# --- Garaj yayını ----------------------------------------------------------------

func _on_local_saved() -> void:
	_request_publish()


func _request_publish() -> void:
	if is_ready():
		_publish_timer.start(publish_delay)


func _on_publish_timeout() -> void:
	if not is_ready():
		return
	if _busy > 0:
		_request_publish()   # oyuncunun işlemi bitince
		return
	if _cloud and _cloud.get_state() != CloudSaveManager.State.SYNCED:
		return   # kayıt seçimi / çevrimdışı: bulut senkronu bitince yeni bir kayıt gelir
	var garage_json: String = _garage_json()
	if garage_json == SaveSafe.s(_meta.get("published", "")) and _ask_key() == SaveSafe.s(_meta.get("published_ask", "")) \
			and _profile_key() == SaveSafe.s(_meta.get("published_profile", "")):
		return
	await _publish(my_name())


## Profil düzenleme kapandı: açık garaj beklemeden yazılır (arkadaşlar yeni fotoğrafı hemen görsün).
func publish_now() -> void:
	if not is_ready():
		return
	_publish_timer.stop()
	if _busy > 0 or (_cloud and _cloud.get_state() != CloudSaveManager.State.SYNCED):
		_request_publish()
		return
	await _publish(my_name())


## Açık garajı (ve adı / kodu) yazar. Başarılıysa yayınlanan JSON cihazda hatırlanır.
func _publish(name: String) -> bool:
	if _save == null:
		return false
	var garage_json: String = _garage_json()
	if garage_json.length() > PublicGarage.MAX_JSON:
		push_warning("SocialManager: açık garaj çok büyük (%d), yayınlanmadı" % garage_json.length())
		return false
	var garage: Dictionary = JSON.parse_string(garage_json)
	var doc: Dictionary = {
		"name": name,
		"code": my_code(),
		"level": PublicGarage.level_of(garage),
		"value": GarageValue.compute(get_tree()),
		"garage_json": garage_json,
		"updated_at": _now(),
	}
	var ask: Dictionary = _current_ask()
	if not ask.is_empty():
		doc["ask"] = {"part": String(ask["part"]), "at": int(ask["at"])}
	if _profile:
		doc.merge(_profile.public_fields())
		# Avatar resmi garajdan ÖNCE: arkadaş yeni hash'i görünce belge hazır olsun
		if not await _upload_avatar():
			doc["av"] = SaveSafe.s(_meta.get("published_av", ""))   # resim yazılamadı: eski tanım kalsın
	var result: Dictionary = await _call(&"set", GARAGES, "g_" + _uid, doc)
	if not _ok(result):
		return false
	await _drop_unused_avatar()
	_meta["published"] = garage_json
	_meta["published_ask"] = _ask_key()
	_meta["published_profile"] = _profile_key()
	_write_meta()
	return true


## Açık profilin karşılaştırma anahtarı (değiştiyse yeniden yayınlanır). İstatistikler dahil değil: yalnızca
## garaj ya da profil değişince yazılır, yarış sayısı yüzünden her kayıtta yazılmasın.
func _profile_key() -> String:
	if _profile == null:
		return ""
	var fields: Dictionary = _profile.public_fields()
	fields.erase("stats")
	return JSON.stringify(fields, "", true)


## Kendi avatar resmini avatars/a_{uid} belgesine yazar (yalnızca hash değiştiyse). Yazılacak resim yoksa true.
func _upload_avatar() -> bool:
	var av: String = _profile.my_av()
	var hash: String = ProfileCatalog.image_hash(av)
	if hash.is_empty() or hash == SaveSafe.s(_meta.get("published_av_hash", "")):
		_meta["published_av"] = av
		return true
	var bytes: PackedByteArray = _profile.upload_bytes()
	var b64: String = Marshalls.raw_to_base64(bytes)
	if bytes.is_empty() or b64.length() > ProfileCatalog.PHOTO_B64_MAX:
		return false
	var result: Dictionary = await _call(&"set", AVATARS, "a_" + _uid, {"img": b64, "hash": hash, "at": _now()})
	if not _ok(result):
		return false
	_meta["published_av"] = av
	_meta["published_av_hash"] = hash
	_store_avatar(_uid, hash, bytes)   # kendi resmim de önbellekte (arkadaş satırı / kart aynı yoldan çizer)
	return true


## Avatar artık resim değilse (hazır avatar / kask / Google kapalı) sunucudaki son resim silinir: fotoğrafı
## kaldıran oyuncunun resmi hesap silinene kadar beklemesin (2026-10-17). Garaj belgesi yeni tanımla yazıldıktan
## SONRA çağrılır: arkadaşlar önce yeni tanımı görür. Silinemezse bir sonraki yayında yeniden denenir.
func _drop_unused_avatar() -> void:
	if SaveSafe.s(_meta.get("published_av_hash", "")).is_empty():
		return
	if not ProfileCatalog.image_hash(SaveSafe.s(_meta.get("published_av", ""))).is_empty():
		return
	var r: Dictionary = await _call(&"delete", AVATARS, "a_" + _uid)
	if _ok(r) or _not_found(r):
		_meta.erase("published_av_hash")


# --- Hurdalık hediyesi -----------------------------------------------------------

## Arkadaşlardan bu parçayı ister: istek açık garajda yayınlanır (6 saatte bir).
func ask_part(part_id: StringName) -> bool:
	var jy: JunkyardManager = _junkyard()
	if not is_ready() or jy == null:
		notice.emit(Loc.t("Arkadaşlarından istemek için Google hesabınla giriş yap."))
		return false
	if friends.is_empty():
		notice.emit(Loc.t("Önce ARKADAŞLAR'dan bir arkadaş ekle."))
		return false
	if not jy.set_ask(part_id):
		notice.emit(Loc.t("Yeniden istemek için %s bekle.") % _clock_text(jy.ask_seconds_left()))
		return false
	_busy += 1
	changed.emit()
	var ok: bool = await _publish(my_name())
	_busy -= 1
	changed.emit()
	notice.emit(Loc.t("Arkadaşlarından %s istedin.") % RestorationCatalog.part_name(part_id) if ok
		else Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
	return ok


## Bu arkadaşa bugün hediye gönderilebilir mi (bir şey istiyor ve bugün gönderilmedi)?
func can_gift(uid: String) -> bool:
	var i: int = _index_of(friends, uid)
	if i < 0 or SaveSafe.s(friends[i].get("ask_part", "")).is_empty():
		return false
	return SaveSafe.i((_meta.get("gifts_sent", {}) as Dictionary).get(uid, -1)) != _today()


## Arkadaşın istediği parçadan 1 tane gönderir (gönderene bedava). Günde bir.
func send_gift(uid: String) -> bool:
	var i: int = _index_of(friends, uid)
	if not is_ready() or i < 0:
		return false
	var part: String = SaveSafe.s(friends[i].get("ask_part", ""))
	if part.is_empty():
		return false
	_busy += 1
	changed.emit()
	var day: int = _today()
	var result: Dictionary = await _call(&"set", _gifts_of(uid), "p_%s_%d" % [_uid, day],
		{"part": part, "name": my_name(), "at": _now(), "day": day})
	_busy -= 1
	var ok: bool = _ok(result)
	if ok or _permission_denied(result):
		var sent: Dictionary = _meta.get("gifts_sent", {}) if _meta.get("gifts_sent") is Dictionary else {}
		sent[uid] = day
		_meta["gifts_sent"] = sent
		_write_meta()
	if ok:
		notice.emit(Loc.t("%s oyuncusuna 1 %s gönderdin.") % [SaveSafe.s(friends[i].get("name", "")),
			RestorationCatalog.part_name(StringName(part))])
	elif _permission_denied(result):
		notice.emit(Loc.t("Bugün bu arkadaşına zaten hediye gönderdin."))
	else:
		notice.emit(Loc.t("Hediye gönderilemedi. İnternet bağlantını kontrol et."))
	changed.emit()
	return ok


## Gelen hediyeleri envantere ekler (her biri bir kez) ve dünkü / eski belgeleri temizler.
## Toplanan parça sayısı.
func collect_gifts() -> int:
	var jy: JunkyardManager = _junkyard()
	if not is_ready() or jy == null:
		return 0
	var result: Dictionary = await _call(&"list", _gifts_of(_uid))
	if not _ok(result):
		return 0
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var got: int = 0
	var names: PackedStringArray = PackedStringArray()
	var today: int = _today()
	for key: Variant in data:
		var id: String = SaveSafe.s(key)
		var doc: Dictionary = data[key] if data[key] is Dictionary else {}
		if not id.begins_with("p_"):
			continue
		if jy.receive_gift(id, StringName(SaveSafe.s(doc.get("part", "")))):
			got += 1
			var who: String = SaveSafe.s(doc.get("name", ""))
			if not who.is_empty() and not names.has(who):
				names.append(who)
			if quiet:
				_log_gift(id, who, SaveSafe.s(doc.get("part", "")))
		if SaveSafe.i(doc.get("day", today)) < today and _ok(await _call(&"delete", _gifts_of(_uid), id)):
			jy.forget_gift(id)
	if got > 0 and not quiet:
		notice.emit(Loc.t("ARKADAŞ HEDİYESİ  +%d PARÇA\n%s") % [got, ", ".join(names)])
	elif got > 0:
		_write_meta()   # gazeteye kalan hediyeler kaybolmasın
	return got


## Gazete topluyorken gelen hediye: gönderen (belge kimliği p_{gön}_{gün}), adı ve parçası gazete için saklanır.
func _log_gift(id: String, name: String, part: String) -> void:
	var body: String = id.trim_prefix("p_")
	var from: String = body.substr(0, body.rfind("_")) if body.rfind("_") > 0 else body
	var log: Array = _meta.get("gift_log", []) if _meta.get("gift_log") is Array else []
	log.append({"uid": from, "name": name, "part": part})
	_meta["gift_log"] = log


func _current_ask() -> Dictionary:
	var jy: JunkyardManager = _junkyard()
	return jy.current_ask() if jy else {}


func _ask_key() -> String:
	var ask: Dictionary = _current_ask()
	return "" if ask.is_empty() else "%s@%d" % [ask["part"], int(ask["at"])]


func _junkyard() -> JunkyardManager:
	return get_tree().get_first_node_in_group("junkyard") as JunkyardManager if is_inside_tree() else null


## UTC gün numarası (kurallar sunucu saatiyle aynısını hesaplar).
static func _today() -> int:
	return floori(float(_now()) / 86400.0)


static func _clock_text(seconds: int) -> String:
	var s: int = maxi(seconds, 0)
	return "%d:%02d" % [s / 3600, (s % 3600) / 60] if s >= 3600 else "%d dk" % maxi(s / 60, 1)


func _garage_json() -> String:
	return PublicGarage.to_json(PublicGarage.from_snapshot(_save.snapshot())) if _save else ""


## Boşta bir kod bulup alır (codes/{KOD} = {uid}). Alınamazsa boş.
func _claim_code() -> String:
	for i: int in CODE_ATTEMPTS:
		var code: String = SocialNames.random_code()
		var result: Dictionary = await _call(&"set", CODES, code, {"uid": _uid})
		if _ok(result):
			return code
		if not _permission_denied(result):
			return ""   # çevrimdışı vb.: yeni kod denemek boşuna
	return ""


# --- İstek / liste ---------------------------------------------------------------

func _send_request(code: String) -> bool:
	var found: Dictionary = await _call(&"get", CODES, code)
	if not _ok(found):
		notice.emit(Loc.t("Bu kodla bir oyuncu bulunamadı.") if _not_found(found)
			else Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	var data: Dictionary = found.get("data", {}) if found.get("data") is Dictionary else {}
	var uid: String = SaveSafe.s(data.get("uid", ""))
	if uid.is_empty() or uid == _uid:
		notice.emit(Loc.t("Bu senin kendi kodun.") if uid == _uid else Loc.t("Bu kodla bir oyuncu bulunamadı."))
		return false
	if is_friend(uid):
		notice.emit(Loc.t("Zaten arkadaşsınız."))
		return false
	if _profile and _profile.is_blocked(uid):
		_profile.unblock(uid)   # engellediği oyuncuyu kendi isteğiyle ekliyor: engel kalkar
		notice.emit(Loc.t("Bu oyuncunun engeli kaldırıldı."))
	if _index_of(outgoing, uid) >= 0:
		notice.emit(Loc.t("Bu oyuncuya zaten istek gönderdin."))
		return false
	if _index_of(incoming, uid) >= 0:
		return await _accept(uid)   # o da istek göndermiş: doğrudan arkadaş olunur
	var garage: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	if not _ok(garage):
		notice.emit(Loc.t("Bu kodla bir oyuncu bulunamadı.") if _not_found(garage)
			else Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	var their: Dictionary = garage.get("data", {}) if garage.get("data") is Dictionary else {}
	var at: int = _now()
	var mine: Dictionary = {"name": my_name(), "code": my_code(), "at": at}
	var theirs: Dictionary = {"name": SaveSafe.s(their.get("name", "")), "code": code, "at": at}
	if not _ok(await _call(&"set", _inbox_of(uid), "r_" + _uid, mine)):
		notice.emit(Loc.t("İstek gönderilemedi. İnternet bağlantını kontrol et."))
		return false
	await _call(&"set", _outbox_of(_uid), "o_" + uid, theirs)   # yalnızca bekleyen listesi için
	var entry: Dictionary = theirs.duplicate()
	entry["uid"] = uid
	outgoing.append(entry)
	notice.emit(Loc.t("%s oyuncusuna istek gönderildi.") % theirs["name"])
	return true


## Arkadaşlığı kurar: iki belgeyi de kabul eden (bu oyuncu) yazar, sonra istek kayıtları silinir.
func _accept(uid: String) -> bool:
	var at: int = _index_of(incoming, uid)
	var since: Dictionary = {"since": _now()}
	var ok: bool = _ok(await _call(&"set", _friends_of(_uid), "f_" + uid, since)) \
		and _ok(await _call(&"set", _friends_of(uid), "f_" + _uid, since))
	if not ok:
		notice.emit(Loc.t("İstek kabul edilemedi. Tekrar dene."))
		return false
	await _call(&"delete", _inbox_of(_uid), "r_" + uid)
	await _call(&"delete", _outbox_of(uid), "o_" + _uid)   # karşı tarafın bekleyen listesi
	var entry: Dictionary = incoming[at]
	incoming.remove_at(at)
	var friend: Dictionary = await _friend_entry(uid, entry)
	if not friend.is_empty():
		friends.append(friend)
	notice.emit(Loc.t("%s artık arkadaşın!") % SaveSafe.s(entry.get("name", "")))
	return true


func _load_lists() -> bool:
	var friend_list: Dictionary = await _call(&"list", _friends_of(_uid))
	var inbox: Dictionary = await _call(&"list", _inbox_of(_uid))
	var outbox: Dictionary = await _call(&"list", _outbox_of(_uid))
	if not (_ok(friend_list) and _ok(inbox) and _ok(outbox)):
		return false
	incoming = _requests(inbox, "r_")
	outgoing = _requests(outbox, "o_")
	var kept: Array[Dictionary] = []
	for entry: Dictionary in incoming:
		var from: String = entry["uid"]
		if _profile and _profile.is_blocked(from):
			await _call(&"delete", _inbox_of(_uid), "r_" + from)   # engellenenin isteği: sessizce silinir
			await _call(&"delete", _outbox_of(from), "o_" + _uid)
			continue
		# İstek gönderenin fotoğrafı / bayrağı (karar verirken kim olduğu görünsün)
		var garage: Dictionary = await _call(&"get", GARAGES, "g_" + from)
		if _ok(garage) and garage.get("data") is Dictionary:
			entry.merge(profile_fields(garage["data"]))
		kept.append(entry)
	incoming = kept
	var loaded: Array[Dictionary] = []
	for doc_id: String in _ids(friend_list):
		var uid: String = doc_id.trim_prefix("f_")
		var entry: Dictionary = await _friend_entry(uid, {})
		if entry.is_empty():
			# Arkadaş hesabını silmiş: kendi listemizden de düşer
			await _call(&"delete", _friends_of(_uid), doc_id)
			continue
		loaded.append(entry)
	loaded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["level"]) > int(b["level"]))
	friends = loaded
	# Haberler arkadaş listesinden SONRA: "artık arkadaş değil" süzgeci güncel listeye bakar (önce okununca bütün
	# haberler silinirdi)
	await _load_race_events()
	await _load_visits()
	return true


## Garajıma gelen ziyaretler: beğeniler sayılır (ziyaretçi başına günde bir; toplam PlayerProfile.likes, açık garajda),
## ziyaret gazete için kaydedilir (gazete toplanmıyorsa küçük bildirim) ve sunucudan silinir.
func _load_visits() -> void:
	var result: Dictionary = await _call(&"list", _visits_of(_uid))
	if not _ok(result):
		return
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var log: Array = _meta.get("visit_log", []) if _meta.get("visit_log") is Array else []
	var counted: Dictionary = _meta.get("likes_counted", {}) if _meta.get("likes_counted") is Dictionary else {}
	var liked_names: PackedStringArray = PackedStringArray()
	var visit_names: PackedStringArray = PackedStringArray()
	var changed_meta: bool = false
	for key: Variant in data:
		var id: String = SaveSafe.s(key)
		var doc: Dictionary = data[key] if data[key] is Dictionary else {}
		var from: String = id.trim_prefix("v_")
		if not id.begins_with("v_") or doc.is_empty():
			continue
		if (_profile and _profile.is_blocked(from)) or not is_friend(from):
			await _call(&"delete", _visits_of(_uid), id)
			continue
		var name: String = SaveSafe.s(person(from).get("name", doc.get("name", "")))
		var day: int = SaveSafe.i(doc.get("day", 0))
		var like: bool = bool(doc.get("liked", false)) and day > SaveSafe.i(counted.get(from, -1))
		if like:
			counted[from] = day
			if _profile:
				_profile.add_like()
		if quiet:
			log.append({"uid": from, "name": name, "liked": like})
		elif like:
			liked_names.append(name)
		else:
			visit_names.append(name)
		changed_meta = true
		await _call(&"delete", _visits_of(_uid), id)
	if not changed_meta:
		return
	_meta["visit_log"] = log
	_meta["likes_counted"] = counted
	_write_meta()
	if not liked_names.is_empty():
		notice.emit(Loc.t("%s GARAJINI BEĞENDİ") % Loc.upper(", ".join(liked_names)))
	elif not visit_names.is_empty():
		notice.emit(Loc.t("%s GARAJINI GEZDİ") % Loc.upper(", ".join(visit_names)))


## Arkadaşın güncel adı / seviyesi açık garajından. Garaj yoksa (hesap silinmiş) boş; okunamazsa
## eldeki bilgiyle döner.
func _friend_entry(uid: String, fallback: Dictionary) -> Dictionary:
	var result: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
	if _not_found(result):
		return {}
	var doc: Dictionary = result.get("data", {}) if _ok(result) and result.get("data") is Dictionary else fallback
	var ask_part: String = ""
	var ask_at: int = 0
	var ask: Variant = doc.get("ask", {})
	if ask is Dictionary and RestorationCatalog.is_part(StringName(SaveSafe.s(ask.get("part", "")))) \
			and _now() - SaveSafe.i(ask.get("at", 0)) < JunkyardManager.ASK_LIFETIME:
		ask_part = SaveSafe.s(ask.get("part", ""))
		ask_at = SaveSafe.i(ask.get("at", 0))
	var entry: Dictionary = {
		"uid": uid,
		"name": SaveSafe.s(doc.get("name", fallback.get("name", ""))),
		"code": SaveSafe.s(doc.get("code", fallback.get("code", ""))),
		"level": maxi(SaveSafe.i(doc.get("level", 1)), 1),
		"value": SaveSafe.i(doc.get("value", 0)),
		"ask_part": ask_part,
		"ask_at": ask_at,
	}
	entry.merge(profile_fields(doc))
	# Yarış: arkadaşın araçları, boyaları, modifiyeleri (garaj belgesi zaten okundu, ek okuma yok)
	entry["race"] = PublicGarage.race_data(PublicGarage.parse(SaveSafe.s(doc.get("garage_json", ""))))
	return entry


## Açık garaj belgesinden profil alanları (geçersiz değerler boşa düşer; eski sürümün belgesinde hiçbiri yoktur).
static func profile_fields(doc: Dictionary) -> Dictionary:
	var av: String = SaveSafe.s(doc.get("av", ""))
	var frame: String = SaveSafe.s(doc.get("frame", ""))
	var flag: String = SaveSafe.s(doc.get("flag", ""))
	var title: String = SaveSafe.s(doc.get("title", ""))
	var car: String = SaveSafe.s(doc.get("car", ""))
	var raw_stats: Dictionary = doc.get("stats", {}) if doc.get("stats") is Dictionary else {}
	return {
		"av": av if ProfileCatalog.is_valid_av(av) else "",
		"frame": frame if ProfileCatalog.is_frame(frame) else ProfileCatalog.DEFAULT_FRAME,
		"flag": flag if ProfileCatalog.is_flag(flag) else "",
		"title": title if SocialNames.is_valid_title(title) else "",
		"car": car if not CarCatalog.get_entry(StringName(car)).is_empty() else "",
		"stats": {
			"wins": maxi(SaveSafe.i(raw_stats.get("wins", 0)), 0),
			"races": maxi(SaveSafe.i(raw_stats.get("races", 0)), 0),
			"cars": maxi(SaveSafe.i(raw_stats.get("cars", 0)), 0),
			"best": maxi(SaveSafe.i(raw_stats.get("best", 0)), 0),
			"best_car": SaveSafe.s(raw_stats.get("best_car", "")),
		},
	}


func _requests(result: Dictionary, prefix: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	for doc_id: Variant in data:
		var doc: Dictionary = data[doc_id] if data[doc_id] is Dictionary else {}
		var id: String = SaveSafe.s(doc_id)
		if not id.begins_with(prefix):
			continue
		out.append({"uid": id.trim_prefix(prefix), "name": SaveSafe.s(doc.get("name", "")),
			"code": SaveSafe.s(doc.get("code", "")), "at": SaveSafe.i(doc.get("at", 0))})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	return out


# --- Avatarlar ------------------------------------------------------------------------

## Bir oyuncunun avatar resmi: {"texture", "illustrated"}. Hazır avatar hemen gelir; yüklenmiş fotoğraf önbellekte
## yoksa indirmesi başlar (bitince avatar_ready) ve o sırada kask gösterilir. Engellenen / şikâyet edilip gizlenen
## oyuncunun fotoğrafı yerine kask.
func avatar_of(uid: String, av: String) -> Dictionary:
	if FeaturedFriends.is_featured(uid):
		return {"texture": ProfileCatalog.featured_texture(uid), "illustrated": true}
	var hash: String = ProfileCatalog.image_hash(av)
	if (_profile and _profile.is_blocked(uid)) or (_profile and _profile.is_hidden(uid, hash)):
		return {"texture": ProfileCatalog.default_texture(), "illustrated": true}
	if ProfileCatalog.is_preset(av):
		return {"texture": ProfileCatalog.preset_texture(av), "illustrated": true}
	if hash.is_empty():
		return {"texture": ProfileCatalog.default_texture(), "illustrated": true}
	var cached: Dictionary = _avatars.get(uid, {})
	if SaveSafe.s(cached.get("hash", "")) == hash and cached.get("tex") is Texture2D:
		return {"texture": cached["tex"], "illustrated": false}
	if SaveSafe.s(_avatar_index.get(uid, "")) == hash:
		var tex: Texture2D = _avatar_from_disk(uid)
		if tex:
			_avatars[uid] = {"hash": hash, "tex": tex}
			return {"texture": tex, "illustrated": false}
	_fetch_avatar(uid, hash)
	return {"texture": ProfileCatalog.default_texture(), "illustrated": true}


## Arkadaş / istek listesindeki bir oyuncunun girdisi (profil kartı için); yoksa boş.
func person(uid: String) -> Dictionary:
	for list: Array[Dictionary] in [friends, incoming, outgoing]:
		var i: int = _index_of(list, uid)
		if i >= 0:
			return list[i]
	return {}


func _fetch_avatar(uid: String, hash: String) -> void:
	if _avatar_pending.get(uid, "") == hash or not is_ready():
		return
	_avatar_pending[uid] = hash
	var result: Dictionary = await _call(&"get", AVATARS, "a_" + uid)
	_avatar_pending.erase(uid)
	if not _ok(result) or not result.get("data") is Dictionary:
		return
	var data: Dictionary = result["data"]
	var b64: String = SaveSafe.s(data.get("img", ""))
	if b64.is_empty() or b64.length() > ProfileCatalog.PHOTO_B64_MAX:
		return
	var bytes: PackedByteArray = Marshalls.base64_to_raw(b64)
	var got: String = ProfileCatalog.hash_of(bytes)
	if ProfileCatalog.image_from_bytes(bytes) == null:
		return
	_store_avatar(uid, got, bytes)
	avatar_ready.emit(uid)


func _store_avatar(uid: String, hash: String, bytes: PackedByteArray) -> void:
	var image: Image = ProfileCatalog.image_from_bytes(bytes)
	if image == null:
		return
	_avatars[uid] = {"hash": hash, "tex": ImageTexture.create_from_image(image)}
	DirAccess.make_dir_recursive_absolute(AVATAR_CACHE_DIR)
	var file: FileAccess = FileAccess.open(AVATAR_CACHE_DIR + uid.validate_filename() + ".jpg", FileAccess.WRITE)
	if file:
		file.store_buffer(bytes)
		file.close()
		_avatar_index[uid] = hash
		var index: FileAccess = FileAccess.open(AVATAR_CACHE_INDEX, FileAccess.WRITE)
		if index:
			index.store_string(JSON.stringify(_avatar_index))


func _avatar_from_disk(uid: String) -> Texture2D:
	var path: String = AVATAR_CACHE_DIR + uid.validate_filename() + ".jpg"
	if not FileAccess.file_exists(path):
		return null
	var image: Image = ProfileCatalog.image_from_bytes(FileAccess.get_file_as_bytes(path))
	return ImageTexture.create_from_image(image) if image else null


func _load_avatar_index() -> void:
	_avatar_index = _read_json(AVATAR_CACHE_INDEX)


## Yeni cihaz / yeniden kurulum: kayıtta fotoğraf seçili ama dosyası yok → kendi avatar belgesinden geri yüklenir.
func _restore_own_photo() -> void:
	if _profile == null or not _profile.needs_photo_restore():
		return
	var result: Dictionary = await _call(&"get", AVATARS, "a_" + _uid)
	if _ok(result) and result.get("data") is Dictionary:
		_profile.restore_photo(Marshalls.base64_to_raw(SaveSafe.s((result["data"] as Dictionary).get("img", ""))))


# --- Yarış haberleri -----------------------------------------------------------------

## Gönderenin haberi (yoksa boş).
func race_event(uid: String) -> Dictionary:
	var i: int = _index_of(race_events, uid)
	return race_events[i] if i >= 0 else {}


## İNTİKAM yarışının rakip sahibi (RaceManager.start_revenge): gönderenin profili + haberdeki boya / modifiye.
func revenge_owner(uid: String) -> Dictionary:
	var event: Dictionary = race_event(uid)
	if event.is_empty():
		return {}
	return {"uid": uid, "name": event["name"], "av": SaveSafe.s(event.get("av", "")), "frame": SaveSafe.s(event.get("frame", "")),
		"flag": SaveSafe.s(event.get("flag", "")), "featured": false, "paint": event["paint"], "build": event["build"]}


## Haber kapatıldı (TAMAM) ya da İNTİKAM için kullanıldı: sunucudan silinir.
func dismiss_event(uid: String) -> void:
	var i: int = _index_of(race_events, uid)
	if i < 0:
		return
	race_events.remove_at(i)
	changed.emit()
	if is_ready():
		await _call(&"delete", _races_of(_uid), "e_" + uid)


func _load_race_events() -> void:
	var result: Dictionary = await _call(&"list", _races_of(_uid))
	if not _ok(result):
		return
	var data: Dictionary = result.get("data", {}) if result.get("data") is Dictionary else {}
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager if is_inside_tree() else null
	var seen: Dictionary = _meta.get("events_seen", {}) if _meta.get("events_seen") is Dictionary else {}
	var loaded: Array[Dictionary] = []
	var fresh: Array[Dictionary] = []
	for key: Variant in data:
		var id: String = SaveSafe.s(key)
		var doc: Dictionary = data[key] if data[key] is Dictionary else {}
		var from: String = id.trim_prefix("e_")
		if not id.begins_with("e_") or doc.is_empty():
			continue
		if (_profile and _profile.is_blocked(from)) or not is_friend(from):
			await _call(&"delete", _races_of(_uid), id)   # engellenen / artık arkadaş olmayan: sessizce silinir
			continue
		var event: Dictionary = _parse_event(from, doc)
		if event.is_empty():
			continue
		if race:
			race.set_their_counts(from, int(event["mw"]), int(event["ml"]))   # skorun onun yönü
		loaded.append(event)
		if SaveSafe.i(seen.get(from, -1)) != int(event["at"]):
			fresh.append(event)
			seen[from] = int(event["at"])
	loaded.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) > int(b["at"]))
	race_events = loaded
	if not fresh.is_empty():
		_meta["events_seen"] = seen
		for event: Dictionary in fresh:
			race_news.emit(event)
			if not quiet:
				_note_race_seen(event)   # bildirimi görüldü: gazete tekrarlamasın
		_write_meta()


# --- OTO MANŞET ------------------------------------------------------------------------------------

## Son gazeteden bu yana arkadaş haberleri (NewsDigest ham haberleri). `since`: tabanı olmayan olay (ilk gazete) bu
## andan eskiyse sayılmaz. Gösterilen durum saklanır; news_shown() tabana yazar. İlk çağrıda arkadaş / istek tabanı
## boşsa o anki liste taban olur (güncellemeden sonraki ilk gazete "10 yeni arkadaş" demesin).
func news_items(since: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	_news_next = {}
	_news_gifts = 0
	_news_visits = 0
	if not is_ready():
		return out
	var base: Dictionary = _meta.get("news", {}) if _meta.get("news") is Dictionary else {}
	var at: int = maxi(SaveSafe.i(base.get("at", 0)), since)
	var scores: Dictionary = base.get("scores", {}) if base.get("scores") is Dictionary else {}
	var next: Dictionary = {"scores": scores.duplicate(), "asks": (base.get("asks", {}) as Dictionary).duplicate()
		if base.get("asks") is Dictionary else {}, "at": _now()}
	for event: Dictionary in race_events:
		var uid: String = event["uid"]
		var mw: int = int(event["mw"])
		var ml: int = int(event["ml"])
		var lost: int = 0
		var won: int = 0
		var old: Variant = scores.get(uid)
		if old is Array and (old as Array).size() == 2:
			lost = maxi(mw - SaveSafe.i(old[0]), 0)
			won = maxi(ml - SaveSafe.i(old[1]), 0)
		elif int(event["at"]) > at:
			lost = 1 if bool(event["won"]) else 0
			won = 0 if bool(event["won"]) else 1
		next["scores"][uid] = [mw, ml]
		if lost > 0:
			out.append({"kind": NewsDigest.RACE_LOST, "people": [_news_person(uid, event)], "count": lost, "car": event["car"]})
		if won > 0:
			out.append({"kind": NewsDigest.RACE_WON, "people": [_news_person(uid, event)], "count": won, "car": event["their_car"]})
	var log: Array = _meta.get("gift_log", []) if _meta.get("gift_log") is Array else []
	for gift: Variant in log:
		if gift is Dictionary and not RestorationCatalog.part(StringName(SaveSafe.s(gift.get("part", "")))).is_empty():
			var from: String = SaveSafe.s(gift.get("uid", ""))
			out.append({"kind": NewsDigest.GIFT, "people": [_news_person(from, {"name": SaveSafe.s(gift.get("name", ""))})],
				"parts": {StringName(SaveSafe.s(gift["part"])): 1}})
	_news_gifts = log.size()
	var visits: Array = _meta.get("visit_log", []) if _meta.get("visit_log") is Array else []
	for visit: Variant in visits:
		if visit is Dictionary:
			var from: String = SaveSafe.s(visit.get("uid", ""))
			out.append({"kind": NewsDigest.VISIT, "people": [_news_person(from, {"name": SaveSafe.s(visit.get("name", ""))})],
				"likes": 1 if bool(visit.get("liked", false)) else 0})
	_news_visits = visits.size()
	var friend_ids: Array = friends.map(func(f: Dictionary) -> String: return String(f["uid"]))
	var request_ids: Array = incoming.map(func(r: Dictionary) -> String: return String(r["uid"]))
	if base.get("friends") is Array:
		for uid: String in friend_ids:
			if not (base["friends"] as Array).has(uid):
				out.append({"kind": NewsDigest.FRIEND_NEW, "people": [_news_person(uid, {})]})
	if base.get("requests") is Array:
		for uid: String in request_ids:
			if not (base["requests"] as Array).has(uid):
				out.append({"kind": NewsDigest.FRIEND_REQUEST, "people": [_news_person(uid, {})]})
	next["friends"] = friend_ids
	next["requests"] = request_ids
	for entry: Dictionary in friends:
		var uid: String = entry["uid"]
		var ask_at: int = SaveSafe.i(entry.get("ask_at", 0))
		var part: StringName = StringName(SaveSafe.s(entry.get("ask_part", "")))
		if part != &"" and ask_at > SaveSafe.i(next["asks"].get(uid, at)) and can_gift(uid):
			out.append({"kind": NewsDigest.ASK, "people": [_news_person(uid, entry)], "part": part})
		if part != &"":
			next["asks"][uid] = maxi(ask_at, SaveSafe.i(next["asks"].get(uid, 0)))
	if not base.get("friends") is Array or not base.get("requests") is Array:
		var first: Dictionary = base.duplicate()
		first["friends"] = friend_ids
		first["requests"] = request_ids
		_meta["news"] = first   # ilk taban hemen yazılır (gazete açılmasa da)
		_write_meta()
	_news_next = next
	return out


## Gazete gösterildi: taban gösterilen duruma ilerler, gösterilen hediye kayıtları silinir.
func news_shown() -> void:
	if _news_next.is_empty():
		return
	_meta["news"] = _news_next
	var log: Array = _meta.get("gift_log", []) if _meta.get("gift_log") is Array else []
	_meta["gift_log"] = log.slice(mini(_news_gifts, log.size()))
	var visits: Array = _meta.get("visit_log", []) if _meta.get("visit_log") is Array else []
	_meta["visit_log"] = visits.slice(mini(_news_visits, visits.size()))
	_news_next = {}
	_news_gifts = 0
	_news_visits = 0
	_write_meta()


## Gazeteye girmeyen (oyun içinde bildirimi görülen) yarış haberi: tabanı hemen ilerler.
func _note_race_seen(event: Dictionary) -> void:
	var base: Dictionary = _meta.get("news", {}) if _meta.get("news") is Dictionary else {}
	var scores: Dictionary = base.get("scores", {}) if base.get("scores") is Dictionary else {}
	scores[String(event["uid"])] = [int(event["mw"]), int(event["ml"])]
	base["scores"] = scores
	_meta["news"] = base


## Gazetedeki kişi: arkadaş listesindeki güncel ad / fotoğraf, yoksa haberdeki ad.
func _news_person(uid: String, fallback: Dictionary) -> Dictionary:
	var entry: Dictionary = person(uid)
	var source: Dictionary = entry if not entry.is_empty() else fallback
	return {"uid": uid, "name": SaveSafe.s(source.get("name", fallback.get("name", ""))), "av": SaveSafe.s(source.get("av", "")),
		"frame": SaveSafe.s(source.get("frame", "")), "flag": SaveSafe.s(source.get("flag", ""))}


## Sunucudaki haber belgesi → haber (biçimsiz alanlar elenir) + arkadaşın profili (fotoğraf / çerçeve / bayrak).
func _parse_event(from: String, doc: Dictionary) -> Dictionary:
	var car: StringName = StringName(SaveSafe.s(doc.get("car", "")))
	var their: StringName = StringName(SaveSafe.s(doc.get("their_car", "")))
	if CarCatalog.get_entry(car).is_empty() or CarCatalog.get_entry(their).is_empty():
		return {}
	var paint: String = SaveSafe.s(doc.get("paint", ""))
	var event: Dictionary = {
		"uid": from, "name": SaveSafe.s(doc.get("name", "")), "car": car, "their_car": their,
		"paint": paint if Color.html_is_valid(paint) else "",
		"build": PerformanceMods.normalized(doc.get("build", {}) if doc.get("build") is Dictionary else {}),
		"won": bool(doc.get("won", false)), "revenge": bool(doc.get("revenge", false)),
		"mw": maxi(SaveSafe.i(doc.get("mw", 0)), 0), "ml": maxi(SaveSafe.i(doc.get("ml", 0)), 0),
		"at": SaveSafe.i(doc.get("at", 0)),
	}
	var friend: Dictionary = person(from)
	for key: String in ["av", "frame", "flag"]:
		event[key] = SaveSafe.s(friend.get(key, ""))
	if SaveSafe.s(friend.get("name", "")) != "":
		event["name"] = friend["name"]   # güncel takma ad
	return event


## Gerçek arkadaşın aracıyla yarış bitti: ona haber yazılır (Emre / Elif'e yazılmaz). İNTİKAM için benim aracımın
## boyası ve modifiyeleri de gider; skorun benim yönüm (mw / ml) habere eklenir.
func _on_friend_race_finished(owner: Dictionary, won: bool, my_car: StringName, their_car: StringName, revenge: bool) -> void:
	var uid: String = SaveSafe.s(owner.get("uid", ""))
	if not is_ready() or uid.is_empty() or bool(owner.get("featured", false)) or not is_friend(uid):
		return
	var race: RaceManager = get_tree().get_first_node_in_group("race") as RaceManager
	var counts: Vector2i = race.my_counts(uid) if race else Vector2i.ZERO
	var ownership: VehicleOwnership = get_tree().get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	var paint: String = SaveSafe.s((ownership.paint_state() if ownership else {}).get(String(my_car), ""))
	var build: Dictionary = {}
	var mine: Dictionary = PerformanceMods.build_of(my_car)
	for category: StringName in mine:
		build[String(category)] = int(mine[category])
	var doc: Dictionary = {"name": my_name(), "car": String(my_car), "paint": paint, "build": build,
		"their_car": String(their_car), "won": won, "revenge": revenge, "mw": counts.x, "ml": counts.y, "at": _now()}
	await _call(&"set", _races_of(uid), "e_" + _uid, doc)


# --- Şikâyet / engelleme ----------------------------------------------------------

## Oyuncuyu şikâyet eder (reports/x_{ben}_{o}); fotoğrafı bu ekranda hemen gizlenir. Rapor konsoldan incelenir.
func report(uid: String, reason: String) -> bool:
	if not is_ready() or FeaturedFriends.is_featured(uid) or uid == _uid or not REPORT_REASONS.has(reason):
		return false
	var who: Dictionary = person(uid)
	if who.is_empty():
		var garage: Dictionary = await _call(&"get", GARAGES, "g_" + uid)
		if _ok(garage) and garage.get("data") is Dictionary:
			who = profile_fields(garage["data"])
			who["name"] = SaveSafe.s((garage["data"] as Dictionary).get("name", ""))
	var av: String = SaveSafe.s(who.get("av", ""))
	var doc: Dictionary = {"target": uid, "reason": reason, "av": av, "name": SaveSafe.s(who.get("name", "")), "at": _now()}
	# Şikâyet anındaki fotoğraf da rapora girer: oyuncu sonra değiştirse de incelemede görünsün
	var cached: Dictionary = _avatars.get(uid, {})
	var hash: String = ProfileCatalog.image_hash(av)
	if reason == "photo" and not hash.is_empty() and SaveSafe.s(cached.get("hash", "")) == hash:
		var path: String = AVATAR_CACHE_DIR + uid.validate_filename() + ".jpg"
		if FileAccess.file_exists(path):
			doc["img"] = Marshalls.raw_to_base64(FileAccess.get_file_as_bytes(path))
	_busy += 1
	changed.emit()
	var ok: bool = _ok(await _call(&"set", REPORTS, "x_%s_%s" % [_uid, uid], doc))
	_busy -= 1
	if _profile and not hash.is_empty():
		_profile.hide_photo(uid, hash)   # şikâyet edenin ekranında hemen gizlenir (gönderilemese de)
	notice.emit(Loc.t("Şikâyetin alındı, inceleyeceğiz. Teşekkürler!") if ok
		else Loc.t("Şikâyet gönderilemedi. İnternet bağlantını kontrol et."))
	changed.emit()
	return ok


## Engeller: arkadaşlıktan çıkarır, bekleyen istekleri siler, fotoğrafını gizler, yeni isteklerini yok sayar.
func block(uid: String) -> bool:
	if _profile == null or FeaturedFriends.is_featured(uid) or uid == _uid or uid.is_empty():
		return false
	var who: Dictionary = person(uid)
	_profile.block(uid, SaveSafe.s(who.get("name", "")))
	if is_ready():
		if is_friend(uid):
			await remove_friend(uid)
		if _index_of(incoming, uid) >= 0:
			await reject(uid)
		if _index_of(outgoing, uid) >= 0:
			await cancel(uid)
	notice.emit(Loc.t("%s engellendi, artık sana görünmez.") % SaveSafe.s(who.get("name", Loc.t("OYUNCU"))))
	changed.emit()
	return true


func unblock(uid: String) -> void:
	if _profile:
		_profile.unblock(uid)
		changed.emit()


# --- Firestore istek kuyruğu ------------------------------------------------------

## Tek istek: sırası gelince gönderilir, sonucu (ya da zaman aşımı) beklenir.
## kind: &"get" / &"set" / &"delete" / &"list" (list: id yok, sonuç data = {belge_kimliği: veri}).
func _call(kind: StringName, collection: String, id: String = "", data: Dictionary = {}) -> Dictionary:
	if _fb == null:
		return {"status": false, "error": "unavailable"}
	while _op_busy:
		await _op_slot_free
	_op_busy = true
	_current = {"kind": kind, "id": id}
	_op_timer.start(request_timeout)
	match kind:
		&"get":
			_fb.firestoreGetDocument(collection, id)
		&"set":
			_fb.firestoreSetDocument(collection, id, data, false)
		&"delete":
			_fb.firestoreDeleteDocument(collection, id)
		&"list":
			_fb.firestoreGetDocumentsInCollection(collection)
	var result: Dictionary = await _op_result
	_op_busy = false
	_op_slot_free.emit()
	return result


func _on_get_completed(result: Dictionary) -> void:
	if _current.is_empty():
		return
	match _current["kind"]:
		&"get":
			if SaveSafe.s(result.get("docID", "")) == _current["id"]:
				_finish(result)
		&"list":
			if not result.has("docID"):   # koleksiyon sonucu kimliksizdir (bulut kaydınınki kimlikli)
				_finish(result)


func _on_write_completed(result: Dictionary) -> void:
	if not _current.is_empty() and _current["kind"] == &"set" and SaveSafe.s(result.get("docID", "")) == _current["id"]:
		_finish(result)


func _on_delete_completed(result: Dictionary) -> void:
	if not _current.is_empty() and _current["kind"] == &"delete" and SaveSafe.s(result.get("docID", "")) == _current["id"]:
		_finish(result)


func _on_op_timeout() -> void:
	if not _current.is_empty():
		_finish({"status": false, "error": "timeout"})


func _finish(result: Dictionary) -> void:
	_current = {}
	_op_timer.stop()
	_op_result.emit(result)


# --- Yardımcılar -----------------------------------------------------------------

func _check_name(name: String) -> bool:
	if name.length() < SocialNames.NAME_MIN or name.length() > SocialNames.NAME_MAX:
		notice.emit(Loc.t("Takma ad %d–%d karakter olmalı.") % [SocialNames.NAME_MIN, SocialNames.NAME_MAX])
		return false
	if not SocialNames.is_valid_name(name):
		notice.emit(Loc.t("Bu takma ad kullanılamaz. Harf, rakam, boşluk ve . _ - kullanabilirsin."))
		return false
	return true


func _set_state(value: State) -> void:
	if _state == value:
		return
	_state = value
	changed.emit()


static func _friends_of(uid: String) -> String:
	return "users/%s/friends" % uid


static func _inbox_of(uid: String) -> String:
	return "users/%s/inbox" % uid


static func _outbox_of(uid: String) -> String:
	return "users/%s/outbox" % uid


static func _gifts_of(uid: String) -> String:
	return "users/%s/gifts" % uid


static func _races_of(uid: String) -> String:
	return "users/%s/races" % uid


static func _visits_of(uid: String) -> String:
	return "users/%s/visits" % uid


static func _ok(result: Dictionary) -> bool:
	return bool(result.get("status", false))


static func _not_found(result: Dictionary) -> bool:
	return SaveSafe.s(result.get("error", "")) == NOT_FOUND_ERROR


## Kural reddi (kod alınmış vb.). Eklenti hata metnini olduğu gibi verir.
static func _permission_denied(result: Dictionary) -> bool:
	return SaveSafe.s(result.get("error", "")).to_upper().contains("PERMISSION")


## Liste sonucundaki belge kimlikleri.
static func _ids(result: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var data: Variant = result.get("data", {})
	if data is Dictionary:
		for key: Variant in data:
			out.append(SaveSafe.s(key))
	return out


static func _index_of(list: Array[Dictionary], uid: String) -> int:
	for i: int in list.size():
		if SaveSafe.s(list[i].get("uid", "")) == uid:
			return i
	return -1


static func _now() -> int:
	return int(Time.get_unix_time_from_system())


func _write_meta() -> void:
	var file: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_meta))


static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func _make_timer(wait: float, callback: Callable) -> Timer:
	var timer: Timer = Timer.new()
	timer.one_shot = true
	timer.wait_time = wait
	timer.timeout.connect(callback)
	add_child(timer)
	return timer
