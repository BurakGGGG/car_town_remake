extends SceneTree
## OTO MANŞET HABER KAYNAKLARI (2026-10-17, adım 3) — arkadaş haberleri (SocialManager.news_items / news_shown): yarış skor
## farkı (seni X kez yendi / senin aracın kazandı), tabansız ilk gazete, gösterilince taban ilerler, oyun içinde bildirimi
## görülen yarış tekrarlanmaz, hediye kaydı (quiet), yeni arkadaş / istek / parça isteği; oyun haberleri (NewsSources):
## yokluk aralığında dolan hurda yığını, biten modifiye, yenilenen görevler; hepsi birlikte tek sayfalık gazete olur.
## Çalıştırma: tools/run_tests.sh news_sources_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func kinds(items: Array[Dictionary]) -> Array:
	return items.map(func(item: Dictionary) -> StringName: return StringName(item["kind"]))


func of_kind(items: Array[Dictionary], kind: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: Dictionary in items:
		if item["kind"] == kind:
			out.append(item)
	return out


func _friend(uid: String, name: String) -> Dictionary:
	return {"uid": uid, "name": name, "code": "ABC123", "level": 5, "av": "p03", "frame": "", "flag": "TR", "ask_part": "", "ask_at": 0}


func _event(uid: String, name: String, won: bool, mw: int, ml: int, at: int) -> Dictionary:
	return {"uid": uid, "name": name, "car": &"vw_golf_7", "their_car": &"bmw_e60", "paint": "", "build": {}, "won": won,
		"revenge": false, "mw": mw, "ml": ml, "at": at, "av": "p03", "frame": "", "flag": "TR"}


## Sunucusuz SocialManager: _call bellekteki koleksiyonlara yazar / okur (yalnız ziyaret testleri için).
class LocalSocial extends SocialManager:
	var docs: Dictionary = {}   # koleksiyon → {kimlik: belge}

	func _call(kind: StringName, collection: String, id: String = "", data: Dictionary = {}) -> Dictionary:
		var col: Dictionary = docs.get(collection, {})
		docs[collection] = col
		match kind:
			&"set":
				col[id] = data.duplicate(true)
				return {"status": true}
			&"delete":
				col.erase(id)
				return {"status": true}
			&"list":
				return {"status": true, "data": col.duplicate(true)}
			&"get":
				return {"status": col.has(id), "data": col.get(id, {})}
		return {"status": false}


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake") and not OS.get_user_data_dir().ends_with("/AUTO YARD"))
	OS.set_environment("CT_NO_NET", "1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SocialManager.META_PATH))
	var now: int = int(Time.get_unix_time_from_system())

	print("== 1) İlk gazete: taban yok ==")
	var social: SocialManager = SocialManager.new()
	root.add_child(social)
	await frames(2)
	social._state = SocialManager.State.READY
	social._uid = "me"
	social._meta = {"uid": "me", "name": "Burak", "code": "XYZ789"}
	social.friends.append(_friend("f1", "Elif"))
	social.friends.append(_friend("f2", "Mert"))
	social.incoming.append(_friend("r1", "Tolga"))
	social.race_events.append(_event("f1", "Elif", true, 4, 1, now - 600))     # yokluk sırasında: sayılır
	social.race_events.append(_event("f2", "Mert", false, 2, 3, now - 86400 * 9))   # çok eski: sayılmaz
	var items: Array[Dictionary] = social.news_items(now - 3600)
	check(kinds(items) == [NewsDigest.RACE_LOST], "tabansız: yalnız yokluktaki yarış, 1 kez (%s)" % [kinds(items)])
	check(int(items[0]["count"]) == 1 and items[0]["car"] == &"vw_golf_7" and String(items[0]["people"][0]["name"]) == "Elif",
		"Elif seni Golf'le yendi")
	check((social._meta["news"]["friends"] as Array).size() == 2 and (social._meta["news"]["requests"] as Array) == ["r1"],
		"ilk taban hemen yazıldı (güncellemeden sonra '2 yeni arkadaş' yok)")
	social.news_shown()
	check(social._meta["news"]["scores"]["f1"] == [4, 1] and social._meta["news"]["scores"]["f2"] == [2, 3], "gösterilince skor tabanı")

	print("== 2) Skor farkı, yeni arkadaş / istek / parça isteği ==")
	social.race_events[0]["mw"] = 8   # Elif 4 kez daha kazandı
	social.race_events[0]["ml"] = 3   # senin aracın 2 kez kazandı
	social.race_events[0]["at"] = now
	social.friends.append(_friend("f3", "Zeynep"))
	social.incoming.append(_friend("r2", "Melis"))
	social.friends[1]["ask_part"] = "piston"
	social.friends[1]["ask_at"] = now + 2   # son gazeteden sonra
	items = social.news_items(now - 3600)
	var lost: Array[Dictionary] = of_kind(items, NewsDigest.RACE_LOST)
	var won: Array[Dictionary] = of_kind(items, NewsDigest.RACE_WON)
	check(lost.size() == 1 and int(lost[0]["count"]) == 4, "Elif seni 4 kez yendi (skor farkı)")
	check(won.size() == 1 and int(won[0]["count"]) == 2 and won[0]["car"] == &"bmw_e60", "senin E60'ın 2 kez kazandı")
	check(of_kind(items, NewsDigest.FRIEND_NEW).size() == 1 and String(of_kind(items, NewsDigest.FRIEND_NEW)[0]["people"][0]["uid"]) == "f3",
		"yeni arkadaş Zeynep")
	check(of_kind(items, NewsDigest.FRIEND_REQUEST).size() == 1, "yeni istek Melis (Tolga eski)")
	var asks: Array[Dictionary] = of_kind(items, NewsDigest.ASK)
	check(asks.size() == 1 and asks[0]["part"] == &"piston", "Mert piston istiyor")
	var again: Array[Dictionary] = social.news_items(now - 3600)
	check(again.size() == items.size(), "gösterilmeden tekrar sorulunca aynı haberler")
	social.news_shown()
	check(social.news_items(now - 3600).is_empty(), "gösterildikten sonra haber kalmadı")
	social.news_shown()

	print("== 3) Oyun içinde görülen yarış tekrarlanmaz, gönderilmiş parça istenmez ==")
	social.race_events[0]["mw"] = 9
	social._note_race_seen(social.race_events[0])   # oyun açıkken bildirimi çıktı
	social.friends[1]["ask_at"] = now + 5
	social._meta["gifts_sent"] = {"f2": SocialManager._today()}   # bugün zaten gönderdin
	check(social.news_items(now - 3600).is_empty(), "bildirimi görülen yarış ve gönderilmiş istek gazetede yok")
	social.news_shown()

	print("== 4) Hediye kaydı (gazete toplarken) ==")
	social.quiet = true
	social._log_gift("p_f1_20380", "Elif", "bolt")
	social._log_gift("p_f2_20380", "Mert", "spark_plug")
	social._log_gift("p_f2_20380", "Mert", "yok_boyle_parca")
	items = social.news_items(now - 3600)
	var gifts: Array[Dictionary] = of_kind(items, NewsDigest.GIFT)
	check(gifts.size() == 2 and String(gifts[0]["people"][0]["uid"]) == "f1" and (gifts[0]["parts"] as Dictionary).has(&"bolt"),
		"iki hediye, gönderen belgeden okundu, bilinmeyen parça atlandı")
	social._log_gift("p_f3_20380", "Zeynep", "gear")   # gazete açıkken gelen
	social.news_shown()
	check((social._meta["gift_log"] as Array).size() == 1, "yalnız gösterilenler silindi (sonradan gelen kaldı)")
	social.quiet = false
	var issue: Dictionary = NewsDigest.compose(items, 3)
	check(String(NewsDigest.title(issue["columns"][0] if not (issue["columns"] as Array).is_empty() else issue["headline"], 1)) != "",
		"hediye haberi başlık üretir")
	var merged: Array[Dictionary] = NewsDigest.merge(gifts)
	check(merged.size() == 1 and NewsDigest.deck(merged[0]).contains("1 CIVATA") and NewsDigest.deck(merged[0]).contains("1 BUJİ"),
		"iki hediye tek haberde: %s" % NewsDigest.deck(merged[0]))
	social.free()

	print("== 4b) Ziyaret + beğeni (sahip ve ziyaretçi) ==")
	var owner: LocalSocial = LocalSocial.new()
	var profile: PlayerProfile = PlayerProfile.new()
	root.add_child(profile)
	root.add_child(owner)
	await frames(2)
	owner._state = SocialManager.State.READY
	owner._uid = "me"
	owner._profile = profile
	owner._meta = {"uid": "me", "name": "Burak", "code": "XYZ789"}
	owner.friends.assign([_friend("f1", "Elif"), _friend("f2", "Mert")])
	var today: int = SocialManager._today()
	owner.docs["users/me/visits"] = {
		"v_f1": {"name": "Elif", "at": now, "day": today, "liked": true},
		"v_f2": {"name": "Mert", "at": now, "day": today, "liked": false},
		"v_x9": {"name": "Yabanci", "at": now, "day": today, "liked": true},
	}
	var notices: Array[String] = []
	owner.notice.connect(func(text: String) -> void: notices.append(text))
	owner.quiet = true
	await owner._load_visits()
	check(profile.likes == 1, "Elif'in beğenisi sayıldı (arkadaş olmayan yok sayıldı)")
	check((owner.docs["users/me/visits"] as Dictionary).is_empty(), "okunan ziyaretler sunucudan silindi")
	check(notices.is_empty() and (owner._meta["visit_log"] as Array).size() == 2, "toplarken bildirim yok, gazeteye 2 ziyaret")
	items = owner.news_items(now - 3600)
	var visit_items: Array[Dictionary] = of_kind(items, NewsDigest.VISIT)
	var visit_news: Array[Dictionary] = NewsDigest.merge(visit_items)
	check(visit_items.size() == 2 and visit_news.size() == 1 and int(visit_news[0]["likes"]) == 1, "iki ziyaret tek haber, 1 beğeni")
	print("  %s / %s" % [NewsDigest.title(visit_news[0], 0), NewsDigest.deck(visit_news[0])])
	owner.news_shown()
	check((owner._meta["visit_log"] as Array).is_empty(), "gösterilince ziyaret kaydı silindi")
	owner.docs["users/me/visits"] = {"v_f1": {"name": "Elif", "at": now, "day": today, "liked": true}}
	owner.quiet = false
	await owner._load_visits()
	check(profile.likes == 1, "aynı gün ikinci beğeni sayılmaz")
	check(notices.size() == 1 and notices[0].contains("GEZDİ"), "oyun açıkken bildirim: %s" % [notices])
	owner.docs["users/me/visits"] = {"v_f1": {"name": "Elif", "at": now, "day": today + 1, "liked": true}}
	await owner._load_visits()
	check(profile.likes == 2 and notices.size() == 2 and notices[1].contains("BEĞENDİ"), "ertesi gün yeni beğeni + bildirim")
	check(profile.stats().get("likes", 0) == 2, "açık garaj istatistiğinde likes")
	profile.likes = 0
	check(not profile.stats().has("likes"), "beğeni yokken alan yazılmaz (eski kural reddederdi)")
	# Ziyaretçi: dönüşte tek belge, beğeni günde bir hatırlanır
	await owner._send_visit("f2", true)
	var sent: Dictionary = (owner.docs.get("users/f2/visits", {}) as Dictionary).get("v_me", {})
	check(bool(sent.get("liked", false)) and int(sent.get("day", -1)) == today and String(sent.get("name", "")) == "Burak",
		"ziyaret belgesi yazıldı (beğenili)")
	check(int((owner._meta["likes_sent"] as Dictionary).get("f2", -1)) == today, "bugün beğendiğin hatırlandı")
	await owner._send_visit("featured_emre", true)
	check(not owner.docs.has("users/featured_emre/visits"), "ustalara ziyaret yazılmaz")
	await owner._send_visit("yabanci", true)
	check(not owner.docs.has("users/yabanci/visits"), "arkadaş olmayana yazılmaz")
	owner.free()
	profile.free()

	print("== 5) Oyun haberleri: yokluk aralığı ==")
	var node: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await frames(12)
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(6, 0, 0)
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(JunkyardManager.OPEN_BAYS)
	var junkyard: JunkyardManager = get_first_node_in_group("junkyard") as JunkyardManager
	var mods: PerformanceModManager = get_first_node_in_group("performance_mods") as PerformanceModManager
	check(junkyard.is_open(), "hurdalık açık")
	var from: int = now - 2 * 86400
	var piles: int = junkyard.pile_count()
	junkyard._pile_ready_at.resize(piles)
	for i: int in piles:
		junkyard._pile_ready_at[i] = (now - 3600) if i < 2 else (now + 3600)   # 2'si yoklukta doldu, kalanı dolmadı
	mods._jobs.append({"car": &"bmw_e60", "category": &"motor", "stage": 1, "bay": 2, "start": float(now - 7200), "end": float(now - 60)})
	var local: Array[Dictionary] = NewsSources.local(self, from, now)
	check(of_kind(local, NewsDigest.PILES).size() == 1 and int(of_kind(local, NewsDigest.PILES)[0]["count"]) == mini(2, piles),
		"yoklukta dolan yığınlar (%d)" % (int(of_kind(local, NewsDigest.PILES)[0]["count"]) if not of_kind(local, NewsDigest.PILES).is_empty() else -1))
	check(of_kind(local, NewsDigest.MOD_READY).size() == 1 and of_kind(local, NewsDigest.MOD_READY)[0]["car"] == &"bmw_e60", "biten modifiye")
	var missions: Array[Dictionary] = of_kind(local, NewsDigest.MISSIONS)
	check(missions.size() == 1 and bool(missions[0]["daily"]), "2 günde görevler yenilendi")
	check(NewsSources.local(self, now - 120, now).filter(func(i: Dictionary) -> bool: return i["kind"] == NewsDigest.MISSIONS).is_empty()
		or (get_first_node_in_group("gem_rewards") as GemRewards).day_key(now - 120) != (get_first_node_in_group("gem_rewards") as GemRewards).day_key(now),
		"aynı gün içinde görev haberi yok")
	check(NewsSources.local(self, 0, now).is_empty(), "aralık yoksa (ilk açılış) oyun haberi yok")
	mods._jobs.clear()

	print("== 6) Hepsi bir gazetede ==")
	var all: Array[Dictionary] = []
	all.append({"kind": NewsDigest.EARNINGS, "money": 4200, "jobs": 12, "minutes": 300})
	all.append_array(lost)
	all.append_array(won)
	all.append_array(gifts)
	all.append_array(asks)
	all.append_array(local)
	var paper: Dictionary = NewsDigest.compose(all, 3)
	check(paper["headline"]["kind"] == NewsDigest.RACE_LOST, "manşet: seni yenen arkadaş")
	check((paper["columns"] as Array).size() == 3, "3 sütun")
	var brief_kinds: Array = (paper["briefs"] as Array).map(func(i: Dictionary) -> StringName: return StringName(i["kind"]))
	check(brief_kinds.has(NewsDigest.PILES) and brief_kinds.has(NewsDigest.MOD_READY) and brief_kinds.has(NewsDigest.MISSIONS),
		"küçük işler KISA KISA'da")
	node.free()
	print("SONUC: %d hata" % fails)
	quit(1 if fails > 0 else 0)
