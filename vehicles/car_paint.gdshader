shader_type spatial;

// Dokulu araçlarda gövde boyası. Boya dokunun içine pişmiştir; hangi TEXEL'in boyanacağını aracın
// kendi UV düzenindeki paint mask belirler (tools/make_paint_mask.gd üretir):
//   mask = 0 → doku aynen (cam, far, stop, krom, siyah trim, plaka, ızgara, egzoz, anten)
//   mask = 1 → kaporta: fabrika boyası yeni renge çevrilir, dokunun gölgesi / parlaması / paneli korunur.
// Renk dönüşümü düz boyama DEĞİLDİR: texel'in parlaklığı (l) fabrika boyasının parlaklığına (pl)
// oranlanır ve yeni renk bu oranla çarpılır → dokunun gölgesi, parlaması, panel çizgileri, kiri ve
// pası aynen korunur; koyu renklerde de kaporta detayı kaybolmaz. Oran 1'i aşan parlamalarda renk
// kanal kanal kırpılıp ton kaymasın diye yumuşakça beyaza gider.
// recolor = 0 (varsayılan renk) iken doku hiç işlenmez. CarRig bu uniform'ları CarAppearance'tan doldurur.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D paint_mask : hint_default_black, filter_linear_mipmap;
uniform vec4 paint : source_color = vec4(1.0);   // dokudaki fabrika boyası (CarPartMap.default_paint)
uniform vec4 tint : source_color = vec4(1.0);    // istenen boya (CarAppearance.body_color)
uniform float recolor = 0.0;                     // 0 = doku aynen, 1 = maskeli bölge yeni renkte
uniform float highlight = 0.85;                  // parlamanın beyaza gitme oranı
uniform float metallic = 0.15;
uniform float roughness = 0.45;

const vec3 LUMA = vec3(0.299, 0.587, 0.114);

void fragment() {
	vec3 t = texture(albedo_tex, UV).rgb;
	float m = recolor * texture(paint_mask, UV).r;
	if (m > 0.001) {
		float l = max(dot(t, LUMA), 0.02);
		float pl = max(dot(paint.rgb, LUMA), 0.02);
		float ratio = l / pl;
		vec3 painted = tint.rgb * min(ratio, 1.0);
		painted = mix(painted, vec3(1.0), clamp(ratio - 1.0, 0.0, 1.0) * highlight);
		t = mix(t, clamp(painted, vec3(0.0), vec3(1.0)), m);
	}
	ALBEDO = t;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}
