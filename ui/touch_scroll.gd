class_name TouchScroll
extends Node
## DOKUNMATİK KAYDIRMA: bir ScrollContainer'ın çocuğu olarak eklenir (TouchScroll.attach).
##  - Kaydırma çubuğu görünmez (SHOW_NEVER: kaydırma sürer, çubuk çizilmez).
##  - Parmak bırakılınca içerik ATALETLE akar (yavaşlayarak durur); kenarda hemen durur.
##  - snap açıksa (yatay seçim şeridi) bırakınca en yakın kartın başına KAYARAK oturur.
##  - TUT-ÇEK her yerde: telefonda parmak (kabın kendi sürüklemesi), masaüstünde fare sol tuşu (burada);
##    tekerlek yalnızca ek kolaylıktır. Öncelik mobil: dokunmadan türetilen fare olayları yok sayılır.
##  - Kaptaki STOP öğeler (düğmeler VE plakalar / paneller) MOUSE_FILTER_PASS yapılır: STOP olan öğe parmak
##    sürüklemesini yutar ve liste kaymaz (ölçüldü: görev plakaları PanelContainer'dı, liste telefonda da
##    kaymıyordu). Düğme PASS iken de basılır; kaydırma başlayınca kap basışı kendisi iptal eder.
##  - PARMAK SÜRÜKLEMESİ KABIN KENDİSİNE BAĞLI DEĞİL: telefonda kasa / kart düğmesinin üstünden başlayan
##    kaydırma kaymıyordu (yalnızca düğmeler arası boşlukta kayıyordu; kullanıcı bildirdi). Godot'nun
##    düğmeden kaba olay aktarımına güvenmek yerine: parmağın BU kaba indiğini, dokunulan öğenin kendi
##    `gui_input` sinyali söyler (Godot'nun isabet testi: üstte açık pencere varsa kap sahiplenmez);
##    hareket `_input`'ta, arayüz yönlendirmesinden ÖNCE izlenir. Kabın yerleşik sürüklemesi de
##    çalışırsa aynı değeri (başlangıç − toplam hareket) yazar, çakışmaz.
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
## Fareyle tut-çek durumu.
var _mouse_down: bool = false
var _mouse_dragging: bool = false
var _mouse_origin: Vector2 = Vector2.ZERO
var _mouse_start: float = 0.0
## Parmakla sürükleme durumu (dokunma indeksi, toplam hareket, başlangıç değeri).
var _touch_index: int = -1
var _touch_accum: float = 0.0
var _touch_start: float = 0.0
var _touch_dragging: bool = false


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
	_watch(_scroll)
	for control: Node in _scroll.find_children("*", "Control", true, false):
		_pass(control)
		_watch(control)
	get_tree().node_added.connect(_on_node_added)   # sonradan kurulan kartlar da (liste yenilenince)
	set_process(false)


func _exit_tree() -> void:
	if get_tree() and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is Control and _scroll and _scroll.is_ancestor_of(node):
		_pass(node)
		_watch(node)


## Kaptaki her öğenin dokunuşu (öğe olayı kaba aktarmasa da) parmağın bu kaba indiğini bildirir.
func _watch(node: Node) -> void:
	var control: Control = node as Control
	if control and not control.gui_input.is_connected(_on_touch_landed):
		control.gui_input.connect(_on_touch_landed)


## Parmak bu kabın bir öğesine indi: gerçek dokunuş (ScreenTouch) ya da ondan türetilen fare basışı.
## Aynı basış öğeden kaba doğru birkaç kez gelebilir (aktarım): tekrarlar yok sayılır.
func _on_touch_landed(event: InputEvent) -> void:
	var index: int = -1
	if event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		index = (event as InputEventScreenTouch).index
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION \
			and (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		index = 0   # türetilmiş fare: ilk parmak
	else:
		return
	if _touch_index == index:
		return
	if _touch_index >= 0 and index != 0:
		return   # ikinci parmak: ilk sürükleme sürer
	_touch_index = index
	_touch_accum = 0.0
	_touch_start = _value()
	_touch_dragging = false
	_press()


## Parmak kalktı: gerçek bırakış ya da ondan türetilen fare bırakışı (hangisi önce gelirse; ikisi
## de gelmezse durum asılı kalır ve sonraki dokunuş yok sayılırdı).
func _is_touch_release(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event as InputEventScreenTouch
		return not touch.pressed and touch.index == _touch_index
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		var button: InputEventMouseButton = event as InputEventMouseButton
		return not button.pressed and button.button_index == MOUSE_BUTTON_LEFT and _touch_index == 0
	return false


## Parmak hareketi ARAYÜZDEN ÖNCE: altta düğme, panel ya da başka bir öğe olması fark etmez.
func _input(event: InputEvent) -> void:
	if _touch_index < 0:
		return
	if event is InputEventScreenDrag and (event as InputEventScreenDrag).index == _touch_index:
		var relative: Vector2 = (event as InputEventScreenDrag).relative
		_touch_accum += relative.x if _horizontal else relative.y
		if not _touch_dragging and absf(_touch_accum) > DEADZONE:
			_touch_dragging = true
			_stop_motion()
			# Kaptaki düğmeler basışı bıraksın: parmak kalkınca kasa / kart "basıldı" sayılmaz
			_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _touch_dragging:
			_set_value(clampf(_touch_start - _touch_accum, 0.0, _max_value()))
	elif _is_touch_release(event):
		_touch_index = -1
		_touch_dragging = false
		_release_press()


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
	# 1) GERÇEK FARE: tut-çek (masaüstü / editörde deneme). Kabın kendisi fareyle sürüklemez (yalnızca
	#    tekerlek); burada parmak gibi davranır. Dokunmadan türetilen fare olayları (DEVICE_ID_EMULATION)
	#    yok sayılır: telefonda parmak sürüklemesini kabın kendisi işler, ikisi birden çift kaydırırdı.
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		if event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		if (event as InputEventMouseButton).pressed:
			_mouse_down = true
			_mouse_dragging = false
			_mouse_origin = (event as InputEventMouseButton).global_position
			_mouse_start = _value()
			_press()
		elif _mouse_down:
			_mouse_down = false
			if _mouse_dragging:
				_scroll.accept_event()   # sürükleme bitti: altındaki kart "basıldı" sayılmasın
			_mouse_dragging = false
			_release_press()
		return
	if event is InputEventMouseMotion:
		if not _mouse_down or event.device == InputEvent.DEVICE_ID_EMULATION:
			return
		var delta: Vector2 = (event as InputEventMouseMotion).global_position - _mouse_origin
		var along: float = delta.x if _horizontal else delta.y
		if not _mouse_dragging and absf(along) > DEADZONE:
			_mouse_dragging = true
			# Kaptaki düğmeler basışı bıraksın (parmakla kaydırmada kabın yaptığı gibi)
			_scroll.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		if _mouse_dragging:
			_set_value(clampf(_mouse_start - along, 0.0, _max_value()))
			_scroll.accept_event()
		return
	# 2) PARMAK: basış öğelerin gui_input sinyalinden (_on_touch_landed), hareket ve bırakış _input'tan.


func _press() -> void:
	_stop_motion()
	_pressed = true
	_vel = 0.0
	_last = _value()
	set_process(true)


func _release_press() -> void:
	if not _pressed:
		return
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
	_last = _pos
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
	# Kabın yerleşik ataleti de akıtıyorsa (değeri biz yazmadan değişti) çekilinir: iki atalet
	# aynı anda farklı değer yazıp içeriği titretmesin.
	if absf(_value() - _last) > 1.0:
		_coasting = false
		set_process(false)
		return
	var max_v: float = _max_value()
	_pos = clampf(_pos + _vel * delta, 0.0, max_v)
	_set_value(_pos)
	_last = _value()
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
