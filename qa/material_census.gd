extends SceneTree
## SHADER SÜRÜMÜ SAYIMI: GL Compatibility her FARKLI shader için (StandardMaterial3D'de: özellik
## birleşimi başına bir shader) ilk kullanımda 4 modu + kullanılan varyantı derler (önbellek yoksa ilk
## kurulumda saniyeler). Bu betik ağaçtaki bütün 3B materyallerin (SubViewport dünyaları dahil) shader'ı
## belirleyen özelliklerinden anahtar çıkarır; farklı anahtar ≈ derlenecek shader sürümü.
## Kullanım: QA_SAVE=<kayıt> tools/qa_isolated.sh res://qa/material_census.gd --display-driver x11 \
##   --disable-vsync --resolution 1152x648 [-- <kare sayısı>]

## BaseMaterial3D'de shader kodunu değiştiren özellikler (sayısal renk / değerler DEĞİL: onlar uniform).
const KEY_PROPS: PackedStringArray = [
	"transparency", "blend_mode", "cull_mode", "depth_draw_mode", "no_depth_test", "shading_mode",
	"diffuse_mode", "specular_mode", "disable_ambient_light", "disable_fog", "disable_specular_occlusion",
	"vertex_color_use_as_albedo", "vertex_color_is_srgb", "use_point_size", "fixed_size", "billboard_mode",
	"billboard_keep_scale", "texture_filter", "texture_repeat", "albedo_texture_force_srgb",
	"albedo_texture_msdf", "normal_enabled", "emission_enabled", "rim_enabled", "clearcoat_enabled",
	"anisotropy_enabled", "ao_enabled", "heightmap_enabled", "subsurf_scatter_enabled", "backlight_enabled",
	"refraction_enabled", "detail_enabled", "uv1_triplanar", "uv1_world_triplanar", "uv2_triplanar",
	"grow", "proximity_fade_enabled", "distance_fade_mode", "alpha_antialiasing_mode",
	"use_particle_trails", "particles_anim_h_frames", "metallic_texture_channel", "roughness_texture_channel",
	"shadow_to_opacity", "stencil_mode",
]
const TEX_PROPS: PackedStringArray = ["albedo_texture", "metallic_texture", "roughness_texture",
	"emission_texture", "normal_texture", "orm_texture"]


func _initialize() -> void:
	_run.call_deferred()


func _key(mat: Material) -> String:
	if mat == null:
		return "(varsayılan)"
	if mat is ShaderMaterial:
		var sh: Shader = (mat as ShaderMaterial).shader
		return "Shader:" + (sh.resource_path if sh and sh.resource_path != "" else "kod#%d" % (sh.get_instance_id() if sh else 0))
	if mat is BaseMaterial3D:
		var parts: PackedStringArray = PackedStringArray([mat.get_class()])
		for p: String in KEY_PROPS:
			var v: Variant = mat.get(p)
			var on: bool = false
			if v is bool:
				on = v
			elif v is int:
				on = v != 0
			elif v is float:
				on = v != 0.0
			else:
				on = v != null
			if on:
				parts.append("%s=%s" % [p, v])
		for p: String in TEX_PROPS:
			if mat.get(p) != null:
				parts.append(p)
		return " ".join(parts)
	return mat.get_class()


func _materials(node: Node) -> Array[Material]:
	var out: Array[Material] = []
	var g: GeometryInstance3D = node as GeometryInstance3D
	if g == null:
		return out
	if g.material_override:
		out.append(g.material_override)
		return out
	var mesh: Mesh = null
	if g is MeshInstance3D:
		mesh = (g as MeshInstance3D).mesh
	elif g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh:
		mesh = (g as MultiMeshInstance3D).multimesh.mesh
	elif g is CPUParticles3D:
		mesh = (g as CPUParticles3D).mesh
	elif g is CSGShape3D:
		out.append(g.get(&"material") as Material)
		return out
	elif g is Label3D or g is SpriteBase3D:
		out.append(null)   # kendi iç materyali: ayarına göre ayrı shader
		return out
	if mesh == null:
		return out
	for s: int in mesh.get_surface_count():
		var m: Material = (g as MeshInstance3D).get_surface_override_material(s) if g is MeshInstance3D else null
		out.append(m if m else mesh.surface_get_material(s))
	return out


func _run() -> void:
	change_scene_to_file("res://Main.tscn")
	var wait: int = int(OS.get_cmdline_user_args()[0]) if OS.get_cmdline_user_args().size() > 0 else 240
	for i: int in wait:
		await process_frame
	var keys: Dictionary = {}   # anahtar → {count, examples}
	for node: Node in root.find_children("*", "GeometryInstance3D", true, false):
		var where: String = String(root.get_path_to(node))
		var short: String = "/".join(where.split("/").slice(0, 5))
		var kind: String = node.get_class()
		for mat: Material in _materials(node):
			var k: String = _key(mat) if not (node is Label3D or node is SpriteBase3D) else kind
			if not keys.has(k):
				keys[k] = {"count": 0, "examples": {}}
			keys[k]["count"] += 1
			var ex: Dictionary = keys[k]["examples"]
			if ex.size() < 3:
				ex[short] = true
	var sorted: Array = keys.keys()
	sorted.sort_custom(func(a: String, b: String) -> bool: return keys[a]["count"] > keys[b]["count"])
	print("SAYIM %d farklı shader anahtarı" % keys.size())
	for k: String in sorted:
		print("SAYIM %4d  %s\n           örn: %s" % [keys[k]["count"], k, ", ".join(PackedStringArray((keys[k]["examples"] as Dictionary).keys()))])
	quit(0)
