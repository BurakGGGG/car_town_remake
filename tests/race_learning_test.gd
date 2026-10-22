extends SceneTree
## ÖĞRENEN ZORLUK (docs/KOSU_ESLESTIRME.md, Faz 2): bağlam, kol politikası (başlangıç kuralı / Thompson / korkuluklar /
## kişisel sayılar), yarış sonrası KALIŞ ölçümü (sıradaki yarış, pencere, arka plan, kapanış, sahne yenileme), yarış
## günlüğü ve yüklemesi, RaceManager bağlantısı ve sanal oyuncularla öğrenmenin yönü.
## Çalıştırma: tools/run_tests.sh race_learning_test
var fails: int = 0

const T0: int = 1761100000   # 2025-10-22 civarı; yalnızca göreli süreler önemli
const EASY: int = RivalSelector.Arm.EASY
const EVEN: int = RivalSelector.Arm.EVEN
const HARD: int = RivalSelector.Arm.HARD


## Sosyal düğümün yalnız yarış günlüğü yolu: yazılanları tutar, istenirse başarısız olur.
class FakeSocial extends SocialManager:
	var fake_uid: String = "alice"
	var fail: bool = false
	var fail_day: int = -1         # yalnız bu gün reddedilir (kural: cihaz saati kaymış)
	var written: Dictionary = {}   # gün → {events, n}

	func uid() -> String:
		return fake_uid

	func write_race_log(day: int, events_json: String, count: int) -> bool:
		await get_tree().process_frame
		if fail or day == fail_day:
			return false
		written[day] = {"events": JSON.parse_string(events_json), "n": count}
		return true


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _history(results: Array, arm: int = EVEN) -> Array:
	var out: Array = []
	for won: bool in results:
		out.append({"w": won, "a": arm, "p": 0.5})
	return out


func _shares(learning: RaceLearning, history: Array, races: int, rng: RandomNumberGenerator, n: int) -> Array[float]:
	var counts: Array[float] = [0.0, 0.0, 0.0]
	for i: int in n:
		counts[learning.choose_arm(history, races, rng)] += 1.0
	for i: int in 3:
		counts[i] /= float(n)
	return counts


## Genel tablo: bağlam → kol başına (kalış oranı, deneme).
func _table(rows: Dictionary) -> Dictionary:
	var table: Dictionary = {}
	for context: String in rows:
		var row: Dictionary = {}
		var arms: Array = rows[context]
		for arm: int in 3:
			var rate: float = arms[arm][0]
			var trials: int = arms[arm][1]
			row[str(arm)] = {"s": int(round(rate * trials)), "n": trials}
		table[context] = row
	return {"table": table}


## Yeni örnek (oyun yeniden açıldı / sahne yenilendi): saat düğüm hazırlanmadan önce verilir (bekleyen sonuç _ready'de çözülür).
func _fresh(holder: Node, now: int = T0) -> RaceLearning:
	var learning: RaceLearning = RaceLearning.new()
	learning.now_override = now
	learning.global_override = {}
	holder.add_child(learning)
	return learning


func _event(context: String, arm: int, won: bool) -> Dictionary:
	return {"c": context, "a": arm, "p": 0.5, "w": won, "pc": "vw_golf_7", "pt": 11.2, "rc": "seat_leon", "rt": 11.3, "o": "n", "lv": 4}


func _run() -> void:
	assert(not OS.get_user_data_dir().ends_with("/AUTO YARD") and not OS.get_user_data_dir().ends_with("/CarTownRemake"))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceLearning.FILE))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var holder: Node = Node.new()
	root.add_child(holder)

	print("== 1) Bağlam ==")
	check(RaceLearning.context_of(_history([true, false]), 5) == "new", "ilk %d yarış: new" % RaceLearning.NEW_RACES)
	check(RaceLearning.context_of(_history([true, false]), 30) == "WL", "önce kazandı, sonra kaybetti: WL")
	check(RaceLearning.context_of(_history([false, false, true]), 30) == "LW", "son iki sonuç: LW")
	check(RaceLearning.context_of(_history([true]), 30) == "new", "tek sonuç: new")

	print("== 2) Kol politikası ==")
	var learning: RaceLearning = _fresh(holder)
	var start: Array[float] = _shares(learning, _history([true, true]), 30, rng, 3000)
	check(absf(start[EVEN] - 0.55) < 0.04 and absf(start[EASY] - 0.33) < 0.04 and absf(start[HARD] - 0.12) < 0.03,
		"tablo yokken başlangıç kuralı (kolay %.2f · dengeli %.2f · zor %.2f)" % [start[EASY], start[EVEN], start[HARD]])
	learning.global_override = _table({"LL": [[0.9, 200], [0.5, 200], [0.2, 200]], "WW": [[0.4, 200], [0.8, 200], [0.6, 200]],
		"WL": [[0.6, 10], [0.5, 200], [0.5, 200]]})
	var ww: Array[float] = _shares(learning, _history([true, true]), 30, rng, 1000)
	check(ww[EVEN] > 0.8, "WW'de en çok kalınan kol (dengeli) seçilir (%.2f)" % ww[EVEN])
	var wl: Array[float] = _shares(learning, _history([true, false]), 30, rng, 2000)
	check(absf(wl[EVEN] - 0.55) < 0.05, "bağlamın bir kolunda %d denemeden az: başlangıç kuralı (dengeli %.2f)" % [RaceLearning.MIN_TRIALS, wl[EVEN]])
	var ll: Array[float] = _shares(learning, _history([false, false]), 30, rng, 200)
	check(ll[EASY] == 1.0, "seri kırıcı: iki kayıptan sonra hep kolay")
	var hard_table: Dictionary = _table({"WW": [[0.2, 300], [0.3, 300], [0.95, 300]]})
	learning.global_override = hard_table
	var many_hard: Array = _history([true, true, true, true, true], HARD) + _history([true, true, true, true, true, true, true,
		true, true, true, true, true, true, true, true], EVEN)
	var capped: Array[float] = _shares(learning, many_hard, 30, rng, 500)
	check(capped[HARD] == 0.0, "son 20 yarışta %%25 zor: zor kolu kapanır (%.2f)" % capped[HARD])
	var two_hard: Array = _history([true, true, true, true], EVEN)
	two_hard[-1]["a"] = HARD
	two_hard[-2]["a"] = HARD
	check(_shares(learning, two_hard, 30, rng, 500)[HARD] == 0.0, "üç zor üst üste gelmez")
	learning.global_override = {"table": hard_table["table"], "off": true}
	var off: Array[float] = _shares(learning, _history([true, true]), 30, rng, 2000)
	check(absf(off[EVEN] - 0.55) < 0.05, "panelden kapatılınca başlangıç kuralı (dengeli %.2f)" % off[EVEN])
	# Kişisel sayılar genel tabloyu ezer: genel WW'de dengeli öne, bu oyuncu kolayda kalıyor, dengelide hep çıkıyor
	learning.global_override = _table({"WW": [[0.5, 300], [0.6, 300], [0.5, 300]]})
	learning.load_counts({"WW": {"0": [60, 60], "1": [0, 60]}})
	var personal: Array[float] = _shares(learning, _history([true, true]), 30, rng, 1000)
	check(personal[EASY] > 0.8, "kişisel sayılar genel önseli geçer (kolay %.2f)" % personal[EASY])
	learning.load_counts({"WW": {"0": [99, 5], "1": "bozuk", "7": [1, 1]}, "XX": {"0": [1, 1]}})
	check(learning.cell("WW", EASY) == Vector2i(5, 5) and learning.cell("WW", EVEN) == Vector2i.ZERO
		and not learning.counts_state().has("XX"), "bozuk kişisel sayılar sınırlanır / atılır")
	learning.queue_free()

	print("== 3) Kalış ölçümü ==")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceLearning.FILE))
	learning = _fresh(holder)
	await frames(1)
	var day: int = floori(T0 / 86400.0)
	learning.race_finished(_event("WW", EVEN, true))
	learning.now_override = T0 + 30
	learning.race_started()
	var events: Array = learning.day_events(day)
	check(events.size() == 1 and events[0]["s"] == true and events[0]["n"] == true and events[0]["d"] == 30,
		"sıradaki yarış başladı: kaldı (30 sn sonra)")
	check(learning.cell("WW", EVEN) == Vector2i(1, 1), "kişisel sayı arttı")
	learning.now_override = T0 + 100
	learning.race_finished(_event("WL", EASY, false))
	learning.now_override = T0 + 100 + learning.window() - 1
	learning.poll()
	check(not learning.pending().is_empty(), "pencere dolmadan karar yok")
	learning.now_override = T0 + 100 + learning.window()
	learning.poll()
	events = learning.day_events(day)
	check(events.size() == 2 and events[1]["s"] == true and events[1]["n"] == false, "5 dk oyunda kaldı: kaldı")
	learning.now_override = T0 + 1000
	learning.race_finished(_event("LL", EASY, false))
	learning.now_override = T0 + 1040
	learning._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	learning.now_override = T0 + 1070
	learning._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	check(not learning.pending().is_empty() and not learning.pending().has("left"), "30 sn arka plan (bildirim): ayrılma sayılmaz")
	learning.now_override = T0 + 1100
	learning._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	learning.now_override = T0 + 1100 + RaceLearning.LEAVE_GRACE + 5
	learning._notification(Node.NOTIFICATION_APPLICATION_RESUMED)
	events = learning.day_events(day)
	check(events.size() == 3 and events[2]["s"] == false and events[2]["d"] == 100, "100. saniyede ayrıldı, uzun kaldı: kalmadı")
	# Oyun arka planda öldürüldü: sonuç diskte, sonraki açılışta ayrılma anına göre
	learning.now_override = T0 + 2000
	learning.race_finished(_event("LW", HARD, true))
	learning.now_override = T0 + 2050
	learning._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	learning.queue_free()
	await frames(1)
	learning = _fresh(holder, T0 + 9000)
	await frames(1)
	events = learning.day_events(day)
	check(events.size() == 4 and events[3]["s"] == false and events[3]["d"] == 50 and learning.pending().is_empty(),
		"kapanıştan sonraki açılış: 50. saniyede ayrılmış → kalmadı")
	# Sahne yenilendi (bulut kaydı): ayrılma yok, bekleme yeni örnekte sürer
	learning.now_override = T0 + 9100
	learning.race_finished(_event("WW", EVEN, true))
	learning.queue_free()
	await frames(1)
	learning = _fresh(holder, T0 + 9120)
	await frames(1)
	check(not learning.pending().is_empty(), "sahne yenilenince bekleyen sonuç kaybolmaz")
	learning.now_override = T0 + 9100 + learning.window()
	learning.poll()
	check(learning.day_events(day).size() == 5 and learning.day_events(day)[4]["s"] == true, "yenilemeden sonra da pencere dolunca kaldı")
	# Çökme: ayrılma anı yok ve çok eski → sayılmaz
	learning.race_finished(_event("WW", EVEN, true))
	var crash_at: int = learning.now_override
	learning.queue_free()
	await frames(1)
	learning = _fresh(holder, crash_at + RaceLearning.WINDOW_DEFAULT + RaceLearning.STALE_SEC + 10)
	await frames(1)
	check(learning.pending().is_empty() and learning.day_events(day).size() == 5, "ayrılma anı bilinmeyen eski sonuç sayılmaz")

	print("== 4) Yarış günlüğü ==")
	var social: FakeSocial = FakeSocial.new()
	holder.add_child(social)
	await frames(2)
	social.fail = true
	await learning.upload()
	check(learning.is_dirty(day) and social.written.is_empty(), "yazılamayınca gün kirli kalır (sonra yeniden)")
	social.fail = false
	await learning.upload()
	var doc: Dictionary = social.written.get(day, {})
	check(not learning.is_dirty(day) and int(doc.get("n", 0)) == 5 and (doc.get("events", []) as Array).size() == 5,
		"günün 5 olayı tek belgede yazıldı")
	var first: Dictionary = (doc.get("events", [{}]) as Array)[0]
	check(first.get("c") == "WW" and int(first.get("a")) == EVEN and first.get("pc") == "vw_golf_7" and first.get("o") == "n"
		and first.has("t") and not first.has("left"), "olay alanları: bağlam, kol, araçlar, rakip türü, zaman")
	social.fake_uid = ""
	learning.race_finished(_event("WW", EVEN, true))
	learning.race_started()
	await learning.upload()
	check(learning.is_dirty(day) and int(social.written[day]["n"]) == 5, "misafir (oturum yok): günlük cihazdan çıkmaz")
	social.fake_uid = "alice"
	social.fail_day = day
	learning.now_override = T0 + 86400
	learning.race_finished(_event("WW", EVEN, true))
	learning.race_started()
	await learning.upload()
	check(learning.is_dirty(day) and social.written.has(day + 1) and not learning.is_dirty(day + 1),
		"reddedilen gün sonraki günün yazılmasını tıkamaz")
	social.fail_day = -1
	learning.now_override = T0 + 3 * 86400
	learning.race_finished(_event("WW", EVEN, true))
	learning.race_started()
	check(learning.day_events(day).is_empty() and not learning.is_dirty(day), "iki günden eski gün atılır (kural kabul etmez)")
	social.queue_free()
	learning.queue_free()

	print("== 5) RaceManager bağlantısı ==")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(RaceLearning.FILE))
	var race: RaceManager = RaceManager.new()
	holder.add_child(race)
	await frames(2)
	race.learning().global_override = {}
	race._rng.seed = 4
	race._records[&"vw_golf_7"] = {"time": 11.0, "trace": PackedFloat32Array()}
	race._races = 30
	race._history.assign(_history([true, false]))
	race.friend_chance = 0.0
	var pick: Dictionary = race.pick_rival(&"vw_golf_7")
	race._rival_id = pick["id"]
	race._rival_owner = pick["owner"]
	race.rival_recording(&"vw_golf_7")
	race._reward_paid = false
	var arm_before: int = race.arm()
	var rival_before: String = String(race._rival_id)
	race.finish_race(true)   # kazanınca rakip serbest kalır (kol sıfırlanır)
	var pending: Dictionary = race.learning().pending()
	check(pending.get("c") == "WL" and int(pending.get("a", -9)) == arm_before and arm_before >= 0 and pending.get("w") == true
		and pending.get("rc") == rival_before and float(pending.get("rt", -1)) > 0.0 and pending.get("o") == "n",
		"yarış bitince olay bekler: bağlam bu yarıştan önceki geçmiş, kol, rakip ve süresi")
	race.rival_recording(&"vw_golf_7")   # rövanş / sıradaki yarış
	check(race.learning().pending().is_empty() and race.learning().cell("WL", int(pending["a"])).y == 1,
		"pist yeniden açılınca önceki sonuç 'kaldı'")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(race.state()))
	var copy: RaceManager = RaceManager.new()
	copy.load_state(saved)
	check(copy.learning().cell("WL", int(pending["a"])).y == 1, "kişisel sayılar kayıttan geri gelir")
	copy.free()
	var garage: Dictionary = PublicGarage.from_snapshot({"version": SaveManager.SAVE_VERSION, "vehicles": {"owned": []}, "race": saved})
	check(not (garage.get("race", {}) as Dictionary).has("learn") and not (garage.get("race", {}) as Dictionary).has("recent"),
		"kişisel öğrenme açık garaja gitmez")
	race.queue_free()

	print("== 6) Sanal oyuncular: öğrenme doğru yöne kayar ==")
	# Nüfus başlangıç kuralıyla oynar, gece tablosu toplanır; sonra öğrenen politika aynı nüfusa sorulur.
	for kind: String in ["kaybedince çıkan", "kazanınca sıkılan"]:
		var stay_win: float = 0.9 if kind == "kaybedince çıkan" else 0.35
		var stay_loss: float = 0.3 if kind == "kaybedince çıkan" else 0.85
		var sim: RaceLearning = _fresh(holder)
		var table: Dictionary = {}
		for context: String in RaceLearning.CONTEXTS:
			table[context] = {"0": {"s": 0, "n": 0}, "1": {"s": 0, "n": 0}, "2": {"s": 0, "n": 0}}
		for player: int in 120:
			var history: Array = []
			for race_index: int in 40:
				var arm: int = RivalSelector.choose_arm(history, rng)
				var won: bool = rng.randf() < RivalSelector.target_of(arm)
				var stayed: bool = rng.randf() < (stay_win if won else stay_loss)
				var context: String = RaceLearning.context_of(history, race_index)
				table[context][str(arm)]["n"] += 1
				if stayed:
					table[context][str(arm)]["s"] += 1
				history.append({"w": won, "a": arm, "p": 0.5})
		sim.global_override = {"table": table}
		var learned: Array[float] = _shares(sim, _history([true, true]), 30, rng, 2000)
		if kind == "kaybedince çıkan":
			check(learned[EASY] > 0.6, "%s oyuncu: öğrenen sistem KOLAY'a kayar (%.2f; başlangıçta 0.33)" % [kind, learned[EASY]])
		else:
			check(learned[EASY] < 0.15 and learned[HARD] > learned[EASY],
				"%s oyuncu: KOLAY azalır, ZOR artar (kolay %.2f · zor %.2f)" % [kind, learned[EASY], learned[HARD]])
		sim.queue_free()

	holder.queue_free()
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
