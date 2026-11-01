extends SceneTree
## SOL ÜST PROFİL BLOĞU taslakları için arka plan: dekorlu kayıtla şehir, sol üst blok GİZLİ (temiz) ve mevcut hâli.
## QA_SAVE=~/Projects/ct_shots/bench_saves/featured.json tools/qa_isolated.sh res://qa/hud_left_shots.gd --resolution 1152x648
## QA_LANG=en|es|de|fr: o dilde, o dilin isim havuzundan bir adla ve o ülkenin bayrağıyla (ehliyet şeridi) çeker.
## Çıktı: ~/Projects/ct_shots/hud_sol/{temiz,mevcut}[_<dil>].png (+ _dar: 1,0 ölçek)
const OUT: String = "/home/burak/Projects/ct_shots/hud_sol/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_run.call_deferred()


func _shot(name: String) -> void:
	for i: int in 25:
		await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + name + ".png")
	print("görüntü: ", name)


func _run() -> void:
	create_timer(150.0).timeout.connect(func() -> void: quit(1))
	OS.set_environment("CT_NO_TUTORIAL", "1")
	change_scene_to_file("res://Main.tscn")
	for i: int in 150:
		await process_frame
	var hud: Hud = current_scene.find_child("HUD", true, false) as Hud
	hud.router.close_all()
	var profile: PlayerProfile = get_first_node_in_group("player_profile") as PlayerProfile
	var lang: String = Loc.current()
	var flags: Dictionary = {"tr": "TR", "en": "GB", "es": "ES", "de": "DE", "fr": "FR"}
	profile.set_preset({"tr": "p26", "en": "p12", "es": "p22", "de": "p19", "fr": "p27"}.get(lang, "p26"))
	profile.set_frame("gold")
	profile.set_flag(flags.get(lang, "TR"))
	hud.set_player_name("TurboSomun" if lang == "tr" else NamePool.seeded_name(7, lang))
	var suffix: String = "" if lang == "tr" else "_" + lang
	for scale_k: float in [1.35, 1.0]:
		root.content_scale_factor = scale_k
		var tag: String = ("" if scale_k > 1.2 else "_dar") + suffix
		hud.top_left.visible = true
		await _shot("mevcut" + tag)
		hud.top_left.visible = false
		await _shot("temiz" + tag)
		hud.top_left.visible = true
	print("sol üst blok rect (1,35): ", hud.top_left.get_global_rect())
	quit(0)
