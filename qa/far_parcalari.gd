extends SceneTree
## FAR ROLÜNÜN İÇİNDE NE VAR? Otomatik rol sınıflandırıcısı (2026-09-27 ikinci parti) kaporta
## parçalarını far rolüne koymuş olabilir — Civic ve Audi'de far ile kaporta dokusu BİREBİR aynı
## renk çıkıyor (Δparlaklık 0,001 / 0,002, bkz. qa/far_kontrast.gd). Öyleyse far materyalini
## koyulaştırmak kaportayı lekeler.
##
## Gerçek bir far: küçük, aracın ÖN ucuna yakın, yerden orta yükseklikte ve yanal olarak
## merkezden uzak (çift hâlinde). Bu betik her far parçasının kutusunu ve konumunu basar;
## şüphelileri (hacimce büyük ya da ön uçtan uzak) işaretler.
##
## Kullanım: godot-4 --headless --path . -s res://qa/far_parcalari.gd

## Aracın boyu 1,0'e normalize. Ön uçtan bu orandan daha geride olan parça far değildir.
const FRONT_ZONE: float = 0.30
## Far hacmi aracın kutu hacminin bu oranını aşamaz.
const MAX_VOLUME_RATIO: float = 0.010


func _init() -> void:
	for entry: Dictionary in CarCatalog.all():
		var path: String = entry["scene_path"]
		var map: Dictionary = CarPartMap.get_map(path)
		var list: Array = map.get(&"headlights", [])
		if list.is_empty():
			continue
		var root: Node3D = (load(path) as PackedScene).instantiate()
		var by_name: Dictionary = {}
		for m: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			by_name[m.name] = m
		var whole: AABB = _whole(by_name)
		# Modeller +Z bakar: ön uç = kutunun en büyük z'si
		var front_z: float = whole.position.z + whole.size.z
		var car_vol: float = maxf(whole.size.x * whole.size.y * whole.size.z, 1e-6)
		var rows: PackedStringArray = PackedStringArray()
		var bad: int = 0
		for index: int in list:
			var mi: MeshInstance3D = by_name.get("tripo_part_%d" % index)
			if mi == null:
				continue
			var b: AABB = _boxed(mi)
			var c: Vector3 = b.get_center()
			var vol: float = b.size.x * b.size.y * b.size.z / car_vol
			var depth: float = (front_z - c.z) / maxf(whole.size.z, 1e-6)   # 0 = tam ön uç
			var flags: String = ""
			if vol > MAX_VOLUME_RATIO:
				flags += "BÜYÜK "
			if depth > FRONT_ZONE:
				flags += "GERİDE "
			if flags != "":
				bad += 1
			rows.append("    %-16s hacim=%%%.2f  öndenDerinlik=%.2f  kutu=%.3f×%.3f×%.3f  %s" % [
				"tripo_part_%d" % index, vol * 100.0, depth, b.size.x, b.size.y, b.size.z, flags])
		root.free()
		print("%-22s far parçası=%d  şüpheli=%d" % [entry["id"], list.size(), bad])
		for r: String in rows:
			print(r)
	quit()


## Parçanın ARAÇ uzayındaki kutusu. `mesh.get_aabb()` yerel uzaydadır; optimize_car kök
## dönüşümü düğüme yazar (vertex'lere pişirmez), bu yüzden dönüşüm uygulanmadan hepsi aracın
## ortasında görünüyordu. Kutuyu dönüştürmek yerine 8 KÖŞE dönüştürülür — `Transform3D * AABB`
## döndürülmüş kutunun eksen hizalı sınırını verir ve şişirir.
static func _boxed(mi: MeshInstance3D) -> AABB:
	var b: AABB = mi.mesh.get_aabb()
	var xf: Transform3D = mi.transform
	var out: AABB = AABB(xf * b.position, Vector3.ZERO)
	for i: int in 8:
		out = out.expand(xf * (b.position + Vector3(
			b.size.x if (i & 1) else 0.0, b.size.y if (i & 2) else 0.0, b.size.z if (i & 4) else 0.0)))
	return out


static func _whole(by_name: Dictionary) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for m: MeshInstance3D in by_name.values():
		var b: AABB = _boxed(m)
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out
