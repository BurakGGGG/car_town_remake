class_name PetsScreen
extends Control
## HAYVANLAR ekranı (2026-11-03, kullanıcı kararı taslak "Ekran C · Büyük kart + altta yüz şeridi"). Sağ üstteki pati
## tabelasından (PetsButton) açılır; UiRouter'da PLACE "pets" (dünya kararmış arkada görünür, HUD gizli) — MODAL
## olsaydı üstünde ad ekranı / MARKET (ikisi de MODAL) açılınca kapanırdı.
##   - Sol üstte HAYVANLAR plakası + "GARAJDA n / 2"; sağ üstte ✕.
##   - Ortada seçili hayvanın büyük kartı: tam boy portre (assets/pets/portraits/<çeşit>.jpg), ad + durum (GARAJDA /
##     EVDE / fiyat), çeşidin açıklaması, DOSTLUK, ÜSTÜNDE; düğmeler: sahip olunan → GARAJA ÇIKAR / EVE GÖNDER +
##     ADINI DEĞİŞTİR; alınmamış → "%d GEM · SATIN AL" (ilk dokunuş ONAYLA, ikincisi alır; elmas yetmezse MARKET);
##     YAKINDA (köpek) → kapalı.
##   - Altta yuvarlak yüz şeridi (her çeşit + YAKINDA): seçili halkalı, altında durum etiketi ve ad.
## Kurallar PetManager'da: garajda en çok MAX_OUT hayvan (dolu garaja çıkarmak için önce biri eve gider), her çeşitten
## bir tane, aksesuar dolabı ortak. Alınan kedi varsayılan adla gelir, hemen ad ekranı açılır (değiştirmek isteğe bağlı).

signal closed

const CARD_SIZE: Vector2 = Vector2(620.0, 238.0)
const PORTRAIT_SIZE: Vector2 = Vector2(172.0, 212.0)
const FACE: float = 64.0
## Satın almada ilk dokunuştan sonra ONAYLA'nın açık kaldığı süre (sn).
const ARM_SEC: float = 3.0
const STATE_COLORS: Dictionary = {
	&"out": [HudPalette.PLATE_SELECTED, HudPalette.PLATE_SELECTED_EDGE],
	&"home": [Color("E2D9C2"), HudPalette.PLATE_EDGE],
	&"price": [HudPalette.GEM_LIGHT, HudPalette.GEM_DARK],
	&"soon": [HudPalette.LANE_TRACK, Color("8A8F96")],
}

## Ad ekranı (yakın kameranınki; Hud verir).
var name_screen: PetNameScreen
var _pets: PetManager
var _router: UiRouter
var _selected: StringName = &"orange"
var _armed_until: int = 0
var _closing: bool = false

var _column: VBoxContainer
var _count_label: Label
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _dog: _Dog
var _name_label: Label
var _state_chip: PanelContainer
var _state_label: Label
var _caption: Label
var _friend_box: VBoxContainer
var _friend_bar: _Bar
var _friend_label: Label
var _worn_label: Label
var _note: Label
var _primary: PlateButton
var _rename_button: PlateButton
var _faces: HBoxContainer
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween          # art arda bildirimde eskisinin solması yenisini söndürmesin


func _ready() -> void:
	name = "PetsScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()


func open() -> void:
	_pets = get_tree().get_first_node_in_group("pets") as PetManager
	_router = get_tree().get_first_node_in_group("ui_router") as UiRouter
	if _router and not _router.stack_changed.is_connected(_on_stack):
		_router.stack_changed.connect(_on_stack)
	_closing = false
	_armed_until = 0
	if _pets:
		if not _pets.pets_changed.is_connected(_refresh):
			_pets.pets_changed.connect(_refresh)
			_pets.name_changed.connect(func(_n: String) -> void: _refresh())
			_pets.accessories_changed.connect(_refresh)
		# Açılışta garajdaki (odaktaki) hayvan seçili
		var info: Dictionary = _pets.pet_info(_pets.focused())
		_selected = StringName(info.get("variant", &"orange"))
		_pets.mark_screen_seen()
	_refresh()
	show()
	PlateAnim.pop_in(self, _column)


func close() -> void:
	if not visible or _closing:
		return
	_closing = true
	PlateAnim.pop_out(self, _column, func() -> void:
		hide()
		_closing = false
		closed.emit())


## Testler / QA: kartı bir çeşide getirir.
func select(id: StringName) -> void:
	_selected = id
	_armed_until = 0
	_refresh()


func selected() -> StringName:
	return _selected


# --- Durum ------------------------------------------------------------------------------------

func _refresh() -> void:
	if _pets == null:
		return
	_count_label.text = Loc.t("GARAJDA %d / %d") % [_pets.out_pets().size(), PetManager.MAX_OUT]
	var soon: bool = _is_soon(_selected)
	var v: Dictionary = PetManager.variant(_selected)
	var uid: String = _pets.uid_of_variant(_selected)
	var owned: bool = uid != ""
	_portrait_frame.visible = not soon
	_dog.visible = soon
	if not soon:
		_portrait.texture = load("res://assets/pets/portraits/%s.jpg" % _selected) as Texture2D
	if soon:
		_name_label.text = Loc.t(_soon_name(_selected))
	elif owned:
		_name_label.text = _pets.name_of(uid).to_upper()
	else:
		_name_label.text = Loc.t(String(v["name"]))
	var state: StringName = _state_of(_selected)
	_set_chip(state, uid)
	_caption.text = Loc.t("Garajına yakında gelecek.") if soon else Loc.t(String(v["caption"]))
	_friend_box.visible = owned
	_note.visible = not owned
	if owned:
		var points: int = _pets.friendship_of(uid)
		var next: int = 0
		for t: Dictionary in PetManager.TRICKS:
			if points < int(t["points"]):
				next = int(t["points"])
				break
		_friend_bar.value = 1.0 if next == 0 else clampf(float(points) / float(next), 0.0, 1.0)
		_friend_label.text = str(points) if next == 0 else "%d / %d" % [points, next]
		var names: PackedStringArray = PackedStringArray()
		for id: StringName in _pets.worn_of(uid):
			names.append(Loc.t(String(PetManager.accessory(id)["name"])))
		_worn_label.text = " · ".join(names) if not names.is_empty() else "—"
	elif soon:
		_note.text = Loc.t("Yeni dostlar yolda: köpekler de garaja geliyor.")
	else:
		_note.text = Loc.t("Kendi adı, dostluğu ve kıyafetleriyle garajına gelir.")
	_refresh_buttons(uid, soon)
	_refresh_faces()


func _refresh_buttons(uid: String, soon: bool) -> void:
	_primary.disabled = false
	_primary.highlight = false
	_primary.kind = HudIcon.Kind.NONE
	_rename_button.visible = uid != ""
	if uid != "":
		var cost: int = _pets.rename_cost(uid)
		_rename_button.kind = HudIcon.Kind.GEM if cost > 0 else HudIcon.Kind.NONE
		_rename_button.icon_left = true
		_rename_button.icon_size = 16.0
		_rename_button.text = Loc.t("ADINI DEĞİŞTİR · %d") % cost if cost > 0 else Loc.t("ADINI DEĞİŞTİR")
	if soon:
		_primary.text = Loc.t("YAKINDA")
		_primary.disabled = true
	elif uid != "":
		if _pets.is_out(uid):
			_primary.text = Loc.t("EVE GÖNDER")
		else:
			_primary.text = Loc.t("GARAJA ÇIKAR")
			_primary.highlight = true
	else:
		var cost: int = int(PetManager.variant(_selected).get("gems", 0))
		_primary.kind = HudIcon.Kind.GEM
		_primary.icon_left = true
		_primary.icon_size = 18.0
		if Time.get_ticks_msec() < _armed_until:
			_primary.text = Loc.t("ONAYLA: %d") % cost
			_primary.highlight = true
		else:
			_primary.text = Loc.t("%d GEM · SATIN AL") % cost


func _state_of(id: StringName) -> StringName:
	if _is_soon(id):
		return &"soon"
	var uid: String = _pets.uid_of_variant(id)
	if uid == "":
		return &"price"
	return &"out" if _pets.is_out(uid) else &"home"


func _state_text(state: StringName, id: StringName) -> String:
	match state:
		&"out":
			return Loc.t("GARAJDA")
		&"home":
			return Loc.t("EVDE")
		&"price":
			return Loc.t("%d GEM") % int(PetManager.variant(id).get("gems", 0))
	return Loc.t("YAKINDA")


func _set_chip(state: StringName, _uid: String) -> void:
	var colors: Array = STATE_COLORS[state]
	_state_chip.add_theme_stylebox_override(&"panel", _chip_box(colors[0], colors[1]))
	_state_label.text = _state_text(state, _selected)
	_state_label.add_theme_color_override(&"font_color", HudPalette.TEXT_LIGHT if state == &"soon" else HudPalette.INK)


func _refresh_faces() -> void:
	for face: Node in _faces.get_children():
		var f: _Face = face as _Face
		var state: StringName = _state_of(f.id)
		f.selected = f.id == _selected
		f.dim = state == &"price" or state == &"soon"
		var uid: String = _pets.uid_of_variant(f.id)
		f.set_labels(_pets.name_of(uid).to_upper() if uid != "" else
			(Loc.t(_soon_name(f.id)) if state == &"soon" else Loc.t(String(PetManager.variant(f.id)["name"]))),
			_state_text(state, f.id))
		var colors: Array = STATE_COLORS[state]
		f.set_tag_style(_chip_box(colors[0], colors[1]), HudPalette.TEXT_LIGHT if state == &"soon" else HudPalette.INK)


static func _is_soon(id: StringName) -> bool:
	for s: Dictionary in PetManager.SOON:
		if s["id"] == id:
			return true
	return false


static func _soon_name(id: StringName) -> String:
	for s: Dictionary in PetManager.SOON:
		if s["id"] == id:
			return String(s["name"])
	return ""


# --- Eylemler ---------------------------------------------------------------------------------

func _on_face(id: StringName) -> void:
	if _selected == id:
		return
	_selected = id
	_armed_until = 0
	_refresh()


func _on_primary() -> void:
	if _pets == null or _is_soon(_selected):
		return
	var uid: String = _pets.uid_of_variant(_selected)
	if uid != "":
		if _pets.is_out(uid):
			_pets.set_out(uid, false)
			_show_toast(Loc.t("%s EVE GİTTİ") % _pets.name_of(uid).to_upper())
		elif not _pets.set_out(uid, true):
			_show_toast(Loc.t("GARAJ DOLU\nÖnce bir hayvanı eve gönder."))
		else:
			_show_toast(Loc.t("%s GARAJA ÇIKTI") % _pets.name_of(uid).to_upper())
		return
	var cost: int = int(PetManager.variant(_selected).get("gems", 0))
	if Time.get_ticks_msec() >= _armed_until:
		_armed_until = Time.get_ticks_msec() + int(ARM_SEC * 1000.0)
		_refresh_buttons("", false)
		get_tree().create_timer(ARM_SEC + 0.05).timeout.connect(func() -> void:
			if visible:
				_refresh_buttons(_pets.uid_of_variant(_selected), _is_soon(_selected)))
		return
	_armed_until = 0
	var player: PlayerProgress = get_tree().get_first_node_in_group("player_progress") as PlayerProgress
	if player == null or not player.can_afford_gems(cost):
		_show_toast(Loc.t("GEM YETMİYOR\n%d GEM gerekiyor, %d GEM'in var.") % [cost, player.gems if player else 0])
		_refresh_buttons("", false)
		if _router:
			_router.open(&"gem_store")
		return
	var new_uid: String = _pets.buy_pet(_selected)
	if new_uid == "":
		_refresh()
		return
	_ask_name(new_uid, Loc.t("Yeni kedine ad ver"))


func _rename() -> void:
	var uid: String = _pets.uid_of_variant(_selected) if _pets else ""
	if uid != "":
		_ask_name(uid, "")


## Ad ekranı (yakın kameranınki, MODAL "pet_name") odaktaki hayvanı adlandırır: önce odak bu hayvana alınır.
func _ask_name(uid: String, title: String) -> void:
	var screen: PetNameScreen = name_screen
	if screen == null or _router == null:
		return
	_pets.focus(uid)
	screen.mandatory = false
	screen.start_name = _pets.name_of(uid)
	screen.title_text = title
	screen.cost_gems = _pets.rename_cost(uid)   # ilk ad ücretsiz, sonrası elmas
	_router.open(&"pet_name")


## Üstte bir pencere (ad ekranı, MARKET) açıkken HAYVANLAR görünmez: o pencereler bu ekrandan önce kurulduğu için
## altta kalıyordu (MARKET tümüyle örtülüyordu, künye kartın üstüne biniyordu). Kapanınca geri gelir, tazelenir.
func _on_stack(top: StringName, _place_open: bool) -> void:
	if not visible or _closing:
		return
	var covered: bool = top != &"pets" and _router.is_open(&"pets")
	for c: Node in get_children():
		(c as CanvasItem).visible = not covered or c == _toast.get_parent()
	if not covered:
		_refresh()


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.visible = true
	_toast.modulate.a = 1.0
	if _toast_tween and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast_tween = _toast.create_tween()
	_toast_tween.tween_interval(1.6)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.3)
	_toast_tween.tween_callback(func() -> void: _toast.visible = false)


# --- Kurulum ----------------------------------------------------------------------------------

func _label(variation: StringName, text: String) -> Label:
	var l: Label = Label.new()
	l.theme_type_variation = variation
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func _chip_box(bg: Color, edge: Color) -> StyleBoxFlat:
	var b: StyleBoxFlat = StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = edge
	b.set_border_width_all(2)
	b.set_corner_radius_all(6)
	b.content_margin_left = 8.0
	b.content_margin_right = 8.0
	b.content_margin_top = 1.0
	b.content_margin_bottom = 1.0
	return b


func _build() -> void:
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.06, 0.07, 0.08, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, 14)
	add_child(margin)
	_column = VBoxContainer.new()
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_theme_constant_override(&"separation", 8)
	margin.add_child(_column)

	# Üst sıra: HAYVANLAR plakası · ✕
	var top: HBoxContainer = HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(top)
	var title: PanelContainer = PanelContainer.new()
	title.add_theme_stylebox_override(&"panel", PetCloseupScreen.plate_box())
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	top.add_child(title)
	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override(&"separation", 10)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(title_row)
	var paw: TextureRect = TextureRect.new()
	paw.texture = load("res://ui/hud/art/nav/pets.svg") as Texture2D
	paw.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	paw.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	paw.custom_minimum_size = Vector2(30.0, 26.0)
	paw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(paw)
	var title_label: Label = _label(&"HudPlateTitle", Loc.t("HAYVANLAR"))
	title_label.add_theme_font_size_override(&"font_size", 22)
	title_row.add_child(title_label)
	_count_label = _label(&"HudInkCaption", "")
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	title_row.add_child(_count_label)
	var spacer: Control = Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var close_button: PlateButton = PlateButton.new()
	close_button.shape = PlateButton.Shape.ROUND
	close_button.theme_type_variation = &"HudSign"
	close_button.kind = HudIcon.Kind.CROSS
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(func() -> void:
		if _router:
			_router.back())
	top.add_child(close_button)

	var gap: Control = Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(gap)
	_build_card()
	var gap2: Control = Control.new()
	gap2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_column.add_child(gap2)

	# Yüz şeridi
	var strip: CenterContainer = CenterContainer.new()
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(strip)
	_faces = HBoxContainer.new()
	_faces.add_theme_constant_override(&"separation", 22)
	_faces.mouse_filter = Control.MOUSE_FILTER_IGNORE
	strip.add_child(_faces)
	var ids: Array[StringName] = []
	for v: Dictionary in PetManager.VARIANTS:
		ids.append(v["id"])
	for s: Dictionary in PetManager.SOON:
		ids.append(s["id"])
	for id: StringName in ids:
		var face: _Face = _Face.new()
		face.id = id
		face.texture = load("res://assets/pets/portraits/%s_face.png" % id) as Texture2D \
			if ResourceLoader.exists("res://assets/pets/portraits/%s_face.png" % id) else null
		face.pressed.connect(_on_face.bind(id))
		_faces.add_child(face)

	# Bildirim (üst orta)
	var toast_box: VBoxContainer = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	toast_box.offset_top = 70.0
	add_child(toast_box)
	_toast = PanelContainer.new()
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.add_theme_stylebox_override(&"panel", PetCloseupScreen.plate_box())
	_toast.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_toast.visible = false
	_toast_label = _label(&"HudInkValue", "")
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)
	toast_box.add_child(_toast)


func _build_card() -> void:
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(center)
	var card: PanelContainer = PanelContainer.new()
	card.add_theme_stylebox_override(&"panel", PetCloseupScreen.plate_box())
	card.custom_minimum_size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(card)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	card.add_child(row)
	# Portre (çerçeveli) ya da YAKINDA çizimi
	_portrait_frame = PanelContainer.new()
	var frame: StyleBoxFlat = StyleBoxFlat.new()
	frame.bg_color = HudPalette.LANE_TRACK
	frame.border_color = HudPalette.INK
	frame.set_border_width_all(2)
	frame.set_corner_radius_all(8)
	frame.set_content_margin_all(2.0)
	_portrait_frame.add_theme_stylebox_override(&"panel", frame)
	_portrait_frame.custom_minimum_size = PORTRAIT_SIZE
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.clip_contents = true
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	_dog = _Dog.new()
	_dog.custom_minimum_size = PORTRAIT_SIZE
	_dog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dog.visible = false
	row.add_child(_dog)
	# Bilgi
	var info: VBoxContainer = VBoxContainer.new()
	info.add_theme_constant_override(&"separation", 5)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var head: HBoxContainer = HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 10)
	info.add_child(head)
	_name_label = _label(&"HudPlateTitle", "")
	_name_label.add_theme_font_size_override(&"font_size", 28)
	_name_label.clip_text = true
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_name_label)
	_state_chip = PanelContainer.new()
	_state_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_state_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(_state_chip)
	_state_label = _label(&"HudInkCaption", "")
	_state_label.add_theme_font_size_override(&"font_size", 12)
	_state_chip.add_child(_state_label)
	_caption = _label(&"HudInkCaption", "")
	_caption.add_theme_font_size_override(&"font_size", 13)
	info.add_child(_caption)
	_friend_box = VBoxContainer.new()
	_friend_box.add_theme_constant_override(&"separation", 4)
	info.add_child(_friend_box)
	_friend_box.add_child(_label(&"HudInkCaption", Loc.t("DOSTLUK")))
	var friend: HBoxContainer = HBoxContainer.new()
	friend.add_theme_constant_override(&"separation", 8)
	_friend_box.add_child(friend)
	_friend_bar = _Bar.new()
	_friend_bar.custom_minimum_size = Vector2(0.0, 14.0)
	_friend_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_friend_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	friend.add_child(_friend_bar)
	_friend_label = _label(&"HudInkValue", "")
	friend.add_child(_friend_label)
	_friend_box.add_child(_label(&"HudInkCaption", Loc.t("ÜSTÜNDE")))
	_worn_label = _label(&"HudInkValue", "")
	_worn_label.clip_text = true
	_friend_box.add_child(_worn_label)
	_note = _label(&"HudInkValue", "")
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_note)
	var fill: Control = Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(fill)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	info.add_child(buttons)
	_primary = PlateButton.new()
	_primary.theme_type_variation = &"HudPlate"
	_primary.focus_mode = Control.FOCUS_NONE
	_primary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_primary.pressed.connect(_on_primary)
	buttons.add_child(_primary)
	_rename_button = PlateButton.new()
	_rename_button.theme_type_variation = &"HudPlate"
	_rename_button.focus_mode = Control.FOCUS_NONE
	_rename_button.text = Loc.t("ADINI DEĞİŞTİR")
	_rename_button.pressed.connect(_rename)
	buttons.add_child(_rename_button)


## Dostluk çubuğu: koyu yol şeridi üstünde amber dolgu (yakın kamera kartıyla aynı dil).
class _Bar extends Control:
	var value: float = 0.0:
		set(v):
			value = v
			queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		var back: StyleBoxFlat = StyleBoxFlat.new()
		back.bg_color = HudPalette.LANE_TRACK
		back.border_color = HudPalette.INK
		back.set_border_width_all(2)
		back.set_corner_radius_all(int(size.y * 0.5))
		draw_style_box(back, r)
		if value > 0.0:
			var fill: StyleBoxFlat = StyleBoxFlat.new()
			fill.bg_color = HudPalette.LANE_PAINT
			fill.set_corner_radius_all(int(size.y * 0.5) - 2)
			draw_style_box(fill, Rect2(Vector2(2.0, 2.0), Vector2((size.x - 4.0) * value, size.y - 4.0)))


## Yüz şeridinin bir yuvası: yuvarlak yüz (seçiliyse amber halka), altında durum etiketi ve ad.
class _Face extends Button:
	var id: StringName = &""
	var texture: Texture2D
	var selected: bool = false:
		set(v):
			selected = v
			_disc.queue_redraw()
	var dim: bool = false:
		set(v):
			dim = v
			_disc.queue_redraw()
	var _disc: Control
	var _tag: PanelContainer
	var _tag_label: Label
	var _name: Label

	func _init() -> void:
		flat = true
		focus_mode = Control.FOCUS_NONE
		custom_minimum_size = Vector2(PetsScreen.FACE + 30.0, PetsScreen.FACE + 46.0)
		var col: VBoxContainer = VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.add_theme_constant_override(&"separation", 2)
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(col)
		_disc = Control.new()
		_disc.custom_minimum_size = Vector2(PetsScreen.FACE, PetsScreen.FACE)
		_disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_disc.draw.connect(_draw_disc)
		col.add_child(_disc)
		_tag = PanelContainer.new()
		_tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_tag)
		_tag_label = Label.new()
		_tag_label.theme_type_variation = &"HudInkCaption"
		_tag_label.add_theme_font_size_override(&"font_size", 10)
		_tag_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tag.add_child(_tag_label)
		_name = Label.new()
		_name.theme_type_variation = &"HudOutlined"
		_name.add_theme_font_size_override(&"font_size", 12)
		_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(_name)

	func set_labels(pet_name: String, tag: String) -> void:
		_name.text = pet_name
		_tag_label.text = tag

	func set_tag_style(box: StyleBox, ink: Color) -> void:
		_tag.add_theme_stylebox_override(&"panel", box)
		_tag_label.add_theme_color_override(&"font_color", ink)

	func _draw_disc() -> void:
		var r: float = PetsScreen.FACE * 0.5
		var c: Vector2 = _disc.size * 0.5
		if selected:
			_disc.draw_circle(c, r + 5.0, HudPalette.INK)
			_disc.draw_circle(c, r + 3.0, HudPalette.PLATE_SELECTED)
		else:
			_disc.draw_circle(c, r + 2.5, HudPalette.TEXT_LIGHT if not dim else Color("8A8F96"))
		_disc.draw_circle(c, r, HudPalette.LANE_TRACK)
		var tint: Color = Color(1, 1, 1, 0.6) if dim else Color.WHITE
		if texture:
			_disc.draw_texture_rect(texture, Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), false, tint)
		else:
			PetsScreen._Dog.draw_dog(_disc, c, r * 0.62, Color("8A8F96"))


## YAKINDA: sarkık kulaklı köpek başı silueti (model yok).
class _Dog extends Control:
	func _draw() -> void:
		var frame: StyleBoxFlat = StyleBoxFlat.new()
		frame.bg_color = HudPalette.LANE_TRACK
		frame.border_color = Color("8A8F96")
		frame.set_border_width_all(2)
		frame.set_corner_radius_all(8)
		draw_style_box(frame, Rect2(Vector2.ZERO, size))
		draw_dog(self, size * 0.5, minf(size.x, size.y) * 0.3, Color("5A5E64"))

	static func draw_dog(ci: CanvasItem, c: Vector2, s: float, color: Color) -> void:
		ci.draw_circle(c + Vector2(0.0, s * 0.1), s, color)                 # baş
		for sx: float in [-1.0, 1.0]:                                        # sarkık kulaklar
			var ear: PackedVector2Array = PackedVector2Array()
			for i: int in 14:
				var a: float = TAU * float(i) / 14.0
				ear.append(c + Vector2(sx * s * 0.95, s * 0.15) + Vector2(cos(a) * s * 0.34, sin(a) * s * 0.7))
			ci.draw_colored_polygon(ear, color.darkened(0.25))
		ci.draw_circle(c + Vector2(0.0, s * 0.62), s * 0.42, color.lightened(0.18))   # burun bölgesi
		ci.draw_circle(c + Vector2(0.0, s * 0.45), s * 0.16, HudPalette.INK)           # burun
		for sx: float in [-1.0, 1.0]:
			ci.draw_circle(c + Vector2(sx * s * 0.38, s * -0.05), s * 0.1, HudPalette.INK)   # gözler
