"""TEKİR AKSESUARLARI (GARAJ DOSTLARI, 2026-10-31): Meshy'nin ürettiği aksesuarları (assets/pets/source/acc_*.glb,
git dışı) kedinin dinlenme duruşuna oturtur, kedinin iskeletine DERİLER ve her birini kedinin model uzayında (metre)
iskeletiyle birlikte GLB olarak çıkarır; kart rafı için küçük resim (icon_<id>.png) da çizer. Oyun (PetActor) ağı kendi
iskeletinden alıp kedinin Skeleton3D'sine taşır; deri bağları adla çözülür.

  tasma   boynun EN KISA çevreli kesitine (kemik boyunca + eğimle taranır) halka; BVH ışınlarıyla yüzeye sarılır,
          künye gerdanda tek parça; deri TEK PARÇA (halkanın ortalama ağırlığı: boyun ~0.67 + baş ~0.31)
  bandana aynı yöntem, biraz gövdeye yakın; düğüm ensede, üçgen göğüste; deri köşe köşe (yalnız gövde zinciri)
  kep     USTA KEPİ (Meshy, acc_mech_cap.glb): kulak köklerinin önünde, kafatası eğimine göre öne yatık, kenarı
          kafaya gömülüp dışarı itmeyle kafatasına oturtulur; başa sabit
  kask    kafaya ölçekli; kulak delikleri kulak köklerinden kesilir (boolean); başa sabit

  blender -b --factory-startup --python tools/pets/tekir_acc.py -- <tekir_rig.blend> <src_klasörü> <çıktı_klasörü> [kontrol.png]
  Oyun için çıktı klasörü assets/pets/acc; başsız --import sonrası *_Image_0.jpg.import → compress/mode=2.
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

TEX_SIZE = 512
ITEMS = ["collar_red", "bandana", "cap", "helmet"]
# Kaynak dosya adı kimlikten farklıysa (2026-10-31: "cap" artık usta kepi; eski gri kasket acc_cap.glb kaynakta kaldı)
SOURCE = {"cap": "mech_cap"}


def log(*a):
    print("RAPOR", *a)


def import_item(path: str, name: str) -> bpy.types.Object:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    new = [o for o in bpy.data.objects if o not in before]
    mesh = next(o for o in new if o.type == "MESH")
    for o in new:
        o.select_set(o == mesh)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in new:
        if o != mesh:
            bpy.data.objects.remove(o)
    mesh.name = "acc_" + name
    mesh.data.name = "acc_" + name
    # Merkez: kutunun ortası (yerleştirme kendi noktasını verir)
    V = verts(mesh)
    c = (V.min(0) + V.max(0)) / 2
    mesh.data.transform(Matrix.Translation(Vector(-c)))
    mesh.data.update()
    return mesh


def verts(o) -> np.ndarray:
    return np.array([v.co[:] for v in o.data.vertices])


def rotate_z_to_front(o, direction_xy: np.ndarray) -> None:
    """Modelde verilen yatay yönü −Y'ye (kedinin önü) çevirir."""
    ang = math.atan2(direction_xy[0], -direction_xy[1])   # (x, y) → (0, −1) için gereken açı
    o.data.transform(Matrix.Rotation(ang, 4, "Z"))
    o.data.update()


def neck_frame(arm, t: float = 0.35):
    b = arm.data.bones["neck"]
    p = b.head_local.lerp(b.tail_local, t)
    n = (b.tail_local - b.head_local).normalized()
    x = Vector((1, 0, 0))
    u = n.cross(x).normalized()          # boyun ekseni + yanal → yukarı-geri (halka düzleminde)
    return p, n, x, u


def section_extent(cat_v: np.ndarray, p: Vector, n: Vector, a: Vector, b: Vector, slab: float = 0.006):
    """Boyun kesiti, p'den geçen n'ye dik düzlemde. Dört yönde (±a, ±b) ±30° dilimdeki köşelerin eksene uzaklığının
    ortancası → (a yarıçapı, b yarıçapı, a kayması, b kayması). Kutu ölçüsü omuzları / çeneyi de sayıp şişiriyordu."""
    rel = cat_v - np.array(p[:])
    d = rel @ np.array(n[:])
    ring = rel[np.abs(d) < slab]
    pa = ring @ np.array(a[:])
    pb = ring @ np.array(b[:])
    ang = np.arctan2(pb, pa)
    rad = np.hypot(pa, pb)
    def med(center):
        # Dilimdeki EN YAKIN yüzey (alt %12): boyun ekseni yatıka yakın, düzlem yukarı-geride sırtı / omzu da keser
        m = np.abs(np.angle(np.exp(1j * (ang - center)))) < math.radians(30)
        return float(np.percentile(rad[m], 12)) if m.any() else float(np.median(rad))
    r_pa, r_na, r_pb, r_nb = med(0.0), med(math.pi), med(math.pi / 2), med(-math.pi / 2)
    return (r_pa + r_na) / 2, (r_pb + r_nb) / 2, (r_pa - r_na) / 2, (r_pb - r_nb) / 2


def neck_slice(arm, label: str, t_range=(0.0, 0.75), tilt_range=(-35, 40)):
    """Tasmanın oturacağı boyun kesiti: boyun kemiği boyunca (t) ve kemiğe göre eğimle (X ekseni çevresinde) taranan
    düzlemlerden ÇEVRESİ EN KISA olanı (gerçek tasma da boynun en ince yerine kayar). Her düzlemde merkezden 72 ışın;
    ışın kaçıran ya da kafanın arkasına / omza uzanan (yarıçap > 0.075) kesit elenir. Merkez bir kez kesitin
    ağırlık merkezine taşınıp yeniden ölçülür. Dönüş: (merkez, eksen, yanal, düzlem-içi yukarı)."""
    from mathutils.bvhtree import BVHTree
    cat = bpy.data.objects["Tekir"]
    bvh = BVHTree.FromObject(cat, bpy.context.evaluated_depsgraph_get())
    bone = arm.data.bones["neck"]
    n0 = (bone.tail_local - bone.head_local).normalized()
    x = Vector((1, 0, 0))
    th = np.linspace(-math.pi, math.pi, 72, endpoint=False)

    def ring(c, axis):
        u = axis.cross(x).normalized()
        pts = []
        for a in th:
            d = x * math.cos(a) + u * math.sin(a)
            hit = bvh.ray_cast(c, d, 0.2)
            if hit[0] is None:
                return None
            pts.append(hit[0])
        return pts

    best = None
    for t in np.linspace(t_range[0], t_range[1], 16):
        c0 = bone.head_local.lerp(bone.tail_local, float(t))
        for tilt in range(tilt_range[0], tilt_range[1] + 1, 5):
            axis = Matrix.Rotation(math.radians(tilt), 3, "X") @ n0
            pts = ring(c0, axis)
            if pts is None:
                continue
            c = sum(pts, Vector()) / len(pts)
            c = c - axis * (c - c0).dot(axis)
            pts = ring(c, axis)
            if pts is None:
                continue
            rad = [(q - c).length for q in pts]
            if max(rad) > 0.075:
                continue
            per = sum((pts[i] - pts[i - 1]).length for i in range(len(pts)))
            if best is None or per < best[0]:
                best = (per, float(t), tilt, c, axis, min(rad), max(rad))
    per, t, tilt, c, axis, rmin, rmax = best
    log("%s kesit: t=%.2f eğim=%+d° çevre=%.3f yarıçap %.3f–%.3f eksen=(%.2f %.2f %.2f)"
        % (label, t, tilt, per, rmin, rmax, axis.x, axis.y, axis.z))
    return c, axis, x, axis.cross(x).normalized()


def place(o, M: Matrix) -> None:
    o.data.transform(M)
    o.data.update()


def radial_fit(o, cat, center: Vector, n: Vector, a: Vector, b: Vector, r0: float, gap: float, keep=None) -> None:
    """Halkayı boyun yüzeyine sarar: (a, b) düzleminde her açıda merkezden yüzeye ışın atılır (BVH); o açıdaki köşeler
    yarıçapı r0 olan iç yüzeyi yüzeyin `gap` dışına gelecek oranda ölçeklenir (kalınlık oranla korunur). keep(rel):
    True dönen köşeler (ör. künye) ölçeklenmez, yalnız o açıdaki halka kadar taşınır."""
    from mathutils.bvhtree import BVHTree
    bvh = BVHTree.FromObject(cat, bpy.context.evaluated_depsgraph_get())
    thetas = np.linspace(-math.pi, math.pi, 97)
    radii = []
    for th in thetas:
        d = a * math.cos(th) + b * math.sin(th)
        hit = bvh.ray_cast(center, d, 0.25)
        radii.append(hit[3] if hit[0] is not None else np.nan)
    radii = np.array(radii)
    ok = ~np.isnan(radii)
    radii = np.interp(thetas, thetas[ok], radii[ok])
    log("boyun yüzeyi yarıçap %.3f–%.3f" % (radii.min(), radii.max()))
    kept = [v for v in o.data.vertices if keep is not None and keep(v.co - center)]
    if kept:
        # Künye gibi parçalar BÜTÜN olarak taşınır (açı açı ölçeklemek onu buruşturuyordu)
        c = sum((v.co for v in kept), Vector()) / len(kept) - center
        th0 = math.atan2(c.dot(b), c.dot(a))
        k0 = (float(np.interp(th0, thetas, radii)) + gap) / r0
        move = (a * math.cos(th0) + b * math.sin(th0)) * (k0 - 1.0) * r0
    kept_ids = {v.index for v in kept}
    for v in o.data.vertices:
        if v.index in kept_ids:
            v.co = v.co + move
            continue
        rel = v.co - center
        pa, pb, ph = rel.dot(a), rel.dot(b), rel.dot(n)
        th = math.atan2(pb, pa)
        k = (float(np.interp(th, thetas, radii)) + gap) / r0
        v.co = center + a * pa * k + b * pb * k + n * ph
    o.data.update()
    return sorted(kept_ids)


# Tasma SARILIR (kullanıcı 2026-10-31: "ensede o kadar boşluk olmasın, öne gelsin; tasma bükülebilir, kedinin üstüne
# yapıştırabilirsin"). Düz halka kısa boyunda ya ensede havada kalıyor ya kafatasının arkasına tırmanıyordu. Yol iki
# noktaya bağlanır: önde GERDAN (COLLAR_FRONT_T), arkada sırt profilinde ENSE (COLLAR_NAPE_Y: kafatası tepesinden
# sırt düzlüğüne inen yokuşun üstü); bu ikisinden ve yanal eksenden geçen kesit deri üstünde izlenir. Model yol boyunca bükülüp deriye
# TEĞET yatırılır (çerçeve yüzey normalinden: ensede boşluk kalmaz), yüzeye COLLAR_GAP mesafeyle; künye gerdanda tek
# parça. (Boyun profili ensede kafaya düzgün yükseliyor, "kalınlaşma" ölçütü ense noktasını bulamadı; kulak kökünün
# arkasından yukarıdan ışın kafatası tepesine çarpıp halkayı yüzün çevresine çıkardı.)
COLLAR_FRONT_T = 0.85     # gerdan: boyun kemiğinin bu oranında kemiğe dik aşağı ışın
COLLAR_NAPE_Y = -0.180    # ense: orta çizgide sırt profilinin bu y'si (kafatası tepesi −0,24, sırt düzlüğü −0,16)
COLLAR_GAP = 0.0025


def neck_path(arm, half_w: float, n: int = 96, front_t: float = None, nape_y: float = None):
    """Gerdan ve enseden geçen, boynu saran kapalı yol: (açılar, noktalar, dış normaller, kafaya doğru yönler,
    teğetler). Açı 0 = gerdan, π/2 = +X yanı, π = ense."""
    from mathutils.bvhtree import BVHTree
    front_t = COLLAR_FRONT_T if front_t is None else front_t
    nape_y = COLLAR_NAPE_Y if nape_y is None else nape_y
    cat = bpy.data.objects["Tekir"]
    bvh = BVHTree.FromObject(cat, bpy.context.evaluated_depsgraph_get())
    bone = arm.data.bones["neck"]
    O = bone.head_local.copy()
    A = (bone.tail_local - bone.head_local)
    L = A.length
    A.normalize()
    X = Vector((1, 0, 0))
    down = Vector((0, 0, -1))
    D0 = (down - A * A.dot(down)).normalized()
    hit = bvh.ray_cast(O + A * (front_t * L), D0, 0.2)
    F = hit[0]
    top = bvh.ray_cast(Vector((0.0, nape_y, 1.0)), Vector((0, 0, -1)), 2.0)
    K = top[0]
    c = (F + K) / 2
    u0 = (F - K)
    u0 = (u0 - X * u0.dot(X)).normalized()             # gerdana doğru (kesit düzleminde)
    pn = X.cross(u0).normalized()
    th = np.linspace(0.0, 2.0 * math.pi, n, endpoint=False)
    P, N = [], []
    for a in th:
        d = u0 * math.cos(a) + X * math.sin(a)
        hit = bvh.ray_cast(c, d, 0.2)
        P.append(np.array(hit[0][:]))
        nor = hit[1] if hit[1].dot(d) > 0 else -hit[1]
        N.append(np.array((nor * 0.6 + d * 0.4).normalized()[:]))   # yüz normali gürültülü: ışın yönüyle karışık
    P, N = np.array(P), np.array(N)

    def smooth(M, w=3):
        padm = np.concatenate([M[-w:], M, M[:w]])
        return np.array([padm[i:i + 2 * w + 1].mean(0) for i in range(len(M))])
    P = smooth(P)
    N = smooth(N, 4)
    N /= np.linalg.norm(N, axis=1)[:, None]
    T = np.roll(P, -1, 0) - np.roll(P, 1, 0)
    T /= np.linalg.norm(T, axis=1)[:, None]
    B = np.cross(N, T)
    B /= np.linalg.norm(B, axis=1)[:, None]
    if (B @ np.array(A[:])).mean() < 0:
        B = -B
    # Yol tasmanın ORTA çizgisi: yarı en kadar gövdeye kaydır (ön kenar çeneye / kafatasına değmesin)
    P = P - B * half_w * 0.5
    T = np.cross(B, N)
    tilt = math.degrees(math.atan2((K - F).z, (K - F).y))
    log("tasma yolu: gerdan t=%.2f (%.3f, %.3f), ense y=%.3f z=%.3f, kesit yataydan %.0f°, çevre %.3f m"
        % (front_t, F.y, F.z, K.y, K.z, tilt, float(np.linalg.norm(np.roll(P, -1, 0) - P, axis=1).sum())))
    return th, P, N, B, T


def fit_collar(o, cat_v, arm, front_t: float = None, nape_y: float = None) -> list:
    V = verts(o)
    # Künye: halkanın dışına en çok taşan köşeler
    r = np.linalg.norm(V[:, :2], axis=1)
    tag = V[r > np.percentile(r, 97)][:, :2].mean(0)
    rotate_z_to_front(o, tag)
    V = verts(o)
    # Halkanın GERÇEK merkezi: içe aktarma kutuyu ortalıyor, sarkan künye yüzünden orijin künye tarafına kayık.
    # Orijine göre açı / kalınlık alınca arka ~17 mm "kalın" sayılıp deriden havaya kalkıyordu (ensede boşluk).
    # x: kutu ortası (künye ortada); y: arka dış kenar − dış yarıçap (yanal genişlikten).
    r_out = float((V[:, 0].max() - V[:, 0].min()) / 2)
    ctr = np.array((float((V[:, 0].max() + V[:, 0].min()) / 2), float(V[:, 1].max()) - r_out, 0.0))
    V = V - ctr
    rho = np.linalg.norm(V[:, :2], axis=1)
    ring_mask = rho <= r_out * 1.03
    ring_v = V[ring_mask]
    ring_in = float(np.percentile(rho[ring_mask], 3))   # iç yarıçap
    ring_out = float(np.percentile(rho[ring_mask], 97))
    z_mid = float((ring_v[:, 2].min() + ring_v[:, 2].max()) / 2)
    s = 0.05 / ring_in                                 # önceki halka ile aynı kalınlık / en
    sw = s * 0.8
    half_w = float((ring_v[:, 2].max() - ring_v[:, 2].min()) / 2) * sw
    th, P, N, B, T = neck_path(arm, half_w, front_t=front_t, nape_y=nape_y)
    n = len(th)
    tag_ids = [i for i in range(len(V)) if rho[i] > r_out * 1.05 and V[i, 1] < 0]

    def frame(a):
        f = (a % (2.0 * math.pi)) / (2.0 * math.pi) * n
        i0 = int(math.floor(f)) % n
        i1 = (i0 + 1) % n
        u = f - math.floor(f)
        mix = lambda M: M[i0] * (1 - u) + M[i1] * u
        nn, bb = mix(N), mix(B)
        nn /= np.linalg.norm(nn)
        bb = bb - nn * bb.dot(nn)
        bb /= np.linalg.norm(bb)
        return mix(P), nn, bb, np.cross(bb, nn)

    # Deriye YANSITMA: şerit üstündeki yer (yol + en yönü) deriye ışınla düşürülür, kalınlık deri normali boyunca.
    # Teğet şerit ensenin çukurunda kenarlardan deriye giriyor, dışarı itme bütün bandı kaldırıyordu (ölçüm: ensede
    # 19,5 mm, sağ arkada 26 mm boşluk; önde 3 mm).
    from mathutils.bvhtree import BVHTree
    from mathutils.interpolate import poly_3d_calc
    cat = bpy.data.objects["Tekir"]
    me = cat.data
    cbvh = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])

    def onto_skin(base: np.ndarray, nn: np.ndarray):
        b, nv = Vector(base.tolist()), Vector(nn.tolist())
        hit = cbvh.ray_cast(b + nv * 0.03, -nv, 0.06)
        loc, fi = (hit[0], hit[2]) if hit[0] is not None else cbvh.find_nearest(b)[0::2]
        poly = me.polygons[fi]
        w = poly_3d_calc([me.vertices[i].co for i in poly.vertices], loc)
        sn = sum((me.vertices[i].normal * wi for i, wi in zip(poly.vertices, w)), Vector())
        if sn.length < 1e-6 or sn.dot(nv) < 0.2:
            sn = nv if sn.length < 1e-6 or sn.dot(nv) < -0.2 else (sn.normalized() + nv).normalized()
        sn = (sn.normalized() * 0.7 + nv * 0.3).normalized()   # deri normali gürültülü: yol normaliyle karışık
        return np.array(loc[:]), np.array(sn[:])

    # İç yüz HER AÇIDA ayrı: halka tam çember değil, toka merkez tahminini kaydırıyor; açı dilimindeki en içteki
    # köşe deriye COLLAR_GAP ile oturur, kalınlık (toka dahil) o dilimin iç yüzünden ölçülür
    ang = np.arctan2(V[:, 0], -V[:, 1]) % (2.0 * math.pi)
    nb = 72
    binr = np.full(nb, np.nan)
    bi = (ang / (2.0 * math.pi) * nb).astype(int) % nb
    for b in range(nb):
        m = ring_mask & (bi == b)
        if m.any():
            binr[b] = float(np.percentile(rho[m], 2))
    ok = ~np.isnan(binr)
    xs = np.arange(nb)
    binr = np.interp(xs, xs[ok], binr[ok], period=nb)
    padb = np.concatenate([binr[-2:], binr, binr[:2]])
    binr = np.array([padb[i:i + 5].mean() for i in range(nb)])

    def inner_r(a: float) -> float:
        f = (a % (2.0 * math.pi)) / (2.0 * math.pi) * nb
        i0 = int(math.floor(f)) % nb
        u = f - math.floor(f)
        return float(binr[i0] * (1 - u) + binr[(i0 + 1) % nb] * u)

    tag_set = set(tag_ids)
    P0, N0, B0, T0 = frame(0.0)
    anchor = np.array((0.0, -ring_in, z_mid))
    for i, v in enumerate(o.data.vertices):
        x, y, z = V[i]
        if i in tag_set:
            rel = V[i] - anchor
            q = P0 + N0 * COLLAR_GAP + T0 * rel[0] * s + N0 * (-rel[1]) * s + B0 * rel[2] * s
        else:
            a = math.atan2(x, -y)                      # 0 = künye (−Y) = gerdan, +X yanına doğru artar
            pp, nn, bb, _tt = frame(a)
            sp, sn = onto_skin(pp + bb * (z - z_mid) * sw, nn)
            q = sp + sn * (COLLAR_GAP + max(rho[i] - inner_r(a), 0.0) * s)
        v.co = Vector(q.tolist())
    o.data.update()
    log("tasma sarıldı: merkez kayması y %.3f, iç / dış yarıçap %.3f / %.3f, ölçek %.3f, en %.1f mm, künye %d köşe"
        % (ctr[1], ring_in, ring_out, s, half_w * 2000, len(tag_ids)))
    return tag_ids


def fit_bandana(o, cat_v, arm) -> None:
    V = verts(o)
    tip = V[np.argmin(V[:, 2])]
    rotate_z_to_front(o, tip[:2])
    V = verts(o)
    top = V[V[:, 2] > V[:, 2].max() - 0.25]          # halka bölgesi (üçgenin üstü)
    ring_r = float(np.percentile(np.abs(top[:, 0]), 90))
    # Tasmanınkiyle aynı yöntem, biraz daha gövdeye yakın: düğüm enseye, üçgen göğse
    p, axis, side, _u = neck_slice(arm, "bandana", t_range=(0.0, 0.45))
    r0 = 0.05
    s = r0 / ring_r
    fwd = axis.cross(side).normalized()
    # model −Y (üçgenin ucu) → −fwd (öne-aşağı, göğüs); X×Y=Z sağ el
    R = Matrix(((side.x, fwd.x, axis.x), (side.y, fwd.y, axis.y), (side.z, fwd.z, axis.z))).to_4x4()
    ring_c = Vector((0.0, 0.0, (top[:, 2].max() + top[:, 2].min()) / 2))
    place(o, Matrix.Translation(p) @ R @ Matrix.Diagonal((s, s, s, 1.0)) @ Matrix.Translation(-ring_c))
    cat = bpy.data.objects["Tekir"]
    radial_fit(o, cat, p, axis, side, fwd, r0, 0.004)
    log("bandana halka %.3f ölçek %.3f" % (ring_r, s))


def head_info(arm, cat_v):
    hb = arm.data.bones["head"]
    head = cat_v[cat_v[:, 1] < hb.head_local.y + 0.01]
    ears = {s: (arm.data.bones["ear_" + s].head_local.copy(), arm.data.bones["ear_" + s].tail_local.copy()) for s in "LR"}
    mid_x = (ears["L"][0].x + ears["R"][0].x) / 2
    return head, ears, mid_x


# USTA KEPİ (2026-10-31, kullanıcı: eski gri kasketi beğenmedi + "tam oturmuyor, havada kalıyor"). Eski kasket kafatası
# tepesinde TEK noktaya göre konup yana 9° yatırılmıştı → kenarlar havada. Şimdi: taç kulak köklerinin hemen önünde,
# kepin dik ekseni kafatasının o bölgedeki ortalama yüzey normaline hizalı (doğal öne eğim), taç kenarları kafaya
# gömülecek kadar indirilir, dışarı itme (push_out) kenarı kafatasına CAP_GAP ile oturtur — kumaş kep gibi sarar.
CAP_WIDTH = 0.95        # taç eni / kulak kökleri arası
CAP_FORWARD = 0.012     # taç merkezi kulak köklerinden bu kadar önde (m)


def fit_cap(o, cat_v, arm) -> None:
    from mathutils.bvhtree import BVHTree
    V = verts(o)
    # Siperlik = ince uç: ±Y uçlarından z kalınlığı küçük olan öne (−Y)
    half = (V[:, 1].max() - V[:, 1].min()) * 0.4
    yc = (V[:, 1].max() + V[:, 1].min()) / 2
    thick_neg = np.ptp(V[V[:, 1] < yc - half][:, 2])
    thick_pos = np.ptp(V[V[:, 1] > yc + half][:, 2])
    if thick_pos < thick_neg:
        o.data.transform(Matrix.Rotation(math.pi, 4, "Z"))
        o.data.update()
        V = verts(o)
    # Taç: arka dış kenardan yanal yarıçap kadar içerideki daire
    r_crown = float((V[:, 0].max() - V[:, 0].min()) / 2)
    c_crown = np.array((float((V[:, 0].max() + V[:, 0].min()) / 2), float(V[:, 1].max()) - r_crown))
    z_bot = float(V[:, 2].min())
    head, ears, mid_x = head_info(arm, cat_v)
    gap = abs(ears["L"][0].x - ears["R"][0].x)
    sc = gap * CAP_WIDTH / (2.0 * r_crown)
    cat = bpy.data.objects["Tekir"]
    bvh = BVHTree.FromObject(cat, bpy.context.evaluated_depsgraph_get())
    # Kafatası tepesinde hedef nokta ve çevresindeki ortalama normal (taç yarıçapı kadar disk)
    ty = (ears["L"][0].y + ears["R"][0].y) / 2 - CAP_FORWARD
    rc = r_crown * sc
    pts, nors = [], []
    for dx in np.linspace(-rc, rc, 7):
        for dy in np.linspace(-rc, rc, 7):
            if dx * dx + dy * dy > rc * rc:
                continue
            hit = bvh.ray_cast(Vector((mid_x + dx, ty + dy, 1.0)), Vector((0, 0, -1)), 2.0)
            if hit[0] is not None:
                pts.append(hit[0])
                nors.append(hit[1] if hit[1].z > 0 else -hit[1])
    # Eğim: tacın ön ve arka kenarının altındaki kafatası yüksekliğinden (alın kulak önünde dik iniyor; ortalama
    # normal tacın önünü alnın üstünde havada bırakıyordu). Yanlara göre de aynı (sol / sağ kenar).
    def skull_z(x, y):
        hit = bvh.ray_cast(Vector((x, y, 1.0)), Vector((0, 0, -1)), 2.0)
        return hit[0].z if hit[0] is not None else None
    zf, zb = skull_z(mid_x, ty - rc * 0.9), skull_z(mid_x, ty + rc * 0.9)
    zl, zr = skull_z(mid_x - rc * 0.9, ty), skull_z(mid_x + rc * 0.9, ty)
    pitch = math.atan2(zb - zf, rc * 1.8)                  # + = ön alçak → üst öne yatar
    roll = math.atan2(zr - zl, rc * 1.8) if zl is not None and zr is not None else 0.0
    up = (Matrix.Rotation(pitch, 3, "X") @ Matrix.Rotation(-roll, 3, "Y")) @ Vector((0, 0, 1))
    top = max(p.z for p in pts if abs(p.x - mid_x) < rc * 0.4 and abs(p.y - ty) < rc * 0.4)
    anchor = Vector((mid_x, ty, top))
    fwd = Vector((0, -1, 0))
    fwd = (fwd - up * fwd.dot(up)).normalized()
    side = fwd.cross(up).normalized()                       # model +X
    # model X→side, Y→−fwd (siperlik −Y → fwd), Z→up
    R = Matrix(((side.x, -fwd.x, up.x), (side.y, -fwd.y, up.y), (side.z, -fwd.z, up.z))).to_4x4()
    pivot = Vector((c_crown[0], c_crown[1], z_bot))
    place(o, Matrix.Translation(anchor) @ R @ Matrix.Diagonal((sc, sc, sc, 1.0)) @ Matrix.Translation(-pivot))
    # Taç kenarı (alt %12, taç dairesi içinde) ile kafatası arası, kep ekseni boyunca
    W = verts(o)
    loc_up = np.array(up[:])
    h = (W - np.array(anchor[:])) @ loc_up
    rim = [i for i in range(len(W)) if h[i] < np.ptp(h) * 0.12
           and np.hypot(*(np.array([(V[i, 0] - c_crown[0]), (V[i, 1] - c_crown[1])]))) <= r_crown * 1.02]
    gaps = []
    for i in rim:
        q = Vector(W[i].tolist())
        hit = bvh.ray_cast(q + up * 0.03, -up, 0.08)
        if hit[0] is not None:
            gaps.append(hit[3] - 0.03)                      # + = kenar yüzeyin üstünde (havada)
    sink = float(np.percentile(gaps, 85)) if gaps else 0.0
    o.data.transform(Matrix.Translation(-up * (sink + 0.002)))
    o.data.update()
    log("usta kepi: kulak arası %.3f, ölçek %.3f, öne eğim %.0f° yan %.0f°, kenar boşluğu %.1f–%.1f mm → %.1f mm indirildi"
        % (gap, sc, math.degrees(pitch), math.degrees(roll), min(gaps) * 1000 if gaps else 0,
           max(gaps) * 1000 if gaps else 0, (sink + 0.002) * 1000))


def fit_helmet(o, cat_v, arm) -> None:
    V = verts(o)
    head, ears, mid_x = head_info(arm, cat_v)
    skull = head[head[:, 2] > 0.2]
    hx = skull[:, 0].max() - skull[:, 0].min()
    sx = hx * 1.16 / (V[:, 0].max() - V[:, 0].min())
    sy = sx * 0.78
    sz = sx * 0.92
    top_model = Vector((0.0, 0.0, V[:, 2].max()))
    hb = arm.data.bones["head"]
    z_top = skull[(np.abs(skull[:, 0] - mid_x) < 0.015)][:, 2].max() if len(skull) else 0.33
    target = Vector((mid_x, hb.head_local.y - 0.018, z_top + 0.012))
    place(o, Matrix.Translation(target) @ Matrix.Rotation(math.radians(-8), 4, "X") @ Matrix.Diagonal((sx, sy, sz, 1.0)) @ Matrix.Translation(-top_model))
    # Kulak delikleri: kulak kökünden ucuna silindir. Yarıçap kulağın ALT yarısının kesitinden (+ pay): sabit 1,6 cm
    # dardı, kafa eğilince kulak kökü deliğin kenarından kabuğun dışına taşıyordu
    cat = bpy.data.objects["Tekir"]
    for s in "LR":
        base, tip = ears[s]
        d = (tip - base)
        g = cat.vertex_groups.get("ear_" + s)
        axis = d.normalized()
        rad = []
        for v in cat.data.vertices:
            w = next((x.weight for x in v.groups if g is not None and x.group == g.index), 0.0)
            if w < 0.85:
                continue
            rel = v.co - base
            t = rel.dot(axis) / d.length
            if 0.1 < t < 0.45:
                rad.append((rel - axis * rel.dot(axis)).length)
        hole = float(np.clip((np.percentile(rad, 90) if rad else 0.016) + 0.003, 0.016, 0.024))
        log("kask kulak deliği %s yarıçap %.3f (%d köşe)" % (s, hole, len(rad)))
        cyl_len = d.length * 3.0
        bpy.ops.mesh.primitive_cylinder_add(radius=hole, depth=cyl_len, vertices=24,
                                            location=base + d.normalized() * (cyl_len * 0.35))
        cyl = bpy.context.active_object
        cyl.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        bpy.context.view_layer.update()
        mod = o.modifiers.new("ear_" + s, "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cyl
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.data.objects.remove(cyl)
    log("kask ölçek %.3f/%.3f/%.3f tepe z %.3f üçgen %d" % (sx, sy, sz, z_top, sum(len(p.vertices) - 2 for p in o.data.polygons)))


FIT = {"collar_red": fit_collar, "bandana": fit_bandana, "cap": fit_cap, "helmet": fit_helmet}


# GÖMÜLME (2026-10-31, kullanıcı: "aksesuarlar hep kedinin içine giriyor"): ölçüm tools/pets/acc_clip_check.py.
# İki neden vardı: (1) dinlenme duruşunda bile görünmeyen kısımlar içerideydi (tasmanın önü gerdanda, bandananın
# %40'ı göğüste, kasket kenarı kafatasında, kask yanakları yüzde); (2) tasma tek parça / bandana yalnız gövde
# ağırlığıyla deriyi izlemiyordu, kafa eğilince boyun-göğüs içlerinden geçiyordu. Çözüm: dinlenmede DIŞARI İTME
# (push_out) + tasma ve bandanada altındaki derinin BÜTÜN kemik ağırlıkları (yüzeyde yumuşatılmış). Kasket / kask
# başa sabit; kulaklar kask deliklerinden geçtiği için kaskta kulak bölgesi itilmez (kasket kumaş: kulaklardan da
# itilir, aralarına sıkışmış gibi durur).
# Kask da derinin ağırlığını alır ama ÇOK yumuşatılmış: kafaya katı bağlıyken kafa eğilince (yemek, yalanma) ense
# derisi (boyun ağırlıklı) kaskın arka kabuğundan çıkıyordu; şimdi yalnız arka kenarı enseyle hafif esner.
SKIN = {"collar_red": "skin", "bandana": "skin", "cap": "head", "helmet": "skin"}
GAP = {"collar_red": 0.003, "bandana": 0.004, "cap": 0.0015, "helmet": 0.003}
SMOOTH = {"collar_red": 0.012, "bandana": 0.010, "helmet": 0.025}   # ağırlık yumuşatma yarıçapı (m)
# Kulak kemiği ağırlığı kafaya sayılır: deri kulak kökünde biraz kulak ağırlığı taşıyor; aksesuar alırsa kulak
# seğirdikçe tasma / kask deliği oynardı
REMAP = {"ear_L": "head", "ear_R": "head"}
# Kask kemik sınırı denendi ve BIRAKILDI: yalnız baş + boyun (23 klip gömülüyor) ya da boyun ≤%35 (29 klip) tam deri
# ağırlığından (11 klip) kötü; kafa eğilince omuzlar kaskın alt kenarına geliyor. Alttan bakınca görünen siyah astar
# bükülme değil, kaskın içi.
LIMIT = {}
RAYS = (Vector((0.31, 0.12, 0.94)).normalized(), Vector((-0.83, 0.47, 0.29)).normalized(),
        Vector((0.21, -0.95, -0.22)).normalized())


def is_inside(bvh, co: Vector) -> bool:
    """Işın sayımı: üç yönden en az ikisinde tek sayıda kesişme = kedinin içinde (yüz normaline güvenmez)."""
    odd = 0
    for d in RAYS:
        p, n = co.copy(), 0
        for _k in range(24):
            hit = bvh.ray_cast(p, d, 2.0)
            if hit[0] is None:
                break
            n += 1
            p = hit[0] + d * 1e-5
        odd += n % 2
    return odd >= 2


def adjacency(me) -> list:
    adj = [[] for _ in me.vertices]
    for e in me.edges:
        a, b = e.vertices
        adj[a].append(b)
        adj[b].append(a)
    return adj


def ear_weight(cat) -> list:
    """Köşe başına kulak ağırlığı (kask deliklerinden geçen kulak: oraya itme yapılmaz)."""
    ears = {g.index for g in cat.vertex_groups if g.name.startswith("ear")}
    return [sum(g.weight for g in v.groups if g.group in ears) for v in cat.data.vertices]


PUSH_RADIUS = {"collar_red": 0.008, "bandana": 0.008, "cap": 0.010, "helmet": 0.016}


def push_out(o, cat, gap: float, skip_ears: bool, radius: float, rounds: int = 12) -> None:
    """İçerideki ya da yüzeye `gap`'ten yakın köşeleri yüzeyin `gap` dışına iter. İtme UZAYDA yumuşak bir alan:
    her gömülen köşenin itmesi `radius` içindeki bütün köşelere azalarak uygulanır → kalın parçanın iç ve dış
    katmanı birlikte kayar (köşe köşe itmede iç astar kaskın kabuğunu, bandananın iç katmanı dışını deliyordu)."""
    from mathutils.bvhtree import BVHTree
    from mathutils.interpolate import poly_3d_calc
    me = cat.data
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
    ear = ear_weight(cat) if skip_ears else None

    def on_ear(loc: Vector, fi: int) -> bool:
        # En yakın nokta KULAĞIN ÜSTÜNDE mi (ara değerli kulak ağırlığı); kulak kökü / kafatası tepesi itilir
        if ear is None:
            return False
        poly = me.polygons[fi]
        bw = poly_3d_calc([me.vertices[i].co for i in poly.vertices], loc)
        return sum(ear[i] * b for i, b in zip(poly.vertices, bw)) > 0.6

    V = np.array([v.co[:] for v in o.data.vertices])
    first = None
    left = 0
    for r in range(rounds):
        idx, D = [], []
        for i in range(len(V)):
            co = Vector(V[i])
            loc, nor, fi, d = bvh.find_nearest(co, 0.05)
            if loc is None or on_ear(loc, fi):
                continue
            if is_inside(bvh, co):
                dv = (loc - co).normalized() * (d + gap) if d > 1e-6 else nor * gap
            elif d < gap * 0.98:
                dv = (co - loc).normalized() * (gap - d)
            else:
                continue
            idx.append(i)
            D.append(dv[:])
        if first is None:
            first = len(idx)
        left = len(idx)
        if not idx:
            break
        P = V[idx]
        D = np.array(D)
        dist = np.linalg.norm(V[:, None, :] - P[None, :, :], axis=2)
        w = np.clip(1.0 - dist / radius, 0.0, 1.0)
        w = w * w * (3.0 - 2.0 * w)
        num = w @ D
        den = np.maximum(w.sum(1), 1.0)[:, None]
        V += num / den
    for v, co in zip(o.data.vertices, V):
        v.co = Vector(co)
    o.data.update()
    log("%s dışarı itme: ilk %d köşe, %d tur, son turda %d" % (o.name, first or 0, r + 1, left))


def skin_item(o, cat, arm, mode: str, rigid=None, smooth: float = 0.0) -> None:
    from mathutils.bvhtree import BVHTree
    from mathutils.interpolate import poly_3d_calc
    o.parent = arm
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    deform = {b.name for b in arm.data.bones if b.use_deform}
    if mode in deform:
        vg = o.vertex_groups.new(name=mode)
        vg.add(range(len(o.data.vertices)), 1.0, "REPLACE")
        return
    me = cat.data
    bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
    names = {g.index: g.name for g in cat.vertex_groups}

    def weights_at(co: Vector) -> dict:
        """Altındaki deri noktasının ağırlıkları (yüzde ağırlık merkezi ile ara değer, bütün deforme kemikler)."""
        loc, _n, fi, _d = bvh.find_nearest(co)
        poly = me.polygons[fi]
        bw = poly_3d_calc([me.vertices[i].co for i in poly.vertices], loc)
        acc = {}
        for vi, b in zip(poly.vertices, bw):
            for g in me.vertices[vi].groups:
                nm = REMAP.get(names[g.group], names[g.group])
                if nm in deform and g.weight > 0.0:
                    acc[nm] = acc.get(nm, 0.0) + g.weight * b
        return acc or {"chest": 1.0}   # ağırlıksız köşe kalırsa dışa aktarıcı "neutral_bone" ekliyor

    W = [weights_at(v.co) for v in o.data.vertices]
    if smooth > 0.0:
        # UZAYDA yumuşatma (yarıçap `smooth` m): tasmanın eni ve kalınlığı boyunca ağırlık aynı kalır; köşe köşe
        # farklı yüzlere düşen ağırlıklar kafa eğilince kenarı dikenli / buruşuk yapıyordu
        bones = sorted({nm for w in W for nm in w})
        M = np.array([[w.get(nm, 0.0) for nm in bones] for w in W])
        X = np.array([v.co[:] for v in o.data.vertices])
        dist = np.linalg.norm(X[:, None, :] - X[None, :, :], axis=2)
        k = np.clip(1.0 - dist / smooth, 0.0, 1.0)
        k = k * k * (3.0 - 2.0 * k)
        M = (k @ M) / k.sum(1)[:, None]
        W = [{nm: float(M[i, j]) for j, nm in enumerate(bones) if M[i, j] > 1e-4} for i in range(len(W))]
    lim = LIMIT.get(o.name[4:])
    if lim:
        allowed, caps = lim
        out = []
        for w in W:
            w = {nm: wt for nm, wt in w.items() if nm in allowed} or {"head": 1.0}
            tot = sum(w.values())
            w = {nm: wt / tot for nm, wt in w.items()}
            for nm, cap in caps.items():
                if w.get(nm, 0.0) > cap:
                    w["head"] = w.get("head", 0.0) + w[nm] - cap
                    w[nm] = cap
            out.append(w)
        W = out
    rigid_ids = set(rigid or [])
    if rigid_ids:
        # Künye tek parça: halkada künyenin asıldığı yere (künyenin en üst noktası) en yakın köşelerin ağırlığı
        top = max((o.data.vertices[i].co for i in rigid_ids), key=lambda c: c.z)
        ring = sorted((v.index for v in o.data.vertices if v.index not in rigid_ids),
                      key=lambda i: (o.data.vertices[i].co - top).length)[:24]
        fixed = {}
        for i in ring:
            for nm, wt in W[i].items():
                fixed[nm] = fixed.get(nm, 0.0) + wt / len(ring)
        for i in rigid_ids:
            W[i] = fixed
    groups = {}
    for v in o.data.vertices:
        top4 = sorted(W[v.index].items(), key=lambda kv: -kv[1])[:4]
        tot = sum(wt for _, wt in top4) or 1.0
        for nm, wt in top4:
            if nm not in groups:
                groups[nm] = o.vertex_groups.new(name=nm)
            groups[nm].add([v.index], wt / tot, "REPLACE")
    log("%s deri: %s" % (o.name, ", ".join(sorted(groups))))


def export(o, path: str) -> None:
    for img in bpy.data.images:
        if img.size[0] > TEX_SIZE:
            img.scale(TEX_SIZE, TEX_SIZE)
    arm = bpy.data.objects["TekirRig"]
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_animations=False, export_skins=True, export_yup=True, export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=90)
    log("glb", path, os.path.getsize(path))


ICON_PX = 128


def render_icons(cat, objs, out_dir: str) -> None:
    """Kart rafı küçük resimleri: her aksesuar TEK BAŞINA, saydam zemin, önden-sağdan-üstten ortografik."""
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    scene.render.film_transparent = True
    scene.render.resolution_x = scene.render.resolution_y = ICON_PX
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("IconW")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs[1].default_value = 0.9
    scene.world = world
    sun = bpy.data.objects.new("IconSun", bpy.data.lights.new("IconSun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(35), 0, math.radians(-25))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("IconCam", bpy.data.cameras.new("IconCam"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    cat.hide_render = True
    d = Vector((0.45, -1.0, 0.55)).normalized()
    for name, o in objs.items():
        for other in objs.values():
            other.hide_render = other != o
        V = np.array([(o.matrix_world @ v.co)[:] for v in o.data.vertices])
        c = Vector(((V.min(0) + V.max(0)) / 2).tolist())
        # Kameradan görünen genişlik: köşelerin bakış düzlemine izdüşümü
        right = d.cross(Vector((0, 0, 1))).normalized()
        up = right.cross(d).normalized()
        rel = V - np.array(c[:])
        span = max(np.ptp(rel @ np.array(right[:])), np.ptp(rel @ np.array(up[:])))
        cam.data.ortho_scale = float(span) * 1.12
        cam.location = c + d * 1.0
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "icon_%s.png" % name)
        bpy.ops.render.render(write_still=True)
        log("simge", scene.render.filepath)
    cat.hide_render = False
    for o in objs.values():
        o.hide_render = False
    scene.render.film_transparent = False
    bpy.data.objects.remove(sun)
    bpy.data.objects.remove(cam)


def check_render(cat, objs, out: str) -> None:
    scene = bpy.context.scene
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.72, 0.73, 0.76, 1)
    sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(40), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 0.24
    scene.collection.objects.link(cam)
    scene.camera = cam
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    px = 360
    scene.render.resolution_x = scene.render.resolution_y = px
    scene.view_settings.view_transform = "Standard"
    c = Vector((0.0, -0.24, 0.25))
    shots = []
    combos = [["collar_red", "cap"], ["bandana", "helmet"], ["bandana"], ["collar_red"]]
    for combo in combos:
        for o in objs.values():
            o.hide_render = o.name[4:] not in combo
        for name, d in (("on", Vector((0.25, -1, 0.25))), ("yan", Vector((1, -0.15, 0.3)))):
            d = d.normalized()
            cam.location = c + d * 1.0
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            p = out + "_%d_%s.png" % (len(shots), name)
            scene.render.filepath = p
            bpy.ops.render.render(write_still=True)
            shots.append(p)
    cols = 4
    buf = np.zeros((px * 2, px * cols, 4), dtype=np.float32)
    for i, p in enumerate(shots):
        im = bpy.data.images.load(p)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(px, px, 4)
        r, cc = 1 - i // cols, i % cols
        buf[r * px:(r + 1) * px, cc * px:(cc + 1) * px] = a
        os.remove(p)
    sheet = bpy.data.images.new("sheet", px * cols, px * 2)
    sheet.pixels = buf.ravel()
    sheet.filepath_raw = out + ".png"
    sheet.file_format = "PNG"
    sheet.save()
    log("kontrol", out + ".png")


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    blend, src_dir, out_dir = argv[0], argv[1], argv[2]
    check = argv[3] if len(argv) > 3 else ""
    bpy.ops.wm.open_mainfile(filepath=blend)
    cat = bpy.data.objects["Tekir"]
    arm = bpy.data.objects["TekirRig"]
    assert arm.matrix_world == Matrix.Identity(4) and cat.matrix_world == Matrix.Identity(4), "rig dünya dönüşümü birim değil"
    cat_v = np.array([(cat.matrix_world @ v.co)[:] for v in cat.data.vertices])
    os.makedirs(out_dir, exist_ok=True)
    objs = {}
    for name in ITEMS:
        o = import_item(os.path.join(src_dir, "acc_%s.glb" % SOURCE.get(name, name)), name)
        rigid = FIT[name](o, cat_v, arm)
        objs[name] = o
        push_out(o, cat, GAP[name], name == "helmet", PUSH_RADIUS[name])   # kulaklar yalnız kask deliklerinden
        skin_item(o, cat, arm, SKIN[name], rigid, SMOOTH.get(name, 0.0))
    for name, o in objs.items():
        export(o, os.path.join(out_dir, "%s.glb" % name))
    render_icons(cat, objs, out_dir)
    if check:
        check_render(cat, objs, os.path.splitext(check)[0])


main()
