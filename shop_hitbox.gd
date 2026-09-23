extends StaticBody3D
## Haritadaki "CAR PARTS & SHOWROOM" binasının tıklama kutusu: binaya tıklanınca ARABA GALERİSİ
## (ShowroomScreen) açılır. Araç satın almanın tek girişi burasıdır.
##
## Mevcut 3D seçim akışıyla aynı yolu kullanır (StaticBody3D + input_ray_pickable + _input_event,
## car_hitbox.gd ile aynı), yani araçların önünde/arkasında olmasına göre doğru sırayla seçilir.
## Kamerayı sürüklemek showroom'u açmaz: basış ve bırakış aynı noktadaysa tıklama sayılır.
## Ekranı kendisi bulur ("showroom" grubu); HUD ile doğrudan bağı yoktur.

## Tıklama sayılan en büyük parmak/fare kayması (piksel).
const CLICK_SLOP: float = 14.0

var _press_pos: Vector2 = Vector2.ZERO
var _pressed: bool = false


func _ready() -> void:
	input_ray_pickable = true
	add_to_group("shop_hitboxes")


func _input_event(_camera: Camera3D, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if mb.pressed:
		_press_pos = mb.position
		_pressed = true
		return
	if not _pressed:
		return
	_pressed = false
	if mb.position.distance_to(_press_pos) > CLICK_SLOP:
		return   # kamera sürüklendi, tıklama değil
	var showroom: Node = get_tree().get_first_node_in_group("showroom")
	if showroom == null:
		push_warning("ShopHitbox: sahnede showroom ekranı yok")
		return
	showroom.call(&"open")
	get_viewport().set_input_as_handled()
