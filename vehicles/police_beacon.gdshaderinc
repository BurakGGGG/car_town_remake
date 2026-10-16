// POLİS IŞIĞI ZAMANLAMASI — lens (police_lights.gdshader) ve hale (police_beacon_halo.gdshader) AYNI fonksiyonu
// kullanır; ikisi aynı rate / phase / mode ile kurulur (PoliceLights), böylece hale ile lens aynı karede yanar.
// Desen: aracın sol yarısı iki kısa çakma, yarım döngü sonra sağ yarısı iki kısa çakma (wig-wag + çift strob).
// side < 0 sol (araç uzayında -X), side >= 0 sağ. Saat GPU'nun TIME'ı: kare başı betik maliyeti yok.

uniform float rate = 1.6;    // döngü / sn (bir döngüde iki yarı da bir kez çakar)
uniform float phase = 0.0;   // araç başına rastgele kayma (iki polis aracı aynı anda çakmasın)
uniform int mode = 0;        // 0 çakar, 1 sürekli yanık (küçük resim), 2 sönük

float beacon_on(float side, float time) {
	if (mode == 1) {
		return 1.0;
	}
	if (mode == 2) {
		return 0.0;
	}
	float t = fract(time * rate + phase + (side < 0.0 ? 0.0 : 0.5));
	float first = step(t, 0.15);
	float second = step(0.22, t) * step(t, 0.37);
	return max(first, second);
}
