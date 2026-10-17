extends SceneTree
## PASİF GELİR + YARIM KALAN İŞLER + OTO MANŞET AKIŞI (2026-10-17) — ölçülmüş gelir tablosu ve tamir hızı, 8 saat kasa
## sınırı, kısa aralarda birikim, saat geri alma, temel ders şartı, gösterilen payın ödenmesi (açıkken biriken sonraya
## kalır), kayıt turu, sunucu saati (HTTP Date) ayrıştırma, kazanç haberinin metni, kayıttaki yarım işler (biten → gazete,
## bitmeyen → alana) ve gerçek sahnede açılış: gazete açılır, TAMAM parayı verir, Rıza Usta bir kez konuşur.
## Çalıştırma: tools/run_tests.sh offline_earnings_test
var fails: int = 0
var main: Node


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func load_main() -> Node:
	var node: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(node)
	current_scene = node
	await frames(10)
	return node


func reload() -> void:
	if main:
		main.free()
	await frames(4)
	main = await load_main()


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func write_disk(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


func g(group: StringName) -> Node:
	return get_first_node_in_group(group)


func _init() -> void:
	_run()


func _run() -> void:
	await process_frame
	assert(not OS.get_user_data_dir().ends_with("/CarTownRemake") and not OS.get_user_data_dir().ends_with("/AUTO YARD"))
	OS.set_environment("CT_NO_NET", "1")
	OS.set_environment("CT_NO_TUTORIAL", "1")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveManager.SAVE_PATH))

	print("== 1) Ölçülmüş gelir tablosu ==")
	check(is_equal_approx(OfflineEarnings.active_rate(1, 1, 1.0, false), 372.0), "garaj 1, kısa işler: 372 ₺/dk")
	check(is_equal_approx(OfflineEarnings.active_rate(3, 1, 1.0, false), 1008.0), "garaj 3, kısa işler: alan sayısı değiştirmez")
	check(is_equal_approx(OfflineEarnings.active_rate(3, 3, 1.0, true), 1666.0), "garaj 3, 3 alan, orta işler: 1.666")
	check(is_equal_approx(OfflineEarnings.active_rate(3, 3, 0.6, true), 1666.0 * 1.48), "tamir hızı 5: +%48 (ölçüm)")
	var mid: float = OfflineEarnings.active_rate(3, 3, 0.8, true)
	check(mid > 1666.0 and mid < 1666.0 * 1.48, "ara tamir hızı arada (%.0f)" % mid)
	check(is_equal_approx(OfflineEarnings.active_rate(9, 9, 1.0, true), 1877.0), "aralık dışı değerler sınıra çekilir")
	var full_late: float = OfflineEarnings.active_rate(4, 3, 0.6, true) * OfflineEarnings.OFFLINE_SHARE * OfflineEarnings.CAP_MINUTES
	check(full_late > 70000.0 and full_late < 90000.0, "geç oyunda 8 saat ≈ 30 dk oyun (%.0f ₺)" % full_late)

	print("== 2) Sunucu saati (HTTP Date) ==")
	var expect: int = Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 17, "hour": 14, "minute": 52, "second": 3})
	check(OfflineEarnings.parse_http_date("Sat, 17 Oct 2026 14:52:03 GMT") == expect, "RFC 1123 tarihi okundu")
	check(OfflineEarnings.parse_http_date("Sat, 17 Okt 2026 14:52 GMT") == 0 and OfflineEarnings.parse_http_date("") == 0,
		"bozuk tarih 0")

	print("== 3) Kasa: oran, 8 saat sınırı, kısa aralar ==")
	var away: OfflineEarnings = OfflineEarnings.new()
	away.use_network = false
	root.add_child(away)
	await frames(4)
	var rate: float = away.offline_rate()
	check(is_equal_approx(rate, 372.0 / 16.0), "yönetici yokken garaj 1 oranı (%.2f ₺/dk)" % rate)
	away.accrue(3600)
	check(is_equal_approx(away.bank_minutes, 60.0) and away.bank_money == int(round(60.0 * rate)), "1 saat → %d ₺" % away.bank_money)
	check(away.bank_jobs >= 1 and not away.full, "araç sayısı hesaplandı, kasa dolmadı")
	away.accrue(300)
	away.accrue(300)
	check(is_equal_approx(away.bank_minutes, 70.0), "kısa aralar birikir (70 dk)")
	away.accrue(20 * 3600)
	check(is_equal_approx(away.bank_minutes, OfflineEarnings.CAP_MINUTES) and away.full, "8 saatte kepenk iner")
	var capped: int = away.bank_money
	away.accrue(3600)
	check(away.bank_money == capped, "dolu kasa büyümez")

	print("== 4) Gösterilen pay ödenir, açıkken biriken sonraya kalır ==")
	var economy: EconomyManager = EconomyManager.new()
	root.add_child(economy)
	await frames(1)
	var before: int = economy.money
	away.load_state({})
	away.accrue(2 * 3600)
	away.finished.append({"type": "engine", "reward": 150, "xp": 10})
	var items: Array[Dictionary] = away.news_items()
	check(items.size() == 1 and items[0]["kind"] == NewsDigest.EARNINGS, "tek kazanç haberi")
	var shown: int = away.shown_money()
	check(shown == away.bank_money + 150, "haber parası = kasa + yarım iş (%d)" % shown)
	away.accrue(1800)   # gazete açıkken biriken
	var result: Dictionary = away.collect()
	check(economy.money == before + shown, "TAMAM gösterilen parayı verdi")
	check(bool(result["bank"]) and int(result["xp"]) == 10 and away.finished.is_empty(), "yarım işin XP'si, liste boşaldı")
	check(is_equal_approx(away.bank_minutes, 30.0) and away.bank_money > 0, "açıkken biriken 30 dk kasada kaldı")
	check(away.collect().is_empty(), "ikinci TAMAM bir şey vermez")
	away.load_state({})
	away.accrue(300)
	check(not away.has_news(), "10 dk'dan kısa birikim haber değil")

	print("== 5) Saat geri alma, kayıt turu, temel ders ==")
	away.load_state({"last_seen": int(Time.get_unix_time_from_system()) + 7200})
	check(away._away_seconds(int(Time.get_unix_time_from_system())) == 0, "saat geri alınmış: yokluk 0")
	away.load_state({})
	check(away._away_seconds(int(Time.get_unix_time_from_system())) == 0, "kayıt yoksa yokluk 0")
	away.accrue(5400)
	away.issue = 7
	away.told_first = true
	away.finished.append({"type": "body", "reward": 230, "xp": 14})
	var copy: OfflineEarnings = OfflineEarnings.new()
	copy.load_state(JSON.parse_string(JSON.stringify(away.state())))
	check(copy.bank_money == away.bank_money and is_equal_approx(copy.bank_minutes, 90.0) and copy.issue == 7 and copy.told_first,
		"kayıt turu (kasa, sayı, Rıza)")
	check(copy.finished.size() == 1 and int(copy.finished[0]["reward"]) == 230, "biten yarım iş kayıtta")
	copy.load_state({"finished": [{"type": "yok_boyle_is", "reward": 9999}], "bank": {"minutes": "x", "money": -5}})
	check(copy.finished.is_empty() and copy.bank_money == 0 and copy.bank_minutes == 0.0, "bozuk kayıt temizlendi")
	copy.free()
	var tutorial: TutorialManager = TutorialManager.new()
	root.add_child(tutorial)
	await frames(1)
	away.load_state({})
	away.accrue(3600)
	check(away.bank_minutes == 0.0, "temel ders bitmeden usta çalışmaz")
	tutorial.mark_done(TutorialManager.BASICS)
	away.accrue(3600)
	check(is_equal_approx(away.bank_minutes, 60.0), "ders bitince çalışır")
	for node: Node in [away, economy, tutorial]:
		node.free()

	print("== 6) Kazanç haberinin metni ==")
	var deck: String = NewsDigest.deck({"kind": NewsDigest.EARNINGS, "money": 2300, "jobs": 9, "minutes": 360, "full": true,
		"finished": 2, "finished_money": 780, "finished_xp": 25})
	check(deck.contains("6 saat içinde 9 araç") and deck.contains("2 iş de bitti") and deck.contains("+25 XP")
		and deck.contains("kepenk"), "süre + araç + yarım işler + kepenk: %s" % deck)
	var only_jobs: String = NewsDigest.deck({"kind": NewsDigest.EARNINGS, "money": 780, "jobs": 0, "finished": 1,
		"finished_money": 780, "finished_xp": 25})
	check(only_jobs.begins_with("Yarım bıraktığın iş bitti"), "yalnız tek yarım iş: tekil cümle, 'de' yok")
	check(NewsDigest.duration_text(40) == "40 dakika" and NewsDigest.duration_text(130) == "2 saat", "süre yazısı")
	var composed: Dictionary = NewsDigest.compose([{"kind": NewsDigest.EARNINGS, "money": 3000, "jobs": 9, "minutes": 480,
		"full": true, "finished": 2, "finished_money": 700, "finished_xp": 20}] as Array[Dictionary], 3)
	var composed_deck: String = NewsDigest.deck(composed["headline"])
	check(composed_deck.contains("2 iş de bitti") and composed_deck.contains("kepenk"), "birleştirmeden sonra da yarım iş + kepenk")

	print("== 7) Gerçek sahne: kayıttaki yarım işler + açılış gazetesi ==")
	main = await load_main()
	await create_timer(1.0).timeout
	(g(&"tutorial") as TutorialManager).mark_done(TutorialManager.BASICS)
	var save: SaveManager = g(&"save_manager") as SaveManager
	check(save.save_game(), "ilk kayıt")
	var data: Dictionary = disk()
	check(data.has("away") and data.has("repairs"), "kayıtta away + repairs bölümleri")
	var now: int = int(Time.get_unix_time_from_system())
	data["away"]["last_seen"] = now - 3 * 3600
	data["repairs"] = [
		{"vehicle": "tofas_sahin", "colors": {"body": "c0392b"}, "type": "engine", "severity": 1.0, "bay": 0, "elapsed": 2.0,
			"duration_scale": 1.0, "reward_scale": 1.0, "boosted": false, "saved_at": now - 3 * 3600},
	]
	write_disk(data)
	var money_before: int = int(data["economy"]["money"])
	await reload()
	await create_timer(0.6).timeout
	var earn: OfflineEarnings = g(&"offline_earnings") as OfflineEarnings
	check(earn != null and earn.finished.size() == 1, "3 saatte biten yarım iş gazeteye (%d)" % (earn.finished.size() if earn else -1))
	check(earn != null and absf(earn.bank_minutes - 180.0) < 1.0, "3 saatlik kasa (%.1f dk)" % (earn.bank_minutes if earn else -1.0))
	var repairs: RepairManager = g(&"repair_manager") as RepairManager
	check(repairs.is_bay_free(0), "biten işin alanı boş")
	var hud: Hud = main.get_node("HUD") as Hud
	await create_timer(1.8).timeout
	check(hud.router.top() == &"news", "gazete kendiliğinden açıldı")
	var expected: int = earn.shown_money()
	check(expected == earn.bank_money + 150, "haber: kasa + 150 ₺ motor işi (%d)" % expected)
	await create_timer(1.0).timeout
	hud.news_screen._ok.pressed.emit()
	await create_timer(0.8).timeout
	var economy_main: EconomyManager = g(&"economy") as EconomyManager
	check(economy_main.money == money_before + expected, "TAMAM: para verildi (%d → %d)" % [money_before, economy_main.money])
	check(earn.bank_money == 0 and earn.finished.is_empty(), "kasa boşaldı")
	var saved: Dictionary = disk()
	check(int(saved["away"]["bank"]["money"]) == 0 and (saved["away"]["finished"] as Array).is_empty()
		and int(saved["economy"]["money"]) == money_before + expected, "ödeme kayda HEMEN yazıldı")
	await create_timer(1.2).timeout
	check(hud.tutorial.is_running() and earn.told_first, "Rıza Usta pasif geliri anlatıyor")
	hud.tutorial_overlay.action_pressed.emit()
	await create_timer(0.3).timeout
	check(not hud.tutorial.is_running(), "TAMAM ile kapandı")

	print("== 8) Bitmeyen yarım iş alana döner, kısa yoklukta gazete yok ==")
	data = disk()
	now = int(Time.get_unix_time_from_system())
	data["away"]["last_seen"] = now - 20
	data["repairs"] = [
		{"vehicle": "tofas_sahin", "colors": {}, "type": "engine", "severity": 1.0, "bay": 0, "elapsed": 1.0,
			"duration_scale": 1.0, "reward_scale": 1.0, "boosted": false, "saved_at": now - 20},
		{"vehicle": "renault_toros", "colors": {}, "type": "brake_overhaul", "severity": 1.0, "bay": 0, "elapsed": 0.0,
			"duration_scale": 1.0, "reward_scale": 1.0, "boosted": false, "saved_at": now - 20},
	]
	write_disk(data)
	await reload()
	await create_timer(0.6).timeout
	earn = g(&"offline_earnings") as OfflineEarnings
	repairs = g(&"repair_manager") as RepairManager
	check(earn.finished.size() == 1, "20 sn'de 10 sn'lik iş bitti, 300 sn'lik bitmedi")
	var back: Array = repairs.jobs_state()
	check(back.size() == 1 and String(back[0]["type"]) == "brake_overhaul" and float(back[0]["elapsed"]) >= 20.0,
		"bitmeyen iş geçen süreyle alana döndü")
	check(not repairs.is_bay_free(0), "alanı ayrılmış")
	check(earn.bank_minutes < 1.0, "20 sn'lik kasa haber olmaz (%.2f dk)" % earn.bank_minutes)

	print("SONUC: %d hata" % fails)
	quit(1 if fails > 0 else 0)
