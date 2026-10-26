class_name AdBoot
extends RefCounted
## REKLAMI AÇILIŞTA BAŞLATMA (2026-10-26, kullanıcı: "manşet reklamını direkt açılışta yükleyebilirsin, bir süreyi geçerse
## devam eder"): yükleme ekranı Main'i arka planda yüklerken reklam SDK'sı başlar ve her yuvanın ilk ödüllü reklamı
## yüklenmeye başlar. Eskiden ikisi de Main kurulunca (AdService) başlıyordu; OTO MANŞET açıldığında reklam çoğu zaman
## henüz yoktu. AdService ilk kurulduğunda sağlayıcıyı buradan devralır (take). Devralan olmazsa (testler, doğrudan
## Main.tscn) ya da devralındıktan sonra (sahne yeniden kurulunca) AdService eskisi gibi kendisi seçer ve başlatır.
## Yalnız sağlayıcı betikleri yüklenir (AdService ve bağlı oyun sınıfları değil): yükleme ekranının ilk karesi gecikmez.

## Seçilmeyen ağın sağlayıcısı adıyla anılmaz (yalnız gerekince yüklenir): betiği yüklenince eklentinin GDScript
## sınıfları da yüklenir ve eklenti kapalıyken her açılışta "Native plugin not found" hataları basar (telefonda
## görüldü 2026-10-23; Telemetry bunları hata raporu sayıyordu).
const ADMOB_PROVIDER: String = "res://ads/admob_provider.gd"
const APPLOVIN_PROVIDER: String = "res://ads/applovin_provider.gd"
const APPLOVIN_SINGLETON: String = "AppLovinMAXGodotPlugin"   # AppLovinProvider.SINGLETON

static var _provider: AdProvider
static var _done: bool = false
static var _ok: bool = false
static var _on_started: Callable = Callable()


## Ağın eklentisi varsa gerçek sağlayıcı (kimlikler eksikse KAPALI); eklentisiz debug derleme = sahte sağlayıcı.
static func pick() -> AdProvider:
	if not GameFeatures.ADS:
		return AdProvider.new()   # kapalı: hiçbir şey yüklenmez, hiçbir teklif çıkmaz
	match AdConfig.NETWORK:
		AdConfig.Network.APPLOVIN:
			if Engine.has_singleton(APPLOVIN_SINGLETON):
				return load(APPLOVIN_PROVIDER).new() if AdConfig.applovin_ready() else AdProvider.new()
		AdConfig.Network.ADMOB:
			if Engine.has_singleton("PoingGodotAdMob"):
				return load(ADMOB_PROVIDER).new() if AdConfig.any_slot_usable() else AdProvider.new()
		AdConfig.Network.APPODEAL:
			if AppodealProvider.available():
				return AppodealProvider.new() if AdConfig.appodeal_ready() else AdProvider.new()
	if OS.is_debug_build():
		return MockAdProvider.new()   # masaüstü geliştirme
	return AdProvider.new()


## Yükleme ekranı: sağlayıcıyı seçer ve SDK'yı başlatır; başlayınca (AdService henüz devralmadıysa) her yuvanın
## reklamını yüklemeye başlar.
static func start_early() -> void:
	if _provider != null:
		return
	_done = false
	_ok = false
	_provider = pick()
	_provider.start(func(ok: bool) -> void: _started(ok))


static func _started(ok: bool) -> void:
	_done = true
	_ok = ok
	if _on_started.is_valid():
		var adopter: Callable = _on_started
		_on_started = Callable()
		adopter.call(ok)   # AdService devraldı: yüklemeyi kendisi yönetir
		return
	if not ok or _provider == null:
		return
	for slot: StringName in AdConfig.slots():
		var unit: String = _provider.unit_for(slot)
		if unit != "":
			# Sonuç burada beklenmez: AdService devralınca yuvaya bakar (yüklüyse hazır, sürüyorsa aynı yüklemeyi bekler).
			_provider.load_rewarded(slot, unit, func(_loaded: bool) -> void: pass)


## AdService: erken başlatılmış sağlayıcıyı devralır (BİR kez). on_started(ok) başlatma bitince çağrılır (bittiyse bir
## sonraki karede). Erken başlatma yoksa null.
static func take(on_started: Callable) -> AdProvider:
	var provider: AdProvider = _provider
	if provider == null:
		return null
	_provider = null
	if _done:
		on_started.call_deferred(_ok)
	else:
		_on_started = on_started
	return provider
