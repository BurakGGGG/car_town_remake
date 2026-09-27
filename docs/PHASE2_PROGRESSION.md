# FAZ 2 — İLERLEME TAMAMLAMA

Tarih: 2026-09-26. Önceki aşamalar: [PROGRESSION_REFACTOR.md](PROGRESSION_REFACTOR.md) (refactor),
[QA_REVIEW.md](QA_REVIEW.md) (bağımsız QA). Bu belge FAZ 2'de **kodlananları** ve
**tasarlanıp bilerek kodlanmayanları** ayırır.

---

## 1. KODLANAN — GERİ BİLDİRİM (Faz 1)

QA'nin en büyük bulgusu: oyuncu neye para verdiğini göremiyordu. `gameplay/progression_effects.gd`
satırları **çalışan sistemlerden okur** (RepairManager.SUPPLY, RepairBayManager, RepairType), elle
yazılmaz — tablo değişince metin kendiliğinden doğru kalır.

**Garajı genişlet plakası** (dünyadaki tabela):

```
GARAJI GENİŞLET
SEVİYE 2  ·  12.000 ₺
+%25 DAHA SIK MÜŞTERİ
+1 BEKLEME NOKTASI
+%15 DAHA DEĞERLİ MÜŞTERİ
2. TAMİR ALANI AÇILIR (5.000 ₺)
```

**Tamir alanı plakası:**

```
TAMİR ALANI 2
5.000 ₺
+1 EŞZAMANLI TAMİR
BOYA İŞİ AÇILIR (90 sn · 600 ₺)
DÖŞEME AÇILIR (180 sn · 1.150 ₺)
```

**Kural:** bir iş hem garaj seviyesi hem alan istiyorsa garaj plakası onu VAAT ETMEZ (alan plakası
eder). Yoksa oyuncuya tutulmayacak söz verilmiş olur — testte bu davranış doğrulanır.

**Tamir plakası:** `MOTOR ARIZASI · 10 sn · +173 ₺ · 1.038 ₺/dk · +10 XP · USTALIK ★ (12/40)`.
₺/dk gerçek ödül ve gerçek süreden (tamir hızı geliştirmesi dahil) hesaplanır. Bu sayı, QA'de
"anlaşılmıyor" çıkan kısa/uzun iş kararının tek okunabilir ölçüsüdür: MOTOR 1.038 ₺/dk, BOYA
460 ₺/dk — uzun iş saniye başına daha az getirir, değeri BOŞTAKİ ALANI DOLDURMASIDIR.

## 2. KODLANAN — İŞ USTALIĞI (Faz 2)

| Kademe | Kısa iş (ağırlık 1,0) | BOYA (0,8) | DÖŞEME (0,6) | REVİZYON (0,5) |
|---|---|---|---|---|
| 1★ | 10 | 8 | 6 | 5 |
| 2★ | 40 | 32 | 24 | 20 |
| 3★ | 120 | 96 | 72 | 60 |
| 4★ | 300 | 240 | 180 | 150 |
| 5★ | 750 | 600 | 450 | 375 |

**Eşikler ayrı bir alan DEĞİL, `RepairType.weight`'ten türetilir.** Ağırlık zaten arızanın gelme
sıklığıdır; ölçülen akışta (garaj 3, 3 alan) saatte ~35 kısa iş, ~28 boya, ~21 döşeme, ~17 revizyon
geliyor. Eşikler ağırlıkla ölçeklenince **her arızada 1. yıldız ~18 dakikaya** denk gelir; hiçbir iş
"ulaşılmaz ustalık" olmaz ve yeni bir veri alanı eklemek gerekmez.

Kademe başına:
- **Tek seferlik ödül** = `arıza ödülü × [8, 18, 40, 85, 180] × ağırlık`
  (MOTOR 1★ = 1.200 ₺, REVİZYON 1★ = 7.200 ₺). Kademe başına düşen pay bilinçli olarak azalır:
  o kademede kazanılanın ~%80 → %60 → %50 → %47 → %40'ı.
- **Kalıcı +%10 XP / yıldız** (5★'da +%50) — mevcut davranış korundu.
- **Kalıcı +%2 ödül / yıldız** (5★'da +%10) — YENİ. Küçük tutuldu: ölçülen 120 dk'lık koşuda
  ustalık geliri toplam gelirin %11'i; ekonomiyi bozmuyor.

**Ustalık panosu** (garaj ekranı → USTALIK plakası): her arıza için yıldız, sayaç/sonraki eşik ve
o işten gelen kalıcı bonuslar. Fiziksel plaka dili, generic kart yok.

**5★ FİZİKSEL ÖDÜL — TASARLANDI, KODLANMADI.** `JobMastery.mastered_jobs()` API'si hazır; garaj
duvarındaki rütbe tabelasının yanına 5★ olan her iş için küçük altın yıldız plakası asılacak
(GarageScreen'de ~20 satır, yeni sistem değil). Şimdilik kodlanmadı çünkü ilk 5★ ölçülen akışta
**~22 saatlik** oyundan sonra geliyor; dekorasyon sistemini bunun için büyütmek erken.

**KAYIT: sürüm DEĞİŞMEDİ (v7).** Ustalıkta saklanan tek şey sayaçlardır (`{arıza id: sayı}`);
yıldızlar, bonuslar ve ödüller hep sayaçtan türetilir. Eşik tablosu değişse bile şema aynı kalır,
v7 kayıtlar olduğu gibi açılır (yıldızlar yeni eşiklerle yeniden hesaplanır; geçmişe dönük kademe
ödemesi yapılmaz — oyuncunun aleyhine değil, lehine bir sapma).

## 3. TASARLANDI, KODLANMADI — ARAÇ İLERLEMESİ (Faz 3)

### 3.1 Mevcut matris

| ID | Marka | Model | Fiyat | Sınıf | Min sv. | Min rütbe | Garaj değeri | Bugünkü işlevi |
|---|---|---|---|---|---|---|---|---|
| tofas_sahin | Tofaş | Şahin | 15.000 | D | 1 | 1 | 15.000 | ilk alınan araç |
| renault_toros | Renault | Toros | 20.000 | D | 3 | 1 | 20.000 | — |
| hyundai_era | Hyundai | Era | 30.000 | C | 6 | 1 | 30.000 | — |
| hyundai_getz | Hyundai | Getz | 35.000 | C | 8 | 2 | 35.000 | — |
| vw_passat_b55 | VW | Passat B5.5 | 50.000 | B | 12 | 3 | 50.000 | — |
| renault_fluence | Renault | Fluence | 60.000 | B | 15 | 4 | 60.000 | — |
| bmw_e46 | BMW | E46 | 85.000 | A | 1 | 1 | 85.000 | **ücretsiz başlangıç aracı** |

Araçların toplamı 295.000 ₺ — bugünkü garaj değeri tavanının (439.500 ₺) **%67'si**.

**Bugünkü tek işlev: garaj değeri → rütbe → yeni araç kilidi.** Yani araçlar araç açıyor: döngüsel
ve zayıf bir gerekçe. Ayrıca bir tutarsızlık var: **en pahalı ve en üst sınıf araç bedava** veriliyor.

### 3.2 Seçenekler

| | Model | Ekonomik etki | Karmaşıklık | Risk |
|---|---|---|---|---|
| A | Araç SINIFI müşteri kalitesini artırır (sahip olunan en iyi sınıf → ödül çarpanı D/C/B/A = ×1,00/1,05/1,10/1,15) | Tavanda +%15 gelir; 60.000 ₺'lik araç ~167 dk'da amorti | **En düşük**: `VehicleOwnership.best_class()` + mevcut ödül zincirine bir çarpan | Garaj seviyesi çarpanıyla üst üste binme; başlangıç aracı A sınıfı olduğu için ÖNCE veri düzeltmesi şart |
| B | Belirli araçlar belirli işlere bonus (ör. Passat → BOYA +%10) | Hedefli, küçük | Orta: araç başına bonus tablosu + ödül hesabında arama | Gerekçesi "oyunsal", fiziksel dünyada açıklaması zor |
| C | Araçlar koleksiyon ilerlemesi açar | Tek seferlik ödüller, kontrollü | Yüksek: koleksiyon sistemi gerekir | 7 araçla koleksiyonlar çok ince (bkz. §5) |
| D | Yalnızca garaj değeri (bugünkü durum) | Yok | Sıfır | QA'nin tespit ettiği "neden araç alayım?" sorusu cevapsız kalır |

### 3.3 Karar: **A** (+ zorunlu veri düzeltmesi)

Gerekçe: (1) fiziksel dünyada açıklanabilir — "garajında iyi arabalar varsa iyi müşteri gelir",
(2) en az kod: ödül zinciri zaten `garaj seviyesi × ustalık` çarpanlarından geçiyor, üçüncü bir
çarpan eklemek tek satır, (3) zaten eklediğimiz `class` alanını kullanır, yeni şema yok,
(4) oyuncu etkiyi tamir plakasındaki ₺ ve ₺/dk sayısında ANINDA görür.

**Zorunlu ön koşul — başlangıç aracı:** bugün oyuncu oyuna A sınıfı 85.000 ₺'lik BMW E46 ile
başlıyor; sınıf tabanlı bir sistem bu haliyle daha ilk dakikada tavana oturur. Önerilen düzeltme:
başlangıç aracı **Tofaş Şahin (D, 15.000 ₺)**, BMW E46 ise **satın alınabilir uç oyun aracı**
(A sınıfı, sv.18, rütbe 5). Yan faydaları: garaj değeri 85.000 yerine 15.000'den başlar (rütbe
merdiveni ilk saatte anlam kazanır) ve "hurda Şahin'den başlayıp BMW'ye çıkmak" fantezisi güçlenir.
Kayıt uyumu: kayıtta araç id'leri saklandığı için mevcut kayıtlar etkilenmez; değişen yalnızca YENİ
oyunun başlangıç aracıdır.

**Neden şimdi kodlanmadı:** başlangıç aracını değiştirmek garaj değeri eşiklerini, showroom
kilitlerini ve ilk 30 dakikanın ekonomisini birlikte etkiler; kural gereği önce ölçüp sonra
değiştirmek gerekir. Faz 3 kendi ölçüm turunu hak ediyor.

## 4. TASARLANDI, KODLANMADI — İŞLEVSEL GARAJ EŞYALARI (Faz 4)

Mimari uyum: eşyalar `GarageSystem/PlacedObjects` altında Node3D olarak yaşar (kilitli tamir alanı
görselleri bugün tam olarak böyle kuruluyor), katalog `RepairType`/`PaintCatalog` desenindedir,
durum yeni bir `gameplay/garage_objects.gd` (grup `garage_objects`) içinde tutulur, kayda
`"objects": {id: {...}}` alanı eklenir → **v8 göçü** (v7 → v8: alan yoksa boş sözlük).

Üç prototip (ölçülen geç oyun geliri 2.400 ₺/dk baz alınarak fiyatlandı):

| Eşya | Ücret | Garaj değeri | Etki | Aralık | Açılış şartı | Performans |
|---|---|---|---|---|---|---|
| OTOMAT | 6.000 ₺ | +6.000 | pasif 120 ₺/dk (5 dakikada bir 600 ₺'lik kasa, dokununca toplanır) | 5 dk | Garaj 2 | 1 mesh + 1 billboard etiket (~6 çizim) |
| PARÇA RAFI | 6.000 ₺ | +6.000 | KAPORTA ve LASTİK işlerinde +%15 ödül (≈ +%4 toplam gelir) | — | Garaj 2 | 1 mesh + 2 küçük kutu (~8 çizim) |
| HURDA KUTUSU | 12.000 ₺ | +12.000 | her 10 tamirde 400-900 ₺'lik hurda sandığı (dokununca toplanır) | ~3 dk | Garaj 3 + 2 alan | 1 mesh + toplama ışığı (~6 çizim) |

Amorti: otomat ~50 dk, parça rafı ~65 dk, hurda kutusu ~55 dk. Toplam çizim maliyeti ~20 (bugünkü
dünya 230-568 çizim, bütçe 700) — mobilde güvenli.

**UYARI (ölçümden):** 0-10 saat projeksiyonuna göre oyuncu ~3 saatte bugünkü içeriğin tamamını
alıyor ve para BİRİKMEYE başlıyor (5. saatte ~400.000 ₺, 10. saatte ~1.000.000 ₺ atıl). İşlevsel
eşyalar **gelir ekler**; bu yüzden tek başlarına eklenirlerse doyma sorununu büyütürler. Doğru sıra:
önce para HARCAYACAK içerik (koleksiyon plakaları, dekor, yeni araçlar), sonra pasif gelir.

## 5. TASARLANDI, KODLANMADI — KOLEKSİYONLAR (Faz 5)

Veri modeli (kod yazılmadı):

```
{ "id": "yerli_klasikler", "title": "YERLİ KLASİKLER",
  "vehicles": ["tofas_sahin", "renault_toros", "tofas_dogan"],
  "reward": {"money": 0, "xp": 300, "garage_value": 25000, "plate": "YERLİ KLASİKLER"} }
```

7 araçla çıkabilecek anlamlı setler: YERLİ (Şahin, Toros) · HYUNDAI (Era, Getz) · ALMAN (BMW,
Passat) · RENAULT (Toros, Fluence) — hepsi **2 araçlık**. İki arabalık koleksiyon ne toplama hissi
ne de hedef yaratır.

**Karar: şimdi kodlanmadı.** Anlamlı bir koleksiyon katmanı için en az 9-12 araç (3'er araçlık 3-4
set) gerekir. Araç sayısı 10'a çıktığında sistem 1-2 günlük iştir ve veri modeli yukarıda hazırdır.
Ödül tasarımı şimdiden sabit: **para VERMEMELİ** (ekonomi zaten geç oyunda doyuyor) — ödül
garaj değeri + fiziksel tabela + XP olmalı.

## 6. GARAJ DEĞERİ — katkı kuralı

`GarageValue.compute()` toplamsaldır ve şu kalemlerden oluşur:

| Kalem | Kaynak | Bugünkü tavan |
|---|---|---|
| Araçlar | sahip olunan araçların katalog fiyatı | 295.000 ₺ |
| Geliştirmeler | o güne kadar ödenen geliştirme ücretleri | 113.500 ₺ |
| Tamir alanları | açılan alanların ücretleri | 17.000 ₺ |
| Boya | boyanmış araç × 2.000 ₺ | 14.000 ₺ |
| *(gelecek)* İşlevsel eşyalar | eşyanın ücreti kadar | — |
| *(gelecek)* Dekorasyon | eşyanın ücreti kadar | — |
| **Toplam** | | **439.500 ₺ → 8. rütbe** |

Kural: **bir kalem garaj değerine ancak oyuncunun ödediği ₺ kadar katkı verir** (boya gemle
alınabildiği için sabit 2.000 ₺ karşılık yazılır). Yeni kalem eklemek = `compute()`'a bir toplam
daha; şema değişmez çünkü değer türetilmiştir, kayda yazılmaz. 9. (550.000) ve 10. (700.000) rütbe
bilerek ulaşılamaz durumda bırakıldı: gelecek araç/eşya/dekor içeriğinin hedefi olacaklar.

## 7. EKONOMİ ÖLÇÜMÜ

### 7.1 Gerçek oyun, temiz oyuncu, 120 dakika (Faz 2 kodu ile)

| dk | Para | XP | Sv | Garaj | Alan | Araç | Değer | Rütbe | ★ | Tamir | İş geliri | Ustalık geliri | ₺/dk |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 603 | 352 | 3 | 1 | 1 | 1 | 96.500 | 1 | 1 | 32 | 4.653 | 1.200 | 465 |
| 20 | 8.752 | 583 | 5 | 1 | 1 | 1 | 96.500 | 1 | 3 | 20 | 3.249 | 2.400 | 325 |
| 30 | 651 | 779 | 5 | 2 | 1 | 1 | 108.500 | 1 | 4 | 19 | 2.779 | 1.120 | 278 |
| 45 | 14.930 | 1.532 | 8 | 2 | 2 | 1 | 113.500 | 2 | 4 | 61 | 11.779 | 0 | 785 |
| 60 | 12.031 | 2.532 | 9 | 2 | 2 | 3 | 148.500 | 2 | 9 | 47 | 15.391 | 14.460 | 1.026 |
| 90 | 26.567 | 6.186 | 13 | 3 | 3 | 4 | 220.500 | 4 | 11 | 106 | 58.816 | 12.720 | 1.961 |
| 120 | 36.197 | 10.111 | 15 | 3 | 3 | 6 | 305.500 | 5 | 13 | 121 | 62.570 | 21.060 | 2.086 |

Toplam: 406 tamir · 159.237 ₺ iş geliri · **52.960 ₺ ustalık geliri (toplam gelirin %25'i)**.

**Faz 2 oyunu hızlandırdı mı?** Hayır: Faz 1 sonundaki ölçümle (413 tamir, sv.15, 6 araç, rütbe 5)
120. dakikadaki durum **aynı**. Ustalık geliri 3 katına çıktığı halde ilerleme değişmedi, çünkü
ilerleme parayla değil **seviye ve rütbe kilitleriyle** sınırlı (Passat sv.12 + rütbe 3, Fluence
sv.15 + rütbe 4). Bu yüzden ustalık ödülleri kısılmadı — ölçüm "aşırı hızlanma yok" diyor.

### 7.2 Uzun vade projeksiyonu (dakika adımlı model, ölçülen oranlarla)

| dk | Para | Sv | Garaj | Alan | Araç | Değer | Rütbe | ★ | ₺/dk | Ustalık geliri |
|---|---|---|---|---|---|---|---|---|---|---|
| 60 | 6.662 | 11 | 3 | 2 | 3 | 178.500 | 3 | 10 | 1.609 | 24.700 |
| 120 | 4.336 | 16 | 4 | 3 | 6 | 365.500 | 6 | 13 | 2.490 | 52.960 |
| 300 | 551.759 | 21 | 4 | 3 | 7 | 425.500 | 7 | 21 | 2.542 | 175.560 |
| 600 | 1.570.435 | 25 | 4 | 3 | 7 | 425.500 | 7 | 28 | 2.590 | 401.660 |

Model, gerçek 120 dk koşusuyla ustalık gelirinde **birebir** (52.960), yapılandırmada bir adım önde
(model 100. dakikada garaj 4 alıyor, gerçek oyun 120. dakikada henüz almamış).

**EN ÖNEMLİ BULGU:** oyuncu **~3 saatte bugünkü içeriğin tamamını** bitiriyor (7 araç, garaj 4,
3 alan, 7. rütbe) ve sonrasında para harcayacak yer kalmıyor: 5. saatte ~550.000 ₺, 10. saatte
~1.570.000 ₺ atıl birikiyor. Bu, ekonominin değil **İÇERİĞİN** sınırı. Bir sonraki aşamanın önceliği
gelir eklemek değil, **para harcanacak içerik** eklemektir (araçlar, işlevsel eşyalar, koleksiyon
plakaları, dekor).

### 7.3 Faz 3 A seçeneğinin ölçümü

| Senaryo | 60 dk değer/rütbe | 120 dk para | 300 dk para |
|---|---|---|---|
| Bugün (BMW başlangıç, sınıf etkisi yok) | 178.500 / 3 | 4.336 | 551.759 |
| Bugünkü başlangıç + sınıf etkisi | 190.500 / 3 | 36.514 | 652.069 |
| **Şahin başlangıç + sınıf etkisi** | 105.500 / 1 | 31.820 | 558.116 |
| Şahin başlangıç, sınıf etkisi yok (kontrol) | 105.500 / 1 | 21.770 | 484.154 |

Bugünkü başlangıçla sınıf etkisi **sabit +%15**'e dönüşüyor (oyuncu zaten A sınıfı araçla başlıyor):
ilerleme hissi sıfır. Önerilen başlangıçla çarpan ×1,00'den başlıyor ve BMW alındığında (modelde
**154. dakika**) ×1,15'e çıkıyor — "hurda Şahin'den BMW'ye" yayı ölçülebilir hale geliyor. Ayrıca
garaj değeri 85.000 yerine 15.000'den başladığı için ilk saatte rütbe 1'de kalıyor (bugün 3).

## 8. OFFLINE İŞLER — yalnızca tasarım notu

Car Town'da uzun işler "4 saat sonra gel" mantığındaydı; bizde uzun iş 90-300 sn gerçek zamanlı.
Offline katman eklenirse:

1. Kayda `last_seen` zaman damgası (v8) ve açılışta geçen süre hesabı gerekir.
2. **Offline PARA ÜRETMEMELİ.** Ekonominin tamamı "alan kapasitesi" kısıtı üzerine kurulu; offline
   gelir bu kısıtı atlar ve §7.2'deki doyma sorununu büyütür.
3. Doğru tasarım: offline süre **bekleyen müşteri** üretir (üst sınır: bekleme noktası sayısı) ve
   oyuncu döndüğünde çalışacak iş bulur. Böylece "geri dönme sebebi" olur, ekonomi bozulmaz.
4. Üst sınır ~2 saat; fazlası oyuncuyu "zaten her şey hazır" hissine sokar.

## 9. CAR TOWN UYUM TABLOSU

| Car Town prensibi | Bizim sistem | Durum |
|---|---|---|
| Player Level | XP 1,25^n eğrisi, seviye ödülü (para + açılan içerik), arıza ve araç kilidi | DOĞRU |
| Garage Expansion | 4 fiziksel seviye (12/30/60k), dünyada tabela, müşteri arzını büyütür, alan açar, **etkileri plakada yazıyor** | DOĞRU |
| Work Bays | 1-3 alan, ayrı satın alma, dünyada kilitli görsel, kapasite = açılmış alan, **uzun işin alan şartı** | DOĞRU |
| Jobs | 4 kısa (6-12 sn) + 3 uzun (90-300 sn), seviye/garaj/alan kilidi, **₺/dk gösterimi** | DOĞRU |
| Job Mastery | 5 yıldız, ağırlığa göre eşik, tek seferlik ödül + kalıcı %10 XP / %2 ödül, ustalık panosu | DOĞRU (5★ fiziksel plaka: PLAN) |
| Garage Value | 4 kalem, 10 rütbe (8 ulaşılabilir), araç kilidi, merdiven ekranı | DOĞRU (eşya/dekor kalemi: PLAN) |
| Vehicle Classes | `class` alanı var ama yalnızca gösterim | EKSİK — Faz 3 tasarımı hazır |
| Vehicle Progression | sahiplik + boya + garaj değeri; araç başına ilerleme yok | EKSİK — tasarlandı (A seçeneği), kodlanmadı |
| Functional Items | yok | PLAN — 3 prototip fiyatlandı |
| Collections | yok | PLAN — veri modeli hazır, 7 araç yetersiz |
| Offline Jobs | yok | PLAN — §8 |
| Social | yok | BİLEREK YOK |
| Racing | yok | BİLEREK YOK |

## 10. PERFORMANS (1152×648, vsync kapalı)

| Durum | FPS ort / min | Çizim | VRAM |
|---|---|---|---|
| Dünya garaj 1 (trafik 4) | 859 / 764 | 240 | 83,5 MB |
| Dünya garaj 2 (trafik 6) | 553 / 515 | 383 | 85,5 MB |
| Dünya garaj 3 (trafik 8) | 569 / 489 | 439 | 84,2 MB |
| Dünya garaj 4 (trafik 10) | 493 / 474 | 538 | 95,5 MB |
| Genişletme plakası açık (kuruluş 0,3 ms) | 469 / 452 | 528 | 95,7 MB |
| Garaj ekranı (açılış 10 ms) | 177 / 171 | 1.148 | 113,7 MB |
| Ustalık panosu (açılış 66 ms) | 166 / 150 | 1.122 | 114,4 MB |

Yeni geri bildirim satırları ve ustalık panosu ölçülebilir bir maliyet getirmedi (plaka kuruluşu
0,3 ms, pano 66 ms tek seferlik). Hedefler (60 FPS, <700 dünya çizimi, <120 MB) tutuyor.
