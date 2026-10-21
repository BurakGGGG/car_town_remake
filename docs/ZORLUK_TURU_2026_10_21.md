# Zorluk turu + isim tabelası + SERGİLE (2026-10-21)

Kullanıcı isteği (3 saatlik bağımsız çalışma, "beğenmezsem revize ederiz"):
1. otoparkta duvara isim yazılabilsin — harflerden oluşan, kişiselleştirilebilir tabela,
2. otopark ve depoda SERGİLE düğmesi yok,
3. oyunda çok hızlı ilerleniyor (garaj hemen büyüyor, ~10 araç oluyor),
4. başarımlar çok kolay, ödüle boğuluyorum,
5. garaj genişletme ücretleri çok az,
6. tam test paketi, 7. hata ayıklama.

## 1. İSİM TABELASI
- `world/name_sign.gd` (`NameSign`): her harf ayrı karo, karolar rayın üstünde; 4 stil (KLASİK krem / NEON koyu karo +
  parlayan harf / AHŞAP hafif oynak karolar / METAL), 9 harf rengi (0 = stilin rengi), en çok 16 harf. Metin takma adla
  aynı süzgeçten geçer (`SocialNames.is_valid_title`: karakter kümesi + küfür).
- Yer: `GarageInterior.SIGN_ANCHORS` — otoparkta arka korkuluğun ÜSTÜNDE direklerle (çatı tabelası), depolarda arka
  duvarda pencere / saat / kolonların arasında. Konumlar `qa/name_sign_shots.gd` ile denetlendi
  (`~/Projects/ct_shots/name_sign/` → snap altında `~/snap/godot-4/common/Projects/ct_shots/name_sign/`).
- Kayıt: `CarGarageManager` `signs` bölümü (`sign_of` / `set_sign`, `sign_changed`); otopark her zaman, depo alınmışsa.
- Arayüz: ARAÇLAR ekranında otopark / depo iç mekânındayken sağ üstte HARF tabelası (HudIcon.LETTERS) →
  `ui/hud/name_sign_panel.gd` (yazı, STİL, HARF RENGİ, KAYDET / KALDIR / VAZGEÇ). Her değişiklik anında önizlenir;
  boş tabelada profildeki garaj adı önerilir. Pano açıkken alt raf gizlenir, araç seçilmez.
- Arkadaş ziyareti: depoların tabelası açık garaj JSON'unda deponun satırında (`PublicGarage.depot_layout` → "sign"),
  `VisitDepotsScreen` gösterir. Otopark ziyarette yok (eskiden de yoktu).
- **Ana garaj (GARAJIM, 2026-10-21 ikinci istek):** dekor paletinde DUVAR EŞYASI → İSİM TABELASI (`name_sign`, 2.500 ₺,
  seviye 1, istenen kadar kopya). Sabit boy koyu pano (5 × 1,15 m) + harf karoları; yazı ÖRNEK başına
  (`DecorManager.set_instance_sign` / `instance_sign`, kayıtta örneğin `"sign"` alanı, arkadaşın kaydı da süzgeçten geçer).
  Yazısız tabela "GARAJIM" yazar. Düzenleme kipinde tabelayı seç → YAZI → aynı pano; yeni konan tabelada pano
  kendiliğinden açılır. Depoya kaldırılan tabelanın yazısı silinir. Açık garajla arkadaş ziyaretinde görünür.
  Test `tests/name_sign_test.gd` (run_tests HEADLESS), görsel QA `qa/name_sign_garage_shots.gd`.

## 2. SERGİLE
- ARAÇLAR rafında YARIŞ ile DİĞER arasında garaj ikonlu SERGİLE (yalnız araç depoda / otoparktayken).
  TAŞI → GARAJIMA KOY ile aynı akış (düzenleme kipi, araç parmakta).
- Garajda yer yoksa düzenleme açılmaz: "GARAJINDA YER YOK / EŞYALARI TAŞI YA DA GARAJI BÜYÜT" (`Hud._place_at_home`).

## 3–5. Ekonomi (eski → yeni)

| Ne | Eski | Yeni | Dosya |
|---|---|---|---|
| GARAJI GENİŞLET sv2 / sv3 / sv4 | 36.000 / 90.000 / 180.000 | 90.000 / 260.000 / 650.000 | `gameplay/garage_upgrade.gd` |
| TAMİR HIZI 4 adım | 1.000 / 2.000 / 3.500 / 5.000 | 3.000 / 7.500 / 15.000 / 30.000 | `gameplay/garage_upgrade.gd` |
| 2. / 3. tamir alanı | 5.000 / 12.000 | 15.000 / 40.000 | `gameplay/repair_bay_manager.gd` |
| MAHALLE PARK YERİ | 20 b (5 dk) / 40 b (10 dk) | 40 b (10 dk) / 80 b (20 dk) | `gameplay/car_garage_catalog.gd` |
| SANAYİ PARK YERİ | 100 b (10 dk) / 200 b (20 dk) | 200 b (20 dk) / 400 b (40 dk) | `gameplay/car_garage_catalog.gd` |
| Yarış kazanma ₺ D/C/B/A/S | 450 / 700 / 1000 / 1400 / 2000 | 300 / 480 / 700 / 1000 / 1400 | `gameplay/race/race_manager.gd` |
| Yeni rakip aralığı / yarış sonrası bekleme | 5–10 sn / 12 sn | 10–15 sn / 10 sn (önce 25–45 / 30 denendi, kullanıcı 10–15 istedi) | `gameplay/race/race_manager.gd` |
| Seviye XP eğrisi | 100 × 1,25^(sv−1) | 130 × 1,27^(sv−1) (sv10'a +%42, sv20'ye +%63 XP) | `gameplay/player_progress.gd` |
| Seviye başına gem | 2 (+10 her 5. sv) | 1 (+10 her 5. sv) | `gameplay/player_progress.gd` |
| Kasa gem: şehir / aile / spor / prestij / süper | 30 / 50 / 80 / 120 / 200 | 40 / 65 / 100 / 150 / 250 | `vehicles/crates.json` |
| Başlangıç görev zinciri gemleri | toplam 125 | toplam 63 | `gameplay/quest_catalog.gd` |
| Başarım değeri (yıldız 1–5) | 5 / 15 / 30 / 60 / 100 | 3 / 9 / 20 / 40 / 70 | `gameplay/missions/mission_catalog.gd` |
| Başarım ₺ / XP / gem payı | değer × 60 / × 6 / × 0,2 | değer × 40 / × 5 / × 0,12 | `gameplay/missions/mission_catalog.gd` |
| Başarım eşikleri | ilk yıldızı 1 olan ~15 çizgi | ilk yıldız 2–3+, hepsi yukarı (tablo dosyada) | `gameplay/missions/mission_catalog.gd` |

Neden yarış: rakip 5–10 sn'de bir geliyordu, D sınıfı 450 ₺ ile ardı ardına yarışmak sv1 tamirinden (~370 ₺/dk) fazla
kazandırıyordu → garaj genişletmesi çabuk geliyordu.

Ölçüm (`python3 tools/economy/crate_sim.py days --players 300`, ACTIVE 60 dk/gün; sim eski seviye eğrisini kullanır →
gerçekte daha yavaş). Eski (HEAD cf042c5) → yeni, medyan araç: 1. gün 6 → 4, 3. gün 9 → 6, 7. gün 12 → 9,
30. gün 19 → 15; açılan kasa 30. günde 30 → 21; gem/gün (1→7) 74 → 57, (7→30) 39,5 → 34,8 (hedef 25–35).
`qa/sim_progress.gd` (gerçek oyun ₺ simülasyonu) bu turda koşulmadı — tam paketle aynı anda koşulamıyor.

Değişmeyenler: tamir iş ödülleri, müşteri sıklığı, depo satın alma fiyatları, giriş ödülü, günlük/haftalık görev
ödül oranları (gelire oranlı, kendiliğinden ayarlanır), hurdalık.
