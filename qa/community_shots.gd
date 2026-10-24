extends SceneTree
## TOPLULUK görsel QA — MARKET › ÜCRETSİZ sekmesi (TAKİP ET / ÖDÜLÜ AL / ALINDI) ve BİZİ DEĞERLENDİR penceresi.
## Bağlantılar açılmaz (opener sahte). Telefon oranı (20:9) için 1404x648, en dar tuval 853x480.
## Kullanım: QA_LANG=de tools/qa_isolated.sh res://qa/community_shots.gd --display-driver x11 --disable-vsync \
##   --resolution 1404x648 -- <çıktı klasörü>
var _out: String = "/home/burak/Projects/ct_shots/community/"


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
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	var router: UiRouter = hud.router
	var community: CommunityLinks = get_first_node_in_group("community") as CommunityLinks
	community.opener = func(_url: String) -> void: pass
	(get_first_node_in_group("player_progress") as PlayerProgress).load_state(6, 0, 85)
	await frames(60)
	router.close_all()
	router.open(&"gem_store")
	await frames(70)
	var screen: GemStoreScreen = hud.gem_store_screen
	screen._on_tab_pressed(GemStoreScreen.TAB_FREE)
	await frames(40)
	await shot("free")
	community.open_link(&"instagram")
	await frames(20)
	await shot("free_opened")
	community.claim(&"tiktok")   # açılmadı: alınmaz
	community.open_link(&"tiktok")
	community.claim(&"tiktok")
	await frames(20)
	await shot("free_claimed")
	router.close_all()
	await frames(40)
	router.open(&"rate_prompt")
	await frames(50)
	await shot("rate_prompt")
	quit()
