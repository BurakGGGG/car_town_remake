// KAMERA GÖRÜNTÜSÜ (profil fotoğrafı çekimi, CameraCapture): CameraServer akışını RGB'ye çevirir.
// Telefon kameraları çoğunlukla Y + CbCr ayrı dokular verir (CameraFeed.FEED_YCBCR_SEP); masaüstü web kamerası RGB.
// feed_x / feed_y / feed_o: CameraFeed.feed_transform (yön / ayna; Godot'un ortam arka planıyla aynı dönüşüm).
shader_type canvas_item;

uniform sampler2D rgb_tex : filter_linear;
uniform sampler2D y_tex : filter_linear;
uniform sampler2D cbcr_tex : filter_linear;
uniform bool separate = false;
uniform bool mirror = false;
uniform vec2 feed_x = vec2(1.0, 0.0);
uniform vec2 feed_y = vec2(0.0, -1.0);
uniform vec2 feed_o = vec2(0.0, 1.0);

void fragment() {
	vec2 uv = UV;
	if (mirror) {
		uv.x = 1.0 - uv.x;
	}
	uv = feed_x * uv.x + feed_y * uv.y + feed_o;
	if (separate) {
		float y = texture(y_tex, uv).r;
		vec2 c = texture(cbcr_tex, uv).rg - vec2(0.5);
		COLOR = vec4(y + 1.402 * c.y, y - 0.344 * c.x - 0.714 * c.y, y + 1.772 * c.x, 1.0);
	} else {
		COLOR = vec4(texture(rgb_tex, uv).rgb, 1.0);
	}
}
