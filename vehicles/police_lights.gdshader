// POLİS IŞIK LENSİ — CarPartMap "police_lights" parçalarının (tavan çubuğu, ızgara flaşörü) materyali.
// Görünüm aracın kendi dokusudur (GLB materyaliyle aynı: atlas, metalik 0, çift yüz). Çakan kısım dokudan
// SEÇİLİR: doygun ve yeterince parlak KIRMIZI ya da MAVİ texel lens sayılır; çubuğun gövdesi, koyu tabanı ve
// krom kısımları ışımaz. Işıma rengi texel'in kendi tonudur (parlaklığa normalize), yani kırmızı lens kırmızı,
// mavi lens mavi yanar — renk haritaya yazılmaz. Sol / sağ yarı ayrımı ARAÇ UZAYINDA X işaretiyle yapılır:
// parça kendi yerel uzayında çizildiği için side_plane = parça dönüşümünün X satırı (PoliceLights hesaplar).

shader_type spatial;
render_mode cull_disabled;

#include "res://vehicles/police_beacon.gdshaderinc"
#include "res://vehicles/car_texture.gdshaderinc"

uniform sampler2D albedo_tex : source_color, hint_default_white, filter_linear_mipmap;
uniform vec4 side_plane = vec4(1.0, 0.0, 0.0, 0.0);   // dot(VERTEX, xyz) + w = araç uzayında x
uniform float energy = 2.6;

varying float side;

void vertex() {
	side = dot(VERTEX, side_plane.xyz) + side_plane.w;
}

void fragment() {
	vec3 t = car_texture(albedo_tex, UV).rgb;   // sınırlı mipmap (car_texture.gdshaderinc)
	float hi = max(t.r, max(t.g, t.b));
	float lo = min(t.r, min(t.g, t.b));
	float sat = (hi - lo) / max(hi, 0.001);
	// Kırmızı ya da mavi baskın (sarı / yeşil kaplama şeridi lens değildir)
	float red_or_blue = max(step(max(t.g, t.b), t.r), step(max(t.r, t.g), t.b));
	float lens = red_or_blue * smoothstep(0.35, 0.55, sat) * smoothstep(0.16, 0.32, hi);
	float on = beacon_on(side, TIME);
	ALBEDO = t;
	METALLIC = 0.0;
	ROUGHNESS = 0.35;
	// Ton kübü: baskın kanal 1, diğerleri bastırılır — ışıma doygun kalır (mavi lens camgöbeğine, kırmızı pembeye kaymaz)
	EMISSION = pow(t / max(hi, 0.05), vec3(3.0)) * lens * on * energy;
}
