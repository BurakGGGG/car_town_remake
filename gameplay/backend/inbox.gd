class_name Inbox
extends Node
## HABERLER KUTUSU (2026-10-25, docs/HABERLER.md): sağ üstteki HABERLER tabelasının listesi. Kaynaklar:
##   HEDİYE     MailService.pending() — ödül, bakiye düzeltmesi ya da kayıt geri yükleme. Alınana kadar okunmamış sayılır,
##              kutudan AL ile alınır (kendiliğinden pencere açılmaz; kullanıcı kararı), sonra geçmişte ALINDI damgalı
##   MESAJ      ödülsüz posta ("tek oyuncuya haber") — kutu açılınca okunur, geçmişe geçer
##   HABERLER   NewsFeed (panelin Haberler sekmesi: güncelleme notu / etkinlik / duyuru), oyunda süzülür
##   DUYURU     config/app.notice (eski sürümlerin penceresi; bu sürüm kutuda gösterir)
##   YENİ SÜRÜM config/app.latest_code bu sürümden büyükse GÜNCELLE düğmeli haber (YENİ SÜRÜM VAR penceresi de kalır)
##   ETKİNLİK   süren canlı etkinlik (config/app.event): başlayınca kendiliğinden, sabit, ETKİNLİĞE GİT; bitince kalkar
##   MİSAFİR    hesapsız oyuncuya en üstte HESABINI BAĞLA kartı (hediyeler hesaplıya gelir)
## Sıra: misafir kartı, sabitler, sonra en yeni üstte; en çok MAX_ITEMS (alınmamış hediye düşmez). Okunmamış = alınmamış
## hediye + görülmemiş haber (tabeladaki sayı). Kutu açılınca haberler görülmüş sayılır (mark_open); görülenler ve
## geçmiş kayıtta (MailService). Hud kurar; ziyarette yok. "inbox" grubundan bulunur.

signal changed
## Bu oturumda ilk kez görülen alınmamış hediye(ler): HUD "HEDİYEN VAR" yazısı.
signal gift_arrived(count: int)

const MAX_ITEMS: int = 50
## Yayın başlangıcı / bitişi ve etkinlik geçişi için listeye yeniden bakılır.
const TICK_SEC: float = 30.0

const GIFT: StringName = &"gift"
const MESSAGE: StringName = &"message"
const UPDATE: StringName = &"update"
const EVENT: StringName = &"event"
const NOTICE: StringName = &"notice"
const GUEST: StringName = &"guest"

var _mail: MailService
var _feed: NewsFeed
var _config: AppConfig
var _cloud: CloudSaveManager
var _progress: PlayerProgress
var _items: Array[Dictionary] = []
var _signature: String = ""
var _notified: Dictionary = {}   # bu oturumda HEDİYEN VAR denilen posta kimlikleri


func _init(mail: MailService) -> void:
	name = "Inbox"
	_mail = mail


func _ready() -> void:
	add_to_group("inbox")
	var tree: SceneTree = get_tree()
	_cloud = tree.get_first_node_in_group("cloud_save") as CloudSaveManager
	_progress = tree.get_first_node_in_group("player_progress") as PlayerProgress
	_mail.arrived.connect(rebuild)
	_mail.history_changed.connect(rebuild)
	if _cloud:
		_cloud.state_changed.connect(func(_state: CloudSaveManager.State) -> void: rebuild())
	var timer: Timer = Timer.new()
	timer.wait_time = TICK_SEC
	timer.timeout.connect(rebuild)
	add_child(timer)
	timer.start()
	rebuild()


## Liste: {id, kind, title, text, from, at, end, expires, image, action {kind, url}, pinned, unread, claimed,
## mail (alınmamış postanın normalize hali), rewards (geçmişteki postanın ödül satırları)}.
func items() -> Array[Dictionary]:
	return _items


func item(id: String) -> Dictionary:
	for entry: Dictionary in _items:
		if entry["id"] == id:
			return entry
	return {}


## Tabeladaki sayı: alınmamış hediye + görülmemiş haber.
func unread() -> int:
	var count: int = 0
	for entry: Dictionary in _items:
		if entry["unread"]:
			count += 1
	return count


func gift_count() -> int:
	var count: int = 0
	for entry: Dictionary in _items:
		if entry["kind"] == GIFT and not entry["claimed"]:
			count += 1
	return count


## Kutu açıldı: haberler görüldü, ödülsüz postalar okundu (geçmişe geçer, sunucudan silinir). Hediyeler alınana kadar kalır.
func mark_open() -> void:
	if _feed:
		_feed.refresh_if_stale()
	var seen: Array = []
	var messages: Array[String] = []
	for entry: Dictionary in _items:
		if entry["kind"] == MESSAGE and not entry["claimed"]:
			messages.append(entry["id"])
		elif entry["kind"] != GIFT and entry["unread"]:
			seen.append(entry["id"])
	_mail.mark_seen(seen)
	for id: String in messages:
		_mail.claim(id)   # kaydı kendisi yazar
	if messages.is_empty() and not seen.is_empty():
		var save: SaveManager = get_tree().get_first_node_in_group("save_manager") as SaveManager
		if save:
			save.save_game()   # okundu bilgisi kalsın (rozet yeniden açılışta geri gelmesin)
	rebuild()


## Uzaktan ayar ve yayın akışı kökte yaşar (AppConfig); kutudan sonra kurulmuş olabilir: her yeniden kurulumda bağlanır.
func _bind_sources() -> void:
	if _config == null or not is_instance_valid(_config):
		_config = AppConfig.of(get_tree())
		if _config:
			_config.changed.connect(rebuild)
	if (_feed == null or not is_instance_valid(_feed)) and _config:
		_feed = NewsFeed.of(get_tree())
		if _feed:
			_feed.changed.connect(rebuild)


func rebuild() -> void:
	if not is_inside_tree():
		return
	_bind_sources()
	var now: int = LiveEvent.now()
	var out: Array[Dictionary] = []
	if _cloud and _cloud.get_state() == CloudSaveManager.State.SIGNED_OUT:
		out.append(_entry("guest", GUEST, Loc.t("HESABINI BAĞLA"),
			Loc.t("Hediyeler ve ödüller hesabı olan oyunculara gelir. Hesabını bağla, ilerlemen de güvende olsun."),
			0, {"kind": "account", "url": ""}, true))
	for mail: Dictionary in _mail.pending():
		var gift: bool = MailService.is_gift(mail)
		var entry: Dictionary = _entry(mail["id"], GIFT if gift else MESSAGE, mail["title"], mail["text"], int(mail["at"]),
			mail["action"], false)
		entry["from"] = mail["from"]
		entry["image"] = mail["image"]
		entry["expires"] = int(mail["expires"])
		entry["mail"] = mail
		entry["unread"] = gift or not _mail.is_seen(mail["id"])
		out.append(entry)
	for past: Dictionary in _mail.history():
		var entry: Dictionary = _entry(past["id"], GIFT if past["gift"] else MESSAGE, past["title"], past["text"],
			int(past["at"]), past["action"], false)
		entry["from"] = past["from"]
		entry["image"] = past["image"]
		entry["claimed"] = true
		entry["unread"] = false
		entry["rewards"] = past
		out.append(entry)
	if _feed:
		var level: int = _progress.level if _progress else 1
		for news: Dictionary in _feed.visible_items(now, Loc.current(), level, AppInfo.version_code(), AppInfo.is_dev_build()):
			var entry: Dictionary = _entry(news["id"], StringName(news["kind"]), AppConfig.text_of(news["title"]),
				AppConfig.text_of(news["text"]), int(news["at"]), news["action"], news["pinned"])
			entry["image"] = news["image"]
			entry["end"] = int(news["end"])
			out.append(entry)
	if _config:
		_add_config_items(out, now)
	out.sort_custom(_before)
	_trim(out)
	_items = out
	_announce_gifts()
	var signature: String = JSON.stringify(_items)
	if signature != _signature:
		_signature = signature
		changed.emit()


func _add_config_items(out: Array[Dictionary], now: int) -> void:
	var notice: Dictionary = _config.notice()
	if not notice.is_empty():
		var id: String = "cfg_" + SaveSafe.s(notice["id"])
		out.append(_entry(id, NOTICE, notice["title"], notice["text"], _seen_or(id, now), {"kind": "", "url": ""}, false))
	var latest: int = SaveSafe.i(_config.config().get("latest_code", 0))
	if not AppInfo.is_dev_build() and latest > AppInfo.version_code():
		var id: String = "store_%d" % latest
		var text: String = _config.update_text()
		out.append(_entry(id, UPDATE, Loc.t("YENİ SÜRÜM VAR"), text if not text.is_empty() \
			else Loc.t("Yeni sürümde düzeltmeler ve yenilikler var. Şimdi güncellemek ister misin?"), _seen_or(id, now),
			{"kind": "store", "url": ""}, false))
	var event: Dictionary = _config.active_event()
	if not event.is_empty():
		var title: String = SaveSafe.s(event["title"])
		var entry: Dictionary = _entry("evt_" + SaveSafe.s(event["id"]), EVENT, title if not title.is_empty() \
			else Loc.t("CANLI ETKİNLİK"), SaveSafe.s(event["text"]), int(event["start"]), {"kind": "event", "url": ""}, true)
		entry["end"] = int(event["end"])
		out.append(entry)


func _entry(id: String, kind: StringName, title: String, text: String, at: int, action: Dictionary, pinned: bool) -> Dictionary:
	return {
		"id": id, "kind": kind, "title": title, "text": text, "from": "", "at": at, "end": 0, "expires": 0, "image": "",
		"action": action if action is Dictionary else {"kind": "", "url": ""}, "pinned": pinned,
		"unread": not _mail.is_seen(id), "claimed": false, "mail": {}, "rewards": {},
	}


## Zamanı olmayan haber (duyuru, yeni sürüm): görüldüyse görüldüğü an, görülmediyse şimdi (yeni gelen üstte durur).
func _seen_or(id: String, now: int) -> int:
	return _mail.seen_at(id) if _mail.is_seen(id) else now


static func _before(a: Dictionary, b: Dictionary) -> bool:
	if (a["kind"] == GUEST) != (b["kind"] == GUEST):
		return a["kind"] == GUEST
	if a["pinned"] != b["pinned"]:
		return a["pinned"]
	if int(a["at"]) != int(b["at"]):
		return int(a["at"]) > int(b["at"])
	return String(a["id"]) < String(b["id"])


## MAX_ITEMS'ı aşan en eski kayıtlar düşer; alınmamış hediye düşmez.
static func _trim(out: Array[Dictionary]) -> void:
	var i: int = out.size() - 1
	while out.size() > MAX_ITEMS and i >= 0:
		if not (out[i]["kind"] == GIFT and not out[i]["claimed"]):
			out.remove_at(i)
		i -= 1


## Bu postanın "HEDİYEN VAR" yazısı çıkmasın (on) / yeniden çıkabilsin (off). MARKET › KOD GİR kabul edilen kuponun
## hediyesini kendisi açar (2026-10-31); açamazsa (posta gecikti, pano kapandı) işareti kaldırır, yazı her zamanki gibi gelir.
func set_announced(id: String, on: bool) -> void:
	if on:
		_notified[id] = true
		return
	_notified.erase(id)
	_announce_gifts()


func _announce_gifts() -> void:
	var fresh: int = 0
	for entry: Dictionary in _items:
		if entry["kind"] == GIFT and not entry["claimed"] and not _notified.has(entry["id"]):
			_notified[entry["id"]] = true
			fresh += 1
	if fresh > 0:
		gift_arrived.emit(fresh)
