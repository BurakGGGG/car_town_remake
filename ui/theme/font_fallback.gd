class_name FontFallback
extends RefCounted
## YAZI TİPİ YEDEĞİ: oyunun yazı tipi (Godot'nun gömülü Open Sans SemiBold'u — tema FontVariation'ının
## temel yazı tipi boş) ₺, ★ ☆, → ← ↔ ↗, ✓ ✔, ↻, ≡ karakterlerini İÇERMİYOR. Eksik karakterde Godot
## SİSTEM yazı tiplerini tek tek tarar: ölçüldü, görevler ekranının başarım sekmesi bu yüzden 175 ms
## sürüyordu (bu karakterler olmadan 32 ms). ₺ her para yazısında geçtiği için tarama oyunun her
## yerindeydi; telefonda karakterler de cihaza göre farklı bir sistem yazı tipiyle görünüyordu.
##
## Çözüm: yalnızca bu glifleri taşıyan küçük bir alt küme (DejaVu Sans Bold'dan, 16 KB,
## ui/theme/fonts/autoyard_symbols.ttf — lisans gereği yeniden adlandırıldı, DEJAVU_LICENSE.txt)
## gömülü yazı tipinin yedeği olarak bağlanır: arama paketin içinde biter, sistem taranmaz.
## Tema .tres'ine dokunulmaz; çalışma anında bir kez kurulur (Hud._ready).
##
## PARA = ALTIN SİMGE (2026-11-03, kullanıcı: "paramızın adı TL olmasın, direkt gold simgesi olsun, yabancı oyuncularım
## da var"): metinlerdeki ₺ değişmedi; zincirde sembol yazı tipinin ÖNÜNDE yalnız U+20BA'yı taşıyan RENKLİ bir yazı tipi
## (autoyard_coin.ttf, tools/fonts/make_coin_font.py) durur → her yazıda ₺ yerine HUD'daki altın paranın aynısı çizilir
## (renk katmanları yazı rengine boyanmaz: koyu ve beyaz yazıda aynı altın).

const COIN_PATH: String = "res://ui/theme/fonts/autoyard_coin.ttf"
const SYMBOLS_PATH: String = "res://ui/theme/fonts/autoyard_symbols.ttf"


static func install() -> void:
	var base: Font = ThemeDB.fallback_font
	if base == null:
		return
	var ours: Array[Font] = []
	for path: String in [COIN_PATH, SYMBOLS_PATH]:   # sıra önemli: ₺ ikisinde de var, para önce gelmeli
		var font: Font = load(path) as Font if ResourceLoader.exists(path) else null
		if font != null:
			ours.append(font)
	var list: Array[Font] = []
	for font: Font in base.fallbacks:
		if not ours.has(font):
			list.append(font)
	list.append_array(ours)
	if list != base.fallbacks:
		base.fallbacks = list
