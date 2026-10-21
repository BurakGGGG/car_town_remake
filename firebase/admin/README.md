# AUTO YARD yönetim paneli (yerel)

Bu bilgisayarda tarayıcıda açılan küçük bir panel. İnternete açık bir yönetici kapısı yoktur: oyun ve site depoları
herkese açık olduğu için yönetim yalnızca buradan yapılır (karar 2026-10-21).

| Sekme | Ne yapar | Firestore |
|---|---|---|
| Özet | oyuncu sayısı, son derleme, sürüm dağılımı, son işlemler | `players`, `admin_log` |
| Sürüm ve bakım | zorunlu güncelleme (`min_code`), "yeni sürüm var" (`latest_code`), bakım modu, oyun içi duyuru | `config/app` |
| Hediye gönder | tek oyuncuya (arkadaş kodu / e-posta / UID) ya da herkese ₺, elmas, kasa, dekor eşyası | `users/{uid}/mail/{id}` |
| Duyuru bildirimi | bildirimleri açmış herkese (misafir dahil) telefon bildirimi; önce kendine deneme | FCM konusu `news_<dil>` |
| Oyuncu | hesabın özeti, para / elmas / seviye, bekleyen posta (silme), kaydın tamamı; **yasakla / kaldır**, adı sıfırla, fotoğrafı kaldır, not | `moderation`, `admin_notes` |
| Şikâyetler | oyuncu şikâyetleri hedefe göre (fotoğraf, ad, sayı); adı sıfırla / fotoğrafı kaldır / kapat | `reports` |
| Kuponlar | kupon kodu oluştur (ödül, kullanım sınırı, bitiş), aç / kapat, kullanım sayısı | `promo` |
| İstatistik | hesaplı oyuncu, aktif 1 / 7 / 30 gün, yeni hesap, bildirim oranı, son 30 gün grafiği, dil / seviye dağılımı | `stats_daily`, `players` |

Hediye ve duyuruda **Filtreli** hedef: seviye, son oynama, kaç gündür oynamadığı ("geri dön hediyesi"), sürüm kodu,
dil. Sürüm ve bakım sekmesinde **canlı etkinlik** (para / XP çarpanı, başlangıç / bitiş, tabela başlığı). Oyuncu
sekmesinde **Destek**: bakiye düzeltme (eksi dahil) ve kayıt geçmişinden geri yükleme.

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
npm run e2e     # paneli emülatörde ("demo-" projesi) açıp HTTP ile sınar: güvenlik kapıları, ayar, posta, duyuru
```

## Dikkat

- `min_code`'u **Play'deki son sürümün kodundan büyük** yaparsan mağazadaki sürüm de oynayamaz. Panel uyarır.
  Sıra: yeni sürüm Play'de yayına girer → sonra `min_code` yükseltilir.
- "Herkese" hediye her hesaba ayrı belge yazar (oyuncu sayısı kadar yazma) ve her birine bildirim gider.
- Bakım modu açıkken kimse oynayamaz (geliştirme sürümü hariç). İşin bitince kapatmayı unutma.
- Yasak açık garajı ve fotoğrafı hemen gizler; sosyal yasakta oyuncu oynamaya devam eder, tam yasakta oturumu kapanır.
  Oyuncu yasağı sebep ve bitişiyle görür (en geç 30 dakikada, oyunu açınca hemen).
- Biçimler oyunla aynıdır: `gameplay/backend/app_config.gd`, `gameplay/backend/mail_service.gd`,
  `gameplay/social/push_service.gd`. Ayrıntı: `docs/BACKEND.md`.
