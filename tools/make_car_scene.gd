extends SceneTree
## Araç sarmalayıcı sahnesi üreticisi: optimize GLB'yi MİRAS ALAN 4 satırlık .tscn yazar
## (mevcut araçlarla birebir aynı yapı: kök = GLB örneği, adı araç id'si).
##
## Neden metin yazıyoruz: başsız Godot'ta PackedScene.pack() bir GLB örneğini "instance" olarak
## DEĞİL, bütün mesh verisini gömerek kaydediyor (8 MB'lık .tscn). Miras alan sahne biçimini
## doğrudan üretmek hem doğru hem küçük. UID'ler ResourceUID'den alınır, elle uydurulmaz.
##
## Kullanım: godot-4 --headless --path . -s res://tools/make_car_scene.gd -- <id> [<id> ...]


func _init() -> void:
	var ids: PackedStringArray = OS.get_cmdline_user_args()
	if ids.is_empty():
		push_error("en az bir araç id'si gerekli")
		quit(1)
		return
	for id: String in ids:
		var glb: String = "res://assets/cars/optimized/%s.glb" % id
		var out: String = "res://assets/cars/%s.tscn" % id
		if not ResourceLoader.exists(glb):
			push_error("optimize GLB yok: " + glb)
			continue
		var glb_uid: int = ResourceLoader.get_resource_uid(glb)
		var scene_uid: int = ResourceUID.create_id()
		var text: String = "[gd_scene format=3 uid=\"%s\"]\n\n" % ResourceUID.id_to_text(scene_uid)
		text += "[ext_resource type=\"PackedScene\" uid=\"%s\" path=\"%s\" id=\"1_%s\"]\n\n" % [
			ResourceUID.id_to_text(glb_uid), glb, id.substr(0, 5)]
		text += "[node name=\"%s\" instance=ExtResource(\"1_%s\")]\n" % [id, id.substr(0, 5)]
		var file: FileAccess = FileAccess.open(out, FileAccess.WRITE)
		if file == null:
			push_error("yazılamadı: " + out)
			continue
		file.store_string(text)
		file.close()
		ResourceUID.add_id(scene_uid, out)
		print("sahne: %s (glb uid %s)" % [out, ResourceUID.id_to_text(glb_uid)])
	quit()
