# ARAÇ KOLEKSİYONU / KASA SİSTEMİ — Tasarım

> **Not (2026-09-29):** Bu v1 belgesinin tekrar koruması, ₺ fiyatlama ve E46 başlangıç kararları [vehicle_crate_design_v2.md](vehicle_crate_design_v2.md) ile **değiştirildi**. Güncel tasarım v2dir.

Tarih: 2026-09-29 · Durum: **TASARIM, kod yazılmadı** · Araştırma:
[vehicle_crate_research.md](vehicle_crate_research.md)

Hesaplar iki kaynaktan geliyor:
- Oyunun gerçek sabitleri: `vehicles/cars.json`, `player_progress.gd`, `quest_catalog.gd`,
  `race_manager.gd`, `garage_value.gd`.
- Ölçülmüş ilerleme simülasyonu: [AUDIT_2026_09.md](AUDIT_2026_09.md) §6 ve
  [PROGRESSION_REFACTOR.md](PROGRESSION_REFACTOR.md) §9.

Kasa olasılıkları Monte Carlo ile hesaplandı: 20.000–50.000 tekrar, Python. Betikler repoda
değil, oturum geçici klasöründe.

> **Kısa sonuç:** Önerilen biçimiyle (gemle alınan, tekrar koruması olmayan, seviye filtresi
> olmayan kasa) sistem ilerlemeyi **bozar**. Sayılar §6, §13 ve §15'te. Bu belgedeki son öneri
> (§19) ilerlemeyi **korur**: toplam maliyet ≤ bugünkü fiyatlar, seviye kilidi korunur, en kötü
> durum sınırlı. Değişen tek şey, aynı kademe içindeki araçların **hangi sırayla** geldiği.

---

## 1. Mevcut araç sistemi

### 1.1 16 araç (`vehicles/cars.json`)

Rütbe = `min_garage_rank`. Yarış statları: hız / ivme / tepki / yol tutuş.

| # | id | Ad | Sınıf | Fiyat ₺ | Seviye | Rütbe | Garaj değeri katkısı | Yarış (hız/ivme/tepki/tutuş) | Bugünkü açılma koşulu |
|---|---|---|---|---|---|---|---|---|---|
| 1 | `bmw_e46` | BMW E46 | A | 85.000 | 12 | 3 | 85.000 | 145 / 84 / 78 / 80 | **Ücretsiz başlangıç aracı**. Kilitleri hiç uygulanmaz |
| 2 | `tofas_sahin` | Tofaş Şahin | D | 15.000 | 1 | 1 | 15.000 | 105 / 52 / 48 / 45 | Sv 1, 15.000 ₺ |
| 3 | `renault_toros` | Renault Toros | D | 20.000 | 3 | 1 | 20.000 | 100 / 56 / 50 / 47 | Sv 3 (bildirim var) |
| 4 | `hyundai_era` | Hyundai Era | C | 30.000 | 6 | 1 | 30.000 | 118 / 64 / 58 / 60 | Sv 6 (bildirim var) |
| 5 | `hyundai_getz` | Hyundai Getz | C | 35.000 | 8 | 2 | 35.000 | 112 / 70 / 62 / 64 | Sv 8 + rütbe 2 |
| 6 | `hyundai_accent_blue` | Hyundai Accent Blue | C | 38.000 | 8 | 2 | 38.000 | 120 / 68 / 62 / 64 | Sv 8 + rütbe 2 (bildirim yok) |
| 7 | `ford_focus` | Ford Focus | C | 45.000 | 10 | 2 | 45.000 | 125 / 72 / 66 / 68 | Sv 10 + rütbe 2 |
| 8 | `vw_passat_b55` | VW Passat B5.5 | B | 50.000 | 12 | 3 | 50.000 | 135 / 72 / 66 / 70 | Sv 12 + rütbe 3 |
| 9 | `skoda_kamiq` | Skoda Kamiq | B | 55.000 | 12 | 3 | 55.000 | 131 / 76 / 70 / 74 | Sv 12 + rütbe 3 |
| 10 | `renault_fluence` | Renault Fluence | B | 60.000 | 15 | 4 | 60.000 | 128 / 78 / 72 / 74 | Sv 15 + rütbe 4 |
| 11 | `vw_golf_7` | VW Golf 7 | B | 65.000 | 15 | 4 | 65.000 | 134 / 80 / 74 / 76 | Sv 15 + rütbe 4 |
| 12 | `seat_leon` | Seat Leon | B | 68.000 | 16 | 4 | 68.000 | 138 / 82 / 74 / 78 | Sv 16 + rütbe 4 |
| 13 | `honda_civic` | Honda Civic VTEC | B | 72.000 | 18 | 4 | 72.000 | 140 / 83 / 76 / 78 | Sv 18 + rütbe 4 |
| 14 | `audi_a3` | Audi A3 | A | 95.000 | 20 | 5 | 95.000 | 148 / 86 / 80 / 82 | Sv 20 + rütbe 5 |
| 15 | `volvo_s60` | Volvo S60 | A | 105.000 | 22 | 5 | 105.000 | 150 / 85 / 78 / 84 | Sv 22 + rütbe 5 |
| 16 | `bmw_e60` | BMW E60 | A | 120.000 | 25 | 6 | 120.000 | 155 / 88 / 80 / 82 | Sv 25 + rütbe 6 |

- Sınıf dağılımı: D 2 · C 4 · B 6 · A 4.
- Satın alınabilir araç sayısı (E46 hariç) 15, toplam fiyatları **873.000 ₺**.
- **Kadroda süper araç, muscle ya da klasik spor araç yok.** Hepsi Türkiye sokaklarından
  gündelik araçlar. Önerideki "SUPER / MUSCLE / LEGENDARY" kasa adlarının dolduracak aracı yok.
  Kasalar mevcut kadroya göre adlandırılmalı (§4).

### 1.2 Doğrudan satın alma — hangi dosyalar

| Dosya | Rol |
|---|---|
| `gameplay/vehicle_ownership.gd` | **Tek merkez.** `purchase_vehicle()`, `status()`, `Status` enum'u (OWNED / PURCHASABLE / TOO_EXPENSIVE / LOCKED_LEVEL / LOCKED_RANK), `add_vehicle()`, `sell_vehicle()` (%40), kayıt `load_state()` |
| `ui/hud/showroom_screen.gd` | Showroom ekranı. Satır 857–879: durum plakası + SATIN AL → `purchase_vehicle` |
| `shop_hitbox.gd` | Haritadaki showroom binasına dokunma → ekranı açar |
| `ui/hud/car_gallery.gd` | `Mode.SHOP` (satır 240, **artık hiçbir yere bağlı değil**) + `Mode.OWNED` (garaj listesi) |
| `gameplay/progression_effects.gd` | Kilit yazıları: "SEVİYE n GEREKLİ", "₺ DAHA GEREKLİ" |
| `ui/hud/hud.gd` | `_on_vehicle_purchased` → "… GARAJINDA" bildirimi (satır 713, 847) |
| `vehicles/car_catalog.gd` + `cars.json` | `price`, `class`, `min_level`, `min_garage_rank` |
| `gameplay/garage_value.gd` | `vehicles_value()` sahip olunan araçların katalog fiyatını toplar. Rütbe kilidi buradan |
| `gameplay/player_progress.gd` | `LEVEL_REWARDS` metinleri ("TOROS SHOWROOM'DA" …). 9 yeni araç için metin yok |
| `gameplay/quest_catalog.gd` | `OWN_VEHICLES` görevleri (2 ve 4 araç) |
| `gameplay/save_manager.gd` | v9, `"vehicles": {"owned": [...]}` |
| `qa/sim_progress.gd` | Otomatik oyuncu, satır 108 `purchase_vehicle` |

### 1.3 Para birimleri

- **₺ (EconomyManager):** tamir, yarış, seviye ödülü, görev ve ustalık ile kazanılır. Araç,
  garaj, alan, hız, standart boya ve dekor ile harcanır.
- **Gem (PlayerProgress):** başlangıçta 40. Tek kaynak 7 tek seferlik görev (10+15+10+15+20+25+30
  = 125). **Tekrarlayan hiçbir gem kaynağı yok**; gerçek parayla satış da yok. Tek harcama yeri
  özel boya (15–25 gem). **Oyuncunun ömür boyu kazanabileceği gem: 165.**

### 1.4 İlerleme eksenleri

| Eksen | Bugün |
|---|---|
| Oyuncu seviyesi | Araçları açar (`min_level`). XP her seviyede ×1,25 |
| Garaj değeri | Türetilmiş, 10 rütbe (0 … 700k). Araç fiyatları değerin büyük kısmı |
| Yarış | Ödül rakibin sınıfına göre: D 450 · C 700 · B 1.000 · A 1.400 ₺. Rakip = oyuncunun aracının sınıfı veya bir üstü |

### 1.5 Ölçülmüş tempo

Kaynak: AUDIT §6, doğrudan satın almayla otomatik oyuncu.

| Dakika | Seviye | Araç | Kümülatif kazanç (≈) |
|---|---|---|---|
| 10 | 3 | 1 | 12k |
| 60 | 11 | 3 | 103k |
| 120 | 16 | 7 | 291k |
| 300 | 22 | 15 | 959k |
| 600 | 25 | 16 | 2,1M |

İlk satın alınan araç (Şahin) 40,7. dakikada geliyor. 16 aracın tamamı yaklaşık 5. saatte bitiyor.

### 1.6 Kasa tasarımını etkileyen iki bulgu

1. **Yarış aracı hep `owned[0]`.** `RaceManager.player_vehicle_id()` "garajda seçili araç"
   demesine rağmen her zaman sahip olunan ilk aracı döndürür, yani E46'yı. Oyuncu ilk dakikadan
   **A sınıfıyla** yarışıyor ve D→C→B→A yarış ilerlemesi bugün fiilen yok. Kasanın yarışı bozma
   riski §12'de bu gerçeğe göre değerlendirildi.
2. **İçerik 5. saatte bitiyor.** Kasa sistemi araç sayısını artırmaz. Tek başına oyun süresini
   uzatmaz, yalnızca 16 aracın **nasıl** geldiğini değiştirir.

## 2. Araştırma — tasarıma giren bulgular

Ayrıntı ve URL'ler: [vehicle_crate_research.md](vehicle_crate_research.md).

- **Car Town'da kasa vardı** (Mystery Box: Bronze 5 BP … Ferrari 100 BP, ücretli yeniden
  çevirme, seviye kısıtı yok). Ama doğrudan satın almanın **yanındaydı** ve yalnızca premium
  parayla alınıyordu.
- **Car Town'da 4 araçlık temalı koleksiyon setleri vardı.** Tamamlanınca altın + XP.
- Başarılı sistemler rastgeleliği **sınırlıyor**: Hearthstone tekrar koruması + 40/10 pity,
  Marvel Snap tekrarsız paket, Forza kategori koruması, Clash Royale sabit dizi.
- Brawl Stars rastgeleliği tamamen kaldırınca gelir düştü ve heyecan kayboldu; rastgele ödülü
  geri getirdi. Tamamen deterministik olmak da hedef değil.
- Olasılık açıklaması Google Play ve App Store'da zorunlu. Japonya "set tamamlama gacha"sını
  yasakladı. Belçika ücretli loot box'ı kumar sayıyor.

## 3. Kasa sistemi önerisi — analiz

Akış: araç satın alma → kasa satın alma → kasa açma → araç koleksiyona eklenir.

### 3.1 Avantajlar (gerçekçi değerlendirme)

| Avantaj | Bizim oyunda gerçekleşir mi? |
|---|---|
| Koleksiyon hissi | **Evet.** Bugün showroom 16 aracın hepsini baştan gösteriyor; keşfedilecek bir şey yok |
| Kasa temaları | **Kısmen.** 16 gündelik araçla 3–4 kasa mantıklı; 5 temalı kasa için araç yok |
| Nadirlik | **Evet**, ama nadirlik yalnızca sıralamayı etkilerse adil kalır (§8) |
| Koleksiyon tamamlama | **Evet.** "8 / 16" hedefi bugün hiç gösterilmiyor |
| Tekrar açma motivasyonu | **Sınırlı.** 15 araç biter; sonrası için setler (§16) ve yeni araçlar gerekir |

### 3.2 Riskler (ölçülü)

| Risk | Şiddet | Kanıt |
|---|---|---|
| İstenen araca ulaşamama | **Yüksek** (korumasız) | Naif kasada E60'ı %50 olasılıkla görmek için **138 kasa** gerekiyor (§8) |
| Tekrar sorunu | **Çok yüksek** (korumasız) | 20 kasada 11,4 tekrar, tamamlamak için ortalama 327 kasa (§8) |
| İlerlemenin rastgeleleşmesi | **Yüksek** (filtresiz) | Seviye filtresi yoksa 1. seviyede E60 çıkabilir (%0,5) |
| Gem ekonomisinin bozulması | **Kesin** | Ömür boyu 165 gem ile 75 gemlik kasadan en fazla 2 tane (§15) |
| Pay-to-win hissi | Bugün düşük, gem satışı gelirse yüksek | Gerçek parayla gem satışı yok; eklenirse ücretli loot box olur |
| Seviye ilerlemesinin bozulması | Filtreye bağlı | §13 |

Her riskin çözümü bir kurala bağlanabiliyor: tekrar koruması, seviye filtresi, ₺ fiyatı,
olasılık açıklaması. Bu yüzden öneri reddedilmiyor, **kısıtlanıyor**.

## 4. Kasa kategorileri

Kadroda süper/muscle araç olmadığı için kasalar **ilerleme kademesine** göre kuruldu. Her kademe
oyunun D→C→B→A sınıf sırasıyla örtüşüyor. **Tema** koleksiyon setlerine bırakıldı (§16): setler
kasaları keser, marka ve dönem üzerinden kurulur. Car Town'da da kutular fiyat kademesi, setler
tema idi.

| Kasa | Tema / ton | Havuz (araç) | Sınıf | Nadirlik | Açılır |
|---|---|---|---|---|---|
| **ŞEHİR KASASI** | ilk arabalar, yerli klasikler, şehir araçları | Şahin, Toros, Era, Getz, Accent Blue, Focus (6) | D, C | Common, Uncommon | Sv 1 |
| **AİLE KASASI** | aile sedanları ve kompaktlar | Passat B5.5, Kamiq, Fluence, Golf 7 (4) | B | Uncommon, Rare | Sv 10 |
| **SPOR KASASI** | sıcak kompaktlar | Leon, Civic VTEC, A3 (3) | B, A | Rare, Epic | Sv 14 |
| **PRESTİJ KASASI** | premium sedanlar | S60, E60 (2) | A | Epic, Legendary | Sv 20 + rütbe 5 |

- Havuzlar **ayrık**: her araç tek bir kasada. Kasalar arası fiyat farkından yararlanma
  (arbitraj) olmaz ve "bu kasa bitti" net olur.
- **E46 hiçbir kasada yok.** Başlangıç aracıdır, koleksiyonda baştan sahip sayılır (1/16).
- 5. kasa (LEGENDARY) önerilmiyor: kadroda tek bir Legendary araç var. Tek araçlık kasa,
  rastgelelik değil gizli bir satın alma olur.

## 5. Fiyatlar

### 5.1 Para birimi: gem değil ₺

Karar sayılara dayanıyor (§15):
- Ömür boyu gem geliri **165**. Önerilen 75–300 gem fiyatlarla oyuncu hayatı boyunca **1–2 kasa**
  açabilir; bugün ise 5 saatte 15 araç alıyor.
- ₺ tarafında ölçülmüş bir **harcanamayan para** sorunu var (AUDIT §6: 10. saatte 1,1M ₺ ölü
  para). Dekor kısmen çözdü (74 eşya, 1,76M ₺). Araç kasası ₺ ile satılınca araç harcaması aynı
  kalır; ekonomi dengesi korunur.

### 5.2 Fiyat kuralı: "kasanın fiyatı = içindeki en ucuz yeni aracın fiyatı"

Üç model simüle edildi (tam havuz, tekrar koruması, 40.000 tekrar):

| Model | Kural | Toplam ödenen / katalog | Zararlı açılış (oyuncu başına) | İlk ŞEHİR açılışı |
|---|---|---|---|---|
| **Sabit** | kasa başına havuz ortalaması (30.500 / 57.500 / 78.333 / 112.500) | 1,00 | 8,0 | 30.500 ₺ |
| **Sıra fiyatı** | k. açılış = havuzdaki k. en ucuz fiyat | 1,00 | 5,2 | 15.000 ₺ |
| **En ucuz yeni araç** (öneri) | fiyat = havuzda kalan uygun araçların en ucuzu | **0,90** | **0,0** | 15.000 ₺ |

"Zararlı açılış" = gelen aracın katalog değeri ödenen fiyattan düşük.

Neden son model:
- **Hiçbir açılış zarar ettirmez.** Gelen araç her zaman ödenen fiyat kadar ya da daha değerli.
  Oyuncuya tek cümleyle anlatılabilir ve manipülatif değildir.
- İlk araç yine **15.000 ₺**. Bugün Şahin'in geldiği 41. dakika korunur. Sabit model ilk aracı
  30.500 ₺'ye iterdi.
- Toplamda %10 ucuz (873k yerine ortalama 785k). Farkın çoğu erken kasada: ŞEHİR oranı 0,72.
  AUDIT'in "ilk satın alma geç geliyor" sorununa küçük bir katkı sağlar.
- Kasa ekranında fiyatın yanında "EN AZ ŞU DEĞERDE ARAÇ" yazar.

Kasa bazında beklenen toplam maliyet:

| Kasa | Katalog toplamı | Ortalama ödenen | En kötü durum |
|---|---|---|---|
| ŞEHİR | 183.000 | 131.800 | 183.000 |
| AİLE | 230.000 | 214.232 | 230.000 |
| SPOR | 235.000 | 218.989 | 235.000 |
| PRESTİJ | 225.000 | 220.013 | 225.000 |
| **Toplam** | **873.000** | **785.034** | **873.000** |

En kötü durumda bile bugünkü doğrudan satın alma fiyatları aşılmaz.

## 6. Araç havuzları ve uygunluk

Bir araç, bir kasadan ancak şu dört koşul birlikte sağlanıyorsa çıkabilir:

1. o kasanın havuzunda,
2. **keşfedilmemiş** (hiç sahip olunmamış, §9),
3. `oyuncu seviyesi ≥ min_level − 2` ("2 seviye önden bakış"),
4. `garaj rütbesi ≥ min_garage_rank` (bugünkü kural aynen).

Kasa, en az bir uygun araç varsa satılır. Yoksa kasa üstünde ne zaman açılacağı yazar ("SEVİYE
12'DE 2 YENİ ARAÇ" gibi).

"−2" gerekçesi: Car Town kutusu seviye kilidini tamamen kaldırıyordu. Biz kilidi koruyup küçük
bir sürpriz payı bırakıyoruz. Oyuncu bir aracı en fazla **2 seviye erken** alabilir. 8.
seviyedeki oyuncunun alabileceği en üst araç Focus'tur (Sv 10, C sınıfı). E60 için en az Sv 23
gerekir.

Kasaların fiilen açıldığı zaman (AUDIT seviye eğrisiyle):

| Kasa | İlk uygun araç | Sv | ≈ dakika |
|---|---|---|---|
| ŞEHİR | Şahin, Toros | 1 | 0 |
| AİLE | Passat, Kamiq (Sv 12 − 2) | 10 | 54 |
| SPOR | Leon (Sv 16 − 2) | 14 | 96 |
| PRESTİJ | S60 (Sv 22 − 2) + rütbe 5 | 20 | 240 |

## 7. Nadirlik

Nadirlik ≠ sınıf. **Sınıf** performans ve yarış kademesidir. **Nadirlik** koleksiyondaki
değer/istenirliktir ve kasadaki çıkış ağırlığını belirler. Nadirliği belirleyen dört şey:
seviye, fiyat, yarış statı ve "ikonluk".

| Araç | Sınıf | Nadirlik | Gerekçe |
|---|---|---|---|
| Tofaş Şahin | D | COMMON | En ucuz, Sv 1, en zayıf stat. Yerli ikon ama koleksiyonun giriş aracı |
| Renault Toros | D | COMMON | Sv 3, D sınıfı, Şahin'in eşi |
| Hyundai Era | C | COMMON | C sınıfının en ucuzu (30k, Sv 6) |
| Hyundai Getz | C | UNCOMMON | Sv 8, rütbe 2 ister |
| Hyundai Accent Blue | C | UNCOMMON | Sv 8, rütbe 2 |
| Ford Focus | C | UNCOMMON | C'nin tepesi (45k, Sv 10) |
| VW Passat B5.5 | **B** | **UNCOMMON** | **Sınıf ≠ nadirlik örneği:** B sınıfı ama B'nin en ucuzu ve en eskisi (2004, 50k) |
| Skoda Kamiq | B | RARE | Sv 12, B'nin tek SUV'si |
| Renault Fluence | B | RARE | Sv 15, rütbe 4 |
| VW Golf 7 | B | RARE | Sv 15, rütbe 4 |
| Seat Leon | B | RARE | Sv 16. Spor kasasının "tabanı" |
| Honda Civic VTEC | **B** | **EPIC** | **Sınıf ≠ nadirlik örneği:** B sınıfı ama Sv 18 ve ikon (VTEC). B'nin en güçlü statı |
| Audi A3 | A | EPIC | Sv 20, rütbe 5, A sınıfı |
| Volvo S60 | A | EPIC | Sv 22, rütbe 5 |
| **BMW E60** | A | **LEGENDARY** | Tek Legendary. En pahalı (120k), en yüksek seviye (25), en iyi hız/ivme |
| BMW E46 | A | (EPIC, kasa dışı) | **Sınıf ≠ edinme örneği:** A sınıfı ama ücretsiz başlangıç aracı |

Dağılım: C 3 · U 4 · R 4 · E 3 (+E46) · L 1. Her kasa iki bitişik nadirliği kapsar, böylece
nadirlik her kasada gerçekten bir şey ifade eder.

## 8. Drop oranları

### 8.1 Önerilen örnek oranlar (50/30/15/4/1) neden kabul edilmedi

Tek havuz, 15 araç, **tekrar koruması yok**, seviye filtresi yok (Monte Carlo, 20.000 tekrar):

| Açılan kasa | Ortalama yeni araç | Ortalama tekrar |
|---|---|---|
| 1 | 1,00 | 0,00 |
| 5 | 3,96 | 1,04 |
| 10 | 6,22 | 3,78 |
| 20 | 8,58 | 11,42 |
| 50 | 11,31 | 38,69 |
| 100 | 12,92 | 87,08 |

- 15 aracı tamamlamak: ortalama **327 kasa**, medyan 270, en kötü %10'luk dilimde 598.
- Tek bir kasada E60 olasılığı %0,5. %50 olasılıkla görmek için **138 kasa** gerekir.
- 5 kasalık pity ile bile ortalama 50 kasa: doğrudan satın almanın 3,3 katı.

Bu oranlar 1.000+ araçlık oyunlar için yazılmış; 15 araçta tekrar fabrikasıdır.

### 8.2 Önerilen ağırlıklar

Uygun ve keşfedilmemiş araçlar arasında ağırlıklı seçim yapılır:
**COMMON 10 · UNCOMMON 6 · RARE 4 · EPIC 2 · LEGENDARY 1**.

Havuz tam uygunken ve hiç araç yokken:

| Kasa | Olasılıklar |
|---|---|
| ŞEHİR | Şahin 20,8 % · Toros 20,8 % · Era 20,8 % · Getz 12,5 % · Accent 12,5 % · Focus 12,5 % |
| AİLE | Passat 33,3 % · Kamiq 22,2 % · Fluence 22,2 % · Golf 22,2 % |
| SPOR | Leon 50 % · Civic 25 % · A3 25 % |
| PRESTİJ | S60 66,7 % · E60 33,3 % |

Oranlar her açılışta değişir (keşfedilen araç havuzdan çıkar) ve **kasa ekranında o anki
değerlerle** gösterilir. Bu Google Play / App Store kuralıdır.

### 8.3 Beklenen koleksiyon ilerlemesi (öneriyle)

Tekrar koruması (§9) olduğu için **her kasa = 1 yeni araç**. Soru "kaç araç" olmaktan çıkar,
"hangi sırayla" olur.

| Açılan kasa | Yeni araç | Açıklama |
|---|---|---|
| 1 | 1 | Sv 1'de Şahin veya Toros (yarı yarıya): ödenen 15.000, gelen ort. 17.500 ₺. Tam havuzda (Sv 10+) gelen ort. 28.253 ₺ |
| 5 | 5 | Sv 10+ ise ŞEHİR'den 5 araç. %70,7 olasılıkla eksik kalan bir UNCOMMON |
| 10 | 10 | ŞEHİR tamam + AİLE'den 4 (Sv 15+) |
| 20 | 15 (tavan) | 15 açılışta kadro biter. 16–20. kasa **satılmaz** ("TAMAMLANDI") |

Nadirliğin etkisi sıralamadadır. ŞEHİR'de Common'lar ortalama 3,1., Uncommon'lar 3,9. sırada
gelir. PRESTİJ'de E60 üçte iki olasılıkla sonuncudur.

## 9. Tekrar sistemi

| Seçenek | Ekonomi | Oyuncu hissi | İlerleme | Uygulama |
|---|---|---|---|---|
| **A** Tekrar araç çıkar, garaj değeri artar | Garaj değeri şişer. Rütbeler anlamsızlaşır | "Aynı arabadan iki tane mi?" | Tekrarlar ilerleme sayılır, yanıltıcı | Sahiplik küme değil çoklu küme olur. Garaj 7 park yeri, kayıt, satış yeniden yazılır. **Pahalı** |
| **B** ₺ verir | Kasa fiyatını geri iade ederse nötr | "Paramı geri aldım", sıkıcı ama adil | Etkisiz | Kolay |
| **C** Gem parçası | Tek tekrarlayan gem kaynağı olur, boya fiyatlarını bozar | Olumlu | Etkisiz | Kolay ama ekonomi riski |
| **D** Blueprint | Yıldız/yükseltme ekonomisi gerekir, bizde yok | Asphalt gibi yavaş | Araç açmayı haftalara yayar | Pahalı, kapsam dışı |
| **E** Koleksiyon tokeni | Token ile istenen araç alınır ("spark") | İyi | Garantili | Orta. Ama koruma varsa gereksiz |
| **F** Tekrar koruması | Ekonomi değişmez. Maliyet = katalog | En iyisi: her kasa yeni | Deterministik sayı, rastgele sıra | Kolay. Havuzdan keşfedilenler çıkarılır |

**Öneri: F, B ile emniyetli.** Tekrar hiç üretilmez (Hearthstone Legendary kuralı, Marvel Snap
Snap Pack). Olağan dışı bir durumda tekrar oluşursa kasa bedeli ₺ olarak iade edilir. Olağan
dışı durum örnekleri: katalogdan araç çıkması, kayıt göçü.

**Kritik ayrıntı: koruma "keşfedilen" kümeye göre çalışmalı, "şu an sahip olunan" kümeye göre
değil.** Oyunda satış var (%40). Koruma "sahip olunan"a bakarsa bir istismar döngüsü doğar:
- 15.000 ₺'lik ŞEHİR kasasını aç, Focus çıkar (45.000 ₺).
- Sat, 18.000 ₺ al: +3.000 ₺ kâr.
- Focus tekrar havuza döner. Tekrar aç. Sonsuz para.

Keşfedilen kümeyle satılan araç bir daha kasadan çıkmaz. Showroom'dan katalog fiyatına geri
alınır (§14).

## 10. Garanti / pity

| Garanti türü | Korumasız kasada | Önerilen sistemde |
|---|---|---|
| "X kasada yeni araç" | Pity 5: tamamlama 327 → 50 kasa. Pity 3: 39 kasa | **Gereksiz**: her kasa yeni (pity = 1) |
| Nadirlik garantisi | E60 için 138 kasa sorunu | Gereksiz: E60 PRESTİJ'in 2 aracından biri, **en geç 2. açılışta** |
| Koleksiyon tamamlama garantisi | Yok | **Doğal**: kasa başına en fazla havuz boyu kadar açılış (6 / 4 / 3 / 2) |
| Tekrar koruması | — | Var (§9) |

Ekonomik etki:
- Korumasız + pity 5: oyuncu 15 araç için ~50 kasa öder. ₺ karşılığı katalogun 3,3 katı; 5.
  saatteki içerik ~16 saate yayılır. Bu, oynanış süresi değil **tekrar grindi** olur.
- Önerilen sistem: toplam en fazla katalog, ortalama %90'ı. İçerik süresi bugünküyle aynı kalır.

**En kötü durum her kasada ekranda yazar:** "BU KASADAKİ 6 ARACIN HEPSİ EN FAZLA 6 AÇILIŞTA".

## 11. Koleksiyon ekranı

- Başlık: **KOLEKSİYON 8 / 16** ve kasa bazında alt sayaçlar (ŞEHİR 4/6 …). Setler: §16.
- Izgara kasalara göre gruplanır. E46 "BAŞLANGIÇ" grubundadır.
- Kart durumları:

| Durum | Gösterilen | Gizlenen |
|---|---|---|
| **SAHİPSİN** | Tam kart: model, ad, sınıf, nadirlik, stat, garaj değeri | — |
| **KEŞFEDİLDİ** (satılmış) | Tam kart + "SHOWROOM'DAN GERİ AL — fiyat" | — |
| **?** (keşfedilmemiş, uygun) | Siluet, sınıf harfi, nadirlik rengi, hangi kasa | Ad, marka, stat, fiyat |
| **KİLİTLİ** (seviye/rütbe yetmiyor) | Koyu siluet, nadirlik rengi, "SEVİYE 18" | Ad, marka, stat, fiyat, **sınıf** |

Gerekçe: siluet + nadirlik + kasa, "orada ne var" merakını yaratır. Adı ve statı saklamak keşfi
korur.

Siluet: mevcut thumbnail üretimi aynı modeli düz koyu malzemeyle çizer. Yeni varlık gerekmez.

## 12. Garaj değeri

- Formül **değişmez**: sahip olunan araçların katalog fiyatı. Kasa ile gelen araç eklendiği
  anda değeri artar.
- Sahiplik bir kümedir ve koruma tekrar üretmez. **Tekrar değeri iki kez sayılmaz.** A
  seçeneğinin yol açacağı şişme hiç doğmaz.
- **Keşfedilen ama satılmış** araç değere **sayılmaz**. Değer "garajında olan" demektir, bugünkü
  anlamı korunur.
- Fark: "en ucuz yeni araç" fiyatlaması yüzünden değer, harcamanın ortalama %10 önünde gider.
  Tam koleksiyonda katalog 873k, ödenen ~785k. Rütbeler biraz erken gelir. Rütbe zaten "garajın
  ne kadar değerli" demek olduğu için tutarlıdır. Eşiklerin değişmesi gerekmez: 16 araçla 10.
  rütbe bugün de 5. saatte geliyor (AUDIT §6).
- Koleksiyon seti bonusu garaj değerine eklenebilir (§16). Bu, "gelecek içeriğe ayrılmış" 9–10.
  rütbelere anlamlı bir yol açar.

## 13. Oyuncu seviyesi

Soru: 10. seviyedeki oyuncu 25. seviye BMW E60'ı çıkarabilir mi?

| Alternatif | Sonuç |
|---|---|
| Filtre yok (Car Town kutusu gibi) | Çıkarabilir (%0,5/kasa). Seviye araç açmayı bırakır; `LEVEL_REWARDS` anlamsızlaşır. **Reddedildi** |
| Kasanın kendisi seviyeyle açılır, içerik filtresiz | PRESTİJ Sv 20'de açılır; içinde yalnızca S60/E60 var. Kabul edilebilir ama ŞEHİR'de Sv 1'de Focus (Sv 10) çıkar |
| **Araç başına filtre, −2 önden bakış** (öneri) | E60 en erken Sv 23. Sürpriz payı en fazla 2 seviye |
| Kesin filtre (−0) | Güvenli ama kasa "showroom'un rastgele sırası" olur, sürpriz sıfır |
| Havuza giriş seviyesi + ağırlık artışı (yeni açılan araç daha olası) | İlginç ama açıklaması zor. İleriye bırakıldı |

Seviye tempo bağı korunur: araçlar yine aynı seviyelerde "erişilebilir" olur. Değişen şey,
erişilebilir olanlardan hangisinin önce geldiği. `LEVEL_REWARDS` metinleri "X SHOWROOM'DA"
yerine "ŞEHİR KASASINA 2 YENİ ARAÇ" olur. Sessiz kalan 9 araç (Accent … E60) için de metin
eklenir.

## 14. Yarış ilerlemesi

Soru: 8. seviyede A sınıfı BMW E60 çıkması nasıl ele alınmalı?

- **Önerilen sistemde bu olamaz.** 8. seviyede alınabilecek en üst araç Focus'tur (C, Sv 10).
  E60 Sv 23'ten önce hiçbir kasada uygun değildir.
- **Gerçek durum (§1.6):** oyuncu zaten dakika 0'da A sınıfı E46 ile yarışıyor, çünkü yarış
  aracı `owned[0]`. Rakip havuzu A sınıfı, ödül hep 1.400 ₺/galibiyet. Kasa yarış dengesini
  bugünkünden kötü yapamaz. Bugünkü dengesizliğin kaynağı başlangıç aracıdır.
- Kasalar kademe sırasıyla açılır: ŞEHİR D/C → AİLE B → SPOR B/A → PRESTİJ A. Bu, yarış
  ilerlemesinin istediği D→C→B→A ile birebir aynı. Yarış aracı seçimi eklenirse kasa sırası
  yarış sınıfı sırasını doğal olarak besler.
- **Ayrı öneri (kasa kapsamı dışında):** yarışa seçili garaj aracı çıksın (`player_vehicle_id`
  yorumunun söylediği davranış). Rakip sınıfı ve ödül ona göre belirlensin. Bu, kasa yokken de
  gereken bir düzeltme.

Sınıf içi stat farkı küçük. E60 (155/88) ile E46 (145/84) arasındaki fark, A-A yarışında
kazanma şansını biraz artırır ama ödülü artırmaz.

## 15. Gem ekonomisi

### 15.1 Bugünkü gem geliri

| Kaynak | Gem | Ne zaman (≈ oynanış dakikası) |
|---|---|---|
| Başlangıç | 40 | 0 |
| BÜYÜK GARAJ | 10 | 25 |
| KOLEKSİYONCU | 15 | 41 |
| YENİ RENK | 10 | 45 |
| ÜÇÜNCÜ ALAN | 15 | 78 |
| DEĞERLİ GARAJ | 20 | 80 |
| FİLO | 25 | 90 |
| YILDIZLI USTA | 30 | 95 |
| **Toplam** | **165** | **~100. dakikada biter, sonra 0** |

Günlük, haftalık ya da tekrarlayan kaynak **yok**.

### 15.2 Gem fiyatlı kasaların satın alınabilirliği

Profiller: Hafif 10 dk/gün, Casual 30 dk/gün, Aktif 90 dk/gün. Oyunda gerçek parayla satış
olmadığı için üçü de ödeme yapmayan oyuncudur.

| Profil | Gün | Oynanış | Gem | 75'lik | 100'lük | 150'lik | 200'lük | 300'lük |
|---|---|---|---|---|---|---|---|---|
| Hafif | 7 | 70 dk | 75 | 1 | 0 | 0 | 0 | 0 |
| Hafif | 30 | 300 dk | 165 | 2 | 1 | 1 | 0 | 0 |
| Casual | 7 | 210 dk | 165 | 2 | 1 | 1 | 0 | 0 |
| Casual | 30 | 900 dk | 165 | 2 | 1 | 1 | 0 | 0 |
| Aktif | 7 | 630 dk | 165 | 2 | 1 | 1 | 0 | 0 |
| Aktif | 30 | 2.700 dk | 165 | 2 | 1 | 1 | 0 | 0 |

(Her sütun, o fiyatlı kasadan kaç tane alınabileceğini gösterir; birbirine eklenmez. Boya için
harcanan gem bu sayıları düşürür.)

**Karşılaştırma, bugünkü ₺ ile doğrudan alım:**

| Profil | 7 gün | 30 gün |
|---|---|---|
| Hafif | ~3,7 araç | ~15 araç |
| Casual | ~11 araç | 16 araç |
| Aktif | 16 araç | 16 araç |

**Gem kasası uygulanırsa 30 gün oynayan aktif oyuncu 1–2 araçta kalır.** Bugün 16 araç alıyor.

### 15.3 Gem kasasını çalıştırmak için gereken gem geliri

- Önerilen fiyatlarla tekrar korumalı tam koleksiyon: 6×75 + 4×100 + 3×150 + 2×200 =
  **1.700 gem**.
- Bugünkü tempoyu (15 araç ≈ 300 dk) korumak için **≈ 5,7 gem/dk (≈ 340 gem/saat)** gerekir.
  Bu, bugünkü ömür boyu gem gelirinin iki katını her saat vermek demek.
- Sonuç: gem artık premium değil ikinci bir ₺ olur. 15 gemlik boya bedavaya döner. Gerçek
  parayla gem satışı eklenirse kasa **ücretli loot box** olur: olasılık açıklaması zorunlu,
  Belçika'da sorunlu, İngiltere'de 18 yaş altı için ebeveyn kontrolü gerekir.

**Öneri:** kasalar ₺ ile. Gem özel boya gibi kozmetik ve premium hissi olan şeylerde kalır.
İleride günlük ödül (GDD §4.12: haftada 15 gem) eklenirse **yalnızca kozmetik içerikli** bir
gem kasası düşünülebilir (boya, plaka, dekor). Araç içermez, ilerlemeyi etkilemez.

### 15.4 ₺ tarafında etki

- Araç harcaması 873k'dan ~785k'ya düşer. Fark ~88k ₺, 10 saatlik 2,1M ₺ kazancın %4'ü. Dekor
  kataloğu (1,76M) bu farkı fazlasıyla karşılar.
- Oyuncu 5 saatlik araç içeriğini yine yaklaşık 5 saatte bitirir. Kasa oyunu uzatmaz ama
  kısaltmaz da.

## 16. Koleksiyon setleri

Car Town modeli: 4 araçlık temalı setler. Kasalar kademeye göre, setler **temaya göre** kurulur
ve kasaları keser:

| Set | Araçlar | Kasalar | Ödül önerisi |
|---|---|---|---|
| YERLİ KLASİKLER | Şahin, Toros | ŞEHİR | Duvar plaketi + 150 XP |
| KORE HATTI | Era, Getz, Accent Blue | ŞEHİR | Plaket + 250 XP |
| VW GRUBU | Passat, Golf 7, Kamiq, Leon, A3 | AİLE, SPOR | Plaket + 600 XP + garaj değeri +15.000 |
| SICAK KOMPAKT | Focus, Golf 7, Leon, Civic | ŞEHİR, AİLE, SPOR | Plaket + 500 XP |
| AİLE SEDANI | Era, Passat, Fluence, S60 | ŞEHİR, AİLE, PRESTİJ | Plaket + 500 XP |
| BAVYERA | E46, E60 | başlangıç, PRESTİJ | Plaket + 400 XP + garaj değeri +20.000 |
| PREMIUM | E46, A3, S60, E60 | başlangıç, SPOR, PRESTİJ | Özel tabela + 800 XP + garaj değeri +25.000 |

- Ödül nakit değil: **fiziksel duvar plaketi** (dekor sisteminin mevcut yerleştirme akışıyla),
  XP ve garaj değeri bonusu.
- Garaj değeri bonusu `GarageValue`'ya yeni bir kalem olarak eklenir. Türetilmiş kalır (tamamlanan
  setlerden hesaplanır), kayda ek alan gerekmez.
- **Kompu gacha kontrolü:** Japonya'nın yasakladığı şey, rastgele **ücretli** çekişlerle
  tamamlanan sete ödül vermekti. Bizde para birimi kazanılan ₺, gerçek parayla satış yok, tekrar
  koruması tamamlamayı deterministik kılıyor ve maliyet katalogla sınırlı. Yine de ileride gem
  satışı eklenirse **set ödülleri asla gemle alınan kasaya bağlanmamalı**.
- Mevcut koleksiyon fikriyle birleşme:
  - Görevlerdeki `OWN_VEHICLES` (2 ve 4 araç) aynen çalışır.
  - Yeni görev türü `COMPLETE_SET` ve `OPEN_CRATES` eklenebilir.

## 17. Fiziksel kasa UX'i

Akış: showroom'da kasa satın alınır → garaj avlusuna teslim edilir → oyuncu dokunur → kasa
açılır → araç çıkar → koleksiyona eklenir.

**UX avantajları**
- Car Town'ın fiziksel dili: para dünyada bir nesneye dönüşür. Tamir alanı kilidi ve dekor
  zaten bu dilde.
- Açma anı garajın içinde olur ve araç doğrudan park yerine gider. Showroom → garaj bağlantısı
  görünür hale gelir.
- Birden fazla kasa biriktirip toplu açmak ("açılış töreni") doğal bir sosyal ekran anı yaratır.

**Kurallar**
- **Sonuç satın alma anında çekilir ve kayda yazılır.** Kasa açılırken değil. Açma animasyonu
  sırasında uygulama kapanırsa araç kaybolmaz, çift gelmez ve yeniden çekilemez.
- Teslim yeri: garaj kapısının önünde **sabit bir teslim noktası**. Dekor ızgarasına yerleşmez,
  yer kavgası olmaz. En fazla 3 açılmamış kasa (üst üste istif).
- Odak modu (garaj düzenleme) açıkken kasalar da dünya-UI gibi gizlenir.

**Performans maliyeti** (mevcut ölçümlerle)
- Kasa modeli: 300–800 üçgen, 1–3 çizim çağrısı. Mevcut bütçede önemsiz (dünya 213 çizim).
- Araç modeli yükleme: showroom'da araç değişimi **9–41 ms** takılma ölçüldü. Sonuç satın almada
  bilindiği için sahne `ResourceLoader.load_threaded_request` ile **arka planda önceden** yüklenir.
  Animasyon (1–2 sn) yüklemeyi gizler.
- Açma anında sahnede araç başına ~100–200 çizim çağrısı eklenir (GLB başına 60–78 parça).
  Garaj ekranında 7 araç 1.275 çizim ölçüldü; tek bir açılış onun çok altında.
- Parçacık/konfeti: GPUParticles yerine CPUParticles veya birkaç sprite. Mobil uyumlu,
  kısa ömürlü.

**Aşamalama:** önce showroom içinde UI açılışı (1. aşama), sonra fiziksel kasa (2. aşama). Aynı
`CrateManager` iki sunumu da besler.

## 18. Riskler — pay-to-win ve hayal kırıklığı

| Risk | Nasıl ortaya çıkar | Önerilen sistemde durum |
|---|---|---|
| Aşırı rastgelelik | Korumasız çekiş | **Kapalı.** Her kasa yeni araç, en kötü durum = havuz boyu |
| Zorlayıcılık / grind | 327 kasalık tamamlama | **Kapalı.** Maliyet ≤ katalog |
| İstenen araca erişememe | Nadir aracın düşük olasılığı | **Sınırlı.** En fazla 6/4/3/2 açılış. Keşfedilmiş araç showroom'dan geri alınır |
| Manipülatif gem harcatma | Gemle kasa + gerçek parayla gem | **Kapalı.** Kasa ₺ ile. Gem satışı yok. Olası gem kasası yalnızca kozmetik |
| Karanlık desenler | Sahte "neredeyse kazandın" animasyonu, geri sayım baskısı, gizli oranlar, yeniden çevirme | **Yasak listesi:** oranlar her zaman görünür; sonuç animasyondan önce belli (animasyon sonucu değiştirmez); zaman sınırlı kasa yok; ücretli yeniden çevirme yok (Car Town'dakine rağmen) |
| Pay-to-win | Parayla güçlü araç | Bugün imkansız. Gem satışı gelirse araç asla gemle alınmamalı |
| Tekrar ile sat-al istismarı | Koruma "sahip olunan"a bakarsa | **Kapalı.** Koruma "keşfedilen"e bakar (§9) |
| Kayıt manipülasyonu | Açmadan önce kapat-aç | **Kapalı.** Sonuç satın almada kayda yazılır |
| Keşif hissinin ölmesi | Tüm detayları göstermek | Siluet + nadirlik + kasa. Ad/stat gizli |
| İçeriğin hızlı tükenmesi | 15 araç | Kasa bunu çözmez. Yeni araç = cars.json + havuz satırı, kod yok |
| Hukuki | Gem satışı + rastgele araç | Bugün kapsam dışı. Gelecekte oranlar hazır, yaş kontrolü ayrı iş |

## 19. Önerilen son sistem

1. **4 kasa, ₺ ile:** ŞEHİR (6 araç, Sv 1), AİLE (4, Sv 10), SPOR (3, Sv 14), PRESTİJ (2,
   Sv 20 + rütbe 5). Havuzlar ayrık, E46 kasa dışı.
2. **Fiyat = kasadaki en ucuz uygun yeni aracın katalog fiyatı.** Hiçbir açılış zarar
   ettirmez. Toplam ≤ katalog (ortalama %90).
3. **Tekrar koruması** "keşfedilen" araçlara göre. Olağan dışı tekrarda ₺ iadesi.
4. **Uygunluk:** `seviye ≥ min_level − 2` ve `rütbe ≥ min_garage_rank`.
5. **Nadirlik** (C/U/R/E/L) yalnızca çıkış sırasını etkiler. Ağırlık 10/6/4/2/1. Oranlar her
   zaman ekranda.
6. **Pity gerekmez:** yapı gereği her kasa yeni araç. En kötü durum ekranda yazar.
7. **Hibrit showroom:** keşfedilmemiş araçlar showroom'da satılmaz ("?"). **Keşfedilmiş** ama
   sahip olunmayan (satılmış) araçlar katalog fiyatına geri alınır. Showroom = kasa satış noktası
   + koleksiyon vitrini + geri alma.
8. **Koleksiyon ekranı:** 16'da n, kasa grupları, siluetli "?" kartlar.
9. **Garaj değeri** formülü aynı. Set bonusları yeni bir kalem.
10. **Koleksiyon setleri** (7 set): plaket + XP + garaj değeri. Nakit yok.
11. **Gem:** kasada yok. Kozmetik kalır.
12. **Fiziksel kasa** 2. aşamada, sonuç satın almada çekilir.

**Alternatif (oyun testinde hayal kırıklığı çıkarsa):** keşfedilmemiş araçlar da showroom'da
katalog ×1,25 fiyatla doğrudan satılır. "Kesin yol pahalı, sürpriz yol ucuz." Keşif hissini
zayıflatır, bu yüzden varsayılan değil.

### Neden bu, bugünkü ilerlemeyi bozmaz

| Ölçüt | Bugün | Öneri |
|---|---|---|
| İlk araç | 15.000 ₺ (~41. dk) | 15.000 ₺ (~41. dk) |
| Bir aracın en erken seviyesi | `min_level` | `min_level − 2` |
| 15 aracın toplam maliyeti | 873.000 ₺ | ort. 785.000, en fazla 873.000 |
| Sınıf sırası | serbest (herhangi bir sırayla alınır) | kasa sırasıyla D/C → B → B/A → A |
| Tekrar | yok | yok |
| Rastgelelik | yok | yalnızca kademe içi sıra |

## 20. Uygulama planı (henüz uygulanmayacak)

**Faz 0 — kararlar (kullanıcı)**
- Para birimi ₺ mi, gem mi? Bu belge ₺ öneriyor.
- Showroom'da keşfedilmemiş araç satışı kalkacak mı (öneri: kalksın, yalnızca geri alma)?
- Nadirlik tablosu ve kasa havuzları onayı.

**Faz 1 — veri + mantık (UI'sız, testli)**
- `vehicles/crates.json` (yeni): kasa id, ad, havuz, `min_level`, `min_garage_rank`, nadirlik
  ağırlıkları. Nadirlik `cars.json`'a yeni bir `rarity` alanı olarak eklenir; `CarCatalog.SCHEMA`
  satırıyla.
- `gameplay/crate_manager.gd` (yeni, grup `crates`, autoload yok):
  - `eligible(crate)`, `price(crate)`, `odds(crate)`,
  - `purchase(crate)`: ₺ düş → sonucu çek → bekleyen kasaya yaz → kaydet,
  - `open(pending)`: `VehicleOwnership.add_vehicle` → sinyal.
- `gameplay/vehicle_ownership.gd`: `_discovered` kümesi, `is_discovered()`, `buy_back()`.
  `purchase_vehicle` yalnızca keşfedilmiş araçlar için. `Status`'a `UNDISCOVERED` eklenir.
- `gameplay/save_manager.gd`: **v10**
  - `"vehicles": {"owned", "discovered"}`,
  - `"crates": {"pending": [{crate, vehicle}]}`.
  - Göç: v9'da sahip olunan her araç keşfedilmiş sayılır.
- `gameplay/garage_value.gd`: `sets_value()` kalemi (Faz 3'te).
- Testler: `tests/crate_test.gd` (uygunluk, fiyat kuralı, tekrar koruması, sat-al istismarı,
  kayıt göçü, v9 → v10). `ui_test` kilit yazıları.
- `qa/sim_progress.gd`: otomatik oyuncu kasa açar. 120 ve 300 dk tabloları AUDIT §6 ile
  karşılaştırılır. **Kabul ölçütü:** araç sayısı eğrisi ±1 araç, ilk araç ±5 dk.

**Faz 2 — UI (kod ile, `.tscn` düzenlemesi yok)**
- `ui/hud/showroom_screen.gd`: KASALAR / KOLEKSİYON / GERİ AL sekmeleri. Kasa plakası (fiyat,
  "en az şu değerde", o anki oranlar, en kötü durum). Açılış sahnesi mevcut SubViewport'ta.
- `ui/hud/collection_screen.gd` (yeni): ızgara, siluet thumbnail (mevcut thumbnail üretiminin
  koyu malzeme varyantı).
- `gameplay/progression_effects.gd`: yeni durum yazıları.
- `gameplay/player_progress.gd`: `LEVEL_REWARDS` metinleri kasa diline çevrilir, eksik araç
  metinleri eklenir.
- `ui/hud/hud.gd`: "KOLEKSİYONA EKLENDİ" bildirimi.
- `ui/hud/car_gallery.gd`: kullanılmayan `Mode.SHOP` kaldırılır.
- Görevler: `OPEN_CRATES`, `COMPLETE_SET`.

**Faz 3 — setler + fiziksel kasa**
- `vehicles/collection_sets.json` + garaj değeri kalemi + duvar plaketi (dekor kataloğunda
  ödül-only eşya).
- Fiziksel teslim noktası (`world/`), dokunma, açılış animasyonu, arka planda araç yükleme.
  Performans ölçümü: dünya FPS, çizim, VRAM ve açılış süresi. Hedef: takılma < 16 ms.

**Faz 4 — ayrı düzeltme (kasadan bağımsız, önerilir)**
- `RaceManager.player_vehicle_id()` seçili garaj aracını döndürsün. Yarış sınıfı ilerlemesi
  gerçekten çalışır hale gelir.

**Sahne değişikliği:** planlanan hiçbir adım `.tscn` düzenlemesi gerektirmiyor. Showroom, garaj
ekranı ve dünya süslemesi zaten kodla kuruluyor. Fiziksel kasa için sahneye node eklemek
gerekirse ayrıca söylenecek.
