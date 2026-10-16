shader_type canvas_item;
// Teaser son işleme: renk sapması (kesme anlarında darbe), vinyet, film greni, pozlama ve
// siyaha / beyaza karartma. Tam ekran ColorRect'e takılır (3B'nin ve yazının ÜSTÜNDE).
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float aberration = 0.0;      // piksel cinsinden kanal kayması (ekran genişliğinin binde biri)
uniform float vignette = 0.45;
uniform float grain = 0.05;
uniform float exposure = 1.0;
uniform float black = 0.0;           // 1 = tamamen siyah
uniform float white = 0.0;           // 1 = tamamen beyaz (flaş)
uniform float zoom_blur = 0.0;       // merkeze doğru radyal bulanıklık (hız)
uniform vec2 blur_center = vec2(0.5, 0.5);
uniform float seed = 0.0;
uniform vec3 tint = vec3(1.0);

float rnd(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233)) + seed * 17.13) * 43758.5453);
}

vec3 sample_ab(vec2 uv, vec2 dir) {
	float r = texture(screen, uv + dir).r;
	float g = texture(screen, uv).g;
	float b = texture(screen, uv - dir).b;
	return vec3(r, g, b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 from_c = uv - vec2(0.5);
	vec2 dir = from_c * aberration * 0.004;
	vec3 col = vec3(0.0);
	if (zoom_blur > 0.001) {
		vec2 to_c = uv - blur_center;
		for (int i = 0; i < 10; i++) {
			float k = float(i) / 9.0;
			col += sample_ab(uv - to_c * zoom_blur * k * 0.12, dir);
		}
		col /= 10.0;
	} else {
		col = sample_ab(uv, dir);
	}
	col *= exposure * tint;
	float v = smoothstep(0.85, 0.2, length(from_c * vec2(0.9, 1.1)));
	col *= mix(1.0, v, vignette);
	col += (rnd(uv * 913.0) - 0.5) * grain;
	col = mix(col, vec3(0.0), black);
	col = mix(col, vec3(1.0), white);
	COLOR = vec4(col, 1.0);
}
