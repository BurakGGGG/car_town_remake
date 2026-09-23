shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, specular_disabled;

// Araç seçim göstergesi (statik): zemine yatık quad üzerinde
// yumuşak kenarlı ışık halkası + halkayı saran karenin dört köşesinde L braket.
// Quad'ı car_hitbox.gd, aracın hitbox ölçüsünden üretir; tüm ölçüler quad'a oranlıdır (0..1).

uniform vec4 color : source_color = vec4(0.961, 0.745, 0.298, 1.0); // HUD amber #F5BE4C
uniform float ring_radius = 0.40;
uniform float ring_width = 0.035;
uniform float glow_width = 0.09;
uniform float fill_strength = 0.16;
uniform float bracket_length = 0.14;
uniform float bracket_thickness = 0.04;
uniform float bracket_margin = 0.03;

float soft_box(vec2 q, vec2 lo, vec2 hi, float aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, q) * (1.0 - smoothstep(hi - aa, hi + aa, q));
	return a.x * a.y;
}

void fragment() {
	vec2 p = UV - 0.5;
	float aa = 0.004;
	float dist = length(p);

	// Halka: keskin çekirdek + dışa doğru sönen parıltı
	float d = abs(dist - ring_radius);
	float core = 1.0 - smoothstep(ring_width * 0.5, ring_width, d);
	float glow = (1.0 - smoothstep(0.0, glow_width, d)) * 0.45;

	// Halkanın içinde hafif zemin ışığı
	float fill = (1.0 - smoothstep(ring_radius * 0.3, ring_radius, dist)) * fill_strength;

	// Köşe braketleri: halkanın hemen dışındaki karede; abs(p) ile dört köşeye aynalanır
	vec2 q = abs(p);
	vec2 h = vec2(ring_radius + bracket_margin);
	float arm_v = soft_box(q, vec2(h.x - bracket_thickness, h.y - bracket_length), h, aa);
	float arm_h = soft_box(q, vec2(h.x - bracket_length, h.y - bracket_thickness), h, aa);
	float bracket = max(arm_v, arm_h);

	float alpha = max(max(core, glow), max(bracket, fill));
	vec3 rgb = mix(color.rgb, vec3(1.0), max(core, bracket) * 0.35); // çekirdek ve braketler daha parlak
	ALBEDO = rgb;
	ALPHA = clamp(alpha, 0.0, 1.0) * color.a;
}
