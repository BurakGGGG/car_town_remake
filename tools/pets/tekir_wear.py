"""TEKİR KIYAFETLERİ (GARAJ DOSTLARI, 2026-11-03): gövdeye giyilen dört kıyafet — İKAZ YELEĞİ, YARIŞ MONTU, DERİ CEKET,
ÖRGÜ KAZAK. Kullanıcı kararı: Meshy yok; kıyafet KEDİNİN KENDİ DERİSİNDEN türetilir.

Yöntem (her kıyafet):
  1) Kedinin dinlenme örgüsü kopyalanır, köşe başına işaretli alanlarla KESİLİR: boyun düzlemi (boyun kemiği boyunca
     neck_t), etek düzlemi (sırtta hem_top, karında hem_bot; eğik), ön bacaklar (yelekte ağırlık eşiğiyle kol deliği,
     montlarda bacak zinciri boyunca kol boyu `sleeve`), arka bacak / kuyruk / baş ağırlık eşikleri. Kesim kenarları
     alanın sıfır çizgisinden geçer (temiz, düz etek ve kol ağzı); en büyük parça kalır.
  2) İç köşeler hafif yumuşatılır, kenar halkaları kendi boylarınca düzlenir; yüzey normal boyunca `gap` dışarı alınır,
     Solidify ile `shell` kalınlık + kenar dolgusu (kol ağzında kumaş kalınlığı görünür).
  3) Deri: her köşe altındaki deri noktasının ağırlıkları (kedinin bütün deform kemikleri, en çok 4) — kıyafet deriyle
     AYNI bükülür, içine gömülmez.
  4) UV: Smart UV; doku 3B'de boyanır (yeni UV'nin dikişleri desende görünmez): her doku pikselinin dinlenme yeri,
     normali, ön bacak ağırlığı ve en yakın kenarın türü / kenar boyunca uzunluğu / uzaklığı bilinir; desenler bunların
     işlevidir (reflektif bantlar, yarış şeritleri, ribanalar, fermuar, zımbalar, örgü ilmekleri, yamalar).
  5) GLB (kedinin iskeletiyle, aksesuarlar gibi; oyun PetActor ağı kedinin Skeleton3D'sine taşır) + raf simgesi.

  python3 tools/pets/tekir_wear_decals.py <çalışma>/decals
  blender -b --factory-startup --python tools/pets/tekir_wear.py -- <tekir_rig.blend> <decals> <çıktı_klasörü> [kontrol_klasörü] [--only id,id]
  Oyun için çıktı klasörü assets/pets/acc; başsız --import sonrası <id>_Image_0.jpg.import → compress/mode=2.
"""
import bpy, bmesh, sys, os, math
import numpy as np
from mathutils import Vector, Matrix
from mathutils.kdtree import KDTree
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

TEX = 1024
FRONT = {"L": ("upperarm_L", "forearm_L", "hand_L"), "R": ("upperarm_R", "forearm_R", "hand_R")}
REAR = ("thigh_L", "shin_L", "foot_L", "toe_L", "thigh_R", "shin_R", "foot_R", "toe_R")
TAIL = tuple("tail%d" % i for i in range(1, 7))
HEAD = ("head", "ear_L", "ear_R")
ZC = 0.158          # gövde kesitinin ortası (z, m): sırt ~0,215, karın ~0,10
R_BODY = 0.055      # gövde yarıçapı (çevre koordinatı = açı × R_BODY)
W_SCALE = 0.05      # ağırlık alanlarını metreye çevirir (alanlar min ile birleşir)

# Kesim: neck_t boyun kemiği boyunca (0 göğüs, 1 baş), hem = (sırtta y, karında y) — y büyüdükçe arka;
# sleeve: kol boyu (0 omuz eklemi, 1 bilek; yelekte omzun hemen altı = kol deliği), leg_iso: bacak sayılan ağırlık
ITEMS = {
    "vest": {"gap": 0.0040, "shell": 0.0016, "neck_t": 0.10, "hem": (0.035, -0.030), "sleeve": 0.06,
             "rough": 0.7},
    "race_jacket": {"gap": 0.0048, "shell": 0.0020, "neck_t": 0.16, "neck_up": 0.55, "hem": (0.052, -0.012),
                    "sleeve": 0.50,
                    "rough": 0.55},
    "leather_jacket": {"gap": 0.0048, "shell": 0.0022, "neck_t": 0.16, "neck_up": 0.55, "hem": (0.012, -0.052),
                       "sleeve": 0.56,
                       "rough": 0.42},
    "sweater": {"gap": 0.0058, "shell": 0.0024, "neck_t": 0.22, "neck_up": 0.55, "hem": (0.060, 0.008),
                "sleeve": 0.84,
                "rough": 0.95},
}
BTYPES = ("neck", "hem", "arm")
# Gizleme maskesi: kıyafetin altında kalan DERİ oyunda çizilmez (yatarken / kıvrılırken derinin kendi kıvrımı kıyafetin
# içinden dışarı taşıyordu: acc_clip_check en kötü 6–9 mm). Kedinin UV'sinde, kesim alanlarının kenardan bu kadar
# (m) içerisi = 1. Oyun: PetActor kedi gölgelendiricisi (world/pets/pet_body.gdshader) bu pikselleri atar.
MASK_SIZE = 512
MASK_MARGIN = 0.007
DEBUG_DIR = ""      # kontrol klasörü verilirse doku PNG'leri de oraya


def log(*a):
    print("RAPOR", *a)


def smooth(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def mix(a, b, k):
    k = np.asarray(k)[..., None] if np.ndim(k) else k
    return a * (1 - k) + np.asarray(b, dtype=np.float64) * k


# --- Kedi ölçüleri --------------------------------------------------------------------------------

class Cat:
    def __init__(self, cat, arm):
        self.obj, self.arm = cat, arm
        me = cat.data
        self.V = np.array([v.co[:] for v in me.vertices])
        names = {g.index: g.name for g in cat.vertex_groups}
        self.W = {n: np.zeros(len(me.vertices)) for n in names.values()}
        for v in me.vertices:
            for g in v.groups:
                self.W[names[g.group]][v.index] = g.weight
        self.bvh = BVHTree.FromPolygons([v.co for v in me.vertices], [p.vertices[:] for p in me.polygons])
        b = arm.data.bones
        self.neck = (np.array(b["neck"].head_local[:]), np.array(b["neck"].tail_local[:]))
        self.chain = {s: [np.array(b[n].head_local[:]) for n in FRONT[s]] for s in FRONT}   # omuz, dirsek, bilek
        self.deform = [bn.name for bn in b if bn.use_deform]

    def weights_at(self, co: Vector) -> dict:
        from mathutils.interpolate import poly_3d_calc
        me = self.obj.data
        loc, _n, fi, _d = self.bvh.find_nearest(co)
        poly = me.polygons[fi]
        bw = poly_3d_calc([me.vertices[i].co for i in poly.vertices], loc)
        acc = {}
        for vi, wgt in zip(poly.vertices, bw):
            for g in me.vertices[vi].groups:
                nm = self.obj.vertex_groups[g.group].name
                if nm in self.deform and g.weight > 0.0:
                    acc[nm] = acc.get(nm, 0.0) + g.weight * wgt
        return acc or {"chest": 1.0}


def leg_param(P: np.ndarray, chain: list):
    """Ön bacak zinciri (omuz → dirsek → bilek) boyunca t (0 omuz, 1 bilek; omuzdan yukarısı eksi), eksene uzaklık,
    en yakın eksen noktası."""
    seg = [(chain[i], chain[i + 1]) for i in range(len(chain) - 1)]
    lens = [np.linalg.norm(b - a) for a, b in seg]
    total = sum(lens)
    best_d = np.full(len(P), np.inf)
    best_t = np.zeros(len(P))
    best_q = np.zeros_like(P)
    cum = 0.0
    for k, ((a, b), L) in enumerate(zip(seg, lens)):
        d = (b - a) / L
        u = (P - a) @ d
        lo = -np.inf if k == 0 else 0.0
        hi = np.inf if k == len(seg) - 1 else L
        uc = np.clip(u, lo, hi)
        q = a + uc[:, None] * d
        dist = np.linalg.norm(P - q, axis=1)
        m = dist < best_d
        best_d[m], best_t[m], best_q[m] = dist[m], (cum + uc[m]) / total, q[m]
        cum += L
    return best_t, best_d, best_q, total


def fields(P: np.ndarray, W: dict, cat: Cat, spec: dict) -> np.ndarray:
    """Kesim alanları (artı = kalır), sütunlar BTYPES sırasıyla + arka/kuyruk/baş (hem'e sayılır)."""
    n0, n1 = cat.neck
    nd = (n1 - n0) / np.linalg.norm(n1 - n0)
    pc = n0 + (n1 - n0) * spec["neck_t"]
    # neck_up: yaka düzlemi yukarı yatırılır → önde boğaza kadar çıkar, ensede boyun kökünde kalır (tasmaya değmez)
    nd = nd + np.array([0.0, 0.0, spec.get("neck_up", 0.0)])
    nd /= np.linalg.norm(nd)
    s_neck = -((P - pc) @ nd)
    y_top, y_bot = spec["hem"]
    p_top = np.array([0.0, y_top, 0.22])
    d = np.array([0.0, y_bot - y_top, 0.10 - 0.22])
    n = np.array([0.0, -d[2], d[1]])
    n /= np.linalg.norm(n)
    if n[1] < 0:
        n = -n
    s_hem = -((P - p_top) @ n)
    # Ön bacak: yalnız o yanın bacak ağırlığı leg_iso'yu geçen VE zincir boyunca `sleeve`'den aşağıdaki yer kesilir
    # (bacaklar göğse yapışık: ağırlık tek başına göğüs önünü, eksene uzaklık tek başına bacağın iç yanını ayıramıyor)
    s_arm = np.full(len(P), 1.0)
    for side, ch in cat.chain.items():
        t, _dist, _q, total = leg_param(P, ch)
        w_side = sum(W[b] for b in FRONT[side])
        s_side = np.maximum((spec.get("leg_iso", 0.5) - w_side) * W_SCALE, (spec["sleeve"] - t) * total)
        on = (P[:, 0] > 0) if side == "L" else (P[:, 0] <= 0)
        s_arm = np.where(on, np.minimum(s_arm, s_side), s_arm)
    s_rear = (0.4 - sum(W[b] for b in REAR)) * W_SCALE
    s_tail = (0.3 - sum(W[b] for b in TAIL)) * W_SCALE
    s_head = (0.3 - sum(W[b] for b in HEAD)) * W_SCALE
    return np.stack([s_neck, np.minimum(np.minimum(s_hem, s_rear), np.minimum(s_tail, s_head)), s_arm], axis=1)


# --- Kesim ----------------------------------------------------------------------------------------

def cut_garment(cat: Cat, spec: dict, name: str):
    """Kedinin örgüsünden kıyafet yüzeyi (bmesh): alanların sıfır çizgisinden kes, en büyük parçayı tut."""
    bm = bmesh.new()
    bm.from_mesh(cat.obj.data)
    F = fields(cat.V, cat.W, cat, spec)
    lay = bm.verts.layers.float.new("s")
    typ = bm.verts.layers.int.new("btype")
    bm.verts.ensure_lookup_table()
    for v in bm.verts:
        f = F[v.index]
        s = float(f.min())
        v[lay] = s if abs(s) > 1e-7 else 1e-7
        v[typ] = int(np.argmin(f))
    for e in [e for e in bm.edges if (e.verts[0][lay] > 0) != (e.verts[1][lay] > 0)]:
        a, b = e.verts
        sa, sb = a[lay], b[lay]
        fac = sa / (sa - sb)
        co = a.co.lerp(b.co, fac)
        ta = a[typ] if abs(sa) < abs(sb) else b[typ]
        _ne, nv = bmesh.utils.edge_split(e, a, fac)
        nv.co = co
        nv[lay] = 0.0
        nv[typ] = ta
    for f in list(bm.faces):
        zs = [v for v in f.verts if v[lay] == 0.0]
        if len(zs) == 2 and not any(set(e.verts) == set(zs) for e in f.edges):
            bmesh.utils.face_split(f, zs[0], zs[1])
    bmesh.ops.delete(bm, geom=[f for f in bm.faces if any(v[lay] < 0 for v in f.verts)], context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # En büyük bağlı parça
    bm.faces.ensure_lookup_table()
    seen, parts = set(), []
    for f0 in bm.faces:
        if f0.index in seen:
            continue
        stack, part = [f0], []
        seen.add(f0.index)
        while stack:
            f = stack.pop()
            part.append(f)
            for e in f.edges:
                for g in e.link_faces:
                    if g.index not in seen:
                        seen.add(g.index)
                        stack.append(g)
        parts.append(part)
    parts.sort(key=len, reverse=True)
    for p in parts[1:]:
        bmesh.ops.delete(bm, geom=p, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    log(name, "kesim: parça", len(parts), "yüz", len(bm.faces), "atılan küçük parçalar", [len(p) for p in parts[1:6]])
    return bm


def shape_garment(bm, spec: dict) -> None:
    """Yumuşat, kenarları düzle, normal boyunca dışarı al."""
    # Kesimin köşeye çok yakın geçtiği yerde kalan kıymık üçgenler (Solidify'da diken, normalde bozukluk) erir
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0006)
    bmesh.ops.dissolve_degenerate(bm, dist=0.0006, edges=bm.edges)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    inner = [v for v in bm.verts if not v.is_boundary]
    for _ in range(3):
        bmesh.ops.smooth_vert(bm, verts=inner, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
    border = [v for v in bm.verts if v.is_boundary]
    for _ in range(8):
        new = {}
        for v in border:
            nb = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
            if len(nb) == 2:
                new[v] = v.co * 0.5 + (nb[0].co + nb[1].co) * 0.25
        for v, co in new.items():
            v.co = co
    bm.normal_update()
    # Normal de bir kez komşularla ortalanır (koltuk altı gibi içbükey yerde katlanmasın)
    nrm = {}
    for v in bm.verts:
        n = v.normal.copy()
        for e in v.link_edges:
            n += e.other_vert(v).normal
        nrm[v] = n.normalized()
    for v in bm.verts:
        v.co += nrm[v] * spec["gap"]
    bm.normal_update()


def boundary_samples(bm) -> tuple:
    """Kenar halkaları → (KDTree, türler, halka boyunca uzunluk) — 0,5 mm aralıklı örnekler."""
    typ = bm.verts.layers.int["btype"]
    edges = [e for e in bm.edges if e.is_boundary]
    left = set(edges)
    pts, kinds, arcl = [], [], []
    while left:
        e0 = left.pop()
        loop = [e0.verts[0], e0.verts[1]]
        cur = e0
        while True:
            v = loop[-1]
            nxt = [e for e in v.link_edges if e in left]
            if not nxt:
                break
            cur = nxt[0]
            left.discard(cur)
            loop.append(cur.other_vert(v))
        votes = [loop_v[typ] for loop_v in loop]
        kind = max(set(votes), key=votes.count)
        s = 0.0
        for a, b in zip(loop[:-1], loop[1:]):
            L = (b.co - a.co).length
            k = max(int(L / 0.0005), 1)
            for i in range(k):
                pts.append(a.co.lerp(b.co, i / k))
                kinds.append(kind)
                arcl.append(s + L * i / k)
            s += L
        log("kenar halkası", BTYPES[kind], "uzunluk %.3f m" % s, "köşe", len(loop))
    kd = KDTree(len(pts))
    for i, p in enumerate(pts):
        kd.insert(p, i)
    kd.balance()
    return kd, np.array(kinds), np.array(arcl)


# --- Doku: piksel başına öznitelik ----------------------------------------------------------------

def raster(tri_uv: np.ndarray, tri_attr: np.ndarray, W: int, H: int) -> np.ndarray:
    k = tri_attr.shape[2]
    out = np.full((H, W, k), np.nan, dtype=np.float64)
    px = tri_uv.copy()
    px[..., 0] = tri_uv[..., 0] * W - 0.5
    px[..., 1] = (1.0 - tri_uv[..., 1]) * H - 0.5
    for t in range(len(px)):
        a, b, c = px[t]
        x0, x1 = int(max(np.floor(min(a[0], b[0], c[0])) - 1, 0)), int(min(np.ceil(max(a[0], b[0], c[0])) + 1, W - 1))
        y0, y1 = int(max(np.floor(min(a[1], b[1], c[1])) - 1, 0)), int(min(np.ceil(max(a[1], b[1], c[1])) + 1, H - 1))
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
        m = (l0 >= -0.03) & (l1 >= -0.03) & (l2 >= -0.03)
        if not m.any():
            continue
        A = tri_attr[t]
        out[ys[m], xs[m]] = l0[m, None] * A[0] + l1[m, None] * A[1] + l2[m, None] * A[2]
    return out


def texel_attrs(o, cat: Cat, bkd) -> dict:
    """Kıyafet yüzeyinin (Solidify'dan ÖNCE) piksel başına öznitelikleri."""
    me = o.data
    me.calc_loop_triangles()
    uv = me.uv_layers.active.data
    nv = len(me.vertices)
    P = np.array([v.co[:] for v in me.vertices])
    N = np.array([v.normal[:] for v in me.vertices])
    lf = np.zeros(nv)
    for i, v in enumerate(me.vertices):
        w = cat.weights_at(v.co)
        lf[i] = sum(w.get(b, 0.0) for s in FRONT for b in FRONT[s])
    attr = np.concatenate([P, N, lf[:, None]], axis=1)
    n = len(me.loop_triangles)
    tuv, tat = np.zeros((n, 3, 2)), np.zeros((n, 3, attr.shape[1]))
    for i, t in enumerate(me.loop_triangles):
        for k in range(3):
            tuv[i, k] = uv[t.loops[k]].uv[:]
            tat[i, k] = attr[t.vertices[k]]
    R = raster(tuv, tat, TEX, TEX)
    valid = ~np.isnan(R[..., 0])
    ys, xs = np.nonzero(valid)
    A = {"ys": ys, "xs": xs, "valid": valid}
    Pt = R[ys, xs, 0:3]
    Nt = R[ys, xs, 3:6]
    Nt /= np.maximum(np.linalg.norm(Nt, axis=1, keepdims=True), 1e-9)
    A["P"], A["N"], A["lf"] = Pt, Nt, np.clip(R[ys, xs, 6], 0, 1)
    A["x"], A["y"], A["z"] = Pt[:, 0], Pt[:, 1], Pt[:, 2]
    A["theta"] = np.arctan2(Pt[:, 0], Pt[:, 2] - ZC)
    A["arc"] = A["theta"] * R_BODY
    # Ön bacak: kendi tarafının zinciri boyunca t ve eksen çevresinde açı (0 = dış yan)
    tl, ph, ar = np.zeros(len(Pt)), np.zeros(len(Pt)), np.zeros(len(Pt))
    for side, ch in cat.chain.items():
        m = (Pt[:, 0] > 0) if side == "L" else (Pt[:, 0] <= 0)
        t, dist, q, total = leg_param(Pt[m], ch)
        rel = Pt[m] - q
        lat = np.array([1.0 if side == "L" else -1.0, 0.0, 0.0])
        fwd = np.array([0.0, -1.0, 0.0])
        ph[m] = np.arctan2(rel @ fwd, rel @ lat)
        tl[m] = t
        ar[m] = t * total
    A["tleg"], A["phi"], A["along"] = tl, ph, ar
    # En yakın kenar: türü, kenar boyunca uzunluk, uzaklık
    kind, s, d = np.zeros(len(Pt), dtype=int), np.zeros(len(Pt)), np.zeros(len(Pt))
    kd, kinds, arcl = bkd
    for i in range(len(Pt)):
        co, idx, dist = kd.find(Pt[i])
        kind[i], s[i], d[i] = kinds[idx], arcl[idx], dist
    A["bkind"], A["bs"], A["bd"] = kind, s, d
    A["sleeve"] = smooth(0.35, 0.65, A["lf"])
    log("doku pikseli", len(Pt))
    return A


# --- Gürültü ve çıkartmalar --------------------------------------------------------------------------

_LATTICE = np.random.default_rng(11).random((64, 64, 64))


def vnoise(P: np.ndarray, scale: float, seed: int = 0) -> np.ndarray:
    X = P * scale + seed * 17.3
    i = np.floor(X).astype(int)
    f = X - i
    f = f * f * (3 - 2 * f)
    out = 0.0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                g = _LATTICE[(i[:, 0] + dx) % 64, (i[:, 1] + dy) % 64, (i[:, 2] + dz) % 64]
                w = (f[:, 0] if dx else 1 - f[:, 0]) * (f[:, 1] if dy else 1 - f[:, 1]) * (f[:, 2] if dz else 1 - f[:, 2])
                out = out + g * w
    return out


def fbm(P, scale, octaves=3, seed=0):
    tot, amp, s = 0.0, 1.0, scale
    norm = 0.0
    for k in range(octaves):
        tot = tot + vnoise(P, s, seed + k) * amp
        norm += amp
        amp *= 0.5
        s *= 2.0
    return tot / norm


def load_decal(path: str) -> np.ndarray:
    im = bpy.data.images.load(path)
    im.colorspace_settings.name = "Non-Color"
    w, h = im.size
    a = np.array(im.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1]
    return a   # satır 0 = üst, 0..1


def surface_anchor(A, y: float, theta: float) -> int:
    """Gövde koordinatında (y, açı) en yakın doku pikseli (yamaların merkezi)."""
    return int(np.argmin((A["y"] - y) ** 2 + ((A["theta"] - theta) * R_BODY) ** 2 + A["sleeve"] * 1.0))


def stamp(col, A, decal: np.ndarray, center: int, width: float, flip: bool = False) -> np.ndarray:
    """Çıkartmayı merkez pikselin teğet düzlemine yansıt: yatay eksen gövde boyunca (sol yanda başa→kuyruğa, sağ
    yanda tersi; yandan bakan okusun), dikey eksen yukarı."""
    C, Nc = A["P"][center], A["N"][center]
    eu = np.array([0.0, -1.0 if flip else 1.0, 0.0])
    eu = eu - Nc * (eu @ Nc)
    eu /= np.linalg.norm(eu)
    ev = np.cross(Nc, eu)
    if ev[2] < 0:
        ev = -ev
    h, w = decal.shape[:2]
    height = width * h / w
    rel = A["P"] - C
    u = rel @ eu / width + 0.5
    v = 0.5 - rel @ ev / height
    m = (u >= 0) & (u < 1) & (v >= 0) & (v < 1) & (A["N"] @ Nc > 0.4) & (np.linalg.norm(rel, axis=1) < width)
    px = np.clip((u[m] * w).astype(int), 0, w - 1)
    py = np.clip((v[m] * h).astype(int), 0, h - 1)
    rgba = decal[py, px]
    a = rgba[:, 3:4]
    col[m] = col[m] * (1 - a) + rgba[:, :3] * 255.0 * a
    return col


# --- Desenler ---------------------------------------------------------------------------------------

def body_range(A) -> tuple:
    torso = A["sleeve"] < 0.2
    top = torso & (A["N"][:, 2] > 0.5)
    return float(A["y"][top].min()), float(A["y"][top].max())


def paint_vest(A, decals) -> np.ndarray:
    y0, y1 = body_range(A)
    weave = 0.95 + 0.05 * np.abs(np.sin(A["x"] * 2600) * np.sin(A["y"] * 2600 + A["z"] * 2600))
    col = np.array([255.0, 104.0, 14.0]) * (weave * (0.94 + 0.08 * fbm(A["P"], 40.0)))[:, None]
    torso = 1.0 - A["sleeve"]
    for f in (0.42, 0.74):
        yb = y0 + (y1 - y0) * f
        band = (1.0 - smooth(0.0052, 0.0062, np.abs(A["y"] - yb))) * torso
        beads = 0.88 + 0.12 * (np.sin(A["x"] * 5200) * np.sin(A["z"] * 5200 + A["y"] * 900) > 0)
        silver = np.array([206.0, 210.0, 216.0]) * beads[:, None]
        edge = 1.0 - smooth(0.0046, 0.0052, np.abs(A["y"] - yb))
        col = mix(col, silver * (0.86 + 0.14 * edge)[:, None], band)
    piping = 1.0 - smooth(0.0042, 0.0050, A["bd"])
    col = mix(col, np.array([46.0, 46.0, 50.0]) * (0.9 + 0.1 * np.abs(np.sin(A["bs"] * 1800)))[:, None], piping)
    return col


def paint_race(A, decals) -> np.ndarray:
    sheen = 0.9 + 0.12 * fbm(A["P"], 30.0) + 0.04 * A["N"][:, 2]
    col = np.array([200.0, 22.0, 32.0]) * sheen[:, None]
    torso = 1.0 - A["sleeve"]
    top = smooth(0.0, 0.35, A["N"][:, 2])
    ax = np.abs(A["x"])
    stripe = (smooth(0.0034, 0.0042, ax) * (1.0 - smooth(0.0120, 0.0128, ax))) * torso * top
    col = mix(col, np.array([246.0, 246.0, 246.0]) * sheen[:, None], stripe)
    # Kolun dış yanında beyaz şerit
    sl = (1.0 - smooth(0.32, 0.4, np.abs(A["phi"]))) * A["sleeve"]
    col = mix(col, np.array([246.0, 246.0, 246.0]) * sheen[:, None], sl)
    # Yamalar: omuzlarda yuvarlaklar, yanlarda AUTO YARD
    y0, y1 = body_range(A)
    col = stamp(col, A, decals["roundel_7"], surface_anchor(A, y0 + (y1 - y0) * 0.2, math.radians(62)), 0.026)
    col = stamp(col, A, decals["roundel_flag"], surface_anchor(A, y0 + (y1 - y0) * 0.2, math.radians(-62)), 0.026,
                flip=True)
    col = stamp(col, A, decals["patch_autoyard"], surface_anchor(A, y0 + (y1 - y0) * 0.62, math.radians(80)), 0.05)
    col = stamp(col, A, decals["patch_autoyard"], surface_anchor(A, y0 + (y1 - y0) * 0.62, math.radians(-80)), 0.05,
                flip=True)
    # Siyah ribana: yaka, kol ağzı, etek
    width = np.where(A["bkind"] == 2, 0.0085, 0.0095)
    rib = 1.0 - smooth(width - 0.0006, width, A["bd"])
    ribs = 0.74 + 0.26 * np.abs(np.sin(A["bs"] * math.pi / 0.0026))
    col = mix(col, np.array([30.0, 30.0, 34.0]) * ribs[:, None], rib)
    return col


def paint_leather(A, decals) -> np.ndarray:
    grain = 0.86 + 0.2 * fbm(A["P"], 55.0, 4, 3)
    crease = np.abs(np.sin(fbm(A["P"] * np.array([1.0, 3.0, 1.0]), 25.0, 2, 7) * 40.0))
    tone = grain * (0.92 + 0.08 * crease) * (0.92 + 0.12 * A["N"][:, 2])
    col = np.array([38.0, 34.0, 37.0]) * tone[:, None]
    # Kenarlarda hafif aşınma (açık)
    wear = (1.0 - smooth(0.0, 0.003, A["bd"])) * 0.5
    col = mix(col, np.array([70.0, 64.0, 66.0]) * tone[:, None], wear)
    # Yaka: geniş yaka bandı + iç çizgisi
    neck = A["bkind"] == 0
    lapel = neck * (1.0 - smooth(0.0125, 0.0132, A["bd"]))
    col = mix(col, np.array([48.0, 44.0, 47.0]) * tone[:, None], lapel)
    seam = neck * (1.0 - smooth(0.0004, 0.0008, np.abs(A["bd"] - 0.0136)))
    col = mix(col, np.array([14.0, 13.0, 14.0]), seam)
    # Dikiş: her kenardan 5,5 mm içeride kesikli açık çizgi
    stitch = (1.0 - smooth(0.00035, 0.0007, np.abs(A["bd"] - 0.0058))) * (np.mod(A["bs"], 0.003) < 0.0019)
    col = mix(col, np.array([128.0, 122.0, 124.0]), stitch * 0.9)
    # Zımbalar: sırttaki yaka boyunca
    sd = np.mod(A["bs"], 0.011) - 0.0055
    stud_r = np.sqrt(sd ** 2 + (A["bd"] - 0.0088) ** 2)
    stud = neck * (A["N"][:, 2] > 0.25) * (1.0 - smooth(0.0019, 0.0023, stud_r))
    dome = np.clip(1.0 - stud_r / 0.0021, 0, 1) ** 0.5
    col = mix(col, (np.array([150.0, 152.0, 158.0]) + 90.0 * dome[:, None]), stud)
    # Asimetrik fermuar: göğüs önünde (önden bakınca) sol omuzdan sağ alta çapraz
    front = smooth(0.25, 0.5, -A["N"][:, 1]) * (1.0 - A["sleeve"])
    a2, b2 = np.array([0.024, 0.214]), np.array([-0.016, 0.104])
    q = np.stack([A["x"], A["z"]], axis=1)
    dv = b2 - a2
    L = np.linalg.norm(dv)
    t = np.clip((q - a2) @ dv / (L * L), 0, 1)
    dist = np.linalg.norm(q - (a2 + t[:, None] * dv), axis=1)
    tape = front * (1.0 - smooth(0.0030, 0.0036, dist))
    col = mix(col, np.array([16.0, 16.0, 18.0]), tape)
    teeth = front * (1.0 - smooth(0.0013, 0.0018, dist))
    alt = (np.mod(t * L, 0.0016) < 0.0008)
    col = mix(col, np.where(alt[:, None], [200.0, 202.0, 208.0], [128.0, 130.0, 136.0]), teeth)
    pull = front * (np.abs(t * L - 0.006) < 0.0035) * (dist < 0.0042)
    col = mix(col, np.array([214.0, 216.0, 222.0]), pull)
    # Yan cep fermuarları
    for sgn in (1.0, -1.0):
        side = smooth(0.4, 0.6, sgn * A["N"][:, 0]) * (1.0 - A["sleeve"])
        pa, pb = np.array([-0.085, 0.118]), np.array([-0.045, 0.152])
        q2 = np.stack([A["y"], A["z"]], axis=1)
        dv2 = pb - pa
        t2 = np.clip((q2 - pa) @ dv2 / (dv2 @ dv2), 0, 1)
        d2 = np.linalg.norm(q2 - (pa + t2[:, None] * dv2), axis=1)
        col = mix(col, np.array([182.0, 184.0, 190.0]), side * (1.0 - smooth(0.0007, 0.0011, d2)))
    return col


# Fair Isle motifi (7 ilmek sırası × 8 ilmek tekrar): 1 = krem
MOTIF = ["11111111",
         "00010000",
         "00111000",
         "01101100",
         "00111000",
         "00010000",
         "11111111"]


def paint_sweater(A, decals) -> np.ndarray:
    red = np.array([176.0, 30.0, 44.0])
    cream = np.array([240.0, 232.0, 214.0])
    sw, sh = 0.0056, 0.0048                     # ilmek eni (çevre boyunca) ve boyu — oyunda okunsun diye iri
    sl = A["sleeve"] > 0.5
    around = np.where(sl, A["phi"] * 0.02, A["arc"])
    along = np.where(sl, A["along"], A["y"])
    cu, cv = around / sw, along / sh
    i, j = np.floor(cu), np.floor(cv)
    fu, fv = cu - i, cv - j
    # V ilmeği: iki eğik lob
    x = np.where(fu < 0.5, fu * 2.0, (1.0 - fu) * 2.0)
    dlob = x - (0.5 + 0.38 * (fv - 0.5))
    lob = np.clip(1.0 - (np.abs(dlob) / 0.55) ** 2, 0.0, 1.0)
    shade = (0.62 + 0.38 * lob) * (0.8 + 0.2 * np.sin(math.pi * fv))
    # Motif bandı: gövdede ortada 7 sıra
    y0, y1 = body_range(A)
    j0 = math.floor((y0 + (y1 - y0) * 0.5) / sh) - 3
    row = (j - j0).astype(int)
    in_band = (~sl) & (row >= 0) & (row < 7)
    motif = np.zeros(len(row), dtype=bool)
    rr = np.clip(row, 0, 6)
    ii = (i.astype(int) % 8)
    lut = np.array([[c == "1" for c in r] for r in MOTIF])
    motif = in_band & lut[rr, ii]
    # Noktalar: bandın iki yanında birer sıra seyrek krem ilmek
    dots = (~sl) & ((row == -3) | (row == 9)) & ((i.astype(int) % 4) == 0)
    is_cream = motif | dots
    base = np.where(is_cream[:, None], cream, red)
    col = base * shade[:, None]
    # Ribana: kenarlardan 1 cm, dikey (kenara dik) fitiller
    rib = 1.0 - smooth(0.0100, 0.0108, A["bd"])
    ribs = 0.55 + 0.45 * np.abs(np.sin(A["bs"] * math.pi / 0.0034)) ** 0.7
    col = mix(col, red * 0.86 * ribs[:, None], rib)
    # Ribananın iç sınırında ince koyu dikiş çizgisi
    col = mix(col, red * 0.55, (1.0 - smooth(0.0003, 0.0007, np.abs(A["bd"] - 0.0104))))
    col = col * (0.95 + 0.06 * fbm(A["P"], 90.0))[:, None]
    return col


PAINT = {"vest": paint_vest, "race_jacket": paint_race, "leather_jacket": paint_leather, "sweater": paint_sweater}


def hide_mask(cat: Cat, spec: dict) -> np.ndarray:
    """Kedinin UV'sinde kıyafetin altında kalan yer (1) — kesimle aynı alanlar, kenardan MASK_MARGIN içeride."""
    me = cat.obj.data
    me.calc_loop_triangles()
    uv = me.uv_layers[0].data
    bones = [b for s in FRONT for b in FRONT[s]] + list(REAR) + list(TAIL) + list(HEAD)
    attr = np.concatenate([cat.V] + [cat.W[b][:, None] for b in bones], axis=1)
    n = len(me.loop_triangles)
    tuv, tat = np.zeros((n, 3, 2)), np.zeros((n, 3, attr.shape[1]))
    for i, t in enumerate(me.loop_triangles):
        for k in range(3):
            tuv[i, k] = uv[t.loops[k]].uv[:]
            tat[i, k] = attr[t.vertices[k]]
    R = raster(tuv, tat, MASK_SIZE, MASK_SIZE)
    valid = ~np.isnan(R[..., 0])
    vals = R[valid]
    Wt = {b: vals[:, 3 + i] for i, b in enumerate(bones)}
    F = fields(vals[:, :3], Wt, cat, spec)
    img = np.zeros((MASK_SIZE, MASK_SIZE, 3))
    img[valid] = (F.min(axis=1) > MASK_MARGIN)[:, None] * 255.0
    img = dilate(img, valid, 4)
    log("gizleme maskesi: deri pikseli %d, gizlenen %%%.1f" % (valid.sum(), 100.0 * (img[valid][:, 0] > 127).mean()))
    return img


def save_png(img: np.ndarray, path: str) -> None:
    h, w, _ = img.shape
    im = bpy.data.images.new(os.path.basename(path), w, h, alpha=False)
    im.colorspace_settings.name = "Non-Color"     # pikselleri yazmadan ÖNCE (sonra değiştirmek görüntüyü sıfırlıyor)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = np.clip(img[::-1], 0, 255) / 255.0
    im.pixels = rgba.ravel()
    im.filepath_raw = path
    im.file_format = "PNG"
    im.save()


def dilate(img: np.ndarray, valid: np.ndarray, rounds: int = 12) -> np.ndarray:
    img, valid = img.copy(), valid.copy()
    for _ in range(rounds):
        acc = np.zeros_like(img)
        cnt = np.zeros(valid.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
            sv = np.roll(np.roll(valid, dy, 0), dx, 1)
            si = np.roll(np.roll(img, dy, 0), dx, 1)
            acc += si * sv[..., None]
            cnt += sv
        grow = (~valid) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        valid = valid | grow
    return img


# --- Kurulum -----------------------------------------------------------------------------------------

def build(cat: Cat, name: str, spec: dict, decals: dict):
    bm = cut_garment(cat, spec, name)
    shape_garment(bm, spec)
    bkd = boundary_samples(bm)
    # Kedinin ağırlık katmanı ve kesim katmanları gitmesin: deri aşağıda yeniden kurulur (eski grup sıraları karışırdı)
    for coll in (bm.verts.layers.deform, bm.verts.layers.float, bm.verts.layers.int):
        for key in list(coll.keys()):
            coll.remove(coll[key])
    me = bpy.data.meshes.new("wear_" + name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("acc_" + name, me)
    bpy.context.scene.collection.objects.link(o)
    o.vertex_groups.clear()
    # UV
    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.006, correct_aspect=True,
                             scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Doku
    A = texel_attrs(o, cat, bkd)
    col = PAINT[name](A, decals)
    log(name, "doku ortalama", np.nanmean(col, axis=0).round(1), "NaN", int(np.isnan(col).sum()))
    img = np.zeros((TEX, TEX, 3))
    img[A["ys"], A["xs"]] = np.clip(col, 0, 255)
    img = dilate(img, A["valid"])
    im = bpy.data.images.new("Image_0", TEX, TEX, alpha=False)   # içe aktarmada <id>_Image_0.jpg (aksesuarlarla aynı)
    im.colorspace_settings.name = "sRGB"           # ÖNCE: renk uzayını değiştirmek üretilmiş görüntüyü sıfırlıyor
    rgba = np.ones((TEX, TEX, 4), dtype=np.float32)
    rgba[..., :3] = img[::-1] / 255.0              # bayt görüntü: değerler olduğu gibi (sRGB) saklanır
    im.pixels = rgba.ravel()
    im.pack()
    if DEBUG_DIR:
        im.filepath_raw = os.path.join(DEBUG_DIR, "doku_%s.png" % name)
        im.file_format = "PNG"
        im.save()
    mat = bpy.data.materials.new("wear_" + name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
    tex.image = im
    mat.node_tree.links.new(tex.outputs[0], bsdf.inputs["Base Color"])
    mat.node_tree.nodes.active = tex
    bsdf.inputs["Roughness"].default_value = spec["rough"]
    me.materials.append(mat)
    # Kumaş kalınlığı
    sol = o.modifiers.new("Solidify", "SOLIDIFY")
    sol.thickness = spec["shell"]
    sol.offset = -1.0
    sol.use_rim = True
    sol.use_even_offset = False      # eşit kalınlık keskin köşede dikene dönüşüyordu
    bpy.ops.object.modifier_apply(modifier=sol.name)
    for p in me.polygons:
        p.use_smooth = True
    # Deri
    o.parent = cat.arm
    mod = o.modifiers.new("Armature", "ARMATURE")
    mod.object = cat.arm
    groups = {}
    for v in me.vertices:
        w = cat.weights_at(v.co)
        top4 = sorted(w.items(), key=lambda kv: -kv[1])[:4]
        tot = sum(wt for _, wt in top4) or 1.0
        for nm, wt in top4:
            if nm not in groups:
                groups[nm] = o.vertex_groups.new(name=nm)
            groups[nm].add([v.index], wt / tot, "REPLACE")
    log(name, "köşe", len(me.vertices), "üçgen", sum(len(p.vertices) - 2 for p in me.polygons),
        "deri", ", ".join(sorted(groups)))
    return o


def export(o, path: str) -> None:
    arm = o.parent
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_animations=False, export_skins=True, export_yup=True, export_apply=True,
                              export_image_format="JPEG", export_jpeg_quality=90)
    log("glb", path, os.path.getsize(path))


def check_render(cat_obj, objs: dict, out_dir: str) -> None:
    """Dinlenme duruşunda kedi + kıyafet: önden 3/4, yandan, arkadan 3/4 (Workbench, doku rengi)."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.render.resolution_x, scene.render.resolution_y = 520, 520
    scene.render.film_transparent = False
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"
    if scene.world is None:
        scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.62, 0.64, 0.66)
    cam = bpy.data.objects.new("ChkCam", bpy.data.cameras.new("ChkCam"))
    cam.data.lens = 60
    scene.collection.objects.link(cam)
    scene.camera = cam
    views = {"on": Vector((0.5, -0.95, 0.45)), "yan": Vector((1.1, 0.0, 0.25)), "arka": Vector((-0.6, 0.8, 0.6)),
             "alt": Vector((0.25, -0.9, -0.05))}
    target = Vector((0.0, -0.08, 0.16))
    for name, o in objs.items():
        for other in objs.values():
            other.hide_render = other != o
        for vname, loc in views.items():
            cam.location = target + loc
            cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out_dir, "kontrol_%s_%s.png" % (name, vname))
            bpy.ops.render.render(write_still=True)
    for o in objs.values():
        o.hide_render = False
    bpy.data.objects.remove(cam)
    log("kontrol", out_dir)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    blend, decal_dir, out_dir = argv[0], argv[1], argv[2]
    check = argv[3] if len(argv) > 3 and not argv[3].startswith("--") else ""
    only = argv[argv.index("--only") + 1].split(",") if "--only" in argv else list(ITEMS)
    global DEBUG_DIR
    DEBUG_DIR = check
    bpy.ops.wm.open_mainfile(filepath=blend)
    cat_obj = bpy.data.objects["Tekir"]
    arm = bpy.data.objects["TekirRig"]
    assert arm.matrix_world == Matrix.Identity(4) and cat_obj.matrix_world == Matrix.Identity(4)
    cat = Cat(cat_obj, arm)
    decals = {n: load_decal(os.path.join(decal_dir, n + ".png")) for n in ("patch_autoyard", "roundel_7", "roundel_flag")}
    os.makedirs(out_dir, exist_ok=True)
    objs = {}
    for name in only:
        objs[name] = build(cat, name, ITEMS[name], decals)
    for name, o in objs.items():
        export(o, os.path.join(out_dir, "%s.glb" % name))
        save_png(hide_mask(cat, ITEMS[name]), os.path.join(out_dir, "%s_mask.png" % name))
    import tekir_acc as TA
    TA.render_icons(cat_obj, objs, out_dir)
    if check:
        os.makedirs(check, exist_ok=True)
        check_render(cat_obj, objs, check)
        # Tasma ile birlikte (yaka tasmaya değmesin): oyundaki tasma GLB'si dinlenme duruşunda
        root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
        before = set(bpy.data.objects)
        bpy.ops.import_scene.gltf(filepath=os.path.join(root, "assets/pets/acc/collar_red.glb"))
        collar = [o for o in bpy.data.objects if o not in before]
        combo = {n + "_tasma": o for n, o in objs.items()}
        check_render(cat_obj, combo, check)
        for o in collar:
            bpy.data.objects.remove(o)


if __name__ == "__main__":
    main()
