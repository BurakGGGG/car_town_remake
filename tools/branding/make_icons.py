#!/usr/bin/env python3
"""Uygulama ikonlarını tek bir 512x512 Play Store ikonundan üretir (assets/branding/).

Kullanım: python3 tools/branding/make_icons.py <autoyard_playstore_512.png>
Gerekenler: Pillow, numpy, scipy (venv: python3 -m venv v && v/bin/pip install pillow numpy scipy)

Kaynak TAM KARE bir ikondur: altın çerçeve, mavi ışın (sunburst) zemin, ortada logo. Çıktılar:
  icon_512.png                  proje ikonu + Play Store ikonu: kaynağın birebir kopyası
  launcher_192.png              eski (adaptive olmayan) başlatıcılar: kaynağın küçültülmüşü
  adaptive_foreground_432.png   yalnızca LOGO (şeffaf), güvenli bölgeye sığacak kadar küçük, yumuşak gölgeli
  adaptive_background_432.png   ışınlı mavi zemin: kaynaktan ölçülen renk profili + ışınlar yeniden üretilir (altın çerçeve yok)
  adaptive_monochrome_432.png   Android 13 temalı ikon: logonun parlaklıktan türetilmiş siluet maskesi

Neden böyle: logo kaynağın %85'ini kaplıyor; kare ikonu olduğu gibi adaptive ön plana koymak ya logoyu çember
maskede keser ya da "ikon içinde ikon" gösterir. Logo ayrılıp küçültülür, zemin tuvali dolduracak şekilde yeniden üretilir
(logoyu zeminden silip doldurmak denendi: logo ışınların çoğunu kapattığı için doldurma izli çıkıyor).

Adaptive ölçü: tuval 108dp = 432px; maske 72dp = 288px'lik ortadaki pencereye uygulanır, güvenli bölge 66dp daire.
Logo bölgesi: zeminin "mavi, doygun" olmasından yararlanılır; altın dış hat logoyu zeminden ayırır, dıştaki
zemin bileşeninin dışında kalan her şey logodur.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage as ndi

OUT = Path(__file__).resolve().parents[2] / "assets" / "branding"
CANVAS = 432
LOGO_PX = 236            # logonun ön plandaki genişliği (güvenli bölge dairesi 264px)
BG_SCALE = 0.84          # zeminin tuvale oranı: kaynağın 85..427 aralığı görünür pencere olur, altın çerçeve dışarıda kalır
MAX_LOGO_H, MAX_LOGO_W = 400, 450   # bundan büyük zemin-dışı bileşen çerçeve halkasıdır
RAYS = 18               # zemindeki ışın sayısı
HALO = 16                # logonun etrafındaki koyu gölge halesi: zemin doldurulurken bu pay da silinir


def logo_region(img: Image.Image) -> np.ndarray:
	hsv = np.asarray(img.convert("RGB").convert("HSV")).astype(np.float32)
	h, sat, val = hsv[..., 0] * 360.0 / 255.0, hsv[..., 1] / 255.0, hsv[..., 2] / 255.0
	bg_like = (h > 205) & (h < 250) & (sat > 0.45) & (val < 0.9)
	labels, _ = ndi.label(bg_like)
	bg_main = labels == labels[60, 256]   # üst ortadaki ışınlı zemin
	# Zemin dışı bileşenler: logo (432x240 civarı) ve çerçeve halkası / çerçeve dışı köşeler (400+ px boyunda).
	# Halka ve köşeler logo değil: yüksekliği 400'ü ya da genişliği 450'yi aşanlar atılır.
	lab, n = ndi.label(~bg_main)
	keep_ids = [i + 1 for i, sl in enumerate(ndi.find_objects(lab))
			if sl[0].stop - sl[0].start < MAX_LOGO_H and sl[1].stop - sl[1].start < MAX_LOGO_W]
	region = np.isin(lab, keep_ids)
	# Kalan küçük lekeler (tek tük piksel) logo sayılmaz: en büyük bileşeni ve ona yakın kabarcıkları tut
	lab, n = ndi.label(ndi.binary_dilation(region, iterations=6))
	sizes = ndi.sum(region, lab, range(1, n + 1))
	keep = lab == (1 + int(np.argmax(sizes)))
	return ndi.binary_fill_holes(region & keep)


def synth_background(img: Image.Image, region: np.ndarray) -> Image.Image:
	"""Işınlı zemini YENİDEN ÜRETİR (logo silinemeyeceği için): merkezden uzaklığa göre renk profili logodan
	etkilenmeyen temiz pikseller (üst/alt dikey kesitler) ölçülerek çıkarılır, üstüne soluk ışın modülasyonu eklenir.
	Işınlar ~%2,5 genlikli ve 18 adettir (kaynakta ölçüldü); profil logonun kapladığı yarıçaplara dışarıdan uzatılır."""
	rgb = np.asarray(img.convert("RGB")).astype(np.float32)
	yy, xx = np.mgrid[0:512, 0:512].astype(np.float32)
	dy, dx = yy - 255.5, xx - 255.5
	r, th = np.hypot(dx, dy), np.arctan2(dy, dx)
	clean = ~ndi.binary_dilation(region, iterations=HALO) & (r < 212)   # 212+: altın çerçevenin iç parıltısı
	vertical = np.abs(np.abs(th) - np.pi / 2) < np.radians(50)
	use = clean & vertical
	prof = np.full((260, 3), np.nan, np.float32)
	ri = r.astype(int)
	for k in range(260):
		m = use & (ri == k)
		if m.sum() > 6:
			prof[k] = rgb[m].mean(0)
	valid = np.where(~np.isnan(prof[:, 0]))[0]
	first, last = int(valid[0]), int(valid[-1])
	# Merkez (logonun kapladığı yarıçaplar): ölçülen eğimle geriye 60px uzatılır, sonra sabit tutulur (ani plato olmasın)
	inward = (prof[min(first + 30, last)] - prof[first]) / float(max(min(first + 30, last) - first, 1))
	for k in range(first - 1, -1, -1):
		prof[k] = np.clip(prof[k + 1] - inward * (1.0 if first - k <= 60 else 0.0), 0, 255)
	for k in range(first, last + 1):
		if np.isnan(prof[k, 0]):
			prof[k] = prof[k - 1]
	prof[first:last + 1] = ndi.gaussian_filter1d(prof[first:last + 1], 4.0, axis=0, mode="nearest")
	slope = (prof[last] - prof[max(last - 50, first)]) / float(last - max(last - 50, first))
	for k in range(last + 1, 260):
		prof[k] = np.maximum(prof[last] + slope * (k - last), 0)
	# Işın modülasyonu: ölçülen oran = piksel / profil - 1  ->  cos/sin(18θ) en küçük kareler
	g = prof[np.clip(ri, 0, 259)]
	ratio = (rgb.mean(2) / np.maximum(g.mean(2), 1.0)) - 1.0
	fit = use & (r > 150)
	basis = np.stack([np.cos(RAYS * th[fit]), np.sin(RAYS * th[fit]), np.ones(fit.sum())], axis=1)
	coef, *_ = np.linalg.lstsq(basis, ratio[fit], rcond=None)
	return prof, coef


def background_layer(prof: np.ndarray, coef: np.ndarray) -> Image.Image:
	"""Tuval boyunda zemin: tuval pikseli kaynak koordinatına BG_SCALE ile eşlenir."""
	k = (CANVAS / 512.0) * BG_SCALE
	yy, xx = np.mgrid[0:CANVAS, 0:CANVAS].astype(np.float32)
	dy, dx = (yy - (CANVAS - 1) / 2.0) / k, (xx - (CANVAS - 1) / 2.0) / k
	r, th = np.hypot(dx, dy), np.arctan2(dy, dx)
	base = np.stack([np.interp(r, np.arange(260), prof[:, c]) for c in range(3)], axis=-1)
	mod = 1.0 + coef[0] * np.cos(RAYS * th) + coef[1] * np.sin(RAYS * th)
	return Image.fromarray((base * mod[..., None]).clip(0, 255).astype(np.uint8), "RGB").convert("RGBA")


def logo_layer(img: Image.Image, region: np.ndarray) -> Image.Image:
	"""Logo + yumuşak gölge (silinen koyu halenin yerine)."""
	core = ndi.binary_erosion(region, iterations=1)   # kenardaki zemin karışımı pikselleri atılır
	alpha = np.clip(ndi.gaussian_filter(core.astype(np.float32), 0.7) * 1.2, 0, 1)
	shadow = np.clip(ndi.gaussian_filter(np.roll(region.astype(np.float32), 5, axis=0), 5.0) * 1.4, 0, 1) * 0.6
	rgb = np.asarray(img.convert("RGB")).astype(np.float32)
	sh_col = np.array([6, 16, 62], np.float32)
	out_a = alpha + shadow * (1 - alpha)
	out_rgb = (rgb * alpha[..., None] + sh_col * (shadow * (1 - alpha))[..., None]) / np.maximum(out_a, 1e-4)[..., None]
	return Image.fromarray(np.dstack([out_rgb, out_a * 255]).clip(0, 255).astype(np.uint8), "RGBA")


def silhouette(img: Image.Image, region: np.ndarray) -> np.ndarray:
	"""Logonun parlak yüzleri (beyaz harf, altın, jant) opak; lacivert dış hat şeffaf."""
	a = np.asarray(img.convert("RGB"), dtype=np.float32)
	lum = 0.299 * a[..., 0] + 0.587 * a[..., 1] + 0.114 * a[..., 2]
	return np.clip((lum - 100.0) / 45.0, 0.0, 1.0) * ndi.gaussian_filter(region.astype(np.float32), 0.7)


def place(layer: Image.Image, width: int, bbox: tuple) -> Image.Image:
	"""Katmanı bbox'ının genişliği `width` olacak şekilde küçültüp tuvale ortalar."""
	x0, y0, x1, y1 = bbox
	scale = width / float(x1 - x0)
	size = (int(round(layer.width * scale)), int(round(layer.height * scale)))
	small = layer.resize(size, Image.LANCZOS)
	cx, cy = (x0 + x1) / 2.0 * scale, (y0 + y1) / 2.0 * scale
	canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
	canvas.alpha_composite(small, (int(round(CANVAS / 2 - cx)), int(round(CANVAS / 2 - cy))))
	return canvas


def main() -> None:
	src = Image.open(sys.argv[1]).convert("RGBA")
	assert src.size == (512, 512), "kaynak 512x512 olmalı"
	OUT.mkdir(parents=True, exist_ok=True)
	src.save(OUT / "icon_512.png")
	src.resize((192, 192), Image.LANCZOS).save(OUT / "launcher_192.png")

	region = logo_region(src)
	ys, xs = np.where(region)
	bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)   # gölge payı sığsın diye hafif geniş
	pad = 10
	bbox = (bbox[0] - pad, bbox[1] - pad, bbox[2] + pad, bbox[3] + pad)

	prof, coef = synth_background(src, region)
	print("ışın genliği: %.1f%%" % (100 * float(np.hypot(coef[0], coef[1]))))
	background_layer(prof, coef).save(OUT / "adaptive_background_432.png")

	logo = logo_layer(src, region)
	place(logo, LOGO_PX, bbox).save(OUT / "adaptive_foreground_432.png")

	white = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
	white.putalpha(Image.fromarray((silhouette(src, region) * 255).astype(np.uint8), "L"))
	place(white, LOGO_PX, bbox).save(OUT / "adaptive_monochrome_432.png")
	print("yazıldı:", ", ".join(sorted(p.name for p in OUT.glob("*.png"))), "| logo kutusu", bbox)


if __name__ == "__main__":
	main()
