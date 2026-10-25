extends SceneTree
## HAFTALIK DRAG LİDER TABLOSU (2026-10-26, docs/LIDER_TABLOSU.md) — oyun tarafı: hafta hesabı (Pazartesi 00:00 Türkiye,
## sunucuyla aynı), belge kimlikleri, sıra (süre kovaları), ödül kademesi, bir üst kademeye kalan fark, yarış sonrası yazım
## (misafir yazmaz; ilk kayıt / daha yavaş koşu / iyileşme; belge kuralın 13 alanı), OTO MANŞET "seni tabloda geçti" haberi
## (gazetede çıkar, gösterilince sunucudan silinir; artık arkadaş olmayanınki atılır).
## Çalıştırma: tools/run_tests.sh leaderboard_test
var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


## Sunucusuz SocialManager: tablo yazımı ve haber koleksiyonu bellekte.
class LocalSocial extends SocialManager:
	var written: Dictionary = {}   # belge kimliği → belge
	var docs: Dictionary = {}      # koleksiyon → {kimlik: belge}
	var accepting: bool = true

	func write_lb_run(id: String, doc: Dictionary) -> bool:
		if not accepting:
			return false
		written[id] = doc.duplicate(true)
		return true

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
		return {"status": false}


static func summary_of(times: Array, count: int = -1) -> Dictionary:
	var hist: Dictionary = {}
	var top: Array = []
	var sorted: Array = times.duplicate()
	sorted.sort()
	for t: Variant in sorted:
		var key: String = str(floori(float(t) * Leaderboard.BUCKETS_PER_SEC))
		hist[key] = int(hist.get(key, 0)) + 1
		if top.size() < 50:
			top.append({"uid": "u%d" % top.size(), "time": float(t)})
	return {"count": count if count >= 0 else sorted.size(), "hist": hist, "top": top}


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake") and not OS.get_user_data_dir().ends_with("/AUTO YARD"))
	OS.set_environment("CT_NO_NET", "1")
	Loc.use("tr")   # gazete metni Türkçe denetlenir (başsız oyunda cihaz dili gelirdi)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Leaderboard.FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SocialManager.META_PATH))

	print("== 1) Hafta: Pazartesi 00:00 Türkiye ==")
	var monday: int = int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 25, "hour": 21,
		"minute": 0, "second": 0}))   # 26 Ekim 2026 Pazartesi 00:00 TR
	check(Leaderboard.week_of(monday) == 2965 and Leaderboard.week_of(monday - 1) == 2964, "26 Ekim 00:00 TR → 2965, bir sn önce 2964 (belgedeki örnek)")
	check(Leaderboard.week_of(monday + 7 * 86400 - 1) == 2965 and Leaderboard.week_of(monday + 7 * 86400) == 2966, "hafta 7 gün sürer")
	check(Leaderboard.week_end(2965) == monday + 7 * 86400, "haftanın bitişi bir sonraki Pazartesi 00:00 TR")
	Leaderboard.test_now = monday + 3600
	check(Leaderboard.current_week() == 2965, "test saati")
	check(Leaderboard.class_of(&"bmw_e46") == &"A" and Leaderboard.class_of(&"yok_boyle_arac") == &"", "sınıf katalogdan")
	check(Leaderboard.doc_id(2965, &"A", "abc") == "2965_A_abc" and Leaderboard.summary_id(2965, &"A") == "2965_A"
		and Leaderboard.summary_id(2965, &"A", "TR") == "2965_A_TR", "belge kimlikleri (sunucuyla aynı)")

	print("== 2) Sıra, kademe, kalan fark ==")
	var small: Dictionary = {"count": 16, "hist": {"196": 5, "200": 10, "230": 1}}
	var r: Dictionary = Leaderboard.rank_in(small, 10.0)
	check(int(r["rank"]) == 6 and int(r["count"]) == 16, "daha hızlı kovalar + 1 (aynı kovadakiler eşit): 6. / 16")
	check(int(Leaderboard.rank_in(small, 10.0, false)["count"]) == 17, "tabloda yoksa sayıya kendisi eklenir")
	check(int(Leaderboard.rank_in({}, 12.0)["rank"]) == 1 and Leaderboard.rank_in(small, 0.0).is_empty(), "boş özet 1., süresiz {}")
	check(Leaderboard.tier_of(1, 10) == &"top3" and Leaderboard.tier_of(3, 100) == &"top3", "İLK 3")
	check(Leaderboard.tier_of(4, 100) == &"p10" and Leaderboard.tier_of(10, 100) == &"p10", "İLK %10 (yukarı yuvarlanır)")
	check(Leaderboard.tier_of(11, 100) == &"p50" and Leaderboard.tier_of(50, 100) == &"p50", "İLK %50")
	check(Leaderboard.tier_of(51, 100) == &"" and Leaderboard.tier_of(0, 100) == &"", "kademe dışı")
	var times: Array = []
	for i: int in 312:
		times.append(9.8 + i * 0.012)
	var big: Dictionary = summary_of(times)
	var mine: float = 10.3   # ~42. sıra: %50 kademesinde, hedef İLK %10 (32.)
	var at: Dictionary = Leaderboard.rank_in(big, mine)
	var next: Dictionary = Leaderboard.chase(big, mine, int(at["rank"]), int(at["count"]))
	check(next.get("tier") == &"p10" and is_equal_approx(mine - float(next["gap"]), float(big["top"][31]["time"])),
		"İLK %%10 hedefi: 32. kişinin süresi kesin (top listesinden) (%s)" % [next])
	var slow: float = 12.0   # %50'nin dışında: hedef 156. sıra, top listesinde yok → kovalardan
	at = Leaderboard.rank_in(big, slow)
	next = Leaderboard.chase(big, slow, int(at["rank"]), int(at["count"]))
	var reached: Dictionary = Leaderboard.rank_in(big, slow - float(next.get("gap", 0.0)) - 0.001)
	check(next.get("tier") == &"p50" and Leaderboard.tier_of(int(reached["rank"]), int(reached["count"])) == &"p50",
		"İLK %%50 hedefi kovalardan: farkı kapatan kademeye girer (%s → %d.)" % [next, int(reached["rank"])])
	at = Leaderboard.rank_in(big, 9.75)
	check(Leaderboard.chase(big, 9.75, int(at["rank"]), int(at["count"])).is_empty(), "İLK 3'teyken hedef yok")

	print("== 3) Yarış sonrası yazım ==")
	var board: Leaderboard = Leaderboard.new()
	board.base_url = ""
	root.add_child(board)
	await frames(2)
	var rec: DragRaceSim.Recording = DragRaceSim.ai_recording(&"bmw_e46", {&"motor": 3, &"turbo": 2},
		DragRaceSim.roll_form(&"bmw_e46", null), RandomNumberGenerator.new())
	rec.time = 11.4
	var info: Dictionary = await board.submit(rec)
	check(bool(info.get("guest", false)) and board.my_best(2965, &"A") < 0.0, "hesapsız: yazılmaz, misafir şeridi")
	var social: LocalSocial = LocalSocial.new()
	root.add_child(social)
	await frames(2)
	social._state = SocialManager.State.READY
	social._uid = "me"
	social._meta = {"uid": "me", "name": "Burak", "code": "XYZ789"}
	board.inject("lb/2965_A", big)
	info = await board.submit(rec)
	var doc: Dictionary = social.written.get("2965_A_me", {})
	check(bool(info["improved"]) and int(info["old_rank"]) == 0 and int(info["rank"]) > 0, "ilk kayıt yazıldı (%s)" % [info])
	var fields: Array = ["uid", "wk", "cls", "time", "car", "paint", "stage", "level", "name", "av", "flag", "run", "at"]
	var keys: Array = doc.keys()
	keys.sort()
	fields.sort()
	check(keys == fields, "belge kuralın 13 alanı (%s)" % [keys])
	check(doc.get("uid") == "me" and int(doc.get("wk", 0)) == 2965 and doc.get("cls") == "A" and doc.get("car") == "bmw_e46"
		and int(doc.get("stage", -1)) == 3, "sahibi, hafta, sınıf, araç, en yüksek kademe")
	var run: String = String(doc.get("run", ""))
	check(run.length() > 0 and run.length() <= 2000 and JSON.parse_string(run) is Dictionary, "koşu JSON metni, ≤ 2000 (%d)" % run.length())
	check(is_equal_approx(board.my_best(2965, &"A"), 11.4) and board.my_best_car(2965, &"A") == &"bmw_e46", "en iyi cihazda")
	social.written.clear()
	rec.time = 11.9
	info = await board.submit(rec)
	check(not bool(info["improved"]) and social.written.is_empty() and is_equal_approx(float(info["best"]), 11.4),
		"daha yavaş koşu yazılmaz, en iyi kalır")
	rec.time = 10.25
	info = await board.submit(rec)
	check(bool(info["improved"]) and social.written.has("2965_A_me") and int(info["old_rank"]) > int(info["rank"]),
		"iyileşme yazıldı, sıra yükseldi (%d → %d)" % [int(info["old_rank"]), int(info["rank"])])
	check(info.get("next_tier") == &"p10" and float(info.get("gap", 0.0)) > 0.0, "bir üst kademeye kalan fark şeritte")
	social.accepting = false
	rec.time = 10.0
	info = await board.submit(rec)
	check(bool(info["failed"]) and is_equal_approx(board.my_best(2965, &"A"), 10.25), "yazılamazsa en iyi değişmez (şerit gizli)")
	social.accepting = true
	rec.vehicle_id = &"yok_boyle_arac"
	check((await board.submit(rec)).is_empty(), "sınıfsız araç tabloya girmez")

	print("== 4) OTO MANŞET: arkadaş seni tabloda geçti ==")
	social.friends.append({"uid": "f1", "name": "Elif", "code": "ABC123", "level": 5, "av": "p03", "frame": "", "flag": "TR"})
	var news: Dictionary = {
		"2965_A_f1": {"uid": "f1", "name": "Elif", "av": "p03", "car": "bmw_e60", "time": 10.1, "my_time": 10.25, "cls": "A",
			"wk": 2965, "at": monday + 60},
		"2965_B_x9": {"uid": "x9", "name": "Yabancı", "car": "bmw_e60", "time": 11.0, "my_time": 11.2, "cls": "B", "wk": 2965,
			"at": monday},
		"2960_A_f1": {"uid": "f1", "name": "Elif", "car": "bmw_e60", "time": 10.0, "my_time": 10.5, "cls": "A", "wk": 2960,
			"at": 0},
	}
	social.docs[SocialManager._lb_news_of("me")] = news
	await social._load_lb_news()
	check(social.lb_news.size() == 1 and (social.docs[SocialManager._lb_news_of("me")] as Dictionary).keys() == ["2965_A_f1"],
		"arkadaş olmayanın ve eski haftanın haberi silindi")
	var items: Array[Dictionary] = social.news_items(monday - 3600)
	var passed: Array[Dictionary] = []
	for item: Dictionary in items:
		if item["kind"] == NewsDigest.LB_PASSED:
			passed.append(item)
	check(passed.size() == 1 and String(passed[0]["people"][0]["name"]) == "Elif" and passed[0]["cls"] == &"A",
		"gazetede LB_PASSED")
	var issue: Dictionary = NewsDigest.compose(items, 3)
	var headline: Dictionary = issue.get("headline", {})
	check(headline.get("kind") == NewsDigest.LB_PASSED, "tek haber: manşet")
	var title: String = NewsDigest.title(headline, 1)
	var deck: String = NewsDigest.deck(headline)
	check(title.contains("ELİF") and deck.contains("10,10") and deck.contains("10,25"), "başlık / açıklama (%s · %s)" % [title, deck])
	check(NewsDigest.weight(headline) > NewsDigest.weight({"kind": NewsDigest.EARNINGS, "minutes": 480})
		and NewsDigest.weight(headline) < NewsDigest.weight({"kind": NewsDigest.RACE_LOST, "count": 1}),
		"önem: büyük kazancın üstünde, seni yenen arkadaşın altında")
	check(not NewsDigest.brief(headline).is_empty() and not NewsDigest.caption(headline).is_empty()
		and not NewsDigest.section(headline).is_empty(), "kısa satır / foto altı / bölüm")
	await social.news_shown()
	check(social.lb_news.is_empty() and (social.docs[SocialManager._lb_news_of("me")] as Dictionary).is_empty(),
		"gösterilince sunucudan silindi")
	check(social.news_items(monday - 3600).filter(func(i: Dictionary) -> bool: return i["kind"] == NewsDigest.LB_PASSED).is_empty(),
		"tekrar çıkmaz")

	Leaderboard.test_now = -1
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Leaderboard.FILE))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SocialManager.META_PATH))
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
