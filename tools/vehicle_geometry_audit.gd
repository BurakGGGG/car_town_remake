extends SceneTree
## ARAÇ GEOMETRİ DENETİMİ — 16 aracın tekerlek/çamurluk/zemin teması ölçümü.
##   godot-4 --path . --script tools/vehicle_geometry_audit.gd            (tablo)
##   godot-4 --path . --script tools/vehicle_geometry_audit.gd -- <id>    (tek araç ayrıntı)
##
## Ölçülenler (araç YEREL uzayında, ölçek uygulanmadan):
##   - her tekerlek grubunun kutusu, merkezi, yarıçapı ve ZEMİN farkı (alt y)
##   - gövdenin (tekerlek olmayan parçalar) zemine göre yüksekliği
##   - PİVOT testi: teker 90° döndürülünce grubun merkezi kaydı mı?
##   - GÖVDE BAĞIMSIZLIĞI: teker dönerken tekerlek olmayan HİÇBİR mesh kıpırdamamalı
##   - ÇAMURLUK BULAŞMASI: tekerlek grubundaki bir mesh tekerlek kutusundan taşıyor mu?

## Zemin toleransı (model yerel birimi; araçlar 1.0 uzunluğa normalize → 0,005 ≈ 2 cm).
## 0,012 iken Toros (0,0114) "geçiyor" görünüyordu ama tekerleri gerçekten havadaydı.
const GROUND_TOL: float = 0.005
## Pivot kayma toleransı.
const PIVOT_TOL: float = 0.004
## Gövde kıpırdama toleransı (0 olmalı; sayısal gürültü payı).
const BODY_TOL: float = 0.0005
## Bir tekerlek mesh'i, grubun lastik kutusunun bu katından büyükse "çamurluk bulaşmış" sayılır.
const FENDER_FACTOR: float = 1.55


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_detail(StringName(args[0]))
	else:
		_table()
	quit(0)


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh:
		out.append(node)
	for c: Node in node.get_children():
		_meshes(c, out)


## Mesh'in kutusu, ARACIN kökü uzayında. (global_transform kullanılmaz: araç sahne ağacında
## işlenmeden ölçüm yapıldığı için zincir elle çarpılır.)
func _xform_to(node: Node3D, root: Node3D) -> Transform3D:
	var t: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


func _box_in_root(mesh: MeshInstance3D, root: Node3D) -> AABB:
	return _xform_to(mesh, root) * mesh.get_aabb()


func _merge(boxes: Array) -> AABB:
	var out: AABB = boxes[0]
	for i: int in range(1, boxes.size()):
		out = out.merge(boxes[i])
	return out


## Aracı kurar ve ölçüm için gereken her şeyi döndürür.
func _analyse(id: StringName) -> Dictionary:
	var path: String = CarCatalog.scene_path(id)
	var car: Node3D = (load(path) as PackedScene).instantiate()
	car.scale = Vector3.ONE
	car.position = Vector3.ZERO
	car.rotation = Vector3.ZERO
	get_root().add_child(car)
	var rig: CarRig = CarRig.for_node(car)
	rig.apply(CarAppearance.get_for(path))

	var all: Array[MeshInstance3D] = []
	_meshes(car, all)
	var groups: Array = rig.get("_wheel_groups")
	var wheel_meshes: Dictionary = {}     # mesh → grup indeksi
	for gi: int in groups.size():
		for m: MeshInstance3D in (groups[gi]["meshes"] as Array):
			wheel_meshes[m] = gi

	# --- tekerlek grupları
	var wheels: Array = []
	for gi: int in groups.size():
		var boxes: Array = []
		var oversize: Array = []
		var tyre: AABB = AABB()
		var first: bool = true
		for m: MeshInstance3D in (groups[gi]["meshes"] as Array):
			var b: AABB = _box_in_root(m, car)
			boxes.append(b)
			if first:
				tyre = b
				first = false
		var merged: AABB = _merge(boxes)
		# Çamurluk bulaşması: grubun ilk mesh'i (lastik) referans, diğerleri ondan çok büyükse şüpheli
		for i: int in boxes.size():
			var b: AABB = boxes[i]
			var ratio: float = maxf(b.size.y, b.size.z) / maxf(maxf(tyre.size.y, tyre.size.z), 0.0001)
			if ratio > FENDER_FACTOR or b.size.x > tyre.size.x * 3.0:
				oversize.append("%d(×%.1f)" % [i, ratio])
		wheels.append({
			"front": bool(groups[gi]["front"]),
			"box": merged,
			"center": merged.get_center(),
			"radius": maxf(merged.size.y, merged.size.z) * 0.5,
			"bottom": merged.position.y,
			"count": (groups[gi]["meshes"] as Array).size(),
			"oversize": oversize,
		})

	# --- gövde (tekerlek olmayan, görünür parçalar)
	var body_boxes: Array = []
	var body_meshes: Array[MeshInstance3D] = []
	for m: MeshInstance3D in all:
		if wheel_meshes.has(m) or not m.visible:
			continue
		body_meshes.append(m)
		body_boxes.append(_box_in_root(m, car))
	var body: AABB = _merge(body_boxes) if not body_boxes.is_empty() else AABB()
	var total: AABB = _merge([body] + wheels.map(func(w: Dictionary) -> AABB: return w["box"]))

	# --- PİVOT + GÖVDE BAĞIMSIZLIĞI: tekerleri 90° çevir, neyin kıpırdadığını ölç
	var before_body: Array = []
	for m: MeshInstance3D in body_meshes:
		before_body.append(_box_in_root(m, car))
	# PİVOT ölçümü NOKTA üzerinden yapılır: `Transform3D * AABB` döndürülmüş KUTUNUN sınırlarını
	# verir (37°'de kutu √2 büyür), geometriyi değil — kutuyla ölçmek her araçta sahte hata
	# üretiyordu. Mesh'in kutu MERKEZİ ise nokta olarak tam dönüşür, yani doğru sabittir:
	# pivot doğruysa bu nokta kıpırdamaz.
	var before_points: Array = []
	for gi: int in groups.size():
		var pts: Array = []
		for m: MeshInstance3D in (groups[gi]["meshes"] as Array):
			pts.append(_xform_to(m, car) * m.get_aabb().get_center())
		before_points.append(pts)
	# Birden çok açı denenir: yanlış EKSEN yalnızca belirli açılarda görünebilir.
	var body_moved: float = 0.0
	var moved_names: Array = []
	var pivot_drift: float = 0.0
	var satellite_drift: float = 0.0
	for angle: float in [37.0, 90.0, 143.0, 211.0, 305.0]:
		rig.set_wheel_spin(angle)
		for i: int in body_meshes.size():
			var after: AABB = _box_in_root(body_meshes[i], car)
			var d: float = (after.get_center() - (before_body[i] as AABB).get_center()).length() \
				+ (after.size - (before_body[i] as AABB).size).length()
			if d > BODY_TOL:
				body_moved = maxf(body_moved, d)
				if moved_names.size() < 6:
					moved_names.append("%s(%.4f @%.0f°)" % [body_meshes[i].name, d, angle])
		for gi: int in groups.size():
			var meshes_g: Array = groups[gi]["meshes"]
			for mi: int in meshes_g.size():
				var m: MeshInstance3D = meshes_g[mi]
				var after_point: Vector3 = _xform_to(m, car) * m.get_aabb().get_center()
				var drift: float = (after_point - ((before_points[gi] as Array)[mi] as Vector3)).length()
				# LASTİK (grubun en büyük üyesi) kendi ekseninde dönmeli: merkezi KIPIRDAMAZ.
				# Jant/göbek gibi eş merkezli üyeler de kıpırdamaz; biraz kaçık modellenmiş
				# bir göbek dönerken küçük bir yörünge çizer, bu görsel olarak DOĞRUdur
				# (tekere sabitlenmiş parça) — bu yüzden yalnızca lastik ölçülür.
				if mi == int(groups[gi]["tyre_index"]):
					pivot_drift = maxf(pivot_drift, drift)
				else:
					satellite_drift = maxf(satellite_drift, drift)
	# Direksiyon: ön tekerler Y ekseninde dönerken de gövde kıpırdamamalı.
	rig.set_wheel_spin(0.0)
	rig.set_steer(22.0)
	for i: int in body_meshes.size():
		var after_steer: AABB = _box_in_root(body_meshes[i], car)
		var ds: float = (after_steer.get_center() - (before_body[i] as AABB).get_center()).length()
		if ds > BODY_TOL:
			body_moved = maxf(body_moved, ds)
			if moved_names.size() < 8:
				moved_names.append("%s(%.4f direksiyon)" % [body_meshes[i].name, ds])
	rig.set_steer(0.0)
	rig.set_wheel_spin(0.0)

	car.free()
	return {
		"id": id, "wheels": wheels, "body": body, "total": total,
		"body_moved": body_moved, "moved_names": moved_names, "pivot_drift": pivot_drift,
		"satellite_drift": satellite_drift, "dropped": rig.get("_wheel_dropped"),
		"body_count": body_meshes.size(),
	}


func _status(data: Dictionary) -> Dictionary:
	var wheels: Array = data["wheels"]
	var ground_ok: bool = wheels.size() == 4
	var worst_ground: float = 0.0
	var fender: bool = false
	for w: Dictionary in wheels:
		worst_ground = maxf(worst_ground, absf(float(w["bottom"])))
		if not (w["oversize"] as Array).is_empty():
			fender = true
	ground_ok = ground_ok and worst_ground <= GROUND_TOL
	return {
		"ground": ground_ok, "worst_ground": worst_ground,
		"pivot": float(data["pivot_drift"]) <= PIVOT_TOL,
		"body": float(data["body_moved"]) <= BODY_TOL,
		"fender": not fender,
		"count": wheels.size() == 4,
	}


func _table() -> void:
	print("%-22s %4s %8s %8s %8s %8s %8s %8s %7s %6s %s" % ["araç", "tkr", "FL", "FR", "RL", "RR",
		"gövde", "pivot", "yarıçp", "elenen", "durum"])
	var fails: int = 0
	for entry: Dictionary in CarCatalog.all():
		var data: Dictionary = _analyse(entry["id"])
		var st: Dictionary = _status(data)
		var w: Array = data["wheels"]
		var g: Array = []
		for i: int in 4:
			g.append(float(w[i]["bottom"]) if i < w.size() else NAN)
		var flags: PackedStringArray = PackedStringArray()
		if not st["count"]: flags.append("TEKER%d" % w.size())
		if not st["ground"]: flags.append("ZEMİN")
		if not st["pivot"]: flags.append("PİVOT")
		if not st["body"]: flags.append("GÖVDE")
		if not st["fender"]: flags.append("ÇAMURLUK")
		var ok: bool = flags.is_empty()
		if not ok:
			fails += 1
		print("%-22s %4d %8.4f %8.4f %8.4f %8.4f %8.4f %8.4f %7.3f %6d %s" % [data["id"], w.size(),
			g[0], g[1], g[2], g[3], float((data["body"] as AABB).position.y),
			float(data["pivot_drift"]),
			float(w[0]["radius"]) if w.size() > 0 else 0.0,
			(data["dropped"] as PackedStringArray).size(),
			"PASS" if ok else "FAIL: " + ", ".join(flags)])
	print("--------")
	print("%d/16 araç geçti" % (16 - fails))


func _detail(id: StringName) -> void:
	var data: Dictionary = _analyse(id)
	var st: Dictionary = _status(data)
	print("=== %s ===" % id)
	var total: AABB = data["total"]
	print("toplam kutu: boy %.4f  en %.4f  yükseklik %.4f  (alt y %.4f)" % [
		total.size.z, total.size.x, total.size.y, total.position.y])
	print("gövde parça sayısı: %d, gövde alt y: %.4f" % [data["body_count"],
		float((data["body"] as AABB).position.y)])
	var names: Array = ["FL", "FR", "RL", "RR"]
	for i: int in (data["wheels"] as Array).size():
		var w: Dictionary = (data["wheels"] as Array)[i]
		print("%s: mesh %d | merkez (%.3f, %.3f, %.3f) | yarıçap %.4f | alt y %.4f | kutu %.3f×%.3f×%.3f%s" % [
			names[i] if i < 4 else "W%d" % i, w["count"], w["center"].x, w["center"].y, w["center"].z,
			w["radius"], w["bottom"], (w["box"] as AABB).size.x, (w["box"] as AABB).size.y,
			(w["box"] as AABB).size.z,
			"  ÇAMURLUK ŞÜPHESİ: " + str(w["oversize"]) if not (w["oversize"] as Array).is_empty() else ""])
	print("lastik pivot kayması: %.5f (%s) | eş merkezli üyelerin yörüngesi: %.5f" % [
		data["pivot_drift"], "OK" if st["pivot"] else "HATA", data["satellite_drift"]])
	print("tekerlek grubundan elenen parçalar: %s" % str(data["dropped"]))
	print("gövde kıpırdaması: %.5f (%s) %s" % [data["body_moved"],
		"OK" if st["body"] else "HATA", data["moved_names"]])
