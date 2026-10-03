class_name TouchScroll
extends Node
## DOKUNMATİK KAYDIRMA: bir ScrollContainer'ın çocuğu olarak eklenir (TouchScroll.attach).
##  - Kaydırma çubuğu görünmez (SHOW_NEVER: kaydırma sürer, çubuk çizilmez).
##  - Parmak bırakılınca içerik ATALETLE akar (yavaşlayarak durur); kenarda hemen durur.
##  - snap açıksa (yatay seçim şeridi) bırakınca en yakın kartın başına KAYARAK oturur.
##  - Kaptaki düğmeler MOUSE_FILTER_PASS yapılır: STOP olan kart parmak sürüklemesini yutar ve şerit
##    kaymaz (ölçüldü). Kaydırma başlayınca kap kartın basışını kendisi iptal eder.
## Kare başına iş yalnızca parmak basılıyken ya da içerik akarken yapılır (_process kapalı bekler).

## Akış yavaşlama katsayısı (1/sn): büyük = çabuk durur.
const DECAY: float = 4.5
## Bu hızın (birim/sn) altında akış biter.
const MIN_SPEED: float = 24.0
## Dokunuş sürükleme sayılmadan önce gidilmesi gereken mesafe (tuval birimi).
const DEADZONE: int = 10
const SNAP_TIME: float = 0.26

var snap: bool = false

var _scroll: ScrollContainer
var _horizontal: bool = false
var _pressed: bool = false
var _coasting: bool = false
var _vel: float = 0.0
var _pos: float = 0.0
var _last: float = 0.0
var _tween: Tween


## `scroll`'a dokunmatik kaydırma ekler (yatay mı dikey mi kabın açık eksenine göre belli olur).
static func attach(scroll: ScrollContainer, snap_to_cards: bool = false) -> TouchScroll:
	var driver: TouchScroll = TouchScroll.new()
	driver.name = "TouchScroll"
	driver.snap = snap_to_cards
	scroll.add_child(driver)
	return driver


func _ready() -> void:
	_scroll = get_parent() as ScrollContainer
	if _scroll == null:
		return
	_horizontal = _scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
	if _horizontal:
		_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if _scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_scroll.scroll_deadzone = DEADZONE
	_scroll.gui_input.connect(_on_gui_input)
	for button: Node in _scroll.find_children("*", "BaseButton", true, false):
		_pass(button)
	get_tree().node_added.connect(_on_node_added)   # sonradan kurulan kartlar da (liste yenilenince)
	set_process(false)


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is BaseButton and _scroll and _scroll.is_ancestor_of(node):
		_pass(node)


static func _pass(node: Node) -> void:
	var control: Control = node as Control
	if control and control.mouse_filter == Control.MOUSE_FILTER_STOP:
		control.mouse_filter = Control.MOUSE_FILTER_PASS


func _value() -> float:
	return float(_scroll.scroll_horizontal if _horizontal else _scroll.scroll_vertical)


func _set_value(v: float) -> void:
	if _horizontal:
		_scroll.scroll_horizontal = roundi(v)
	else:
		_scroll.scroll_vertical = roundi(v)


func _max_value() -> float:
	var bar: ScrollBar = _scroll.get_h_scroll_bar() if _horizontal else _scroll.get_v_scroll_bar()
	return maxf(bar.max_value - bar.page, 0.0)


func _on_gui_input(event: InputEvent) -> void:
	var down: bool = false
	var up: bool = false
	if event is InputEventScreenTouch:
		down = (event as InputEventScreenTouch).pressed
		up = not down
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		down = (event as InputEventMouseButton).pressed
		up = not down
	if down:
		_stop_motion()
		_pressed = true
		_vel = 0.0
		_last = _value()
		set_process(true)
	elif up and _pressed:
		_pressed = false
		_release()


func _stop_motion() -> void:
	_coasting = false
	if _tween:
		_tween.kill()
		_tween = null


func _release() -> void:
	if snap:
		_snap_to_card(_value() + _vel * 0.18)
		set_process(false)
		return
	_pos = _value()
	_coasting = absf(_vel) > MIN_SPEED
	set_process(_coasting)


func _process(delta: float) -> void:
	if _scroll == null or delta <= 0.0:
		return
	if _pressed:
		var now: float = _value()
		_vel = lerpf(_vel, (now - _last) / delta, 0.5)
		_last = now
		return
	if not _coasting:
		set_process(false)
		return
	var max_v: float = _max_value()
	_pos = clampf(_pos + _vel * delta, 0.0, max_v)
	_set_value(_pos)
	_vel *= exp(-DECAY * delta)
	if absf(_vel) < MIN_SPEED or _pos <= 0.0 or _pos >= max_v:
		_coasting = false
		set_process(false)


## Bırakılan yerden (hız payıyla) en yakın kartın başına kayar.
func _snap_to_card(target: float) -> void:
	var content: Node = null
	for child: Node in _scroll.get_children():
		if child is Control:
			content = child
			break
	var best: float = clampf(target, 0.0, _max_value())
	var best_d: float = INF
	if content:
		for child: Node in content.get_children():
			var card: Control = child as Control
			if card == null or not card.visible:
				continue
			var at: float = card.position.x if _horizontal else card.position.y   # kartın içerik içindeki başı
			var d: float = absf(at - target)
			if d < best_d:
				best_d = d
				best = clampf(at, 0.0, _max_value())
	if _tween:
		_tween.kill()
	_tween = create_tween()
	var prop: String = "scroll_horizontal" if _horizontal else "scroll_vertical"
	_tween.tween_property(_scroll, prop, int(best), SNAP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
