shader_type canvas_item;
// HIZ ÇİZGİLERİ — drag yarışında ekran kenarlarında akan ince rüzgâr çizgileri.
// `flow`: dünyanın ekranda aktığı yön (piksel uzayında, birim vektör; aracın gidişinin tersi).
// `intensity` 0 iken DragRaceScreen düğümü gizler (dolum maliyeti yok).

uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 flow = vec2(-0.8, -0.6);
uniform float aspect = 1.777;
uniform float rows = 70.0;

float hash(float n) {
	return fract(sin(n * 127.1) * 43758.5453);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	vec2 dir = normalize(flow);
	float along = dot(p, dir);
	float across = dot(p, vec2(-dir.y, dir.x));
	float row = floor(across * rows);
	float h = hash(row);
	float h2 = hash(row + 31.7);
	// Satırların yalnızca bir kısmında çizgi olur (seyrek, dağınık)
	float active = step(0.55, h);
	float cell = fract(across * rows);
	float thin = smoothstep(0.5, 0.18, abs(cell - 0.5));
	// Çizgi akış yönünde kayar: uzunluk ve hız satıra göre değişir
	float s = fract(along * (0.55 + h2 * 0.6) - TIME * (1.6 + h2 * 1.8) + h * 7.0);
	float len = 0.18 + h2 * 0.22;
	float streak = smoothstep(0.0, 0.03, s) * smoothstep(len, 0.0, s);
	// Merkez temiz kalır (araçlar), kenarlara doğru güçlenir
	float edge = smoothstep(0.22, 0.65, length(p * vec2(0.8, 1.15)));
	float a = active * thin * streak * edge * intensity * 0.8;
	COLOR = vec4(1.0, 0.98, 0.93, a);
}
