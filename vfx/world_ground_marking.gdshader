shader_type spatial;
render_mode cull_disabled;
// ŞEHİR ZEMİN İŞARETİ + PİŞMİŞ GÖLGE — yaya geçidi / ok / dur çizgisi gibi dokudan kesilen (alpha scissor), yere yatık
// işaretlerin StandardMaterial3D'si yerine (WorldShadow.receive). world_ground.gdshader'ın kesik + çift yüzlü hâli:
// altındaki yol gölgedeyse işaret de gölgede kalır (yoksa gölgenin içinde parlak çizgiler kalırdı).

#include "res://vfx/world_shadow.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;
uniform float alpha_scissor_threshold = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = albedo.rgb * tex.rgb * world_shadow_factor(world_pos);
	ALPHA = albedo.a * tex.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
