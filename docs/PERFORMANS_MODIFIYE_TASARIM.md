# PERFORMANS MODİFİYESİ — Tasarım (2026-10-13)

> Önceki adımlar: `PERFORMANS_MODIFIYE_ARASTIRMA.md` (orijinal Car Town) → `PERFORMANS_MODIFIYE_TASLAK.md`
> (tür karşılaştırması, 6 kategori × 5 kademe). Bu belge taslağı **ölçülmüş** bir tasarıma çevirir: her
> parça simülasyonda fiziksel bir değeri değiştirir ve 55 aracın hepsinde kusursuz sürüşle ölçülmüştür.
> Ölçüm aracı: `qa/mod_report.gd` (oyun koduna dokunmaz). Henüz oyuna kod eklenmedi.
>
> ```
> godot-4 --headless --path . -s res://qa/mod_report.gd -- tablo           # bütün araçlar, özet
> godot-4 --headless --path . -s res://qa/mod_report.gd -- kademe vw_passat_b55
> godot-4 --headless --path . -s res://qa/mod_report.gd -- json /yol/mod.json
> ```

## 0. Kısaca

- **6 kategori × 5 kademe** (SOKAK · SPOR · YARIŞ · PRO · EFSANE). Her kademe gerçek parça adıyla.
- Parçalar sayıya değil **fiziğe** etki eder: tork, devir sınırı, turbo gecikmesi, vites oranı, vites geçiş
  süresi, lastik tutuşu, dönen kütle, kütle, hava direnci. Bu yüzden **her araç farklı tepki verir**:
  Passat'ta MOTOR, Golf'te LASTİK, Şahin'de HAVA AKIŞI en verimli parçadır.
- Motor tipine göre **6 profil** (turbo benzin, turbo dizel, atmosferik, klasik, dizel, elektrik). Aynı parça
  turbo dizelde çok, atmosferikte az tork verir. Klasikte TURBO yerine KOMPRESÖR, elektrikte BATARYA satılır.
- **Full yükseltme** (30 parça): 300 m **−%7…−11** (çoğunlukla −%8), gösterilen 0-100 **−%17…−27**,
  son hız **+%11…13**, beygir **+%14…18** (elektrikte +%12).
- **Sınıf en fazla bir basamak atlar.** 55 aracın 20'si full yükseltmeyle üst sınıfa geçer; hiçbiri iki
  basamak atlamaz. C sınıfı Passat full olunca B olur, A'ya yetişemez.
- İstediğin örnek birebir tutuyor: **Passat 9,9 sn → MOTOR · Stage 1 Yazılım → 9,72 sn**;
  ŞANZIMAN son hızı **208 → 218 km/sa** çıkarır.

## 1. Kademeler

| # | Kademe | Renk | Kilit (öneri) | Takma (öneri) |
|---|---|---|---|---|
| 1 | **SOKAK** | gri | Seviye 3 (yarışlar açılınca) | Anında |
| 2 | **SPOR** | yeşil | Seviye 5 | Anında |
| 3 | **YARIŞ** | mavi | Seviye 8 | Tamir alanında 1 dk |
| 4 | **PRO** | mor | Seviye 12 | Tamir alanında 3 dk |
| 5 | **EFSANE** | altın | Seviye 16 | Tamir alanında 6 dk |

- Kademeler sırayla alınır (SPOR için önce SOKAK). Bir kategoride kademe, ötekilerden bağımsızdır.
- YARIŞ ve üstü bir tamir alanını işgal eder: araç lifte çıkar, süre bitince "TAKILDI" (restorasyon /
  tamir alanının mevcut akışı). Alan doluyken müşteri tamiri yapılamaz → **gerçek bir fırsat maliyeti**
  (orta işlerle aynı "alayım mı?" kararı). Süre mevcut tamir hızlandırmasıyla (gem) kısaltılabilir.
- Seviye eşikleri orta işlerin açıldığı seviyelerle (5 / 8 / 12) hizalı.

## 2. Parçalar ve fiziksel etkileri

Tablolar **birikimlidir** (EFSANE takılıysa önceki dört kademenin etkisi de içindedir). Yüzdeler profil
çarpanından ÖNCEKİ değerdir (§3).

### MOTOR — tork, bütün devir bandında

| Kademe | Parça | Tork |
|---|---|---|
| SOKAK | Stage 1 Yazılım | +%1,2 |
| SPOR | Spor Eksantrik | +%2,1 |
| YARIŞ | Dövme Piston | +%2,9 |
| PRO | Stroker Krank | +%3,6 |
| EFSANE | Yarış Bloğu | +%4,2 |

İlk kademe en hissedilir (yazılım ucuz ve etkili), sonrakiler azalan getiri.

### TURBO — tork + turbo gecikmesi

| Kademe | Parça | Tork | Tepe tork devri (gecikme) |
|---|---|---|---|
| SOKAK | Turbo Yükseltme | +%0,9 | +%1 |
| SPOR | Büyük İntercooler | +%2,0 | +%2 |
| YARIŞ | Hibrit Türbin | +%3,1 | +%3 |
| PRO | Büyük Turbo | +%4,3 | +%4 |
| EFSANE | Twin-Turbo | +%5,4 | +%5 |

Büyük turbo üst devirde çok, kalkışta az verir: tepe tork devri yukarı kayar (gecikme). Kalkış devri tepe
torka göre yeniden hesaplanır.

### HAVA AKIŞI — devir sınırı (motor yükseğe nefes alır)

| Kademe | Parça | Tork | Devir sınırı + tepe güç devri |
|---|---|---|---|
| SOKAK | Spor Hava Filtresi | +%0,3 | +%0,8 |
| SPOR | Soğuk Hava Emişi | +%0,6 | +%1,6 |
| YARIŞ | Downpipe | +%0,9 | +%2,4 |
| PRO | Paslanmaz Manifold | +%1,2 | +%3,2 |
| EFSANE | Titanyum Yarış Egzozu | +%1,5 | +%4,0 |

Az tork, çok devir: her viteste daha uzun çekilir, beygir (tork × devir) artar. Yüksek devirli atmosferik
motorlarda (Civic VTEC, M3, Şahin) en verimli parça budur.

### ŞANZIMAN — vites geçişi, volan, oranlar, son hız

| Kademe | Parça | Vites geçiş süresi | Dönen kütle | Alt vitesler | Yarış son vitesi | Gösterilen son hız |
|---|---|---|---|---|---|---|
| SOKAK | Kısa Vites Kolu | ×0,90 | — | — | +%2 | +%0,8 |
| SPOR | Spor Debriyaj | ×0,86 | — | — | +%4 | +%1,6 |
| YARIŞ | Hafif Volan | ×0,82 | −%1 | — | +%6 | +%2,4 |
| PRO | Yakın Oranlı Kutu | ×0,76 | −%1 | 1. vites %3 kısa | +%8 | +%4,0 |
| EFSANE | Sıralı Yarış Şanzımanı | ×0,62 | −%1 | 1. vites %4 kısa | +%10 | +%5,0 |

Kusursuz geçiş 0,085 sn → EFSANE'de 0,053 sn. Kutu her kademede uzun son vitesle yeniden kurulur (güçlenen
araç devir sınırına dayanmasın); yakın oranlı kutuda alt vitesler kısalır (1. vites en çok, son vites aynı).

### LASTİK & JANT — tutuş + dönen kütle

| Kademe | Parça | Tutuş | Dönen kütle |
|---|---|---|---|
| SOKAK | Spor Lastik | +%3 | — |
| SPOR | Hafif Jant & Yarı Slik | +%6 | −%0,7 |
| YARIŞ | Dövme Jant & Drag Radial | +%9 | −%1,1 |
| PRO | Magnezyum Jant & Slik | +%12 | −%1,5 |
| EFSANE | Karbon Jant & Pro Drag Slik | +%15 | −%1,8 |

**Eşik davranışı:** tutuş yalnızca kalkışta patinaj yapan araçta işe yarar. Patinaj yapmayan araçta (Passat,
klasikler) yalnız dönen kütle çalışır: küçük ama her zaman var. Patinaj yapan güçlü araçta (Golf, Leon,
E46, S sınıfı) **en büyük kazanç buradadır**: Golf 7'de SPOR kademesinde patinaj biter, 0-100 8,06 → 7,36 sn
(tek parçanın en büyük sıçraması); Seat Leon'da aynı eşik YARIŞ kademesinde.
Taslaktaki "Hafif Jant" GÖVDE'den buraya taşındı.

### GÖVDE — kütle + hava direnci

| Kademe | Parça | Kütle | Hava direnci (ön alan × Cd) |
|---|---|---|---|
| SOKAK | Hafif Akü | −%0,7 | — |
| SPOR | Karbon Kaput | −%1,4 | −%0,8 |
| YARIŞ | Kova Koltuk & İç Söküm | −%2,1 | −%1,6 |
| PRO | Karbon Panel & Spoiler | −%2,8 | −%2,4 |
| EFSANE | Tam Karbon Gövde | −%3,5 | −%3,5 |

Not: kütle düşünce çekiş kuvveti de (ağırlık × tutuş) düşer. Bu yüzden patinaj yapan araçta GÖVDE kalkışta
neredeyse etkisizdir; üst viteste ve son hızda çalışır.

### Dönen kütlenin modeli

Hafif jant / hafif volan, ivmelenen kütleyi azaltır ama çekişi belirleyen ağırlığı değiştirmez. Simülasyonda
kütle ×(1−x), tutuş katsayısı ÷(1−x): çekiş kuvveti aynı kalır, ivme artar.

## 3. Motor profilleri — aynı parçaya farklı tepki

Profil `performance.engine` ve yıldan otomatik çıkar (`qa/mod_report.gd: profile_of`).
Çarpanlar §2'deki artışlara uygulanır.

| Profil | Nasıl tanınır | MOTOR | TURBO | Gecikme | HAVA torku | Devir | Araçlar |
|---|---|---|---|---|---|---|---|
| **Turbo benzin** | turbo / TSI / TFSI / "…T" / biturbo | ×1,25 | ×1,20 | ×0,6 | ×0,9 | ×1,0 | Golf, Leon, A3, S60, RS6, S400, Evo, Delta, Celica, Corsa… |
| **Turbo dizel** | TDI / CRDi | ×1,50 | ×1,30 | ×0,6 | ×0,6 | ×0,4 | Passat, Kamiq, Getz |
| **Atmosferik** | diğerleri (1980+) | ×1,00 | ×1,00 | ×1,5 | ×1,25 | ×1,2 | Huracán, GT3, Civic, E46, Şahin, Toros… |
| **Klasik** | 1980 öncesi | ×1,10 | ×1,00 (kompresör) | 0 | ×1,30 | ×1,0 | Mustang, Charger, DB5, Murat 124, Anadol… |
| **Dizel** | "Dizel" (turbosuz) | ×1,00 | ×1,30 | ×1,5 | ×0,6 | ×0,4 | Mercedes W123 |
| **Elektrik** | Elektrik | ×1,30 | ×1,00 (batarya) | 0 | ×0,5 | 0 | Tesla Model Y |

Gerekçeler: turbo dizel yazılıma en çok cevap veren motordur ama devir çevirmez; atmosferik motor yazılımdan
az, egzoz / emişten çok kazanır; turbo atmosferik motora "turbo kiti" olarak eklenir (büyük gecikme);
kompresör gecikmesizdir; elektrik motorunun devir sınırı yükseltilemez.

### Kategori adları profile göre değişir

| Profil | TURBO yerine | HAVA AKIŞI yerine |
|---|---|---|
| Klasik | **KOMPRESÖR**: Kompresör Kiti · Büyük Kasnak · Intercooler · Roots Kompresör · Twin-Screw Kompresör | **KARBÜRATÖR & EGZOZ**: Spor Hava Filtresi · Çift Karbüratör · Weber Karbüratör · Yarış Manifoldu · Enjeksiyon Dönüşümü |
| Elektrik | **BATARYA**: Yüksek Deşarj Modu · Hızlı Hücre Paketi · Yarış Hücreleri · Süperkapasitör Destek · Yarış Bataryası | **SOĞUTMA**: Spor Radyatör · Batarya Ön Isıtma · Sıvı Soğutmalı Kablo · Yarış Soğutma Devresi · Kriyo Soğutma |
| Atmosferik / dizel | **TURBO**: ilk kademe "Turbo Kiti" (sonrakiler aynı) | aynı |

Klasikte MOTOR'un ilk kademesi "Stage 1 Yazılım" yerine **Elektronik Ateşleme**. Elektrikte MOTOR:
Performans Yazılımı · Spor İnvertör · SiC İnvertör · Karbon Sargılı Rotor · Yarış Motoru.

## 4. Ekrandaki değerler nasıl hesaplanır

Oyunun yarışı 300 m (kusursuz kalkış + kusursuz vites, `DragRaceSim.Runner`). Ekranda ayrıca gerçek dünya
değerleri gösterilir; bunlar katalogdaki gerçek değerin **ölçülmüş oranla** çarpımıdır:

- **0-100** = katalog 0-100 × (modifiyeli / fabrika) karşılaştırma süresi. Karşılaştırma süresi tek hızda
  değil, karşılaştırma hızının **%50–%100 bandındaki 26 hıza varış anının ortalaması**dır. Tek noktada ölçmek
  hatalıydı: vites geçişi tam 100 km/sa'ya denk gelince süre 0,14 sn sıçrıyor ve Camaro'da MOTOR yükseltmesi
  0-100'ü 4,0'dan 4,15'e "kötüleştiriyordu". Karşılaştırma hızı 100 km/sa; 100'e zor varan klasiklerde
  (Fiat 500, T1, Willys) fabrika tepe hızının %75'i.
- **Beygir** = katalog bg × (tepe tork × tepe güç devri oranı).
- **Son hız** = katalog son hız × (güç / hava direnci)^(1/3) × (1 + şanzıman katkısı).
- **Gösterge asla kötüleşmez:** bir kademe takılınca gösterilen 0-100, öncekinden büyükse öncekinde kalır.
  Gerekçe: zaten patinaj yapan S sınıfı arka itişlilerde fazladan güç patinaja gider ve bant ortalamasında
  ≤0,005 sn kaybettirebilir (fiziksel olarak doğru, ama "para verdim kötüleşti" hissi yanlış). 300 m'de
  hiçbir parça hiçbir araçta süreyi uzatmaz (55 araç × 30 kademe ölçüldü).
- **Patinaj ipucu:** MOTOR / TURBO bir araçta 0-100'ü kıpırdatmıyorsa (GT3, Camaro, 2016 Beetle) parça
  kartında "Güç patinaja gidiyor — önce LASTİK" yazar. Bu araçlarda MOTOR yine beygiri, son hızı ve 300 m'yi
  iyileştirir.

## 5. Sınıf, GENEL puan, rakip ve ödül

### Sınıf kuralı

Modifiyeli aracın sınıfı, **300 m süresinin hangi sınıfın en yavaş fabrika aracına yetiştiğine** göre:

| Sınıf | Eşik (300 m ≤) | Sınırı belirleyen fabrika araç |
|---|---|---|
| S | 8,37 sn | Chevrolet Camaro |
| A | 10,95 sn | Toyota Celica GT-Four |
| B | 11,63 sn | Ford Escort RS1600 |
| C | 12,72 sn | Hyundai Getz |
| D | üstü | |

Fabrika sınıf bantları temiz ayrık olduğu için (S ≤ 8,37 < A 8,94…10,95 < B 11,18…11,63 < C 12,07…12,72 <
D ≥ 12,99) kural hiçbir fabrika aracın sınıfını değiştirmez. Full yükseltmeyle:
**A→S 1 araç (Evo VI), B→A 6, C→B 7, D→C 6; iki basamak atlayan yok.** Kartta "C → B" rozeti.
Yeni araç eklenince eşikler kendiliğinden kayar: eşik sabit sayı değil, "sınıfın en yavaş fabrika aracı".

### GENEL puan

`DragRaceSim.overall_of` zaten 300 m'den hesaplanıyor; modifiyeli süreyle hesaplanır. Formül değişmez ama
**üst sınır kalkar**: full S araçları 1000'i geçer (Huracán 992 → 1061, 488 Pista 973 → 1042). Tavan 1000
kalırsa üç S aracının son kademeleri GENEL'de hiç görünmez. Fabrika puanları değişmez.

### Rakip ve ödül

Bugün rakip havuzu oyuncu aracının `base_time`'ına göre seçiliyor (RIVAL_FASTER 0,06 / RIVAL_SLOWER 0,08),
ödül rakibin sınıfına göre (D 450 · C 700 · B 1000 · A 1400 · S 2000). Öneri: **modifiyeli süre** kullanılsın.
Yükseltme "kolay galibiyet" değil **daha üst sınıf rakip ve daha yüksek ödül** getirir: full Passat B
rakipleriyle eşleşir, kazanınca 700 yerine 1000 ₺. Yükseltmenin kendini geri ödemesi buradan gelir, oyun
dengesi (her yarış yakın) bozulmaz. Yarış ekranındaki egzoz alevi / motor sesi / pist akışı
(`performance_ratio`) gösterilen 0-100'den beslenir: modifiyeli araç kendiliğinden daha "sert" görünür.

## 6. Fiyat

**Fiyat = max(taban, araç fiyatı × kademe oranı) × kategori ağırlığı**, 50 ₺'ye yuvarlanır.

| Kademe | Oran | Taban |
|---|---|---|
| SOKAK | %1 | 250 ₺ |
| SPOR | %2 | 500 ₺ |
| YARIŞ | %3,5 | 800 ₺ |
| PRO | %6 | 1.300 ₺ |
| EFSANE | %10 | 2.000 ₺ |

Kategori ağırlığı: MOTOR 1,2 · TURBO 1,2 · ŞANZIMAN 1,0 · GÖVDE 1,0 · HAVA 0,8 · LASTİK 0,8.
Full yükseltme ≈ araç fiyatının **1,35 katı** (ucuz araçlarda taban yüzünden biraz fazla).

| Örnek | SOKAK MOTOR | Full |
|---|---|---|
| Tofaş Şahin (15.000 ₺, başlangıç aracı) | 300 ₺ | 29.100 ₺ |
| VW Passat (50.000 ₺) | 600 ₺ | 67.500 ₺ |
| VW Golf 7 (65.000 ₺) | 800 ₺ | 87.800 ₺ |
| Lamborghini Huracán (400.000 ₺) | 4.800 ₺ | 540.000 ₺ |

Ekonomiyle kıyas: kısa tamir işleri bay başına ~1.000 ₺/dk. SOKAK parçası 20–60 sn'lik tamir parası
(ilk alım dürtüsü), full Passat ~1 saatlik aktif oyun. Araç satılınca harcanan modifiye parasının %40'ı geri
döner (araç satışıyla aynı oran). Hepsi ₺; gem yalnızca takma süresini kısaltır (orijinal Car Town'da
premium kademeler en çok şikâyet alan şeydi).

## 7. Kategori verimliliği — oyuncu aracına göre karar verir

EFSANE kademede tek başına kategorinin gösterilen 0-100'e etkisi (sn). "En verimli" = sn başına en ucuz
kategori. "Güç sonrası lastik": MOTOR + TURBO + HAVA full iken LASTİK'in 300 m'ye katkısı (patinaj yapan
araçta güç ile lastik birbirini besler).

Okuma:
- **Turbo dizel** (Passat, Kamiq, Getz): TURBO ve MOTOR açık ara önde; HAVA zayıf (devir çevirmez).
- **Atmosferik / klasik**: HAVA AKIŞI en verimli; motor yazılımı az verir.
- **Patinaj yapan güçlüler** (Golf, Leon, A3, S60, E46, M3, S sınıfı): LASTİK tek başına MOTOR+TURBO'dan
  fazla kazandırır; güçten sonra lastik ~%3 daha.
- **AWD** (Delta, RS200, Celica): az patinaj, güç ve hava parçaları çalışır. Evo VI ve Quattro S1 yine de
  patinaj yapacak kadar güçlü: LASTİK önde.
- **Elektrik** (Model Y): SOĞUTMA neredeyse etkisiz, MOTOR / BATARYA / ŞANZIMAN eşit.

## 8. Bütün araçlar — fabrika ve FULL

300 m sırasıyla. 0-100 / son hız / güç gösterilen değerlerdir (§4); 300 m ve GENEL oyunun gerçek yarış
sonucudur. "Yeni sınıf" §5'teki kurala göre. Fiyat §6'daki formülle 30 parçanın toplamıdır.

| Araç | Sınıf | Çekiş | Profil | 0-100 | Son hız | Güç | 300 m | → FULL 0-100 | Son hız | Güç | 300 m | GENEL | Yeni sınıf | Fiyat (full) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| LAMBORGHINI HURACÁN | S | AWD | Atmosferik | 2.9 | 325 | — | 7.28 | 2.37 (-18%) | 364 | — | 6.65 (-8.6%) | 992 → 1061 | S | 540.000 ₺ |
| FERRARI 488 PISTA | S | RWD | Atmosferik | 2.9 | 340 | — | 7.44 | 2.39 (-18%) | 381 | — | 6.82 (-8.4%) | 973 → 1042 | S | 607.500 ₺ |
| PORSCHE 911 GT3 | S | RWD | Atmosferik | 3.4 | 311 | — | 7.84 | 2.80 (-18%) | 348 | — | 7.18 (-8.4%) | 929 → 1002 | S | 405.000 ₺ |
| AUDI RS6 | S | AWD | Turbo benzin | 3.9 | 305 | — | 8.36 | 3.19 (-18%) | 343 | — | 7.65 (-8.5%) | 872 → 950 | S | 297.000 ₺ |
| CHEVROLET CAMARO | S | RWD | Atmosferik | 4.0 | 250 | — | 8.37 | 3.31 (-17%) | 280 | — | 7.67 (-8.4%) | 871 → 949 | S | 189.000 ₺ |
| MITSUBISHI LANCER EVO VI | A | AWD | Turbo benzin | 4.4 | 240 | 280 | 8.94 | 3.55 (-19%) | 270 | 331 | 8.21 (-8.2%) | 808 → 889 | **S** ↑ | 84.300 ₺ |
| AUDI SPORT QUATTRO S1 | A | AWD | Turbo benzin | 4.8 | 250 | 306 | 9.34 | 3.84 (-20%) | 281 | 361 | 8.58 (-8.2%) | 764 → 848 | A | 84.300 ₺ |
| TESLA MODEL Y | A | AWD | Elektrik | 5.0 | 217 | — | 9.43 | 4.04 (-19%) | 239 | — | 8.76 (-7.1%) | 755 → 828 | A | 148.500 ₺ |
| MERCEDES S400 | A | RWD | Turbo benzin | 5.3 | 250 | — | 9.50 | 4.35 (-18%) | 281 | — | 8.72 (-8.2%) | 746 → 833 | A | 229.500 ₺ |
| PORSCHE 911 CARRERA RS (1973) | A | RWD | Klasik (karbüratör) | 5.8 | 245 | 210 | 9.85 | 4.75 (-18%) | 274 | 246 | 9.08 (-7.9%) | 708 → 793 | A | 84.300 ₺ |
| LANCIA DELTA INTEGRALE | A | AWD | Turbo benzin | 5.7 | 220 | 210 | 9.93 | 4.41 (-23%) | 247 | 248 | 9.12 (-8.2%) | 699 → 789 | A | 84.300 ₺ |
| FORD RS200 | A | AWD | Turbo benzin | 6.1 | 225 | 250 | 10.17 | 4.72 (-23%) | 253 | 295 | 9.33 (-8.3%) | 673 → 766 | A | 84.300 ₺ |
| CHEVROLET CORVETTE C2 (1963) | A | RWD | Klasik (karbüratör) | 6.3 | 225 | 360 | 10.22 | 5.13 (-19%) | 252 | 421 | 9.42 (-7.8%) | 667 → 756 | A | 84.300 ₺ |
| BMW E46 | A | RWD | Atmosferik | 6.5 | 250 | — | 10.34 | 5.26 (-19%) | 280 | — | 9.53 (-7.9%) | 653 → 744 | A | 114.800 ₺ |
| BMW E60 | A | RWD | Atmosferik | 6.5 | 250 | — | 10.37 | 5.11 (-21%) | 280 | — | 9.50 (-8.4%) | 651 → 746 | A | 162.000 ₺ |
| BMW M3 E30 | A | RWD | Atmosferik | 6.6 | 241 | 215 | 10.41 | 5.34 (-19%) | 270 | 252 | 9.58 (-8.0%) | 646 → 738 | A | 84.300 ₺ |
| LAMBORGHINI MIURA (1968) | A | RWD | Klasik (karbüratör) | 6.7 | 280 | 350 | 10.43 | 5.46 (-19%) | 313 | 409 | 9.63 (-7.7%) | 644 → 733 | A | 84.300 ₺ |
| DODGE CHARGER (1970) | A | RWD | Klasik (karbüratör) | 6.7 | 210 | 375 | 10.50 | 5.29 (-21%) | 235 | 438 | 9.65 (-8.1%) | 636 → 730 | A | 84.300 ₺ |
| MERCEDES CLS | A | RWD | Atmosferik | 6.7 | 250 | — | 10.57 | 5.28 (-21%) | 280 | — | 9.68 (-8.4%) | 629 → 726 | A | 202.500 ₺ |
| LANCIA STRATOS HF (1974) | A | RWD | Klasik (karbüratör) | 6.8 | 232 | 190 | 10.59 | 5.48 (-19%) | 260 | 222 | 9.78 (-7.7%) | 626 → 716 | A | 84.300 ₺ |
| VW BEETLE | A | FWD | Turbo benzin | 6.9 | 229 | 220 | 10.59 | 5.68 (-18%) | 257 | 260 | 9.73 (-8.1%) | 626 → 721 | A | 108.000 ₺ |
| VOLVO S60 | A | FWD | Turbo benzin | 7.0 | 235 | 210 | 10.60 | 5.73 (-18%) | 264 | 248 | 9.73 (-8.2%) | 625 → 721 | A | 141.800 ₺ |
| JAGUAR E-TYPE (1961) | A | RWD | Klasik (karbüratör) | 7.1 | 241 | 265 | 10.70 | 5.75 (-19%) | 270 | 310 | 9.88 (-7.7%) | 614 → 705 | A | 84.300 ₺ |
| AUDI A3 | A | FWD | Turbo benzin | 7.2 | 232 | 180 | 10.76 | 5.84 (-19%) | 261 | 213 | 9.88 (-8.2%) | 608 → 705 | A | 128.300 ₺ |
| FORD MUSTANG (1967) | A | RWD | Klasik (karbüratör) | 7.4 | 195 | 320 | 10.87 | 5.81 (-21%) | 218 | 374 | 9.99 (-8.1%) | 596 → 692 | A | 84.300 ₺ |
| TOYOTA CELICA GT-FOUR | A | AWD | Turbo benzin | 7.5 | 230 | 208 | 10.95 | 5.82 (-22%) | 258 | 246 | 10.03 (-8.4%) | 586 → 688 | A | 84.300 ₺ |
| ASTON MARTIN DB5 (1964) | B | RWD | Klasik (karbüratör) | 8.0 | 233 | 282 | 11.18 | 6.29 (-21%) | 261 | 330 | 10.28 (-8.0%) | 562 → 660 | **A** ↑ | 84.300 ₺ |
| SEAT LEON | B | FWD | Turbo benzin | 8.0 | 215 | 150 | 11.23 | 6.48 (-19%) | 241 | 177 | 10.34 (-7.9%) | 555 → 653 | **A** ↑ | 91.900 ₺ |
| VW GOLF 7 | B | FWD | Turbo benzin | 8.2 | 216 | 150 | 11.33 | 6.62 (-19%) | 243 | 177 | 10.43 (-7.9%) | 544 → 643 | **A** ↑ | 87.800 ₺ |
| MERCEDES-BENZ 300 SL (1955) | B | RWD | Klasik (karbüratör) | 8.8 | 235 | 215 | 11.57 | 6.91 (-21%) | 263 | 251 | 10.64 (-8.1%) | 517 → 620 | **A** ↑ | 84.300 ₺ |
| ALFA ROMEO 159 | B | FWD | Atmosferik | 8.8 | 222 | 185 | 11.58 | 6.90 (-22%) | 249 | 217 | 10.62 (-8.3%) | 517 → 623 | **A** ↑ | 121.500 ₺ |
| FORD ESCORT RS1600 (1972) | B | RWD | Klasik (karbüratör) | 8.9 | 182 | 120 | 11.63 | 6.99 (-21%) | 204 | 140 | 10.71 (-8.0%) | 511 → 613 | **A** ↑ | 84.300 ₺ |
| VOLKSWAGEN PASSAT B5.5 | C | FWD | Turbo dizel | 9.9 | 208 | 130 | 12.07 | 7.73 (-22%) | 233 | 152 | 11.06 (-8.4%) | 462 → 574 | **B** ↑ | 67.500 ₺ |
| RENAULT FLUENCE | C | FWD | Atmosferik | 9.9 | 200 | 140 | 12.09 | 7.76 (-22%) | 224 | 164 | 11.08 (-8.3%) | 460 → 572 | **B** ↑ | 81.000 ₺ |
| SKODA KAMIQ | C | FWD | Turbo dizel | 10.2 | 193 | 115 | 12.22 | 7.96 (-22%) | 216 | 134 | 11.21 (-8.3%) | 447 → 558 | **B** ↑ | 74.300 ₺ |
| HYUNDAI ACCENT BLUE | C | FWD | Atmosferik | 10.2 | 190 | 124 | 12.22 | 7.98 (-22%) | 213 | 145 | 11.20 (-8.3%) | 447 → 559 | **B** ↑ | 51.300 ₺ |
| HONDA CIVIC VTEC | C | FWD | Atmosferik | 10.5 | 200 | 125 | 12.34 | 8.22 (-22%) | 224 | 147 | 11.31 (-8.4%) | 433 → 547 | **B** ↑ | 97.100 ₺ |
| FORD FOCUS | C | FWD | Atmosferik | 10.9 | 193 | 125 | 12.52 | 8.54 (-22%) | 216 | 147 | 11.47 (-8.3%) | 414 → 528 | **B** ↑ | 60.800 ₺ |
| OPEL CORSA | C | FWD | Turbo benzin | 11.2 | 185 | 100 | 12.63 | 8.69 (-22%) | 208 | 118 | 11.57 (-8.4%) | 401 → 517 | **B** ↑ | 34.900 ₺ |
| HYUNDAI GETZ | C | FWD | Turbo dizel | 11.5 | 176 | 110 | 12.72 | 8.97 (-22%) | 197 | 128 | 11.69 (-8.1%) | 391 → 505 | C | 47.300 ₺ |
| CHEVROLET BEL AIR (1956) | D | RWD | Klasik (karbüratör) | 12.0 | 165 | 162 | 12.99 | 9.44 (-21%) | 185 | 189 | 11.92 (-8.3%) | 361 → 480 | **C** ↑ | 33.800 ₺ |
| HYUNDAI ERA | D | FWD | Atmosferik | 12.3 | 177 | 97 | 13.06 | 9.62 (-22%) | 198 | 114 | 11.97 (-8.4%) | 354 → 474 | **C** ↑ | 40.500 ₺ |
| TOFAŞ ŞAHİN | D | RWD | Atmosferik | 13.2 | 165 | — | 13.38 | 10.31 (-22%) | 185 | — | 12.27 (-8.3%) | 318 → 441 | **C** ↑ | 29.100 ₺ |
| TOFAŞ MURAT 131 (1979) | D | RWD | Klasik (karbüratör) | 14.0 | 155 | 75 | 13.63 | 10.99 (-22%) | 174 | 88 | 12.52 (-8.1%) | 290 → 413 | **C** ↑ | 33.800 ₺ |
| MINI COOPER (1965) | D | FWD | Klasik (karbüratör) | 14.8 | 145 | 55 | 13.67 | 11.52 (-22%) | 162 | 64 | 12.58 (-7.9%) | 287 → 406 | **C** ↑ | 33.800 ₺ |
| RENAULT TOROS | D | FWD | Atmosferik | 14.5 | 150 | — | 13.82 | 11.32 (-22%) | 168 | — | 12.67 (-8.3%) | 270 → 397 | **C** ↑ | 29.100 ₺ |
| TOFAŞ MURAT 124 (1971) | D | RWD | Klasik (karbüratör) | 16.5 | 145 | 60 | 14.27 | 12.89 (-22%) | 162 | 70 | 13.12 (-8.1%) | 250 → 347 | D | 33.800 ₺ |
| PEUGEOT 404 (1968) | D | RWD | Klasik (karbüratör) | 17.0 | 145 | 72 | 14.50 | 13.30 (-22%) | 162 | 84 | 13.30 (-8.3%) | 250 → 327 | D | 33.800 ₺ |
| VOLKSWAGEN BEETLE (1967) | D | RWD | Klasik (karbüratör) | 20.0 | 125 | 53 | 15.21 | 15.52 (-22%) | 140 | 62 | 13.96 (-8.2%) | 250 → 255 | D | 33.800 ₺ |
| ANADOL A1 (1967) | D | RWD | Klasik (karbüratör) | 20.0 | 130 | 53 | 15.22 | 15.54 (-22%) | 146 | 62 | 13.96 (-8.3%) | 250 → 255 | D | 33.800 ₺ |
| MERCEDES-BENZ W123 | D | RWD | Dizel (atmosferik) | 22.0 | 143 | 72 | 15.85 | 17.27 (-21%) | 159 | 82 | 14.55 (-8.2%) | 250 → 250 | D | 33.800 ₺ |
| LAND ROVER SERIES III (1975) | D | AWD | Klasik (karbüratör) | 29.0 | 110 | 70 | 19.04 | 21.43 (-26%) | 123 | 82 | 17.41 (-8.6%) | 250 → 250 | D | 33.800 ₺ |
| WILLYS JEEP MB (1944) | D | AWD | Klasik (karbüratör) | 30.0 | 105 | 60 | 19.44 | 21.80 (-27%) | 118 | 70 | 17.77 (-8.6%) | 250 → 250 | D | 33.800 ₺ |
| FIAT 500 (1965) | D | RWD | Klasik (karbüratör) | 35.0 | 95 | 18 | 21.12 | 26.59 (-24%) | 106 | 21 | 19.21 (-9.0%) | 250 → 250 | D | 33.800 ₺ |
| VOLKSWAGEN T1 (1965) | D | RWD | Klasik (karbüratör) | 40.0 | 105 | 44 | 21.93 | 29.05 (-27%) | 118 | 51 | 19.45 (-11.3%) | 250 → 250 | D | 33.800 ₺ |

## 9. Kategori başına etki (EFSANE, tek başına, 0-100 farkı sn)

| Araç | MOTOR | TURBO | HAVA | ŞANZ. | LASTİK | GÖVDE | Güç sonrası lastik | En verimli |
|---|---|---|---|---|---|---|---|---|
| LAMBORGHINI HURACÁN | -0.01 | -0.01 | -0.03 | -0.13 | -0.39 | -0.01 | -3.0% | LASTİK |
| FERRARI 488 PISTA | -0.00 | -0.00 | -0.03 | -0.12 | -0.36 | -0.00 | -2.8% | LASTİK |
| PORSCHE 911 GT3 | +0.00 | +0.00 | -0.03 | -0.12 | -0.46 | +0.00 | -3.1% | LASTİK |
| AUDI RS6 | -0.03 | -0.04 | -0.05 | -0.13 | -0.49 | -0.02 | -2.7% | LASTİK |
| CHEVROLET CAMARO | +0.00 | +0.00 | -0.03 | -0.13 | -0.51 | +0.00 | -3.3% | LASTİK |
| MITSUBISHI LANCER EVO VI | -0.06 | -0.07 | -0.10 | -0.18 | -0.43 | -0.03 | -2.2% | LASTİK |
| AUDI SPORT QUATTRO S1 | -0.09 | -0.11 | -0.12 | -0.21 | -0.59 | -0.06 | -2.1% | LASTİK |
| TESLA MODEL Y | -0.25 | -0.24 | -0.04 | -0.25 | -0.08 | -0.17 | -0.6% | ŞANZ. |
| MERCEDES S400 | -0.05 | -0.07 | -0.06 | -0.14 | -0.68 | -0.04 | -3.1% | LASTİK |
| PORSCHE 911 CARRERA RS (1973) | -0.02 | -0.02 | -0.07 | -0.20 | -0.67 | -0.02 | -3.5% | LASTİK |
| LANCIA DELTA INTEGRALE | -0.27 | -0.35 | -0.24 | -0.28 | -0.10 | -0.19 | -2.2% | HAVA |
| FORD RS200 | -0.29 | -0.35 | -0.24 | -0.28 | -0.10 | -0.20 | -0.6% | HAVA |
| CHEVROLET CORVETTE C2 (1963) | -0.09 | -0.11 | -0.12 | -0.21 | -0.66 | -0.07 | -2.6% | LASTİK |
| BMW E46 | -0.09 | -0.13 | -0.23 | -0.18 | -0.77 | -0.08 | -3.8% | LASTİK |
| BMW E60 | -0.26 | -0.35 | -0.29 | -0.28 | -0.11 | -0.22 | -0.6% | HAVA |
| BMW M3 E30 | -0.09 | -0.12 | -0.19 | -0.19 | -1.00 | -0.08 | -2.7% | LASTİK |
| LAMBORGHINI MIURA (1968) | -0.09 | -0.10 | -0.16 | -0.19 | -0.94 | -0.07 | -2.7% | LASTİK |
| DODGE CHARGER (1970) | -0.29 | -0.34 | -0.29 | -0.29 | -0.12 | -0.23 | -3.5% | HAVA |
| MERCEDES CLS | -0.27 | -0.36 | -0.29 | -0.28 | -0.12 | -0.23 | -0.7% | HAVA |
| LANCIA STRATOS HF (1974) | -0.14 | -0.16 | -0.19 | -0.24 | -0.58 | -0.11 | -2.3% | LASTİK |
| VW BEETLE | -0.01 | -0.01 | -0.09 | -0.20 | -0.75 | -0.01 | -3.9% | LASTİK |
| VOLVO S60 | -0.08 | -0.11 | -0.09 | -0.18 | -0.84 | -0.06 | -3.2% | LASTİK |
| JAGUAR E-TYPE (1961) | -0.12 | -0.14 | -0.22 | -0.20 | -0.80 | -0.10 | -2.7% | LASTİK |
| AUDI A3 | -0.11 | -0.15 | -0.13 | -0.22 | -0.79 | -0.08 | -3.0% | LASTİK |
| FORD MUSTANG (1967) | -0.33 | -0.39 | -0.34 | -0.33 | -0.14 | -0.25 | -3.0% | HAVA |
| TOYOTA CELICA GT-FOUR | -0.37 | -0.46 | -0.31 | -0.33 | -0.13 | -0.26 | -0.6% | TURBO |
| ASTON MARTIN DB5 (1964) | -0.35 | -0.40 | -0.36 | -0.33 | -0.14 | -0.28 | -0.6% | HAVA |
| SEAT LEON | -0.13 | -0.16 | -0.20 | -0.19 | -1.09 | -0.09 | -3.0% | LASTİK |
| VW GOLF 7 | -0.14 | -0.18 | -0.22 | -0.21 | -1.01 | -0.10 | -2.9% | LASTİK |
| MERCEDES-BENZ 300 SL (1955) | -0.39 | -0.45 | -0.41 | -0.36 | -0.15 | -0.31 | -0.6% | HAVA |
| ALFA ROMEO 159 | -0.35 | -0.49 | -0.43 | -0.37 | -0.16 | -0.31 | -0.6% | HAVA |
| FORD ESCORT RS1600 (1972) | -0.39 | -0.45 | -0.41 | -0.35 | -0.16 | -0.31 | -0.6% | HAVA |
| VOLKSWAGEN PASSAT B5.5 | -0.59 | -0.67 | -0.19 | -0.38 | -0.18 | -0.35 | -0.7% | TURBO |
| RENAULT FLUENCE | -0.40 | -0.56 | -0.48 | -0.38 | -0.18 | -0.35 | -0.6% | HAVA |
| SKODA KAMIQ | -0.61 | -0.70 | -0.21 | -0.39 | -0.18 | -0.36 | -0.6% | TURBO |
| HYUNDAI ACCENT BLUE | -0.42 | -0.58 | -0.51 | -0.39 | -0.18 | -0.36 | -0.6% | HAVA |
| HONDA CIVIC VTEC | -0.43 | -0.60 | -0.52 | -0.40 | -0.19 | -0.37 | -0.6% | HAVA |
| FORD FOCUS | -0.44 | -0.60 | -0.54 | -0.39 | -0.20 | -0.38 | -0.6% | HAVA |
| OPEL CORSA | -0.57 | -0.72 | -0.47 | -0.39 | -0.20 | -0.40 | -0.6% | TURBO |
| HYUNDAI GETZ | -0.70 | -0.80 | -0.24 | -0.39 | -0.21 | -0.41 | -0.6% | TURBO |
| CHEVROLET BEL AIR (1956) | -0.55 | -0.63 | -0.53 | -0.43 | -0.22 | -0.43 | -0.7% | HAVA |
| HYUNDAI ERA | -0.51 | -0.71 | -0.63 | -0.42 | -0.22 | -0.44 | -0.7% | HAVA |
| TOFAŞ ŞAHİN | -0.55 | -0.77 | -0.68 | -0.44 | -0.24 | -0.48 | -0.7% | HAVA |
| TOFAŞ MURAT 131 (1979) | -0.65 | -0.75 | -0.67 | -0.44 | -0.26 | -0.51 | -0.6% | HAVA |
| MINI COOPER (1965) | -0.70 | -0.81 | -0.81 | -0.48 | -0.27 | -0.56 | -0.6% | HAVA |
| RENAULT TOROS | -0.62 | -0.84 | -0.75 | -0.45 | -0.27 | -0.53 | -0.6% | HAVA |
| TOFAŞ MURAT 124 (1971) | -0.78 | -0.90 | -0.86 | -0.53 | -0.31 | -0.62 | -0.6% | HAVA |
| PEUGEOT 404 (1968) | -0.80 | -0.93 | -0.84 | -0.55 | -0.32 | -0.64 | -0.7% | HAVA |
| VOLKSWAGEN BEETLE (1967) | -0.97 | -1.13 | -1.07 | -0.65 | -0.38 | -0.77 | -0.6% | HAVA |
| ANADOL A1 (1967) | -0.97 | -1.12 | -1.05 | -0.66 | -0.38 | -0.77 | -0.6% | HAVA |
| MERCEDES-BENZ W123 | -0.99 | -1.68 | -0.48 | -0.77 | -0.43 | -0.86 | -0.7% | TURBO |
| LAND ROVER SERIES III (1975) | -1.86 | -2.15 | -2.13 | -0.66 | -0.64 | -1.48 | -0.6% | HAVA |
| WILLYS JEEP MB (1944) | -2.06 | -2.37 | -2.51 | -0.95 | -0.69 | -1.65 | -0.7% | HAVA |
| FIAT 500 (1965) | -1.96 | -2.27 | -1.86 | -1.33 | -0.77 | -1.56 | -0.7% | HAVA |
| VOLKSWAGEN T1 (1965) | -2.60 | -3.00 | -2.01 | -2.44 | -1.04 | -2.07 | -0.9% | HAVA |

## 10. Veri eksiği: beygir

12 aracın katalogda `performance.hp` değeri 0. Bu araçlarda "130 → 136 bg" göstergesi çalışmaz (tablolarda
"—"). Oyuna geçmeden doldurulmalı. Öneri (üretici değerleri, PS; ⚠ işaretliler doğrulanmalı):

| Araç | Motor (katalog) | Öneri |
|---|---|---|
| BMW E46 | 3.0 | 231 (330i) |
| BMW E60 | 3.0 | 272 (530i, N52) |
| Mercedes CLS | 3.5 V6 | 306 (CLS 350) ⚠ yıl 2018 ama 3.5 V6 önceki kasada |
| Audi RS6 | 4.0 TFSI | 600 |
| Porsche 911 GT3 | 4.0 | 500 |
| Lamborghini Huracán | 5.2 V10 | 610 (LP 610-4) |
| Ferrari 488 Pista | 3.9 V8 | 720 |
| Chevrolet Camaro | 6.2 V8 | 432 (SS) |
| Mercedes S400 | 3.0 V6 Biturbo | 333 |
| Tesla Model Y | Elektrik | ~350 ⚠ (Tesla resmî değer vermiyor) |
| Tofaş Şahin | 1.6 | ⚠ doğrula |
| Renault Toros | 1.4 | ⚠ doğrula |

Beygir yalnızca göstergedir; yarış fiziğini (DragRaceSim künyesi) değiştirmez.

## 11. Oyuna geçiş planı (onaydan sonra)

Kod (GDScript, statik tipli):
1. `gameplay/race/performance_mods.gd` — tablolar, profiller, `apply(spec, build) -> EngineSpec`, ad
   tabloları (`Loc.t`). `qa/mod_report.gd`'deki ölçülmüş model buraya taşınır; rapor aracı onu kullanır.
2. `gameplay/performance_mod_manager.gd` — araç id → {kategori: kademe}; satın alma `EconomyManager.spend_money`,
   seviye kilidi `PlayerProgress`, takma süresi tamir alanı akışıyla; kayıt (`SaveManager`).
3. `DragRaceSim`: `spec_of(id)` modifiyeli künyeyi döndürür; `base_time` / `overall_of` önbelleği araç id +
   yapı anahtarıyla; `overall_of` üst sınırı kalkar; `performance_ratio` gösterilen 0-100'den.
4. `RaceManager.rival_pool` modifiyeli süreyle.
5. `ui/hud/performance_screen.gd` — garajda PERFORMANS sekmesi: 6 kategori kartı, 5 kademe çentiği
   (renkli), sıradaki parçanın adı / fiyatı / önce → sonra değeri, sınıf rozeti. Control + container.
6. Testler: `tests/performance_mod_test.gd` — 55 araç × 30 kademe: 300 m hiç uzamaz, gösterge hiç
   kötüleşmez, sınıf en fazla bir basamak atlar, Passat SOKAK MOTOR 9,72 sn, Golf SPOR LASTİK eşiği.

Sahne: `Main.tscn`'e `World/Gameplay/PerformanceModManager` düğümü gerekir. CLAUDE.md gereği bunu sen
editörde eklersin (ya da düğüm koddan kurulur; karar §12).

## 12. Onay gereken kararlar

1. **Sınıf atlama:** §5 kuralı (en fazla bir basamak, 20 araç atlar) uygun mu?
2. **Rakip:** modifiyeli süreyle eşleşme + rakip sınıfına göre ödül (öneri) mi, yoksa fabrika süresi mi
   (yükseltme = kolay galibiyet)?
3. **GENEL tavanı:** 1000'in üstüne çıkabilsin mi (öneri), yoksa S araçlar 1000'de mi dursun?
4. **Fiyat:** araç fiyatına oranlı (full ≈ 1,35 × araç) uygun mu? Daha ucuz / pahalı?
5. **Takma süresi + kilit:** SOKAK/SPOR anında, YARIŞ 1 dk / PRO 3 dk / EFSANE 6 dk tamir alanında;
   seviye 3 / 5 / 8 / 12 / 16.
6. **Beygir verileri** (§10): önerilen değerler girilsin mi, ⚠'liler için kaynak?
7. **Düğüm:** PerformanceModManager'ı `Main.tscn`'e sen mi eklersin, yoksa kodda mı kurulsun?
8. **Satış:** modifiye parasının %40'ı araç satışında geri dönsün mü?

## Ek A — Her araç, her kategori, her kademe

Hücre: gösterilen 0-100 · (MOTOR/TURBO/HAVA'da) beygir · (ŞANZIMAN'da) son hız · parça fiyatı. Birikimli
değil: o satırdaki kategori tek başına, o kademeye kadar takılıyken. Klasikte TURBO = KOMPRESÖR, HAVA =
KARBÜRATÖR & EGZOZ; elektrikte TURBO = BATARYA, HAVA = SOĞUTMA.

### LAMBORGHINI HURACÁN — S · AWD · Atmosferik · fiyat 400.000 ₺
Fabrika: 0-100 **2.9 sn** · son hız **325 km/sa** · bg **eksik** · 300 m **7.28 sn** · kalkış patinajı 1.18 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 2.90 sn · 4.800 ₺ | 2.90 sn · 9.600 ₺ | 2.90 sn · 16.800 ₺ | 2.89 sn · 28.800 ₺ | 2.89 sn · 48.000 ₺ |
| TURBO | 2.89 sn · 4.800 ₺ | 2.89 sn · 9.600 ₺ | 2.89 sn · 16.800 ₺ | 2.89 sn · 28.800 ₺ | 2.89 sn · 48.000 ₺ |
| HAVA | 2.89 sn · 3.200 ₺ | 2.89 sn · 6.400 ₺ | 2.88 sn · 11.200 ₺ | 2.88 sn · 19.200 ₺ | 2.87 sn · 32.000 ₺ |
| ŞANZ. | 2.87 sn · 328 km/sa · 4.000 ₺ | 2.85 sn · 330 km/sa · 8.000 ₺ | 2.82 sn · 333 km/sa · 14.000 ₺ | 2.80 sn · 338 km/sa · 24.000 ₺ | 2.77 sn · 341 km/sa · 40.000 ₺ |
| LASTİK | 2.82 sn · 3.200 ₺ | 2.73 sn · 6.400 ₺ | 2.65 sn · 11.200 ₺ | 2.58 sn · 19.200 ₺ | 2.51 sn · 32.000 ₺ |
| GÖVDE | 2.90 sn · 4.000 ₺ | 2.90 sn · 8.000 ₺ | 2.90 sn · 14.000 ₺ | 2.90 sn · 24.000 ₺ | 2.89 sn · 40.000 ₺ |

**FULL:** 0-100 2.37 sn · 364 km/sa · bg — · 300 m 6.65 sn → sınıf **S**

### FERRARI 488 PISTA — S · RWD · Atmosferik · fiyat 450.000 ₺
Fabrika: 0-100 **2.9 sn** · son hız **340 km/sa** · bg **eksik** · 300 m **7.44 sn** · kalkış patinajı 1.05 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 2.90 sn · 5.400 ₺ | 2.90 sn · 10.800 ₺ | 2.90 sn · 18.900 ₺ | 2.90 sn · 32.400 ₺ | 2.90 sn · 54.000 ₺ |
| TURBO | 2.90 sn · 5.400 ₺ | 2.90 sn · 10.800 ₺ | 2.90 sn · 18.900 ₺ | 2.90 sn · 32.400 ₺ | 2.90 sn · 54.000 ₺ |
| HAVA | 2.89 sn · 3.600 ₺ | 2.88 sn · 7.200 ₺ | 2.88 sn · 12.600 ₺ | 2.87 sn · 21.600 ₺ | 2.87 sn · 36.000 ₺ |
| ŞANZ. | 2.87 sn · 343 km/sa · 4.500 ₺ | 2.84 sn · 345 km/sa · 9.000 ₺ | 2.82 sn · 348 km/sa · 15.750 ₺ | 2.81 sn · 354 km/sa · 27.000 ₺ | 2.78 sn · 357 km/sa · 45.000 ₺ |
| LASTİK | 2.82 sn · 3.600 ₺ | 2.73 sn · 7.200 ₺ | 2.66 sn · 12.600 ₺ | 2.60 sn · 21.600 ₺ | 2.54 sn · 36.000 ₺ |
| GÖVDE | 2.90 sn · 4.500 ₺ | 2.90 sn · 9.000 ₺ | 2.90 sn · 15.750 ₺ | 2.90 sn · 27.000 ₺ | 2.90 sn · 45.000 ₺ |

**FULL:** 0-100 2.39 sn · 381 km/sa · bg — · 300 m 6.82 sn → sınıf **S**

### PORSCHE 911 GT3 — S · RWD · Atmosferik · fiyat 300.000 ₺
Fabrika: 0-100 **3.4 sn** · son hız **311 km/sa** · bg **eksik** · 300 m **7.84 sn** · kalkış patinajı 1.30 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 3.40 sn · 3.600 ₺ | 3.40 sn · 7.200 ₺ | 3.40 sn · 12.600 ₺ | 3.40 sn · 21.600 ₺ | 3.40 sn · 36.000 ₺ |
| TURBO | 3.40 sn · 3.600 ₺ | 3.40 sn · 7.200 ₺ | 3.40 sn · 12.600 ₺ | 3.40 sn · 21.600 ₺ | 3.40 sn · 36.000 ₺ |
| HAVA | 3.39 sn · 2.400 ₺ | 3.39 sn · 4.800 ₺ | 3.39 sn · 8.400 ₺ | 3.38 sn · 14.400 ₺ | 3.37 sn · 24.000 ₺ |
| ŞANZ. | 3.37 sn · 313 km/sa · 3.000 ₺ | 3.35 sn · 316 km/sa · 6.000 ₺ | 3.32 sn · 318 km/sa · 10.500 ₺ | 3.30 sn · 323 km/sa · 18.000 ₺ | 3.28 sn · 327 km/sa · 30.000 ₺ |
| LASTİK | 3.30 sn · 2.400 ₺ | 3.20 sn · 4.800 ₺ | 3.10 sn · 8.400 ₺ | 3.01 sn · 14.400 ₺ | 2.94 sn · 24.000 ₺ |
| GÖVDE | 3.40 sn · 3.000 ₺ | 3.40 sn · 6.000 ₺ | 3.40 sn · 10.500 ₺ | 3.40 sn · 18.000 ₺ | 3.40 sn · 30.000 ₺ |

**FULL:** 0-100 2.80 sn · 348 km/sa · bg — · 300 m 7.18 sn → sınıf **S**

### AUDI RS6 — S · AWD · Turbo benzin · fiyat 220.000 ₺
Fabrika: 0-100 **3.9 sn** · son hız **305 km/sa** · bg **eksik** · 300 m **8.36 sn** · kalkış patinajı 1.22 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 3.89 sn · 2.650 ₺ | 3.89 sn · 5.300 ₺ | 3.88 sn · 9.250 ₺ | 3.87 sn · 15.850 ₺ | 3.87 sn · 26.400 ₺ |
| TURBO | 3.90 sn · 2.650 ₺ | 3.89 sn · 5.300 ₺ | 3.88 sn · 9.250 ₺ | 3.87 sn · 15.850 ₺ | 3.86 sn · 26.400 ₺ |
| HAVA | 3.89 sn · 1.750 ₺ | 3.88 sn · 3.500 ₺ | 3.87 sn · 6.150 ₺ | 3.87 sn · 10.550 ₺ | 3.85 sn · 17.600 ₺ |
| ŞANZ. | 3.87 sn · 307 km/sa · 2.200 ₺ | 3.85 sn · 310 km/sa · 4.400 ₺ | 3.81 sn · 312 km/sa · 7.700 ₺ | 3.78 sn · 317 km/sa · 13.200 ₺ | 3.77 sn · 320 km/sa · 22.000 ₺ |
| LASTİK | 3.81 sn · 1.750 ₺ | 3.69 sn · 3.500 ₺ | 3.59 sn · 6.150 ₺ | 3.50 sn · 10.550 ₺ | 3.41 sn · 17.600 ₺ |
| GÖVDE | 3.90 sn · 2.200 ₺ | 3.89 sn · 4.400 ₺ | 3.89 sn · 7.700 ₺ | 3.89 sn · 13.200 ₺ | 3.88 sn · 22.000 ₺ |

**FULL:** 0-100 3.19 sn · 343 km/sa · bg — · 300 m 7.65 sn → sınıf **S**

### CHEVROLET CAMARO — S · RWD · Atmosferik · fiyat 140.000 ₺
Fabrika: 0-100 **4.0 sn** · son hız **250 km/sa** · bg **eksik** · 300 m **8.37 sn** · kalkış patinajı 1.48 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 4.00 sn · 1.700 ₺ | 4.00 sn · 3.350 ₺ | 4.00 sn · 5.900 ₺ | 4.00 sn · 10.100 ₺ | 4.00 sn · 16.800 ₺ |
| TURBO | 4.00 sn · 1.700 ₺ | 4.00 sn · 3.350 ₺ | 4.00 sn · 5.900 ₺ | 4.00 sn · 10.100 ₺ | 4.00 sn · 16.800 ₺ |
| HAVA | 3.99 sn · 1.100 ₺ | 3.99 sn · 2.250 ₺ | 3.97 sn · 3.900 ₺ | 3.97 sn · 6.700 ₺ | 3.97 sn · 11.200 ₺ |
| ŞANZ. | 3.97 sn · 252 km/sa · 1.400 ₺ | 3.94 sn · 254 km/sa · 2.800 ₺ | 3.90 sn · 256 km/sa · 4.900 ₺ | 3.90 sn · 260 km/sa · 8.400 ₺ | 3.87 sn · 262 km/sa · 14.000 ₺ |
| LASTİK | 3.89 sn · 1.100 ₺ | 3.75 sn · 2.250 ₺ | 3.65 sn · 3.900 ₺ | 3.57 sn · 6.700 ₺ | 3.49 sn · 11.200 ₺ |
| GÖVDE | 4.00 sn · 1.400 ₺ | 4.00 sn · 2.800 ₺ | 4.00 sn · 4.900 ₺ | 4.00 sn · 8.400 ₺ | 4.00 sn · 14.000 ₺ |

**FULL:** 0-100 3.31 sn · 280 km/sa · bg — · 300 m 7.67 sn → sınıf **S**

### MITSUBISHI LANCER EVO VI — A · AWD · Turbo benzin · fiyat 62.500 ₺
Fabrika: 0-100 **4.4 sn** · son hız **240 km/sa** · **280 bg** · 300 m **8.94 sn** · kalkış patinajı 0.99 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 4.38 sn · 284 bg · 750 ₺ | 4.38 sn · 287 bg · 1.500 ₺ | 4.37 sn · 290 bg · 2.600 ₺ | 4.35 sn · 293 bg · 4.500 ₺ | 4.34 sn · 295 bg · 7.500 ₺ |
| TURBO | 4.38 sn · 283 bg · 750 ₺ | 4.37 sn · 287 bg · 1.500 ₺ | 4.36 sn · 290 bg · 2.600 ₺ | 4.34 sn · 294 bg · 4.500 ₺ | 4.33 sn · 298 bg · 7.500 ₺ |
| HAVA | 4.38 sn · 283 bg · 500 ₺ | 4.37 sn · 286 bg · 1.000 ₺ | 4.35 sn · 289 bg · 1.750 ₺ | 4.34 sn · 292 bg · 3.000 ₺ | 4.30 sn · 295 bg · 5.000 ₺ |
| ŞANZ. | 4.36 sn · 242 km/sa · 600 ₺ | 4.32 sn · 244 km/sa · 1.250 ₺ | 4.27 sn · 246 km/sa · 2.200 ₺ | 4.26 sn · 250 km/sa · 3.750 ₺ | 4.22 sn · 252 km/sa · 6.250 ₺ |
| LASTİK | 4.32 sn · 500 ₺ | 4.20 sn · 1.000 ₺ | 4.12 sn · 1.750 ₺ | 4.03 sn · 3.000 ₺ | 3.97 sn · 5.000 ₺ |
| GÖVDE | 4.39 sn · 600 ₺ | 4.38 sn · 1.250 ₺ | 4.38 sn · 2.200 ₺ | 4.38 sn · 3.750 ₺ | 4.37 sn · 6.250 ₺ |

**FULL:** 0-100 3.55 sn · 270 km/sa · 331 bg · 300 m 8.21 sn → sınıf **S**

### AUDI SPORT QUATTRO S1 — A · AWD · Turbo benzin · fiyat 62.500 ₺
Fabrika: 0-100 **4.8 sn** · son hız **250 km/sa** · **306 bg** · 300 m **9.34 sn** · kalkış patinajı 0.80 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 4.77 sn · 311 bg · 750 ₺ | 4.75 sn · 314 bg · 1.500 ₺ | 4.74 sn · 317 bg · 2.600 ₺ | 4.72 sn · 320 bg · 4.500 ₺ | 4.71 sn · 322 bg · 7.500 ₺ |
| TURBO | 4.78 sn · 309 bg · 750 ₺ | 4.75 sn · 313 bg · 1.500 ₺ | 4.73 sn · 317 bg · 2.600 ₺ | 4.71 sn · 322 bg · 4.500 ₺ | 4.69 sn · 326 bg · 7.500 ₺ |
| HAVA | 4.78 sn · 309 bg · 500 ₺ | 4.74 sn · 313 bg · 1.000 ₺ | 4.73 sn · 316 bg · 1.750 ₺ | 4.70 sn · 319 bg · 3.000 ₺ | 4.68 sn · 323 bg · 5.000 ₺ |
| ŞANZ. | 4.76 sn · 252 km/sa · 600 ₺ | 4.71 sn · 254 km/sa · 1.250 ₺ | 4.67 sn · 256 km/sa · 2.200 ₺ | 4.64 sn · 260 km/sa · 3.750 ₺ | 4.59 sn · 262 km/sa · 6.250 ₺ |
| LASTİK | 4.72 sn · 500 ₺ | 4.63 sn · 1.000 ₺ | 4.24 sn · 1.750 ₺ | 4.23 sn · 3.000 ₺ | 4.21 sn · 5.000 ₺ |
| GÖVDE | 4.79 sn · 600 ₺ | 4.77 sn · 1.250 ₺ | 4.77 sn · 2.200 ₺ | 4.75 sn · 3.750 ₺ | 4.74 sn · 6.250 ₺ |

**FULL:** 0-100 3.84 sn · 281 km/sa · 361 bg · 300 m 8.58 sn → sınıf **A**

### TESLA MODEL Y — A · AWD · Elektrik · fiyat 110.000 ₺
Fabrika: 0-100 **5.0 sn** · son hız **217 km/sa** · bg **eksik** · 300 m **9.43 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 4.93 sn · 1.300 ₺ | 4.87 sn · 2.650 ₺ | 4.83 sn · 4.600 ₺ | 4.79 sn · 7.900 ₺ | 4.75 sn · 13.200 ₺ |
| TURBO | 4.96 sn · 1.300 ₺ | 4.91 sn · 2.650 ₺ | 4.86 sn · 4.600 ₺ | 4.80 sn · 7.900 ₺ | 4.76 sn · 13.200 ₺ |
| HAVA | 4.99 sn · 900 ₺ | 4.99 sn · 1.750 ₺ | 4.98 sn · 3.100 ₺ | 4.97 sn · 5.300 ₺ | 4.96 sn · 8.800 ₺ |
| ŞANZ. | 4.96 sn · 219 km/sa · 1.100 ₺ | 4.93 sn · 220 km/sa · 2.200 ₺ | 4.88 sn · 222 km/sa · 3.850 ₺ | 4.79 sn · 226 km/sa · 6.600 ₺ | 4.75 sn · 228 km/sa · 11.000 ₺ |
| LASTİK | 5.00 sn · 900 ₺ | 4.97 sn · 1.750 ₺ | 4.95 sn · 3.100 ₺ | 4.93 sn · 5.300 ₺ | 4.92 sn · 8.800 ₺ |
| GÖVDE | 4.97 sn · 1.100 ₺ | 4.93 sn · 2.200 ₺ | 4.90 sn · 3.850 ₺ | 4.87 sn · 6.600 ₺ | 4.83 sn · 11.000 ₺ |

**FULL:** 0-100 4.04 sn · 239 km/sa · bg — · 300 m 8.76 sn → sınıf **A**

### MERCEDES S400 — A · RWD · Turbo benzin · fiyat 170.000 ₺
Fabrika: 0-100 **5.3 sn** · son hız **250 km/sa** · bg **eksik** · 300 m **9.50 sn** · kalkış patinajı 1.69 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 5.28 sn · 2.050 ₺ | 5.27 sn · 4.100 ₺ | 5.26 sn · 7.150 ₺ | 5.26 sn · 12.250 ₺ | 5.25 sn · 20.400 ₺ |
| TURBO | 5.29 sn · 2.050 ₺ | 5.27 sn · 4.100 ₺ | 5.26 sn · 7.150 ₺ | 5.24 sn · 12.250 ₺ | 5.23 sn · 20.400 ₺ |
| HAVA | 5.28 sn · 1.350 ₺ | 5.27 sn · 2.700 ₺ | 5.27 sn · 4.750 ₺ | 5.25 sn · 8.150 ₺ | 5.24 sn · 13.600 ₺ |
| ŞANZ. | 5.27 sn · 252 km/sa · 1.700 ₺ | 5.25 sn · 254 km/sa · 3.400 ₺ | 5.20 sn · 256 km/sa · 5.950 ₺ | 5.18 sn · 260 km/sa · 10.200 ₺ | 5.16 sn · 262 km/sa · 17.000 ₺ |
| LASTİK | 5.17 sn · 1.350 ₺ | 5.01 sn · 2.700 ₺ | 4.87 sn · 4.750 ₺ | 4.74 sn · 8.150 ₺ | 4.62 sn · 13.600 ₺ |
| GÖVDE | 5.29 sn · 1.700 ₺ | 5.28 sn · 3.400 ₺ | 5.28 sn · 5.950 ₺ | 5.27 sn · 10.200 ₺ | 5.26 sn · 17.000 ₺ |

**FULL:** 0-100 4.35 sn · 281 km/sa · bg — · 300 m 8.72 sn → sınıf **A**

### PORSCHE 911 CARRERA RS (1973) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **5.8 sn** · son hız **245 km/sa** · **210 bg** · 300 m **9.85 sn** · kalkış patinajı 1.71 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 5.79 sn · 213 bg · 750 ₺ | 5.79 sn · 215 bg · 1.500 ₺ | 5.79 sn · 217 bg · 2.600 ₺ | 5.78 sn · 218 bg · 4.500 ₺ | 5.78 sn · 220 bg · 7.500 ₺ |
| TURBO | 5.80 sn · 212 bg · 750 ₺ | 5.79 sn · 214 bg · 1.500 ₺ | 5.79 sn · 217 bg · 2.600 ₺ | 5.79 sn · 219 bg · 4.500 ₺ | 5.78 sn · 221 bg · 7.500 ₺ |
| HAVA | 5.78 sn · 213 bg · 500 ₺ | 5.77 sn · 215 bg · 1.000 ₺ | 5.76 sn · 218 bg · 1.750 ₺ | 5.73 sn · 220 bg · 3.000 ₺ | 5.73 sn · 223 bg · 5.000 ₺ |
| ŞANZ. | 5.75 sn · 247 km/sa · 600 ₺ | 5.71 sn · 249 km/sa · 1.250 ₺ | 5.65 sn · 251 km/sa · 2.200 ₺ | 5.63 sn · 255 km/sa · 3.750 ₺ | 5.60 sn · 257 km/sa · 6.250 ₺ |
| LASTİK | 5.65 sn · 500 ₺ | 5.47 sn · 1.000 ₺ | 5.34 sn · 1.750 ₺ | 5.23 sn · 3.000 ₺ | 5.13 sn · 5.000 ₺ |
| GÖVDE | 5.80 sn · 600 ₺ | 5.79 sn · 1.250 ₺ | 5.79 sn · 2.200 ₺ | 5.79 sn · 3.750 ₺ | 5.78 sn · 6.250 ₺ |

**FULL:** 0-100 4.75 sn · 274 km/sa · 246 bg · 300 m 9.08 sn → sınıf **A**

### LANCIA DELTA INTEGRALE — A · AWD · Turbo benzin · fiyat 62.500 ₺
Fabrika: 0-100 **5.7 sn** · son hız **220 km/sa** · **210 bg** · 300 m **9.93 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 5.62 sn · 213 bg · 750 ₺ | 5.56 sn · 216 bg · 1.500 ₺ | 5.51 sn · 218 bg · 2.600 ₺ | 5.47 sn · 219 bg · 4.500 ₺ | 5.43 sn · 221 bg · 7.500 ₺ |
| TURBO | 5.64 sn · 212 bg · 750 ₺ | 5.58 sn · 215 bg · 1.500 ₺ | 5.51 sn · 218 bg · 2.600 ₺ | 5.42 sn · 221 bg · 4.500 ₺ | 5.35 sn · 224 bg · 7.500 ₺ |
| HAVA | 5.65 sn · 212 bg · 500 ₺ | 5.61 sn · 215 bg · 1.000 ₺ | 5.56 sn · 217 bg · 1.750 ₺ | 5.51 sn · 219 bg · 3.000 ₺ | 5.46 sn · 221 bg · 5.000 ₺ |
| ŞANZ. | 5.65 sn · 222 km/sa · 600 ₺ | 5.60 sn · 224 km/sa · 1.250 ₺ | 5.55 sn · 225 km/sa · 2.200 ₺ | 5.47 sn · 229 km/sa · 3.750 ₺ | 5.42 sn · 231 km/sa · 6.250 ₺ |
| LASTİK | 5.70 sn · 500 ₺ | 5.66 sn · 1.000 ₺ | 5.64 sn · 1.750 ₺ | 5.62 sn · 3.000 ₺ | 5.60 sn · 5.000 ₺ |
| GÖVDE | 5.66 sn · 600 ₺ | 5.62 sn · 1.250 ₺ | 5.59 sn · 2.200 ₺ | 5.55 sn · 3.750 ₺ | 5.51 sn · 6.250 ₺ |

**FULL:** 0-100 4.41 sn · 247 km/sa · 248 bg · 300 m 9.12 sn → sınıf **A**

### FORD RS200 — A · AWD · Turbo benzin · fiyat 62.500 ₺
Fabrika: 0-100 **6.1 sn** · son hız **225 km/sa** · **250 bg** · 300 m **10.17 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.01 sn · 254 bg · 750 ₺ | 5.95 sn · 257 bg · 1.500 ₺ | 5.90 sn · 259 bg · 2.600 ₺ | 5.85 sn · 261 bg · 4.500 ₺ | 5.81 sn · 263 bg · 7.500 ₺ |
| TURBO | 6.04 sn · 253 bg · 750 ₺ | 5.97 sn · 256 bg · 1.500 ₺ | 5.89 sn · 259 bg · 2.600 ₺ | 5.82 sn · 263 bg · 4.500 ₺ | 5.75 sn · 266 bg · 7.500 ₺ |
| HAVA | 6.06 sn · 253 bg · 500 ₺ | 6.01 sn · 255 bg · 1.000 ₺ | 5.95 sn · 258 bg · 1.750 ₺ | 5.91 sn · 261 bg · 3.000 ₺ | 5.86 sn · 264 bg · 5.000 ₺ |
| ŞANZ. | 6.06 sn · 227 km/sa · 600 ₺ | 6.01 sn · 229 km/sa · 1.250 ₺ | 5.95 sn · 230 km/sa · 2.200 ₺ | 5.87 sn · 234 km/sa · 3.750 ₺ | 5.82 sn · 236 km/sa · 6.250 ₺ |
| LASTİK | 6.10 sn · 500 ₺ | 6.06 sn · 1.000 ₺ | 6.04 sn · 1.750 ₺ | 6.01 sn · 3.000 ₺ | 6.00 sn · 5.000 ₺ |
| GÖVDE | 6.06 sn · 600 ₺ | 6.02 sn · 1.250 ₺ | 5.98 sn · 2.200 ₺ | 5.94 sn · 3.750 ₺ | 5.90 sn · 6.250 ₺ |

**FULL:** 0-100 4.72 sn · 253 km/sa · 295 bg · 300 m 9.33 sn → sınıf **A**

### CHEVROLET CORVETTE C2 (1963) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **6.3 sn** · son hız **225 km/sa** · **360 bg** · 300 m **10.22 sn** · kalkış patinajı 1.55 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.28 sn · 365 bg · 750 ₺ | 6.26 sn · 368 bg · 1.500 ₺ | 6.24 sn · 371 bg · 2.600 ₺ | 6.22 sn · 374 bg · 4.500 ₺ | 6.21 sn · 377 bg · 7.500 ₺ |
| TURBO | 6.28 sn · 363 bg · 750 ₺ | 6.26 sn · 367 bg · 1.500 ₺ | 6.24 sn · 371 bg · 2.600 ₺ | 6.21 sn · 375 bg · 4.500 ₺ | 6.19 sn · 379 bg · 7.500 ₺ |
| HAVA | 6.28 sn · 364 bg · 500 ₺ | 6.25 sn · 369 bg · 1.000 ₺ | 6.22 sn · 373 bg · 1.750 ₺ | 6.19 sn · 377 bg · 3.000 ₺ | 6.18 sn · 382 bg · 5.000 ₺ |
| ŞANZ. | 6.26 sn · 227 km/sa · 600 ₺ | 6.23 sn · 229 km/sa · 1.250 ₺ | 6.16 sn · 230 km/sa · 2.200 ₺ | 6.13 sn · 234 km/sa · 3.750 ₺ | 6.09 sn · 236 km/sa · 6.250 ₺ |
| LASTİK | 6.18 sn · 500 ₺ | 6.01 sn · 1.000 ₺ | 5.88 sn · 1.750 ₺ | 5.75 sn · 3.000 ₺ | 5.64 sn · 5.000 ₺ |
| GÖVDE | 6.28 sn · 600 ₺ | 6.28 sn · 1.250 ₺ | 6.25 sn · 2.200 ₺ | 6.25 sn · 3.750 ₺ | 6.23 sn · 6.250 ₺ |

**FULL:** 0-100 5.13 sn · 252 km/sa · 421 bg · 300 m 9.42 sn → sınıf **A**

### BMW E46 — A · RWD · Atmosferik · fiyat 85.000 ₺
Fabrika: 0-100 **6.5 sn** · son hız **250 km/sa** · bg **eksik** · 300 m **10.34 sn** · kalkış patinajı 1.11 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.48 sn · 1.000 ₺ | 6.45 sn · 2.050 ₺ | 6.44 sn · 3.550 ₺ | 6.42 sn · 6.100 ₺ | 6.41 sn · 10.200 ₺ |
| TURBO | 6.48 sn · 1.000 ₺ | 6.45 sn · 2.050 ₺ | 6.43 sn · 3.550 ₺ | 6.40 sn · 6.100 ₺ | 6.37 sn · 10.200 ₺ |
| HAVA | 6.44 sn · 700 ₺ | 6.40 sn · 1.350 ₺ | 6.37 sn · 2.400 ₺ | 6.32 sn · 4.100 ₺ | 6.27 sn · 6.800 ₺ |
| ŞANZ. | 6.46 sn · 252 km/sa · 850 ₺ | 6.42 sn · 254 km/sa · 1.700 ₺ | 6.35 sn · 256 km/sa · 3.000 ₺ | 6.34 sn · 260 km/sa · 5.100 ₺ | 6.32 sn · 262 km/sa · 8.500 ₺ |
| LASTİK | 6.06 sn · 700 ₺ | 5.80 sn · 1.350 ₺ | 5.77 sn · 2.400 ₺ | 5.76 sn · 4.100 ₺ | 5.73 sn · 6.800 ₺ |
| GÖVDE | 6.48 sn · 850 ₺ | 6.47 sn · 1.700 ₺ | 6.45 sn · 3.000 ₺ | 6.44 sn · 5.100 ₺ | 6.42 sn · 8.500 ₺ |

**FULL:** 0-100 5.26 sn · 280 km/sa · bg — · 300 m 9.53 sn → sınıf **A**

### BMW E60 — A · RWD · Atmosferik · fiyat 120.000 ₺
Fabrika: 0-100 **6.5 sn** · son hız **250 km/sa** · bg **eksik** · 300 m **10.37 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.42 sn · 1.450 ₺ | 6.37 sn · 2.900 ₺ | 6.32 sn · 5.050 ₺ | 6.28 sn · 8.650 ₺ | 6.24 sn · 14.400 ₺ |
| TURBO | 6.43 sn · 1.450 ₺ | 6.35 sn · 2.900 ₺ | 6.29 sn · 5.050 ₺ | 6.22 sn · 8.650 ₺ | 6.15 sn · 14.400 ₺ |
| HAVA | 6.44 sn · 950 ₺ | 6.38 sn · 1.900 ₺ | 6.31 sn · 3.350 ₺ | 6.26 sn · 5.750 ₺ | 6.21 sn · 9.600 ₺ |
| ŞANZ. | 6.46 sn · 252 km/sa · 1.200 ₺ | 6.43 sn · 254 km/sa · 2.400 ₺ | 6.37 sn · 256 km/sa · 4.200 ₺ | 6.27 sn · 260 km/sa · 7.200 ₺ | 6.22 sn · 262 km/sa · 12.000 ₺ |
| LASTİK | 6.50 sn · 950 ₺ | 6.46 sn · 1.900 ₺ | 6.43 sn · 3.350 ₺ | 6.41 sn · 5.750 ₺ | 6.39 sn · 9.600 ₺ |
| GÖVDE | 6.46 sn · 1.200 ₺ | 6.41 sn · 2.400 ₺ | 6.37 sn · 4.200 ₺ | 6.32 sn · 7.200 ₺ | 6.28 sn · 12.000 ₺ |

**FULL:** 0-100 5.11 sn · 280 km/sa · bg — · 300 m 9.50 sn → sınıf **A**

### BMW M3 E30 — A · RWD · Atmosferik · fiyat 62.500 ₺
Fabrika: 0-100 **6.6 sn** · son hız **241 km/sa** · **215 bg** · 300 m **10.41 sn** · kalkış patinajı 1.25 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.57 sn · 218 bg · 750 ₺ | 6.55 sn · 220 bg · 1.500 ₺ | 6.54 sn · 221 bg · 2.600 ₺ | 6.52 sn · 223 bg · 4.500 ₺ | 6.51 sn · 224 bg · 7.500 ₺ |
| TURBO | 6.58 sn · 217 bg · 750 ₺ | 6.56 sn · 219 bg · 1.500 ₺ | 6.54 sn · 222 bg · 2.600 ₺ | 6.51 sn · 224 bg · 4.500 ₺ | 6.48 sn · 227 bg · 7.500 ₺ |
| HAVA | 6.57 sn · 218 bg · 500 ₺ | 6.53 sn · 221 bg · 1.000 ₺ | 6.48 sn · 224 bg · 1.750 ₺ | 6.44 sn · 227 bg · 3.000 ₺ | 6.41 sn · 230 bg · 5.000 ₺ |
| ŞANZ. | 6.56 sn · 243 km/sa · 600 ₺ | 6.53 sn · 245 km/sa · 1.250 ₺ | 6.46 sn · 247 km/sa · 2.200 ₺ | 6.44 sn · 251 km/sa · 3.750 ₺ | 6.41 sn · 253 km/sa · 6.250 ₺ |
| LASTİK | 6.48 sn · 500 ₺ | 6.32 sn · 1.000 ₺ | 6.20 sn · 1.750 ₺ | 5.79 sn · 3.000 ₺ | 5.60 sn · 5.000 ₺ |
| GÖVDE | 6.59 sn · 600 ₺ | 6.57 sn · 1.250 ₺ | 6.55 sn · 2.200 ₺ | 6.54 sn · 3.750 ₺ | 6.52 sn · 6.250 ₺ |

**FULL:** 0-100 5.34 sn · 270 km/sa · 252 bg · 300 m 9.58 sn → sınıf **A**

### LAMBORGHINI MIURA (1968) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **6.7 sn** · son hız **280 km/sa** · **350 bg** · 300 m **10.43 sn** · kalkış patinajı 1.34 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.68 sn · 355 bg · 750 ₺ | 6.66 sn · 358 bg · 1.500 ₺ | 6.64 sn · 361 bg · 2.600 ₺ | 6.63 sn · 364 bg · 4.500 ₺ | 6.61 sn · 366 bg · 7.500 ₺ |
| TURBO | 6.68 sn · 353 bg · 750 ₺ | 6.66 sn · 357 bg · 1.500 ₺ | 6.64 sn · 361 bg · 2.600 ₺ | 6.62 sn · 365 bg · 4.500 ₺ | 6.60 sn · 369 bg · 7.500 ₺ |
| HAVA | 6.67 sn · 354 bg · 500 ₺ | 6.64 sn · 358 bg · 1.000 ₺ | 6.60 sn · 363 bg · 1.750 ₺ | 6.57 sn · 367 bg · 3.000 ₺ | 6.54 sn · 371 bg · 5.000 ₺ |
| ŞANZ. | 6.66 sn · 282 km/sa · 600 ₺ | 6.62 sn · 284 km/sa · 1.250 ₺ | 6.55 sn · 287 km/sa · 2.200 ₺ | 6.54 sn · 291 km/sa · 3.750 ₺ | 6.51 sn · 294 km/sa · 6.250 ₺ |
| LASTİK | 6.57 sn · 500 ₺ | 6.41 sn · 1.000 ₺ | 6.28 sn · 1.750 ₺ | 6.16 sn · 3.000 ₺ | 5.76 sn · 5.000 ₺ |
| GÖVDE | 6.69 sn · 600 ₺ | 6.67 sn · 1.250 ₺ | 6.66 sn · 2.200 ₺ | 6.64 sn · 3.750 ₺ | 6.63 sn · 6.250 ₺ |

**FULL:** 0-100 5.46 sn · 313 km/sa · 409 bg · 300 m 9.63 sn → sınıf **A**

### DODGE CHARGER (1970) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **6.7 sn** · son hız **210 km/sa** · **375 bg** · 300 m **10.50 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.61 sn · 380 bg · 750 ₺ | 6.55 sn · 384 bg · 1.500 ₺ | 6.50 sn · 387 bg · 2.600 ₺ | 6.45 sn · 390 bg · 4.500 ₺ | 6.41 sn · 392 bg · 7.500 ₺ |
| TURBO | 6.64 sn · 378 bg · 750 ₺ | 6.57 sn · 382 bg · 1.500 ₺ | 6.50 sn · 387 bg · 2.600 ₺ | 6.43 sn · 391 bg · 4.500 ₺ | 6.36 sn · 395 bg · 7.500 ₺ |
| HAVA | 6.63 sn · 379 bg · 500 ₺ | 6.58 sn · 384 bg · 1.000 ₺ | 6.52 sn · 388 bg · 1.750 ₺ | 6.46 sn · 393 bg · 3.000 ₺ | 6.41 sn · 398 bg · 5.000 ₺ |
| ŞANZ. | 6.66 sn · 212 km/sa · 600 ₺ | 6.63 sn · 213 km/sa · 1.250 ₺ | 6.55 sn · 215 km/sa · 2.200 ₺ | 6.46 sn · 218 km/sa · 3.750 ₺ | 6.41 sn · 220 km/sa · 6.250 ₺ |
| LASTİK | 6.70 sn · 500 ₺ | 6.65 sn · 1.000 ₺ | 6.63 sn · 1.750 ₺ | 6.60 sn · 3.000 ₺ | 6.58 sn · 5.000 ₺ |
| GÖVDE | 6.65 sn · 600 ₺ | 6.61 sn · 1.250 ₺ | 6.56 sn · 2.200 ₺ | 6.52 sn · 3.750 ₺ | 6.47 sn · 6.250 ₺ |

**FULL:** 0-100 5.29 sn · 235 km/sa · 438 bg · 300 m 9.65 sn → sınıf **A**

### MERCEDES CLS — A · RWD · Atmosferik · fiyat 150.000 ₺
Fabrika: 0-100 **6.7 sn** · son hız **250 km/sa** · bg **eksik** · 300 m **10.57 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.62 sn · 1.800 ₺ | 6.56 sn · 3.600 ₺ | 6.51 sn · 6.300 ₺ | 6.47 sn · 10.800 ₺ | 6.43 sn · 18.000 ₺ |
| TURBO | 6.64 sn · 1.800 ₺ | 6.57 sn · 3.600 ₺ | 6.49 sn · 6.300 ₺ | 6.41 sn · 10.800 ₺ | 6.34 sn · 18.000 ₺ |
| HAVA | 6.64 sn · 1.200 ₺ | 6.58 sn · 2.400 ₺ | 6.52 sn · 4.200 ₺ | 6.47 sn · 7.200 ₺ | 6.41 sn · 12.000 ₺ |
| ŞANZ. | 6.67 sn · 252 km/sa · 1.500 ₺ | 6.64 sn · 254 km/sa · 3.000 ₺ | 6.58 sn · 256 km/sa · 5.250 ₺ | 6.47 sn · 260 km/sa · 9.000 ₺ | 6.42 sn · 262 km/sa · 15.000 ₺ |
| LASTİK | 6.70 sn · 1.200 ₺ | 6.65 sn · 2.400 ₺ | 6.63 sn · 4.200 ₺ | 6.60 sn · 7.200 ₺ | 6.58 sn · 12.000 ₺ |
| GÖVDE | 6.65 sn · 1.500 ₺ | 6.61 sn · 3.000 ₺ | 6.56 sn · 5.250 ₺ | 6.51 sn · 9.000 ₺ | 6.47 sn · 15.000 ₺ |

**FULL:** 0-100 5.28 sn · 280 km/sa · bg — · 300 m 9.68 sn → sınıf **A**

### LANCIA STRATOS HF (1974) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **6.8 sn** · son hız **232 km/sa** · **190 bg** · 300 m **10.59 sn** · kalkış patinajı 1.23 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.76 sn · 193 bg · 750 ₺ | 6.73 sn · 194 bg · 1.500 ₺ | 6.70 sn · 196 bg · 2.600 ₺ | 6.68 sn · 198 bg · 4.500 ₺ | 6.66 sn · 199 bg · 7.500 ₺ |
| TURBO | 6.77 sn · 192 bg · 750 ₺ | 6.74 sn · 194 bg · 1.500 ₺ | 6.70 sn · 196 bg · 2.600 ₺ | 6.67 sn · 198 bg · 4.500 ₺ | 6.64 sn · 200 bg · 7.500 ₺ |
| HAVA | 6.75 sn · 192 bg · 500 ₺ | 6.72 sn · 195 bg · 1.000 ₺ | 6.68 sn · 197 bg · 1.750 ₺ | 6.65 sn · 199 bg · 3.000 ₺ | 6.61 sn · 201 bg · 5.000 ₺ |
| ŞANZ. | 6.74 sn · 234 km/sa · 600 ₺ | 6.70 sn · 236 km/sa · 1.250 ₺ | 6.63 sn · 238 km/sa · 2.200 ₺ | 6.60 sn · 241 km/sa · 3.750 ₺ | 6.56 sn · 244 km/sa · 6.250 ₺ |
| LASTİK | 6.69 sn · 500 ₺ | 6.55 sn · 1.000 ₺ | 6.43 sn · 1.750 ₺ | 6.31 sn · 3.000 ₺ | 6.22 sn · 5.000 ₺ |
| GÖVDE | 6.78 sn · 600 ₺ | 6.75 sn · 1.250 ₺ | 6.73 sn · 2.200 ₺ | 6.71 sn · 3.750 ₺ | 6.69 sn · 6.250 ₺ |

**FULL:** 0-100 5.48 sn · 260 km/sa · 222 bg · 300 m 9.78 sn → sınıf **A**

### VW BEETLE — A · FWD · Turbo benzin · fiyat 80.000 ₺
Fabrika: 0-100 **6.9 sn** · son hız **229 km/sa** · **220 bg** · 300 m **10.59 sn** · kalkış patinajı 2.01 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.90 sn · 223 bg · 950 ₺ | 6.89 sn · 226 bg · 1.900 ₺ | 6.89 sn · 228 bg · 3.350 ₺ | 6.89 sn · 230 bg · 5.750 ₺ | 6.89 sn · 232 bg · 9.600 ₺ |
| TURBO | 6.89 sn · 222 bg · 950 ₺ | 6.89 sn · 225 bg · 1.900 ₺ | 6.89 sn · 228 bg · 3.350 ₺ | 6.89 sn · 231 bg · 5.750 ₺ | 6.89 sn · 234 bg · 9.600 ₺ |
| HAVA | 6.89 sn · 222 bg · 650 ₺ | 6.86 sn · 225 bg · 1.300 ₺ | 6.83 sn · 227 bg · 2.250 ₺ | 6.82 sn · 229 bg · 3.850 ₺ | 6.81 sn · 232 bg · 6.400 ₺ |
| ŞANZ. | 6.86 sn · 231 km/sa · 800 ₺ | 6.82 sn · 233 km/sa · 1.600 ₺ | 6.74 sn · 234 km/sa · 2.800 ₺ | 6.73 sn · 238 km/sa · 4.800 ₺ | 6.70 sn · 240 km/sa · 8.000 ₺ |
| LASTİK | 6.74 sn · 650 ₺ | 6.56 sn · 1.300 ₺ | 6.42 sn · 2.250 ₺ | 6.27 sn · 3.850 ₺ | 6.15 sn · 6.400 ₺ |
| GÖVDE | 6.90 sn · 800 ₺ | 6.89 sn · 1.600 ₺ | 6.89 sn · 2.800 ₺ | 6.89 sn · 4.800 ₺ | 6.89 sn · 8.000 ₺ |

**FULL:** 0-100 5.68 sn · 257 km/sa · 260 bg · 300 m 9.73 sn → sınıf **A**

### VOLVO S60 — A · FWD · Turbo benzin · fiyat 105.000 ₺
Fabrika: 0-100 **7.0 sn** · son hız **235 km/sa** · **210 bg** · 300 m **10.60 sn** · kalkış patinajı 1.93 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 6.98 sn · 213 bg · 1.250 ₺ | 6.96 sn · 216 bg · 2.500 ₺ | 6.94 sn · 218 bg · 4.400 ₺ | 6.93 sn · 219 bg · 7.550 ₺ | 6.92 sn · 221 bg · 12.600 ₺ |
| TURBO | 6.99 sn · 212 bg · 1.250 ₺ | 6.96 sn · 215 bg · 2.500 ₺ | 6.94 sn · 218 bg · 4.400 ₺ | 6.91 sn · 221 bg · 7.550 ₺ | 6.89 sn · 224 bg · 12.600 ₺ |
| HAVA | 6.98 sn · 212 bg · 850 ₺ | 6.95 sn · 215 bg · 1.700 ₺ | 6.94 sn · 217 bg · 2.950 ₺ | 6.92 sn · 219 bg · 5.050 ₺ | 6.91 sn · 221 bg · 8.400 ₺ |
| ŞANZ. | 6.97 sn · 237 km/sa · 1.050 ₺ | 6.93 sn · 239 km/sa · 2.100 ₺ | 6.87 sn · 241 km/sa · 3.700 ₺ | 6.84 sn · 244 km/sa · 6.300 ₺ | 6.82 sn · 247 km/sa · 10.500 ₺ |
| LASTİK | 6.83 sn · 850 ₺ | 6.62 sn · 1.700 ₺ | 6.46 sn · 2.950 ₺ | 6.30 sn · 5.050 ₺ | 6.16 sn · 8.400 ₺ |
| GÖVDE | 6.99 sn · 1.050 ₺ | 6.98 sn · 2.100 ₺ | 6.97 sn · 3.700 ₺ | 6.96 sn · 6.300 ₺ | 6.94 sn · 10.500 ₺ |

**FULL:** 0-100 5.73 sn · 264 km/sa · 248 bg · 300 m 9.73 sn → sınıf **A**

### JAGUAR E-TYPE (1961) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **7.1 sn** · son hız **241 km/sa** · **265 bg** · 300 m **10.70 sn** · kalkış patinajı 1.14 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.06 sn · 268 bg · 750 ₺ | 7.04 sn · 271 bg · 1.500 ₺ | 7.02 sn · 273 bg · 2.600 ₺ | 7.00 sn · 275 bg · 4.500 ₺ | 6.98 sn · 277 bg · 7.500 ₺ |
| TURBO | 7.07 sn · 267 bg · 750 ₺ | 7.04 sn · 270 bg · 1.500 ₺ | 7.02 sn · 273 bg · 2.600 ₺ | 6.99 sn · 276 bg · 4.500 ₺ | 6.96 sn · 279 bg · 7.500 ₺ |
| HAVA | 7.04 sn · 268 bg · 500 ₺ | 7.00 sn · 271 bg · 1.000 ₺ | 6.95 sn · 275 bg · 1.750 ₺ | 6.92 sn · 278 bg · 3.000 ₺ | 6.88 sn · 281 bg · 5.000 ₺ |
| ŞANZ. | 7.05 sn · 243 km/sa · 600 ₺ | 7.02 sn · 245 km/sa · 1.250 ₺ | 6.93 sn · 247 km/sa · 2.200 ₺ | 6.93 sn · 251 km/sa · 3.750 ₺ | 6.90 sn · 253 km/sa · 6.250 ₺ |
| LASTİK | 6.71 sn · 500 ₺ | 6.37 sn · 1.000 ₺ | 6.35 sn · 1.750 ₺ | 6.32 sn · 3.000 ₺ | 6.30 sn · 5.000 ₺ |
| GÖVDE | 7.08 sn · 600 ₺ | 7.06 sn · 1.250 ₺ | 7.04 sn · 2.200 ₺ | 7.02 sn · 3.750 ₺ | 7.00 sn · 6.250 ₺ |

**FULL:** 0-100 5.75 sn · 270 km/sa · 310 bg · 300 m 9.88 sn → sınıf **A**

### AUDI A3 — A · FWD · Turbo benzin · fiyat 95.000 ₺
Fabrika: 0-100 **7.2 sn** · son hız **232 km/sa** · **180 bg** · 300 m **10.76 sn** · kalkış patinajı 1.82 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.16 sn · 183 bg · 1.150 ₺ | 7.14 sn · 185 bg · 2.300 ₺ | 7.12 sn · 187 bg · 4.000 ₺ | 7.10 sn · 188 bg · 6.850 ₺ | 7.09 sn · 189 bg · 11.400 ₺ |
| TURBO | 7.17 sn · 182 bg · 1.150 ₺ | 7.14 sn · 184 bg · 2.300 ₺ | 7.11 sn · 187 bg · 4.000 ₺ | 7.08 sn · 189 bg · 6.850 ₺ | 7.05 sn · 192 bg · 11.400 ₺ |
| HAVA | 7.17 sn · 182 bg · 750 ₺ | 7.15 sn · 184 bg · 1.500 ₺ | 7.11 sn · 186 bg · 2.650 ₺ | 7.09 sn · 188 bg · 4.550 ₺ | 7.07 sn · 190 bg · 7.600 ₺ |
| ŞANZ. | 7.16 sn · 234 km/sa · 950 ₺ | 7.13 sn · 236 km/sa · 1.900 ₺ | 7.05 sn · 238 km/sa · 3.350 ₺ | 7.01 sn · 241 km/sa · 5.700 ₺ | 6.98 sn · 244 km/sa · 9.500 ₺ |
| LASTİK | 7.06 sn · 750 ₺ | 6.86 sn · 1.500 ₺ | 6.70 sn · 2.650 ₺ | 6.55 sn · 4.550 ₺ | 6.41 sn · 7.600 ₺ |
| GÖVDE | 7.19 sn · 950 ₺ | 7.17 sn · 1.900 ₺ | 7.15 sn · 3.350 ₺ | 7.14 sn · 5.700 ₺ | 7.12 sn · 9.500 ₺ |

**FULL:** 0-100 5.84 sn · 261 km/sa · 213 bg · 300 m 9.88 sn → sınıf **A**

### FORD MUSTANG (1967) — A · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **7.4 sn** · son hız **195 km/sa** · **320 bg** · 300 m **10.87 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.30 sn · 324 bg · 750 ₺ | 7.23 sn · 327 bg · 1.500 ₺ | 7.17 sn · 330 bg · 2.600 ₺ | 7.11 sn · 333 bg · 4.500 ₺ | 7.07 sn · 335 bg · 7.500 ₺ |
| TURBO | 7.33 sn · 323 bg · 750 ₺ | 7.25 sn · 326 bg · 1.500 ₺ | 7.17 sn · 330 bg · 2.600 ₺ | 7.09 sn · 334 bg · 4.500 ₺ | 7.01 sn · 337 bg · 7.500 ₺ |
| HAVA | 7.31 sn · 324 bg · 500 ₺ | 7.25 sn · 328 bg · 1.000 ₺ | 7.17 sn · 332 bg · 1.750 ₺ | 7.12 sn · 335 bg · 3.000 ₺ | 7.06 sn · 339 bg · 5.000 ₺ |
| ŞANZ. | 7.34 sn · 197 km/sa · 600 ₺ | 7.31 sn · 198 km/sa · 1.250 ₺ | 7.23 sn · 200 km/sa · 2.200 ₺ | 7.12 sn · 203 km/sa · 3.750 ₺ | 7.07 sn · 205 km/sa · 6.250 ₺ |
| LASTİK | 7.40 sn · 500 ₺ | 7.35 sn · 1.000 ₺ | 7.32 sn · 1.750 ₺ | 7.28 sn · 3.000 ₺ | 7.26 sn · 5.000 ₺ |
| GÖVDE | 7.35 sn · 600 ₺ | 7.30 sn · 1.250 ₺ | 7.25 sn · 2.200 ₺ | 7.20 sn · 3.750 ₺ | 7.15 sn · 6.250 ₺ |

**FULL:** 0-100 5.81 sn · 218 km/sa · 374 bg · 300 m 9.99 sn → sınıf **A**

### TOYOTA CELICA GT-FOUR — A · AWD · Turbo benzin · fiyat 62.500 ₺
Fabrika: 0-100 **7.5 sn** · son hız **230 km/sa** · **208 bg** · 300 m **10.95 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.39 sn · 211 bg · 750 ₺ | 7.31 sn · 213 bg · 1.500 ₺ | 7.24 sn · 216 bg · 2.600 ₺ | 7.18 sn · 217 bg · 4.500 ₺ | 7.13 sn · 219 bg · 7.500 ₺ |
| TURBO | 7.42 sn · 210 bg · 750 ₺ | 7.32 sn · 213 bg · 1.500 ₺ | 7.23 sn · 216 bg · 2.600 ₺ | 7.13 sn · 219 bg · 4.500 ₺ | 7.04 sn · 221 bg · 7.500 ₺ |
| HAVA | 7.42 sn · 210 bg · 500 ₺ | 7.36 sn · 212 bg · 1.000 ₺ | 7.31 sn · 215 bg · 1.750 ₺ | 7.24 sn · 217 bg · 3.000 ₺ | 7.19 sn · 219 bg · 5.000 ₺ |
| ŞANZ. | 7.44 sn · 232 km/sa · 600 ₺ | 7.40 sn · 234 km/sa · 1.250 ₺ | 7.33 sn · 236 km/sa · 2.200 ₺ | 7.23 sn · 239 km/sa · 3.750 ₺ | 7.17 sn · 242 km/sa · 6.250 ₺ |
| LASTİK | 7.50 sn · 500 ₺ | 7.45 sn · 1.000 ₺ | 7.42 sn · 1.750 ₺ | 7.39 sn · 3.000 ₺ | 7.37 sn · 5.000 ₺ |
| GÖVDE | 7.45 sn · 600 ₺ | 7.40 sn · 1.250 ₺ | 7.35 sn · 2.200 ₺ | 7.29 sn · 3.750 ₺ | 7.24 sn · 6.250 ₺ |

**FULL:** 0-100 5.82 sn · 258 km/sa · 246 bg · 300 m 10.03 sn → sınıf **A**

### ASTON MARTIN DB5 (1964) — B · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **8.0 sn** · son hız **233 km/sa** · **282 bg** · 300 m **11.18 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.90 sn · 286 bg · 750 ₺ | 7.82 sn · 289 bg · 1.500 ₺ | 7.76 sn · 291 bg · 2.600 ₺ | 7.70 sn · 293 bg · 4.500 ₺ | 7.65 sn · 295 bg · 7.500 ₺ |
| TURBO | 7.93 sn · 285 bg · 750 ₺ | 7.85 sn · 288 bg · 1.500 ₺ | 7.76 sn · 291 bg · 2.600 ₺ | 7.67 sn · 294 bg · 4.500 ₺ | 7.60 sn · 297 bg · 7.500 ₺ |
| HAVA | 7.92 sn · 285 bg · 500 ₺ | 7.86 sn · 289 bg · 1.000 ₺ | 7.77 sn · 292 bg · 1.750 ₺ | 7.70 sn · 296 bg · 3.000 ₺ | 7.64 sn · 299 bg · 5.000 ₺ |
| ŞANZ. | 7.95 sn · 235 km/sa · 600 ₺ | 7.91 sn · 237 km/sa · 1.250 ₺ | 7.82 sn · 239 km/sa · 2.200 ₺ | 7.73 sn · 242 km/sa · 3.750 ₺ | 7.67 sn · 245 km/sa · 6.250 ₺ |
| LASTİK | 8.00 sn · 500 ₺ | 7.95 sn · 1.000 ₺ | 7.91 sn · 1.750 ₺ | 7.88 sn · 3.000 ₺ | 7.86 sn · 5.000 ₺ |
| GÖVDE | 7.95 sn · 600 ₺ | 7.89 sn · 1.250 ₺ | 7.83 sn · 2.200 ₺ | 7.78 sn · 3.750 ₺ | 7.72 sn · 6.250 ₺ |

**FULL:** 0-100 6.29 sn · 261 km/sa · 330 bg · 300 m 10.28 sn → sınıf **A**

### SEAT LEON — B · FWD · Turbo benzin · fiyat 68.000 ₺
Fabrika: 0-100 **8.0 sn** · son hız **215 km/sa** · **150 bg** · 300 m **11.23 sn** · kalkış patinajı 1.45 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 7.96 sn · 152 bg · 800 ₺ | 7.93 sn · 154 bg · 1.650 ₺ | 7.91 sn · 155 bg · 2.850 ₺ | 7.89 sn · 157 bg · 4.900 ₺ | 7.87 sn · 158 bg · 8.150 ₺ |
| TURBO | 7.97 sn · 152 bg · 800 ₺ | 7.93 sn · 154 bg · 1.650 ₺ | 7.91 sn · 156 bg · 2.850 ₺ | 7.87 sn · 158 bg · 4.900 ₺ | 7.84 sn · 160 bg · 8.150 ₺ |
| HAVA | 7.97 sn · 152 bg · 550 ₺ | 7.93 sn · 153 bg · 1.100 ₺ | 7.88 sn · 155 bg · 1.900 ₺ | 7.85 sn · 156 bg · 3.250 ₺ | 7.80 sn · 158 bg · 5.450 ₺ |
| ŞANZ. | 7.96 sn · 217 km/sa · 700 ₺ | 7.92 sn · 218 km/sa · 1.350 ₺ | 7.84 sn · 220 km/sa · 2.400 ₺ | 7.84 sn · 224 km/sa · 4.100 ₺ | 7.81 sn · 226 km/sa · 6.800 ₺ |
| LASTİK | 7.85 sn · 550 ₺ | 7.67 sn · 1.100 ₺ | 6.96 sn · 1.900 ₺ | 6.93 sn · 3.250 ₺ | 6.91 sn · 5.450 ₺ |
| GÖVDE | 7.98 sn · 700 ₺ | 7.96 sn · 1.350 ₺ | 7.94 sn · 2.400 ₺ | 7.93 sn · 4.100 ₺ | 7.91 sn · 6.800 ₺ |

**FULL:** 0-100 6.48 sn · 241 km/sa · 177 bg · 300 m 10.34 sn → sınıf **A**

### VW GOLF 7 — B · FWD · Turbo benzin · fiyat 65.000 ₺
Fabrika: 0-100 **8.2 sn** · son hız **216 km/sa** · **150 bg** · 300 m **11.33 sn** · kalkış patinajı 1.38 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 8.16 sn · 152 bg · 800 ₺ | 8.12 sn · 154 bg · 1.550 ₺ | 8.10 sn · 155 bg · 2.750 ₺ | 8.06 sn · 157 bg · 4.700 ₺ | 8.06 sn · 158 bg · 7.800 ₺ |
| TURBO | 8.17 sn · 152 bg · 800 ₺ | 8.14 sn · 154 bg · 1.550 ₺ | 8.09 sn · 156 bg · 2.750 ₺ | 8.05 sn · 158 bg · 4.700 ₺ | 8.02 sn · 160 bg · 7.800 ₺ |
| HAVA | 8.15 sn · 152 bg · 500 ₺ | 8.11 sn · 153 bg · 1.050 ₺ | 8.07 sn · 155 bg · 1.800 ₺ | 8.02 sn · 156 bg · 3.100 ₺ | 7.98 sn · 158 bg · 5.200 ₺ |
| ŞANZ. | 8.15 sn · 218 km/sa · 650 ₺ | 8.11 sn · 219 km/sa · 1.300 ₺ | 8.03 sn · 221 km/sa · 2.300 ₺ | 8.02 sn · 225 km/sa · 3.900 ₺ | 7.99 sn · 227 km/sa · 6.500 ₺ |
| LASTİK | 8.06 sn · 500 ₺ | 7.36 sn · 1.050 ₺ | 7.25 sn · 1.800 ₺ | 7.21 sn · 3.100 ₺ | 7.19 sn · 5.200 ₺ |
| GÖVDE | 8.18 sn · 650 ₺ | 8.16 sn · 1.300 ₺ | 8.15 sn · 2.300 ₺ | 8.11 sn · 3.900 ₺ | 8.10 sn · 6.500 ₺ |

**FULL:** 0-100 6.62 sn · 243 km/sa · 177 bg · 300 m 10.43 sn → sınıf **A**

### MERCEDES-BENZ 300 SL (1955) — B · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **8.8 sn** · son hız **235 km/sa** · **215 bg** · 300 m **11.57 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 8.69 sn · 218 bg · 750 ₺ | 8.60 sn · 220 bg · 1.500 ₺ | 8.53 sn · 222 bg · 2.600 ₺ | 8.47 sn · 224 bg · 4.500 ₺ | 8.41 sn · 225 bg · 7.500 ₺ |
| TURBO | 8.72 sn · 217 bg · 750 ₺ | 8.63 sn · 219 bg · 1.500 ₺ | 8.54 sn · 222 bg · 2.600 ₺ | 8.44 sn · 224 bg · 4.500 ₺ | 8.35 sn · 227 bg · 7.500 ₺ |
| HAVA | 8.71 sn · 218 bg · 500 ₺ | 8.62 sn · 220 bg · 1.000 ₺ | 8.55 sn · 223 bg · 1.750 ₺ | 8.47 sn · 225 bg · 3.000 ₺ | 8.39 sn · 228 bg · 5.000 ₺ |
| ŞANZ. | 8.75 sn · 237 km/sa · 600 ₺ | 8.70 sn · 239 km/sa · 1.250 ₺ | 8.61 sn · 241 km/sa · 2.200 ₺ | 8.50 sn · 244 km/sa · 3.750 ₺ | 8.44 sn · 247 km/sa · 6.250 ₺ |
| LASTİK | 8.80 sn · 500 ₺ | 8.74 sn · 1.000 ₺ | 8.71 sn · 1.750 ₺ | 8.67 sn · 3.000 ₺ | 8.65 sn · 5.000 ₺ |
| GÖVDE | 8.74 sn · 600 ₺ | 8.68 sn · 1.250 ₺ | 8.62 sn · 2.200 ₺ | 8.56 sn · 3.750 ₺ | 8.49 sn · 6.250 ₺ |

**FULL:** 0-100 6.91 sn · 263 km/sa · 251 bg · 300 m 10.64 sn → sınıf **A**

### ALFA ROMEO 159 — B · FWD · Atmosferik · fiyat 90.000 ₺
Fabrika: 0-100 **8.8 sn** · son hız **222 km/sa** · **185 bg** · 300 m **11.58 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 8.70 sn · 187 bg · 1.100 ₺ | 8.62 sn · 189 bg · 2.150 ₺ | 8.55 sn · 190 bg · 3.800 ₺ | 8.49 sn · 192 bg · 6.500 ₺ | 8.45 sn · 193 bg · 10.800 ₺ |
| TURBO | 8.71 sn · 187 bg · 1.100 ₺ | 8.61 sn · 189 bg · 2.150 ₺ | 8.51 sn · 191 bg · 3.800 ₺ | 8.40 sn · 193 bg · 6.500 ₺ | 8.31 sn · 195 bg · 10.800 ₺ |
| HAVA | 8.70 sn · 187 bg · 700 ₺ | 8.62 sn · 190 bg · 1.450 ₺ | 8.53 sn · 192 bg · 2.500 ₺ | 8.45 sn · 195 bg · 4.300 ₺ | 8.37 sn · 198 bg · 7.200 ₺ |
| ŞANZ. | 8.76 sn · 224 km/sa · 900 ₺ | 8.71 sn · 226 km/sa · 1.800 ₺ | 8.61 sn · 227 km/sa · 3.150 ₺ | 8.51 sn · 231 km/sa · 5.400 ₺ | 8.43 sn · 233 km/sa · 9.000 ₺ |
| LASTİK | 8.80 sn · 700 ₺ | 8.74 sn · 1.450 ₺ | 8.70 sn · 2.500 ₺ | 8.67 sn · 4.300 ₺ | 8.64 sn · 7.200 ₺ |
| GÖVDE | 8.74 sn · 900 ₺ | 8.68 sn · 1.800 ₺ | 8.62 sn · 3.150 ₺ | 8.55 sn · 5.400 ₺ | 8.49 sn · 9.000 ₺ |

**FULL:** 0-100 6.90 sn · 249 km/sa · 217 bg · 300 m 10.62 sn → sınıf **A**

### FORD ESCORT RS1600 (1972) — B · RWD · Klasik (karbüratör) · fiyat 62.500 ₺
Fabrika: 0-100 **8.9 sn** · son hız **182 km/sa** · **120 bg** · 300 m **11.63 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 8.78 sn · 122 bg · 750 ₺ | 8.70 sn · 123 bg · 1.500 ₺ | 8.63 sn · 124 bg · 2.600 ₺ | 8.56 sn · 125 bg · 4.500 ₺ | 8.51 sn · 126 bg · 7.500 ₺ |
| TURBO | 8.82 sn · 121 bg · 750 ₺ | 8.73 sn · 122 bg · 1.500 ₺ | 8.63 sn · 124 bg · 2.600 ₺ | 8.53 sn · 125 bg · 4.500 ₺ | 8.45 sn · 126 bg · 7.500 ₺ |
| HAVA | 8.81 sn · 121 bg · 500 ₺ | 8.72 sn · 123 bg · 1.000 ₺ | 8.65 sn · 124 bg · 1.750 ₺ | 8.56 sn · 126 bg · 3.000 ₺ | 8.49 sn · 127 bg · 5.000 ₺ |
| ŞANZ. | 8.85 sn · 183 km/sa · 600 ₺ | 8.80 sn · 185 km/sa · 1.250 ₺ | 8.71 sn · 186 km/sa · 2.200 ₺ | 8.62 sn · 189 km/sa · 3.750 ₺ | 8.55 sn · 191 km/sa · 6.250 ₺ |
| LASTİK | 8.90 sn · 500 ₺ | 8.84 sn · 1.000 ₺ | 8.80 sn · 1.750 ₺ | 8.77 sn · 3.000 ₺ | 8.74 sn · 5.000 ₺ |
| GÖVDE | 8.84 sn · 600 ₺ | 8.78 sn · 1.250 ₺ | 8.71 sn · 2.200 ₺ | 8.65 sn · 3.750 ₺ | 8.59 sn · 6.250 ₺ |

**FULL:** 0-100 6.99 sn · 204 km/sa · 140 bg · 300 m 10.71 sn → sınıf **A**

### VOLKSWAGEN PASSAT B5.5 — C · FWD · Turbo dizel · fiyat 50.000 ₺
Fabrika: 0-100 **9.9 sn** · son hız **208 km/sa** · **130 bg** · 300 m **12.07 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 9.72 sn · 132 bg · 600 ₺ | 9.59 sn · 134 bg · 1.200 ₺ | 9.48 sn · 136 bg · 2.100 ₺ | 9.39 sn · 137 bg · 3.600 ₺ | 9.31 sn · 138 bg · 6.000 ₺ |
| TURBO | 9.78 sn · 132 bg · 600 ₺ | 9.65 sn · 133 bg · 1.200 ₺ | 9.51 sn · 135 bg · 2.100 ₺ | 9.36 sn · 137 bg · 3.600 ₺ | 9.23 sn · 139 bg · 6.000 ₺ |
| HAVA | 9.86 sn · 131 bg · 400 ₺ | 9.83 sn · 131 bg · 800 ₺ | 9.79 sn · 132 bg · 1.400 ₺ | 9.75 sn · 133 bg · 2.400 ₺ | 9.71 sn · 133 bg · 4.000 ₺ |
| ŞANZ. | 9.86 sn · 210 km/sa · 500 ₺ | 9.82 sn · 211 km/sa · 1.000 ₺ | 9.72 sn · 213 km/sa · 1.750 ₺ | 9.58 sn · 216 km/sa · 3.000 ₺ | 9.52 sn · 218 km/sa · 5.000 ₺ |
| LASTİK | 9.90 sn · 400 ₺ | 9.83 sn · 800 ₺ | 9.79 sn · 1.400 ₺ | 9.75 sn · 2.400 ₺ | 9.72 sn · 4.000 ₺ |
| GÖVDE | 9.83 sn · 500 ₺ | 9.76 sn · 1.000 ₺ | 9.69 sn · 1.750 ₺ | 9.62 sn · 3.000 ₺ | 9.55 sn · 5.000 ₺ |

**FULL:** 0-100 7.73 sn · 233 km/sa · 152 bg · 300 m 11.06 sn → sınıf **B**

### RENAULT FLUENCE — C · FWD · Atmosferik · fiyat 60.000 ₺
Fabrika: 0-100 **9.9 sn** · son hız **200 km/sa** · **140 bg** · 300 m **12.09 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 9.78 sn · 142 bg · 700 ₺ | 9.69 sn · 143 bg · 1.450 ₺ | 9.62 sn · 144 bg · 2.500 ₺ | 9.55 sn · 145 bg · 4.300 ₺ | 9.50 sn · 146 bg · 7.200 ₺ |
| TURBO | 9.81 sn · 141 bg · 700 ₺ | 9.69 sn · 143 bg · 1.450 ₺ | 9.59 sn · 144 bg · 2.500 ₺ | 9.45 sn · 146 bg · 4.300 ₺ | 9.34 sn · 148 bg · 7.200 ₺ |
| HAVA | 9.81 sn · 142 bg · 500 ₺ | 9.70 sn · 144 bg · 950 ₺ | 9.61 sn · 146 bg · 1.700 ₺ | 9.52 sn · 148 bg · 2.900 ₺ | 9.42 sn · 149 bg · 4.800 ₺ |
| ŞANZ. | 9.86 sn · 202 km/sa · 600 ₺ | 9.82 sn · 203 km/sa · 1.200 ₺ | 9.72 sn · 205 km/sa · 2.100 ₺ | 9.58 sn · 208 km/sa · 3.600 ₺ | 9.52 sn · 210 km/sa · 6.000 ₺ |
| LASTİK | 9.90 sn · 500 ₺ | 9.83 sn · 950 ₺ | 9.79 sn · 1.700 ₺ | 9.75 sn · 2.900 ₺ | 9.72 sn · 4.800 ₺ |
| GÖVDE | 9.83 sn · 600 ₺ | 9.76 sn · 1.200 ₺ | 9.69 sn · 2.100 ₺ | 9.62 sn · 3.600 ₺ | 9.55 sn · 6.000 ₺ |

**FULL:** 0-100 7.76 sn · 224 km/sa · 164 bg · 300 m 11.08 sn → sınıf **B**

### SKODA KAMIQ — C · FWD · Turbo dizel · fiyat 55.000 ₺
Fabrika: 0-100 **10.2 sn** · son hız **193 km/sa** · **115 bg** · 300 m **12.22 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 10.02 sn · 117 bg · 650 ₺ | 9.88 sn · 119 bg · 1.300 ₺ | 9.77 sn · 120 bg · 2.300 ₺ | 9.67 sn · 121 bg · 3.950 ₺ | 9.59 sn · 122 bg · 6.600 ₺ |
| TURBO | 10.08 sn · 116 bg · 650 ₺ | 9.93 sn · 118 bg · 1.300 ₺ | 9.79 sn · 120 bg · 2.300 ₺ | 9.64 sn · 121 bg · 3.950 ₺ | 9.50 sn · 123 bg · 6.600 ₺ |
| HAVA | 10.16 sn · 116 bg · 450 ₺ | 10.11 sn · 116 bg · 900 ₺ | 10.08 sn · 117 bg · 1.550 ₺ | 10.03 sn · 117 bg · 2.650 ₺ | 9.99 sn · 118 bg · 4.400 ₺ |
| ŞANZ. | 10.16 sn · 195 km/sa · 550 ₺ | 10.11 sn · 196 km/sa · 1.100 ₺ | 10.01 sn · 198 km/sa · 1.950 ₺ | 9.88 sn · 201 km/sa · 3.300 ₺ | 9.81 sn · 203 km/sa · 5.500 ₺ |
| LASTİK | 10.20 sn · 450 ₺ | 10.13 sn · 900 ₺ | 10.09 sn · 1.550 ₺ | 10.05 sn · 2.650 ₺ | 10.02 sn · 4.400 ₺ |
| GÖVDE | 10.13 sn · 550 ₺ | 10.06 sn · 1.100 ₺ | 9.98 sn · 1.950 ₺ | 9.91 sn · 3.300 ₺ | 9.84 sn · 5.500 ₺ |

**FULL:** 0-100 7.96 sn · 216 km/sa · 134 bg · 300 m 11.21 sn → sınıf **B**

### HYUNDAI ACCENT BLUE — C · FWD · Atmosferik · fiyat 38.000 ₺
Fabrika: 0-100 **10.2 sn** · son hız **190 km/sa** · **124 bg** · 300 m **12.22 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 10.08 sn · 125 bg · 450 ₺ | 9.99 sn · 127 bg · 900 ₺ | 9.91 sn · 128 bg · 1.600 ₺ | 9.84 sn · 128 bg · 2.750 ₺ | 9.78 sn · 129 bg · 4.550 ₺ |
| TURBO | 10.10 sn · 125 bg · 450 ₺ | 9.97 sn · 126 bg · 900 ₺ | 9.85 sn · 128 bg · 1.600 ₺ | 9.74 sn · 129 bg · 2.750 ₺ | 9.62 sn · 131 bg · 4.550 ₺ |
| HAVA | 10.09 sn · 126 bg · 300 ₺ | 10.00 sn · 127 bg · 600 ₺ | 9.90 sn · 129 bg · 1.050 ₺ | 9.79 sn · 131 bg · 1.800 ₺ | 9.69 sn · 132 bg · 3.050 ₺ |
| ŞANZ. | 10.15 sn · 192 km/sa · 400 ₺ | 10.11 sn · 193 km/sa · 750 ₺ | 10.00 sn · 195 km/sa · 1.350 ₺ | 9.89 sn · 198 km/sa · 2.300 ₺ | 9.81 sn · 200 km/sa · 3.800 ₺ |
| LASTİK | 10.20 sn · 300 ₺ | 10.13 sn · 600 ₺ | 10.09 sn · 1.050 ₺ | 10.05 sn · 1.800 ₺ | 10.02 sn · 3.050 ₺ |
| GÖVDE | 10.13 sn · 400 ₺ | 10.06 sn · 750 ₺ | 9.98 sn · 1.350 ₺ | 9.91 sn · 2.300 ₺ | 9.84 sn · 3.800 ₺ |

**FULL:** 0-100 7.98 sn · 213 km/sa · 145 bg · 300 m 11.20 sn → sınıf **B**

### HONDA CIVIC VTEC — C · FWD · Atmosferik · fiyat 72.000 ₺
Fabrika: 0-100 **10.5 sn** · son hız **200 km/sa** · **125 bg** · 300 m **12.34 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 10.37 sn · 126 bg · 850 ₺ | 10.28 sn · 128 bg · 1.750 ₺ | 10.20 sn · 129 bg · 3.000 ₺ | 10.13 sn · 130 bg · 5.200 ₺ | 10.07 sn · 130 bg · 8.650 ₺ |
| TURBO | 10.39 sn · 126 bg · 850 ₺ | 10.27 sn · 128 bg · 1.750 ₺ | 10.14 sn · 129 bg · 3.000 ₺ | 10.01 sn · 130 bg · 5.200 ₺ | 9.90 sn · 132 bg · 8.650 ₺ |
| HAVA | 10.39 sn · 127 bg · 600 ₺ | 10.29 sn · 128 bg · 1.150 ₺ | 10.18 sn · 130 bg · 2.000 ₺ | 10.08 sn · 132 bg · 3.450 ₺ | 9.98 sn · 133 bg · 5.750 ₺ |
| ŞANZ. | 10.45 sn · 202 km/sa · 700 ₺ | 10.41 sn · 203 km/sa · 1.450 ₺ | 10.30 sn · 205 km/sa · 2.500 ₺ | 10.18 sn · 208 km/sa · 4.300 ₺ | 10.10 sn · 210 km/sa · 7.200 ₺ |
| LASTİK | 10.50 sn · 600 ₺ | 10.43 sn · 1.150 ₺ | 10.39 sn · 2.000 ₺ | 10.34 sn · 3.450 ₺ | 10.31 sn · 5.750 ₺ |
| GÖVDE | 10.43 sn · 700 ₺ | 10.35 sn · 1.450 ₺ | 10.28 sn · 2.500 ₺ | 10.20 sn · 4.300 ₺ | 10.13 sn · 7.200 ₺ |

**FULL:** 0-100 8.22 sn · 224 km/sa · 147 bg · 300 m 11.31 sn → sınıf **B**

### FORD FOCUS — C · FWD · Atmosferik · fiyat 45.000 ₺
Fabrika: 0-100 **10.9 sn** · son hız **193 km/sa** · **125 bg** · 300 m **12.52 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 10.78 sn · 126 bg · 550 ₺ | 10.68 sn · 128 bg · 1.100 ₺ | 10.59 sn · 129 bg · 1.900 ₺ | 10.52 sn · 130 bg · 3.250 ₺ | 10.46 sn · 130 bg · 5.400 ₺ |
| TURBO | 10.81 sn · 126 bg · 550 ₺ | 10.68 sn · 128 bg · 1.100 ₺ | 10.56 sn · 129 bg · 1.900 ₺ | 10.42 sn · 130 bg · 3.250 ₺ | 10.30 sn · 132 bg · 5.400 ₺ |
| HAVA | 10.80 sn · 127 bg · 350 ₺ | 10.70 sn · 128 bg · 700 ₺ | 10.58 sn · 130 bg · 1.250 ₺ | 10.48 sn · 132 bg · 2.150 ₺ | 10.36 sn · 133 bg · 3.600 ₺ |
| ŞANZ. | 10.86 sn · 195 km/sa · 450 ₺ | 10.82 sn · 196 km/sa · 900 ₺ | 10.71 sn · 198 km/sa · 1.600 ₺ | 10.58 sn · 201 km/sa · 2.700 ₺ | 10.51 sn · 203 km/sa · 4.500 ₺ |
| LASTİK | 10.90 sn · 350 ₺ | 10.82 sn · 700 ₺ | 10.79 sn · 1.250 ₺ | 10.74 sn · 2.150 ₺ | 10.70 sn · 3.600 ₺ |
| GÖVDE | 10.82 sn · 450 ₺ | 10.75 sn · 900 ₺ | 10.68 sn · 1.600 ₺ | 10.60 sn · 2.700 ₺ | 10.52 sn · 4.500 ₺ |

**FULL:** 0-100 8.54 sn · 216 km/sa · 147 bg · 300 m 11.47 sn → sınıf **B**

### OPEL CORSA — C · FWD · Turbo benzin · fiyat 26.000 ₺
Fabrika: 0-100 **11.2 sn** · son hız **185 km/sa** · **100 bg** · 300 m **12.63 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 11.03 sn · 101 bg · 300 ₺ | 10.91 sn · 103 bg · 600 ₺ | 10.80 sn · 104 bg · 1.100 ₺ | 10.71 sn · 104 bg · 1.850 ₺ | 10.63 sn · 105 bg · 3.100 ₺ |
| TURBO | 11.07 sn · 101 bg · 300 ₺ | 10.92 sn · 102 bg · 600 ₺ | 10.77 sn · 104 bg · 1.100 ₺ | 10.62 sn · 105 bg · 1.850 ₺ | 10.48 sn · 106 bg · 3.100 ₺ |
| HAVA | 11.10 sn · 101 bg · 200 ₺ | 11.01 sn · 102 bg · 400 ₺ | 10.92 sn · 103 bg · 750 ₺ | 10.83 sn · 104 bg · 1.250 ₺ | 10.73 sn · 105 bg · 2.100 ₺ |
| ŞANZ. | 11.15 sn · 186 km/sa · 250 ₺ | 11.10 sn · 188 km/sa · 500 ₺ | 11.00 sn · 189 km/sa · 900 ₺ | 10.89 sn · 192 km/sa · 1.550 ₺ | 10.81 sn · 194 km/sa · 2.600 ₺ |
| LASTİK | 11.20 sn · 200 ₺ | 11.12 sn · 400 ₺ | 11.08 sn · 750 ₺ | 11.03 sn · 1.250 ₺ | 11.00 sn · 2.100 ₺ |
| GÖVDE | 11.12 sn · 250 ₺ | 11.04 sn · 500 ₺ | 10.96 sn · 900 ₺ | 10.88 sn · 1.550 ₺ | 10.80 sn · 2.600 ₺ |

**FULL:** 0-100 8.69 sn · 208 km/sa · 118 bg · 300 m 11.57 sn → sınıf **B**

### HYUNDAI GETZ — C · FWD · Turbo dizel · fiyat 35.000 ₺
Fabrika: 0-100 **11.5 sn** · son hız **176 km/sa** · **110 bg** · 300 m **12.72 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 11.29 sn · 112 bg · 400 ₺ | 11.14 sn · 113 bg · 850 ₺ | 11.01 sn · 115 bg · 1.450 ₺ | 10.89 sn · 116 bg · 2.500 ₺ | 10.80 sn · 117 bg · 4.200 ₺ |
| TURBO | 11.36 sn · 111 bg · 400 ₺ | 11.19 sn · 113 bg · 850 ₺ | 11.03 sn · 114 bg · 1.450 ₺ | 10.85 sn · 116 bg · 2.500 ₺ | 10.70 sn · 118 bg · 4.200 ₺ |
| HAVA | 11.45 sn · 111 bg · 300 ₺ | 11.41 sn · 111 bg · 550 ₺ | 11.35 sn · 112 bg · 1.000 ₺ | 11.31 sn · 112 bg · 1.700 ₺ | 11.26 sn · 113 bg · 2.800 ₺ |
| ŞANZ. | 11.45 sn · 177 km/sa · 350 ₺ | 11.40 sn · 179 km/sa · 700 ₺ | 11.29 sn · 180 km/sa · 1.250 ₺ | 11.18 sn · 183 km/sa · 2.100 ₺ | 11.11 sn · 185 km/sa · 3.500 ₺ |
| LASTİK | 11.50 sn · 300 ₺ | 11.42 sn · 550 ₺ | 11.37 sn · 1.000 ₺ | 11.33 sn · 1.700 ₺ | 11.29 sn · 2.800 ₺ |
| GÖVDE | 11.42 sn · 350 ₺ | 11.34 sn · 700 ₺ | 11.25 sn · 1.250 ₺ | 11.17 sn · 2.100 ₺ | 11.09 sn · 3.500 ₺ |

**FULL:** 0-100 8.97 sn · 197 km/sa · 128 bg · 300 m 11.69 sn → sınıf **C**

### CHEVROLET BEL AIR (1956) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **12.0 sn** · son hız **165 km/sa** · **162 bg** · 300 m **12.99 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 11.84 sn · 164 bg · 300 ₺ | 11.72 sn · 166 bg · 600 ₺ | 11.62 sn · 167 bg · 1.050 ₺ | 11.53 sn · 168 bg · 1.800 ₺ | 11.45 sn · 169 bg · 3.000 ₺ |
| TURBO | 11.89 sn · 163 bg · 300 ₺ | 11.76 sn · 165 bg · 600 ₺ | 11.63 sn · 167 bg · 1.050 ₺ | 11.49 sn · 169 bg · 1.800 ₺ | 11.37 sn · 171 bg · 3.000 ₺ |
| HAVA | 11.90 sn · 164 bg · 200 ₺ | 11.79 sn · 166 bg · 400 ₺ | 11.68 sn · 168 bg · 700 ₺ | 11.56 sn · 170 bg · 1.200 ₺ | 11.47 sn · 172 bg · 2.000 ₺ |
| ŞANZ. | 11.96 sn · 166 km/sa · 250 ₺ | 11.92 sn · 168 km/sa · 500 ₺ | 11.80 sn · 169 km/sa · 900 ₺ | 11.65 sn · 172 km/sa · 1.500 ₺ | 11.57 sn · 173 km/sa · 2.500 ₺ |
| LASTİK | 12.00 sn · 200 ₺ | 11.92 sn · 400 ₺ | 11.87 sn · 700 ₺ | 11.82 sn · 1.200 ₺ | 11.78 sn · 2.000 ₺ |
| GÖVDE | 11.92 sn · 250 ₺ | 11.83 sn · 500 ₺ | 11.74 sn · 900 ₺ | 11.65 sn · 1.500 ₺ | 11.57 sn · 2.500 ₺ |

**FULL:** 0-100 9.44 sn · 185 km/sa · 189 bg · 300 m 11.92 sn → sınıf **C**

### HYUNDAI ERA — D · FWD · Atmosferik · fiyat 30.000 ₺
Fabrika: 0-100 **12.3 sn** · son hız **177 km/sa** · **97 bg** · 300 m **13.06 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 12.15 sn · 98 bg · 350 ₺ | 12.04 sn · 99 bg · 700 ₺ | 11.94 sn · 100 bg · 1.250 ₺ | 11.86 sn · 100 bg · 2.150 ₺ | 11.79 sn · 101 bg · 3.600 ₺ |
| TURBO | 12.17 sn · 98 bg · 350 ₺ | 12.02 sn · 99 bg · 700 ₺ | 11.89 sn · 100 bg · 1.250 ₺ | 11.73 sn · 101 bg · 2.150 ₺ | 11.59 sn · 102 bg · 3.600 ₺ |
| HAVA | 12.17 sn · 98 bg · 250 ₺ | 12.05 sn · 100 bg · 500 ₺ | 11.92 sn · 101 bg · 850 ₺ | 11.81 sn · 102 bg · 1.450 ₺ | 11.67 sn · 104 bg · 2.400 ₺ |
| ŞANZ. | 12.26 sn · 178 km/sa · 300 ₺ | 12.21 sn · 180 km/sa · 600 ₺ | 12.09 sn · 181 km/sa · 1.050 ₺ | 11.95 sn · 184 km/sa · 1.800 ₺ | 11.88 sn · 186 km/sa · 3.000 ₺ |
| LASTİK | 12.30 sn · 250 ₺ | 12.21 sn · 500 ₺ | 12.16 sn · 850 ₺ | 12.11 sn · 1.450 ₺ | 12.08 sn · 2.400 ₺ |
| GÖVDE | 12.21 sn · 300 ₺ | 12.12 sn · 600 ₺ | 12.03 sn · 1.050 ₺ | 11.95 sn · 1.800 ₺ | 11.86 sn · 3.000 ₺ |

**FULL:** 0-100 9.62 sn · 198 km/sa · 114 bg · 300 m 11.97 sn → sınıf **C**

### TOFAŞ ŞAHİN — D · RWD · Atmosferik · fiyat 15.000 ₺
Fabrika: 0-100 **13.2 sn** · son hız **165 km/sa** · bg **eksik** · 300 m **13.38 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 13.04 sn · 300 ₺ | 12.92 sn · 600 ₺ | 12.81 sn · 950 ₺ | 12.72 sn · 1.550 ₺ | 12.65 sn · 2.400 ₺ |
| TURBO | 13.05 sn · 300 ₺ | 12.89 sn · 600 ₺ | 12.74 sn · 950 ₺ | 12.58 sn · 1.550 ₺ | 12.43 sn · 2.400 ₺ |
| HAVA | 13.05 sn · 200 ₺ | 12.91 sn · 400 ₺ | 12.78 sn · 650 ₺ | 12.66 sn · 1.050 ₺ | 12.52 sn · 1.600 ₺ |
| ŞANZ. | 13.15 sn · 166 km/sa · 250 ₺ | 13.09 sn · 168 km/sa · 500 ₺ | 12.97 sn · 169 km/sa · 800 ₺ | 12.83 sn · 172 km/sa · 1.300 ₺ | 12.76 sn · 173 km/sa · 2.000 ₺ |
| LASTİK | 13.20 sn · 200 ₺ | 13.11 sn · 400 ₺ | 13.05 sn · 650 ₺ | 13.00 sn · 1.050 ₺ | 12.96 sn · 1.600 ₺ |
| GÖVDE | 13.11 sn · 250 ₺ | 13.01 sn · 500 ₺ | 12.91 sn · 800 ₺ | 12.82 sn · 1.300 ₺ | 12.72 sn · 2.000 ₺ |

**FULL:** 0-100 10.31 sn · 185 km/sa · bg — · 300 m 12.27 sn → sınıf **C**

### TOFAŞ MURAT 131 (1979) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **14.0 sn** · son hız **155 km/sa** · **75 bg** · 300 m **13.63 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 13.81 sn · 76 bg · 300 ₺ | 13.67 sn · 77 bg · 600 ₺ | 13.55 sn · 77 bg · 1.050 ₺ | 13.44 sn · 78 bg · 1.800 ₺ | 13.35 sn · 78 bg · 3.000 ₺ |
| TURBO | 13.87 sn · 76 bg · 300 ₺ | 13.71 sn · 76 bg · 600 ₺ | 13.56 sn · 77 bg · 1.050 ₺ | 13.40 sn · 78 bg · 1.800 ₺ | 13.25 sn · 79 bg · 3.000 ₺ |
| HAVA | 13.86 sn · 76 bg · 200 ₺ | 13.72 sn · 77 bg · 400 ₺ | 13.59 sn · 78 bg · 700 ₺ | 13.45 sn · 79 bg · 1.200 ₺ | 13.33 sn · 80 bg · 2.000 ₺ |
| ŞANZ. | 13.95 sn · 156 km/sa · 250 ₺ | 13.90 sn · 157 km/sa · 500 ₺ | 13.76 sn · 159 km/sa · 900 ₺ | 13.63 sn · 161 km/sa · 1.500 ₺ | 13.56 sn · 163 km/sa · 2.500 ₺ |
| LASTİK | 14.00 sn · 200 ₺ | 13.90 sn · 400 ₺ | 13.84 sn · 700 ₺ | 13.79 sn · 1.200 ₺ | 13.74 sn · 2.000 ₺ |
| GÖVDE | 13.90 sn · 250 ₺ | 13.80 sn · 500 ₺ | 13.69 sn · 900 ₺ | 13.59 sn · 1.500 ₺ | 13.49 sn · 2.500 ₺ |

**FULL:** 0-100 10.99 sn · 174 km/sa · 88 bg · 300 m 12.52 sn → sınıf **C**

### MINI COOPER (1965) — D · FWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **14.8 sn** · son hız **145 km/sa** · **55 bg** · 300 m **13.67 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 14.59 sn · 56 bg · 300 ₺ | 14.44 sn · 56 bg · 600 ₺ | 14.31 sn · 57 bg · 1.050 ₺ | 14.20 sn · 57 bg · 1.800 ₺ | 14.10 sn · 58 bg · 3.000 ₺ |
| TURBO | 14.66 sn · 55 bg · 300 ₺ | 14.49 sn · 56 bg · 600 ₺ | 14.32 sn · 57 bg · 1.050 ₺ | 14.15 sn · 57 bg · 1.800 ₺ | 13.99 sn · 58 bg · 3.000 ₺ |
| HAVA | 14.64 sn · 56 bg · 200 ₺ | 14.47 sn · 56 bg · 400 ₺ | 14.31 sn · 57 bg · 700 ₺ | 14.15 sn · 58 bg · 1.200 ₺ | 13.99 sn · 58 bg · 2.000 ₺ |
| ŞANZ. | 14.74 sn · 146 km/sa · 250 ₺ | 14.66 sn · 147 km/sa · 500 ₺ | 14.50 sn · 148 km/sa · 900 ₺ | 14.38 sn · 151 km/sa · 1.500 ₺ | 14.32 sn · 152 km/sa · 2.500 ₺ |
| LASTİK | 14.80 sn · 200 ₺ | 14.69 sn · 400 ₺ | 14.63 sn · 700 ₺ | 14.57 sn · 1.200 ₺ | 14.53 sn · 2.000 ₺ |
| GÖVDE | 14.69 sn · 250 ₺ | 14.58 sn · 500 ₺ | 14.47 sn · 900 ₺ | 14.36 sn · 1.500 ₺ | 14.24 sn · 2.500 ₺ |

**FULL:** 0-100 11.52 sn · 162 km/sa · 64 bg · 300 m 12.58 sn → sınıf **C**

### RENAULT TOROS — D · FWD · Atmosferik · fiyat 20.000 ₺
Fabrika: 0-100 **14.5 sn** · son hız **150 km/sa** · bg **eksik** · 300 m **13.82 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 14.32 sn · 300 ₺ | 14.19 sn · 600 ₺ | 14.07 sn · 950 ₺ | 13.98 sn · 1.550 ₺ | 13.88 sn · 2.400 ₺ |
| TURBO | 14.35 sn · 300 ₺ | 14.18 sn · 600 ₺ | 14.01 sn · 950 ₺ | 13.82 sn · 1.550 ₺ | 13.66 sn · 2.400 ₺ |
| HAVA | 14.35 sn · 200 ₺ | 14.19 sn · 400 ₺ | 14.05 sn · 650 ₺ | 13.90 sn · 1.050 ₺ | 13.75 sn · 1.600 ₺ |
| ŞANZ. | 14.46 sn · 151 km/sa · 250 ₺ | 14.41 sn · 152 km/sa · 500 ₺ | 14.27 sn · 154 km/sa · 800 ₺ | 14.12 sn · 156 km/sa · 1.300 ₺ | 14.05 sn · 158 km/sa · 2.000 ₺ |
| LASTİK | 14.50 sn · 200 ₺ | 14.40 sn · 400 ₺ | 14.34 sn · 650 ₺ | 14.28 sn · 1.050 ₺ | 14.23 sn · 1.600 ₺ |
| GÖVDE | 14.40 sn · 250 ₺ | 14.29 sn · 500 ₺ | 14.18 sn · 800 ₺ | 14.07 sn · 1.300 ₺ | 13.97 sn · 2.000 ₺ |

**FULL:** 0-100 11.32 sn · 168 km/sa · bg — · 300 m 12.67 sn → sınıf **C**

### TOFAŞ MURAT 124 (1971) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **16.5 sn** · son hız **145 km/sa** · **60 bg** · 300 m **14.27 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 16.27 sn · 61 bg · 300 ₺ | 16.10 sn · 61 bg · 600 ₺ | 15.95 sn · 62 bg · 1.050 ₺ | 15.83 sn · 62 bg · 1.800 ₺ | 15.72 sn · 63 bg · 3.000 ₺ |
| TURBO | 16.34 sn · 61 bg · 300 ₺ | 16.15 sn · 61 bg · 600 ₺ | 15.97 sn · 62 bg · 1.050 ₺ | 15.77 sn · 63 bg · 1.800 ₺ | 15.60 sn · 63 bg · 3.000 ₺ |
| HAVA | 16.32 sn · 61 bg · 200 ₺ | 16.14 sn · 61 bg · 400 ₺ | 15.98 sn · 62 bg · 700 ₺ | 15.79 sn · 63 bg · 1.200 ₺ | 15.64 sn · 64 bg · 2.000 ₺ |
| ŞANZ. | 16.42 sn · 146 km/sa · 250 ₺ | 16.36 sn · 147 km/sa · 500 ₺ | 16.19 sn · 148 km/sa · 900 ₺ | 16.04 sn · 151 km/sa · 1.500 ₺ | 15.97 sn · 152 km/sa · 2.500 ₺ |
| LASTİK | 16.50 sn · 200 ₺ | 16.38 sn · 400 ₺ | 16.31 sn · 700 ₺ | 16.25 sn · 1.200 ₺ | 16.19 sn · 2.000 ₺ |
| GÖVDE | 16.38 sn · 250 ₺ | 16.26 sn · 500 ₺ | 16.13 sn · 900 ₺ | 16.01 sn · 1.500 ₺ | 15.88 sn · 2.500 ₺ |

**FULL:** 0-100 12.89 sn · 162 km/sa · 70 bg · 300 m 13.12 sn → sınıf **D**

### PEUGEOT 404 (1968) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **17.0 sn** · son hız **145 km/sa** · **72 bg** · 300 m **14.50 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 16.75 sn · 73 bg · 300 ₺ | 16.59 sn · 74 bg · 600 ₺ | 16.44 sn · 74 bg · 1.050 ₺ | 16.31 sn · 75 bg · 1.800 ₺ | 16.20 sn · 75 bg · 3.000 ₺ |
| TURBO | 16.84 sn · 73 bg · 300 ₺ | 16.64 sn · 73 bg · 600 ₺ | 16.45 sn · 74 bg · 1.050 ₺ | 16.25 sn · 75 bg · 1.800 ₺ | 16.07 sn · 76 bg · 3.000 ₺ |
| HAVA | 16.83 sn · 73 bg · 200 ₺ | 16.64 sn · 74 bg · 400 ₺ | 16.48 sn · 75 bg · 700 ₺ | 16.32 sn · 75 bg · 1.200 ₺ | 16.16 sn · 76 bg · 2.000 ₺ |
| ŞANZ. | 16.93 sn · 146 km/sa · 250 ₺ | 16.87 sn · 147 km/sa · 500 ₺ | 16.71 sn · 148 km/sa · 900 ₺ | 16.54 sn · 151 km/sa · 1.500 ₺ | 16.45 sn · 152 km/sa · 2.500 ₺ |
| LASTİK | 17.00 sn · 200 ₺ | 16.87 sn · 400 ₺ | 16.81 sn · 700 ₺ | 16.74 sn · 1.200 ₺ | 16.68 sn · 2.000 ₺ |
| GÖVDE | 16.87 sn · 250 ₺ | 16.75 sn · 500 ₺ | 16.62 sn · 900 ₺ | 16.49 sn · 1.500 ₺ | 16.36 sn · 2.500 ₺ |

**FULL:** 0-100 13.30 sn · 162 km/sa · 84 bg · 300 m 13.30 sn → sınıf **D**

### VOLKSWAGEN BEETLE (1967) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **20.0 sn** · son hız **125 km/sa** · **53 bg** · 300 m **15.21 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 19.71 sn · 54 bg · 300 ₺ | 19.50 sn · 54 bg · 600 ₺ | 19.32 sn · 55 bg · 1.050 ₺ | 19.16 sn · 55 bg · 1.800 ₺ | 19.03 sn · 55 bg · 3.000 ₺ |
| TURBO | 19.80 sn · 53 bg · 300 ₺ | 19.57 sn · 54 bg · 600 ₺ | 19.34 sn · 55 bg · 1.050 ₺ | 19.09 sn · 55 bg · 1.800 ₺ | 18.87 sn · 56 bg · 3.000 ₺ |
| HAVA | 19.77 sn · 54 bg · 200 ₺ | 19.54 sn · 54 bg · 400 ₺ | 19.34 sn · 55 bg · 700 ₺ | 19.13 sn · 56 bg · 1.200 ₺ | 18.93 sn · 56 bg · 2.000 ₺ |
| ŞANZ. | 19.91 sn · 126 km/sa · 250 ₺ | 19.85 sn · 127 km/sa · 500 ₺ | 19.63 sn · 128 km/sa · 900 ₺ | 19.45 sn · 130 km/sa · 1.500 ₺ | 19.35 sn · 131 km/sa · 2.500 ₺ |
| LASTİK | 20.00 sn · 200 ₺ | 19.85 sn · 400 ₺ | 19.77 sn · 700 ₺ | 19.68 sn · 1.200 ₺ | 19.62 sn · 2.000 ₺ |
| GÖVDE | 19.85 sn · 250 ₺ | 19.70 sn · 500 ₺ | 19.54 sn · 900 ₺ | 19.39 sn · 1.500 ₺ | 19.23 sn · 2.500 ₺ |

**FULL:** 0-100 15.52 sn · 140 km/sa · 62 bg · 300 m 13.96 sn → sınıf **D**

### ANADOL A1 (1967) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **20.0 sn** · son hız **130 km/sa** · **53 bg** · 300 m **15.22 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 19.71 sn · 54 bg · 300 ₺ | 19.50 sn · 54 bg · 600 ₺ | 19.32 sn · 55 bg · 1.050 ₺ | 19.17 sn · 55 bg · 1.800 ₺ | 19.03 sn · 55 bg · 3.000 ₺ |
| TURBO | 19.80 sn · 53 bg · 300 ₺ | 19.57 sn · 54 bg · 600 ₺ | 19.34 sn · 55 bg · 1.050 ₺ | 19.10 sn · 55 bg · 1.800 ₺ | 18.88 sn · 56 bg · 3.000 ₺ |
| HAVA | 19.78 sn · 54 bg · 200 ₺ | 19.56 sn · 54 bg · 400 ₺ | 19.34 sn · 55 bg · 700 ₺ | 19.15 sn · 56 bg · 1.200 ₺ | 18.95 sn · 56 bg · 2.000 ₺ |
| ŞANZ. | 19.93 sn · 131 km/sa · 250 ₺ | 19.85 sn · 132 km/sa · 500 ₺ | 19.64 sn · 133 km/sa · 900 ₺ | 19.45 sn · 135 km/sa · 1.500 ₺ | 19.34 sn · 136 km/sa · 2.500 ₺ |
| LASTİK | 20.00 sn · 200 ₺ | 19.85 sn · 400 ₺ | 19.77 sn · 700 ₺ | 19.68 sn · 1.200 ₺ | 19.62 sn · 2.000 ₺ |
| GÖVDE | 19.85 sn · 250 ₺ | 19.70 sn · 500 ₺ | 19.54 sn · 900 ₺ | 19.39 sn · 1.500 ₺ | 19.23 sn · 2.500 ₺ |

**FULL:** 0-100 15.54 sn · 146 km/sa · 62 bg · 300 m 13.96 sn → sınıf **D**

### MERCEDES-BENZ W123 — D · RWD · Dizel (atmosferik) · fiyat 25.000 ₺
Fabrika: 0-100 **22.0 sn** · son hız **143 km/sa** · **72 bg** · 300 m **15.85 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 21.71 sn · 73 bg · 300 ₺ | 21.49 sn · 74 bg · 600 ₺ | 21.30 sn · 74 bg · 1.050 ₺ | 21.14 sn · 75 bg · 1.800 ₺ | 21.01 sn · 75 bg · 3.000 ₺ |
| TURBO | 21.70 sn · 73 bg · 300 ₺ | 21.34 sn · 74 bg · 600 ₺ | 21.00 sn · 75 bg · 1.050 ₺ | 20.64 sn · 76 bg · 1.800 ₺ | 20.32 sn · 77 bg · 3.000 ₺ |
| HAVA | 21.91 sn · 72 bg · 200 ₺ | 21.80 sn · 73 bg · 400 ₺ | 21.71 sn · 73 bg · 700 ₺ | 21.61 sn · 73 bg · 1.200 ₺ | 21.52 sn · 74 bg · 2.000 ₺ |
| ŞANZ. | 21.92 sn · 144 km/sa · 250 ₺ | 21.86 sn · 145 km/sa · 500 ₺ | 21.62 sn · 146 km/sa · 900 ₺ | 21.35 sn · 149 km/sa · 1.500 ₺ | 21.23 sn · 150 km/sa · 2.500 ₺ |
| LASTİK | 22.00 sn · 200 ₺ | 21.83 sn · 400 ₺ | 21.74 sn · 700 ₺ | 21.64 sn · 1.200 ₺ | 21.57 sn · 2.000 ₺ |
| GÖVDE | 21.83 sn · 250 ₺ | 21.66 sn · 500 ₺ | 21.48 sn · 900 ₺ | 21.31 sn · 1.500 ₺ | 21.14 sn · 2.500 ₺ |

**FULL:** 0-100 17.27 sn · 159 km/sa · 82 bg · 300 m 14.55 sn → sınıf **D**

### LAND ROVER SERIES III (1975) — D · AWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **29.0 sn** · son hız **110 km/sa** · **70 bg** · 300 m **19.04 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 28.44 sn · 71 bg · 300 ₺ | 28.03 sn · 72 bg · 600 ₺ | 27.69 sn · 72 bg · 1.050 ₺ | 27.39 sn · 73 bg · 1.800 ₺ | 27.14 sn · 73 bg · 3.000 ₺ |
| TURBO | 28.61 sn · 71 bg · 300 ₺ | 28.16 sn · 71 bg · 600 ₺ | 27.72 sn · 72 bg · 1.050 ₺ | 27.26 sn · 73 bg · 1.800 ₺ | 26.85 sn · 74 bg · 3.000 ₺ |
| HAVA | 28.51 sn · 71 bg · 200 ₺ | 28.07 sn · 72 bg · 400 ₺ | 27.65 sn · 73 bg · 700 ₺ | 27.24 sn · 73 bg · 1.200 ₺ | 26.87 sn · 74 bg · 2.000 ₺ |
| ŞANZ. | 28.88 sn · 111 km/sa · 250 ₺ | 28.81 sn · 112 km/sa · 500 ₺ | 28.50 sn · 113 km/sa · 900 ₺ | 28.36 sn · 114 km/sa · 1.500 ₺ | 28.34 sn · 116 km/sa · 2.500 ₺ |
| LASTİK | 29.00 sn · 200 ₺ | 28.75 sn · 400 ₺ | 28.61 sn · 700 ₺ | 28.47 sn · 1.200 ₺ | 28.36 sn · 2.000 ₺ |
| GÖVDE | 28.75 sn · 250 ₺ | 28.44 sn · 500 ₺ | 28.14 sn · 900 ₺ | 27.83 sn · 1.500 ₺ | 27.52 sn · 2.500 ₺ |

**FULL:** 0-100 21.43 sn · 123 km/sa · 82 bg · 300 m 17.41 sn → sınıf **D**

### WILLYS JEEP MB (1944) — D · AWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **30.0 sn** · son hız **105 km/sa** · **60 bg** · 300 m **19.44 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 29.37 sn · 61 bg · 300 ₺ | 28.92 sn · 61 bg · 600 ₺ | 28.54 sn · 62 bg · 1.050 ₺ | 28.21 sn · 62 bg · 1.800 ₺ | 27.94 sn · 63 bg · 3.000 ₺ |
| TURBO | 29.57 sn · 61 bg · 300 ₺ | 29.06 sn · 61 bg · 600 ₺ | 28.58 sn · 62 bg · 1.050 ₺ | 28.07 sn · 63 bg · 1.800 ₺ | 27.63 sn · 63 bg · 3.000 ₺ |
| HAVA | 29.40 sn · 61 bg · 200 ₺ | 28.87 sn · 61 bg · 400 ₺ | 28.38 sn · 62 bg · 700 ₺ | 27.91 sn · 63 bg · 1.200 ₺ | 27.49 sn · 64 bg · 2.000 ₺ |
| ŞANZ. | 29.74 sn · 106 km/sa · 250 ₺ | 29.60 sn · 107 km/sa · 500 ₺ | 29.23 sn · 108 km/sa · 900 ₺ | 29.08 sn · 109 km/sa · 1.500 ₺ | 29.05 sn · 110 km/sa · 2.500 ₺ |
| LASTİK | 30.00 sn · 200 ₺ | 29.73 sn · 400 ₺ | 29.58 sn · 700 ₺ | 29.42 sn · 1.200 ₺ | 29.31 sn · 2.000 ₺ |
| GÖVDE | 29.73 sn · 250 ₺ | 29.38 sn · 500 ₺ | 29.04 sn · 900 ₺ | 28.71 sn · 1.500 ₺ | 28.35 sn · 2.500 ₺ |

**FULL:** 0-100 21.80 sn · 118 km/sa · 70 bg · 300 m 17.77 sn → sınıf **D**

### FIAT 500 (1965) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **35.0 sn** · son hız **95 km/sa** · **18 bg** · 300 m **21.12 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 34.41 sn · 18 bg · 300 ₺ | 33.99 sn · 18 bg · 600 ₺ | 33.62 sn · 19 bg · 1.050 ₺ | 33.31 sn · 19 bg · 1.800 ₺ | 33.04 sn · 19 bg · 3.000 ₺ |
| TURBO | 34.60 sn · 18 bg · 300 ₺ | 34.12 sn · 18 bg · 600 ₺ | 33.66 sn · 19 bg · 1.050 ₺ | 33.17 sn · 19 bg · 1.800 ₺ | 32.73 sn · 19 bg · 3.000 ₺ |
| HAVA | 34.60 sn · 18 bg · 200 ₺ | 34.22 sn · 18 bg · 400 ₺ | 33.85 sn · 19 bg · 700 ₺ | 33.51 sn · 19 bg · 1.200 ₺ | 33.14 sn · 19 bg · 2.000 ₺ |
| ŞANZ. | 34.91 sn · 96 km/sa · 250 ₺ | 34.82 sn · 97 km/sa · 500 ₺ | 34.42 sn · 97 km/sa · 900 ₺ | 33.87 sn · 99 km/sa · 1.500 ₺ | 33.67 sn · 100 km/sa · 2.500 ₺ |
| LASTİK | 35.00 sn · 200 ₺ | 34.70 sn · 400 ₺ | 34.53 sn · 700 ₺ | 34.36 sn · 1.200 ₺ | 34.23 sn · 2.000 ₺ |
| GÖVDE | 34.70 sn · 250 ₺ | 34.38 sn · 500 ₺ | 34.07 sn · 900 ₺ | 33.76 sn · 1.500 ₺ | 33.44 sn · 2.500 ₺ |

**FULL:** 0-100 26.59 sn · 106 km/sa · 21 bg · 300 m 19.21 sn → sınıf **D**

### VOLKSWAGEN T1 (1965) — D · RWD · Klasik (karbüratör) · fiyat 25.000 ₺
Fabrika: 0-100 **40.0 sn** · son hız **105 km/sa** · **44 bg** · 300 m **21.93 sn** · kalkış patinajı 0.00 sn

| Kategori | SOKAK | SPOR | YARIŞ | PRO | EFSANE |
|---|---|---|---|---|---|
| MOTOR | 39.22 sn · 45 bg · 300 ₺ | 38.66 sn · 45 bg · 600 ₺ | 38.17 sn · 45 bg · 1.050 ₺ | 37.75 sn · 46 bg · 1.800 ₺ | 37.40 sn · 46 bg · 3.000 ₺ |
| TURBO | 39.46 sn · 44 bg · 300 ₺ | 38.83 sn · 45 bg · 600 ₺ | 38.22 sn · 45 bg · 1.050 ₺ | 37.57 sn · 46 bg · 1.800 ₺ | 37.00 sn · 46 bg · 3.000 ₺ |
| HAVA | 39.58 sn · 45 bg · 200 ₺ | 39.16 sn · 45 bg · 400 ₺ | 38.78 sn · 46 bg · 700 ₺ | 38.39 sn · 46 bg · 1.200 ₺ | 37.99 sn · 47 bg · 2.000 ₺ |
| ŞANZ. | 39.95 sn · 106 km/sa · 250 ₺ | 39.87 sn · 107 km/sa · 500 ₺ | 39.32 sn · 108 km/sa · 900 ₺ | 38.00 sn · 109 km/sa · 1.500 ₺ | 37.56 sn · 110 km/sa · 2.500 ₺ |
| LASTİK | 40.00 sn · 200 ₺ | 39.59 sn · 400 ₺ | 39.36 sn · 700 ₺ | 39.14 sn · 1.200 ₺ | 38.96 sn · 2.000 ₺ |
| GÖVDE | 39.59 sn · 250 ₺ | 39.18 sn · 500 ₺ | 38.76 sn · 900 ₺ | 38.35 sn · 1.500 ₺ | 37.93 sn · 2.500 ₺ |

**FULL:** 0-100 29.05 sn · 118 km/sa · 51 bg · 300 m 19.45 sn → sınıf **D**

