# Canlı etkinlik ve içerik paketleri (güncellemesiz)

2026-10-23, kullanıcı isteği: "hafta sonu etkinliği deyip güncelleme atmadan etkinlik yapabileyim; hepsini ekle, panelime de
ekle". Bu sürümden (1.1.0) itibaren etkinlik ve yeni dekor içeriği Play'e güncelleme göndermeden açılır.

## Nasıl çalışır

- Etkinlikler Firestore `config/app.events` listesindedir (takvim, 2026-10-26); yönetim paneli **Etkinlik** sekmesi yazar. Takvimi
  bilmeyen eski sürümler yalnız `config/app.event` okur: panel ve `eventsTick` orayı süren / sıradaki etkinliğin AYNASI olarak
  tutar (aşağıda "Takvim ve etkinlik aracı").
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
| 7 · Etkinlik aracı | Bütün görevleri bitiren aracı kalıcı alır; o zamana kadar ödünç (yalnız etkinlik yarışları). Ayrıntı aşağıda. | edinilebilir araç; en az bir görev; teselli elması 0–1000 + satılan kasa |

Görev türleri: tamir, tamirden ₺, uzun iş, yarışa katıl, yarış kazan, etkinlik rakibini yen, kasa aç, kasa sipariş et, eşya
yerleştir, eşya satın al, araç boya, modifiye tak, hurdalık yığını, hurdalık parçası, arkadaş yarışı, arkadaş yarışı kazan,
₺ harca; 2026-10-26: etkinlik aracıyla yarış kazan (`event_car_wins`), etkinlik aracıyla yarışa katıl (`event_car_races`), arkadaş
garajı ziyaret et (`garage_visits`). Metinler oyunda 5 dilde hazırdır. Etkinlik aracı görevleri yalnız araçlı etkinlikte yazılabilir.

**Etkinlik kimliği:** panel her yeni (ve kopyalanan) etkinliğe yeni kimlik verir. Düzenlemek kimliği korur: süren etkinliği
düzeltir, ilerleme korunur. Düzenlerken "YENİ etkinlik olarak kaydet" işaretlenirse yeni kimlik alır: görev ilerlemesi, özel rakip
ödülü ve etkinlik aracı ilerlemesi herkes için sıfırlanır.
**Süren etkinliği silmek** onu hemen bitirir. Biten ama alınmamış görev ödülleri oyunculara kendiliğinden verilir; görevleri
bitmemiş etkinlik aracı geri alınır.

## Hafta sonu etkinliği: adım adım

1. Paneli aç (`cd firebase/admin && npm start`, terminaldeki bağlantı) → **Etkinlik**.
2. **+ Yeni etkinlik.** Başlangıç / bitiş: ör. Cuma 18:00 → Pazar 23:59 (yeni etkinlik varsayılan olarak takvimdeki son
   etkinliğin bitişinden başlar). Başlık: KIŞ ETKİNLİĞİ (+ İngilizce). İsteğe bağlı açıklama.
3. İstediğin modülleri doldur (ör. para ×2, kasalar %30, 3 görev, özel rakip, etkinlik aracı).
4. **Kaydet ve yayınla.** Bütün takvim hemen yayınlanır; listedeki rozet "başlayacak / SÜRÜYOR / bitti" gösterir.

## Takvim ve etkinlik aracı (2026-10-26)

### Takvim

- Panel **Etkinlik** sekmesi bir **liste**dir: en çok **12** etkinlik önceden planlanır, başlangıca göre sıralı. Her satırda başlık,
  tarih, durum rozeti (başlayacak / SÜRÜYOR / bitti), modül özeti, varsa araç adı ve "bildirimli" işareti. Düğmeler: **+ Yeni
  etkinlik**, **Düzenle**, **Kopyala** (yeni kimlik, aynı süre, ilk gelecek haftaya kaydırılır), **Sil**.
- Her kaydet / sil işlemi listenin TAMAMINI yazar (`POST /api/events` → `config/app.events`, tek işlemde; öbür alanlar —
  `min_code`, bakım, duyuru, `ads` — korunur). Paket listesi değişikliği **Paket listesini yayınla** ile ya da bir etkinliği
  kaydedince yayınlanır.
- **Çakışma yasak:** oyun aynı anda tek etkinlik gösterir; zaman aralıkları kesişen iki etkinlik kaydedilmez (hata iki etkinliği
  adı ve tarihiyle söyler). Art arda gelmek serbest: biri biterken (`end`) öbürü başlayabilir (`start` = önceki `end`).
- Kimlikler listede tekildir. Modülsüz etkinlik kaydedilmez.
- Biten etkinlik listede soluk kalır; bitişinin üzerinden **30 gün** geçmişse sonraki kayıtta listeden düşer.
- Takvim hiç kaydedilmemişse (eski tek etkinlik düzeni) panel `config/app.event`'i listenin ilk öğesi olarak gösterir; ilk kayıtta
  takvime geçer.

### Etkinlik aracı (modül 7)

`car = {id, owned_gems, owned_crate}`:
- `id`: edinilebilir araç (katalogdan; polis gibi edinilemeyen olmaz — özel rakiple aynı kural).
- Etkinliğin **bütün görevlerini** bitiren oyuncu aracı **kalıcı** alır. O zamana kadar araç ÖDÜNÇTÜR: yalnız etkinlik
  yarışlarında kullanılır (günde 3 yarış, ödüllü reklamla +1: reklam türü `event_race`, panel **Reklamlar** sekmesi). Etkinlik
  görevler bitmeden sona ererse araç geri alınır, ilerleme kaybolur.
- Araçlı etkinlikte **en az bir görev şart** ("Etkinlik aracı için en az bir görev gerekli"). Araç + görev tek başına geçerli
  bir etkinliktir. `event_car_wins` / `event_car_races` görevleri yalnız araçlı etkinlikte yazılabilir.
- `owned_gems` (0–1000) ve `owned_crate` (boş ya da SATILAN bir kasa; hediye kasası olmaz): oyuncuda araç zaten varsa
  görevler bitince verilen teselli ödülü.
- `reveal_days` (0–14, varsayılan 3; araçlı etkinlikte hep yazılır): oyundaki takvim yaklaşan etkinliğin aracını başlangıçtan bu
  kadar gün önce gösterir.

### Başlayınca bildirim

`notify: true` ("Başlayınca bildirim gönder"): etkinlik başlayınca `eventsTick` dil konularına (`news_tr` … `news_fr`, misafir de
abone) BİR KEZ bildirim yollar. Başlık = etkinlik başlığı (o dilde yoksa İngilizce, o da yoksa Türkçe), metin araçlı / araçsız
şablondan ("Etkinlik başladı! Görevleri bitir, etkinlik aracı senin olsun." / "Etkinlik başladı! Kaçırma."); veri
`{kind: "event", id}`. Başlangıçtan en geç 10 dakika sonra gider. 6 saatten eski başlamış etkinliğe hiç gitmez (dağıtımdan hemen
sonra eski etkinliğe bildirim gitmesin). Gönderilenler `ops/event_push = {etkinlikKimliği: unix sn}` belgesinde (istemciye kapalı);
aynı kimliğe ikinci kez gitmez, düzenleme yeniden göndermez ("YENİ etkinlik olarak kaydet" yeni kimlik = yeni bildirim). Hiçbir
dile gidemezse işaretlenmez, sonraki turda yeniden denenir.

### Belge biçimi

```json
{
  "events": [
    {
      "id": "e_mvod153h", "title": {"tr": "SÜPER HAFTA", "en": "SUPER WEEK"}, "text": {},
      "start": 1793400000, "end": 1793572800, "money_mult": 2, "xp_mult": 1,
      "missions": [{"id": "m1_ab12", "metric": "event_car_wins", "target": 3, "money": 0, "gems": 20, "xp": 0, "crate": "", "decor": ""}],
      "car": {"id": "ford_focus", "owned_gems": 150, "owned_crate": "city_crate"},
      "reveal_days": 3, "notify": true
    }
  ],
  "event": { "…": "süren, yoksa sıradaki etkinliğin aynısı (eski sürümler)" }
}
```

Modül alanları (`sale`, `crate_boost`, `missions`, `rival`, `pack`, `car`) yalnız doluysa yazılır; `notify` yalnız `true` ise.

### Eski sürümler: `config/app.event` aynası

1.1.1 ve öncesi yalnız `config/app.event` okur. Takvim her yazıldığında aynı işlemde `event` = **süren** etkinlik (start ≤ şimdi
< end), yoksa **sıradaki** (en küçük start > şimdi; eski sürüm başlangıç saatinde kendisi açar), o da yoksa alan silinir. Tek
kod: `functions/events_tick.js` `mirrorEvent` (panel `lib.mjs` üzerinden aynısını kullanır). Eski sürüm bilmediği görev türlerini
(`event_car_*`, `garage_visits`) ve `car`'ı yok sayar: yalnız araç + araç görevi olan etkinlik eski sürümde görünmez.

### eventsTick (Cloud Function, 10 dakikada bir)

- `config/app`'i okur (1 okuma). `events` yoksa (takvim hiç kaydedilmemiş) hiçbir şey yazmaz.
- Ayna değiştiyse (etkinlik bitti → sıradakine geçiş, son etkinlik bitti → silme) İŞLEM içinde yeniden okuyup yalnız `event` +
  `updated_at` günceller; panelin aynı anda yazdığı listeyi ezmez. Kimse panele dokunmasa da eski sürümler en geç 10 dakikada
  sıradaki etkinliği görür.
- Bildirim adayı varsa `ops/event_push`'u okur, yukarıdaki kuralla gönderir.
- Bölge europe-west4, saat dilimi Europe/Istanbul, en çok 1 örnek. Dağıtım: `firebase deploy --only functions:eventsTick
  --project car-town-remake`.

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
| Panel | `firebase/admin/lib.mjs` (`buildEvent`, `buildEvents`, `buildPacks`, `buildEventsDoc`, `eventsOf`), `server.mjs` (`/api/events`, `/api/packs/*`), `public/index.html` |
| Ayna + başlangıç bildirimi | `firebase/functions/events_tick.js` (`mirrorEvent`, `eventsTick`), `index.js` `eventsTick` |
| Testler | `tests/live_event_test.gd`; panel `npm test` + `npm run e2e`; functions `npm test` (`test/events_tick.test.js`); görsel `qa/live_ops_shots.gd` |
