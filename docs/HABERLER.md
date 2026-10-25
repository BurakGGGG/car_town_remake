# HABERLER kutusu — 2026-10-25

Sağ üstte **kamera · HABERLER · ayarlar** sırasında gazete tabelası. Rozet: okunmamış haber + alınmamış hediye sayısı
(9'dan fazlası 9+). Dokununca HABERLER panosu açılır: solda liste, sağda okuma kartı (kullanıcının seçtiği taslak A;
tuval https://claude.ai/artifact/443R6BRm4PhHMMvEEo2LFP).

## Kullanıcı kararları

| Konu | Karar |
|---|---|
| OTO MANŞET gazetesi | aynen kalır (açılış özeti); kutu ayrı, oyun ekibinden gelenlerin kalıcı yeri |
| Arkadaş haberleri | kutuya girmez (gazete + ARKADAŞLAR) |
| Hediye gelince | POSTA penceresi kendiliğinden AÇILMAZ: rozet + kısa "HEDİYEN VAR!" yazısı (dokununca kutu) |
| Hediye alma | kutudan, TEK TEK (HEPSİNİ AL yok) |
| İçerik | hediye / posta, güncelleme notu, etkinlik, duyuru |
| Geçmiş | en yeni 50 kayıt; alınan hediye ALINDI damgalı kalır |
| Okundu | kutu açılınca; hediye alınana kadar rozette sayılır |
| Hediye süresi | 30 gün; son 3 günde kırmızı SON N GÜN |
| Güncelleme notu | yalnız kutuya düşer, panelden yazılır (sürüm koduna bağlı) |
| DUYURU penceresi | kalktı → kutuda haber. YENİ SÜRÜM VAR penceresi kalır + kutuda GÜNCELLE düğmeli haber |
| Etkinlik | panelden başlayınca kutuya kendiliğinden düşer (sabit, ETKİNLİĞE GİT), bitince kalkar |
| Kapak | türe göre hazır çizim; istenirse panelden resim (Firebase Storage) |
| Düğme | panelde seçilir: MARKET, ETKİNLİK, GÖREVLER, SHOWROOM, ARKADAŞLAR, DAVET ET, GÜNCELLE (Play), bağlantı |
| Dil | panelde 5 alan, çeviriyi kullanıcı yazar (boş dil → en → tr) |
| Bildirim | panelde haber başına kutucuk |
| Misafir | haberleri görür + en üstte HESABINI BAĞLA kartı |
| Panel | ileri tarihli yayın, bitiş tarihi, hedefleme (dil / seviye / sürüm / tek oyuncu), sabitleme |

## Veri

- **`news/{id}`** — panelin yazdığı haberler (yalnız sunucu okur / yazar):
  `kind (update | event | notice), title / text {tr, en, es, de, fr}, image, action {kind, url}, start, end, pinned, code,
  target {langs, min_level, max_level, min_code, max_code}, notify, pushed_at, at`.
- **`config/news`** — panel her kayıtta yayındaki haberleri (bitmemiş, ileri tarihliler dahil, en çok 40) buraya toplar:
  `{items: [...], at}`. Oyun YALNIZ bu belgeyi okur (oturumsuz REST, 1 okuma): koleksiyonu listelemek oyuncu başına
  onlarca okuma olurdu. `config` kuralı zaten herkese `get` verir.
- **Tek oyuncuya haber** = ödülsüz posta (`users/{uid}/mail/{id}`); postada isteğe bağlı `image` ve `action`.
- Kapak resmi yalnız `firebasestorage.googleapis.com`, `storage.googleapis.com`, `autoyard.online` (https). Storage kovası
  `car-town-remake.firebasestorage.app` (US-CENTRAL1, üretim modu kuralları; adreslerde indirme jetonu var).

## Oyun

| Parça | Görev |
|---|---|
| `NewsFeed` (`gameplay/backend/news_feed.gd`) | AppConfig'in çocuğu (kökte): `config/news`'i açılışta, öne gelince, 15 dk'da bir ve kutu açılınca (1 dk'dan eskiyse) okur; `user://news_feed.json`'da saklar; `visible()` süzgeci: zaman, dil, seviye, sürüm, güncelleme notunun sürümü (geliştirme sürümü sürüm süzgecine takılmaz) |
| `Inbox` (`gameplay/backend/inbox.gd`) | kaynakları birleştirir: bekleyen posta (HEDİYE / MESAJ), posta geçmişi, NewsFeed, `config/app.notice`, `latest_code`, süren etkinlik, misafir kartı. Sıra: misafir, sabitler, en yeni. `mark_open()`: haberler görüldü, ödülsüz posta okunur (geçmişe geçer). `gift_arrived` → HEDİYEN VAR |
| `MailService` | posta + kutunun kalıcı durumu (kayıtta `mail`): `history` (alınan postalar, 50), `seen` (görülen kimlikler, 200) |
| `InboxScreen` (`ui/hud/inbox_screen.gd`) | UiRouter MODAL `inbox`; liste + okuma kartı; AL → `MailNotice.claim_now` (ödül penceresi), düğme → `Hud._on_inbox_action` |
| `InboxCover`, `InboxImages` | türün hazır kapağı (hediye kutusu, YENİ rozeti, dama bayrak, megafon, zarf, kask) / indirilen resim (önbellek `user://news_img/`) |
| `MailNotice` | artık pencere değil: yalnız AL → ödül penceresi (+ efsanevi araç seçimi) |
| `HudIcon.Kind.NEWSPAPER` | tabelanın simgesi |

**Hata (aynı gün bulundu):** eklentinin koleksiyon okuması iç içe alanları Godot sözlüğüne çevirmiyordu (motor
`java.util.HashMap`'i JavaObject yapar) → posta boş sayılıp atlanıyordu. `SocialManager.list_mail` artık listeden yalnız
kimliği alır, her postayı tek belge okumasıyla (`get`, çevirir) okur. 1.1.0'da bekleyen postalar silinmedi; yeni sürümde gelir.

## Hediye ekranı ve araç hediyesi (2026-10-25)

Kullanıcı: "hediyeyi toplama ekranı seviye atlama ekranındaki gibi olsun, hediyenin fotosu gözüksün; araba da hediye
edebileyim". AL → **HEDİYEN GELDİ!** (`ui/hud/gift_screen.gd`, GiftScreen): hediye kutusu rozeti + dönen ışık, postanın
başlığı · gönderen, ₺ / GEM hapları, İÇİNDEKİLER kartları (araç fotoğrafı + nadirlik, dönen 3B kasa, dekor resmi, çerçeve
oyuncunun avatarıyla, efsanevi araç seçimi), TOPLA → paralar sayaçlara uçar. SEVİYE ATLADIN ile aynı taban:
`ui/hud/reward_screen.gd` (RewardScreen; LevelUpScreen de ondan türer). Posta alanı `cars: {araç: 1}` — edinilebilir
araçlar, her biri bir adet; oyuncuda zaten varsa satış değeri (`VehicleOwnership.sell_price`) ₺ olarak verilir, kartta
ZATEN VARDI. HABERLER kartında araç hediyesinin kapağı aracın kendisi. Panel posta formunda "+ araç ekle".
QA: `qa/hediye_ekrani_qa.gd` (dolu / arac / var).

## Sunucu

- `functions/news_feed.js`: `newsPush` (news/{id} yazılınca, haber görünürse) ve `newsPushScheduled` (10 dk'da bir,
  ileri tarihli yayın) — dil konularına (`news_<dil>`, misafir de abone) bir kez bildirim; `pushed_at` işlem içinde.
  Seviye / sürüm hedefli habere bildirim gitmez (konu süzemez; panel de izin vermez).
- Panel `firebase/admin` **Haberler** sekmesi: liste, form, önizleme, resim yükleme (`/api/news/upload`), düzenle / sil,
  "en üste taşı"; posta formunda resim + düğme. Eski `config/app.notice` editörü "eski sürümler için" diye kaldı.

## Testler / QA

- `tools/run_tests.sh inbox_test mail_test app_config_test referral_test`
- `firebase/functions`: `npm test`, `npm run e2e`; `firebase/admin`: `npm test`, `npm run e2e`; kurallar emülatörde
- Görsel: `tools/qa_isolated.sh res://qa/haberler_qa.gd --resolution 1152x648 --display-driver x11` (telefon tuvali
  853x480; `QA_LANG=en`, geniş telefon `--resolution 1440x648`) → `~/Projects/ct_shots/haberler/`

## Açık

- Bildirime dokununca oyun açılır ama kutu kendiliğinden açılmaz (bildirimin `data.type` / `id`'si okunmuyor).
- Davet postalarının özel görünümü (avatar, basamak noktaları) kutuda yok; başlık ve metinle gösterilir.
