shader_type spatial;
// ÇİMEN (world/city_scenery.gd, GrassArea'ya): dünya konumundan örneklenen, dokusuz bir çimen görünümü.
// Car Town'daki gibi parlak yeşil; büyük ölçekte açık-koyu lekeler, küçük ölçekte ot benekleri. UV'ye
// bakmaz (CSG kutusunun UV'si 20 birime yayılıyor), dünya X/Z'sinden hesaplanır; ek doku yok.

uniform vec3 base_color : source_color = vec3(0.47, 0.72, 0.29);
uniform vec3 dark_color : source_color = vec3(0.36, 0.60, 0.22);
uniform vec3 light_color : source_color = vec3(0.58, 0.80, 0.34);

varying vec3 world_pos;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz;
	float patches = noise(p * 0.55) * 0.65 + noise(p * 1.7) * 0.35;
	vec3 c = mix(dark_color, base_color, smoothstep(0.25, 0.6, patches));
	c = mix(c, light_color, smoothstep(0.62, 0.85, patches) * 0.7);
	// Ot benekleri: ince ızgarada rastgele açık / koyu noktalar
	vec2 cell = p * 38.0;
	float blade = hash(floor(cell));
	vec2 local = fract(cell) - 0.5;
	float dot_mask = smoothstep(0.26, 0.12, length(local * vec2(1.0, 0.45)));
	c *= 1.0 + (blade - 0.5) * 0.22 * dot_mask;
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
