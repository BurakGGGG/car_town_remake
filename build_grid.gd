@tool
extends Node3D

@export var width: int = 4
@export var depth: int = 3
@export var cell_size: float = 0.5
## Dekorasyon v2: çizgiler düğümün +X / +Z köşesinden (garajın sabit ön-sağ köşesi) başlayıp `extent`
## boyunca −X / −Z'ye sayılır ve garaj zemininde kırpılır. Böylece zemin karoları, iç duvarlar ve eşya
## oturtma ile aynı çizgiler görünür ve garaj büyüyünce çizgiler kaymaz (bkz. world/decor_grid.gd).
@export var anchor_corner: bool = false
@export var extent: Vector2 = Vector2.ZERO

func _ready():
	create_grid()

func create_grid():
	var old_grid = get_node_or_null("Grid")
	if old_grid:
		old_grid.queue_free()

	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()

	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Göz boyu tamir alanının uzun kenarının 1/4'üne indi (garage_system.gd GRID_CELL); çizgi
	# sayısı arttığı için eski %50 opak camgöbeği ızgara zemini düz bir örtüye çeviriyordu.
	# Koyu ve silik çizgi zemindeki DERZ gibi okunuyor, aynı bilgiyi zemini boğmadan veriyor.
	material.albedo_color = Color(0.16, 0.19, 0.23, 0.22)

	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)

	if anchor_corner and extent.x > 0.0 and extent.y > 0.0:
		var hx: float = extent.x / 2.0
		var hz: float = extent.y / 2.0
		var k: int = 0
		while hx - k * cell_size >= -hx - 1e-4:
			var px: float = hx - k * cell_size
			mesh.surface_add_vertex(Vector3(px, 0.02, -hz))
			mesh.surface_add_vertex(Vector3(px, 0.02, hz))
			k += 1
		k = 0
		while hz - k * cell_size >= -hz - 1e-4:
			var pz: float = hz - k * cell_size
			mesh.surface_add_vertex(Vector3(-hx, 0.02, pz))
			mesh.surface_add_vertex(Vector3(hx, 0.02, pz))
			k += 1
		mesh.surface_end()
		var anchored := MeshInstance3D.new()
		anchored.name = "Grid"
		anchored.mesh = mesh
		add_child(anchored)
		return

	var total_width = width * cell_size
	var total_depth = depth * cell_size

	var start_x = -total_width / 2.0
	var start_z = -total_depth / 2.0

	for x in range(width + 1):
		var px = start_x + x * cell_size
		mesh.surface_add_vertex(Vector3(px, 0.02, start_z))
		mesh.surface_add_vertex(Vector3(px, 0.02, -start_z))

	for z in range(depth + 1):
		var pz = start_z + z * cell_size
		mesh.surface_add_vertex(Vector3(start_x, 0.02, pz))
		mesh.surface_add_vertex(Vector3(-start_x, 0.02, pz))

	mesh.surface_end()

	var grid := MeshInstance3D.new()
	grid.name = "Grid"
	grid.mesh = mesh

	add_child(grid)
