@tool
extends Node3D
## Garajın FİZİKSEL boyutu: zemin + sol/arka duvar + ızgara. Sağ (x=-0.2) ve ön (z=-0.2) kenar sabittir,
## garaj -x ve -z yönüne büyür. Seviyeyi GarageUpgradeManager'daki "garage_level" geliştirmesi sürer
## (satın alma ve para orada); burada yalnızca geometri vardır.
## Genişletme dünyada tabela olarak durmaz: GARAJ sekmesinin alt panelindeki GENİŞLET düğmesindedir.

## Fiziksel seviye değişti (0 tabanlı indeks).
signal level_changed(level: int)

@export_category("Current Garage")
@export_range(0, 3, 1) var current_level: int = 0

@export_category("Garage Levels")
@export var level_names: PackedStringArray = [
	"10x10",
	"20x20",
	"30x30",
	"40x40"
]

@export var level_prices: PackedInt32Array = [
	30000,
	75000,
	150000,
	300000
]

# Fiziksel ölçüler
# Tamir alanları taşınabilir (RepairBayManager.DEFAULT_POSITIONS): her alanın varsayılan yeri kendi
# seviyesinde açılan zemin şeridine düşer (Sv.3'te x ≥ -4,4 → genişlik ≥ 4,6).
var level_widths = [2.0, 3.6, 4.6, 5.6]
var level_depths = [1.5, 2.2, 2.9, 3.6]

const FIXED_RIGHT_X := -0.2
const FIXED_FRONT_Z := -0.2
const LEFT_WALL_DEPTH := 1.5
const BACK_WALL_WIDTH := 2.0




func _ready():
	update_garage()
	if Engine.is_editor_hint():
		return
	add_to_group("garage_system")
	_ensure_decor_manager()
	_ensure_decor_view()
	_ensure_crate_system()
	_ensure_editor.call_deferred()
	_ensure_world_dressing.call_deferred()
	_hide_build_grid()
	_connect_upgrade.call_deferred()


## Dekorasyon yöneticisi KODLA kurulur (sahne dosyası elle düzenlenmiyor — bkz. CLAUDE.md).
## Diğer yöneticiler gibi grupla bulunur ("decor"); garaj değeri ve kayıt ona bakar.
func _ensure_decor_manager() -> void:
	if get_tree().get_first_node_in_group("decor") != null:
		return
	var decor: DecorManager = DecorManager.new()
	decor.name = "DecorManager"
	add_child(decor)


## ARAÇ TESLİMAT KASALARI da kodla kurulur (sahne dosyası elle düzenlenmiyor): kasa durumu ve
## kayıt (CrateManager, "crates"), tekrarlayan gem kaynakları (GemRewards, "gem_rewards") ve
## dünyadaki teslimat alanı (CrateDelivery, "crate_delivery"). Burada SENKRON kurulurlar: HUD'un
## ertelenmiş bağlantısı ve SaveManager'ın ertelenmiş yüklemesi onları hazır bulur.
func _ensure_crate_system() -> void:
	if get_tree().get_first_node_in_group("crates") == null:
		var crates: CrateManager = CrateManager.new()
		crates.name = "CrateManager"
		add_child(crates)
	if get_tree().get_first_node_in_group("gem_rewards") == null:
		var gems: GemRewards = GemRewards.new()
		gems.name = "GemRewards"
		add_child(gems)
	if get_tree().get_first_node_in_group("crate_delivery") == null:
		add_child(CrateDelivery.new())
	# REKLAM servisi (ödüllü): kodla kurulur, SaveManager'dan ÖNCE hazır olmalı (sayaçları o yükler).
	if get_tree().get_first_node_in_group("ads") == null:
		var ads: AdService = AdService.new()
		ads.name = "AdService"
		add_child(ads)


## Avludaki dekorasyon görünümü de kodla kurulur (sahne dosyası elle düzenlenmiyor).
func _ensure_decor_view() -> void:
	if get_tree().get_first_node_in_group("garage_decor_view") != null:
		return
	add_child(GarageDecorView.new())


## Garaj düzenleyicisi (world/garage_editor.gd) de kodla kurulur. Sahnenin SON çocuğu olur:
## Godot _unhandled_input'u ağaçtaki son düğümden başlatır, böylece düzenleyici eşya sürüklerken
## olayları kameradan ve araç kutularından önce alıp tüketebilir. (Ertelenmiş: sahne kurulurken
## current_scene'e çocuk eklenemez.)
func _ensure_editor() -> void:
	if get_tree().get_first_node_in_group("garage_editor") != null:
		return
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	host.add_child(GarageEditor.new())


## Dünyanın tamamlanması (world/world_dressing.gd) de kodla kurulur: yollar kameranın gidebileceği
## kenara kadar uzar, yarım kalan showroom binası yenisiyle değişir, trafiğin uç noktaları taşınır.
func _ensure_world_dressing() -> void:
	var host: Node = get_tree().current_scene if get_tree().current_scene else get_parent()
	if host.get_node_or_null("WorldDressing") != null:
		return
	host.add_child(WorldDressing.new())


## Yerleştirme ızgarası (BuildGrid) açılış kadrajının tam ortasında camgöbeği tel kafes olarak
## görünüyordu: bu, yerleştirme sistemi için bırakılmış bir prototip yardımcısı, oyuncuya
## gösterilecek bir görsel değil. Sahnede DURUYOR (ileride yerleştirme modunda açılacak),
## yalnızca oyunda gizleniyor.
func _hide_build_grid() -> void:
	var grid: Node = get_node_or_null("BuildGrid")
	if grid == null:
		return
	for node: Node in [grid.get_node_or_null("BuildGrid"), grid.get_node_or_null("BuildGrid/GridPreview")]:
		if node is Node3D:
			(node as Node3D).visible = false


## Seviyeyi "garage_level" geliştirmesinden alır ve satın alındıkça büyür.
func _connect_upgrade() -> void:
	var upgrades: GarageUpgradeManager = get_tree().get_first_node_in_group("garage_upgrades") as GarageUpgradeManager
	if upgrades == null:
		return
	upgrades.levels_changed.connect(func() -> void: _sync_from_upgrade(upgrades))   # kayıttan yükleme dahil
	_sync_from_upgrade(upgrades)


func _sync_from_upgrade(upgrades: GarageUpgradeManager) -> void:
	set_level(upgrades.garage_level() - 1)   # geliştirme 1 tabanlı, buradaki indeks 0 tabanlı


## Fiziksel seviyeyi doğrudan ayarlar (kayıttan yükleme / geliştirme satın alma).
func set_level(level: int) -> void:
	var clamped: int = clampi(level, 0, level_widths.size() - 1)
	if clamped == current_level:
		return
	current_level = clamped
	update_garage()
	level_changed.emit(current_level)


func update_garage():
	var garage_floor = $Floor/GarageFloor
	var left_wall = $Walls/GarageLeftWall
	var back_wall = $Walls/GarageBackWall

	var garage_width = level_widths[current_level]
	var garage_depth = level_depths[current_level]

	garage_floor.size.x = garage_width
	garage_floor.size.z = garage_depth

	# Ön ve sağ taraf SABİT
	garage_floor.position.x = FIXED_RIGHT_X - garage_width / 2.0
	garage_floor.position.z = FIXED_FRONT_Z - garage_depth / 2.0

	# Sol duvar
	left_wall.scale.z = garage_depth / LEFT_WALL_DEPTH
	left_wall.position.x = FIXED_RIGHT_X - garage_width
	left_wall.position.z = FIXED_FRONT_Z - garage_depth / 2.0

	# Arka duvar
	back_wall.scale.x = garage_width / BACK_WALL_WIDTH
	back_wall.position.x = FIXED_RIGHT_X - garage_width / 2.0
	back_wall.position.z = FIXED_FRONT_Z - garage_depth + 0.025

	_update_grid(garage_width, garage_depth)
	var view: Node = get_node_or_null("GarageDecorView")
	if view and view.has_method("refresh"):
		view.call("refresh")   # avlu büyüdü: yeni yuvalar açılmış olabilir


## Yerleştirme ızgarasının göz boyu: TAMİR ALANININ (CarSpot 0,5 x 0,7) uzun kenarının DÖRTTE
## biri. Eski değer 0,5 idi (bir göz neredeyse koca bir tamir alanı); 0,7/8 denendi ama alan
## olarak tamir alanı ~45 göze bölünüyordu ve fazla ince duruyordu — iki katına çıkarıldı.
const GRID_CELL: float = 0.7 / 4.0


## Zemindeki ızgara da garajla birlikte büyür (yeni alan boş zemin gibi görünmesin).
func _update_grid(garage_width: float, garage_depth: float) -> void:
	var grid: Node3D = get_node_or_null("BuildGrid/BuildGrid")
	if grid == null:
		return
	grid.cell_size = GRID_CELL
	grid.position.x = FIXED_RIGHT_X - garage_width / 2.0
	grid.position.z = FIXED_FRONT_Z - garage_depth / 2.0
	grid.width = int(round(garage_width / grid.cell_size))
	grid.depth = int(round(garage_depth / grid.cell_size))
	grid.create_grid()
	var preview: MeshInstance3D = grid.get_node_or_null("GridPreview")
	if preview and preview.mesh is PlaneMesh:
		(preview.mesh as PlaneMesh).size = Vector2(garage_width, garage_depth)


func get_current_level_name() -> String:
	return level_names[current_level]


func get_current_price() -> int:
	return level_prices[current_level]


func get_next_price() -> int:
	if current_level >= level_prices.size() - 1:
		return -1

	return level_prices[current_level + 1]


func can_upgrade() -> bool:
	return current_level < level_names.size() - 1


func upgrade_garage() -> bool:
	if not can_upgrade():
		return false

	current_level += 1
	update_garage()
	return true
