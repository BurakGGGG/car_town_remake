# Japon drift gösterisi

2026-11-02 kullanıcı isteği: "Gtr hariç 4'ü gerçekten tam bir drift makinesi. Nadir bir olasılıkla 2'şer araç olacak
şekilde şehirde drift atıp gitsinler. Lastik sesleri, dumanlar, güzel drift görüntüsü olsun. Tam o araçlar geçerken oyun
müziği değişip Japon drift müziği gibi olsun. Müzik araçlar sahneye girmeden başlasın. Gerçekten nadir bir olay olsun."

İkinci tur istekleri:

- Hep aynı yoldan gelmesin.
- Lastik izleri yavaşça silinsin.
- Arkadaki araç zıplıyordu, düzelsin.
- Optimizasyon iyi olsun.

## Ne olur

Supra, NSX, RX-7 ve AE86 arasından şehirde olmayan ikisi tandem gelir. R34 dört çeker olduğu için yok.

1. Giriş yolunda manji yapar: sağa sola savrularak kayar.
2. Virajdan önce dışa doğru çalım atar.
3. Kavşakta 40–48° kayarak döner.
4. Çıkış yolunda yine manji yapar ve uzaklaşır.

Arka lastiklerden kalın beyaz duman çıkar, yolda siyah izler kalır. Araçlar kendi pişmiş motor seslerini yüksek devirde
çalar; gaz kesince Supra'nın patlamaları duyulur. Lastik cıyağı sürekli bir döngüdür. Araçlar kavşağı geçince ışıkta
bekleyen bir araç bazen "dıt-dıt" korna çalar.

## Müzik

Kaynak: `tools/music/drift_theme.py`. Ortak sentez kodu `synth_lib.py` dosyasında. Blender'ın python'uyla çalışır
(`/snap/blender/current/5.2/python/bin/python3.13 -I`), FluidSynth koto, taiko ve orkestra vuruşunu çalar. Parça özgün
bir Eurobeat bestesidir.

- **Tempo ve uzunluk:** 155 BPM, 21 sn, tek seferlik (döngü yok).
- **Giriş (4 ölçü):** koto, taiko ve yükselen hazırlık.
- **Drop:** tam 6,1935 sn'de, `DriftEvent.MUSIC_DROP`.
- **Nakarat:** 6 ölçü.
- **Son akor:** 15,48 sn'de, ardından koto yankısı gelir.
- **Garaj temasına dönüş:** 18 sn'den itibaren çapraz geçişle (`GameMusic.DRIFT_HANDBACK`).

**Senkron:** gösteri saati müziğin çalma konumuna bağlıdır. Öndeki aracın ekrana girdiği an drop'a denk gelir; ölçülen
fark 2–30 ms. Araçlar drop'tan `APPROACH` (2,2 sn) önce ekran dışında doğar, motor sesi yaklaşırken duyulur. Doğma anı
araçlar doğmadan hemen önce o anki kameraya göre yeniden hesaplanır, çünkü oyuncu müziği duyup kamerayı kaydırabilir.

**Dünya örtülürse:** garaj, harita, yarış gibi bir ekran açılınca tema kesilir ve garaj teması kaldığı yerden döner.
Yarış ya da hurdalık teması başlarsa drift teması hemen susar.

## Nadirlik

- Sayaç yalnız şehir ekrandayken işler; eğitimde ve dünyayı örten ekranlarda durur.
- Sayaç oturumlar arasında kalıcıdır (`user://city_events.cfg`).
- İlk gösteri toplam 9 dk sonra gelir, sonrakiler 14–24 dk arayla.
- Süre dolunca şu koşullar sağlanana kadar bekler:
  - ekran ya da pano açık değil,
  - kovalamaca, trafik polisi ya da yarış daveti yok,
  - kamera rotayı görüyor.
- **Hemen denemek için:** `CT_DRIFT_IN=15 godot-4 --path .` ile 15 sn sonra başlar.

## Rota

Giriş yolu dört yoldan rastgele seçilir; bir önceki gösterinin girişi en sona bırakılır. Dönüş yönü kameranın gördüğüne
göre ağırlıklıdır: görünen dönüş daha olasıdır ama ikisi de olabilir. Seçilen yolun hiçbir dönüşü görünmüyorsa sıradaki
yol denenir.

Çizgi ve pozlar önceden hesaplanır (`traffic/drift_line.gd`):

- **Yol:** Hermite anahtar noktalarından çizilir, eğrilik yumuşatılır.
- **Kayma açısı:** eğrilikten ve biraz ileriden bakarak hesaplanır, yay-sönüm modeliyle izlenir.
- **Ön aks çizgiyi izler:** kuyruk dışa açılır.
- **Karşı direksiyon:** ön tekerler hareket yönüne bakar.
- **Gövde:** virajın dışına yatar, gazda arkaya oturur.
- **Arka tekerler:** patinajda 1,8 kat hızlı döner.

**Arkadaki araç** kendi hız profiliyle sürer. Öndekine olan yol mesafesini yumuşak bir denetleyici tutar: düzlükte 0,98,
virajda 0,8. Eskiden konumu öndekinden basamaklı bir mesafeyle türetiliyordu. Bu yüzden hızı kare kare 1 birim/sn
sıçrıyor, gövdesi ±0,04 arasında titriyordu (51 titreme); şimdi titreme yok.

## Sahne güvenliği

Hazırlık, gösteriden önce sessizce yapılır:

- yeni araç ve yarış daveti doğmaz,
- kavşağa yalnız boşalması gereken iki şerit girer: giriş şeridi ve çıkış yolunun karşı şeridi,
- bu şeritler, kavşak ve çıkış yolunun başı boşalınca gösteri başlar; 25 sn'de boşalmazsa vazgeçilir.

Gösteride kavşak herkese kapalıdır. Araçlar kavşağı geçince açılır, araçlar gidince doğum sürer. Bekleyen müşterinin
sabrı işlemez; kaldırımdan çıkıp araçların önüne girmez. Dörtlü, kovalamaca ve trafik polisi bekler.

## Efektler ve maliyet

2026-11-02 masaüstü ölçümü: `qa/drift_fx_bench.gd`.

**Duman** (`vfx/drift_smoke.gd` ve `.gdshader`)

- Tek MultiMesh, 260 topak, tek çizim.
- Hareketin tamamı shader'da, doğuş verisinden hesaplanır. İşlemci her topağı yalnız doğarken bir kez yazar.
- Maliyet ~10 µs/kare; önceki işlemci benzetimi 154 µs/kare idi.
- Son topak sönünce düğüm uyur.
- Kaliteye göre yoğunluk: düşük %50, orta %80.

**İzler** (`vfx/skid_marks.gd` ve `.gdshader`)

- Kapanmış şeritler durağan bir mesh'te, büyüyen şeritler ikinci küçük mesh'te; ikisi iki çizim.
- Açık şeritlerin yalnız son 5 parçası yeniden hesaplanır.
- Maliyet ~45 µs/kare; önceki tam yeniden kurulum 221 µs/kare idi.
- **Yavaşça silinir:** her nokta çizildiği anı taşır, önce çizilen önce solar. 6 sn sonra solmaya başlar, 70 sn'de
  kaybolur; solarken griye döner. Solarken yalnızca bir shader değeri değişir.

**Diğer**

- Rotalar yalnız gösteri yaklaşınca arka plan iş parçacığında kurulur (~120 ms, iş parçacığında) ve gösteriden sonra
  bırakılır.
- Modeller gösteriden önce arka planda yüklenir, sonra bırakılır.
- Poz örnekleme ~7 µs/araç.
- Kare süresine ve çizim çağrısına ölçülebilir etkisi yok.

## Ses düzeyleri

`qa/drift_event_qa.gd` kayıtlarının bus bus ölçümüne göre:

- Araçlar ekranın ortasından geçerken toplam ses müziğin ~3–4 dB üstündedir.
- Motor `ENGINE_DB` −16, cıyak `SQUEAL_DB` −14, ikisi de Ambience bus'ında.
- Müzik `GameMusic.DRIFT_DB` −4; nakarat garaj temasından ~2 dB yüksektir.

## Test ve QA

**Test:** `tools/run_tests.sh drift_event_test` (pencereli), 97 kontrol:

- sekiz rotada araçlar yolda kalır, birbirine değmez, virajda büyük açıyla kayar, pürüzsüz gider,
- dört yoldan rastgele gelir, art arda aynı yoldan gelmez,
- hazırlık ve kavşak kuralları,
- gösteride trafiğe değmez,
- drop senkronu,
- duman ve iz oluşur,
- müzik katmanları,
- kalıcı sayaç,
- doğal akış (sayaç, ön yükleme, hazırlık, gösteri).

`run_tests.sh` ve `qa_isolated.sh` her pakette `city_events.cfg`'yi siler, sayaç testler arasında birikmez.

**QA:** `CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/drift_event_qa.gd --resolution 1152x648 [-- x,z ±1]`

- Ortam değişkenleri:
  - `QA_ZOOM=3.2` varsayılan görünüm,
  - `QA_MUTE=engine|squeal` motoru ya da cıyağı susturur,
  - `QA_NOSHOT=1` kare kaydetmez,
  - `QA_SAVE=<kayıt>` o kaydın kopyasıyla açar.
- Çıktılar `~/Projects/ct_shots/drift/` altında:
  - kareler,
  - `drift_master.wav`, `drift_music.wav`, `drift_ambience.wav`,
  - dinleme kopyaları `drift_theme.wav` ve `drift_squeal_loop_x3.wav`.

Telefonda denenmedi.
