# Arkadaşlık — kod, istek, arkadaş garajı ziyareti

Durum: 2026-10-05. Facebook girişi DÜŞÜNÜLDÜ, BIRAKILDI (Meta App Review + işletme doğrulaması; `user_friends`
yalnızca oyunu oynayan arkadaşları döndürür). Yerine: arkadaş kodu + karşılıklı istek (bu belge) ve sonra
Google Play Games arkadaş listesi (henüz yok, bkz. "Sonraki adım").

## Oyuncu ne görür

* Sağ üstte GÖREVLER'in altında **ARKADAŞLAR** plakası. Gelen istek varsa amber olur: `ARKADAŞLAR (1)`.
* Misafir (Google girişi yok): "Google ile giriş yap" + GİRİŞ YAP (PLAYER ekranını açar).
* İlk açılışta takma ad seçilir (öneri: `Usta1234`). Gerçek ad paylaşılmaz.
* Profil: takma ad (DEĞİŞTİR), arkadaş kodu `AY-7K2Q4M` (KOPYALA), kodla EKLE.
* GELEN İSTEKLER (KABUL / RET), ARKADAŞLARIN (GARAJA GİT / ÇIKAR, çıkarma iki adımlı), GÖNDERDİĞİN İSTEKLER (GERİ AL).
* İki oyuncu birbirine istek atarsa ikinci gönderen doğrudan arkadaş olur.
* GARAJA GİT: kendi garajın **donar**, arkadaşın garajı açılır. Üstte "ARKADAŞ GARAJI · ad · seviye · garaj değeri"
  ve GARAJIMA DÖN (Android GERİ de döndürür). Dönünce her şey kaldığı yerden sürer, ARKADAŞLAR ekranı açıktır.

## Öne çıkan arkadaşlar (Emre Usta · Elif Usta)

Hay Day'deki Greg gibi: herkesin ARKADAŞLARIN listesinin başında duran, oyunla gelen iki garaj. Sunucu gerekmez
(misafir, çevrimdışı ve PC'de de gezilir), çıkarılamaz, istek / kod yoktur.

* **Emre Usta — Gece Garajı** (karanlık, 70 eşya): siyah elmas sac zemin, siyah duvarlar, neon tabelalar ve LED
  şeritler; cam bölmeli karbon sergide damalı altlıklar üzerinde Huracán, 488 Pista, GT3 (projektörler, kupa
  vitrinleri, babalar); kauçuk zeminli tehlike şeritli atölye (kaynak, motor bloğu, varil rafı, tamirci); pencereli
  bölmeli koyu parke lounge (jukebox, otomatlar, langırt, kırmızı dama halı); yarış şeritli giriş plazası, yakıt
  pompası, motosiklet, E60, RS6, CLS.
* **Elif Usta — Pamuk Garaj** (ponçik, 73 eşya): şeker çizgili duvarlar, beyaz parke; pastel karolu bahçe kafe
  (ağaçlar, palmiye, şemsiyeli masalar, ışık dizileri, piknik masası, mangal, köpek kulübesi); nane damalı atölye;
  pembe damalı otoparkta Huracán, Golf, Şahin, A3; açık parke lounge'da CLS, Getz, jukebox; çit ve çiçeklerle giriş.
* Araçlar **fabrika renginde** (kullanıcı kararı: boyanmaz); her garajda 6 araç.

Bu tema için kataloğa (mağazada da satılır) 4 pastel zemin deseni (PEMBE DAMA, NANE DAMA, PASTEL KARO, BEYAZ PARKE) ve
4 duvar kaplaması (PEMBE / NANE / LİLA BOYA, ŞEKER ÇİZGİ) eklendi (`vfx/decor_textures.gd`, `decor/decorations.json`).

Garajlar `gameplay/social/featured/<kimlik>.json` (açık garaj biçimi). **Elle düzenlenmez**: tasarım
`tools/featured/featured_designs.gd`'dedir, `tools/featured/run.sh [kimlik] [--export]` garajı GERÇEK oyunda kurar,
her eşyayı oyunun yerleşim kurallarıyla doğrular (hata varsa dışa aktarmaz) ve `~/Projects/ct_shots/featured/`'a
görüntü alır. Kod: `gameplay/social/featured_friends.gd`. Kimlikler `featured_` önekli (Firebase UID'leriyle karışmaz).

Ziyaret açılınca kamera garajın tamamını çerçeveler (`VisitBar._frame_garage`): 4. seviye garaj varsayılan
yakınlıkta ekrana sığmıyordu.

## Kod

| Dosya | Görev |
|---|---|
| `gameplay/social/social_manager.gd` | Profil, kod, istekler, liste, açık garaj yayını, ziyaret, hesap silmede temizlik |
| `gameplay/social/public_garage.gd` | Kayıttan yalnızca görsel kısım (para / gem / kasa / görev YOK) |
| `gameplay/social/social_names.gd` | Kod alfabesi, takma ad kuralı, küfür filtresi |
| `gameplay/social/garage_visit.gd` | Ziyaret: kendi sahneyi dondurur, Main.tscn'yi ziyaret kipinde açar |
| `ui/hud/friends_screen.gd` | ARKADAŞLAR ekranı (kodla kurulur, UiRouter MODAL `friends`) |
| `ui/hud/visit_bar.gd` | Ziyaretteki tek arayüz |

`SocialManager`'ı `GarageSystem` kodla kurar ("social" grubu). Oturum `CloudSaveManager`'ındır: sosyal yalnızca
bulut kaydı **SYNCED** iken başlar ve açık garaj yalnızca o zaman yayınlanır (kayıt seçimi sürerken cihazdaki kayıt
henüz bu hesabın olmayabilir).

## Firestore

Kurallar: `firebase/firestore.rules`. Test: `firebase/rules_test` (yerel emülatör, gerçek projeye dokunmaz):

```
cd firebase && (cd rules_test && npm install)   # ilk sefer
firebase emulators:exec --only firestore --project demo-cartown "node rules_test/rules_test.mjs"
```

| Yol | İçerik | Kim |
|---|---|---|
| `garages/g_{uid}` | name, code, level, value, garage_json, updated_at | herkes (girişli) okur, sahibi yazar |
| `codes/{KOD}` | uid | bir kez alınır, üzerine yazılamaz |
| `users/{alıcı}/inbox/r_{gönderen}` | name, code, at | gönderen yazar; iki taraf okur / siler |
| `users/{gönderen}/outbox/o_{alıcı}` | name, code, at | sahibi yazar; alıcı kabul / ret ederken siler |
| `users/{a}/friends/f_{b}` | since | iki belgeyi de KABUL EDEN yazar (o an gelen kutusunda istek olmalı) |

**Belge kimlikleri hiçbir zaman çıplak UID değildir** (`g_ / r_ / o_ / f_`). Firebase eklentisi sonuçları
yalnızca belge kimliğiyle bildirir (koleksiyon yok) ve `CloudSaveManager` kendi sonucunu "kimlik == UID" diye tanır.
Önek kaldırılırsa bulut kaydı sosyal yazmanın sonucunu kendi sonucu sanar. `SocialManager` isteklerini sırayla
gönderir; koleksiyon listesinin sonucunda kimlik yoktur (bulut kaydı liste istemez).

Okuma maliyeti: açılışta 3 liste + arkadaş başına 1 okuma; ekran 30 sn'den sık yenilenmez. Ziyaret 1 okuma.

## Ziyaret kipi

`GarageVisit.begin`: kendi sahne `root`'tan çıkarılır (silinmez), Main.tscn'nin yeni kopyasında:
`SaveManager.visit_mode = true` (diskten okumaz, arkadaşın açık garajını uygular, `save_game` / `new_game` /
`apply_snapshot` reddedilir), HUD ve CloudSaveManager çıkarılır, `GarageSystem` kasa / görev / reklam / sosyal /
düzenleyici kurmaz. SaveManager işaretlenemezse ziyaret açılmaz. Gruplar ağaca bağlı olduğu için kendi sahnenin
yöneticileri ziyaret boyunca bulunmaz. Ziyaretten önce kendi kayıt diske yazılır; bulut yazması sürüyorsa ziyaret
reddedilir ("birazdan tekrar dene").

## Hesap silme

`CloudSaveManager` Google doğrulamasından sonra, bulut kaydından ÖNCE `SocialManager.delete_all()` çağırır:
arkadaşlıklar iki taraftan, istekler, açık garaj ve kod silinir. Silinemezse hesap silinmez.

## Testler

* `tools/run_tests.sh social_test` — sahte Firebase (sırasız gecikmeli yanıtlar, sadeleştirilmiş kurallar),
  profil, kod çakışması, yayın + bulut kaydı birlikte, istek / kabul / ret / geri alma / çıkarma, çevrimdışı,
  zaman aşımı, hesap silme. `SOCIAL_SEED=<n>` ile farklı yanıt sırası.
* `tools/run_tests.sh visit_test` — gerçek Main.tscn: donma, ziyaret sahnesi içeriği, ziyarette hiçbir dosya /
  buluta yazma olmaması, dönüş.
* `qa/social_shots.gd` — ekran görüntüleri (`~/Projects/ct_shots/social/`).

## Sonraki adım: Play Games arkadaşları

Ön koşul (Play Console, kullanıcı): Play Games Services projesi + Oyun Kimliği (Game ID), OAuth istemcisi, yükleme
ve Play imza anahtarının SHA-1'leri. Sonra: `godot-sdk-integrations/godot-play-game-services` eklentisi (autoload
yok, singleton doğrudan), "Play Games arkadaşlarını getir" butonunda izin, `pgs/p_{playerId} → uid` eşlemesi.
Google kuralı: arkadaş listesi saklanırsa düzenli yeniden doğrulanmalı → saklanmaz, her açılışta yüklenir.
