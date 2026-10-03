# DOĞRUDAN ARAÇ SATIN ALMA (₺) — Ekonomi Tasarımı (genel, veri güdümlü)

Tarih: 2026-10-02 · Revizyon 2 · Durum: **TASARIM, oyun kodu değişmedi**

Bu revizyonla doğrudan satın alma **16 araca özel bir fiyat listesi değil, genel bir ekonomi kuralıdır**. Hiçbir değer araç kimliğine bağlı değildir. Bir aracın doğrudan fiyatı, açılış seviyesi, kasa sadakati ve garaj değeri, kataloğa zaten yazılan metadata'dan **türetilir**. 16 araç yalnızca ilk katalogdur; sistem sentetik 20/50/100/200 araçlık kataloglarla test edildi (§16).

**Önceki belgeler:**
- [vehicle_crate_design_v2.md](vehicle_crate_design_v2.md),
- [vehicle_crate_implementation_report.md](vehicle_crate_implementation_report.md),
- [crate_system_qa_report.md](crate_system_qa_report.md) (kasa sistemi PASS).

**Analiz araçları** (`tools/economy/`, oyun kodu değil):

| Dosya | Ne yapar |
|---|---|
| `direct_purchase_policy.json` | **Önerilen politika.** Uygulamada olduğu gibi `vehicles/direct_purchase.json` olur. Araç kimliği içermez |
| `acquisition_model.py` | Katalog (gerçek ya da sentetik) + politika → fiyat / seviye / sadakat / garaj değeri türetme; katalog doğrulama; sentetik katalog üretici |
| `acquisition_sim.py` | **Parametrik 100.000 oyuncu simülasyonu**, herhangi bir katalogla, çok çekirdekli. Gem kaynakları `crate_sim.py`'den (oyunla eşleşmesi `sync_check` ile doğrulanır), ₺ eğrisi gerçek 600 dakikalık koşudan ölçülmüş |
| `scalability_test.py` | 16 gerçek + 20/50/100/200 sentetik araç × 8 dağılım × 3 tohum değişmez testi, yeni araç / yeni nadirlik örnekleri, kimlik taraması, performans. **91.544 kontrol, 0 hata** |
| `direct_purchase_sim.py` | İlk revizyonun 16 araçlık simülasyonu. Yalnızca ayar geçmişi (§10.3) için duruyor |

**Revizyon 1'e göre değişenler (gerekçeleri ilgili bölümlerde):**
1. **Fiyat formülü:** fiyat, seviye ve sadakat genel formülden türetiliyor; tüm ayarlar tek politika dosyasında.
2. **Kamiq:** 82.000 → **83.000 ₺**. Formül 82.500 veriyor; ilk tablo Python'un "çifte yuvarlama"sıyla 82.000 olmuştu. Oyunun GDScript `round()`'ı yarımı yukarı yuvarlar.
3. **E60 sadakati:** 60 → **73 kasa**. Sabit "60 kasa" ölçeklenmiyordu (§6.3); yerine oran tabanlı kuyruk kuralı geldi, 60 alt sınır olarak kaldı. 16 araçta 30 günlük sonuçları değiştirmiyor (E60'ın ₺ yolu seviye 37'de).
4. **Kasasız Epic/Legendary yasak:** sadakat şartı olan nadirlikteki araç bir kasa havuzunda olmak zorunda (katalog kuralı, §6.4).
5. **10 saat bakiyesi:** 181.266 → **20.314 ₺** (§11). İlk simülasyon, kasa sadakati yüzünden henüz alınamayan araçlar için de para ayırıyordu.

---

## 1. Yönetici özeti

**Üç edinim yolu, birbirine karışmaz:**

| Yol | Para | Ne alırsın | His |
|---|---|---|---|
| **KASA** (mevcut, değişmez) | gem | temalı kasadan rastgele araç | "Şansımı deniyorum" |
| **DOĞRUDAN** (yeni) | ₺ | seçtiğin araç, garanti | "Bu aracı istiyorum ve parasını biriktiriyorum" |
| **GERİ ALMA** (mevcut) | ₺ | keşfedip sattığın araç, katalog fiyatına | "Daha önce keşfettiğim aracı geri alıyorum" |

**Genel kural (araç kimliği yok):**
```
fiyat   = yuvarla( katalog fiyatı × nadirlik çarpanı × sınıf çarpanı × kategori çarpanı × genel ayar , 1.000 )
seviye  = max( aracın ilerleme seviyesi , aracın kasasının kapısı ) + nadirlik farkı
sadakat = max( nadirliğin alt sınırı , "kasadan gelen oyuncuların %87'si bu aracı bulmuş olur" kasa sayısı )   [yalnızca Legendary'de kuyruk]
garaj değeri = katalog fiyatı (hangi yoldan gelirse gelsin)
```

**Varsayılan politika:**

| Nadirlik | Fiyat çarpanı | Seviye farkı | Sadakat |
|---|---|---|---|
| Common | ×1 | +0 | — |
| Rare | ×1,5 | +3 | — |
| Epic | ×3 | +6 | 5 kasa |
| Legendary | ×12 | +12 | en az 60 kasa ve %87 kuyruk |

Sınıf ve kategori çarpanları 1,0 (nötr), genel ayar 1,0.

**Neden fiyat değil kapı?** Geç oyunda ₺ fiilen sınırsız. 16 araçta aktif oyuncunun 30. gün bakiyesi 4,4–4,7 M ₺. Katalog fiyatı, yarı fiyat ve hatta ×8 fiyat bile aktif oyuncuyu 30 günde %100 koleksiyona götürüyor (§10.1). Nadirliği **seviye kapısı + kasa sadakati** koruyor.

**100.000 oyuncu, ACTIVE (60 dk/gün), 30. gün:**

| Katalog | Koleksiyon (kasa → final) | Tam koleksiyon | Legendary'lerin kasadan gelen payı | Gem harcaması (final / yalnızca kasa) | Yeni araçta kasa payı |
|---|---|---|---|---|---|
| **16 gerçek** | %91,2 → %93,7 | %14,7 → **%26,1** | %100 | %95 | %82 |
| 50 sentetik | %58,8 → %83,5 | %0 → %0 | %100 | %104 | %54 |
| 100 sentetik | %40,1 → %79,1 | %0 → %0 | %100 | %110 | %38 |

16 araçta E60 sahipliği %20,2 → **%28,8**. 10 saatte (tek gün) 13 araç, **20.314 ₺** bakiye.

**Ölçek bulgusu:** katalog büyüdükçe ₺, Common/Rare için ana edinim yolu olur; bu Car Town DNA'sıdır. Kasa yine ölmez: gem tamamen kasaya gider ve Legendary'ler ilk 30 günde %100 kasadan gelir. Bu dengeyi izlemek ve ayarlamak için kollar §16.6'da.

## 2. Mevcut kasa ekonomisi (gerçek dosyalardan, değişmez)

- **Kasalar** (`vehicles/crates.json`): ŞEHİR 30 gem sv 1 · AİLE 50 gem sv 10 · SPOR 80 gem sv 14 · PRESTİJ 120 gem sv 20.
- **Ağırlıklar:** Common 100 / Rare 40 / Epic 15 / Legendary 4. Oran = ağırlık / havuz toplamı; sahiplikle değişmez. Sonuç satın alma anında kilitlenir.
- **Kopya:** yıldız (1/3/6/10/15) + gem hurdası (2/5/12/30). Keşif gemi 3/8/20/40.
- **Koleksiyon gemi:** 5/10/14/16 araçta 15/30/50/100.
- **Sahiplik:** `VehicleOwnership`, keşif ≠ sahiplik. Bugünkü `purchase_vehicle` yalnızca **geri alma** (keşfedilmiş araç, katalog fiyatı).
- **Garaj değeri** (`GarageValue`, türetilmiş): sahip olunan araçların katalog fiyatı + geliştirme + alan + boya + dekor.
- **QA referansı (10 saat):**

  | Kalem | Değer |
  |---|---|
  | Tamir geliri | 2.023.456 ₺ |
  | Dekor | 1.759.800 ₺ |
  | Bakiye | 138.156 ₺ |
  | Araç | 8 |
  | Kasa | 20 |
  | Garaj değeri | 1.127.420 |

## 3. Car Town referansı

Kaynak: Car Town Wiki; ayrıntı [vehicle_crate_research.md](vehicle_crate_research.md).

| Mekanik | Car Town | Bizde |
|---|---|---|
| Doğrudan satın alma | Buy Cars: altınla, **seviye / garaj değeri kilitli** | DOĞRUDAN: ₺ + türetilmiş seviye + (Epic/Legendary) kasa sadakati |
| Kilit atlama | **Blue Points (premium) seviye kilidini atlar** | **Yok.** Gem hiçbir kilidi atlatmaz |
| Kutu | Mystery Box: yalnızca BP, seviye kısıtı yok, ücretli yeniden çevirme | KASA: gem, seviye kapılı, yeniden çevirme yok, oranlar açık |
| Kutu ile doğrudan fiyat | 1 BP ≈ 1.200 altın. Gold Box 25 BP (≈30.000 altın) çoğunlukla 50–100 bin altınlık araç verir. **Kutu beklenen değerde ucuz ama rastgele** | Aynı DNA: kasa ucuz ve olasılıklı; doğrudan pahalı ve garanti |
| Katalog büyümesi | Yüzlerce araç; çoğu altınla alınır, kutular "özel" araç kaynağı | Büyük katalogda Common/Rare çoğunlukla ₺ ile, Epic/Legendary kasa öncelikli (§16) |

**Alınmayan:** premium paranın kilit atlatması ve ücretli yeniden çevirme.

## 4. Doğrudan satın alma felsefesi

1. **Kasa keşif, doğrudan hedef.** Doğrudan yol, oyuncunun istediği araca ulaşma hakkıdır.
2. **Fiyat koruma değildir, kapı korumadır.** Fiyat "bu araç değerli" sinyali ve orta oyunda biriktirme hedefidir. Nadirliği seviye kapısı ve sadakat korur.
3. **Nadir araç önce kasadan gelir.** Epic/Legendary'nin ₺ yolu kasa açmakla ilerler ve kasa yolunun kötü şans kuyruğunda açılır: şanssız ama sadık oyuncuya güvence ağı.
4. **Para birimleri karışmaz.** Gem = kasa. ₺ = doğrudan + geri alma. Gem kilit atlatmaz.
5. **Garaj değeri ödenen fiyatı değil katalog fiyatını yazar.**
6. **Veri güdümlü.** Yeni araç yalnızca katalog metadata'sıyla eklenir. Ekonomi kodunda araç kimliği, araç başına fiyat ya da `if` yoktur (§16).

## 5. Fiyat formülü ve 16 aracın sonuçları

### 5.1 Formül

```
direct_price = yuvarla_yarım_yukarı( base_value
                                     × rarity.price_multiplier
                                     × class_modifier[class]
                                     × category_modifier[category]
                                     × tuning_multiplier ,  round_to )
               (en az round_to; başlangıç aracı satılmaz; politikada satırı olmayan nadirlik satılmaz)
```

| Parametre | Kaynak | Ne işe yarar / neden gerekli | Ayar aralığı | Ne zaman değişir |
|---|---|---|---|---|
| `base_value` | `cars.json` `price` (bugünkü katalog fiyatı) | Aracın "piyasa değeri". Garaj değeri, satış (%40) ve geri alma da bunu kullanır; tek kaynak | Sınıf bandına göre (bugün 15k–120k) | Yalnızca araç verisi değişince |
| `rarity.price_multiplier` | politika, nadirlik satırı | Garanti yolun "nadirlik primi". Kasada %2,8 olan aracı kesin almak katalog fiyatına olmamalı | Common 1 · Rare 1–2 · Epic 2–4 · Legendary 8–15 | Nadirlik ayarı / yeni nadirlik |
| `class_modifier[class]` | politika, `{"default": 1.0}` | **Bugün nötr.** `base_value` sınıfı zaten içeriyor (D 15–20k … A 85–120k). Bir sınıfın katalog fiyatı oyun içi değerinden ayrışırsa (ör. "S sınıfı ₺ ile fazla kolay") tek satırla düzeltmek için | 0,8–1,5 | Yeni sınıf ya da sınıf bazlı denge sorunu |
| `category_modifier[category]` | politika, `{"default": 1.0}` | **Bugün nötr.** `cars.json`'da `category` zaten var (sedan, hatchback…). İleride "klasik", "etkinlik" gibi kategoriler için | 0,8–2,0 | Yeni kategori |
| `tuning_multiplier` | politika | Tüm doğrudan fiyatları birlikte kaydıran ekonomi kolu. Bugün 1,0 | 0,5–3,0 | Simülasyon kasa / ₺ dengesinin bozulduğunu gösterirse (§16.6) |
| `round_to`, `rounding` | politika | Fiyatlar okunur kalsın (1.000'lik). `half_up` = GDScript `round()` | 500 / 1.000 / 5.000 | Para ölçeği değişirse |

**Neden daha karmaşık değil?** Seviyeye ya da saatlik gelire bağlı fiyat denendi; fiyat korumadığı için değer katmadı (§10.3, v3: Legendary ×35 bile E46'yı aktif oyuncuların %100'üne sattı). Bu yüzden sınıf ve kategori çarpanları yalnızca **kanca** olarak var ve varsayılanda nötr.

### 5.2 16 araç: formülün ürettiği değerler

- "Kasa: beklenen / medyan" = 1/p ve %50 olasılık.
- "≈ gün" = ACTIVE oyuncu ~111 gem/gün kazanır ve tüm gemini o kasaya verirse geçen süre.
- "Biriktirme" = fiyat ÷ o seviyedeki ₺/dk (ölçülmüş eğri).

| Araç | Sınıf | Nadirlik | base_value (= garaj değeri) | Kasa | p | Kasa: beklenen / medyan | ≈ gün | **Doğrudan ₺** | **Sv** | **Sadakat** | Biriktirme ≈ dk |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Tofaş Şahin | D | Common | 15.000 | başlangıç | — | — | — | (geri alma 15.000) | — | — | — |
| Hyundai Getz | C | Common | 35.000 | ŞEHİR | %33,9 | 3,0 / 2 | 0,8 | **35.000** | **8** | — | 14 |
| Hyundai Accent Blue | C | Common | 38.000 | ŞEHİR | %33,9 | 3,0 / 2 | 0,8 | **38.000** | **8** | — | 15 |
| Hyundai Era | C | Rare | 30.000 | ŞEHİR | %13,6 | 7,4 / 5 | 2,0 | **45.000** | **9** | — | 18 |
| Renault Toros | D | Epic | 20.000 | ŞEHİR | %5,1 | 19,7 / 14 | 5,3 | **60.000** | **9** | 5 ŞEHİR | 24 |
| Ford Focus | C | Rare | 45.000 | ŞEHİR | %13,6 | 7,4 / 5 | 2,0 | **68.000** (67.500) | **13** | — | 19 |
| VW Passat B5.5 | B | Common | 50.000 | AİLE | %39,2 | 2,5 / 2 | 1,1 | **50.000** | **12** | — | 14 |
| Renault Fluence | B | Common | 60.000 | AİLE | %39,2 | 2,5 / 2 | 1,1 | **60.000** | **15** | — | 17 |
| Skoda Kamiq | B | Rare | 55.000 | AİLE | %15,7 | 6,4 / 5 | 2,9 | **83.000** (82.500) | **15** | — | 23 |
| VW Golf 7 | B | Epic | 65.000 | AİLE | %5,9 | 17,0 / 12 | 7,7 | **195.000** | **21** | 5 AİLE | 54 |
| Seat Leon | B | Common | 68.000 | SPOR | %84,0 | 1,2 / 1 | 0,9 | **68.000** | **16** | — | 21 |
| Honda Civic VTEC | B | Epic | 72.000 | SPOR | %12,6 | 7,9 / 6 | 5,7 | **216.000** | **24** | 5 SPOR | 56 |
| **BMW E46** | A | **Legendary** | 85.000 | SPOR | %3,4 | 29,8 / 21 | 21,4 | **1.020.000** | **26** | **60 SPOR** | 266 |
| Audi A3 | A | Common | 95.000 | PRESTİJ | %69,4 | 1,4 / 1 | 1,6 | **95.000** | **20** | — | 27 |
| Volvo S60 | A | Rare | 105.000 | PRESTİJ | %27,8 | 3,6 / 3 | 3,9 | **158.000** (157.500) | **25** | — | 41 |
| **BMW E60** | A | **Legendary** | 120.000 | PRESTİJ | %2,8 | 36,0 / 25 | 38,9 | **1.440.000** | **37** | **73 PRESTİJ** | 376 |

**İstenen listeyle karşılaştırma:**
- **14 araç birebir aynı:** Getz 35k, Accent 38k, Era 45k, Toros 60k, Passat 50k, Focus 68k, Fluence 60k, Leon 68k, A3 95k, Golf 195k, Civic 216k, S60 158k, E46 1,020 M, E60 1,440 M.
- **Kamiq 82k → 83k:** formül 55.000 × 1,5 = 82.500 veriyor. Yarımı yukarı yuvarlama (GDScript `round()`) 83.000 yapar. İlk tablo Python `round()`'ının çifte yuvarlamasıyla 82.000 yazmıştı. 82.000'i korumak için ya `rounding: "half_even"` (oyunda ek kod) ya da araç başına istisna gerekir; ikincisi bu revizyonun ilkesine aykırı. **Öneri: 83.000.**
- **Seviyeler** birebir aynı.
- **E60 sadakati 60 → 73:** §6.3'teki kuyruk kuralından geliyor. 30 günlük sonuçları etkilemiyor, çünkü E60'ın ₺ yolu seviye 37'de açılıyor ve ölçülmüş eğri ~85 saatte 36'ya ulaşıyor.

Doğrudan fiyatlar toplamı (Şahin hariç): 3.771.000 ₺. Katalog toplamı 943.000 ₺.

## 6. Açılış seviyesi ve kasa sadakati (genel kurallar)

### 6.1 Seviye

```
direct_level = clamp( max(progression_level, crate_gate) + rarity.level_offset , min_unlock_level , max_unlock_level )
  progression_level = cars.json "min_level"
  crate_gate        = aracın bulunduğu kasaların en düşük min_level'ı (kasada değilse 1)
```

- **`max(progression_level, crate_gate)`:** doğrudan yol aracın kendi kasası açılmadan asla açılmaz (§16 değişmezi).
- **`level_offset`:** nadir araçlarda kasa yoluna avans verir. Common +0 (garanti yol hemen), Rare +3, Epic +6, Legendary +12.
- **Aralık:** Common 0–4, Rare 2–7, Epic 4–10, Legendary 10–16. Sıra korunmalı (doğrulayıcı kontrol eder).
- **Clamp:** `SaveManager.MAX_LEVEL = 99` ile uyumlu.

**16 araç:**

| Sv | Araç (şart) |
|---|---|
| 8 | Getz, Accent |
| 9 | Era, Toros (5 ŞEHİR) |
| 12 | Passat |
| 13 | Focus |
| 15 | Fluence, Kamiq |
| 16 | Leon |
| 20 | A3 |
| 21 | Golf 7 (5 AİLE) |
| 24 | Civic (5 SPOR) |
| 25 | S60 |
| 26 | E46 (60 SPOR) |
| 37 | E60 (73 PRESTİJ) |

Kasa kapıları 1/10/14/20 değişmez.

### 6.2 Kasa sadakati

```
loyalty = max( rarity.loyalty_crates ,  ceil( ln(1 − rarity.loyalty_tail) / ln(1 − p) ) )      [loyalty_tail yoksa yalnızca ilk terim]
  p        = aracın kendi kasasındaki oranı (birden çok kasadaysa en yükseği)
  sayılan  = aracın bulunduğu kasalardan AÇILAN kasa sayısı (satın alma değil açılış)
```

| Nadirlik | `loyalty_crates` | `loyalty_tail` | Anlamı |
|---|---|---|---|
| Common / Rare | 0 | — | şart yok |
| Epic | 5 | — | "o kasayı denemiş ol" (Civic'te %49, Golf'te %26 bulma şansı) |
| Legendary | 60 (alt sınır) | 0,87 | "kasadan gelen oyuncuların %87'si bu aracı zaten bulmuş olurdu" |

### 6.3 Neden sabit "60 kasa" değil de kuyruk kuralı?

Sabit sayı yalnızca 16 araçlık katalogda anlamlıydı: E46 %3,4 → P87 ≈ 60 kasa. Sentetik 20 araçlık katalogda tek Legendary ve 3 kasa var; aktif oyuncu 30 günde ~63 kasa açıyor, 60 sınırına ulaşıyor:
- **sabit 60:** tam koleksiyon %13,0 → **%64,7**,
- **kuyruk kuralı:** **%42,1**; Legendary %100 kasadan.

Kuyruk kuralı orana bağlı olduğu için havuz büyüdükçe kendiliğinden ayarlanıyor. Kasaya yeni araç eklenince oradaki Legendary'nin oranı düşer, şart artar (§16.3 örneği: E46 60 → 81). 60 alt sınırı mevcut 16 aracın değerlerini korur.

### 6.4 Katalog kuralı: sadakatli nadirlik kasada olmalı

Hiçbir kasada olmayan Epic/Legendary için sadakat ölçülemez. Denenen seçenekler:

| Seçenek | Sonuç (50 araç) |
|---|---|
| Sadakati kaldırmak | Tek kasasız Legendary, ACTIVE Legendary payını %5,7 → %24,8'e çıkardı |
| Tüm kasaların toplamını saymak | ACTIVE düzeldi, HEAVY toplam 60 kasayı aşıp yine aldı (%28,2) |
| **Doğrulama hatası (seçilen)** | Katalog yüklenirken ERROR. Yanlışlıkla yayınlanırsa tüm kasaların toplamı sayılır |

Common/Rare araçlar kasasız (yalnızca ₺ ile) satılabilir.

## 7. Kasa ve doğrudan karşılaştırması (16 araç)

| Araç | KASA (gem → olasılık) | DOĞRUDAN (₺ → kesin) | Yorum |
|---|---|---|---|
| **Honda Civic** (Epic) | SPOR %12,6; medyan 6 kasa (~4 gün); %90 için 18 | Sv 24 + 5 SPOR, 216.000 ₺ | Şanslı oyuncu kasadan çok önce bulur, şanssız oyuncu sv 24'te garantiye kavuşur |
| **VW Golf 7** (Epic) | AİLE %5,9; medyan 12 kasa; %90 için 38 | Sv 21 + 5 AİLE, 195.000 ₺ | Doğrudan yol sv 21'de (~5. gün) şanssızlara yetişir |
| **Volvo S60** (Rare) | PRESTİJ %27,8; medyan 3 kasa | Sv 25, 158.000 ₺ | Çoğu oyuncu kasadan alır |
| **BMW E46** (Legendary) | SPOR %3,4; medyan 21, %87 için 60, %95 için 88 kasa | Sv 26 + **60 SPOR**, 1.020.000 ₺ | ACTIVE 30. gün sahiplik %54,8 → %71,2. Artışın çoğu kasa odağından (aşağıda) |
| **BMW E60** (Legendary) | PRESTİJ %2,8; medyan 25, %87 için 73 kasa | Sv 37 + **73 PRESTİJ**, 1.440.000 ₺ | ₺ yolu ~85+ saatlik hedef. ACTIVE %20,2 → %28,8; artışın tamamı kasa odağından |

**Kasa odağı:** oyuncu Common/Rare araçları ₺ ile alınca, kasalarda yeni çıkabilecek araç olarak nadirler kalır ve gem oraya gider. Legendary sahipliği bu yüzden artıyor, ama **tamamen kasadan**: 30 günde Legendary'lerin kasadan gelen payı her katalogda %100. Legendary hâlâ nadir; kopyası çok nadir.

## 8. Garaj değeri davranışı (değişmez)

| Olay | Sahiplik | Keşif | Garaj değeri |
|---|---|---|---|
| Kasadan yeni araç | +1 | +1 | + `base_value` |
| **Doğrudan satın alma** | +1 | +1 | + **`base_value`** (ödenen fiyat değil) |
| Kopya | — | — | — |
| Satış (%40 iade) | −1 | keşfedilmiş kalır | − `base_value` |
| Geri alma | +1 | — | + `base_value` |

Doğrudan alım sahip olunan araca uygulanamaz. Garaj değeri formülüne yeni terim girmez; 200 araçta da aynı formül.

## 9. Koleksiyon davranışı (değişmez)

- **DISCOVERED ≠ CURRENTLY OWNED.** Doğrudan alım = kasadan çıkış: keşif +1, ilk keşif gemi (nadirliğe göre) ve koleksiyon gemi bir kez.
- **Kopya üretmez.** Doğrudan alım kopya ya da yıldız vermez; kopya yalnızca kasadan.
- **Geri alma:** keşfedilmiş ama satılmış araç katalog fiyatına (seviye / sadakat aranmaz).
- **Kart:** keşfedilmemiş araç kartına doğrudan yolun şartı eklenir: "SATIN AL: SV 26 · SPOR KASASI 12/60 · 1.020.000 ₺".
- **Ölçek notu:** bugünkü koleksiyon gem eşikleri 5/10/14/16 (`crate_manager.gd` `COLLECTION_MILESTONES`) **16 araca sabit**. 17+ araçta "16" eşiği tam koleksiyondan önce tetiklenir. Önerilen oransal eşik %31/%63/%88/%100 (yukarı yuvarlanmış), 16 araçta birebir 5/10/14/16 verir. Simülasyon büyük kataloglarda bunu kullanıyor. Kasa sistemine ait bir değişiklik; katalog 16'yı aşmadan yapılmalı (§16.7).

## 10. 100.000 oyunculuk simülasyon sonuçları

**Komut:** `python3 tools/economy/acquisition_sim.py --players 100000 --catalogs 16,50,100`. 12 çekirdekte 2 dk 47 sn.

**Politika ("koleksiyoncu", en kötü durum):**
- gem → P(yeni)/fiyat oranı en iyi açık kasa;
- ₺ → önce zorunlu yatırımlar (130.500 ₺), sonra parası yeten **en ucuz** yeni araç, sonra dekor (alınabilir sıradaki araç için para ayırarak).

"Hedefli" politika (en pahalıyı biriktir) 16 araçta aynı sonucu verdi (ACTIVE 16/16 %26,1 ile %26,2). Sonucu politika değil kapılar belirliyor.

**Sentetik katalog üretici** (`acquisition_model.synthetic`):
- **Dağılım:** sınıf D/C/B/A/S (S bugün yok); nadirlik varsayılanı %45/28/18/9; 6 kategori.
- **Değerler:** sınıf bandına göre ilerleme seviyesi ve `base_value`.
- **Kasalar:** ilerleme sırasıyla 4–7 araçlık havuzlar. Kasa kapısı havuzun en düşük seviyesi, gem fiyatı 30 + 4,5 × (kapı − 1).
- **Kasasız araçlar:** %5'i kasasız (yalnızca Common/Rare).
- **Gem kaynakları ve ₺ eğrisi bugünkü oyunla aynı.** Yani büyük katalog sonuçları "aynı ekonomiye daha çok araç eklenirse" sorusunun cevabı.

### 10.1 16 araç: revizyon 1 senaryoları (değişmedi)

ACTIVE, 30. gün:

| Senaryo | 16/16 | E60 | Kasa | Not |
|---|---|---|---|---|
| Yalnızca kasa | %14,7 | %20,2 | 65,5 | bugün |
| Katalog fiyatı, eski seviye | **%100** | %100 | 26,9 | kasa −%59 |
| Aşırı ucuz (×0,5) | %100 | %100 | 26,9 | CASUAL bile %100 |
| Pahalı (×8) | %100 | %100 | 33,9 | ₺ fazlası fiyatı eritiyor |
| **Final** | **%26,1** | **%28,8** | 50,2 | kasa −%23, yeni araçların %82'si kasadan |

### 10.2 Parametrik katalog: yalnızca kasa ve final, 100.000 oyuncu, 30. gün

**Sütunlar:**
- **Koleksiyon** = ortalama sahip olunan / katalog.
- **Legendary payı** = katalogdaki Legendary'lerin ortalama sahiplik oranı.
- **Kasa payı** = yeni araçların kasadan gelen oranı.
- **C/R/E/L** = her nadirlikte kasadan gelen pay.

**16 GERÇEK ARAÇ**

| Profil | Mod | Araç medyan (P10–P90) | Koleksiyon | Tam koleksiyon | Legendary payı | E60 / E46 | Garaj değeri | ₺ harcama (araç / dekor) | ₺ bakiye | Gem | Kasa | Kopya | Kasadan / doğrudan | Kasa payı · C/R/E/L |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CASUAL | kasa | 14 (12–15) | %85,3 | %3,1 | %20,8 | %11,8 / %29,8 | 2,64 M | 1,89 M (0 / 1,76 M) | 138 k | 2.526 | 47,0 | 34,3 | 12,7 / 0 | %100 |
| CASUAL | final | 14 (14–15) | %90,7 | %7,6 | %27,9 | %13,5 / %42,3 | 2,58 M | 2,00 M (225 k / 1,65 M) | 25 k | 2.522 | 40,2 | 28,7 | 11,5 / 2,0 | %85 · 94/89/60/100 |
| ACTIVE | kasa | 15 (14–16) | %91,2 | %14,7 | %37,5 | %20,2 / %54,8 | 2,70 M | 1,89 M | 4,73 M | 3.858 | 65,5 | 51,9 | 13,6 / 0 | %100 |
| **ACTIVE** | **final** | 15 (14–16) | %93,7 | **%26,1** | %50,0 | **%28,8** / %71,2 | 2,74 M | 2,21 M (316 k / 1,76 M) | 4,42 M | 3.670 | 50,2 | 38,7 | 11,4 / 2,6 | **%82** · 94/83/49/**100** |
| HEAVY | kasa | 15 (14–16) | %92,6 | %21,1 | %44,8 | %25,6 / %64,0 | 2,72 M | 1,89 M | 15,07 M | 4.364 | 71,3 | 57,5 | 13,8 / 0 | %100 |
| HEAVY | final | 15 (14–16) | %94,7 | %34,1 | %57,3 | %35,9 / %78,6 | 2,75 M | 2,25 M (361 k / 1,76 M) | 14,71 M | 4.063 | 53,3 | 41,9 | 11,3 / 2,8 | %80 · 98/77/42/100 |
| 10 saat | kasa | 11 (9–12) | %68,0 | %0 | %5,1 | %5,3 / %5,0 | 2,45 M | 1,89 M | 138 k | 941 | 20,1 | 10,2 | 9,9 / 0 | %100 |
| 10 saat | final | 13 (12–14) | %80,6 | %0 | %5,1 | %5,3 / %5,0 | 2,45 M | 2,01 M (235 k / 1,64 M) | **20 k** | 941 | 20,1 | 10,2 | 9,9 / 2,0 | %83 |

**50 SENTETİK ARAÇ** (8 kasa; C24 R13 E8 L5)

| Profil | Mod | Araç medyan (P10–P90) | Koleksiyon | Tam | Legendary payı | Garaj değeri | ₺ harcama (araç / dekor) | ₺ bakiye | Gem | Kasa | Kopya | Kasadan / doğrudan | Kasa payı · C/R/E/L |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CASUAL | kasa | 23 (21–25) | %46,0 | %0 | %9,2 | 3,03 M | 1,89 M | 138 k | 2.433 | 35,0 | 13,0 | 22,0 / 0 | %100 |
| CASUAL | final | 31 (29–33) | %61,5 | %0 | %12,8 | 2,98 M | 1,95 M (591 k / 1,23 M) | 77 k | 2.497 | 30,6 | 10,9 | 19,7 / 10,1 | %66 · 61/66/92/100 |
| ACTIVE | kasa | 29 (27–32) | %58,8 | %0 | %13,6 | 3,75 M | 1,89 M | 4,73 M | 3.865 | 48,0 | 19,6 | 28,4 / 0 | %100 |
| **ACTIVE** | **final** | 42 (39–44) | %83,5 | %0 | %22,8 | 4,84 M | 3,81 M (1,92 M / 1,76 M) | 2,82 M | 4.029 | 41,3 | 19,5 | 21,9 / 18,9 | **%54** · 52/52/54/**100** |
| HEAVY | kasa | 31 (29–34) | %62,7 | %0 | %15,0 | 3,92 M | 1,89 M | 15,07 M | 4.494 | 55,2 | 24,9 | 30,4 / 0 | %100 |
| HEAVY | final | 45 (43–48) | %89,6 | %0,2 | %39,2 | 5,09 M | 4,65 M (2,75 M / 1,76 M) | 12,31 M | 4.838 | 59,2 | 39,0 | 20,2 / 23,7 | %46 · 48/38/37/100 |
| 10 saat | kasa | 13 (12–14) | %26,1 | %0 | %5,7 | 2,40 M | 1,89 M | 138 k | 878 | 15,9 | 3,9 | 12,0 / 0 | %100 |
| 10 saat | final | 29 (28–30) | %57,7 | %0 | %5,7 | 2,34 M | 2,03 M (1,19 M / 710 k) | 0 | 878 | 15,9 | 3,9 | 12,0 / 15,8 | %43 |

**100 SENTETİK ARAÇ** (16 kasa; C39 R32 E21 L8)

| Profil | Mod | Araç medyan (P10–P90) | Koleksiyon | Tam | Legendary payı | Garaj değeri | ₺ harcama (araç / dekor) | ₺ bakiye | Gem | Kasa | Kopya | Kasadan / doğrudan | Kasa payı · C/R/E/L |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CASUAL | kasa | 31 (28–33) | %30,5 | %0 | %5,0 | 3,18 M | 1,89 M | 138 k | 2.485 | 40,0 | 10,5 | 29,5 / 0 | %100 |
| CASUAL | final | 58 (56–61) | %58,4 | %0 | %5,2 | 3,10 M | 1,97 M (1,84 M / 2 k) | 56 k | 2.664 | 34,8 | 7,2 | 27,6 / 29,8 | %48 · 48/39/94/100 |
| ACTIVE | kasa | 40 (37–43) | %40,1 | %0 | %6,6 | 3,94 M | 1,89 M | 4,73 M | 3.909 | 55,5 | 16,5 | 39,1 / 0 | %100 |
| **ACTIVE** | **final** | 79 (77–81) | %79,1 | %0 | %9,0 | 6,77 M | 6,28 M (4,41 M / 1,73 M) | 344 k | 4.319 | 53,2 | 23,5 | 29,7 / 48,3 | **%38** · 42/28/48/**100** |
| HEAVY | kasa | 44 (41–47) | %43,7 | %0 | %7,2 | 4,33 M | 1,89 M | 15,07 M | 4.562 | 61,7 | 18,9 | 42,8 / 0 | %100 |
| HEAVY | final | 87 (84–90) | %87,0 | %0 | %9,0 | 7,82 M | 7,74 M (5,85 M / 1,76 M) | 9,22 M | 5.068 | 59,5 | 31,1 | 28,4 / 57,6 | %33 · 39/21/42/100 |
| 10 saat | kasa | 16 (15–18) | %16,3 | %0 | %2,1 | 2,41 M | 1,89 M | 138 k | 915 | 18,3 | 3,1 | 15,3 / 0 | %100 |
| 10 saat | final | 47 (46–49) | %47,3 | %0 | %2,1 | 2,18 M | 1,98 M (1,85 M / 0) | 50 k | 915 | 18,3 | 3,1 | 15,3 / 31,1 | %33 |

**Kontrol katalogları** (20.000 oyuncu; ACTIVE, 30. gün, yalnızca kasa → final):

| Katalog | Koleksiyon | Tam koleksiyon | Legendary payı | Gem | Kasa | Kasa payı · L |
|---|---|---|---|---|---|---|
| 20 araç (3 kasa, 1 Legendary) | %91,0 → %96,1 | %13,0 → %42,1 | %29,9 → %44,0 | 3.915 → 3.560 | 69,3 → 69,1 | %67 · L %100 |
| 200 araç (34 kasa, 21 Legendary) | %25,3 → %66,9 | %0 → %0 | %2,5 → %1,9 | 3.920 → 4.306 | 66,2 → 48,6 | %32 · L %100 |

**Okuma:**
1. **Legendary her katalogda ilk 30 günde %100 kasadan.** ₺ yolu yalnızca kuyrukta açılıyor.
2. **Kasa ölmüyor.** Gem harcaması yalnızca kasa senaryosunun %91–110'u; gem başka yere gitmiyor. Kasa *sayısı* bazı kataloglarda düşüyor: Common'lar ₺ ile alınınca oyuncu daha pahalı kasaları seçiyor ve aynı gemle daha az kasa açıyor.
3. **Büyük katalogda ₺ ana edinim yolu oluyor.** Gem geliri sabitken araç sayısı artıyor; yeni araçların kasa payı %82 (16) → %54 (50) → %38 (100) → %32 (200). Bu Car Town'ın dengesine yakın.
4. **₺ fazlası büyük katalogda doğal olarak eriyor.** ACTIVE bakiye 4,73 M → 344 k (100 araç). Ama koleksiyoncu politikada araç alımı dekoru sıkıştırabiliyor (100 araç, 10 saat: dekor 0). Bu bir **içerik temposu** kararı (§16.6).
5. **20 araçta tam koleksiyon %42.** Tek Legendary'li küçük katalogda kasa odağı etkisi tam koleksiyonu büyütüyor; Legendary yine %100 kasadan. Kural ve fiyatla değil, içerik kararıyla (katalogdaki Legendary sayısı) ayarlanır.

### 10.3 Ayar geçmişi (16 araç, ACTIVE, 5.000 oyuncu ön koşuları, revizyon 1)

| Deneme | Değişiklik | 16/16 | E60 | E46 | Sonuç |
|---|---|---|---|---|---|
| v1 | ×1/1,5/3/12; seviye +0/3/6/10; Legendary 10 kasa | %41,7 | %41,7 | %100 | red |
| v2 | Legendary +12; sadakat Epic 5 / Legendary 15 | %40,2 | %40,2 | %100 | red |
| v3 | Legendary ×35 | %34,4 | %34,4 | %100 | **fiyat koruma değil** |
| v4 | Legendary sadakat 30 | %32,9 | %33,2 | %99,3 | red |
| v5 | Legendary sadakat 60 | %26,2 | %28,9 | %71,2 | kabul (revizyon 1) |
| **revizyon 2** | v5 + kuyruk kuralı (E60 73) + kasasız-sadakat yasağı + yarım-yukarı yuvarlama | **%26,1** | **%28,8** | **%71,2** | **kabul**, aynı sonuç ve ölçeklenir |

## 11. 600 dakika (10 saat) ekonomi etkisi (16 araç)

| | Yalnızca kasa | Final |
|---|---|---|
| Araç medyanı | 11 (gerçek QA koşusu: 8) | 13 |
| Doğrudan alınan | 0 | 2,0 (ucuz Common/Rare) |
| Araca giden ₺ | 0 | 235.442 |
| Dekora giden ₺ | 1.759.800 (katalog bitti) | 1.642.200 |
| **₺ bakiye** | 138.156 | **20.314** |
| Garaj değeri | 2,45 M | 2,45 M |
| Kasa / kopya | 20,1 / 10,2 | 20,1 / 10,2 |

**Düzeltme:** revizyon 1'deki 181.266 ₺ hatalıydı. İlk simülasyon, kasa sadakati yüzünden henüz alınamayan araçlar (ör. 5 ŞEHİR kasası isteyen Toros) için de dekordan para ayırıyordu. Yeni simülasyon yalnızca gerçekten alınabilir sıradaki araç için ayırıyor. Bakiye düşük çünkü ₺ araca ve dekora gidiyor; garaj değeri aynı.

**₺ fazlası bu görevin konusu değil.** 16 araçta 30 günlük ACTIVE bakiye 4,4 M ₺; doğrudan satın alma bunu çözmüyor ve çözmeye çalışmıyor. Geç oyun ₺ harcama hedefi ayrı bir tasarım konusu.

## 12. Riskler

| # | Risk | Şiddet | Ölçüm / önlem |
|---|---|---|---|
| R1 | Doğrudan yol kasayı öldürür | Yüksek (yanlış ayarla) | Katalog fiyatında kasa −%59, 30 günde %100. Final: gem harcaması %91–110, Legendary %100 kasadan |
| R2 | Geç oyun ₺ fazlası (16 araç) | Yüksek, mevcut | Kapsam dışı; doğrudan satın alma çözmez |
| R3 | Legendary nadirliği | Orta | Fiyatla korunamaz; seviye +12 ve kuyruk sadakati korur, her katalogda 30 günde %100 kasadan |
| R4 | Kasa odağı nadirleri dolaylı kolaylaştırır | Düşük | Legendary sahipliği ×1,3–1,7, tamamen kasadan. Kabul |
| R5 | **Ölçek:** büyük katalogda ₺ ana yol olur, dekoru sıkıştırabilir | Orta | 100 araç 10 saatte dekor 0 (koleksiyoncu politika). Kollar §16.6; her katalog büyümesinde `acquisition_sim.py` |
| R6 | **Kasa havuzuna araç eklemek diğer araçların oranını düşürür** | Orta (içerik) | Kasa sisteminin mevcut davranışı (ağırlık / havuz toplamı). Örnek: SPOR'a Rare eklenince Leon %84 → %63, E46 %3,4 → %2,5. Kuyruk sadakati otomatik artar. İçerik kararı: yeni kasa mı, mevcut havuz mu |
| R7 | **İçerik güncellemesinde sadakat şartı artar** | Orta | E46 60 → 81: güncellemeden önce 70 kasa açmış oyuncu hakkını kaybetmemeli → "şart bir kez karşılandı mı açık kalır" (§13 madde 4) |
| R8 | Koleksiyon gem eşikleri 16'ya sabit | Orta (16+ araçta) | Oransal eşik (§9); kasa sistemi değişikliği, katalog 16'yı aşmadan |
| R9 | Model varsayımları | Orta | ₺ eğrisi tek gerçek koşudan; seviye eğrisi 85 saatte 36; sentetik kasalar ilerleme sıralı. Uygulamadan sonra `qa/sim_progress.gd` yeniden koşulmalı |

## 13. Önerilen uygulama planı (bu görevde yapılmadı)

1. **Veri:** `tools/economy/direct_purchase_policy.json` olduğu gibi `vehicles/direct_purchase.json` olur.
   - **Neden ayrı dosya:** üç yol ayrı kalır; kasa verisine (`crates.json`) ve araç verisine (`cars.json`) dokunulmaz. Kasa sisteminin davranışı sıfır riskle korunur.
   - **Neden tek dosya:** tüm doğrudan satın alma ayarları tek yerde. Nadirlik satırları burada, kasa ağırlıkları `crates.json`'da kalır.
2. **`vehicles/direct_purchase_catalog.gd`** (yeni, `CrateCatalog` kalıbında statik sınıf):
   - `price(id)`, `unlock_level(id)`, `loyalty(id) -> {crates, count}`, `for_sale(id)`, `validate()`.
   - Yalnızca `CarCatalog` + `CrateCatalog` + politikayı okur. **Araç kimliği yok.**
   - Formüller `acquisition_model.py` ile birebir.
3. **CrateManager:** kasa türüne göre **açılış** sayacı `opened_by_crate` (kayıtta `crates.opened`, eski kayıtta 0). Kasa RNG / oran / kopya / kayıt akışı değişmez.
4. **Sadakat kalıcılığı:** `VehicleOwnership` bir aracın sadakat şartını ilk karşıladığında kimliğini `direct_unlocked` listesine yazar (kayıtta). Sonraki içerik güncellemesi şartı artırsa da açık kalır (R7).
5. **VehicleOwnership:**
   - `direct_status(id)`: OWNED / LOCKED_LEVEL / LOCKED_LOYALTY / TOO_EXPENSIVE / BUYABLE / NOT_FOR_SALE.
   - `purchase_direct(id)`: ₺ → `add_vehicle` → keşif + koleksiyon gemi (CrateManager'daki kurallar ortak fonksiyona) → kayıt.
   - Mevcut `purchase_vehicle` geri alma olarak kalır.
6. **Showroom:** KASALAR (mevcut) ve ARAÇLAR (yeni) tabelaları. ARAÇLAR altında GERİ AL ayrı bölüm. Wireframe:
   ```
    [ KASALAR ]  [ ARAÇLAR ]      ← iki krem tabela, seçili olan amber
    ┌─ ARAÇLAR ──────┐                        ┌───────────────────────┐
    │ HYUNDAI GETZ   │     (platformda araç)   │ BMW E46               │
    │ 35.000 ₺       │                         │ LEGENDARY · A SINIFI  │
    │ FORD FOCUS     │                         │ GARAJ DEĞERİ +85.000  │
    │ SV 13 GEREKLİ  │                         │ KASADAN: SPOR %3,4    │
    │ BMW E46   ★    │                         │ ŞART: SV 26 ✔         │
    │ SPOR 12/60     │                         │  SPOR KASASI 12/60    │
    │ ── GERİ AL ──  │                         ├───────────────────────┤
    │ VOLVO S60      │                         │ SATIN AL 1.020.000 ₺  │ (pasif: "48 KASA DAHA")
    └────────────────┘                         └───────────────────────┘
    [GERİ]
   ```
   Liste 100+ araçta tembel kurulur (yalnızca görünür plakalar). Mevcut kaydırma kabı ve küçük resim tembelliği kullanılır.
7. **Koleksiyon kartı:** keşfedilmemiş araçta doğrudan yol satırı.
8. **Katalog doğrulama:** oyun açılışında (debug) ve `tools/run_tests.sh`'ta `DirectPurchaseCatalog.validate()`. Kurallar: nadirlik satırı eksik, politika sırası bozuk, kasasız sadakatli araç → ERROR.
9. **Değişmezler:** garaj değeri formülü, kopya / yıldız / hurda, kasa RNG ve oranları, fiziksel kasa, kuyruk, kayıt göçleri.

## 14. Değişecek dosyalar

| Dosya | Değişiklik |
|---|---|
| `vehicles/direct_purchase.json` (yeni) | politika (= `tools/economy/direct_purchase_policy.json`) |
| `vehicles/direct_purchase_catalog.gd` (yeni) | türetme + doğrulama, araç kimliği yok |
| `gameplay/crate_manager.gd` | `opened_by_crate` sayacı + kayıt alanı; keşif / koleksiyon gemini ortak fonksiyona ayırma |
| `gameplay/vehicle_ownership.gd` | `direct_status`, `purchase_direct`, `direct_unlocked` |
| `gameplay/save_manager.gd` | `crates.opened`, `vehicles.direct_unlocked` (eksikse boş; sürüm artmaz) |
| `gameplay/progression_effects.gd` | doğrudan alım plaka satırları |
| `ui/hud/showroom_screen.gd` | KASALAR / ARAÇLAR, doğrudan alım plakası, tembel liste |
| `ui/hud/collection_screen.gd` | keşfedilmemiş kartta doğrudan yol satırı |
| `ui/hud/hud.gd` | satın alma bildirimi (mevcut akış genişler) |
| `tools/run_tests.sh` | `scalability_test.py` + katalog doğrulama |
| `qa/sim_progress.gd`, `qa/crate_playthrough.gd` | doğrudan alım adımı |

**Değişmeyecekler:**
- `vehicles/cars.json`, `vehicles/crates.json`: yeni alan gerekmiyor.
- `world/crate_delivery.gd`, `world/crate_visual.gd`, `gameplay/crate_catalog.gd`, `gameplay/gem_rewards.gd`, `gameplay/garage_value.gd`.

**Ayrı karar** (kasa sistemi, ölçek için, §16.7): `COLLECTION_MILESTONES` oransal eşik.

## 15. Eklenmesi gereken testler

1. **Formül eşleşmesi:** `DirectPurchaseCatalog` 16 araçta §5.2 tablosunu birebir üretir; GDScript ile Python sonuçları aynı. `scalability_test.py` beklentileri tek kaynak.
2. **Sentetik değişmezler** (GDScript tarafında da, en az 100 araç):
   - fiyat > 0 ve `round_to` katı;
   - seviye ≥ kasa kapısı ve ≥ ilerleme seviyesi;
   - nadirlik arttıkça fiyat / seviye / sadakat düşmez;
   - garaj değeri = `base_value`;
   - her araç erişilebilir;
   - kasa oranı = ağırlık / havuz.
3. **Kilitler:** sv 25'te E46 alınamaz; sv 26 + 59 SPOR açılışında alınamaz; 60'ta alınır.
4. **Sadakat kalıcılığı:** şart karşılandıktan sonra havuz büyüyüp şart artınca araç alınabilir kalır.
5. **Alım:** ₺ doğru düşer; yetersiz ₺'de hiçbir şey değişmez; çift dokunuş tek alım; sahip olunan araç reddedilir.
6. **Garaj değeri:** + `base_value` (ödenen değil); satış −, geri alma +.
7. **Koleksiyon:** keşif +1; ilk keşif ve koleksiyon gemi birer kez; kopya yok.
8. **Sayaç:** yalnızca açılışta artar; kayıt / yükleme / bulut geri yüklemede korunur; eski kayıtta 0.
9. **Kasa sistemi değişmedi:** crate_test (96), oyuncu testi (47 + 10), 16 araç (80) aynen geçer; oranlar doğrudan alımdan etkilenmez.
10. **Doğrulayıcı:** eksik nadirlik satırı, bozuk politika sırası, kasasız Legendary → ERROR.
11. **Showroom UI:** KASALAR / ARAÇLAR geçişi; kilitli plaka şartı gösterir; GERİ AL ayrı; 100 araçlık sentetik katalogda açılış süresi.
12. **Ekonomi regresyonu** (`acquisition_sim.py`, gerçek katalog, ACTIVE 30. gün):
    - 16/16 ≤ %30, E60 ≤ %35;
    - Legendary kasa payı = %100;
    - gem harcaması ≥ yalnızca kasa senaryosunun %90'ı.

---

## 16. Future Vehicle Scalability

### 16.1 Yeni araç için gereken metadata

Hepsi `cars.json` ve `crates.json`'da **zaten var olan** alanlar. Yeni alan gerekmiyor.

| Alan | Dosya | Ekonomide kullanımı |
|---|---|---|
| `price` (= base_value) | cars.json | doğrudan fiyatın tabanı, garaj değeri, satış %40, geri alma |
| `rarity` | cars.json | fiyat çarpanı, seviye farkı, sadakat, kasa ağırlığı, keşif / hurda gemi |
| `class` | cars.json | `class_modifier` (bugün nötr), raporlama |
| `min_level` (= progression_level) | cars.json | doğrudan seviyenin tabanı |
| `category` | cars.json | `category_modifier` (bugün nötr) |
| kasa havuzu (`pool`) | crates.json | kasa uygunluğu, kasa kapısı, sadakat sayacının kasası, p |

İsteğe bağlı gelecek alanları (bugün gerekmiyor, model desteklemiyor):
- `"direct": false` → etkinlik / ödül aracı satılmasın;
- `"starter": true` → başlangıç aracı veriden (bugün `VehicleOwnership.starting_vehicle_id`).

### 16.2 Kod değiştirmek gerekiyor mu?

**Hayır.** Fiyat, seviye, sadakat, kasa uygunluğu ve garaj değeri metadata'dan türetiliyor.
- `scalability_test.py` kimlik taraması: `acquisition_model.py` ve politika dosyasında **hiçbir araç kimliği yok**.
- Yeni araç eklemenin **ekonomi tarafı** yalnızca veri. Asset tarafı (GLB, parça haritası) her zaman olduğu gibi araç başına iş (§16.8).

### 16.3 Örnek: "Yeni bir B sınıfı, Rare, spor araç"

Yalnızca metadata: `class B · rare · price 70.000 · min_level 17 · category sport` ve SPOR havuzuna eklenir. Sistem otomatik üretir:

| Çıktı | Değer | Nasıl |
|---|---|---|
| Doğrudan fiyat | **105.000 ₺** | 70.000 × 1,5 |
| Açılış seviyesi | **20** | max(17, SPOR kapısı 14) + 3 |
| Kasa uygunluğu | SPOR, **p %25,2** | ağırlık 40 / havuz toplamı |
| Sadakat | yok | Rare → 0 |
| Garaj değeri | +70.000 | base_value |
| Mevcut 16 araç | fiyat / seviye / garaj değeri **aynı** | — |
| Yan etki | E46 sadakati **60 → 81**; SPOR oranları Leon %84,0 → %62,9, Civic %12,6 → %9,4, E46 %3,4 → %2,5 | havuz büyüdü (R6, R7) |

### 16.4 Örnek: "Yeni bir Legendary A sınıfı araç"

Yalnızca metadata: `class A · legendary · price 130.000 · min_level 26 · category sedan`, PRESTİJ havuzuna.

| Çıktı | Değer | Nasıl |
|---|---|---|
| Doğrudan fiyat | **1.560.000 ₺** | 130.000 × 12 |
| Açılış seviyesi | **38** | max(26, 20) + 12 |
| Kasa uygunluğu | PRESTİJ, **p %2,70** | 4 / havuz |
| Sadakat | **75 PRESTİJ kasası** | max(60, ⌈ln 0,13 / ln(1 − 0,027)⌉) |
| Garaj değeri | +130.000 | — |
| Mevcut araçlar | fiyat / seviye / garaj değeri aynı; E60 sadakati 73 → 75 | PRESTİJ havuzu büyüdü |

Hiçbir kasaya konmazsa doğrulayıcı ERROR verir (§6.4).

### 16.5 Cevaplar

- **Yeni araç için hangi metadata gerekiyor?** `price`, `rarity`, `class`, `min_level`, `category` (cars.json) ve bir kasa havuzu (crates.json; Epic/Legendary için zorunlu, Common/Rare için isteğe bağlı).
- **Kod değiştirmek gerekiyor mu?** Ekonomi için **hayır**.
- **Fiyat nasıl hesaplanıyor?** `yuvarla(price × nadirlik çarpanı × sınıf çarpanı × kategori çarpanı × genel ayar, 1.000)` (§5.1).
- **Açılış seviyesi nasıl hesaplanıyor?** `max(min_level, kasa kapısı) + nadirlik farkı`, 1–99 arası (§6.1).
- **Sadakat nasıl hesaplanıyor?** `max(nadirlik alt sınırı, ⌈ln(1 − kuyruk) / ln(1 − p)⌉)`; aracın kendi kasalarından açılan kasa sayısıyla karşılaştırılır; bir kez karşılanınca kalıcı (§6.2, §13.4).
- **100 araçta çalışıyor mu?** Evet.
  - Mekanik: 24 sentetik katalog × 3 tohum, 91.544 kontrol, 0 hata.
  - Ekonomi: 100.000 oyuncuda Legendary %100 kasadan, gem harcaması %110, koleksiyon ACTIVE %79.
  - ₺ büyük katalogda ana yol olur; kollar §16.6.
- **200 araçta performans?**

  | | 16 araç | 200 araç |
  |---|---|---|
  | Tüm katalog türetme | 0,03 ms | 0,34 ms |
  | Doğrulama | — | 0,05 ms |
  | 30 günlük HEAVY oyuncu simülasyonu | 0,21 ms | 1,0 ms |
  | 100.000 oyuncu, tek çekirdek | ~21 sn | ~100 sn |

  12 çekirdekte 3 katalog × 2 mod × 4 profil × 100.000 oyuncu 2 dk 47 sn. Oyunda türetme bir kez (katalog yüklenince) yapılır; 200 araçta milisaniyenin altında.
- **Yeni nadirlik ya da kategori eklenirse hangi config değişiyor?**
  - **Kategori:** hiçbir şey. İstenirse `direct_purchase.json` → `category_modifier` satırı.
  - **Sınıf:** hiçbir şey. İstenirse `class_modifier` satırı.
  - **Nadirlik:** üç satır.
    1. `crates.json` `rarities` (ağırlık / etiket / renk; kasa sistemi verisi).
    2. `direct_purchase.json` `rarity` satırı. Doğrulayıcı sırayı denetler: daha nadir olanın değerleri daha düşük olamaz. Testte `mythic` için kuyruk eksik satır yakalandı.
    3. Kasa sisteminde nadirliğe göre sabit tablolar: `crate_manager.gd` `DISCOVERY_GEMS` / `DUP_SCRAP`, `crate_catalog.gd` `RARITY_ORDER`, kart çerçevesi ve parıltı (`collection_screen.gd`, `crate_panel.gd`, `crate_delivery.gd`). Bunlar bilinmeyen nadirlikte varsayılana düşer (0 gem, gri, ince çerçeve); kasa sistemine ait, ilk yeni nadirlikten önce `rarities` tablosuna taşınmalı (§16.7).

### 16.6 Ölçek dengesi: izlenecekler ve ayar kolları

Gem geliri sabitken katalog büyürse yeni araçların kasa payı düşer (16 araç %82 → 100 araç %38). Bu kabul edilebilir: Car Town'da da çoğu araç altınla alınır. Ama her katalog büyümesinde `acquisition_sim.py` koşulmalı.

**Sağlık eşikleri** (ACTIVE, 30. gün, aynı katalog, yalnızca kasaya göre):
1. Legendary kasa payı = %100.
2. Gem harcaması ≥ %90.
3. Gerçek katalogda tam koleksiyon ≤ %30.
4. Dekor harcaması yalnızca kasa senaryosunun ≥ %80'i.

| Kol (politika alanı) | 100 araç, ACTIVE: koleksiyon / kasa payı / dekor / bakiye | Etkisi |
|---|---|---|
| varsayılan | %79 / %38 / 1,73 M / 344 k | — |
| **`level_offset` C+4 / R+7 / E+10** | %72 / %45 / **1,76 M** / 1,86 M | **Önerilen ilk kol:** doğrudan yolu geciktirir, dekoru korur |
| `tuning_multiplier` ×2 | %74 / %46 / **28 k** / 186 k | ₺'yi dekordan araca kaydırır; garaj değeri 6,8 M → 4,7 M. Önerilmez |
| `tuning_multiplier` ×3 | %68 / %53 / **0** / 199 k | aynı sorun, daha sert |
| `loyalty_tail` / `loyalty_crates` | — | yalnızca Epic/Legendary'yi etkiler; Common/Rare dengesi için kullanılmaz |

Kollar kodsuz, `direct_purchase.json`'dan ayarlanır. Gem tarafı (kasa başına gem, gem geliri) kasa sisteminindir ve bu görevde değişmez.

### 16.7 Ölçek için bulunan mevcut kod sınırları (değiştirilmedi, kayıt için)

| Yer | Sınır | Ne zaman gerekir |
|---|---|---|
| `gameplay/crate_manager.gd` `COLLECTION_MILESTONES = {5,10,14,16}` | 16 araca sabit | **17. araçtan önce.** Oransal eşik 16'da aynı sonucu verir |
| `crate_manager.gd` `DISCOVERY_GEMS`, `DUP_SCRAP`; `crate_catalog.gd` `RARITY_ORDER`; kart / parıltı `match` | nadirlik listesi kodda | ilk yeni nadirlikten önce, `crates.json` `rarities`'e |
| `tools/rebuild_cars.sh` | `renault_toros` için özel optimize oranı | araç başına `optimize_args` alanı istenirse (asset hattı, ekonomi değil) |
| `vehicles/car_part_map.gd` `MAPS` | araç başına elle parça haritası | doğası gereği araç başına veri (asset) |
| `vehicles/car_catalog.gd` `_normalize` beyaz listesi | yeni `cars.json` alanı sessizce düşer | yalnızca yeni alan eklenirse (bu tasarım yeni alan istemiyor) |

### 16.8 NEW VEHICLE ADDITION CHECKLIST

| # | Adım | Nerede / araç | Ekonomi için mi? |
|---|---|---|---|
| 1 | **GLB** | `assets/cars/source/<id>.glb` (ham, `.gdignore`) | hayır |
| 2 | **Optimize sahne** | `tools/optimize_car.gd` → `assets/cars/optimized/<id>.glb`; `tools/make_car_scene.gd <id>` → sarmalayıcı `.tscn` (araç üretir, elle düzenlenmez); `tools/make_paint_mask.gd --car <id>` → boya maskesi | hayır |
| 3 | **Katalog metadata** | `vehicles/cars.json`: `id, brand, model, display_name, year, condition, scene_path, source_path, optimized_path, world_node, default_color, available_colors, plate_color, traffic, min_garage_rank` | kısmen |
| 4 | **Parça haritası** | `vehicles/car_part_map.gd` `MAPS[<scene_path>]`: roller, `wheel_groups`, gerekirse `extract` / `split_z` | hayır |
| 5 | **Boyut / ölçek** | `cars.json` `real_dimensions` + `model_scale`; `tools/vehicle_geometry_audit.gd <id>` (zemin / pivot / çamurluk) | hayır |
| 6 | **Yarış değerleri** | `cars.json` `race: {top_speed, acceleration, reaction, grip}` | hayır |
| 7 | **Kasa havuzu** | `vehicles/crates.json` → uygun kasanın `pool`'u (ya da yeni kasa); gerekirse `sets`. **Epic/Legendary için zorunlu.** Not: havuzdaki diğer araçların oranı düşer, o kasadaki Legendary'nin sadakati otomatik artar | **evet** |
| 8 | **Nadirlik** | `cars.json` `rarity` (politikada satırı olan bir nadirlik) | **evet** |
| 9 | **İlerleme metadata** | `cars.json` `price` (= katalog / garaj değeri), `class`, `min_level`, `category` | **evet** |
| ✔ | **Doğrulama** | `python3 tools/economy/scalability_test.py` (+ uygulamadan sonra `DirectPurchaseCatalog.validate()`); büyük eklemede `acquisition_sim.py --catalogs 16` ile §16.6 eşikleri | evet |

> **Ekonomi için manuel fiyat yazmak GEREKMİYOR.** Doğrudan fiyat, açılış seviyesi, kasa sadakati ve garaj değeri 7–9. adımlardaki metadata'dan otomatik türetilir. Araç başına ₺ fiyatı, seviye ya da sadakat yazılan bir yer yoktur ve olmamalıdır. Tek "fiyat" alanı `cars.json` `price`; bu da aracın katalog / garaj değeridir. Doğrudan fiyatı genel kural üretir.

---

## Sonuç — net cevaplar

- **Mevcut kasa sistemi korunuyor mu?** **Evet.** RNG, oranlar, kopya, yıldız, hurda, koleksiyon, satın alma anında kilit, fiziksel kasa, kuyruk, kayıt değişmiyor. `crates.json` ve `cars.json`'a yeni alan yok. Kasa tarafına yalnızca açılış sayacı ekleniyor.
- **Doğrudan satın alma kasayı gereksiz kılıyor mu?** **Hayır.**
  - 16 araçta yeni araçların %82'si kasadan.
  - Her katalogda gem harcaması yalnızca kasa senaryosunun %91–110'u.
  - Legendary'ler 30 günde %100 kasadan.
  - Büyük katalogda Common/Rare çoğunlukla ₺ ile alınıyor (Car Town DNA).
- **16 aracın ₺ fiyatları** (formülün ürettiği, kodda araca bağlı değil):
  - Getz 35.000 · Accent 38.000 · Era 45.000 · Toros 60.000 · Passat 50.000
  - Focus 68.000 · Fluence 60.000 · **Kamiq 83.000** (82.000 değil, yuvarlama)
  - Leon 68.000 · A3 95.000 · Golf 7 195.000 · Civic 216.000 · S60 158.000
  - **E46 1.020.000 · E60 1.440.000**
- **Seviyeler (değişmedi):**
  - sv 8 Getz / Accent · sv 9 Era / Toros · sv 12 Passat · sv 13 Focus
  - sv 15 Fluence / Kamiq · sv 16 Leon · sv 20 A3 · sv 21 Golf · sv 24 Civic · sv 25 S60
  - sv 26 E46 (60 SPOR) · sv 37 **E60 (73 PRESTİJ)**
- **30 günlük aktif oyuncuda 16/16:** **%26,1** (yalnızca kasa %14,7).
- **E60 sahipliği:** **%28,8** (yalnızca kasa %20,2), tamamı kasadan.
- **10 saatte ₺ bakiyesi:** **20.314 ₺** (yalnızca kasa 138.156; revizyon 1'deki 181.266 düzeltildi), 13 araç.
- **Gelecek araçlar:** yeni araç yalnızca metadata ile eklenir; ekonomi kodu ve manuel fiyat gerekmez. 100 ve 200 araçta sistem çalışıyor; performans sorunu yok. Katalog 16'yı aşmadan koleksiyon gem eşikleri oransal yapılmalı (kasa sistemi kararı).
