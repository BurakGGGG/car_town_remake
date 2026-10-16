shader_type spatial;
// Far huzmesi (Compatibility'de hacimli sis yok): toplamalı koni. Uca doğru söner, kenarları yumuşak,
// içinde yavaş akan toz gürültüsü. Koni yerel -Y ekseninde (CylinderMesh): UV.y 0 = tepe (far), 1 = taban.
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.9, 0.72);
uniform float intensity = 0.35;
uniform float drift = 0.0;

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1.0, 0.0, 0.0)), f.x),
				   mix(hash(i + vec3(0.0, 1.0, 0.0)), hash(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0.0, 0.0, 1.0)), hash(i + vec3(1.0, 0.0, 1.0)), f.x),
				   mix(hash(i + vec3(0.0, 1.0, 1.0)), hash(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}

void fragment() {
	float along = UV.y;
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	float soft = pow(facing, 1.6);
	float fade = pow(1.0 - along, 1.5) * smoothstep(0.0, 0.06, along);
	vec3 q = local_pos * 6.0 + vec3(drift * 0.7, drift * 0.25, drift);
	float dust = 0.55 + 0.45 * value_noise(q) + 0.25 * value_noise(q * 3.1);
	ALBEDO = color;
	ALPHA = clamp(intensity * soft * fade * dust, 0.0, 1.0);
}
