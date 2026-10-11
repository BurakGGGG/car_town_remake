# HURDALIK (Junkyard) — Araştırma raporu

Durum: 2026-10-11. Konu: orijinal Car Town'ın (Cie Games, Facebook, 2010–2014) **Junk Yard** güncellemesi.
Hurdalık mekânı, hurda yığınları, araç restorasyonu, Master Mechanic kademesi, parça ekonomisi ve sosyal
taraf incelendi. Ardından bizim oyunun bugünkü sistemleriyle eşleme ve entegrasyon önerisi geliyor.

Referans görüntüler depo dışında: `~/Projects/ct_shots/junkyard_referans/` (18 kare; dosya adları bu
belgede geçer).

---

## 1. Özet

- **Ne:** Hurdalık, haritadaki (GPS) ayrı bir mekândı. Oradan **satın alınamayan, yalnızca restorasyonla
  kazanılan** araçların projesi başlatılıyordu. Hepsi klasik, konsept ya da yarış aracıydı.
- **Döngü:**
  1. Hurdalıkta araç seçilir. Kazanılmamış araç **siluet** olarak görünür.
  2. RESTORE'a basılır. Bunun için **boş bir tamir lifti ve işçi** gerekir.
  3. Paslı **çıplak şasi** oyuncunun kendi garajında lifte çıkar.
  4. Restorasyon paneline 6 tür **genel parça** "envanterden eklenir".
  5. %100 olunca araç **depoya** düşer.
- **Parça kaynakları (üç tane):**
  1. Hurdalıktaki **çöp yığınlarını aramak.** Şansa bağlıdır, "No car part found." da çıkabilir.
  2. **Arkadaştan istemek.** Gönderme bekleme süresi ~6 saatti.
  3. **Blue Points (premium para) ile satın almak.** Parça başına ya da tek tuşla **"Buy All"**.
- **Kademe:** 10 temel restorasyon bitince **Master Mechanic** unvanı açılır (Facebook paylaşımı vardı).
  Altında iki dal var: **Classic Cars** (15 araç) ve **Race Cars** (16 araç, 2012-12-06'da eklendi). Bu
  araçlar 3 tür parçadan 6'şar, 3 türden 20'şer, toplam **78 parça** istiyordu (XJ220 ölçümü). Temel
  araçlar 6 türden **1'er parça** istiyordu (Fiat 500 ölçümü).
- **Neden sevildi:**
  - Parayla alınamayan, prestijli araçlar.
  - Şasinin **kendi garajında, liftte** görünmesi.
  - Siluetli koleksiyon listesi.
  - Unvan.
  - Düzenli eklenen yeni araçlar (live-ops).
- **Neden sinir etti (forum, 2011):**
  - Proje lifti **günlerce** işgal ediyordu ve tamir geliri düşüyordu.
  - Az arkadaşı olan ancak parayla ilerleyebiliyordu.
  - Parça göndermenin ödülü yoktu.
  - "Buy All" **onaysız** premium para harcıyordu; bir oyuncu yanlışlıkla 38 BP (≈3,80 $) kaybetti.
- **Bizim için öneri (§6):**
  - Haritada yeni **HURDALIK** parseli.
  - Kendi ekranında 3D hurdalık sahnesi (showroom gibi).
  - Yığın aramasında zamanlayıcı ve şanssızlık koruması olacak.
  - Tamir işlerinden de parça düşecek; böylece arkadaşa bağımlılık kalkar.
  - Gemle parça alımı **onaylı** olacak.
  - Klasik Türk ve dünya araçlarından oluşan, **kasada ve showroom'da olmayan** bir restorasyon kataloğu.
  - Kullanıcı kararları §7'de: proje mevcut tamir alanını kaplar, yığın saf şans, parça kaynaklarının
    dördü birden.

---

## 2. Kaynaklar ve yöntem

| Kaynak | Ne alındı |
|---|---|
| Car Town Wiki (fandom; MediaWiki API'si üzerinden ham wikitext) | Junkyard, Basic Restorations, Master Mechanic: Classic / Race Cars sayfaları; restorasyon araçlarının bilgi kutuları (satış değeri, XP, renk / body kit kısıtı); Blue Points / Gold Coins fiyatları; Rusty, The Docks, Neighbors |
| YouTube, 5 video (2011-10-05 → 2014-08-21), ~3.000 kare içinden 4 sn aralıkla çıkarılan kareler | Mekân, yığın penceresi, restorasyon paneli (Fiat 500 ve XJ220 baştan sona), Master Mechanic listeleri, tamamlanma, Facebook paylaşımı |
| cartown.com resmî SSS (Wayback Machine) | "Add from Inventory" mekanizması, arkadaştan gelen parçaların gittiği yer |
| cartown.com/forum (Wayback Machine, 2011) | Açılış tarihi, yeni araç duyurusu, parça hediyesi şikâyetleri, gönderme bekleme süresi, "Buy All" onay şikâyeti |

Videolar: `qc6Q18-iOGc` (2014, tüm hurdalık + Master Mechanic), `76BGQYcGwas` (2013, tüm restorasyonlar),
`OgeRzmTcUM8` (2012, XJ220 baştan sona), `JQeUy4qbOhY` (2012, Fiat 500 restorasyonu), `gOz-hk01EBg`
(2011, açılış haftası, kameradan çekim).

**Doğrulanamayanlar** (kaynakta yok; tasarımda varsayım olarak işaretlenmeli):
- Yığınların yenilenme süresi, sayısı, düşme oranları.
- Yığın aramanın yakıt / enerji harcayıp harcamadığı. Üst sağdaki yakıt göstergesinde "More in: mm:ss"
  sayacı görünüyor, ama aramayla ilişkisi kanıtlanamadı.
- Parça başına BP fiyatları.
- Fiat ile XJ220 dışındaki araçların tam parça listesi.
- Aynı anda kaç restorasyon yürütülebildiği.

---

## 3. Orijinal hurdalık — ayrıntılar

### 3.1 Zaman çizelgesi

| Tarih | Olay | Kaynak |
|---|---|---|
| 2011 Eylül sonu | GPS haritasında "Junkyard — Coming Soon!" afişi. Oyuncular sabırsız | forum t-33622 |
| 2011-10-05 / 06 | Hurdalık açıldı ("New Junk Yard" videosu, forumda "we are supposed to get the junkyard today") | video `gOz-hk01EBg`, forum |
| İlk hâli | Araç serbestçe seçilmiyordu. **Her gün değişen 4 araçtan** biri seçiliyordu. Master Mechanic yoktu | wiki "Basic Restorations / Facts" |
| 2011-11-28 | "Two new restoration cars!": 1966 Pontiac GTO Convertible + 1965 Alfa Romeo Giulia Super | forum t-35305 |
| 2011-11 | Resmî "Weekly Highlight Location: Junkyard" konusu. Oyuncular kamyon / çekici restorasyonu istiyor | forum t-33940 |
| (wiki: 2011-12) | Wiki "Basic Restorations Aralık 2011'de eklendi" diyor. Forum ve video Ekim'i gösteriyor; wiki muhtemelen tam listeye geçişi kastediyor | wiki |
| 2012 | Master Mechanic: Classic Cars | videolar |
| 2012-12-06 | Master Mechanic: Race Cars ("tamamen beklenmedik"). Önceden yalnızca BP ile satılan 9 araç buraya taşındı | wiki |
| 2014-08-29 | Oyun kapandı | wiki |

### 3.2 Mekân (görüntü 01, 07, 18)

- **GPS** penceresindeki "What's new!" sekmesinde, Ghostbusters, Top Gear, NHRA Dragstrip ve Game Show
  ile birlikte **Junk Yard** binası var: ahşap baraka, üstünde "JUNK" tabelası.
- Tıklayınca "**Calculating Route!**" geçişi gelir (sarı yol üzerinde kırmızı ok). Mekândan çıkarken de
  aynı geçiş "Comin' back to hometown!" yazısıyla oynar.
- İzometrik sahne:
  - Konteyner duvarlarla çevrili toprak saha, yüksek tel çit, sokak lambaları.
  - Lastik yığınları ve sarı **mıknatıslı vinç**.
  - Hurda dolu açık konteynerler.
  - Tekerleksiz **çıplak araç iskeletleri**.
  - Işığı yanan **"JUNK" barakası**, önünde koltuk ve masa.
  - Kırmızı tabela.
  - **Paslı mavi Shelby Cobra.** Reklamı yapılan araç, ödülün vitrini.
- **İki NPC var:**
  - Barakanın önünde tulumlu, şapkalı ihtiyar usta.
  - Sahada konuşma balonlu bir işçi: *"Search junk piles for a chance to get free parts for your car
    build!"*
- **Alt çubuk:** sol köşede `Junk Yard` adı, yanında iki düğme: **Master Mechanic** (anahtar ikonu) ve
  **Restore Cars** (araç ikonu).

### 3.3 Hurda yığınları (görüntü 01, 18)

- Aranabilir yığınlar sarı çerçeveyle **vurgulanır**. 76BG videosunda aynı anda 3–4 vurgulu yığın var:
  konteyner tepesi, saha köşesi, barakanın yanındaki kutu.
- Yığına tıklayınca "**Junk pile contents…**" penceresi açılır: büyüteç ikonu ve sonuç.
- Kaydedilen sonuç: *"No car part found. Search junk piles for a chance to get free parts for your car
  build"* + OK.
- Arama **şansa bağlı** ve **boş da çıkabiliyor**. Yenilenme süresi bilinmiyor (bkz. §2).

### 3.4 Restore Cars — temel restorasyonlar (görüntü 02, 03)

Pencerenin adı "**Completed Restorations — Restore these cars in your garage!**". 4'lü sayfalar halinde
araç kartları var. Her kartta yıl + ad, küçük 3D araç ikonu, **sınıf rozeti** (D / C / B / A / ★) ve
**performans puanı** yazıyor. Sağ altta **Master Mechanic ilerleme çubuğu** (`10 / 10`).

| Araç | Sınıf | Perf. |
|---|---|---|
| '62 Ford Thunderbird | B | 290 |
| '60 Fiat Nuova 500 D | D | 48 |
| '34 Chrysler Airflow | A | 117 |
| '36 Dodge Pickup | B | 136 |
| '50 Ford F-1 | C | 120 |
| '36 Dodge Panel Pickup | B | 136 |
| '53 Cadillac El Dorado | A | 175 |
| '65 Alfa Romeo 2600 SZ | A | 353 |
| '55 Ford Thunderbird | C | 380 |
| '59 Chevrolet Impala | B | 345 |
| '61 Chrysler 300G | A | 374 |
| '41 Plymouth Deluxe Woody Wagon | A | 111 |
| '59 Cadillac El Dorado | A | 280 |
| '50 VW Transporter | B | 95 |
| '65 Alfa Romeo Giulia Super | C | 192 |
| '41 Jeep Willys MB | B | 87 |
| '61 Chrysler Turboflite | A | 188 |
| ('66 Pontiac GTO Convertible) | ? | ? |

GTO videodaki 17'lik listede yok; wiki ve forum duyurusunda var. Muhtemelen sonradan kaldırıldı.

**Araç bilgi kutularındaki (wiki) ortak kurallar:**
- *Cost: "Cannot Purchase — Must be earned through the Junkyard Restoration Challenge"*.
- **XP gain: No**, **Body kit: No**, **Colors choice: No**, **Level unlock: No**.
- **Resell value** düşük: Willys 10.000 GC, X-2000 11.500 GC.
- Restore edilen araç fabrika renginde gelir, ama jant değiştirilebilir (XJ220 videosu).

### 3.5 Restorasyonu başlatmak (görüntü 12, 09)

1. Listede henüz kazanılmamış araç **siyah siluet**tir. Tıklayınca "**Vehicle Restoration**" penceresi
   açılır: *"Restore this car in your garage to unlock a rare vehicle!"*, siluet, sınıf ve perf, altta
   küçük harfle *"Requires one available workbay and worker"*, düğmeler **Close / Restore**.
2. RESTORE → oyuncu **kendi garajına** döner. Proje bir **tamir liftine** yerleşir. Liftin üstünde
   balon: *"Vehicle Restoration · '60 Fiat Nuova 500 D · (click to check)"*. Lift o süre boyunca
   tamir işi alamaz.

### 3.6 Restorasyon paneli (görüntü 08, 13–15)

```
┌──────────────────── Restoration ────────────────────┐
│ 🚗 Restore this car to mint condition!              │
│ Progress: ███████░░░░ 67%        '60 Fiat           │
│                                  [D] ◎48 Nuova 500 D│
│   [ paslı şasi                   ┌Paint──┐┌Pistons┐┌Bolts──┐
│     döner lift                   │ 1/1 ✓ ││ 1/1 ✓ ││ 1/1 ✓ │
│     üstünde ]                    ├Spark──┤├Nuts───┤├Gears──┤
│                                  │0/1[Add││0/1[Add││1/1 ✓  │
│                                  └───────┘└───────┘└───────┘
│ (Quit Challenge)            [ Buy All ]             │
└─────────────────────────────────────────────────────┘
```

- **Sol:** sarı-siyah şeritli zemin plakası üzerinde **tek kolonlu lift** ve üstünde **paslı çıplak
  şasi**. XJ220'de tekerleksiz pas rengi iskelet. Proje bitene kadar şasi görüntüsü değişmiyor; ilerleme
  görsel olarak yalnızca çubukta.
- **Sağ:** 6 parça kutusu. Her kutuda şunlar var:
  - Parça adı ve ikonu.
  - **Envanter sayısı** (ikonun sağ üstünde küçük rakam, örn. 27).
  - `takılan / gereken`.
  - Duruma göre düğme:
    - Envanterde varsa **"Add from Inventory"**.
    - Envanter 0 ise iki küçük düğme: **"Ask Friends"** ve **"◎ N Buy"** (BP ile tek tek; görüntü 15'te
      "Motor Oil 16/20" kutusunda).
    - Tamamlanınca yeşil **`N/N ✓`**.
- **Alt:** sol altta küçük **Quit Challenge**, ortada büyük mavi **Buy All**. %100 olunca Buy All'un yerine
  **Continue** gelir.
- **İlerleme = takılan parça toplamı / gereken parça toplamı.** Ölçümle doğrulandı:
  - XJ220: 12/78 = %15 (ekranda 16), 29/78 = %37 (38), 62/78 = %79 (80), 74/78 = %95 (95).
  - Fiat: 1/6 = 17, 4/6 = 67.
- **Parçalar genel**, araca özgü değil. Bir türden yığılabiliyor: XJ220'ye başlarken envanterde 16–44
  arası. Yani oyuncu araç başlatmadan önce **stok yapabiliyordu** (forumda da bu isteniyor).

**Ölçülen parça reçeteleri:**

| Araç (kademe) | Parçalar | Toplam |
|---|---|---|
| '60 Fiat Nuova 500 D (temel, D 48) | Paint 1, Pistons 1, Bolts 1, Spark Plugs 1, Nuts 1, Gears 1 | 6 |
| '92 Jaguar XJ220 (Master Classic, A 726, listenin en üstü) | Pistons 6, Spark Plugs 6, Gears 6, Motor Oil 20, Belts 20, Fiberglass 20 | 78 |

Wiki'ye göre Master Classic parça türleri: Gears, Pistons, Spark plugs, Motor Oil, Fiberglass, Belts. Temel
kademe ise Paint, Pistons, Bolts, Spark Plugs, Nuts, Gears kullanıyor. **Kademeye göre parça seti
değişiyor**; Pistons, Spark Plugs ve Gears ortak, gerisi kademeye özgü. Gereken miktar, aracın
performansıyla ve kademeyle büyüyor.

### 3.7 Tamamlanma (görüntü 10, 16)

- "**Restoration Complete!**" penceresi: araç (tam renkli, parlak), sarı patlama rozetiyle **"placed in
  your storage!"**, ad, sınıf ve perf; düğmeler **Close / Share**.
- Araç depoya gider. Oyuncu Edit Garage → Car Storage'dan garajına koyar (Fiat videosunda '34 Chrysler
  Airflow ve '65 Alfa 2600 SZ sergide).
- Fiat videosunda tamamlanma hemen bir koleksiyon penceresini de tetikliyor ("2/4 The Starter
  Collection"). Bu restorasyondan bağımsız olan genel koleksiyon sistemi.

### 3.8 Master Mechanic (görüntü 04–06, 11, 17)

- **Açılış:** 10 temel restorasyon. Temel listedeki çubuk `10 / 10` dolunca açılıyor. Facebook duvar
  paylaşımı çıkıyor: *"X is now a Master Mechanic! … has reached Master Mechanic status and is now on
  their way to restoring some awesome, rare cars in Car Town!"*
- **Giriş penceresi:** "MASTER Mechanic" anahtar logosu, alevli kırmızı zemin, *"Select the car that you
  want to restore"*, iki büyük seçenek: **Classic Cars** (kırmızı roadster) / **Race Cars** (mavi
  Cobra).
- **Live-ops:** Yeni araç geldiğinde oyuna girişte "**New Master Mechanic Car!**" duyuru penceresi
  (XJ220).
- Listeler **performansa göre artan sırada**. Liste aynı zamanda bir zorluk merdiveni.

**Classic Cars (15):**

| Araç | Sınıf | Perf |
|---|---|---|
| '57 BMW 507 Roadster | A | 207 |
| '65 Dodge Deora | A | 244 |
| '59 Jaguar Mark II | B | 277 |
| '58 Ford X-2000 | A | 290 |
| '59 Cadillac Cyclone | A | 295 |
| '56 Chevrolet Nomad | A | 314 |
| '56 Buick Centurion Concept | ★ | 325 |
| '60 Plymouth XNR Concept | ★ | 345 |
| '63 Aston Martin DB5 | A | 349 |
| '61 Jaguar E-Type Coupe | ★ | 366 |
| '69 Dodge Charger III Prototype | A | 423 |
| '65 Alfa Romeo Giulia TZ2 Pininfarina | ★ | 497 |
| '57 Jaguar D-Type | ★ | 518 |
| '64 Lamborghini 350GT | A | 527 |
| '92 Jaguar XJ220 | A | 726 |

**Race Cars (16):**

| Araç | Sınıf | Perf |
|---|---|---|
| '11 Mitsubishi Racing Lancer Dakar Ed. | A | 313 |
| '12 Scion tC Race Ed. | A | 410 |
| '12 Mazda Mazdaspeed3 Race Ed. | A | 433 |
| '03 Mitsubishi Lancer Evo VIII Rally | B | 465 |
| '12 Scion FR-S Race Prototype | B | 533 |
| '12 Ford Fiesta RS WRC | B | 544 |
| '75 BMW 3.0 CSL | A | 614 |
| '11 Lotus Evora Type 124 | A | 615 |
| '12 Lotus Exige R-GT | A | 630 |
| '00 Dodge Viper GTS-R Concept | A | 668 |
| '64 Shelby Daytona Coupe | A | 670 |
| '65 Shelby Cobra 427 S/C | A | 719 |
| '11 BMW Z4 GT3 | A | 769 |
| '12 Volvo S60 Polestar TTA | A | 857 |
| '86 Ford RS200 Rally Ed. | A | 859 |
| '12 McLaren MP4-12C GT3 | ★ | 877 |

**Perf aralıkları:** temel 48–380, Classic 207–726, Race 313–877. Kademeler kısmen örtüşüyor; her dal
kendi içinde yükseliyor.

### 3.9 Sosyal taraf (SSS + forum)

- **Ask Friends:**
  - Parça isteği arkadaşlara Facebook isteği olarak gidiyordu.
  - Gönderilen parça **normal depoya değil**, restorasyon panelindeki envanter sayısına ekleniyordu. Bu
    resmî SSS'de stock car (NASCAR) yapımı için yazıyor; aynı "Add from Inventory" mekanizması.
  - Bir arkadaşa tekrar parça göndermek için **~6 saat** beklemek gerekiyordu (forum, Dom's Charger
    parçaları için).
- **Şikâyetler** (forum t-33712 "Rewards for gifting parts", 2011-10):
  - *"I can't tell you how many times I have had a project sitting on a lift for a few days just because
    people would not send parts."*
  - Arkadaş sayısı azaldıkça istekler günde 20–30'dan 7'ye düşmüş, hepsi de alan taraf.
  - *"having one lift down can really slow things down when you got a car that is 90% done and has been
    there for days"*.
  - Öneri: parça gönderene ödül verilsin (günlük girişe benzer bir şey).

### 3.10 Para tarafı

- Premium para **Blue Points**: 5 $ = 50 BP … 100 $ = 1.200 BP. Normal para Gold Coins: 5 $ = 60.000 GC.
- Eksik parça BP ile **tek tek** ya da **Buy All** ile alınıyordu. Restorasyon araçları satın alınamadığı
  için "parayla atla" yolu yalnızca bu parça alımıydı.
- **Onaysız Buy All** (forum t-25316): Buy All tek tıkla BP harcıyor, onay sormuyordu. Oyuncular
  kapatma düğmesi sanıp bastı; 38 BP ve 70 BP kaybı anlatılıyor. Moderatör "geliştiricilere iletildi"
  diyor. **Kesin ders: premium harcama her zaman onaylı.**

### 3.11 Yakın sistemler

- **Rusty:** her oyuncunun ilk "komşusu" olan NPC. Adı pastan geliyor; hurdalık temasıyla akraba.
- **Salvaged Trucks Collection:** garajın dışına gelen hurda gıda kamyonları (dondurma, taco, süt, çiçek)
  duvarda paylaşılarak toplanıyordu. Ödül 1.000 GC + 100 XP. Hurdalıktan ayrı, ama "kurtarılmış araç"
  teması ortak.
- **The Docks:** BP karşılığı rastgele araç veren liman (bizdeki kasa sistemine benziyor).

---

## 4. Tasarım analizi

**Çalışan taraflar (alınmalı):**
1. **Satın alınamayan ödül.** Restorasyon aracı showroom'da ya da kasada yok. Değeri emekten geliyor.
2. **Projenin garajda görünmesi.** Liftte paslı şasi, arkadaş ziyaretinde de görünür.
3. **Siluetli koleksiyon listesi** ve performansa göre artan merdiven: "sıradaki" her zaman belli.
4. **Genel, yığılabilir parçalar.** Oyuncu proje olmadan da biriktirebiliyor, her arama boşa gitmiyor.
5. **Kademe ve unvan** (10 restorasyon → Master Mechanic) ve iki dal.
6. **Live-ops:** "New Master Mechanic Car!" ile yeni araç eklemek ucuz bir içerik akışı.

**Çalışmayan taraflar (düzeltilmeli):**
1. **Proje lifti işgal ediyordu.** Ana gelir kaynağıyla çatışıyordu ve günlerce süren projeler oyuncuyu
   cezalandırıyordu.
2. **Arkadaş bağımlılığı.** Az arkadaşı olan ancak parayla ilerleyebiliyordu.
3. **Onaysız premium harcama.**
4. **Boş arama.** "No car part found" sinir bozucu, şanssızlık koruması yok.
5. **Şasi görüntüsü ilerledikçe değişmiyordu.** Görsel ödül yalnızca en sonda geliyordu.

---

## 5. Bizim oyunla eşleme (bugünkü durum)

| Orijinal | Bizde bugün | Not |
|---|---|---|
| GPS haritasındaki mekân | GPS yok. Mekânlar şehirde bina: SHOWROOM (`WorldDressing._build_showroom`, `ShowroomHitbox` → `ShowroomScreen`, kendi SubViewport'u), drag pisti | Hurdalık şehirde yeni bir parsel olur. Tıklayınca kendi 3D ekranı açılır (showroom kalıbı) |
| Workbay + worker | 3 tamir alanı (`RepairBayManager`, 0 / 5.000 / 12.000 ₺), işler 6 sn – 5 dk | Restorasyonu tamir alanına koymak geliri doğrudan düşürür (orijinaldeki şikâyet) |
| Klasik, satılmayan araçlar | 26 araç. Hepsi kasadan (gem) ya da showroom'dan (keşfedilmişse ₺). Klasik olarak yalnızca Şahin ve Toros var | Restorasyon için **yeni** araç modelleri gerekir. Asset'leri kullanıcı üretir ([[kasa-sistemi]] kararı) |
| Sınıf D / C / B / A / ★ | Sınıf D / C / B / A / S, `race{}` değerleri | Birebir eşleşir |
| Blue Points | Gem (günde ~25–35, IAP var) | Parça satın alma iyi bir gem harcama yeri. **Onay zorunlu** |
| Ask Friends / hediye | Arkadaş kodu, istek, garaj ziyareti var. **Hediye yok** | Hediye için yeni Firestore koleksiyonu + kural + rules_test gerekir. İkinci aşamaya bırakılabilir |
| Facebook paylaşımı | Yok | Unvan rozeti profil / garaj tabelasında gösterilebilir |
| Koleksiyon | Kasa setleri (`crates.json` sets), CollectionScreen | Restorasyon kendi listesine sahip olmalı |
| Kayıt | v10 | v11: `"junkyard": {parça envanteri, aktif proje(ler), tamamlananlar, yığın zamanlayıcıları}` |

---

## 6. Entegrasyon önerisi (v1)

### 6.1 Mekân: HURDALIK parseli
- Şehirde boş bir köşeye (yol kollarının birinde) çitli parsel kurulur: konteyner duvar, lastik yığını,
  vinç, baraka, "HURDALIK" tabelası. Kod + Blender modeli, showroom ile aynı yol (`tools/world/*.py`).
- Tıklayınca **HurdalıkScreen** açılır: kendi SubViewport'unda hurdalık sahnesi, aranabilir yığınlar,
  restorasyon lifti, usta NPC.
- Alt plakalar: **RESTORASYONLAR** (liste) ve **PARÇALAR** (envanter).

### 6.2 Parça ekonomisi
- **Parça türleri, iki set:**
  - Temel: CIVATA, SOMUN, BOYA, BUJİ, PİSTON, DİŞLİ.
  - Usta: BUJİ, PİSTON, DİŞLİ, MOTOR YAĞI, KAYIŞ, FİBERGLAS.
  - Orijinaldeki ayrım korunur. Reçete aracın sınıfından türer (Fiat 6×1 → XJ220 3×6 + 3×20).
- **Kaynaklar:**
  1. **Yığın arama:** N yığın, her biri arandıktan sonra bir süre sonra dolar (öneri: 3 yığın, 4 saat).
     Her aramada 1–3 parça. Boş sonuç olacaksa üst üste en fazla 1 kez.
  2. **Tamir işlerinden düşme:** Örneğin her tamirde %x şansla 1 parça. Arkadaşı olmayan da ilerler ve
     ana döngüye bağlanır.
  3. **Gemle alma:** parça başına sabit fiyat, her zaman **onay plakası** ile. "Hepsini al" ya hiç
     olmaz ya da toplam fiyatı gösteren iki adımlı onayla olur.
  4. *(Aşama 2)* **Arkadaş hediyesi:** günde 1 hediye; **gönderen de ödül alır** (forumdaki öneri).
- **Simülasyon:** `tools/economy/` altına bir restorasyon simülasyonu. Hedef: temel araç ~1–2 gün,
  usta araç ~1–2 hafta (düzenli oyuncu, gem harcamadan).

### 6.3 Restorasyon alanı (karar: mevcut tamir alanı, bkz. §7)
- Proje, açık tamir alanlarından birini kaplar. Orijinaldeki "Requires one available workbay"
  kuralı.
- `RepairManager.capacity()` / `_free_bay` projeli alanı dolu sayar. O alana müşteri gönderilmez.
- Proje liftte durur, arkadaş ziyaretinde de görünür.
- Projeyi bırakmak (Quit) alanı boşaltır. Takılmış parçaların ne olacağı tasarımda belirlenmeli
  (öneri: envantere geri döner).

### 6.4 Görsel ilerleme (orijinalden iyi yapılacak yer)
Projedeki araç tek kare değil, **3 aşamada** değişsin:
1. **%0–33:** paslı, tekerleksiz. Mevcut araç modeli + pas shader'ı + gizli tekerlekler.
2. **%34–99:** astar gri, tekerlekli.
3. **%100:** fabrika boyası + parlama + "RESTORASYON TAMAMLANDI" plakası.

Mevcut boya maskesi (`car_paint.gdshader`, `_paintmask.png`) ve CarPartMap rolleri (wheels / tires /
glass) bunu yeni model gerektirmeden destekler. Paslı görünüm aynı maskeye bir pas dokusuyla bindirilir.

### 6.5 Ödül araçları
- `cars.json`'a `"obtain": "restoration"` alanı eklenir.
- Bu araçlar kasa havuzuna ve showroom'a **girmez**. Kasa çekilişi ve ₺ satın alma bu bayrağı dışlar.
- Örnek klasik liste (kullanıcı modelleri üretecek):
  - Temel: Tofaş Murat 124, Anadol A1, VW Beetle, Fiat 500, Mercedes W123, Land Rover Defender.
  - Usta Klasik: Ford Mustang '67, Chevrolet Bel Air '57, Jaguar E-Type, Porsche 911 '73 …
  - Usta Yarış: rallici, eski DTM, Group B …
- **Mevcut araçların paslı versiyonu** ile başlanabilir. Model beklemeden sistem test edilir; gerçek
  ödül araçları geldikçe katalog büyür.

### 6.6 Kademe
- 10 temel restorasyon → **USTA RESTORATÖR** unvanı.
- Usta Klasik ve Usta Yarış dalları açılır.
- Unvan profilde ve garaj tabelasında görünür.
- GÖREVLER'e günlük "3 yığın ara", başarım "ilk restorasyon / 10 restorasyon" eklenir.

### 6.7 Teknik iskelet (tahmini)
| Dosya | Görev |
|---|---|
| `gameplay/junkyard/junkyard_manager.gd` | Parça envanteri, yığın zamanlayıcıları, aktif projeler, kayıt durumu (GarageSystem kodla kurar, grup `junkyard`) |
| `gameplay/junkyard/restoration_catalog.gd` + `vehicles/restorations.json` | Araç → kademe, reçete, sıra |
| `gameplay/junkyard/part_catalog.gd` | Parça türleri, ikon, gem fiyatı |
| `world/junkyard_lot.gd` | Şehirdeki parsel + tıklama kutusu |
| `ui/hud/junkyard_screen.gd` | 3D hurdalık ekranı (UiRouter) |
| `ui/hud/restoration_panel.gd` | 6 kutulu panel (container tabanlı) |
| `vfx/rust.gdshader` | Pas / astar aşamaları |
| `tests/junkyard_test.gd`, `qa/junkyard_qa.gd`, `tools/economy/restoration_sim.py` | Test, görsel QA, ekonomi |
| `SaveManager` v10 → v11 | `junkyard` bloğu, eski kayıt boş envanterle yüklenir |
| `locale/*.json` | TR / EN / ES metinleri (`Loc.t`) |

Sahne (.tscn) düzenlemesi gerekmez: her şey mevcut kalıpla kodla kurulur.

---

## 7. Kararlar (kullanıcı, 2026-10-11)

1. **Restorasyon yeri: mevcut tamir alanı (orijinal gibi).** Proje 3 tamir alanından birini kaplar. §6.3'teki
   ayrı lift önerisi geçersiz. Gerilim bilinçli olarak korunur. Gelir kaybı ekonomi simülasyonunda
   ölçülmeli.
2. **Ödül araçları: yeni klasik modeller.** Modelleri kullanıcı üretir. Sistem önce mevcut araçların
   paslı hâliyle test edilir, modeller geldikçe katalog büyür.
3. **Parça kaynakları: dördü birden.** Yığın arama, tamir işlerinden düşme, gemle onaylı satın alma ve
   arkadaş hediyesi.
4. **Boş yığın: saf şans (orijinal gibi).** Boş çıkabilir, şanssızlık koruması yok.

Sorulmadı, varsayılan (değiştirilebilir):
- **"Hepsini al" onaylı:** toplam gem fiyatını gösteren onay plakası.
- **Kademe orijinaldeki gibi:** 10 temel restorasyon → USTA RESTORATÖR, iki dal (Klasik / Yarış).
