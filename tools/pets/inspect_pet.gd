extends SceneTree
## Kedi sahnesini (assets/pets/tekir.glb) Godot'ta doğrular: düğüm ağacı, animasyonlar, iskelet, boyut.
##   godot-4 --headless --path . --script res://tools/pets/inspect_pet.gd


func _initialize() -> void:
	var scene: PackedScene = load("res://assets/pets/tekir.glb") as PackedScene
	if scene == null:
		print("RAPOR yüklenemedi")
		quit(1)
		return
	var root: Node = scene.instantiate()
	_dump(root, 0)
	var player: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false).front() as AnimationPlayer
	if player:
		var names: PackedStringArray = player.get_animation_list()
		print("RAPOR animasyon ", names.size(), ": ", ", ".join(names))
		for n: String in ["walk", "idle", "sleep", "trick_roll"]:
			if player.has_animation(n):
				var a: Animation = player.get_animation(n)
				print("RAPOR   %s uzunluk %.3f iz %d döngü %d" % [n, a.length, a.get_track_count(), a.loop_mode])
	var skel: Skeleton3D = root.find_children("*", "Skeleton3D", true, false).front() as Skeleton3D
	if skel:
		var bones: PackedStringArray = PackedStringArray()
		for i: int in skel.get_bone_count():
			bones.append(skel.get_bone_name(i))
		print("RAPOR kemik ", bones.size(), ": ", ", ".join(bones))
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		print("RAPOR örgü %s aabb %s yüzey %d" % [mi.name, mi.get_aabb(), mi.mesh.get_surface_count()])
	root.free()
	quit(0)


func _dump(node: Node, depth: int) -> void:
	print("RAPOR ", "  ".repeat(depth), node.name, " (", node.get_class(), ")")
	for c: Node in node.get_children():
		_dump(c, depth + 1)
