// POLİS IŞIĞI HALESİ — lensin çaktığı anda üstünde parlayan ışık (yuvarlak öz + yatay ışın). Oyun kamerasında araç
// küçük; lens tek başına birkaç piksel kalıyordu. Bütün haleler TEK mesh'tir (PoliceLights.halo_mesh): her hale bir
// dörtgen, dört köşesi de hale MERKEZİNDE durur; köşe UV'den açılır ve kameraya döner (billboard). UV2.x = yarı
// (-1 sol / +1 sağ), COLOR = ışık rengi. Sönükken dörtgen sıfır boydadır → hiç piksel çizilmez.
// Toplamalı karışım: siyah = görünmez, saydam dörtgen kenarı oluşmaz (GL Compatibility'de alfa karışımlı dörtgenin
// gölgeli sahnede kare çizilmesi sorunu yok — bkz. vfx/luxury_sparkle.gdshader notu).

shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, skip_vertex_transform;

#include "res://vehicles/police_beacon.gdshaderinc"

uniform float size = 0.10;    // hale yarıçapı (araç uzayı; araç boyu 1,0) — varsayılan zumda da okunsun
uniform float lift = 0.05;    // kameraya doğru öne alma: hale çubuğun / tavanın içinde kaybolmasın
uniform float intensity = 1.8;

varying vec3 tint;
varying vec2 corner;

void vertex() {
	float scale = length(MODEL_MATRIX[0].xyz);
	vec3 center = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	center.z += lift * scale;
	corner = UV * 2.0 - 1.0;
	float on = beacon_on(UV2.x, TIME);
	VERTEX = center + vec3(corner * size * scale * on, 0.0);
	NORMAL = vec3(0.0, 0.0, 1.0);
	tint = COLOR.rgb;
}

void fragment() {
	float r = length(corner);
	float core = pow(max(1.0 - r, 0.0), 2.2);
	float streak = exp(-abs(corner.y) * 16.0) * max(1.0 - abs(corner.x), 0.0);
	vec3 c = tint * (core * 1.3 + streak * 0.7) * intensity;
	c += vec3(1.0) * pow(max(1.0 - r * 2.6, 0.0), 2.0) * 0.8;   // beyaz sıcak nokta
	ALBEDO = c;
}
