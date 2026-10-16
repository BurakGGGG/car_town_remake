shader_type spatial;
// TEASER PASI — vfx/rust_overlay.gdshader'ın teaser kopyası, iki ek temizleme yolu:
//   wipe_z / wipe_dir : düzlemin bir yanında pas yok; sınırda kızgın turuncu bir çizgi (tarama).
//   clean_center / clean_radius : bu kürenin içinde pas yok; sınırı yine kızgın (taşlama).
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.9;
uniform vec3 rust_light : source_color = vec3(0.62, 0.33, 0.16);
uniform vec3 rust_dark : source_color = vec3(0.30, 0.15, 0.08);
uniform vec3 dirt : source_color = vec3(0.24, 0.21, 0.17);
uniform float density = 11.0;
uniform float base_y = 0.0;
uniform float height = 0.4;
uniform float wipe_z = 100.0;
uniform float wipe_dir = 1.0;   // 1: z > wipe_z temiz · -1: z < wipe_z temiz
uniform vec3 clean_center = vec3(0.0, -100.0, 0.0);
uniform float clean_radius = 0.0;
uniform vec3 hot : source_color = vec3(1.0, 0.55, 0.15);
uniform float hot_width = 0.035;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
				   mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
				   mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void fragment() {
	vec3 p = world_pos * density;
	float n = value_noise(p) * 0.55 + value_noise(p * 2.7) * 0.3 + value_noise(p * 7.3) * 0.15;
	float low = 1.0 - clamp((world_pos.y - base_y) / max(height, 0.001), 0.0, 1.0);
	float edge = 0.78 - amount * 0.45 - low * 0.22;
	float rust = smoothstep(edge, edge + 0.08, n);
	float grime = smoothstep(0.35, 0.7, value_noise(p * 1.7 + 11.0)) * amount * 0.55;
	vec3 rust_color = mix(rust_dark, rust_light, value_noise(p * 4.1 + 3.0));
	// Temizleme sınırı: düzensiz (gürültülü) bir cephe, önünde temiz, sınırında kor.
	float jag = (value_noise(p * 3.0) - 0.5) * 0.06;
	float d_wipe = (world_pos.z - wipe_z) * wipe_dir + jag;
	float d_ball = clean_radius - distance(world_pos, clean_center) + jag;
	float d = max(d_wipe, d_ball);            // > 0: temizlenmiş bölge
	float keep = 1.0 - smoothstep(0.0, 0.004, d);
	float glow = (1.0 - smoothstep(0.0, hot_width, abs(d))) * step(0.0001, amount);
	ALBEDO = mix(mix(dirt, rust_color, rust), hot, glow);
	EMISSION = hot * glow * 6.0;
	ALPHA = clamp(max(max(rust * 0.97, grime) * keep, glow), 0.0, 1.0) * step(0.001, amount);
	ROUGHNESS = 0.95;
}
