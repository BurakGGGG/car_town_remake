class_name AvatarButton
extends Button
## DOKUNULABİLİR YUVARLAK AVATAR: HUD'un sol üstündeki kendi avatarın (profil açılır), arkadaş satırları (kart açılır),
## profil düzenlemedeki hazır avatar / çerçeve seçicileri. Görünümü içindeki AvatarView çizer; düğmenin kendi
## zemini yoktur. Basınca hafif içe çöker; seçili (button_pressed) iken altında amber halka.

## Kenar uzunluğu (tuval birimi).
@export var diameter: float = 56.0:
	set(value):
		diameter = value
		custom_minimum_size = Vector2(value, value)

var view: AvatarView


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	custom_minimum_size = Vector2(diameter, diameter)
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	view = AvatarView.new()
	view.name = "Avatar"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)
	button_down.connect(func() -> void: view.scale = Vector2.ONE * 0.93)
	button_up.connect(func() -> void: view.scale = Vector2.ONE)
	resized.connect(func() -> void: view.pivot_offset = size * 0.5)
	toggled.connect(func(_on: bool) -> void: queue_redraw())


func show_avatar(tex: Texture2D, illustrated: bool, frame: String = ProfileCatalog.DEFAULT_FRAME, flag: String = "") -> void:
	view.show_avatar(tex, illustrated, frame, flag)


func _draw() -> void:
	if toggle_mode and button_pressed:
		var r: float = minf(size.x, size.y) * 0.5
		draw_arc(size * 0.5, r + 2.0, 0.0, TAU, 48, HudPalette.PLATE_SELECTED, 4.0, true)
