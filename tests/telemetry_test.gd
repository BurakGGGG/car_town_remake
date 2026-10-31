extends SceneTree
## ANALİTİK + ÇÖKME RAPORU TESTİ (Telemetry): Android olmadan — olaylar Telemetry.recorded'a yazılır.
## Düğümden önceki olayların sırası, Analytics ad / değer kuralları, ayrılmış adlar, AYARLAR rıza anahtarları,
## GDScript hata yakalayıcısı (Logger: tekilleştirme, uyarı yok sayılır), oyun sinyallerinin olaylara bağlanması.
## Çalıştırma: tools/run_tests.sh telemetry_test
var fails: int = 0

func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond: fails += 1

func frames(n: int) -> void:
	for i: int in n: await process_frame

func _init() -> void: _run()

func _last(kind: StringName, name: String = "") -> Dictionary:
	for i: int in range(Telemetry.recorded.size() - 1, -1, -1):
		var entry: Dictionary = Telemetry.recorded[i]
		if entry.get("kind") == kind and (name.is_empty() or String(entry.get("name", "")) == name):
			return entry
	return {}

func _count(kind: StringName, name: String = "") -> int:
	var n: int = 0
	for entry: Dictionary in Telemetry.recorded:
		if entry.get("kind") == kind and (name.is_empty() or String(entry.get("name", "")) == name):
			n += 1
	return n

func _run() -> void:
	await process_frame
	print("== 1) Ad kuralları ==")
	check(Telemetry.clean_name("Crate Open!") == "crate_open_", "küçük harf, boşluk/işaret → _")
	check(Telemetry.clean_name("9lives") == "e_9lives", "harfle başlar")
	check(Telemetry.clean_name("x".repeat(60)).length() == Telemetry.NAME_MAX, "en çok 40 karakter")

	print("== 2) Düğümden önceki olaylar sırada bekler ==")
	Telemetry.event(&"early_event", {"a": 1})
	check(_count(&"event", "early_event") == 0, "düğüm yokken gönderilmedi")
	var settings: GameSettings = GameSettings.new()
	settings.reload_on_language_change = false
	root.add_child(settings)
	var progress: PlayerProgress = PlayerProgress.new()
	root.add_child(progress)
	var telemetry: Telemetry = Telemetry.new()
	root.add_child(telemetry)
	await frames(2)
	check(_count(&"event", "early_event") == 1, "düğüm gelince gönderildi")
	check(_last(&"property", "lang").get("value", "") == Loc.current(), "dil oyuncu özelliği")

	print("== 3) Parametreler ==")
	Telemetry.event(&"crate_open", {"rarity": &"rare", "duplicate": true, "money": 1500, "ratio": 0.5,
		"Long Key": "y".repeat(150), "obj": Vector2(1, 2)})
	var params: Dictionary = _last(&"event", "crate_open").get("params", {})
	check(params.get("rarity") == "rare", "StringName → metin")
	check(params.get("duplicate") == 1, "bool → 1/0")
	check(params.get("money") == 1500 and params.get("ratio") == 0.5, "sayılar korunur")
	check(String(params.get("long_key", "")).length() == Telemetry.VALUE_MAX, "uzun metin 100'e kırpıldı, anahtar temizlendi")
	check(params.get("obj") is String, "başka türler metne çevrilir")
	Telemetry.event(&"session_start")
	check(_count(&"event", "session_start_game") == 1 and _count(&"event", "session_start") == 0, "ayrılmış ad değiştirildi")
	var many: Dictionary = {}
	for i: int in 40:
		many["p%d" % i] = i
	Telemetry.event(&"many", many)
	check((_last(&"event", "many").get("params", {}) as Dictionary).size() == Telemetry.PARAMS_MAX, "en çok 25 parametre")

	print("== 4) Ekranlar ==")
	var before: int = _count(&"event", "screen_view")
	Telemetry.screen(&"garage")
	Telemetry.screen(&"garage")
	Telemetry.screen(&"world")
	check(_count(&"event", "screen_view") == before + 2, "aynı ekran üst üste yazılmaz")
	check(_last(&"event", "screen_view").get("params", {}).get("screen_name") == "world", "ekran adı parametrede")

	print("== 5) Oyun olayları ==")
	progress.level_up.emit(7)
	check(_last(&"event", "level_up").get("params", {}).get("level") == 7, "seviye atlama → level_up")
	check(_last(&"property", "level").get("value") == "7", "seviye oyuncu özelliği güncellendi")

	print("== 6) Rıza: KULLANIM İSTATİSTİKLERİ kapalı ==")
	settings.set_analytics_enabled(false)
	check(not Telemetry.analytics_enabled, "ayar Telemetry'ye geçti")
	var count: int = Telemetry.recorded.size()
	Telemetry.event(&"should_not_send")
	Telemetry.screen(&"map")
	check(_count(&"event", "should_not_send") == 0 and _count(&"event", "screen_view") == before + 2, "kapalıyken olay / ekran gönderilmez")
	settings.set_analytics_enabled(true)
	Telemetry.event(&"back_on")
	check(_count(&"event", "back_on") == 1, "açılınca yeniden gönderilir")
	var cfg: ConfigFile = ConfigFile.new()
	settings.set_crash_reports_enabled(false)
	check(cfg.load(GameSettings.PATH) == OK and cfg.get_value("privacy", "crash_reports", true) == false
		and cfg.get_value("privacy", "analytics", false) == true, "iki anahtar settings.cfg'ye yazıldı")
	check(not Telemetry.crash_enabled, "HATA RAPORLARI kapalı")
	settings.set_crash_reports_enabled(true)
	check(Telemetry.recorded.size() >= count, "kayıt bozulmadı")

	print("== 7) GDScript hataları ==")
	for i: int in 2:   # aynı satır iki kez (yer + ileti aynı)
		push_error("TELEMETRY TEST: deneme hatası")
	push_warning("TELEMETRY TEST: uyarı sayılmaz")
	await frames(2)
	var errors: int = 0
	var warned: bool = false
	for entry: Dictionary in Telemetry.recorded:
		if entry.get("kind") == &"error":
			if String(entry["name"]).contains("deneme hatası"):
				errors += 1
			warned = warned or String(entry["name"]).contains("uyarı sayılmaz")
	check(errors == 1, "aynı yerden aynı hata bir kez raporlandı (%d)" % errors)
	check(not warned, "uyarılar raporlanmaz")
	var err_entry: Dictionary = {}
	for entry: Dictionary in Telemetry.recorded:
		if entry.get("kind") == &"error" and String(entry["name"]).contains("deneme hatası"):
			err_entry = entry
	check(String(err_entry.get("name", "")).contains("telemetry_test.gd"), "hatanın yeri betik yığınından (%s)" % err_entry.get("name", ""))
	var counted: Dictionary = _last(&"event", "script_error")
	check(String(counted.get("params", {}).get("where", "")).contains("telemetry_test.gd"), "Analytics'e script_error sayacı")
	push_error("TELEMETRY TEST: başka hata")
	await frames(2)
	check(_count(&"error") == 2, "farklı ileti ayrı raporlandı")

	print("== 8) Sahne yeniden kuruldu ==")
	telemetry.queue_free()
	await frames(2)
	Telemetry.event(&"between_scenes")
	var telemetry2: Telemetry = Telemetry.new()
	root.add_child(telemetry2)
	await frames(2)
	check(_count(&"event", "between_scenes") == 1, "aradaki olay yeni düğümle gönderildi")
	push_error("TELEMETRY TEST: yeni sahnede hata")
	await frames(2)
	check(_count(&"error") == 3, "Logger tek kaldı, yeni düğüm hataları alıyor")

	print("== 9) Hesap türü (account) ==")
	check(Telemetry.account_kind(CloudSaveManager.PROVIDER_GOOGLE) == "google"
		and Telemetry.account_kind(CloudSaveManager.PROVIDER_FACEBOOK) == "facebook"
		and Telemetry.account_kind(CloudSaveManager.PROVIDER_EMAIL) == "email"
		and Telemetry.account_kind("") == "guest", "giriş yolu → google / facebook / email, oturumsuz → guest")

	print("== 10) GPU izi + derlenemeyen shader'ın kimliği (PowerVR, 2026-10-31) ==")
	check(_last(&"log").is_empty() == false and _count(&"log") > 0, "çökme günlüğüne iz yazılıyor")
	var gpu_logged: bool = false
	for entry: Dictionary in Telemetry.recorded:
		gpu_logged = gpu_logged or (entry.get("kind") == &"log" and String(entry["name"]).begins_with("gpu: "))
	check(gpu_logged, "düğüm kurulunca GPU özeti çökme günlüğüne yazıldı")
	check(_last(&"property", "gpu").get("value", "") == RenderingServer.get_video_adapter_name().left(36), "gpu oyuncu özelliği")
	Telemetry.breadcrumb("ön ısıtma: deneme")
	check(_last(&"log", "ön ısıtma: deneme").size() > 0, "breadcrumb çökme günlüğüne gider")
	# Godot'un _display_error_with_code biçimi: önce "N: satır", sonra hata (ileti iki satır)
	var errors_before: int = _count(&"error")
	for line: String in ["1: #version 300 es", "2: #define USE_GLES_OVER_GL", "3: #define DISABLE_LIGHTMAP",
			"4: #define MAX_GLOBAL_SHADER_UNIFORMS 256", "5: #define MODE_RENDER_DEPTH", "6: ",
			"7: uniform highp sampler2D m_albedo_tex;", "8: vec4 m_paint_color; float m_gloss;",
			"9: #define SHADOW_DEPTH(m_uv) (m_uv)", "10: color = m_paint_color.rgb * m_gloss;"]:
		print(line)
	push_error("SceneShaderGLES3: Fragment shader compilation failed:\nCompile failed.")
	await frames(2)
	var shader_error: String = String(_last(&"error").get("name", ""))
	check(_count(&"error") == errors_before + 1, "shader hatası raporlandı")
	check(shader_error.contains("m_albedo_tex, m_paint_color, m_gloss") and not shader_error.contains("m_uv"),
		"kimlikte malzemenin m_ adları (şablonun m_uv'si yok): %s" % shader_error)
	check(shader_error.contains("bayrak: USE_GLES_OVER_GL, DISABLE_LIGHTMAP, MODE_RENDER_DEPTH")
		and not shader_error.contains("MAX_GLOBAL"), "kimlikte değersiz #define bayrakları")
	check(not shader_error.contains("\n"), "ileti tek satır")
	# Başka malzemede aynı hata metni: ayrı raporlanır (anahtar kimliği içerir); dökümsüz aynı hata kimliksiz kalır
	for line: String in ["1: #version 300 es", "2: #define USE_RADIANCE_MAP", "3: float m_glow;"]:
		print(line)
	push_error("SceneShaderGLES3: Fragment shader compilation failed:\nCompile failed.")
	await frames(2)
	check(_count(&"error") == errors_before + 2 and String(_last(&"error").get("name", "")).contains("m_glow"),
		"başka malzemenin aynı hatası ayrı raporlandı")
	print("57: sıra dışı numaralı satır döküm başlatmaz")
	check(Telemetry._take_dump().is_empty(), "döküm hata ile tüketildi, sıra dışı satır yeni döküm açmadı")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(GameSettings.PATH))
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
