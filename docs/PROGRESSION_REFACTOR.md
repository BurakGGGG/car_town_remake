# İLERLEME REFACTOR'Ü — uygulama raporu

Tarih: 2026-09-26. Kaynak tasarım: [GDD.md](GDD.md) (bölüm 0.1 "kapasite tavanı" bulgusu).
Bu belge **yapılan işi ve ölçülen sonuçları** tutar; tasarım gerekçeleri GDD'dedir.

---

## 1. SORUN (ölçümle)

GDD'nin 0.1 bölümünde bulunan tavan, gerçek oyunda 20 dakikalık koşularla doğrulandı:

| Yapılandırma | tamir/dk | ₺/dk | bay doluluğu | kuyruk |
|---|---|---|---|---|
| 1 bay / garaj 1 | 2,40 | 368 | 0,38 | 0,00 |
| 3 bay / garaj 3 | 1,90 | 276 | 0,29 | 0,00 |

Üç tamir alanı (o günkü fiyatlarla 28.000 ₺) geliri **artırmıyordu, düşürüyordu**: sistem tamamen
müşteri arzına bağlıydı, garaj büyümesi arzı hiç değiştirmiyordu. Kuyruk hep boş, bay doluluğu %30.

## 2. DÖRT EKSEN

Kullanıcının şartı: dört eksen **ayrı** kalacak, `repair_capacity` fiziksel genişlemenin yerine
geçmeyecek.

| Eksen | Nerede | Ne yapar |
|---|---|---|
| Oyuncu seviyesi | `PlayerProgress` | içerik açar (arıza türleri, showroom araçları), para ödülü verir |
| Garaj seviyesi | `GarageUpgradeManager.garage_level()` (1-4, 12k/30k/60k) | zemini fiziksel büyütür, **müşteri arzını** büyütür, tamir alanlarını ortaya çıkarır |
| Tamir alanı | `RepairBayManager` (1-3, 0/5k/12k) | aynı anda kaç iş yapılabileceği |
| Garaj değeri | `GarageValue` (türetilmiş, 10 rütbe) | prestij; pahalı araçların kilidi |

Kayıt şeması bu ayrımı yansıtır: `garage_upgrades.garage_level` ve `repair_bays.unlocked` ayrı
alanlardır (v7).

## 3. ÇÖZÜM — garaj seviyesi arzı büyütür

`RepairManager.SUPPLY` tablosu (kod içinde, tek yer):

| Garaj | müşteri aralığı | bekleyen sınırı | bekleme noktası | ödül çarpanı | trafik |
|---|---|---|---|---|---|
| 1 | ×1,00 (6-14 sn) | 2 | 2 | ×1,00 | 4 |
| 2 | ×0,80 | 2 | 2 | ×1,15 | 6 |
| 3 | ×0,62 | 2 | 2 | ×1,30 | 8 |
| 4 | ×0,48 | 2 | 2 | ×1,45 | 10 (QA'de 8'den yükseltildi) |

**2026-09-27 (kullanıcı kararı):** bekleyen sınırı ve bekleme noktası artık HER seviyede 2.
Önceden garaj büyüdükçe 3-5'e çıkıyordu; kaldırımda 3-4 araç birikmesi dağınık görünüyordu.
Garaj seviyesinin arz katkısı yalnızca müşteri sıklığı, müşteri değeri ve trafik yoğunluğu
üzerinden kalıyor; genişletme plakası artık "+1 BEKLEME NOKTASI" vaat etmiyor
(`progression_test` bunu doğruluyor).

Ek olarak `SPOT_AHEAD_MAX` 1,8 → 3,2 m: aracın bir bekleme noktasını "görebildiği" pencere dardı,
sayaç dolduğu halde aday bulunamıyordu (ölçülen yakalama oranı %42).

## 4. İŞ SÜRELERİ — iki kademe

| İş | Süre | Ödül | XP | Oyuncu sv. | Garaj sv. | Alan |
|---|---|---|---|---|---|---|
| LASTİK | 6 sn | 100 ₺ | 7 | 1 | 1 | 1 |
| FREN | 8 sn | 140 ₺ | 9 | 1 | 1 | 1 |
| MOTOR | 10 sn | 150 ₺ | 10 | 1 | 1 | 1 |
| KAPORTA | 12 sn | 200 ₺ | 14 | 1 | 1 | 1 |
| BOYA İŞİ | 90 sn | 600 ₺ | 45 | 5 | 2 | 2 |
| DÖŞEME | 180 sn | 1.150 ₺ | 85 | 8 | 2 | 2 |
| FREN REVİZYONU | 300 sn | 1.800 ₺ | 140 | 12 | 3 | 3 |

`min_bays` alanı ölçümden doğdu: tek alanı olan oyuncu 300 sn'lik işi alırsa 5 dakika boyunca
yapacak bir şeyi kalmıyor, almazsa bekleme noktası kalıcı tıkanıyor (müşterinin sabır sayacı yok).

## 5. GARAJ DEĞERİ (10 rütbe)

`gameplay/garage_value.gd` — **türetilmiş**, kayda yazılmaz, node değildir:
değer = araçların katalog fiyatı + geliştirmelere ödenen + alanlara ödenen + boyalı araç × 2.000 ₺.

Rütbeler: 0 / 110k / 150k / 200k / 260k / 320k / 380k / 440k / 550k / 700k ₺ →
DERME ÇATMA · VASAT · MÜTEVAZI · GÖZE ÇARPAN · İYİ · ETKİLEYİCİ · SAYGIN · HARİKA · GÖZ KORKUTAN ·
EFSANE GARAJ. Bugünkü içerikle ulaşılabilir tavan 8. rütbe; 9-10 ileriki dekor/ustalık içeriği için.

## 6. İŞ USTALIĞI

`gameplay/job_mastery.gd` — arıza başına tamamlanan iş sayısı; 10/50/150/400/1000'de yıldız,
yıldız başına tek seferlik 1.000/3.000/8.000/20.000/50.000 ₺ ve kalıcı **+%10 XP** çarpanı.
Kayıtta `job_mastery: {arıza_id: sayı}` (v7).

## 7. ARAÇ İLERLEMESİ

`vehicles/cars.json` alanları `class`, `min_level`, `min_garage_rank`:

| Araç | Fiyat | Sınıf | Seviye | Rütbe |
|---|---|---|---|---|
| Tofaş Şahin | 15.000 | D | 1 | 1 |
| Renault Toros | 20.000 | D | 3 | 1 |
| Hyundai Era | 30.000 | C | 6 | 1 |
| Hyundai Getz | 35.000 | C | 8 | 2 |
| VW Passat B5.5 | 50.000 | B | 12 | 3 |
| Renault Fluence | 60.000 | B | 15 | 4 |
| BMW E46 | 85.000 | A | — | — (ücretsiz başlangıç) |

Satış: `VehicleOwnership.sell_vehicle()`, katalog fiyatının **%40**'ı, son araç satılamaz.

## 8. ÖLÇÜM 1 — ekonomi modeli (102.000 müşteri döngüsü)

Kesikli olay modeli (`model_sim.gd`), oyunun gerçek sabitleriyle, yapılandırma başına
**6 koşu × 1.000 müşteri = 6.000 döngü**, 17 yapılandırma. Yakalama oranı gerçek koşulardan
kalibre edildi (garaj 1/2/3 → 0,42 / 0,49 / 0,54).

**Doğrulama** (model ↔ gerçek 20 dk'lık oyun koşusu):

| Yapılandırma | model tamir/dk | gerçek tamir/dk | model ₺/dk | gerçek ₺/dk |
|---|---|---|---|---|
| garaj 1 / 1 alan | 2,52 | 2,50 | 372 | 369 |
| garaj 2 / 2 alan | 3,70 | 3,70 | 626 | 628 |
| garaj 3 / 3 alan | 5,25 | 5,20 | 1.008 | 997 |

**Erken oyun** (yalnızca kısa işler): alan sayısı geliri DEĞİŞTİRMEZ (2,52 / 2,51 / 2,53 tamir/dk) —
kısa işler bir alanı doyurmaz. Geliri büyüten şey garaj seviyesidir (372 → 626 → 1.008 → 1.441 ₺/dk).

**Geç oyun** (orta işler de geliyor, oyuncu sv. 12+):

| Garaj | 1 alan | 2 alan | 3 alan |
|---|---|---|---|
| 2 | 624 ₺/dk | 991 | 1.258 |
| 3 | 997 | 1.234 | 1.666 |
| 4 | 1.414 | 1.421 | 1.877 |

Alanlar ancak **uzun işler geldiğinde** para kazandırır; bu yüzden uzun işler garaj seviyesine ve
alan sayısına bağlandı. Tamir hızı 5. seviyede geç oyun geliri 1.666 → 2.472 ₺/dk (+%48).

## 9. ÖLÇÜM 2 — 120 dakikalık gerçek oyun koşusu

Gerçek `Main.tscn`, 6× hızlandırma, otomatik oyuncu (bekleyeni al, biteni topla, parayı
garaj → alan → hız → en ucuz açık araç sırasıyla harca). Toplam **385 tamir**, 388 müşteri.

| Dakika | Tamir | Tamir geliri | ₺/dk | Seviye | Garaj | Alan | Araç | Değer | Rütbe | ★ | Alan doluluğu | Kuyruk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 0-10 | 30 | 4.850 | 485 | 3 | 1 | 1 | 1 | 96.500 | 1 | 2 | 0,35 | 0,00 |
| 10-20 | 32 | 4.700 | 470 | 5 | 1 | 1 | 1 | 96.500 | 1 | 4 | 0,29 | 0,00 |
| 20-30 | 36 | 5.966 | 597 | 6 | 2 | 2 | 1 | 113.500 | 2 | 4 | 0,42 | 0,02 |
| 30-45 | 47 | 12.563 | 838 | 8 | 2 | 2 | 2 | 128.500 | 2 | 4 | 0,75 | 0,02 |
| 45-60 | 43 | 14.877 | 992 | 10 | 2 | 2 | 3 | 148.500 | 2 | 5 | 1,01 | 0,23 |
| 60-90 | 100 | 46.175 | 1.539 | 13 | 3 | 3 | 4 | 220.500 | 4 | 10 | 1,64 | 0,45 |
| 90-120 | 97 | 65.000 | 2.167 | 15 | 3 | 3 | 5 | 255.500 | 4 | 11 | 2,41 | 0,71 |

**Kilometre taşları:** TAMİR HIZI 2-5 → 0-9 dk · GARAJ SEVİYE 2 → 23,0 dk · TAMİR ALANI 2 → 28,4 dk ·
Şahin → 40,7 dk · Toros → 56,2 dk · GARAJ SEVİYE 3 → 75,4 dk · TAMİR ALANI 3 → 77,6 dk ·
Era → 88,3 dk · Getz → 101,6 dk. Yani ilk iki saatte ortalama **13 dakikada bir** somut ilerleme.

## 10. ÖLÇÜM 3 — performans (1152×648, vsync kapalı)

| Durum | FPS ort / min | Çizim | VRAM | Trafik |
|---|---|---|---|---|
| Dünya, garaj 1 | 919 / 809 | 209 | 83,5 MB | 4 |
| Dünya, garaj 2 | 569 / 542 | 457 | 85,5 MB | 6 |
| Dünya, garaj 3 | 536 / 500 | 461 | 85,5 MB | 8 |
| Dünya, garaj 4 | 580 / 456 | 384 | 94,3 MB | 8 |
| Garaj ekranı (açılış 8 ms) | 188 / 185 | 947 | 112,4 MB | 8 |
| Rütbe merdiveni (açılış 51 ms) | 170 / 164 | 1.097 | 112,9 MB | 8 |

Trafik 4 → 8'e çıkınca dünya 919 → 536 FPS'e iner; hedefin (60) hâlâ 8 katı, çizim çağrısı 700'ün
altında, VRAM 120 MB'ın altında.

## 11. TESTLER

| Paket | Sonuç |
|---|---|
| `ui_test` (garaj değeri plakası, rütbe merdiveni, satış, araç kilitleri, değer kalemleri) | 33/33 |
| `save_test` (v6→v7, v5→v7 göçü, tam tur, yeni oyun) | 27/27 |
| `quest_test` (görev zinciri + yeni eksenler) | tamamı |
| `paint_test` | tamamı |
| `cloud_test` | tamamı |

## 12. BİLİNEN RİSKLER

1. **Reddedilen uzun iş bekleme noktasını kalıcı tıkar.** Müşterinin sabır sayacı yok; oyuncu
   300 sn'lik işi almazsa o nokta boşalmaz. `min_bays` en kötü durumu (tek alan) engelliyor ama
   "müşteriyi gönder" aksiyonu ileride gerekebilir.
2. ~~Geç oyunda müşterilerin %45-59'u geri çevriliyor.~~ **DÜZELTME (QA, bkz. [QA_REVIEW.md](QA_REVIEW.md)):
   bu rakam modelin tamir hızı 1 varsayımından ve trafik havuzu geri beslemesini görmemesinden
   geliyordu. Gerçek oyunda ölçülen "kuyruk dolu" süresi %0,0'dır (G2+2 ve G3+3, 10 dk); sistem
   kuyruk değil MÜŞTERİ ARZI sınırlıdır.**
3. **9. ve 10. rütbe bugünkü içerikle ulaşılamaz.** Ölçülen tavan 439.500 ₺'dir; 8. rütbe eşiği
   440.000 iken tavan ona 500 ₺ yetişemiyordu — QA'de eşik 430.000'e çekildi, 9-10 bilinçli
   olarak gelecek içeriğe ayrıldı.
4. Erken oyunda 2. tamir alanı, oyuncu 5. seviyeye gelip BOYA İŞİ açılana kadar gelir artırmaz;
   ölçülen koşuda alan 28. dakikada, ilk uzun iş 23. dakikada geldiği için sıralama doğru çıktı,
   ama oyuncu farklı bir sırada ilerlerse alanı "boşa almış" hissedebilir.
