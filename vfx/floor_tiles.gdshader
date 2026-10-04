shader_type spatial;
// GARAJ ZEMİNİ — karo karo boyanmış desenler TEK çizim çağrısında (vfx/decor_textures.gd, world/decor_grid.gd).
// Dünya noktasından gözü bulur, gözün desen indeksini küçük veri dokusundan okur (0 = varsayılan zemin),
// deseni Texture2DArray'den örnekler. Türevler sürekli koordinattan alınır: göz sınırında mipmap
// seçimi zıplamaz (fract() kenarında 1 piksellik çizgi çıkmaz).

uniform sampler2DArray patterns : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D tile_index : filter_nearest, repeat_disable;
uniform vec2 corner = vec2(-0.2, -0.2);
uniform float cell = 0.175;
uniform vec2 grid_size = vec2(32.0, 21.0);
uniform vec4 base_color : source_color = vec4(0.467, 0.467, 0.467, 1.0);
uniform float base_roughness = 0.85;
uniform float roughness_of[32];
uniform float metallic_of[32];
// Düzenleme önizlemesi: bu dikdörtgendeki gözler (min.xy, max.xy, göz indeksi, dahil) vurgulanır.
uniform vec4 preview_rect = vec4(-1.0, -1.0, -2.0, -2.0);
uniform vec4 preview_color : source_color = vec4(0.98, 0.71, 0.18, 0.35);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 d = (corner - world_pos.xz) / cell;
	ivec2 c = ivec2(floor(d));
	vec3 col = base_color.rgb;
	float rough = base_roughness;
	float metal = 0.0;
	if (c.x >= 0 && c.y >= 0 && c.x < int(grid_size.x) && c.y < int(grid_size.y)) {
		int k = int(texelFetch(tile_index, c, 0).r * 255.0 + 0.5);
		if (k > 0) {
			vec2 uv = fract(d);
			col = textureGrad(patterns, vec3(uv, float(k - 1)), dFdx(d), dFdy(d)).rgb;
			rough = roughness_of[k - 1];
			metal = metallic_of[k - 1];
		}
	}
	if (float(c.x) >= preview_rect.x && float(c.y) >= preview_rect.y
			&& float(c.x) <= preview_rect.z && float(c.y) <= preview_rect.w) {
		col = mix(col, preview_color.rgb, preview_color.a);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
}
