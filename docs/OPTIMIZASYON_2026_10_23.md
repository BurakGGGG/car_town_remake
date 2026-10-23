# Optimizasyon gecesi — 2026-10-23

İstek: "Alt barı oyuna uygula, simgeleri biraz küçült. Ardından mükemmel bir optimizasyon ve boyut küçültme yap; görsel
olarak bir şey kaybetmek istemiyorum." Her madde görüntüyü (ya da sesi) bayt / piksel düzeyinde aynı bırakacak şekilde
seçildi ve ölçüldü. Commit yok.

## 1. Alt bar

Gece taslaktaki turkuaz bar (2B çizim sekmeler, arkadaş şeridi, hızlı tepsi) uygulandı; sabah kullanıcı beğenmedi:
"alt barı eski haline geri getir, ama görevler ve arkadaşlar alt bara insin, profil kalksın". Son hâl:
- Alt sıra eski krem plakalar: GARAJ · ARAÇLAR · SHOWROOM · GÖREVLER · ARKADAŞLAR · (hikâyeyle) HARİTA. PROFİL plakası gizli
  (sol üst avatar profili açar; düğme nesnesi duruyor). Yeni ikonlar `HudIcon.Kind.TASKS` (onaylı pano) ve `FRIENDS` (iki kişi).
- GÖREVLER'in alınabilir ödül sayısı ve ARKADAŞLAR'ın istek + yarış haberi sayısı plaka rozetinde (amber alt sırada "seçili"
  anlamına geldiği için kullanılmadı).
- Sağ üst: kamera / ayar, MARKET (krem plaka, solda elmas + altın çizimi), otoparkta araç varken eski OTOPARK plakası.
- Turkuaz bar dosyaları (nav_bar / friends_strip / friends_tray / lot_tab_badge, çizimler, nav_bar_test) silindi; PlateButton
  gece öncesine döndü. Ekran taraması (dunya) p20x9 / p16x9 / fold ve %120 HUD: 0 sorun.

## Testler
Tam paket (`tools/run_tests.sh`, 72 paket): ilk koşuda 2 pakette 4 hata — ikisi de test beklentisiydi, düzeltildi:
`quest_test` (GÖREVLER sayısı artık sekme rozetinde), `race_test` (canlı etkinlik işiyle gelen `event_paid` yarış kaydı alanı).
Bu iki test paket klasöründe (`~/snap/godot-4/common/cloudtest/`; yedekler `*.pre_altbar.bak`, `*.pre_etkinlik.bak`).
Yeniden koşu: ikisi de 0 hata. Yeni paket: `audio_cache_test` (14). (Turkuaz barla gelen `nav_bar_test` bar geri alınınca silindi.)

## 2. Paket boyutu (ayrıntı: docs/MESH_BUTCESI.md "Paket boyutu 4")

Doğrulama AAB'si (1.1.0 doğrulamasına göre): indirme **261,6 → 246,8 MiB (−14,8)**, kurulu **398,1 → 378,7 MiB (−19,4)**;
.pck 253,8 → 234,2 MiB. RSCC 2 MiB blok yeniden paketleme (`tools/size/rscc_repack.py`, derleme betikleri çağırır), WebP en
yüksek çaba, açılış resmi / simge RGB. Hepsi kayıpsız; 303 kaynağın içerik özeti önce / sonra aynı.

## 3. Çalışma performansı

| Ölçü | Önce | Sonra | Nasıl |
|---|---|---|---|
| Şerit çizgileri (Main.tscn, 62 CSG kök) | kadrajdaki her kesik 1 çağrı (varsayılan kamerada ~13) | 1 çağrı | `WorldDressing._batch_lane_lines` |
| Hareketli avatar halkası (gökkuşağı) | 0,42 ms/kare | 0,15 ms | yaylar bir kez çizilir, her kare self_modulate |
| Hareketli avatar halkası (neon) | 0,10 ms | 0,03 ms | aynı yöntem |
| Kodla üretilen sesler (2. açılıştan sonra) | 1298 ms işlemci | 3,8 ms | `AudioCache` |
| TouchScroll node_added çağrısı (garaj açılışı) | ~32 000 | ~370 | tek statik dağıtıcı |

- **AvatarView** (`ui/hud/avatar_view.gd`): fotoğraf / gölge değişince bir kez çizilir; halka ayrı katman (`_RingLayer`).
  Gökkuşağı / neon yayları BİR KEZ beyaz (ya da taban renkte) çizilir, her kare yalnız `self_modulate` değişir: beyaz yay ×
  renk = o renkte yay. Eski / yeni kod 6 çerçeve × 3 boy × 4 an karşılaştırıldı: en büyük fark 0/255.
- **Şerit çizgileri**: görünür CSG kesikler `bake_static_mesh` ile dünya dönüşümü işlenerek malzemeye göre tek mesh'te
  birleşir (malzeme yine motorun varsayılanı), CSG'ler gizlenir ve `batched` işareti alır. Öncesi / sonrası ekran farkı yalnız
  hareket eden trafik araçlarında.
- **AudioCache** (`gameplay/audio_cache.gd`): şehir ortam bankası, siren, gazete / para / trafik sesleri sürüm kodu başına bir kez
  üretilip `user://audio_cache/`'e yazılır (3,3 MB), sonra aynı PCM okunur. Geliştirme sürümünde (sürüm kodu 0) kapalı.
  Test `tests/audio_cache_test.gd` (diskten okunan ses bayt bayt aynı, dizi türleri korunur, eski sürüm dosyası silinir).
- **TouchScroll**: her sürücünün ayrı `node_added` bağlantısı → tek statik dağıtıcı (yeni düğümün ataları bir kez yürünür).

### Ölçüm araçları (bu gece eklenen)
- `qa/hud_draw_census.gd` — HUD kümelerinin çizim çağrısı payı (eski alt sırayla: HUD 175 çağrı).
- `qa/open_hitch.gd` — ekran açılışının gerçek süresi (profilleyicisiz).
- `qa/startup_timeline.gd` — soğuk / sıcak açılış: yükleme ekranı 4,4 / 3,9 sn'de kalkıyor, sonrasında en uzun kare ~22 ms
  (eski notlardaki 7,9 sn'lik soğuk shader derlemesi artık yok).
- `qa/size_audit/resource_hash.gd` — kaynak içerik özeti (kayıpsız paketlemenin kanıtı).

## 4. Bakılıp bilerek yapılmayanlar
- Garaj ekranı açılışı (~95 ms ilk, ~50 ms sonra): iç mekân ve 13 park etmiş araç her açılışta kurulup kapanınca siliniyor —
  bellek için bilinçli karar; açık tutmak RAM / VRAM artırır.
- CarMeshMerger önbelleğini 8 modelden büyütmek: garajda 13 model olduğu için yeniden birleştirme yapıyor, ama model başına
  ~3,5 MB; zayıf telefonda risk.
- Garaj arayüzü (~260 çizim çağrısı) ve HUD (~175): daha da azaltmak arayüzü dokuya önceden çizmeyi gerektirir
  (büyük mimari değişiklik).
- LOD1 taban mesh, R8, müzik sıkıştırma: kullanıcı daha önce istemedi.
