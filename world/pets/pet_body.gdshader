shader_type spatial;
render_mode cull_disabled;
// GARAJ DOSTLARI — kedinin gövde gölgelendiricisi (glb'nin StandardMaterial3D'si yerine; aynı ayarlar: çift yüzlü,
// metalik 0, pürüzlülük 0,8). Tek fark GİZLEME MASKESİ: kıyafet giyilince kedinin UV'sinde kıyafetin altında kalan yer
// (tools/pets/tekir_wear.py → assets/pets/acc/<kıyafet>_mask.png, kenardan 7 mm içeride) çizilmez. Yatarken /
// kıvrılırken derinin kendi kıvrımı kıyafetin içinden dışarı taşıyordu (göğüs tüyü dirsekte); deri orada yoksa taşamaz.

uniform sampler2D albedo_texture : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform sampler2D hide_mask : hint_default_black, filter_nearest, repeat_disable;
uniform float roughness = 0.8;

void fragment() {
	if (texture(hide_mask, UV).r > 0.5) {
		discard;
	}
	ALBEDO = texture(albedo_texture, UV).rgb;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
