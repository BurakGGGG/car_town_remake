shader_type canvas_item;
// EĞİTİM SPOT IŞIĞI — ekranı karartır, hedefin çevresinde yuvarlatılmış bir delik açar.
// Deliğin kenarında amber bir parıltı ve dışa doğru yayılan halkalar (dikkat çeker, göz yormaz).
// Delik koordinatları piksel cinsindendir (ColorRect'in kendi alanında): TutorialOverlay her karede yazar.

uniform vec2 rect_size = vec2(1152.0, 648.0);
// x, y, genişlik, yükseklik (px)
uniform vec4 hole = vec4(0.0, 0.0, 0.0, 0.0);
uniform float has_hole = 0.0;
uniform float corner = 16.0;
// Karartma (0 = yalnızca parıltı, oyun kapanmaz)
uniform float dim = 0.0;
// Parıltı + halkaların gücü
uniform float glow = 0.0;
uniform vec4 glow_color : source_color = vec4(0.96, 0.75, 0.30, 1.0);
uniform vec4 shade_color : source_color = vec4(0.03, 0.04, 0.07, 1.0);

float sd_round_rect(vec2 p, vec2 center, vec2 half_size, float r) {
	vec2 q = abs(p - center) - half_size + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

void fragment() {
	vec2 p = UV * rect_size;
	float d = 100000.0;
	if (has_hole > 0.5) {
		// Delik hafifçe "nefes alır"
		vec2 half_size = hole.zw * 0.5 + vec2(sin(TIME * 3.2) * 2.5);
		float r = min(corner, min(half_size.x, half_size.y));
		d = sd_round_rect(p, hole.xy + hole.zw * 0.5, half_size, r);
	}
	// Karartma: deliğin kenarında yumuşak geçiş, köşelere doğru biraz daha koyu (vinyet)
	vec2 centered = UV - vec2(0.5);
	float shade = dim * smoothstep(0.0, 14.0, d);
	shade = clamp(shade + dot(centered, centered) * 0.55 * dim, 0.0, 0.92);
	// Kenar parıltısı: deliğin hemen dışında ince parlak çizgi
	float outside = max(d, 0.0);
	float rim = exp(-(outside * outside) / 18.0) * step(-3.0, d);
	// İki yayılan halka (faz kaydırmalı), dışarı çıktıkça söner
	float ripple = 0.0;
	for (int i = 0; i < 2; i++) {
		float t = fract(TIME / 1.7 + float(i) * 0.5);
		float rd = d - t * 52.0;
		ripple += exp(-(rd * rd) / 22.0) * (1.0 - t) * step(0.0, d);
	}
	float light = clamp(rim * 0.95 + ripple * 0.6, 0.0, 1.0) * glow * has_hole;
	vec3 color = mix(shade_color.rgb, glow_color.rgb, clamp(light / max(light + shade, 0.001), 0.0, 1.0));
	COLOR = vec4(color, clamp(shade + light, 0.0, 1.0));
}
