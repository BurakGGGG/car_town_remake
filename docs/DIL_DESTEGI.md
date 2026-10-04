# Dil desteği — Türkçe · İngilizce · İspanyolca

Durum: 2026-10-04. Kod: `ui/loc.gd` (Loc), dil ayarı `gameplay/game_settings.gd`, çeviriler `locale/`.
Test: `tests/locale_test.gd`.

## Nasıl çalışır

* **Kaynak dil Türkçe.** Çeviri anahtarı Türkçe metnin kendisidir; ayrı anahtar tablosu yok. Türkçe oyun hiçbir
  çeviri dosyası olmadan çalışır.
* `locale/en.json`, `locale/es.json`: `{"Türkçe metin": "çeviri"}`. Değeri `""` olan anahtar bilerek çevrilmez
  (editör grup adları, hata ayıklama metni, özel isimler).
* `Loc.t("…")` metni çevirir. **Biçimli metinlerde önce çevir, sonra biçimle:** `Loc.t("%s TAMİR YAP") % hedef`.
* `Loc.tn(metin, n)`: n == 1 ise tekil biçim (`"<metin>|1"` anahtarı, yalnızca çevirilerde): "OPEN 1 CRATE".
* `Loc.percent()` (TR %25 · EN 25% · ES 25 %), `Loc.decimal()` (TR/ES virgül · EN nokta),
  `Hud.format_thousands()` (TR/ES 1.000 · EN 1,000).
* Sahne dosyalarındaki ve kodda doğrudan Label/Button'a verilen metinleri Godot kendisi çevirir (auto translate).
  Çevrilmemesi gereken düğme (dil adları) `auto_translate_mode = DISABLED`.
* Veri dosyalarından (decorations.json, crates.json) ve sabit kataloglardan (görevler, rütbe adları, boya adları)
  gelen metin **gösterildiği yerde** `Loc.t` ile çevrilir.
* Sunucuda yalnızca seçili dilin çevirisi yüklüdür (Godot karşılığı olmayan metni yedek dile, İngilizceye düşürür;
  hepsi yüklü olsaydı Türkçe seçiliyken İngilizce görünürdü).

## Dil seçimi

* Varsayılan: cihaz dili (tr / en / es), değilse İngilizce. AYARLAR → DİL · LANGUAGE · IDIOMA ile değişir,
  `user://settings.cfg`'ye yazılır (cihaza özel, kayda / buluta girmez).
* Dil değişince oyun kaydedilir ve sahne yeniden kurulur (hesap girişindeki dünya yenilemesiyle aynı yol):
  açık her ekran yeni dille baştan kurulur.

## Yeni metin eklerken

1. Oyuncuya görünen metni `Loc.t("…")` ile yaz (biçimliyse önce çevir).
2. `python3 tools/i18n/extract.py` → `locale/strings.json` güncellenir (kod + .tscn + JSON verileri).
3. `python3 tools/i18n/check.py` → eksik / biçim belirteci uyuşmayan / eskimiş çevirileri listeler.
4. Eksikleri `locale/en.json` ve `locale/es.json`'a ekle; `check.py` hatasız bitmeli.
5. `tools/i18n/wrap.py` eski kodu toplu sarmak içindi (bir kez çalıştırıldı); yeni kodda gerekmez.

## Bilinen sınırlar

* Araç adları (TOFAŞ ŞAHİN, BMW E46) özel isimdir, çevrilmez.
* Testler Türkçe metinleri denetler: `tools/run_tests.sh` her paketten önce `settings.cfg`'ye `language="tr"` yazar.
* Geliştirme makinesinin dili İngilizceyse (en_US) oyun editörde İngilizce açılır; AYARLAR'dan değiştirilebilir.
