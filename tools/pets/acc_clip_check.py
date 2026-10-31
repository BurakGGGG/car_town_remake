"""AKSESUAR GÖMÜLME ÖLÇÜMÜ (GARAJ DOSTLARI): oyundaki kedi (assets/pets/tekir.glb, bütün klipler) ve aksesuarlar
(assets/pets/acc/*.glb) Blender'da AYNI iskelete bağlanır; her klipte örneklenen karelerde aksesuar köşelerinin kedi
yüzeyine İŞARETLİ uzaklığı ölçülür (BVH en yakın nokta + yüz normali; eksi = kedinin İÇİNDE). Godot'un derisi de
doğrusal karışım (Blender Armature değiştiricisi, hacim koruma kapalı) olduğundan sonuç oyundakiyle aynıdır.

  blender -b --factory-startup --python tools/pets/acc_clip_check.py -- <proje_kökü> [rapor.json] [--render <klasör>]

Çıktı: aksesuar × klip için en derin gömülme (mm, model metresi) ve gömülen köşe oranı; --render ile her aksesuarın
en kötü karesi yakın plan PNG.
"""
import bpy, bmesh, sys, os, json, math
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ITEMS = ["collar_red", "bandana", "cap", "helmet"]
# Kaskta kulak teması sayılmaz (kulaklar deliklerden geçer)
STEP = 3            # her 3 karede bir
NEAR = 0.03         # bu kadar uzaktaki köşe ölçülmez (siperlik, bandana ucu)
INSIDE = -0.0005    # 0,5 mm'den derin = gömülü


def log(*a):
    print("RAPOR", *a)


RAYS = (Vector((0.31, 0.12, 0.94)).normalized(), Vector((-0.83, 0.47, 0.29)).normalized(),
        Vector((0.21, -0.95, -0.22)).normalized())


def is_inside(bvh, co: Vector) -> bool:
    """Işın sayımı: üç yönden en az ikisinde tek sayıda kesişme = kedinin içinde (normal yönüne güvenmez)."""
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


def penetration(bvh, verts, skip=None) -> tuple:
    """(en derin gömülme m, gömülen oranı, yakın köşe sayısı) — yalnız yüzeye NEAR'dan yakın köşeler.
    skip(loc, yüz) True dönen temas sayılmaz (kaskta kulak)."""
    depth, inside, near = 0.0, 0, 0
    for co in verts:
        loc, _nor, fi, dist = bvh.find_nearest(co, NEAR)
        if loc is None:
            continue
        if skip is not None and skip(loc, fi):
            continue
        near += 1
        if dist > 0.0005 and is_inside(bvh, co):
            inside += 1
            depth = max(depth, dist)
    return depth, inside / max(near, 1), near


def cat_bvh(cat, dg) -> tuple:
    """Değerlendirilmiş (pozlu) kedi ağından BVH. Yüz sırası cat.data ile aynı (kulak ağırlığı bakılabilsin);
    UV dikişlerinde ağ parçalı ama ışın sayımı birleştirilmiş ağla aynı sonucu veriyor (denendi)."""
    ce = cat.evaluated_get(dg)
    m = ce.to_mesh()
    verts = [cat.matrix_world @ v.co for v in m.vertices]
    bvh = BVHTree.FromPolygons(verts, [p.vertices[:] for p in m.polygons])
    ce.to_mesh_clear()
    return bvh, verts


def ear_lookup(cat):
    """Yüz → kulak üstünde mi (kaskta kulaklar deliklerden geçer; o temas sayılmaz)."""
    from mathutils.interpolate import poly_3d_calc
    ears = {g.index for g in cat.vertex_groups if g.name.startswith("ear")}
    w = [sum(g.weight for g in v.groups if g.group in ears) for v in cat.data.vertices]
    polys = [p.vertices[:] for p in cat.data.polygons]

    def on_ear(bvh_verts, loc, fi) -> bool:
        vs = polys[fi]
        bw = poly_3d_calc([bvh_verts[i] for i in vs], loc)
        return sum(w[i] * b for i, b in zip(vs, bw)) > 0.6
    return on_ear


def skinned_mesh(objs):
    """İçe aktarıcı kemik görüntüsü için "Icosphere" da ekliyor: Armature değiştiricili ağ seçilir."""
    return next(o for o in objs if o.type == "MESH" and any(m.type == "ARMATURE" for m in o.modifiers))


def import_glb(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    root = argv[0]
    report = argv[1] if len(argv) > 1 and not argv[1].startswith("--") else ""
    render_dir = argv[argv.index("--render") + 1] if "--render" in argv else ""
    bpy.ops.wm.read_factory_settings(use_empty=True)
    new = import_glb(os.path.join(root, "assets/pets/tekir.glb"))
    arm = next(o for o in new if o.type == "ARMATURE")
    cat = skinned_mesh(new)
    acts = sorted(bpy.data.actions, key=lambda a: a.name)
    accs = {}
    for name in ITEMS:
        objs = import_glb(os.path.join(root, "assets/pets/acc/%s.glb" % name))
        mesh = skinned_mesh(objs)
        mw = mesh.matrix_world.copy()
        mesh.parent = arm
        mesh.matrix_world = mw
        for m in mesh.modifiers:
            if m.type == "ARMATURE":
                m.object = arm
        for o in objs:
            if o != mesh:
                bpy.data.objects.remove(o)
        accs[name] = mesh
    scene = bpy.context.scene
    scene.render.fps = 30
    if arm.animation_data is None:
        arm.animation_data_create()
    # Dinlenme duruşu (klip yok): oturtma hatası mı, animasyon mu ayırt edilsin
    arm.animation_data.action = None
    for pb in arm.pose.bones:
        pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    dg = bpy.context.evaluated_depsgraph_get()
    on_ear = ear_lookup(cat)
    bvh0, cv0 = cat_bvh(cat, dg)
    for n, o in accs.items():
        om = o.evaluated_get(dg).to_mesh()
        sk = (lambda loc, fi: on_ear(cv0, loc, fi)) if n == "helmet" else None
        d, fr, near = penetration(bvh0, [o.matrix_world @ v.co for v in om.vertices], sk)
        o.evaluated_get(dg).to_mesh_clear()
        log("%-10s DİNLENME: en derin %.1f mm, gömülen %%%.1f (%d yakın köşe)" % (n, d * 1000, fr * 100, near))
    results = {n: {} for n in ITEMS}
    worst = {n: (0.0, None, 0) for n in ITEMS}
    for act in acts:
        arm.animation_data.action = act
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        f0, f1 = int(act.frame_range[0]), int(act.frame_range[1])
        per = {n: [0.0, 0.0, f0] for n in ITEMS}   # en derin, oran, en kötü kare
        for f in range(f0, f1 + 1, STEP):
            scene.frame_set(f)
            dg = bpy.context.evaluated_depsgraph_get()
            bvh, cv = cat_bvh(cat, dg)
            for n, o in accs.items():
                oe = o.evaluated_get(dg)
                om = oe.to_mesh()
                ow = o.matrix_world
                verts = [ow @ v.co for v in om.vertices]
                oe.to_mesh_clear()
                sk = (lambda loc, fi: on_ear(cv, loc, fi)) if n == "helmet" else None
                depth, frac, _near = penetration(bvh, verts, sk)
                if depth > per[n][0]:
                    per[n][0] = depth
                    per[n][2] = f
                per[n][1] = max(per[n][1], frac)
                if depth > worst[n][0]:
                    worst[n] = (depth, act.name, f)
        for n in ITEMS:
            results[n][act.name] = {"mm": round(per[n][0] * 1000, 1), "pct": round(per[n][1] * 100, 1), "frame": per[n][2]}
    for n in ITEMS:
        bad = sorted(results[n].items(), key=lambda kv: -kv[1]["mm"])
        log("%-10s en kötü: %s" % (n, ", ".join("%s %.1fmm %.0f%%" % (k, v["mm"], v["pct"]) for k, v in bad[:8])))
        tot = sum(1 for _k, v in bad if v["mm"] >= 1.0)
        log("%-10s ≥1 mm gömülen klip: %d / %d" % (n, tot, len(bad)))
    if report:
        json.dump({"results": results, "worst": {n: [w[0], w[1], w[2]] for n, w in worst.items()}},
                  open(report, "w"), indent=1, ensure_ascii=False)
    if render_dir:
        top = int(argv[argv.index("--top") + 1]) if "--top" in argv else 1
        shots = {}
        for n in ITEMS:
            bad = sorted(results[n].items(), key=lambda kv: -kv[1]["mm"])[:top]
            shots[n] = [(v["mm"] / -1000.0 * -1, k, v["frame"]) for k, v in bad if v["mm"] >= 1.0]
        render_worst(cat, arm, accs, shots, render_dir)


def render_worst(cat, arm, accs, worst, out):
    os.makedirs(out, exist_ok=True)
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    scene.render.resolution_x = scene.render.resolution_y = 420
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    next(n for n in world.node_tree.nodes if n.type == "BACKGROUND").inputs[0].default_value = (0.72, 0.73, 0.76, 1)
    scene.world = world
    sun = bpy.data.objects.new("S", bpy.data.lights.new("S", "SUN"))
    sun.data.energy = 3.2
    sun.rotation_euler = (math.radians(40), 0, math.radians(-30))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("C", bpy.data.cameras.new("C"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    for n, lst in worst.items():
      for depth, act_name, f in lst:
        if act_name is None:
            continue
        arm.animation_data.action = bpy.data.actions[act_name]
        act = bpy.data.actions[act_name]
        if hasattr(arm.animation_data, "action_slot") and act.slots:
            arm.animation_data.action_slot = act.slots[0]
        scene.frame_set(f)
        for o in accs.values():
            o.hide_render = o != accs[n]
        dg = bpy.context.evaluated_depsgraph_get()
        om = accs[n].evaluated_get(dg).to_mesh()
        V = np.array([(accs[n].matrix_world @ v.co)[:] for v in om.vertices])
        accs[n].evaluated_get(dg).to_mesh_clear()
        c = Vector(((V.min(0) + V.max(0)) / 2).tolist())
        cam.data.ortho_scale = float(np.ptp(V, axis=0).max()) * 2.2
        for tag, d in (("on", Vector((0.4, -1, 0.35))), ("yan", Vector((1, 0.1, 0.25))), ("alt", Vector((0.3, -0.6, -0.6)))):
            d = d.normalized()
            cam.location = c + d * 1.5
            cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
            scene.render.filepath = os.path.join(out, "%s_%s_%d_%s.png" % (n, act_name, f, tag))
            bpy.ops.render.render(write_still=True)
        log("kare", n, act_name, f, "%.1f mm" % (depth * 1000))


main()
