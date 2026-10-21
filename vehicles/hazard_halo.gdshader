// DÖRTLÜ (HAZARD) HALESİ — trafik aracının dört köşesinde yanıp sönen sarı ışık (HazardLights). Polis halesiyle aynı
// yöntem (police_beacon_halo.gdshader): bütün haleler TEK mesh, dört köşe hale merkezinde; köşe UV'den açılır ve
// kameraya döner. Yanıp sönme GPU saatiyle (TIME): kare başı betik yok. Sönükken dörtgen sıfır boy → piksel çizilmez.
// Toplamalı karışım: siyah = görünmez.

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

uniform float size = 0.08;      // hale yarıçapı (araç uzayı)
uniform float lift = 0.025;     // kameraya doğru öne alma: lamba camının içinde kaybolmasın (büyük olursa uzak köşe gövdenin dışında parlar)
uniform float rate = 1.45;      // yanıp sönme (Hz)
uniform float duty = 0.55;      // yanık kalma payı
uniform float phase = 0.0;      // araç başına faz
uniform vec3 color : source_color = vec3(1.0, 0.56, 0.06);
uniform float intensity = 1.9;

varying vec2 corner;
varying float glow;

void vertex() {
	// NORMAL = lambanın baktığı yön (araç uzayı): kameradan uzağa bakan lamba söner (ortografik: görüş -Z)
	float facing = smoothstep(-0.12, 0.2, normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz).z);
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 center = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	center.z += lift * scale;
	corner = UV * 2.0 - 1.0;
	float t = fract(TIME * rate + phase);
	// Kenarları yumuşak kare dalga: ampul gibi hızlı yanar, biraz daha yavaş söner
	float on = smoothstep(0.0, 0.06, t) * (1.0 - smoothstep(duty, duty + 0.12, t));
	glow = on;
	VERTEX = center + vec3(corner * size * scale * step(0.02, on) * facing, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
}

void fragment() {
	float r = length(corner);
	float core = pow(max(1.0 - r, 0.0), 2.0);
	vec3 c = color * core * 1.4 * intensity * glow;
	c += vec3(1.0, 0.9, 0.7) * pow(max(1.0 - r * 2.8, 0.0), 2.0) * 0.7 * glow;   // sıcak öz
	ALBEDO = c;
}
