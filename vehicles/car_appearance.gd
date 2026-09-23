class_name CarAppearance
extends Resource
## Bir araç tipinin oyuncu tarafından değiştirilebilen görünümü.
## Varsayılanlar gerçekçi bir fabrika görünümüdür: araç boyası CarCatalog.default_color'dan,
## jantlar metalik gümüş, camlar opak koyu füme (içerisi görünmez), ışıklar kapalı.
## Bir alan değişince `changed` yayılır; CarRig kayıtlı tüm instance'ları günceller.

const DEFAULT_RIM: Color = Color(0.62, 0.63, 0.66)
const DEFAULT_GLASS: Color = Color(0.11, 0.14, 0.18)  # koyu mavi-gri füme

## Gövde boyası (body + ayna gövdeleri). Sadece boyanabilir parçaları etkiler.
@export var body_color: Color = Color.WHITE:
	set(value):
		body_color = value
		emit_changed()

## Yalnızca ayrı jant/göbek mesh'i olan parçalar (rims rolü); lastikleri asla boyamaz.
@export var wheel_color: Color = DEFAULT_RIM:
	set(value):
		wheel_color = value
		emit_changed()

## Cam tonu (camlar her zaman opak; gövde renginden bağımsız).
@export var glass_color: Color = DEFAULT_GLASS:
	set(value):
		glass_color = value
		emit_changed()

@export var headlights_enabled: bool = false:
	set(value):
		headlights_enabled = value
		emit_changed()

@export var taillights_enabled: bool = false:
	set(value):
		taillights_enabled = value
		emit_changed()

## Araç tipi (.tscn yolu) → paylaşılan görünüm. Dünya aracı, garaj önizlemesi ve thumbnail
## aynı nesneyi okur; değişiklik hepsine yansır.
static var _by_scene: Dictionary = {}


static func get_for(scene_path: String) -> CarAppearance:
	if not _by_scene.has(scene_path):
		var appearance: CarAppearance = CarAppearance.new()
		appearance.resource_name = scene_path.get_file().get_basename()
		appearance.body_color = CarCatalog.default_color_for(scene_path)  # katalog; yoksa CarPartMap.default_paint
		appearance.changed.connect(func() -> void: CarRig.apply_to_all(scene_path, appearance))
		_by_scene[scene_path] = appearance
	return _by_scene[scene_path]


## Fabrika görünümüne döndürür.
func reset(scene_path: String = "") -> void:
	body_color = CarCatalog.default_color_for(scene_path)
	wheel_color = DEFAULT_RIM
	glass_color = DEFAULT_GLASS
	headlights_enabled = false
	taillights_enabled = false
