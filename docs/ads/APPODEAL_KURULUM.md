# Appodeal kurulumu (2026-10-22/23)

AdMob hesabı reddedildi, AppLovin yeni yayıncı almıyor → reklam ağı **Appodeal** (aracı platform). Appodeal kendi
hesaplarıyla AppLovin, Unity Ads, Mintegral, Vungle/Liftoff, Meta, Moloco, IronSource/LevelPlay, Pangle, InMobi,
DT Exchange ve kendi borsalarını (BidMachine, Bidon) bağlar; bu ağlarda ayrı hesap açmak gerekmez.

## Panel (app.appodeal.com)

| Adım | Durum |
|---|---|
| 1. Add App | Tamam — "Not Live" (ön kayıttaki uygulama mağazadan içe aktarılamıyor), Google Play, AUTO YARD, `com.autoyard.app`. Uygulama no 788100. |
| 2. Monetization Setup | Tamam — Autoconnection açık. AdMob ve Meta (yalnız kendi hesabınla) bağlanmadı. |
| 3. SDK Integration | İlk test gösterimi bekleniyor (hata ayıklama APK'sı, test modu). |
| 4. Publish App | Uygulama yayına girince mağaza linki bağlanır. |

App Key: `AdConfig.APPODEAL_APP_KEY` (pakete gömülür, gizli değil).

## Oyun tarafı

- `ads/appodeal_provider.gd` — eklentisiz, Godot'un Java köprüsüyle (`JavaClassWrapper`; geri çağrı arayüzleri
  `create_proxy`). Ödüllü reklam (`Appodeal.REWARDED_VIDEO` = 128), otomatik önbellek kapalı (yüklemeyi AdService
  yönetir), iki yuva tek önbelleği paylaşır. Hata ayıklama derlemesi `setTesting(true)` → test reklamı.
- AB onayı: Appodeal 4 başlatırken UMP tabanlı onay penceresini kendisi gösterir (yalnız AEA). Sonradan:
  AYARLAR → HESAP VE GİZLİLİK → REKLAM GİZLİLİK SEÇENEKLERİ (`ConsentManager.showPrivacyOptionsForm`).
- `AdConfig.NETWORK = APPODEAL`, `APPODEAL_DEPENDENCIES` (Gradle), `APPODEAL_MAVEN`.
- `addons/autoyard_android/plugin.gd` bağımlılıkları ve Maven deposunu dışa aktarmaya ekler, konum izinlerini çıkarır.
- Poing AdMob'un Android dışa aktarması KAPALI (`admob/general/android/enabled=false`): iki Google reklam SDK'sı
  çakışmasın. AdMob'a dönmek: `NETWORK = ADMOB` + bu ayarı aç.

### Bağımlılık seçimi

Liste Appodeal'ın 4.4.0 üreticisinden (docs.appodeal.com/onboarding/android/get-started). Çıkarılanlar:

- AdMob / Google Ad Manager adaptörleri — AdMob uygulama kimliği olmadan Google SDK'sı açılışta çöker.
- Analitik servisleri (Adjust, AppsFlyer, Facebook Analytics, Firebase, Sentry) — Firebase adaptörü bizim Firebase
  sürüm kümemizi (BoM 33.13.0) yükseltir.
- Amazon (kendi APS hesabı ister) ve küçük ağlar (Chartboost, MobileFuse, Ogury, PubMatic, Smaato, Start.io, TaurusX,
  Verve, VK, zMaticoo, Yandex, myTarget, Bigo) — paket boyutu. Gelir ölçülünce eklenebilir: bir ağın BEŞ katmandaki
  (Appodeal, BidMachine, AppLovin MAX, Bidon, LevelPlay) adaptörlerinin hepsi birlikte eklenir.

### Düz HTTP (cleartext)

Appodeal rehberi `networkSecurityConfig` ile düz HTTP'ye izin verilmesini istiyor (bazı ağların içerikleri). Kullanıcı
kararı (2026-10-23): şimdilik **izin yok**; test reklamlarında sorun çıkarsa açılır.

## Yayından önce

1. `app-ads.txt` — site deposunda `src/static/app-ads.txt` Appodeal listesiyle güncellendi (2.5 bin satır); push edilip
   `autoyard.online/app-ads.txt`'de görünmeli. Play Console'da geliştirici web sitesi `autoyard.online` olmalı.
2. Gizlilik politikası — Reklamlar bölümü AdMob yerine Appodeal + ortak ağları anlatmalı (5 dil).
3. Play Console → Veri güvenliği — reklam kimliği, uygulama etkileşimleri, tanılama (Appodeal'ın "App Privacy
   Details" sayfasına göre).
4. Panel 4. adım — uygulama yayına girince mağaza linkini bağla.
