# HURDALIK — Tasarım kararları

Durum: 2026-10-11. Kullanıcıyla soru-cevapla kararlaştırıldı. Araştırma: `docs/HURDALIK_ARASTIRMA.md`.
Çekirdek (parça envanteri, projeler, kayıt) ve 24 klasik araç kodda hazır. Bu belge haritanın ve
oyuncunun gördüğü her şeyin tasarımıdır.

## 1. Yer ve ulaşım
- Hurdalık şehirde **değil**, **ayrı bir harita**.
- Ulaşım **HARİTA ekranından**. Çizilmiş harita üzerinde ŞEHİR ve HURDALIK simgeleri, aralarında yol;
  ileride yeni mekanlar da buraya eklenecek. Harita görseli Blender'da çizgi-film tarzı render, simgeler
  ve yol kodla çiziliyor.
- **Geçiş:** kısa yol animasyonu kartı (orijinaldeki "Calculating Route!"). Yükleme süresini de gizliyor.
- **Kamera:** şehir gibi gezilebilir (sürükle + iki parmakla yakınlaştır). Saha **orta boy**, varsayılan
  yakınlıkta ~2–3 ekran.
- **Açılış:** bir hikâye görevi ("Hurdacı Necati'yi ziyaret et"). Görev **2. tamir alanı açılınca** gelir;
  proje bir alanı kapladığı için tamir hiç durmaz.

## 2. Görünüş
- **Tarz:** showroom binası gibi. Çizgi-film oranları, düz renk + hafif doku, yumuşak kenarlar.
- **Zemin:** kuru toprak, yağ lekeleri, lastik izleri.
- **Işık:** sıcak, tozlu öğleden sonra.
- **Sınır:** oluklu sac çit (paslı, yamalı, dikenli telli) + üst üste konteynerler + ezilmiş araç yığınları.
- **Nesneler:**
  - Mıknatıslı sarı vinç, döngü animasyonuyla.
  - Araç presi ve yanında ezilmiş araç küpleri, döngü animasyonuyla.
  - Usta barakası: ofis, ışığı yanan pencere, HURDALIK tabelası.
  - Bekçi köpeği ve kulübesi.
  - Vinç ve pres **yalnızca dekor**.
- **Düzen:**
  - Kamera giriş kapısından açılıyor; kapının hemen yanında baraka.
  - Ortada araç sıraları.
  - Arkada vinç, pres ve hurda yığınları.
  - Kenarlarda konteynerler ve hurda duvarı.

## 3. Karakterler
- **Hurdacı Necati:** yaşlı, bıyıklı, tulumlu sahip. Barakanın önünde durur.
- **Çırak Cemo:** genç, kasketli. Sahada dolaşır.
- Sahada basit hareketli 3D figürler. Konuşurken Rıza Usta kartı gibi kodla çizilmiş 2D portre.

## 4. Araçlar
- Sahada **rastgele 3 paslı araç** var (tekerleksiz, paslı) ve **24 saatte bir değişiyor**.
- **Yalnız bu 3 araçtan biri** restore edilebilir. Tam liste koleksiyonda, siluetli.
- **Havuz:** açık kademelerden, henüz restore edilmemiş araçlar.
- **Seçim:** araca dokununca bilgi plakası (ad, yıl, sınıf, parça reçetesi) + RESTORE ET.
- Başlatılan araç sahadan kalkıyor; yeri bir sonraki yenilemeye kadar boş kalıyor.
- **Proje garajda bir tamir alanını kaplıyor** (çekirdekte hazır). Garajda **3 aşamada** görünüyor:
  1. **%0–33:** çıplak demir şasi. Ortak model, ben çiziyorum.
  2. **%34–99:** aracın kendisi, paslı ve tekerleksiz, şasinin üstünde.
  3. **%100:** temiz, parlak araç + kutlama.

## 5. Hurda yığınları
- **Görünüş:** karışık metal yığını (sac, jant, boru, motor parçası). Aranabilir olanın üstünde sarı
  halka / işaret.
- **Sayı ve dolma süresi (2026-10-12, simülasyon + kullanıcı kararı):** sahnedeki **6 yığının hepsi**
  aktif, aranan yığın **8 saatte** dolar, her arama **1 parça**, **%25 boş**. Tamirden düşme **%10**.
  Simülasyon (tools/economy/junkyard_sim.py, günde 3–4 oturum): temel araç ~1,4 gün, usta ~10,7 gün; günde 2
  oturum 1,4 / 11 gün, 6 oturum 1,4 / 9,5 gün — az oynayan geride kalmıyor (en adil seçenek).
- **Gem fiyatı (2026-10-12):** ilk taslağın **iki katı**, parça başı 4–6 gem (günde ~35 gem kazanılıyor).
- **Arama bedava;** tek sınır zamanlayıcı. Sonuç **saf şans**, boş da çıkabilir.
- **Dokununca:** ~1 sn animasyon. Yığın sallanıyor, toz kalkıyor, parça ikonu envantere uçuyor (görev
  ödülündeki uçan para gibi); ya da "Bir şey çıkmadı".

## 6. Arayüz (hurdalık ekranı)
- **Alt plakalar:**
  - PARÇALAR: envanter.
  - HARİTA: şehre dönüş.
  - KOLEKSİYON: restorasyon bölümleri.
  - **Yenilenme sayacı:** yeni araçlara ve yığınların dolmasına kalan süre.
- **Tanıtım:** ilk ziyarette Necati'nin kısa dersi (Rıza Usta dersleri gibi). Cemo ilk yığını arattırıyor;
  ilk arama garantili parça veriyor.

## 7. Ses
- Yeni **hurdalık müzik teması**. Garaj teması gibi özgün beste (tools/music): ağır blues / çelik gitar
  havası; arkada metal tıkırtıları ve uzaktan pres sesi.

## 8. Önceden verilmiş kararlar (çekirdek / araçlar)
- **Parça kaynakları:** yığın, tamirden düşme, onaylı gemle satın alma, arkadaş hediyesi.
- **"Hepsini al":** onaylı.
- **Kademe:** 10 temel restorasyon → usta (Klasik / Yarış).
- **Restorasyon araçları:** trafikte yok, kasada yok, yarış rakibi olmaz, boyanamaz.
- **Koleksiyon:** ayrı bölümde.
- **Satış:** düşük fiyata.
- **Paket:** klasik modeller pakette (ayrı indirme yok).

## 9. Uygulama durumu (2026-10-12)
- **Harita:** tools/world/junkyard.py + export_junkyard.py → assets/world/junkyard.glb. Işık Cycles'la köşe
  rengine ve zemin dokusuna PİŞİRİLİR, oyunda ışıksız çizilir (telefonda GI / gölge yok; Godot GL
  Compatibility köşe rengini sRGB sayar → pişmiş değerler sRGB kodlanır). world/junkyard_world.gd.
- **Günün araçları:** 24 klasiğin paslı, tekerleksiz hurda varyantları (assets/world/junk_wrecks/, ~3.000 üçgen).
- **Ekranlar:** ui/hud/junkyard_screen.gd (saha, yığın arama, araç plakası, PARÇALAR, sayaçlar),
  ui/hud/map_screen.gd (tools/world/map_render.py ile çizilen harita + rota animasyonu + yol kartı),
  ui/hud/restoration_panel.gd (garajdaki proje panosu: tak, onaylı gemle al, bitir, bırak).
- **Garaj:** gameplay/junkyard/restoration_bays.gd + world/restoration_display.gd — liftte 3 aşama
  (assets/world/restoration_chassis.glb şasi → vfx/rust_overlay.gdshader paslı araç → temiz araç).
- **Görev:** "HURDACI NECATİ" (QuestCatalog, 2. alandan sonra); HARİTA plakası görevle görünür, hurdalık
  2. tamir alanıyla açılır (JunkyardManager.OPEN_BAYS).
- **Necati'nin dersi, müzik, portreler:** tamam (TutorialManager.JUNKYARD, tools/music/junkyard_theme.py,
  CoachCard COACH_NECATI / COACH_CEMO).
- **Arkadaş hediyesi (2026-10-12, kullanıcı kararı: orijinal "Ask Friends"):** proje panosunda eksik
  parçaya İSTE (6 saatte bir) → istek açık garaj belgesinde ("ask", 24 saat) → arkadaş ARKADAŞLAR'da
  GÖNDER (bedava, günde bir) → users/{alıcı}/gifts/p_{gönderen}_{gün}; alıcı hurdalığa girince / liste
  yenilenince toplar. Günlük sınır SUNUCUDA (firestore.rules gifts; emülatör testi firebase/rules_test).
  Kurallar canlıya yüklenmeden hediye çalışmaz (yükleme kullanıcı onayıyla).
- **Kalan:** canlı kural yüklemesi; yığın / hediye ekonomisine hediyenin etkisi simülasyonda yok.

## 10. Sıradaki adımlar (ilk plan)
1. **Blender'da kaba yerleşim:** zemin, çit, konteynerler, baraka, vinç, pres, araç sıraları, yığınlar.
   Render kullanıcıya gösterilip onaylanacak, sonra ayrıntıya geçilecek.
2. Hurdalık sahnesi + kamera + HARİTA ekranı + geçiş kartı.
3. Günlük 3 araç, yığın arama, plakalar, proje başlatma.
4. Garajdaki 3 aşamalı proje (şasi modeli + pas efekti).
5. Ekonomi simülasyonu → yığın sayısı ve dolma süresi.
6. Görev, Necati'nin dersi, müzik, karakter figürleri ve portreler.
