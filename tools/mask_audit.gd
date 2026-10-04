extends SceneTree
## BOYA MASKESİ DENETİMİ — dokuda fabrika boyası renginde olup maskede BOYANMAYAN üçgenleri parça ve rol
## bazında sayar; en çok kaçıran parçalar üstte. Kırmızı / yeşil gibi doygun boyada ton, gri / beyazda
## parlaklık eşleşir. Kaçıran texel haritası ~/Projects/ct_shots/boya/maske_fark.png.
## Kullanım: godot-4 --headless --path . -s res://tools/mask_audit.gd -- <id>
func _initialize() -> void:
	var id: StringName = StringName(OS.get_cmdline_user_args()[0])
	var path: String = CarCatalog.scene_path(id)
	var map: Dictionary = CarPartMap.get_map(path)
	var role_of: Dictionary = {}
	for role: StringName in CarPartMap.ROLES:
		for i: int in map.get(role, []): role_of[i] = role
	var car: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(car)
	var mask: Image = Image.load_from_file(ProjectSettings.globalize_path(String(CarCatalog.get_entry(id)["optimized_path"]).get_basename() + "_paintmask.png"))
	var img: Image = null
	var paint: Color = map["default_paint"]
	var out: Image = Image.create(1024, 1024, false, Image.FORMAT_RGB8)
	var per: Dictionary = {}
	for m: MeshInstance3D in car.find_children("tripo_part_*", "MeshInstance3D", true, false):
		if img == null:
			img = (m.mesh.surface_get_material(0) as BaseMaterial3D).albedo_texture.get_image()
			if img.is_compressed(): img.decompress()
			img.resize(1024, 1024, Image.INTERPOLATE_BILINEAR)
		var arr: Array = m.mesh.surface_get_arrays(0)
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var part: int = int(String(m.name).get_slice("_", 2))
		var miss: int = 0
		var tot: int = 0
		for t: int in idx.size() / 3:
			var u: Vector2 = (uv[idx[t * 3]] + uv[idx[t * 3 + 1]] + uv[idx[t * 3 + 2]]) / 3.0
			var x: int = clampi(int(u.x * 1024), 0, 1023)
			var y: int = clampi(int(u.y * 1024), 0, 1023)
			var c: Color = img.get_pixel(x, y)
			var like: bool = (c.s > 0.55 and c.v > 0.25 and absf(wrapf(c.h - paint.h, -0.5, 0.5)) < 0.04) if paint.s > 0.3 \
				else (c.s < 0.12 and absf(c.v - paint.v) < 0.12)
			if like:
				tot += 1
				if mask.get_pixel(x, y).r < 0.5:
					miss += 1
					out.set_pixel(x, y, Color.WHITE)
		if miss > 0:
			per[part] = [miss, tot]
	var keys: Array = per.keys()
	keys.sort_custom(func(a, b): return per[a][0] > per[b][0])
	for k: int in keys:
		print("p%-3d %-11s kirmizi-ama-boyasiz %4d / %4d ucgen" % [k, role_of.get(k, "?"), per[k][0], per[k][1]])
	out.save_png("/home/burak/Projects/ct_shots/boya/maske_fark.png")
	quit()
