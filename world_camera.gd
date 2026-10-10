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

## Dünyadaki kameraya dönük plakaların görüntü katmanı: araç balonları (🔧 / ₺ / 🏁) ve kilitli
## tamir alanının fiyat plakası. Garaj düzenlenirken kamera bu katmanı göstermez — telefonda
## denendi: yarış rakibinin balonu ve tamirdeki aracın plakası eşyaların önünü kapatıyordu.
## Balonların görünürlüğünü (visible) araç mantığı kullandığı için onlara dokunulmaz, katman gizlenir.
const LAYER_WORLD_UI: int = 1 << 1

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
		var before: Vector2 = _touch_midpoint()
		_touches[sd.index] = sd.position
		if _touches.size() == 2 and _pinch_start_dist > 1.0:
			# Parmaklar açılınca yaklaş (size küçülür), kapanınca uzaklaş
			_target_size = clampf(_pinch_start_size * (_pinch_start_dist / maxf(_touch_distance(), 1.0)), min_zoom, _max_zoom_fit())
			# İki parmağın ortası kayınca görüntü de kayar: tek parmağın zemine boya / duvar çizdiği
			# düzenleme araçlarında kamera iki parmakla gezdirilir (sürükleme bir parmağın yarısı kadar).
			pan_by_pixels((_touch_midpoint() - before))
			get_viewport().set_input_as_handled()


## Verilen kutuyu (ör. garajın zemini + duvar yüksekliği) ekranın dikey [top, bottom] oranları
## arasına ve yatayda kenar payları içine SIĞDIRACAK şekilde yumuşakça odaklanır. Önceki görünümü
## döndürür (restore_view ile geri alınır). Garaj düzenleyicisi kullanır: alt paletin üstünde
## kalan alana garajın tamamı sığsın.
## `closest` > 0: bu sahneye özel, oyuncunun yakınlaşma sınırından (min_zoom) DAHA yakın çekim (kasa
## açılışı gibi sinematik anlar). Oyuncunun parmakla yakınlaşma sınırı değişmez; restore_view geri döner.
func frame_box(box: AABB, top: float = 0.14, bottom: float = 0.64, side: float = 0.05,
		closest: float = 0.0) -> Dictionary:
	var before: Dictionary = {"focus": _focus, "size": _target_size}
	var right: Vector3 = global_transform.basis.x
	var up: Vector3 = global_transform.basis.y
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)
	for i: int in 8:
		var p: Vector3 = box.position + Vector3(box.size.x if (i & 1) else 0.0,
			box.size.y if (i & 2) else 0.0, box.size.z if (i & 4) else 0.0)
		var s: Vector2 = Vector2(p.dot(right), p.dot(up))
		lo = lo.min(s)
		hi = hi.max(s)
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var aspect: float = screen.x / maxf(screen.y, 1.0)
	var needed: float = maxf((hi.y - lo.y) / maxf(bottom - top, 0.1),
		(hi.x - lo.x) / maxf((1.0 - side * 2.0) * aspect, 0.1))
	var nearest: float = closest if closest > 0.0 else min_zoom
	var final_size: float = clampf(needed, nearest, _max_zoom_fit())
	# Kutunun merkezi ekranda [top, bottom] aralığının ortasına düşsün: odağı zemin üzerinde
	# kaydırıp kutunun ekrandaki yerini ölç, farkı pan_by_pixels ile kapat (aynı dönüşümle).
	var keep_size: float = size
	var keep_focus: Vector3 = _focus
	size = final_size
	_focus = Vector3(box.get_center().x, 0.0, box.get_center().z)
	_apply_focus()
	var target: Vector2 = Vector2(screen.x * 0.5, screen.y * (top + bottom) * 0.5)
	pan_by_pixels(target - unproject_position(box.get_center()))
	var final_focus: Vector3 = _focus
	size = keep_size
	_focus = keep_focus
	_apply_focus()
	_glide_to(final_focus, final_size, nearest)
	return before


## Dünya plakaları (LAYER_WORLD_UI) görünsün mü?
func set_world_ui_visible(on: bool) -> void:
	cull_mask = (cull_mask | LAYER_WORLD_UI) if on else (cull_mask & ~LAYER_WORLD_UI)


## frame_box'tan önceki görünüme döner.
func restore_view(state: Dictionary) -> void:
	if state.has("focus") and state.has("size"):
		_glide_to(state["focus"], float(state["size"]))


var _glide: Tween


func _glide_to(focus: Vector3, zoom: float, nearest: float = 0.0) -> void:
	if _glide:
		_glide.kill()
	_target_size = clampf(zoom, nearest if nearest > 0.0 else min_zoom, max_zoom)
	_glide = create_tween()
	_glide.tween_method(func(f: Vector3) -> void:
		_focus = f
		_apply_focus(), _focus, focus, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


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


func _touch_midpoint() -> Vector2:
	var positions: Array = _touches.values()
	return ((positions[0] as Vector2) + (positions[1] as Vector2)) * 0.5 if positions.size() >= 2 else Vector2.ZERO


func _touch_distance() -> float:
	var positions: Array = _touches.values()
	return (positions[0] as Vector2).distance_to(positions[1]) if positions.size() >= 2 else 0.0
