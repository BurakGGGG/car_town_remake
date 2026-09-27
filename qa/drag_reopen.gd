extends SceneTree
## 1) Yarış bitip ekran kapandıktan sonra tekrar açılınca kamera çıkışta mı?
## 2) Oyuncu HİÇ dokunmazsa rakip kendi kalkıyor ve oyuncunun aracı çizgide duruyor mu?
const OUT: String = "/home/burak/Projects/ct_shots/drag/"
var _hud: Node
var _drag: Node
var _elapsed: float = 0.0

func _initialize() -> void:
	Engine.max_fps = 0
	_run.call_deferred()

func _find(n: Node, s: String) -> Node:
	if n.name == s: return n
	for c: Node in n.get_children():
		var r: Node = _find(c, s)
		if r: return r
	return null

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _cam_z() -> float:
	return (_drag.get("_camera") as Camera3D).global_position.z

func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await _frames(60)
	_hud = _find(current_scene, "HUD")
	_drag = _hud.get("drag_race_screen")
	_drag.call("open")
	await _frames(10)
	var first: float = _cam_z()
	print("1. açılış kamera z = %.2f" % first)

	# Oyuncu HİÇ dokunmuyor. Geri sayım ~2.4 sn, sonra 3 sn koşu izlenir.
	var p: Node3D = _drag.get("_player_car")
	var r: Node3D = _drag.get("_rival_car")
	for t: float in [3.0, 5.0, 6.0, 7.0, 9.0]:
		while _elapsed < t:
			await create_timer(0.25).timeout
			_elapsed += 0.25
		print("%4.1f sn | faz=%s | oyuncu z=%.2f rakip z=%.2f fark=%.2f | rakip koşuyor=%s oyuncu koşuyor=%s" % [
			_elapsed, _drag.get("_phase"), p.position.z, r.position.z, r.position.z - p.position.z,
			_drag.get("_rival").running, _drag.get("_player").running])
		if is_equal_approx(t, 7.0):
			RenderingServer.force_draw()
			get_root().get_texture().get_image().save_png(OUT + "dokunmadan.png")

	# Yarışın bitmesini bekle (en fazla 45 sn)
	var waited: float = 0.0
	while int(_drag.get("_phase")) != 3 and waited < 45.0:
		await create_timer(0.5).timeout
		waited += 0.5
	print("yarış bitti: faz=%s, %.1f sn | kamera z = %.2f" % [_drag.get("_phase"), waited, _cam_z()])

	_drag.call("close")
	await _frames(20)
	_drag.call("open")
	await _frames(10)
	var again: float = _cam_z()
	print("2. açılış kamera z = %.2f  (ilkinden fark %.2f)" % [again, absf(again - first)])
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + "ikinci_acilis.png")
	quit(0)
