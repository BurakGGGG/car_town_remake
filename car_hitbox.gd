extends StaticBody3D

## Şu an seçili aracın kök node'u; tüm hitbox'lar paylaşır. Diğer sistemler buradan okuyabilir.
static var selected_car: Node3D = null
# Tıklama anında seçili olan araç — aynı araca tekrar tıklamayı (seçimi kaldırma) anlamak için.
static var _selected_before_click: Node3D = null
# _unhandled_input her hitbox'ta ayrı çalışır; aynı tıklamayı yalnızca bir kez işlemek için.
static var _last_click: InputEvent = null

## Zemin göstergesi (halka + köşe braketleri). SelectionRing açma/kapama anahtarı olarak kalır.
const INDICATOR_SHADER: Shader = preload("res://vfx/selection_indicator.gdshader")
const INDICATOR_HEIGHT: float = 0.05  # araç lokalinde zeminden yükseklik (z-fighting önlemi)
const INDICATOR_PADDING: float = 1.3  # quad, ayak izinin en uzun kenarının bu katı

@onready var selection_ring: MeshInstance3D = get_parent().get_node("SelectionRing")


func _ready() -> void:
	input_ray_pickable = true
	selection_ring.visible = false
	add_to_group("car_hitboxes")
	_build_ground_indicator()


## Eski torus yerine, SelectionRing'in altına zemine yatık shader'lı bir quad ekler.
## Boyut ve merkez aracın BoxShape3D hitbox'ından alınır; sahne dosyası değişmez.
func _build_ground_indicator() -> void:
	selection_ring.mesh = null  # torus çizilmesin; node görünürlük anahtarı olarak kalıyor

	var footprint: Vector2 = Vector2(0.6, 1.0)
	var ground_center: Vector3 = Vector3.ZERO
	var shape_node: CollisionShape3D = get_node_or_null("CollisionShape3D")
	if shape_node and shape_node.shape is BoxShape3D:
		var box_size: Vector3 = (shape_node.shape as BoxShape3D).size
		footprint = Vector2(box_size.x, box_size.z)
		ground_center = Vector3(shape_node.position.x, 0.0, shape_node.position.z)

	var quad_size: float = maxf(footprint.x, footprint.y) * INDICATOR_PADDING
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(quad_size, quad_size)
	quad.orientation = PlaneMesh.FACE_Y

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = INDICATOR_SHADER
	quad.material = material

	var indicator: MeshInstance3D = MeshInstance3D.new()
	indicator.name = "GroundIndicator"
	indicator.mesh = quad
	indicator.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# SelectionRing araç lokalinde havada (y=0.6); göstergeyi araç orijininin hemen üstüne indir
	indicator.position = ground_center + Vector3(0.0, INDICATOR_HEIGHT, 0.0) - selection_ring.position
	selection_ring.add_child(indicator)


## Bu aracı koddan seçer (araç galerisi vb.). Tıklama akışıyla aynı sonucu üretir:
## diğer halkalar kapanır, bu aracın halkası açılır, selected_car güncellenir.
func select() -> void:
	clear_selection(get_tree())
	selection_ring.visible = true
	selected_car = get_parent()
	print(get_parent().name, " seçildi!")


## Tüm araç seçimlerini kaldırır.
static func clear_selection(tree: SceneTree) -> void:
	selected_car = null
	for car in tree.get_nodes_in_group("car_hitboxes"):
		var ring: MeshInstance3D = car.get_parent().get_node_or_null("SelectionRing")
		if ring:
			ring.visible = false


func _input_event(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var car: Node3D = get_parent()

			# Not: Godot aynı tıklama için önce _unhandled_input'u çalıştırır (bütün halkalar
			# orada kapatıldı), fizik picking sonra gelir. Burada sadece tıklanan araç ele alınır.
			if _selected_before_click == car:
				# Aynı araca tekrar tıklandı → seçim kaldırılmış kalır
				selected_car = null
				print(car.name, " seçimi kaldırıldı")
			else:
				selection_ring.visible = true
				selected_car = car
				print(car.name, " seçildi!")

			# Tıklamayı burada tüket
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			# Aynı tıklama diğer hitbox'larda zaten işlendi
			if event == _last_click:
				return
			_last_click = event
			_selected_before_click = selected_car
			selected_car = null

			# Boş yere tıklanırsa bütün seçimleri kaldır
			# (araca tıklandıysa picking hemen ardından sadece o aracı yeniden seçer)
			for car in get_tree().get_nodes_in_group("car_hitboxes"):
				var ring: MeshInstance3D = car.get_parent().get_node_or_null("SelectionRing")
				if ring:
					ring.visible = false
