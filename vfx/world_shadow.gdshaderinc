// ŞEHİR GÖLGESİ — WorldShadow'un (vfx/world_shadow.gd) pişirdiği gölge haritasını zeminde okur.
//
// Harita, statik nesnelerin GÜNEŞ YÖNÜNDEN dik izdüşümüdür: dünya noktası güneş ışını boyunca kayarsa haritadaki
// yeri değişmez. Bu yüzden zeminin hangi yükseklikte olduğu fark etmez — çimen (y −0,1), yol (0) ve kaldırım
// (0,02) aynı haritadan doğru gölgeyi alır. Zeminler gölge düşürmez (haritaya çizilmez), kendi kendini karartmaz.
// Değerler malzemeye WorldShadow tarafından yazılır; güç 0 iken (varsayılan) gölge yoktur — aynı shader başka
// dünyalarda (garaj ziyareti, ekranlar) kullanıldığında şehrin gölgesi oraya düşmez.

uniform sampler2D world_shadow_map : hint_default_black, filter_linear, repeat_disable;
uniform vec4 world_shadow_u = vec4(0.0);   // xyz · dünya + w = harita u
uniform vec4 world_shadow_v = vec4(0.0);   // xyz · dünya + w = harita v
uniform vec4 world_shadow_tint = vec4(1.0, 1.0, 1.0, 0.0);   // rgb gölgedeki çarpan (ALBEDO, Compatibility: sRGB), a güç

vec3 world_shadow_factor(vec3 world) {
	vec2 uv = vec2(dot(world, world_shadow_u.xyz) + world_shadow_u.w, dot(world, world_shadow_v.xyz) + world_shadow_v.w);
	vec2 inside = step(vec2(0.0), uv) * step(uv, vec2(1.0));
	float s = texture(world_shadow_map, uv).r * world_shadow_tint.a * inside.x * inside.y;
	return mix(vec3(1.0), world_shadow_tint.rgb, s);
}
