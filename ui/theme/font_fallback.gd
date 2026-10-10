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

const SYMBOLS_PATH: String = "res://ui/theme/fonts/autoyard_symbols.ttf"


static func install() -> void:
	var base: Font = ThemeDB.fallback_font
	if base == null or not ResourceLoader.exists(SYMBOLS_PATH):
		return
	var symbols: Font = load(SYMBOLS_PATH) as Font
	if symbols == null or base.fallbacks.has(symbols):
		return
	var list: Array[Font] = base.fallbacks.duplicate()
	list.append(symbols)
	base.fallbacks = list
