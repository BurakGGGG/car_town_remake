shader_type spatial;
// PAS KATMANI — restorasyon projesinin 2. aşamasında (%34–99) aracın üstüne material_overlay olarak
// çizilir: lekeler hâlinde pas (altta yoğun), aralarda kir. Dünya uzayında 3B değer gürültüsü
// (araç sabit durur; doku / UV gerekmez). amount ilerledikçe kod azaltır: pas temizleniyor.
render_mode blend_mix, depth_draw_never, cull_back, specular_disabled;

uniform float amount : hint_range(0.0, 1.0) = 0.7;
uniform vec3 rust_light : source_color = vec3(0.66, 0.36, 0.18);
uniform vec3 rust_dark : source_color = vec3(0.38, 0.20, 0.11);
uniform vec3 dirt : source_color = vec3(0.30, 0.26, 0.21);
// Desen sıklığı (dünya birimi başına). Şehirde araç boyu ~0,6 birim.
uniform float density = 22.0;
// Aracın dünya Y aralığı: altta pas daha yoğun.
uniform float base_y = 0.0;
uniform float height = 0.3;

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
	float grime = smoothstep(0.35, 0.7, value_noise(p * 1.7 + 11.0)) * amount * 0.45;
	vec3 rust_color = mix(rust_dark, rust_light, value_noise(p * 4.1 + 3.0));
	ALBEDO = mix(dirt, rust_color, rust);
	ALPHA = clamp(max(rust * 0.95, grime), 0.0, 1.0) * step(0.001, amount);
	ROUGHNESS = 0.95;
}
