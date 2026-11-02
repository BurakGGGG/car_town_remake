extends SceneTree
## MOTOR SES LABORATUVARI'nı açar (oyunu değil). Pencere 1600×960 (ekrana sığdırılır), ölçekleme kapalı (oyunun mobil tuval ayarı
## laboratuvara uygulanmaz). Ayrıntı: tools/engine_lab/engine_lab_ui.gd.
##   tools/engine_lab.sh   ya da   godot-4 --path . -s res://tools/engine_lab/engine_lab.gd

const LabUI = preload("res://tools/engine_lab/engine_lab_ui.gd")


func _initialize() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.title = "MOTOR SES LABORATUVARI — AUTO YARD"
	var screen: Rect2i = DisplayServer.screen_get_usable_rect()
	var size: Vector2i = Vector2i(mini(1600, screen.size.x - 40), mini(960, screen.size.y - 60))
	DisplayServer.window_set_size(size)
	DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
	root.add_child(LabUI.new())
