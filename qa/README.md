# qa/ — ölçüm araçları

Bunlar test değil **ölçüm** araçlarıdır: sayı üretirler, PASS/FAIL vermezler. Testler
`tools/run_tests.sh` ile çalışır. Hepsi `godot-4 --path . --script qa/<ad>.gd` biçiminde
çalıştırılır; ekran görüntüsü üretenler `/home/burak/Projects/ct_shots/` altına yazar
(Godot snap `/tmp`'yi okuyamadığı için script'ler proje içinde durur).

| Araç | Ne ölçer | Çalıştırma |
|---|---|---|
| `perf_screen.gd` | Tek ekranın FPS / çizim çağrısı / VRAM / açılış süresi. Her ekran AYRI süreçte ölçülmeli, yoksa VRAM birikir. | `--script qa/perf_screen.gd -- garage <sahip_olunan_araçlar...>` |
| `sim_progress.gd` | Yeni oyuncu simülasyonu: para, XP, seviye, garaj, alan, araç, ustalık. `Engine.time_scale = 12`. | `--headless --script qa/sim_progress.gd -- 120` (dakika) |
| `ekran_tarama.gd` | EKRAN TARAMASI: ~50 ekran / alt görünüm (dünya plakaları, garaj + modifiye, tüm panolar, eğitim kartları, hurdalık, harita...) bir cihaz ORANINDA açılır; kadraj dışı, kabından taşan, çakışan ve kesilen öğeler `SORUN` satırı olarak yazılır, her durumun görüntüsü `ct_shots/ekran_tarama/<profil>/`. Tuval yalnızca orana bağlı (mobil ölçek 1,35): 20:9 1067x480 · 16:9 853x480 · 16:10 853x533 · 4:3 853x640 · katlanabilir 853x711 · 21:9 1120x480 · masaüstü 1152x648. Kalan bilinen satırlar süstür (ders kartının eğik ikaz şeridi, yarış süresinin -4 aralıklı rekor satırı). | `tools/ekran_tarama.sh [profil ...] [-- durum_öneki ...]` (dil: `CT_LANG=es`) |
| `ui_audit.gd` | Her ekranda kadraj dışına taşan Control'ler, 44 px altı dokunma hedefleri + ekran görüntüsü. | `--resolution 1040x480 --script qa/ui_audit.gd` |
| `mission_sim.gd` | GÖREVLER simülasyonu: 5 oyuncu profili × 30 gün; tamamlanma oranı, ₺ / gem akışı, görev çeşitliliği, DDA (docs/gorevler_tasarimi.md §12). | `--headless --script qa/mission_sim.gd` |
| `i18n_tarama.gd` | Dil taraması: ekranlarda çevrilmeden kalan metinler + ekran görüntüleri (docs/DIL_DESTEGI.md). | `--resolution 1152x648 --script qa/i18n_tarama.gd -- en` |
| `mesh_cost.gd` | Araç başına mesh/yüzey/vertex/üçgen ve örnek başına VRAM artışı. | `--script qa/mesh_cost.gd` |
| `tex_quality.gd` | İçe aktarılmış (VRAM sıkıştırılmış) doku ile kaynak JPEG arasındaki PSNR. | `--headless --script qa/tex_quality.gd` |
| `mip_probe.gd` | Telefon çözünürlüğünde (2400x1080, ölçek 1,35) şehir / showroom / garaj kadrajlarında araç dokusunun hangi mip'ten okunduğu + 2048 / 1536 / 1024 doku farkı (PSNR, yan yana görüntü). Doku çözünürlüğü kararı buna dayanır. | Xephyr 2400x1080 içinde, betiğin başındaki komut |
| `proportion_check.gd` | Model kutusunun en/boy ve yükseklik/boy oranlarının gerçek ölçülerle farkı. | `--script qa/proportion_check.gd` |
| `measure_models.gd` | Optimize modelin gerçek kutusu + dünya geometrisi (ölçek referansı). | `--script qa/measure_models.gd` |
| `shot_world.gd` | Açılış kadrajı (hiçbir ekran açılmadan). | `--script qa/shot_world.gd` |
| `shot_drag.gd` | Drag yarışı uçtan uca kareler + araçların ekran konumu. | `--script qa/shot_drag.gd` |
| `magaza_goruntuleri.gd` | Play mağaza ekran görüntüleri (1920x1080): ilerlemiş oyuncu kurar, 7 ekranı çeker. İzole kayıt + `--position 0,0 --resolution 1920x1080` gerekir. | `--script qa/magaza_goruntuleri.gd` |
| `sizinti_olcum.gd` | Ekranları art arda açıp kapatır; her turdan sonra düğüm / nesne / kaynak / bellek / VRAM (doku, tampon). Turlar arasında büyüme = sızıntı. | `QA_SAVE=… tools/qa_isolated.sh res://qa/sizinti_olcum.gd --display-driver x11 --disable-vsync --resolution 1152x648 [-- ekran ...]` |
| `birlesim_olcum.gd` | Ekran açıldıktan sonra araç parçası birleştirmesi (CarMeshMerger, GPU geri okuması) bitene kadar kare sayısı / toplam / en uzun kare. `QA_UZAKSIZ=1` araç uzak kademesini kapatır. | `… res://qa/birlesim_olcum.gd … -- garage drag_race` |
| `uzak_lod_kiyas.gd` | Araç uzak kademesi (CarFarLod): her araç tam detay / eski en kaba / yeni uzak kademede, üç kadrajda yan yana + çizilen üçgen. | `godot-4 --path . --display-driver x11 --resolution 1500x900 -s res://qa/uzak_lod_kiyas.gd -- <klasör> <araç_id> ...` |
| `garaj_acilis_olcum.gd` | Garaj ekranı açılışı: doğrudan ve DEPOLARIM → GİT (iç mekân ön yüklemeli) yolu; open() süresi, sonraki en uzun kare, en uzun çizim (shader derlemesi / doku yüklemesi). | `QA_SAVE=… tools/qa_isolated.sh res://qa/garaj_acilis_olcum.gd --display-driver x11 --disable-vsync --resolution 1152x648 [-- dogrudan]` |
| `hud_icon_sheet.gd` | HudIcon'un bütün ikonları 4 boyda + tablonun çizim çağrısı; önce / sonra piksel kıyası için görüntü. | `tools/qa_isolated.sh res://qa/hud_icon_sheet.gd --display-driver x11 --resolution 1152x648 -- <etiket>` |
| `gorunum_lab.gd` | Şehrin ışık / gölge ön ayarları aynı kadrajlarda (pisgolge, isik, yonN, yukN, toplu / toplusuz…; garaj_yakin = en yakın zoom); `QA_TOPLUSUZ=1` toplu çizimi, `QA_UZAKSIZ=1` araç uzak kademesini baştan kapatır. | `… res://qa/gorunum_lab.gd … -- <ön_ayar> ...` |
| `trafik_dogum_olcum.gd` | Bir trafik aracının doğuş süresi (ana iş parçacığı) ve sonraki kare. | `QA_SAVE=… tools/qa_isolated.sh res://qa/trafik_dogum_olcum.gd …` |
| `lod_angle_probe.gd` | Araç GLB'sinin içe aktarıcı LOD üretimiyle (ImporterMesh.generate_lods) kademe üçgenleri, normal açısına göre. | `godot-4 --headless --path . --script qa/lod_angle_probe.gd -- <araç_id> ...` |
| `zemin_sayim.gd` | Şehirdeki düz (zemin) ve yüksek (gölge düşüren) geometrinin materyal türleri (WorldShadow sınıflaması için). | `QA_SAVE=… tools/qa_isolated.sh res://qa/zemin_sayim.gd …` |

**Yalıtım:** kayda dokunan ölçümler için geçici `override.cfg` yazıp
(`config/use_custom_user_dir=true`, `custom_user_dir_name="ct_fresh"`) bitince silin;
yoksa geliştirme kaydı (seviye 20, ustalık 150+) sonucu bozar.
