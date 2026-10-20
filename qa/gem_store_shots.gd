extends SceneTree
## MARKET görsel QA — HUD'un sol üstü (MARKET düğmesi), GEM AL ve PARAYA ÇEVİR sekmeleri, çeviri onayı.
## Telefon oranı (20:9) için 1404x648. Masaüstünde sahte Play (MockBillingClient) fiyat verir.
## Kullanım: tools/qa_isolated.sh res://qa/gem_store_shots.gd --resolution 1404x648 -- <çıktı klasörü>
var _out: String = "/home/burak/Projects/ct_shots/gem_store/"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].trim_suffix("/") + "/"
	DirAccess.make_dir_recursive_absolute(_out)
	_run.call_deferred()


func frames(n: int) -> void:
	for i: int in n:
		await process_frame


func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(_out + name + ".png")
	print("çekildi: ", _out + name + ".png")


func _run() -> void:
	await frames(2)
	change_scene_to_file("res://Main.tscn")
	await frames(90)
	var hud: Node = current_scene.find_child("HUD", true, false)
	var router: UiRouter = hud.get("router")
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(6, 0, 85)
	await frames(60)
	await shot("hud")
	router.open(&"gem_store")
	await frames(70)
	await shot("store")
	await create_timer(0.7).timeout
	await shot("store_b")
	var screen: GemStoreScreen = hud.get("gem_store_screen")
	screen._on_tab_pressed(GemStoreScreen.TAB_CASH)
	await frames(30)
	await shot("cash")
	screen._on_cash_pressed(1)   # 50 GEM: ilk dokunuş onay ister
	await frames(20)
	await shot("cash_confirm")
	screen._on_cash_pressed(1)
	await frames(80)
	await shot("cash_reward")
	quit()
