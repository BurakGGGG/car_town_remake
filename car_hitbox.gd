extends StaticBody3D

@onready var selection_ring = get_parent().get_node("SelectionRing")


func _ready():
	input_ray_pickable = true
	selection_ring.visible = false
	add_to_group("car_hitboxes")


func _input_event(camera, event, position, normal, shape_idx):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			
			# Önce bütün arabaların halkasını kapat
			for car in get_tree().get_nodes_in_group("car_hitboxes"):
				var ring = car.get_parent().get_node_or_null("SelectionRing")
				if ring:
					ring.visible = false

			# Sonra sadece tıklanan arabayı seç
			selection_ring.visible = true

			print(get_parent().name, " seçildi!")

			# Tıklamayı burada tüket
			get_viewport().set_input_as_handled()


func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			
			# Boş yere tıklanırsa bütün seçimleri kaldır
			for car in get_tree().get_nodes_in_group("car_hitboxes"):
				var ring = car.get_parent().get_node_or_null("SelectionRing")
				if ring:
					ring.visible = false
