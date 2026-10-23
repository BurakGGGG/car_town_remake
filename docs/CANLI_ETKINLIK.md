# Canlı etkinlik ve içerik paketleri (güncellemesiz)

2026-10-23, kullanıcı isteği: "hafta sonu etkinliği deyip güncelleme atmadan etkinlik yapabileyim; hepsini ekle, panelime de
ekle". Bu sürümden (1.1.0) itibaren etkinlik ve yeni dekor içeriği Play'e güncelleme göndermeden açılır.

## Nasıl çalışır

- Etkinlik Firestore `config/app.event` belgesindedir; yönetim paneli **Etkinlik** sekmesi yazar.
- Oyun belgeyi açılışta, öne gelince ve 15 dakikada bir okur (misafir de). Başlangıç saatinde kendiliğinden başlar, bitişte söner.
- Okunan son belge cihazda saklanır: internet yokken de etkinlik süresince geçerlidir.
- Üst ortada geri sayımlı **tabela** çıkar ("×2 · KIŞ ETKİNLİĞİ · ÇİFTE PARA · İNDİRİM −%30 · +3 · 23:41:05"). Sığmayan
  modüller "+N" olur.
- Tabelaya dokununca **ETKİNLİK PANOSU** açılır: afiş, açıklama ve her modül için bir satır + oraya götüren düğme.
- Bir etkinlikte modüllerin hepsi ya da birkaçı olabilir. En az biri dolu olmalı; hiçbiri doluysa etkinlik yok sayılır.

## Modüller (panel ve oyun aynı sınırları uygular)

| Modül | Ne yapar | Sınır |
|---|---|---|
| 1 · Çifte para / XP | Tamir ve yarış ödülü çarpanı. Tamir işi başlarken çarpan sabitlenir. | 1–3 |
| 2 · İndirim | Kasalar (gem), GERİ AL araçlar (₺), dekor (₺ ve elmas, karo / duvar dahil), modifiye parçaları. Görünen fiyat = düşen fiyat; kartlarda "−%30" etiketi. | %0–50 (GERİ AL'ınan araç %40'a satılır: %50'yi geçen indirimle al-sat kâr ederdi) |
| 3 · Etkinlik kasası | Seçili kasada işaretli araçların çıkma ağırlığı çarpılır. Showroom'da kasa "★" ile işaretli, oran listesi GERÇEK oranı gösterir (★ işaretli araçlar). | çarpan 2–5, araçlar o kasanın havuzundan |
| 4 · Etkinlik görevleri | GÖREVLER'de en başta ETKİNLİK sekmesi. Yalnız etkinlik sürerken sayar. Bitip alınmayan ödül etkinlik sonunda kendiliğinden verilir. HEPSİNİ AL bunları da toplar. | en çok 6 görev; ödül ₺ ≤ 5 M, elmas ≤ 1000, XP ≤ 100 b, + kasa, + eşya |
| 5 · Özel rakip | Panodaki YARIŞ pisti doğrudan açar. Araç, her kategoride aynı modifiye kademesi, boya ve ad panelden. Yarışılabilir (sınırsız); özel ödül ilk galibiyette, etkinlik başına bir kez. Görev türü "Etkinlik rakibini yen" bunu sayar. | kademe 0–5; polis gibi edinilemeyen araç olmaz |
| 6 · İçerik paketi | Etkinliğin paketi: paketin "yalnız etkinlikte" eşyaları bu etkinlik sürerken dekor mağazasında "ETKİNLİK" etiketiyle satılır; afiş panonun başında. | paket, paket listesinde olmalı |

Görev türleri: tamir, tamirden ₺, uzun iş, yarışa katıl, yarış kazan, etkinlik rakibini yen, kasa aç, kasa sipariş et, eşya
yerleştir, eşya satın al, araç boya, modifiye tak, hurdalık yığını, hurdalık parçası, arkadaş yarışı, arkadaş yarışı kazan,
₺ harca. Metinler oyunda 5 dilde hazırdır.

**Etkinlik kimliği:** panel her yeni etkinliğe yeni kimlik verir. "YENİ etkinlik olarak yayınla" işaretliyse görev ilerlemesi
ve özel rakip ödülü herkes için sıfırlanır. İşaretsiz kaydetmek süren etkinliği düzeltir; ilerleme korunur.
**Etkinliği bitir:** alan silinir. Biten ama alınmamış görev ödülleri oyunculara kendiliğinden verilir.

## Hafta sonu etkinliği: adım adım

1. Paneli aç (`cd firebase/admin && npm start`, terminaldeki bağlantı) → **Etkinlik**.
2. Başlangıç / bitiş: ör. Cuma 18:00 → Pazar 23:59. Başlık: KIŞ ETKİNLİĞİ (+ İngilizce). İsteğe bağlı açıklama.
3. İstediğin modülleri doldur (ör. para ×2, kasalar %30, 3 görev, özel rakip).
4. **Kaydet ve yayınla.** Başlık yanındaki rozet "başlayacak / SÜRÜYOR / bitti" gösterir.

## İçerik paketi (yeni dekor eşyası + afiş)

Paket bir Godot `.pck` dosyasıdır. Oyuncu onu arka planda bir kez indirir ve hep saklar. Örnek paket: kış çamı + afiş,
yaklaşık 210 KB.

**Ne taşır:**
- Yalnızca içerik: model, doku, afiş, tanım.
- Oyun kodu taşımaz. Play kuralı: uygulama kendini Play dışından güncelleyemez.
- Paket oyunun var olan hiçbir dosyasını ezemez: `load_resource_pack(..., false)`.
- Yalnızca listedeki SHA-256 özetiyle birebir aynıysa bağlanır.

**Yeni araç pakette gelmez.** Bir aracın 10'a yakın üretilmiş dosyası (LOD, boya maskesi, küçük resim, rakip havuzu, ölçüler)
trafik, garaj, yarış ve kayıt sistemlerine bağlı. Sınırlı süreli araç için önerilen yol:
- aracı bir güncellemeyle oyuna koy;
- etkinlik kasasıyla (modül 3) ya da görev / rakip ödülüyle öne çıkar.

### Paket kurmak

1. Klasör: `tools/live_pack/content/<kimlik>/`. Kimlik: küçük harf / rakam / _, ör. `kis_2026`.
2. `pack.json` — örnek: `tools/live_pack/content/ornek_kis/pack.json`:
   - `banner`: afiş, ham PNG. Önerilen 960×240, yazısız.
   - `decor`: eşyalar. Her eşya `decor/decorations.json` kaydı gibidir (`id`, `kind`, `price` ya da `price_gems`, `value`,
     `min_level`), ek olarak:
     - `model`: `models/x.glb` ya da oyundaki bir `res://` modeli
     - `title`: dil sözlüğü `{"tr": …, "en": …}`; oyunda büyük harfe çevrilir
     - `event_only: true`: yalnızca bu paketin etkinliği sürerken satılır
   - `kind`: luxury, workshop, lounge, wall_item, yard ya da plant.
   - Eşya kimliği oyunda ve başka pakette olmamalı. Kimlik kalıcıdır: oyuncunun kaydına yazılır.
3. Modeller `models/` altına `.glb` olarak. Blender hattı: `tools/decor`, docs/dekorasyon notları.
4. `tools/live_pack/build_pack.sh <kimlik>` → `firebase/admin/packs/<kimlik>.pck` + özet dosyası.
   - Araç önce modelleri içe aktarır, sonra paketi kurar.
   - Kod dosyası ya da oyunda olan kimlik varsa durur.
5. Panel → Etkinlik → **İçerik paketleri** → "Bilgisayardaki paketler" → **Storage'a yükle ve listeye ekle**.
   - Paket Firebase Storage'a gider: `live_packs/<kimlik>-<özet>.pck`, indirme anahtarlı adres.
   - Storage açık değilse panel söyler. O durumda paketi başka yerde barındır (ör. sitenin `static/` klasörü) ve
     **Adresten ekle**'yi kullan; panel özeti kendisi hesaplar.
6. Etkinliğin "6 · İçerik paketi" alanında paketi seç → **Kaydet ve yayınla**.

### Kurallar

- **Yayındaki paketi listeden çıkarma.** Paketten eşya almış oyuncu, paket listedeyken o eşyayı görür.
  - Paket çıkarılırsa eşya kayıttan SİLİNMEZ: "bekleyen" olarak kayda yazılmaya devam eder (`DecorManager` dormant).
  - Paket listeye geri gelince eşya yerine konur.
- **Aynı kimlikle değiştirilmiş paket** (yeni özet) indirilir ama oyunun o açılışında bağlanamaz; sonraki açılışta gelir.
  - Acil değilse yeni kimlikle paket yayınla.
- Yeni kurulumda ya da paket henüz inmemişken kayıttaki paket eşyaları da bekler.
  - Ödülü paket eşyası olan görevde ÖDÜLÜ AL, eşya inene kadar "EŞYA İNİYOR" der.
- Fiyat ve değer: oyunun kendi eşyalarının ölçeğinde tut. Garaj değeri `value` ile büyür.

## Kod haritası

| Parça | Dosya |
|---|---|
| Doğrulama, fiyat / oran / görev / rakip kapısı | `gameplay/backend/live_event.gd` (`LiveEvent`) |
| Belge okuma, statik erişim, paket listesi | `gameplay/backend/app_config.gd` (`AppConfig.active_event`, `packs`, `current`) |
| İndir, doğrula, sakla, bağla | `gameplay/backend/live_packs.gd` (`LivePacks`; açılışta `LoadingScreen` → `mount_cached`) |
| Paket eşyaları kataloğa, yalnız-etkinlik satışı | `gameplay/garage_decor.gd` (`register_pack_items`, `on_sale`) |
| Bekleyen eşya (kayıttan silinmez) | `gameplay/decor_manager.gd` (`_dormant_*`, `revive_dormant`) |
| İndirim | `CrateCatalog.sale_price`, `VehicleOwnership.buy_price`, `DecorManager.price_of`, `PerformanceMods.price` |
| Etkinlik kasası | `CrateCatalog.odds` |
| Görevler | `MissionManager` (etkinlik görevleri bölümü), `MissionScreen` ETKİNLİK sekmesi |
| Özel rakip | `RaceManager.start_event_rival` / `_pay_event_rival`, `Hud.start_event_race` |
| Tabela / pano | `ui/hud/event_banner.gd`, `ui/hud/event_screen.gd` |
| Paket kurucu | `tools/live_pack/` (`build_pack.sh`, `LivePackBuilder`) |
| Panel | `firebase/admin/lib.mjs` (`buildEvent`, `buildPacks`, `buildEventDoc`), `server.mjs` (`/api/event`, `/api/packs/*`), `public/index.html` |
| Testler | `tests/live_event_test.gd`; panel `npm test` + `npm run e2e`; görsel `qa/live_ops_shots.gd` |
