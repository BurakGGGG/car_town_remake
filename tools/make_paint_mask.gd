extends SceneTree
## Araç boya maskesi üreticisi (headless Godot, harici bağımlılık yok).
## Dokulu araçlarda boya dokunun içine pişmiştir; hangi TEXEL'in boyanabileceğini bu maske belirler:
##   BEYAZ (255) = kaporta, boyanabilir      SİYAH (0) = doku aynen kalır (cam, far, stop, krom,
##   siyah trim, plaka, egzoz, anten, lastik, jant, ızgara)
## Maske aracın kendi UV düzenindedir (albedo ile aynı layout), varsayılan 1024².
##
## Nasıl üretilir (iki aşama, biri diğerini tamamlar):
##   1) GEOMETRİ: CarPartMap rollerine göre üçgenler UV uzayında rasterize edilir. "body" ve "mirrors"
##      aday (beyaz), cam / far / stop / teker / jant / lastik her zaman engel (siyah). Engel daima
##      kazanır, böylece UV'si çakışan parçalar boyayı sızdırmaz. Tampon/ızgara/plaka gibi PROMOTE_ROLES
##      rolleri, dokuda neredeyse tamamen fabrika boyası rengindeyse (kaporta rengi tampon) boyaya
##      yükseltilir — otomatik rol sınıflandırmasının "siyah trim" sandığı boyalı parçalar kurtarılır.
##   2) DOKU: Aday texel'lerin BASKIN renk kümesi (kromatiklik + parlaklık histogramı, alan × parlaklık ×
##      doygunluk puanı) fabrika boyasıdır. Her boya parçası bu renge göre ölçülür:
##        • parçanın texel'lerinin çoğu boyaysa (>= PART_PAINT_RATIO) parçanın TAMAMI boyanır — panel
##          içinde delik/leke kalmaz (kaportanın pişmiş gölgeleri, çizikleri, logoları korunur),
##        • hiçbiri değilse parça atlanır (yanlış role düşmüş trim),
##        • karışıksa (gövdeye KAYNAMIŞ cam/far/trim: BMW ve Getz ön camı, tek mesh Toros) texel bazında
##          elenir — renk tonu açısı + asimetrik parlaklık bandı.
##      Bulunan boya rengi rapor satırında yazılır; CarPartMap.default_paint ve cars.json default_color
##      bununla aynı olmalıdır (aksi halde "← GÜNCELLE" uyarısı çıkar).
##   3) TEMİZLİK: tekil lekeler atılır, küçük delikler doldurulur, kenar 1 texel içeri çekilir (VRAM
##      sıkıştırma blok taşmasına karşı) ve yumuşatılır.
##
## Kullanım:
##   godot-4 --headless --path . -s res://tools/make_paint_mask.gd -- --car bmw_e46
##   godot-4 --headless --path . -s res://tools/make_paint_mask.gd -- --all [--size 1024]
## Çıktı: assets/cars/optimized/<id>_paintmask.png  (CarRig bunu CarCatalog.optimized_path'ten bulur)

const DEFAULT_SIZE: int = 1024
## Parçanın texel'lerinin bu oranı boyaysa parça bütün olarak boyanır (panel içi delik oluşmaz);
## eşik yüksek tutulur, yoksa gövdeye kaynamış cam/far olan parça da bütün boyanır (BMW/Getz ön camı
## parçanın ~%40'ını kapladığı için bu eşiğin altında kalır ve texel bazında elenir).
const PART_PAINT_RATIO: float = 0.72
## Bu oranın altındaysa parça hiç boyanmaz (yanlış role düşmüş cam / trim / krom parçası).
const PART_SKIP_RATIO: float = 0.12
## Boya olmayan rollerden yükseltme: parçanın texel'lerinin bu oranı fabrika boyası rengindeyse
## (yalnızca doygun boyalarda; beyaz/gümüş araçta renk testi ayırt edemez) parça boyanabilir sayılır.
## Far/stop/cam/teker rolleri bu listede olmadığı için kırmızı bir stop lambası asla boyaya karışmaz;
## eşik gölgeli tamponları yakalayacak kadar düşük tutulur.
const PROMOTE_RATIO: float = 0.70
const PROMOTE_ROLES: Array[StringName] = [&"black_trim", &"grille", &"plate", &"fog_lights", &"exhaust", &"antenna"]
## YUMUŞAK engel rolleri: teker parçaları ve (yükseltilmeyen) trim. Tripo dokusunda bir texel'i birden çok
## parça paylaşabiliyor; Ferrari'nin lastik ve trim parçalarına çamurluk kenarından kırmızı üçgenler karışmıştı
## ve "engel her zaman kazanır" kuralı GÖVDENİN aynı texel'lerini boyasız bırakıyordu (maviye boyanınca
## kaputta / kenarlarda kırmızı çizgiler ve lekeler). Doygun boyalarda yumuşak engelin BOYA RENGİNDEKİ
## texel'i engel sayılmaz. Cam, far, stop ve gizli parçalar KATI engel olarak kalır; gümüş / beyaz boyada
## renk testi ayırt edemediği için yumuşak engel de tamamen engeldir (eski davranış).
const SOFT_BLOCK_ROLES: Array[StringName] = [&"wheels", &"tires", &"rims"]
## Renk tonu toleransı: texel ile boya vektörü arasındaki açı (radyan, ~14°). Açı ölçüsü doygun
## boyalarda da çalışır (kırmızının açık/koyu tonları aynı açıda kalır; RGB uzaklığı kalmaz).
const HUE_TOLERANCE: float = 0.25
## Boyadan bu kadar oktav koyu texel'ler hâlâ boya (pişmiş gölge), bu kadar açık olanlar parlama.
const SHADE_DARK: float = 2.6
## Doygun boyalarda (kırmızı Ferrari / Golf, yeşil GT3) panel kenarı ve kıvrımlardaki KOYU gölge bu kadar
## oktava kadar boya sayılır — tonu boyayla aynı ve doygunluğu en az DARK_SATURATION ise. Eskiden 2,6
## oktavın altı atlanıyordu: Ferrari maviye boyanınca kaputta ve kenarlarda kırmızı çizgiler kalıyordu.
## Siyah plastik doygun değildir (sat < 0,4), bu kurala girmez.
const SHADE_DARK_SATURATED: float = 5.0
const DARK_SATURATION: float = 0.55
const SHADE_LIGHT: float = 0.9
## Doygunluğu bunun altındaki texel'ler renk tonu testinden muaf (parlama/gölge boyayı soldurur);
## RENKLİ boyada bu muafiyet yalnızca dar bir parlaklık bandında geçerlidir (gri trim sızmasın).
const DESAT_LIMIT: float = 0.16
const DESAT_OCTAVE: float = 0.45
## Boyanın kendisi bu doygunluğun altındaysa (gümüş / beyaz / gri araç) renk tonu testi anlamsızdır.
const NEUTRAL_PAINT: float = 0.10
## Baskın renk aranırken bunun altındaki parlaklıklar sayılmaz (araç altı, derin gölge, siyah plastik).
const PAINT_MIN_LUMA: float = 0.10

var _size: int = DEFAULT_SIZE


func _init() -> void:
	var args: Dictionary = _parse_args()
	_size = int(args.get("size", DEFAULT_SIZE))
	var ids: Array[StringName] = []
	if args.has("all"):
		for entry: Dictionary in CarCatalog.all():
			ids.append(entry["id"])
	elif args.has("car"):
		ids.append(StringName(args["car"]))
	else:
		push_error("--car <id> ya da --all gerekli")
		quit(1)
		return
	for id: StringName in ids:
		_build(id)
	quit()


func _build(id: StringName) -> void:
	var entry: Dictionary = CarCatalog.get_entry(id)
	if entry.is_empty():
		push_error("katalogda yok: %s" % id)
		return
	var scene_path: String = entry["scene_path"]
	var map: Dictionary = CarPartMap.get_map(scene_path)
	if map.is_empty():
		push_error("CarPartMap yok: %s" % scene_path)
		return
	var root: Node3D = (load(scene_path) as PackedScene).instantiate() as Node3D
	get_root().add_child(root)

	# Rol → parça adı kümesi: boyalı / yükseltilebilir (tampon, ızgara...) / kesin engel (cam, far, teker)
	var paintable: Dictionary = {}
	var promotable: Dictionary = {}
	var blocked: Dictionary = {}
	var soft_names: Dictionary = {}
	for role: StringName in CarPartMap.ROLES:
		var target: Dictionary = blocked
		if role == &"body" or role == &"mirrors":
			target = paintable
		elif PROMOTE_ROLES.has(role):
			target = promotable
		elif SOFT_BLOCK_ROLES.has(role):
			target = soft_names
		for index: int in map.get(role, []):
			target[String(CarPartMap.part_name(index))] = true
	for spec: Dictionary in map.get("split_z", []):
		# Tek mesh'te iki rol: her iki yüzey de kendi rolüne göre işlenir (aşağıda yüzey bazlı)
		pass

	var albedo: Image = _albedo_image(root)
	if albedo == null:
		push_error("albedo dokusu yok: %s" % scene_path)
		root.queue_free()
		return
	var declared: Color = map.get("default_paint", Color.WHITE)

	# 1) Geometri: parça bazında aday maskeler + tüm engeller
	var block: PackedByteArray = PackedByteArray(); block.resize(_size * _size)
	var soft: PackedByteArray = PackedByteArray(); soft.resize(_size * _size)   # yumuşak engel (bkz. SOFT_BLOCK_ROLES)
	var parts: Array[Dictionary] = []   # {name, mask}
	var stats: Dictionary = {"paint_tris": 0, "block_tris": 0, "other_tris": 0}
	var pending: Array[Dictionary] = []   # yükseltme adayları: {name, mask}
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var is_paint: bool = paintable.has(mesh.name)
		var is_pending: bool = promotable.has(mesh.name)
		var part_mask: PackedByteArray = PackedByteArray()
		if is_paint or is_pending:
			part_mask.resize(_size * _size)
		var target: PackedByteArray = part_mask if (is_paint or is_pending) \
				else (soft if soft_names.has(mesh.name) else block)
		var key: String = "paint_tris" if is_paint else ("block_tris" if blocked.has(mesh.name) or is_pending else "other_tris")
		for si: int in mesh.mesh.get_surface_count():
			# Atlası KULLANMAYAN yüzey maskeye girmez: UV'si anlamsızdır ve engel olarak
			# rasterize edilirse bütün gövdeyi kapatabilir. (Toros'un Blender'da üretilen
			# tekerleri düz renk materyalle gelir; UV'leri 0-1'e yayıldığı için aday texel
			# sayısını 624.555 → 23.864'e düşürüyordu.)
			var surf_mat: BaseMaterial3D = mesh.mesh.surface_get_material(si) as BaseMaterial3D
			if surf_mat and surf_mat.albedo_texture == null:
				continue
			stats[key] += _rasterize(mesh.mesh.surface_get_arrays(si), target)
		if is_paint:
			parts.append({"name": mesh.name, "mask": part_mask})
		elif is_pending:
			pending.append({"name": mesh.name, "mask": part_mask})

	# 2) Doku: aday texel'lerin baskın rengi = fabrika boyası
	var scale: float = float(albedo.get_width()) / float(_size)
	var candidate: PackedByteArray = PackedByteArray(); candidate.resize(_size * _size)
	for part: Dictionary in parts:
		var pm: PackedByteArray = part["mask"]
		for i: int in pm.size():
			if pm[i] != 0 and block[i] == 0:
				candidate[i] = 255
	var samples: Array[Color] = []
	for i: int in candidate.size():
		if candidate[i] != 0:
			samples.append(_texel(albedo, i, scale))
	var paint: Color = _dominant_color(samples)

	# 3) Yükseltme: tampon / ızgara / plaka gibi parçalar dokuda kaporta rengindeyse boyaya alınır
	var promoted: PackedStringArray = PackedStringArray()
	var can_promote: bool = _saturation(paint) >= NEUTRAL_PAINT
	for part: Dictionary in pending:
		var pm: PackedByteArray = part["mask"]
		var total: int = 0
		var hits: int = 0
		for i: int in pm.size():
			if pm[i] == 0:
				continue
			total += 1
			if _is_paint(_texel(albedo, i, scale), paint):
				hits += 1
		if can_promote and total > 0 and float(hits) / float(total) >= PROMOTE_RATIO:
			parts.append(part)
			promoted.append(String(part["name"]).trim_prefix("tripo_part_"))
			for i: int in pm.size():
				if pm[i] != 0:
					candidate[i] = 255
		else:
			for i: int in pm.size():
				if pm[i] != 0:
					soft[i] = 255   # yükseltilmeyen trim: yumuşak engel
	# Yumuşak engel: doygun boyada boya rengindeki texel'i engel sayılmaz (paylaşılan kaporta texel'i)
	var saturated: bool = _saturation(paint) >= NEUTRAL_PAINT
	var released: int = 0
	for i: int in soft.size():
		if soft[i] == 0 or block[i] != 0:
			continue
		if saturated and candidate[i] != 0 and _is_paint(_texel(albedo, i, scale), paint):
			released += 1
			continue
		block[i] = 255
	if released > 0:
		print("        yumuşak engelden boyaya bırakılan texel: %d" % released)
	_dilate(block, 1)  # engel kenarını bir texel genişlet (UV dikişi boyayı sızdırmasın)
	for i: int in candidate.size():
		if block[i] != 0:
			candidate[i] = 0

	# 4) Parça kararı: tamamı boya / hiç / karışıksa texel bazında
	var mask: PackedByteArray = PackedByteArray(); mask.resize(_size * _size)
	var solid: PackedByteArray = PackedByteArray(); solid.resize(_size * _size)   # bütün boyanan parçalar
	var kept: int = 0
	var mixed: PackedStringArray = PackedStringArray()
	var skipped: PackedStringArray = PackedStringArray()
	for part: Dictionary in parts:
		var pm: PackedByteArray = part["mask"]
		var total: int = 0
		var hits: int = 0
		for i: int in pm.size():
			if pm[i] == 0 or block[i] != 0:
				continue
			total += 1
			if _is_paint(_texel(albedo, i, scale), paint):
				hits += 1
		if total == 0:
			continue
		var ratio: float = float(hits) / float(total)
		if ratio >= PART_PAINT_RATIO:
			for i: int in pm.size():
				if pm[i] != 0 and block[i] == 0:
					mask[i] = 255
					solid[i] = 255
					kept += 1
		elif ratio >= PART_SKIP_RATIO:
			mixed.append("%s(%%%.0f)" % [String(part["name"]).trim_prefix("tripo_part_"), ratio * 100.0])
			for i: int in pm.size():
				if pm[i] != 0 and block[i] == 0 and _is_paint(_texel(albedo, i, scale), paint):
					mask[i] = 255
					kept += 1
		else:
			skipped.append("%s(%%%.0f)" % [String(part["name"]).trim_prefix("tripo_part_"), ratio * 100.0])

	# 5) Temizlik: gürültüyü at, panel içindeki delikleri kapat (morfolojik kapama — yalnızca aday
	# alan içinde, böylece boya cama/trime taşmaz)
	# Temizlik yalnızca EKLER, var olanı silmez: ince UV şeritleri (panel kenarı, kaput çizgisi) kapamanın
	# daraltma adımında tamamen siliniyordu — kısıtlı genişletme şeridin dışına taşamadığı için daraltma onu
	# yiyordu (Ferrari maviye boyanınca kaputta ve kenarlarda kırmızı çizgiler). Gürültü temizliği de yalnızca
	# texel bazında elenen (karışık) parçaların benekleri içindir; bütün boyanan parçaya dokunmaz.
	_despeckle(mask)
	for i: int in mask.size():
		if solid[i] != 0:
			mask[i] = 255
	var before_close: PackedByteArray = mask.duplicate()
	_close_within(mask, candidate, 4)
	for i: int in mask.size():
		if before_close[i] != 0:
			mask[i] = 255
	_fill_holes(mask)
	# UV adası kenarlarına taşır (bilinear örnekleme ve ada sınırındaki üçgen kenarları boyasız
	# ince çizgiler bırakmasın); engel adalarına taşan kısım geri alınır
	_dilate(mask, 2)
	for i: int in mask.size():
		if block[i] != 0:
			mask[i] = 0
	# Teşhis: MASK_DEBUG=1 ile her boya parçasının texel dağılımı (engel / beyaz / boya renkli ama siyah)
	if OS.get_environment("MASK_DEBUG") != "":
		for part: Dictionary in parts:
			var pm2: PackedByteArray = part["mask"]
			var n_all: int = 0
			var n_block: int = 0
			var n_white: int = 0
			var n_red_lost: int = 0
			for i: int in pm2.size():
				if pm2[i] == 0:
					continue
				n_all += 1
				if block[i] != 0:
					n_block += 1
				if mask[i] != 0:
					n_white += 1
				elif _is_paint(_texel(albedo, i, scale), paint):
					n_red_lost += 1
			print("DBG %s texel=%d engel=%d beyaz=%d boyarenkli-ama-siyah=%d" % [part["name"], n_all, n_block, n_white, n_red_lost])
	var image: Image = Image.create_from_data(_size, _size, false, Image.FORMAT_L8, mask)
	_blur(image)
	var out_path: String = String(entry["optimized_path"]).get_basename() + "_paintmask.png"
	image.save_png(out_path)
	var white: int = 0
	for b: int in mask:
		if b > 127:
			white += 1
	print("[mask] %-16s %dx%d  boyalı=%%%.1f  aday=%d → boya=%d  parça: boyalı=%d karışık=%d atlanan=%d  fabrika boyası: bulunan #%s / haritada #%s%s  → %s" % [
		id, _size, _size, 100.0 * white / (_size * _size), _count(candidate), kept, parts.size() - mixed.size() - skipped.size(), mixed.size(), skipped.size(),
		paint.to_html(false).to_upper(), declared.to_html(false).to_upper(), "" if _close(paint, declared) else "  ← GÜNCELLE", out_path.get_file()])
	if not mixed.is_empty():
		print("        karışık parçalar (texel bazında elendi): %s" % ", ".join(mixed))
	if not skipped.is_empty():
		print("        boyanmayan gövde parçaları: %s" % ", ".join(skipped))
	if not promoted.is_empty():
		print("        boyaya yükseltilen parçalar (dokuda kaporta rengi): %s" % ", ".join(promoted))
	root.queue_free()


## Maskedeki i indeksinin albedo texel'i.
func _texel(albedo: Image, index: int, scale: float) -> Color:
	return albedo.get_pixel(mini(int((index % _size + 0.5) * scale), albedo.get_width() - 1), mini(int((index / _size + 0.5) * scale), albedo.get_height() - 1))


## Aday texel'lerin baskın rengi: kromatiklik (r/l, g/l) histogramının en kalabalık kovası, o kovadaki
## texel'lerin medyan parlaklığında. Boya kaportanın en geniş alanıdır; tampon/trim/cam azınlıkta kalır.
static func _dominant_color(samples: Array[Color]) -> Color:
	const BINS: int = 24
	const LUMA_BINS: int = 7   # kromatiklik tek başına siyah plastiği, griyi ve beyazı aynı kovaya atar
	var hist: Dictionary = {}
	for c: Color in samples:
		var l: float = maxf(c.get_luminance(), 0.02)
		if l < PAINT_MIN_LUMA:
			continue  # siyah plastik / araç altı / derin gölge boyayı temsil etmez
		var band: int = clampi(int(sqrt(l) * LUMA_BINS), 0, LUMA_BINS - 1)
		var key: int = (mini(int(c.r / l * 0.5 * BINS), BINS - 1) * BINS + mini(int(c.g / l * 0.5 * BINS), BINS - 1)) * LUMA_BINS + band
		if not hist.has(key):
			hist[key] = []
		(hist[key] as Array).append(c)
	# Kova puanı = texel sayısı × √parlaklık × (1 + doygunluk). Kaporta alanı geniştir; koyu ama geniş
	# kovalar (araç altı, iç gölge — Passat) ve soluk gri kovalar (Getz'in kromu) boyayı geçmesin.
	var score: Dictionary = {}
	for key: int in hist:
		var bucket: Array = hist[key]
		var avg: Color = Color(0, 0, 0)
		for c: Color in bucket:
			avg += c
		avg = avg / bucket.size()
		score[key] = bucket.size() * sqrt(avg.get_luminance()) * (1.0 + _saturation(avg))
	var keys: Array = hist.keys()
	keys.sort_custom(func(a: int, b: int) -> bool: return score[a] > score[b])
	var report: PackedStringArray = PackedStringArray()
	for i: int in mini(4, keys.size()):
		var bucket: Array = hist[keys[i]]
		var avg: Color = Color(0, 0, 0)
		for c: Color in bucket:
			avg += c
		report.append("#%s×%d(%.0f)" % [(avg / bucket.size()).to_html(false).to_upper(), bucket.size(), score[keys[i]]])
	print("        baskın kovalar: %s" % ", ".join(report))
	var best: Array = hist[keys[0]] if not keys.is_empty() else []
	if best.is_empty():
		return Color.WHITE
	best.sort_custom(func(a: Color, b: Color) -> bool: return a.get_luminance() < b.get_luminance())
	var mid: Array = best.slice(int(best.size() * 0.3), maxi(int(best.size() * 0.8), int(best.size() * 0.3) + 1))
	var sum: Color = Color(0, 0, 0)
	for c: Color in mid:
		sum += c
	return sum / mid.size()


static func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.04 and absf(a.g - b.g) < 0.04 and absf(a.b - b.b) < 0.04


## Texel fabrika boyası mı? Kromatiklik (gölgeden bağımsız) + asimetrik parlaklık bandı + doygunluk muafiyeti.
static func _is_paint(texel: Color, paint: Color) -> bool:
	var l: float = maxf(texel.get_luminance(), 0.005)
	var pl: float = maxf(paint.get_luminance(), 0.02)
	var oct: float = log(l / pl) / log(2.0)
	if oct < -SHADE_DARK and oct >= -SHADE_DARK_SATURATED and _saturation(paint) >= NEUTRAL_PAINT \
			and _saturation(texel) >= DARK_SATURATION and _hue_close(texel, paint):
		return true   # boyanın KOYU gölgesi (kıvrım, panel kenarı): tonu ve doygunluğu boyayla aynı
	if oct > SHADE_LIGHT or oct < -SHADE_DARK:
		return false  # cam / krom / far parlaması ya da siyah plastik / derin gölge
	var sat: float = _saturation(texel)
	if _saturation(paint) < NEUTRAL_PAINT:
		# Gümüş / beyaz / gri araç: boyanın tonu yok; renkli texel (far, stop, plaka, logo) boya değildir
		return sat < DESAT_LIMIT * 1.6
	if sat < DESAT_LIMIT:
		return oct > -DESAT_OCTAVE  # soluk texel: boyanın parlaması (üst sınır zaten SHADE_LIGHT)
	return _hue_close(texel, paint)


static func _hue_close(texel: Color, paint: Color) -> bool:
	var tv: Vector3 = Vector3(texel.r, texel.g, texel.b)
	var pv: Vector3 = Vector3(paint.r, paint.g, paint.b)
	if tv.length() < 0.001 or pv.length() < 0.001:
		return false
	return acos(clampf(tv.normalized().dot(pv.normalized()), -1.0, 1.0)) < HUE_TOLERANCE


static func _saturation(c: Color) -> float:
	var mx: float = maxf(maxf(c.r, c.g), c.b)
	return 0.0 if mx <= 0.02 else (mx - minf(minf(c.r, c.g), c.b)) / mx


## Yüzeyin UV üçgenlerini maskeye basar; işlenen üçgen sayısını döner.
func _rasterize(arrays: Array, target: PackedByteArray) -> int:
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if uvs.is_empty() or indices.is_empty():
		return 0
	var count: int = indices.size() / 3
	for t: int in count:
		_triangle(uvs[indices[t * 3]], uvs[indices[t * 3 + 1]], uvs[indices[t * 3 + 2]], target)
	return count


## Tek UV üçgeni (barycentric, konservatif: merkezi içeride olan texel'ler + kenar texel'leri).
func _triangle(a: Vector2, b: Vector2, c: Vector2, target: PackedByteArray) -> void:
	var pa: Vector2 = Vector2(a.x * _size, a.y * _size)
	var pb: Vector2 = Vector2(b.x * _size, b.y * _size)
	var pc: Vector2 = Vector2(c.x * _size, c.y * _size)
	var min_x: int = clampi(int(floor(minf(minf(pa.x, pb.x), pc.x))) - 1, 0, _size - 1)
	var max_x: int = clampi(int(ceil(maxf(maxf(pa.x, pb.x), pc.x))) + 1, 0, _size - 1)
	var min_y: int = clampi(int(floor(minf(minf(pa.y, pb.y), pc.y))) - 1, 0, _size - 1)
	var max_y: int = clampi(int(ceil(maxf(maxf(pa.y, pb.y), pc.y))) + 1, 0, _size - 1)
	var area: float = (pb - pa).cross(pc - pa)
	if absf(area) < 0.000001:
		return
	for y: int in range(min_y, max_y + 1):
		for x: int in range(min_x, max_x + 1):
			var p: Vector2 = Vector2(x + 0.5, y + 0.5)
			var w0: float = (pb - pa).cross(p - pa) / area
			var w1: float = (pc - pb).cross(p - pb) / area
			var w2: float = (pa - pc).cross(p - pc) / area
			if w0 >= -0.35 and w1 >= -0.35 and w2 >= -0.35:
				target[y * _size + x] = 255


func _count(mask: PackedByteArray) -> int:
	var n: int = 0
	for b: int in mask:
		if b != 0:
			n += 1
	return n


func _neighbors(mask: PackedByteArray, index: int) -> int:
	var x: int = index % _size
	var y: int = index / _size
	var n: int = 0
	for dy: int in [-1, 0, 1]:
		for dx: int in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx >= 0 and nx < _size and ny >= 0 and ny < _size and mask[ny * _size + nx] != 0:
				n += 1
	return n


## 8-komşusundan en çok 2'si dolu olan tekil texel'leri siler (doku gürültüsü).
func _despeckle(mask: PackedByteArray) -> void:
	var copy: PackedByteArray = mask.duplicate()
	for i: int in mask.size():
		if copy[i] != 0 and _neighbors(copy, i) <= 2:
			mask[i] = 0


## 8-komşusunun en az 7'si dolu olan boş texel'leri doldurur (anahtarın kaçırdığı gölge delikleri).
func _fill_holes(mask: PackedByteArray) -> void:
	for pass_index: int in 2:
		var copy: PackedByteArray = mask.duplicate()
		for i: int in mask.size():
			if copy[i] == 0 and _neighbors(copy, i) >= 7:
				mask[i] = 255


## Morfolojik kapama (genişlet + daralt), yalnızca izin verilen alan içinde: panel içindeki tekil
## delikler ve benek gürültüsü kapanır, cam gibi GENİŞ delikler açık kalır.
func _close_within(mask: PackedByteArray, allowed: PackedByteArray, radius: int) -> void:
	for s: int in radius:
		var copy: PackedByteArray = mask.duplicate()
		for i: int in mask.size():
			if copy[i] == 0 and allowed[i] != 0 and _neighbors(copy, i) >= 3:
				mask[i] = 255
	for s: int in radius:
		var copy: PackedByteArray = mask.duplicate()
		for i: int in mask.size():
			if copy[i] != 0 and _neighbors(copy, i) <= 4:
				mask[i] = 0


func _dilate(mask: PackedByteArray, steps: int) -> void:
	for s: int in steps:
		var copy: PackedByteArray = mask.duplicate()
		for i: int in mask.size():
			if copy[i] == 0 and _neighbors(copy, i) > 0:
				mask[i] = 255


func _erode(mask: PackedByteArray, steps: int) -> void:
	for s: int in steps:
		var copy: PackedByteArray = mask.duplicate()
		for i: int in mask.size():
			if copy[i] != 0 and _neighbors(copy, i) < 8:
				mask[i] = 0


## 3x3 kutu bulanıklık: kenarlar yumuşasın (shader'da sert geçiş olmasın).
func _blur(image: Image) -> void:
	var src: Image = image.duplicate()
	for y: int in _size:
		for x: int in _size:
			var sum: float = 0.0
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					sum += src.get_pixel(clampi(x + dx, 0, _size - 1), clampi(y + dy, 0, _size - 1)).r
			image.set_pixel(x, y, Color(sum / 9.0, sum / 9.0, sum / 9.0))


static func _albedo_image(root: Node3D) -> Image:
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		for si: int in mesh.mesh.get_surface_count():
			var mat: BaseMaterial3D = mesh.mesh.surface_get_material(si) as BaseMaterial3D
			if mat and mat.albedo_texture:
				var img: Image = mat.albedo_texture.get_image()
				if img.is_compressed():
					img.decompress()
				return img
	return null


func _parse_args() -> Dictionary:
	var out: Dictionary = {}
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		var a: String = args[i]
		if a.begins_with("--"):
			if i + 1 < args.size() and not args[i + 1].begins_with("--"):
				out[a.trim_prefix("--")] = args[i + 1]
				i += 2
			else:
				out[a.trim_prefix("--")] = "true"
				i += 1
		else:
			i += 1
	return out
