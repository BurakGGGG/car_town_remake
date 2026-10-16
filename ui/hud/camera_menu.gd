class_name CameraMenu
extends PanelContainer
## KAMERA MENÜSÜ — sağ üstteki kamera tabelasına basınca hemen altında açılan küçük kutu. Yazı yok: kutunun
## içinde tek sırada yuvarlak tabelalar — FOTOĞRAF ÇEK · HUD'U GİZLE · SİNEMA MODU | UZAKLAŞ · YAKINLAŞ · ORTALA
## (ince ayraç modları kamera kontrollerinden ayırır; yakınlaştırma tabelaları sahnedeki ZoomIn/ZoomOut
## düğmeleridir, HUD buraya taşır). Kutunun üst kenarında kamera tabelasını gösteren küçük bir çıkıntı var.
## Sağ üst sütunda tabela sırasının altına girer, GÖREVLER / ARKADAŞLAR bir sıra aşağı kayar.
## Bir mod seçilince ya da kutunun / kamera tabelasının dışına dokunulunca kapanır (dismissed);
## yakınlaştırma ve ortala kutuyu açık bırakır (art arda basılabilsin).
## Yalnızca görünüm: ne yapılacağına HUD karar verir (sinyaller).

signal photo_requested
signal hide_hud_requested
signal cinema_requested
signal recenter_requested
## Kutunun dışına dokunuldu (HUD kamera tabelasını bırakır, kutu kapanır).
signal dismissed

## Dışarı dokunuş sayılmayan pay: düğmelerin görünmez dokunma kenarı (PlateButton.MIN_TOUCH) kadar.
const TOUCH_SLOP: float = 14.0
## Kamera tabelasını gösteren çıkıntının yarı genişliği / yüksekliği (sütun aralığına sığar).
const TAIL_HALF: float = 8.0
const TAIL_HEIGHT: float = 6.0

var photo_button: PlateButton
var hide_hud_button: PlateButton
var cinema_button: PlateButton
var recenter_button: PlateButton
## Kutuyu açan tabela: ona dokunmak "dışarı" sayılmaz (kendi toggled'ı kapatır); çıkıntı onu gösterir.
var anchor_button: Control
var _row: HBoxContainer
var _tween: Tween


func _init() -> void:
	name = "CameraMenu"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP   # kutunun boşluklarına dokunuş dünyaya geçmesin
	size_flags_horizontal = Control.SIZE_SHRINK_END
	item_rect_changed.connect(queue_redraw)   # sütun yeniden dizilince çıkıntı kamerayı göstermeye devam etsin


func _ready() -> void:
	if anchor_button:   # kutu açılınca sütun genişler, tabela sırası bir kare sonra yeniden dizilir
		anchor_button.item_rect_changed.connect(queue_redraw)
	# Zemin: araç plakasının (HudCarPlate) kremi ve alt kalınlığı; daha yuvarlak köşe, daha dar pay
	var plate: StyleBoxFlat = get_theme_stylebox(&"panel", &"HudCarPlate") as StyleBoxFlat
	var box: StyleBoxFlat = plate.duplicate() as StyleBoxFlat if plate else StyleBoxFlat.new()
	if plate == null:
		box.bg_color = HudPalette.PLATE
	box.set_corner_radius_all(16)
	box.content_margin_left = 6.0
	box.content_margin_right = 6.0
	box.content_margin_top = 5.0
	box.content_margin_bottom = 8.0
	add_theme_stylebox_override(&"panel", box)
	_row = HBoxContainer.new()
	_row.name = "Signs"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_theme_constant_override(&"separation", 4)
	add_child(_row)
	photo_button = _sign("PhotoButton", HudIcon.Kind.CAMERA, photo_requested)
	hide_hud_button = _sign("HideHudButton", HudIcon.Kind.EYE_OFF, hide_hud_requested)
	cinema_button = _sign("CinemaButton", HudIcon.Kind.FILM, cinema_requested)
	var divider: ColorRect = ColorRect.new()
	divider.name = "Divider"
	divider.color = Color(HudPalette.PLATE_EDGE, 0.7)
	divider.custom_minimum_size = Vector2(2, 28)
	divider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.add_child(divider)
	recenter_button = _sign("RecenterButton", HudIcon.Kind.TARGET, recenter_requested)


## Sahnedeki yakınlaştırma tabelalarını kutuya alır (ayraçtan sonra, ORTALA'nın soluna: − + ⌖).
func adopt_zoom_buttons(zoom_out: Control, zoom_in: Control) -> void:
	var at: int = recenter_button.get_index()
	for button: Control in [zoom_out, zoom_in]:
		button.reparent(_row, false)
		button.theme_type_variation = photo_button.theme_type_variation
	_row.move_child(zoom_out, at)
	_row.move_child(zoom_in, at + 1)


## Tüm yuvarlak tabelalar (sırasıyla).
func signs() -> Array[PlateButton]:
	var out: Array[PlateButton] = []
	for child: Node in _row.get_children():
		if child is PlateButton:
			out.append(child)
	return out


func open() -> void:
	if visible:
		return
	if _tween:
		_tween.kill()
	show()
	queue_redraw()
	# Kamera tabelasının altından "açılır": üst kenardan büyüyüp belirir
	pivot_offset = Vector2(size.x, 0.0)
	scale = Vector2(0.9, 0.8)
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, 0.10)


func close() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	scale = Vector2.ONE
	modulate.a = 1.0
	hide()


## Üst kenarda kamera tabelasının ortasını gösteren çıkıntı (kutunun kremiyle aynı renk, dikişsiz).
## Konum kutunun YERLEŞİM yerinden (position) hesaplanır, kendi ölçeğinden değil: açılış animasyonu sürerken
## çizilse de animasyon bitince doğru yerde kalır.
func _draw() -> void:
	var parent: Control = get_parent() as Control
	if anchor_button == null or not is_instance_valid(anchor_button) or parent == null:
		return
	var center: Vector2 = parent.get_global_transform().affine_inverse() * Hud.screen_rect(anchor_button).get_center()
	var x: float = clampf(center.x - position.x, 18.0 + TAIL_HALF, size.x - 18.0 - TAIL_HALF)
	var fill: Color = HudPalette.PLATE
	var box: StyleBoxFlat = get_theme_stylebox(&"panel") as StyleBoxFlat
	if box:
		fill = box.bg_color
	draw_colored_polygon(PackedVector2Array([Vector2(x - TAIL_HALF, 1.0), Vector2(x, -TAIL_HEIGHT),
		Vector2(x + TAIL_HALF, 1.0)]), fill)




## Kutu açıkken kutunun / tabelanın dışına basılırsa kapanır. Olay tüketilmez (dokunuş dünyaya,
## kameraya ya da başka bir düğmeye gitmeye devam eder).
func _input(event: InputEvent) -> void:
	if not visible:
		return
	var at: Vector2
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		at = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		at = (event as InputEventScreenTouch).position
	else:
		return
	if Hud.screen_rect(self).grow(TOUCH_SLOP).has_point(at):   # HUD boyutu ölçeği dahil
		return
	if anchor_button and Hud.screen_rect(anchor_button).grow(TOUCH_SLOP).has_point(at):
		return
	dismissed.emit()


func _sign(node_name: String, icon: HudIcon.Kind, chosen: Signal) -> PlateButton:
	var button: PlateButton = PlateButton.new()
	button.name = node_name
	button.theme_type_variation = &"HudSign"
	button.shape = PlateButton.Shape.ROUND
	button.kind = icon
	button.icon_size = 18.0
	button.custom_minimum_size = Vector2(32, 32)
	button.bolts = false
	button.lift_when_pressed = 0.0
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(chosen.emit)
	_row.add_child(button)
	return button
