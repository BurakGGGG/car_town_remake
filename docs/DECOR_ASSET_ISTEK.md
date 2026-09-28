# Avlu dekorasyonu — üretilenler ve Blender'dan beklenenler

Tarih: 2026-09-27 · Sistem: `gameplay/garage_decor.gd` (katalog) ·
`vfx/decor_builder.gd` (kodla üretilen gövdeler) · `world/garage_decor_view.gd` (avluya yerleşim)

---

## 1. Kodla ürettiklerim (26 eşya)

Hepsi kutu/silindir/küre gibi ilkel gövdelerden, garaj ve showroom ile aynı dilde üretiliyor;
ayrı dosya gerekmiyor. Kategori · eşya · fiyat · garaj değeri katkısı · rütbe kilidi:

| Kategori | Eşya | Fiyat ₺ | Değer ₺ | Rütbe |
|---|---|---|---|---|
| AVLU ZEMİNİ | Karo avlu | 6.000 | 2.400 | 1 |
| AVLU ZEMİNİ | Asfalt avlu | 22.000 | 8.800 | 3 |
| GARAJ DUVARI | Tuğla duvar | 9.000 | 3.600 | 2 |
| GARAJ DUVARI | Panel duvar | 30.000 | 12.000 | 4 |
| ATÖLYE | Palet yığını | 2.500 | 1.000 | 1 |
| ATÖLYE | Takım dolabı | 3.000 | 1.200 | 1 |
| ATÖLYE | Yağ varilleri | 3.500 | 1.400 | 1 |
| ATÖLYE | Lastik rafı | 5.000 | 2.000 | 1 |
| ATÖLYE | Kriko | 9.500 | 3.800 | 2 |
| ATÖLYE | Kompresör | 12.000 | 4.800 | 2 |
| ATÖLYE | Alet arabası | 16.000 | 6.400 | 3 |
| ATÖLYE | Parça rafı | 34.000 | 13.600 | 4 |
| AVLU DÜZENİ | Trafik konileri | 1.500 | 600 | 1 |
| AVLU DÜZENİ | Bariyer | 7.000 | 2.800 | 2 |
| AVLU DÜZENİ | Çöp konteyneri | 11.000 | 4.400 | 2 |
| AVLU DÜZENİ | Aydınlatma direği | 40.000 | 16.000 | 5 |
| AVLU DÜZENİ | Depo konteyneri | 48.000 | 19.200 | 5 |
| AVLU DÜZENİ | Yakıt pompası | 85.000 | 34.000 | 7 |
| AVLU DÜZENİ | Bayrak direği | 120.000 | 48.000 | 8 |
| YAŞAM ALANI | Sehpa | 4.000 | 1.600 | 1 |
| YAŞAM ALANI | Bank | 5.500 | 2.200 | 1 |
| YAŞAM ALANI | Saksı bitki | 6.500 | 2.600 | 2 |
| YAŞAM ALANI | Kanepe | 8.000 | 3.200 | 2 |
| YAŞAM ALANI | Piknik masası | 14.000 | 5.600 | 3 |
| YAŞAM ALANI | Otomat | 26.000 | 10.400 | 4 |
| PANO | Neon tabela | 60.000 | 24.000 | 6 |

Toplam bedel **576.500 ₺**, garaj değeri katkısı **230.600 ₺**.
Yerleştirme yeri: seviye 1'de 3, seviye 2'de 7, seviye 3'te 12, seviye 4'te 18 avlu yeri
(+ 1 duvar panosu + zemin/duvar kaplaması).

---

## 1b. Blender boru hattı ÇALIŞIYOR (2026-09-28)

İlk model üretildi ve oyuna girdi: **LASTİK YIĞINI** (`tyre_pile`, 12.000 ₺).

- Üretim reçetesi: `tools/decor/tyre_pile.py` (parametrik, sabit tohumlu — beğenilmezse
  değeri değiştirip yeniden üretiyoruz, elle modelleme turu yok).
- Gönderici: `tools/decor/blender_send.py` açık Blender oturumuna soketten kod yollar
  (blender-mcp eklentisi, 127.0.0.1:9876) — modelleme ekranda CANLI görünür.
- Dışa aktarım: `tools/decor/export_glb.py` → `assets/decor/tyre_pile.glb` (86 KB, 1.440 üçgen).
- Yükleme: `DecorBuilder.build()` önce `assets/decor/<id>.glb` arar, varsa onu kullanır;
  yoksa kodla üretilen gövdeye düşer. Yani model gelince katalogda hiçbir şey değişmiyor.

**Ölçek zinciri doğrulandı:** Blender 1,34 × 1,00 × 1,16 m → oyunda ölçülen 1,34 × 1,00 × 1,16 m.
Metre → oyun birimi katsayısı `DecorBuilder.METER = 0.1367`.

Yol boyunca bir tuzak: materyal düğümünü ADIYLA aramak (`nodes.get("Principled BSDF")`)
Blender 5.2'de None döndü ve model sessizce BEYAZ çıktı. Artık düğüm TİPE göre aranıyor
(`n.type == 'BSDF_PRINCIPLED'`) ve bulunamazsa hata veriyor. Kendi modellerinde bu seni
ilgilendirmez (materyali elle veriyorsun), ama script üretiminde tekrar etmesin diye not.

---

## 2. Blender listesi KAPANDI (2026-09-28)

Listedeki 11 modelin tamamı üretildi — hiçbiri elle modelleme beklemiyor.

| Model | Ölçü | Üçgen | Not |
|---|---|---|---|
| Otomat | 0,94 × 0,84 × 1,88 m | 528 | Vitrin camı, 4 raf × 5 ürün, tuş takımı, ekran, teslim kapağı |
| Retro yakıt pompası | 1,10 × 0,68 × 2,01 m | 464 | Işıklı cam küre, sayaç penceresi, hortum + tabanca yuvası |
| Jukebox | 0,82 × 0,63 × 1,41 m | 372 | Kavisli üst gövde, krom kemer, plak penceresi, hoparlör ızgarası |
| Kupa vitrini | 1,16 × 0,52 × 1,88 m | 1.872 | **Şeffaf cam**, 3 raf, 9 kulplu kupa, üstten aydınlatma |
| Langırt masası | 1,52 × 1,02 × 1,05 m | 1.660 | 8 çubuk, 22 oyuncu figürü, saha çizgileri |
| Araç lifti | 3,18 × 1,23 × 2,92 m | 432 | İki sütun, delikli raylar, 4 kaldırma kolu, kumanda kutusu |
| Hurda araç | 4,63 × 1,77 × 1,23 m | 672 | Paslı etek, ezik kaput, **kırık şeffaf camlar**, bir teker eksik (çıplak poyra) |
| Motosiklet | 2,01 × 0,62 × 1,05 m | 712 | Telli jantlar, depo, gidon, far, egzoz |
| Tamirci figürü | 0,46 × 0,72 × 1,72 m | 432 | Tulum, şapka, siperlik |
| Su deposu | 2,07 × 1,91 × 4,10 m | 816 | 4 eğik ayak, çapraz bağlar, bantlı tank, konik çatı, merdiven |
| Servis römorku | 4,25 × 2,04 × 1,90 m | 528 | Şasi, kapı + kol, **şeffaf pencere**, çeki oku, destek ayağı |

Yol boyunca bir tuzak daha: **cam opak çıkıyordu.** GLTF'e `alphaMode=BLEND` yazılması için
Base Color'un alfası yetmiyor; `Alpha` girdisi ve `blend_method='BLEND'` de gerekiyor. Kupa
vitrininde kupalar görünmüyordu, düzeltildi (`kit.py` → `mat(..., alpha=)`).

## 3. Üretim boru hattı

| Dosya | İş |
|---|---|
| `tools/decor/kit.py` | Ortak yardımcılar: `box/cyl/cone/ball/torus/mat/finish` — metre ölçeği, taban orijini, birleştirme, GLB yazımı |
| `tools/decor/blender_send.py` | Açık Blender'a soketten kod gönderir (`--kit` ile kiti başa ekler) |
| `tools/decor/props_bitki.py` | 9 bitki / peyzaj |
| `tools/decor/props_avlu.py` | 12 avlu ekipmanı |
| `tools/decor/props_atolye.py` | 10 atölye + yaşam alanı |
| `tools/decor/props_isik.py` | 7 aydınlatma + tabela |
| `tools/decor/props_detay_a.py` | 5 detaylı: otomat, pompa, jukebox, vitrin, langırt |
| `tools/decor/props_detay_b.py` | 6 detaylı: lift, hurda, motor, tamirci, su deposu, römork |
| `tools/decor/tyre_pile.py` | lastik yığını |
| `qa/decor_sheet.gd` | Modelleri nötr sahnede zemin çizgisiyle yan yana çeker (kalite kontrol) |

Bir modeli beğenmezsen ilgili `props_*.py` dosyasındaki değeri değiştirip yeniden gönderiyoruz;
elle modelleme turu yok. Yeni model eklemek için: kit fonksiyonlarıyla çiz → `finish("<id>")` →
katalogda bir satır.
