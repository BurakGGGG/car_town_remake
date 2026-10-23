extends SceneTree
## YÜKLEME EKRANI SLAYTLARI: temiz kayıtla açılır (ilk açılış → giriş seçenekleri ekranı tutar), 26 sn boyunca
## görünen slayt izlenir: Tofaş'lı açılış görseli hiç gelmez, ilk görsel bir slayt, rastgele torba sırası (dördü
## gösterilmeden tekrar yok, art arda aynısı yok), geçiş ortasında iki görselin karışması, en kötü kare süresi. Kareler: ~/Projects/ct_shots/loading_slides/.
## Kullanım: CT_LOGIN_GATE=1 CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/yukleme_slayt_qa.gd --display-driver x11 --resolution 1152x648
const OUT: String = "/home/burak/Projects/ct_shots/loading_slides/"
const DURATION_MS: int = 26000


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for file: String in DirAccess.get_files_at(OUT):
		DirAccess.remove_absolute(OUT + file)
	_run.call_deferred()


func _shot(name: String) -> void:
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png(OUT + name + ".png")


func _run() -> void:
	var t0: int = Time.get_ticks_msec()
	change_scene_to_file(String(ProjectSettings.get_setting("application/run/main_scene")))
	await process_frame
	await process_frame
	var screen: LoadingScreen = root.find_child("LoadingScreen", true, false) as LoadingScreen
	if screen == null:
		print("SLAYT HATA: yükleme ekranı yok")
		quit(1)
		return
	var order: Array[String] = []
	var last: Texture2D = null
	var worst: int = 0
	var mid_fade_shot: bool = false
	var fails: int = 0
	while Time.get_ticks_msec() - t0 < DURATION_MS:
		var f0: int = Time.get_ticks_msec()
		await process_frame
		worst = maxi(worst, Time.get_ticks_msec() - f0)
		if not is_instance_valid(screen):
			print("SLAYT HATA: yükleme ekranı erken kapandı (giriş seçenekleri bekletmedi: CT_LOGIN_GATE=1 verildi mi?)")
			fails += 1
			break
		var art: TextureRect = screen.get("_art")
		var next: TextureRect = screen.get("_art_next")
		if art.texture != last:
			last = art.texture
			var path: String = last.resource_path.get_file().get_basename() if last else "?"
			order.append(path)
			print("SLAYT %5.1f sn  %s" % [(Time.get_ticks_msec() - t0) / 1000.0, path])
			_shot("%02d_%s" % [order.size(), path])
		if not mid_fade_shot and next.texture != null and next.modulate.a > 0.4 and next.modulate.a < 0.6:
			mid_fade_shot = true
			_shot("gecis_ortasi")
	# 2026-10-23 kuralı: Tofaş'lı garaj (loading_bg) yalnız motorun açılış ekranında; çubukla birlikte rastgele bir slayt,
	# sonra torba usulü rastgele sıra — dördü gösterilmeden tekrar yok, art arda aynısı yok
	var slides: int = LoadingScreen.SLIDES.size()
	if order.has("loading_bg"):
		print("SLAYT HATA: yükleme ekranında Tofaş'lı açılış görseli göründü")
		fails += 1
	for i: int in order.size():
		if i > 0 and order[i] == order[i - 1]:
			print("SLAYT HATA: %d. görsel bir öncekiyle aynı (%s)" % [i + 1, order[i]])
			fails += 1
		if i < slides and order.slice(0, i).has(order[i]):
			print("SLAYT HATA: %s, dört görsel gösterilmeden tekrar geldi" % order[i])
			fails += 1
	if order.size() < slides + 1:
		print("SLAYT HATA: %d görsel görüldü, en az %d bekleniyordu" % [order.size(), slides + 1])
		fails += 1
	if not mid_fade_shot:
		print("SLAYT HATA: geçiş ortası yakalanamadı")
		fails += 1
	print("SLAYT sıra: %s · en kötü kare %d ms · %s" % [" → ".join(order), worst, "TAMAM" if fails == 0 else "%d HATA" % fails])
	quit(0 if fails == 0 else 1)
