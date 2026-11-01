# Optimizasyon turu — 2026-11-01 (kullanıcı yokken)

İstek: kişiselleştirme işinden (avatar, çerçeve, isim havuzu, araç adları) sonra "baştan aşağı bir optimizasyon turu".
Commit / push yok. Ölçümler masaüstünde (Intel ADL, GL Compatibility); telefonda işlemci ~5–8 kat yavaş, kıyas göreli.

## 1. Taban ölçüm (qa/perf_bench.gd, featured.json)

`~/Projects/ct_shots/bench/taban_1101.txt` — seviye 45, 9 araç, **105 dekor eşyası**.

| senaryo | kare ms ort | p95 | çizim | üçgen | VRAM MB | bellek MB |
|---|---|---|---|---|---|---|
| dünya (varsayılan) | 3.12 | 3.65 | 354 | 468k | 146 | 269 |
| garaj | 2.64 | 4.64 | 186 | 105k | 171 | 270 |
| showroom | 4.25 | 5.22 | 387 | 49k | 173 | 272 |
| koleksiyon | 3.70 | 4.52 | 455 | 528k | 168 | 284 |
| görevler | 3.72 | 4.73 | 449 | 532k | 176 | 289 |
| garaj düzenleme | 4.23 | 5.10 | 795 | 464k | 181 | 291 |
| drag koşu | 3.12 | 3.56 | 194 | 191k | 209 | 293 |
| tamir sürerken | 3.91 | 5.09 | 396 | 612k | 199 | 294 |

**Regresyon değil:** çizim çağrıları 25 Ekim tablosundan yüksek (dünya 226 → 354) ama tezgâh kaydı
`bench_saves/featured.json` 2026-11-01 01:02'de değişmiş: 67 → 105 dekor eşyası. `qa/render_breakdown.gd`: dünyanın
251 çağrısı = sergi araçları 73 + şehir süsü 54 + HUD 58 + dekor 16 (+ zemin / gökyüzü); sistem başına maliyet önceki
turla aynı düzeyde. Kıyas için kayıt dosyasının kopyası tutulmalı (bench_saves yazılabilir durumda; bir sonraki tur
önce/sonra'yı aynı kayıtla ölçsün).

## 2. Nereye bakıldı

| alan | ölçüm | sonuç |
|---|---|---|
| Oturmuş dünyada betik | `qa/script_profile.gd world` | 300 karede 63 ms (profilleyici şişirmesiyle) ≈ 0,2 ms / kare → büyük betik darboğazı yok |
| Açılış (gerçek süre) | `qa/main_ready_profile.gd` | Main yükleme 2,8 sn (geliştirmede betik derlemesi dahil), HUD `_ready` 267 ms, ilk kare 1,2 sn |
| Açılışta ses sentezi | `script_profile startup` | şehir uğultusu, gazete / korna / motor / siren sentezi profilde baskın; ama `AudioCache` yayında sürüm başına bir kez üretiyor (geliştirmede bilerek kapalı) → yayında yük yok |
| Profil açılışı | `script_profile open:profile` | betik payı ~10 ms / 40 kare; süre motorun yerleşim / çizim tarafında |
| PROFİL › DÜZENLE (yeni ızgara) | `qa/profile_edit_perf.gd` (yeni) | açılış ort. 41 ms (ilk sefer doku yüklemesi), FOTOĞRAF sekmesi 19 ms, dokunuş gürültü düzeyinde |
| Sızıntı | `qa/sizinti_olcum.gd` profil / düzenle / arkadaşlar / lider / koleksiyon / garaj | bellek turlar boyunca sabit (~277–294 MB); düğüm dalgalanması trafik doğumu |
| Kare başı boşta çalışanlar | statik tarama + profil | 3 düğüm gizliyken her karede çalışıyordu (aşağıda) |
| Ekran taraması | `tools/ekran_tarama.sh p16x9 p20x9` | 8 / 9 madde, hepsi bilinen (ders kartı ikaz şeridi, bayrak rozeti, yarış süresi) + 31 Ekim'den kalma kedi kartı başlığının "…" ile kısalması (bugünkü işten değil) |

## 3. Yapılanlar (görüntü aynı)

- **Gizliyken kare başına çalışanlar:** `TutorialHand`, koç kartı rozeti (`CoachCard._Badge`) ve `PhotoMode` artık
  yalnız görünürken `_process` çalıştırır (`NOTIFICATION_VISIBILITY_CHANGED` / `ENTER_TREE` → `set_process`).
  Önce: oturmuş dünyada (eğitim kapalı) her biri her karede çağrılıyordu (profilde 300 karede 300 çağrı).
- **`RepairManager._tutorial_running`** (her karede, sabır sayacı): eğitim yöneticisi her karede gruptan aranıyordu →
  zayıf referansla bir kez bulunur.
- **`ProfileCatalog.frame()`**: 28 elemanlı diziyi her çağrıda tarıyordu; hareketli çerçeveler her karede birkaç kez
  soruyor → kimlik → kayıt sözlüğü.
- **Yeni avatar / çerçeve kodu:** `AvatarView` arka süs katmanı (kanat) yalnız öyle bir çerçeve takılıyken oluşur
  (listelerdeki her avatara boş düğüm eklenmesin); halka / süs dokuları küçük dairede mipmap'li, büyükte mipmap'siz
  süzgeç. PROFİL › DÜZENLE `changed` + `avatar_changed` aynı karede geldiğinde ızgarayı iki kez kuruyordu → tek
  ertelenmiş kurulum.

## 4. Bilerek yapılmayanlar

- **HUD ekranlarını tembel kurmak** (açılışta HUD 267 ms): yük yükleme ekranından oyun içine, ilk açılışa taşınır
  (takılma). Önceki turlar ekranları bilerek önceden ısıtıyor (prewarm); yönlendirici de örneğe bağlı. Gözetimsiz
  oturumda riskli bir yeniden yazım.
- **Drag pisti kurulumunu ertelemek** (`DragTrack` dokuları ~18 ms profilde): aynı neden, ilk yarışta takılma.
- **Sergi araçlarının üçgeni** (dünyada 382k / 9 araç): görsel kalite kararı (kullanıcı otoparktaki araçların uzaktan
  kötü göründüğünü söylemişti); dokunulmadı.
- **Tam ekran panolar açıkken dünyayı dondurmak**: panelin arkasında trafik durur → görsel değişiklik.

- **Uzak LOD eksikleri (tam paketin bulduğu):** Supra ve R34'ün (Meshy hattı, 10-31 / 11-01) uzak kademe dosyası
  yoktu, VW T1'inki sabahki logo düzleştirmesinden sonra eskimişti. `tools/far_lod/make_far_lod.sh toyota_supra
  nissan_skyline_r34 vw_t1_bus`: şehirdeki en kaba kademe R34 55 452 → 14 157, Supra 33 059 → 7 408, T1 59 184 →
  27 379 üçgen. Yeni araç eklerken bu adım unutulmasın (far_lod_test yakalıyor).

## 5. Sonuç ölçümü ve testler

`~/Projects/ct_shots/bench/sonra_1101.txt` (aynı kayıt): kare süreleri, çizim ve bellek tabanla aynı düzeyde (fark gürültü
içinde; trafik rastgele doğduğu için üçgen ±%5 oynuyor). Düğüm sayısı panolarda ~100 azaldı (garaj düzenleme 5887 →
5783, görevler 5866 → 5762: arka süs katmanı tembel). Bu turun değişiklikleri kare başına mikro kazançlar (telefonda pil /
ısınma) + uzak LOD eksiklerinin kapanması; büyük kalemler önceki turlarda alınmıştı.

**Tam test paketi:** 89 paket, ilk koşuda yalnız `far_lod_test` 2 FAIL (yukarıdaki eksik dosyalar, bugünkü işten
değil) → düzeltildi, `far_lod_test` 11/0. Diğer 88 paket 0 FAIL.
