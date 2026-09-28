@tool
extends Node3D
## Garajın FİZİKSEL boyutu: zemin + sol/arka duvar + ızgara. Sağ (x=-0.2) ve ön (z=-0.2) kenar sabittir,
## garaj -x ve -z yönüne büyür. Seviyeyi GarageUpgradeManager'daki "garage_level" geliştirmesi sürer
## (satın alma ve para orada); burada yalnızca geometri vardır.
## Oyunda garajın önünde "GARAJI GENİŞLET" tabelası durur: tıklanınca expand_clicked yayılır,
## satın alma plakasını HUD gösterir. Tabela yalnızca çalışırken kurulur (editörde değil).

## Fiziksel seviye değişti (0 tabanlı indeks).
signal level_changed(level: int)
## Dünyadaki genişletme tabelasına tıklandı.
signal expand_clicked

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
	10000,
	25000,
	50000,
	100000
]

# Fiziksel ölçüler
var level_widths = [2.0, 4.0, 6.0, 8.0]
var level_depths = [1.5, 3.0, 4.5, 6.0]

const FIXED_RIGHT_X := -0.2
const FIXED_FRONT_Z := -0.2
const LEFT_WALL_DEPTH := 1.5
const BACK_WALL_WIDTH := 2.0


var _sign: Node3D


func _ready():
	update_garage()
	if Engine.is_editor_hint():
		return
	add_to_group("garage_system")
	_ensure_decor_manager()
	_ensure_decor_view()
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


## Avludaki dekorasyon görünümü de kodla kurulur (sahne dosyası elle düzenlenmiyor).
func _ensure_decor_view() -> void:
	if get_tree().get_first_node_in_group("garage_decor_view") != null:
		return
	add_child(GarageDecorView.new())


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
	var economy: EconomyManager = get_tree().get_first_node_in_group("economy") as EconomyManager
	if economy:
		economy.money_changed.connect(func(_m: int) -> void: _update_sign(upgrades))
	_sync_from_upgrade(upgrades)


func _sync_from_upgrade(upgrades: GarageUpgradeManager) -> void:
	set_level(upgrades.garage_level() - 1)   # geliştirme 1 tabanlı, buradaki indeks 0 tabanlı
	_update_sign(upgrades)


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


# --- Dünyadaki "GARAJI GENİŞLET" tabelası -------------------------------------------

## Garajın ön-sağ köşesinde duran fiziksel tabela: seviye, ücret ve tıklama kutusu.
func _update_sign(upgrades: GarageUpgradeManager) -> void:
	if Engine.is_editor_hint():
		return
	var maxed: bool = upgrades.is_max(GarageUpgradeManager.GARAGE_ID)
	if maxed:
		if is_instance_valid(_sign):
			_sign.queue_free()
			_sign = null
		return
	if not is_instance_valid(_sign):
		_sign = _build_sign()
		add_child(_sign)
	# Garajın ön-sağ köşesinde, zeminin ÜSTÜNDE durur (yolun üstünde durursa geçen araçlar
	# tıklamayı kapatıyor; sağ/ön kenar sabit olduğu için garaj büyüse de tabela yerinde kalır)
	_sign.position = Vector3(FIXED_RIGHT_X - 0.32, 0.0, FIXED_FRONT_Z - 0.4)
	var label: Label3D = _sign.get_node("SignText")
	label.text = "GARAJI GENİŞLET\nSEVİYE %d  ·  %s ₺" % [
		upgrades.level(GarageUpgradeManager.GARAGE_ID) + 1,
		Hud.format_thousands(upgrades.next_cost(GarageUpgradeManager.GARAGE_ID))]


func _build_sign() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "ExpandSign"
	# Direk yok: tabela kilitli alan plakalarıyla aynı dilde, havada duran krem plakadır
	var board: MeshInstance3D = MeshInstance3D.new()
	board.name = "Board"
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.62, 0.2)
	board.mesh = quad
	board.position = Vector3(0.0, 0.38, 0.0)
	board.material_override = _sign_material(Color("F3E8CF"), true)
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(board)

	var label: Label3D = Label3D.new()
	label.name = "SignText"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 2
	label.pixel_size = 0.00105
	label.font_size = 48
	label.outline_size = 0
	label.modulate = Color("2F3236")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector3(0.0, 0.38, 0.0)
	root.add_child(label)

	var body: StaticBody3D = StaticBody3D.new()
	body.name = "ClickBody"
	body.input_ray_pickable = true
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.72, 0.34, 0.3)   # plakanın etrafı (mobilde rahat dokunma payı)
	shape.shape = box
	shape.position = Vector3(0.0, 0.38, 0.0)
	body.add_child(shape)
	body.input_event.connect(_on_sign_input)
	root.add_child(body)
	return root


func _sign_material(color: Color, billboard: bool) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if billboard:
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


func _on_sign_input(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape: int) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		expand_clicked.emit()
		get_viewport().set_input_as_handled()
