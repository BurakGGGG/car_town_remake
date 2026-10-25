class_name CarFarLod
extends Resource
## ARAÇ UZAK LOD'u — araç modeli başına bir dosya (res://assets/cars/far_lod/<model>.res), tools/far_lod/make_far_lod.gd
## üretir. Godot'nun içe aktarıcısı LOD zincirini parça kenarları kilitli kuruyor; Tripo parçaları açık kabuk olduğu için
## en kaba kademe 19–61 bin üçgende tıkanıyordu (sergi araçları dünyadaki üçgenlerin %80+'ı). Bu dosya her parçanın
## kenar kilitsiz, mutlak sapma sınırlı sadeleştirilmiş İNDEKSLERİNİ tutar: köşeler içe aktarılmış mesh'inkiler
## (aynı sıra), yalnız indeks tamponu eklenir. CarMeshMerger birleşik mesh'e kademeyi kendi sapma eşiğinde (× SWITCH_MARGIN)
## koyar; Godot kademeyi ekrandaki sapmaya göre seçtiği için ancak sapma pikselin altına inince çizilir (şehirde sergi
## araçları varsayılan kamerada: dünya üçgeni 497k → 324k, docs/OPTIMIZASYON_2026_10_25.md §6). Yalnız şehir araçları
## (CarRig.optimize far_lod): kenarlar kilitsiz, garajın zorla en kaba kipinde çatlaklar benek benek görünüyordu.
## Model yeniden içe aktarılıp köşe sırası değişirse (köşe sayısı / ilk köşe tutmaz) parça bu kademeyi kullanmaz.

const DIR: String = "res://assets/cars/far_lod/"

## Sadeleştirmenin sapma sınırı (mesh birimi; araç uzunluğu = 1). Birleşik mesh'te kademenin LOD eşiği bunun SWITCH_MARGIN katı.
@export var error: float = 0.0
## "mesh adı:yüzey" → [köşe sayısı, ilk köşe (Vector3), indeks baytları (bkz. encode)]
@export var surfaces: Dictionary = {}

## Geçiş payı: kademe eşiği sadeleştirmenin sapma sınırının bu katı. Pay yokken şehrin en yakın zoom'unda (araç ~250 piksel)
## seçiliyordu ve Lambo'nun yanında, Golf'ün kaputunda 1–2 piksellik izler görünüyordu (qa/gorunum_lab.gd garaj_yakin,
## QA_UZAKSIZ ile kıyas); 2 katla sapma geçişte ~0,7 pikselin altında.
const SWITCH_MARGIN: float = 2.0
## Bellekte tutulan en çok dosya (en son kullanılan; araç başına ~50–150 KB). Bir model birleşirken her parçası ayrı sorar:
## önbelleksiz her parça dosyayı baştan yüklüyordu (garaj açılışında 123 parça ~41 ms, birleştirme bütçesini yiyordu).
const CACHE_SIZE: int = 8

## QA: false iken hiçbir parça uzak kademe almaz (önce / sonra kıyası; CarMeshMerger önbelleği de temizlenmeli).
static var enabled: bool = true
## Yüklenemeyen / olmayan dosyalar: her parçada yeniden denenmesin.
static var _missing: Dictionary = {}
## Yüklenmiş dosyalar: yol → CarFarLod; _order en son kullanılan sonda.
static var _loaded: Dictionary = {}
static var _order: PackedStringArray = PackedStringArray()


## Model dosyasının yolu (içe aktarılmış mesh'in kaynak GLB'sinden), yoksa "".
static func path_for(mesh: Mesh) -> String:
	var source: String = mesh.resource_path
	var at: int = source.find("::")
	if at < 0:
		return ""
	return DIR + source.left(at).get_file().get_basename() + ".res"


## Parçanın uzak kademesi: [LOD eşiği (sapma × SWITCH_MARGIN), köşe sayısı, ilk köşe, indeks baytları] ya da boş. Ana iş
## parçacığı (yükleme).
static func lookup(mesh: Mesh, surface: int) -> Array:
	var file: String = path_for(mesh)
	if not enabled or file == "" or _missing.has(file):
		return []
	var data: CarFarLod = _load(file)
	if data == null:
		return []
	var entry: Array = data.surfaces.get("%s:%d" % [mesh.resource_name, surface], [])
	if entry.size() < 3:
		return []
	return [data.error * SWITCH_MARGIN, int(entry[0]), entry[1], entry[2]]


static func _load(file: String) -> CarFarLod:
	var data: CarFarLod = _loaded.get(file) as CarFarLod
	if data == null:
		data = load(file) as CarFarLod if ResourceLoader.exists(file) else null
		if data == null:
			_missing[file] = true
			return null
		_loaded[file] = data
	var at: int = _order.find(file)
	if at >= 0:
		_order.remove_at(at)
	_order.append(file)
	while _order.size() > CACHE_SIZE:
		_loaded.erase(_order[0])
		_order.remove_at(0)
	return data


## Kaydedilen kademe bu köşe dizisine mi ait (köşe sırası değişmemiş mi)? Düz veri: iş parçacığında güvenli.
static func matches(far: Array, vertices: PackedVector3Array) -> bool:
	return far.size() == 4 and vertices.size() == int(far[1]) and vertices.size() > 0 \
		and vertices[0].is_equal_approx(far[2])


## İndeks kodlaması: köşe ≤ 65536 ise ardışık farkın 16 bitte sarılıp zigzag'lanmış hâli (uint16; zstd'de düz 16 bit
## indeksten ~%19 küçük), değilse düz uint32.
static func encode(indices: PackedInt32Array, vertex_count: int) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	if vertex_count > 65536:
		return indices.to_byte_array()
	out.resize(indices.size() * 2)
	var prev: int = 0
	for i: int in indices.size():
		var delta: int = ((indices[i] - prev + 32768) & 0xFFFF) - 32768   # [-32768, 32767]
		prev = indices[i]
		out.encode_u16(i * 2, ((delta << 1) ^ (delta >> 31)) & 0xFFFF)
	return out


## encode'un tersi; `offset` eklenerek `target`ın sonuna yazılır. Düz veri: iş parçacığında güvenli.
static func append_decoded(target: PackedInt32Array, bytes: PackedByteArray, vertex_count: int, offset: int) -> void:
	if vertex_count > 65536:
		var wide: PackedInt32Array = bytes.to_int32_array()
		var start: int = target.size()
		target.resize(start + wide.size())
		for i: int in wide.size():
			target[start + i] = wide[i] + offset
		return
	var count: int = bytes.size() / 2
	var base: int = target.size()
	target.resize(base + count)
	var prev: int = 0
	for i: int in count:
		var zz: int = bytes.decode_u16(i * 2)
		prev = (prev + ((zz >> 1) ^ -(zz & 1))) & 0xFFFF
		target[base + i] = prev + offset
