class_name MissionCatalog
## GÖREV KATALOĞU — günlük / haftalık şablonlar ve başarım çizgileri (TEK KAYNAK).
## Tasarım ve gerekçe: docs/gorevler_tasarimi.md. Şablon eklemek = bu listeye bir kayıt; üretici
## (MissionGenerator) şart, ağırlık, hedef sınırı ve ödülü buradan okur, koda gömülü sayı yoktur.
##
## Görev = (metrik, hedef). Metrikler MissionManager'ın sayaçlarından gelir (docs §3):
##   repairs, repair_money, job_<id>, long_jobs, races, race_wins, crates_opened, crates_bought, paints,
##   growth_buys, decor_placed, cars_displayed, decor_bought, money_spent, levels, days_played,
##   daily_done, daily_all, weekly_done, weekly_all,
##   (2026-10-20 genişletme) junk_searches, junk_parts, restorations, mods_installed, interior_ups, depot_builds,
##   friend_races, friend_wins, revenges, records, photos, luxury_bought, cars_bought.
## Durum metrikleri (anlık): cars_discovered, cars_on_display, garage_level, bays, garage_rank, job_stars, player_level,
##   best_streak, ach_stars, legend, depots_owned, cars_owned, legendary_cars.

enum Tier { EASY, MEDIUM, HARD }
## Kategori: günlük listede çeşitlilik ve "nudge" (kullanılmayan özelliğe yönlendirme) için.
## Yeni kategori SONA eklenir: görev kaydı kategoriyi sayı olarak tutar.
enum Cat { REPAIR, EARN, JOB, RACE, GROWTH, COLLECT, STYLE, JUNK, TUNE, SOCIAL }

## Günlük slot düzeni: 2 kolay, 2 orta, 1 zor.
const DAILY_SLOTS: Array[int] = [Tier.EASY, Tier.EASY, Tier.MEDIUM, Tier.MEDIUM, Tier.HARD]
## Kademe → tipik günlük performansın kaçı hedef olur.
const TIER_FACTOR: Dictionary = {Tier.EASY: 0.35, Tier.MEDIUM: 0.65, Tier.HARD: 1.05}
## Günlük ödül: oyuncunun TİPİK günlük kazancının / XP'sinin payı (5 görevin toplamı ≈ %19). Alt sınır:
## yarım dakikalık gelir (çok az oynayana da hissedilsin).
const DAILY_SHARE: Dictionary = {Tier.EASY: 0.02, Tier.MEDIUM: 0.04, Tier.HARD: 0.07}
const REWARD_FLOOR_MIN: float = 0.5
## Günlük görevlerin hepsi bitince verilen gem.
const DAILY_BONUS_GEMS: int = 10
## Haftalık görev başına ödül: ₺ ve XP (tipik HAFTALIK kazancın / XP'nin payı) + sabit gem.
const WEEKLY_SHARE: float = 0.03
const WEEKLY_GEMS: int = 0
## Haftalık BÜYÜK ÖDÜL: gem + bedava kasa + XP (tipik haftalık XP'nin payı).
const WEEKLY_BONUS_GEMS: int = 40
const WEEKLY_BONUS_XP_SHARE: float = 0.06
## Günlük görevler bu oyuncu seviyesinden sonra açılır (eski GemRewards kuralı).
const MIN_LEVEL: int = 3
## Saatte kaç tamir yapıldığı varsayımı (ödül ölçeği; docs/AUDIT_2026_09.md §6: ~3,4 tamir/dk).
const REPAIRS_PER_MIN: float = 3.4

## --- GÜNLÜK ŞABLONLAR ------------------------------------------------------------------------
## id, cat, tier, metric, text (%s = hedef), weight, base (tipik değer anahtarı), lo/hi (hedef sınırı),
## step (yuvarlama: "count" 5'in katı, "money" büyüklüğe göre, "one" 1), req (açık olma şartı).
## "job" şablonları iş türü başına genişletilir (metric "job_<id>", metin işin adını alır).
const DAILY: Array[Dictionary] = [
	{"id": &"rep_e", "cat": Cat.REPAIR, "tier": Tier.EASY, "metric": &"repairs", "text": "%s TAMİR YAP", "weight": 10.0, "base": &"repairs", "lo": 8, "hi": 60, "step": &"count"},
	{"id": &"rep_m", "cat": Cat.REPAIR, "tier": Tier.MEDIUM, "metric": &"repairs", "text": "%s TAMİR YAP", "weight": 8.0, "base": &"repairs", "lo": 12, "hi": 120, "step": &"count"},
	{"id": &"rep_h", "cat": Cat.REPAIR, "tier": Tier.HARD, "metric": &"repairs", "text": "%s TAMİR YAP", "weight": 7.0, "base": &"repairs", "lo": 20, "hi": 220, "step": &"count"},
	{"id": &"earn_e", "cat": Cat.EARN, "tier": Tier.EASY, "metric": &"repair_money", "text": "TAMİRDEN %s ₺ KAZAN", "weight": 10.0, "base": &"repair_money", "lo": 300, "hi": 20000, "step": &"money"},
	{"id": &"earn_m", "cat": Cat.EARN, "tier": Tier.MEDIUM, "metric": &"repair_money", "text": "TAMİRDEN %s ₺ KAZAN", "weight": 8.0, "base": &"repair_money", "lo": 600, "hi": 40000, "step": &"money"},
	{"id": &"earn_h", "cat": Cat.EARN, "tier": Tier.HARD, "metric": &"repair_money", "text": "TAMİRDEN %s ₺ KAZAN", "weight": 7.0, "base": &"repair_money", "lo": 1000, "hi": 60000, "step": &"money"},
	{"id": &"job", "cat": Cat.JOB, "tier": Tier.MEDIUM, "metric": &"job_", "text": "%s ADET %s İŞİ TAMAMLA", "weight": 5.0, "base": &"job_", "lo": 3, "hi": 25, "step": &"one", "req": &"job"},
	{"id": &"long_m", "cat": Cat.JOB, "tier": Tier.MEDIUM, "metric": &"long_jobs", "text": "%s UZUN İŞ TAMAMLA", "weight": 6.0, "base": &"long_jobs", "lo": 1, "hi": 8, "step": &"one", "req": &"long_job"},
	{"id": &"long_h", "cat": Cat.JOB, "tier": Tier.HARD, "metric": &"long_jobs", "text": "%s UZUN İŞ TAMAMLA", "weight": 5.0, "base": &"long_jobs", "lo": 2, "hi": 16, "step": &"one", "req": &"long_job"},
	{"id": &"race_e", "cat": Cat.RACE, "tier": Tier.EASY, "metric": &"races", "text": "%s YARIŞA KATIL", "weight": 9.0, "base": &"races", "lo": 1, "hi": 3, "step": &"one", "req": &"race"},
	{"id": &"race_m", "cat": Cat.RACE, "tier": Tier.MEDIUM, "metric": &"races", "text": "%s YARIŞA KATIL", "weight": 7.0, "base": &"races", "lo": 2, "hi": 10, "step": &"one", "req": &"race"},
	{"id": &"race_win_m", "cat": Cat.RACE, "tier": Tier.MEDIUM, "metric": &"race_wins", "text": "%s YARIŞ KAZAN", "weight": 6.0, "base": &"race_wins", "lo": 1, "hi": 4, "step": &"one", "req": &"race"},
	{"id": &"race_win_h", "cat": Cat.RACE, "tier": Tier.HARD, "metric": &"race_wins", "text": "%s YARIŞ KAZAN", "weight": 5.0, "base": &"race_wins", "lo": 2, "hi": 8, "step": &"one", "req": &"race"},
	{"id": &"spend_m", "cat": Cat.GROWTH, "tier": Tier.MEDIUM, "metric": &"money_spent", "text": "%s ₺ HARCA", "weight": 6.0, "base": &"money_spent", "lo": 500, "hi": 100000, "step": &"money", "req": &"spend"},
	{"id": &"growth_m", "cat": Cat.GROWTH, "tier": Tier.MEDIUM, "metric": &"growth_buys", "text": "BİR GARAJ GELİŞTİRMESİ SATIN AL", "weight": 6.0, "base": &"growth_buys", "lo": 1, "hi": 1, "step": &"one", "req": &"growth"},
	{"id": &"crate_open_m", "cat": Cat.COLLECT, "tier": Tier.MEDIUM, "metric": &"crates_opened", "text": "%s KASA AÇ", "weight": 7.0, "base": &"crates_opened", "lo": 1, "hi": 4, "step": &"one", "req": &"crate_open"},
	{"id": &"crate_buy_e", "cat": Cat.COLLECT, "tier": Tier.EASY, "metric": &"crates_bought", "text": "BİR KASA SİPARİŞ ET", "weight": 6.0, "base": &"crates_bought", "lo": 1, "hi": 1, "step": &"one", "req": &"crate_buy"},
	{"id": &"paint_m", "cat": Cat.STYLE, "tier": Tier.MEDIUM, "metric": &"paints", "text": "BİR ARACI BOYA", "weight": 5.0, "base": &"paints", "lo": 1, "hi": 1, "step": &"one", "req": &"paint"},
	{"id": &"decor_e", "cat": Cat.STYLE, "tier": Tier.EASY, "metric": &"decor_placed", "text": "%s EŞYA YERLEŞTİR", "weight": 6.0, "base": &"decor_placed", "lo": 1, "hi": 6, "step": &"one", "req": &"decor"},
	{"id": &"display_e", "cat": Cat.STYLE, "tier": Tier.EASY, "metric": &"cars_displayed", "text": "BİR ARACINI GARAJDA SERGİLE", "weight": 5.0, "base": &"cars_displayed", "lo": 1, "hi": 1, "step": &"one", "req": &"display"},
	# 2026-10-20 genişletme (kullanıcı: "görevleri epey bir genişlet"): sonradan gelen özellikler görevlere girdi
	{"id": &"photo_e", "cat": Cat.STYLE, "tier": Tier.EASY, "metric": &"photos", "text": "GARAJININ FOTOĞRAFINI ÇEK", "weight": 4.0, "base": &"photos", "lo": 1, "hi": 1, "step": &"one"},
	{"id": &"junk_e", "cat": Cat.JUNK, "tier": Tier.EASY, "metric": &"junk_searches", "text": "HURDALIKTA %s YIĞIN ARA", "weight": 7.0, "base": &"junk_searches", "lo": 1, "hi": 6, "step": &"one", "req": &"junk"},
	{"id": &"junk_m", "cat": Cat.JUNK, "tier": Tier.MEDIUM, "metric": &"junk_parts", "text": "HURDALIKTAN %s PARÇA TOPLA", "weight": 6.0, "base": &"junk_parts", "lo": 3, "hi": 30, "step": &"one", "req": &"junk"},
	{"id": &"mod_m", "cat": Cat.TUNE, "tier": Tier.MEDIUM, "metric": &"mods_installed", "text": "BİR ARACINA MODİFİYE TAK", "weight": 6.0, "base": &"mods_installed", "lo": 1, "hi": 1, "step": &"one", "req": &"mods"},
	{"id": &"friend_e", "cat": Cat.SOCIAL, "tier": Tier.EASY, "metric": &"friend_races", "text": "%s ARKADAŞ YARIŞINA KATIL", "weight": 6.0, "base": &"friend_races", "lo": 1, "hi": 3, "step": &"one", "req": &"race"},
	{"id": &"friend_win_m", "cat": Cat.SOCIAL, "tier": Tier.MEDIUM, "metric": &"friend_wins", "text": "%s ARKADAŞINI YARIŞTA YEN", "weight": 5.0, "base": &"friend_wins", "lo": 1, "hi": 3, "step": &"one", "req": &"race"},
	{"id": &"interior_m", "cat": Cat.GROWTH, "tier": Tier.MEDIUM, "metric": &"interior_ups", "text": "BİR DEPODA İÇ YÜKSELTME YAP", "weight": 5.0, "base": &"interior_ups", "lo": 1, "hi": 1, "step": &"one", "req": &"interior"},
]

## --- HAFTALIK ŞABLONLAR ----------------------------------------------------------------------
## Slot 1-3 sabit rol (hacim, kazanç, günlük bağı); 4. slot "nudge" (kullanılmayan kategori),
## 5. slot alışkanlık / zor hedef. `wk` = haftalık çarpan (tipik günlük × beklenen aktif gün × 0,9).
const WEEKLY_CORE: Array[Dictionary] = [
	{"id": &"w_repairs", "cat": Cat.REPAIR, "metric": &"repairs", "text": "%s TAMİR YAP", "base": &"repairs", "lo": 40, "hi": 1200, "step": &"count"},
	{"id": &"w_earn", "cat": Cat.EARN, "metric": &"repair_money", "text": "TAMİRDEN %s ₺ KAZAN", "base": &"repair_money", "lo": 3000, "hi": 400000, "step": &"money"},
	{"id": &"w_daily", "cat": Cat.GROWTH, "metric": &"daily_done", "text": "%s GÜNLÜK GÖREV TAMAMLA", "base": &"", "lo": 8, "hi": 22, "step": &"one"},
]
const WEEKLY_POOL: Array[Dictionary] = [
	{"id": &"w_race_wins", "cat": Cat.RACE, "metric": &"race_wins", "text": "%s YARIŞ KAZAN", "weight": 7.0, "base": &"race_wins", "lo": 3, "hi": 8, "step": &"one", "req": &"race"},
	{"id": &"w_crates", "cat": Cat.COLLECT, "metric": &"crates_opened", "text": "%s KASA AÇ", "weight": 7.0, "base": &"crates_opened", "lo": 3, "hi": 8, "step": &"one", "req": &"crate_open"},
	{"id": &"w_long", "cat": Cat.JOB, "metric": &"long_jobs", "text": "%s UZUN İŞ TAMAMLA", "weight": 7.0, "base": &"long_jobs", "lo": 6, "hi": 40, "step": &"one", "req": &"long_job"},
	{"id": &"w_paints", "cat": Cat.STYLE, "metric": &"paints", "text": "2 ARACI BOYA", "weight": 4.0, "base": &"paints", "lo": 2, "hi": 2, "step": &"one", "req": &"paint"},
	{"id": &"w_decor", "cat": Cat.STYLE, "metric": &"decor_placed", "text": "%s EŞYA YERLEŞTİR", "weight": 5.0, "base": &"decor_placed", "lo": 6, "hi": 20, "step": &"one", "req": &"decor"},
	{"id": &"w_spend", "cat": Cat.GROWTH, "metric": &"money_spent", "text": "%s ₺ HARCA", "weight": 6.0, "base": &"money_spent", "lo": 2000, "hi": 400000, "step": &"money", "req": &"spend"},
	{"id": &"w_growth", "cat": Cat.GROWTH, "metric": &"growth_buys", "text": "2 GARAJ GELİŞTİRMESİ AL", "weight": 4.0, "base": &"growth_buys", "lo": 2, "hi": 2, "step": &"one", "req": &"growth"},
	{"id": &"w_days", "cat": Cat.GROWTH, "metric": &"days_played", "text": "5 FARKLI GÜN OYNA", "weight": 5.0, "base": &"", "lo": 5, "hi": 5, "step": &"one"},
	{"id": &"w_perfect", "cat": Cat.GROWTH, "metric": &"daily_all", "text": "%s GÜNÜN TÜM GÖREVLERİNİ BİTİR", "weight": 5.0, "base": &"", "lo": 2, "hi": 3, "step": &"one"},
	# 2026-10-20 genişletme
	{"id": &"w_junk", "cat": Cat.JUNK, "metric": &"junk_searches", "text": "HURDALIKTA %s YIĞIN ARA", "weight": 6.0, "base": &"junk_searches", "lo": 5, "hi": 30, "step": &"one", "req": &"junk"},
	{"id": &"w_parts", "cat": Cat.JUNK, "metric": &"junk_parts", "text": "HURDALIKTAN %s PARÇA TOPLA", "weight": 5.0, "base": &"junk_parts", "lo": 15, "hi": 150, "step": &"count", "req": &"junk"},
	{"id": &"w_restore", "cat": Cat.JUNK, "metric": &"restorations", "text": "BİR KLASİĞİ RESTORE ET", "weight": 5.0, "base": &"restorations", "lo": 1, "hi": 1, "step": &"one", "req": &"junk"},
	{"id": &"w_mods", "cat": Cat.TUNE, "metric": &"mods_installed", "text": "%s MODİFİYE TAK", "weight": 6.0, "base": &"mods_installed", "lo": 2, "hi": 8, "step": &"one", "req": &"mods"},
	{"id": &"w_friend_wins", "cat": Cat.SOCIAL, "metric": &"friend_wins", "text": "%s ARKADAŞ YARIŞI KAZAN", "weight": 6.0, "base": &"friend_wins", "lo": 2, "hi": 8, "step": &"one", "req": &"race"},
	{"id": &"w_record", "cat": Cat.RACE, "metric": &"records", "text": "DRAG REKORUNU KIR", "weight": 4.0, "base": &"records", "lo": 1, "hi": 1, "step": &"one", "req": &"record"},
	{"id": &"w_interior", "cat": Cat.GROWTH, "metric": &"interior_ups", "text": "%s İÇ YÜKSELTME YAP", "weight": 5.0, "base": &"interior_ups", "lo": 2, "hi": 6, "step": &"one", "req": &"interior"},
	{"id": &"w_photos", "cat": Cat.STYLE, "metric": &"photos", "text": "3 FOTOĞRAF ÇEK", "weight": 3.0, "base": &"photos", "lo": 3, "hi": 3, "step": &"one"},
]

## --- BAŞARIM ÇİZGİLERİ -----------------------------------------------------------------------
## id, title, metric, kind ("counter": yaşam boyu sayaç · "state": oyunun anlık durumu), tiers (eşikler),
## mult (değer zorluk çarpanı), value (verilirse yıldız başına değer listesi: eski tamir kilometre taşları).
## Yıldız başına taban DEĞER: 5 · 15 · 30 · 60 · 100; ₺ ve XP değerle orantılı (§6.3). Gem değerin
## ACH_GEM_SHARE'idir (2026-10-11 elmas ekonomisi: gem kısıldı, ₺ / XP aynı kaldı).
## 2026-10-21 zorluk turu (kullanıcı: "başarımlar çok kolay, hemen ödüle boğuluyorum"): eşikler yükseldi (ilk yıldızı 1 olan
## çizgiler 2–3'ten başlar), değer 5/15/30/60/100 → 3/9/20/40/70, ₺ 60 → 40 / değer, XP 6 → 5, gem payı 0,2 → 0,12.
const ACH_VALUE: Array[int] = [3, 9, 20, 40, 70]
const ACH_GEM_SHARE: float = 0.12
const ACH_MONEY_PER_VALUE: int = 40
const ACH_XP_PER_VALUE: int = 5
const ACHIEVEMENTS: Array[Dictionary] = [
	{"id": &"a_repairs", "title": "TAMİRCİ", "text": "%s tamir tamamla", "metric": &"repairs", "kind": &"counter", "tiers": [100, 500, 1500, 4000, 10000], "value": [6, 12, 20, 35, 55]},
	{"id": &"a_earn", "title": "KAZANÇLI", "text": "Tamirlerden toplam %s ₺ kazan", "metric": &"repair_money", "kind": &"counter", "tiers": [50000, 500000, 3000000, 15000000], "mult": 1.0},
	{"id": &"a_spend", "title": "HARCAMACI", "text": "Toplam %s ₺ harca", "metric": &"money_spent", "kind": &"counter", "tiers": [75000, 600000, 3000000, 15000000], "mult": 0.8},
	{"id": &"a_race_wins", "title": "YARIŞÇI", "text": "%s yarış kazan", "metric": &"race_wins", "kind": &"counter", "tiers": [10, 40, 120, 300], "mult": 1.0},
	{"id": &"a_races", "title": "ARENA", "text": "%s yarışa katıl", "metric": &"races", "kind": &"counter", "tiers": [25, 100, 400], "mult": 0.6},
	{"id": &"a_crates", "title": "KASA AVCISI", "text": "%s kasa aç", "metric": &"crates_opened", "kind": &"counter", "tiers": [5, 20, 60, 150], "mult": 0.9},
	{"id": &"a_cars", "title": "KOLEKSİYONCU", "text": "%s farklı araç keşfet", "metric": &"cars_discovered", "kind": &"state", "tiers": [5, 10, 18, 28, 40], "mult": 1.5},
	{"id": &"a_paints", "title": "BOYACI", "text": "%s boya satın al", "metric": &"paints", "kind": &"counter", "tiers": [3, 10, 30], "mult": 0.7, "feature": &"paint"},
	{"id": &"a_decor", "title": "DEKORATÖR", "text": "Garaja toplam %s eşya yerleştir", "metric": &"decor_placed", "kind": &"counter", "tiers": [15, 40, 100, 200], "mult": 0.7},
	{"id": &"a_display", "title": "SERGİCİ", "text": "Garajda aynı anda %s araç sergile", "metric": &"cars_on_display", "kind": &"state", "tiers": [3, 6, 10, 16], "mult": 0.8},
	{"id": &"a_garage", "title": "GARAJ USTASI", "text": "Garajı %s. seviyeye genişlet", "metric": &"garage_level", "kind": &"state", "tiers": [2, 3, 4], "mult": 1.0},
	{"id": &"a_bays", "title": "ALAN SAHİBİ", "text": "%s tamir alanına sahip ol", "metric": &"bays", "kind": &"state", "tiers": [2, 3], "mult": 0.8},
	{"id": &"a_rank", "title": "DEĞERLİ GARAJ", "text": "Garaj değerinde %s. rütbeye ulaş", "metric": &"garage_rank", "kind": &"state", "tiers": [4, 6, 8, 10], "mult": 1.2},
	{"id": &"a_stars", "title": "USTA", "text": "İşlerden toplam %s ustalık yıldızı topla", "metric": &"job_stars", "kind": &"state", "tiers": [8, 15, 22, 30, 35], "mult": 1.0},
	# 2026-10-20 genişletme: hurdalık, modifiye, depolar, arkadaş yarışları, rekor, fotoğraf, lüks dekor, filo
	{"id": &"a_long", "title": "SABIRLI USTA", "text": "%s uzun iş tamamla", "metric": &"long_jobs", "kind": &"counter", "tiers": [20, 100, 300, 800], "mult": 0.9},
	{"id": &"a_junk", "title": "HURDACI", "text": "Hurdalıkta %s yığın ara", "metric": &"junk_searches", "kind": &"counter", "tiers": [10, 40, 150, 400], "mult": 0.8},
	{"id": &"a_parts", "title": "PARÇA AVCISI", "text": "Hurdalıktan toplam %s parça topla", "metric": &"junk_parts", "kind": &"counter", "tiers": [50, 250, 900, 2500], "mult": 0.8},
	{"id": &"a_restore", "title": "RESTORATÖR", "text": "%s klasik aracı restore et", "metric": &"restorations", "kind": &"counter", "tiers": [2, 5, 10, 16, 24], "mult": 1.3},
	{"id": &"a_mods", "title": "MODİFİYECİ", "text": "%s modifiye tak", "metric": &"mods_installed", "kind": &"counter", "tiers": [3, 15, 40, 100], "mult": 1.0},
	{"id": &"a_depots", "title": "DEPO SAHİBİ", "text": "%s depoya sahip ol", "metric": &"depots_owned", "kind": &"state", "tiers": [1, 2, 3, 4, 5], "mult": 1.2},
	{"id": &"a_interior", "title": "İÇ MİMAR", "text": "Depolarda %s iç yükseltme tamamla", "metric": &"interior_ups", "kind": &"counter", "tiers": [3, 10, 25, 45], "mult": 0.9},
	{"id": &"a_fleet", "title": "FİLO SAHİBİ", "text": "Aynı anda %s araca sahip ol", "metric": &"cars_owned", "kind": &"state", "tiers": [8, 20, 35, 55, 70], "mult": 1.2},
	{"id": &"a_legendary", "title": "EFSANE AVCISI", "text": "%s efsane araç keşfet", "metric": &"legendary_cars", "kind": &"state", "tiers": [1, 3, 5, 7], "mult": 1.5},
	{"id": &"a_bought", "title": "ALICI", "text": "Showroom'dan %s araç satın al", "metric": &"cars_bought", "kind": &"counter", "tiers": [2, 8, 20], "mult": 0.8},
	{"id": &"a_friend_races", "title": "DOSTLUK YARIŞI", "text": "%s arkadaş yarışına katıl", "metric": &"friend_races", "kind": &"counter", "tiers": [3, 20, 75, 200], "mult": 0.7},
	{"id": &"a_friend_wins", "title": "SOKAK KRALI", "text": "%s arkadaşını yarışta yen", "metric": &"friend_wins", "kind": &"counter", "tiers": [3, 15, 60, 150], "mult": 1.0},
	{"id": &"a_revenge", "title": "İNTİKAMCI", "text": "%s intikam yarışı kazan", "metric": &"revenges", "kind": &"counter", "tiers": [2, 10, 30], "mult": 0.9},
	{"id": &"a_records", "title": "REKORTMEN", "text": "Drag rekorunu %s kez kır", "metric": &"records", "kind": &"counter", "tiers": [3, 10, 25, 60], "mult": 1.0},
	{"id": &"a_photos", "title": "FOTOĞRAFÇI", "text": "%s fotoğraf çek", "metric": &"photos", "kind": &"counter", "tiers": [3, 15, 60], "mult": 0.5},
	{"id": &"a_luxury", "title": "LÜKS SEVER", "text": "%s lüks eşya al", "metric": &"luxury_bought", "kind": &"counter", "tiers": [2, 6, 15], "mult": 1.0},
	{"id": &"a_level", "title": "SEVİYE", "text": "%s. seviyeye ulaş", "metric": &"player_level", "kind": &"state", "tiers": [8, 15, 25, 35, 50], "mult": 1.0},
	{"id": &"a_days", "title": "SADAKAT", "text": "Toplam %s gün oyna", "metric": &"days_played", "kind": &"counter", "tiers": [3, 7, 30, 100, 365], "mult": 1.0},
	{"id": &"a_streak", "title": "SERİ", "text": "%s gün üst üste giriş yap", "metric": &"best_streak", "kind": &"state", "tiers": [3, 7, 14, 30], "mult": 0.9},
	{"id": &"a_daily", "title": "GÖREV AVCISI", "text": "%s günlük görev tamamla", "metric": &"daily_done", "kind": &"counter", "tiers": [20, 80, 250, 700], "mult": 0.8},
	{"id": &"a_perfect", "title": "MÜKEMMEL GÜN", "text": "%s günün tüm görevlerini bitir", "metric": &"daily_all", "kind": &"counter", "tiers": [5, 20, 60, 150], "mult": 1.0},
	{"id": &"a_weekly", "title": "HAFTA YILDIZI", "text": "%s haftanın tüm görevlerini bitir", "metric": &"weekly_all", "kind": &"counter", "tiers": [2, 6, 15, 30], "mult": 1.2},
	{"id": &"a_meta", "title": "YILDIZ TOPLAYICI", "text": "Toplam %s başarım yıldızı topla", "metric": &"ach_stars", "kind": &"state", "tiers": [15, 35, 60, 90], "mult": 1.0},
	{"id": &"a_legend", "title": "EFSANE GARAJ SAHİBİ", "text": "Tüm araçlar, garaj Sv.4, 3 alan, 10. rütbe ve 35 ustalık yıldızı", "metric": &"legend", "kind": &"state", "tiers": [1], "value": [500]},
]
## Dönem anahtarları (kayıt).
const LIFE: StringName = &"life"
const DAY: StringName = &"day"
const WEEK: StringName = &"week"

## Kategori → o kategoriye ait metrikler ("son 7 günde kullanıldı mı" için).
const CAT_METRICS: Dictionary = {
	Cat.REPAIR: [&"repairs"],
	Cat.EARN: [&"repair_money"],
	Cat.JOB: [&"long_jobs"],
	Cat.RACE: [&"races", &"race_wins"],
	Cat.GROWTH: [&"money_spent", &"growth_buys", &"interior_ups"],
	Cat.COLLECT: [&"crates_opened", &"crates_bought"],
	Cat.STYLE: [&"paints", &"decor_placed", &"cars_displayed", &"photos"],
	Cat.JUNK: [&"junk_searches", &"junk_parts", &"restorations"],
	Cat.TUNE: [&"mods_installed"],
	Cat.SOCIAL: [&"friend_races", &"friend_wins"],
}


static func daily_template(id: StringName) -> Dictionary:
	for t: Dictionary in DAILY:
		if t["id"] == id:
			return t
	return {}


static func weekly_template(id: StringName) -> Dictionary:
	for t: Dictionary in WEEKLY_CORE:
		if t["id"] == id:
			return t
	for t: Dictionary in WEEKLY_POOL:
		if t["id"] == id:
			return t
	return {}


static func achievement(id: StringName) -> Dictionary:
	for a: Dictionary in ACHIEVEMENTS:
		if a["id"] == id:
			return a
	return {}


## Görev metni. `id` "job:<iş>" biçimindeyse ikinci %s işin kısa adıdır.
static func text_of(template_id: StringName, target: int) -> String:
	var shown: String = Hud.format_thousands(target)
	var id_text: String = String(template_id)
	if id_text.begins_with("job:"):
		var job: RepairType = RepairType.by_id(StringName(id_text.substr(4)))
		var name: String = job.short_title() if job else id_text.substr(4).to_upper()
		return Loc.tn(String(daily_template(&"job")["text"]), target) % [shown, name]
	var tpl: Dictionary = daily_template(template_id)
	if tpl.is_empty():
		tpl = weekly_template(template_id)
	if tpl.is_empty():
		return id_text
	var text: String = Loc.tn(String(tpl["text"]), target)
	return text % shown if text.contains("%s") else text


## Başarım çizgisinin n. yıldızının (0 tabanlı) ödül değeri (₺ / XP / gem bundan türer).
static func ach_value(line: Dictionary, star: int) -> int:
	if line.has("value"):
		var list: Array = line["value"]
		return int(list[clampi(star, 0, list.size() - 1)])
	var base: int = ACH_VALUE[clampi(star, 0, ACH_VALUE.size() - 1)]
	return maxi(int(round(float(base) * float(line.get("mult", 1.0)))), 1)


## Başarım çizgisinin n. yıldızının (0 tabanlı) gem ödülü.
static func ach_gems(line: Dictionary, star: int) -> int:
	return maxi(int(round(float(ach_value(line, star)) * ACH_GEM_SHARE)), 1)


static func ach_money(line: Dictionary, star: int) -> int:
	return ach_value(line, star) * ACH_MONEY_PER_VALUE


static func ach_xp(line: Dictionary, star: int) -> int:
	return ach_value(line, star) * ACH_XP_PER_VALUE
