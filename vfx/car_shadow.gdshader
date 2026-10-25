shader_type spatial;
render_mode unshaded, blend_mul, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// HAREKETLİ ARACIN GÖLGESİ (vfx/car_shadow.gd) — aracın altındaki düz dörtgende, güneş yönüne uzanan yumuşak gölge.
// Pişmiş şehir gölgesiyle (world_shadow.gdshaderinc) aynı yön ve renk; trafik araçları haritaya giremediği için kendi
// gölgelerini taşır. Gövde iki kutu sayılır: alt kasa (tam taban, yüksekliğin GOVDE oranı) ve dar kabin (tam yükseklik).
// Kutu güneş yönünde süpürülür: zemin noktası, kutunun kaydırılmış kopyalarından birinin içindeyse gölgededir.
// Araç liftte yükselince gölge söner (lift platformu gölgesini zaten pişmiş haritadan alır).

uniform vec2 half_size = vec2(0.13, 0.3);   // taban yarı genişlik (yerel x), yarı boy (yerel z)
uniform vec2 center = vec2(0.0);            // tabanın yerel x/z merkezi
uniform float height = 0.12;
uniform vec3 sun_shift = vec3(0.0);         // birim yükseklik başına zemindeki kayma (dünya; güneşten uzağa)
uniform vec4 tint = vec4(1.0, 1.0, 1.0, 0.0);   // rgb gölgedeki çarpan (ekrandaki renge), a güç
uniform float base_y = 0.0;                 // aracın normal zemin yüksekliği (dünya)

const float BODY = 0.55;
const float SOFT = 0.018;

varying vec2 local;
varying vec2 reach;
varying float fade;

void vertex() {
	local = VERTEX.xz - center;
	reach = (inverse(mat3(MODEL_MATRIX)) * sun_shift).xz * height;
	fade = 1.0 - smoothstep(0.03, 0.1, MODEL_MATRIX[3].y - base_y);
}

float sd_box(vec2 q, vec2 b, float r) {
	vec2 e = abs(q) - b + r;
	return length(max(e, 0.0)) + min(max(e.x, e.y), 0.0) - r;
}

void fragment() {
	float d = 1e3;
	for (int i = 0; i <= 5; i++) {
		float t = float(i) / 5.0;
		d = min(d, sd_box(local - reach * (BODY * t), half_size, 0.035));
		d = min(d, sd_box(local - reach * mix(BODY, 1.0, t), half_size * vec2(0.8, 0.5), 0.045));
	}
	float s = (1.0 - smoothstep(-SOFT, SOFT, d)) * tint.a * fade;
	ALBEDO = mix(vec3(1.0), tint.rgb, s);
}
