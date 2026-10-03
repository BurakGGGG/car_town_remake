extends SceneTree
## DEKOR VARLIK ANALİZİ — katalogdaki her eşyanın gövdesini kurar ve ölçer (rapor §2 tablosu).
## Sütunlar: tür, yerleşim, model kaynağı (.glb / kod), dünyadaki iz (en × derinlik) ve boy,
## modelin orijin sapması (normalleştirmenin düzelttiği: taban y ve iz ortası), rütbe, fiyat.
##   godot-4 --headless --path . -s res://qa/dekor_varlik_analizi.gd > tablo.md


func _initialize() -> void:
	var rows: Array[String] = []
	var kinds: Dictionary = {}
	var sunk_count: int = 0
	var off_count: int = 0
	var smallest: Array = ["", INF]
	var largest: Array = ["", 0.0]
	for item: Dictionary in GarageDecor.all():
		var id: StringName = item["id"]
		var kind: String = GarageDecor.kind_title(int(item["kind"]))
		kinds[kind] = int(kinds.get(kind, 0)) + 1
		if GarageDecor.is_surface(id):
			rows.append("| %s | %s | %s | kaplama | — | — | — | %d | %s |" % [id, item["title"], kind,
				int(item["min_rank"]), _money(int(item["price"]))])
			continue
		var size: Vector3 = DecorBuilder.local_size(id) * GarageDecorView.WORLD_SCALE
		var norm: Dictionary = DecorBuilder._norm.get(id, {})
		var offset: Vector3 = norm.get("offset", Vector3.ZERO)
		var wall: bool = GarageDecor.placement(id) == GarageDecor.PLACE_WALL
		# Normalleştirme ofseti modelin orijin sapmasının tersidir (gövde birimi → dünya).
		var base_off: float = (offset.y if not wall else 0.0) * GarageDecorView.WORLD_SCALE
		var center_off: float = Vector2(offset.x, offset.z if not wall else 0.0).length() * GarageDecorView.WORLD_SCALE
		if base_off > 0.004:
			sunk_count += 1
		if center_off > 0.01:
			off_count += 1
		var area: float = size.x * size.z
		if not wall and area < float(smallest[1]):
			smallest = [String(id), area]
		if not wall and area > float(largest[1]):
			largest = [String(id), area]
		rows.append("| %s | %s | %s | %s · %s | %.2f × %.2f | %.2f | %s | %d | %s |" % [id, item["title"], kind,
			"duvar" if wall else "zemin", "glb" if DecorBuilder.has_model(id) else "kod", size.x, size.z, size.y,
			"taban %+.3f · orta %.3f" % [-base_off, center_off] if (absf(base_off) > 0.001 or center_off > 0.001) else "—",
			int(item["min_rank"]), _money(int(item["price"]))])
	print("| id | ad | kategori | yerleşim · model | iz (en × derinlik) | boy | orijin sapması (düzeltildi) | rütbe | fiyat ₺ |")
	print("|---|---|---|---|---|---|---|---|---|")
	for row: String in rows:
		print(row)
	print("")
	print("kategoriler: %s" % kinds)
	print("tabanı zemine gömülü gelen model: %d · iz ortası orijinden kaçık model: %d" % [sunk_count, off_count])
	print("en küçük iz: %s (%.4f m²-birim) · en büyük iz: %s (%.4f)" % [smallest[0], smallest[1], largest[0], largest[1]])
	quit()


static func _money(v: int) -> String:
	var s: String = str(v)
	var out: String = ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out
