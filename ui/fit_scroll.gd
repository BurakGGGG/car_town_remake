class_name FitScroll
extends RefCounted
## Tam ekran panoların ortalanmış sütunu KISA ekranda taşmasın: sütun yeterince kısaysa eskisi gibi
## ortada durur; ekrandan uzunsa dikey kaydırılır (çubuksuz, ataletli: TouchScroll). Eskiden
## CenterContainer taşan içeriği iki uçtan da kırpıyordu — alttaki KAPAT düğmesi ekranın altında
## kalıyor, günlük görevler açılınca ulaşılamıyordu (telefonda 480 birim yükseklik).
##
## HUD PAYI: pano dünyanın üstünde açıkken sol üstteki oyun HUD'u (seviye, para, GEM AL) görünür kalır —
## ödüller oraya uçar. Dar tuvalde (853 birim: 16:9 telefon, tabletler) ortalanmış sütun o bloğun üstüne
## biniyordu (görev sekmeleri para satırının, gem kartları GEM AL'ın üstünde). HUD bloğun dikdörtgenini
## set_reserve ile yazar; sütun ona biniyorsa ortalama alanı bloğun sağından başlar (sığdığı kadar ortada).

const GROUP: StringName = &"fit_scroll"
## HUD bloğu ile sütun arasında bırakılan boşluk.
const GAP: float = 10.0
## Sütunun kadraj kenarına bıraktığı en az pay (available_width hesabı).
const EDGE: float = 16.0

## Sütunun örtmemesi gereken alan (tuval koordinatı). Boş = pay yok (bir YER açık, HUD gizli).
static var _reserve: Rect2 = Rect2()


## `host` altına [ScrollContainer > CenterContainer] kurar ve ortalayıcıyı döndürür; sütun ona eklenir.
static func center_in(host: Control) -> CenterContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "FitScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	scroll.add_to_group(GROUP)
	host.add_child(scroll)
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_PASS
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL   # kısa sütun: dikeyde ortada; uzunsa kaydırılır
	scroll.add_child(center)
	TouchScroll.attach(scroll)
	# Sütun boyu / kadraj / görünürlük değişince HUD payı yeniden hesaplanır (kare sonunda, bir kez)
	var refit: Callable = func() -> void: _fit(scroll)
	center.minimum_size_changed.connect(refit, CONNECT_DEFERRED)
	host.resized.connect(refit, CONNECT_DEFERRED)
	host.visibility_changed.connect(refit, CONNECT_DEFERRED)
	return center


## HUD sol üst bloğunun dikdörtgeni (boş Rect2 = pay yok). Açık panoların hepsi hemen yerleşir; genişliği
## available_width'e bağlı olan pano `fit_reserve_changed()` metodunu tanımlarsa o da çağrılır.
static func set_reserve(tree: SceneTree, rect: Rect2) -> void:
	if rect == _reserve:
		return
	_reserve = rect
	for node: Node in tree.get_nodes_in_group(GROUP):
		_fit(node as ScrollContainer)
		var host: Node = node.get_parent()
		if host and host.has_method(&"fit_reserve_changed"):
			host.call(&"fit_reserve_changed")


## Panonun yatayda kullanabileceği en geniş alan. `row` verilirse o satırın ortalanmış yerine bakılır: HUD
## bloğunun altında kalıyorsa tuvalin tamamı (iki kenar payı düşülmüş), bloğun hizasındaysa bloğun sağından
## kadraj kenarına kadarı. Geniş satırlar (gem kartları) buna göre kaydırılır.
static func available_width(host: Control, row: Control = null) -> float:
	var width: float = host.get_viewport_rect().size.x
	if not _reserve.has_area():
		return width - EDGE * 2.0
	if row:
		var column: Control = row.get_parent() as Control
		var top: float = _row_top(column, row, host.size)
		if top >= _reserve.end.y + GAP - host.global_position.y:
			return width - EDGE * 2.0
	return width - (_reserve.end.x + GAP) - EDGE


static func _fit(scroll: ScrollContainer) -> void:
	if scroll == null or not is_instance_valid(scroll) or scroll.get_child_count() == 0:
		return
	var host: Control = scroll.get_parent() as Control
	var center: Control = scroll.get_child(0) as Control
	var inset: float = 0.0
	if host and host.is_visible_in_tree() and center and center.get_child_count() > 0 and _reserve.has_area():
		var view: Vector2 = host.size
		var column: Control = center.get_child(0) as Control
		var limit: float = _reserve.end.x + GAP - host.global_position.x
		var bottom: float = _reserve.end.y + GAP - host.global_position.y
		# Bloğun HİZASINDAKİ satırların (tabela, sekmeler, liste...) ortalanmış sol kenarı bloğa değiyorsa
		# sütun o kadar sağa kayar; bloğun altında kalan satırlar (gem kartları) kaydırmayı gerektirmez.
		var shift: float = 0.0
		for entry: Dictionary in _rows(column, view):
			if float(entry["top"]) < bottom:
				shift = maxf(shift, limit - float(entry["left"]))
		# Ortalama alanı [inset, view.x]: merkez inset / 2 kayar; en çok bloğun sağına kadar
		inset = clampf(shift * 2.0, 0.0, limit)
	if not is_equal_approx(scroll.offset_left, inset):
		scroll.offset_left = inset


## Sütunun satırları (VBox ise çocukları, değilse kendisi) ORTALANMIŞ yerleşimde: üst kenar ve sol kenar.
## Yerleşim beklenmeden yalnızca en küçük boylardan hesaplanır (kare sonu sıralamasına bağlı kalmasın).
static func _rows(column: Control, view: Vector2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if column == null:
		return out
	var content: Vector2 = column.get_combined_minimum_size()
	var y: float = maxf((view.y - content.y) * 0.5, 0.0)
	var column_left: float = (view.x - content.x) * 0.5
	if not column is VBoxContainer:
		out.append({"node": column, "top": y, "left": column_left})
		return out
	var separation: float = float(column.get_theme_constant(&"separation"))
	for node: Node in column.get_children():
		var child: Control = node as Control
		if child == null or not child.visible or child.top_level:
			continue
		var size: Vector2 = child.get_combined_minimum_size()
		var flags: int = child.size_flags_horizontal
		var left: float = column_left
		if (flags & Control.SIZE_FILL) == 0:
			if flags & Control.SIZE_SHRINK_CENTER:
				left = (view.x - size.x) * 0.5
			elif flags & Control.SIZE_SHRINK_END:
				left = column_left + content.x - size.x
		out.append({"node": child, "top": y, "left": left})
		y += size.y + separation
	return out


static func _row_top(column: Control, row: Control, view: Vector2) -> float:
	for entry: Dictionary in _rows(column, view):
		if entry["node"] == row:
			return float(entry["top"])
	return 0.0
