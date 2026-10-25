shader_type spatial;
render_mode cull_disabled;
// STATİK TOPLU ÇİZİM, ÇİFT YÜZLÜ (world/static_batch.gd) — static_batch.gdshader'ın arka yüz ayıklamasız hâli: cull_mode'u
// kapalı (Blender'dan çift yüzlü gelen) düz renkli StandardMaterial3D yüzeyleri için.

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	SPECULAR = COLOR.a;
}
