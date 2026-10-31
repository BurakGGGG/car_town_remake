# MESHY → KAYNAK GLB. Meshy AI'ın iki çıktısını (dokulu tek mesh + "part-segmentation_split") oyunun Tripo
# yapısındaki kaynak GLB'ye çevirir: tripo_part_N parçaları, tek materyal, tek temel renk dokusu, boy 1.0,
# ön +Z (glTF), zemin y=0. Sonrası normal araç hattı (optimize_car.gd --ratio 1.0 …, docs/VEHICLE_ASSETS.md).
#
#   blender -b --factory-startup --python tools/meshy_prep.py -- <ayar.json>
#
# Neden pişirme: Meshy dokusu binlerce küçük UV adasından oluşan bir atlas. Godot'un sadeleştiricisi (optimize_car,
# içe aktarma LOD'u) bu dikişleri birleştirince kaportada siyah leke / kayıp cam çıkıyordu (Şahin denemesi,
# 2026-10-29). Burada üçgen azaltma Blender'da yapılır ve doku yeni, az adalı bir UV'ye pişirilir:
#   1. bölütleme parçaları dokulu mesh'e en yakın yüzle aktarılır (kutular birebir oturur, yalnız ölçek farklı)
#   2. cam adayı parçalarda yalnız koyu texel'li yüzler cam olur (Supra tavanı gövde rengi), stop = arka uçtaki
#      kırmızı texel kümeleri
#   3. kopya mesh kaynaştırılır, role göre parçalara ayrılır, her parça kendi hedefine sadeleştirilir
#   4. Smart UV + Cycles "selected to active" EMIT pişirmesi (temel renk) + gövdeye hafif AO (tekerlere değil:
#      teker dönerken kemer gölgesi de dönerdi)
#
# Ayar dosyası (tools/meshy/<id>.json):
#   textured, segmented   Meshy dosyaları;  out  çıktı GLB (assets/cars/source/<id>.glb)
#   front                 Blender'a alınmış dokulu mesh'te aracın önünün baktığı eksen ("-X" | "+X" | "-Y" | "+Y")
#   seg                   bölütleme parça numarası → rol: {"wheels": [..], "glass": [..], "trim": [..]} (gerisi gövde)
#   glass_max_value       cam adayında cam sayılan texel parlaklığı üst sınırı (varsayılan 0.38)
#   taillights            arka uçtaki kırmızı texel kümelerini stop parçasına ayır (varsayılan true)
#   tris                  hedef üçgen: {"body", "glass", "wheel", "lights", "trim"}
#   tex, ao               pişirilen doku kenarı (2048) ve AO gücü (0 = yok)
import bpy, bmesh, sys, json, math, os
import numpy as np
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree

PROJ = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
argv = sys.argv[sys.argv.index("--") + 1:]
cfg = json.load(open(argv[0]))
def P(p):
    p = os.path.expanduser(p)
    return p if os.path.isabs(p) else os.path.join(PROJ, p)

SEG = cfg["seg"]
TRIS = {"body": 80000, "glass": 4000, "wheel": 6000, "lights": 1500, "trim": 1500}
TRIS.update(cfg.get("tris", {}))
TEX = int(cfg.get("tex", 2048))
AO = float(cfg.get("ao", 0.45))
GLASS_MAX = float(cfg.get("glass_max_value", 0.38))

# rol kodları (yüz etiketi) — sıra = tripo_part_N sırası
BODY, GLASS, TAIL, FL, FR, RL, RR, TRIM = range(8)
NAMES = ["body", "glass", "taillights", "wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr", "trim"]

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.data.objects if o not in before and o.type == "MESH"]
    for o in objs:
        mw = o.matrix_world.copy()
        o.parent = None
        o.matrix_world = mw
        o.data.transform(o.matrix_world)
        o.matrix_world = Matrix.Identity(4)
    return objs


def np_verts(me):
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    return co.reshape(-1, 3)


def adjacency(bm):
    """Kenar komşuluğu: iki yüzü paylaşan her kenar için (a, b) yüz indeksleri."""
    bm.edges.ensure_lookup_table()
    pairs = [(e.link_faces[0].index, e.link_faces[1].index) for e in bm.edges if len(e.link_faces) == 2]
    ab = np.array(pairs, np.int64).reshape(-1, 2)
    return ab[:, 0], ab[:, 1]


def components(n, a, b):
    """numpy birleştir-bul: a[i]–b[i] kenarlarıyla bağlı düğümlerin kök numarası."""
    parent = np.arange(n)
    while True:
        ra, rb = parent[a], parent[b]
        if (ra == rb).all():
            return parent
        m = np.minimum(ra, rb)
        np.minimum.at(parent, ra, m)
        np.minimum.at(parent, rb, m)
        while True:
            p2 = parent[parent]
            if (p2 == parent).all():
                break
            parent = p2


def cleanup(label, a, b, area, amin, rounds=3):
    """Alanı amin'den küçük bağlı etiket bölgelerini en uzun sınırı paylaştığı komşu etikete katar."""
    for _ in range(rounds):
        same = label[a] == label[b]
        root = components(len(label), a[same], b[same])
        carea = np.bincount(root, weights=area, minlength=len(label))
        small = carea[root] < amin
        diff = ~same
        votes = {}
        for x, y in ((a[diff], b[diff]), (b[diff], a[diff])):
            sel = small[x]
            for r, l in zip(root[x[sel]].tolist(), label[y[sel]].tolist()):
                d = votes.setdefault(r, {})
                d[l] = d.get(l, 0) + 1
        if not votes:
            break
        new = {r: max(d, key=d.get) for r, d in votes.items()}
        idx = np.nonzero(small)[0]
        changed = 0
        for i, r in zip(idx.tolist(), root[idx].tolist()):
            if r in new and new[r] != label[i]:
                label[i] = new[r]; changed += 1
        if changed == 0:
            break
    return label


# --- 1. dokulu mesh + bölütleme -------------------------------------------------------------------------------
hi = import_glb(P(cfg["textured"]))
assert len(hi) == 1, "dokulu GLB tek mesh olmalı"
hi = hi[0]
hi.name = "HI"
segs = import_glb(P(cfg["segmented"]))
seg_v, seg_f, seg_pid = [], [], []
base = 0
for o in segs:
    pid = int(o.name.split("part")[-1].split(".")[0])
    v = np_verts(o.data)
    n = len(o.data.polygons)
    ls = np.empty(n, np.int32); o.data.polygons.foreach_get("loop_total", ls)
    assert (ls == 3).all()
    lv = np.empty(len(o.data.loops), np.int32); o.data.loops.foreach_get("vertex_index", lv)
    seg_v.append(v); seg_f.append(lv.reshape(-1, 3) + base); seg_pid.append(np.full(n, pid, np.int32))
    base += len(v)
seg_v = np.concatenate(seg_v); seg_f = np.concatenate(seg_f); seg_pid = np.concatenate(seg_pid)
for o in segs:
    bpy.data.objects.remove(o, do_unlink=True)

hv = np_verts(hi.data)
hlo, hhi = hv.min(0), hv.max(0)
slo, shi = seg_v.min(0), seg_v.max(0)
k = (hhi - hlo) / (shi - slo)
print("HIZALAMA ölçek", np.round(k, 4), "(üç eksen aynı olmalı)")
assert np.ptp(k) / k.mean() < 0.01, "bölütleme dokulu mesh'e oturmuyor"
seg_v = (seg_v - slo) * k + hlo
seg_bvh = BVHTree.FromPolygons([tuple(p) for p in seg_v.tolist()], seg_f.tolist())

# --- 2. kaynaştırılmış kopya + yüz etiketleri --------------------------------------------------------------------
lo = hi.copy(); lo.data = hi.data.copy(); lo.name = "LO"
sc.collection.objects.link(lo)
bm = bmesh.new(); bm.from_mesh(lo.data)
L = float(max(hhi - hlo))
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=L * 1e-6)
bm.faces.ensure_lookup_table()
F = len(bm.faces)
cent = np.array([f.calc_center_median() for f in bm.faces], np.float32)
area = np.array([f.calc_area() for f in bm.faces], np.float32)
label_seg = np.empty(F, np.int32)
for i in range(F):
    _, _, idx, _ = seg_bvh.find_nearest(Vector(cent[i]))
    label_seg[i] = seg_pid[idx]
print("ETİKET", {int(p): int((label_seg == p).sum()) for p in np.unique(label_seg)})

# dokudan yüz rengi (yüz UV merkezi + köşeye doğru 3 iç nokta, çoğunluk)
img = next(n.image for n in hi.data.materials[0].node_tree.nodes if n.type == "TEX_IMAGE" and n.image
           and n.image.colorspace_settings.name == "sRGB")
W, H = img.size
px = np.empty(W * H * 4, np.float32); img.pixels.foreach_get(px); px = px.reshape(H, W, 4)[:, :, :3]
uvl = bm.loops.layers.uv.active
fuv = np.array([[l[uvl].uv[:] for l in f.loops] for f in bm.faces], np.float32)  # F × 3 × 2
def sample(u):
    return px[np.clip((u[:, 1] % 1) * H, 0, H - 1).astype(int), np.clip((u[:, 0] % 1) * W, 0, W - 1).astype(int)]
mid = fuv.mean(1)
cols = np.stack([sample(mid)] + [sample(fuv[:, i] * 0.5 + mid * 0.5) for i in range(3)], 1)
val = cols.max(2)
sat = np.where(val > 1e-4, (val - cols.min(2)) / np.maximum(val, 1e-4), 0)
fval = np.median(val, 1); fsat = np.median(sat, 1)
r_, g_, b_ = cols[..., 0], cols[..., 1], cols[..., 2]
red = ((r_ > 0.25) & (r_ > 1.7 * g_) & (r_ > 1.7 * b_)).sum(1) >= 2

# önü belirle → normalize matrisi (ön -Y, sol +X, boy 1, zemin z=0, ortada)
rot = {"-X": 90.0, "+X": -90.0, "+Y": 180.0, "-Y": 0.0}[cfg.get("front", "-X")]
R = Matrix.Rotation(math.radians(rot), 4, "Z")
corners = np.array([[x, y, z] for x in (hlo[0], hhi[0]) for y in (hlo[1], hhi[1]) for z in (hlo[2], hhi[2])], np.float32)
rc = np.array([(R @ Vector(c))[:] for c in corners])
rlo, rhi = rc.min(0), rc.max(0)
s = 1.0 / (rhi[1] - rlo[1])
ctr = (rlo + rhi) / 2
NORM = Matrix.Scale(s, 4) @ Matrix.Translation(Vector((-ctr[0], -ctr[1], -rlo[2]))) @ R
ncent = np.array([(NORM @ Vector(c))[:] for c in cent], np.float32)

label = np.full(F, BODY, np.int32)
for p in SEG.get("trim", []):
    label[label_seg == p] = TRIM
glass_cand = np.isin(label_seg, SEG.get("glass", []))
adj_a, adj_b = adjacency(bm)
deg = np.bincount(adj_a, minlength=F) + np.bincount(adj_b, minlength=F)
g = (glass_cand & (fval <= GLASS_MAX)).astype(np.float32)
for _ in range(4):   # komşu çoğunluğu: koyu/açık texel sınırında tek tek yüzler savrulmasın
    s_ = np.bincount(adj_a, weights=g[adj_b], minlength=F) + np.bincount(adj_b, weights=g[adj_a], minlength=F)
    g = np.where(glass_cand, (g + s_) / (1 + deg) > 0.5, 0).astype(np.float32)
label[g > 0.5] = GLASS
wheel_parts = SEG.get("wheels", [])
for p in wheel_parts:
    m = label_seg == p
    c = (ncent[m] * area[m, None]).sum(0) / area[m].sum()
    corner = (FL if c[1] < 0 else RL) if c[0] > 0 else (FR if c[1] < 0 else RR)
    label[m] = corner
    print("TEKER parça", p, "→", NAMES[corner], np.round(c, 4))
assert len(set(label[np.isin(label_seg, wheel_parts)])) == len(wheel_parts) == 4, "teker köşeleri çakıştı"

# stop: arka %14'teki kırmızı gövde yüzleri; küçük kırıntılar (rozet, yansıma) elenir
if cfg.get("taillights", True):
    cand = (label == BODY) & red & (ncent[:, 1] > 0.5 - 0.14)
    idx = np.nonzero(cand)[0]
    candset = set(idx.tolist())
    comp = {}
    ncomp = 0
    for i in idx:
        if i in comp:
            continue
        cid = ncomp; ncomp += 1
        stack = [i]; comp[i] = cid
        while stack:
            f = bm.faces[stack.pop()]
            for e in f.edges:
                for g in e.link_faces:
                    if g.index in candset and g.index not in comp:
                        comp[g.index] = cid; stack.append(g.index)
    if comp:
        carea = {}
        for i, cid in comp.items():
            carea[cid] = carea.get(cid, 0.0) + area[i]
        big = max(carea.values())
        keep = {cid for cid, a in carea.items() if a >= big * 0.12}
        for i, cid in comp.items():
            if cid in keep:
                label[i] = TAIL
        print("STOP kümeleri", len(carea), "tutulan", len(keep), "yüz", int((label == TAIL).sum()))

# temizlik: kırıntı bölgeler (en yakın yüz eşlemesinin sınır gürültüsü, cam eşiğinin tuz-biberi) komşuya katılır
AMIN = float(cfg.get("min_region", 2.5e-4)) * area.sum()
label = cleanup(label, adj_a, adj_b, area, AMIN)
# önce yuvalar: yuva sayısından büyük material_index to_mesh'te sıfırlanır
lo.data.materials.clear()
for n in NAMES:
    lo.data.materials.append(bpy.data.materials.new("P_" + n))
for i, f in enumerate(bm.faces):
    f.material_index = int(label[i])
bm.to_mesh(lo.data); bm.free()
lo.data.transform(NORM); lo.data.update()
hi.data.transform(NORM); hi.data.update()
print("ROLLER", {NAMES[r]: int((label == r).sum()) for r in range(len(NAMES))})

# --- 3. parçala + sadeleştir ---------------------------------------------------------------------------------------
for o in bpy.context.selected_objects:
    o.select_set(False)
bpy.context.view_layer.objects.active = lo
lo.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")
parts = [o for o in sc.objects if o.type == "MESH" and o != hi]
for o in parts:
    role = o.data.materials[o.data.polygons[0].material_index].name[2:]   # separate kullanılmayan yuvaları atabilir
    o.name = "R_" + role
    target = TRIS["wheel" if role.startswith("wheel") else ("lights" if role == "taillights" else role)]
    n = len(o.data.polygons)
    if n > target:
        mod = o.modifiers.new("dec", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.ratio = target / n
        mod.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = o
        bpy.ops.object.modifier_apply(modifier=mod.name)
    print("PARÇA", role, n, "→", len(o.data.polygons))

# --- 4. tek nesne, yeni UV, pişirme ------------------------------------------------------------------------------
for o in sc.objects:
    o.select_set(o in parts)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
low = bpy.context.view_layer.objects.active
low.name = "LOW"
for uv in list(low.data.uv_layers):
    low.data.uv_layers.remove(uv)
low.data.uv_layers.new(name="UVMap")
# UV: Smart UV sadeleşmiş yüzeyin gürültülü normalleriyle ~10 bin ada üretiyordu. Bunun yerine her yüz altı küp
# yönünden birine atanır (komşu oylamasıyla yumuşatılır), küçük adalar en uygun komşuya katılır, ada sınırları
# dikiş olur ve açı tabanlı açılım + paketleme yapılır → birkaç yüz ada.
bm = bmesh.new(); bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
Fl = len(bm.faces)
fn = np.array([f.normal[:] for f in bm.faces], np.float32)
fa = np.array([f.calc_area() for f in bm.faces], np.float32)
ua, ub = adjacency(bm)
AX = np.array([[1, 0, 0], [-1, 0, 0], [0, 1, 0], [0, -1, 0], [0, 0, 1], [0, 0, -1]], np.float32)
dots = fn @ AX.T                                   # Fl × 6
dlab = dots.argmax(1)
degl = np.bincount(ua, minlength=Fl) + np.bincount(ub, minlength=Fl)
for _ in range(8):
    votes = np.zeros((Fl, 6), np.float32)
    for x, y in ((ua, ub), (ub, ua)):
        np.add.at(votes, (x, dlab[y]), 1.0)
    dlab = (dots + 0.9 * votes / np.maximum(degl, 1)[:, None]).argmax(1)
UV_MIN = float(cfg.get("uv_min_island", 1.5e-4)) * fa.sum()
for _ in range(4):
    same = dlab[ua] == dlab[ub]
    root = components(Fl, ua[same], ub[same])
    carea = np.bincount(root, weights=fa, minlength=Fl)
    small = carea[root] < UV_MIN
    if not small.any():
        break
    # küçük adanın ortalama normali, komşu adaların yönlerinden en uyanına
    mean_n = np.zeros((Fl, 3), np.float32)
    np.add.at(mean_n, root, fn * fa[:, None])
    diff = ~same
    cand = {}
    for x, y in ((ua[diff], ub[diff]), (ub[diff], ua[diff])):
        sel = small[x]
        for r, d in zip(root[x[sel]].tolist(), dlab[y[sel]].tolist()):
            cand.setdefault(r, set()).add(d)
    if not cand:
        break
    for r, ds in cand.items():
        ds = sorted(ds)
        best = ds[int(np.argmax(mean_n[r] @ AX[ds].T))]
        cand[r] = best
    idx = np.nonzero(small)[0]
    for i, r in zip(idx.tolist(), root[idx].tolist()):
        if r in cand:
            dlab[i] = cand[r]
same = dlab[ua] == dlab[ub]
root = components(Fl, ua[same], ub[same])
print("UV adası", len(np.unique(root)))
bm.edges.ensure_lookup_table()
for e in bm.edges:
    lf = e.link_faces
    e.seam = bool(len(lf) == 2 and root[lf[0].index] != root[lf[1].index])
bm.to_mesh(low.data); bm.free()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.unwrap(method="ANGLE_BASED", fill_holes=True, correct_aspect=True, margin=0.002)
bpy.ops.object.mode_set(mode="OBJECT")
# alta bakan adalar (taban, hiç görünmez) paketlemeden önce küçültülür → görünen yüzeylere daha çok texel
DOWN_SCALE = float(cfg.get("underside_uv_scale", 0.3))
uvd = low.data.uv_layers.active.data
luv = np.empty(len(low.data.loops) * 2, np.float32); uvd.foreach_get("uv", luv); luv = luv.reshape(-1, 2)
lp = np.empty(len(low.data.loops), np.int64)
pstart = np.empty(Fl, np.int64); low.data.polygons.foreach_get("loop_start", pstart)
ptot = np.empty(Fl, np.int64); low.data.polygons.foreach_get("loop_total", ptot)
for i in range(Fl):
    lp[pstart[i]:pstart[i] + ptot[i]] = i
down = dlab[lp] == 5
if down.any():
    lroot = root[lp]
    for r in np.unique(lroot[down]):
        m = lroot == r
        c = luv[m].mean(0)
        luv[m] = c + (luv[m] - c) * DOWN_SCALE
    uvd.foreach_set("uv", luv.ravel())
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
try:
    bpy.ops.uv.pack_islands(rotate=True, margin=0.0025, shape_method="CONCAVE")
except TypeError as e:
    print("pack", e)
    bpy.ops.uv.pack_islands(rotate=True, margin=0.0025)
bpy.ops.object.mode_set(mode="OBJECT")

color_img = bpy.data.images.new("albedo", TEX, TEX, alpha=False)
ao_img = bpy.data.images.new("ao", TEX, TEX, alpha=False)
ao_img.pixels.foreach_set(np.ones(TEX * TEX * 4, np.float32))   # pişirilmeyen (teker) texel'ler AO = 1 kalsın
dummy = bpy.data.images.new("dummy", 64, 64, alpha=False)
for img_ in (ao_img, dummy):
    img_.colorspace_settings.name = "Non-Color"
for m in low.data.materials:
    m.use_nodes = True
    nt = m.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = color_img
    nt.nodes.active = tex

# kaynak: temel renk dokusu → emisyon (metal parçalar EMIT'te kararmasın)
hm = hi.data.materials[0]
nt = hm.node_tree
bc = next(n for n in nt.nodes if n.type == "TEX_IMAGE" and n.image == img)
out = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
em = nt.nodes.new("ShaderNodeEmission")
nt.links.new(bc.outputs["Color"], em.inputs["Color"])
nt.links.new(em.outputs["Emission"], out.inputs["Surface"])

try:
    sc.render.engine = "CYCLES"
except TypeError as e:
    print("motor", e)
sc.cycles.device = "CPU"
bk = sc.render.bake
bk.use_selected_to_active = True
# kafes: sadeleşmiş cam yüksek çözünürlüklü camın içine düşebiliyor; kafes dışarıda kalmazsa ışın kaportanın iç
# yüzüne çarpıp camda açık leke bırakıyordu (Supra yan camı)
bk.cage_extrusion = float(cfg.get("cage", 0.008))
bk.max_ray_distance = bk.cage_extrusion * 2.5
bk.margin = 8
bk.margin_type = "EXTEND"
sc.cycles.samples = 4
for o in sc.objects:
    o.select_set(o in (hi, low))
bpy.context.view_layer.objects.active = low
bpy.ops.object.bake(type="EMIT")
print("PİŞİRME renk tamam")

# AO yalnız teker olmayan yüzlere: teker materyallerinin hedefi geçici olarak kukla doku
if AO > 0:
    hi.hide_render = True
    bk.use_selected_to_active = False
    sc.cycles.samples = 48
    if sc.world is None:
        sc.world = bpy.data.worlds.new("w")
    try:
        sc.world.light_settings.distance = 0.06
    except Exception as e:
        print("ao mesafe", e)
    for m in low.data.materials:
        t = next(n for n in m.node_tree.nodes if n.type == "TEX_IMAGE")
        t.image = dummy if m.name.startswith("P_wheel") else ao_img
    for o in sc.objects:
        o.select_set(o == low)
    bpy.ops.object.bake(type="AO")
    print("PİŞİRME AO tamam")
    # teker maskesi: AO pişirmesinin kenar dolgusu komşu adaların AO'sunu teker texel'lerine taşıyordu (jant koyu)
    mask_img = bpy.data.images.new("wheelmask", TEX, TEX, alpha=False)
    mask_img.colorspace_settings.name = "Non-Color"
    for m in low.data.materials:
        nt_ = m.node_tree
        t = next(n for n in nt_.nodes if n.type == "TEX_IMAGE")
        t.image = mask_img
        nt_.nodes.active = t
        e_ = nt_.nodes.new("ShaderNodeEmission")
        v_ = 1.0 if m.name.startswith("P_wheel") else 0.0
        e_.inputs["Color"].default_value = (v_, v_, v_, 1)
        o_ = next(n for n in nt_.nodes if n.type == "OUTPUT_MATERIAL")
        nt_.links.new(e_.outputs["Emission"], o_.inputs["Surface"])
    sc.cycles.samples = 1
    bpy.ops.object.bake(type="EMIT")
    c = np.empty(TEX * TEX * 4, np.float32); color_img.pixels.foreach_get(c)
    a = np.empty(TEX * TEX * 4, np.float32); ao_img.pixels.foreach_get(a)
    wm = np.empty(TEX * TEX * 4, np.float32); mask_img.pixels.foreach_get(wm)
    c = c.reshape(-1, 4); a = a.reshape(-1, 4)[:, :1]; wm = np.clip(wm.reshape(-1, 4)[:, :1], 0, 1)
    c[:, :3] *= 1.0 - AO * (1.0 - np.clip(a, 0, 1)) * (1.0 - wm)
    color_img.pixels.foreach_set(c.ravel())
    color_img.update()

# dışa aktarıcı dokuyu diskteki dosyadan okusun (üretilmiş görüntü güvenilmez); çalışma klasörü depo dışı
WORK = os.path.expanduser(cfg.get("work", "~/Projects/ct_shots/meshy_prep/" + os.path.basename(cfg["out"])[:-4]))
os.makedirs(WORK, exist_ok=True)
color_img.filepath_raw = os.path.join(WORK, "baked_albedo.png")
color_img.file_format = "PNG"
color_img.save()
color_img.reload()

# --- 5. tek materyal, parçalara ayır, dışa aktar ---------------------------------------------------------------
final = bpy.data.materials.new("car")
final.use_nodes = True
fnt = final.node_tree
bsdf = next(n for n in fnt.nodes if n.type == "BSDF_PRINCIPLED")
ft = fnt.nodes.new("ShaderNodeTexImage"); ft.image = color_img
fnt.links.new(ft.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Metallic"].default_value = 0.0
bsdf.inputs["Roughness"].default_value = 0.5

for o in sc.objects:
    o.select_set(o == low)
bpy.context.view_layer.objects.active = low
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.separate(type="MATERIAL")
bpy.ops.object.mode_set(mode="OBJECT")
out_parts = {}
for o in [o for o in sc.objects if o.type == "MESH" and o != hi]:
    rid = o.data.materials[o.data.polygons[0].material_index].name[2:]
    out_parts[NAMES.index(rid)] = o
bpy.data.objects.remove(hi, do_unlink=True)

summary = {"parts": {}, "wheel_axes": {}}
for n_, rid in enumerate(sorted(out_parts)):
    o = out_parts[rid]
    o.name = o.data.name = "tripo_part_%d" % n_
    o.data.materials.clear(); o.data.materials.append(final)
    bpy.context.view_layer.objects.active = o
    for q in sc.objects:
        q.select_set(q == o)
    # ayırmanın asıl nesnesinde öteki parçaların yüzsüz köşeleri kalıyor → pivot (BOUNDS) kayıyordu
    bm = bmesh.new(); bm.from_mesh(o.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(o.data); bm.free()
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    summary["parts"][n_] = {"role": NAMES[rid], "tris": len(o.data.polygons)}
    if NAMES[rid].startswith("wheel"):
        # dönme ekseni: lastik dış zarfına (yan izdüşüm, alt 120° hariç) en küçük kareler çemberi
        v = np_verts(o.data) + np.array(o.location[:], np.float32)   # dönüş / ölçek yok
        yz = v[:, 1:3]
        c = (yz.min(0) + yz.max(0)) / 2
        r = (yz[:, 1].max() - yz[:, 1].min()) / 2
        for _ in range(4):   # dış zarf: 5°'lik dilimlerin en uzak noktası, alt 120° (ezik taban) hariç
            d = np.hypot(*(yz - c).T)
            ang = np.degrees(np.arctan2(yz[:, 0] - c[0], yz[:, 1] - c[1]))  # 0 = yukarı
            env = []
            for a0 in range(-120, 120, 5):
                m = (ang >= a0) & (ang < a0 + 5)
                if m.any():
                    env.append(np.nonzero(m)[0][np.argmax(d[m])])
            if len(env) < 20:
                break
            e = yz[env]
            A = np.c_[2 * e, np.ones(len(e))]
            sol = np.linalg.lstsq(A, (e ** 2).sum(1), rcond=None)[0]
            rn = math.sqrt(sol[2] + sol[0] ** 2 + sol[1] ** 2)
            if not (0.8 * r < rn < 1.2 * r):
                break
            c, r = sol[:2], rn
        cy, cz = c
        # Godot uzayı: y = Blender z, z = -Blender y
        summary["wheel_axes"][NAMES[rid][-2:]] = [round(float(cz), 4), round(float(-cy), 4), round(float(r), 4)]

for o in sc.objects:
    o.select_set(o.type == "MESH")
bpy.ops.export_scene.gltf(filepath=P(cfg["out"]), export_format="GLB", use_selection=True, export_apply=True,
                          export_texcoords=True, export_normals=True, export_tangents=False,
                          export_image_format="JPEG", export_jpeg_quality=92, export_yup=True)
print("ÖZET", json.dumps(summary))
