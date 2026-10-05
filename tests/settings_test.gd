extends SceneTree
## AYARLAR — grafik / performans / ses ayarlarının uygulanması ve kalıcılığı, AYARLAR ekranı ve
## giriş noktaları (dişli tabela, hesap, reklam gizlilik seçenekleri). Çalıştırma: tools/run_tests.sh settings_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	var main: Node = (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	await frames(12)
	var settings: GameSettings = get_first_node_in_group("settings")
	var hud: Hud = main.find_child("HUD", true, false)
	var router: UiRouter = hud.router
	check(settings != null, "GameSettings sahnede ('settings' grubu)")

	print("== VARSAYILANLAR ==")
	check(settings.quality == GameSettings.Quality.MEDIUM and not settings.battery_saver and not settings.muted, "varsayılan: ORTA kalite, pil tasarrufu kapalı, ses açık")
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Viewport.MSAA_DISABLED, "ORTA: 3B çözünürlük %100, MSAA kapalı (eski görünüm)")
	check(Engine.max_fps == 60, "kare hızı 60")
	check(AudioServer.get_bus_index(GameSettings.MUSIC_BUS) >= 0 and AudioServer.get_bus_index(GameSettings.SFX_BUS) >= 0, "Müzik ve Efekt bus'ları kuruldu")

	print("== UYGULAMA ==")
	settings.set_quality(GameSettings.Quality.LOW)
	check(is_equal_approx(root.scaling_3d_scale, 0.7) and root.msaa_3d == Viewport.MSAA_DISABLED, "DÜŞÜK: 3B çözünürlük %70")
	settings.set_quality(GameSettings.Quality.HIGH)
	check(is_equal_approx(root.scaling_3d_scale, 1.0) and root.msaa_3d == Viewport.MSAA_2X, "YÜKSEK: MSAA 2×")
	settings.set_battery_saver(true)
	check(Engine.max_fps == 30, "pil tasarrufu: 30 FPS")
	settings.set_music_volume(0.5)
	var music: int = AudioServer.get_bus_index(GameSettings.MUSIC_BUS)
	check(absf(AudioServer.get_bus_volume_db(music) - linear_to_db(0.5)) < 0.01, "müzik %50 → bus düzeyi")
	settings.set_sfx_volume(0.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(GameSettings.SFX_BUS)), "efekt %0 → bus susturuldu")
	settings.set_music_volume(7.0)
	check(is_equal_approx(settings.music_volume, 1.0), "düzey 0–1 aralığına kırpılır")
	settings.set_muted(true)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "tüm sesler kapalı → Master susturuldu")

	print("== KALICILIK ==")
	var copy: GameSettings = GameSettings.new()
	copy.load_settings()
	check(copy.quality == GameSettings.Quality.HIGH and copy.battery_saver and copy.muted and is_equal_approx(copy.sfx_volume, 0.0),
		"ayarlar user://settings.cfg'ye yazıldı ve yeniden okundu")
	copy.free()
	var save: SaveManager = get_first_node_in_group("save_manager")
	check(not save.snapshot_json().contains("battery_saver"), "ayarlar oyun kaydına / buluta girmez (cihaza özel)")
	var f: FileAccess = FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
	f.store_string("[graphics]\nquality=99\n[audio]\nmusic=\"bozuk\"")
	f.close()
	var broken: GameSettings = GameSettings.new()
	broken.load_settings()
	check(broken.quality == GameSettings.Quality.HIGH, "aralık dışı kalite kırpılır")
	broken.free()

	print("== OTOMATİK KALİTE / ZAYIF CİHAZ ==")
	const GB: int = 1_073_741_824
	check(GameSettings.detect_quality("PowerVR Rogue GE8320", 3 * GB, 8) == GameSettings.Quality.LOW, "Oppo A15 (GE8320, 3 GB) → DÜŞÜK")
	check(GameSettings.detect_quality("PowerVR Rogue GE8320", 6 * GB, 8) == GameSettings.Quality.LOW, "PowerVR GPU (RAM yetse de) → DÜŞÜK")
	check(GameSettings.detect_quality("Mali-G52 MC2", 4 * GB, 8) == GameSettings.Quality.LOW, "Mali-G52 → DÜŞÜK")
	check(GameSettings.detect_quality("Adreno (TM) 610", 4 * GB, 8) == GameSettings.Quality.LOW, "Adreno 610 → DÜŞÜK")
	check(GameSettings.detect_quality("Mali-G57 MC2", 6 * GB, 8) == GameSettings.Quality.MEDIUM, "Galaxy A24 (Mali-G57, 6 GB) → ORTA")
	check(GameSettings.detect_quality("Adreno (TM) 740", 8 * GB, 8) == GameSettings.Quality.HIGH, "amiral gemisi (Adreno 740, 8 GB) → YÜKSEK")
	check(GameSettings.detect_quality("Adreno (TM) 740", 6 * GB, 8) == GameSettings.Quality.MEDIUM, "güçlü GPU ama 6 GB → ORTA")
	check(GameSettings.detect_quality("Adreno (TM) 660", 2 * GB, 8) == GameSettings.Quality.LOW, "2 GB RAM → DÜŞÜK")
	check(GameSettings.detect_quality("Unknown GPU", 6 * GB, 4) == GameSettings.Quality.LOW, "4 çekirdek → DÜŞÜK")
	check(not GameSettings.msaa_supported("PowerVR Rogue GE8320", "Imagination Technologies"), "PowerVR'da MSAA kapalı (#104351)")
	check(GameSettings.msaa_supported("Mali-G57 MC2", "ARM"), "Mali'de MSAA açılabilir")
	settings.set_quality(GameSettings.Quality.LOW)
	check(GameSettings.subviewport_msaa(Viewport.MSAA_2X) == Viewport.MSAA_DISABLED and not GameSettings.shadows_enabled(),
		"DÜŞÜK: SubViewport MSAA ve gölge kapalı")
	var traffic: Node = get_first_node_in_group("traffic")
	check(traffic != null and int(traffic.get("max_vehicles")) == GameSettings.LOW_TRAFFIC, "DÜŞÜK: trafikte en çok %d araç" % GameSettings.LOW_TRAFFIC)
	settings.set_quality(GameSettings.Quality.MEDIUM)
	check(GameSettings.subviewport_msaa(Viewport.MSAA_2X) == Viewport.MSAA_2X and GameSettings.shadows_enabled(), "ORTA: SubViewport MSAA ve gölge açık")
	check(traffic != null and int(traffic.get("max_vehicles")) > GameSettings.LOW_TRAFFIC, "ORTA: trafik eski sayısına döndü")
	var drag: DragRaceScreen = hud.drag_race_screen
	settings.set_quality(GameSettings.Quality.LOW)
	drag.open()
	check(drag._viewport.msaa_3d == Viewport.MSAA_DISABLED, "drag pisti DÜŞÜK'te MSAA'sız açılır (eskiden 2×'te sabitti)")
	drag.close()
	settings.set_quality(GameSettings.Quality.MEDIUM)
	# Elle seçim kalıcı; eski dosyada işaret yoksa ORTA dışı değer "seçilmiş" sayılır
	var chosen: GameSettings = GameSettings.new()
	chosen.load_settings()
	check(chosen.quality_chosen, "elle seçilen kalite işaretlendi (otomatik ezmez)")
	chosen.free()
	for legacy: Array in [[0, true], [1, false], [2, true]]:
		var lf: FileAccess = FileAccess.open(GameSettings.PATH, FileAccess.WRITE)
		lf.store_string("[graphics]\nquality=%d\n" % legacy[0])
		lf.close()
		var old: GameSettings = GameSettings.new()
		old.load_settings()
		check(old.quality_chosen == legacy[1], "eski dosya quality=%d → seçilmiş: %s" % [legacy[0], legacy[1]])
		old.free()
	settings.save_settings()

	print("== EKRAN ==")
	check(hud.settings_button != null and hud.settings_button.is_visible_in_tree(), "sağ üstte dişli tabela görünür")
	check(hud.settings_button.get_parent() == hud.camera_button.get_parent(), "dişli kamera tabelasının yanında")
	hud.settings_button.pressed.emit()
	await frames(4)
	check(router.top() == &"settings" and hud.settings_screen.visible, "dişli → AYARLAR açıldı")
	var screen: SettingsScreen = hud.settings_screen
	screen._quality_buttons[0].pressed.emit()
	check(settings.quality == GameSettings.Quality.LOW, "ekrandan DÜŞÜK seçildi")
	settings.set_battery_saver(false)
	await frames(2)
	check(not screen._saver.button_pressed, "ekran ayar değişince tazelenir")
	var before_music: float = settings.music_volume
	screen._music_label.get_parent().get_child(1).pressed.emit()   # [−]
	check(settings.music_volume < before_music, "[−] müzik düzeyini düşürdü")
	var ads: AdService = get_first_node_in_group("ads")
	var mock: MockAdProvider = ads.provider() as MockAdProvider
	if mock:
		mock.privacy_required = false
		screen._refresh()
		check(not screen._privacy_options.visible, "gizlilik seçenekleri gerekmiyorsa düğme gizli")
		mock.privacy_required = true
		screen._refresh()
		check(screen._privacy_options.visible, "onay istenen bölgede REKLAM GİZLİLİK SEÇENEKLERİ görünür")
		screen._privacy_options.pressed.emit()
		await frames(2)
		check(mock.privacy_shows == 1, "düğme UMP gizlilik formunu açtı")
	else:
		check(true, "(sağlayıcı sahte değil: gizlilik düğmesi testi atlandı)")
	check(router.place_open() and not hud.top_left.visible and not hud.bottom.visible, "AYARLAR tam ekran: oyun HUD'u gizli")
	var backdrop: ColorRect = screen.get_node("Backdrop")
	check(backdrop.color.a >= 0.999 and backdrop.get_global_rect().size.y >= root.get_visible_rect().size.y - 1.0, "arka plan opak ve ekranı kaplıyor (oyun arkada görünmez)")
	screen.screen_requested.emit(&"account")
	await frames(4)
	check(router.top() == &"account" and screen.visible, "GOOGLE HESABI → hesap panosu AYARLAR'ın üstünde açıldı")
	router.back()
	await create_timer(0.4).timeout
	check(router.top() == &"settings" and screen.visible, "hesaptan geri → AYARLAR")
	screen._close.pressed.emit()
	await create_timer(0.4).timeout
	check(router.top() == &"" and not screen.visible and hud.top_left.visible, "GERİ → oyun, HUD geri geldi")
	settings.set_quality(GameSettings.Quality.MEDIUM)
	settings.set_muted(false)
	settings.set_music_volume(0.8)
	settings.set_sfx_volume(1.0)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
