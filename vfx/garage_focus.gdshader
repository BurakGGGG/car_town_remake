shader_type canvas_item;
// GARAJ DÜZENLEME ODAĞI (world/garage_focus.gd): ekranda garajın dış çizgisinin DIŞI bulanıklaşır,
// renginden çalar ve kararır; içi hiç değişmez (alfa 0 — eşyalar pikseli pikseline net kalır).
// Dış çizgi = garaj kutusunun izdüşümünün dışbükey zarfı, tuval biriminde; kamera kaydıkça
// script her kare günceller. Zarfın köşe sırası kenar normali (e.y, -e.x) DIŞARI bakacak şekilde
// verilir. Bulanıklık ekran dokusunun mipmap'inden okunur (tek örnek; mobilde ucuz).

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 screen_size = vec2(1152.0, 648.0);
uniform vec2 hull[8];
uniform int hull_count = 0;
// Geçiş zarfın kenarına ORTALANIR: kenarda yarım, `feather / 2` dışarıda tam etki, içeride o kadar
// sonra hiç. (Geçiş tamamen dışarıda olunca duvarların üstünde net, parlak bir çimen şeridi kalıyordu.)
uniform float margin = 0.0;
uniform float feather = 16.0;
// 0 = kapalı, 1 = tam odak (açılış / kapanışta tween).
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float blur_lod = 2.8;
uniform float dim = 0.55;
uniform float desaturate = 0.7;

void fragment() {
	vec2 p = SCREEN_UV * screen_size;
	float d = -1.0e6;
	for (int i = 0; i < 8; i++) {
		if (i >= hull_count) {
			break;
		}
		vec2 a = hull[i];
		vec2 e = hull[(i + 1) % hull_count] - a;
		float len = length(e);
		if (len > 0.001) {
			d = max(d, dot(p - a, vec2(e.y, -e.x) / len));
		}
	}
	float outside = hull_count >= 3 ? smoothstep(margin - feather * 0.5, margin + feather * 0.5, d) : 1.0;
	outside *= strength;
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod * outside).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma), desaturate) * dim;
	COLOR = vec4(c, outside);
}
