extends SceneTree
## TEKERLEK GRUBU UYDURUCU — her tekerin dönme eksenini LASTİĞİN geometrisinden ölçer ve teker silindirinin
## İÇİNDE kalan her parçayı (jant kolu dilimi, göbek, jant halkası) gruba alır. Sonuç CarPartMap'e yazılacak
## satırlar olarak basılır: "wheel_groups" + "wheel_axes" (+ gerekiyorsa rol düzeltmesi).
##
## Neden: Tripo modellerinde jant çoğu zaman birkaç parçaya bölünmüş (tek kol dilimi, halka, göbek). Gruba
## girmeyen parça teker dönerken YERİNDE KALIYORDU (E60 arka jantın iki kolu, Accent'te kol dilimleri).
## Pivot da lastiğin kutu merkeziydi; birkaç çöp üçgen kutuyu kaydırınca teker yalpalıyordu.
##
## Kurallar:
##   eksen    = lastik vertex'lerinin YZ yüzdelik (%0,5–%99,5) uçlarının ortası; yarıçap = yarı genişlik.
##   üye      = vertex'lerinin >= %92'si silindirin içinde (merkeze uzaklık <= 1,04 R, X lastik genişliği içinde).
##   kaliper  = silindirin içinde ama DOYGUN renkli ve çemberin küçük bir dilimini kaplıyor → gruba GİRMEZ
##              (gerçekte fren kaliperi dönmez).
##   rol      = gruba yeni giren parçanın rolü teker dışıysa (body / black_trim ...) "rims" önerilir: boya
##              maskesi jant kolunu boyamasın.
## Kullanım: godot-4 --headless --path . -s res://tools/wheel_fit.gd [-- <id> ...]

const INSIDE_RATIO: float = 0.92
const RADIUS_SLACK: float = 1.04
const CALIPER_SAT: float = 0.30
const CALIPER_COVER: float = 0.45
const SAMPLE: int = 3000


func _initialize() -> void:
	var ids: Array[StringName] = []
	for a: String in OS.get_cmdline_user_args():
		ids.append(StringName(a))
	if ids.is_empty():
		for entry: Dictionary in CarCatalog.all():
			ids.append(entry["id"])
	for id: StringName in ids:
		await _fit(id)
	quit()


func _fit(id: StringName) -> void:
	var path: String = CarCatalog.scene_path(id)
	var car: Node3D = (load(path) as PackedScene).instantiate()
	root.add_child(car)
	await process_frame
	var map: Dictionary = CarPartMap.get_map(path)
	var by_index: Dictionary = {}
	for m: Node in car.find_children("tripo_part_*", "MeshInstance3D", true, false):
		by_index[int(String(m.name).get_slice("_", 2))] = m
	var albedo: Image = _albedo(by_index.values())
	var rig: CarRig = CarRig.for_node(car)
	var role_of: Dictionary = {}
	for role: StringName in CarPartMap.ROLES:
		for idx: int in map.get(role, []):
			role_of[idx] = role
	var groups: Dictionary = map.get("wheel_groups", {})
	var used: Dictionary = {}
	var out_groups: PackedStringArray = PackedStringArray()
	var out_axes: PackedStringArray = PackedStringArray()
	var role_moves: PackedStringArray = PackedStringArray()
	var notes: PackedStringArray = PackedStringArray()
	for key: String in ["fl", "fr", "rl", "rr"]:
		# Lastik: CarRig'in boyut elemesinden SONRA seçtiği lastik (haritadaki en büyük üye çamurluk olabilir:
		# Audi A3'te grubun en büyüğü yarıçapı 0,123 olan kemer parçasıydı, gerçek teker 0,087)
		var tyre_idx: int = -1
		var gi: int = ["fl", "fr", "rl", "rr"].find(key)
		if gi < rig._wheel_groups.size():
			var g: Dictionary = rig._wheel_groups[gi]
			var tyre_mesh: MeshInstance3D = g["meshes"][int(g["tyre_index"])]
			tyre_idx = int(String(tyre_mesh.name).get_slice("_", 2))
		if tyre_idx < 0:
			notes.append("%s: lastik yok" % key)
			continue
		var tp: PackedVector3Array = _points(by_index[tyre_idx])
		var ys: PackedFloat32Array = PackedFloat32Array()
		var zs: PackedFloat32Array = PackedFloat32Array()
		var xs: PackedFloat32Array = PackedFloat32Array()
		for p: Vector3 in tp:
			ys.append(p.y)
			zs.append(p.z)
			xs.append(p.x)
		ys.sort()
		zs.sort()
		xs.sort()
		var cy: float = (_pct(ys, 0.005) + _pct(ys, 0.995)) * 0.5
		var cz: float = (_pct(zs, 0.005) + _pct(zs, 0.995)) * 0.5
		var radius: float = maxf(_pct(ys, 0.995) - _pct(ys, 0.005), _pct(zs, 0.995) - _pct(zs, 0.005)) * 0.5
		var x_lo: float = _pct(xs, 0.01) - radius * 0.15
		var x_hi: float = _pct(xs, 0.99) + radius * 0.15
		var members: Array[int] = [tyre_idx]
		for idx: int in by_index:
			if idx == tyre_idx or used.has(idx):
				continue
			var m: MeshInstance3D = by_index[idx]
			var role: StringName = role_of.get(idx, &"")
			if role == &"glass" or role == &"headlights" or role == &"taillights":
				continue
			var pts: PackedVector3Array = _points(m)
			if pts.is_empty():
				continue
			var inside: int = 0
			var bins: Dictionary = {}
			for p: Vector3 in pts:
				var d: Vector2 = Vector2(p.y - cy, p.z - cz)
				if d.length() <= radius * RADIUS_SLACK and p.x >= x_lo and p.x <= x_hi:
					inside += 1
					if d.length() > radius * 0.2:
						bins[int(fposmod(d.angle(), TAU) / TAU * 36.0)] = true
			if float(inside) / float(pts.size()) < INSIDE_RATIO:
				continue
			var col: Color = _mean_color(m, albedo)
			var cover: float = float(bins.size()) / 36.0
			if col.s >= CALIPER_SAT and col.v > 0.15 and cover < CALIPER_COVER:
				notes.append("%s: p%d kaliper sayıldı (doygunluk %.2f, kaplama %.0f%%)" % [key, idx, col.s, cover * 100.0])
				continue
			members.append(idx)
			if not [&"wheels", &"tires", &"rims"].has(role):
				role_moves.append("p%d %s→rims" % [idx, role if role != &"" else &"(rolsüz)"])
		for idx: int in members:
			used[idx] = true
		members.sort()
		# Lastik (eksen kaynağı) önde olsun
		members.erase(tyre_idx)
		members.push_front(tyre_idx)
		var old: Array = groups.get(key, [])
		var added: Array[int] = []
		var removed: Array[int] = []
		for idx: int in members:
			if not old.has(idx):
				added.append(idx)
		for idx: int in old:
			if not members.has(idx):
				removed.append(idx)
		out_groups.append('"%s": %s' % [key, str(members)])
		out_axes.append('"%s": [%.4f, %.4f, %.4f]' % [key, cy, cz, radius])
		if not added.is_empty() or not removed.is_empty():
			notes.append("%s: eklenen %s, çıkan %s" % [key, str(added), str(removed)])
	print("@@ %s" % id)
	print('\t\t"wheel_groups": {%s},' % ", ".join(out_groups))
	print('\t\t"wheel_axes": {%s},' % ", ".join(out_axes))
	if not role_moves.is_empty():
		print("## rol: " + ", ".join(role_moves))
	for n: String in notes:
		print("## " + n)
	car.queue_free()
	await process_frame


static func _points(mesh: MeshInstance3D) -> PackedVector3Array:
	var out: PackedVector3Array = PackedVector3Array()
	if mesh.mesh == null:
		return out
	for s: int in mesh.mesh.get_surface_count():
		var verts: PackedVector3Array = mesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
		var step: int = maxi(1, verts.size() / SAMPLE)
		for i: int in range(0, verts.size(), step):
			out.append(mesh.transform * verts[i])
	return out


static func _pct(values: PackedFloat32Array, q: float) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(int(float(values.size() - 1) * q), 0, values.size() - 1)]


static func _albedo(meshes: Array) -> Image:
	for m: MeshInstance3D in meshes:
		var mat: BaseMaterial3D = m.mesh.surface_get_material(0) as BaseMaterial3D if m.mesh else null
		if mat and mat.albedo_texture:
			var img: Image = mat.albedo_texture.get_image()
			if img.is_compressed():
				img.decompress()
			return img
	return null


static func _mean_color(mesh: MeshInstance3D, img: Image) -> Color:
	if img == null or mesh.mesh == null:
		return Color.GRAY
	var uvs: PackedVector2Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	if uvs.is_empty():
		return Color.GRAY
	var acc: Color = Color(0, 0, 0)
	var n: int = 0
	var step: int = maxi(1, uvs.size() / 400)
	for i: int in range(0, uvs.size(), step):
		var uv: Vector2 = uvs[i]
		acc += img.get_pixel(clampi(int(uv.x * img.get_width()), 0, img.get_width() - 1),
			clampi(int(uv.y * img.get_height()), 0, img.get_height() - 1))
		n += 1
	return Color(acc.r / n, acc.g / n, acc.b / n)
