@tool
extends Node3D

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


func _ready():
	update_garage()


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
