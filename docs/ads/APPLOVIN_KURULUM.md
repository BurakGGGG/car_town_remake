# AppLovin MAX Kurulumu (2026-10-19)

> **DURUM: BEKLEMEDE.** AppLovin kayıttan sonra "We're currently not accepting new publisher accounts" e-postası
> gönderdi (2026-10-19). Ağ yine AdMob (`AdConfig.NETWORK = ADMOB`), `project.godot` eski hâlinde: AppLovin editör
> eklentisi KAPALI, AdMob dışa aktarımı AÇIK. AppLovin kodu duruyor; açmak için aşağıdaki "Kodda ne değişti"
> tablosundaki iki `project.godot` ayarı + `NETWORK = APPLOVIN`. Bu kod Godot'ta henüz hiç çalıştırılmadı.

AdMob hesabı "program kriterlerine uygun değil" diye reddedildi → reklam ağı **AppLovin MAX**.
Oyun kodu hazır; anahtar ve birim kimlikleri girilene kadar release derlemede reklam **kapalı** kalır
(`AdConfig.applovin_ready()` false → `AdService` kapalı sağlayıcı seçer).

## Kodda ne değişti

| Yer | Ne |
|---|---|
| `addons/applovin_max/` | Resmi eklenti 1.2.0 (MIT): `AppLovinMAX.gd` + AAR. Android'e bizim **v2 dışa aktarma sarmalayıcımız** (`applovin_max_plugin.gd`) ekler, AppLovin SDK `13.6.4` orada sabit. Resmi hata düzeltildi: test cihazı kimlikleri Java'ya hiç geçmiyordu |
| `ads/applovin_provider.gd` | Yeni sağlayıcı (yükle / göster / ödül tek sefer / geç gelen ödül / debug'da test modu zorunlu) |
| `ads/ad_privacy.gd` | Kişiselleştirilmiş reklam kararı: AEA/BK/İsviçre varsayılan **kapalı**, diğerleri açık, ülke bilinmiyorsa kapalı; oyuncu AYARLAR'dan değiştirir |
| `ads/ad_config.gd` | `NETWORK = APPLOVIN`, `APPLOVIN_SDK_KEY`, `APPLOVIN_REWARDED_UNIT` (iki yuva paylaşır), `APPLOVIN_TEST_DEVICES` |
| `ui/hud/settings_screen.gd` | HESAP VE GİZLİLİK → **KİŞİSELLEŞTİRİLMİŞ REKLAMLAR** AÇIK/KAPALI |
| `project.godot` | AppLovin eklentisi açık; `admob/general/android/enabled=false` (AdMob SDK APK'ya girmez, kodu duruyor) |

AdMob'a dönmek: `AdConfig.NETWORK = Network.ADMOB` + `admob/general/android/enabled=true`. Ya da AdMob hesabı
düzelirse AdMob'u MAX içinde **aracı ağ** olarak bağlamak (Google talebi de gelir).

## 1. AppLovin paneli (sen) — dash.applovin.com

1. Hesap aç. Kayıt formu mağaza linki isterse: oyun Play'de herkese açık olunca
   `https://play.google.com/store/apps/details?id=com.autoyard.app` (2026-10-19'da hâlâ 404). Panelde yayında olmayan
   uygulama **Manually Add Your Package Name** ile `com.autoyard.app` olarak eklenebilir. Account → General → Basic Info
   alanına yalnız kök alan adı: `autoyard.online` (Play kaydındaki web sitesi ve app-ads.txt ile aynı).
   **Ad soyad, adres, telefon kimliğinle birebir aynı** olsun (AdMob reddinin muhtemel nedeni bilgi
   uyuşmazlığı / mükerrer hesaptı; aynı hatayı tekrarlama).
2. **SDK Key**: Account → Keys. → bana ver (`AdConfig.APPLOVIN_SDK_KEY`).
3. **Ad Unit** × 1: MAX → Manage → Ad Units → Create. Platform **Android**, paket `com.autoyard.app`,
   biçim **Rewarded**, ad `odullu`. AppLovin biçim başına TEK birim öneriyor; yarış / tamir raporda yerleşim adıyla
   (`race` / `repair`) ayrılır. Çıkan 16 haneli kimliği bana ver (`AdConfig.APPLOVIN_REWARDED_UNIT`).
4. **Test cihazı**: telefonda Ayarlar → Google → Reklamlar → reklam kimliği (8-4-4-4-12). MAX → Test Mode'a ekle
   ve bana ver (`APPLOVIN_TEST_DEVICES`). Bu telefon release derlemede de test reklamı görür; **kendi telefonunda
   gerçek reklam izleme** (geçersiz trafik).
5. **Ödeme**: Account → Payments. PayPal Türkiye'de yok → **banka havalesi**. **W-8BEN** vergi formu şart; formdaki
   ad banka hesabındaki adla aynı olmalı. AppLovin ağı için en düşük ödeme 100 $.
6. **app-ads.txt**: panelin verdiği AppLovin satır(lar)ını bana ver → siteye eklenecek
   (`~/Projects/auto_yard_website/src/static/app-ads.txt`; AdMob satırı orada hazır ama push edilmedi).

## 2. Play Console (sen) — AppLovin'li sürüm yayına çıkmadan önce

- **Veri güvenliği** formu: AppLovin SDK'sının topladığı verileri ekle. AppLovin'in kendi "Data safety" yardım
  sayfasındaki listeyi kullan (tahmin etme). Reklam kimliği beyanı zaten "Reklam veya pazarlama".
- **Reklamlar**: "Evet, uygulamada reklam var" (değişmez).
- Hedef kitle **13+** kalmalı: AppLovin çocuklara yönelik uygulamada kullanılamaz ve "çocuk" sayılan kullanıcı için
  SDK başlatılamaz.

## 3. Web sitesi (ben hazırlarım, yayını AppLovin'li sürümle aynı anda)

Gizlilik politikası + kullanım şartları 5 dilde "Google AdMob" diyor → AppLovin'e göre güncellenecek
(veri listesi, AEA'da onay penceresi yerine kişiselleştirme varsayılan kapalı + AYARLAR düğmesi, AppLovin gizlilik
politikası bağlantısı). **Erken yayınlama**: sitede yazan ile oyunun yaptığı aynı olmalı.

## 4. Telefonda deneme (anahtarlar gelince)

1. Kimlikleri `ad_config.gd`'ye yaz, `tools/build_debug_apk.sh`, telefona kur.
2. Debug derlemede reklam yalnızca **test modunda** çıkar; günlükte `Test Mode On: true` ara
   (`adb logcat | grep -i applovin`). Test modu kapalıysa günlükte "debug derleme ama test modu kapalı" uyarısı çıkar.
3. Yarış sonucu ×2 ve uzun tamir kısaltma: ödül bir kez, reklamı erken kapatınca ödül yok.
4. AYARLAR → HESAP VE GİZLİLİK → KİŞİSELLEŞTİRİLMİŞ REKLAMLAR düğmesi.

## Açık noktalar

- Resmi eklenti Mayıs 2025'ten beri güncellenmedi; AAR v1 adını taşıyor (Godot 4.7.2 uyarıyla yüklüyor). Godot ileride
  v1 desteğini kaldırırsa AAR'ı kaynaktan v2 adıyla derlemek gerekir (`Source/Android`, AppLovin-MAX-Godot deposu).
- AppLovin'in canlı reklam için uygulamanın Play'de yayında olmasını isteyip istemediği doğrulanmadı.
- AB için ayrı bir onay platformu (TCF CMP) yok; AEA'da varsayılan kişiselleştirilmemiş reklam + açık rıza düğmesi.
