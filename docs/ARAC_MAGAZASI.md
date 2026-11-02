# ARAÇ MAĞAZASI — showroom'da ₺ / gem ile araç (2026-11-02)

Neden: yayın verisinde (docs/EKONOMI_2026_11_02.md) bağlı oyuncunun parası birikiyordu (200–670 bin ₺); araç yalnız
gemle (kasa) ya da hurdalıktan geliyordu, paranın harcanacak yeri yoktu.

## Kullanıcı kararları

- Showroom'da **KASALAR** ve **ARAÇLAR** ayrı kısımlar. Görünüş: taslak **B** (tuval
  https://claude.ai/artifact/RNZi5nf3Jw78hDcA1euXjV) — üstte sekme, altta araç rafı; "araca biraz daha yer ayır, gözüksün".
- Araç **ya ₺ ya gem** ile alınır (ikisinden biri). **Gemle alınan hemen gelir.**
- **₺ ile alınan 24 saatte teslim edilir; her ödüllü reklam 8 saat kısaltır** (3 reklam = hemen).
- **Yalnız gem** (₺ fiyatı yok): MAZURA RZ-7, TOKAYA SUPREMA, NISKA SKYRISE 34, HONZA NZX, MERIDES S-40, MERIDES GD 63
  ve SÜPER KASA'nın tamamı (AUDEX RX6 … BUGANTI CHIRAL) — 14 araç.
- Seviye kilidi kalır (cars.json min_level).
- Fiyatlar onaylandı ("fiyatlar iyi"): tablo `vehicles/car_shop.json` "cars".

Benim kararlarım (kullanıcıya söylendi): aynı anda birden çok sipariş olabilir; hurdalık klasikleri, başlangıç aracı ve
polis mağazada yok; ödemede ikinci dokunuş (EMİN MİSİN?); sipariş beklerken araç kasadan gelirse ₺ iade; satılmış ama
mağazada olmayan araçların eski GERİ AL'ı ARAÇLAR'daki GERİ AL çipine taşındı.

## Fiyat

| | Formül (listede olmayan yeni araç için) | Örnek |
|---|---|---|
| ₺ | değer × nadirlik (yaygın 1,25 · nadir 1,5 · epik 2 · efsane 3), 1.000'e yuvarlı | CIVITA 72.000 × 2 = 144.000 ₺ |
| gem (₺'li araç) | ₺ ÷ (aracın seviyesi × 100), 5'e yukarı yuvarlı — MARKET'in GEM→₺ kuru: bozdurup almakla aynı | 144.000 ÷ 1.800 → 80 gem |
| gem (yalnız gem) | değer × nadirlik ÷ 500, 50'ye yuvarlı | CHIRAL 900.000 × 3 ÷ 500 = 5.400 gem |

Onaylanan tablo Python'la (yarımda çifte yuvarlama) hesaplandı; GDScript `round` yarımı yukarı yuvarlar (5 araçta
1.000 ₺ fark) → fiyatlar dosyada AÇIKÇA yazılı, formül yalnız yedek. Canlı etkinlik araç indirimi (LiveEvent "cars")
iki fiyata da uygulanır. Sonuç: ₺'li araçta gemle almak kasadan ucuz; kasalar yalnız gem araçlar için piyango ve
yıldız (kopya) kaynağı olarak kalır (kullanıcıya söylendi).

## Kod

| Dosya | Görev |
|---|---|
| `vehicles/car_shop.json` | onaylanan fiyatlar, teslim (24 sa) / reklam (8 sa) süreleri, formül sabitleri, yalnız gem kasası |
| `gameplay/car_shop.gd` | CarShop: satış kapsamı, fiyat, durum (AVAILABLE / OWNED / ORDERED / LOCKED), gemle alım, ₺ siparişi, reklamla kısaltma, teslim (1 sn zamanlayıcı + uygulama dönüşü + açılış), iade, kayıt "car_shop" |
| `gameplay/vehicle_ownership.gd` | `grant_purchased`: ödenmiş araç → sahiplik + `vehicle_purchased` (görev cars_bought, analitik) + YERLEŞTİR |
| `ads/ad_policy.gd` | `CAR_DELIVERY` (günde 9, sv3+, repair yuvası); panel `firebase/admin/lib.mjs` AD_KINDS |
| `ui/hud/showroom_screen.gd` | KASALAR / ARAÇLAR sekmesi, raf (çipler + kartlar), plaka, ₺ / gem düğmeleri, reklam düğmesi, kadraj kayması |
| `ui/hud/hud.gd` | "X YOLDA: 24 SAATTE GELİR", "X GELDİ!", iade bildirimi |

Saat: `OfflineEarnings.now()` (Google HTTPS Date başlığına bağlı). İnternetsiz cihaz saatine düşer: saati ileri alan
oyuncu siparişi erken alabilir (pasif gelirdeki bilinen açıkla aynı).

**Sekme yeri (2026-11-02, kullanıcı "kasalar ve araçlar butonunu daha güzel bir yere koy"):** tuval
https://claude.ai/artifact/Cv89wdarF5k2bwJnBiCE5x'de A (ortada büyük anahtar) / B (sol kenar rafı) / C (GERİ'nin yanında)
→ **C**: KASALAR | ARAÇLAR sol üstte GERİ'ye bitişik, koyu zeminli ikili anahtar (`_title_group` PanelContainer);
MAĞAZA tabelası kalktı, KOLEKSİYON sağ üstte.

Ekran (telefon tuvali 853×480): `PlateButton` en az 44 birim yükseklik ve 14 punto yazı zorlar → B taslağındaki
tabelanın altındaki sekme önce tabelanın yanına, sonra (C) GERİ'nin yanına alındı, kartlarda yalnız küçük resim + fiyat / durum (ad sağdaki plakada),
düğmelerin söylediği "24 saatte / hemen" satırları plakada yok. Kadraj ARAÇLAR'da ekranın %17'si sola, %15'i yukarı
kayar ve %12 uzaklaşır (`CARS_VIEW_SHIFT`, `CARS_ZOOM`).

## Test

- `tests/car_shop_test.gd` (run_tests listesinde): fiyat (tablo + formül), kapsam, durum / engeller, gemle alım, ₺
  siparişi, 3 reklam, zamanla teslim, iade, kayıt turu, showroom sekmesi / çipler / kartlar / EMİN MİSİN? / YOLDA çipi.
- `qa/arac_magazasi_qa.gd`: telefon tuvalinde kareler + sığma ölçümü (TR/DE/FR, 1152×648 ve 1440×648);
  kareler `~/Projects/ct_shots/arac_magazasi/`.

## Açık

- OTO MANŞET gazetesine "siparişin geldi" haberi yok (teslimde HUD bildirimi + YERLEŞTİR var).
- Bildirim (push) yok: 24 saat dolunca telefon haber vermez.
