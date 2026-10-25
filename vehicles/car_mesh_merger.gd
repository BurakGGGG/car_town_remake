class_name CarMeshMerger
extends RefCounted
## ARAÇ PARÇALARINI BİRLEŞTİRİR — çizim çağrısı bütçesi için.
##
## Sorun (ölçüldü 2026-10-10): araç GLB'leri 47–80 ayrı parça mesh'i, ama CarRig'in rol başına
## atadığı yalnızca 5–11 farklı materyal var. Her parça ayrı çizim çağrısı: altı sergi aracı tek
## başına 413 çizim çağrısı ve 685k üçgen (dekorlu garajın %62'si). Zayıf telefonda (GL
## Compatibility, PowerVR) darboğaz tam olarak çizim çağrısı sayısıdır.
##
## Çözüm: AYNI MATERYALİ kullanan parçalar tek yüzeyde birleşir (materyal başına bir çizim).
## Geometri araç MODELİ başına bir kez kurulur ve önbellekte paylaşılır; materyaller örnek başına
## surface override olarak kalır (boya / far / cam ayarları bozulmaz).
##
## LOD KORUNUR: içe aktarılmış her parçanın LOD indeksleri (RenderingServer.mesh_get_surface)
## okunur; birleşik yüzeye birkaç ortak eşikte LOD kademesi kurulur. Her kademede bir parça, o
## eşiğe izin verilen EN KABA LOD'unu kullanır (hiçbir parça özgün hâlinden daha kaba çizilmez).
## `far_lod` istenirse ve modelin uzak kademe dosyası varsa (CarFarLod) onun kademesi kendi sapma eşiğine girer (bkz.
## _merge_group; yalnız şehir araçları, CarRig.optimize).
##
## İŞ PARÇACIĞI GÜVENLİĞİ (ölçüldü): GPU'ya dokunan çağrılar (mesh okuma / yükleme) GL
## Compatibility'de YALNIZCA ana iş parçacığında güvenli — arka planda yapılınca işler takılıyor,
## oyun kapanamıyordu (telefonda çökme olurdu). Bu yüzden üç aşama:
##   1) ANA, kare başına ~READ_BUDGET_MS: parça dizileri + LOD indeks baytları okunur;
##   2) ARKA PLAN (WorkerThreadPool): yalnızca düz veri — dizi birleştirme, indeks kaydırma, LOD çözme;
##   3) ANA, kare başına bir yüzey: add_surface_from_arrays.
## Bir model masaüstünde toplam ~50-85 ms işti; böylece hiçbir karede birkaç ms'den fazla sürmez.
## Aynı modelin bekleyen istekleri tek işte birleşir.

## Birleşik yüzeyde en fazla bu kadar LOD kademesi (her biri ayrı 16 bit indeks tamponu). Az kademe
## kaba geçiş demek: 2 kademede araçlar gereğinden detaylı kademede kalıp üçgen %20-35 artıyordu.
const MAX_LEVELS: int = 4
## Bir yüzeyin en çok köşe sayısı: Godot bunun altında 16 bit, üstünde 32 bit indeks kullanır.
## Büyük grup bu sınırın altında parçalara bölünür → indeks belleği yarı (araç başına +1-2 çizim).
const MAX_SURFACE_VERTICES: int = 65536
## Önbellekte tutulan en çok model (en son kullanılan; model başına ~3,5 MB). Trafikte modeller dönüp durduğu için zayıf
## referans aynı modeli tekrar tekrar birleştirirdi; sınırsız önbellek de bellek şişirir. Kaliteye göre (GameSettings):
## DÜŞÜK 8 (zayıf telefon), ORTA 12, YÜKSEK 16 — garaj ekranında 13 model var, 8'lik önbellek her açılışta 5+ modeli
## yeniden birleştiriyordu (yüzlerce GPU okuması). 2026-10-25'te birleştirme sızıntısı kapandığı için bellek payı açıldı.
const CACHE_BY_QUALITY: Array[int] = [8, 12, 16]
## Aşama 1'de bir karede parça okumaya ayrılan süre. Karenin İLK okuması sayılmaz: GPU tamponunu okumak (Compatibility:
## glGetBufferSubData / glMapBufferRange) sürücüyü GPU'nun sıradaki işini bitirmesini beklemeye zorlar; ilk okuma bu
## beklemeyi öder (masaüstünde drag ekranı açılırken ~3,5 ms), aynı karedeki sonraki okumalar yalnız kopyadır. Eskiden
## bekleme bütçeyi tek başına aştığı için her karede tek parça okunuyor, model başına 40–60 kare GPU senkronu oluyordu.
const READ_BUDGET_MS: float = 2.0

## Önbellek: anahtar → ArrayMesh; _order en son kullanılan sonda.
static var _cache: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()
## Süren işler: anahtar → {"callbacks", "parts", "groups", "read", "data", "stage", "result", "built"}
static var _jobs: Dictionary = {}
static var _pumping: bool = false
## Arka plan → ana devir teslimi ("stage" / "result") bu kilitle: Dictionary iş parçacığı güvenli değil.
static var _lock: Mutex = Mutex.new()


## Birleşik mesh'i ister; hazır olunca `callback.call(mesh)` ANA iş parçacığında çağrılır (önbellekte
## varsa hemen). `parts`: [[Mesh, yüzey, köke göre Transform3D, grup, LOD hata sınırı], …] — düğüm DEĞİL kaynak.
## Hata sınırı (isteğe bağlı, mesh uzayında): parçanın edge_length'i bunu aşan kademeleri kullanılmaz (tekerler,
## bkz. CarRig.WHEEL_LOD_ERROR).
## `threaded` false ise aynı karede kurulur (test / araç). `far_lod`: araç uzak kademesi (CarFarLod) eklensin mi.
static func request(key: String, parts: Array, group_count: int, callback: Callable,
		threaded: bool = true, far_lod: bool = false) -> void:
	if _cache.has(key):
		_touch(key)
		callback.call(_cache[key])
		return
	if _jobs.has(key):
		(_jobs[key]["callbacks"] as Array).append(callback)
		return
	if not threaded:
		var mesh: ArrayMesh = build(parts, group_count, far_lod)
		if mesh:
			_store(key, mesh)
		callback.call(mesh)
		return
	_jobs[key] = {"callbacks": [callback], "parts": parts, "groups": group_count, "read": 0,
		"data": [], "stage": 0, "result": [], "built": null, "far": far_lod}
	if not _pumping:
		_pumping = true
		(Engine.get_main_loop() as SceneTree).process_frame.connect(_pump)


## Aynı karede baştan sona kurar (aşamalar ardışık; test ve araçlar için). Okunamayan parça varsa null.
static func build(parts: Array, group_count: int, far_lod: bool = false) -> ArrayMesh:
	var data: Array = []
	for part: Array in parts:
		data.append(_read(part, far_lod))
	if not data.all(_readable):
		return null
	var mesh: ArrayMesh = ArrayMesh.new()
	for group: Array in _merge(data, group_count):
		_upload(mesh, group)
	return mesh


static func clear_cache() -> void:
	_cache.clear()
	_order.clear()


## Süren iş var mı (test / QA)?
static func busy() -> bool:
	return not _jobs.is_empty()


# --- Aşama makinesi (ana iş parçacığı, her kare) ---------------------------------------

static func _pump() -> void:
	var start: int = Time.get_ticks_usec()
	var synced: bool = false
	for key: String in _jobs.keys():
		var job: Dictionary = _jobs[key]
		_lock.lock()
		var stage: int = int(job["stage"])
		_lock.unlock()
		match stage:
			0:   # parça okuma (bütçeli)
				var parts: Array = job["parts"]
				while int(job["read"]) < parts.size():
					(job["data"] as Array).append(_read(parts[int(job["read"])], bool(job["far"])))
					job["read"] = int(job["read"]) + 1
					if not synced:
						synced = true
						start = Time.get_ticks_usec()   # GPU beklemesi ödendi: bütçe kopyalamaya
					if float(Time.get_ticks_usec() - start) / 1000.0 > READ_BUDGET_MS:
						return
				# Okunamayan parça: iş bırakılır, araç parçalı kalır (geri çağrı yok). Arka plandaki _merge boş diziyi
				# çeviremeyip yarıda kalıyordu; iş "arka planda" aşamasında sonsuza dek takılı kalıyordu (busy() hep true).
				if not (job["data"] as Array).all(_readable):
					_jobs.erase(key)
					continue
				_lock.lock()
				job["stage"] = 1
				_lock.unlock()
				job["task"] = WorkerThreadPool.add_task(_work.bind(job), false, "CarMeshMerger")
			1:   # arka planda
				pass
			2:   # yükleme: kare başına bir yüzey
				if job.has("task"):
					# Havuz, beklenmeyen görevin verisini (bağlı iş sözlüğü: parça dizileri, birleşik mesh) SALIVERMEZ:
					# her birleştirme bellekte kalıyordu — garaj her açılışta ~30 MB RAM + ~20 MB VRAM büyüyordu
					# (qa/sizinti_olcum.gd, 2026-10-25). Görev bitti (aşama 2): bekleme anında döner.
					WorkerThreadPool.wait_for_task_completion(int(job["task"]))
					job.erase("task")
				if job["built"] == null:
					job["built"] = ArrayMesh.new()
				var groups: Array = job["result"]
				if not groups.is_empty():
					_upload(job["built"], groups.pop_front())
					return
				_jobs.erase(key)
				var mesh: ArrayMesh = job["built"]
				_store(key, mesh)
				for callback: Callable in job["callbacks"]:
					if callback.is_valid():
						callback.call(mesh)
				return
	if _jobs.is_empty():
		(Engine.get_main_loop() as SceneTree).process_frame.disconnect(_pump)
		_pumping = false


## Arka plan: düz veriyle birleştirme. Sonuç yazıldıktan SONRA aşama 2'ye geçilir (ana iş parçacığı
## "stage"i okuyunca sonuç hazırdır).
static func _work(job: Dictionary) -> void:
	var result: Array = _merge(job["data"], int(job["groups"]))
	_lock.lock()
	job["result"] = result
	job["data"] = []   # parça dizileri artık gereksiz (model başına birkaç MB)
	job["stage"] = 2
	_lock.unlock()


static func _store(key: String, mesh: ArrayMesh) -> void:
	_cache[key] = mesh
	_touch(key)
	while _order.size() > CACHE_BY_QUALITY[clampi(GameSettings.active_quality(), 0, CACHE_BY_QUALITY.size() - 1)]:
		_cache.erase(_order[0])
		_order.remove_at(0)


static func _touch(key: String) -> void:
	var at: int = _order.find(key)
	if at >= 0:
		_order.remove_at(at)
	_order.append(key)


# --- Aşamalar -------------------------------------------------------------------------

## 1) ANA: parçanın dizileri + LOD'ları (eşik, indeks baytları) + indeks genişliği.
static func _read(part: Array, far_lod: bool) -> Dictionary:
	var source: Mesh = part[0]
	var surface: int = part[1]
	var xf: Transform3D = part[2]
	var raw: Dictionary = RenderingServer.mesh_get_surface(source.get_rid(), surface)
	var scale: float = maxf(xf.basis.get_scale().abs().x, 0.0001)
	var limit: float = float(part[4]) if part.size() > 4 else INF
	var lods: Array = []
	for lod: Dictionary in raw.get("lods", []):
		if float(lod["edge_length"]) > limit:
			continue
		lods.append([float(lod["edge_length"]) * scale, lod["index_data"]])
	# Uzak kademe (CarFarLod): sınırlı parçada (tekerler) yalnız sapması sınırın içindeyse
	var far: Array = CarFarLod.lookup(source, surface) if far_lod else []
	if not far.is_empty() and float(far[0]) > limit:
		far = []
	if not far.is_empty():
		far[0] = float(far[0]) * scale
	return {"arrays": source.surface_get_arrays(surface), "lods": lods, "far": far, "xf": xf, "group": part[3],
		"wide": int(raw.get("vertex_count", 0)) > 65536}


## Parçanın dizileri okunabildi mi: sahte işleyicide (--headless) yüzey verisi boş döner.
static func _readable(item: Dictionary) -> bool:
	var arrays: Array = item["arrays"]
	return arrays.size() > Mesh.ARRAY_VERTEX and arrays[Mesh.ARRAY_VERTEX] is PackedVector3Array


## 2) ARKA PLAN: grup başına birleşik diziler + LOD indeksleri. Dönen: [[arrays, lods, grup], …]
## — bir grup MAX_SURFACE_VERTICES'i aşarsa birden çok yüzeye bölünür (aynı grup = aynı materyal).
static func _merge(data: Array, group_count: int) -> Array:
	var out: Array = []
	for group: int in group_count:
		var chunk: Array = []
		var chunk_vertices: int = 0
		for item: Dictionary in data:
			if int(item["group"]) != group:
				continue
			var count: int = ((item["arrays"] as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
			if not chunk.is_empty() and chunk_vertices + count > MAX_SURFACE_VERTICES:
				out.append(_merge_group(chunk) + [group])
				chunk = []
				chunk_vertices = 0
			chunk.append(item)
			chunk_vertices += count
		if not chunk.is_empty():
			out.append(_merge_group(chunk) + [group])
	return out


static func _merge_group(members: Array) -> Array:
	# Ortak öznitelikler: tüm parçalarda olanlar (bir parçada yoksa o öznitelik grupta düşer)
	var keep: Dictionary = {Mesh.ARRAY_NORMAL: true, Mesh.ARRAY_TEX_UV: true, Mesh.ARRAY_TANGENT: true,
		Mesh.ARRAY_COLOR: true, Mesh.ARRAY_TEX_UV2: true}
	for item: Dictionary in members:
		var arrays: Array = item["arrays"]
		for attribute: int in keep.keys():
			if arrays[attribute] == null:
				keep.erase(attribute)
	var edges: PackedFloat32Array = PackedFloat32Array()
	var far_edge: float = 0.0
	for item: Dictionary in members:
		for lod: Array in item["lods"]:
			edges.append(float(lod[0]))
		if CarFarLod.matches(item["far"], (item["arrays"] as Array)[Mesh.ARRAY_VERTEX]):
			far_edge = maxf(far_edge, float(item["far"][0]))
		else:
			item["far"] = []
	var thresholds: PackedFloat32Array = _thresholds(edges)
	# Uzak kademe (CarFarLod) GERÇEK sapmasının eşiğinde: içe aktarıcının bundan büyük eşikli kademelerini geçer (daha az
	# sapma, daha az üçgen), onlar düşer. Eşik eskiden en kaba kademenin üstündeydi: o eşik küçük parçaların aşırı
	# sadeleşmiş zinciri yüzünden çok büyük, kademe yalnız zorla en kaba kipte (lod_bias 0) çiziliyordu, şehirde hiç.
	# Bu kademede uzak indeksi olmayan parça (teker) eşiğe uyan en kaba kademesini kullanır. Zorla en kaba kip (garajın
	# uzak araçları) için en sona eski en kaba kademe kalır: uzak indeksler + ötekilerin en kaba kademesi.
	var far_level: int = -1
	var coarse_level: int = -1
	if far_edge > 0.0:
		var top: float = thresholds[thresholds.size() - 1] if not thresholds.is_empty() else 0.0
		var kept: PackedFloat32Array = PackedFloat32Array()
		for threshold: float in thresholds:
			if threshold < far_edge:
				kept.append(threshold)
		far_level = kept.size()
		kept.append(far_edge)
		if top > far_edge * 1.25:
			coarse_level = kept.size()
			kept.append(top)
		thresholds = kept

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var uv2s: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var tangents: PackedFloat32Array = PackedFloat32Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var lod_indices: Array[PackedInt32Array] = []
	for t: float in thresholds:
		lod_indices.append(PackedInt32Array())
	for item: Dictionary in members:
		var arrays: Array = item["arrays"]
		var xf: Transform3D = item["xf"]
		var offset: int = vertices.size()
		vertices.append_array(xf * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array))
		if keep.has(Mesh.ARRAY_NORMAL):
			var rotation: Transform3D = Transform3D(xf.basis.orthonormalized(), Vector3.ZERO)
			normals.append_array(rotation * (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array))
		if keep.has(Mesh.ARRAY_TEX_UV):
			uvs.append_array(arrays[Mesh.ARRAY_TEX_UV])
		if keep.has(Mesh.ARRAY_TEX_UV2):
			uv2s.append_array(arrays[Mesh.ARRAY_TEX_UV2])
		if keep.has(Mesh.ARRAY_COLOR):
			colors.append_array(arrays[Mesh.ARRAY_COLOR])
		if keep.has(Mesh.ARRAY_TANGENT):
			tangents.append_array(arrays[Mesh.ARRAY_TANGENT])
		var source_index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null \
			else _sequence((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
		_append_offset(indices, source_index, offset)
		var far_indices: PackedInt32Array = PackedInt32Array()   # bir kez çözülür, iki kademeye (uzak / en kaba) girer
		if not (item["far"] as Array).is_empty():
			CarFarLod.append_decoded(far_indices, item["far"][3], int(item["far"][1]), offset)
		for k: int in thresholds.size():
			if (k == far_level or k == coarse_level) and not far_indices.is_empty():
				lod_indices[k].append_array(far_indices)
				continue
			var bytes: PackedByteArray = _coarsest(item["lods"], thresholds[k])
			if bytes.is_empty():
				_append_offset(lod_indices[k], source_index, offset)
			else:
				_append_bytes(lod_indices[k], bytes, bool(item["wide"]), offset)
	var arrays_out: Array = []
	arrays_out.resize(Mesh.ARRAY_MAX)
	arrays_out[Mesh.ARRAY_VERTEX] = vertices
	if keep.has(Mesh.ARRAY_NORMAL):
		arrays_out[Mesh.ARRAY_NORMAL] = normals
	if keep.has(Mesh.ARRAY_TEX_UV):
		arrays_out[Mesh.ARRAY_TEX_UV] = uvs
	if keep.has(Mesh.ARRAY_TEX_UV2):
		arrays_out[Mesh.ARRAY_TEX_UV2] = uv2s
	if keep.has(Mesh.ARRAY_COLOR):
		arrays_out[Mesh.ARRAY_COLOR] = colors
	if keep.has(Mesh.ARRAY_TANGENT):
		arrays_out[Mesh.ARRAY_TANGENT] = tangents
	arrays_out[Mesh.ARRAY_INDEX] = indices
	var lods: Dictionary = {}
	for k: int in thresholds.size():
		lods[thresholds[k]] = lod_indices[k]
	return [arrays_out, lods]


## 3) ANA: grubu GPU'ya yükler. İçe aktarılan araçlar gibi sıkıştırılmış öznitelik (yarım hassasiyet
## normal / UV): bellek ~yarı.
## Yüzey → grup eşlemesi mesh'in "groups" meta'sında (CarRig materyalleri buna göre takar).
static func _upload(mesh: ArrayMesh, group: Array) -> void:
	var arrays: Array = group[0]
	var flags: int = Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES if arrays[Mesh.ARRAY_NORMAL] != null else 0
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], group[1], flags)
	var groups: PackedInt32Array = mesh.get_meta(&"groups", PackedInt32Array())
	groups.append(int(group[2]))
	mesh.set_meta(&"groups", groups)


## Birleşik mesh'in yüzey `surface`'ı hangi materyal grubuna ait?
static func group_of(mesh: Mesh, surface: int) -> int:
	var groups: PackedInt32Array = mesh.get_meta(&"groups", PackedInt32Array())
	return groups[surface] if surface < groups.size() else surface


# --- Yardımcılar (düz veri; iş parçacığında güvenli) -------------------------------------

## Ortak eşikler: tüm parçaların LOD eşiklerinin dağılımından en çok MAX_LEVELS değer.
static func _thresholds(edges: PackedFloat32Array) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	if edges.is_empty():
		return out
	edges.sort()
	for q: float in [0.25, 0.5, 0.75, 1.0]:
		var value: float = edges[clampi(int(round(q * float(edges.size() - 1))), 0, edges.size() - 1)]
		if out.is_empty() or value > out[out.size() - 1] * 1.05:
			out.append(value)
		if out.size() >= MAX_LEVELS:
			break
	return out


## Eşiğe izin verilen en kaba LOD'un indeksleri; hiçbiri uymuyorsa boş (LOD0 kullanılır).
static func _coarsest(lods: Array, threshold: float) -> PackedByteArray:
	var best: PackedByteArray = PackedByteArray()
	for lod: Array in lods:
		if float(lod[0]) <= threshold:
			best = lod[1]
	return best


static func _append_offset(target: PackedInt32Array, source: PackedInt32Array, offset: int) -> void:
	if offset == 0:
		target.append_array(source)   # grubun ilk parçası: kaydırma yok, tek kopya
		return
	var base: int = target.size()
	target.resize(base + source.size())
	for i: int in source.size():
		target[base + i] = source[i] + offset


## Ham LOD indeksleri (16 ya da 32 bit, küçük uçlu) → kaydırılmış int32.
static func _append_bytes(target: PackedInt32Array, bytes: PackedByteArray, wide: bool, offset: int) -> void:
	if wide:
		_append_offset(target, bytes.to_int32_array(), offset)
		return
	var count: int = bytes.size() / 2
	var base: int = target.size()
	target.resize(base + count)
	for i: int in count:
		target[base + i] = bytes.decode_u16(i * 2) + offset


static func _sequence(count: int) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	out.resize(count)
	for i: int in count:
		out[i] = i
	return out


## Parçanın köke göre dönüşümü (kök ağaçta olmasa da: ata zinciri çarpılır).
static func relative(node: Node3D, root: Node3D) -> Transform3D:
	var xf: Transform3D = Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
