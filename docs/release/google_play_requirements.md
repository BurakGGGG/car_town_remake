# Google Play Gereksinimleri (2026-10-02)

Kaynak: resmi Google sayfaları, bu oturumda çekildi.
- https://support.google.com/googleplay/android-developer/answer/11926878 (Target API)
- https://developer.android.com/google/play/requirements/target-sdk
- https://support.google.com/googleplay/android-developer/answer/13327111 (hesap silme)
- https://support.google.com/googleplay/android-developer/answer/9859152 (boyut / mağaza metin sınırları)

| Gereksinim | Resmi kural | AUTO YARD durumu |
|---|---|---|
| Hedef API | 31 Ağu 2026'dan itibaren yeni uygulama ve güncellemeler **API 36 (Android 16)** hedeflemeli (uzatma talebi: 1 Kasım 2026'ya kadar) | targetSdk **36** (manifestten doğrulandı) ✅ |
| 64-bit | arm64 desteği gerekli | yalnızca `arm64-v8a` ✅ |
| Biçim | Yeni uygulamalar **AAB** yükler | AAB üretildi ✅ |
| Boyut | Cihaz başına sıkıştırılmış indirme ≤ 200 MB (AAB) | AAB 128.9 MB ✅ (cihaz başına indirme ölçülmedi) |
| İmza | Play App Signing; yükleme anahtarıyla imzalı AAB | ❌ gerçek yükleme anahtarı yok, AAB debug anahtarıyla imzalı |
| Paket kimliği | Kalıcıdır, sonradan değişmez | `com.cartownBurak.app` — karar gerekli (P1) |
| versionCode / Name | her yüklemede artan kod | 1 / 1.0.0 ✅ |
| Hesap silme | Hesap oluşturulabiliyorsa uygulama içi silme yolu **+ web linki + Data safety beyanı** | uygulama içi: var (PROFİL → HESABIMI SİL, test 53 kontrol); web sayfası: ayrı repoda (autoyardwebsite.vercel.app) var; **gerçek telefonda Google yeniden doğrulama denenmedi**; Data safety formu konsolda doldurulmalı |
| Mağaza metni | Ad ≤ 30, kısa açıklama ≤ 80, tam açıklama ≤ 4000 karakter | metinler yazılmamış/doğrulanmamış (ÖLÇÜLMEDİ) |
| Kişisel geliştirici hesabı test şartı (kapalı test, tester sayısı/gün) | Resmi sayfadan **doğrulanamadı** (çekilen sayfa bu konuyu içermiyordu) | Play Console → Test ve yayınlama sayfasından kontrol edilmeli |
| Gizlilik politikası | URL zorunlu | site repo'sunda /gizlilik var; konsola girilmeli |
| İçerik derecelendirme, hedef kitle, reklam beyanı (reklam yok), uygulama erişimi (Google girişi opsiyonel; misafir oynanır) | Konsol formları | yapılmadı — konsol işi |
| Mağaza varlıkları | 512×512 ikon, 1024×500 öne çıkan grafik, ekran görüntüleri | ikon: ✅ (`assets/branding/icon_512.png`); öne çıkan grafik taslağı `~/Projects/ct_shots/store/` içinde, **bu denetimde incelenmedi**; ekran görüntüleri doğrulanmadı |

Resmi sayfa ikon/öne çıkan grafik/ekran görüntüsü ölçülerini içermediği için bu üç ölçü doğrulanmadı; Play Console yükleme ekranı kabul ettiği ölçüyü gösterir.
