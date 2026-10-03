# AUTO YARD v2 — Reklam Entegrasyonu Araştırma Raporu

Tarih: 2026-10-03 · Durum: **ARAŞTIRMA / TASARIM — oyun kodu değişmedi**

Kaynaklar resmi Google sayfaları ve eklentinin kendi deposudur (sonda liste). Sayısal gelir değerleri üçüncü taraf blog
verisidir ve **Türkiye için doğrulanmış değildir**; tahmin olarak okunmalıdır.

---

## 0. Kesinleşen kararlar (2026-10-03)

| Konu | Karar |
|---|---|
| Reklam ödülü | **Yalnızca ₺ (para) ve süre kısaltma. Gem YOK** → R3 (gem teklifi) ve R4'ün gem kısmı kapsam dışı; kasa/gem dengesi dokunulmaz |
| Hedef kitle | Play Console'da **13 yaş ve üzeri** seçildi → çocuk odaklı Aileler politikası kısıtları gerekmiyor (Console'daki seçimin yalnızca 13+ olduğu teyit edilmeli) |
| Web sitesi / gizlilik | Reklam açılmadan önce güncellenecek |
| Mağaza metni | "renge boya" ifadesi düzeltilecek |
| "Reklamları kaldır" (ücretli) | **Sonraki aşama** (v2 kapsamı dışı) |
| AdMob hesabı | Var; ancak önceki bir uygulama **2 ay boyunca onaylanmadı** → bkz. §6 notu, hesap/uygulama durumu önce kontrol edilecek |
| Ödüllü noktalar | Konuşulacak (açık) |
| Interstitial | Açık (cevaplanmadı) |

---

## 1. Kısa cevap

- **Evet, AdMob.** Godot'ta Android reklam için fiili standart: **Poing Studios "AdMob" eklentisi** (MIT lisanslı, Godot Asset Library / Asset Store'da).
  Çıkış sürümü v5.1.0 (2026-09-13), Godot 4.4+ ile uyumlu, **4.7.2'ye karşı test edilmiş** olduğu yazıyor. Biz Godot 4.7.2'deyiz.
- Formatlar: Banner, Interstitial, **Rewarded**, Rewarded Interstitial, App Open, Native. **UMP (onay penceresi)** dahil.
- **Önerim:** v2'de **ödüllü reklam (rewarded) ağırlıklı**, tek bir dikkatli **geçiş reklamı (interstitial)**. Banner ve App Open **yok**.
  Gerekçe: oyun yatay, kenarlara taşan plaka arayüzü var (banner yer bulamaz), tamir/kasa gibi oyuncunun odaklandığı anlar çok.
- **İki karar bu raporun geri kalanını belirler** (bkz. §9): (1) Play'deki **hedef kitle yaşı** (çocukları içeriyorsa kurallar çok sıkılaşır),
  (2) **gem ekonomisi** reklamla beslenecek mi (kasa sisteminin dengesini etkiler).

---

## 2. Teknik yol: hangi eklenti, nasıl kurulur

| Konu | Bilgi |
|---|---|
| Eklenti | `poingstudios/godot-admob-plugin` (MIT). Asset Library'de "AdMob" |
| Godot sürümü | 4.4+ (v5.1.0); 4.7.2 ile test edildiği belirtilmiş |
| Android gereksinimi | **Gradle build** (zaten kullanıyoruz), `minSdk ≥ 24` (bizde 24), `compileSdk ≥ 35` (bizde 36) |
| SDK | Google Mobile Ads **Next-Gen SDK** (Google eski SDK'yı "bakım modunda" ilan etti, yenisini öneriyor) |
| Onay | UMP SDK dahil: `ConsentInformation.request_consent_info_update()` → gerekirse form |
| Test | Google test reklam kimlikleri (`ca-app-pub-3940256099942544/…`; ödüllü: `/5224354917`). **Gerçek kimlikle geliştirirken tıklamak hesabı askıya aldırabilir** |
| Editörde | v5'te "mock" reklamlar var → masaüstünde akışı denemek mümkün |
| API (GDScript) | `RewardedAdLoader.new().load(unit_id, AdRequest.new(), callback)` → `ad.show(OnUserEarnedRewardListener…)`; `InterstitialAdLoader` benzer |

**Dikkat edilecek riskler (hiçbiri engelleyici değil, ama erken denenmeli):**
1. **Firebase eklentisiyle çakışma.** Projede kaynaktan derlenmiş `GodotFirebaseAndroid` var. İkisi de gradle'da Google Play Services /
   AndroidX sürümleri getiriyor; sürüm çatışması çıkarsa çözmek gerekir. → **İlk iş: ayrı dalda 1 günlük "spike"** (eklentiyi kur, test reklamı göster, AAB derle).
2. **Boyut.** Reklam SDK'sı AAB'ye birkaç MB ekler (şimdi 128,9 MB; 200 MB sınırının çok altında).
3. **Eklenti sürümü/SDK numaraları** yukarıda eklentinin kendi sürüm notundan alındı. Kurulum sırasında gerçek bağımlılık sürümlerini `gradle` çıktısından teyit edeceğiz.
4. **Proje kuralları:** autoload yok → reklam servisi `ui`/`gameplay` gibi bir **düğüm + grup** (`"ads"`) olacak; `.tscn`'ye ben dokunmam,
   gerekirse sahneye eklenecek düğümü sen eklersin; tipli GDScript; sinyaller `.connect()`.

---

## 3. Reklam formatları — AUTO YARD için karar tablosu

| Format | Karar | Gerekçe |
|---|---|---|
| **Rewarded (ödüllü)** | ✅ ANA GELİR | Oyuncu seçer, hiçbir şey zorlanmaz; en yüksek kazanç; AdMob politikasına en uygun |
| **Interstitial (geçiş)** | ⚠️ TEK NOKTA, kısıtlı | Yalnızca yarış sonucundan garaja dönerken (doğal mola), sıkı sıklık sınırıyla. İlk sürümde kapalı bayrakla gönderilip A/B açılabilir |
| Rewarded Interstitial | ❌ | Otomatik çıkar; opt-in intro ekranı gerektirir; oyuncu kontrolü zayıf |
| **Banner** | ❌ | Yatay, immersive, plaka tabanlı HUD; yanlış tıklama riski (hesap uyarısı sebebi); oyun hissini bozar |
| **App Open** | ❌ | Açılışta reklam AdMob politikasında interstitial için yasak; retention'ı öldürür |
| Native | ❌ (v2'de) | UI emek ister, getirisi belirsiz |

---

## 4. Nereye koyacağız — oyunun gerçek akışına göre

Mevcut sistemlerden okunan anlar (kod incelendi):

### 4.1 Ödüllü reklam noktaları (hepsi "REKLAM İZLE" plakası = açık opt-in)

| # | Yer | Teklif | Neden uyuyor | Ekonomi etkisi |
|---|---|---|---|---|
| R1 | **Yarış sonucu** (`RaceResultScreen`, ödül zaten gösteriliyor) | "Reklam izle → ₺ ödülü **×2**" | Oyuncu en mutlu anında; ödül `RaceManager.finish_race` ile tek seferlik verilir → ek ödül **ayrı ve tek sefer** işaretlenmeli (çift ödül riski) | ₺ enflasyonu: ₺ geç oyunda zaten sink arıyor → **günlük sınır** (örn. 5) |
| R2 | **Uzun tamir** (BOYA 90 sn, DÖŞEME 180 sn, FREN REVİZYONU 300 sn — `repair_type.gd`) | "Reklam izle → **kalan sürenin %50'si / hemen bitir**" | Bekleme süresini kısaltmak klasik ve adil; kısa işlerde (6–12 sn) **gösterme** | Gelir hızı artar ama ödül miktarı değişmez |
| R3 | **Gem teklifi** (HUD gem plakası / kasa ekranı) | "Reklam izle → **+10 gem**", günde en çok 3 | Gem = kasa para birimi. ACTIVE oyuncu ~111 gem/gün (tasarım belgesi) → +30 gem/gün ≈ +%27, CASUAL ~69/gün → ≈ +%43 | **Kasa dengesini değiştirir** (§7). Sabit miktar olmalı (rastgele ödül ise olasılıklar önceden gösterilmeli) |
| R4 | **Günlük giriş ödülü** (`GemRewards.LOGIN_CYCLE`) | "Reklam izle → bugünkü ödülü **×2**" | Geri dönüş anı | Tek sefer/gün, mevcut "aynı gün iki kez verilmez" işaretine bağlanır |
| R5 | **Seviye atlama ödülü** (`PlayerProgress.level_reward`) | "×2 para" | Doğal kutlama anı | Küçük; R1 ile aynı mantık |
| R6 (opsiyonel) | **Müşteri çağır** (garaj boş, müşteri akışı 6–14 sn) | "VIP müşteri hemen gelsin (+%50 tamir ödülü)" | Boş bekleme anı | Müşteri arzı sınırlıydı (GDD §0.1) — dengeyi test et |

**Kural (AdMob politikası):** teklif plakasında **neyi izleyince ne alacağı açık yazılmalı**; reddetmek hiçbir şeyi bloke etmemeli;
ödül **reklam gerçekten bitince** verilmeli; "bizi desteklemek için izle" gibi ifadeler yasak.

### 4.2 Geçiş reklamı noktası (opsiyonel, sıkı kurallı)

- **Tek yer:** `RaceResultScreen` → "GARAJA DÖN" **sonrası** (yarış-garaj geçişi = mantıksal mola). Gösterim *Continue'dan önce/sonra* tuzağı yok: reklamı oyuncu butona basınca değil, **geçiş tamamlanınca** göster.
- Sınırlar (bizim kuralımız, politikadan daha sıkı): ilk oturumda yok; seviye ≥ 5; en az 3 yarışta bir; iki reklam arası ≥ 4 dk; hiç **GERİ tuşunda / açılışta / çıkışta** yok (AdMob "disallowed"); kasa açılışı, tamir toplama, satın alma sırasında **asla**.
- Reklam **önceden yüklenir** (preload); gecikmeli, ani çıkan reklam politika ihlali sayılır.
- Yarışta hızlı dokunma var (vites) → AdMob "aşırı dokunan uygulamalarda ekran sonrası gecikme koyun" tavsiyesi: sonuç ekranından sonra 1–2 sn bekleme.

### 4.3 ASLA reklam gösterilmeyecek anlar
Açılış/yükleme, drag yarışı sırasında, tamir sürerken, kasa açılış/ödül gösterimi, GERİ tuşuyla çıkış, hesap/silme ekranları, ilk 10 dk (ilk oturum), garaj editörü.

---

## 5. Kod mimarisi önerisi (mevcut sistemlere dokunmadan)

```
ads/
  ad_config.gd        # birim kimlikleri (test/gerçek), bayraklar. Release'te test kimliği, debug'ta gerçek kimlik YASAK (guard + test)
  ad_service.gd       # düğüm, grup "ads": init, consent, preload, show; sağlayıcı soyutlaması
  admob_provider.gd   # Poing eklentisini saran ince katman
  mock_provider.gd    # testler / masaüstü için sahte sağlayıcı (headless testler eklentisiz çalışır)
  ad_policy.gd        # saf statik: sıklık sınırı, günlük tavan, uygunluk (test edilebilir)
  consent_flow.gd     # UMP akışı
ui/hud/
  ad_offer_plate.gd   # PlateButton diliyle "REKLAM İZLE → +10 GEM" plakası (container tabanlı, mutlak konum yok)
gameplay/game_features.gd → const ADS: bool   # mevcut PAINT bayrağı gibi tek açma/kapama noktası
```

Dikkat edilecekler (bu projenin kendi derslerinden):
- **Ödül idempotansı:** ödül yalnızca `on_user_earned_reward`'da, **bir kez** verilir ve **hemen kaydedilir** (kasa sistemindeki "satın al → sonuç kaydedildi" mantığı). Uygulama reklam ortasında kapanırsa ödül yok, kayıp yok.
- **Kayıt:** `SaveManager` v11'e `ads` bölümü (günlük sayaçlar, gün numarası). `GemRewards`'taki **saat güvenliği** modeli (gün yalnızca ileri gider) aynen kullanılır; yeni alanlar `SaveSafe` ile okunur (bu oturumda eklediğimiz bozuk-kayıt koruması).
- **Hile yüzeyi:** "reklam izle" hızlı çift dokunuş → teklif plakası tek seferde kilitlenir; reklam dönene kadar buton pasif.
- **Çevrimdışı / reklam yok (no fill):** buton "REKLAM HAZIR DEĞİL" der, **sonsuz yükleme yok**; ödül verilmez ama oyun akışı bloke olmaz.
- **GERİ tuşu / UiRouter:** tam ekran reklam ayrı bir Android Activity; oyun arka plana geçer, dönüşte sahne korunmalı → cihazda test şart.
- **Ses:** oyunda ses yok; ses eklenirse reklam sırasında susturma gerekir.
- **Testler:** `ad_policy` birim testleri, mock sağlayıcıyla "ödül tek sefer", "limit aşılırsa teklif yok", "release'te test kimliği yok" kontrolleri → `tools/run_tests.sh`'e `ads_test`.

---

## 6. Google / AdMob / Play uyumluluk kontrol listesi

| Konu | Gereken | Kaynak |
|---|---|---|
| **AdMob hesabı + uygulama bağlama** | AdMob'da uygulama eklenir, Play'e yayınlandıktan sonra bağlanır; yayına kadar **test reklam** | AdMob |
| **Onay penceresi (UMP)** | AEA/BK/İsviçre için Google onaylı CMP zorunlu (AdMob'un kendi UMP'si yeterli). Yoksa yalnızca "sınırlı reklam" | AdMob/UMP |
| **Türkiye (KVKK)** | Aranan kaynaklarda Türkiye'ye özgü bir madde **bulamadım**. Gizlilik metni için hukuki teyit gerekir | — |
| **Play: "Reklam içerir"** | Console'da **Evet** işaretlenir (mağazada "Reklam içerir" etiketi çıkar) | Play |
| **Data safety** | Reklam kimliği, cihaz kimlikleri, kullanım verisi "reklam/pazarlama" amacıyla **Google AdMob ile paylaşılıyor** diye beyan | Play |
| **AD_ID izni** | AdMob SDK ≥ 20.4 ile **manifeste otomatik** eklenir; Play Console'da "reklam kimliği kullanıyor: evet / reklam-pazarlama" beyanı gerekir | Android 13+ |
| **Gizlilik politikası + site** | Mevcut sitede **"reklam yok"** cümleleri var (proje notu) → reklam açılmadan **güncellenmeli** (/gizlilik, SSS, llms.txt) | iç not |
| **app-ads.txt** | Mağaza kaydındaki **geliştirici web sitesinin kök dizinine** `google.com, pub-XXXX, DIRECT, …` satırı. Zorunlu olduğu net yazılmıyor ama önerilir ve gelir güvenliği için gerekli | AdMob |
| **Hedef kitle / Aileler politikası** | Çocukları da hedefleyen uygulamalarda **Families self-certified Ads SDK** kullanılmalı (AdMob 19+ uygun), reklam kimliği çocuklara gönderilemez, `tagForChildDirectedTreatment` ve **max içerik derecesi G** şart, yalnız çocuk yaş grupları seçilirse AdMob otomatik uyumlu reklam sunar | Play/AdMob |
| **İçerik derecelendirme** | Reklamlar için anketin güncellenmesi | Play |
| **AdMob ödeme** | Vergi/ödeme profili, eşik tutar | AdMob |

**Mağaza metni uyarısı (reklamdan bağımsız, şimdi düzeltilmeli):** `~/Projects/ct_shots/store/final/magaza_metinleri.md` içinde
"Arabalarını istediğin renge boya" yazıyor; oysa **boya özelliği oyuncuya kapalı** (`GameFeatures.PAINT=false`). Yanıltıcı açıklama Play politikası sorunu doğurabilir.
Ayrıca reklam gelince açıklamaya/etikete reklam bilgisi eklenmeli.

---

## 7. Ekonomi etkisi (en çok tartışılacak kısım)

1. **Gem sürümü:** Kasa sistemi "gem gerçek parayla satılmaz, kıtlık kasıtlı" ilkesiyle tasarlandı (`vehicle_crate_design_v2.md`).
   Ödüllü reklamla gem vermek bu ilkeyi **gevşetir** (dolaylı gerçek para → gem). Eğer yapılacaksa:
   - Sabit, küçük, günlük tavanlı (öneri: **+10 gem × en çok 3/gün**) ve
   - kasa fiyatları/olasılıkları `tools/economy/crate_sim.py` ve `acquisition_sim.py` ile **yeniden simüle edilmeli** (30 gün / 10 saat koşuları).
   - Alternatif (daha güvenli): reklam **gem değil ₺ ve süre kısaltma** versin; gem yalnızca oynanışla gelsin.
2. **₺ enflasyonu:** Geç oyunda ₺ çıkışı zaten "ekonomi tasarım riski" (önceki denetim). ₺×2 reklamı bunu büyütür → sınır + yeni ₺ harcama yeri.
3. **Bedava araç/kasa yok:** reklam doğrudan araç veya kasa vermemeli (koleksiyon değerini düşürür).
4. **Reklamsız ilk deneyim:** ilk oturum ve ilk yarış reklamsız → ilk izlenim ve Play'in "yanıltıcı teşvik" riskine karşı.
5. **"Reklamları kaldır" satın alması** şu an **yok** (Play Billing gerekir; ayrı ve büyük bir iş). v2'de yoksa interstitial'ı çok kısıtlı tut.

### Gelir tahmini (YAKLAŞIK, doğrulanmamış)
Kaynaklara göre rewarded eCPM: Tier-1 ülkeler $15–40, Tier-2/3 yaklaşık **$3–10**; Türkiye için ölçülmüş değer bulamadım.
Formül: `günlük gelir ≈ DAU × (kullanıcı başı günlük izleme) × eCPM / 1000`.
Örnek (yalnızca hesap örneği): 1.000 DAU × 2 izleme × $5/1000 ≈ **$10/gün**. Yani ilk aylarda gelir küçük; asıl iş **oyuncu sayısı**.
Bu yüzden reklam tasarımının oyuncu kaybettirmemesi, gelirin kendisinden önemlidir.

---

## 8. Önerilen plan (fazlar)

| Faz | İş | Çıktı |
|---|---|---|
| **0 — Karar** | §9'daki sorular (hedef yaş, gem politikası, interstitial evet/hayır) | Net kapsam |
| **1 — Spike (1 gün)** | Dalda eklentiyi kur, test ödüllü reklamı göster, **Firebase ile birlikte AAB derle**, telefonda dene | Çakışma var/yok kanıtı |
| **2 — Altyapı** | `ads/` modülü, `GameFeatures.ADS`, mock sağlayıcı, `ad_policy`, kayıt v11 + `ads_test` | Testli iskelet, reklam yok görünür |
| **3 — UMP + ilk teklif** | Onay akışı, R1 (yarış ×2) ve R2 (tamir hızlandır) | İlk gerçek akış (test kimlikleriyle) |
| **4 — Ekonomi** | R3/R4 (gem/giriş) kararına göre; simülasyonlarla denge | Simülasyon raporu |
| **5 — Mağaza/uyum** | AdMob hesabı, gerçek kimlikler, Data safety, site/gizlilik, app-ads.txt, "reklam içerir", mağaza metni düzeltmesi | Konsol işleri (sende) |
| **6 — Kapalı test** | Cihazda yaşam döngüsü, GERİ tuşu, çevrimdışı, reklam yok durumu; pre-launch raporu | v2 RC |
| **7 — Yayın** | Kademeli yayın (%10 → %50 → %100), AdMob/Play vitals izleme | v2 |

**Test disiplini (v1 denetiminden):** her faz sonunda `tools/run_tests.sh` (şu an 1289 kontrol) + yeni `ads_test`; release AAB'de
test kimliği taraması; gerçek cihaz testi **yapılmadan "tamam" denmeyecek**.

---

## 9. Senin vereceğin kararlar

1. **Play Console hedef kitle yaşı ne seçildi?** (13+ mı, çocukları da içeriyor mu?) → çocuklar varsa reklam türü ve ağlar kısıtlanır, getiri düşer.
2. **Gem ödülü olsun mu?** (R3/R4) yoksa reklam yalnızca ₺ + süre kısaltma mı versin?
3. **Interstitial olsun mu?** (öneri: v2'de kapalı bayrakla hazır, ödüllüler oturunca A/B)
4. **"Reklamları kaldır" ücretli seçeneği** v2 kapsamında mı? (Play Billing = ayrı iş)
5. **AdMob hesabın var mı?** (yoksa şimdi aç; uygulama ekleme, ödeme/vergi profili, onay mesajı oluşturma sende)
6. **Hangi ödüllü noktalar** ilk sürüme girsin? (öneri: R1 + R2; R3 kararına göre)

---

## Kaynaklar
- Eklenti deposu: https://github.com/poingstudios/godot-admob-plugin · sürümler: https://github.com/poingstudios/godot-admob-plugin/releases
- Eklenti belgeleri: https://poingstudios.github.io/godot-admob-plugin/stable/
- Ödüllü reklam rehberi (Android): https://developers.google.com/admob/android/rewarded
- Ödüllü reklam politikası: https://support.google.com/admob/answer/7313578
- Yasak interstitial uygulamaları: https://support.google.com/admob/answer/6201362
- Önerilen interstitial uygulamaları: https://support.google.com/admob/answer/6201350
- Aileler politikası ve AdMob: https://support.google.com/admob/answer/6223431
- Aileler self-certified reklam SDK: https://support.google.com/googleplay/android-developer/answer/12955712
- Avrupa düzenleme mesajları / UMP: https://support.google.com/admob/answer/10114014 · https://developers.google.com/admob/android/privacy/gdpr
- app-ads.txt: https://support.google.com/admob/answer/9363762
- Data safety: https://support.google.com/googleplay/android-developer/answer/10787469
- Reklam kimliği / gizlilik: https://support.google.com/admob/answer/11402075
- eCPM verisi (3. taraf): https://www.businessofapps.com/ads/rewarded-video/ · https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect
