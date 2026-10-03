class_name GarageFocus
extends CanvasLayer
## GARAJ DÜZENLEME ODAĞI — düzenlerken garajın DIŞI bulanıklaşır, soluklaşır ve kararır; garaj ve
## içindeki eşyalar net kalır (vfx/garage_focus.gdshader). Telefonda denendi: düzenleme ekranında
## yol, trafik, mağaza binası ve rakip araç garaj kadar göze batıyordu.
##
## Dış çizgi: garaj zemininin (duvarlar dahil) ve en uzun eşyanın boyundaki kutunun ekrandaki
## izdüşümünün dışbükey zarfı. Kamera kaydırılıp yakınlaştırıldıkça her kare yeniden hesaplanır,
## odak garajı izler. Dünya (3B) ile HUD (katman 10) arasında çizilir: düzenleme plakaları etkilenmez.
## Kapalıyken çizilmez — ekran kopyası ve bulanıklık yalnızca düzenleme modunda maliyet.

const SHADER: Shader = preload("res://vfx/garage_focus.gdshader")
## Dünya ile HUD (10) arası.
const LAYER: int = 5
const FADE_TIME: float = 0.35
## Duvarların dış yüzü de net kalsın: zemin dikdörtgeninin sol kenarına eklenen pay (sol duvar zemin
## kenarında ±0,025 kalın; arka duvar zeminin İÇİNE doğru 0,05 kalın, dış yüzü zaten kenarda).
## Fazlası duvarın arkasındaki çimeni net bırakıp garajın çevresinde parlak yeşil bir şerit
## çıkarıyordu (telefon oranında görüldü).
const LEFT_WALL_PAD: float = 0.025
const MAX_HULL: int = 8

var _rect: ColorRect
var _material: ShaderMaterial
var _view: GarageDecorView
var _strength: float = 0.0
var _tween: Tween


func _ready() -> void:
	name = "GarageFocus"
	layer = LAYER
	visible = false
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_rect = ColorRect.new()
	_rect.name = "Dim"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rect.material = _material
	add_child(_rect)
	set_process(false)


## Odağı açar (yumuşak geçişle).
func show_focus(view: GarageDecorView) -> void:
	_view = view
	visible = true
	set_process(true)
	_update_hull()
	_fade_to(1.0)


## Odağı kapatır; geçiş bitince katman gizlenir ve kare başı iş durur.
func hide_focus() -> void:
	if not visible:
		return
	_fade_to(0.0)


func strength() -> float:
	return _strength


## Anlık odak gücü (0–1). Testler efektin etkisini aynı karede ölçmek için de kullanır.
func set_strength(value: float) -> void:
	_strength = value
	_material.set_shader_parameter(&"strength", value)


func _fade_to(target: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(set_strength, _strength, target, FADE_TIME) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if target <= 0.0:
		_tween.tween_callback(func() -> void:
			visible = false
			set_process(false))


func _process(_delta: float) -> void:
	_update_hull()


## Garaj kutusunun 8 köşesini ekrana izdüşürür, zarfı shader'a verir.
func _update_hull() -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null or _view == null:
		return
	var lot: Rect2 = _view.lot_rect().grow_individual(LEFT_WALL_PAD, 0.0, 0.0, 0.0)
	var top: float = _view.content_top()
	var points: PackedVector2Array = PackedVector2Array()
	for x: float in [lot.position.x, lot.end.x]:
		for z: float in [lot.position.y, lot.end.y]:
			for y: float in [0.0, top]:
				points.append(camera.unproject_position(Vector3(x, y, z)))
	var hull: PackedVector2Array = Geometry2D.convex_hull(points)
	if hull.size() > 1 and hull[0].is_equal_approx(hull[hull.size() - 1]):
		hull.remove_at(hull.size() - 1)   # zarfın son noktası ilkinin tekrarı
	if hull.size() >= 3:
		# Shader kenar normalini (e.y, -e.x) DIŞARI bakar sayar: içe bakıyorsa sırayı çevir.
		var center: Vector2 = Vector2.ZERO
		for point: Vector2 in hull:
			center += point
		center /= float(hull.size())
		var edge: Vector2 = hull[1] - hull[0]
		if Vector2(edge.y, -edge.x).dot(center - hull[0]) > 0.0:
			hull.reverse()
	var count: int = mini(hull.size(), MAX_HULL)
	hull.resize(MAX_HULL)
	_material.set_shader_parameter(&"hull", hull)
	_material.set_shader_parameter(&"hull_count", count)
	_material.set_shader_parameter(&"screen_size", get_viewport().get_visible_rect().size)
