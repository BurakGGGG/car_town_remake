# Günlük giriş merdiveni

2026-10-23. Eski 7 günlük giriş elmasının (10-10-15-10-15-10-40, girişte kendiliğinden verilirdi) yerine geçen 28 basamaklı
günlük ödül sistemi.

## Kullanıcı kararları

- 1 hafta = 7 basamak, toplam 4 hafta (28 gün).
- **Bir gün kaçırılırsa merdiven 1. güne döner** (sıkı seri).
- Merdiven eski giriş elmasının **yerini alır** (tek sistem).
- **Her hafta sonu yeni, mağazada olmayan bir dekor** (7. / 14. / 21. gün), 28. günde **"N. AY" dekoru**. Her ay dört yeni eşya
  sürekli eklenecek.
- Ekran **günün ilk girişinde kendiliğinden** açılır, ayrıca sağ üstteki tabeladan ve GÖREVLER › GÜNLÜK'ten.
- Sağ üstte MARKET yuvarlak ve yazısız; yanında günlük giriş tabelası.

## Araştırmadan alınan desenler

Mobil oyunların günlük giriş takvimlerinde ortak olanlar (kaynaklar aşağıda):

- **Bütün takvim baştan görünür**, ödüller büyüyerek gider: oyuncu ileriki büyük ödülü görür, geri gelir.
- **Bugünün basamağı vurgulu**, alma düğmesi nabız atar; alınan günler işaretli.
- **Kilometre taşları** (7 / 14 / 21) ve **son gün kahraman ödülü**: büyük, parlak, "özel".
- **Kaçırma kuralı açıkça yazılı**.
- **Yarının ödülü ve geri sayım**.
- Ekran **girişte kendiliğinden** açılır; köşede ödül hazırken dikkat çeken **küçük bir düğme**.
- Takvim oyunun **dekor eşyalarını tanıtır**.

## Kurallar (kod)

- `gameplay/login_ladder.gd` (`LoginLadder`): ödül tablosu, durum tutmaz.
  - Hafta: 1. gün 10 gem, 2. ₺, 3. 15 gem, 4. ₺, 5. 15 gem, 6. ₺, 7. hafta dekoru + 40 gem → haftada 80 gem.
  - ₺ = oyuncunun ŞU ANKİ aktif oyun gelirinin dakikası (OfflineEarnings.current_active_rate: garaj seviyesi, açık alan,
    tamir hızı). Para günleri 6 / 9 / 12 dakika × hafta çarpanı 1,0 / 1,15 / 1,35 / 1,6 (ay ilerledikçe büyür); okunur
    sayıya yuvarlanır. Ayda ~138 dakikalık gelir: günde ~1 saat oynayana aylık kazancın ~%7–8'i kadar ek.
    Dengeleme (2026-10-23, kullanıcı: "20 gün oynayan ~300 bin ₺ sahibi, 4 bin cezbedici değil; ne abartı ne az"):

    | Oyuncu | ₺/dk | 2. gün | 13. gün | 20. gün | 27. gün | ayda |
    |---|---|---|---|---|---|---|
    | yeni (garaj 1) | 372 | 2.200 | 5.100 | 6.000 | 7.100 | 51.200 |
    | garaj 2 / 2 alan | 991 | 5.900 | 13.500 | 16.000 | 19.000 | 136.600 |
    | garaj 3 / 3 alan (~20. gün, ~300 bin) | 1.666 | 10.000 | 23.000 | 27.000 | 32.000 | 229.000 |
    | garaj 4 / 3 alan + hız 5 | 2.778 | 16.500 | 38.500 | 45.000 | 53.500 | 383.000 |
  - 28. gün: ay dekoru + 50 gem.
  - O ayın dekoru katalogda yoksa yerine elmas (hafta 60, ay 100).
- `gameplay/gem_rewards.gd`: basamak = ardışık giriş serisi (`ladder_day`), tamamlanan ay (`months_done`).
  - Ödül girişte VERİLMEZ, AL ile alınır (`claim_ladder`).
  - Alınmadan gün dönerse o basamak kendiliğinden verilir (`ladder_claimed` → `auto`), kaybolmaz.
  - 28. gün alınınca ay tamamlanır; sonraki merdiven bir sonraki ayın dekorlarını verir.
  - ×2 ödüllü reklam (AdPolicy.DAILY_DOUBLE) yalnız merdiven panosunda, bugün alınan elmas / ₺ için (dekor ikiye katlanmaz).
  - Kayıt: `login` bölümüne `claimed`, `cg`, `cm`, `months` eklendi.
- `ui/hud/login_ladder_screen.gd`: pano.
  - Solda aşağıdan yukarı çıkan 4 basamak, sağda dönen 3B ay ödülü ve BUGÜN alanı (AL / ×2 / yarın + geri sayım).
  - Oyun sakinleşince açılır: pano / ders / ödül penceresi yok, ilk ders bitmiş, bekleyen SEVİYE ATLADIN önce.
  - Testlerde (CT_NO_TUTORIAL) kendiliğinden açılmaz.
- `ui/hud/login_ladder_button.gd`: sağ üstteki tabela; takvim yaprağında bugünün günü, alınabilirken rozet ve zıplama.

## Yeni ay eklemek

1. Dört eşya üret (örnek: `tools/decor/props_v7_giris.py`; adlar `login_mNN_w1..w3`, `login_mNN_cup`):
   `CT_DECOR_OUT=assets/decor blender --background --factory-startup --python tools/decor/run_bpy.py -- <betik>`
2. `.glb.import` dosyalarında `ensure_tangents` ve `create_shadow_meshes` false, `--import` tekrar.
3. `decor/decorations.json`'a dört kayıt: `"kind": "luxury"`, `"exclusive": true`, `"login": {"month": N, "week": 1..4}`.
4. Çeviri: `python3 tools/i18n/extract.py` → yeni başlık / açıklama `locale/*.json`.

İlk oyuncu en erken 28 gün sonra 2. aya geçer; o zamana kadar 2. ayın dört eşyası eklenmeli (yoksa elmas verilir).

## Test / QA

- `tests/login_ladder_test.gd`: tablo, akış, kaçırma, kendiliğinden verme, 28. gün, kayıt, pano.
- `qa/giris_merdiveni_shots.gd`: pano kareleri (`-- <gün>`).
- Ekran taraması durumu `giris_merdiveni`.
- Pencereli QA'da `--display-driver x11 --disable-vsync` şart: örtülü pencerede vsync her kareyi 1 sn yapıyor.

## Kaynaklar

- Unity Gaming Services — Daily Rewards: https://docs.unity.com/en-us/services/solutions/daily-rewards
- GameRefinery — Onboarding best practices part 2: https://www.gamerefinery.com/keep-your-players-coming-back-introducing-onboarding-best-practices-part-2/
- SWTOR 28 günlük giriş takvimi: https://swtorista.com/articles/?p=14716
- Roblox Engagement Rewards: https://create.roblox.com/docs/resources/feature-packages/engagement-rewards
- Daily Rewards Login Streak System (yerleşim türleri): https://builtbybit.com/resources/daily-rewards-login-streak-system.105963/
