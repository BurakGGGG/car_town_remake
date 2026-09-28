extends SceneTree
## FAR KONTRASTI: her aracın far texel'leri kaportadan ne kadar ayrışıyor?
##
## Farlar dokudan gelir (CarRig yalnızca ton/metaliklik/pürüz/emisyon ayarlar). Doku beyaz
## kaportanın üstünde beyazsa far oyunda kayboluyor — Volvo S60 ve Honda Civic'te gözle
## görülüyordu. Bu betik rol başına UV'den örnekleyip DOKUDAKİ parlaklık farkını ölçer,
## yani CarRig'in materyal ayarından bağımsız ham sorunu gösterir.
##
## Kullanım: godot-4 --headless --path . -s res://qa/far_kontrast.gd

func _init() -> void:
	print("%-22s %-10s %-10s %8s  %s" % ["araç", "kaporta", "far", "Δparlak", "durum"])
	var weak: int = 0
	var total: int = 0
	for entry: Dictionary in CarCatalog.all():
		var path: String = entry["scene_path"]
		var map: Dictionary = CarPartMap.get_map(path)
		if map.is_empty():
			continue
		var root: Node3D = (load(path) as PackedScene).instantiate()
		var by_name: Dictionary = {}
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			by_name[m.name] = m
		var img: Image = _albedo_of(by_name)
		if img == null:
			print("%-22s doku yok" % entry["id"])
			root.free()
			continue
		var body: Color = _role_color(map, by_name, img, &"body")
		var head: Color = _role_color(map, by_name, img, &"headlights")
		root.free()
		if body.a < 0.5:
			print("%-22s kaporta rolü ölçülemedi" % entry["id"])
			continue
		if head.a < 0.5:
			print("%-22s %-10s %-10s %8s  far rolü YOK" % [entry["id"], "#" + body.to_html(false), "-", "-"])
			continue
		total += 1
		var d: float = absf(_lum(head) - _lum(body))
		var verdict: String = "ZAYIF" if d < 0.10 else ("sınırda" if d < 0.18 else "iyi")
		if d < 0.10:
			weak += 1
		print("%-22s %-10s %-10s %8.3f  %s" % [entry["id"], "#" + body.to_html(false),
			"#" + head.to_html(false), d, verdict])
	print("--- %d araçtan %d'sinde far kontrastı zayıf (Δ < 0,10) ---" % [total, weak])
	quit()


static func _lum(c: Color) -> float:
	return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b


## Araçtaki ilk dokulu materyalin albedo görüntüsü (tüm parçalar tek atlası paylaşır).
static func _albedo_of(by_name: Dictionary) -> Image:
	for m: MeshInstance3D in by_name.values():
		for s: int in m.mesh.get_surface_count():
			var mat: BaseMaterial3D = m.mesh.surface_get_material(s) as BaseMaterial3D
			if mat and mat.albedo_texture:
				var img: Image = mat.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
				return img
	return null


## Rolün üçgen vertex'lerinin UV'lerinden doku örnekleyip ortalama rengi döndürür (a=0 → yok).
static func _role_color(map: Dictionary, by_name: Dictionary, img: Image, role: StringName) -> Color:
	var sum: Color = Color(0, 0, 0)
	var n: int = 0
	for index: int in map.get(role, []):
		var mi: MeshInstance3D = by_name.get("tripo_part_%d" % index)
		if mi == null:
			continue
		for s: int in mi.mesh.get_surface_count():
			var uvs: PackedVector2Array = mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_TEX_UV]
			if uvs.is_empty():
				continue
			var step: int = maxi(1, uvs.size() / 400)   # parça başına en çok ~400 örnek
			for i: int in range(0, uvs.size(), step):
				sum += img.get_pixel(
					clampi(int(uvs[i].x * img.get_width()), 0, img.get_width() - 1),
					clampi(int(uvs[i].y * img.get_height()), 0, img.get_height() - 1))
				n += 1
	if n == 0:
		return Color(0, 0, 0, 0)
	return Color(sum.r / n, sum.g / n, sum.b / n, 1.0)
