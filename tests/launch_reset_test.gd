extends SceneTree
## ÜRETİM SIFIRLAMASI (LaunchReset, 2026-10-26): geliştirme sürümünde kapalı; açıkken oyun durumu dosyaları ve klasörleri
## silinir, ayarlar / önbellekler / başka kitaplıkların dosyaları kalır, işaret yazılır ve ikinci açılış hiçbir şeye
## dokunmaz. Yollar sahibi sınıflardaki sabitlerle aynı olmalı (sınıf yolu değiştirirse sıfırlama o dosyayı atlardı).
## Çalıştırma: tools/run_tests.sh launch_reset_test

var fails: int = 0


func check(cond: bool, what: String) -> void:
	print(("  OK   " if cond else "  FAIL ") + what)
	if not cond:
		fails += 1


func _initialize() -> void:
	_run.call_deferred()


func _touch(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{}")
	f.close()


const KEPT: Array[String] = [
	"user://settings.cfg",
	"user://ad_privacy.cfg",
	"user://app_config.json",
	"user://news_feed.json",
	"user://audio_cache/deneme.bin",
	"user://live_packs/ornek.pck",
	"user://PersistedInstallation.deneme.json",   # Firebase Installations gibi başka kitaplığın dosyası
]


func _run() -> void:
	print("== YOLLAR SAHİPLERİYLE AYNI ==")
	var owners: Array[String] = [
		SaveManager.SAVE_PATH, CloudSaveManager.LOCAL_BACKUP_PATH, CloudSaveManager.SIGNOUT_BACKUP_PATH,
		CloudSaveManager.CLOUD_BACKUP_PATH, CloudSaveManager.META_PATH, SocialManager.META_PATH, ReferralManager.META_PATH,
		PurchaseManager.DEVICE_LEDGER_PATH, PushService.FILE, ModerationWatch.FILE, Leaderboard.FILE, RaceLearning.FILE,
	]
	for path: String in owners:
		check(LaunchReset.FILES.has(path), "silinir: %s" % path)
	check(LaunchReset.FILES.size() == owners.size(), "fazladan dosya yok")
	check(LaunchReset.DIRS.has(PlayerProfile.DIR), "silinir: %s" % PlayerProfile.DIR)
	check(LaunchReset.DIRS.has(SocialManager.AVATAR_CACHE_DIR), "silinir: %s" % SocialManager.AVATAR_CACHE_DIR)
	check(LaunchReset.FIREBASE_PLUGIN == CloudSaveManager.PLUGIN_NAME, "Firebase eklentisinin adı aynı")
	check(not LaunchReset.FILES.has(GameSettings.PATH), "ayarlar silinmez")

	for path: String in LaunchReset.FILES + KEPT:
		_touch(path)
	_touch(PlayerProfile.PHOTO_PATH)
	_touch(PlayerProfile.GOOGLE_META)
	_touch(SocialManager.AVATAR_CACHE_INDEX)
	DirAccess.remove_absolute(LaunchReset.MARKER)

	print("== GELİŞTİRME SÜRÜMÜ ==")
	check(AppInfo.version_code() == 0, "testte sürüm kodu 0 (geliştirme)")
	check(not LaunchReset.run_once(), "kapalı: sıfırlamaz")
	check(FileAccess.file_exists(SaveManager.SAVE_PATH) and not FileAccess.file_exists(LaunchReset.MARKER),
		"kayıt yerinde, işaret yazılmadı")

	print("== İLK AÇILIŞ (force) ==")
	LaunchReset.force = true
	check(LaunchReset.run_once(), "sıfırladı")
	for path: String in LaunchReset.FILES:
		check(not FileAccess.file_exists(path), "silindi: %s" % path)
	for dir: String in LaunchReset.DIRS:
		check(not DirAccess.dir_exists_absolute(dir), "klasör silindi: %s" % dir)
	for path: String in KEPT:
		check(FileAccess.file_exists(path), "kaldı: %s" % path)
	check(FileAccess.file_exists(LaunchReset.MARKER), "işaret yazıldı")

	print("== SONRAKİ AÇILIŞ ==")
	_touch(SaveManager.SAVE_PATH)   # yeni oyunun kaydı
	check(not LaunchReset.run_once(), "bir daha sıfırlamaz")
	check(FileAccess.file_exists(SaveManager.SAVE_PATH), "yeni kayıt yerinde")

	print("== YENİ KURULUM ==")
	DirAccess.remove_absolute(LaunchReset.MARKER)
	DirAccess.remove_absolute(SaveManager.SAVE_PATH)
	check(not LaunchReset.run_once(), "silinecek bir şey yok")
	check(FileAccess.file_exists(LaunchReset.MARKER), "yalnız işaret yazıldı")

	LaunchReset.force = false
	DirAccess.remove_absolute(LaunchReset.MARKER)
	for path: String in KEPT:
		DirAccess.remove_absolute(path)
	print("RESULT fails=%d" % fails)
	quit(1 if fails > 0 else 0)
