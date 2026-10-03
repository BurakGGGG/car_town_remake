class_name FitScroll
extends RefCounted
## Tam ekran panoların ortalanmış sütunu KISA ekranda taşmasın: sütun yeterince kısaysa eskisi gibi
## ortada durur; ekrandan uzunsa dikey kaydırılır (çubuksuz, ataletli: TouchScroll). Eskiden
## CenterContainer taşan içeriği iki uçtan da kırpıyordu — alttaki KAPAT düğmesi ekranın altında
## kalıyor, günlük görevler açılınca ulaşılamıyordu (telefonda 480 birim yükseklik).


## `host` altına [ScrollContainer > CenterContainer] kurar ve ortalayıcıyı döndürür; sütun ona eklenir.
static func center_in(host: Control) -> CenterContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "FitScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL   # kısa sütun: dikeyde ortada; uzunsa kaydırılır
	scroll.add_child(center)
	TouchScroll.attach(scroll)
	return center
