# GARAJLARIM — Araç garajları, arama/sıralama, iç yükseltmeler

Durum: 2026-10-19. Kullanıcıyla soru-cevapla kararlaştırıldı.
- **FAZ 1 uygulandı:** `AllCarsScreen`, `VehicleSort`, `RaceManager` araç sayaçları; test `tests/all_cars_test.gd`.
- **FAZ 2 uygulandı:** `CarGarageCatalog` (veri), `CarGarageManager` (durum, kayıt `car_garages`),
  `CarGaragesScreen` (GARAJLARIM), `CarGarageUpgradeScreen` (İÇ YÜKSELTMELER), garaj ekranında seçici /
  TAŞI / bekleyenler / boş garaj; `GemSkip.cost_long`; test `tests/car_garage_test.gd`. Garajlar şimdilik
  KUTU garaj: bugünkü oda, duvarlar garajın rengine boyanır.
- Faz 3–4 henüz kodda yok. Konu ARAÇLAR ekranı
(`ui/hud/garage_screen.gd`): bugün tek bir garaj odası var ve içinde yalnızca lifteki araç duruyor.
Bu belge ekranın arama/sıralama özelliğini ve 5 garajlık koleksiyon sistemini anlatır.

**Kayıt notu:** Oyun üretime çıkmadı. Üretime çıkınca bütün hesaplar silinecek, herkes sıfırdan
başlayacak. Bu yüzden eski kayıtlar için göç yazılmıyor, kayıt biçimi serbestçe değişebilir.

**Ad çakışması:** Ana dünyadaki "GARAJ SEVİYESİ" geliştirmesi (`garage_level`, tamirhanenin
büyüklüğü) bu sistemden AYRIDIR ve olduğu gibi kalır. Yeni sistemin oyuncuya görünen adı
**GARAJLARIM**, garajlar tek tek adlarıyla anılır (MAHALLE GARAJI, NEON YERALTI…).

## 1. Arama, filtre, sıralama (FAZ 1)

### Yerleşim
- Alt araç şeridi kalır. Şeritte **içinde bulunulan garajın** araçları durur.
- Şeridin solunda **TÜM ARAÇLAR** plakası durur (ızgara ikonu + araç sayısı). Bu plaka tam ekran bir ızgara
  panosu açar (UiRouter `all_cars`, MODAL; garaj altta açık kalır).
- SINIF, NADİRLİK ve SIRALA panonun üstünde tek satırda **açılır plakalardır**. Üç çip satırı telefon
  tuvalinde (480 birim) ızgaraya yer bırakmıyordu. Seçimler oyun açık kaldıkça hatırlanır, kayda yazılmaz.
- Lifteki aracın kartı amberdir; yarış aracının kartında `YARIŞ ARACI` yazar.
- Pano şunları kapsar:
  - **Kapsam:** bütün garajlardaki araçlar ve bekleyenler. **BU GARAJ** anahtarıyla daraltılır.
  - **Kart:** küçük resim, sınıf harfi, nadirlik rengi ve aracın **garaj rozeti** (bekleyenlerde
    `BEKLİYOR`).
  - **Seçim:** karta dokununca pano kapanır, ekran o garaja geçer ve kamera araca gider.

### Filtreler
Filtreler tek seçimlidir ve her grubun bir `TÜMÜ` düğmesi vardır.
- **SINIF:** D / C / B / A / S. Ölçü, modifiye dahil sınıftır (`PerformanceMods.class_of`).
- **NADİRLİK:** yaygın / nadir / epik / efsanevi (katalog `rarity`).
- Gövde tipi (sedan/SUV) filtresi ve yazıyla arama **istenmedi**.

### Sıralama
Sıralama seçicide (açılır plaka) yapılır. Eşitlikte araç adına göre sıralanır.

| Seçenek | Ölçü |
|---|---|
| EN HIZLI | Performans puanı: modifiye dahil 300 m simülasyon süresi (`class_of`'un kullandığı `t300`); küçük süre önde |
| EN ÇOK YARIŞILAN | Araç başına biten yarış sayısı (rövanş dahil) |
| EN ÇOK KAZANAN | Araç başına galibiyet sayısı |
| EN DEĞERLİ | Katalog fiyatı (garaj değerine katkısıyla aynı ölçü; modifiye harcaması kayıtta tutulmuyor) |
| SON EKLENEN | Edinme sırası; en yeni önde |

### Kayıt
- **Yarış sayaçları:** `RaceManager` araç başına yarış ve galibiyet sayar. Kayıtta `race.cars`
  alanında `{id: {"r", "w"}}` biçiminde durur. Yarış, o an seçili yarış aracına yazılır (rövanş dahil).
  Satılan aracın sayacı silinmez.
- **Edinme sırası:** Ayrı zaman alanı gerekmedi. `VehicleOwnership._owned` zaten alınma sırasıyla
  tutuluyor ve kayıtta bu sıra korunuyor; satılıp yeniden alınan araç sona eklenir.

## 2. Garajlar

### Garajların oyuncuya sağladıkları
- **Vitrin:** araçlar garajın içinde park hâlinde görünür.
- **Kapasite sınırı:** her garajın bir park yeri sayısı var. Toplam kapasite, sahip olunabilecek
  araç sayısını belirler.
- **Prestij:** bkz. §5.
- Pasif gelir **yok**.

### Sahiplik
- Alınan garajlar oyuncuda kalır.
- Araçlar garajlara dağılır.
- Garajlar arasında ekranın üstünden geçilir.

### Liste
Garajlar pahalandıkça büyüyen bir merdivendir, ama her basamağın kendi tarzı vardır.

| # | Garaj | Fiyat | İnşaat | Seviye şartı | Park yeri (taban → en çok) | Tarz |
|---|---|---|---|---|---|---|
| 1 | MAHALLE GARAJI | ücretsiz (başlangıç) | — | — | 4 → 6 | Bugünkü garaj: asfalt, sarı şerit, lift |
| 2 | SANAYİ ATÖLYESİ | 150.000 ₺ | 1 sa | sv. 5 | 6 → 10 | Tuğla duvar, kepenk, tavan vinci |
| 3 | NEON YERALTI | 900.000 ₺ | 4 sa | sv. 12 | 8 → 14 | Beton kolonlar, neon şeritler, JDM havası |
| 4 | CAM SHOWROOM | 3.000.000 ₺ | 12 sa | sv. 20 | 10 → 18 | Parlak zemin, döner platformlar, cam cephe |
| 5 | UÇAK HANGARI | 8.000.000 ₺ | 24 sa | sv. 30 | 18 → 30 | Kemerli tavan, jet, dev kapı |

- **Toplam kapasite:** en çok 78 park yeri. Bugün edinilebilen 72 araç var (polisler hariç).
  Yeni araç partileri geldikçe bu sayı yeniden ölçülmeli. Gerekirse PARK YERİ kademesi ya da
  6. garaj eklenir.
- **İkinci garaj bilerek ucuz.** Başlangıç garajı erken dolar ve oyuncu bekleme otoparkında
  sıkışmamalı. Seviye 5'te 150.000 ₺'nin ulaşılabilir olduğu simülasyonla doğrulanacak.

### Para ve süre
- Garajlar ve iç yükseltmeler **₺** ile alınır.
- Garaj inşaatı ve iç yükseltme işleri **süreli**dir ve elmasla bitirilebilir.
- İnşaat sürerken o garaj kilitlidir ve içinde iskele görünür. Öteki garajlar çalışmaya devam eder.
- Her garajda aynı anda **tek** iç yükseltme işi yürür.

### Elmasla bitirme
Mevcut `GemSkip` kuralı dakikada 2 elmastır. Bu kuralla 24 saatlik inşaat 2.880 elmas tutar, oysa
oyuncu günde ~35 elmas kazanıyor. Garaj işleri için **azalan oranlı** bir eğri kullanılır:

```
kalan ≤ 60 dk : ceil(dk) × 2                    (GemSkip ile aynı; 10 dk = 20)
kalan > 60 dk : ceil(120 × (dk / 60) ^ 0.6)     (1 sa = 120, 4 sa ≈ 276, 12 sa ≈ 533, 24 sa ≈ 808)
```

Eğri 60. dakikada süreklidir. Onay kuralı `GemSkip` ile aynıdır: ilk dokunuştan sonra 3 sn içinde
onay.

## 3. İç yükseltmeler

### Kalemler
Her garajda 5 ayrı kalem vardır. Her seviye 3D'de gözle görülür biçimde değişir.

| Kalem | Etki | Seviye |
|---|---|---|
| PARK YERİ | Kapasite (+1 / +2 / +3) | Garaja göre 2–4 kademe |
| ZEMİN | Görünüm + değer | 3 (★ taban + 2 yükseltme) |
| IŞIKLAR | Görünüm + değer | 3 |
| DUVAR / VİTRİN | Görünüm + değer | 3 |
| LİFT / PLATFORM | Görünüm + değer | 3 |

- Görsel kalemler **oyun dengesine dokunmaz**. Yalnızca görünümü değiştirir ve garaj değerine
  eklenir.
- Serbest dekor yerleştirme bu sistemde **yok**.

### Fiyat taslağı (₺)
Ayar simülasyonla yapılacak. Hedef: 5 garaj + bütün iç yükseltmeler ≈ **25 M ₺**. Mevcut ölçüme göre
bu, oyun ortasından sonra yaklaşık 100 saatlik birikime denk gelir.

| Garaj | PARK YERİ kademeleri | Görsel kalem başına (sv.2 / sv.3) | Garaj iç toplamı | İş süresi |
|---|---|---|---|---|
| MAHALLE | +1: 20 b · +1: 40 b | 10 b / 20 b | ~180 b | 5–10 dk |
| SANAYİ | +2: 100 b · +2: 200 b | 40 b / 80 b | ~780 b | 10–20 dk |
| NEON | +2: 200 b · +2: 300 b · +2: 450 b | 100 b / 200 b | ~2,15 M | 20–45 dk |
| CAM SHOWROOM | +2: 250 b · 350 b · 500 b · 700 b | 150 b / 300 b | ~3,6 M | 30–90 dk |
| HANGAR | +3: 500 b · 750 b · 1 M · 1,5 M | 250 b / 450 b | ~6,55 M | 45–120 dk |

Toplam: iç ≈ 13,3 M + garajlar 12,05 M = **≈ 25,3 M ₺**.

## 4. Araçların yerleşimi ve bekleme otoparkı

### Otomatik yerleşim
- Yeni gelen araç (galeri, kasa, hediye kutusu, hurdalık, Hoş geldin kutusu) **boş yeri olan en üst
  garaja** kendiliğinden park eder.
- **TAŞI:** araç başka bir garaja ya da başka bir park yerine taşınır. İşlem ücretsiz ve anında olur.
  Hedef doluysa iki araç yer değiştirir.

### Bekleme otoparkı
Bütün garajlar doluyken gelen araç kaybolmaz, **BEKLEYEN** olur:
- Kasa ve hediye akışı bozulmaz. Galeride SATIN AL kilitlenmez, yalnızca "garaj dolu, araç bekleyecek"
  uyarısı çıkar.
- Bekleyen araç yarışa, modifiyeye ve boyaya giremez; satılabilir. Yarış aracı olarak seçilemez.
- Süresizdir.
- Yer açılınca (satış, PARK YERİ yükseltmesi, inşaatın bitmesi) bekleyenler geliş sırasıyla
  kendiliğinden park eder ve bildirim çıkar.
- **Görünüm:** listede `BEKLİYOR` rozeti taşır. Garaj ekranında kapının önünde bir çekicinin üstünde
  durur (3D'de en çok 1–2 tanesi). Dokununca **YER AÇ / SAT / GARAJ AL** seçenekleri çıkar.

## 5. Prestij
- **Garaj değeri ve rütbe:** garajlara ve iç yükseltmelere ödenen ₺ `GarageValue`'ya eklenir. Yeni
  terim: `garages_value`.
- **Rütbeler (UYGULANDI 2026-10-19):** 1–10 aynen kalır, böylece araçların `min_garage_rank` kilitleri bozulmaz.
  Üste **11–15** eklendi.
  - Eşikler (kullanıcı onayı): 2 M / 5 M / 10 M / 20 M / 32 M. Araçların hepsi 8,26 M (12. rütbe); 13–15 için
    garajlar şart; garajlar ≈ 25 M ile toplam ≈ 34 M.
  - Adlar (kullanıcı seçimi): EFSANE ★ … EFSANE ★★★★★ (10. EFSANE GARAJ'ın devamı).
  - Garaj değeri ekranı: yeni "ARAÇ GARAJLARI" satırı (`GarageValue.garages_value` = `CarGarageManager.spent_total`).
    Merdiven telefonda sığsın diye kısaltıldı: ulaşılmış rütbeler tek satır, şimdiki + sıradaki 5, kalanlar
    "+N RÜTBE DAHA".
  - Başarım "DEĞERLİ GARAJ" (a_rank) kademeleri hâlâ 3/5/7/10 (11–15 kademesi ödül ekonomisi kararı: açık).
- **Arkadaş ziyareti: ŞİMDİLİK YOK (kullanıcı kararı 2026-10-19).** Ziyaret eskisi gibi; açık garaja yerleşim,
  kalem seviyeleri ve işler gitmez.
- **Açık özet (UYGULANDI):** `garage_json` içinde `car_garage_summary` = {own: alınmış garajlar, cap: toplam park
  yeri} (`PublicGarage.car_garage_summary`; sunucudan geleni süzer). Belge alanı değil: Firestore kuralı
  değişmedi, deploy gerekmedi.
- **Profil rozeti (UYGULANDI):** profil kartında seviye satırının altında garaj ikonu + "UÇAK HANGARI · 5 GARAJ ·
  64 YER". Uzun dillerde (EN/ES ≈ 280 > 239 birim) iki satıra kayar. Özeti olmayan kartta (eski sürüm arkadaş,
  öne çıkan garajlar) gizli.
- **OTO MANŞET (UYGULANDI):**
  - Kendi: sen yokken biten inşaat (`GARAGE_BUILT`, sütun, EMLAK) ve iç yükseltme (`GARAGE_UPGRADED`, KISA KISA).
    İşler açılışta kendiliğinden kapandığı için `CarGarageManager` biten işleri PLANLANAN bitiş saatiyle günlüğe
    yazar (kayıtta "done", en çok 20 kayıt / 8 gün).
  - Arkadaş: yalnız CAM SHOWROOM / UÇAK HANGARI (`FRIEND_GARAGE`, MAGAZİN; SANAYİ / NEON haber olmaz). Taban
    `social.json` news.garages {uid: [lüks garaj]}; yeni arkadaş / ilk açılış haber vermez, özeti okunamayanın
    tabanı korunur (`SocialManager.friend_garage_news`).

## 6. Ekran

### Garaj seçici
- **Üst tabela:** `◀ NEON YERALTI 9/14 ▶`. Oklarla garajlar arasında geçilir.
- Tabelaya basınca **GARAJLARIM** panosu açılır. Her garaj için bir kart vardır:
  - Sahip olunan: doluluk.
  - İnşaatta: geri sayım + `💎 BİTİR`.
  - Kilitli: fiyat, seviye şartı, `SATIN AL`.
- Bekleyen araç varsa sayısı panoda görünür.

### Sergileme
- Garajdaki bütün araçlar yerlerinde park hâlinde durur.
- Garaj parmakla kaydırılır ve yakınlaştırılır.
- Araca dokununca kamera ona gider ve bilgi panosu açılır. Bugünkü sol bilgi plakaları ve sağdaki
  aksiyonlar kullanılır: DETAY, BOYA, MODİFİYE, YARIŞ ARACI, SAT, TAŞI.
- Telefonda çok araç için LOD şart. Uzak araçlar sadeleştirilir, gölgeler kapalı tutulur.
  `SHOW_PARKED_CARS` kapatılırken öne sürülen "kalabalık" sorunu park yeri düzeniyle çözülür.

### İç yükseltme panosu
Kalem listesi; her satırda yıldız seviyesi, sıradaki seviyenin etkisi, fiyat ve süre yer alır.

## 7. 3D üretim (FAZ 3)

Kullanıcı kararları (2026-10-19): **perspektif diorama** kamera (ön ve sağ duvar kesik, çatı yok), **garaja özel
atmosfer**, bekleme otoparkı **çatı katı otopark**, önce MAHALLE + otopark (onaylandı: "çok çok iyi"), sonra öteki dört.

| Garaj | Atmosfer | Boyut | Betik |
|---|---|---|---|
| MAHALLE | sıcak akşamüstü, açık kepenkten güneş, tuğla | 14 × 10 m | `tools/garages/mahalle.py` |
| SANAYİ | serin sabah, yüksek pencere huzmeleri, oluklu sac, tavan vinci | 18 × 14 m | `sanayi.py` |
| NEON YERALTI | gece, yeraltı, pembe / camgöbeği neon, rampa | 26 × 15 m | `neon.py` |
| CAM SHOWROOM | parlak gün ışığı, cam cephe + şehir, açılı galeri dizilişi | 26 × 16 m | `showroom.py` |
| UÇAK HANGARI | gün batımı dev kapıdan, asılı pervaneli uçak, kemerler | 34 × 22 m | `hangar.py` |
| BEKLEYENLER | gün batımı çatı katı otopark, şehir fonu, çekici | 25 × 17 m | `rooftop.py` |

### Hat
- **Önizleme:** `blender -b --factory-startup --python tools/garages/<ad>.py -- preview <sv> <çıktı.png>` (Cycles,
  gerçek oyun araçlarıyla). Ortak parçalar `tools/garages/garage_kit.py` (hurdalık kitinin üstüne).
- **Oyuna aktarma:** `blender -b … tools/garages/export_garage.py -- <ad>` → `assets/garages/<ad>/`:
  - ışık köşe rengine pişer (sonda kopyası + yüz çevirme, hurdalık hattından),
  - **AgX görüntü dönüşümünden geçirilmiş ekran değeri** saklanır (oyunda ışıksız, doğrusal ton eşlemeyle olduğu gibi),
  - zemin her (zemin sv., IŞIKLAR sv.) çifti için ayrı tam ışıklı doku (9 doku; uzun kenar ≤ 2048 px),
  - seviyeyle gelen eşyaların zemin gölgesi çarpımlı çıkartma (iki pişirmenin oranı; gölgesizler atılır),
  - ışıyan yüzlerin köşe rengine kendi ışık rengi; huzmeler katkılı.
  - İçe aktarma: dokular `compress/mode=2` + mipmap, GLB'de LOD / teğet / gölge ağı kapalı (.import elle).
- **Oyun:** `world/garage_interior.gd` (GarageInterior: GLB + materyaller + seviye gösterimi + park yerleri + kamera /
  ışık ayarı), `ui/hud/garage_interior_view.gd` (kamera: kaydır / iki parmak & tekerlek yakınlaştır / araca dokun →
  odak; araçlar park yerlerinde, temas gölgesi, seçim halkası). Garaj ekranı pişmiş sahnesi olan garajda bu kipe
  girer; yoksa eski kutu odaya düşer.
- QA: `qa/garaj3d_shot.gd` (tek başına görüntü + çizim yükü), `tools/ekran_tarama.sh … -- garajlar` (arayüzle).

### Öğrenilen tuzaklar
- 16 bit PNG geri okununca Blender pikselleri doğrusala çeviriyor: "Non-Color" işaretlenmeden okunan değerler köşe
  rengine doğrusal yazılıyor, oyunda orta tonlar kararıyordu.
- Zemini kaplayan çıkartma düzlemi pişirmeden sonra görünür kalınca sonrakiler (aynı yükseklik) simsiyah pişiyordu.
- Yüksekteki kiriş / tavan elemanı kamera açısından (~40°) arka duvarın üstüne izdüşer: tavan elemanları duvar
  dibinde ya da arka yarıda.
- Park etmiş araçların birleştirmesi (CarMeshMerger) kuyrukla oturur: ölçüm birkaç yüz kare sonra yapılmalı.

### Çizim yükü (masaüstü ölçümü, birleştirme oturduktan sonra)
Ortam 25–35 bin üçgen. Araç başına ~10 çizim çağrısı, ~64 bin üçgen (en kaba otomatik LOD bile 19–60 bin):
MAHALLE 6 araç 86 çağrı / 396 bin, SANAYİ 10 araç 125 çağrı / 663 bin. 30 araçlı HANGAR ≈ 1,8 M üçgen.

**Karar (kullanıcı, 2026-10-19): yalnız yakındakiler tam model.** Vitrin modeli (ikinci hafif model) ve gösterilen
araç sınırı seçilmedi. `GarageInteriorView._update_detail`: odaktaki araç LOD0, kameranın varacağı konuma en yakın
`NEAR_CARS` (6) araç dünya kademesi, kalanlar `lod_bias = 0` (en kaba kademe; 0,25 sn'de bir yeniden seçilir).
`lod_bias = 0` gerçekten en kabayı seçer (tek araç sondası: BMW F30 70→43 bin, GT3 71→54 bin). Kazanç sınırlı,
çünkü içe aktarmanın en kaba kademesi büyük:

| Garaj | Önce | Sonra |
|---|---|---|
| NEON sv.3 (14 araç) | 965 bin | 794 bin |
| CAM SHOWROOM sv.3 (18) | 1,30 M | 1,03 M |
| HANGAR sv.1 (18) | 1,25 M | 1,01 M |
| HANGAR sv.3 (24) | 1,61 M | 1,27 M |

Ölçüm QA_SETTLE=800 ile (400 karede birleştirme bitmemiş olabiliyor; parçalı hâl daha az üçgen gösterir, yanıltır).
Uzaktaki araçlarda gözle görülür bozulma yok. Telefonda denenmedi.

## 8. Uygulama sırası
1. **Liste (UYGULANDI 2026-10-19):**
   - TÜM ARAÇLAR panosu, SINIF/NADİRLİK filtreleri, 5 sıralama.
   - Araç başına yarış/galibiyet sayacı.
2. **Garaj sistemi (UYGULANDI 2026-10-19):**
   - Katalog, kapasite, otomatik yerleşim, TAŞI, bekleme otoparkı.
   - Satın alma, inşaat, elmasla bitirme, iç yükseltme işleri, kayıt.
   - TÜM ARAÇLAR kartlarında garaj rozeti / `BEKLİYOR`, **BU GARAJ** anahtarı (yalnız birden çok garaj ya
     da bekleyen varken görünür).
   - Uygulamada netleşenler:
     - Kayıtta `car_garages` bölümü SAHİPLİKTEN ÖNCE yüklenir. Sonra uzlaştırma çalışır: kayıtta yeri
       olmayan araç (eski kayıt) sırayla yerleşir.
     - Bekleyen araç yarış aracı olamaz (`VehicleOwnership.race_vehicle_id` park etmiş araca düşer).
     - İnşaat ve iş süresi dolunca kendiliğinden biter ("topla" adımı yok); HUD bildirim gösterir.
     - TAŞI garaj düzeyinde (ilk boş yere). Dolu garaja taşıma / yer değiştirme Faz 3'te, park yerleri
       3D'de görünür olunca.
     - Arkadaş ziyaretinde yönetici kurulmaz: garaj ekranı eski tek garaj görünümüne düşer (Faz 4'te
       ziyaret garajları gelecek).
3. **3D (UYGULANDI 2026-10-19):** 5 garaj + çatı katı otopark pişirildi ve oyunda; uzak araçlar en kaba LOD'da
   (§7 çizim yükü). Açık: TAŞI'nın park yeri düzeyi, telefonda kare hızı.
4. **Prestij (UYGULANDI 2026-10-19):** rütbe 11–15 + ARAÇ GARAJLARI değeri, açık özet, profil rozeti, OTO MANŞET
   (§5). Arkadaş ziyaretine garajlar eklenmedi (kullanıcı kararı). Test: `car_garage_test` bölüm 10; QA:
   `qa/oto_manset_qa.gd` 05_garajlar / 06_insaat.
   - Bütün metinler 5 dilde (TR/EN/ES/DE/FR).

## 9. Açık konular
- Fiyat, süre ve seviye şartları simülasyonla ayarlanacak (özellikle 2. garajın erişilebilirliği).
- Başarım "DEĞERLİ GARAJ" 11–15 kademeleri (ödül ekonomisi).
- Garaj değeri dökümünde DEKOR satırı yok (eskiden beri): kalemler toplamı tutmuyor.
- Yeni araç partileri gelince toplam kapasite yetecek mi?
- Garaj ekranının sağ sütununda artık 7 plaka var (TAŞI eklendi); telefonda şerit sütunun solunda bitiyor.
  TAMİR plakasının sinyalini hiçbir yer dinlemiyor (bugün de işlevsiz): kaldırılırsa yer açılır.
