# AdMob Kurulumu ve Play Uyum Adımları (v2)

Durum (2026-10-03): kod hazır, **test reklamlarıyla** telefonda doğrulandı (yarış bonusu ✅). Gerçek reklam için aşağıdaki konsol işleri gerekir.
Gerçek kimlikler gelene kadar release derleme reklamı **kapalı** tutar (`AdConfig.REAL_REWARDED` boşsa).

## 1. AdMob konsolu (sen)

1. admob.google.com → **Uygulamalar → Uygulama ekle**
   - Platform: Android · "Uygulama Google Play veya başka bir mağazada listeleniyor mu?" → **Hayır (henüz değil)** de (uygulama yayında olunca mağaza kaydına bağlarsın).
   - Ad: **AUTO YARD** · Kullanıcı metriklerini aç (önerilir).
   - Sonunda **Uygulama Kimliği** verilir: `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY` (ortasında `~` var).
2. Uygulamanın içinde **Reklam birimi ekle → Ödüllü**
   - Ad: `odullu_yaris_ve_tamir` · Ödül miktarı/türü: 1 / `odul` (oyun kendi ödülünü verir, bu değer kullanılmaz).
   - **Reklam Birimi Kimliği** verilir: `ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ` (ortasında `/` var).
3. **Gizlilik ve mesajlaşma → Avrupa düzenlemeleri → Mesaj oluştur**: uygulamayı seç, varsayılan mesajı yayınla (AEA/BK/İsviçre onay penceresi; kodda UMP akışı hazır).
4. **Ödemeler**: vergi bilgileri + ödeme profili + adres PIN'i (eşiğe ulaşınca ödeme için gerekir).
5. Eski uygulamanın onaylanmama nedeni için: Uygulamalar sayfası durum sütunu ve **Politika merkezi**'ni kontrol et.

## 2. Kimlikleri projeye koyma (bana ver / ben yaparım)

- Uygulama Kimliği → `project.godot` → `[admob] general/android/app_id="ca-app-pub-…~…"` (Proje Ayarları → AdMob).
- Reklam Birimi Kimliği → `ads/ad_config.gd` → `REAL_REWARDED`.
- Debug derlemeler **her zaman test kimliği** kullanır (kodla zorunlu), release gerçek kimlik. Test cihazını kayıt etmek şart değil.
- Kimlikler gizli bilgi değildir (APK içinde görünür), repoya yazılabilir; **AdMob hesap parolası/e-postası yazılmaz**.

## 3. Play Console (sen) — uygulama v2'yi yüklemeden önce

| Form | Cevap |
|---|---|
| Uygulama içeriği → **Reklamlar** | **Evet, uygulamada reklam var** |
| **Reklam kimliği (Advertising ID)** beyanı | Kullanıyor → amaç: **Reklam veya pazarlama** (manifestte `AD_ID` izni otomatik var) |
| **Data safety** → toplanan veri | Cihaz veya diğer kimlikler (reklam kimliği) → **Google ile paylaşılıyor**, amaç: **Reklamcılık veya pazarlama**; uygulama etkileşimleri/tanılama (AdMob SDK) aynı şekilde |
| Data safety → şifreleme / silme | Mevcut yanıtlar (Google girişi, bulut kaydı, hesap silme) aynen kalır |
| **Hedef kitle** | Yalnızca 13+ yaş grupları (çocuk yaş grubu işaretlenmemeli) |
| **İçerik derecelendirme** anketi | Reklamlar sorusu → evet |
| Mağaza açıklaması | "Reklam içerir" etiketi konsolda otomatik çıkar; metne ayrıca yazmak şart değil |

Not: `FOREGROUND_SERVICE` ve `WAKE_LOCK` izinleri reklam SDK'sından geliyor (debug manifestte görüldü). Release AAB'de izin listesini
yeniden doğrulayıp Play'in "ön plan hizmeti" beyanı isteyip istemediğine bakacağım.

## 4. Web sitesi (hazır, YAYINLANMADI)

`~/Projects/auto_yard_website` deposunda `reklam-guncelleme` dalı: gizlilik politikası (Reklamlar bölümü, paylaşım listesi, hukuki sebepler tablosu),
SSS "Oyunda reklam var mı?", llms.txt metni ve **androidPackage `com.autoyard.app`** düzeltmesi (eski `com.cartownBurak.app` yazıyordu).
`npm run build` + `check` geçti. **Dalı birleştirip push etme zamanı: reklamlı sürüm Play'de yayına çıkmadan hemen önce** (sitede "reklam göstermez" yazarken
reklam çıkarsa ya da tersi, yanıltıcı olur). Paket adı düzeltmesini ayırıp hemen yayınlamak istersen söyle.

**KVKK uyarısı:** politika metnini hukuki olarak ben doğrulayamam; reklam kimliği için "açık rıza" ifadesi ve Türkiye'deki aydınlatma gereklilikleri
bir hukukçuya gösterilmeli.

## 5. app-ads.txt

Mağaza kaydındaki **geliştirici web sitesi** alanına `https://autoyardwebsite.vercel.app` girilmeli. AdMob → Uygulamalar → **app-ads.txt** sayfasında
verilen satır (`google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`) sitenin `src/static/app-ads.txt` dosyasına yazılacak
(yayın ID'yi aldıktan sonra; `vercel.app` alt alan adının AdMob tarafından kök alan adı olarak taranıp taranmadığı konsolda doğrulanmalı — ÖNCEDEN DOĞRULANMADI).

## 6. Mağaza metni

`~/Projects/ct_shots/store/final/magaza_metinleri.md`: "Arabalarını istediğin renge boya" cümlesi kaldırıldı (boya özelliği kapalı).
