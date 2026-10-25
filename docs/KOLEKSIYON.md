# KOLEKSİYON ÖDÜLLERİ (2026-10-25)

Özellik raporu P1 #4 (`~/Projects/planlar/Auto Yard Özellik Raporu.html`). Eskiden 13 set ödülsüzdü, kilometre taşları
16 araçlık eski katalogdan kalmaydı (kasa araçları, 5/10/14/16). Kararlar kullanıcıyla soru-cevapla verildi.

## Kurallar (`gameplay/collection_rewards.gd`, `CollectionRewards`)
- **Sayılan araçlar:** edinilebilir bütün katalog = kasa araçları + hurdalık klasikleri (72). Bir kez SAHİP OLMAK yeter
  (keşif: sonra satılsa da sayılır). KOLEKSİYONCU görevleri eskisi gibi yalnız kasa araçlarını sayar
  (`VehicleOwnership.discovered_count`).
- **Setler:** `vehicles/crates.json` → `sets` (21 set; her edinilebilir araç en az bir sette). Hurdalık klasikleri için 8
  yeni set: ŞEHİR ARABALARI, SUV DÜNYASI, DOLMUŞ DURAĞI, AVRUPA MİNİKLERİ, YOL VE MACERA, AMERİKAN KASLILARI,
  ALTIN ÇAĞ GT, RALLİ EFSANELERİ; YERLİ KLASİKLER'e Murat 124/131 + Anadol, BAVYERA'ya M3 E30, SICAK KOMPAKT'a Formentor.
- **Set ödülü:** elmas + ₺, setteki araçların NADİRLİĞİNE göre araç başına toplanır:
  `SET_GEMS` common 2 · rare 5 · epic 9 · legendary 18; `SET_MONEY` 5 b · 10 b · 20 b · 40 b ₺ (elmas "daha cimri").
  Hurdalık klasiğinin nadirliği restorasyon kademesinden: basit → nadir, klasik → epik, yarış → efsanevi.
- **Kilometre taşları:** 10 / 20 / 35 / 50 / 72 araç → 10 / 20 / 40 / 80 / 150 elmas.
- **TAM KOLEKSİYON (72):** ayrıca KOLEKSİYONER profil çerçevesi (lacivert-altın, yıldızlı), KOLEKSİYONER KUPASI
  (`collector_trophy`, lüks zemin eşyası, mağazada yok; `tools/decor/props_v9_koleksiyon.py`) ve KOLEKSİYONER unvanı
  (profil kartında "★ KOLEKSİYONER"; `public_garages.honor`).
- Ödül araç keşfedilir keşfedilmez hesaba geçer (`VehicleOwnership.vehicle_discovered`): kasa, hurdalık, posta hediyesi,
  showroom — kaynağı ne olursa olsun. Her set / taş bir kez.
- Katalog büyürse `MILESTONES`'un son taşı toplam araç sayısına çekilmeli (`collection_rewards_test` yakalar).

## Ekranlar
- **SET TAMAMLANDI!** (`ui/hud/collection_reward_screen.gd`, RewardScreen dili): ödül hesapta, sayaçlar bekler; oyun
  sakinleşince açılır (kasa sonucu plakası, pano, ders, başka ödül ekranı kapanınca), aradaki ödüller tek ekranda birleşir.
  Kartlar: set (ilk 3 aracın fotoğrafı, +N), kilometre taşı (birden çok taş tek kartta), TAM KOLEKSİYON'da çerçeve +
  kupa + unvan. En çok 5 kart; sığmayan setler "+N SET DAHA" kartında. TOPLA → paralar sayaçlara uçar.
- **KOLEKSİYON panosu** (`ui/hud/collection_screen.gd`): başlıkta `N / 72`, üstte kilometre taşı şeridi (ödül ya da
  ✔ ALINDI), altta set satırları (ilerleme çubuğu, araç adları, ödül ya da ✔ ALINDI; geniş plakada iki sütun).

## Kayıt
`savegame.json` → `"collection": {"sets": [...], "milestones": [...]}`. Bölümü olmayan kayıtta bugün tamam olanlar
ÖDÜLSÜZ işaretlenir (`mark_existing`). Eski kasa kilometre taşları (`CrateManager.COLLECTION_MILESTONES`, `"milestones"`)
kaldırıldı; eski kayıttaki alan yok sayılır.

## Sunucu
`firebase/firestore.rules` → `isValidGarage` `honor` alanını kabul eder (`^[a-z_]{1,16}$`). **Yayından önce kurallar
deploy edilmeli**, yoksa unvanı olan oyuncunun garaj yayını reddedilir.

## Testler
`tools/run_tests.sh collection_rewards_test` (kurallar, set / taş ödemesi, ekran, pano, kayıt, eski kayıt, tam koleksiyon).
Görsel: `tools/qa_isolated.sh res://qa/koleksiyon_qa.gd --resolution 1152x648 --display-driver x11 -- set|coklu|tam|pano`.
