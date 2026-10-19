extends SceneTree
## ARAÇ MESH'İ ÖNCE / SONRA KADRAJLARI: tools/resimplify_car.py'nin görsel etkisini oyunun kendi
## ekranlarında ölçmek için. Aynı betik iki kez koşulur (önce eski GLB'ler içe aktarılmışken TAG=old,
## sonra yeniler içe aktarılmışken TAG=new); qa/size_audit/mesh_compare.py iki klasörü karşılaştırır.
## Telefonu taklit eder (mip_probe ile aynı): Xephyr 2400x1080 + content_scale_factor 1,35 → showroom ve
## garaj SubViewport'u 1067x480.
##   Xephyr :7 -screen 2400x1080x24 -ac -br -noreset -nolisten tcp &
##   DISPLAY=:7 tools/qa_isolated.sh res://qa/size_audit/mesh_probe.gd --display-driver x11 \
##     --resolution 2400x1080 --position 0,0 -- <old|new> [araç_id ...]
## MESH_PROBE_FAST=1: yalnızca en kötü durum (showroom en yakın zoom, yan ve arka 3/4), garaj yok.
const OUT: String = "/home/burak/Projects/ct_shots/mesh_probe/"
const YAWS: Array[float] = [-38.0, -90.0, 150.0, 0.0]

var _tag: String = "new"
var _cars: PackedStringArray = []
var _fast: bool = OS.get_environment("MESH_PROBE_FAST") == "1"


func _initialize() -> void:
	root.content_scale_factor = 1.35
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	_cars = args.slice(1)
	if _cars.is_empty():
		_cars = PackedStringArray(["bmw_e46", "ferrari_488_pista", "hyundai_getz"])
	DirAccess.make_dir_recursive_absolute(OUT + _tag)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(240)
	var own: VehicleOwnership = get_first_node_in_group("vehicle_ownership") as VehicleOwnership
	for id: String in _cars:
		own.add_vehicle(StringName(id))
	await _frames(10)
	var router: Node = _find(current_scene, "HUD").get("router")

	router.call("open", &"showroom")
	await _frames(30)
	var showroom: Node = router.call("screen", &"showroom")
	for id: String in _cars:
		showroom.call("_show_vehicle", StringName(id))
		await _frames(150)
		for zoom: float in ([ShowroomScreen.ZOOM_MIN] if _fast else [1.0, ShowroomScreen.ZOOM_MIN]):
			for yaw: float in ([-90.0, 150.0] if _fast else YAWS):
				showroom.set_process(false)
				(showroom.get("_display_root") as Node3D).rotation = Vector3(0.0, deg_to_rad(yaw), 0.0)
				showroom.set("_zoom", zoom)
				showroom.set("_zoom_target", zoom)
				showroom.call("_apply_camera")
				await _save("showroom_%s_z%.2f_y%d" % [id, zoom, int(yaw)], showroom.get("_viewport"))
		showroom.set_process(true)
	router.call("close_all")
	await _frames(30)
	if _fast:
		print("mesh_probe %s: %d araç bitti (hızlı)" % [_tag, _cars.size()])
		quit()
		return

	router.call("open", &"garage")
	await _frames(40)
	var garage: Node = router.call("screen", &"garage")
	for id: String in _cars:
		garage.call("_show_vehicle", StringName(id), false)
		await _frames(150)
		await _save("garaj_%s" % id, _first_subviewport(garage))
	print("mesh_probe %s: %d araç bitti" % [_tag, _cars.size()])
	quit()


func _save(label: String, vp: Viewport) -> void:
	await _frames(4)
	RenderingServer.force_draw()
	await _frames(1)
	var img: Image = vp.get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(OUT + _tag + "/" + label + ".png")


func _first_subviewport(node: Node) -> SubViewport:
	for c: Node in node.find_children("*", "SubViewport", true, false):
		return c as SubViewport
	return null


func _find(node: Node, n: String) -> Node:
	if node.name == n:
		return node
	for c: Node in node.get_children():
		var f: Node = _find(c, n)
		if f:
			return f
	return null
