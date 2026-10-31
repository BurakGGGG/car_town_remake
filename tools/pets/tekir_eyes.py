"""TEKİR KAPALI GÖZ DOKUSU: Meshy'nin parçalı UV'sinde gözler birkaç adacığa bölünmüş; doku 3B'de boyanır.

  1) blender -b --factory-startup --python tools/pets/tekir_eyes.py -- dump <tekir_rig.blend> <tris.npz>
  2) blender -b --factory-startup --python tools/pets/tekir_eyes.py -- paint <doku.png> <tris.npz> <çıktı.png> [kontrol.png]
     (sistem python'unda numpy yok: ikisi de Blender'ın python'uyla, görüntü G/Ç bpy ile)

Her doku pikselinin örgüdeki 3B yeri (dinlenme duruşu, metre) üçgenler UV'de taranarak bulunur. Göz bebekleri (en koyu
pikseller) iki kümeye ayrılır → göz merkezleri. Göz çevresi (3B yarıçap) halkadaki kürk rengiyle doldurulur ve göz
düzleminde aşağı kıvrık bir kapak çizgisi (‿, mutlu / uykulu) çizilir. Oyun uyurken / sevilirken bu dokuya geçer.
"""
import sys


def dump(blend: str, out: str) -> None:
    import bpy
    import numpy as np
    bpy.ops.wm.open_mainfile(filepath=blend)
    me = bpy.data.objects["Tekir"].data
    me.calc_loop_triangles()
    uv = me.uv_layers[0].data
    P = np.array([v.co[:] for v in me.vertices])
    n = len(me.loop_triangles)
    tri_uv, tri_p = np.zeros((n, 3, 2)), np.zeros((n, 3, 3))
    for i, t in enumerate(me.loop_triangles):
        for k in range(3):
            tri_uv[i, k] = uv[t.loops[k]].uv[:]
            tri_p[i, k] = P[t.vertices[k]]
    np.savez(out, uv=tri_uv, p=tri_p)
    print("RAPOR üçgen", n)


def position_map(tri_uv, tri_p, W: int, H: int):
    import numpy as np
    pos = np.full((H, W, 3), np.nan, dtype=np.float32)
    px = tri_uv.copy()
    px[..., 0] = tri_uv[..., 0] * W - 0.5
    px[..., 1] = (1.0 - tri_uv[..., 1]) * H - 0.5
    for t in range(len(px)):
        a, b, c = px[t]
        x0, x1 = int(max(np.floor(min(a[0], b[0], c[0])), 0)), int(min(np.ceil(max(a[0], b[0], c[0])), W - 1))
        y0, y1 = int(max(np.floor(min(a[1], b[1], c[1])), 0)), int(min(np.ceil(max(a[1], b[1], c[1])), H - 1))
        if x1 < x0 or y1 < y0:
            continue
        xs, ys = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
        v0, v1 = b - a, c - a
        d = v0[0] * v1[1] - v1[0] * v0[1]
        if abs(d) < 1e-12:
            continue
        wx, wy = xs - a[0], ys - a[1]
        l1 = (wx * v1[1] - v1[0] * wy) / d
        l2 = (v0[0] * wy - wx * v0[1]) / d
        l0 = 1 - l1 - l2
        m = (l0 >= -0.02) & (l1 >= -0.02) & (l2 >= -0.02)   # kenarda hafif taşma: dikiş pikselleri boş kalmasın
        if not m.any():
            continue
        P = tri_p[t]
        pts = l0[m, None] * P[0] + l1[m, None] * P[1] + l2[m, None] * P[2]
        pos[ys[m], xs[m]] = pts
    return pos


def load_rgb(path: str):
    """→ (H, W, 3) float 0..255, satır 0 = ÜST (PIL ile aynı yön)."""
    import bpy
    import numpy as np
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"   # ham değerler (sRGB dönüşümü olmadan)
    W, H = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(H, W, 4)[::-1, :, :3] * 255.0
    return a


def save_rgb(arr, path: str) -> None:
    import bpy
    import numpy as np
    H, W, _ = arr.shape
    im = bpy.data.images.new("out", W, H, alpha=False)
    im.colorspace_settings.name = "Non-Color"
    rgba = np.ones((H, W, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(arr, 0, 255)[::-1] / 255.0
    im.pixels = rgba.ravel()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


def paint(tex_path: str, tris: str, out: str, debug: str = "") -> None:
    import numpy as np
    d = np.load(tris)
    col = load_rgb(tex_path)
    H, W, _ = col.shape
    pos = position_map(d["uv"], d["p"], W, H)
    valid = ~np.isnan(pos[..., 0])
    lum = col @ np.array([0.299, 0.587, 0.114])
    # Göz bebekleri: yüzün önünde (y < −0,22 m), baş yüksekliğinde, çok koyu pikseller
    face = valid & (pos[..., 1] < -0.22) & (pos[..., 2] > 0.2)
    pupil = face & (lum < 40)
    pts = pos[pupil]
    left, right = pts[pts[:, 0] > 0], pts[pts[:, 0] <= 0]
    centers = {"L": left.mean(0), "R": right.mean(0)}
    gap = float(np.linalg.norm(centers["L"] - centers["R"]))
    print("RAPOR göz bebeği pikseli", len(pts), "merkezler", {k: np.round(v, 4).tolist() for k, v in centers.items()},
          "aralık %.4f m" % gap)
    eye_r = gap * 0.30        # göz yarıçapı (iris dahil) — kontrol görüntüsüyle ayarlandı
    out_col = col.copy()
    for side, c in centers.items():
        # Göz düzlemi: yanal eksen = iki göz arası doğrultu, dikey eksen = yukarı (normal yaklaşık ileri+yana)
        lat = (centers["L"] - centers["R"]) / gap
        up = np.array([0.0, 0.0, 1.0])
        up = up - lat * np.dot(up, lat)
        up /= np.linalg.norm(up)
        rel = pos - c
        dist = np.linalg.norm(rel, axis=-1)
        near = valid & (dist < eye_r * 1.9)
        u = (rel @ lat) / eye_r            # −1..1 göz genişliği
        v = (rel @ up) / eye_r             # −1..1 göz yüksekliği
        eye = near & (u * u / 1.0 + v * v / 0.72 < 1.0)
        # Renk halkası gözden biraz uzakta: gözün hemen çevresi açık bej (göz çerçevesi), dolgu ona benzerse disk gibi kalıyordu
        rr = u * u / 1.0 + v * v / 0.72
        orange = (lum > 90) & (lum < 205) & (col[..., 0] - col[..., 2] > 55)   # beyaz ağız / koyu çizgi dışarıda
        ring = valid & orange & (dist < eye_r * 2.2) & (rr > 1.3) & (rr < 3.2)
        # Halka rengi: üst yarı ve alt yarı ayrı ortalama, göz içinde dikey geçiş (çizgiler kaybolmasın diye hafif gürültü)
        top = ring & (v > 0)
        bot = ring & (v <= 0)
        ct = np.median(col[top], axis=0) if top.any() else np.median(col[ring], axis=0)
        cb = np.median(col[bot], axis=0) if bot.any() else ct
        t = np.clip((v[eye] + 0.85) / 1.7, 0, 1)[:, None]
        rng = np.random.default_rng(7)
        fill = (cb * (1 - t) + ct * t)  + rng.normal(0, 5.0, (eye.sum(), 3))
        out_col[eye] = fill
        # Yumuşak kenar: halkanın iç kısmı dolguya karışır
        edge = near & ~eye & (u * u + v * v / 0.72 < 1.6)
        k = np.clip((np.sqrt(u[edge] ** 2 + v[edge] ** 2 / 0.72) - 1.0) / 0.6, 0, 1)[:, None]
        tt = np.clip((v[edge] + 0.85) / 1.7, 0, 1)[:, None]
        out_col[edge] = (cb * (1 - tt) + ct * tt) * (1 - k) + col[edge] * k
        # Kapak çizgisi: aşağı kıvrık yay v = −0,35·(1 − u²) − 0,05, kalınlık ~ 0,16 eye_r, uçlar incelir
        arc = -0.33 * (1 - u * u) - 0.02
        lw = 0.15 * (1 - 0.55 * np.abs(u))
        line = near & (np.abs(u) < 1.0) & (np.abs(v - arc) < lw)
        dark = np.array([58.0, 34.0, 22.0])
        a = np.clip(1 - np.abs(v[line] - arc[line]) / lw[line], 0, 1)[:, None] ** 0.6
        out_col[line] = out_col[line] * (1 - a) + dark * a
        print("RAPOR göz", side, "dolgu", int(eye.sum()), "çizgi", int(line.sum()))
    save_rgb(out_col, out)
    print("RAPOR yazıldı", out)
    if debug:
        dbg = col.copy()
        dbg[pupil] = [0, 255, 0]
        save_rgb(dbg, debug)


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args[0] == "dump":
        dump(args[1], args[2])
    else:
        paint(*args[1:])
