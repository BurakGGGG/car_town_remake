shader_type spatial;
// DEKOR TOPLU ÇİZİMİ (world/static_batch.gd) — düz renkli dekor yüzeylerinin ortak materyali. Renk köşe renginden,
// pürüz / metaliklik UV2'den, specular köşe alfasından. GL Compatibility'de ALBEDO sRGB uzayındadır (motor ışıklandırmadan
// önce kendisi doğrusala çevirir; StandardMaterial3D'nin albedo_color'ı da böyle gider): renk olduğu gibi verilir.
// Işık modeli StandardMaterial3D'nin varsayılanı (Burley + Schlick-GGX, arka yüz ayıklama).

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	SPECULAR = COLOR.a;
}
