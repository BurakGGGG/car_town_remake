# DRAG RACING 2.0 — Uygulama Raporu

Tasarım ve araştırma notları: `docs/drag_racing_2_design.md`

## 1. Araştırılan oyunlar

CSR Racing 2 (ana referans), CSR Racing, genel mobil drag racing shifting mekanikleri ve
gerçek manuel şanzıman davranışı (power band, close-ratio kutular, short shifting).

## 2. Kaynaklar

- CSR 2 Help Center — Perfect Shift: <https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/5912-how-do-i-get-the-perfect-shift/>
- CSR 2 Help Center — Perfect Start: <https://zyngasupport.helpshift.com/hc/en/55-csr-2/faq/13224-how-do-i-get-the-perfect-start/>
- Gamezebo CSR2 rehberi: <https://www.gamezebo.com/walkthroughs/csr-racing-2-tips-cheats-and-strategies/>
- CSR2 Tuning Guide (shift pattern / deep shift): <https://csr2modding.com/blog/csr2-tuning-guide>
- Perfect Shift Pattern Guide: <https://www.allclash.com/perfect-shift-pattern-guide/>
- Level Winner (launch / wheelspin): <https://www.levelwinner.com/csr-racing-2-tips-cheats-strategies-7-hints-need-know/>
- Wikipedia: Power band, Close-ratio transmission, Short shifting

## 3. Eski sistem (1.0)

- `rpm` gerçek devir değil, `hız / vites_tepe_hızı` ile bulunan 0-1 normalize bir sayıydı.
- Vites kademeleri her araçta aynı geometrik oranla (×0,72) üretiliyordu; gerçek oran tablosu yoktu.
- Vites kalitesinin sonucu **1,3 saniye süren bir ivme çarpanıydı** (erken 0,84 · iyi 1,14 · geç 0,80).
  Yani "iyi vites" fiziksel bir olay değil, bir bonus katsayısıydı.
- Kalkışta yalnızca tepki süresi vardı; kalkış devri, bog ve patinaj yoktu.
- Vites geçişi anlıktı: debriyaj, geçiş süresi ve çekiş kesintisi modellenmiyordu.
- Optimum vites devri bütün araçlarda aynı normalize banttaydı (%72-90).

**Korunanlar:** adım tabanlı `Runner` mimarisi (ekran, rakip ve testler aynı adımı çalıştırıyor),
`Run` özeti, yarış akışı (dünya → davet → pist → geri sayım → yarış → sonuç → garaj), kamera,
kadran sanatı, sonuç ekranı, ödül/XP akışı.

## 4. Yeni sistem (2.0)

```
tekerlek_devri = hız / (2π·r) · 60
motor_devri    = tekerlek_devri · diferansiyel · oran[vites]     (rölanti…sınır arası kırpılır)
tork           = tork_eğrisi(devir) · tepe_tork                   (Nm)
kuvvet         = tork · oran · diferansiyel · verim / r           (N)
direnç         = ½·ρ·Cd·A·v² + Crr·m·g
ivme           = (kuvvet − direnç) / kütle
```

Çekiş limiti `μ·m·g·0,62` aşılırsa **patinaj**: aktarılan kuvvet dinamik sürtünmeye düşer
(×0,78) ve süre ölçülür. Her araç künyesi (`EngineSpec`) katalog statlarından **türetilir**;
hiçbir yerde araç id'sine göre elle değer yazılmaz.

## 5. RPM modeli

- Rölanti 780-900, sınır 6071-7048 (araca göre).
- Tork eğrisi üç kırılım: rölanti → **tepe tork (1,00)** → **tepe güç (0,80)** → **sınır (0,55)**.
  Tepe gücün üstündeki sert düşüş tasarımın kalbi: ideal vites noktası bu yüzden sınırın
  ALTINDA kalır. (Düz bir eğriyle "hep sınıra daya" tek doğru strateji oluyordu — ölçülerek
  görüldü ve düzeltildi.)
- Devir **her adımda** hızdan yeniden hesaplanır; testte 1.274 örnekte hız×oran ile birebir
  uyum doğrulandı. UI'de gösterilen ibre bu değerin ta kendisi (741 örnekte 0 sapma).

## 6. Şanzıman modeli

- 5 veya 6 vites (hızlanma statı ≥ 80 ise 6).
- Oranlar geometrik dizi; **son vites**, tepe güç devrinde katalogdaki son hıza ulaşacak şekilde
  çözülür, **birinci vites** hızlanma statına göre 3,05-3,75 arası.
- Diferansiyel 3,55-4,25 (küçük araçta kısa).
- Tepe tork, hedeflenen 0-100 süresinden (stat 30 → 15,5 sn, stat 100 → 6,0 sn) ölçeklenir.
- **Vites geçişi:** `shift_time` boyunca çekiş kesilir, motor serbest kalır; geçiş bitince devir
  YENİ oranla hesaplanır. Düşüş oran farkının sonucudur — sabit katsayı değil.
  Ölçülen örnek (BMW E46): 6211 → 5539, 6259 → 5176, 6260 → 5080, 6254 → 4997.
- Geçiş süreleri: kusursuz 0,085 · iyi 0,110 · geç 0,150 · erken 0,155 · sınır 0,185 · ıska 0,215 sn.
  **Tek fiziksel ceza budur**; ivme çarpanı yoktur.

## 7. Vites oranları (örnek)

| Araç | vites | oranlar | diferansiyel |
|---|---|---|---|
| BMW E46 | 6 | 3,64 · 2,89 · 2,25 · 1,71 · 1,28 | 3,78 |
| Tofaş Şahin | 5 | 3,41 · 2,88 · 2,38 · 1,94 · 1,54 | 3,89 |
| Hyundai Getz | 5 | 3,54 · 3,01 · 2,53 · 2,10 · 1,72 | 4,23 |
| BMW E60 | 6 | 3,67 · 3,07 · 2,54 · 2,08 · 1,68 · 1,34 | 3,55 |

## 8. Redline

Sınıra dayanınca limitçi torku %12'ye düşürür, devir sınırda tutulur ve orada geçen süre
ölçülür. Ölçüm: 1 sn sınırda kalmak ivmeyi +0,60 m/sn'ye düşürüyor (normalde ~3 m/sn).
Beş vitesi boyunca sınırda tutulan Tofaş Şahin 300 m'yi **19,48 sn**'de bitiriyor
(kusursuz: 14,58 sn).

## 9. Shift zones

Her vites için optimum devir, bir üst viteste aynı hızda üretilen kuvvetin bu vitestekine
**eşitlendiği** devir olarak sayısal çözülür (klasik ideal upshift noktası). Sonuç araca ve
vitese göre değişir: Şahin 5551-5638, E46 6207-6300, Volvo S60 6423-6471.

Kadran sanatı sabit olduğu için motor devri yaya **parçalı** eşlenir: rölanti → yay başı,
o vitesin optimum penceresi → yeşil dilim, sınır → yayın sonu. Yani yeşil dilim her araçta
gerçekten "şimdi at" demektir; kadran doğrusal bir devirölçer değil, **vites zamanlama
göstergesidir**. Gerçek sayısal devir debug katmanında ve `Run` özetinde durur.

Kalite pencereleri: |Δ| ≤ %2,5 **KUSURSUZ**, ≤ %7,5 **İYİ**, altı **ERKEN** (%30'dan fazla
erken ise **IŞKA**), üstü **GEÇ**, sınırda **DEVİR SINIRI**.

## 10. Launch

**2026-09-27 (kullanıcı kararı):** oyuncu kalkış devrini AYARLAMAZ. Geri sayımda araç kalkış
devrinde hazır bekler (ibre yeşil dilimde durur), yeşil yanınca dokunulur ve araç 1. viteste
çıkar. Oyuncunun kalkıştaki becerisi **tepki süresidir**; devirle uğraşmak oyunun ritmini
bozuyordu. Kalkış fiziği modelde aynen duruyor: debriyaj, tekerlek devri motora **yetişene
kadar** kayar (en fazla 1,8 sn) ve güçlü araçlar patinaj yapar. Rakip kendi becerisine göre
farklı devirde kalkmaya devam eder, yani bog/patinaj AI tarafında hâlâ etkili.

Aşağıdaki tarama modelin kalkış devri duyarlılığını gösterir (rakip ve testler bu aralıkta
çalışır; oyuncu her zaman optimumda kalkar):

BMW E46 kalkış taraması (300 m, diğer her şey kusursuz):

| kalkış devri | süre | 60 m | not |
|---|---|---|---|
| 1555 | 14,87 | 6,92 | bog |
| 3111 | 13,22 | 5,31 | bog |
| 3777 | 12,72 | 4,84 | iyi |
| **4444 (optimum)** | **12,48** | **4,62** | kusursuz |
| 5111 | 12,57 | 4,71 | iyi |
| 5777 | 12,68 | 4,81 | geç |
| 6666 | 12,93 | 5,04 | aşırı devir |

## 11. Wheelspin

Çekiş limiti aşılırsa tekerlek boşa döner, aktarılan kuvvet düşer ve süre ölçülür. Güçlü
araçlarda kendiliğinden ortaya çıkıyor (Audi A3, Volvo S60, BMW E60: kalkışta 0,15-1,25 sn).
Zayıf araçlarda hiç görülmüyor — yani patinaj bir "efekt" değil, güç/tutuş dengesinin sonucu.

## 12. AI

Rakip **aynı `Runner`**, aynı fizik. Farkı yalnızca hedeflediği devir: beceri sınıftan gelir
(D 0,35 · C 0,55 · B 0,75 · A 0,90, araç tepki statıyla harmanlanır) ve hedef devir optimumun
etrafında ±%18 (beceri 0) … ±%1 (beceri 1) sapar. Kalkış devri de aynı şekilde sapar.
Test: rakip hiçbir koşuda kusursuz koşudan hızlı değil (hile yok).

## 13. UI

Mevcut 256² kadran sanatı (yüz + bant + ibre) korundu ve artık **gerçek göstergedir**:

- Geri sayımda kadran kalkış devrini gösterir ve ibre yeşilde bekler; yazı "HAZIR OL" →
  son saniyede "YEŞİLDE DOKUN", buton "DOKUN". Dokunuş kalkıştır (gaz tutma yok).
- Yarışta kadran o vitesin **vites penceresini** gösterir; pencereye girince "HAZIRLAN",
  tam ortasında "ŞİMDİ!" yazar ve kadran yanar. Sınırda kırmızı hale + "DEVİR SINIRI! VİTES AT".
- Vites sonrası yazı kaliteyi söyler: KUSURSUZ / İYİ VİTES / ERKEN ATTIN / GEÇ KALDIN /
  SINIRDA ATTIN / IŞKA.
- Vites numarası modelin kendi vites sayısından gelir (5 ya da 6).
- **Debug katmanı** (`DRAG_DEBUG=1`): devir, vites, hız, mesafe, geçiş/patinaj/sınır/debriyaj
  bayrakları, isabet sayısı, rakip durumu. Yayında hiç kurulmaz.

## 14. 16 araç dengesi

```
araç                   sf   vits sınır  optim kalkş kusrsz    iyi  zayıf   fark
bmw_e46                A       6  6813   6207  4444  12.49  12.62  13.04   0.55
hyundai_getz           C       5  6630   6122  4225  13.82  13.95  14.34   0.52
renault_fluence        B       5  6849   6282  4423  12.62  12.73  13.08   0.47
vw_passat_b55          B       5  6601   6051  4221  12.89  13.01  13.38   0.49
hyundai_era            C       5  6499   5951  4099  13.76  13.87  14.26   0.50
renault_toros          D       5  6131   5608  3814  14.44  14.56  14.91   0.47
tofas_sahin            D       5  6071   5551  3751  14.58  14.70  15.08   0.50
hyundai_accent_blue    C       5  6675   6116  4239  13.41  13.52  13.89   0.48
ford_focus             C       5  6751   6188  4317  13.17  13.28  13.66   0.49
skoda_kamiq            B       5  6944   6368  4470  12.91  13.02  13.42   0.51
vw_golf_7              B       6  6937   6317  4495  12.90  13.03  13.44   0.54
seat_leon              B       6  6991   6368  4545  12.74  12.87  13.28   0.54
honda_civic            B       6  6910   6295  4500  12.57  12.70  13.11   0.54
audi_a3                A       6  7034   6410  4604  12.42  12.55  12.97   0.56
volvo_s60              A       6  7048   6423  4605  12.23  12.36  12.76   0.52
bmw_e60                A       6  6955   6340  4567  11.97  12.09  12.48   0.52
```

("kusrsz" = optimum vitesler, "iyi" = %93 devirde, "zayıf" = %78 devirde, "fark" = zayıf−kusursuz)

Sınıf ortalamaları: **A 12,28 · B 12,77 · C 13,54 · D 14,51 sn** — progression sırası korunuyor.
Araçlar karakter olarak da ayrışıyor: Şahin/Toros düşük devirli (6071/6131), 5 vitesli, erken
vites isteyen sakin araçlar; Volvo/Audi/E60 yüksek devirli (7048/7034/6955), 6 vitesli, patinaj
yapabilen güçlü araçlar; Getz kısa oranlı (diferansiyel 4,23) ama düşük torklu.

## 15. Test sonuçları

Yeni paket `drag_transmission_test.gd` — **38 kontrol, 0 hata**:
künye tutarlılığı, devirin rölantiden tırmanması, vites sonrası düşüş, düşüşün oranla uyumu,
tekrar tırmanma, sınırın aşılamaması, limitçinin ivmeyi kesmesi, erken/kusursuz/geç/sınır
sürelerinin sıralanması, bog ve aşırı devir kalkışının optimumdan yavaş olması, patinajın
ortaya çıkması, AI'nin aynı fiziği kullanması ve hile yapmaması, determinizm, 16 aracın
tamamının çalışması, sınıf sıralaması, devir-hız birebir uyumu.

Tüm paketler (regresyon dahil): **767 kontrol, 0 hata**
(save 27 · edge 34 · quest 28 · paint 27 · cloud 50 · **drag_transmission 38** · ui 47 ·
race 49 · progression 33 · vehicle_asset 328 · vehicle_scale 106).

### Shift pattern testi (Faz 19) — BMW E46, 300 m

| desen | süre | sınırda | fark |
|---|---|---|---|
| çok erken (%75) | 13,133 | 0,00 | +0,64 |
| erken (%90) | 12,775 | 0,00 | +0,28 |
| **kusursuz (optimum)** | **12,492** | 0,00 | — |
| geç (%105) | 12,575 | 0,00 | +0,08 |
| devir sınırında | 12,783 | 0,04 | +0,29 |
| rastgele | 12,658 | 0,00 | +0,17 |

### Optimum arama (Faz 20)

Kaba→ince koordinat inişi (3 tur, vites başına 9 deneme) ile aranan en hızlı desen,
**dört araçta da** modelin analitik "kusursuz" noktasıyla birebir aynı çıktı
(Şahin, Getz, Civic, E60 → fark 0,000 sn).

Yani bizim modelde yeşil dilim gerçekten teorik optimumdur. CSR2'de böyle olmak zorunda
değil (gücü aşağıda olan araçlarda erken, yukarıda olan araçlarda derin shift daha hızlı
olabiliyor); bizde model kendi içinde tutarlı olduğu için "gizli desen" yok. Oyuncunun beceri alanı **tepki süresi** ile **dar kusursuz vites bandını yakalamak**.

## 16. Before / after

| | Eski (1.0) | Yeni (2.0) |
|---|---|---|
| BMW E46 kusursuz | 12,49 sn* | 12,49 sn |
| Vites sonrası devir | sabit ×0,72 | 6211→5539, 6259→5176, 6260→5080 (viteste değişir) |
| Erken/kusursuz farkı | çarpan kaynaklı | **0,64 sn** (fizik kaynaklı) |
| Sınırda tutma cezası | ivme ×0,15 | Şahin: 14,58 → **19,48 sn** |
| Kalkış devrinin etkisi | **yok** | modelde var (bog 14,87 ↔ optimum 12,48 ↔ aşırı 12,93); oyuncu optimumda kalkar, rakip becerisine göre sapar |
| Patinaj | yok | güçlü araçlarda 0,15-1,25 sn |

(*) Eski sistemin süreleri de benzer bantta tutuldu ki ekonomi ve rakip eşleşmesi bozulmasın.

## 17. Performans

Drag ekranı: **304 FPS ort · 224 çizim · 111,0 MB · 19 ms açılış** — yeniden yazımdan önceki
değerlerle aynı (294/227/111,0/18). `step()` hiçbir dizi/sözlük/metin ayırmaz; tek ayırma
yarış başına 5 elemanlık `shift_log`. Künyeler `_specs` sözlüğünde önbelleklenir, yarış
başlangıcında türetme yapılmaz. Sabit adım (1/120 sn) → kare hızından bağımsız ve deterministik.

## 18. Değiştirilen dosyalar

| Dosya | Değişiklik |
|---|---|
| `gameplay/race/drag_race_sim.gd` | Tamamen yeniden yazıldı (317 → 640 satır): EngineSpec, gerçek fizik, kalite/kalkış/patinaj |
| `ui/hud/drag_race_screen.gd` | Kalkış devri girişi (basılı tut/bırak), kadran eşlemesi, kalite yazıları, rakip AI, debug katmanı |
| `docs/drag_racing_2_design.md` | YENİ — araştırma + tasarım |
| `docs/drag_racing_2_report.md` | YENİ — bu rapor |
| `qa/drag_lab.gd` | YENİ — shift pattern / kalkış taraması / optimum arama / denge tablosu |
| `qa/drag_trace.gd`, `qa/drag_model.gd`, `qa/drag_play.gd` | YENİ — devir izi, künye dökümü, gerçek oynanış doğrulaması |
| `~/snap/godot-4/common/cloudtest/drag_transmission_test.gd` | YENİ — 38 kontrol |
| `tools/run_tests.sh` | Yeni paket eklendi |

## 19. Kalan problemler

1. **Kadran doğrusal bir devirölçer değil.** Sanat sabit olduğu için devir yaya parçalı eşleniyor.
   İbre her zaman gerçek simülasyon durumunu gösteriyor (0 sapma ölçüldü) ama "ibre %50'de =
   devir %50" değil. Doğrusal bir gösterge için bant sanatının araca göre yeniden çizilmesi
   (ya da kodla çizilmesi) gerekir.
2. **Yeşil dilim = teorik optimum.** CSR2'deki "bazı araçlarda gizli daha iyi desen" nüansı
   bizde yok; eklemek için tork eğrisine araca özgü düzensizlikler koymak gerekir.
3. **Son viteste kadran doğrusal.** Atılacak vites olmadığı için yeşil dilim anlamsız; şu an
   devir sınıra göre doğrusal gösteriliyor.
4. **Patinaj görseli yok.** Süre ve kuvvet kaybı modelde var, ekranda lastik dumanı/titreşim
   eklenmedi (mevcut kalkış dumanı dışında).
5. **Kütle ve tork türetmesi kaba.** Gerçek araç ağırlıkları yerine boy/genişlikten tahmin
   ediliyor; sınıf sıralaması doğru ama mutlak değerler yaklaşık.
