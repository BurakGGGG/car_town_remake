// LASTİK İZİ (vfx/skid_marks.gd): drift sırasında yola çizilen kauçuk şeritleri. UV.x şeridin enine (0..1), UV.y
// boyuna birikimli uzunluk, UV2.x noktanın çizildiği an; köşe rengi (COLOR.a) o noktadaki kayma şiddeti. Kenarlar yumuşak,
// boyunca ince oluklar ve kumlanma (tek renk bant gibi durmasın). YAVAŞÇA SİLİNİR: yaşı fade_from'dan fade_to'ya giderken
// saydamlaşır (önce çizilen önce); solarken kauçuk biraz griye döner.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec3 tint : source_color = vec3(0.045, 0.045, 0.05);
uniform float strength = 0.62;
uniform float now = 0.0;
uniform float fade_from = 6.0;
uniform float fade_to = 70.0;

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float soft = 1.0 - smoothstep(0.5, 1.0, across);
	float grooves = 0.78 + 0.22 * sin(UV.x * 31.0 + sin(UV.y * 2.7) * 1.5);
	vec2 cell = floor(vec2(UV.x * 6.0, UV.y * 46.0));
	float grain = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	float age = smoothstep(fade_from, fade_to, now - UV2.x);
	float fade = 1.0 - age;
	ALBEDO = mix(tint, vec3(0.16, 0.16, 0.17), age * 0.6);
	ALPHA = clamp(COLOR.a * strength * soft * grooves * (0.78 + 0.22 * grain) * fade * fade, 0.0, 1.0);
}
