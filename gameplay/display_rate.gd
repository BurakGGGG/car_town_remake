class_name DisplayRate
extends RefCounted
## EKRAN YENİLEME HIZI SEÇİMİ (Android; GameSettings kullanır). 90 / 120 Hz ekranlı telefonda oyun 60 kare çizerken
## ekran 90 Hz'de kalırsa 60 kare 90 yenilemeye eşit bölünmez: kareler sırayla 2 ve 1 yenileme (22 / 11 ms) ekranda
## durur, FPS sayısı iyi görünse de akış titrer ("kasıyor gibi").
##
## Ölçüm (2026-10-26, Samsung A24, 60 / 90 Hz ekran; SurfaceFlinger'ın ekrana çıkan kare zamanları, şehir ekranı,
## aynı kayıt, 30 sn):
##   ekran 90 Hz → ort. 51,6 FPS; karelerin %72'si 22 ms, %27'si 11 ms; ardışık kare süresi değişimi %55
##   ekran 60 Hz → ort. 59,4 FPS; karelerin %99'u 16,7 ms; değişim %2
##   (FPS sınırlayıcısı suçsuz: 60 Hz'de sınır 60 ile sınırsız aynı ölçüldü. 90 FPS de olmuyor: sınırsız 90 Hz'de
##   ort. 58,9 FPS, kareler yarı yarıya 11 / 22 ms — telefon 3B tam çözünürlükte ~60'ın sınırında.)
## Çare: oyunun penceresi hedefe bölünen ekran hızını ister (WindowManager.LayoutParams.preferredRefreshRate; sistem
## aynı çözünürlükteki o hızlı modu taban mod yapar). Yüzey düzeyindeki istek (Surface.setFrameRate) Samsung'da YETMEDİ:
## "Hareket akıcılığı" uyarlanabilirken taban mod 90 Hz, istek SurfaceFlinger'a ulaştı ama ekran 90'da kaldı.
##
## Godot'un Java köprüsü (JavaClassWrapper) nesne alanı yazamaz → alan Java yansımasıyla (Field.setFloat) yazılır.
## Window.setAttributes yalnız Android'in arayüz iş parçacığında çağrılabilir → Activity.runOnUiThread. Oradaki GDScript
## yalnız iki Java çağrısı yapar; nesneler (ve köprünün sınıf sarmalama önbelleği) önceden ana iş parçacığında hazırlanır.

## İstenen ekran hızı en az bu (Hz): pil tasarrufunun 30 FPS'ine 30 değil 60 Hz istenir (30 Hz modlu telefon yok).
const MIN_RATE: float = 60.0

## Arayüz iş parçacığında bekleyen iş (Java tarafı çalıştırana kadar canlı kalsın).
static var _pending: Object


## Bu cihazda istek yapılabilir mi (Android + Godot'un AndroidRuntime eklentisi).
static func supported() -> bool:
	return OS.get_name() == "Android" and Engine.has_singleton("AndroidRuntime")


## Pencere için `fps`'e bölünen ekran yenileme hızını ister (request_rate). Sonuç: istek gönderildi ya da pencere zaten
## bu hızı istiyordu; köprü hata verirse false. Ekranda bu hızda mod yoksa sistem isteği yok sayar (eski davranış).
static func request(fps: int) -> bool:
	if not supported():
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.call("getActivity")
	if activity == null:
		return false
	var rate: float = request_rate(fps)
	var window: Object = activity.call("getWindow")
	var attrs: Object = window.call("getAttributes") if window != null and not _failed() else null
	var java_class: Object = attrs.call("getClass") if attrs != null and not _failed() else null
	var field: Object = java_class.call("getField", "preferredRefreshRate") if java_class != null and not _failed() else null
	if field == null or _failed():
		return false
	if is_equal_approx(float(field.call("getFloat", attrs)), rate):
		return true
	var apply: Callable = func() -> void:
		field.call("setFloat", attrs, rate)
		window.call("setAttributes", attrs)
	_pending = runtime.call("createRunnableFromGodotCallable", apply)
	if _pending == null or _failed():
		return false
	activity.call("runOnUiThread", _pending)
	return not _failed()


## İstenecek ekran hızı: `fps`'in 60 ve üstündeki en küçük katı (60 → 60, 30 → 60). Telefonların hemen hepsinde 60 Hz
## modu var; uygulamaya listelenmese bile (Samsung A24, Android 16: Display.getSupportedModes / getSupportedRefreshRates
## yalnız 90'ı döndürdü, sistemin kendi listesinde 60 da var) sistem pencere isteğini kendi listesinden karşılar.
static func request_rate(fps: int) -> float:
	return float(ceili(MIN_RATE / float(fps)) * fps)


static func _failed() -> bool:
	var exception: JavaObject = JavaClassWrapper.get_exception()
	if exception == null:
		return false
	push_warning("DisplayRate: %s" % str(exception.call("toString")))
	return true
