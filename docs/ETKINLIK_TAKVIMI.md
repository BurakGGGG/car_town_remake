# Etkinlik takvimi + etkinlik aracı (2026-10-26)

Özellik raporu P1 #5. Kararlar kullanıcıyla soru-cevapla verildi; görünüm taslak **B "ARACA GİDEN YOL"** (tuval:
https://claude.ai/artifact/EZb11w5LLrPHQA2Wso8Lst). Kullanıcının taslağa notu: "arka plan daha bulanık olsun, yol çizimi
daha cool olsun". Panelde planlama ve başlangıç bildirimi: docs/CANLI_ETKINLIK.md, "Takvim ve etkinlik aracı" bölümü.

## Kurallar (kullanıcı kararları)

- **Takvim:** etkinlikleri yönetim paneli liste olarak planlar (`config/app.events`, en çok 12, pencereler çakışmaz).
  - Oyun süren etkinliği listeden seçer: `LiveEvent.active_raw`, penceresi şimdiyi kapsayanların en erken başlayanı.
  - Takvimde süren ve yaklaşan en çok 4 etkinlik görünür (`LiveEvent.calendar`).
  - Eski tek alan `config/app.event` yine okunur. Eski sürümler için panel ve `eventsTick` süren ya da sıradaki
    etkinliği oraya da yazar; aynı kimlik bir kez sayılır.
- **Etkinlik aracı** (`car` modülü: `{id, owned_gems, owned_crate}`): mevcut katalogdan, edinilebilir bir araç.
  - Etkinlik sürerken **ödünç** verilir ve yalnız **etkinlik yarışında** kullanılır. Showroom'un karşısındaki alt
    müşterilerin beklediği kaldırımın köşesinde, garajın köşesinin dibinde, burnu showroom'a dönük park eder (kullanıcı
    kararı).
  - Etkinlik görevlerinin **hepsi** bitince oyuncunun olur (`VehicleOwnership.add_vehicle`; keşif ve koleksiyon ödülleri
    de işler).
  - Araç oyuncuda zaten varsa görevler yine yapılır; ödül elmas + kasa (`owned_gems`, `owned_crate`).
  - Etkinlik biterken görevler bitmemişse araç geri alınır ve **ilerleme silinir**. Görev ilerlemesi etkinlik
    kimliğine bağlıdır.
  - Görevsiz etkinlikte araç yok sayılır.
- **Etkinlik yarışı:** günde **3 hak**, ödüllü reklamla günde **+1** (`AdPolicy.EVENT_RACE`). Hak yarış başlarken düşer.
  - Oyuncunun aracı etkinlik aracıdır (sahibiyse kendi modifiyesiyle).
  - Rakip o aracın performans havuzundan isimsiz yapay zekâdır.
  - Normal yarış ödülü verilir.
  - Ödünç araç oyuncunun değil: koşusu arkadaşlara gitmez; rekor, araç sayaçları ve öğrenen zorluk yazılmaz.
- **Yeni görev türleri:**
  - `event_car_wins`: ETKİNLİK ARACIYLA N YARIŞ KAZAN
  - `event_car_races`: ETKİNLİK ARACIYLA N YARIŞA KATIL
  - `garage_visits`: N ARKADAŞ GARAJI ZİYARET ET (arkadaşın ya da öne çıkan ustanın garajı; ziyaretten önce sayılır)
  - Tamir, kasa aç, para kazan gibi eski türler de kullanılabilir.
- **Takvimde araç:** yaklaşan etkinliğin aracı başlangıçtan `reveal_days` gün önce görünür (varsayılan 3); öncesinde
  siluet ve "ARAÇ YAKINDA AÇIKLANACAK".
- **Başlangıç bildirimi:** panelde etkinlik başına kutucuk (`notify`); gönderen `eventsTick` fonksiyonu.
- 29 Ekim için özel bir şey yok (kullanıcı).

## Ekranlar

- **ETKİNLİK PANOSU** (`ui/hud/event_screen.gd`):
  - Arka plan bulanık (`vfx/screen_blur.gdshader`: ekran dokusunun mipmap'i, tek örnek; garaj odağıyla aynı yöntem).
  - Üstte başlık + geri sayım; altında modül çipleri. Dokununca oraya gider: `Action_showroom`, `Action_missions`,
    `Action_race` (özel rakip), `Action_decor`.
  - Ortada **EventRoad** (`ui/hud/event_road.gd`), kodla çizilen kıvrımlı pist:
    - kırmızı-beyaz kerb, beyaz kenar çizgisi, kesik orta şerit;
    - biten kısım altın gibi parlar, şu anki durakta üstten görünen küçük araç;
    - başta dama bayrak, finişte ışıklı FİNİŞ kapısı, kenarda koniler.
  - Görevler pistin durakları. Plakalar dönüşümlü alt / üst dizilir; ödülü bekleyen görevde ÖDÜLÜ AL.
  - Finişte aracın resmi + ÖDÜNÇ / ✔ ARAÇ SENİN! / ZATEN SENDE.
  - Altta **ETKİNLİK YARIŞI · 2 / 3 HAK** (`Action_car_race`), reklamla **+1 HAK** ve **TAKVİM** şeridi.
  - Görevsiz etkinlikte yol yerine eski modül satırları.
  - Süren etkinlik yokken yalnız takvim açılır ("ETKİNLİK TAKVİMİ", büyük kartlar).
- **Tabela** (`ui/hud/event_banner.gd`):
  - Araçlı etkinlikte rozetin yerinde aracın resmi; ana satır "VIER SPORT 85 · 2 / 5 GÖREV".
  - Süren etkinlik yokken 3 gün içinde başlayacak etkinlik varsa **YAKINDA** hâli: başlangıca geri sayım; dokununca
    takvim açılır.
- **Kaldırımda ödünç araç** (`world/event_car_spot.gd`, EventCarSpot; kullanıcı: "tamire gelen araçların olduğu kaldırımın
  köşesinde, tam garajın köşesindeki kaldırımda, showrooma bakar şekilde"):
  - Müşterilerin beklediği kuzey kaldırımda (z −0,2–0), garajın sağ-ön köşesinin dibinde (garaj büyüse de bu köşe
    sabit), kavşak köşesine yakın durur (`EventCarSpot.PARK` = x −0,34 · z −0,1); burnu doğuya, kavşağın karşısındaki
    showroom'a dönük. Müşteriler daha batıda bekler ve tamire ışınlanır: yolları kesişmez.
  - Gölgesini kendi taşır (`CarShadow`): pişmiş şehir gölgesine girmez.
  - Üstünde koyu tabela "ÖDÜNÇ · ETKİNLİK ARACI / YARIŞ ▶ 2 / 3". Araca dokununca pano açılır.
  - Kazanınca, etkinlik bitince ya da araç oyuncudaysa kalkar. Garaj zeminine girmez, garaj değerine katılmaz.
- **Kazanınca:** HEDİYEN GELDİ! ekranının dilinde **ETKİNLİK ARACI SENİN!** (zaten varsa **ETKİNLİK TAMAMLANDI!** +
  elmas + kasa). Oyun sakinleşince açılır (`GiftScreen.show_when_calm`).

## Kod

| Parça | Dosya |
|---|---|
| Takvim, araç modülü, yeni metrikler | `gameplay/backend/live_event.gd` (`active_raw`, `calendar`, `parse`, `summary_parts`, `car`, `upcoming`) |
| Süren etkinlik seçimi | `gameplay/backend/app_config.gd` (`active_event`) |
| Ödünç, haklar, ödül | `gameplay/backend/event_car.gd` (EventCar, kayıt `"event_car"`) |
| Etkinlik yarışı | `RaceManager.start_event_car_race`, `event_car_race_finished`; `Hud.start_event_car_race` |
| Görev sayaçları | `MissionManager._connect` (event_car_*), `SocialManager.visit` + `FeaturedFriends.visit` (garage_visits) |
| Reklam | `AdPolicy.EVENT_RACE` (günde 1) |
| Pano / pist / tabela / kaldırımdaki araç | `ui/hud/event_screen.gd`, `ui/hud/event_road.gd`, `ui/hud/event_banner.gd`, `world/event_car_spot.gd` |
| Testler | `tools/run_tests.sh event_car_test`; görsel `qa/etkinlik_araci_qa.gd` (CT_NO_TUTORIAL=1) |
