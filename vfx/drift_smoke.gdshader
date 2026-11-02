// DRIFT DUMANI — tek MultiMesh (vfx/drift_smoke.gd): her örnek bir duman topağı. Topağın BÜTÜN hareketi burada,
// doğduğu andaki verilerden kapalı biçimde hesaplanır (işlemci her topağı yalnız doğarken bir kez yazar):
//   örnek dönüşümünün origin'i = doğduğu yer, basis.x = ilk hız, basis.y = (son boy, ömür, ilk açı),
//   basis.z = (dönüş hızı, tohum, -), INSTANCE_CUSTOM.x = doğduğu an, COLOR = ton.
// Hız sönümle azalır (dv/dt = -drag·v + kaldırma), rüzgârla kayar; boy büyür, saydamlık hızla dolup yavaşça söner.
// Büyüdükçe merkezi yükselir (kameraya dönük dörtgen yola gömülmesin). Ömrü bitmiş / doğmamış örnek sıfır boydadır.
// Kameraya dönük dörtgen; kenarları yumuşak ve topak topak, üstü hafif aydınlık. Işıksız alfa karışımı.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float now = 0.0;
uniform float drag = 1.9;
uniform float buoyancy = 0.12;
uniform vec3 wind = vec3(0.05, 0.0, -0.035);
uniform float size_start = 0.15;
uniform float peak_alpha = 0.42;
uniform float ground_hold = 0.46;

varying vec4 tint;
varying float seed;

void vertex() {
	vec3 p0 = MODEL_MATRIX[3].xyz;
	vec3 v0 = MODEL_MATRIX[0].xyz;
	vec3 shape = MODEL_MATRIX[1].xyz;   // son boy, ömür, ilk açı
	vec3 extra = MODEL_MATRIX[2].xyz;   // dönüş hızı, tohum
	float age = now - INSTANCE_CUSTOM.x;
	float life = shape.y;
	float u = life > 0.001 ? age / life : 2.0;
	float live = step(0.0, u) * step(u, 0.999);
	u = clamp(u, 0.0, 1.0);
	float e = exp(-drag * age);
	float spread = (1.0 - e) / drag;
	vec3 p = p0 + v0 * spread + vec3(0.0, buoyancy / drag * (age - spread), 0.0) + wind * age;
	float size = mix(size_start, shape.x, 1.0 - pow(1.0 - u, 2.2)) * live;
	p.y = max(p.y, size * ground_hold + 0.015);
	float spin = shape.z + extra.x * age;
	tint = vec4(COLOR.rgb, peak_alpha * smoothstep(0.0, 0.08, u) * pow(1.0 - u, 1.5));
	seed = extra.y;
	vec2 v = VERTEX.xy * size;
	v = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * v;
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], vec4(p, 1.0));
	VERTEX = vec3(v, 0.0);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float lobes = 0.09 * sin(a * 5.0 + seed * 6.2832) + 0.05 * sin(a * 9.0 - seed * 11.0);
	float body = 1.0 - smoothstep(0.25 + lobes, 0.98 + lobes * 0.4, r);
	// iç yoğunluk: birkaç yumuşak topak (tamamen düz disk gibi durmasın)
	vec2 q = p * 1.7 + vec2(seed * 3.1, seed * 1.7);
	float puff = 0.82 + 0.18 * sin(q.x * 2.3 + sin(q.y * 1.9)) * sin(q.y * 2.1 + seed * 4.0);
	float shade = 0.9 + 0.1 * (-p.y) + 0.05 * (1.0 - r);
	ALBEDO = tint.rgb * shade;
	ALPHA = clamp(tint.a * body * body * puff, 0.0, 1.0);
}
