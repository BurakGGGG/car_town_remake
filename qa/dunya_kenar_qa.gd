extends SceneTree
## DÜNYA KENARI QA — garaj büyüdükçe kameranın gördüğü kenarlar: yol uçları, showroom binasının
## arkası / yanı, çimenin bittiği yer. Her garaj seviyesinde normal mod (en uzak zum, köşelere kaydırılmış)
## ve düzenleme modu (garaja sığdırılmış) fotoğrafları alır.
##   godot-4 --path . --resolution 1170x540 -s res://qa/dunya_kenar_qa.gd [-- <etiket>]
## Görüntüler: /home/burak/Projects/ct_shots/dunya/<etiket>_*.png

const OUT: String = "/home/burak/Projects/ct_shots/dunya/"

var _tag: String = "once"


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_tag = args[0]
	_run.call_deferred()


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	await frames(70)
	var save: SaveManager = get_first_node_in_group("save_manager")
	save.new_game()
	var upgrades: GarageUpgradeManager = get_first_node_in_group("garage_upgrades")
	var camera: WorldCamera = get_root().get_camera_3d() as WorldCamera
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	if _tag.ends_with("_yakin"):
		# Showroom yakın plan: en yakın zum, binanın ortası ve doğudaki açık sergi
		camera.zoom_by(-10.0)
		for spot: Array in [["salon", Vector3(4.6, 0.0, -2.4)], ["sergi", Vector3(7.2, 0.0, -3.2)],
				["totem", Vector3(2.4, 0.0, -1.0)], ["arka", Vector3(5.0, 0.0, -5.5)],
				["kose", Vector3(0.6, 0.0, 0.6)], ["yol_bati", Vector3(-6.0, 0.0, 0.6)], ["yol_kuzey", Vector3(0.6, 0.0, -6.0)],
				["yol_dogu", Vector3(8.2, 0.0, 0.6)], ["yol_guney", Vector3(0.6, 0.0, 7.2)]]:
			camera.set("_focus", spot[1])
			camera.call("_apply_focus")
			await frames(40)
			await _shot("showroom_%s" % spot[0])
		quit()
		return
	for level: int in [1, 4]:
		upgrades.apply_levels({GarageUpgradeManager.GARAGE_ID: level})
		await frames(10)
		# Normal mod: varsayılan görünüm, sonra en uzak zum ve dört köşe
		camera.zoom_by(-10.0)
		camera.set("_focus", Vector3.ZERO)
		camera.call("_apply_focus")
		await frames(40)
		await _shot("sv%d_varsayilan" % level)
		camera.zoom_by(10.0)
		await frames(60)
		for corner: Array in [["kb", Vector3(-20, 0, -20)], ["kd", Vector3(20, 0, -20)],
				["gb", Vector3(-20, 0, 20)], ["gd", Vector3(20, 0, 20)]]:
			camera.set("_focus", corner[1])
			camera.call("_apply_focus")
			await frames(20)
			await _shot("sv%d_uzak_%s" % [level, corner[0]])
		camera.zoom_by(-10.0)
		camera.set("_focus", Vector3.ZERO)
		camera.call("_apply_focus")
		await frames(30)
		router.open(&"garage_edit")
		await frames(50)
		await _shot("sv%d_duzenleme" % level)
		(router.screen(&"garage_edit") as GarageEditScreen).close()
		await frames(40)
	quit()


func _shot(name: String) -> void:
	await frames(3)
	RenderingServer.force_draw()
	get_root().get_texture().get_image().save_png(OUT + _tag + "_" + name + ".png")
	print("   görüntü: %s%s_%s.png" % [OUT, _tag, name])
