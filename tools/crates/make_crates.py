"""ARAÇ TESLİMAT KASALARI — Blender'da kurulur, assets/crates/<id>.glb yazılır.

Kullanım (başsız):
    blender --background --python tools/crates/make_crates.py
    blender --background --python tools/crates/make_crates.py -- --preview /tmp/onizleme   (PNG önizleme)

Model sözleşmesi (vehicles/crates.json _readme): orijin zeminde ve kasanın ortasında, uzun kenar +X,
dış ölçü world_size (0,72 × 0,38 × 0,46 DÜNYA BİRİMİ — 1 Blender birimi = 1 Godot birimi, ölçek
yok). Blender (x, y, z) → Godot (x, z, -y). Yükseklik Blender'da Z.
İçerik: "Lid" + dört menteşeli yan panel + "open" animasyonu (24 fps) + "VehicleAnchor" boş nesnesi.
Dokusuz, düz renkli materyaller (mobil: doku belleği yok).
"""
import bpy, math, os, sys
from mathutils import Vector

OUT = "/home/burak/Projects/car-town-remake/assets/crates"
SX, SY, SZ = 0.72, 0.46, 0.38      # Blender: uzunluk X, derinlik Y, yükseklik Z
PH = 0.04                           # palet yüksekliği
WT = 0.022                          # duvar kalınlığı
FPS = 24
_M = {}


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def mat(hexcol, rough=0.7, metal=0.0, emit=None, strength=3.0):
    key = (hexcol, rough, metal, emit)
    if key in _M:
        return _M[key]
    m = bpy.data.materials.new("M_%s_%d" % (hexcol.lstrip("#"), len(_M)))
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = srgb(hexcol)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        e = srgb(emit)
        b.inputs["Emission Color"].default_value = (e[0], e[1], e[2], 1.0)
        b.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    _M[key] = m
    return m


def new_obj(name, mesh=None):
    o = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(o)
    return o


def box(name, size, loc, m, parent=None, rot=(0, 0, 0), bevel=0.0):
    """Boyutu mesh'e gömülü kutu (nesne ölçeği 1 kalır)."""
    hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
    v = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
         (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
    f = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me = bpy.data.meshes.new(name)
    me.from_pydata(v, [], f)
    me.update()
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    o = new_obj(name, me)
    o.location = loc
    o.rotation_euler = rot
    if bevel > 0:
        bm = o.modifiers.new("bv", 'BEVEL')
        bm.width = bevel
        bm.segments = 1
    if parent:
        o.parent = parent
    return o


def cyl(name, r, h, loc, m, parent=None, rot=(0, 0, 0), verts=12):
    me = bpy.data.meshes.new(name)
    import bmesh
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=verts, radius1=r, radius2=r, depth=h)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(m)
    o = new_obj(name, me)
    o.location = loc
    o.rotation_euler = rot
    if parent:
        o.parent = parent
    return o


def empty(name, loc, parent=None):
    o = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if parent:
        o.parent = parent
    return o


class Panel:
    """Yan panel: menteşe alt kenarda. u = genişlik yönü, v = yükseklik, t = dışa doğru."""
    def __init__(self, root, side, w, h, body_m):
        self.side, self.w, self.h = side, w, h
        axis, sign = side            # 'y'/'x', +1/-1
        self.axis, self.sign = axis, sign
        if axis == 'y':
            loc = (0, sign * SY / 2, PH)
        else:
            loc = (sign * SX / 2, 0, PH)
        self.hinge = empty("Hinge_%s%s" % (axis, "p" if sign > 0 else "n"), loc, root)
        self.body = self.add(0, h / 2, w, h, WT, body_m, -WT / 2, "Panel")

    def add(self, u, v, w, h, d, m, t=0.0, name="d", rot=0.0, bevel=0.0):
        """u,v merkez; w×h yüz boyutu; d kalınlık; t = dışa kayma (yüzeye göre merkez)."""
        if self.axis == 'y':
            size, loc, r = (w, d, h), (u, self.sign * t, v), (0, rot, 0)   # yüz XZ'de, dönüş Y etrafında
        else:
            size, loc, r = (d, w, h), (self.sign * t, u, v), (rot, 0, 0)
        return box(name, size, loc, m, self.hinge, rot=r, bevel=bevel)


# --- Ortak iskelet ---------------------------------------------------------------------

def skeleton(cid, body_m, trim_m, lid_m, pallet_m):
    root = empty("Crate_" + cid, (0, 0, 0))
    box("Pallet", (SX + 0.03, SY + 0.03, PH), (0, 0, PH / 2), pallet_m, root)
    # pallet ayakları (altta oyuk görünümü)
    box("Floor", (SX - 0.02, SY - 0.02, 0.012), (0, 0, PH + 0.006), trim_m, root)
    wall_h = SZ - PH - 0.03
    panels = [
        Panel(root, ('y', 1), SX, wall_h, body_m),
        Panel(root, ('y', -1), SX, wall_h, body_m),
        Panel(root, ('x', 1), SY - WT * 2, wall_h, body_m),
        Panel(root, ('x', -1), SY - WT * 2, wall_h, body_m),
    ]
    lid = empty("Lid", (0, 0, SZ - 0.03), root)
    box("LidBoard", (SX + 0.03, SY + 0.03, 0.03), (0, 0, 0.015), lid_m, lid, bevel=0.004)
    # köşe dikmeleri kapağa bağlı
    for cx in (-1, 1):
        for cy in (-1, 1):
            box("Post", (0.04, 0.04, SZ - PH), (cx * (SX / 2 + 0.005), cy * (SY / 2 + 0.005), -(SZ - PH) / 2 + 0.03), trim_m, lid)
    empty("VehicleAnchor", (0, 0, PH), root)
    return root, panels, lid, wall_h


def animate(root, panels, lid):
    scn = bpy.context.scene
    scn.render.fps = FPS

    def key(o, frame, loc=None, rot=None, interp='BEZIER'):
        if loc is not None:
            o.location = loc
            o.keyframe_insert("location", frame=frame)
        if rot is not None:
            o.rotation_euler = rot
            o.keyframe_insert("rotation_euler", frame=frame)

    l0 = Vector(lid.location)
    key(lid, 1, l0, (0, 0, 0))
    key(lid, 6, l0 + Vector((0, 0, 0.16)), (0, 0, 0))
    key(lid, 14, l0 + Vector((-SX * 0.75, 0, -SZ + 0.02)), (0, math.radians(-30), 0))
    for p in panels:
        a, s = p.axis, p.sign
        r0 = (0, 0, 0)
        if a == 'y':
            r1 = (math.radians(-90 * s), 0, 0)
        else:
            r1 = (0, math.radians(90 * s), 0)
        key(p.hinge, 1, rot=r0)
        key(p.hinge, 14, rot=r0)
        key(p.hinge, 26, rot=r1)
    scn.frame_start, scn.frame_end = 1, 26
    # animasyonu tek "open" eylemine adlandır
    for o in (lid, *[p.hinge for p in panels]):
        if o.animation_data and o.animation_data.action:
            o.animation_data.action.name = "open_" + o.name
    return


# --- Beş tema --------------------------------------------------------------------------

def city():
    wood = mat("#C9A46A", 0.9)
    wood2 = mat("#B58F57", 0.9)
    dark = mat("#6B4B2A", 0.85)
    steel = mat("#5E656B", 0.45, 0.7)
    yel = mat("#E8B923", 0.6)
    blk = mat("#25272A", 0.7)
    root, panels, lid, wh = skeleton("city_crate", wood, dark, wood2, dark)
    for p in panels:
        n = 4
        for i in range(n):  # tahta ayrımları
            p.add(0, (i + 1) * wh / n, p.w - 0.01, 0.006, 0.004, dark, 0.0, "Gap")
        p.add(0, wh / 2, p.w - 0.02, 0.028, 0.004, dark, 0.012, "Brace", bevel=0.001)
        for u in (-1, 1):  # dikey çıtalar
            p.add(u * (p.w / 2 - 0.03), wh / 2, 0.035, wh, 0.012, dark, 0.008, "Rail")
        for u in (-1, 1):  # çelik köşe braketleri
            for v in (0.03, wh - 0.03):
                p.add(u * (p.w / 2 - 0.03), v, 0.05, 0.05, 0.006, steel, 0.015, "Bracket")
    for p in panels[:2]:   # sarı-siyah uyarı bandı + ok damgası
        for i in range(7):
            m = yel if i % 2 == 0 else blk
            p.add(-0.27 + i * 0.09, wh * 0.78, 0.05, 0.035, 0.004, m, 0.014, "Hazard", rot=0.0)
        p.add(0.0, wh * 0.38, 0.05, 0.12, 0.004, blk, 0.014, "ArrowStem")
        p.add(0.0, wh * 0.38 + 0.08, 0.07, 0.07, 0.004, blk, 0.014, "ArrowHead", rot=math.radians(45))
    box("LidStripe1", (0.07, SY + 0.034, 0.008), (-0.18, 0, 0.032), yel, lid)
    box("LidStripe2", (0.07, SY + 0.034, 0.008), (0.18, 0, 0.032), yel, lid)
    box("LidPlate", (0.17, 0.11, 0.008), (0, 0, 0.032), blk, lid)
    for px in (-0.06, 0.06):
        cyl("LidRivet", 0.008, 0.01, (px, 0, 0.038), steel, lid)
    return root, panels, lid


def family():
    blue = mat("#5F8FB0", 0.55, 0.2)
    rib = mat("#4F7C9C", 0.55, 0.2)
    white = mat("#ECF1F4", 0.5)
    navy = mat("#2D4B63", 0.6)
    steel = mat("#8E979D", 0.35, 0.8)
    orange = mat("#F0A33A", 0.55)
    root, panels, lid, wh = skeleton("family_crate", blue, navy, white, navy)
    for p in panels:
        cnt = int(p.w / 0.045)
        for i in range(cnt):  # oluklu sac
            p.add(-p.w / 2 + 0.03 + i * (p.w - 0.06) / (cnt - 1), wh / 2, 0.016, wh - 0.05, 0.008, rib, 0.012, "Corr")
        p.add(0, 0.015, p.w, 0.03, 0.01, navy, 0.011, "SkirtL")
        p.add(0, wh - 0.015, p.w, 0.03, 0.01, navy, 0.011, "SkirtU")
    for p in panels[:2]:   # beyaz kutu + ev amblemi
        p.add(0, wh / 2, 0.2, 0.17, 0.006, white, 0.02, "Badge")
        p.add(0, wh / 2 - 0.02, 0.09, 0.07, 0.006, orange, 0.025, "House")
        p.add(0, wh / 2 + 0.03, 0.085, 0.085, 0.006, orange, 0.025, "Roof", rot=math.radians(45))
        p.add(0, wh / 2 - 0.035, 0.025, 0.04, 0.006, white, 0.028, "Door")
    for p in panels[2:]:   # kilit kolları (konteyner)
        for u in (-0.07, 0.07):
            p.add(u, wh / 2, 0.012, wh - 0.06, 0.012, steel, 0.02, "Rod")
        p.add(0, wh / 2, 0.05, 0.03, 0.014, orange, 0.026, "Handle")
    box("LidRoofMid", (SX * 0.8, 0.06, 0.012), (0, 0, 0.034), steel, lid)
    for y in (-0.12, 0.12):
        box("LidRib", (SX * 0.9, 0.018, 0.01), (0, y, 0.034), navy, lid)
    box("LidHandle", (0.14, 0.02, 0.025), (0, 0, 0.04), steel, lid)
    return root, panels, lid


def sport():
    red = mat("#C4473A", 0.35, 0.1)
    white = mat("#F2F2F0", 0.4)
    carbon = mat("#1B1D20", 0.3, 0.3)
    blk = mat("#101113", 0.5)
    steel = mat("#9AA1A6", 0.3, 0.85)
    yel = mat("#FFCE3A", 0.4)
    root, panels, lid, wh = skeleton("sport_crate", red, blk, carbon, blk)
    for p in panels:
        for v in (0.016, wh - 0.016):
            p.add(0, v, p.w, 0.022, 0.01, blk, 0.011, "Edge")
    for p in panels[:2]:   # çift yarış şeridi + a-bölgesi damalı bayrak
        for u in (-0.04, 0.04):
            p.add(u + 0.21, wh / 2, 0.05, wh - 0.04, 0.005, white, 0.013, "Stripe")
        p.add(-0.2, wh * 0.32, 0.16, 0.07, 0.006, blk, 0.014, "FlagBase")
        for i in range(6):
            for j in range(2):
                if (i + j) % 2 == 0:
                    p.add(-0.2 - 0.065 + i * 0.026 + 0.013, wh * 0.32 - 0.017 + j * 0.034, 0.026, 0.034, 0.006, white, 0.0185, "Chk")
        for k in range(4):   # hava girişleri
            p.add(-0.2 - 0.045 + k * 0.03, wh * 0.68, 0.014, 0.05, 0.006, blk, 0.014, "Vent")
    for p in panels[2:]:
        p.add(0, wh / 2, p.w - 0.05, 0.05, 0.006, white, 0.013, "Stripe")
        p.add(0, wh / 2, 0.06, 0.06, 0.006, yel, 0.016, "Bolt", rot=math.radians(45))
    for y in (-0.03, 0.03):
        box("LidStripe", (SX * 0.95, 0.04, 0.006), (0, y, 0.032), red, lid)
    for i in range(5):   # kapakta havalandırma ızgarası
        box("LidVent", (0.012, 0.13, 0.008), (-0.26 + i * 0.03, 0.0, 0.034), steel, lid)
    box("LidSpoiler", (0.05, SY * 0.9, 0.025), (0.28, 0, 0.04), red, lid)
    return root, panels, lid


def prestige():
    body = mat("#252A33", 0.35, 0.35)
    gold = mat("#D4AF37", 0.28, 1.0)
    gold2 = mat("#E9CC72", 0.3, 1.0)
    cream = mat("#E8DFC8", 0.5)
    blk = mat("#14161A", 0.4, 0.2)
    root, panels, lid, wh = skeleton("prestige_crate", body, blk, body, blk)
    for p in panels:
        # altın çerçeve
        p.add(0, 0.022, p.w - 0.03, 0.012, 0.006, gold, 0.011, "FrameB")
        p.add(0, wh - 0.022, p.w - 0.03, 0.012, 0.006, gold, 0.011, "FrameT")
        for u in (-1, 1):
            p.add(u * (p.w / 2 - 0.022), wh / 2, 0.012, wh - 0.04, 0.006, gold, 0.011, "FrameS")
        for u in (-1, 1):   # altın köşe başlıkları
            for v in (0.03, wh - 0.03):
                p.add(u * (p.w / 2 - 0.03), v, 0.05, 0.05, 0.012, gold2, 0.014, "Cap", bevel=0.003)
    for p in panels[:2]:   # elmas amblem + ince çizgi
        p.add(0, wh / 2, 0.09, 0.09, 0.008, gold, 0.014, "Dia", rot=math.radians(45), bevel=0.002)
        p.add(0, wh / 2, 0.055, 0.055, 0.008, body, 0.017, "DiaIn", rot=math.radians(45))
        p.add(0, wh / 2, 0.022, 0.022, 0.008, gold2, 0.019, "DiaCore", rot=math.radians(45))
        for u in (-1, 1):
            p.add(u * 0.19, wh / 2, 0.16, 0.008, 0.006, gold, 0.012, "Line")
            p.add(u * 0.28, wh / 2, 0.012, 0.012, 0.006, gold, 0.012, "Dot", rot=math.radians(45))
    for p in panels[2:]:
        p.add(0, wh / 2, 0.06, 0.06, 0.008, gold, 0.014, "Dia", rot=math.radians(45), bevel=0.002)
    box("LidFrame", (SX * 0.86, SY * 0.8, 0.008), (0, 0, 0.033), gold, lid)
    box("LidInner", (SX * 0.82, SY * 0.74, 0.01), (0, 0, 0.034), body, lid)
    box("LidPlate", (0.2, 0.1, 0.012), (0, 0, 0.04), cream, lid, bevel=0.003)
    box("LidDia", (0.05, 0.05, 0.014), (0, 0, 0.046), gold, lid, rot=(0, 0, math.radians(45)))
    return root, panels, lid


def superc():
    gun = mat("#3A3F46", 0.3, 0.9)
    gold = mat("#E0A82E", 0.25, 1.0)
    gold2 = mat("#F6D56A", 0.25, 1.0)
    glow = mat("#FF8A1F", 0.5, 0.0, emit="#FF7A10", strength=4.0)
    glow2 = mat("#FFD86B", 0.5, 0.0, emit="#FFC13A", strength=5.0)
    blk = mat("#14161A", 0.4, 0.4)
    root, panels, lid, wh = skeleton("super_crate", gun, blk, gun, blk)
    for p in panels:
        # zırh plakaları + altın çerçeve + perçinler
        p.add(0, wh / 2, p.w - 0.05, wh - 0.05, 0.008, blk, 0.012, "Plate")
        for v in (0.012, wh - 0.012):
            p.add(0, v, p.w, 0.024, 0.012, gold, 0.012, "Rim", bevel=0.002)
        for u in (-1, 1):
            p.add(u * (p.w / 2 - 0.012), wh / 2, 0.024, wh, 0.012, gold, 0.012, "RimS", bevel=0.002)
            for v in (0.05, wh - 0.05):
                b = cyl("Bolt", 0.009, 0.01, (0, 0, 0), gold2, p.hinge, verts=8)
                if p.axis == 'y':
                    b.location = (u * (p.w / 2 - 0.04), p.sign * 0.014, v)
                    b.rotation_euler = (math.radians(90), 0, 0)
                else:
                    b.location = (p.sign * 0.014, u * (p.w / 2 - 0.04), v)
                    b.rotation_euler = (0, math.radians(90), 0)
    for p in panels[:2]:   # ışıldayan yıldız (iki dönük kare) + ışık çizgileri
        p.add(0, wh / 2, 0.1, 0.1, 0.01, glow, 0.016, "Star1", bevel=0.002)
        p.add(0, wh / 2, 0.1, 0.1, 0.01, glow, 0.016, "Star2", rot=math.radians(45), bevel=0.002)
        p.add(0, wh / 2, 0.04, 0.04, 0.012, glow2, 0.02, "StarCore", rot=math.radians(22))
        for u in (-1, 1):
            p.add(u * 0.23, wh / 2, 0.15, 0.012, 0.008, glow, 0.014, "Slit")
            p.add(u * 0.23, wh / 2 + 0.05, 0.1, 0.008, 0.008, glow, 0.014, "Slit2")
            p.add(u * 0.23, wh / 2 - 0.05, 0.1, 0.008, 0.008, glow, 0.014, "Slit3")
    for p in panels[2:]:
        p.add(0, wh / 2, 0.07, 0.07, 0.01, glow, 0.016, "Star1", bevel=0.002)
        p.add(0, wh / 2, 0.07, 0.07, 0.01, glow, 0.016, "Star2", rot=math.radians(45), bevel=0.002)
    box("LidRim", (SX * 0.9, SY * 0.86, 0.01), (0, 0, 0.034), gold, lid, bevel=0.002)
    box("LidIn", (SX * 0.84, SY * 0.78, 0.012), (0, 0, 0.036), blk, lid)
    box("LidStar1", (0.12, 0.12, 0.012), (0, 0, 0.042), glow, lid, bevel=0.002)
    box("LidStar2", (0.12, 0.12, 0.012), (0, 0, 0.042), glow, lid, rot=(0, 0, math.radians(45)), bevel=0.002)
    box("LidCore", (0.05, 0.05, 0.014), (0, 0, 0.046), glow2, lid, rot=(0, 0, math.radians(22)))
    for x in (-0.27, 0.27):
        box("LidBar", (0.1, 0.03, 0.01), (x, 0, 0.04), glow, lid)
    return root, panels, lid


BUILDERS = [("city_crate", city), ("family_crate", family), ("sport_crate", sport),
            ("prestige_crate", prestige), ("super_crate", superc)]


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _M.clear()


def export(cid):
    os.makedirs(OUT, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for o in bpy.context.scene.objects:
        o.select_set(True)
    kw = dict(filepath=os.path.join(OUT, cid + ".glb"), export_format='GLB', use_selection=True,
              export_animations=True, export_apply=True, export_yup=True,
              export_animation_mode='ACTIONS' if 'export_animation_mode' in
              bpy.ops.export_scene.gltf.get_rna_type().properties else 'ACTIONS')
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    kw = {k: v for k, v in kw.items() if k in props}
    if "use_active_scene" in props:
        kw["use_active_scene"] = True
    bpy.ops.export_scene.gltf(**kw)


def preview(cid, frame, path):
    scn = bpy.context.scene
    scn.frame_set(frame)
    cam = bpy.data.objects.get("Cam") or bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    if cam.name not in scn.collection.objects:
        scn.collection.objects.link(cam)
    cam.location = (0.75, -1.05, 0.75) if frame == 1 else (0.9, -1.25, 0.95)
    d = Vector((0, 0, 0.16)) - Vector(cam.location)
    cam.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()
    scn.camera = cam
    scn.render.resolution_x = scn.render.resolution_y = 512
    scn.render.filepath = path
    w = bpy.data.worlds.new("W")
    w.use_nodes = True
    next(n for n in w.node_tree.nodes if n.type == 'BACKGROUND').inputs[0].default_value = (0.55, 0.62, 0.7, 1)
    scn.world = w
    sun = bpy.data.objects.get("Sun") or bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", 'SUN'))
    if sun.name not in scn.collection.objects:
        scn.collection.objects.link(sun)
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    try:
        scn.render.engine = 'BLENDER_EEVEE'
    except TypeError:
        scn.render.engine = 'BLENDER_WORKBENCH'
    bpy.ops.render.render(write_still=True)


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    prev = argv[argv.index("--preview") + 1] if "--preview" in argv else None
    for cid, fn in BUILDERS:
        reset()
        root, panels, lid = fn()
        animate(root, panels, lid)
        bpy.context.scene.frame_set(1)
        export(cid)
        print("yazıldı:", cid)
        if prev:
            os.makedirs(prev, exist_ok=True)
            preview(cid, 1, os.path.join(prev, cid + "_closed.png"))
            preview(cid, 26, os.path.join(prev, cid + "_open.png"))


main()
