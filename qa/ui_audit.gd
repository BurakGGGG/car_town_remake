extends SceneTree
## Mobil UI denetimi: her ekranı açar, ekran görüntüsü alır, kadraj dışına taşan Control'leri ve
## küçük dokunma hedeflerini listeler. Ölçüler CANVAS birimindedir (taban 1152x648).
const OUT: String = "/home/burak/Projects/ct_shots/ui/"
const MIN_TOUCH: float = 44.0
var _hud: Node
var _router: Node
var _frame: int = 0
var _step: int = 0
var _screens: Array = [&"garage", &"showroom", &"quest", &"garage_value"]
var _tag: String = ""

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	Engine.max_fps = 0
	_tag = "%dx%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y]

func _find(node: Node, name: String) -> Node:
	if node.name == name:
		return node
	for c: Node in node.get_children():
		var r: Node = _find(c, name)
		if r:
			return r
	return null

## Kadraj: canvas_items + expand → görünür alan tabandan GENİŞ olabilir, dikey taban korunur.
func _canvas_rect() -> Rect2:
	return get_root().get_visible_rect()

func _walk(node: Node, over: Array, small: Array, depth: int = 0) -> void:
	if node is ScrollContainer:
		return   # içerik kırpılır ve kaydırılır: taşma sayılmaz
	if node is Control:
		var c: Control = node
		if c.is_visible_in_tree() and c.size.x > 1.0 and c.size.y > 1.0:
			var r: Rect2 = Rect2(c.get_global_rect())
			var view: Rect2 = _canvas_rect()
			if r.position.x < view.position.x - 0.5 or r.position.y < view.position.y - 0.5 \
					or r.end.x > view.end.x + 0.5 or r.end.y > view.end.y + 0.5:
				over.append("%s (%s) %s" % [c.name, c.get_class(), r])
			var clickable: bool = c is BaseButton or c.has_signal("pressed")
			if clickable and c.mouse_filter != Control.MOUSE_FILTER_IGNORE \
					and (r.size.x < MIN_TOUCH or r.size.y < MIN_TOUCH):
				small.append("%s (%s) %.0fx%.0f" % [c.name, c.get_class(), r.size.x, r.size.y])
	for child: Node in node.get_children():
		_walk(child, over, small, depth + 1)

func _report(label: String) -> void:
	var over: Array = []
	var small: Array = []
	_walk(_hud, over, small)
	print("--- %s @ %s | kadraj %s" % [label, _tag, _canvas_rect().size])
	print("    taşan: %d %s" % [over.size(), over if over.size() <= 6 else over.slice(0, 6)])
	print("    küçük dokunma hedefi (<%dpx): %d %s" % [int(MIN_TOUCH), small.size(),
		small if small.size() <= 8 else small.slice(0, 8)])
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png("%s%s_%s.png" % [OUT, _tag, label])

func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		change_scene_to_file("res://Main.tscn")
		return false
	if _frame == 70:
		_hud = _find(current_scene, "HUD")
		_router = _hud.get("router")
		var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
		for id: StringName in ["bmw_e60", "hyundai_getz", "skoda_kamiq", "vw_golf_7", "volvo_s60",
				"tofas_sahin", "audi_a3", "honda_civic"]:
			own.add_vehicle(id)
		var eco: EconomyManager = get_first_node_in_group("economy") as EconomyManager
		eco.set_money(250000)
		return false
	if _frame == 110:
		_report("dunya")
		return false
	if _frame > 110 and (_frame - 110) % 130 == 0:
		if _step > 0:
			_report(String(_screens[_step - 1]))
			_router.call("close_all") if _router.has_method("close_all") else _router.call("open", &"")
		if _step >= _screens.size():
			print("TAMAM")
			quit(0)
			return true
		_router.call("open", _screens[_step])
		_step += 1
	return false
