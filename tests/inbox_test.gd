extends SceneTree
## HABERLER KUTUSU (NewsFeed + Inbox + InboxScreen metinleri) — ağsız, izole user:// klasöründe.
##   tools/run_tests.sh inbox_test
## 1) Haber belgesinin süzülmesi (resim sunucusu, düğme, metin). 2) Görünürlük: yayın zamanı, dil, seviye, sürüm, güncelleme
## notunun sürümü. 3) Kutu: kaynakların birleşmesi, sıra (sabit önce), okunmamış sayısı, kutu açılınca görülme (hediye
## alınana kadar sayılır, ödülsüz posta geçmişe geçer), duyuru / yeni sürüm / etkinlik haberleri, 50 kayıt sınırı.
## 4) Geçmiş ve görülenler kayıtta (state / load_state). 5) Zaman ve durum yazıları.

var fails: int = 0
var config: AppConfig
var mail: MailService
var inbox: Inbox


func _initialize() -> void:
	if OS.get_user_data_dir().ends_with("/AUTO YARD"):
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


func _run() -> void:
	Loc.use("tr")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(AppConfig.FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(NewsFeed.FILE))
	_normalize()
	_visible()
	await _inbox()
	_state()
	_texts()
	AppInfo.override_code = 0
	LiveEvent.test_now = -1
	print("SONUC: fails=%d" % fails)
	quit(1 if fails > 0 else 0)


func news(id: String, over: Dictionary = {}) -> Dictionary:
	var doc: Dictionary = {"id": id, "kind": "notice", "title": {"tr": "Başlık " + id, "en": "Title " + id},
		"text": {"tr": "Metin"}, "at": 1000}
	doc.merge(over, true)
	return doc


func _normalize() -> void:
	print("== 1) Haber belgesi ==")
	var item: Dictionary = NewsFeed.normalize(news("n1", {"kind": "update", "code": 12, "pinned": true,
		"image": "https://firebasestorage.googleapis.com/v0/b/x/o/news%2Fa.jpg?alt=media&token=t",
		"action": {"kind": "market", "url": "https://kotu.example"},
		"target": {"langs": ["tr", "xx", 5], "min_level": 3, "max_level": -2}}))
	check(item["kind"] == "update" and int(item["code"]) == 12 and item["pinned"] == true, "tür, sürüm kodu, sabit")
	check(String(item["image"]).begins_with("https://firebasestorage.googleapis.com/"), "Storage resmi kabul")
	check(item["action"] == {"kind": "market", "url": ""}, "uygulama içi düğmede bağlantı atılır")
	check(item["target"]["langs"] == ["tr"] and int(item["target"]["min_level"]) == 3 and int(item["target"]["max_level"]) == 0,
		"hedef: bilinmeyen dil ve eksi sınır atılır")
	check(NewsFeed.clean_image("http://firebasestorage.googleapis.com/a.jpg") == "", "http resim reddedilir")
	check(NewsFeed.clean_image("https://kotu.example/a.jpg") == "", "izinsiz sunucu reddedilir")
	check(NewsFeed.clean_image("https://autoyard.online/haber/a.webp") != "", "site resmi kabul")
	check(NewsFeed.clean_action({"kind": "url", "url": "https://autoyard.online"}) == {"kind": "url", "url": "https://autoyard.online"},
		"https bağlantı düğmesi")
	check(NewsFeed.clean_action({"kind": "url", "url": "javascript:alert(1)"})["kind"] == "", "https olmayan bağlantı: düğme yok")
	check(NewsFeed.clean_action({"kind": "sil"})["kind"] == "", "bilinmeyen düğme: yok")
	check(NewsFeed.normalize(news("n2", {"kind": "reklam"}))["kind"] == "notice", "bilinmeyen tür → duyuru")
	check(NewsFeed.normalize({"id": "n3", "title": "Düz başlık"})["title"] == {"tr": "Düz başlık"}, "düz metin → Türkçe")
	check(NewsFeed.normalize({"id": "n4", "title": {"tr": "  "}, "text": {}}).is_empty(), "metinsiz haber atılır")
	check(NewsFeed.normalize({"title": {"tr": "Kimliksiz"}}).is_empty(), "kimliksiz haber atılır")
	check(String(NewsFeed.normalize(news("n5", {"text": {"tr": "x".repeat(900)}}))["text"]["tr"]).length() == NewsFeed.MAX_TEXT,
		"uzun metin kırpılır")


func _visible() -> void:
	print("== 2) Görünürlük ==")
	var now: int = 1_800_000_000
	var base: Dictionary = NewsFeed.normalize(news("v"))
	check(NewsFeed.visible(base, now, "tr", 1, 11, false), "sınırsız haber görünür")
	check(not NewsFeed.visible(NewsFeed.normalize(news("v", {"start": now + 60})), now, "tr", 1, 11, false), "ileri tarihli: henüz yok")
	check(NewsFeed.visible(NewsFeed.normalize(news("v", {"start": now - 60})), now, "tr", 1, 11, false), "başlangıcı geçmiş: var")
	check(not NewsFeed.visible(NewsFeed.normalize(news("v", {"end": now})), now, "tr", 1, 11, false), "bitişi gelmiş: kalkar")
	var langs: Dictionary = NewsFeed.normalize(news("v", {"target": {"langs": ["de", "fr"]}}))
	check(not NewsFeed.visible(langs, now, "tr", 1, 11, false) and NewsFeed.visible(langs, now, "de", 1, 11, false), "dil hedefi")
	var levels: Dictionary = NewsFeed.normalize(news("v", {"target": {"min_level": 5, "max_level": 9}}))
	check(not NewsFeed.visible(levels, now, "tr", 4, 11, false) and NewsFeed.visible(levels, now, "tr", 5, 11, false)
		and not NewsFeed.visible(levels, now, "tr", 10, 11, false), "seviye aralığı")
	var codes: Dictionary = NewsFeed.normalize(news("v", {"target": {"min_code": 11, "max_code": 12}}))
	check(not NewsFeed.visible(codes, now, "tr", 1, 10, false) and NewsFeed.visible(codes, now, "tr", 1, 12, false)
		and not NewsFeed.visible(codes, now, "tr", 1, 13, false), "sürüm aralığı")
	var notes: Dictionary = NewsFeed.normalize(news("v", {"kind": "update", "code": 12}))
	check(not NewsFeed.visible(notes, now, "tr", 1, 11, false) and NewsFeed.visible(notes, now, "tr", 1, 12, false),
		"güncelleme notu: o sürümü yükleyen görür")
	check(NewsFeed.visible(notes, now, "tr", 1, 0, true) and NewsFeed.visible(codes, now, "tr", 1, 0, true),
		"geliştirme sürümü sürüm süzgecine takılmaz")


func _inbox() -> void:
	print("== 3) Kutu ==")
	AppInfo.override_code = 11
	LiveEvent.test_now = int(Time.get_unix_time_from_system())
	var now: int = LiveEvent.test_now
	config = AppConfig.new()
	config.name = AppConfig.NODE_NAME
	config.url = ""
	root.add_child(config)
	await frames(2)
	var feed: NewsFeed = NewsFeed.of(self)
	check(feed != null and feed.url == "", "AppConfig yayın akışını kurar (testte ağsız)")
	mail = MailService.new()
	root.add_child(mail)
	inbox = Inbox.new(mail)
	var announced: Array[int] = []
	inbox.gift_arrived.connect(func(count: int) -> void: announced.append(count))
	root.add_child(inbox)
	await frames(2)
	check(inbox.items().is_empty() and inbox.unread() == 0, "boş kutu")

	# config/news belgesi REST biçiminde: {fields: {items: arrayValue[mapValue…]}}
	var rest: Dictionary = {"fields": {"items": {"arrayValue": {"values": [{"mapValue": {"fields": {
		"id": {"stringValue": "n_rest"}, "kind": {"stringValue": "notice"}, "at": {"integerValue": str(now - 5)},
		"title": {"mapValue": {"fields": {"tr": {"stringValue": "REST haberi"}}}},
		"target": {"mapValue": {"fields": {"langs": {"arrayValue": {}}}}}}}}]}}, "at": {"integerValue": "1"}}}
	feed._on_request_completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), JSON.stringify(rest).to_utf8_buffer())
	await frames(1)
	check(inbox.item("n_rest").get("title") == "REST haberi", "config/news belgesi çözülür, kutuya düşer")
	feed._on_request_completed(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())
	check(feed.items().size() == 1, "ağ yokken eldeki liste kalır")
	feed._on_request_completed(HTTPRequest.RESULT_SUCCESS, 404, PackedStringArray(), PackedByteArray())
	await frames(1)
	check(feed.items().is_empty() and inbox.item("n_rest").is_empty(), "belge yoksa yayında haber yok")

	feed.apply([news("n_old", {"at": now - 7200}), news("n_new", {"at": now - 60}),
		news("n_pin", {"kind": "event", "pinned": true, "at": now - 86400 * 3, "end": now + 3600}),
		news("n_later", {"start": now + 3600, "at": now}), news("n_fr", {"target": {"langs": ["fr"]}, "at": now})])
	await frames(1)
	var ids: Array = inbox.items().map(func(e: Dictionary) -> String: return e["id"])
	check(ids == ["n_pin", "n_new", "n_old"], "sabit önce, sonra en yeni; ileri tarihli ve başka dile yazılan yok (%s)" % [ids])
	check(inbox.unread() == 3, "üç yeni haber okunmamış")
	check(FileAccess.file_exists(NewsFeed.FILE) and NewsFeed.new().items().size() == 5, "liste cihazda saklanır (internetsiz de)")

	mail._pending = [MailService.normalize("m_gift", {"title": {"tr": "Hediye"}, "text": {"tr": "Al bakalım"}, "gems": 20,
		"at": now - 30, "expires": now + 86400}),
		MailService.normalize("m_msg", {"title": {"tr": "Sana özel"}, "text": {"tr": "Merhaba usta"}, "at": now - 20,
		"image": "https://firebasestorage.googleapis.com/v0/b/x/o/a.png", "action": {"kind": "invite"}})]
	mail.arrived.emit()
	await frames(1)
	var gift: Dictionary = inbox.item("m_gift")
	var message: Dictionary = inbox.item("m_msg")
	check(gift["kind"] == Inbox.GIFT and message["kind"] == Inbox.MESSAGE, "ödüllü posta HEDİYE, ödülsüz MESAJ")
	check(message["action"] == {"kind": "invite", "url": ""} and String(message["image"]).ends_with("a.png"), "postada resim + düğme")
	check(inbox.unread() == 5 and inbox.gift_count() == 1, "rozet: 3 haber + hediye + mesaj")
	check(announced == [1], "yeni hediye bir kez duyurulur (HEDİYEN VAR)")
	mail.arrived.emit()
	await frames(1)
	check(announced == [1], "aynı hediye ikinci kez duyurulmaz")

	inbox.mark_open()
	await frames(1)
	check(inbox.unread() == 1 and inbox.item("m_gift")["unread"] == true, "kutu açıldı: haberler görüldü, hediye alınana kadar sayılır")
	check(inbox.item("m_msg")["claimed"] == true and not mail.pending().any(func(m: Dictionary) -> bool: return m["id"] == "m_msg"),
		"ödülsüz posta okunup geçmişe geçti")
	check(mail.is_seen("n_new") and mail.is_seen("n_pin"), "görülenler kayda yazıldı")
	var summary: Dictionary = mail.claim("m_gift")
	await frames(1)
	var claimed: Dictionary = inbox.item("m_gift")
	check(int(summary.get("gems", 0)) == 20 and claimed["claimed"] == true and claimed["unread"] == false and inbox.unread() == 0,
		"hediye alındı: ALINDI, rozet söndü")
	check(int(claimed["rewards"].get("gems", 0)) == 20, "geçmişte ödülü duruyor")

	print("-- duyuru / yeni sürüm / etkinlik --")
	config.apply({"notice": {"id": "d1", "title": {"tr": "Bakım"}, "text": {"tr": "Gece kısa bakım"}}, "latest_code": 12,
		"update_text": {"tr": "Yeni araçlar geldi"},
		"event": {"id": "e1", "title": {"tr": "Çifte para"}, "text": {"tr": "Hafta sonu"}, "start": now - 60, "end": now + 7200,
			"money_mult": 2.0}})
	await frames(1)
	var notice: Dictionary = inbox.item("cfg_d1")
	var store: Dictionary = inbox.item("store_12")
	var event: Dictionary = inbox.item("evt_e1")
	check(notice.get("kind") == Inbox.NOTICE and notice.get("title") == "Bakım" and notice.get("unread") == true, "config duyurusu kutuda")
	check(store.get("kind") == Inbox.UPDATE and store.get("text") == "Yeni araçlar geldi"
		and store.get("action") == {"kind": "store", "url": ""}, "yeni sürüm haberi GÜNCELLE düğmeli")
	check(event.get("kind") == Inbox.EVENT and event.get("pinned") == true and int(event.get("end")) == now + 7200
		and event.get("action") == {"kind": "event", "url": ""}, "süren etkinlik sabit, ETKİNLİĞE GİT")
	check(inbox.items()[0]["id"] == "evt_e1" or inbox.items()[0]["id"] == "n_pin", "etkinlik sabitlerle üstte")
	AppInfo.override_code = 12
	inbox.rebuild()
	check(inbox.item("store_12").is_empty(), "güncelleyince yeni sürüm haberi kalkar")
	LiveEvent.test_now = now + 8000
	inbox.rebuild()
	check(inbox.item("evt_e1").is_empty(), "etkinlik bitince kalkar")
	LiveEvent.test_now = now

	print("-- 50 kayıt --")
	var many: Array = []
	for i: int in 70:
		many.append(news("n_%02d" % i, {"at": now - 1000 - i}))
	mail._pending.append(MailService.normalize("m_eski", {"title": {"tr": "Eski hediye"}, "gems": 5, "at": 10}))
	feed.apply(many)
	await frames(1)
	check(inbox.items().size() == Inbox.MAX_ITEMS, "en çok %d kayıt" % Inbox.MAX_ITEMS)
	check(not inbox.item("m_eski").is_empty(), "alınmamış hediye sınırdan düşmez")
	check(inbox.item("n_69").is_empty(), "en eski haber düştü")
	config.apply({})
	feed.apply([])
	await frames(1)


func _state() -> void:
	print("== 4) Kayıt ==")
	var data: Dictionary = mail.state()
	var copy: MailService = MailService.new()
	copy.load_state(JSON.parse_string(JSON.stringify(data)))
	check(copy.history().size() == mail.history().size() and copy.history()[0]["id"] == mail.history()[0]["id"],
		"geçmiş kayıttan geri gelir")
	check(copy.is_seen("n_new") and copy.seen_at("n_new") > 0, "görülenler kayıttan geri gelir")
	copy.load_state({"history": [{"id": "x", "title": 5, "image": "http://kotu", "items": "bozuk"}, "çöp", {}], "seen": []})
	check(copy.history().size() == 1 and copy.history()[0]["image"] == "" and copy.history()[0]["items"] == [],
		"bozuk geçmiş kaydı güvenli değere iner")
	for i: int in MailService.KEEP_SEEN + 10:
		copy.mark_seen(["s_%d" % i])
	check(copy.state()["seen"].size() <= MailService.KEEP_SEEN, "görülenler sınırlı")
	copy.free()


func _texts() -> void:
	print("== 5) Yazılar ==")
	var now: int = 1_800_000_000
	check(InboxScreen.age_text(now - 10, now) == "ŞİMDİ" and InboxScreen.age_text(now - 300, now) == "5 DK ÖNCE"
		and InboxScreen.age_text(now - 7200, now) == "2 SA ÖNCE" and InboxScreen.age_text(now - 90000, now) == "DÜN"
		and InboxScreen.age_text(now - 86400 * 4, now) == "4 GÜN ÖNCE", "zaman yazısı")
	var gift: Dictionary = {"kind": Inbox.GIFT, "claimed": false, "expires": now + 2 * 86400 - 100, "end": 0}
	check(InboxScreen.status_text(gift, now) == "SON 2 GÜN", "bitmeye 3 gün kala SON N GÜN")
	gift["expires"] = now + 5 * 3600
	check(InboxScreen.status_text(gift, now) == "SON 5 SAAT", "son gün saat")
	gift["expires"] = now + 10 * 86400
	check(InboxScreen.status_text(gift, now) == "", "uzak bitişte yazı yok")
	gift["claimed"] = true
	check(InboxScreen.status_text(gift, now) == "ALINDI", "alınmış hediye ALINDI")
	var event: Dictionary = {"kind": Inbox.EVENT, "claimed": false, "expires": 0, "end": now + 86400 + 14 * 3600 + 100}
	check(InboxScreen.status_text(event, now) == "1 G 14 SA KALDI", "etkinlik kalan süresi")
	event["end"] = now + 3 * 3600 + 20 * 60
	check(InboxScreen.status_text(event, now) == "3 SA 20 DK KALDI", "saat dakika")
