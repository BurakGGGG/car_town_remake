shader_type canvas_item;
// PANO ARKA PLANI (ETKİNLİK PANOSU, ui/hud/event_screen.gd): arkadaki oyun ekranı bulanık, biraz soluk ve karanlık
// (kullanıcı 2026-10-26: "arka plan daha bulanık olsun"). Bulanıklık ekran dokusunun mipmap'inden tek örnekle okunur —
// garaj düzenleme odağıyla (garage_focus.gdshader) aynı yöntem, telefonda denendi: mobilde ucuz.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// 0 = net (açılış başı), 1 = tam bulanık + karanlık (tween).
uniform float strength : hint_range(0.0, 1.0) = 1.0;
uniform float blur_lod = 3.4;
uniform float dim = 0.5;
uniform float desaturate = 0.3;

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, blur_lod * strength).rgb;
	float luma = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(luma), desaturate * strength) * mix(1.0, dim, strength);
	COLOR = vec4(c, 1.0);
}
