shader_type spatial;

// Lastik + jant TEK mesh olan tekerler için: aks eksenine (X) olan yarıçapa göre
// lastik (dış) / jant (iç) ayrımı. Mesh yerel uzayında çalışır; tekerin dönmesinden etkilenmez.
// CarRig her teker için center ve rim_radius'u AABB'den doldurur.
// Dokulu modelde (use_texture = 1) lastik ve jant dokudan gelir; jant bölgesi rim_tint ile çarpılır
// (varsayılan beyaz = doku aynen; CarAppearance.wheel_color / varsayılan jant rengi).

uniform vec3 center = vec3(0.0);
uniform float rim_radius = 0.075;
uniform vec4 tire_color : source_color = vec4(0.05, 0.05, 0.05, 1.0);
uniform vec4 rim_color : source_color = vec4(0.66, 0.67, 0.70, 1.0);
uniform float tire_roughness = 0.95;
uniform float rim_metallic = 0.55;
uniform float rim_roughness = 0.4;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform float use_texture = 0.0;
uniform vec4 rim_tint : source_color = vec4(1.0);

varying float radial;

void vertex() {
	radial = length(VERTEX.yz - center.yz);
}

void fragment() {
	float rim = 1.0 - step(rim_radius, radial);
	vec3 flat_col = mix(tire_color.rgb, rim_color.rgb, rim);
	vec3 tex = texture(albedo_tex, UV).rgb;
	vec3 tex_col = mix(tex, tex * rim_tint.rgb, rim);
	ALBEDO = mix(flat_col, tex_col, use_texture);
	METALLIC = rim * rim_metallic * (1.0 - 0.5 * use_texture);
	ROUGHNESS = mix(tire_roughness, rim_roughness, rim);
}
