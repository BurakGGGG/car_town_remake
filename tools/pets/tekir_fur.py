"""TEKİR TÜY RENKLERİ (GARAJ DOSTLARI, 2026-11-03): aynı kedinin (aynı örgü, iskelet, hareketler) BEYAZ (mavi göz) ve
SİYAH (yeşil göz) dokuları. Kullanıcı kararı: şimdilik herkese turuncu tekir; beyaz ve siyah ilerideki EVCİL HAYVANLAR
ekranında (köpekler vb. ile) seçilecek — oyunda PetManager.set_fur / PetActor.set_fur hazır, arayüzde yok.

Turuncu dokudan piksel piksel türetilir (yeni UV yok, oyun yalnız albedo dokusunu değiştirir):
  - Tüy: turuncu / beyaz sınıfı doygunluğa göre YUMUŞAK karışır (UV adacıklarında dikiş çıkmasın); çizgiler çok hafif
    gölge olarak kalır (beyazda ~%5, siyahta tüy fırça izi gibi), beyaz bölgeler (göğüs, pati, ağız) de aynı renge döner.
  - Pembe (burun, kulak içi): beyazda kalır, siyahta koyu gri-pembe.
  - Yüz ayrıntıları (göz çizgisi, göz bebeği, kapalı gözün kapak çizgisi): yüzdeki KOYU pikseller tüy gibi açılmaz.
  - İris: tekir_eyes.py gibi 3B konum haritası; göz düzleminde (u, v) elips içi, parlaklık rampasıyla mavi / yeşil.
    Göz bebeği ve parlama yerinde kalır.
Açık ve kapalı göz dokusu aynı eşlemeden geçer (kapalı dokuda iris adımı yok: göz zaten tüyle dolu).

  blender -b --factory-startup --python tools/pets/tekir_fur.py -- <tekir_rig.blend> <çıktı_klasörü> [--preview]
  Çıktı: tekir_<renk>.png + tekir_<renk>_eyes_closed.png (+ önizleme önden/yandan, göz yakın planı). Oyuna JPEG
  (PIL, kalite 92) olarak assets/pets/fur/ altına kopyalanır; .import compress/mode=2, size_limit 1024.
"""
import sys, os, math
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tekir_eyes as TE   # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OPEN = os.path.join(ROOT, "assets/pets/tekir_Image_0.jpg")
CLOSED = os.path.join(ROOT, "assets/pets/tekir_eyes_closed.jpg")

LUMA = np.array([0.299, 0.587, 0.114])

# Göz açıklığı (göz düzleminde, birim = göz yarıçapı eye_r; merkez göz bebeği kümesinin ortası). Önden görünüm
# (--preview göz yakın planı) üstünde ölçüldü: badem biçimli, bebeğin biraz altında ve dış köşeye doğru.
EYE_OPEN = {"L": (0.06, -0.05, 0.80, 0.58), "R": (-0.12, -0.07, 0.80, 0.58)}   # (cu, cv, a, b)

VARIANTS = {
    "white": {
        # Oyun ışığında 246 bembeyaz / düz görünüyordu (2026-11-03 QA): taban biraz kısık, fırça izleri belirgin
        "fur": np.array([234.0, 232.0, 229.0]),
        "stripe_k": 0.16,         # turuncu sınıfındaki parlaklık farkının ne kadarı gölge olarak kalsın
        "white_k": 0.85,          # beyaz sınıfındaki (göğüs) fırça izleri
        "feature": np.array([88.0, 74.0, 78.0]),   # göz çizgisi / kapak: koyu pembe-gri
        "pink": None,             # pembe yerinde kalır
        "ear": np.array([238.0, 178.0, 184.0]),    # kulak içi: açık pembe
        "iris": [(0.0, (22, 48, 104)), (0.45, (52, 116, 196)), (0.8, (118, 182, 238)), (1.0, (196, 228, 250))],
    },
    "black": {
        "fur": np.array([44.0, 42.0, 48.0]),
        "stripe_k": 0.30,
        "white_k": 0.45,
        "feature": np.array([12.0, 11.0, 13.0]),
        "pink": np.array([58.0, 46.0, 52.0]),     # burun
        "ear": np.array([74.0, 58.0, 66.0]),      # kulak içi: koyu gri-pembe
        "iris": [(0.0, (30, 66, 22)), (0.45, (92, 160, 46)), (0.8, (172, 214, 74)), (1.0, (226, 240, 150))],
    },
}


def log(*a):
    print("RAPOR", *a)


def smooth(e0: float, e1: float, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def ramp(stops, t):
    t = np.clip(t, 0.0, 1.0)
    out = np.zeros(t.shape + (3,))
    for (t0, c0), (t1, c1) in zip(stops[:-1], stops[1:]):
        m = (t >= t0) & (t <= t1)
        k = ((t[m] - t0) / (t1 - t0))[:, None]
        out[m] = np.array(c0) * (1 - k) + np.array(c1) * k
    return out


def eye_frames(pos, valid, col_open):
    """Göz merkezleri ve göz düzlemi eksenleri (tekir_eyes.paint ile aynı tanım)."""
    lum = col_open @ LUMA
    face = valid & (pos[..., 1] < -0.22) & (pos[..., 2] > 0.2)
    pts = pos[face & (lum < 40)]
    C = {"L": pts[pts[:, 0] > 0].mean(0), "R": pts[pts[:, 0] <= 0].mean(0)}
    gap = float(np.linalg.norm(C["L"] - C["R"]))
    lat = (C["L"] - C["R"]) / gap
    up = np.array([0.0, 0.0, 1.0])
    up = up - lat * np.dot(up, lat)
    up /= np.linalg.norm(up)
    fwd = np.cross(lat, up)
    if fwd[1] > 0:
        fwd = -fwd
    return C, gap * 0.30, lat, up, fwd


def eye_uv(pos, c, eye_r, lat, up, fwd):
    rel = pos - c
    return (rel @ lat) / eye_r, (rel @ up) / eye_r, (rel @ fwd) / eye_r


def recolor(col, pos, valid, frames, var: dict, closed: bool):
    C, eye_r, lat, up, fwd = frames
    lum = col @ LUMA
    mx, mn = col.max(-1), col.min(-1)
    sat = (mx - mn) / np.maximum(mx, 1.0)
    R, G, B = col[..., 0], col[..., 1], col[..., 2]
    # Sınıflar (yumuşak): turuncu ↔ beyaz doygunlukla; pembe B−G ve R−G ile
    orange = smooth(0.14, 0.34, sat)
    pink = smooth(-34.0, -8.0, B - G) * smooth(22.0, 48.0, R - G) * smooth(70.0, 120.0, lum)
    # Tüy gölgesi: turuncu sınıfında parlak turuncuya göre, beyaz sınıfında beyaza göre
    sh_o = 1.0 - var["stripe_k"] * np.clip(1.0 - lum / 188.0, 0.0, 1.0)
    sh_w = 1.0 - var["white_k"] * np.clip(1.0 - lum / 246.0, 0.0, 1.0)
    shade = sh_o * orange + sh_w * (1 - orange)
    fur = var["fur"][None, None, :] * shade[..., None]
    out = fur
    if var["pink"] is None:
        out = out * (1 - pink[..., None]) + col * pink[..., None]
    else:
        pk = var["pink"][None, None, :] * (0.75 + 0.35 * np.clip(lum / 190.0, 0, 1))[..., None]
        out = out * (1 - pink[..., None]) + pk * pink[..., None]
    # Kulak içi (turuncu dokuda pembemsi ten, B−G turuncudan yüksek): gözlerin ortasından göz düzleminde yukarıda
    mid = (C["L"] + C["R"]) / 2
    _, v_mid, _ = eye_uv(pos, mid, eye_r, lat, up, fwd)
    ear = np.where(valid, smooth(1.8, 2.6, v_mid), 0.0) * smooth(-50.0, -42.0, B - G) * smooth(26.0, 38.0, R - G)
    ecol = var["ear"][None, None, :] * (0.82 + 0.22 * np.clip(lum / 170.0, 0, 1.1))[..., None]
    out = out * (1 - ear[..., None]) + ecol * ear[..., None]
    # Göz çevresindeki koyu pikseller (göz çizgisi, bebek, kapalı gözün kapak çizgisi) tüy gibi açılmaz
    near_eye = np.zeros(lum.shape)
    for side, c in C.items():
        u, v, d = eye_uv(pos, c, eye_r, lat, up, fwd)
        cu, cv, a, b = EYE_OPEN[side]
        r = np.sqrt(((u - cu) / a) ** 2 + ((v - cv) / b) ** 2)
        near_eye = np.maximum(near_eye, np.where(valid & (d > -1.2), 1.0 - smooth(1.5, 1.9, r), 0.0))
    feat = near_eye * (1.0 - smooth(62.0, 104.0, lum))
    fcol = var["feature"][None, None, :] * (0.55 + 0.45 * np.clip(lum / 60.0, 0, 1))[..., None]
    out = out * (1 - feat[..., None]) + fcol * feat[..., None]
    if not closed:
        # Göz bebeği (çok koyu) özgün rengini korur, iris yeniden boyanır, parlama kalır
        for side, c in C.items():
            u, v, d = eye_uv(pos, c, eye_r, lat, up, fwd)
            cu, cv, a, b = EYE_OPEN[side]
            r = np.sqrt(((u - cu) / a) ** 2 + ((v - cv) / b) ** 2)
            inside = valid & (r < 1.0) & (d > -1.2)
            w = np.where(inside, 1.0 - smooth(0.86, 1.0, r), 0.0)
            pupil = 1.0 - smooth(38.0, 58.0, lum)
            glint = smooth(185.0, 215.0, lum) * (1.0 - smooth(0.18, 0.3, sat))
            t = np.clip((lum - 40.0) / 150.0, 0.0, 1.0)
            iris = ramp(var["iris"], t)
            k = (w * (1 - pupil) * (1 - glint))[..., None]
            out = out * (1 - k) + iris * k
            kp = (w * pupil)[..., None]
            out = out * (1 - kp) + col * kp
            kg = (w * glint)[..., None]
            out = out * (1 - kg) + col * kg
            log("göz", side, "iris pikseli", int((w * (1 - pupil) * (1 - glint) > 0.5).sum()))
    # UV adacıklarının dışı da (doku süzgeci kenarda onları örnekler) aynı renk eşlemesinden geçer
    return out


# --- Önizleme --------------------------------------------------------------------------------

def eye_front(col, pos, valid, frames, size: int = 300):
    """Gözlerin önden görünümü (göz düzlemine yansıtılmış dokular, öndeki piksel kazanır) — iris elipsini ölçmek için."""
    C, eye_r, lat, up, fwd = frames
    tiles = []
    for side in ("L", "R"):
        u, v, d = eye_uv(pos, C[side], eye_r, lat, up, fwd)
        m = valid & (np.abs(u) < 2.5) & (np.abs(v) < 2.5) & (d > -1.0)
        img = np.zeros((size, size, 3))
        zb = np.full((size, size), -1e9)
        ys, xs = np.nonzero(m)
        px = ((u[m] + 2.5) / 5.0 * (size - 1)).astype(int)
        py = ((2.5 - v[m]) / 5.0 * (size - 1)).astype(int)
        dd, cc = d[m], col[ys, xs]
        for ox in (-1, 0, 1):
            for oy in (-1, 0, 1):
                X, Y = np.clip(px + ox, 0, size - 1), np.clip(py + oy, 0, size - 1)
                order = np.argsort(dd)
                for k in order:
                    if dd[k] >= zb[Y[k], X[k]]:
                        zb[Y[k], X[k]] = dd[k]
                        img[Y[k], X[k]] = cc[k]
        cu, cv, a, b = EYE_OPEN[side]
        for t in np.linspace(0, 2 * math.pi, 360):
            X = int(((cu + a * math.cos(t)) + 2.5) / 5.0 * (size - 1))
            Y = int((2.5 - (cv + b * math.sin(t))) / 5.0 * (size - 1))
            img[Y, X] = (0, 255, 0)
        tiles.append(img)
    return np.concatenate(tiles, axis=1)


def render_previews(blend: str, textures: dict, out_dir: str) -> None:
    """Dinlenme duruşunda önden 3/4 ve yandan Workbench (doku rengi) kareleri; renk başına bir şerit."""
    import bpy
    from mathutils import Vector
    bpy.ops.wm.open_mainfile(filepath=blend)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_cavity = False
    scene.render.resolution_x, scene.render.resolution_y = 520, 520
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("w") if scene.world is None else scene.world
    scene.world = world
    world.color = (0.62, 0.64, 0.66)
    mesh = bpy.data.objects["Tekir"]
    img_node = None
    for mat in mesh.data.materials:
        for n in mat.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                img_node = n
    cam_data = bpy.data.cameras.new("cam")
    cam_data.lens = 60
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {"on": (Vector((0.42, -0.95, 0.42)), Vector((0, -0.12, 0.2))),
             "yuz": (Vector((0.05, -0.75, 0.33)), Vector((0, -0.25, 0.27))),
             "yan": (Vector((1.1, 0.05, 0.3)), Vector((0, 0.02, 0.17)))}
    for name, path in textures.items():
        img_node.image = bpy.data.images.load(path)
        for vname, (loc, target) in views.items():
            cam.location = loc
            cam.rotation_euler = (target - loc).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out_dir, "onizleme_%s_%s.png" % (name, vname))
            bpy.ops.render.render(write_still=True)
    log("önizleme", out_dir)


def main() -> None:
    argv = sys.argv[sys.argv.index("--") + 1:]
    blend, out_dir = argv[0], argv[1]
    os.makedirs(out_dir, exist_ok=True)
    import bpy
    tris = os.path.join(out_dir, "tris.npz")
    TE.dump(blend, tris)
    d = np.load(tris)
    col_open = TE.load_rgb(OPEN)
    col_closed = TE.load_rgb(CLOSED)
    H, W, _ = col_open.shape
    pos = TE.position_map(d["uv"], d["p"], W, H)
    valid = ~np.isnan(pos[..., 0])
    pos = np.nan_to_num(pos, nan=9.0)
    frames = eye_frames(pos, valid, col_open)
    written = {}
    for name, var in VARIANTS.items():
        for closed, src in ((False, col_open), (True, col_closed)):
            out = recolor(src, pos, valid, frames, var, closed)
            path = os.path.join(out_dir, "tekir_%s%s.png" % (name, "_eyes_closed" if closed else ""))
            TE.save_rgb(out, path)
            written[name + ("_closed" if closed else "")] = path
            TE.save_rgb(eye_front(out, pos, valid, frames),
                        os.path.join(out_dir, "goz_%s%s.png" % (name, "_kapali" if closed else "")))
    TE.save_rgb(eye_front(col_open, pos, valid, frames), os.path.join(out_dir, "goz_orange.png"))
    log("yazıldı", sorted(written))
    if "--preview" in argv:
        render_previews(blend, dict(written, orange=OPEN), out_dir)


if __name__ == "__main__":
    main()
