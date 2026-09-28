extends SceneTree
## Garaj kamerasının GÖRDÜĞÜ zemin alanını ölçer: yuvaları buna göre yerleştirmek için.
var _hud: Node
func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null
func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()
func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	for i: int in 70: await process_frame
	_hud = _find(current_scene, "HUD")
	_hud.get("router").call("open", &"garage")
	for i: int in 90: await process_frame
	var garage: Control = _hud.get("garage_screen")
	var cam: Camera3D = garage.get("preview_camera")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		cam.size = float(args[0])
		if args.size() > 1:
			cam.position = cam.position + Vector3(float(args[1]), 0.0, float(args[1]))
		await process_frame
	var vp: SubViewport = garage.get("car_viewport")
	var size: Vector2 = Vector2(vp.size)
	print("kamera pos=%s size=%.2f | viewport %s" % [cam.global_position, cam.size, size])
	# Ekranın dört köşesi + kenar ortaları → y=0 düzlemi
	var names: Array = ["sol-üst", "sağ-üst", "sol-alt", "sağ-alt", "orta"]
	var points: Array = [Vector2(0, 0), Vector2(size.x, 0), Vector2(0, size.y), size, size * 0.5]
	for i: int in points.size():
		var origin: Vector3 = cam.project_ray_origin(points[i])
		var dir: Vector3 = cam.project_ray_normal(points[i])
		var t: float = -origin.y / dir.y if absf(dir.y) > 0.001 else 0.0
		var hit: Vector3 = origin + dir * t
		print("  %-8s → zemin (%.2f, %.2f)" % [names[i], hit.x, hit.z])
	# Arayüzün kapattığı alan: sol sütun ve alt şerit ekranın yüzdesi olarak
	var canvas: Vector2 = get_root().get_visible_rect().size
	var left: Control = garage.get("left_group")
	var strip: Control = garage.get("bottom_group")
	print("sol sütun genişliği %.0f/%0.f px (%%%.0f) | alt şerit yüksekliği %.0f px (%%%.0f)" % [
		left.size.x, canvas.x, left.size.x / canvas.x * 100.0,
		strip.size.y, strip.size.y / canvas.y * 100.0])
	# Lift merkezinin ekrandaki yeri
	print("lift (0,0,0) ekranda: %s | araç yarıçapı ~1.1 birim" % cam.unproject_position(Vector3.ZERO))
	# GÜVENLİ BÖLGE: sol sütun %25, alt şerit %20, üstte tabela payı %12, sağda plaka sütunu %8
	var safe_min: Vector2 = Vector2(canvas.x * 0.28, canvas.y * 0.13)
	var safe_max: Vector2 = Vector2(canvas.x * 0.90, canvas.y * 0.76)
	var lift: Vector2 = cam.unproject_position(Vector3.ZERO)
	print("güvenli kutu: %s .. %s" % [safe_min, safe_max])
	print("aday zemin noktaları (duvarlar x>=-1.15, z>=-1.15):")
	var x: float = -1.15
	while x <= 2.6:
		var z: float = -1.15
		var line: String = ""
		while z <= 2.6:
			var screen: Vector2 = cam.unproject_position(Vector3(x, 0.18, z))
			var inside: bool = screen.x >= safe_min.x and screen.x <= safe_max.x \
				and screen.y >= safe_min.y and screen.y <= safe_max.y
			var clear: bool = Vector2(x, z).length() > 1.05   # lift + araç payı
			line += ("O" if (inside and clear) else ("c" if inside else ".")) 
			z += 0.35
		print("  x=%5.2f  %s" % [x, line])
		x += 0.35
	print("  (sütun z=-1.15..2.60, adım 0.35; O = kullanılabilir, c = araç bölgesi, . = kadraj dışı)")
	quit(0)
