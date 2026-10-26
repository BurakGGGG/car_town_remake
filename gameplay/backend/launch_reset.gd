class_name LaunchReset
extends RefCounted
## ÜRETİM SIFIRLAMASI (2026-10-26, kullanıcı: "üretime çıkınca tüm hesaplar silinecek, herkes sıfırdan başlayacak"): test
## döneminden (1.1.1 ve öncesi) telefonda kalan oyun durumu 1.1.2'nin İLK açılışında BİR KEZ silinir ve Firebase oturumu
## kapatılır — sunucudaki test hesapları da silindi, açık kalan oturum silinmiş hesaba yazmaya çalışırdı. Oyuncu yeni
## kurulmuş gibi başlar (giriş seçenekleri, hoş geldin kutusu, dersler); hesapla girerse bulutta kayıt yoktur.
##
## KALANLAR: ayarlar (dil, grafik, ses, HUD boyutu, gizlilik / reklam onayları) ve önbellekler (uzaktan ayar, haber akışı ve
## resimleri, içerik paketleri, ses, pişmiş gölge). Uygulamanın files/ klasöründe (user://) Firebase, Crashlytics ve
## Appodeal'ın kendi dosyaları da durur: bu yüzden "her şeyi sil, şunları koru" DEĞİL — yalnız oyunun kendi durum dosyaları
## tek tek silinir (yollar sahibi sınıflardaki sabitlerle aynı, tests/launch_reset_test.gd denetler; burada sınıflara
## dayanılmaz ki yükleme ekranı açılırken onların betikleri ana iş parçacığında derlenmesin).
##
## İşaret dosyası MARKER yazılınca bir daha çalışmaz; yeni kurulumda silinecek bir şey yoktur, yalnız işaret yazılır.
## Geliştirme sürümünde (editör / masaüstü / testler, sürüm kodu 0) KAPALI: geliştirme kaydı silinmesin. Testler `force`
## ile açar. LoadingScreen._ready her şeyden önce çağırır (oyun kurulmadan, kayıt okunmadan).

const MARKER: String = "user://launch_reset_1.done"
const FILES: Array[String] = [
	"user://savegame.json",                  # SaveManager.SAVE_PATH
	"user://savegame.before_cloud.json",     # CloudSaveManager.LOCAL_BACKUP_PATH
	"user://savegame.before_signout.json",   # CloudSaveManager.SIGNOUT_BACKUP_PATH
	"user://cloud_backup.json",              # CloudSaveManager.CLOUD_BACKUP_PATH
	"user://cloud_sync.json",                # CloudSaveManager.META_PATH (hesap eşlemesi, giriş ekranı görüldü)
	"user://social.json",                    # SocialManager.META_PATH
	"user://referral.json",                  # ReferralManager.META_PATH
	"user://purchases_device.json",          # PurchaseManager.DEVICE_LEDGER_PATH
	"user://push.json",                      # PushService.FILE
	"user://moderation.json",                # ModerationWatch.FILE
	"user://leaderboard.json",               # Leaderboard.FILE
	"user://race_learning.json",             # RaceLearning.FILE
]
## İçindeki dosyalarla birlikte silinir (alt klasör yok).
const DIRS: Array[String] = [
	"user://profile/",                       # PlayerProfile.DIR (kendi fotoğrafı, Google fotoğrafı)
	"user://avatars/",                       # SocialManager.AVATAR_CACHE_DIR (silinen hesapların fotoğrafları)
]
const FIREBASE_PLUGIN: String = "GodotFirebaseAndroid"   # CloudSaveManager.PLUGIN_NAME

## Testler: sürüm kodu olmadan da çalıştır.
static var force: bool = false


## Gerekiyorsa sıfırlar; sıfırladıysa true.
static func run_once() -> bool:
	if AppInfo.version_code() <= 0 and not force:
		return false
	if FileAccess.file_exists(MARKER):
		return false
	var removed: int = wipe()
	var marker: FileAccess = FileAccess.open(MARKER, FileAccess.WRITE)
	if marker == null:
		push_warning("LaunchReset: işaret yazılamadı (%d)" % FileAccess.get_open_error())
	else:
		marker.store_string(Time.get_datetime_string_from_system(true))
	if removed > 0:
		print("LaunchReset: eski oyun durumu silindi (%d dosya)" % removed)
	return removed > 0


## Oyun durumu dosyalarını siler, Firebase oturumunu kapatır; silinen dosya sayısı.
static func wipe() -> int:
	var removed: int = 0
	for path: String in FILES:
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) == OK:
			removed += 1
	for dir: String in DIRS:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for file: String in DirAccess.get_files_at(dir):
			if DirAccess.remove_absolute(dir + file) == OK:
				removed += 1
		DirAccess.remove_absolute(dir)
	if Engine.has_singleton(FIREBASE_PLUGIN):
		var fb: Object = Engine.get_singleton(FIREBASE_PLUGIN)
		if fb.call("isSignedIn"):
			fb.call("signOut")
	return removed
