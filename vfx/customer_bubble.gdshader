shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;
// Müşteri balonu / TOPLA işareti: aracın (ya da CarSpot'un) üstünde kameraya dönük küçük krem plaka,
// koyu alt kenar ve çizili işaret (HUD plaka dili). glyph 0 = anahtar (müşteri), 1 = ₺ madeni para
// (ödül hazır; glyph_offset ile sola kaydırılır, sağda Label3D "TOPLA" yazar).
// Billboard vertex shader'da; hafif salınım TIME ile (script tarafında per-frame iş yok).

uniform vec4 plate_color : source_color = vec4(0.953, 0.910, 0.812, 1.0);
uniform vec4 edge_color : source_color = vec4(0.725, 0.651, 0.486, 1.0);
uniform vec4 ink_color : source_color = vec4(0.184, 0.196, 0.212, 1.0);
uniform vec4 coin_color : source_color = vec4(0.961, 0.745, 0.298, 1.0);
uniform vec4 coin_edge : source_color = vec4(0.698, 0.478, 0.110, 1.0);
uniform float aspect = 1.0;         // plaka genişlik/yükseklik (işaretler kare kalsın)
uniform int glyph = 0;
uniform float glyph_offset = 0.0;   // işaretin yatay kayması (plaka yüksekliği = 1 birim)
uniform float bob_amount = 0.012;

void vertex() {
	vec3 scale = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * scale.x, INV_VIEW_MATRIX[1] * scale.y, INV_VIEW_MATRIX[2] * scale.z, MODEL_MATRIX[3]);
	VERTEX.y += sin(TIME * 2.4) * bob_amount / max(scale.y, 0.001);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_capsule(vec2 p, vec2 a, vec2 b, float r) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h) - r;
}

// Anahtar: çapraz sap (kapsül) + halka + çentik. p plaka uzayında (-0.5..0.5).
float sd_wrench(vec2 p) {
	vec2 g = (p + vec2(0.0, 0.05)) * 3.0;
	float handle = sd_capsule(g, vec2(-0.62, -0.62), vec2(0.10, 0.10), 0.15);
	vec2 hc = vec2(0.40, 0.40);
	float ring = abs(length(g - hc) - 0.34) - 0.14;
	vec2 nd = normalize(vec2(1.0, 1.0));
	vec2 rel = g - hc;
	vec2 rp = vec2(dot(rel, nd), dot(rel, vec2(-nd.y, nd.x)));
	float notch = sd_round_box(rp - vec2(0.40, 0.0), vec2(0.26, 0.13), 0.0);
	return min(handle, max(ring, -notch));
}

// Madeni para üstündeki ₺: dikey çizgi + iki çapraz çentik. p para merkezine göre, plaka ölçeğinde.
float sd_lira(vec2 p) {
	float bar = sd_capsule(p, vec2(-0.01, -0.10), vec2(-0.01, 0.10), 0.022);
	float t1 = sd_capsule(p, vec2(-0.075, -0.045), vec2(0.045, 0.015), 0.02);
	float t2 = sd_capsule(p, vec2(-0.075, 0.015), vec2(0.045, 0.075), 0.02);
	float hook = abs(length(p - vec2(0.04, -0.06)) - 0.05) - 0.02;
	hook = max(hook, -(p.y + 0.06));  // yalnızca alt yarım halka
	hook = max(hook, -(p.x - 0.0));   // sağ taraf
	return min(min(bar, min(t1, t2)), hook);
}

void fragment() {
	vec2 p = vec2((UV.x - 0.5) * aspect, 0.5 - UV.y);   // y: -0.5..0.5 yukarı +, x en-boy oranıyla
	float plate = sd_round_box(p, vec2(0.47 * aspect, 0.40), 0.12);
	if (plate > 0.0) {
		discard;
	}
	bool edge = p.y < -0.30;                            // alt kalınlık bandı
	vec3 col = edge ? edge_color.rgb : plate_color.rgb;
	if (!edge) {
		vec2 gp = p - vec2(glyph_offset, 0.0);
		if (glyph == 1) {
			// Madeni para: amber disk, koyu kenar halkası, ortada ₺
			vec2 c = gp - vec2(0.0, 0.04);
			float disc = length(c) - 0.26;
			float rim = abs(length(c) - 0.235) - 0.03;
			float lira = sd_lira(c * 1.2);
			float aa = fwidth(disc) * 1.2;
			float in_disc = 1.0 - smoothstep(0.0, aa, disc);
			float in_rim = 1.0 - smoothstep(0.0, aa, rim);
			float in_lira = 1.0 - smoothstep(0.0, fwidth(lira) * 1.2, lira);
			col = mix(col, coin_color.rgb, in_disc);
			col = mix(col, coin_edge.rgb, max(in_rim, in_lira));
		} else {
			float wrench = sd_wrench(gp);
			float aa = fwidth(wrench) * 1.2;
			float ink = 1.0 - smoothstep(0.0, aa, wrench);
			col = mix(col, ink_color.rgb, ink);
		}
	}
	ALBEDO = col;
}
