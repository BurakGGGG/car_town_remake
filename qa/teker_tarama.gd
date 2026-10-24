extends SceneTree
## TEKER BOŞLUK TARAMASI — her tekerin dinlenme hâlinde (dönüş 0) yandan, dışarıdan render'ı.
## Yalnız o tekerin grubu çizilir (gövde ve öbür tekerler gizli), arka plan pembe: lastikte
## modellenmemiş yay varsa pembe görünür. Halkadaki (0,80–0,96 R) pembe pikseller 10°'lik dilimlere
## sayılır (ince: 5°); %25'ten fazlası pembe olan dilim "boşluk" olarak raporlanır (0° = yukarı, 90° = ön, 180° = alt).
## Çıktı: <klasör>/<id>.png (satırda fl fr rl rr) + konsolda "BOSLUK <id> <teker> <dilimler>" satırları.
## Kullanım: godot-4 --path . --display-driver x11 --resolution 240x240 -s res://qa/teker_tarama.gd -- <klasör> [lod=<katsayı>] [<id> ...]
##   lod=<katsayı>: bütün parçalara GeometryInstance3D.lod_bias (0 = en kaba kademe, garajın uzak sergi araçları gibi).
##   trim=<oran>: teker parçalarının LOD zincirinden hatası (edge_length) <oran> x lastik yarıçapını aşan kademeleri
##   at (lod=0 ile birlikte: kalan en kaba kademe çizilir).
##   spin=<derece>: tekerler bu açıya döndürülmüş; govde: gövde ve öbür tekerler de çizilir (boşluk sayımı anlamsızlaşır);
##   span=<kat>: kadraj lastik çapının bu katı (varsayılan 1,25).
##   bakis=<sapma>,<yükseklik>: kamera yönü derece — 0,0 = dışarıdan yan (varsayılan), 90 = önden, -90 = arkadan,
##   >90 = önden ve içeriden (aracın ortasına bakan yanak), 180 = tam içeriden (iç yanak boşluğu sayılır); yükseklik + =
##   yukarıdan. Boşluk sayımı yalnız 0 ve 180'de.
##   merge / merge_old: her teker grubu garajdaki sergi araçları gibi CarMeshMerger ile birleşir ve en kaba kademede
##   (lod_bias 0) çizilir; merge CarRig'in teker LOD sınırıyla (WHEEL_LOD_ERROR), merge_old sınırsız (eski davranış).

const TILE: int = 240
var bins: int = 36   # ince → 72 (5°)
const BAND: Vector2 = Vector2(0.80, 0.96)
const GAP_RATIO: float = 0.25
const BG: Color = Color(1.0, 0.0, 1.0)


func _initialize() -> void:
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var ids: Array[StringName] = []
	var lod_bias: float = -1.0
	var trim: float = -1.0
	var merge: String = ""
	var spin: float = 0.0
	var body: bool = false
	var span_k: float = 1.25
	var view_yaw: float = 0.0
	var view_pitch: float = 0.0
	for i: int in range(1, args.size()):
		if args[i].begins_with("lod="):
			lod_bias = float(args[i].trim_prefix("lod="))
		elif args[i].begins_with("trim="):
			trim = float(args[i].trim_prefix("trim="))
		elif args[i].begins_with("spin="):
			spin = float(args[i].trim_prefix("spin="))
		elif args[i].begins_with("span="):
			span_k = float(args[i].trim_prefix("span="))
		elif args[i].begins_with("bakis="):
			var angles: PackedStringArray = args[i].trim_prefix("bakis=").split(",")
			view_yaw = float(angles[0])
			view_pitch = float(angles[1]) if angles.size() > 1 else 0.0
		elif args[i] == "ince":
			bins = 72
		elif args[i] == "govde":
			body = true
		elif args[i] in ["merge", "merge_old"]:
			merge = args[i]
		else:
			ids.append(StringName(args[i]))
	if ids.is_empty():
		for entry: Dictionary in CarCatalog.all():
			ids.append(entry["id"])
	var stage: Node3D = Node3D.new()
	root.add_child(stage)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = Environment.new()
	we.environment.background_mode = Environment.BG_COLOR
	we.environment.background_color = BG
	we.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	we.environment.ambient_light_color = Color.WHITE
	we.environment.ambient_light_energy = 0.9
	stage.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.basis = Basis.looking_at(Vector3(-0.3, -0.6, -0.7).normalized(), Vector3.UP)
	stage.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.near = 0.001
	cam.far = 10.0
	stage.add_child(cam)
	cam.current = true
	for id: StringName in ids:
		var car: Node3D = (load(CarCatalog.scene_path(id)) as PackedScene).instantiate()
		stage.add_child(car)
		var rig: CarRig = CarRig.for_node(car)
		rig.apply(CarAppearance.get_for(car.scene_file_path))
		rig.set_wheel_spin(spin)
		if trim >= 0.0:
			for group: Dictionary in rig._wheel_groups:
				var tyre_mesh: MeshInstance3D = group["meshes"][0]
				var tyre_box: AABB = tyre_mesh.transform * tyre_mesh.get_aabb()
				var limit: float = trim * maxf(tyre_box.size.y, tyre_box.size.z) * 0.5
				for member: MeshInstance3D in group["meshes"]:
					member.mesh = _trimmed(member.mesh, limit)
		if lod_bias >= 0.0:
			rig.set_lod_bias(lod_bias)
		var all: Array[MeshInstance3D] = []
		_meshes(car, all)
		var groups: Array = rig._wheel_groups
		var sheet: Image = Image.create(TILE * 4, TILE, false, Image.FORMAT_RGB8)
		sheet.fill(Color(0.2, 0.2, 0.2))
		for gi: int in groups.size():
			var group: Dictionary = groups[gi]
			var members: Array = group["meshes"]
			var visible: Array[bool] = []
			for mesh: MeshInstance3D in all:
				visible.append(mesh.visible)
				mesh.visible = (body or members.has(mesh)) and mesh.visible and merge == ""
			var merged: MeshInstance3D = null
			if merge != "":
				merged = _merged(car, rig, members, merge == "merge")
			var pivot: Vector3 = group["pivot"]
			var tyre: MeshInstance3D = members[int(group["tyre_index"])]
			var box: AABB = tyre.transform * tyre.get_aabb()
			var r: float = float(group.get("radius", maxf(box.size.y, box.size.z) * 0.5))   # ölçülmüş yarıçap (wheel_axes)
			var parent: Node3D = tyre.get_parent() as Node3D
			var world_pivot: Vector3 = parent.global_transform * pivot
			var side: float = signf(pivot.x) if absf(pivot.x) > 0.001 else 1.0
			var span: float = r * 2.0 * span_k
			cam.size = span
			var yaw: float = deg_to_rad(view_yaw)
			var pitch: float = deg_to_rad(view_pitch)
			var toward: Vector3 = Vector3(side * cos(yaw) * cos(pitch), sin(pitch), sin(yaw) * cos(pitch))
			cam.position = world_pivot + toward * 1.5
			cam.look_at(world_pivot, Vector3.UP)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img: Image = get_root().get_texture().get_image()
			img.convert(Image.FORMAT_RGB8)
			var tile: Image = img.get_region(Rect2i((img.get_width() - TILE) / 2, (img.get_height() - TILE) / 2, TILE, TILE))
			# içeriden (bakis=180) bakınca ekran ekseni aynalanır; boşluk sayımı yalnız tam yan bakışlarda
			var gaps: PackedStringArray = PackedStringArray()
			if view_pitch == 0.0 and (view_yaw == 0.0 or view_yaw == 180.0):
				gaps = _gaps(tile, r / span * float(TILE), -side if view_yaw == 180.0 else side)
			var key: String = ["fl", "fr", "rl", "rr"][gi] if groups.size() == 4 else str(gi)
			if not gaps.is_empty():
				print("BOSLUK %s %s %s" % [id, key, " ".join(gaps)])
			sheet.blit_rect(tile, Rect2i(0, 0, TILE, TILE), Vector2i(gi * TILE, 0))
			for i: int in all.size():
				all[i].visible = visible[i]
			if merged:
				merged.free()
		sheet.save_png(out_dir.path_join(String(id) + ".png"))
		car.queue_free()
		await process_frame
	print("BITTI")
	quit()


## Halkadaki pembe piksel oranı açı dilimlerinde. Görüntüde yukarı = +Y; kamera +X'ten bakınca
## ekranın sağı aracın arkası (-Z), -X'ten bakınca önü (+Z).
func _gaps(tile: Image, r_px: float, side: float) -> PackedStringArray:
	var total: PackedInt32Array = PackedInt32Array()
	var empty: PackedInt32Array = PackedInt32Array()
	total.resize(bins)
	empty.resize(bins)
	var c: float = float(TILE) * 0.5
	for y: int in TILE:
		for x: int in TILE:
			var dx: float = float(x) + 0.5 - c
			var dy: float = c - (float(y) + 0.5)
			var d: float = sqrt(dx * dx + dy * dy) / r_px
			if d < BAND.x or d > BAND.y:
				continue
			var front: float = dx if side < 0.0 else -dx   # +Z yönündeki ekran ekseni
			var deg: float = fposmod(rad_to_deg(atan2(front, dy)), 360.0)
			var b: int = int(deg / (360.0 / bins)) % bins
			total[b] += 1
			var p: Color = tile.get_pixel(x, y)
			if p.r > 0.9 and p.g < 0.1 and p.b > 0.9:
				empty[b] += 1
	var out: PackedStringArray = PackedStringArray()
	for b: int in bins:
		if total[b] > 0 and float(empty[b]) / float(total[b]) > GAP_RATIO:
			out.append("%d:%d%%" % [b * 360 / bins, roundi(100.0 * empty[b] / total[b])])
	return out


## Grubun parçaları tek mesh'te (CarMeshMerger), en kaba kademede. Materyal lastiğinki (geometri denetimi).
func _merged(car: Node3D, rig: CarRig, members: Array, limited: bool) -> MeshInstance3D:
	var parts: Array = []
	for mesh: MeshInstance3D in members:
		for surface: int in mesh.mesh.get_surface_count():
			parts.append([mesh.mesh, surface, CarMeshMerger.relative(mesh, car), 0,
				rig._wheel_lod_limit.get(mesh, INF) if limited else INF])
	var out: MeshInstance3D = MeshInstance3D.new()
	out.mesh = CarMeshMerger.build(parts, 1)
	out.material_override = (members[0] as MeshInstance3D).get_active_material(0)
	out.lod_bias = 0.0
	car.add_child(out)
	return out


## Mesh'in hatası `limit`i aşan LOD kademeleri atılmış kopyası.
func _trimmed(source: Mesh, limit: float) -> ArrayMesh:
	var out: ArrayMesh = ArrayMesh.new()
	for s: int in source.get_surface_count():
		var raw: Dictionary = RenderingServer.mesh_get_surface(source.get_rid(), s)
		var wide: bool = int(raw.get("vertex_count", 0)) > 65536
		var lods: Dictionary = {}
		for lod: Dictionary in raw.get("lods", []):
			if float(lod["edge_length"]) > limit:
				continue
			var bytes: PackedByteArray = lod["index_data"]
			var idx: PackedInt32Array = PackedInt32Array()
			if wide:
				idx = bytes.to_int32_array()
			else:
				idx.resize(bytes.size() / 2)
				for i: int in idx.size():
					idx[i] = bytes.decode_u16(i * 2)
			lods[float(lod["edge_length"])] = idx
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(s), [], lods)
		out.surface_set_material(s, source.surface_get_material(s))
	return out


func _meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out.append(node)
	for child: Node in node.get_children():
		_meshes(child, out)
