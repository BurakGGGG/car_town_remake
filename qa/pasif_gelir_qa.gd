extends SceneTree
## PASİF GELİR QA (2026-10-17, OTO MANŞET adım 2): gerçek oyunda açılış — garaj 3 / 3 alan / tamir hızı 3, 6 saat yokluk,
## kayıtta 2 yarım iş → gazete kendiliğinden açılır, TAMAM'da paralar sayaca uçar, Rıza Usta bir kez anlatır; 10 saat
## yoklukta kepenk iner (ikinci açıklama); arka plandan 45 dk sonra dönüş. Saat gerçekten Google'dan alınır.
## Telefon tuvali (scale 1,35): pencere 1152x648 → 853x480.
##   CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/pasif_gelir_qa.gd --display-driver x11 --resolution 1152x648
## Kareler: /home/burak/Projects/ct_shots/pasif_gelir/

const OUT: String = "/home/burak/Projects/ct_shots/pasif_gelir/"

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + file + ".png")


func _initialize() -> void:
	get_root().content_scale_factor = 1.35
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func hud() -> Hud:
	return root.get_node_or_null("World/HUD") as Hud


func disk() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))


func write_disk(data: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()


## Kayıttaki yokluğu ayarlayıp sahneyi baştan kurar (soğuk açılış gibi), gazete açılana dek bekler.
func cold_start(hours: float, jobs: Array) -> bool:
	var data: Dictionary = disk()
	var now: int = int(Time.get_unix_time_from_system())
	data["away"]["last_seen"] = now - int(hours * 3600.0)
	data["repairs"] = jobs
	write_disk(data)
	reload_current_scene()
	await create_timer(1.0).timeout
	return await wait_news(8.0)


func wait_news(limit: float) -> bool:
	var waited: float = 0.0
	while waited < limit:
		await create_timer(0.25).timeout
		waited += 0.25
		if hud() and hud().router.top() == &"news":
			await create_timer(1.3).timeout   # fırlatma bitsin
			return true
	return false


func _job(type: String, bay: int, vehicle: String, color: String) -> Dictionary:
	return {"vehicle": vehicle, "colors": {"body": color}, "type": type, "severity": 1.0, "bay": bay, "elapsed": 3.0,
		"duration_scale": 0.8, "reward_scale": 1.3, "boosted": false, "saved_at": int(Time.get_unix_time_from_system())}


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await create_timer(4.0).timeout
	(get_first_node_in_group("tutorial") as TutorialManager).mark_done(TutorialManager.BASICS)
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: 3, GarageUpgradeManager.SPEED_ID: 3})
	(get_first_node_in_group("repair_bays") as RepairBayManager).load_state(3)
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(9, 0, 50)
	(get_first_node_in_group("save_manager") as SaveManager).save_game()

	print("1) 6 saat yokluk + 2 yarım iş")
	check(await cold_start(6.0, [_job("engine", 0, "tofas_sahin", "c0392b"), _job("paint_job", 1, "renault_toros", "2e86c1")]),
		"gazete kendiliğinden açıldı")
	var earn: OfflineEarnings = get_first_node_in_group("offline_earnings") as OfflineEarnings
	print("  saat sunucudan mı: %s · oran %.1f ₺/dk · kasa %d ₺ / %.0f dk / %d araç · yarım iş %d" % [earn.is_trusted(),
		earn.offline_rate(), earn.bank_money, earn.bank_minutes, earn.bank_jobs, earn.finished.size()])
	check(earn.finished.size() == 2 and absf(earn.bank_minutes - 360.0) < 2.0, "6 saatlik kasa + 2 iş")
	await shot("01_gazete_6saat")
	var economy: EconomyManager = get_first_node_in_group("economy") as EconomyManager
	var before: int = economy.money
	var expected: int = earn.shown_money()
	hud().news_screen._ok.pressed.emit()
	await create_timer(0.55).timeout
	await shot("02_para_ucusu")
	check(economy.money == before + expected, "para verildi (+%d)" % expected)
	await create_timer(1.6).timeout
	check(hud().tutorial.is_running(), "Rıza Usta konuşuyor")
	await create_timer(1.6).timeout   # yazı aksın
	await shot("03_riza_ilk")
	hud().tutorial_overlay.action_pressed.emit()
	await create_timer(0.5).timeout

	print("2) 10 saat yokluk: kepenk")
	check(await cold_start(10.0, []), "gazete açıldı")
	earn = get_first_node_in_group("offline_earnings") as OfflineEarnings
	check(earn.full and is_equal_approx(earn.bank_minutes, OfflineEarnings.CAP_MINUTES), "8 saatte durdu")
	await shot("04_gazete_kepenk")
	hud().news_screen._ok.pressed.emit()
	await create_timer(3.2).timeout
	check(hud().tutorial.is_running() and earn.told_full and earn.told_first, "yalnız kepenk açıklaması (ilki bir daha yok)")
	await shot("05_riza_kepenk")
	hud().tutorial_overlay.action_pressed.emit()
	await create_timer(0.5).timeout

	print("3) Arka plandan 45 dk sonra dönüş")
	earn.last_seen = int(Time.get_unix_time_from_system()) - 45 * 60
	earn._resume()
	check(await wait_news(8.0), "dönüşte gazete")
	check(absf(earn.bank_minutes - 45.0) < 1.0, "45 dk kasa (%.1f)" % earn.bank_minutes)
	await shot("06_donus_45dk")
	hud().news_screen._ok.pressed.emit()
	await create_timer(2.5).timeout
	check(not hud().tutorial.is_running(), "Rıza Usta bir daha konuşmadı")

	print("4) Arka plandan 10 dk sonra: gazete yok, kasa büyür")
	earn.last_seen = int(Time.get_unix_time_from_system()) - 10 * 60
	earn._resume()
	await create_timer(3.0).timeout
	check(hud().router.top() == &"" and absf(earn.bank_minutes - 10.0) < 1.0, "sessizce birikti (%.1f dk)" % earn.bank_minutes)
	print("SONUÇ: %d hata" % fails)
	quit(1 if fails > 0 else 0)
