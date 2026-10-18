"""ARMA SÖKÜCÜ — araç dokusundaki gerçek marka logolarını (ızgara / kaput / bagaj arması, jant göbeği, model
yazısı) çevresinin rengiyle doldurur. Blender'ın kendi Python'unda (numpy) çalışır, Godot'a dokunmaz.

Neden: araç adları kurgusal (docs/ARAC_ADLARI.md) ama Tripo dokularında gerçek logolar basılı.

Yöntem (her araç tek atlas, tek UV):
  1. render: optimize GLB + oyunun kullandığı albedo JPEG'i ile 8 ortografik görünüm çizilir (Workbench, ışıksız
     doku rengi = albedo). Aynı görünümler boya maskesiyle de çizilir. Kamera bilgisi JSON'a yazılır.
  2. Logolar görünüm pikselinde dikdörtgen / elips olarak tools/debadge/badges.json'a yazılır (grid.py ızgaralı
     kopyadan okunur).
  3. apply: her bölge görünüm görüntüsünde çevresinden difüzyonla doldurulur (albedo + maske), sonra o bölgeye
     düşen ve kameradan GÖRÜNEN (BVH ışını) her doku texel'ine geri yansıtılır. Ada kenarındaki dolgu texel'leri
     (_pad_islands'ın bıraktığı) de yeni renge çekilir; mip'te eski logo hâlesi kalmaz.

Kullanım:
  blender --background --factory-startup --python tools/debadge/debadge.py -- render <id> [<id> ...]
  blender --background --factory-startup --python tools/debadge/debadge.py -- apply  <id> [<id> ...]
Çıktı: ~/Projects/ct_shots/debadge/<id>/ (görünümler, kamera.json, apply sonrası *_after.png önizlemeleri).
apply dokuyu ve maskeyi yerinde yazar: assets/cars/optimized/<ad>_car_albedo_albedo.jpg ve <ad>_paintmask.png
(eski hali ilk apply'da <id>/orig_*.{jpg,png} olarak saklanır; tekrar apply HER ZAMAN o orijinalden başlar).
"""
import json
import math
import os
import subprocess
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT_ROOT = os.path.expanduser("~/Projects/ct_shots/debadge")
SPEC = os.path.join(PROJ, "tools", "debadge", "badges.json")
LONG_SIDE = 1400          # görünüm görüntüsünün uzun kenarı (px)
# Görünümler: ad → (bakış yönü, kameranın yukarısı). Araç ekseni ölçülür: L = uzunluk, W = genişlik, Z = yukarı.
# a / b: uzunluk ekseninin iki ucu (hangisinin ön olduğu araca göre değişir; grid görüntüsünden okunur).
VIEWS = ["a", "b", "a_top", "b_top", "side_p", "side_n", "top", "a_low"]


def log(*a):
    print("[debadge]", *a, flush=True)


def catalog():
    with open(os.path.join(PROJ, "vehicles", "cars.json"), encoding="utf-8") as f:
        return {c["id"]: c for c in json.load(f)["cars"]}


def paths(entry):
    glb = os.path.join(PROJ, entry["optimized_path"].replace("res://", ""))
    stem = glb[:-4]
    return glb, stem + "_car_albedo_albedo.jpg", stem + "_paintmask.png"


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def load_car(glb, albedo_path):
    bpy.ops.import_scene.gltf(filepath=glb)
    meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    img = bpy.data.images.load(albedo_path, check_existing=False)
    img.colorspace_settings.name = "sRGB"
    for o in meshes:
        for slot in o.material_slots:
            mat = slot.material
            if mat is None or not mat.use_nodes:
                continue
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE":
                    n.image = img
    return meshes, img


def gather(meshes):
    """Dünya uzayında üçgenler + UV'ler (tek atlas)."""
    dg = bpy.context.evaluated_depsgraph_get()
    verts_all, uvs_all, polys = [], [], []
    base = 0
    for o in meshes:
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        me.calc_loop_triangles()
        mw = np.array(o.matrix_world)
        co = np.empty(len(me.vertices) * 3, dtype=np.float64)
        me.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        co = (np.c_[co, np.ones(len(co))] @ mw.T)[:, :3]
        uvl = me.uv_layers.active
        luv = np.empty(len(me.loops) * 2, dtype=np.float64)
        uvl.data.foreach_get("uv", luv)
        luv = luv.reshape(-1, 2)
        nt = len(me.loop_triangles)
        tv = np.empty(nt * 3, dtype=np.int64)
        tl = np.empty(nt * 3, dtype=np.int64)
        me.loop_triangles.foreach_get("vertices", tv)
        me.loop_triangles.foreach_get("loops", tl)
        verts_all.append(co[tv.reshape(-1, 3)])
        uvs_all.append(luv[tl.reshape(-1, 3)])
        ev.to_mesh_clear()
    tri = np.concatenate(verts_all)       # (T,3,3)
    uv = np.concatenate(uvs_all)          # (T,3,2)
    flat = tri.reshape(-1, 3)
    bvh = BVHTree.FromPolygons([Vector(p) for p in flat], [(i * 3, i * 3 + 1, i * 3 + 2) for i in range(len(tri))],
                               all_triangles=True)
    return tri, uv, bvh


def axes(tri):
    lo, hi = tri.reshape(-1, 3).min(0), tri.reshape(-1, 3).max(0)
    ext = hi - lo
    L = 0 if ext[0] >= ext[1] else 1
    W = 1 - L
    return lo, hi, L, W


def view_dirs(lo, hi, L, W):
    """Görünüm adı → (bakış yönü d, kamera yukarısı up). d kameradan araca doğru."""
    eL = np.zeros(3); eL[L] = 1
    eW = np.zeros(3); eW[W] = 1
    eZ = np.array([0.0, 0.0, 1.0])
    def tilt(d, deg):
        d = d * math.cos(math.radians(deg)) - eZ * math.sin(math.radians(deg))
        return d / np.linalg.norm(d)
    return {
        "a": (-eL, eZ), "b": (eL, eZ),
        "a_top": (tilt(-eL, 35), eZ), "b_top": (tilt(eL, 35), eZ),
        "side_p": (-eW, eZ), "side_n": (eW, eZ),
        "top": (-eZ, eL), "a_low": (tilt(-eL, -12), eZ),
    }


def cam_basis(d, up):
    d = np.asarray(d, float); up = np.asarray(up, float)
    x = np.cross(d, up); x /= np.linalg.norm(x)
    y = np.cross(x, d); y /= np.linalg.norm(y)
    return x, y, d


def setup_cam(name, d, up, lo, hi):
    center = (lo + hi) / 2
    x, y, z = cam_basis(d, up)
    corners = np.array([[a, b, c] for a in (lo[0], hi[0]) for b in (lo[1], hi[1]) for c in (lo[2], hi[2])])
    px, py = (corners - center) @ x, (corners - center) @ y
    wx, wy = (px.max() - px.min()) * 1.06, (py.max() - py.min()) * 1.06
    radius = np.linalg.norm(hi - lo)
    if wx >= wy:
        rx, ry = LONG_SIDE, max(64, int(round(LONG_SIDE * wy / wx)))
        scale = wx
    else:
        ry, rx = LONG_SIDE, max(64, int(round(LONG_SIDE * wx / wy)))
        scale = wy
    cdata = bpy.data.cameras.new(name)
    cdata.type = "ORTHO"
    cdata.ortho_scale = scale
    cdata.clip_start = 0.001
    cdata.clip_end = radius * 4
    cam = bpy.data.objects.new(name, cdata)
    bpy.context.scene.collection.objects.link(cam)
    loc = center - z * radius * 1.5
    # Blender kamerası -Z'ye bakar, +Y yukarı: sütunlar (x, y, -d)
    rot = Matrix([[x[0], y[0], -z[0]], [x[1], y[1], -z[1]], [x[2], y[2], -z[2]]])
    cam.matrix_world = Matrix.Translation(Vector(loc)) @ rot.to_4x4()
    info = {"loc": loc.tolist(), "x": x.tolist(), "y": y.tolist(), "d": z.tolist(), "scale": scale,
            "res": [rx, ry], "center": center.tolist()}
    return cam, info


def project(info, pts):
    """Dünya noktaları → piksel (sol üst köşe) + derinlik."""
    loc = np.array(info["loc"]); x = np.array(info["x"]); y = np.array(info["y"]); d = np.array(info["d"])
    rx, ry = info["res"]
    if rx >= ry:
        w, h = info["scale"], info["scale"] * ry / rx
    else:
        h, w = info["scale"], info["scale"] * rx / ry
    rel = pts - loc
    u = (rel @ x / w + 0.5) * rx
    v = (0.5 - rel @ y / h) * ry
    return u, v, rel @ d


def setup_render(rx, ry):
    sc = bpy.context.scene
    sc.render.engine = "BLENDER_WORKBENCH"
    sh = sc.display.shading
    sh.light = "FLAT"
    sh.color_type = "TEXTURE"
    sh.show_shadows = False
    sh.show_cavity = False
    sh.show_object_outline = False
    sh.show_specular_highlight = False
    try:
        sc.display.render_aa = "OFF"
    except TypeError:
        pass
    sc.view_settings.view_transform = "Standard"
    sc.view_settings.look = "None"
    sc.view_settings.exposure = 0.0
    sc.view_settings.gamma = 1.0
    sc.render.film_transparent = True
    sc.render.resolution_x, sc.render.resolution_y = rx, ry
    sc.render.resolution_percentage = 100
    sc.render.image_settings.file_format = "PNG"
    sc.render.image_settings.color_mode = "RGBA"


def render_views(cid, entry, image_override=None, suffix=""):
    """Görünümleri çizer; image_override verilirse dokunun yerine o çizilir (maske görünümü)."""
    glb, albedo, mask = paths(entry)
    reset_scene()
    meshes, img = load_car(glb, image_override or albedo)
    tri, uv, bvh = gather(meshes)
    lo, hi, L, W = axes(tri)
    out = os.path.join(OUT_ROOT, cid)
    os.makedirs(out, exist_ok=True)
    cams = {}
    for name, (d, up) in view_dirs(lo, hi, L, W).items():
        cam, info = setup_cam(name, d, up, lo, hi)
        cams[name] = info
        sc = bpy.context.scene
        sc.camera = cam
        setup_render(*info["res"])
        sc.render.filepath = os.path.join(out, f"{name}{suffix}.png")
        bpy.ops.render.render(write_still=True)
    with open(os.path.join(out, "kamera.json"), "w") as f:
        json.dump({"cams": cams, "L": L, "W": W, "lo": lo.tolist(), "hi": hi.tolist()}, f)
    return out


def load_png(path):
    img = bpy.data.images.load(path, check_existing=False)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, img.channels)[::-1].copy()  # üst satır = 0
    bpy.data.images.remove(img)
    return px


def region_mode(r):
    """Dolgu modu: "d" difüzyon (varsayılan, düz yüzey / yuvarlak arma), "h" satır satır yatay (ızgara çıtası,
    krom şerit, yazı: alt / üstteki başka renk — lamba, tampon — sızmaz)."""
    if isinstance(r, dict):
        return r.get("m", "d")
    return r[4] if len(r) > 4 else "d"


def region_mask(shape, regions):
    h, w = shape
    m = np.zeros((h, w), bool)
    yy, xx = np.mgrid[0:h, 0:w]
    for r in regions:
        if isinstance(r, dict) and "e" in r:
            cx, cy, ax, ay = r["e"]
            m |= ((xx - cx) / ax) ** 2 + ((yy - cy) / ay) ** 2 <= 1.0
        elif isinstance(r, dict) and "p" in r:
            m |= poly_mask(r["p"], xx, yy)
        else:
            x0, y0, x1, y1 = r[:4]
            m |= (xx >= x0) & (xx <= x1) & (yy >= y0) & (yy <= y1)
    return m


def inpaint_rows(img, hole, known):
    """Her satırdaki delik parçası, solundaki ve sağındaki en yakın bilinen pikselden doğrusal doldurulur."""
    out = img.copy()
    for y in np.nonzero(hole.any(1))[0]:
        row_h = hole[y]; row_k = known[y] & ~row_h
        xs = np.nonzero(row_h)[0]
        kx = np.nonzero(row_k)[0]
        if len(kx) == 0:
            continue
        # delik parçaları
        splits = np.split(xs, np.nonzero(np.diff(xs) > 1)[0] + 1)
        for seg in splits:
            a, b = seg[0], seg[-1]
            left = kx[kx < a]; right = kx[kx > b]
            lv = img[y, left[-1]] if len(left) and a - left[-1] < 40 else None
            rv = img[y, right[0]] if len(right) and right[0] - b < 40 else None
            if lv is None and rv is None:
                continue
            if lv is None:
                lv = rv
            if rv is None:
                rv = lv
            if np.abs(lv - rv).max() > 0.3:
                # bir uç başka bir nesneye (stop lambası, tampon) değiyor: çevrenin çoğunluk rengine yakın uç kazanır
                y0, y1 = max(0, y - 6), y + 7
                x0, x1 = max(0, a - 12), b + 13
                win = known[y0:y1, x0:x1] & ~hole[y0:y1, x0:x1]
                if win.any():
                    ref = np.median(img[y0:y1, x0:x1][win], axis=0)
                    if np.abs(lv - ref).sum() <= np.abs(rv - ref).sum():
                        rv = lv
                    else:
                        lv = rv
            t = ((seg - a + 1) / (b - a + 2))[:, None]
            out[y, seg] = lv * (1 - t) + rv * t
    return out


def poly_mask(pts, xx, yy):
    inside = np.zeros(xx.shape, bool)
    n = len(pts)
    for i in range(n):
        x0, y0 = pts[i]; x1, y1 = pts[(i + 1) % n]
        cond = ((y0 > yy) != (y1 > yy)) & (xx < (x1 - x0) * (yy - y0) / ((y1 - y0) + 1e-9) + x0)
        inside ^= cond
    return inside


def inpaint(img, hole, known):
    """Difüzyon (Laplace) dolgusu: hole içi, known (araç pikseli, hole dışı) komşulardan. img (h,w,c)."""
    ys, xs = np.nonzero(hole)
    if len(ys) == 0:
        return img
    pad = 6
    y0, y1 = max(0, ys.min() - pad), min(img.shape[0], ys.max() + pad + 1)
    x0, x1 = max(0, xs.min() - pad), min(img.shape[1], xs.max() + pad + 1)
    sub = img[y0:y1, x0:x1].copy()
    hl = hole[y0:y1, x0:x1]
    kn = known[y0:y1, x0:x1] & ~hl
    # başlangıç: bilinen komşuların ortalaması
    if kn.any():
        sub[hl] = sub[kn].mean(0)
    valid = (kn | hl).astype(np.float32)
    for it in range(1500):
        acc = np.zeros_like(sub); cnt = np.zeros(sub.shape[:2], np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(np.roll(sub, dy, 0), dx, 1)
            vv = np.roll(np.roll(valid, dy, 0), dx, 1)
            acc += sh * vv[..., None]; cnt += vv
        new = acc / np.maximum(cnt, 1)[..., None]
        delta = np.abs(new[hl] - sub[hl]).max() if hl.any() else 0
        sub[hl] = new[hl]
        if delta < 1e-4:
            break
    out = img.copy()
    out[y0:y1, x0:x1][hl] = sub[hl]
    return out


def sample(img, u, v):
    h, w = img.shape[:2]
    xi = np.clip(np.round(u - 0.5).astype(int), 0, w - 1)
    yi = np.clip(np.round(v - 0.5).astype(int), 0, h - 1)
    return img[yi, xi]


def raster_uv(tri_uv, size):
    """Bir üçgenin UV'sini texel'lere böler: (texel x, y, barisentrik (n,3))."""
    p = tri_uv * size
    p[:, 1] = size - p[:, 1]                     # UV y yukarı → görüntü satırı aşağı
    x0, y0 = np.floor(p.min(0)).astype(int); x1, y1 = np.ceil(p.max(0)).astype(int)
    x0, y0 = max(x0, 0), max(y0, 0); x1, y1 = min(x1, size - 1), min(y1, size - 1)
    if x1 < x0 or y1 < y0:
        return None
    yy, xx = np.mgrid[y0:y1 + 1, x0:x1 + 1]
    cx, cy = xx.ravel() + 0.5, yy.ravel() + 0.5
    (ax, ay), (bx, by), (qx, qy) = p
    den = (by - qy) * (ax - qx) + (qx - bx) * (ay - qy)
    if abs(den) < 1e-12:
        return None
    l1 = ((by - qy) * (cx - qx) + (qx - bx) * (cy - qy)) / den
    l2 = ((qy - ay) * (cx - qx) + (ax - qx) * (cy - qy)) / den
    l3 = 1 - l1 - l2
    eps = 0.02
    ok = (l1 >= -eps) & (l2 >= -eps) & (l3 >= -eps)
    if not ok.any():
        return None
    return xx.ravel()[ok], yy.ravel()[ok], np.c_[l1[ok], l2[ok], l3[ok]]


def apply(cid, entry, spec):
    glb, albedo_path, mask_path = paths(entry)
    out = os.path.join(OUT_ROOT, cid)
    os.makedirs(out, exist_ok=True)
    orig_albedo = os.path.join(out, "orig_albedo.jpg")
    orig_mask = os.path.join(out, "orig_paintmask.png")
    if not os.path.exists(orig_albedo):
        import shutil
        shutil.copy2(albedo_path, orig_albedo)
        shutil.copy2(mask_path, orig_mask)
    # Görünümleri ORİJİNAL dokuyla yeniden çiz (tekrar apply aynı sonucu verir)
    render_views(cid, entry, orig_albedo, "")
    render_views(cid, entry, orig_mask, "_mask")
    reset_scene()
    meshes, _ = load_car(glb, orig_albedo)
    tri, uv, bvh = gather(meshes)
    with open(os.path.join(out, "kamera.json")) as f:
        cams = json.load(f)["cams"]
    alb = load_png(orig_albedo)[..., :3]        # (2048,2048,3) 0..1 sRGB
    msk = load_png(orig_mask)[..., 0]
    A = alb.shape[0]; M = msk.shape[0]
    alb_new = alb.copy(); msk_new = msk.copy()
    edited = np.zeros((A, A), bool)
    diag = float(np.linalg.norm(tri.reshape(-1, 3).max(0) - tri.reshape(-1, 3).min(0)))
    eps = diag * 0.004
    total = 0
    for view, regions in spec.items():
        if view.startswith("_") or not regions:
            continue
        info = cams[view]
        col = load_png(os.path.join(out, f"{view}.png"))
        mcol = load_png(os.path.join(out, f"{view}_mask.png"))
        rx, ry = info["res"]
        car = col[..., 3] > 0.5
        hole = region_mask((ry, rx), regions) & car
        hole_d = region_mask((ry, rx), [r for r in regions if region_mode(r) == "d"]) & car
        hole_h = hole & ~hole_d
        fill = inpaint(col[..., :3], hole_d, car & ~hole)
        mfill = inpaint(mcol[..., :1], hole_d, car & ~hole)[..., 0]
        if hole_h.any():
            fill = inpaint_rows(fill, hole_h, car & ~hole_h)
            mfill = inpaint_rows(mfill[..., None], hole_h, car & ~hole_h)[..., 0]
        # bölgeye düşen üçgenler
        u, v, dep = project(info, tri.reshape(-1, 3))
        u = u.reshape(-1, 3); v = v.reshape(-1, 3)
        ys, xs = np.nonzero(hole)
        bx0, bx1, by0, by1 = xs.min() - 2, xs.max() + 2, ys.min() - 2, ys.max() + 2
        sel = np.nonzero((u.max(1) >= bx0) & (u.min(1) <= bx1) & (v.max(1) >= by0) & (v.min(1) <= by1))[0]
        d = Vector(info["d"])
        n_view = 0
        for t in sel:
            r = raster_uv(uv[t].copy(), A)
            if r is None:
                continue
            tx, ty, bary = r
            pts = bary @ tri[t]
            pu, pv, pd = project(info, pts)
            inside = (pu >= 0) & (pu < rx) & (pv >= 0) & (pv < ry)
            if not inside.any():
                continue
            tx, ty, pts, pu, pv, pd = tx[inside], ty[inside], pts[inside], pu[inside], pv[inside], pd[inside]
            hit = hole[np.clip(pv.astype(int), 0, ry - 1), np.clip(pu.astype(int), 0, rx - 1)]
            if not hit.any():
                continue
            tx, ty, pts, pu, pv, pd = tx[hit], ty[hit], pts[hit], pu[hit], pv[hit], pd[hit]
            # görünürlük: kameradan gelen ışın önce bu noktaya mı çarpıyor?
            vis = np.zeros(len(pts), bool)
            for k, p in enumerate(pts):
                o = Vector(p) - d * (diag * 2)
                loc, nrm, idx, dist = bvh.ray_cast(o, d, diag * 4)
                vis[k] = loc is not None and abs(dist - diag * 2) < eps
            if not vis.any():
                continue
            tx, ty, pu, pv = tx[vis], ty[vis], pu[vis], pv[vis]
            alb_new[ty, tx] = sample(fill, pu, pv)
            mx = np.clip((tx * M) // A, 0, M - 1); my = np.clip((ty * M) // A, 0, M - 1)
            msk_new[my, mx] = sample(mfill[..., None], pu, pv)[:, 0]
            edited[ty, tx] = True
            n_view += len(tx)
        log(cid, view, "texel:", n_view)
        total += n_view
    # ada dışı dolgu texel'leri: düzenlenen texel'in 4 px çevresinde, hiçbir üçgene ait olmayanlar yeni renge
    if edited.any():
        cover = np.zeros((A, A), bool)
        ys, xs = np.nonzero(edited)
        pad = 6
        for (y0, y1, x0, x1) in boxes(edited, pad):
            uvs = uv * A
            uvs_y = A - uvs[..., 1]
            selt = np.nonzero((uvs[..., 0].max(1) >= x0) & (uvs[..., 0].min(1) <= x1) &
                              (uvs_y.max(1) >= y0) & (uvs_y.min(1) <= y1))[0]
            for t in selt:
                r = raster_uv(uv[t].copy(), A)
                if r is not None:
                    cover[r[1], r[0]] = True
        grow = edited.copy()
        src_y, src_x = np.nonzero(edited)
        for step in range(pad):
            nb = grow.copy()
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb |= np.roll(np.roll(grow, dy, 0), dx, 1)
            ring = nb & ~grow & ~cover
            if not ring.any():
                break
            ry_, rx_ = np.nonzero(ring)
            acc = np.zeros((len(ry_), 3)); cnt = np.zeros(len(ry_))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = np.clip(ry_ + dy, 0, A - 1), np.clip(rx_ + dx, 0, A - 1)
                ok = grow[yy, xx]
                acc[ok] += alb_new[yy[ok], xx[ok]]; cnt[ok] += 1
            alb_new[ry_, rx_] = acc / np.maximum(cnt, 1)[:, None]
            grow |= ring
    save_raw(alb_new, albedo_path, out, "RGB")
    save_raw(msk_new, mask_path, out, "L")
    log(cid, "TOPLAM texel:", total)
    return total


def boxes(mask, pad):
    """Düzenlenen texel kümelerinin kaba kutuları (bağlı bileşen yerine 64 px ızgara)."""
    A = mask.shape[0]; g = 64
    out = []
    cells = mask.reshape(A // g, g, A // g, g).any(axis=(1, 3))
    for cy, cx in zip(*np.nonzero(cells)):
        out.append((cy * g - pad, cy * g + g + pad, cx * g - pad, cx * g + g + pad))
    return out


def save_raw(arr, path, out_dir, mode):
    """Kodlamayı PIL yapar (encode.py): Blender'ın save_render'ı görüntü dönüşümü uygulayıp dokuyu koyulaştırıyordu."""
    h, w = arr.shape[:2]
    raw = os.path.join(out_dir, os.path.basename(path) + ".raw")
    with open(raw, "wb") as f:
        f.write((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8).tobytes())
    enc = os.path.join(PROJ, "tools", "debadge", "encode.py")
    subprocess.run(["python3", "-I", enc, raw, path, mode, str(w), str(h)], check=True)
    os.remove(raw)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(argv) < 2:
        log("kullanım: -- render|apply|after <id> ...")
        return
    mode, ids = argv[0], argv[1:]
    cat = catalog()
    spec = {}
    if os.path.exists(SPEC):
        with open(SPEC, encoding="utf-8") as f:
            spec = json.load(f)
    for cid in ids:
        entry = cat[cid]
        if mode == "render":
            render_views(cid, entry)
            log(cid, "görünümler:", os.path.join(OUT_ROOT, cid))
        elif mode == "apply":
            if cid not in spec:
                log(cid, "badges.json'da yok, atlandı")
                continue
            apply(cid, entry, spec[cid])
            render_views(cid, entry, None, "_after")
        elif mode == "after":
            render_views(cid, entry, None, "_after")


main()
