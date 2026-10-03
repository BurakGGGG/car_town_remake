# AUTO YARD — Proje Envanteri (2026-10-02)

Ölçümler bu oturumda komutlarla alındı; ölçülmeyenler "ÖLÇÜLMEDİ" diye işaretli.

## Motor / yapılandırma
| Alan | Değer |
|---|---|
| Godot | 4.7.2 stable **mono** (snap `godot-4`); proje GDScript |
| Renderer | GL Compatibility (masaüstü + mobil) |
| Ana sahne | `Main.tscn` (uid) |
| Stretch | `canvas_items`, aspect `expand`, `scale.mobile=1.35` |
| FPS sınırı | `run/max_fps=60` |
| Yön | `landscape` (manifest) |
| Uygulama adı | **AUTO YARD** (`config/name`, preset `package/name`; AAB'de `godot_project_name_string` = AUTO YARD doğrulandı) |
| Proje ikonu | `res://assets/branding/icon_512.png` (eskiden varsayılan Godot `icon.svg`; silindi) |
| GERİ tuşu | `application/config/quit_on_go_back=false`; karar `UiRouter.handle_android_back()` |

## Android (export_presets.cfg, AAB'den doğrulandı)
| Alan | Değer |
|---|---|
| Paket / uygulama kimliği | `com.autoyard.app` (değiştirildi, Firebase kaydı mevcut) |
| versionName / versionCode | `1.0.0` / `1` (önceden versionName boştu) |
| minSdk / targetSdk / compileSdk | 24 / **36** / 36 |
| ABI | yalnızca `arm64-v8a` (`libgodot_android.so`, `libc++_shared.so`) |
| Biçim | AAB (`gradle_build/export_format=1`), gradle yapı |
| İzinler | `INTERNET`, `ACCESS_NETWORK_STATE`, `READ_GSERVICES` (Firebase/Play Services); başka yok |
| Manifest notları | `allowBackup=false`, `isGame=true`, `<profileable shell=true>` (Godot şablon varsayılanı) |
| İmza | **Release için gerçek yükleme anahtarı YOK.** AAB yalnızca `~/godot-debug.keystore` (CN=Android Debug) ile imzalandı → Play'e yüklenemez |
| Kenar | edge-to-edge kapalı, immersive açık |

## Üçüncü taraf / bulut
- `addons/GodotFirebaseAndroid` (syntaxerror247, commit be573b1, kaynaktan derlendi): Firebase Auth (Google girişi) + Firestore (`players/{uid}`, tek `save_json` alanı).
- Reklam: **yok**. Analitik: **yok**. Crash raporlama: **yok** (Firebase Crashlytics eklenmemiş). Uygulama içi satın alma: **yok**.
- Firebase proje: `car-town-remake`; `google-services.json` tek SHA-1 içeriyor (Play App Signing SHA-1'i eklenmeli — bkz. P1).

## Dosya sayıları
| | Adet |
|---|---|
| GDScript (addons hariç) | 138 |
| Sahne `.tscn` | 22 |
| `.tres` | 1 |
| GLB | 95 (`assets/cars/source` + `optimized` + dünya/dekor) |
| Doku (png/jpg/webp) | 91 (+ marka ikonları) |
| Araç kataloğu | 16 araç (`vehicles/cars.json`) |
| Test paketi | 18 (`tools/run_tests.sh`) |

## Boyut
- `assets/` 467 MB (çoğu `assets/cars/source/` — `.gdignore` ile içe aktarılmıyor, export'a girmiyor), `assets/cars/optimized/` 96 MB.
- **Release AAB: 128.9 MB** (Play sınırı: sıkıştırılmış indirme ≤ 200 MB/cihaz → geçer). Assetler `assetPackInstallTime` paketinde.
- En büyük kaynak dosyalar (export dışı): `renault_r12.glb` 39.7 MB, `renault_toros_wheels.glb` 34.3 MB, `seat_leon.glb` 20.4 MB (hepsi `source/`).

## Temizlik adayları (silinmedi; rapora yazıldı)
- `.bak/.old/~` dosyası: depoda **yok**. `assets/cars/optimized_old/` ve `eksik_dosyalar/` `.gdignore`'lu (export'a girmez; `eksik_dosyalar/autoyard-logo-pack/png/*` **bozuk render**, bkz. Logo).
- `qa/`, `tests/` export filtresiyle (`qa/*, tests/*`) pakete girmez.
- Kullanılmayan asset/script/scene taraması: **ÖLÇÜLMEDİ** (otomatik referans grafiği çıkarılmadı).
- Debug/hile: `hud.gd` `TEST_MONEY` kısayolu `OS.is_debug_build()` ile korunuyor (release'te kurulmuyor); `DragRaceScreen.debug_enabled()` yalnızca `DRAG_DEBUG` env / editör + `--drag-debug`.
