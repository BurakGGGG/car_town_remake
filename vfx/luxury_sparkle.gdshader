// LÜKS EŞYA IŞILTISI — garajdaki elmasla alınmış eşyaların üstünde ara ara parlayan dört köşeli yıldız.
// Tek MultiMesh (vfx/luxury_sparkles.gd): her yıldız bir örnek; INSTANCE_CUSTOM.x evre (0..1), .y boy.
// SAYDAMLIK YOK: GL Compatibility'de gölgeli sahnede saydam dörtgen kare çiziliyordu (bkz. loading art);
// yıldız opak geometridir, görünüp kaybolması BOYUTLA olur (0 → tam → 0).
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_opaque;

uniform vec4 tint : source_color = vec4(1.0, 0.96, 0.78, 1.0);
// Bir yıldızın iki parlaması arasındaki süre (sn) ve parlamanın bu sürenin ne kadarı olduğu.
uniform float period = 2.8;
uniform float flash = 0.22;

void vertex() {
	float phase = INSTANCE_CUSTOM.x;
	float t = fract(TIME / period + phase);
	float pulse = smoothstep(0.0, flash * 0.45, t) * (1.0 - smoothstep(flash * 0.45, flash, t));
	float spin = TIME * 1.2 + phase * 6.2832;
	vec2 v = VERTEX.xy * pulse * INSTANCE_CUSTOM.y;
	v = mat2(vec2(cos(spin), sin(spin)), vec2(-sin(spin), cos(spin))) * v;
	// Kameraya dönük (billboard): örneğin dünya konumu korunur, yön kameradan alınır
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	VERTEX = vec3(v, 0.0);
}

void fragment() {
	ALBEDO = tint.rgb;
}
