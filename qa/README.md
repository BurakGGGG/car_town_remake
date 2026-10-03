# qa/ — ölçüm araçları

Bunlar test değil **ölçüm** araçlarıdır: sayı üretirler, PASS/FAIL vermezler. Testler
`tools/run_tests.sh` ile çalışır. Hepsi `godot-4 --path . --script qa/<ad>.gd` biçiminde
çalıştırılır; ekran görüntüsü üretenler `/home/burak/Projects/ct_shots/` altına yazar
(Godot snap `/tmp`'yi okuyamadığı için script'ler proje içinde durur).

| Araç | Ne ölçer | Çalıştırma |
|---|---|---|
| `perf_screen.gd` | Tek ekranın FPS / çizim çağrısı / VRAM / açılış süresi. Her ekran AYRI süreçte ölçülmeli, yoksa VRAM birikir. | `--script qa/perf_screen.gd -- garage <sahip_olunan_araçlar...>` |
| `sim_progress.gd` | Yeni oyuncu simülasyonu: para, XP, seviye, garaj, alan, araç, ustalık. `Engine.time_scale = 12`. | `--headless --script qa/sim_progress.gd -- 120` (dakika) |
| `ui_audit.gd` | Her ekranda kadraj dışına taşan Control'ler, 44 px altı dokunma hedefleri + ekran görüntüsü. | `--resolution 1040x480 --script qa/ui_audit.gd` |
| `mesh_cost.gd` | Araç başına mesh/yüzey/vertex/üçgen ve örnek başına VRAM artışı. | `--script qa/mesh_cost.gd` |
| `tex_quality.gd` | İçe aktarılmış (VRAM sıkıştırılmış) doku ile kaynak JPEG arasındaki PSNR. | `--headless --script qa/tex_quality.gd` |
| `proportion_check.gd` | Model kutusunun en/boy ve yükseklik/boy oranlarının gerçek ölçülerle farkı. | `--script qa/proportion_check.gd` |
| `measure_models.gd` | Optimize modelin gerçek kutusu + dünya geometrisi (ölçek referansı). | `--script qa/measure_models.gd` |
| `shot_world.gd` | Açılış kadrajı (hiçbir ekran açılmadan). | `--script qa/shot_world.gd` |
| `shot_drag.gd` | Drag yarışı uçtan uca kareler + araçların ekran konumu. | `--script qa/shot_drag.gd` |
| `magaza_goruntuleri.gd` | Play mağaza ekran görüntüleri (1920x1080): ilerlemiş oyuncu kurar, 7 ekranı çeker. İzole kayıt + `--position 0,0 --resolution 1920x1080` gerekir. | `--script qa/magaza_goruntuleri.gd` |

**Yalıtım:** kayda dokunan ölçümler için geçici `override.cfg` yazıp
(`config/use_custom_user_dir=true`, `custom_user_dir_name="ct_fresh"`) bitince silin;
yoksa geliştirme kaydı (seviye 20, ustalık 150+) sonucu bozar.
