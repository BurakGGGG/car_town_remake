"""TEKİR İSKELETİ (GARAJ DOSTLARI, 2026-10-31): Meshy'nin ürettiği tek parça kedi modeline dört ayaklı iskelet kurar.

Meshy'nin otomatik iskeleti yalnız iki ayaklı karakterler içindir; kedi iskeleti burada, MODELİN ÖLÇÜLERİNDEN kurulur
(ayak kümeleri, kulak uçları, burun, kuyruk orta hattı). Sonra otomatik ağırlık, kafanın düzeltilmesi (Meshy modeli kafayı
konsept gibi hafif yana dönük üretti: dinlenme duruşu düz olsun diye kafa düzeltilip "dinlenme duruşu" yapılır) ve
metreye ölçekleme gelir. Çıktı .blend, animasyon betiği (tekir_anim.py) onu açar.

Kemik eksenleri: bütün kemiklerde YEREL X yanal eksendir (≈ −X dünya). Yerel X dönüşü = eğilme (bacak ileri/geri,
omurga/kuyruk/baş yukarı-aşağı), omurga/kuyruk/boyunda yerel Z dönüşü = sağa-sola.

  blender -b --factory-startup --python tools/pets/tekir_rig.py -- <meshy.glb> <çıktı.blend> [kontrol.png]
"""
import bpy, sys, os, math
import numpy as np
from mathutils import Vector, Matrix

S_METRE = 0.32   # Meshy birimi → metre (kulak ucu ≈ 0,35 m, sırt ≈ 0,26 m, burun-sağrı ≈ 0,40 m)

DEFORM_COLOR = (0.95, 0.15, 0.1, 1)
CONTROL_COLOR = (0.1, 0.5, 1.0, 1)


def log(*a):
    print("RAPOR", *a)


# --- İçe alma ve normalleştirme ----------------------------------------------------------

def import_cat(src: str) -> bpy.types.Object:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    mesh = next(o for o in bpy.context.scene.objects if o.type == "MESH")
    for o in bpy.context.scene.objects:
        o.select_set(o == mesh)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    for o in list(bpy.context.scene.objects):
        if o != mesh:
            bpy.data.objects.remove(o)
    mesh.name = "Tekir"
    mesh.data.name = "Tekir"
    # glTF UV dikişlerinde köşeleri ikizler: birleştirilmezse ısı ağırlığı ikizlere farklı ağırlık verir ve hareket
    # ederken dikişler çatlar (beyaz kırıntılar, 2026-10-31 ilk yürüme). UV döngü başına olduğu için dikişler korunur.
    import bmesh
    bm = bmesh.new()
    bm.from_mesh(mesh.data)
    before = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bm.to_mesh(mesh.data)
    bm.free()
    mesh.data.update()
    log("ikiz köşe birleştirme", before, "→", len(mesh.data.vertices))
    return mesh


def verts(mesh) -> np.ndarray:
    return np.array([v.co[:] for v in mesh.data.vertices])


def foot_clusters(V: np.ndarray) -> dict:
    lo, hi = V.min(0), V.max(0)
    low = V[V[:, 2] < lo[2] + (hi[2] - lo[2]) * 0.12]
    ymid = (low[:, 1].min() + low[:, 1].max()) / 2
    xmid = np.median(low[:, 0])
    out = {}
    for key, m in (("FL", (low[:, 0] > xmid) & (low[:, 1] < ymid)), ("FR", (low[:, 0] <= xmid) & (low[:, 1] < ymid)),
                   ("RL", (low[:, 0] > xmid) & (low[:, 1] >= ymid)), ("RR", (low[:, 0] <= xmid) & (low[:, 1] >= ymid))):
        s = low[m]
        out[key] = {"c": s.mean(0), "ymin": s[:, 1].min(), "ymax": s[:, 1].max()}
    return out


## Gövde orta hattı x = 0, zemin z = 0. Baş −Y'de kalır (glTF'te +Z; oyun kodu bunu bilir).
def normalize(mesh) -> None:
    V = verts(mesh)
    feet = foot_clusters(V)
    xc = float(np.mean([f["c"][0] for f in feet.values()]))
    shift = Vector((-xc, 0.0, -float(V[:, 2].min())))
    mesh.data.transform(Matrix.Translation(shift))
    mesh.data.update()
    log("normalleştirme kaydırma", tuple(round(c, 4) for c in shift))


# --- Ölçüler -----------------------------------------------------------------------------

def two_means(P: np.ndarray):
    a, b = P[np.argmin(P[:, 0])], P[np.argmax(P[:, 0])]
    for _ in range(20):
        da = np.linalg.norm(P - a, axis=1)
        db = np.linalg.norm(P - b, axis=1)
        ma = da < db
        a, b = P[ma].mean(0), P[~ma].mean(0)
    return P[ma], P[~ma]


def landmarks(mesh) -> dict:
    V = verts(mesh)
    lo, hi = V.min(0), V.max(0)
    H = hi[2]
    L = {"H": H, "feet": foot_clusters(V)}
    # Burun: en öndeki (−Y) köşeler
    nose = V[V[:, 1] < lo[1] + 0.03]
    L["nose"] = Vector(nose.mean(0))
    # Kulaklar: en üstteki köşeler iki kümeye
    top = V[V[:, 2] > H - 0.09]
    e1, e2 = two_means(top)
    ears = sorted([e1, e2], key=lambda e: e[:, 0].mean(), reverse=True)   # önce +X (kedinin SOLU)
    L["ear_L_tip"] = Vector(ears[0][np.argmax(ears[0][:, 2])])
    L["ear_R_tip"] = Vector(ears[1][np.argmax(ears[1][:, 2])])
    # Baş merkezi: ön bölgede, boyun üstünde, kulak uçları hariç
    head = V[(V[:, 1] < -0.62) & (V[:, 2] > 0.62) & (V[:, 2] < H - 0.12)]
    L["head_c"] = Vector(head.mean(0))
    # Başın baktığı yön: kulak çizgisine dik (XY), −Y tarafına
    lat = L["ear_L_tip"] - L["ear_R_tip"]
    fwd = Vector((lat.y, -lat.x, 0.0)).normalized()
    if fwd.y > 0:
        fwd = -fwd
    L["head_fwd"] = fwd
    nose_dir = (L["nose"] - L["head_c"]).to_2d().normalized()
    log("baş merkezi", tuple(round(c, 3) for c in L["head_c"]), "kulak yönü", tuple(round(c, 3) for c in fwd[:2]),
        "burun yönü", tuple(round(c, 3) for c in nose_dir))
    # Kuyruk orta hattı: sağrının arkasındaki dilimlerin merkezleri
    tail_v = V[(V[:, 1] > 0.27) & (V[:, 2] > 0.4)]
    ys = np.linspace(tail_v[:, 1].min() + 0.01, tail_v[:, 1].max() - 0.015, 7)
    pts = []
    for y in ys:
        s = tail_v[np.abs(tail_v[:, 1] - y) < 0.035]
        pts.append(Vector(s.mean(0)) if len(s) else Vector((0, y, 0.65)))
    pts[-1] = Vector(tail_v[np.argmax(tail_v[:, 1])])   # uç
    L["tail"] = pts
    return L


# --- İskelet -----------------------------------------------------------------------------

def bone(arm, name, head, tail, parent=None, deform=True, connect=False, roll_up=None):
    b = arm.edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    if parent:
        b.parent = arm.edit_bones[parent]
        b.use_connect = connect
    b.use_deform = deform
    d = (b.tail - b.head).normalized()
    if roll_up is None:
        roll_up = abs(d.z) < 0.7
    # Yerel Z: yatay kemikte yukarı, dikey kemikte ileri (−Y) → yerel X hep yanal
    b.align_roll(Vector((0, 0, 1)) if roll_up else Vector((0, -1, 0)))
    return b


def build_armature(mesh, L) -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("TekirRig")
    arm = bpy.data.objects.new("TekirRig", arm_data)
    bpy.context.scene.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(o == arm)
    bpy.ops.object.mode_set(mode="EDIT")
    a = arm_data
    hc, nose = L["head_c"], L["nose"]
    fwd = L["head_fwd"]
    bone(a, "root", (0, -0.2, 0), (0, -0.2, 0.2), deform=False, roll_up=False)
    bone(a, "hips", (0, 0.24, 0.60), (0, 0.06, 0.64), "root")
    bone(a, "spine1", (0, 0.06, 0.64), (0, -0.14, 0.66), "hips", connect=True)
    bone(a, "spine2", (0, -0.14, 0.66), (0, -0.34, 0.675), "spine1", connect=True)
    bone(a, "chest", (0, -0.34, 0.675), (0, -0.52, 0.69), "spine2", connect=True)
    # Baş kemiği kafatasının arkasından (boynun tepesi) burna: kafa çeneden değil ensesinden döner
    head_base = Vector((0.0, hc.y + 0.13, hc.z - 0.03))
    bone(a, "neck", (0, -0.52, 0.69), head_base, "chest", connect=True)
    bone(a, "head", head_base, Vector((0.0, nose.y + 0.03, head_base.z - 0.01)), "neck", connect=True)
    for side, tip in (("L", L["ear_L_tip"]), ("R", L["ear_R_tip"])):
        base = tip + (hc - tip) * 0.42
        bone(a, "ear_" + side, base, tip, "head", roll_up=False)
    tail = L["tail"]
    prev = "hips"
    tail_start = Vector((0, 0.24, 0.60))
    pts = [tail_start] + tail[1:]
    for i in range(len(pts) - 1):
        name = "tail%d" % (i + 1)
        bone(a, name, pts[i], pts[i + 1], prev, connect=(i > 0), roll_up=True)
        prev = name
    feet = L["feet"]
    for side, s in (("L", 1.0), ("R", -1.0)):
        F = feet["F" + side]
        R = feet["R" + side]
        fx, rx = float(F["c"][0]), float(R["c"][0])
        # Ön bacak: kürek kemiği → kol → ön kol → pençe (dirsek geride, bilek yere yakın)
        sh = Vector((s * 0.085, -0.55, 0.47))
        elbow = Vector((fx, -0.50, 0.29))
        wrist = Vector((fx, -0.53, 0.10))
        ftoe = Vector((fx, float(F["ymin"]) + 0.01, 0.03))
        bone(a, "scapula_" + side, (s * 0.06, -0.46, 0.74), sh, "chest", roll_up=False)
        bone(a, "upperarm_" + side, sh, elbow, "scapula_" + side, connect=True, roll_up=False)
        bone(a, "forearm_" + side, elbow, wrist, "upperarm_" + side, connect=True, roll_up=False)
        bone(a, "hand_" + side, wrist, ftoe, "forearm_" + side, connect=True, roll_up=True)
        # Arka bacak: uyluk (diz önde) → baldır (topuk geride) → tarak → parmak
        hip = Vector((s * 0.09, 0.19, 0.56))
        knee = Vector((rx, 0.06, 0.36))
        hock = Vector((rx, 0.225, 0.19))
        ball = Vector((rx, 0.13, 0.035))
        rtoe = Vector((rx, float(R["ymin"]) + 0.01, 0.02))
        bone(a, "thigh_" + side, hip, knee, "hips", roll_up=False)
        bone(a, "shin_" + side, knee, hock, "thigh_" + side, connect=True, roll_up=False)
        bone(a, "foot_" + side, hock, ball, "shin_" + side, connect=True, roll_up=False)
        bone(a, "toe_" + side, ball, rtoe, "foot_" + side, connect=True, roll_up=True)
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def bind(mesh, arm) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    groups = {g.name for g in mesh.vertex_groups}
    empty = []
    for b in arm.data.bones:
        if b.use_deform and b.name not in groups:
            empty.append(b.name)
    # Isı ağırlığının bulamadığı köşeler en yakın ağırlıklı köşenin ağırlığını alır (yoksa animasyonda yerinde kalır)
    vs = mesh.data.vertices
    weighted = [v.index for v in vs if any(g.weight > 1e-4 for g in v.groups)]
    unweighted = [v.index for v in vs if not any(g.weight > 1e-4 for g in v.groups)]
    if unweighted:
        W = np.array([vs[i].co[:] for i in weighted])
        for i in unweighted:
            j = weighted[int(np.argmin(np.linalg.norm(W - np.array(vs[i].co[:]), axis=1)))]
            for g in vs[j].groups:
                mesh.vertex_groups[g.group].add([i], g.weight, "REPLACE")
    log("ağırlık grupları", len(groups), "eksik kemik", empty, "ağırlıksız köşe (dolduruldu)", len(unweighted))


def _smooth(e0: float, e1: float, x: np.ndarray) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


## Kafa Meshy'de yana dönük (konsept 3/4 çizimdi). İSKELETTEN ÖNCE örgüde düzeltilir: dikey eksende, boyun kökünden
## başa doğru yumuşakça artan bir dönüş (göğüs altı ve bacaklar hiç dönmez). Otomatik ağırlıkla döndürmek boyun-göğüs
## geçişinde yırtık bırakıyordu (2026-10-31 denemesi). Eksen, döndükten sonra kafa merkezi orta hatta (x = 0) düşecek
## yerde seçilir.
def straighten_mesh(mesh, L) -> None:
    fwd = L["head_fwd"]
    ang = math.atan2(fwd.x * -1.0 - fwd.y * 0.0, fwd.dot(Vector((0, -1, 0))))   # fwd → (0, −1)
    log("kafa düzeltme açısı (derece)", round(math.degrees(ang), 1))
    if abs(ang) < math.radians(3):
        return
    hc = L["head_c"]
    y_root = -0.45
    V = verts(mesh)
    # Kafa kendi merkezi etrafında döner ve orta hatta kayar; boyun ikisini yumuşakça karıştırır
    t = _smooth(0.0, 0.30, y_root - V[:, 1]) * _smooth(0.45, 0.70, V[:, 2])
    a = ang * t
    dx, dy = V[:, 0] - hc.x, V[:, 1] - hc.y
    ca, sa = np.cos(a), np.sin(a)
    V[:, 0] = hc.x + ca * dx - sa * dy - t * hc.x
    V[:, 1] = hc.y + sa * dx + ca * dy
    mesh.data.vertices.foreach_set("co", V.ravel())
    mesh.data.update()
    log("kafa merkezi etrafında, kayma x=%.3f" % -hc.x)


## (Eski yol, kullanılmıyor) boyun + baş kemikle döndürülüp duruş "dinlenme" yapılır.
def straighten_head(mesh, arm, L) -> None:
    fwd = L["head_fwd"]
    target = Vector((0, -1, 0))
    ang = math.atan2(fwd.x * target.y - fwd.y * target.x, fwd.dot(target))
    log("kafa düzeltme açısı (derece)", round(math.degrees(ang), 1))
    if abs(ang) < math.radians(3):
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    bpy.ops.object.mode_set(mode="POSE")
    for name, share in (("neck", 0.45), ("head", 0.55)):
        pb = arm.pose.bones[name]
        bpy.context.view_layer.update()
        m = pb.matrix.copy()
        pivot = m.translation.copy()
        R = Matrix.Translation(pivot) @ Matrix.Rotation(ang * share, 4, "Z") @ Matrix.Translation(-pivot)
        pb.matrix = R @ m
        bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")
    # Örgüye uygula (ağırlıklar kalır), sonra duruşu dinlenme yap ve değiştiriciyi geri tak
    bpy.context.view_layer.objects.active = mesh
    mod = next(m for m in mesh.modifiers if m.type == "ARMATURE")
    bpy.ops.object.modifier_apply(modifier=mod.name)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="SELECT")
    bpy.ops.pose.armature_apply(selected=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm


def to_metres(mesh, arm) -> None:
    arm.scale = (S_METRE, S_METRE, S_METRE)
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    V = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
    log("metre boyut", tuple(np.round(V.max(0) - V.min(0), 3)), "üçgen ~", len(mesh.data.polygons))


# --- Kontrol görüntüsü ---------------------------------------------------------------------

def debug_render(mesh, arm, out: str, px: int = 640) -> None:
    scene = bpy.context.scene
    # Yarı saydam gövde
    for slot in mesh.material_slots:
        mat = slot.material
        bsdf = next((n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
        if bsdf:
            for link in list(bsdf.inputs["Alpha"].links):
                mat.node_tree.links.remove(link)
            bsdf.inputs["Alpha"].default_value = 0.28
        try:
            mat.surface_render_method = "BLENDED"
        except Exception:
            mat.blend_method = "BLEND"
    sticks = []
    deform_mat = bpy.data.materials.new("deform")
    deform_mat.use_nodes = True
    em = deform_mat.node_tree.nodes.new("ShaderNodeEmission")
    em.inputs[0].default_value = DEFORM_COLOR
    out_node = next(n for n in deform_mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    deform_mat.node_tree.links.new(em.outputs[0], out_node.inputs[0])
    joint_mat = bpy.data.materials.new("joint")
    joint_mat.use_nodes = True
    em2 = joint_mat.node_tree.nodes.new("ShaderNodeEmission")
    em2.inputs[0].default_value = (1.0, 0.85, 0.1, 1)
    out2 = next(n for n in joint_mat.node_tree.nodes if n.type == "OUTPUT_MATERIAL")
    joint_mat.node_tree.links.new(em2.outputs[0], out2.inputs[0])
    for b in arm.data.bones:
        if not b.use_deform:
            continue
        h = arm.matrix_world @ b.head_local
        t = arm.matrix_world @ b.tail_local
        d = t - h
        bpy.ops.mesh.primitive_cylinder_add(radius=0.004, depth=d.length, location=(h + t) / 2, vertices=6)
        c = bpy.context.active_object
        c.rotation_euler = d.to_track_quat("Z", "Y").to_euler()
        c.data.materials.append(deform_mat)
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.007, location=h, segments=8, ring_count=5)
        j = bpy.context.active_object
        j.data.materials.append(joint_mat)
        sticks += [c, j]
    V = np.array([(mesh.matrix_world @ v.co)[:] for v in mesh.data.vertices])
    lo, hi = Vector(V.min(0)), Vector(V.max(0))
    center = (lo + hi) / 2
    radius = max(hi - lo)
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.75, 0.76, 0.78, 1)
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = radius * 1.15
    scene.collection.objects.link(cam)
    scene.camera = cam
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    scene.render.resolution_x = px
    scene.render.resolution_y = px
    scene.view_settings.view_transform = "Standard"
    base, _ = os.path.splitext(out)
    shots = []
    for name, d in (("yan", Vector((1, 0, 0.05))), ("on", Vector((0, -1, 0.05))), ("ust", Vector((0.001, 0.0, 1))),
                    ("uc_ceyrek", Vector((0.8, -0.7, 0.45)))):
        d = d.normalized()
        cam.location = center + d * radius * 4
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        p = "%s_%s.png" % (base, name)
        scene.render.filepath = p
        bpy.ops.render.render(write_still=True)
        shots.append(p)
    buf = np.zeros((px * 2, px * 2, 4), dtype=np.float32)
    for i, p in enumerate(shots):
        im = bpy.data.images.load(p)
        a = np.array(im.pixels[:], dtype=np.float32).reshape(px, px, 4)
        r, c = 1 - i // 2, i % 2
        buf[r * px:(r + 1) * px, c * px:(c + 1) * px] = a
        os.remove(p)
    sheet = bpy.data.images.new("sheet", px * 2, px * 2)
    sheet.pixels = buf.ravel()
    sheet.filepath_raw = out
    sheet.file_format = "PNG"
    sheet.save()
    log("kontrol görüntüsü", out)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    src, out_blend = argv[0], argv[1]
    debug = argv[2] if len(argv) > 2 else ""
    mesh = import_cat(src)
    normalize(mesh)
    straighten_mesh(mesh, landmarks(mesh))
    L = landmarks(mesh)   # düz kafayla yeniden ölç
    arm = build_armature(mesh, L)
    bind(mesh, arm)
    to_metres(mesh, arm)
    bpy.ops.wm.save_as_mainfile(filepath=out_blend)
    log("kaydedildi", out_blend)
    if debug:
        debug_render(mesh, arm, debug)


main()
