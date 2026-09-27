# DRAG YARIŞI

> **2026-09-27 — DRAG RACING 2.0:** yarışın FİZİĞİ tamamen değişti (gerçek devir, vites
> oranları, redline, kalkış devri, patinaj). Bu belgenin 1. bölümü (statlar), akış ve pist
> tasarımı hâlâ geçerli; **vites/devir mekaniğini anlatan bölümler yerine**
> `docs/drag_racing_2_design.md` ve `docs/drag_racing_2_report.md` okunmalı.

Tarih: 2026-09-26. Car Town zinciri: **GARAJ → yoldan rakip → 🏁 davet → yarış → ödül → garaj.**
Oyuncu normal trafikte araç sürmez; yarış ayrı bir moddur ve dünyadan gelir (menüden değil).

---

## 1. ARAÇ YARIŞ STATLARI

`vehicles/cars.json` içindeki **`race`** bloğu tek kaynaktır; `CarCatalog.SCHEMA`'ya
`Kind.STATS` alanı olarak eklendi (eksik alan olursa `CarCatalog.RACE_STATS` varsayılanı).

| Araç | Sınıf | Hız | Hızlanma | Tepki | Tutuş | İdeal süre |
|---|---|---|---|---|---|---|
| Tofaş Şahin | D | 105 | 52 | 48 | 45 | 8,01 sn |
| Renault Toros | D | 100 | 56 | 50 | 48 | 7,87 sn |
| Hyundai Era | C | 118 | 64 | 58 | 60 | 7,18 sn |
| Hyundai Getz | C | 112 | 70 | 62 | 64 | 7,02 sn |
| VW Passat B5.5 | B | 135 | 72 | 66 | 70 | 6,64 sn |
| Renault Fluence | B | 128 | 78 | 72 | 74 | 6,49 sn |
| BMW E46 | A | 145 | 84 | 78 | 80 | 6,14 sn |

Değerler sınıfla uyumlu ama araç karakteri taşır: Şahin daha yüksek son hız / daha kötü hızlanma
(Toros'un tersi), Getz daha çevik / daha düşük son hız (Era'nın tersi), Passat hızlı ama tepkisi
zayıf (Fluence'in tersi).

## 2. YARIŞ MODELİ (`gameplay/race/drag_race_sim.gd`)

**Tür araştırması — gerçek drag ve mobil drag oyunları (CSR, Drag Racing, Pixel Car Racer) ne
yapıyor, biz ne yapıyorduk:**

| Türün kuralı | Bizde eskiden | Şimdi |
|---|---|---|
| Mesafe çeyrek/sekizde bir mil, sokak aracı 10-16 sn | 150 m, 6-8 sn — "çok kısa" | **300 m, 9,3-12,3 sn** |
| Her vitesin DEVİR bandı var, ivme tork eğrisine bağlı | Devir yok; ibre rastgele bir hedefe süpürüyordu | **6 vites, gerçek devir, tork eğrisi** |
| En iyi vites güç tepesinde atılır | Hedef her turda RASTGELE yer değiştiriyordu | **Kadranın YEŞİL dilimi, hep aynı yerde** |
| Geç kalırsan devir SINIRA dayanır, limitçi keser | Devir sınırı YOKTU, ibre sonsuza kadar dönüyordu | **Sınırda ivme %15'e düşer, kadran kırmızı yanar** |
| Erken vites: devir bandın altına düşer, araç bocalar | Yoktu | **Tork eğrisi + %16 ivme cezası** |
| Yeşil ışıkta rakip kendi kalkar, tepki ayrı beceridir | Rakip oyuncu dokunana kadar HİÇ kalkmıyordu | **Rakip yeşilde kendi kalkar** |
| Çizgiyi hızlanarak geçersin | Araç son hıza oturup düz gidiyordu (ölü zaman) | **Vites kutusu son hızın %30 üstüne kurulu** |

**Model.** `DragRaceSim.Runner` tek bir `step(delta)` fonksiyonudur; ekrandaki oyuncu, ekrandaki
rakip ve başsız testler AYNI fonksiyonu çalıştırır. Yani ekranda gördüğün şey sonucun ta
kendisidir — eskiden süre önceden hesaplanıp araçlar ona göre çiziliyor, her viteste koşu
yeniden hesaplanıyordu (geç atılan bir vites yarışın BAŞINI da değiştiriyordu).

- `ivme = vites ivmesi × tork(devir) × vites kalitesi çarpanı` (+ tutuş kalkışta)
- `devir = hız / vitesin tepe hızı`, kademeler geometrik (her viteste devir %72'ye düşer)
- tork: %0'da 0,58 → **%81'de 1,0 (yeşil dilimin ortası)** → %100'de 0,86
- devir sınırında (%100) ivme **× 0,15**, kadran kırmızı yanar, ibre daha ileri GİTMEZ
- vites kalitesi 1,3 sn süren çarpan verir: **yeşil ×1,14**, erken ×0,84, geç ×0,80

**Kadran sanatla birebir.** `ui/hud/art/dial_band.png` (kullanıcı çizimi) açı taramasıyla
ölçüldü: yay −165°..−15°, yeşil dilim %46-54, sağdaki kırmızı %75'te başlıyor. `gauge(devir)`
motor devrini bu yay oranına çevirir — yani yeşil dilim GERÇEKTEN iyi vites noktasıdır, kırmızı
gerçekten geç kalmaktır, en sağdaki çizgi de devir sınırıdır.

**Neden "yeşil en iyi" kuralı modele açıkça yazıldı:** saf fizikte en iyi vites her zaman sınıra
dayamaktır (ivme vites büyüdükçe düşer, bu yüzden aşağı vitesde kalmak kârlıdır). Arcade drag
oyunlarının hepsi bunu "perfect shift bonusu" ile çözer; biz de öyle yaptık. Ölçüldü: aynı araçla
hep yeşilde atan 9,67 sn, hep sınırda atan 10,04 sn koşuyor.

**Ölçülen süreler** (kusursuz sürüş, tepki hariç) ve beceri farkı:

| Araç | Sınıf | Kusursuz | Kötü sürüş | Fark |
|---|---|---|---|---|
| BMW E46 | A | 9,32 sn | 10,70 sn | 1,38 |
| Passat | B | 10,11 | 11,50 | 1,39 |
| Fluence | B | 9,91 | 11,28 | 1,37 |
| Getz | C | 10,80 | 12,12 | 1,32 |
| Era | C | 10,95 | 12,34 | 1,39 |
| Toros | D | 12,15 | 13,50 | 1,35 |
| Şahin | D | 12,30 | 13,65 | 1,35 |

Sınıf farkı (A→D 3,0 sn) beceri farkından (1,35) büyük: **kötü oynanan A, kusursuz oynanan D'yi
yine yener** (10,70 < 12,30) — kural korundu. Tepki: 0,5 sn geç kalkış tam 0,5 sn kaybettirir
(araç fiziksel olarak çizgide bekler), hatalı çıkış 0,6 sn tutar.

## 3. RAKİP (`gameplay/race/race_manager.gd`)

Yeni bir trafik sistemi YOK: rakip, TrafficManager'ın zaten yoldaki araçlarından seçilir ve tamir
müşterisiyle **aynı yanaşma koduyla** (`TrafficVehicle._pull_over`) yol kenarına çekilir.
`Mode.RACE_CHALLENGE` eklendi; arıza/tamir durumuna dokunulmaz.

- **Sınıf eşleşmesi:** oyuncunun sınıfı ve bir üstü (D → D/C, C → C/B, B → B/A, A → A).
  Oyuncunun sahip olmadığı araçlar da rakip olabilir.
- **Durak:** yarış şeridinde `N_in_approach` (x 0,3 · z −0,8, garajın yanı) — bkz. 3b.
- **Balon:** `CarBubble.show_glyph(GLYPH_FLAG)` — yalnızca damalı bayrak (direk ve yazı yok).
- **Tıklama:** mevcut `CarHitbox` seçim yolu — yeni input sistemi yazılmadı.
- **Cooldown:** yarıştan sonra rakip yola döner (`nearest_waypoint_ahead`, ışınlanma yok) ve
  6 sn boyunca tamir müşterisi olarak seçilmez; yeni davet en erken 35 sn sonra gelir.
  Davet 45 sn kabul edilmezse rakip kendiliğinden gider (kalıcı park etmiş araç kalmaz).

## 3b. YARIŞ ŞERİDİ (rakip nereden gelir)

Şehir kavşağının **garaja yakın şeridi yarışa ayrıldı** (`TrafficManager.race_lane_spawn =
"N_in_spawn"`, x = 0,3, kuzeyden güneye). O şeritte **normal NPC doğmaz**; yalnızca RaceManager'ın
davet araçları girer. Şerit `spawn_points` listesine hiç alınmaz, `race_spawn_point` olarak ayrı
tutulur; davet araçları `city_vehicle_count()` dışındadır, yani bekleyen bir rakip yüzünden şehir
trafiği seyrelmez.

**Yoldan gelen araç = yarıştaki araç.** Rakip modeli ÖNCE eşleştirmeyle seçilir
(`rival_id_for`, oyuncunun sınıfı ya da bir üstü), araç o modelle yola çıkar
(`TrafficManager.spawn_challenger(wanted)`; model havuzda yoksa arka planda yüklenir ve birkaç
saniye sonra denenir). Eskiden yoldan rastgele bir havuz modeli geliyor, yarışta ise ayrı
seçilmiş bir rakip çıkıyordu — kullanıcı "Getz geldi, BMW ile başladık" diye yakaladı.

Akış: rakip şeridin başında doğar → **normal sürerek** gelir → garajın yanındaki duruş noktasında
(`stop_waypoint = "N_in_approach"`, x 0,3 · z −0,8, kavşağın hemen öncesi) durur → 🏁 balonunu açar (**yalnızca damalı bayrak,
direksiz ve yazısız** — `CarBubble.show_glyph(GLYPH_FLAG)`; desenin krem kareleri plakayla aynı
renk olduğu için bayrağa ince koyu çerçeve eklendi) → balona dokununca **"YARIŞMAK İSTER MİSİN?"** panosu açılır → oyuncu kabul etmezse
`challenge_timeout` (30 sn) sonunda **dümdüz devam edip** güneyden şeritten çıkar → `cooldown` /
`challenge_interval` (5-12 sn) sonra arkadan yenisi gelir.

Duruş noktası sahnede işaret istemez: waypoint'in konumundan ve bir sonraki noktaya bakışından
türetilir (araç gidiş yönüne dönük park eder). `challenge_spot` hâlâ isteğe bağlı bir elle-ayar
olarak duruyor ama şeridin 1,5 biriminden uzaksa uyarı basıp yok sayılıyor — `Main.tscn`'deki eski
`RepairSpots/RaceSpot` işareti artık kullanılmıyor (editörde silinebilir).

**Yol boyunca çıkan iki gerçek hata:** (1) `TrafficManager.nearest_waypoint_ahead` aracın ÖNÜ için
`-basis.z` kullanıyordu, oysa model önü `+basis.z` — yarıştan/davetten dönen araç arkasındaki
noktayı hedefleyip geri dönüyordu; (2) davet kavşağın içinde açılırsa kavşak kilidi bırakılmıyordu
(diğer eksen sonsuza kadar bekleyebilirdi) — `request_race_challenge` artık `enter_bay` ile aynı
korumayı yapıyor.

Ölçüm: şerit kapalıyken de açıkken de tamir müşterisi **0,67/dk** (3'er dakika, 6× hız) — müşteri
akışı E şeridinden geldiği ve şehir araç tavanı değişmediği için etkilenmiyor.

## 4. EKRANLAR (UiRouter)

`WORLD → MODAL: race_challenge → PLACE: drag_race → MODAL: race_result → WORLD`

Üçü de UiRouter'a kayıtlı: aynı anda garaj/mağaza/yarış açık kalamaz, ESC tek yerden yönetilir.

**Pist dekoru ayrı bir sahnededir: `race/drag_track.gd` (DragTrack).** Ekran (`ui/hud/drag_race_screen.gd`)
yalnızca dünyayı, ışığı, kamerayı ve araçları yönetir; dekor yarış mantığını hiç bilmez.
Pist **kendi World3D'sindedir** (şehirle hiçbir bağı yok).

**Asset'ler** (`race/art/`, `ui/hud/art/` — hepsi kullanıcı tarafından çizildi, `eksik_dosyalar/`
altındaki ham dosyalardan `eksik_dosyalar/process.py` ile üretildi): `asphalt_dark.png` (512²,
dikişsiz), `barrier_concrete.png` / `tire_barrier.png` (256², dikiş düzeltildi), `finish_banner.png`
(1024×200, alfa), `grandstand.png` (1024×255, alfa), `dial_face/needle/target.png` (256², pivotları
ölçülüp ortalandı). **Her biri için yedek yol vardır**: dosya yoksa `ResourceLoader.exists` false
döner ve eski prosedürel çizim (düz renk / kutu tribün / kodla çizilen kadran) devreye girer —
eksik bir asset hiçbir şeyi bozmaz.

Doku VERİLİRKEN albedo rengi beyaza çekilir (`_textured(..., tint)`): yedek renk dokuyla çarpılınca
beton kahverengi, kırmızı/beyaz lastikler siyah çıkıyordu.

Görsel kimlik (şehir yolundan ayrışsın diye): **koyu kömür asfalt** (#24272B) + iki şerit tonu,
kesiksiz beyaz pist çizgileri ve **amber/krem kerb blokları** (şehirdeki kesikli çizgi yok), kalkış
lastik izleri, **START GRID** (kalın çıkış çizgisi + şerit kareleri + amber oklar), damalı
**FINISH** çizgisi ve üstünde krem tabelalı kapı, çakıl apron, beton bariyer duvarı ve lastik
bariyerleri (tek MultiMesh), mesafe direkleri (MultiMesh), korkuluk, pit duvarı + sponsor
plakaları, tribün, uzakta depo siluetleri, gradyan gökyüzü ve **iki şeridin TAM ORTASINDA**
duran stilize christmas tree (2 küçük "hazır" bulbu + 3 amber + 1 yeşil).

Araç renklerine DOKUNULMAZ: rakip kendi katalog görünümüyle çıkar (ileride modifiyeli NPC'ler
kendi renk/parça setleriyle geleceği için zorla boyama yapılmaz).

Vites göstergesi **yuvarlak kadrandır** (`ui/hud/shift_dial.gd`): amber yay hedef penceresini
gösterir, ibre süpürür, isabette kısa parlama olur — oyuncu nereye dokunacağını görür.

**Hareket hissi:** tekerlekler kat edilen yola göre döner (`CarRig.spin_wheels`), kalkışta araç
hafifçe çömelir, kamera kısa bir "punch" yapar (ortografik size %7 daralıp açılır), her iki aracın
arkasında yumuşak radyal maskeli **kalkış dumanı** (CPUParticles3D, 16 parçacık, tek seferlik)
çıkar ve geri sayımda tabela her sayıda "pop" eder. Yarış bitince pist HUD'u (kadran, dokunma
plakası, durum tabelası) gizlenir; sonucu yalnızca sonuç panosu söyler.

**Çıkış dokunuşu düzeltmesi:** GO'dan sonraki ilk dokunuş TEPKİ olarak sayılır. Bu dal eksikti ve
oyuncunun çıkış dokunuşu yutuluyordu (herkes 0,5 sn'lik otomatik tepkiyle kalkıyordu); artık
`race_test` bunu ayrıca doğruluyor.

Kamera **ortografik izometrik** (pitch −25°, **yaw −45°**) ve iki aracın ortasını takip eder;
kadraj ekran uzayında ayarlanır (`CAM_PAN_RIGHT/UP`) ve bitişe yaklaşırken ileri bakış biraz artar
(`CAM_LOOK_AHEAD_END`) — FINISH kapısı son bölümde kadraja girer.

**Kamera araçların ÖNÜNDEDİR: araçlar ekranda SAĞ ALTA koşar ve yüzleri (ızgara, farlar) görünür.**
Geometrik kural: takip kamerası araçların ARKASINDA olursa gidiş yönü ekranda her zaman YUKARI
okunur (sol üst ya da sağ üst; pitch ne olursa olsun). Sağ alta koşması için kameranın önde olması
gerekir — yaw 135° → −45°. Ortografik kamerada mesafe kadrajı değiştirmediği için kapı hâlâ
görünür: kamera odaktan ~7,7 birim ileride durduğundan FINISH kapısı son ~3 birimde sağ alttan
kadraja girer ve araçlar altından geçer.

Bu çevirmenin gerektirdiği dekor düzeltmeleri: çıkış lambaları panonun **kameraya bakan** yüzüne
alındı (sürücü tarafındayken panonun arkasında kalıyorlardı), FINISH tabelası 180° → 0° döndürüldü
(yazı tersten okunmasın), ve X'te asimetrik dekor aynalandı — tribün uzak tarafa (+X), pit duvarı
ile hakem kulübesi yakın tarafa (−X), depo siluetleri ve ağaçlar da buna göre. Aksi hâlde tribün
kamerayla araçların arasına girip pisti kapatıyordu. Güneş de kamerayla birlikte döndürüldü
(yaw 130° → −50°) ki ekran uzayındaki ışık yönü değişmesin.

**Kadraj GENİŞLİĞE kilitlidir** (`keep_aspect = KEEP_WIDTH`, `size = 4,6 / telefonda 4,9`). Önceden
yüksekliğe kilitliydi; telefonun geniş tuvali (1040×480) yatayda 8,5 birim gösterdiği için araçlar
ekran genişliğinin ancak **%10,6**'sını kaplıyordu (masaüstünde %14,8) — yani "araçlar büyük olsun"
maddesi aslında karşılanmıyordu. Artık araç boyu tuvalden bağımsız: **araç başına ~%23-24**
(masaüstü ve telefonda aynı), iki araç birlikte %40-52. Buna ek olarak araç ölçeği 1,0 → **1,2**,
şerit aralığı 0,68 → **0,56** ve `MAX_VISUAL_GAP` 1,15 → **0,92** yapıldı: kadraj daralınca ikisinin
birden sığması için gereken pay küçültüldü.

Gerçek mesafe farkı ekrana `tanh` ile yumuşatılarak taşınır: araçlar bazen öne fırlar, bazen geri
kalır ama **ikisi de kadrajdan çıkmaz**; kazanan yine önde görünür ve çizgiyi önce geçer.

**Yakın kadrajın getirdiği ayarlar:** çıkış lambası fikstürü %14 kısaltıldı (uzun direk kadrajın
üstünden taşıyordu), FINISH kapısı 1,9 → 1,62 m'ye indi ve tabela 1,74 → 1,40'a çekildi, ileri
bakış 1,1/2,4 → 0,55/0,95 yapıldı (bitişte araçlar kadrajın sağ kenarına kayıyordu). Yan dekor
(tribün, depo siluetleri) artık yalnızca kadrajın köşelerinde görünür: yakın kadrajda kamera
yatayda ±2,3 birim görüyor, bariyer duvarı zaten 2,65'te — bu, "araçlar büyük olsun" maddesiyle
"çevre dolu olsun" maddesi arasında bilinçli bir takas.

**Araçlar geri geri koşuyordu (düzeltildi):** `_spawn_car` modele 180° uyguluyordu. Yedi aracın
hepsi ölçüldü — modeller boyu **1,0'e normalize** ve **+Z'ye bakıyor** (farlar +0,42..+0,47,
stoplar -0,43..-0,47), yarış da +Z yönünde koşuluyor; yani o dönüş araçları ters çeviriyordu.
Kamera araçların ARKASINDA olduğu için yanlış yön "araç önden görünüyor" diye fark edilmemişti;
kalkış dumanının burundan çıkması bunun belirtisiydi. Dönüş kaldırıldı: artık araçlar gidiş
yönüne bakıyor (kamera arkada olduğu için arkadan görünüyorlar, gerçek drag yayınındaki gibi) ve
duman arka tamponun hemen gerisinden çıkıyor (`-0,58 × CAR_SCALE`).

**Burun tam çizgide:** `START_Z` araç MERKEZİdir; burun merkezin `0,5 × CAR_SCALE = 0,60` önünde
olduğu için `START_Z = -0,60` → burun tam çıkış çizgisinin (z = 0) üstünde. Yan etki olarak yarış
bitince (merkez `START_Z + TRACK_LENGTH`) burun tam bitiş çizgisine oturuyor; eskiden (-0,85)
araçlar çizgiye 25 cm kala duruyordu. Çıkış karesi artık araca göre değil ÇİZGİYE göre kuruluyor
(ön kenar +0,08, arka kenar -1,50), böylece araç boyu değişse de kare doğru kalır.

**Oyuncunun aracı SAĞ şeritte** (kamera yaw −45°'de +X ekranda sağdır). **Rakip yeşil ışıkta
kendi kalkar**: oyuncu dokunmasa da yarış başlar, oyuncunun aracı çizgide bekler — tepki cezası
formül değil, fiziksel mesafedir. Hiç dokunulmazsa 0,55 sn'de otomatik kalkış olur (yarış asılı
kalmaz).

**Vites kümesi alt sağ bölgede** (yatay telefonda başparmağın doğal yeri), kenara yapışmadan
içeride (`CORNER_MARGIN` 52×36, telefonda 38×26): üstte durum plakası, altında **büyük kadran**
(136 px, telefonda 118) + **yuvarlak tabela butonu** (122/106 px, `PlateButton.Shape.ROUND`,
`HudSign`). Önce ekranın ortasında geniş bir plaka vardı — hem pistin ortasını kapatıyordu hem de
parmaktan uzaktı; sonra köşeye alındı ama küçük ve kenara yapışıktı.
Yarış sırasında **ekranın her yeri dokunma alanıdır** (`_gui_input`): küçük plakayı ıskalamak
yarışı kaybettirmiyor; butona basıldığında olay orada tüketildiği için çift sayılmıyor.
Yalnızca sonuç panosunda tekrar eden "SEN / RAKİP süre" etiketleri kaldırıldı (yarış biterken
kolon zaten gizleniyordu, yani hiç görünmüyorlardı).

**İDEAL DEVİR BİLDİRİMİ:** ibre amber pencereye girdiği anda dört şey birden olur — kadranın
çevresinde **nabız gibi atan amber hale** yanar (`ShiftDial.hot`: dokuz üst üste binen `draw_arc`
halkası + dönen sekiz kısa ışın; dolu daire kadranın ortasını da boyayıp rakamları
soluklaştırıyordu, beş ayrı halka da bant bant görünüyordu), kadran nabızla %4,5 büyür, yuvarlak
buton amber olup aynı nabızla atar (`PlateButton.highlight` + `scale`) ve plaka **"ŞİMDİ!"** yazıp
amberleşir. Pencereden çıkınca hepsi eski hâline döner. Vites TUTTUĞUNDA ayrıca beyaza çalan tek
seferlik bir patlama halkası çizilir (`flash` → `_draw_burst`), böylece "şimdi bas" ile "tuttu"
birbirine karışmaz. Bildirim penceresi isabet penceresiyle **aynı** koşuldur (`SHIFT_WINDOW`), yani yanarken
basan oyuncu her zaman isabet eder — prob yarışı 4/4 isabetle bitirerek bunu doğruluyor.

## 5. ÖDÜL

| Rakip sınıfı | Kazanınca | Kaybedince |
|---|---|---|
| D | 450 ₺ + 25 XP | 0 ₺ + 7 XP |
| C | 700 ₺ + 35 XP | 0 ₺ + 10 XP |
| B | 1.000 ₺ + 50 XP | 0 ₺ + 15 XP |
| A | 1.400 ₺ + 70 XP | 0 ₺ + 21 XP |

Yakıt yok, katılım ücreti yok, kaybetmek para kaybettirmez. Ödül `RaceManager.finish_race()`
içinde **bir kez** yazılır (`_reward_paid`); sonuç ekranı yalnızca gösterir.

Karşılaştırma: tamir döngüsü ölçülen 450-2.400 ₺/dk üretir; bir yarış (davet + koşu + sonuç)
~30-40 sn sürer, yani yarış ekonomiyi domine etmez, ek bir kol olarak durur.

## 6. KAYIT

**Sürüm değişmedi (v7).** İlk sürümde yarış istatistiği saklanmıyor: galibiyet/mağlubiyet sayacı
eklenirse `job_mastery` deseniyle bir alan ve v8 göçü gerekir (bkz. "Sonraki aşama").

## 7. ÖLÇÜM

**Testler** — sekiz paket de geçiyor (2026-09-27, vites/devir modelinden sonra):
race 49 · ui 47 · progression 32 · save 27 · edge 34 · quest 28 · paint 28 · cloud 50 kontrol,
**0 FAIL**. `save`, `edge`, `quest`, `paint`, `cloud` **headless + ayrı user dizini** ister
(`--headless` + override.cfg); pencereli koşulursa takılır. `progression_test`'in garaj sütunu
iddiası düzeltildi: içerik yerine GÖRÜNEN `_info_scroll` ölçülüyor ve tuval yüksekliğiyle
karşılaştırılıyor (eskiden içerik yüksekliği pencere yüksekliğiyle karşılaştırılıyordu — iki farklı
uzay, telefon tuvalinde yanlış FAIL veriyordu; garaj ekranında gerçek bir taşma yok).

`race_test.gd` (12 bölüm / 49 kontrol): statlar,
sınıf üstünlüğü (40 koşu × 3 eşleşme), tepki/vites, rakip seçimi, ödül, davetin yoldan gelmesi,
balona dokunma, tek panel kuralı, pist akışı, ödülün iki kez verilmemesi, garaja dönüş, rakibin
trafiğe dönmesi, kayıt bütünlüğü ve tamir akışının bozulmadığı.

**Performans** (1152×648, vsync kapalı, dokular bağlandıktan SONRA):

| Durum | FPS ort / min | Çizim | VRAM |
|---|---|---|---|
| Dünya (şehir) | 957 / 647 | 154 | 87,8 MB |
| Drag pisti (hazır) | 325 / 8* | 252 | 105,9 MB |
| Drag pisti (yarış) | 305 / 300 | 252 | 105,9 MB |
| Dünyaya dönüş | 1.517 / 149 | 154 | 91,7 MB |
| Drag pisti (İKİNCİ açılış) | 411 / 360 | 258 | 97,0 MB |

`open()` çağrısı **6,5 ms** (pist 16 → 22 birime uzadı: yarış 7 → 10 sn olunca hız hissi
düşmesin diye). *İlk açılıştaki 9 FPS'lik tek kare, beş PNG'nin GPU'ya ilk
yüklenmesidir: oturumda **bir kez** olur, ikinci açılışta min FPS 360'a çıkıyor (ölçüldü).

Çizim çağrısı 540 → **258**'e düştü: FINISH tabelası (krem plaka + 14 dama kutusu + Label3D) ve
tribün (3 kademeli kutu) tek dokulu quad'a indi. VRAM 109,9 → **91,7 MB** (hedef <120 MB).

Araçların ekran payı — **ölçüldü** (piksel sayımıyla, mavi gövde maskesi):

| Kanvas | Önce (araç başına) | Sonra (araç başına) | İki araç birlikte |
|---|---|---|---|
| Masaüstü 1152×648 | %14,8 | **%24,4** | %41-52 |
| Telefon 1040×480 | %10,6 | **%22,9** | %39-40 |

Önceki raporda yazan "%31 / %22" yanlıştı (iki aracın toplam kümesi ölçülmüştü); doğrusu
yukarıdaki tablodur. Hedef bandın (%25-35) alt ucuna ~1 puan kalıyor: daha da yaklaşmak iki aracın
birden kadrajda kalmasını bozuyor (45°'lik izometri şerit aralığını dikeye de yayıyor).

Görsel doğrulama: her iki kanvasta 6 kare alındı (hazır · ışıklar · kalkış · orta · bitiş · sonuç).
Çıkış lambası **tamamen** kadrajda, alt plaka araçların üstüne binmiyor, FINISH tabelası
okunuyor, araçlar çizgiyi kadrajın ortasında geçiyor.

Pistin maliyeti ~+15 MB (iki araç modeli + render hedefi); kapanışta render hedefi bırakılır
(`_viewport.size = 4×4`). 60 FPS ve <700 çizim hedefleri rahat karşılanıyor.
