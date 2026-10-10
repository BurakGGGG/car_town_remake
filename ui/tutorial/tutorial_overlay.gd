class_name TutorialOverlay
extends Control
## EĞİTİM KATMANI — HUD'un temalı kökünün EN ÜSTÜNDE duran tam ekran katman. Yalnızca görünüm ve
## girdi süzgeci: hangi adımın oynadığına TutorialDirector karar verir.
##
## Parçalar: spot ışığı (spotlight.gdshader: karartma + hedefte yumuşak delik + amber parıltı ve
## yayılan halkalar), dokunmayı gösteren el (TutorialHand), Rıza Usta'nın kartı (CoachCard) ve
## tam ekran ders kartı (ChapterCard).
##
## GİRDİ: katman MOUSE_FILTER_STOP'tur ama _has_point kipine göre cevap verir —
##   engelle (block) : deliğin DIŞI tutulur, deliğin içine dokunuş alttaki düğmeye / dünyaya geçer
##                     (araç seçimi fizik picking ile, düğmeler normal GUI yoluyla çalışır). Bilgi
##                     adımında (pass = false) delik de tutulur: yalnızca gösterir, kartın İLERİ'si ilerletir.
##   serbest         : hiçbir yer tutulmaz; oyun normal oynanır (kart kendi düğmelerini yine alır).
## Hedef deliği her karede yumuşakça izlenir: dünyada hareket eden araç da, açılış animasyonu oynayan
## pano da kayarken delik peşinden gelir.

signal action_pressed
signal skip_pressed
signal chapter_chosen(id: StringName)

const SPOTLIGHT: Shader = preload("res://ui/tutorial/spotlight.gdshader")
const DIM: float = 0.68
const CARD_MARGIN: int = 16
## Delik izleme hızı (büyük = daha sıkı).
const FOLLOW: float = 14.0

var sfx: TutorialSfx
var card: CoachCard
var chapter: ChapterCard

var _shade: ColorRect
var _material: ShaderMaterial
var _hand: TutorialHand
var _card_layer: MarginContainer
var _card_column: VBoxContainer
var _block: bool = false
## Deliğe dokunuş alttakine geçsin mi? Bilgi adımlarında (İLERİ ile geçilen) delik yalnızca vurgular.
var _pass: bool = true
var _has_target: bool = false
var _target: Rect2 = Rect2()
var _hole: Rect2 = Rect2()
var _circle: bool = false
var _dim: float = 0.0
var _glow: float = 0.0
var _dim_tween: Tween
var _card_tween: Tween
var _want_hand: bool = false


func _ready() -> void:
	name = "TutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	sfx = TutorialSfx.new()
	add_child(sfx)

	_shade = ColorRect.new()
	_shade.name = "Spotlight"
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_material = ShaderMaterial.new()
	_material.shader = SPOTLIGHT
	_shade.material = _material
	add_child(_shade)

	_hand = TutorialHand.new()
	_hand.visible = false
	add_child(_hand)

	_card_layer = MarginContainer.new()
	_card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: StringName in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		_card_layer.add_theme_constant_override(side, CARD_MARGIN)
	add_child(_card_layer)
	_card_column = VBoxContainer.new()
	_card_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_layer.add_child(_card_column)
	card = CoachCard.new()
	card.sfx = sfx
	card.visible = false
	card.action_pressed.connect(func() -> void: action_pressed.emit())
	card.skip_pressed.connect(func() -> void: skip_pressed.emit())
	_card_column.add_child(card)

	chapter = ChapterCard.new()
	chapter.sfx = sfx
	chapter.chosen.connect(func(id: StringName) -> void: chapter_chosen.emit(id))
	add_child(chapter)
	set_process(false)


# --- Dış API -------------------------------------------------------------------------

## Katmanı açar (görünür + en üste). Direktör ilk adımdan önce çağırır.
func activate() -> void:
	if not visible:
		show()
		_hole = Rect2(Vector2.ZERO, size)   # ilk delik ekranın tamamı: hedefe doğru "iris" gibi kapanır
	move_to_front()
	set_process(true)


## Her şeyi söndürür ve katmanı kapatır.
func deactivate() -> void:
	hide_card()
	_set_dim(0.0)
	_has_target = false
	_hand.visible = false
	_block = false
	var tween: Tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_callback(func() -> void:
		if not card.visible and not chapter.visible and _dim <= 0.01:
			hide()
			set_process(false))


## Adımın görünümü: dim (karartma), block (deliğin dışını tut), hand (el göster), pass (delik
## dokunuşu alttakine geçirsin).
func set_mode(dim: bool, block: bool, hand: bool, pass_through: bool = true) -> void:
	_block = block
	_pass = pass_through
	_want_hand = hand
	_set_dim(DIM if dim else 0.0)


## Hedef dikdörtgen (katmanın kendi koordinatlarında). Boş Rect2 = hedef yok (delik kapanır).
func set_target(rect: Rect2, circle: bool) -> void:
	_circle = circle
	if rect.size == Vector2.ZERO:
		if _has_target:
			_has_target = false
		return
	if not _has_target:
		_has_target = true
		if _hole.size == Vector2.ZERO:
			_hole = rect.grow(220.0)
	_target = rect


func show_card(chip: String, title: String, body: String, action: String, index: int, count: int, place: StringName) -> void:
	place_card(place)
	card.visible = true
	card.present(chip, title, body, action, index, count)
	if sfx:
		sfx.play(&"pop")
	if _card_tween:
		_card_tween.kill()
	card.modulate.a = 0.0
	await get_tree().process_frame   # boyut kesinleşsin: pivot ortada olsun
	if not card.visible:
		return
	# Kap konumu yönetir (kart kaba bırakılır); giriş yalnızca ölçek + saydamlıkla oynar
	card.pivot_offset = Vector2(card.size.x * 0.5, card.size.y if place != &"top" else 0.0)
	card.scale = Vector2.ONE * 0.9
	_card_tween = create_tween().set_parallel(true)
	_card_tween.tween_property(card, "modulate:a", 1.0, 0.16)
	_card_tween.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Kartın dikey yeri: &"top" · &"center" · &"bottom".
func place_card(place: StringName) -> void:
	match place:
		&"top":
			_card_column.alignment = BoxContainer.ALIGNMENT_BEGIN
		&"center":
			_card_column.alignment = BoxContainer.ALIGNMENT_CENTER
		_:
			_card_column.alignment = BoxContainer.ALIGNMENT_END


func hide_card() -> void:
	if not card.visible:
		return
	if _card_tween:
		_card_tween.kill()
	_card_tween = create_tween()
	_card_tween.tween_property(card, "modulate:a", 0.0, 0.12)
	_card_tween.tween_callback(func() -> void: card.visible = false)


func show_chapter(info: Dictionary) -> void:
	activate()
	hide_card()
	_hand.visible = false
	chapter.show_intro(info)


func show_complete(title: String) -> void:
	activate()
	hide_card()
	_hand.visible = false
	_has_target = false
	chapter.show_complete(title)


func chapter_open() -> bool:
	return chapter.visible


# --- Kare ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	var k: float = 1.0 - exp(-FOLLOW * delta)
	var goal: Rect2 = _target if _has_target else Rect2(_hole.get_center(), Vector2.ZERO)
	_hole = Rect2(_hole.position.lerp(goal.position, k), _hole.size.lerp(goal.size, k))
	var glow_goal: float = 1.0 if _has_target and not chapter.visible else 0.0
	_glow = lerpf(_glow, glow_goal, k)
	_material.set_shader_parameter(&"rect_size", size)
	_material.set_shader_parameter(&"hole", Vector4(_hole.position.x, _hole.position.y, _hole.size.x, _hole.size.y))
	_material.set_shader_parameter(&"has_hole", 1.0 if _hole.size.x > 2.0 else 0.0)
	_material.set_shader_parameter(&"corner", minf(_hole.size.x, _hole.size.y) * 0.5 if _circle else 16.0)
	_material.set_shader_parameter(&"dim", _dim)
	_material.set_shader_parameter(&"glow", _glow)
	var hand_on: bool = _want_hand and _has_target and not chapter.visible
	if hand_on:
		_hand.position = _hand_point(_target)
	if hand_on != _hand.visible:
		_hand.visible = hand_on


## Parmak ucu: düğmede ortanın biraz sağ altı (yazıyı kapatmaz), yuvarlak hedefte (dünya) merkez.
func _hand_point(rect: Rect2) -> Vector2:
	if _circle:
		return rect.get_center() + Vector2(rect.size.x * 0.12, rect.size.y * 0.12)
	return rect.get_center() + Vector2(minf(rect.size.x * 0.22, 40.0), minf(rect.size.y * 0.22, 14.0))


func _set_dim(value: float) -> void:
	if _dim_tween:
		_dim_tween.kill()
	_dim_tween = create_tween()
	_dim_tween.tween_property(self, "_dim", value, 0.25)


## Engelleme: deliğin içi (biraz payla) alttakine geçer, dışı tutulur. Serbest kipte hiçbir yer.
func _has_point(point: Vector2) -> bool:
	if chapter.visible:
		return true
	if not _block:
		return false
	if _has_target and _pass:
		return not _target.grow(4.0).has_point(point)
	return true
