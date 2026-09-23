class_name WorldCamera
extends Camera3D
## Dünya kamerası: sınırlı pan + yumuşak zoom. Açı ve yükseklik sabittir (ortografik izometrik);
## pan, kameranın zemine baktığı odak noktasını X/Z'de kaydırır, zoom `size`'ı değiştirir.
## Dünya dışı hiç görünmez: ekranın dört köşesinin zemindeki izdüşümü world_min..world_max içinde
## tutulur (pan buna göre sınırlanır) ve dünya ekrana sığmayacak kadar uzaklaşılamaz. Köşeler her
## seferinde kameranın gerçek ışınlarından hesaplanır; ekran oranı / döndürme değişse de doğru kalır.
## Girdi _unhandled_input ile alınır: HUD/garaj Control'leri tüketirse kamera hiç görmez
## (garaj açıkken tam ekran STOP → kamera otomatik devre dışı). Sol tık basışı işlenmez, böylece
## car_hitbox seçimi aynen çalışır; yalnızca eşik üstü sürükleme pan olur.
## Mobil: tek parmak sürükleme (fare emülasyonu) → pan, iki parmak pinch → zoom.

@export_group("Dünya Sınırları (zemin X/Z — ekranın hiçbir köşesi dışarı taşmaz)")
## GrassArea (20×20, merkez -0.954 / 0.648) biraz içeriden.
@export var world_min: Vector2 = Vector2(-10.8, -9.2)
@export var world_max: Vector2 = Vector2(8.9, 10.5)
@export_group("Zoom (ortografik size)")
## Açılıştaki zoom (sahnedeki size yerine).
@export var start_zoom: float = 3.2
@export var min_zoom: float = 2.2
## Üst sınır; dünya ekrana sığmıyorsa daha da düşer.
@export var max_zoom: float = 5.0
@export var zoom_speed: float = 0.4       # tekerlek adımı başına size değişimi
@export var zoom_smoothing: float = 10.0  # büyük = daha hızlı yaklaşır
@export_group("Pan")
@export var pan_speed: float = 1.0
@export var drag_threshold_px: float = 6.0

var _focus: Vector3            # kameranın baktığı zemin noktası
var _offset: Vector3           # kamera konumu - odak (sabit)
var _target_size: float
var _press_pos: Vector2
var _dragging: bool = false
var _touches: Dictionary = {}  # index → ekran konumu
var _pinch_start_dist: float = 0.0
var _pinch_start_size: float = 0.0


func _ready() -> void:
	var dir: Vector3 = -global_transform.basis.z
	var t: float = global_position.y / maxf(-dir.y, 0.001)
	_focus = global_position + dir * t
	_focus.y = 0.0
	_offset = global_position - _focus
	size = start_zoom
	_target_size = start_zoom
	get_viewport().size_changed.connect(_on_viewport_resized)
	_apply_focus.call_deferred()   # viewport boyutu kesinleşince
	var hud: Node = get_node_or_null("%HUD")
	if hud and hud.has_signal("camera_zoom_requested"):
		hud.camera_zoom_requested.connect(func(direction: int) -> void: zoom_by(-direction * zoom_speed * 2.0))


func _process(delta: float) -> void:
	if not is_equal_approx(size, _target_size):
		size = lerpf(size, _target_size, 1.0 - exp(-zoom_smoothing * delta))
		if absf(size - _target_size) < 0.002:
			size = _target_size
		_apply_focus()   # uzaklaşırken kenar dışarı taşmasın


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_press_pos = mb.position
				_dragging = false
			else:
				_dragging = false
			return  # basış/bırakış tüketilmez: araç seçimi (car_hitbox) çalışmaya devam eder
		if mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(-zoom_speed)
			get_viewport().set_input_as_handled()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(zoom_speed)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		if mm.button_mask & MOUSE_BUTTON_MASK_LEFT and _touches.size() < 2:
			if not _dragging and mm.position.distance_to(_press_pos) > drag_threshold_px:
				_dragging = true
			if _dragging:
				pan_by_pixels(mm.relative)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		if _touches.size() == 2:
			_pinch_start_dist = _touch_distance()
			_pinch_start_size = _target_size
	elif event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() == 2 and _pinch_start_dist > 1.0:
			# Parmaklar açılınca yaklaş (size küçülür), kapanınca uzaklaş
			_target_size = clampf(_pinch_start_size * (_pinch_start_dist / maxf(_touch_distance(), 1.0)), min_zoom, _max_zoom_fit())
			get_viewport().set_input_as_handled()


## Ekran pikseli cinsinden sürükleme → odak noktası zeminde kayar (sınırlar içinde).
func pan_by_pixels(relative: Vector2) -> void:
	var unit: float = size / maxf(get_viewport().get_visible_rect().size.y, 1.0) * pan_speed
	var right: Vector3 = global_transform.basis.x
	right.y = 0.0
	right = right.normalized()
	var forward_flat: Vector3 = -global_transform.basis.z
	forward_flat.y = 0.0
	forward_flat = forward_flat.normalized()
	var pitch_factor: float = maxf(global_transform.basis.y.dot(forward_flat), 0.05)
	_focus -= right * (relative.x * unit)
	_focus += forward_flat * (relative.y * unit / pitch_factor)
	_apply_focus()


func zoom_by(amount: float) -> void:
	_target_size = clampf(_target_size + amount, min_zoom, _max_zoom_fit())


## Odak, görünen zemin alanı dünyanın içinde kalacak şekilde sınırlanır; alan dünyadan genişse ortalanır.
func _apply_focus() -> void:
	global_position = _focus + _offset
	var view: Rect2 = _view_on_ground()
	var lo: Vector2 = world_min - view.position
	var hi: Vector2 = world_max - view.end
	_focus.x = clampf(_focus.x, lo.x, hi.x) if lo.x <= hi.x else (lo.x + hi.x) * 0.5
	_focus.z = clampf(_focus.z, lo.y, hi.y) if lo.y <= hi.y else (lo.y + hi.y) * 0.5
	_focus.y = 0.0
	global_position = _focus + _offset


## Ekranın dört köşesinin zemindeki (y = 0) izdüşümünü kapsayan dikdörtgen, odağa göre (X, Z).
func _view_on_ground() -> Rect2:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var rect: Rect2 = Rect2()
	var first: bool = true
	for corner: Vector2 in [Vector2.ZERO, Vector2(screen.x, 0.0), Vector2(0.0, screen.y), screen]:
		var origin: Vector3 = project_ray_origin(corner)
		var normal: Vector3 = project_ray_normal(corner)
		var hit: Vector3 = origin + normal * (-origin.y / minf(normal.y, -0.001))
		var point: Vector2 = Vector2(hit.x - _focus.x, hit.z - _focus.z)
		if first:
			rect = Rect2(point, Vector2.ZERO)
			first = false
		else:
			rect = rect.expand(point)
	return rect


## Dünyanın ekrana sığdığı en büyük zoom (görünen alan size ile doğrusal büyür).
func _max_zoom_fit() -> float:
	var view: Rect2 = _view_on_ground()
	var world: Vector2 = world_max - world_min
	if view.size.x <= 0.001 or view.size.y <= 0.001:
		return max_zoom
	var fit: float = size * minf(world.x / view.size.x, world.y / view.size.y)
	return clampf(fit, min_zoom, max_zoom)


func _on_viewport_resized() -> void:
	_target_size = clampf(_target_size, min_zoom, _max_zoom_fit())
	_apply_focus()


func _touch_distance() -> float:
	var positions: Array = _touches.values()
	return (positions[0] as Vector2).distance_to(positions[1]) if positions.size() >= 2 else 0.0
