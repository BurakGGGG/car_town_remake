# UI / MENÜ KONSOLİDASYONU

Tarih: 2026-09-26. Amaç: mevcut ekranları tek bir tutarlı UX altında toplamak; yeni gameplay
sistemi EKLENMEDİ. Önceki aşamalar: [PROGRESSION_REFACTOR.md](PROGRESSION_REFACTOR.md),
[QA_REVIEW.md](QA_REVIEW.md), [PHASE2_PROGRESSION.md](PHASE2_PROGRESSION.md).

---

## 1. EKRAN ENVANTERİ (önce)

| Ekran | Nasıl açılıyordu | Sorun |
|---|---|---|
| HUD (üst sol/üst sağ/alt) | her zaman | — |
| Alt sekme GARAJ | sekme → GarageScreen | tek çalışan sekme |
| Alt sekme ARAÇLAR | **hiçbir şey açmıyordu** | ölü sekme |
| Alt sekme MAĞAZA | **hiçbir şey açmıyordu** | ölü sekme (showroom yalnızca binadan) |
| Alt sekme PROFİL | LoginScreen (hesap) | "profil" adı yanıltıcı, ilerleme yok |
| GarageScreen | GARAJ sekmesi | kendi ESC'si, kendi alt ekranları |
| ShowroomScreen | bina hitbox | kendi ESC'si; görevlerle aynı anda açık kalabiliyordu |
| QuestScreen | sağ üst GÖREVLER plakası | bağımsız |
| MasteryScreen | garaj → USTALIK | yalnızca garajın çocuğuydu, dışarıdan açılamıyordu |
| GarageValueScreen | garaj → GARAJ DEĞERİ plakası | aynı sorun |
| LoginScreen | PROFİL sekmesi / ad plakası | iki giriş, bağlamsız |
| RepairPanel | araç seçilince | bilgi kalabalığı + ödül iki yerde farklı |
| Satın alma plakası (garaj/alan) | dünyadaki tabela | elle kurulmuş, araçtan farklı hiyerarşi |
| CarGallery (HUD içindeki) | **hiç açılmıyordu** | ölü düğüm |
| SettingsButton | — | `settings_pressed` sinyalini dinleyen yok |
| RotateButton | — | `camera_rotate_requested` dinleyen yok, kamera dönüşü yok |
| hud_preview.tscn | yalnızca editörde | ölü değil: gerçek HUD'u örnekleyen geliştirici sahnesi (korundu) |

**Tespit:** 4 alt sekmenin 2'si hiçbir şey açmıyordu · aynı araç listesi iki yerde (HUD CarGallery +
garaj listesi) · 3 ölü düğüm/sinyal · her ekran kendi ESC'sini dinliyordu · showroom "ARABA
GALERİSİ", sekme "MAĞAZA", bina "CAR PARTS" — tek yere üç ad.

## 2. YENİ HİYERARŞİ

```
ANA OYUN (dünya + HUD)
├── HUD: oyuncu/seviye · para · gem · GÖREVLER plakası · kamera/ses · alt sekmeler
├── YER (aynı anda yalnızca biri, oyun HUD'u gizlenir)
│   ├── GARAJ        (GARAJ ve ARAÇLAR sekmeleri) — lift, tamir, geliştirmeler, garaj değeri, boya, satış
│   └── MAĞAZA       (MAĞAZA sekmesi ve showroom binası) — araç kataloğu, araç plakası, satın alma
└── PANO (yerin ÜSTÜNE açılır, en fazla bir tane)
    ├── İLERLEME (PROFİL) → seviye, garaj değeri, ustalık, görevler, hesap
    ├── GARAJ DEĞERİ (rütbe merdiveni)
    ├── USTALIK PANOSU
    ├── GÖREVLER
    └── HESAP (LoginScreen)
```

Kural: **YER + PANO = en fazla iki katman.** Yeni YER açılınca eski YER kapanır; yeni PANO açılınca
eski PANO kapanır; GERİ/ESC yalnızca tepedekini kapatır. Bunu `ui/hud/ui_router.gd` (UiRouter)
uygular ve `ui_router` grubundan dünya nesneleri de (showroom binası) ekran açabilir.

## 3. SATIN ALMA STANDARDI

Üç satın alma da `ui/hud/purchase_plate.gd` (PurchasePlate) ile aynı hiyerarşiyi kullanır —
**BAŞLIK / alt başlık / FİYAT / etki satırları**, aksiyon plakası altta:

```
GARAJI GENİŞLET        TAMİR ALANI 2           TOFAŞ ŞAHIN
SEVİYE 2               (alt başlık yok)        D SINIFI · 1995 · %50
12.000 ₺               5.000 ₺                 15.000 ₺
+%25 DAHA SIK MÜŞTERİ  +1 EŞZAMANLI TAMİR      GARAJ DEĞERİ +15.000 ₺
+1 BEKLEME NOKTASI     BOYA İŞİ AÇILIR         SEVİYE 12 GEREKLİ (şu an 1)
2. TAMİR ALANI AÇILIR  DÖŞEME AÇILIR
[ GENİŞLET ]           [ ALANI AÇ ]            [ SATIN AL ]
```

Etki satırlarının tamamı `ProgressionEffects`ten gelir (SUPPLY tablosu, RepairBayManager,
RepairType, CarCatalog) — UI'da hardcode edilmiş sayı yoktur.

## 4. TAMİR PLAKASI

Sabit bilgi sırası: **süre → maliyet → ödül (₺/dk ile) → XP → ustalık**.

```
MOTOR ARIZASI   ·   10 sn  ·  +173 ₺ (1.038 ₺/dk)  ·  +10 XP  ·  USTALIK ★ 12/40
```

Sağdaki ödül satırı artık aynı sayıyı TEKRARLAMAZ; yalnızca engel varsa konuşur
("TAMİR ALANI DOLU", "SEVİYE 8'DE AÇILIR", "YETERSİZ BAKİYE").

## 5. AÇILIŞ / KAPANIŞ STANDARDI

`ui/hud/plate_anim.gd`: bütün panolar 0,22 sn BACK/EASE_OUT ile açılır, 0,12 sn'de kapanır.
ESC tek yerden (UiRouter) karşılanır. Garaj ve mağaza kendi zengin giriş animasyonlarını korur.

## 6. MOBİL (20:9)

Telefon tuvali ölçüldü: `stretch scale.mobile = 1.35` ile **1040×480** (masaüstü 1152×648).
Bulunan hata: garaj sol sütunu 480 yüksekliğinde **y = −31 … 511** ile hem üstten hem alttan
taşıyordu (GARAJDAN ÇIK plakasının üstüne biniyordu). Çözüm:
- sol sütun bir `ScrollContainer` içine alındı (yükseklik = tuval − çıkış payı),
- 560 pikselin altındaki tuvalde **sade kip**: başlıklar ve "ne alıyorum" özet satırları gizlenir
  (o ayrıntılar zaten dünyadaki satın alma plakasında tam haliyle var).
HUD kenar plakaları için `_apply_safe_area()` eklendi: çentik/yuvarlak köşe payı yalnızca mobil
derlemede kenar boşluklarına eklenir (masaüstünde hiçbir şey değişmez).

## 7. TEMİZLENENLER

| Ne | Nasıl |
|---|---|
| HUD içindeki CarGallery düğümü | hud.tscn'den kaldırıldı (PackedScene yolu; elle .tscn düzenlenmedi) |
| SettingsButton + `settings_pressed` | kaldırıldı (ayar ekranı yok, dinleyen yok) |
| RotateButton + `camera_rotate_requested` | kaldırıldı (kamera dönüşü uygulanmamış) |
| GarageScreen'in kendi MasteryScreen/GarageValueScreen kopyaları | HUD'a taşındı, tek örnek |
| Ekran başına ESC işleyicileri | UiRouter'a toplandı |
| "ARABA GALERİSİ" / "MAĞAZA" ikiliği | tek ad: MAĞAZA |
| Tamir plakasındaki çift ödül gösterimi | tek kaynak (`effective_reward`) |

`ui/hud/hud_preview.tscn` SİLİNMEDİ: gerçek hud.tscn'i örnekleyen geliştirici önizleme sahnesi,
ölü UI değil.

## 8. PERFORMANS (aynı sıra, 1152×648, vsync kapalı)

| Durum | Faz 2 (önce) | UI konsolidasyonu (sonra) |
|---|---|---|
| Dünya garaj 1 | 859 FPS / 240 çizim / 83,5 MB | **867 / 231 / 80,1** |
| Dünya garaj 4 (trafik 10) | 493 / 538 / 95,5 | **462 / 502 / 86,1** |
| Garaj ekranı | 177 / 1.148 / 113,7 · açılış 10 ms | **179 / 946 / 108,1 · 8 ms** |
| Ustalık panosu | 166 / 1.122 / 114,4 · 66 ms | **172 / 980 / 109,8 · 56 ms** |

Çizim çağrısı ve VRAM düştü (ölü düğümler + garaj ekranının kendi pano kopyaları kalktı).
Tam tur (dünya → garaj → mağaza → dört pano) tek oturumda tepe **125,5 MB**; her şey kapanınca
119,4 MB'a iner. Tepe değerin kaynağı mağazanın 3D mekânıdır (Faz 2'de de ~123 MB ölçülmüştü),
UI konsolidasyonu değil. Pano açılışları: profil 7,9 ms · görevler 15,1 ms · rütbe 57,1 ms ·
ustalık 59,3 ms (ilk kuruluşta liste üretimi).
