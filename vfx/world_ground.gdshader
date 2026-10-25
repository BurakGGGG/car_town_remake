shader_type spatial;
// ŞEHİR ZEMİNİ + PİŞMİŞ GÖLGE — yol, kaldırım, bordür, patika, otopark gibi düz renkli zeminlerin StandardMaterial3D'si
// yerine (WorldShadow.receive). Görünüm aynı (renk × doku, pürüz, metaliklik, specular; Burley + Schlick-GGX),
// üstüne world_shadow.gdshaderinc'in gölgesi çarpılır. Doku verilmezse beyaz (yalnız renk).

#include "res://vfx/world_shadow.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec3 uv1_scale = vec3(1.0);
uniform vec3 uv1_offset = vec3(0.0);
uniform float roughness = 1.0;
uniform float metallic = 0.0;
uniform float specular = 0.5;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	UV = UV * uv1_scale.xy + uv1_offset.xy;
}

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb * world_shadow_factor(world_pos);
	ROUGHNESS = roughness;
	METALLIC = metallic;
	SPECULAR = specular;
}
