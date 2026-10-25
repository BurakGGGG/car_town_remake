# AUTO YARD yönetim paneli (yerel)

Bu bilgisayarda tarayıcıda açılan küçük bir panel. İnternete açık bir yönetici kapısı yoktur: oyun ve site depoları
herkese açık olduğu için yönetim yalnızca buradan yapılır (karar 2026-10-21).

| Sekme | Ne yapar | Firestore |
|---|---|---|
| Özet | oyuncu sayısı, son derleme, sürüm dağılımı, son işlemler | `players`, `admin_log` |
| Haberler | oyunun HABERLER kutusu: haber yaz / düzenle / sil, kapak resmi, düğme, zamanlı yayın, hedef, bildirim; oyunun okuduğu yayın | `news/{id}`, `config/news`, Storage `news/` |
| Sürüm ve bakım | zorunlu güncelleme (`min_code`), "yeni sürüm var" (`latest_code`), bakım modu, eski sürümler için duyuru penceresi | `config/app` |
| Hediye gönder | tek oyuncuya (arkadaş kodu / e-posta / UID) ya da herkese ₺, elmas, kasa, dekor eşyası; isteğe bağlı resim + düğme | `users/{uid}/mail/{id}` |
| Duyuru bildirimi | bildirimleri açmış herkese (misafir dahil) telefon bildirimi; önce kendine deneme | FCM konusu `news_<dil>` |
| Oyuncu | hesabın özeti, para / elmas / seviye, bekleyen posta (silme), kaydın tamamı; **yasakla / kaldır**, adı sıfırla, fotoğrafı kaldır, not | `moderation`, `admin_notes` |
| Şikâyetler | oyuncu şikâyetleri hedefe göre (fotoğraf, ad, sayı); adı sıfırla / fotoğrafı kaldır / kapat | `reports` |
| Kuponlar | kupon kodu oluştur (ödül, kullanım sınırı, bitiş), aç / kapat, kullanım sayısı | `promo` |
| Lider tablosu | haftalık drag tablosu: hafta / sınıf / ülke seçip ilk 100 (sınıra yakın süre işaretli), kayıt **silme** (özeti `lbRun` düzeltir), haftalık ödül kademeleri (elmas + kasa) | `lb_runs`, `lb`, `config/app.leaderboard` |
| İstatistik | hesaplı oyuncu, aktif 1 / 7 / 30 gün, yeni hesap, bildirim oranı, son 30 gün grafiği, dil / seviye dağılımı; **yarış öğrenmesi** tablosu (son iki yarış × kolay / dengeli / zor → yarıştan sonra kalış oranı) ve ayarı (kapat, kalış penceresi, genel tablo ağırlığı) | `stats_daily`, `players`, `config/race_learning`, `race_learning_daily` |

Hediye ve duyuruda **Filtreli** hedef: seviye, son oynama, kaç gündür oynamadığı ("geri dön hediyesi"), sürüm kodu,
dil. **Etkinlik** sekmesinde **etkinlik takvimi** (en çok 12 etkinlik, modüller, etkinlik aracı, başlayınca bildirim;
`config/app.events` + eski sürümler için `config/app.event` aynası; docs/CANLI_ETKINLIK.md "Takvim ve etkinlik aracı"). Oyuncu
sekmesinde **Destek**: bakiye düzeltme (eksi dahil) ve kayıt geçmişinden geri yükleme.

## Haberler (2026-10-25)

Haberler `news/{id}` koleksiyonunda durur ve **yalnız sunucunundur** (istemci okuyamaz / yazamaz). Oyun tek bir belgeyi okur:
**`config/news` = `{items, at}`** (oturumsuz, misafir de; oyuncu başına tek okuma). `items` = bitmemiş haberlerin (başlamamışlar
dahil, oyun `start`'ı kendisi süzer) herkese açık alanları `{id, kind, title, text, image, action, start, end, pinned, code, target,
at}`, `at`'e göre yeniden eskiye, **en çok 40** (SABİT'ler sınırda önce kalır). Panel her kaydet / sil / en üste taşı işleminde
yayını haberle **aynı işlemde** yazar; **Yayını yenile** düğmesi elle yeniden kurar. Bitişi geçen haber `newsPushScheduled`
(10 dakikada bir `config/news`'i okur, bitmiş haber varsa yayını koleksiyondan yeniden kurar) ile en geç 10 dakikada düşer.
Yayın kurucusu tektir: `functions/news_feed.js` `buildNewsFeed` (panel `lib.mjs` üzerinden aynısını kullanır).

Haber alanları: `kind` (GÜNCELLEME / ETKİNLİK /
DUYURU), `title` ≤ 60 ve `text` ≤ 600 karakter (5 dil, Türkçe zorunlu; boş dil oyunda en → tr), `image` (boş = türe göre hazır
kapak; yalnız `firebasestorage.googleapis.com`, `storage.googleapis.com`, `autoyard.online`), `action {kind, url}` (MARKET,
ETKİNLİK PANOSU, GÖREVLER, SHOWROOM, ARKADAŞLAR, DAVET, Play Store, https bağlantısı), `start` / `end` (0 = hemen / süresiz),
`pinned`, `code` (yalnız GÜNCELLEME: notların sürüm kodu, zorunlu), `target {langs, min_level, max_level, min_code, max_code}`,
`notify`, `pushed_at`, `at` (oyunda görünen zaman; düzenlemede korunur, **En üste taşı** şimdi yapar).

- **Bildirim:** `notify` işaretliyse haber görünür olunca dil konularına (`news_<dil>`, seçili dillere) **bir kez** gider —
  `newsPush` (kaydedince) ve `newsPushScheduled` (10 dakikada bir, zamanlı haber). Başlık = haber başlığı, metin = haberin ilk
  ~120 karakteri. Gönderilmiş bildirim düzenlemeyle yeniden gitmez. Seviye / sürüm hedefli haberde bildirim seçilemez (konu
  bildirimi bu hedefleri süzemez).
- **Kapak yükleme:** JPEG / PNG / WebP, en çok 1,5 MB (tür dosyanın baytlarından sınanır) → Storage `news/…`, indirme anahtarlı
  adres. Kova `car-town-remake.firebasestorage.app` (yoksa `.appspot.com`; `AUTOYARD_BUCKET` ile değiştirilebilir). Storage
  açık değilse panel "Firebase Storage açık değil" der; o zaman **Resim adresi** ile autoyard.online'dan resim verilebilir.
- **Tek oyuncuya haber:** Hediye gönder › Tek oyuncu, ödülsüz mesaj (resim ve düğme aynı biçimde).
- **Sürüm ve bakım › duyuru penceresi** 1.1.0 ve öncesi içindir (açılışta pencere); yeni sürümler aynı duyuruyu HABERLER'de de
  gösterir. Yeni duyuruları Haberler sekmesinden yaz.

## Kurulum (bir kez)

1. **Hizmet hesabı anahtarı:** Firebase konsolu → **car-town-remake** → Proje ayarları → Hizmet hesapları →
   **Yeni özel anahtar oluştur**. İnen dosyayı `firebase/admin/service-account.json` olarak kaydet.
   - Dosya `.gitignore`'da; panel dosya git'te izleniyorsa ya da başka bir projeye aitse **açılmaz**.
   - Panel bilerek varsayılan Google kimliğine (`gcloud` ADC) düşmez: bu makinede o kimlik başka bir projeye bağlı.
   - Anahtar kaybolursa / sızarsa: konsol → Google Cloud → IAM → Hizmet hesapları → anahtarı sil.
2. `cd firebase/admin && npm install`

## Açmak

```
cd firebase/admin && npm start
```

Terminaldeki `http://127.0.0.1:4400/#k=…` bağlantısını aç. Anahtar her açılışta değişir; Ctrl+C kapatır.

## Testler (canlı projeye dokunmaz)

```
npm test        # doğrulama mantığı (internetsiz)
npm run e2e     # paneli emülatörde ("demo-" projesi) açıp HTTP ile sınar: güvenlik kapıları, ayar, posta, duyuru, haberler
                # (emülatörde Storage'a gidilmez: kova yalnız _e2e_buckets/{ad} belgesi varsa "açık" sayılır)
```

## Dikkat

- Haberler: `newsPush` + `newsPushScheduled` fonksiyonları deploy edilmiş olmalı; yoksa bildirim gitmez ve biten haber yayından
  ancak bir sonraki panel kaydında / **Yayını yenile**'de düşer (oyun `end`'i kendisi de süzer). `config/news`'i okuma kuralı
  (`config/{belge}` get) zaten yayında; `news` koleksiyonu istemciye kapalı.
- `min_code`'u **Play'deki son sürümün kodundan büyük** yaparsan mağazadaki sürüm de oynayamaz. Panel uyarır.
  Sıra: yeni sürüm Play'de yayına girer → sonra `min_code` yükseltilir.
- "Herkese" hediye her hesaba ayrı belge yazar (oyuncu sayısı kadar yazma) ve her birine bildirim gider.
- Bakım modu açıkken kimse oynayamaz (geliştirme sürümü hariç). İşin bitince kapatmayı unutma.
- Yasak açık garajı ve fotoğrafı hemen gizler; sosyal yasakta oyuncu oynamaya devam eder, tam yasakta oturumu kapanır.
  Oyuncu yasağı sebep ve bitişiyle görür (en geç 30 dakikada, oyunu açınca hemen).
- Biçimler oyunla aynıdır: `gameplay/backend/app_config.gd`, `gameplay/backend/mail_service.gd`,
  `gameplay/social/push_service.gd`. Ayrıntı: `docs/BACKEND.md`.

**Araç hediyesi (2026-10-25):** Posta formunda "+ araç ekle" — edinilebilir araçlardan, her biri bir adet (`cars: {araç: 1}`). Oyuncuda zaten varsa oyun aracın satış değerini ₺ olarak verir.
