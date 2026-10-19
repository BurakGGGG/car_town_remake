shader_type spatial;

// Dokulu aracın ortak materyali — GLB'nin StandardMaterial3D'si yerine (CarRig._apply_textured). Görünüm aynı
// (Burley + Schlick-GGX, arka yüz ayıklama, opak), tek fark doku mipmap kademesinin sınırlı olması: uzaktaki
// araçta UV adaları birbirine karışmaz (bkz. car_texture.gdshaderinc). Rol materyalleri (jant, cam, far, stop)
// aynı shader'ın başka uniform değerleri; gövde / trim / ızgara / lastik GLB'nin değerleriyle paylaşılan örnek.

#include "res://vehicles/car_texture.gdshaderinc"

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 albedo_tint : source_color = vec4(1.0);   // doku × renk (StandardMaterial3D.albedo_color)
uniform float metallic = 0.0;
uniform float roughness = 0.5;
uniform vec4 emission : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;   // 0 = ışık kapalı

void fragment() {
	ALBEDO = car_texture(albedo_tex, UV).rgb * albedo_tint.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	EMISSION = emission.rgb * emission_energy;
}
