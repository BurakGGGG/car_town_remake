"""TEKİR HAREKETLERİ (GARAJ DOSTLARI, 2026-10-31): tekir_rig.py'nin .blend'ine kontrol iskeleti kurar, hareket kliplerini
betikle anahtar karelere yazar, deform kemiklerine pişirir; önizleme videosu ve/veya oyun GLB'si çıkarır.

Kontrol iskeleti (dışa aktarılmaz): her ayakta yere basan bir `ctl_XX` (pençe ucunda, dik), onun çocuğu `tgt_XX` (bilek /
topuk; iki kemikli IK hedefi) ve arka ayakta `ball_XX` (tarak ucu). Ayak `ctl`'i yerde dururken gövde ilerler → kaymayan
basış. Yürüme YERİNDE yapılır; oyun kediyi WALK_SPEED ile ilerletir (kök hareketi yok).

  blender -b --factory-startup --python tools/pets/tekir_anim.py -- <rig.blend> <çıktı_klasörü> [klip,klip] [--glb yol.glb] [--preview]
"""
import bpy, sys, os, math, subprocess
from mathutils import Vector, Euler

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tekir_clips as TC   # noqa: E402

FPS = 30
LEGS = ("FL", "FR", "RL", "RR")
# Yürüme: bir döngüde gövdenin aldığı yol (m) ve döngü süresi. Oyun bunu kullanır: hız = STRIDE / (FRAMES / FPS).
WALK_STRIDE = 0.26
WALK_FRAMES = 30
WALK_DUTY = 0.62          # basma oranı (yavaş yürüyüşte > 0,5)
WALK_SPEED = WALK_STRIDE / (WALK_FRAMES / FPS)


def log(*a):
    print("RAPOR", *a)


def rad(d: float) -> float:
    return math.radians(d)


# --- Kontrol iskeleti ------------------------------------------------------------------------

def setup_controls(arm) -> None:
    bpy.context.view_layer.objects.active = arm
    for o in bpy.context.scene.objects:
        o.select_set(o == arm)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm.data.edit_bones
    for leg in LEGS:
        s = leg[1]
        if leg[0] == "F":
            tip, joint = eb["hand_" + s].tail.copy(), eb["forearm_" + s].tail.copy()
        else:
            tip, joint = eb["toe_" + s].tail.copy(), eb["shin_" + s].tail.copy()
        c = eb.new("ctl_" + leg)
        c.head, c.tail = tip, tip + Vector((0, 0, 0.04))
        c.align_roll(Vector((0, -1, 0)))   # yerel X = +X dünya, Y = yukarı, Z = ileri (−Y dünya)
        c.parent = eb["root"]
        c.use_deform = False
        t = eb.new("tgt_" + leg)
        t.head, t.tail = joint, joint + Vector((0, 0, 0.03))
        t.parent = c
        t.use_deform = False
        if leg[0] == "R":
            ball = eb["foot_" + s].tail.copy()
            b = eb.new("ball_" + leg)
            b.head, b.tail = ball, ball + Vector((0, 0, 0.02))
            b.parent = c
            b.use_deform = False
    bpy.ops.object.mode_set(mode="POSE")
    pbs = arm.pose.bones
    for leg in LEGS:
        s = leg[1]
        chain = "forearm_" + s if leg[0] == "F" else "shin_" + s
        ik = pbs[chain].constraints.new("IK")
        ik.target, ik.subtarget, ik.chain_count = arm, "tgt_" + leg, 2
        if leg[0] == "F":
            dt = pbs["hand_" + s].constraints.new("DAMPED_TRACK")
            dt.target, dt.subtarget = arm, "ctl_" + leg
        else:
            dt = pbs["foot_" + s].constraints.new("DAMPED_TRACK")
            dt.target, dt.subtarget = arm, "ball_" + leg
            dt2 = pbs["toe_" + s].constraints.new("DAMPED_TRACK")
            dt2.target, dt2.subtarget = arm, "ctl_" + leg
    for pb in pbs:
        pb.rotation_mode = "XYZ"
    bpy.ops.object.mode_set(mode="OBJECT")
    # Kontroller dinlenme duruşunu bozuyor mu? (IK / izleme hedefleri tam dinlenme yerinde)
    bpy.context.view_layer.update()
    worst = 0.0
    for pb in pbs:
        if pb.bone.use_deform:
            worst = max(worst, (pb.tail - pb.bone.tail_local).length)
    log("kontroller kuruldu, dinlenme sapması (m) %.5f" % worst)


def deform_bones(arm) -> list:
    return [pb for pb in arm.pose.bones if pb.bone.use_deform]


def clear_pose(arm) -> None:
    for pb in arm.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.scale = (1, 1, 1)


def key(pb, f: int, loc=None, rot=None) -> None:
    if loc is not None:
        pb.location = loc
        pb.keyframe_insert("location", frame=f)
    if rot is not None:
        pb.rotation_euler = rot
        pb.keyframe_insert("rotation_euler", frame=f)


## ctl kemiğine dünya ofseti (ileri = −Y dünya) → yerel konum (X, yukarı, ileri)
def paw_loc(dy_world: float, dz: float, dx: float = 0.0) -> Vector:
    return Vector((dx, dz, -dy_world))


# --- Klipler ---------------------------------------------------------------------------------

def clip_walk(arm) -> int:
    pbs = arm.pose.bones
    phase_off = {"RL": 0.0, "FL": 0.25, "RR": 0.5, "FR": 0.75}   # yanal sıralı kedi yürüyüşü
    lift = {"F": 0.034, "R": 0.03}
    push = {"F": 24.0, "R": 18.0}
    curl = {"F": 38.0, "R": 26.0}
    half = WALK_STRIDE * WALK_DUTY / 2
    n = WALK_FRAMES
    T = 2 * math.pi
    for f in range(n + 1):
        p = f / n
        for leg in LEGS:
            kind = leg[0]
            ph = (p - phase_off[leg]) % 1.0
            if ph < WALK_DUTY:
                u = ph / WALK_DUTY
                dy, dz = -half + 2 * half * u, 0.0
                r = push[kind] * ((u - 0.72) / 0.28) ** 2 if u > 0.72 else 0.0
            else:
                u = (ph - WALK_DUTY) / (1 - WALK_DUTY)
                e = 0.5 - 0.5 * math.cos(math.pi * u)
                dy = half - 2 * half * e
                dz = lift[kind] * math.sin(math.pi * u) ** 0.8
                r = (1 - u) * push[kind] + curl[kind] * math.sin(math.pi * u)
            key(pbs["ctl_" + leg], f, loc=paw_loc(dy, dz), rot=Euler((rad(r), 0, 0)))
        # Kürek kemiği ön bacakla salınır (adım uzar)
        for s, off in (("L", 0.25), ("R", 0.75)):
            ph = (p - off) % 1.0
            sw = math.cos(T * ph) * 7.0
            key(pbs["scapula_" + s], f, rot=Euler((rad(sw), 0, 0)))
        # Gövde: iki kez inip kalkar, kalça ve göğüs ters yönde yalpalar (S kıvrımı)
        bob = 0.0035 * math.cos(2 * T * p)
        key(pbs["hips"], f, loc=Vector((0, 0, bob)), rot=Euler((0, rad(3.0 * math.sin(T * p)), rad(3.5 * math.sin(T * p + 1.2)))))
        key(pbs["spine1"], f, rot=Euler((0, 0, rad(-1.5 * math.sin(T * p + 1.2)))))
        key(pbs["spine2"], f, rot=Euler((0, 0, rad(-1.5 * math.sin(T * p + 0.6)))))
        key(pbs["chest"], f, rot=Euler((0, rad(2.5 * math.sin(T * (p - 0.25))), rad(-2.0 * math.sin(T * p)))))
        # Baş: biraz alçak boyun, yüz düz; gövde yalpasını sönümler
        key(pbs["neck"], f, rot=Euler((rad(-7 + 1.2 * math.cos(2 * T * p)), 0, rad(1.5 * math.sin(T * p)))))
        key(pbs["head"], f, rot=Euler((rad(6 - 1.2 * math.cos(2 * T * p)), 0, rad(1.0 * math.sin(T * p)))))
        # Kuyruk havada, uca doğru kıvrık; dalga kökten uca ilerler
        lifts = [32, 8, 4, 0, -6, -14]
        for i in range(6):
            sway = 5.0 * math.sin(T * p - i * 0.55)
            key(pbs["tail%d" % (i + 1)], f, rot=Euler((rad(lifts[i]), 0, rad(sway))))
        for s, off in (("L", 0.0), ("R", 0.5)):
            key(pbs["ear_" + s], f, rot=Euler((rad(4 + 2 * math.sin(T * (p + off))), 0, 0)))
    return n


# --- Duruş kanallarını iskelete uygulama (tekir_clips.py biçimi) -------------------------------------

def _world_to_local(arm, bone: str, v) -> Vector:
    return arm.data.bones[bone].matrix_local.to_3x3().inverted() @ Vector(v)


def _leg_constraints(arm, leg: str) -> list:
    s = leg[1]
    names = ("upperarm_", "forearm_", "hand_") if leg[0] == "F" else ("thigh_", "shin_", "foot_", "toe_")
    out = []
    for n in names:
        out += list(arm.pose.bones[n + s].constraints)
    return out


def apply_pose(arm, p: dict, f=None) -> None:
    pbs = arm.pose.bones
    clear_pose(arm)
    infl = {leg: 1.0 for leg in LEGS}
    for c, v in p.items():
        if c == "hips_loc":
            pbs["hips"].location = pbs["hips"].location + _world_to_local(arm, "hips", v)
        elif c == "root_loc":
            pbs["root"].location = _world_to_local(arm, "root", v)
        elif c == "root_rot":
            pbs["root"].rotation_euler = Euler([rad(x) for x in v])
        elif c.startswith("paw_"):
            leg = c[4:]
            dy, dz, rx, dx, ry = v
            pb = pbs["ctl_" + leg]
            pb.location = _world_to_local(arm, "ctl_" + leg, (dx, dy, dz))   # dy + = geri = +Y dünya
            pb.rotation_euler = Euler((rad(rx), rad(ry), 0))
        elif c.startswith("ik_"):
            infl[c[3:]] = float(v)
        elif c.endswith("@loc"):
            pbs[c[:-4]].location = pbs[c[:-4]].location + Vector(v)
        elif c in pbs:
            pbs[c].rotation_euler = Euler([rad(x) for x in v])
    for leg, w in infl.items():
        for con in _leg_constraints(arm, leg):
            con.influence = w
            if f is not None:
                con.keyframe_insert("influence", frame=f)
    if f is not None:
        for pb in pbs:
            pb.keyframe_insert("location", frame=f)
            pb.keyframe_insert("rotation_euler", frame=f)


# --- Geometrik duruş çözücü (kıvrılma) -------------------------------------------------------------

SPINE = ["hips", "spine1", "spine2", "chest", "neck", "head"]
TAILB = ["tail%d" % i for i in range(1, 7)]


def _set_bone_frame(arm, name: str, head: Vector, tail_pt: Vector, up: Vector) -> None:
    from mathutils import Matrix
    pb = arm.pose.bones[name]
    y = (tail_pt - head).normalized()
    z = (up - y * up.dot(y)).normalized()
    x = y.cross(z)
    m = Matrix.Identity(4)
    for r in range(3):
        m[r][0], m[r][1], m[r][2], m[r][3] = x[r], y[r], z[r], head[r]
    pb.matrix = m
    bpy.context.view_layer.update()


def _arc_points(center, radius_fn, theta0: float, lengths: list, heights: list, sign: float = 1.0) -> list:
    """Çember yayında ardışık eklem noktaları: her adım kemik boyu kadar (düzlemde yaklaşık)."""
    pts = []
    s = 0.0
    for i in range(len(lengths) + 1):
        r = radius_fn(i / max(len(lengths), 1))
        th = theta0 + sign * s / r
        pts.append(Vector((center[0] + r * math.cos(th), center[1] + r * math.sin(th), heights[i])))
        if i < len(lengths):
            s += lengths[i]
    return pts


def solve_curl(arm, spec: dict) -> dict:
    """Omurgayı yerdeki çember yayına (SOLA kıvrık, karın içte), kuyruğu dışta geriye dolanan yaya yerleştirir;
    çıkan yerel dönüş / konumları duruş kanalı olarak döner (bacak / kulak kanalları spec["extra"]'dan)."""
    clear_pose(arm)
    for leg in LEGS:
        for con in _leg_constraints(arm, leg):
            con.influence = 0.0
    bpy.context.view_layer.update()
    bones = arm.data.bones
    C = spec["center"]
    R = spec["radius"]
    U = Vector((0, 0, 1))
    lengths = [bones[b].length for b in SPINE]
    pts = _arc_points(C, lambda u: R, math.radians(spec["theta0"]), lengths, spec["heights"], 1.0)
    for i, b in enumerate(SPINE):
        mid = (pts[i] + pts[i + 1]) / 2
        n_out = Vector((mid.x - C[0], mid.y - C[1], 0)).normalized()
        r = math.radians(spec["rolls"][i])
        _set_bone_frame(arm, b, pts[i], pts[i + 1], U * math.cos(r) + n_out * math.sin(r))
    # Kuyruk: kalçadan GERİYE (saat yönü), yarıçap büyüyerek dıştan dolanır, yere iner
    t_len = [bones[b].length for b in TAILB]
    t0 = bones["tail1"].head_local.copy()
    hip0 = arm.pose.bones["hips"].head.copy()
    tr0, tr1 = spec["tail_radius"]
    tpts = _arc_points(C, lambda u: tr0 + (tr1 - tr0) * u, math.radians(spec["theta0"]) - spec.get("tail_gap", 0.0),
                       t_len, spec["tail_heights"], -1.0)
    tpts[0] = arm.pose.bones["tail1"].head.copy()
    for i, b in enumerate(TAILB):
        _set_bone_frame(arm, b, tpts[i], tpts[i + 1], U)
    # Bacaklar: her eklem için yerde hedef (merkez etrafında açı°, yarıçap, yükseklik); kemik boyu korunur, kemik
    # dönüşü kendi güncel Z ekseni korunarak (burulmasız) hedefe çevrilir. IK yok → dirsek / diz zemine batmaz.
    leg_bones = {"FL": ["upperarm_L", "forearm_L", "hand_L"], "FR": ["upperarm_R", "forearm_R", "hand_R"],
                 "RL": ["thigh_L", "shin_L", "foot_L", "toe_L"], "RR": ["thigh_R", "shin_R", "foot_R", "toe_R"]}
    solved_legs = []
    for leg, joints in spec.get("legs", {}).items():
        names = leg_bones[leg]
        for i, b in enumerate(names):
            pb = arm.pose.bones[b]
            th, rr, zz = joints[i]
            a = math.radians(th)
            target = Vector((C[0] + rr * math.cos(a), C[1] + rr * math.sin(a), zz))
            # Yalnız SALINIM (burulmasız): kemiğin şu anki yönünden hedef yöne en kısa dönüş. Eskiden Z ekseni
            # korunarak kuruluyordu → yerel Euler ±170° çıkıyor, geçişte bacak kendi etrafında dönüyordu.
            from mathutils import Matrix
            head = pb.head.copy()
            m = pb.matrix.copy()
            q = m.to_3x3().col[1].normalized().rotation_difference((target - head).normalized())
            pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ m
            bpy.context.view_layer.update()
            solved_legs.append(b)
    out = {}
    for b in SPINE + TAILB + solved_legs:
        pb = arm.pose.bones[b]
        out[b] = tuple(math.degrees(a) for a in pb.rotation_euler)
    for leg in spec.get("legs", {}):
        out["ik_" + leg] = 0.0
    out["hips@loc"] = tuple(arm.pose.bones["hips"].location)
    out.update(spec.get("extra", {}))
    # Patiler: merkez etrafında kutupsal (açı°, yarıçap, yükseklik) hedef → IK (katlanış hedefe göre, zemine batmaz)
    for leg, (th, rr, zz) in spec.get("paws", {}).items():
        a = math.radians(th)
        target = Vector((C[0] + rr * math.cos(a), C[1] + rr * math.sin(a), zz))
        rest = arm.data.bones["ctl_" + leg].head_local
        d = target - rest
        out["ik_" + leg] = 1.0
        out["paw_" + leg] = (d.y, d.z, spec.get("paw_rx", {}).get(leg, 0.0), d.x, spec.get("paw_ry", {}).get(leg, 0.0))
    return out


def ik_to_fk(arm, pose: dict) -> dict:
    """IK bacaklı duruşun AYNI görünüşlü FK karşılığı (bacak kemiklerinin görünen dönüşü yerel kanala çevrilir).
    IK ↔ FK geçişleri bu duruş üzerinden yapılır: aradaki karışımda pati fırlamaz."""
    apply_pose(arm, pose)
    bpy.context.view_layer.update()
    out = dict(pose)
    leg_bones = {"FL": ("upperarm_L", "forearm_L", "hand_L"), "FR": ("upperarm_R", "forearm_R", "hand_R"),
                 "RL": ("thigh_L", "shin_L", "foot_L", "toe_L"), "RR": ("thigh_R", "shin_R", "foot_R", "toe_R")}
    mats = {}
    for leg, names in leg_bones.items():
        for b in names:
            mats[b] = arm.pose.bones[b].matrix.copy()
    # Kısıtları kapatıp sırayla (ebeveyn önce) aynı matrisi FK ile kur
    for leg in LEGS:
        for con in _leg_constraints(arm, leg):
            con.influence = 0.0
    for leg, names in leg_bones.items():
        for b in names:
            arm.pose.bones[b].matrix = mats[b]
            bpy.context.view_layer.update()
            out[b] = tuple(math.degrees(a) for a in arm.pose.bones[b].rotation_euler)
        out["ik_" + leg] = 0.0
    return out


def solve_tails(arm) -> None:
    """Kuyruğu yere değip gövdenin yanından öne sarılan duruşlar (TC.TAIL_SOLVED): her halka yerdeki yay noktasına
    burulmasız çevrilir. Aynı kuyruğu taşıyan türev duruşlar da güncellenir."""
    from mathutils import Matrix
    lengths = [arm.data.bones[b].length for b in TAILB]
    for name, spec in TC.TAIL_SOLVED.items():
        base = TC.POSES[name]
        orig = {t: base.get(t) for t in TC.TAIL}
        apply_pose(arm, base)
        bpy.context.view_layer.update()
        C = spec["center"]
        r0, r1 = spec["radius"]
        s_acc = 0.0
        new = {}
        for i, b in enumerate(TAILB):
            r = r0 + (r1 - r0) * i / (len(TAILB) - 1)
            th = math.radians(spec["theta0"]) + spec["sign"] * s_acc / r
            target = Vector((C[0] + r * math.cos(th), C[1] + r * math.sin(th), spec["heights"][i]))
            pb = arm.pose.bones[b]
            head = pb.head.copy()
            m = pb.matrix.copy()
            q = m.to_3x3().col[1].normalized().rotation_difference((target - head).normalized())
            pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ m
            bpy.context.view_layer.update()
            new[b] = tuple(math.degrees(a) for a in pb.rotation_euler)
            s_acc += lengths[i]
        patched = []
        for pname, pose in TC.POSES.items():
            if all(pose.get(t) == orig[t] for t in TC.TAIL):
                pose.update(new)
                patched.append(pname)
        log("kuyruk çözüldü", name, "→", patched)
    clear_pose(arm)


def _fabrik(pts: list, lengths: list, target: Vector, iters: int = 40) -> list:
    """Kök sabit zincir: uç hedefe, kemik boyları korunur; ilk tahminin büküm yönü korunmaya çalışılır."""
    root = pts[0].copy()
    pts = [p.copy() for p in pts]
    for _ in range(iters):
        pts[-1] = target.copy()
        for i in range(len(pts) - 2, -1, -1):
            pts[i] = pts[i + 1] + (pts[i] - pts[i + 1]).normalized() * lengths[i]
        pts[0] = root.copy()
        for i in range(1, len(pts)):
            pts[i] = pts[i - 1] + (pts[i] - pts[i - 1]).normalized() * lengths[i - 1]
    return pts


def solve_leg_targets(arm) -> None:
    """TC.LEG_SOLVED: duruşta bir bacağın ucu bir kemiğe göre hedefe (ör. kaşınırken arka ayak kulağın arkasına)."""
    from mathutils import Matrix
    names = {"RL": ["thigh_L", "shin_L", "foot_L", "toe_L"], "RR": ["thigh_R", "shin_R", "foot_R", "toe_R"],
             "FL": ["upperarm_L", "forearm_L", "hand_L"], "FR": ["upperarm_R", "forearm_R", "hand_R"]}
    for pname, legs in TC.LEG_SOLVED.items():
        pose = TC.POSES[pname]
        apply_pose(arm, pose)
        bpy.context.view_layer.update()
        for leg, spec in legs.items():
            bones = names[leg]
            pbs = [arm.pose.bones[b] for b in bones]
            anchor = arm.pose.bones[spec["to"]]
            target = anchor.head + Vector(spec["offset"])
            pts = [pbs[0].head.copy()]
            for d in spec["guess"]:
                pts.append(pts[-1] + Vector(d))
            lengths = [arm.data.bones[b].length for b in bones]
            reach = (target - pts[0]).length
            pts = _fabrik(pts, lengths, target)
            for i, pb in enumerate(pbs):
                head = pb.head.copy()
                m = pb.matrix.copy()
                q = m.to_3x3().col[1].normalized().rotation_difference((pts[i + 1] - head).normalized())
                pb.matrix = Matrix.Translation(head) @ q.to_matrix().to_4x4() @ Matrix.Translation(-head) @ m
                bpy.context.view_layer.update()
                pose[bones[i]] = tuple(math.degrees(a) for a in pb.rotation_euler)
            miss = (arm.pose.bones[bones[-1]].tail - target).length
            log("bacak hedefi", pname, leg, "uzaklık %.3f / boy %.3f, ıska %.3f" % (reach, sum(lengths), miss))
    clear_pose(arm)


def solve_poses(arm) -> None:
    solve_tails(arm)
    for name, src in TC.FK_TWINS.items():
        TC.POSES[name].clear()
        TC.POSES[name].update(ik_to_fk(arm, src))
        log("FK ikizi", name)
    solve_leg_targets(arm)
    for name, spec in TC.SOLVED.items():
        TC.POSES[name].clear()
        TC.POSES[name].update(solve_curl(arm, spec))
        big = {b: tuple(round(a) for a in v) for b, v in TC.POSES[name].items()
               if isinstance(v, tuple) and len(v) == 3 and max(abs(a) for a in v) > 100}
        log("çözüldü", name, "büyük açılar", big)
    clear_pose(arm)


def clip_from_spec(spec: dict):
    def run(arm) -> int:
        n = spec["frames"]
        for f in range(n + 1):
            p = TC.pose_at(spec["keys"], f)
            if spec.get("overlay"):
                TC.add(p, spec["overlay"](f, n))
            apply_pose(arm, p, f)
        return n
    return run


CLIPS = {"walk": clip_walk}
LOOPS = {"walk"}
for _name, _spec in TC.CLIPS.items():
    CLIPS[_name] = clip_from_spec(_spec)
    if _spec.get("loop"):
        LOOPS.add(_name)


# --- Pişirme ----------------------------------------------------------------------------------

def bake_clip(arm, name: str) -> bpy.types.Action:
    clear_pose(arm)
    # Bacak IK etkisi her klipte 1'den başlar: duruş çözücüler (solve_curl, ik_to_fk...) etkiyi 0'a çekip bırakıyordu;
    # etkiyi kendisi anahtarlamayan yordamsal YÜRÜME o artık değerle pişiyor, arka bacaklar adım atmıyordu (2026-10-31)
    for leg in LEGS:
        for con in _leg_constraints(arm, leg):
            con.influence = 1.0
    if arm.animation_data is None:
        arm.animation_data_create()
    src = bpy.data.actions.new(name + "_ctl")
    arm.animation_data.action = src
    end = CLIPS[name](arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    bpy.ops.pose.select_all(action="DESELECT")
    for pb in deform_bones(arm) + [arm.pose.bones["root"]]:
        pb.select = True
    bpy.ops.nla.bake(frame_start=0, frame_end=end, step=1, only_selected=True, visual_keying=True,
                     clear_constraints=False, clear_parents=False, use_current_action=False,
                     bake_types={"POSE"}, channel_types={"LOCATION", "ROTATION"})
    bpy.ops.object.mode_set(mode="OBJECT")
    baked = arm.animation_data.action
    baked.name = name
    baked.use_fake_user = True
    bpy.data.actions.remove(src)
    log("pişti", name, "kare", end, "eğri", sum(1 for _ in _fcurves(baked)))
    return baked


def _fcurves(action):
    if hasattr(action, "fcurves") and len(getattr(action, "fcurves", [])) > 0:
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out += list(bag.fcurves)
    return out


# --- Önizleme ---------------------------------------------------------------------------------

_STAGE = {}
PREVIEW_CAM = "uc_ceyrek"            # --cam ile değişir (uyku: oyun2 → yüz görünür)
PREVIEW_OFFSET = Vector((0, 0, 0))   # --center x,y ile kadraj kaydırma (kıvrılan klipler)


def stage() -> dict:
    """Önizleme sahnesi (bir kez): 5 cm damalı zemin, gök, güneş, iki ortografik kamera."""
    if _STAGE:
        return _STAGE
    scene = bpy.context.scene
    bpy.ops.mesh.primitive_plane_add(size=4, location=(0, 0, 0))
    ground = bpy.context.active_object
    gm = bpy.data.materials.new("zemin")
    gm.use_nodes = True
    nt = gm.node_tree
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 40.0
    chk.inputs["Color1"].default_value = (0.55, 0.56, 0.58, 1)
    chk.inputs["Color2"].default_value = (0.42, 0.43, 0.45, 1)
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    ground.data.materials.append(gm)
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs[0].default_value = (0.8, 0.82, 0.86, 1)
    bg.inputs[1].default_value = 0.7
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (rad(35), rad(10), rad(-35))
    scene.collection.objects.link(sun)
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        pass
    scene.render.resolution_x, scene.render.resolution_y = 640, 400
    try:
        scene.eevee.taa_render_samples = 6   # önizleme: hız > kalite
    except AttributeError:
        pass
    scene.view_settings.view_transform = "Standard"
    scene.render.fps = FPS
    cams = {}
    for cname, d, scale in (("yan", Vector((1, 0, 0.12)), 0.85), ("uc_ceyrek", Vector((0.9, -0.75, 0.5)), 0.9),
                            ("ust", Vector((0.001, 0.0, 1.0)), 0.6), ("oyun", Vector((0.64, -0.64, 0.42)), 0.6),
                            ("oyun2", Vector((-0.64, 0.64, 0.42)), 0.6), ("oyun3", Vector((-0.64, -0.64, 0.42)), 0.6),
                            ("oyun4", Vector((0.64, 0.64, 0.42)), 0.6)):
        cam = bpy.data.objects.new(cname, bpy.data.cameras.new(cname))
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = scale
        scene.collection.objects.link(cam)
        cams[cname] = (cam, d.normalized())
    _STAGE.update({"ground": ground, "sun": sun, "cams": cams})
    return _STAGE


def _shoot(out_dir: str, stem: str, center: Vector, only=None) -> None:
    scene = bpy.context.scene
    for cname, (cam, d) in stage()["cams"].items():
        if only and cname not in only:
            continue
        cam.location = center + d * 3
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        scene.camera = cam
        scene.render.filepath = os.path.join(out_dir, "%s_%s.png" % (stem, cname))
        bpy.ops.render.render(write_still=True)


def preview(arm, mesh, action, out_dir: str, name: str, moving: bool = False, fast: bool = False) -> None:
    scene = bpy.context.scene
    stage()
    arm.animation_data.action = action
    # Kontrol kısıtlarını kapat: pişmiş eylem deform kemiklerini zaten sürer
    for pb in arm.pose.bones:
        for c in pb.constraints:
            c.mute = True
    end = int(action.frame_range[1])
    frames = end * (2 if name in LOOPS and not fast else 1) + (0 if name in LOOPS else 1)
    if fast:   # tek kamera (3/4), küçük kare: bütün kliplerin toplu kontrolü
        scene.render.resolution_x, scene.render.resolution_y = 480, 300
    os.makedirs(out_dir, exist_ok=True)
    speed = WALK_SPEED if moving else 0.0
    for f in range(frames):
        scene.frame_set(f % end if name in LOOPS else f)
        y = -speed * f / FPS
        arm.location = (0, y, 0)
        _shoot(out_dir, "%s_%03d" % (name, f), Vector((0, y - 0.05, 0.18)) + PREVIEW_OFFSET,
               (PREVIEW_CAM,) if fast else ("yan", "uc_ceyrek"))
    arm.location = (0, 0, 0)
    for pb in arm.pose.bones:
        for c in pb.constraints:
            c.mute = False
    if fast:
        log("kareler", name, frames)
        return
    mp4 = os.path.join(out_dir, name + ".mp4")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS),
                    "-i", os.path.join(out_dir, name + "_%03d_yan.png"), "-framerate", str(FPS),
                    "-i", os.path.join(out_dir, name + "_%03d_uc_ceyrek.png"),
                    "-filter_complex", "[0:v][1:v]hstack=inputs=2,format=yuv420p", mp4], check=False)
    log("önizleme", mp4)


## Duruş sayfası: adlı duruşları (TC.POSES) canlı kısıtlarla, pişirmeden render alır (ayar turu hızlı olsun)
def use_texture(path: str) -> None:
    """Önizlemede gövde dokusunu değiştir (kapalı göz dokusuyla uyku duruşları)."""
    new = bpy.data.images.load(path)
    for mat in bpy.data.materials:
        if mat.node_tree:
            for n in mat.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image and n.image != new and n.image.size[0] >= 1024:
                    n.image = new


def pose_sheet(arm, names: list, out_dir: str) -> None:
    stage()
    os.makedirs(out_dir, exist_ok=True)
    if arm.animation_data:
        arm.animation_data.action = None
    mesh = bpy.data.objects["Tekir"]
    for n in names:
        apply_pose(arm, TC.POSES[n])
        bpy.context.view_layer.update()
        # Kadraj: değişmiş örgünün kutusunun ortası (kıvrılan duruşlar dinlenme yerinden kayar)
        me = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
        xs = [v.co for v in me.vertices]
        lo = Vector((min(c.x for c in xs), min(c.y for c in xs), min(c.z for c in xs)))
        hi = Vector((max(c.x for c in xs), max(c.y for c in xs), max(c.z for c in xs)))
        mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
        log("duruş kutusu", n, tuple(round(c, 3) for c in lo), tuple(round(c, 3) for c in hi))
        _shoot(out_dir, "poz_" + n, (lo + hi) / 2)
        log("duruş", n)


# --- Dışa aktarma -----------------------------------------------------------------------------

def export_glb(arm, mesh, path: str) -> None:
    # Kontrol kemikleri ve kısıtlar oyuna gitmez
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    for pb in arm.pose.bones:
        for c in list(pb.constraints):
            pb.constraints.remove(c)
    bpy.ops.object.mode_set(mode="EDIT")
    for b in list(arm.data.edit_bones):
        if b.name.startswith(("ctl_", "tgt_", "ball_")):
            arm.data.edit_bones.remove(b)
    bpy.ops.object.mode_set(mode="OBJECT")
    arm.animation_data.action = None
    clear_pose(arm)
    # Oyunda doku 1024² (paket boyutu kuralı); kapalı göz dokusu ayrı dosya olarak aynı boyda yazılır
    for img in bpy.data.images:
        if img.size[0] > 1024:
            img.scale(1024, 1024)
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    mesh.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, use_active_scene=True,
                              export_animations=True, export_animation_mode="ACTIONS", export_def_bones=False,
                              export_anim_single_armature=True, export_yup=True, export_apply=False,
                              export_image_format="JPEG", export_jpeg_quality=92)
    log("glb", path, os.path.getsize(path))


def main():
    argv = sys.argv[sys.argv.index("--") + 1:]
    blend, out_dir = argv[0], argv[1]
    names = [a for a in (argv[2].split(",") if len(argv) > 2 and not argv[2].startswith("--") else list(CLIPS))]
    glb = argv[argv.index("--glb") + 1] if "--glb" in argv else ""
    want_preview = "--preview" in argv
    bpy.ops.wm.open_mainfile(filepath=blend)
    # Kare hızı: klipler 30 kare/sn yazılır; sahne varsayılanı 24 kalırsa glTF'te süreler 1,25 kat uzuyordu (walk 1,25 sn)
    bpy.context.scene.render.fps = FPS
    bpy.context.scene.render.fps_base = 1.0
    arm = bpy.data.objects["TekirRig"]
    mesh = bpy.data.objects["Tekir"]
    setup_controls(arm)
    solve_poses(arm)
    global PREVIEW_CAM, PREVIEW_OFFSET
    if "--cam" in argv:
        PREVIEW_CAM = argv[argv.index("--cam") + 1]
    if "--center" in argv:
        cx, cy = (float(v) for v in argv[argv.index("--center") + 1].split(","))
        PREVIEW_OFFSET = Vector((cx, cy + 0.05, -0.08))
    if "--eyes" in argv:
        use_texture(argv[argv.index("--eyes") + 1])
    if "--poses" in argv:
        pose_sheet(arm, argv[argv.index("--poses") + 1].split(","), out_dir)
        return
    baked = {n: bake_clip(arm, n) for n in names}
    if want_preview:
        for n, a in baked.items():
            preview(arm, mesh, a, out_dir, n, moving=(n == "walk"), fast="--fast" in argv)
    if glb:
        export_glb(arm, mesh, glb)


main()
