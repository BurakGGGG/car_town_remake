# Profil kişiselleştirme (2026-11-01)

Kullanıcıyla soru turlarıyla karar verildi: daha çok profil resmi, daha çok çerçeve, ilk profilde `Usta1234` yerine
isim havuzu, araç adlarında anlam çevirisi yerine sesle çağrışım. Araç adı kuralı ve listesi: `docs/ARAC_ADLARI.md`.

## Hazır avatarlar (12 → 36)

Üretim: `tools/avatars/make_presets.py` (SVG, parça parça: yüz, gözler, saç, kıyafet, arka plan) → `render_avatars.gd`
(Godot'un SVG okuyucusu, 256 px) → `assets/ui/avatars/preset_NN.png`. Eski 12'si yeniden üretilince bayt bayt aynı çıkar.
Godot snap olduğu için çıktı klasörü ev dizininde olmalı (`/tmp`'ye yazamaz).

| No | Avatar | Kilit |
|---|---|---|
| p01–p12 | eski portreler | ücretsiz |
| p13 | Boyacı (K) | sv17 |
| p14 | Kaynakçı (E) | sv35 |
| p15 | Lastikçi (E) | sv28 |
| p16 | Çekici şoförü (K) | 500 tamir |
| p17 | Driftçi (K) | 300 gem |
| p18 | Ralli pilotu (E) | 100 drag galibiyeti |
| p19 | Motorcu (E) | 200 gem |
| p20 | Retro tuner (K) | 250 gem |
| p21 | Taksici (E) | sv6 |
| p22 | Kurye (K) | sv13 |
| p23 | Yeni ehliyetli (E) | sv3 |
| p24 | Hevesli emekli (K) | 2000 tamir |
| p25–p28 | Sarıklı (E), Latin (K), Doğu Asyalı (E), Kuzeyli (K) | ücretsiz (kimlik avatarları bilerek ücretsiz) |
| p29 | Direksiyon (simge) | ücretsiz |
| p30 | Çapraz İngiliz anahtarı (simge) | ücretsiz |
| p31 | Piston (simge) | sv9 |
| p32 | Vites topuzu (simge) | sv22 |
| p33 | Kriko (simge) | 100 gem |
| p34 | Yağdanlık (simge) | 100 gem |
| p35 | Turbo (simge) | 150 gem |
| p36 | Dama bayrakları (simge) | 500 drag galibiyeti |

* Veri: `ProfileCatalog.AVATAR_UNLOCKS` (listede olmayan ücretsiz). Seçicide sıra `preset_ids_display()`: ücretsiz →
  seviye → elmas → başarım.
* `PlayerProfile.avatar_unlocked / buy_avatar / avatar_progress`; elmasla alınanlar kayıtta `"avatars"`, seviye ve
  başarım koşuldan hesaplanır. Drag galibiyeti = `RaceManager.wins()` (profil kartındaki sayı), tamir =
  `MissionManager.value_of(&"repairs")`.
* Başarım eşiği TAM o an aşılınca `avatar_earned` → HUD "YENİ PROFİL RESMİ AÇILDI!" (dokununca PROFİL › DÜZENLE).
* Seviyeyle açılanlar SEVİYE ATLADIN ekranında "YENİ PROFİL RESMİ" kartı (`LevelUnlocks.Kind.AVATAR`).
* p29–p36 yüzsüz simgeler tuvali doldurur: `AvatarView` küçük boyda yüze yakın kırpmaz (`ProfileCatalog.is_icon_texture`).
* Seçicide kilitli avatar soluk + kilit simgesi; altında "SEVİYE 17", elmas simgesi + fiyat (onayda kırmızı "300?",
  ikinci dokunuş alır), başarımda bayrak / anahtar simgesi + "37/100". Yazılar dilden bağımsız kısa tutuldu
  ("300 JUWELEN" 70 px hücreye sığmıyordu).
* Uyumluluk: Firestore kuralı `p00–p99` kabul eder (kural değişmedi). Eski sürüm tanımadığı avatarı kask gösterir.
* QA: `qa/avatar_shots.gd` (→ `~/Projects/ct_shots/avatars_v2/oyun/`), test: `profile_test` §1 + §2b, `level_up_test`.

## Çerçeveler (13 → 28)

| Çerçeve | Kimlik | Kilit | Not |
|---|---|---|---|
| İKAZ BANDI | `hazard` | sv3 | sarı-siyah eğik şerit, aşınma, cıvata |
| LASTİK | `tire` | sv8 | sırt dişleri, yanak kabartması |
| DİREKSİYON | `wheel` | sv15 | delikli deri, dikiş, tutamak, kırmızı orta işaret |
| YARIŞ ŞERİDİ | `stripe` | sv25 | parlak mavi boya, ince beyaz şeritler |
| GÖSTERGE | `gauge` | sv40 | kadran + krom; ibre kodla, hareketli |
| DEFNE | `laurel` | sv60 | altın oymalı halka + taşan defne dalları, kurdele |
| TAÇ | `crown` | sv99 | oymalı altın halka, taşlar + taşan taç |
| AHŞAP | `wood` | 150 gem | ceviz damarı, budak, pirinç kakma |
| PAS | `rust` | 200 gem | pas lekeleri, eski boya kalıntısı, perçin |
| BAKIR | `copper` | 300 gem | dövme izi, pas yeşili, perçin |
| KROM | `chrome` | 400 gem | ayna yansıması; parıltı kodla, hareketli |
| KADİFE | `velvet` | 500 gem | bordo hav, burgulu altın kordon |
| KANATLI TEKER | `winged` | 900 gem | lastik + krom jant; kanatlar avatarın arkasında |
| ALEVLİ KUPA | `flame_cup` | 1500 gem | kor çatlaklı halka, kupa; alevler kodla, hareketli |
| ELMAS TAÇ | `diamond_crown` | 1000 drag galibiyeti | pavé pırlantalı platin + elmas taç |

* Halkalar DETAYLI DOKU (kullanıcı "biraz daha detaylı ve güzel yap"): `tools/avatars/make_rings.py` →
  `rings_src/ring_<kimlik>.svg` → `assets/ui/frames/ring_<kimlik>.png` (256 px, MIPMAP'li içe aktarma). Eski 13 çerçeve
  kodla çizilmeye devam eder. Hareketli kısımlar (`gauge` ibresi, `chrome` parıltısı, `flame_cup` alevleri)
  `AvatarView._draw_ring`'de dokunun bandına (`ProfileCatalog.RING_INNER`) hizalı.
* Süsler `tools/avatars/make_frames.py` → `frames_src/*.svg` → `assets/ui/frames/<ad>.png`; daireden her yönde EN ÇOK
  %20 taşar (tuvalde 32..480, `profile_test` denetler).
* Kullanıcı kararı (HUD taslakları sonrası): "fotoğraf küçük olsun, prestij alan herkese sığsın; süsü olmayanın da küçük
  olsun" → `AvatarView.ornament_room = ProfileCatalog.ORNAMENT_ROOM` (1,4): daire kutunun içinde küçük çizilir, süs
  kutuya sığar, düzen kaymaz. Uygulanan yerler: HUD avatarı (seviye rozeti taşma payı 8 → 0), profil kartı (kutu
  116 → 132), çerçeve seçicisi hücreleri. Listelerde (arkadaş, lider tablosu, yarış panoları) süs satır arasına taşar.
* Süzgeç: daire 96 px'den küçükse mipmap'li, büyükse mipmap'siz (`AvatarView.MIPMAP_BELOW`; alt mip seviyesi ince
  şeritleri eritip halkayı soluklaştırıyordu).
* `PlayerProfile.frame_unlocked` "wins" (RaceManager.wins) destekler; 1000. galibiyette `frame_earned` → HUD
  "YENİ ÇERÇEVE AÇILDI!". Galibiyet çerçevesi kayda yazılmaz, `LevelUnlocks`'ta görünmez.
* QA: `qa/frame_sheet.gd` (SubViewport, ekrandan bağımsız), `qa/frame_shots.gd` (HUD + seçici). Test: `profile_test`
  §1b, `level_up_test` (sv3'te 4 açılış, son kilit sv99 TAÇ).

## İsim havuzu

* `gameplay/social/name_pool.json` + `NamePool`: "sıfat + garaj nesnesi", bitişik (TurboSomun), sayı yok, oyun diline
  göre (TR/EN/ES/DE/FR, her dilde 3280+ ad). ES/FR sıfatı ismin cinsiyetine uyar (TuercaLoca), DE çekimli
  (RostigerKolben). ES/DE/FR kelimelerinde á é ñ ä ß YOK: eski sürüm geçersiz adı "Usta1234" gösterirdi.
* `SocialNames.default_name` havuzdan çeker (otomatik profil, ARKADAŞLAR formu); geçersiz adlı başka oyuncunun yedek adı
  `NamePool.seeded_name(uid.hash())`.
* ZAR düğmesi (`RenamePrompt.dice_button`): PROFİL › DÜZENLE › İSİM, ARKADAŞLAR'daki profil formu ve ad değiştirme.
* Eski otomatik adlı ("Usta" + 4 rakam) oyuncuya bir kez YENİ TAKMA AD kartı (`RenamePrompt`, MODAL "rename_prompt"):
  oturumun ilk 20 sn'si + 1,5 sn sakin an, KAYDET / KALSIN; `user://rename_offer.json` {uid: true}.
* Test: `name_pool_test`, `social_test` §15–16; QA `qa/rename_shots.gd`.
