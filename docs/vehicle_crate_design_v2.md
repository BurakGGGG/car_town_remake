# ARAÇ KASASI / KOLEKSİYON — Tasarım v2 (Gerçek nadirlik + koleksiyon avcılığı)

> **Uygulandı (2026-09-29):** bu tasarım fiziksel teslimat kasası akışıyla birlikte oyuna girdi.
> Uygulama, testler ve ölçümler: [vehicle_crate_implementation_report.md](vehicle_crate_implementation_report.md).
> Simülasyon artık repoda: `tools/economy/crate_sim.py` (oyunun gerçek JSON verisini okur).

Tarih: 2026-09-29 · Durum: **TASARIM, kod yazılmadı**
Önceki sürüm: [vehicle_crate_design.md](vehicle_crate_design.md) (v1). Araştırma:
[vehicle_crate_research.md](vehicle_crate_research.md) (v2 eki §10 dahil).

**v1'den bu yana değişen kararlar (kullanıcı, 2026-09-29):**
- "Her kasa yeni araç" kaldırıldı. Tekrar koruması yok. Kopya çıkabilir.
- Kasalar **gem** ile alınır. Gem ekonomisi bu sistemin parçası olarak yeniden tasarlanır.
- Başlangıç aracı **Tofaş Şahin**. BMW E46 artık başlangıç aracı değil, kasadan çıkan bir araç.
- Nadirlik gerçek çıkış olasılığıdır. Bazı araçlar gerçekten çok nadirdir.
- Showroom yalnızca keşfedilmiş araçları geri satar.

**Yöntem.** Bütün sayılar Python Monte Carlo simülasyonundan gelir:
- kasa sayısı analizi 100.000 oyuncu,
- gün bazlı ekonomi her profil için 100.000 oyuncu,
- kopya ve set analizi profil başına 20.000 oyuncu.

Oynanış dakikası → seviye eğrisi ölçülmüş simülasyondan alındı ([AUDIT_2026_09.md](AUDIT_2026_09.md)
§6: 60 dk Sv 11, 120 dk Sv 16, 300 dk Sv 22, 600 dk Sv 25). 600. dakikadan sonrası
`PlayerProgress.xp_to_next` (seviye başına ×1,25) ile uzatıldı. Betikler repoda değil (oturum
geçici klasörü: `v2_model.py`, `v2_theory.py`, `v2_econ.py`, `v2_ncrates.py`, `v2_dup.py`,
`v2_sets.py`); istenirse `tools/economy/` altına alınabilir.

---

## 0. Kısa cevap — kanıtlanması istenen soru

> "Nadir araç gerçekten nadir ve değerli olurken, oyuncunun koleksiyonu da makul bir hızda
> ilerliyor mu?"

**Evet, önerilen ayarlarla.** 100.000 aktif oyuncu (60 dk/gün), 30. günün sonunda:

| Ölçüt | Değer |
|---|---|
| Koleksiyon medyanı | **15 / 16** (7. gün 12, 1. gün 7) |
| BMW E60'a (Legendary) sahip olan | **%20,5**. Beşte biri. "Bende var, herkeste yok" |
| BMW E46'ya (Legendary) sahip olan | %55,0 |
| 16 / 16 tamamlayan | **%14,9** |
| Ortalama kopya | 51,8 (%97'si Common/Rare) |
| Açılan kasa | 65,4 |

Nadirlik gerçek: E60'ı %95 olasılıkla görmek için **107 PRESTİJ kasası** gerekir. Bu en kötü
şans kuyruğu, oyuncu deneyimi açısından **aşırı kötü** olarak işaretlendi (§7.3). Kullanıcı
kararına uygun olarak pity eklenmedi; seçenekler §18'de.

---

## 1. Yeni tasarım felsefesi

```
Kasa aç → rastgele araç → nadirlik önemli → çoğu sık, bazısı nadir, biri çok nadir
        → oyuncu nadiri arar → kopyalar boşa gitmez ama nadiri ucuzlatmaz
        → koleksiyon yavaşlayan bir eğriyle dolar, son parça "avlanır"
```

Dört his hedefi ve karşılığı:

| His | Nadirlik | Aynı kasadaki Common'a göre | Oyuncu cümlesi |
|---|---|---|---|
| "Birkaç kasada görürüm" | COMMON | 1× | "Yine Getz çıktı." |
| "Bu daha az çıkıyor" | RARE | 2,5 kat nadir | "Güzel, Kamiq geldi." |
| "Bunu bulmak iyi oldu" | EPIC | ~6,7 kat nadir | "Toros! Sonunda." |
| "Bunu bulmak gerçekten zor" | LEGENDARY | 25 kat nadir | "E60 bende var." |

Tasarım ilkeleri:
1. **Oranlar açık.** Kasa ekranında her aracın yüzdesi yazar.
2. **Sonuç satın alma anında çekilir ve kaydedilir.** Uygulamayı kapatıp açmak sonucu değiştirmez.
3. **Kopya bir şey verir** ama sahipliği çoğaltmaz. Nadir araç tek kalır.
4. **İlerleme kapıları korunur.** Kasa, seviye ilerlemesini atlamanın yolu değildir.
5. **Gem gerçek parayla satılmaz** (bugünkü durum). Satılırsa sistem baştan "ücretli loot box"
   kurallarına göre yeniden değerlendirilir (§17).

## 2. Başlangıç: Tofaş Şahin

- Yeni oyunda **Tofaş Şahin ücretsiz** verilir. İlk garaj aracı, ilk yarış aracı, koleksiyonun
  1/16'sı.
- **Hiçbir kasada yoktur.** Kopyası çıkmaz, "başlangıç" kartıyla koleksiyonda durur.
- İlk dakikada kasa yoktur. **İlk kasa ücretsiz**: Sv 2'de hikâye görevinin ödülü (İLK KASA,
  ŞEHİR). Simülasyonda dahil.
- Yarış: Şahin D sınıfı. Rakip havuzu D veya C, ödül 450 / 700 ₺ (`RaceManager.WIN_REWARD`).
  Bugün oyuncu A sınıfı E46 ile başlıyor; bu, başlangıç yarış dengesini düzeltir (§12).

Değişecek yerler (uygulama fazında):
- `VehicleOwnership.starting_vehicle_id` → `tofas_sahin`.
- `RaceManager.player_vehicle_id()` içindeki sabit `bmw_e46` yedekleri.
- `drag_race_screen.gd:133`.
- Kayıt göçü: mevcut kayıtlarda E46 zaten sahipli; alınmaz, keşfedilmiş sayılır.

## 3. Gem ekonomisi

### 3.1 Bugün ne var, ne yok

| Kaynak | Bugün | Miktar |
|---|---|---|
| Başlangıç gemi | **VAR** | 40 |
| Hikâye görevleri (7 görev) | **VAR** | 125 (tek sefer, ~100. dakikada biter) |
| Seviye atlama | YOK (yalnızca ₺ veriyor) | — |
| Günlük giriş | YOK (GDD §4.12'de öneri olarak duruyor) | — |
| Günlük görev | YOK | — |
| Haftalık hedef | YOK | — |
| Başarım (achievement) | YOK | — |
| Yarış kilometre taşı | YOK | — |
| Koleksiyon kilometre taşı | YOK | — |
| İlk kez araç keşfi | YOK | — |
| İş ustalığı yıldızı | Yıldız sistemi VAR, gem ödülü YOK (₺ veriyor) | — |
| Kopya karşılığı | YOK (sistem yok) | — |
| **Toplam ömür boyu** | | **165** |

Harcama yeri bugün yalnızca özel boya (15–25 gem).

### 3.2 Önerilen kaynaklar

Kaynakları üç türe ayırdım, çünkü sürdürülebilirlik bu dengeye bağlı:
- **Tek seferlik** kaynaklar ilk günleri besler,
- **günlük tavanlı** kaynaklar alışkanlık yaratır ama grindi ödüllendirmez,
- **oynanışla ölçekli** kaynaklar çok oynayanı biraz öne alır.

| Kaynak | Tür | Kural | CASUAL 30 gün | ACTIVE 30 gün | HEAVY 30 gün |
|---|---|---|---|---|---|
| Başlangıç + 7 hikâye görevi (mevcut) | tek sefer | 40 + 125 | 165 | 165 | 165 |
| Seviye atlama | tek sefer | seviye başına 5, her 5. seviyede +25 | 245 | 300 | 345 |
| Günlük giriş | günlük tavan | 7 günlük döngü 10·10·15·10·15·10·40 (110/hafta) | 460 | 460 | 460 |
| Günlük görev (Sv 3+) | günlük tavan | 3 görev × 10 + üçü birden +20 | 600 (günde 2) | 1.500 | 1.500 |
| Haftalık hedef | haftalık tavan | haftada 12 günlük görev → 100 | 400 | 400 | 400 |
| Ustalık yıldızı (mevcut sisteme gem) | tek sefer | yıldız başına 10 (35 yıldız) | 280 | 320 | 350 |
| Tamir başarımları | tek sefer | 50/250/1.000/2.500/5.000 tamir → 10/20/30/50/75 | 60 | 185 | 185 |
| Bahşiş | oynanışla ölçekli | her 20 tamirde 1 gem, günde en fazla 40 | 90 | 330 | 840 |
| İlk keşif | tek sefer (araç başı) | C 3 · R 8 · E 20 · L 40 | 112 | 137 | 144 |
| Koleksiyon kilometre taşı | tek sefer | 5/10/14/16 araç → 15/30/50/100 | 78 | 105 | 114 |
| Kopya hurdası | kasaya bağlı | C 2 · R 5 · E 12 · L 30 | 91 | 142 | 159 |
| **30 günlük toplam (ortalama)** | | | **2.580** | **4.044** | **4.662** |

Profiller: CASUAL 20 dk/gün + 2 günlük görev, ACTIVE 60 dk/gün + 3, HEAVY 150 dk/gün + 3. Hepsi
her gün giriş yapar.

Okuma:
- İlk haftadan sonra günlük gelir CASUAL **~69**, ACTIVE **~111**, HEAVY **~124** gem/gün.
- HEAVY, ACTIVE'in 2,5 katı oynuyor ama yalnızca %15 fazla gem alıyor. **Grind kasıtlı olarak
  ödüllendirilmiyor**; fark bahşişten geliyor.
- Yarış kilometre taşları kasıtlı olarak modele **konmadı**. Yarış sıklığı ölçülmedi ve yarış
  aracı seçimi henüz düzeltilmedi (§12). Eklenecekse "haftalık 20 galibiyet → 50 gem" gibi
  tavanlı olmalı.

### 3.3 Gem'in gelecekteki kullanımları

Önerilen bütçe ilkesi: kasalar ilk 30 günde gem harcamasının **~%90'ı**. Kalan pay ve 16/16
sonrası birikim, gelecekteki şu içeriklere ayrılır:
- premium dekor ve garaj objeleri,
- kozmetik (özel boya, plaka çerçevesi, jant),
- özel koleksiyon içerikleri (set plaketleri, vitrin).

Simülasyonda ACTIVE oyuncu 30. günde 4.044 gem kazanıp 3.856 harcıyor. Koleksiyonu
tamamlayanlarda biriken gem bu içeriklere gider. Yeni gem harcama yeri eklendiğinde kasa fiyatları
yeniden simüle edilmeli. Aksi halde koleksiyon temposu sessizce yavaşlar.

## 4. Kasa kategorileri

| Kasa | Fiyat | Açılış | Havuz | Sınıf | Nadirlik yapısı |
|---|---|---|---|---|---|
| **ŞEHİR** | **30 gem** | Sv 1 | 5 araç | D, C | 2 C · 2 R · 1 E |
| **AİLE** | **50 gem** | Sv 10 | 4 araç | B | 2 C · 1 R · 1 E |
| **SPOR** | **80 gem** | Sv 14 | 3 araç | B, A | 1 C · 1 E · 1 L |
| **PRESTİJ** | **120 gem** | Sv 20 | 3 araç | A | 1 C · 1 R · 1 L |

- Fiyat oranı 1 : 1,7 : 2,7 : 4, kasadaki araçların ₺ değerleri ve açılış seviyesiyle birlikte
  artıyor.
- ŞEHİR'in 30 gemi, ilk hafta ~24 kasayı mümkün kılıyor (§15).
- SUPER / MUSCLE / LEGENDARY kasası **yok**: kadroda bunları dolduracak gerçek araç yok. Kadro
  büyüyünce açılır.
- Havuzlar ayrık: her araç tek bir kasada. Oran tablosu net, "bu kasa bitti" anlaşılır.

Kasa yapısı kullanıcının örneğine uyuyor: bir kasada Legendary yok (ŞEHİR, AİLE), birinde 1
Legendary + 1 Epic var (SPOR).

## 5. Araç havuzları — 16 aracın tam tablosu

Kasa oranları §7'deki ağırlıklardan hesaplanır.

| Araç | Kasa | Nadirlik | Kasa içi olasılık | Sınıf | Sv (cars.json) | Değer ₺ | Setler (§13) |
|---|---|---|---|---|---|---|---|
| Tofaş Şahin | BAŞLANGIÇ | COMMON | — (ücretsiz) | D | 1 | 15.000 | Yerli Klasikler |
| Hyundai Getz | ŞEHİR | COMMON | 33,90 % | C | 8 | 35.000 | Kore Hattı |
| Hyundai Accent Blue | ŞEHİR | COMMON | 33,90 % | C | 8 | 38.000 | Kore Hattı |
| Hyundai Era | ŞEHİR | RARE | 13,56 % | C | 6 | 30.000 | Kore Hattı, Aile Sedanı |
| Ford Focus | ŞEHİR | RARE | 13,56 % | C | 10 | 45.000 | Sıcak Kompakt |
| **Renault Toros** | ŞEHİR | **EPIC** | **5,08 %** | **D** | 3 | 20.000 | Yerli Klasikler |
| VW Passat B5.5 | AİLE | COMMON | 39,22 % | B | 12 | 50.000 | VW Grubu, Aile Sedanı |
| Renault Fluence | AİLE | COMMON | 39,22 % | B | 15 | 60.000 | Aile Sedanı |
| Skoda Kamiq | AİLE | RARE | 15,69 % | B | 12 | 55.000 | VW Grubu |
| VW Golf 7 | AİLE | EPIC | 5,88 % | B | 15 | 65.000 | VW Grubu, Sıcak Kompakt |
| Seat Leon | SPOR | COMMON | 84,03 % | B | 16 | 68.000 | VW Grubu, Sıcak Kompakt |
| **Honda Civic VTEC** | SPOR | **EPIC** | 12,61 % | **B** | 18 | 72.000 | Sıcak Kompakt |
| **BMW E46** | SPOR | **LEGENDARY** | **3,36 %** | A | 12 | 85.000 | Bavyera, Premium |
| **Audi A3** | PRESTİJ | **COMMON** | 69,44 % | **A** | 20 | 95.000 | VW Grubu, Premium |
| Volvo S60 | PRESTİJ | RARE | 27,78 % | A | 22 | 105.000 | Aile Sedanı, Premium |
| **BMW E60** | PRESTİJ | **LEGENDARY** | **2,78 %** | A | 25 | 120.000 | Bavyera, Premium |

Dağılım: COMMON 7 (Şahin dahil) · RARE 4 · EPIC 3 · LEGENDARY 2.

## 6. Nadirlik

### 6.1 Neden 4 kademe (UNCOMMON yok)

- 15 kasa aracı / 4 kasa = kasa başına **3,75 araç**. Beş kademe olsaydı kasaların çoğunda her
  kademe tek araç olurdu.
- UNCOMMON'ın ağırlığı Common (100) ile Rare (40) arasında olacağı için (~65) Common'dan yalnızca
  **1,5 kat** nadir olurdu. Oyuncunun ayırt edemeyeceği bir etiket.
- **Öneri:** kadro ~30 araca ve kasa havuzları 7+ araca çıkınca UNCOMMON eklenir.

### 6.2 Nadirlik ≠ sınıf — gerekçeli örnekler

Nadirlik rastgele dağıtılmadı. Dört ölçüt kullanıldı:
1. **ilerleme** (sınıf ve seviye kasa kapısıyla uyumlu kalmalı),
2. **yarış dengesi** (nadir ≠ güçlü; güçlü araç kapıyla sınırlı),
3. **değer** (garaj değeri katkısı),
4. **ikonluk** (Türkiye'de ve araba kültüründe "bulunması zor" hissi).

| Örnek | Sınıf + Nadirlik | Neden |
|---|---|---|
| Renault Toros | **D + EPIC** | 1994 yerli klasik; bugün iyi durumdasını bulmak zor. Yarışta zayıf (D) olduğu için nadirliği güç vermez. Saf koleksiyon değeri |
| Hyundai Getz / Accent | **C + COMMON** | Sokakta en sık görülen araçlar. Kopyası en çok çıkan araçlar ("yine Getz") |
| Honda Civic VTEC | **B + EPIC** | VTEC ikonu; B'nin en iyi statı. Güç sınıfı B'de kalır, nadirliği prestij verir |
| Audi A3 | **A + COMMON** | PRESTİJ'in "tabanı". A sınıfı ama bu kasanın sıradan sonucu. Sv 20 kapısı zaten A sınıfını sınırlıyor |
| BMW E46 | **A + LEGENDARY** | M3 soyunun ikonu, eskiden başlangıç aracıydı. Artık SPOR kasasının av aracı |
| BMW E60 | **A + LEGENDARY** | En pahalı, en yüksek seviye, en hızlı. Koleksiyonun son parçası olmaya aday |

### 6.3 Ağırlıklar

Her araç nadirliğine göre ağırlık alır. Kasa içi olasılık = ağırlık / havuz toplamı.

**COMMON 100 · RARE 40 · EPIC 15 · LEGENDARY 4.**

Neden kasa başına nadirlik payı (örn. "Epic %12") değil de araç başına ağırlık: ilk
simülasyonda kasa başına payla SPOR'daki tek Epic (Civic) **%35** çıkıyordu. "Epic = nadir"
vaadi, kasadaki araç sayısına göre bozuluyordu. Ağırlıkla bir Epic, hangi kasada olursa olsun
aynı kasadaki bir Common'dan 6,7 kat nadir.

## 7. Drop olasılıkları

### 7.1 Kasa ekranında gösterilecek tablo

| Kasa | COMMON | RARE | EPIC | LEGENDARY |
|---|---|---|---|---|
| ŞEHİR (30) | 67,8 % (Getz, Accent) | 27,1 % (Era, Focus) | 5,1 % (Toros) | — |
| AİLE (50) | 78,4 % (Passat, Fluence) | 15,7 % (Kamiq) | 5,9 % (Golf 7) | — |
| SPOR (80) | 84,0 % (Leon) | — | 12,6 % (Civic) | 3,4 % (E46) |
| PRESTİJ (120) | 69,4 % (A3) | 27,8 % (S60) | — | 2,8 % (E60) |

Oranlar sabittir: sahip olunanlara, seviyeye ya da kasa sayısına göre **değişmez**. Böylece
ekrandaki sayı her zaman doğrudur.

### 7.2 Belirli bir nadir aracı görme olasılığı (teorik, o kasadan n açılış)

| Araç | p | 10 | 25 | 50 | 100 | 200 | %50 | %75 | %90 | %95 |
|---|---|---|---|---|---|---|---|---|---|---|
| Renault Toros (E) | 5,08 % | 40,7 % | 72,9 % | 92,6 % | 99,5 % | ~100 % | 14 | 27 | 45 | 58 |
| VW Golf 7 (E) | 5,88 % | 45,5 % | 78,0 % | 95,2 % | 99,8 % | ~100 % | 12 | 23 | 38 | 50 |
| Honda Civic (E) | 12,61 % | 74,0 % | 96,6 % | 99,9 % | ~100 % | ~100 % | 6 | 11 | 18 | 23 |
| **BMW E46 (L)** | 3,36 % | 29,0 % | 57,5 % | 81,9 % | 96,7 % | 99,9 % | **21** | **41** | **68** | **88** |
| **BMW E60 (L)** | 2,78 % | 24,6 % | 50,6 % | 75,6 % | 94,0 % | 99,6 % | **25** | **50** | **82** | **107** |

Son dört sütun: o olasılığa ulaşmak için gereken kasa sayısı.

### 7.3 Kötü şans kuyruğu — açıkça işaretlenen sorun

| Durum | Kasa | Gem | ACTIVE için yaklaşık süre* |
|---|---|---|---|
| E60, medyan oyuncu | 25 PRESTİJ | 3.000 | ~27 gün |
| E60, en şanssız %10 | 82 | 9.840 | ~89 gün |
| **E60, en şanssız %5** | **107** | **12.840** | **~116 gün** |
| E46, en şanssız %5 | 88 SPOR | 7.040 | ~63 gün |

\* İlk haftadan sonraki ~111 gem/gün ile ve bütün gemin o kasaya gittiği varsayımıyla.

**Değerlendirme:** medyan ve P75 kabul edilebilir: "nadir ama ulaşılabilir". **P90–P95 aşırı
kötü.** Her 20 aktif oyuncudan biri 4 ay boyunca E60'ı göremez. Kullanıcı kararı gereği pity
eklenmedi. Bu kuyruğu kısaltmak için pity olmayan seçenekler §18'de.

### 7.4 Kasa tamamlama (MC, 100.000 oyuncu)

| Kasa | Havuz | 5 / 10 / 25 / 50 açılışta beklenen keşif | Tamamlama medyan | P75 | P90 | P95 | Medyan gem | P90 gem |
|---|---|---|---|---|---|---|---|---|
| ŞEHİR | 5 | 3,01 / 3,91 / 4,68 / 4,93 | 18 | 29 | 45 | 58 | 540 | 1.350 |
| AİLE | 4 | 2,67 / 3,26 / 3,77 / 3,95 | 14 | 24 | 39 | 50 | 700 | 1.950 |
| SPOR | 3 | 1,65 / 2,03 / 2,54 / 2,82 | 23 | 41 | 68 | 89 | 1.840 | 5.440 |
| PRESTİJ | 3 | 1,93 / 2,21 / 2,51 / 2,76 | 25 | 50 | 83 | 107 | 3.000 | 9.960 |

## 8. Kopya (duplicate)

### 8.1 Ne kadar kopya çıkar

ACTIVE oyuncu, 30 gün: ortalama **51,8 kopya**. Dağılım: Common 43,2 · Rare 7,0 · Epic 1,6 ·
Legendary 0,06. Legendary kopyası 30 günde oyuncuların yalnızca **%5,2**'sinde çıkıyor.

### 8.2 Seçeneklerin simülasyonu

Profil başına 20.000 oyuncu, 7. ve 30. gün:

| Seçenek | Simülasyon sonucu (ACTIVE) | Ekonomi | İlerleme | Motivasyon | "Nadir değersizleşir mi?" |
|---|---|---|---|---|---|
| **Blueprint / araç yıldızı** (1/3/6/10/15 kopya → ★1–5) | 30. gün kopyası olan Common'ların %55'i ★3+, %16'sı ★5. Rare'lerin %16'sı ★3+. Legendary ★ yalnızca oyuncuların %5'inde | Gem üretmez, nötr | Kozmetik + küçük değer kalırsa nötr | Common kopyası bile bir adım. Legendary ★ ultra nadir övünç | Hayır: sahiplik tek, ★ ek şans göstergesi |
| **Araç parçası** (kopya başına +1 stat, en fazla +5) | En çok kopyası olan araca **7. günde +4,7**, 30. günde **+5** stat | Nötr | **Yarış dengesini bozar**: Common araçlar en hızlı güçlenir, sınıf sırası karışır | Güç = motivasyon ama P2W algısı | Evet: güç Common'a kayar |
| **Koleksiyon jetonu** (C1 · R3 · E8 · L25) | 30. günde ortalama **78 jeton** (medyan 77) | Neyle takas edildiğine bağlı. 25 jeton = 1 kasa ise +%5 kasa | Keşfedilmemiş araç alınırsa gizli pity olur ve showroom kuralını deler | İyi ("biriktiriyorum") | Keşfedilmemiş araç satarsa evet |
| **Kopya parası = gem hurdası** (C2 · R5 · E12 · L30) | 30. günde ortalama 142 gem = kazancın **%3,5**'i | Küçük enflasyon. Koleksiyon temposunu ~%4 hızlandırır | Nötr | "Tamamen boş değil"; tek başına zayıf | Hayır |
| **Yükseltme malzemesi** | Parça ile aynı sonuç | — | Yarış dengesini bozar | — | Evet |
| **Kozmetik malzeme** (kopya → o araca özel boya/kaplama) | Common'lar 1. haftada malzeme biriktirir, Legendary'ler neredeyse hiç | Gem ekonomisinden ayrı | Nötr | Garaj özelleştirmesiyle birleşir | Hayır |

### 8.3 Öneri (kullanıcı onayına sunulan)

**Araç yıldızı + küçük gem hurdası + ★3'te kozmetik.** Parça ve yükseltme seçenekleri yarış
dengesini bozduğu için elendi.

Her kopya:
- o aracın **yıldızına** 1 adım ekler (★1–5 eşikleri: 1 / 3 / 6 / 10 / 15 kopya),
- nadirliğe göre gem hurdası verir (2 / 5 / 12 / 30).

Yıldız ödülleri:
- **★1:** kartta yıldız.
- **★3:** o araca özel boya veya plaka çerçevesi (kozmetik malzeme fikri).
- **★5:** altın plaka + o aracın garaj değeri katkısına **+%5**. E60 için 6.000 ₺; rütbe
  eşiklerini oynatmaz.

"Nadir aracı tekrar buldum, boşa gitti" hissine karşılık: Legendary kopyası = 30 gem + nadir
★1 + "×2" rozeti. Oyuncuların %95'inin hiç görmeyeceği bir övünç.

"Kopya yüzünden nadir değersizleşti" riskine karşılık: kopya satılabilir ikinci bir araç
üretmez, ★ güç vermez, jeton ile keşfedilmemiş araç alınamaz.

### 8.4 Koleksiyon tamamlandıktan sonra

| Seçenek | Değerlendirme |
|---|---|
| Kopya ağırlıklarını değiştir | **Önerilmez.** Oranlar ekranda yazıyor; değişen oran güveni bozar |
| Tamamlanan kasa başka ödül versin | Önerilir, **tek seferlik**: "KASA USTASI" plaketi |
| Başka kasa açılsın | Kadro büyüyünce: yeni araçlar yeni kasalara |
| Jeton | Gelecekte **kozmetik** mağazası; araç değil |

Tamamlanan kasa satılmaya devam eder, çünkü yıldızlar ve hurda sürer. Kasa kartında "TAMAMLANDI
5/5" rozeti durur.

## 9. Koleksiyon ekranı

- Başlık: **KOLEKSİYON 15 / 16**. Kasa bazında alt sayaçlar: ŞEHİR 5/5, SPOR 2/3 …
- Kart durumları:

| Durum | Gösterilen | Gizlenen |
|---|---|---|
| SAHİPSİN | Tam kart + ★ + kopya sayısı | — |
| KEŞFEDİLDİ (satılmış) | Tam kart + "SHOWROOM'DA GERİ AL" | — |
| ??? (keşfedilmemiş) | Siluet, nadirlik rengi, kasa adı, **o kasadaki olasılık** | Ad, marka, stat, değer |
| KİLİTLİ (kasa henüz açılmadı) | Koyu siluet, nadirlik, "SV 20'DE PRESTİJ KASASI" | Ad, marka, stat, değer, sınıf |

- **Son parça:** 15/16'da kalan kart büyür ve öne çıkar: "KOLEKSİYONUN SON PARÇASI · ??? ·
  LEGENDARY · PRESTİJ KASASI %2,78". Kasa ekranına tek dokunuşla gidilir.
- 16/16 ayrı bir an olarak tasarlanır: "TAM KOLEKSİYON" duvar tabelası, 100 gem kilometre taşı ve
  garajın rütbe tabelasına koleksiyon yıldızı.
- Siluet: mevcut thumbnail üretimi aynı modeli koyu düz malzemeyle çizer. Yeni varlık gerekmez.

## 10. Showroom

**KASA = KEŞİF, SHOWROOM = GERİ ALMA.**

- Showroom yalnızca **keşfedilmiş ama şu an sahip olunmayan** araçları satar.
- Fiyat katalog fiyatıdır ve **₺** ile ödenir. ₺ harcama yeri olarak kalır; gem ekonomisine
  dokunmaz.
- Hiç keşfedilmemiş araç showroom'da **görünmez** (en fazla "???").
- Satış %40 ile aynen kalır. Geri alma %100. Al-sat kârı yok.
- Satılan aracın kasadan tekrar çıkması **kopya değildir**: araç geri gelir, keşif ödülü
  verilmez. Gem → ₺ dönüşümü (kasa aç, sat) çok kötü bir takas: 120 gem → en fazla 48.000 ₺.
  Gem ₺ ile alınmadığı için döngü kurulamaz.

**₺ ekonomisi etkisi:** araçlar artık ₺ harcamıyor. Bugünkü 873.000 ₺'lik araç harcaması
kalkıyor. Bu para garaj seviyesi, tamir alanları, hız, standart boya, **dekor (74 eşya, 1,76 M ₺)**
ve geri almaya kalıyor. AUDIT'teki "10. saatte 1,1 M ₺ ölü para" sorunu, dekor olmasaydı
büyürdü; dekor bunu karşılıyor. Uygulama fazında `qa/sim_progress.gd` ile yeniden ölçülmeli.

## 11. Seviye kısıtları

### 11.1 v1'in "−2 seviye" kuralı gerekli mi?

**Hayır. Yerine kasa kapıları yeterli ve daha şeffaf.**

| Seçenek | Sonuç |
|---|---|
| Kapı yok | ~45. dakikada oyuncunun ~130 gemi olur (hikâye 75 + seviye 55). PRESTİJ (120) açılır, **içindeki her araç A sınıfı**, yani Sv 7'de A sınıfı garanti. İlerleme çöker. **Reddedildi** |
| Araç başına −2 filtresi (v1) | Oranlar seviyeye göre değişir; ekrandaki olasılık tablosu her seviyede farklı olur ve oyuncu "neden bu kasada Toros yok?" diye sorar. Şeffaflık ilkesiyle çatışır |
| **Kasa kapısı** (öneri): ŞEHİR 1 · AİLE 10 · SPOR 14 · PRESTİJ 20 | Oranlar sabit. Kasalar sınıf sırasıyla açılır. En güçlü araçlar kapının arkasında |

Kapıların araç seviyeleriyle ilişkisi:
- ŞEHİR'deki araçlar cars.json'da Sv 3–10 ama hepsi D/C sınıfı.
- AİLE Sv 12–15, hepsi B.
- SPOR'da A sınıfı tek araç E46 (Sv 12 ≤ 14) ve %3,4.
- PRESTİJ'de E60 (Sv 25) 5 seviye erken ama %2,8.

### 11.2 Seviye ↔ sınıf ↔ nadirlik ↔ yarış (simülasyon)

Oyuncunun sahip olduğu en iyi sınıf (100.000 oyuncu):

| Profil | 1. gün | 3. gün | 7. gün | 14. gün |
|---|---|---|---|---|
| CASUAL (Sv 5/11/16/21) | C %100 | B %100 | B %91 · A %9 | A %100 |
| ACTIVE (Sv 11/18/23/27) | B %100 | B %92 · A %8 | A %100 | A %100 |
| HEAVY (Sv 17/23/28/31) | B %95 · A %5 | A %100 | A %100 | A %100 |

- **Bugün:** oyuncuların %100'ü 0. dakikada A sınıfı (E46).
- **Öneriyle:** D ile başlar, C ile ilk saatler, B ile ilk günler. A'ya erken erişim yalnızca
  SPOR kasasındaki %3,4'lük E46 şansıyla, Sv 14'ten sonra.

Sınıf ilerlemesi bugünkünden **daha yavaş ve daha düzenli**.

## 12. Yarış entegrasyonu

- **Hata:** `RaceManager.player_vehicle_id()` "garajda seçili araç" demesine rağmen `owned[0]`
  döndürüyor. Bugün bu E46. Satılırsa listenin bir sonraki aracı olur.
- **Öneri (kasa fazından bağımsız, küçük):**
  - Garajda "YARIŞ ARACI" seçimi; kayıtta `race_vehicle`.
  - Varsayılan Tofaş Şahin.
  - Seçili araç satılırsa kalan araçlardan en yüksek sınıflısına düşer.
- Rakip havuzu (oyuncunun sınıfı + bir üstü) ve ödül tablosu (D 450 · C 700 · B 1.000 · A 1.400
  ₺) aynı kalır.
- Kasa yarışı bozar mı? Yüksek sınıflı araç çıkarsa rakip de bir üst sınıftan gelir; yarış
  kolaylaşmaz, ödül büyür. Büyük ödüle erken erişim §11.2'deki kapılarla sınırlı ve bugünkünden
  (0. dakikada A) daha geç.
- Nadirlik güç vermez: Toros (Epic) D sınıfı, Audi A3 (Common) A sınıfı. Yıldız stat vermez (§8.3).

## 13. Koleksiyon setleri

v1'deki 7 set korundu, yeni havuzlarla güncellendi.

Tamamlanma olasılıkları: 20.000 oyuncu/profil, 7. gün → 30. gün.

| Set | Araçlar | CASUAL | ACTIVE | HEAVY | Ödül |
|---|---|---|---|---|---|
| YERLİ KLASİKLER | Şahin, **Toros (E)** | %54 → %83 | %54 → %98 | %62 → %99 | Plaket + 150 XP |
| KORE HATTI | Era, Getz, Accent | %96 → %100 | %99 → %100 | %100 → %100 | Plaket + 250 XP |
| VW GRUBU | Passat, Golf 7, Kamiq, Leon, A3 | %0 → %62 | %32 → %89 | %41 → %94 | Plaket + 600 XP + garaj değeri +15.000 |
| SICAK KOMPAKT | Focus, Golf 7, Leon, Civic | %11 → %55 | %16 → %87 | %27 → %93 | Plaket + 500 XP |
| AİLE SEDANI | Era, Passat, Fluence, S60 | %0 → %96 | %71 → %100 | %86 → %100 | Plaket + 500 XP |
| **BAVYERA** | **E46 (L), E60 (L)** | %0 → %5 | %1 → %16 | %1 → %22 | Özel tabela + 400 XP + garaj değeri +20.000 |
| PREMIUM | E46, A3, S60, E60 | %0 → %4 | %1 → %16 | %1 → %22 | Özel tabela + 800 XP + garaj değeri +25.000 |

- Ödüller **nakit ya da gem değil**. Plaket, XP ve garaj değeri.
- Set ödülleri nadir aracı değersizleştirmez. BAVYERA iki Legendary ister ve 30. günde aktif
  oyuncuların yalnızca %16'sında tamamlanır. Nadirlik setin prestijini büyütür.
- **Japonya kompu gacha notu:** yasaklanan şey, ücretli rastgele çekişlerle set tamamlayana ödül
  vermekti. Bugün gem gerçek parayla satılmıyor. Satılırsa set ödülleri yeniden değerlendirilmeli
  (§17).

## 14. Ekonomi simülasyonu — kurulum

- Oyuncu her gün `dk/gün` kadar oynar. Seviye, ustalık yıldızı ve tamir sayısı ölçülmüş eğrilerden
  gelir. Gem kaynakları §3.2'deki kurallarla eklenir.
- **Harcama politikası:** açık kasalar arasında `P(yeni araç) / fiyat` oranı en yüksek olanı alır.
  Parası yetmezse bekler. Koleksiyonu biten gem biriktirir. Bu, bilinçli ama "en iyi"den biraz
  saf bir oyuncudur.
- Boya harcaması modele dahil değil. Gerçek oyuncu gemin bir kısmını boyaya harcarsa koleksiyon
  birkaç gün yavaşlar.
- İlk kasa ücretsiz (Sv 2 görev ödülü).

## 15. 1 / 3 / 7 / 14 / 30 günlük ilerleme (100.000 oyuncu / profil)

"Araç" sütunları 16'da kaç araca sahip olunduğunu gösterir, Şahin dahil.

### CASUAL (20 dk/gün)
| Gün | Sv | Kazanılan gem | Harcanan | Kasa | Araç medyan (P25–P75, P90) | Kopya | Epic ort. | E46 | E60 | 16/16 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 5 | 208 | 192 | 7,4 | 4 (4–5, 6) | 3,9 | 0,32 | 0 % | 0 % | 0 % |
| 3 | 11 | 441 | 419 | 12,9 | 7 (6–8, 9) | 6,9 | 0,57 | 0 % | 0 % | 0 % |
| 7 | 16 | 982 | 949 | 23,4 | 10 (9–11, 11) | 14,4 | 1,19 | 9,3 % | 0 % | 0 % |
| 14 | 21 | 1.555 | 1.506 | 31,0 | 12 (11–13, 14) | 19,8 | 1,50 | 14,4 % | 6,3 % | 0,2 % |
| 30 | 25 | 2.580 | 2.526 | 46,9 | 14 (13–14, 15) | 34,3 | 2,27 | 29,9 % | 11,7 % | 3,1 % |

### ACTIVE (60 dk/gün)
| Gün | Sv | Kazanılan gem | Harcanan | Kasa | Araç medyan (P25–P75, P90) | Kopya | Epic ort. | E46 | E60 | 16/16 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 11 | 401 | 379 | 11,2 | 7 (6–8, 8) | 5,1 | 0,51 | 0 % | 0 % | 0 % |
| 3 | 18 | 843 | 813 | 20,1 | 10 (9–10, 11) | 11,5 | 1,02 | 7,7 % | 0 % | 0 % |
| 7 | 23 | 1.480 | 1.441 | 28,7 | 12 (11–13, 14) | 17,5 | 1,32 | 11,9 % | 7,9 % | 0,2 % |
| 14 | 27 | 2.354 | 2.307 | 43,3 | 14 (13–14, 15) | 30,8 | 2,10 | 26,2 % | 11,0 % | 2,1 % |
| 30 | 31 | 4.044 | 3.856 | 65,4 | 15 (14–15, 16) | 51,8 | 2,83 | 55,0 % | 20,5 % | 14,9 % |

### HEAVY (150 dk/gün)
| Gün | Sv | Kazanılan gem | Harcanan | Kasa | Araç medyan (P25–P75, P90) | Kopya | Epic ort. | E46 | E60 | 16/16 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 | 17 | 677 | 650 | 16,5 | 9 (8–10, 11) | 8,4 | 0,83 | 5,5 % | 0 % | 0 % |
| 3 | 23 | 1.086 | 1.045 | 22,0 | 11 (10–12, 13) | 11,8 | 0,96 | 6,5 % | 5,6 % | 0 % |
| 7 | 28 | 1.799 | 1.760 | 33,9 | 13 (12–14, 14) | 22,2 | 1,61 | 16,7 % | 9,3 % | 0,6 % |
| 14 | 31 | 2.790 | 2.726 | 49,9 | 14 (13–15, 15) | 37,1 | 2,39 | 33,7 % | 12,6 % | 4,3 % |
| 30 | 35 | 4.662 | 4.362 | 71,3 | 15 (14–15, 16) | 57,4 | 2,92 | 63,8 % | 25,6 % | 21,2 % |

Okuma:
- **Hızlı başlangıç, yavaşlayan eğri.** ACTIVE 1. günde 7, 7. günde 12, 30. günde 15 araç. Son
  1–2 parça (genellikle Legendary) aylarca sürebilen bir av.
- **Günlük kasa:** ilk haftadan sonra ACTIVE günde ~1,6 kasa açıyor. "Yarın tekrar gel" nedeni:
  günlük giriş + görevler → kasa → her PRESTİJ'de %2,8 E60 şansı.
- **Profil adaleti:** CASUAL 30. günde 14/16'ya ulaşıyor. HEAVY ile ACTIVE arasındaki fark küçük.
  Oyunu çok oynamak şart değil.

## 16. 100.000 oyunculuk Monte Carlo — kasa sayısına göre koleksiyon

Tüm kasalar açık (seviye kısıtı yok), politika §14. 16/16 olduktan sonra oyuncu PRESTİJ açmaya
devam eder (kopya).

| Açılan kasa | Ort. | P10 | P25 | Medyan | P75 | P90 | P95 | 16/16 | E60 | E46 | Kopya ort. | Gem ort. |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | 7,97 | 6 | 7 | 8 | 9 | 10 | 10 | 0,0 % | 1,3 % | 3,5 % | 3,0 | 456 |
| 25 | 11,70 | 10 | 11 | 12 | 13 | 13 | 14 | 0,1 % | 7,7 % | 10,8 % | 14,3 | 1.321 |
| 50 | 13,79 | 12 | 13 | 14 | 15 | 15 | 16 | 7,2 % | 15,3 % | 35,8 % | 37,2 | 2.913 |
| 100 | 15,26 | 14 | 15 | 16 | 16 | 16 | 16 | 50,0 % | 52,4 % | 79,8 % | 85,7 | 7.646 |
| 200 | 15,93 | 16 | 16 | 16 | 16 | 16 | 16 | 94,2 % | 94,3 % | 99,1 % | 185,1 | 19.333 |

(P10–P95: oyuncuların o yüzdesinin bu sayıda **ya da daha az** araca sahip olduğu değer. Düşük
yüzdelik şanssız oyuncuyu gösterir.)

**16/16 için gereken kasa:** medyan 100, P75 137, P90 178. En şanssız **%5,8** 200 kasada bile
bitiremiyor. Bu da §7.3'teki kuyruk sorununun koleksiyon düzeyindeki karşılığı.

## 17. Risk analizi

### 17.1 Oyuncu deneyimi

| Risk | Durum | Ölçüm / önlem |
|---|---|---|
| Legendary kuyruğu | **Yüksek** | E60 P95 = 107 kasa (~116 gün ACTIVE). §18'de pity olmayan seçenekler |
| Erken hayal kırıklığı | Düşük | 1. gün ACTIVE 7 araç; ilk kasa ücretsiz |
| Kopya yorgunluğu | Orta | 30 günde 43 Common kopyası. Yıldız + hurda her kopyayı küçük bir adıma çevirir |
| Nadirin değersizleşmesi | Düşük | Kopya sahiplik üretmez, ★ güç vermez |
| Grind baskısı | Düşük | HEAVY, ACTIVE'den yalnızca %15 fazla gem alır |
| İlerleme atlama | Düşük | Kasa kapıları (§11) |
| Yarış dengesi | Düşük | D başlangıç, kapılı sınıf erişimi, nadirlik ≠ güç |
| Kayıt ile yeniden çekme | Kapalı | Sonuç satın almada kayda yazılır (§19 Faz 1) |

### 17.2 Manipülasyon ve karanlık desenler — yasak listesi

- Oranlar her zaman görünür ve **sabittir**.
- Açma animasyonu sonucu **değiştirmez**. Sonuç satın almada belli, animasyon yalnızca gösterir.
- "Neredeyse kazandın" animasyonu yok: makara Legendary'nin yanında durmaz.
- Süreli kasa, geri sayım baskısı, "son şans" teklifi yok.
- Ücretli yeniden çevirme yok (Car Town'da vardı; alınmadı).
- Gem gerçek parayla satılmıyor. Satılacaksa ayrı bir karar ve hukuki inceleme gerekir.

### 17.3 Platform ve ülke kuralları

Bugün gem **yalnızca oynayarak** kazanılıyor, yani kasalar hukuken "ücretli loot box" değil.
Yine de:

| Kural | Etkisi |
|---|---|
| Google Play / App Store | Rastgele sanal öğe satışında olasılık açıklaması zorunlu. **Tasarım zaten açıklıyor** |
| Güney Kore (2024) | Olasılık açıklaması yasal zorunluluk; ücretli ve dolaylı (anahtar) alımlar kapsamda |
| Japonya (kompu gacha) | Ücretli çekişle set tamamlama ödülü yasak. Gem satışı gelirse set ödülleri yeniden incelenmeli |
| Belçika (2018) | Ücretli loot box = lisanssız kumar. Gem satışı gelirse Belçika'da kasa satın alma kapatılmalı ya da satın alınan gem kasada geçmemeli |
| Hollanda | 2022 Danıştay kararıyla bugün yasal; yasaklama girişimi sürüyor |
| Birleşik Krallık (2023) | 18 yaş altı için ebeveyn kontrolü + açık oranlar |
| **Brezilya (ECA Digital, 2026-03-17)** | Çocukların erişebileceği oyunlarda loot box yasak. Oyunumuz çizgi-film tarzı ve çocukların erişebileceği bir oyun. **Kazanılan parayla açılan kutunun kapsama girip girmediği net değil; yayından önce hukuki görüş alınmalı** |

**Öneri (kesin ilke):** gem gerçek parayla satılmayacaksa bu belgedeki sistem aynen kalabilir.
Satılacaksa iki para birimi gerekir: kazanılan gem kasa açar, satın alınan gem yalnızca kozmetik
alır.

## 18. Son öneri

1. **Başlangıç:** Tofaş Şahin ücretsiz. Kasa dışı. İlk kasa Sv 2'de ücretsiz (ŞEHİR).
2. **4 kasa, gem ile:**
   - ŞEHİR 30 (Sv 1),
   - AİLE 50 (Sv 10),
   - SPOR 80 (Sv 14),
   - PRESTİJ 120 (Sv 20).
3. **Nadirlik dağılımı:**
   - COMMON 7: Şahin, Getz, Accent, Passat, Fluence, Leon, A3.
   - RARE 4: Era, Focus, Kamiq, S60.
   - EPIC 3: Toros, Golf 7, Civic.
   - LEGENDARY 2: E46, E60.
4. **Olasılık:** araç başına ağırlık C 100 · R 40 · E 15 · L 4. Kasa oranları §7.1. Sabit ve
   ekranda.
5. **Gem kaynakları:**
   - mevcut: 40 başlangıç + 125 hikâye,
   - yeni: seviye, günlük giriş, günlük görev, haftalık hedef, ustalık yıldızı, tamir başarımı,
     bahşiş, ilk keşif, koleksiyon kilometre taşı, kopya hurdası.
   - Sonuç: ACTIVE ~111 gem/gün (1. haftadan sonra), 30 günde ~4.000.
6. **Kopya:** araç yıldızı (★1–5), gem hurdası (2/5/12/30), ★3'te kozmetik, ★5'te küçük garaj
   değeri. Parça/yükseltme yok. Tamamlanan kasa aynı oranlarla sürer + tek seferlik plaket.
7. **Pity yok** (kullanıcı kararı). Legendary kuyruğu (P95 = 107 kasa) **aşırı kötü** olarak
   işaretli. İzleme ölçütü: canlıda "30 gün aktif olup E60'ı olmayan" oranı. Tasarım %80
   öngörüyor.

   Pity olmayan seçenekler, sırayla:
   - (a) günlük görevlerde haftada bir **"PRESTİJ anahtarı"** (ücretsiz kasa); PRESTİJ açma hızını
     ~%15 artırır, kuyruk süresini ~%13 kısaltır; oranları değiştirmez,
   - (b) etkinlik haftası: bir kasanın fiyatı indirimli; oranlar aynı,
   - (c) son çare: yalnızca P95 ötesinde devreye giren sert pity (≥ 100 PRESTİJ).
8. **Showroom:** yalnızca keşfedilmiş araçları ₺ ile geri satar.
9. **Seviye:** araç başına −2 kuralı kaldırıldı; yerine kasa kapıları.
10. **Yarış:** seçilebilir yarış aracı, varsayılan Şahin. Nadirlik ≠ güç.
11. **Setler:** 7 set; plaket + XP + garaj değeri. Nakit/gem yok.
12. **Fiziksel kasa:** Faz 3. Sonuç satın almada kaydedilir.

## 19. Uygulama fazları

**Faz 0 — onay (kullanıcı)**
- Nadirlik tablosu, kasa fiyatları, gem kaynakları, kopya önerisi.
- Legendary kuyruğu için (a)/(b)/(c)'den biri ya da "şimdilik hiçbiri".

**Faz 1 — veri + mantık (UI yok, testli)**
- `vehicles/cars.json`: `rarity` alanı; `CarCatalog.SCHEMA`'ya satır.
- `vehicles/crates.json` (yeni): kasa id, ad, fiyat, `min_level`, havuz. Ağırlıklar tek yerde.
- `gameplay/crate_manager.gd` (yeni, grup `crates`, autoload yok):
  - `odds(crate)`, `can_buy(crate)`,
  - `buy(crate)`: gem düş → **RNG ile sonucu çek** → bekleyen listesine yaz → **aynı kayıt
    yazımında** kaydet,
  - `open(pending_id)`: sahiplik veya kopya → yıldız, hurda, keşif ödülü → sinyal.
- `gameplay/vehicle_ownership.gd`:
  - `_discovered` kümesi, `_dup_count`, `stars(id)`, `buy_back(id)` (yalnızca keşfedilmiş, ₺).
  - `purchase_vehicle` → yalnızca keşfedilmiş araçlar için.
  - `starting_vehicle_id = tofas_sahin`.
- `gameplay/player_progress.gd`: seviye gem ödülü.
- Gem kaynakları: yeni `gameplay/daily_manager.gd` (giriş serisi, günlük/haftalık görev). Ustalık
  yıldızı gem ödülü `job_mastery.gd`'de.
- `gameplay/save_manager.gd` **v10**:
  - `vehicles: {owned, discovered, dups}`,
  - `crates: {pending: [{id, crate, vehicle}], opened: {crate: n}}`,
  - `daily: {last_day, streak, tasks, week}`.
  - Göç: v9 kayıtlarında sahip olunanlar keşfedilmiş sayılır, E46 kalır.
  - Bekleyen kasa bulut kaydında da taşınır (`snapshot_json`).
- Testler (`tests/crate_test.gd`):
  - oran toplamı 1,
  - 1 M çekişte gözlenen oranlar ±0,2 puan içinde,
  - kopya → yıldız/hurda,
  - kapat-aç sonucu değiştirmez,
  - showroom keşfedilmemişi satmaz,
  - v9 → v10 göçü.
- `qa/sim_progress.gd`: kasa açan otomatik oyuncu; 1/3/7 günlük tablo bu belgeyle ±%10.

**Faz 2 — UI (kod ile; `.tscn` düzenlemesi gerekmez)**
- `ui/hud/showroom_screen.gd`: KASALAR / KOLEKSİYON / GERİ AL sekmeleri; kasa kartında oran
  tablosu ve havuz.
- Açılış sunumu mevcut SubViewport'ta. Nadirlik rengi ışık/zemin olarak gösterilir, sonuç
  değiştirilmez.
- `ui/hud/collection_screen.gd` (yeni): 16'da n, kasa grupları, siluet, son parça kartı, ★.
- HUD: gem kazanımı bildirimleri (kuyruklu mevcut sistem), günlük görev plakası.

**Faz 3 — fiziksel kasa + setler**
- Garaj kapısı önünde sabit teslim noktası, en fazla 3 açılmamış kasa.
- Dokunma → animasyon → araç çıkışı → koleksiyon.
- Araç sahnesi satın almada `ResourceLoader.load_threaded_request` ile arkadan yüklenir.
  Showroom'da ölçülen 9–41 ms takılma animasyonla gizlenir.
- Setler: `vehicles/collection_sets.json`, plaket (dekor kataloğunda ödül eşyası), garaj değeri
  kalemi.

**Ayrı küçük iş (önerilir, kasadan bağımsız):** `RaceManager.player_vehicle_id()` → seçili yarış
aracı; varsayılan Şahin.

**Sahne değişikliği:** planlanan adımlar `.tscn` düzenlemesi gerektirmiyor. Gerekirse ayrıca
söylenecek.
