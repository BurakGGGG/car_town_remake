# PERFORMANS v2 — drag yarışı gerçek araç verisiyle (2026-10-11)

Kaynak: kullanıcının 26 araçlık tablosu (motor, 0-100, son hız, çekiş). Ölçüm araçları:
`qa/performance_report.gd` (araç başına simülasyon değerleri) ve `qa/matchup_report.gd` (rakip havuzuna karşı
kazanma oranı).

## Ne değişti

**Veri — `vehicles/cars.json`:** her araca `performance` bloğu (variant, engine, hp, zero_100, top_speed,
drivetrain FWD/RWD/AWD). `CarCatalog.SCHEMA`'ya `Kind.PERFORMANCE` olarak eklendi (bilinmeyen alan / geçersiz
çekiş uyarı verir). `race` bloğunda:
- `top_speed` = gerçek son hız (km/sa). GENEL puandaki hız tavanı 160 → 340 (488 Pista).
- `acceleration` = 0-100'den doğrusal: 2,5 sn = 100, 16 sn = 0.
- `reaction` ve `grip` tabloda olmadığı için değişmedi.

İki "Önden / 4 çeker" satırında ilk değer alındı: **Volvo S60 = FWD, Mercedes S400 = RWD**.

**Fizik — `DragRaceSim.EngineSpec.derive`:**
1. **Çekiş payı** (`DRIVE_SHARE`): FWD 0,55 · RWD 0,68 · AWD 0,95. Kalkışta ağırlık arkaya kaydığı için
   önden çekişli kaybeder, arkadan çekişli kazanır. Eskiden bütün araçlar için 0,62'ydi.
2. **Lastik tutuşu** aracın gerçek 0-100'ünü yapabilecek kadar. Ortalama ivmenin %45 fazlası çekişle
   karşılanabilir. %15'te süper sporlar 300 m'nin 6 sn'sini patinajla geçiriyordu, %80'de hiç patinaj
   kalmıyordu. Şimdi süper sporlar kalkışta ~1 sn patinaj yapıyor.
3. **Tork kalibrasyonu:** kusursuz sürüşte ölçülen 0-100 tablodaki süreye oturana kadar tork ölçeklenir
   (`calibrate`). Sonuç: 26 aracın hepsi tablodan en fazla ±0,05 sn sapıyor (ekranda PACE 1,25 ile kısalmış
   haliyle).
4. **Yarış vites kutusu:** gerçek son hıza (340 × PACE) göre kurulan kutuyla 300 m'de son viteslere hiç
   geçilmiyordu (E46 5 vitesin 4'ünü kullanıyordu). Vites atmak oyunun kendisi olduğu için son vitesin tepe
   güç devri 300 m bitiş hızının 1,08 katına denk getirildi (`RACE_GEAR_HEADROOM`). Gerçek son hız yalnızca
   tavan olarak kalıyor; garaj çubuğunda ve GENEL puanda gerçek değer görünüyor.

**Ekran — `DragRaceScreen`:** aradaki fark artık GERÇEK metre farkı. Eskiden `tanh` ile 1,15 birime kırpılıyor,
güçlü araç ne kadar açarsa açsın ekranda hep aynı boşluk kalıyordu. Kamera fark 1,6 birimden küçükken iki
aracın ortasına bakıyor, büyüyünce oyuncuya kilitleniyor ve önde/arkada kalan araç kadrajdan çıkıp gidiyor.
Üstteki ilerleme çubuğu rakibin yerini göstermeye devam ediyor. Ölçüm: E46'ya karşı 488 Pista ve Corsa'ya
karşı Camaro 2,5. saniyede kadrajdan çıkıyor.

## Araç tablosu (kusursuz sürüş, simülasyon)

| Araç | Sınıf | Çekiş | Gerçek 0-100 | Sim. 0-100* | 300 m | GENEL |
|---|---|---|---|---|---|---|
| Lamborghini Huracán | S | AWD | 2,9 | 2,88 | 7,28 | 945 |
| Ferrari 488 Pista | S | RWD | 2,9 | 2,92 | 7,44 | 965 |
| Porsche 911 GT3 | S | RWD | 3,4 | 3,36 | 7,84 | 921 |
| Audi RS6 | S | AWD | 3,9 | 3,93 | 8,36 | 886 |
| Chevrolet Camaro SS | **A** | RWD | 4,0 | 3,92 | 8,37 | 813 |
| Tesla Model Y | A | AWD | 5,0 | 5,01 | 9,43 | 757 |
| Mercedes S400 | A | RWD | 5,3 | 5,25 | 9,50 | 782 |
| BMW E46 330i | A | RWD | 6,5 | 6,47 | 10,34 | 734 |
| BMW E60 530i | A | RWD | 6,5 | 6,50 | 10,38 | 739 |
| Mercedes CLS 350 | A | RWD | 6,7 | 6,69 | 10,58 | 740 |
| Volvo S60 | A | FWD | 7,0 | 6,97 | 10,60 | 711 |
| Audi A3 | A | FWD | 7,2 | 7,20 | 10,76 | 701 |
| Seat Leon | B | FWD | 8,0 | 8,02 | 11,23 | 646 |
| VW Golf 7 | B | FWD | 8,2 | 8,20 | 11,33 | 641 |
| Alfa Romeo 159 | **A** | FWD | 8,8 | 8,80 | 11,59 | 643 |
| VW Passat B5.5 | B | FWD | 9,9 | 9,87 | 12,09 | 563 |
| Renault Fluence | B | FWD | 9,9 | 9,90 | 12,11 | 568 |
| Skoda Kamiq | B | FWD | 10,2 | 10,21 | 12,23 | 550 |
| Hyundai Accent Blue | C | FWD | 10,2 | 10,21 | 12,23 | 525 |
| Honda Civic VTEC | B | FWD | 10,5 | 10,48 | 12,35 | 562 |
| Ford Focus | C | FWD | 10,9 | 10,90 | 12,52 | 518 |
| Opel Corsa | C | FWD | 11,2 | 11,22 | 12,65 | 491 |
| Hyundai Getz | C | FWD | 11,5 | 11,45 | 12,73 | 470 |
| Hyundai Era | C | FWD | 12,3 | 12,30 | 13,07 | 437 |
| Tofaş Şahin | D | RWD | 13,2 | 13,23 | 13,40 | 371 |
| Renault Toros | D | FWD | 14,5 | 14,56 | 13,83 | 320 |

**GENEL sütunu eski formülle hesaplanmıştı** (dört statın ağırlıklı toplamı). 2026-10-11'den beri GENEL doğrudan
kusursuz 300 m süresinden gelir (14,0 sn = 250 · 7,2 sn = 1000, doğrusal): Huracán 992, 488 973, GT3 929, RS6 872,
Camaro 871, Model Y 754, S400 746, E46 653 … Getz 390, Era 353, Şahin 316, Toros 268. Sıralama süreyle birebir
aynıdır (`vehicle_asset_test` denetler).

\* PACE'siz eşdeğer (oyunda tüm süreler PACE 1,25 ile kısalır, sıralama aynıdır).
Öncesi: 0-100 değerleri 6,0–10,2 sn aralığına sıkışmıştı, 300 m farkı en yavaşla en hızlı arasında 2,3 sn'ydi.
Şimdi 6,5 sn.

## Sınıflar 300 m süresine göre yeniden kuruldu (2026-10-11, kullanıcı onayı)

| Sınıf | 300 m (kusursuz) | Araçlar | Değişen |
|---|---|---|---|
| S | ≤ 8,4 sn | Huracán, 488, GT3, RS6, Camaro | Camaro A → S |
| A | 9,4 – 10,8 | Model Y, S400, E46, E60, CLS, S60, A3 | — |
| B | 11,2 – 11,6 | Leon, Golf 7, Alfa 159 | Alfa A → B |
| C | 12,0 – 12,8 | Passat, Fluence, Kamiq, Civic, Accent Blue, Focus, Corsa, Getz | Passat, Fluence, Kamiq, Civic B → C |
| D | ≥ 13,0 | Era, Şahin, Toros | Era C → D |

Sınıf; rakip havuzunu (kendi + bir üst), AI becerisini ve galibiyet ödülünü belirler (Camaro'yu yenmek artık S
ödülü: 2.000 ₺ / 100 XP). Fiyat, seviye kilidi, kasa ve nadirlik DEĞİŞMEDİ.

## Bilinmezlik: rakibin GÜN FORMU

Kullanıcı: "rakip aynı arabayla bir tur 11 yapıyorsa diğer tur düşük ihtimal de olsa 12 yapsın, bazen 10,5
yapsın". Öncesinde aynı araçla rakip süreleri yalnızca ±0,2 sn oynuyordu.

Her yarışta rakibe `DragRaceSim.Form` çekilir (ekrandaki rakip ve başsız `run_rival` AYNI kuralı kullanır):
- **Güç:** normal dağılım σ %3, en fazla ±%8 (lastik sıcaklığı, hava, motor).
- **Beceri:** sınıf becerisi ± σ 0,12.
- **Kötü gün (%8):** beceri −0,30…−0,50, kalkışı kaçırır (debriyaj), bir vitesi ıskalar (optimumun %60'ında
  atar → MISS), güç −%6…−12.
- **İyi gün (%15):** kusursuza yakın sürüş, güç +%12…22.
- Sınıf becerileri indirildi: D 0,35 · C 0,50 · B 0,62 · A 0,72 · S 0,78 (eski: … A 0,90 · S 0,95). Kusursuz
  sürüş artık rakibin iyi günü. Eski hâlde A/S rakibi normal günde de kusursuzdu: iyi oyuncu aynı araçla S
  rakibi hiç yenemiyordu (%0).

Ölçüm (`qa/rival_spread.gd`, 400 yarış):

| Araç | Ortanca | p5 / p95 | En iyi / en kötü | %4,5 hızlı | %9 yavaş |
|---|---|---|---|---|---|
| Tofaş Şahin (D) | 13,92 | 12,77 / 14,82 | 12,42 / 15,87 | %12,5 | %2,8 |
| Hyundai Getz (C) | 13,18 | 12,21 / 14,17 | 12,11 / 14,70 | %14,2 | %2,2 |
| Renault Fluence (C) | 12,51 | 11,48 / 13,36 | 11,36 / 14,08 | %17,2 | %0,8 |
| VW Golf 7 (B) | 11,59 | 11,07 / 12,30 | 10,93 / 12,67 | %5,2 | %0,2 |
| BMW E46 (A) | 10,54 | 10,10 / 11,28 | 9,99 / 12,29 | %2,0 | %1,8 |
| Mercedes S400 (A) | 9,77 | 9,34 / 10,21 | 9,21 / 10,89 | %4,0 | %0,2 |
| Chevrolet Camaro (S) | 8,63 | 8,24 / 9,08 | 8,13 / 9,49 | %4,5 | %0,5 |
| Ferrari 488 Pista (S) | 7,68 | 7,34 / 8,12 | 7,18 / 8,58 | %4,5 | %1,5 |

(Süreler tepki dahil yarış saati; alt sınıflar zaten daha çok hata yaptığı için dağılımları geniş.)

Oyuncunun kendi aracına form uygulanmadı: oyuncunun süresi yalnızca kendi tepkisine ve viteslerine bağlı
(kişisel rekor adil kalsın).

**Bulunan hata (eskiden de vardı):** AI'nin vites hedefi devir sınırına eşit çıkabiliyordu; limitçi devri
sınırın altında tuttuğu için hedef hiç tutmuyor, rakip vites atmadan pistin sonuna kadar sınırda kalıyordu
(Şahin 19,8 sn). Hedef artık sınırın %99,5'i (`AI_SHIFT_CEILING`).

## Eşleşme (iyi oyuncu vs rakip havuzu, `qa/matchup_report.gd`)

Aynı araçla yarış artık dengeli: Getz %96, A3 %75, RS6 %46, Camaro %42 (öncesi S'de %0). Ama havuz "kendi
sınıfı + bir üst" olduğu için bir üst sınıftan gelen rakiplere karşı hâlâ çok "%0" var: sınıf aralığı ~1 sn,
bilinmezlik ~±0,4 sn. **Öneri (uygulanmadı):** rakibi sınıfa göre değil oyuncunun kusursuz 300 m süresine göre
seçmek (ör. oyuncudan en fazla %6 hızlı, en fazla %8 yavaş araçlar). Böylece her eşleşmede kazanma şansı olur,
güçlü rakip yine gelir.

## Diğer açık noktalar
- **Tesla elektrikli** ama aynı vitesli modeli kullanıyor (oyunun vites mekaniği için). Tek vitesli / düz
  torklu bir EV modeli istenirse ayrı karar.
- Garajın DETAY panelinde gerçek veriler (motor, 0-100, çekiş) gösterilmiyor; hâlâ 4 çubuk + GENEL puan.

## Testler
- `race_test` sınıf düelloları: eşit performans Passat–Fluence (C, 9,9 sn) 5–35/40; komşu sınıf Getz (C) – Şahin
  (D) ≥ 30/40 (iyi günde sürpriz olabilir); iki sınıf fark E46 (A) – Getz (C) ≥ 39/40.
- `vehicle_asset_test`: hız aralığı 120–360, ivme 0–100, `performance` bloğu ve son hız eşitliği kontrolü.
- `race_test`: BMW hız statı 145 → 250.
