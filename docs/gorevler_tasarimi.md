# GÖREVLER — Tasarım (günlük · haftalık · başarımlar)

Durum: tasarım + uygulama tamam (2026-10-04). Kod: `gameplay/missions/`, arayüz: `ui/hud/mission_screen.gd`.
Test: `tests/mission_test.gd`, simülasyon: `qa/mission_sim.gd`.

## 1. Amaç ve ilkeler

Üç ayrı ihtiyaç, üç ayrı alan:

| Alan | Zaman ufku | Oyuncuya ne söyler | Ödül |
|---|---|---|---|
| **GÜNLÜK** | 1 oturum | "Bugün bunu yap" — 5 görev | her görev minik (₺ + XP); beşi birden → **gem** |
| **HAFTALIK** | 1 hafta, 2–4 oturum | "Bu hafta bunun peşinde ol" — 5 zor görev, günlüklerin tamamlayıcısı | her görev orta; beşi birden → **büyük ödül** (gem + bedava kasa) |
| **BAŞARIMLAR** | oyunun ömrü | "Ustalık yolu" — yıldızlı, giderek zorlaşan hedefler | her yıldız ayrı ödül |

Sektörde (mobil canlı oyunlar, Hearthstone/HotS/Roblox görev rehberleri, "daily quest" glossary'leri)
tekrar eden ilkeler ve bu tasarımdaki karşılıkları:

1. **Günlük görev tek oturumda bitebilmeli; haftalık 2–3 oturumda.** → hedefler oyuncunun KENDİ tipik
   günlük/haftalık performansından türetilir (§4), sabit sayı değil.
2. **Ödül pasif kazancın anlamlı biçimde üstünde olmalı ama ekonomiyi bozmamalı.** → günlük görev ödülü
   bir oyuncunun 1–3 dakikalık geliri kadar (minik); asıl değer "tamamlama bonusu"nda (§6).
3. **Çeşitlilik.** → her gün farklı *kategorilerden* görev (tamir, kazanç, yarış, büyüme, koleksiyon,
   stil); aynı kategoriden en çok 2 görev; dünkü görevler tekrar edilmez.
4. **Havuzdan ağırlıklı seçim, oyuncuya özel.** → sabit liste yok: ~28 şablonluk havuz, her gün oyuncunun
   durumuna (seviye, garaj, alan, araç, bakiye) ve geçmişine göre süzülüp ağırlıklandırılır.
5. **Zorluk kademeleri.** → günlük 5 slot: 2 KOLAY · 2 ORTA · 1 ZOR. Haftalık hepsi ZOR.
6. **Kaçırma suçluluğu yaratmama.** → seri kırılsa bile ceza yok; görevler birikmez; bir gün oynamayan
   ertesi gün daha kolay hedef alır (DDA, §4.4). Karanlık desen yasak listesi (docs/vehicle_crate_design_v2.md
   §17.2) bu sistem için de geçerli: süre baskısı yok, ödül kaybı yok, para karşılığı görev yenileme yok.
7. **Anlaşılır.** → tek cümlelik görev ("20 TAMİR YAP"), ilerleme şeridi, ödül önizlemesi.

## 2. Mimari

```
olaylar (RepairManager, RaceManager, CrateManager, VehicleOwnership, DecorManager, ...)
        │
        ▼
MissionTracker  ── sayaçlar: yaşam boyu · bugün · bu hafta · son 14 gün geçmişi
        │
        ├─► MissionGenerator (saf, tohumlu)  ── günlük 5 + haftalık 5 görev üretir
        │
        ▼
MissionManager ("missions" grubu)  ── görev durumları, ödül (claim), gece yarısı, kayıt
        │
        ▼
MissionScreen (GÖREVLER tabelası: GÜNLÜK | HAFTALIK | BAŞARIMLAR [| REHBER])
```

* **Tek sayaç kaynağı:** görevler kendi sayacını tutmaz. Her görev `(metrik, hedef)` çiftidir ve ilerleme
  ilgili DÖNEM sayacından okunur (günlük → bugünün sayacı, haftalık → haftanın, başarım → yaşam boyu).
  Böylece aynı olay üç alanı birden besler ve çifte sayım olmaz.
* **Durum metrikleri** (garaj seviyesi, araç sayısı, rütbe, ustalık yıldızı, oyuncu seviyesi) sayaç değil,
  oyunun o anki durumundan okunur (başarımlarda).
* **Saat:** gün/hafta anahtarları `GemRewards`'ın saatinden gelir (tek saat kaynağı; test için `test_now`,
  geri alma koruması orada). Gün değişince `GemRewards.day_changed` yayılır, MissionManager yeni günü kurar.
* **GemRewards'ın payı:** giriş serisi, bahşiş ve ustalık yıldızı gemi orada kalır. Eski günlük görev (3
  sabit tür) ve haftalık hedef (12 günlük görev → 100 gem) buraya TAŞINDI; tamir kilometre taşları
  (50/250/1.000/2.500/5.000 tamir) TAMİRCİ başarımının yıldızları oldu (aynı gem miktarları, çifte ödeme
  yok — eski `repair_step` göçte yıldızlara çevrilir).
* **REHBER sekmesi:** mevcut başlangıç görev zinciri (QuestCatalog / QuestManager: İLK KASA, ÇIRAK, HIZLI
  ELLER …) öğretici işlevi görüyor ve ilk kasayı veriyor; silmek yeni oyuncuyu yönsüz bırakır. Zincir bitene
  kadar sekme çıkar, bitince kaybolur (kullanıcıya sorulacak karar: §10).

## 3. Metrik kataloğu (olay → sayaç)

Hepsi mevcut sinyallerden beslenir; tek yeni sinyal ihtiyacı var (işaretli).

| Metrik | Kaynak olay | Not |
|---|---|---|
| `repairs` | `RepairManager.repair_collected` | PARA TOPLA ile biten tamir |
| `repair_money` | aynı (ödül) | ₺ |
| `job_<id>` (`engine, brakes, tires, body, paint_job, upholstery, brake_overhaul`) | **YENİ** `RepairManager.job_collected(job_id, reward)` | iş türü sayacı |
| `long_jobs` | `job_collected` (paint_job/upholstery/brake_overhaul) | uzun iş |
| `races`, `race_wins` | `RaceManager.race_finished(won,…)` | |
| `race_money` | aynı | ₺ |
| `crates_opened` | `CrateManager.crate_opened` | |
| `crates_bought` | `CrateManager.crate_added` (source=gems) | |
| `paints` | `VehicleOwnership.paint_purchased` | |
| `growth_buys` | `GarageUpgradeManager.upgrade_purchased` + `RepairBayManager.bay_unlocked` | garaj/hız/alan |
| `decor_placed` | `DecorManager.instance_added` (**YENİ** sinyal) | araç sergisi dahil |
| `cars_displayed` | aynı (item "car:…") | |
| `decor_bought` | `DecorManager.purchased` | |
| `money_spent` | `EconomyManager.money_spent` (**YENİ** sinyal) | her harcama |
| `levels` | `PlayerProgress.level_up` | |
| `days_played` | MissionManager (gün değişince bir kez) | yaşam boyu gün sayısı |
| `daily_done`, `daily_all`, `weekly_done`, `weekly_all` | MissionManager | görev ilerlemesi |

Durum metrikleri (başarımlar): `player_level`, `garage_level`, `bays`, `garage_rank`, `cars_discovered`,
`job_stars`, `cars_on_display`, `login_streak_best`, `ach_stars`.

## 4. Günlük görev üretimi (kişiselleştirme)

### 4.1 Girdi: oyuncu profili

```
level, garage_level, bays, owned_cars, money, gems
unlocked_jobs[]            RepairType: min_level ≤ level, min_garage_level ≤ garage, min_bays ≤ bays
typical{metric}            son 7 AKTİF günün medyanı; geçmiş yoksa seviyeden ön-kabul (prior)
active_days_14             son 14 günde kaç gün oynandı (haftalık hedef çarpanı)
used_recently{category}    son 7 günde o kategoride hiç iş yapıldı mı (nudge için)
difficulty (DDA)           0,65 … 1,35 (başlangıç 1,0)
yesterday_ids[]            dünkü şablonlar (tekrar önleme)
income_per_min, avg_xp     açık işlerin ağırlıklı ortalama ödülü/XP'si × garaj ödül çarpanı
```

### 4.2 Tohum — "A kullanıcıya başka, B kullanıcıya başka"

`seed = hash(player_seed, day_key)`. `player_seed` ilk açılışta rastgele üretilip kayıtta saklanır:
aynı gün cihaz yeniden başlasa görevler DEĞİŞMEZ (yeniden-çekme ile istediğini seçme yok), iki oyuncu aynı
gün aynı durumda olsa bile farklı görev alır. Üretim saf bir fonksiyondur (test edilebilir, simüle edilir).

### 4.3 Slotlar ve seçim

| Slot | Kademe | Kural |
|---|---|---|
| 1 | KOLAY | **konfor görevi**: TAMİR ya da KAZANÇ ailesi (oyuncunun zaten yaptığı şey; kesin tamamlanır) |
| 2 | KOLAY | slot 1'den farklı kategori; yarış/stil/büyüme tercih edilir |
| 3 | ORTA | farklı kategori |
| 4 | ORTA | farklı kategori |
| 5 | ZOR | tamir-hacmi / kazanç / yarış zaferi / uzun iş gibi emek isteyen |

Her slot için aday = şablon havuzu − (açılmamış özellik) − (bugün zaten seçilmiş metrik) − (kategori tavanı
dolu). Ağırlık:

```
w = taban_ağırlık
  × 0,25   eğer şablon dün de vardı            (tekrar önleme; hiç aday kalmazsa gevşer)
  × 1,6    eğer kategori son 7 günde kullanılmadı ve gün içinde nudge hakkı var   (en çok 1 nudge)
  × 1,3    eğer oyuncunun son 7 gün en çok yaptığı kategori                        (konfor)
```

Sonra tohumlu RNG ile ağırlıklı çekim. Slot 1'de yalnızca TAMİR/KAZANÇ ailesi çekilir (ilke 3 + tamamlanabilirlik).

### 4.4 Hedefler: oyuncunun temposuna göre

`hedef = güzel_yuvarla( tipik[metrik] × kademe_çarpanı × DDA )`, kademe çarpanları **KOLAY 0,35 · ORTA 0,65 ·
ZOR 1,05**; ayrıca hedef `tipik × 1,05`'i aşmaz (ZOR ≈ "bugün de her zamanki gibi oynarsan biter, biraz
zorlanırsan kaçırırsın"). Tipik değerler yoksa (yeni oyuncu / yeni kategori) şablonun alt sınırı kullanılır. Alt/üst sınırlar şablon başına verilir.
Ön-kabul (yeni oyuncu): `tamir/gün ≈ 18 + 3·seviye` (üst sınır 150), `kazanç = tamir × ort. ödül`,
`yarış = 2`, `kasa = 1`.

**DDA (dinamik zorluk):** gün sonunda (gece yarısı) dünkü sonuca bakılır — yalnızca oynanmış günler sayılır:
5/5 → `×1,05` (üst sınır 1,30) · 4/5 → değişmez · 3/5 → `×0,97` · ≤2/5 → `×0,92` (alt sınır 0,65).
Hiç oynamadı → değişmez. Oyuncu kaçırınca cezalandırılmaz, sıkılınca zorlaşır.

**"Güzel yuvarlama":** tamir sayısı 5'in, ₺ miktarı büyüklüğüne göre 50/100/500/1.000'in katı.

### 4.5 Şablon havuzu (günlük) — 28 şablon

Kategori: TAMİR (T), KAZANÇ (K), İŞ (İ), YARIŞ (Y), BÜYÜME (B), KOLEKSİYON (C), STİL (S).

| Id | Kat. | Kademe | Metin | Metrik | Şart (açık olması için) | Taban ağırlık |
|---|---|---|---|---|---|---|
| `rep_e` | T | K | N TAMİR YAP | repairs | seviye ≥ 3 | 10 |
| `rep_m` | T | O | N TAMİR YAP | repairs | | 8 |
| `rep_h` | T | Z | N TAMİR YAP | repairs | | 7 |
| `earn_e` | K | K | TAMİRDEN N ₺ KAZAN | repair_money | | 10 |
| `earn_m` | K | O | | repair_money | | 8 |
| `earn_h` | K | Z | | repair_money | | 7 |
| `job_<id>` ×7 | İ | O | N ADET <İŞ> TAMAMLA | job_<id> | işin kilidi açık | 5 |
| `long_m` | İ | O | N UZUN İŞ TAMAMLA | long_jobs | en az bir uzun iş açık | 6 |
| `long_h` | İ | Z | N UZUN İŞ TAMAMLA | long_jobs | | 5 |
| `race_e` | Y | K | N YARIŞA KATIL | races | seviye ≥ 3 | 9 |
| `race_m` | Y | O | N YARIŞA KATIL | races | | 7 |
| `race_win_m` | Y | O | N YARIŞ KAZAN | race_wins | | 6 |
| `race_win_h` | Y | Z | N YARIŞ KAZAN | race_wins | | 5 |
| `spend_m` | B | O | N ₺ HARCA | money_spent | seviye ≥ 6 | 6 |
| `growth_m` | B | O | BİR GARAJ GELİŞTİRMESİ AL | growth_buys | alınabilir bir şey var ve (bakiye + tipik gelir ≥ maliyet) | 6 |
| `crate_open_m` | C | O | N KASA AÇ | crates_opened | bekleyen kasa var ya da gem ≥ en ucuz kasa | 7 |
| `crate_buy_e` | C | K | BİR KASA SİPARİŞ ET | crates_bought | gem ≥ en ucuz kasa | 6 |
| `paint_m` | S | O | BİR ARACI BOYA | paints | boya açık, gem ≥ 15 | 5 |
| `decor_e` | S | K | N EŞYA YERLEŞTİR | decor_placed | seviye ≥ 4, deposunda ya da alabileceği eşya var | 6 |
| `display_e` | S | K | BİR ARACINI SERGİLE | cars_displayed | sahip ≥ 2, seviye ≥ 4 | 5 |

Hedef sınırları (`min–max`, hepsi `güzel_yuvarla`): `rep_*` 8–220 · `earn_*` 300–60.000 · `job_*` 3–18 ·
`long_*` 1–10 · `race_*` 1–5 · `race_win_*` 1–4 · `spend_m` 500–100.000 · `crate_open_m` 1–3 ·
`decor_e` 1–4.

### 4.6 Garanti: tamamlanabilirlik

Üretici şunları doğrular (ve `qa/mission_sim.gd` yüzlerce profil üzerinde sınar):
* 5 görev, 5 FARKLI metrik, kategori başına ≤ 2, slot 1 ∈ {T, K}.
* Hiçbir görev açılmamış bir özelliğe bağlı değil; hiçbir hedef oyuncunun tipik günlüğünün 1,05 katını aşmıyor.
* Aynı tohum + aynı profil → birebir aynı çıktı. Farklı `player_seed` → en az bir görev farklı (ölçülen).
* Dünkü şablonlarla kesişim ≤ 1.

## 5. Haftalık görevler (5 ZOR, günlüklerin tamamlayıcısı)

Pazartesi 00:00 yenilenir. Hepsi haftanın sayacından ilerler ve günlük görevlerle AYNI olaylardan
beslenir — günlükler "bugün" için, haftalıklar "uzun soluk" için.

| # | Rol | Şablon | Hedef |
|---|---|---|---|
| 1 | **Hacim** | `w_repairs`: N TAMİR YAP | `tipik tamir/gün × beklenen aktif gün × 0,9` |
| 2 | **Kazanç** | `w_earn`: TAMİRLERDEN N ₺ KAZAN | aynı mantık, `repair_money` |
| 3 | **Günlük bağı** | `w_daily`: N GÜNLÜK GÖREV TAMAMLA | 12 (yeni) … 22 (haftada 35 görev) |
| 4 | **Çeşitlilik / nudge** | havuzdan 1 (aşağıda) | kademeli |
| 5 | **Zor hedef** | havuzdan 1 | zor |

Havuz (4. ve 5. slot): `w_race_wins` (N yarış kazan), `w_crates` (N kasa aç), `w_long` (N uzun iş),
`w_paints` (2 boya), `w_decor` (N eşya yerleştir), `w_spend` (N ₺ harca), `w_growth` (2 geliştirme),
`w_days` (5 farklı gün oyna), `w_perfect` (3 günün tüm görevlerini bitir). Slot 4 oyuncunun KULLANMADIĞI
kategoriden (nudge), slot 5 en çok kullandığı kategoriden ya da `w_days`/`w_perfect`.

`beklenen aktif gün` = son 14 günün aktif gün sayısının yarısı (varsayılan 4; sınır 2,5–5): haftada 2 gün
oynayan oyuncuya 6 günlük hedef verilmez. Haftalık çarpan **0,8** (haftalık hedef "alışkanlığını sürdürürsen
çoğu zaman biter").

## 6. Ödül ekonomisi

Hedef: görev ödülü *hissedilsin ama* ekonomiyi (ölü para sorunu, gem enflasyonu — docs/AUDIT §6,
vehicle_crate_design_v2 §3) bozmasın.

### 6.1 Günlük
* **Her görev:** ₺ + XP = oyuncunun **tipik günlük** kazancının / XP'sinin payı: **KOLAY %2 · ORTA %4 ·
  ZOR %7** (beşinin toplamı ≈ %19: "minik"), alt sınır yarım dakikalık gelir. Tipik değer oyuncunun
  geçmişinden gelir (yoksa seviyeden ön-kabul; ön-kabul açık işlerin ağırlıklı ortalama ödülü × garaj
  ödül çarpanı × 3,4 tamir/dk'dan türer) — yani seviye / garaj / tempo ile kendiliğinden ölçeklenir.
* **Beşi birden:** **+40 gem** (eski: 3×10 + 20 = 50). Haftalıkla birlikte 30 günlük gem bütçesi eskisinden ~%15 aşağıda.
* Görev ödülü ÖDÜLÜ AL ile alınır (otomatik değil: oyuncu tamamlanmış görevi görür); "HEPSİNİ AL" düğmesi var.

### 6.2 Haftalık
* **Her görev:** ₺ + XP (tipik HAFTALIK kazancın / XP'nin %3'ü) + 10 gem.
* **Beşi birden (BÜYÜK ÖDÜL):** **120 gem + bedava kasa** (oyuncunun seviyesine göre en iyi açık kasa: şehir/aile/spor/prestij) +
  XP. Günlükle birlikte tam katılan bir oyuncu haftada ≈ 280 + 50 + 120 = 450 gem; eski sistemde ≈ 350–450.

### 6.3 Başarımlar
Yıldız başına ödül, çizgiye göre ölçeklenir: `gem = 5 · 15 · 30 · 60 · 100` (1…5. yıldız) × çizgi zorluk
çarpanı (0,6 … 1,5), + küçük ₺ ve XP. Tamir çizgisi eski kilometre taşlarının gemini AYNEN korur
(10/20/30/50/75). Tüm çizgilerin tavan toplamı ≈ 1.600 gem ve **aylara yayılır** (son yıldızlar
saatlerce oyun ister); bu, 30 günlük gem gelirinin (≈ 4.000) %40'ı — kasıtlı: "oyunu bitirme" başarımları
koleksiyon sonrası birikimi emsin diye.

## 7. Başarım kataloğu

| Çizgi | Metrik (yaşam boyu) | Yıldız eşikleri | Gem ×(zorluk) |
|---|---|---|---|
| TAMİRCİ | `repairs` | 50 · 250 · 1.000 · 2.500 · 5.000 | 10/20/30/50/75 (eski) |
| KAZANÇLI | `repair_money` | 10.000 · 100.000 · 1.000.000 · 5.000.000 | 1,0 |
| HARCAMACI | `money_spent` | 20.000 · 200.000 · 1.000.000 · 5.000.000 | 0,8 |
| YARIŞÇI | `race_wins` | 3 · 15 · 50 · 150 | 1,0 |
| ARENA | `races` | 10 · 50 · 200 | 0,6 |
| KASA AVCISI | `crates_opened` | 3 · 15 · 50 · 150 | 0,9 |
| KOLEKSİYONCU | `cars_discovered` (durum) | 3 · 6 · 10 · 14 · 16 | 1,5 |
| BOYACI | `paints` | 1 · 5 · 20 | 0,7 |
| DEKORATÖR | `decor_placed` | 5 · 20 · 50 · 100 | 0,7 |
| SERGİCİ | `cars_on_display` (durum) | 1 · 3 · 6 · 10 | 0,8 |
| GARAJ USTASI | `garage_level` (durum) | 2 · 3 · 4 | 1,0 |
| ALAN SAHİBİ | `bays` (durum) | 2 · 3 | 0,8 |
| DEĞERLİ GARAJ | `garage_rank` (durum) | 3 · 5 · 7 · 10 | 1,2 |
| USTA | `job_stars` (durum) | 5 · 12 · 20 · 28 · 35 | 1,0 |
| SEVİYE | `player_level` (durum) | 5 · 10 · 20 · 30 · 50 | 1,0 |
| SADAKAT | `days_played` | 3 · 7 · 30 · 100 · 365 | 1,0 |
| SERİ | `login_streak_best` | 3 · 7 · 14 · 30 | 0,9 |
| GÖREV AVCISI | `daily_done` | 10 · 50 · 200 · 600 | 0,8 |
| MÜKEMMEL GÜN | `daily_all` | 3 · 15 · 50 · 150 | 1,0 |
| HAFTA YILDIZI | `weekly_all` | 1 · 4 · 12 · 26 | 1,2 |
| YILDIZ TOPLAYICI | `ach_stars` (meta) | 10 · 25 · 50 · 80 | 1,0 |
| **EFSANE GARAJ SAHİBİ** | bileşik (16 araç + garaj Sv.4 + 3 alan + rütbe 10 + 35 ustalık yıldızı) | 1 yıldız | 500 gem |

Başarımlar geriye dönük başlar: durum metrikleri mevcut oyundan okunur; `repairs` JobMastery
toplamından, eski kilometre taşları ödenmiş yıldız olarak taşınır. Sayaç metrikleri (kazanç, harcama,
yarış, kasa …) 0'dan başlar: eski oyuncuya geriye dönük sayaç UYDURULMAZ.

## 8. Zaman, gece yarısı ve güvenlik

* **Gün/hafta sınırı = yerel 00:00** (hafta Pazartesi). `GemRewards.day_key/week_key`.
* Gün değişince: (1) dünün sayaçları geçmişe yazılır (son 14 gün), (2) DDA güncellenir, (3) yeni 5 görev üretilir,
  (4) ödülü ALINMAMIŞ tamamlanmış dünkü görevler **kaybolmaz**: gün değişimine kadar AL denmemişse otomatik
  alınır (oyuncu cezalandırılmaz, ödül notu "DÜNÜN GÖREV ÖDÜLLERİ" gösterilir).
* **Saat geri alınırsa:** gün ilerlemediği için hiçbir şey yeniden üretilmez/sıfırlanmaz (GemRewards kuralı).
  İleri alınırsa yalnızca o günün/haftanın görevleri gelir; ödüller işaretlidir, iki kez verilmez.
* **Kayıt:** `SaveManager` "missions" alanı; eski kayıtta yoktur → boş başlar, bugün görevleri ilk açılışta üretilir.
  Atomik kayıt (v10) ve bulut kaydı aynı sözlüğü taşır.

## 9. Arayüz

GÖREVLER plakası (sağ üst) tek tabela açar: üstte sekmeler **GÜNLÜK · HAFTALIK · BAŞARIMLAR** (+ kayıtlıysa
REHBER). Plakada bekleyen ödül sayısı (toplam) görünür ve amber olur.

* **GÜNLÜK:** 5 satır (ad, ilerleme şeridi, ödül özeti, ÖDÜLÜ AL); altta "BÜTÜN GÖREVLER → 40 GEM" şeridi,
  yenilenmeye kalan süre (örn. "YENİLENİR 05:12").
* **HAFTALIK:** 5 satır + büyük ödül şeridi (gem + kasa) + yenilenme süresi.
* **BAŞARIMLAR:** kaydırılabilir çizgiler; her satırda ad, yıldızlar (★★☆☆☆), sıradaki eşik şeridi, ödül, ÖDÜLÜ AL.
* Kısa ekranda (480 birim) başlık ve KAPAT sabit, gövde dokunmatik kaydırma (ui/touch_scroll.gd).
* Tamamlanan görev anında kısa bildirim plakası: "GÜNLÜK GÖREV TAMAM".

## 10. Kullanıcıya sorulan / varsayılan verilen kararlar

1. **REHBER sekmesi** (başlangıç zinciri) — varsayılan: korundu, zincir bitince kaybolur.
2. **Görev yenileme (reroll):** ilk sürümde YOK; 2. aşama önerisi: günde 1 ücretsiz değiştirme. Ücretli yenileme yok (ilke 6).
3. **Reklamlı görevler:** yok (görev sistemi reklama bağlanmaz).
4. **Günlük görev açılış seviyesi:** 3 (eski kural). 1–2. seviyede REHBER zinciri yeter.

## 11. Doğrulama planı

* `tests/mission_test.gd`: üretici (tohum kararlılığı, çeşitlilik, kilit, tekrar önleme, hedef sınırları, farklı
  oyuncular), sayaçlar (olay → metrik), günlük/haftalık ilerleme + ÖDÜLÜ AL (bir kez), tamamlama bonusu,
  gece yarısı (`test_now`), saat geri alma, başarım yıldızları + göç, kayıt/yükleme.
* `qa/mission_sim.gd`: 5 oyuncu profili (yeni, sıradan, aktif, yoğun, oyun sonu) × 30 gün: gem/₺/XP girişi,
  tamamlama oranı, görev çeşitliliği, DDA eğrisi; sonuç bu belgeye eklenir.
* Ekran görüntüleri: 1152×648 ve telefon (480 birim yükseklik).

## 12. Simülasyon sonuçları (`qa/mission_sim.gd`, 30 gün × 40 oyuncu / profil)

Profil başına gürültülü günlük performans (tamir ±%25, yarış / kasa / dekor eğilimi oyuncuya özel),
üretici oyuncunun KENDİ geçmişinden tipik değer hesaplıyor, DDA işliyor:

| Profil | tamam / 5 | 5/5 gün | gem / gün (yalnız günlük bonus) | günlük ödül ₺ / günlük gelir | haftalık 5/5 | 30 günde görülen şablon | DDA |
|---|---|---|---|---|---|---|---|
| YENİ (10 dk) | 4,08 | %35 | 14 | %21 | %42 | 23,6 | 1,12 |
| CASUAL (20 dk) | 4,30 | %45 | 16 | %15 | %46 | 24,8 | 1,22 |
| ARA SIRA (30 dk, haftada 4 gün) | 4,38 | %53 | 12 | %13 | %33 | 24,8 | 1,19 |
| ACTIVE (60 dk) | 4,54 | %62 | 25 | %15 | %81 | 24,8 | 1,26 |
| HEAVY (150 dk) | 4,61 | %65 | 26 | %16 | %89 | 24,8 | 1,26 |

Okuma:
* Aktif bir günde 5 görevden ≈ 4,1–4,6'sı bitiyor; hepsinin bitmesi %35–65 (hedef ~%50: "ulaşılabilir ama
  garanti değil"). Düzeltme turları: ilk koşuda DDA yalnızca ≤1 görevde düştüğü için tavana (1,35) yapışıyordu →
  3/5 ve altı da düşürecek şekilde değiştirildi; HEAVY %83 tamamlıyordu → yarış / iş / dekor hedef tavanları yükseltildi
  ve kademe çarpanları (0,6 → 0,65, 0,95 → 1,05) artırıldı.
* Ödül toplamı günlük gelirin %13–21'i ("minik"). İlk koşuda YENİ oyuncuya %71 veriyordu (sabit dakika katsayısı);
  tipik gelire oranlanınca düzeldi.
* Görev çeşitliliği: 30 günde havuzun (≈ 28 şablon) 24–25'i görülüyor; iki gün arası ortalama kesişim 0,94 / 5.
* Gem: günlük bonus tek başına 12–26 gem / gün; haftalık (5 × 10 + 120 + kasa) ≈ 24 gem / gün eşdeğeri. Eski sistem
  (3 görev × 10 + 20 bonus + haftalık 100) en çok 50 + 14 = 64 gem / gün veriyordu; yeni toplam ≈ 36–50 (tam katılımda).
* Zayıf nokta: "ARA SIRA" oyuncunun haftalık 5/5 oranı %33. Haftada 2–3 gün oynayana 5 haftalık görev yüksek;
  `beklenen aktif gün` bunu zaten düşürüyor ama haftalık hedefler için ilk hafta verisi yok (ön-kabul). Gerçek
  oyuncu verisiyle yeniden ayarlanmalı (çarpan 0,8 tek bir sayıdır).
* Bilinen sınırlama: simülasyon "yarış / kasa" davranışını eğilimle üretiyor; gerçek oyunda yarış davetinin gelme
  sıklığı (RaceManager zamanlayıcısı) ölçülmediği için yarış hedefleri tipik değer yoksa küçük (1–3) başlar.
