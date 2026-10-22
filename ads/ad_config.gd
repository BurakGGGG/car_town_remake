class_name AdConfig
extends RefCounted
## REKLAM KİMLİKLERİ ve açma/kapama kuralı — tek yer.
##
## HESAP GÜVENLİĞİ: Google, gerçek reklam birimini geliştirme sırasında göstermeyi / tıklamayı
## hesap askıya alma sebebi sayar. Bu yüzden kimlik seçimi derleme türüne bağlı ve KOD İLE zorunlu:
##   debug derleme   → her zaman Google'ın TEST kimlikleri
##   release derleme → yalnızca gerçek kimlik; boşsa o yuva KAPALI (test reklamı yayına çıkmaz)
##
## Uygulama kimliği (ca-app-pub-…~…) kodda DEĞİL, Proje Ayarları → admob/general/android/app_id içindedir.
##
## REKLAM AĞI GEÇMİŞİ: 2026-10-19 AdMob hesabı reddedildi; AppLovin MAX hazırlandı ama AppLovin yeni yayıncı almıyor
## (kod beklemede: addons/applovin_max — editör eklentisi KAPALI —, ads/applovin_provider.gd, ads/ad_privacy.gd;
## docs/ads/APPLOVIN_KURULUM.md). 2026-10-22'den beri ağ APPODEAL (aşağıda; docs/ads/APPODEAL_KURULUM.md).
## Ağ değiştirmek: NETWORK + o ağın eklentisi / Gradle bağımlılıkları + admob/general/android/enabled (yalnız ADMOB'da açık).
## AppLovin'de herkese açık test birimi YOK: debug derlemede reklam yalnızca SDK "test modu" bildirirse gösterilir
## (cihaz APPLOVIN_TEST_DEVICES'ta ya da MAX panelinde test cihazı) — AppLovinProvider zorunlu kılar.

## APPODEAL (2026-10-22): AdMob hesabı reddedildi, AppLovin yeni yayıncı almıyor → Appodeal (aracı platform: kendi
## hesaplarıyla AppLovin, Unity, Mintegral, Vungle, Meta… bağlar; oyuncunun bu ağlarda hesabı gerekmez). Eklentisiz:
## Java köprüsü (AppodealProvider), SDK + ağ adaptörleri Gradle bağımlılığı (addons/autoyard_android, APPODEAL_DEPENDENCIES).
## AdMob ile birlikte KULLANILMAZ: Poing AdMob'un Android dışa aktarması kapalı olmalı (admob/general/android/enabled).
enum Network { ADMOB, APPLOVIN, APPODEAL }
const NETWORK: Network = Network.APPODEAL

## Reklam YUVALARI: her yuvanın kendi AdMob birimi ve kendi önceden yüklenmiş reklamı vardır
## (AdMob raporlarında yarış / tamir ayrı görünür). Bir teklif türü AdPolicy.RULES'ta bir yuvaya bağlıdır.
const SLOT_RACE: StringName = &"race"
const SLOT_REPAIR: StringName = &"repair"

## Google'ın herkese açık test reklam birimleri (Android).
const TEST_REWARDED: String = "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL: String = "ca-app-pub-3940256099942544/1033173712"

## GERÇEK ödüllü reklam birimleri (AdMob → AUTO YARD → Reklam birimleri).
const REAL_REWARDED: Dictionary = {
	SLOT_RACE: "ca-app-pub-7404501315536471/5366116477",     # odullu_yaris
	SLOT_REPAIR: "ca-app-pub-7404501315536471/4055980794",   # odullu_tamir
}


static func slots() -> Array[StringName]:
	return [SLOT_RACE, SLOT_REPAIR]


## Yuvanın ödüllü reklam birimi kimliği. Boş dönerse yuva kapalıdır.
static func rewarded_unit(slot: StringName) -> String:
	if OS.is_debug_build():
		return TEST_REWARDED
	return String(REAL_REWARDED.get(slot, ""))


## Bu derlemede, bu birim kimliği güvenle kullanılabilir mi? (test ↔ gerçek karışmasın)
static func unit_is_safe(unit_id: String) -> bool:
	if unit_id == "":
		return false
	var is_test: bool = unit_id.begins_with("ca-app-pub-3940256099942544/")
	return is_test == OS.is_debug_build()


## Herhangi bir yuva bu derlemede kullanılabilir mi? (hepsi boş/güvensizse reklam sistemi hiç kurulmaz)
static func any_slot_usable() -> bool:
	for slot: StringName in slots():
		if unit_is_safe(rewarded_unit(slot)):
			return true
	return false


# --- AppLovin MAX -----------------------------------------------------------------

## SDK anahtarı (MAX paneli → Account → General → Keys). Boşsa AppLovin hiç başlatılmaz.
const APPLOVIN_SDK_KEY: String = ""

## Ödüllü MAX reklam birimi (MAX paneli → Ad Units; 16 haneli onaltılık kimlik). Boşsa reklam kapalı.
## AppLovin biçim başına TEK birim öneriyor → iki yuva aynı birimi paylaşır; MAX raporunda yuvalar yerleşim
## (placement) adıyla ayrılır (AppLovinProvider.show_rewarded).
const APPLOVIN_REWARDED_UNIT: String = ""

## Test cihazlarının reklam kimlikleri (GAID; telefonda Ayarlar → Google → Reklamlar). Bu cihazlar release
## derlemede de TEST reklamı görür: geliştiricinin kendi telefonunda gerçek gösterim = geçersiz trafik.
const APPLOVIN_TEST_DEVICES: PackedStringArray = []


static func applovin_unit(slot: StringName) -> String:
	return APPLOVIN_REWARDED_UNIT.strip_edges() if slots().has(slot) else ""


## AppLovin başlatılabilir mi: anahtar ve en az bir yuva birimi var.
static func applovin_ready() -> bool:
	if APPLOVIN_SDK_KEY.strip_edges() == "":
		return false
	for slot: StringName in slots():
		if applovin_unit(slot) != "":
			return true
	return false


## SDK'ya başlatmada verilen birim listesi (MAX önceden hazırlık için ister).
static func applovin_units() -> PackedStringArray:
	var out: PackedStringArray = []
	for slot: StringName in slots():
		var unit: String = applovin_unit(slot)
		if unit != "" and not out.has(unit):
			out.append(unit)
	return out


# --- Appodeal ----------------------------------------------------------------------

## Uygulama anahtarı (Appodeal paneli → Apps → AUTO YARD). Pakete gömülür, gizli değildir. Boşsa Appodeal başlatılmaz.
const APPODEAL_APP_KEY: String = "cf64a0340176731c4e986d3ef63e5eab2c4963aaf73c9a42"

## Maven deposu ve bağımlılıklar: Appodeal panelinin 4.4.0 listesinden (docs.appodeal.com/onboarding/android/get-started,
## 2026-10-22). ÇIKARILANLAR: AdMob / Google Ad Manager adaptörleri (AdMob uygulama kimliği olmadan Google SDK'sı açılışta
## çöker; hesap reddedildi), analitik servisleri (Adjust, AppsFlyer, Facebook Analytics, Firebase — bizim Firebase
## sürümlerimizi yükseltir —, Sentry), Amazon (kendi APS hesabı ister) ve küçük ağlar (paket boyutu). Bir ağ eklenecekse
## o ağın beş katmandaki adaptörlerinin HEPSİ eklenir (Appodeal kendi, BidMachine, AppLovin MAX, Bidon, LevelPlay).
const APPODEAL_MAVEN: String = "https://artifactory.appodeal.com/appodeal"
const APPODEAL_DEPENDENCIES: PackedStringArray = [
	"com.appodeal.ads.sdk:core:4.4.0",
	# BidMachine
	"io.bidmachine:ads.networks.meta_audience:6.21.0.1",
	"io.bidmachine:ads.networks.mintegral:17.1.61.1",
	"io.bidmachine:ads.networks.vungle:7.7.4.0",
	# AppLovin MAX
	"com.applovin.mediation:bidmachine-adapter:3.7.1.0",
	"com.applovin.mediation:bytedance-adapter:8.1.0.3.0",
	"com.applovin.mediation:facebook-adapter:6.21.0.0",
	"com.applovin.mediation:fyber-adapter:8.4.6.0",
	"com.applovin.mediation:inmobi-adapter:11.3.0.1",
	"com.applovin.mediation:ironsource-adapter:9.4.4.0.0",
	"com.applovin.mediation:mintegral-adapter:17.1.61.0",
	"com.applovin.mediation:moloco-adapter:4.3.1.0",
	"com.applovin.mediation:unityads-adapter:4.17.0.0",
	"com.applovin.mediation:vungle-adapter:7.7.4.0",
	# Bidon
	"org.bidon:applovin-adapter:13.6.3.0",
	"org.bidon:bidmachine-adapter:3.7.1.1",
	"org.bidon:dtexchange-adapter:8.4.6.0",
	"org.bidon:inmobi-adapter:11.3.0.0",
	"org.bidon:ironsource-adapter:9.4.4.0",
	"org.bidon:meta-adapter:6.21.0.0",
	"org.bidon:mintegral-adapter:17.1.61.0",
	"org.bidon:moloco-adapter:4.3.1.0",
	"org.bidon:unityads-adapter:4.17.0.0",
	"org.bidon:vungle-adapter:7.7.4.0",
	# LevelPlay
	"com.unity3d.ads-mediation:applovin-adapter:5.8.0",
	"com.unity3d.ads-mediation:bidmachine-adapter:5.7.0",
	"com.unity3d.ads-mediation:facebook-adapter:5.3.0",
	"com.unity3d.ads-mediation:fyber-adapter:5.9.0",
	"com.unity3d.ads-mediation:inmobi-adapter:5.7.0",
	"com.unity3d.ads-mediation:mintegral-adapter:5.18.0",
	"com.unity3d.ads-mediation:moloco-adapter:5.6.0",
	"com.unity3d.ads-mediation:pangle-adapter:5.18.0",
	"com.unity3d.ads-mediation:unityads-adapter:5.6.0",
	"com.unity3d.ads-mediation:vungle-adapter:5.10.0",
	# Appodeal
	"com.appodeal.ads.sdk.adapters:applovin:13.6.3.0",
	"com.appodeal.ads.sdk.adapters:applovin_max:13.6.3.1",
	"com.appodeal.ads.sdk.adapters:bidmachine:3.7.1.0",
	"com.appodeal.ads.sdk.adapters:bidon:0.14.0.0",
	"com.appodeal.ads.sdk.adapters:dt_exchange:8.4.6.0",
	"com.appodeal.ads.sdk.adapters:iab:1.8.1.1",
	"com.appodeal.ads.sdk.adapters:inmobi:11.3.0.0",
	"com.appodeal.ads.sdk.adapters:ironsource:9.4.4.0",
	"com.appodeal.ads.sdk.adapters:level_play:9.4.4.0",
	"com.appodeal.ads.sdk.adapters:meta:6.21.0.0",
	"com.appodeal.ads.sdk.adapters:mintegral:17.1.61.0",
	"com.appodeal.ads.sdk.adapters:moloco:4.3.1.0",
	"com.appodeal.ads.sdk.adapters:unity_ads:4.17.0.0",
	"com.appodeal.ads.sdk.adapters:vungle:7.7.4.0",
]

## Appodeal'da yuva başına birim YOK: iki yuva aynı ödüllü reklam önbelleğini paylaşır. Boş olmayan işaret = yuva açık.
const APPODEAL_UNIT: String = "appodeal_rewarded"


static func appodeal_ready() -> bool:
	return APPODEAL_APP_KEY.strip_edges() != ""


static func appodeal_unit(slot: StringName) -> String:
	return APPODEAL_UNIT if slots().has(slot) and appodeal_ready() else ""
