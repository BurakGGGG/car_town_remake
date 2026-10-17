# Dil desteği — Türkçe · İngilizce · İspanyolca · Almanca · Fransızca

Durum: 2026-10-04 (TR/EN/ES); Almanca ve Fransızca 2026-10-17'de eklendi. Kod: `ui/loc.gd` (Loc), dil ayarı `gameplay/game_settings.gd`, çeviriler `locale/`.
Test: `tests/locale_test.gd`.

## Nasıl çalışır

* **Kaynak dil Türkçe.** Çeviri anahtarı Türkçe metnin kendisidir; ayrı anahtar tablosu yok. Türkçe oyun hiçbir
  çeviri dosyası olmadan çalışır.
* `locale/en.json`, `es.json`, `de.json`, `fr.json`: `{"Türkçe metin": "çeviri"}`. Değeri `""` olan anahtar bilerek çevrilmez
  (editör grup adları, hata ayıklama metni, özel isimler).
* `Loc.t("…")` metni çevirir. **Biçimli metinlerde önce çevir, sonra biçimle:** `Loc.t("%s TAMİR YAP") % hedef`.
* `Loc.tn(metin, n)`: n == 1 ise tekil biçim (`"<metin>|1"` anahtarı, yalnızca çevirilerde): "OPEN 1 CRATE".
* `Loc.percent()` (TR %25 · EN 25% · ES 25 % · DE/FR 25 % bölünmez boşlukla), `Loc.decimal()` (TR/ES/DE/FR virgül · EN nokta),
  `Hud.format_thousands()` (TR/ES/DE 1.000 · EN 1,000 · FR 1 000 bölünmez boşlukla).
* `Loc.site_url("privacy" | "terms" | "contact" | "delete")`: web sitesinin oyuncunun dilindeki sayfası
  (`Loc.SITE_PATHS` sitenin `src/i18n/<dil>.json` "paths" alanıyla aynı tutulmalı).
* Sahne dosyalarındaki ve kodda doğrudan Label/Button'a verilen metinleri Godot kendisi çevirir (auto translate).
  Çevrilmemesi gereken düğme (dil adları) `auto_translate_mode = DISABLED`.
* Veri dosyalarından (decorations.json, crates.json) ve sabit kataloglardan (görevler, rütbe adları, boya adları)
  gelen metin **gösterildiği yerde** `Loc.t` ile çevrilir.
* Sunucuda yalnızca seçili dilin çevirisi yüklüdür (Godot karşılığı olmayan metni yedek dile, İngilizceye düşürür;
  hepsi yüklü olsaydı Türkçe seçiliyken İngilizce görünürdü).

## Dil seçimi

* Varsayılan: cihaz dili (tr / en / es / de / fr), değilse İngilizce. AYARLAR → dil sayfası ile değişir (sayfanın adı
  geçerli dilde + İngilizcesi: "SPRACHE · LANGUAGE"; anlamadığı dile geçen oyuncu da bulur),
  `user://settings.cfg`'ye yazılır (cihaza özel, kayda / buluta girmez).
* Dil değişince oyun kaydedilir ve sahne yeniden kurulur (hesap girişindeki dünya yenilemesiyle aynı yol):
  açık her ekran yeni dille baştan kurulur.

## Yeni metin eklerken

1. Oyuncuya görünen metni `Loc.t("…")` ile yaz (biçimliyse önce çevir).
2. `python3 tools/i18n/extract.py` → `locale/strings.json` güncellenir (kod + .tscn + JSON verileri).
3. `python3 tools/i18n/check.py` → eksik / biçim belirteci uyuşmayan / eskimiş çevirileri listeler.
4. Eksikleri `locale/en.json`, `es.json`, `de.json` ve `fr.json`'a ekle; `check.py` hatasız bitmeli.
5. `tools/i18n/wrap.py` eski kodu toplu sarmak içindi (bir kez çalıştırıldı); yeni kodda gerekmez.

## Bilinen sınırlar

* Araç adları (TOFAŞ ŞAHİN, BMW E46) özel isimdir, çevrilmez.
* Testler Türkçe metinleri denetler: `tools/run_tests.sh` her paketten önce `settings.cfg`'ye `language="tr"` yazar.
* Geliştirme makinesinin dili İngilizceyse (en_US) oyun editörde İngilizce açılır; AYARLAR'dan değiştirilebilir.

## Almanca / Fransızca yazım kuralları (2026-10-17)

* Hitap: Almanca **du**, Fransızca **tu** (oyunun "sen"i gibi).
* BÜYÜK HARF metinde Almanca `ß` → `SS`; Fransızca büyük harfte aksan korunur (`RÉPARATION`).
* Fransızca `! ? : ;` öncesinde ve `« »` içinde bölünmez boşluk (U+00A0); kesme işareti `’`.
* Terim sözlüğü (garaj = WERKSTATT / GARAGE, kasa = KISTE / CAISSE, gem = JUWELEN / GEMMES, hurdalık = SCHROTTPLATZ /
  CASSE, usta = MEISTER / MAÎTRE …): yeni metin eklerken mevcut çevirilerdeki karşılıkları kullan.
* Bildirim metinleri sunucuda: `firebase/functions/news.js` TEXT (de/fr eklendi); Firestore kuralı `push/p_{uid}.lang`
  yalnızca `tr/en/es/de/fr` kabul eder — yeni dil eklenirse kural da güncellenmeli ve yayınlanmalı.
