extends SceneTree
## DEPO KARTI FOTOĞRAFLARI → res://assets/garages/<id>/card.png (DEPOLARIM panosu, CarGaragesScreen.card_path); OTOPARK
## (CarGarageManager.WAITING, çatı katı sahnesi) → res://assets/garages/rooftop/card.png.
## Her garajın pişmiş iç mekânı ARAÇSIZ ve taban seviyede, oyundaki genel görünüm kamerasıyla çizilir
## (GarageInteriorView.overview): kartta oyuncunun araçları değil garajın kendisi görünür.
## Ne zaman: tools/garages/ ile bir garaj yeniden pişirilince. Sonra --import (yeni PNG'ler kayıplı sıkıştırılır:
## .import'ta compress/mode=1).
## Kullanım (PENCERELİ — başsızda çizim yok):
##   godot-4 --path . --display-driver x11 --disable-vsync --resolution 640x360 \
##     --script res://tools/make_garage_cards.gd [-- <garaj_id> ...]
##   godot-4 --headless --path . --import

## Çizim oyundaki telefon oranında (genel görünüm kamerası bu oranda kadrajlanıyor), sonra kenarlardaki boş siyah kırpılır.
const RENDER_SIZE: Vector2i = Vector2i(1600, 720)
const CROP: Rect2 = Rect2(0.06, 0.0, 0.88, 0.92)   # oran olarak
const CARD_SIZE: Vector2i = Vector2i(960, 452)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var wanted: PackedStringArray = OS.get_cmdline_user_args()
	var viewport: SubViewport = SubViewport.new()
	viewport.size = RENDER_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera: Camera3D = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	var key: DirectionalLight3D = DirectionalLight3D.new()
	viewport.add_child(key)
	var view: GarageInteriorView = GarageInteriorView.new()
	root.add_child(view)
	var ids: Array[StringName] = [CarGarageManager.WAITING]
	ids.append_array(CarGarageCatalog.ids())
	for garage: StringName in ids:
		if not wanted.is_empty() and not wanted.has(String(garage)):
			continue
		if not view.enter(garage, viewport, camera, key, []):
			push_error("make_garage_cards: %s iç mekânı yok" % garage)
			continue
		view.overview(false)
		for i: int in 20:   # birleştirme ve doku yüklemesi otursun
			await process_frame
		var image: Image = viewport.get_texture().get_image()
		var size: Vector2 = Vector2(image.get_size())
		var region: Rect2i = Rect2i(Vector2i(CROP.position * size), Vector2i(CROP.size * size))
		image = image.get_region(region)
		image.resize(CARD_SIZE.x, CARD_SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path: String = CarGaragesScreen.card_path(garage)
		var err: Error = image.save_png(ProjectSettings.globalize_path(path))
		if err != OK:
			push_error("make_garage_cards: %s kaydedilemedi (%d)" % [garage, err])
		else:
			print("make_garage_cards: %s" % path)
		view.exit()
		await process_frame
	quit()
