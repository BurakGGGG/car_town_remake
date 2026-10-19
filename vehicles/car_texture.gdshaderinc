// ARAÇ DOKU ATLASINI SINIRLI MİPMAP KADEMESİYLE ÖRNEKLER — dokulu araçların bütün shader'ları (car_textured,
// car_paint, wheel_split, police_lights) albedo'yu buradan okur.
//
// Neden (ölçüldü 2026-10-19, qa/uzak_arac_qa.gd): Tripo araç dokusu yüzlerce küçük UV adasından oluşan TEK atlas.
// Şehirde uzaklaşınca (zoom out) GPU derin mipmap kademesine iner; 1024² dokunun 64² / 32² kademesinde bir texel
// birbirine komşu birkaç adayı kapsar → kaporta rengi camla / trimle / komşu parçayla karışır: beyaz araçta gri
// lekeler, kırmızı araçta pembe sis, stoplar beyazlar. Mipmap'siz çizimde renkler doğru (karışma yok). Kademe en
// çok CAR_MAX_LOD'a iner (1024² dokuda 256²): renkler doğru kalır, en uzak zoom'da biraz daha keskin çizilir.
// Godot'nun içe aktarıcıdaki mipmaps/limit seçeneği etkisiz, Viewport.texture_mipmap_bias de Compatibility'de
// desteklenmiyor — sınır yalnızca shader'da konabiliyor.
const float CAR_MAX_LOD = 2.0;

vec4 car_texture(sampler2D tex, vec2 uv) {
	vec2 size = vec2(textureSize(tex, 0));
	vec2 dx = dFdx(uv) * size;
	vec2 dy = dFdy(uv) * size;
	float lod = 0.5 * log2(max(max(dot(dx, dx), dot(dy, dy)), 1e-8));
	return textureLod(tex, uv, clamp(lod, 0.0, CAR_MAX_LOD));
}
