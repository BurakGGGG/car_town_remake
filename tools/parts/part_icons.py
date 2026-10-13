"""PERFORMANS PARÇA İKONLARI — her modifiye parçasının küçük 3D modeli, oyunun izometrik açısından render.
Garajın ARAÇLAR → MODİFİYE şeridindeki parça kartları bunları gösterir (ui/hud/art/parts/<id>.png).

Modeller tamamen prosedürel (temel geometri + bevel), oyunun low-poly diliyle: düz yüzeyler, az segment,
sıcak ışık, koyu mürekkep kontur (Freestyle). Arka plan şeffaf, 256×256.

Kullanım (ekransız):
    blender -b --factory-startup --python tools/parts/part_icons.py -- [çıktı klasörü] [id ...]
    # ya da bpy modülüyle:  python tools/parts/part_icons.py [çıktı klasörü] [id ...]
id verilmezse hepsi. Parça listesi: PARTS (id → model fonksiyonu); PerformanceMods.PART_ICONS aynı id'leri kullanır.
"""
import bpy, bmesh, math, os, sys
from mathutils import Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
PROJECT = os.path.dirname(os.path.dirname(HERE))
SIZE = 256
SAMPLES = 40


# --- Renk / materyal ------------------------------------------------------------------------------

def lin(hex_color):
    """sRGB hex → doğrusal RGBA."""
    h = hex_color.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255.0
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return (*out, 1.0)


_MATS = {}


def mat(name, color, metal=0.0, rough=0.5, emit=None, coat=0.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = lin(color) if isinstance(color, str) else color
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    if coat > 0.0:
        p.inputs["Coat Weight"].default_value = coat
    if emit:
        p.inputs["Emission Color"].default_value = lin(emit)
        p.inputs["Emission Strength"].default_value = 2.0
    _MATS[name] = m
    return m


def carbon():
    """Karbon örgü: koyu dama + parlak vernik."""
    if "carbon" in _MATS:
        return _MATS["carbon"]
    m = bpy.data.materials.new("carbon")
    m.use_nodes = True
    nt = m.node_tree
    p = nt.nodes["Principled BSDF"]
    checker = nt.nodes.new("ShaderNodeTexChecker")
    checker.inputs["Scale"].default_value = 18.0
    checker.inputs["Color1"].default_value = lin("1A1C20")
    checker.inputs["Color2"].default_value = lin("3A3E46")
    coord = nt.nodes.new("ShaderNodeTexCoord")
    nt.links.new(coord.outputs["Object"], checker.inputs["Vector"])
    nt.links.new(checker.outputs["Color"], p.inputs["Base Color"])
    p.inputs["Roughness"].default_value = 0.35
    p.inputs["Coat Weight"].default_value = 1.0
    p.inputs["Metallic"].default_value = 0.3
    _MATS["carbon"] = m
    return m


def M():
    """Ortak paletin materyalleri (oyunun sıcak tonları; HudPalette ile uyumlu)."""
    return {
        "steel": mat("steel", "A9AFB7", 1.0, 0.32),
        "dark": mat("dark", "3A3D42", 0.85, 0.42),
        "alu": mat("alu", "D5D9DE", 1.0, 0.22),
        "cast": mat("cast", "7E838A", 0.9, 0.55),
        "red": mat("red", "D2382B", 0.5, 0.3, coat=0.6),
        "blue": mat("blue", "2F6FE0", 0.6, 0.28, coat=0.6),
        "gold": mat("gold", "F5BE4C", 1.0, 0.25),
        "copper": mat("copper", "D97A45", 1.0, 0.3),
        "rubber": mat("rubber", "34363B", 0.0, 0.7),
        "pcb": mat("pcb", "1F8A4C", 0.1, 0.45),
        "chip": mat("chip", "26282C", 0.2, 0.35),
        "orange": mat("orange", "FF7A1A", 0.1, 0.4),
        "yellow": mat("yellow", "F5BE4C", 0.2, 0.35),
        "cream": mat("cream", "F3E8CF", 0.0, 0.6),
        "white": mat("white", "F2F2F2", 0.0, 0.5),
        "ti": mat("ti", "7A62C9", 1.0, 0.22),
        "ti2": mat("ti2", "2F8FD6", 1.0, 0.22),
        "frost": mat("frost", "BFE8FF", 0.0, 0.3, emit="7FD3F5"),
        "green": mat("green", "4FB477", 0.2, 0.35),
        "carbon": carbon(),
    }


# --- Geometri yardımcıları ------------------------------------------------------------------------

def _finish(o, material, smooth=True, bevel=0.0, seg=2):
    o.data.materials.append(material)
    if bevel > 0.0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = seg
        b.limit_method = "ANGLE"
    if smooth:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
        o.select_set(False)
    return o


def box(size, loc=(0, 0, 0), rot=(0, 0, 0), m=None, bevel=0.02):
    bpy.ops.mesh.primitive_cube_add(size=1, location=tuple(loc), rotation=[math.radians(a) for a in rot])
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, m, smooth=False, bevel=bevel)


def cyl(r, depth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, verts=24, bevel=0.01, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, vertices=verts, location=loc,
                                            rotation=[math.radians(a) for a in rot])
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r2, depth=depth, vertices=verts, location=loc,
                                        rotation=[math.radians(a) for a in rot])
    return _finish(bpy.context.object, m, bevel=bevel)


def torus(major, minor, loc=(0, 0, 0), rot=(0, 0, 0), m=None, seg=32, mseg=12):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=seg,
                                     minor_segments=mseg, location=loc, rotation=[math.radians(a) for a in rot])
    return _finish(bpy.context.object, m)


def sphere(r, loc=(0, 0, 0), m=None, seg=16, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, segments=seg, ring_count=seg // 2, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, m)


def pipe(points, r, m=None, res=10):
    """Noktalardan boru (bezier eğri + kalınlık), mesh'e çevrilir."""
    cu = bpy.data.curves.new("pipe", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(points) - 1)
    for bp, p in zip(sp.bezier_points, points):
        bp.co = p
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    sp.resolution_u = res
    o = bpy.data.objects.new("pipe", cu)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o = bpy.context.object
    o.select_set(False)
    return _finish(o, m)


def gear(r, depth, teeth, loc=(0, 0, 0), rot=(0, 0, 0), m=None, tooth=0.08, hole=0.0):
    """Dişli: silindir + dişler (tek mesh değil, nesne grubu)."""
    parts = [cyl(r, depth, loc, rot, m, verts=max(teeth * 2, 24))]
    e = Euler([math.radians(a) for a in rot])
    for i in range(teeth):
        a = 2 * math.pi * i / teeth
        local = Vector((math.cos(a) * (r + tooth * 0.45), math.sin(a) * (r + tooth * 0.45), 0))
        local.rotate(e)
        t = box((tooth, tooth * 0.9, depth * 0.98), loc=Vector(loc) + local, m=m, bevel=0.004)
        t.rotation_euler = e
        t.rotation_euler.rotate_axis("Z", a)
        parts.append(t)
    if hole > 0:
        parts.append(cyl(hole, depth * 1.05, loc, rot, M()["dark"], verts=16))
    return parts


def ring_of(count, radius, make, z=0.0):
    out = []
    for i in range(count):
        a = 2 * math.pi * i / count
        out.append(make(Vector((math.cos(a) * radius, math.sin(a) * radius, z)), a))
    return out


# --- Parçalar: MOTOR ---------------------------------------------------------------------------------

def ecu(accent="green"):
    m = M()
    box((1.2, 0.8, 0.24), (0, 0, 0.12), m=m["alu"], bevel=0.04)
    for i in range(5):   # soğutma kanatçıkları (sol yarı)
        box((0.06, 0.72, 0.1), (-0.5 + i * 0.12, 0, 0.29), m=m["alu"], bevel=0.01)
    box((0.48, 0.6, 0.04), (0.28, 0.0, 0.26), m=m["pcb" if accent == "green" else "blue"], bevel=0.005)
    box((0.2, 0.2, 0.06), (0.28, 0.08, 0.3), m=m["chip"], bevel=0.005)
    for i in range(3):
        box((0.06, 0.1, 0.04), (0.14 + i * 0.12, -0.18, 0.3), m=m["gold"], bevel=0.0)
    box((0.22, 0.42, 0.18), (0.71, 0.0, 0.13), m=m["dark"], bevel=0.02)   # soket
    pipe([(0.82, 0.05, 0.13), (1.05, 0.2, 0.1), (1.2, 0.5, 0.05)], 0.05, m["orange" if accent == "blue" else "rubber"])
    if accent == "blue":   # elektrik: şimşek işareti
        bolt(m["yellow"], (0.28, -0.05, 0.36), 0.32)


def bolt(material, loc, s):
    """Şimşek (düz prizma)."""
    pts = [(-0.1, 0.5), (0.25, 0.5), (0.05, 0.1), (0.3, 0.1), (-0.15, -0.55), (0.0, -0.05), (-0.25, -0.05)]
    me = bpy.data.meshes.new("bolt")
    bm = bmesh.new()
    vs = [bm.verts.new((x * s, y * s, 0)) for x, y in pts]
    f = bm.faces.new(vs)
    ext = bmesh.ops.extrude_face_region(bm, geom=[f])
    for v in [e for e in ext["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co.z += 0.06 * s * 2
    bm.to_mesh(me)
    o = bpy.data.objects.new("bolt", me)
    bpy.context.collection.objects.link(o)
    o.location = loc
    return _finish(o, material, smooth=False)


def camshaft():
    m = M()
    cyl(0.07, 2.2, rot=(0, 90, 0), m=m["steel"], verts=16)
    for i in range(8):
        x = -0.9 + i * 0.26
        a = i * 90
        o = cyl(0.17, 0.09, (x, 0, 0), (0, 90, 0), m["steel"], verts=20)
        o.scale = (1, 1.35, 1)   # yumurta lob
        o.rotation_euler.rotate_axis("X", math.radians(a))
        o.location += Vector((0, math.cos(math.radians(a)) * 0.04, math.sin(math.radians(a)) * 0.04))
    for x in (-1.0, 1.0):
        cyl(0.12, 0.08, (x, 0, 0), (0, 90, 0), m["alu"])
    gear(0.32, 0.07, 22, (-1.15, 0, 0), (0, 90, 0), m["gold"], tooth=0.06)


def piston():
    m = M()
    cyl(0.5, 0.62, (0, 0, 0.6), m=m["alu"], verts=32, bevel=0.03)
    for z in (0.78, 0.7, 0.62):
        cyl(0.505, 0.03, (0, 0, z), m=m["dark"], verts=32, bevel=0)
    cyl(0.12, 0.9, (0, 0, 0.42), (90, 0, 0), m["steel"], verts=16)   # pim
    box((0.18, 0.12, 1.0), (0, 0, -0.05), m=m["steel"], bevel=0.03)   # biyel
    torus(0.24, 0.07, (0, 0, -0.62), (90, 0, 0), m["steel"], seg=24, mseg=8)
    cyl(0.18, 0.13, (0, 0, -0.62), (90, 0, 0), m["dark"], verts=20)


def crankshaft():
    m = M()
    for i in range(5):
        cyl(0.11, 0.22, (-1.0 + i * 0.5, 0, 0), (0, 90, 0), m["steel"], verts=16)
    for i in range(4):
        x = -0.75 + i * 0.5
        up = 1 if i in (0, 3) else -1
        for dx in (-0.13, 0.13):
            box((0.08, 0.36, 0.6), (x + dx, 0, up * 0.12), m=m["cast"], bevel=0.04)
        cyl(0.1, 0.2, (x, 0, up * 0.26), (0, 90, 0), m["alu"], verts=16)
        box((0.26, 0.42, 0.18), (x, 0, -up * 0.24), m=m["cast"], bevel=0.05)   # karşı ağırlık
    cyl(0.28, 0.08, (1.25, 0, 0), (0, 90, 0), m["dark"], verts=24)


def engine_block(color="red"):
    m = M()
    box((1.6, 0.9, 0.9), (0, 0, 0.45), m=m["cast"], bevel=0.05)
    box((1.55, 0.7, 0.22), (0, 0, 1.0), m=m[color], bevel=0.06)   # külbütör kapağı
    for i in range(4):
        cyl(0.07, 0.1, (-0.5 + i * 0.33, 0.0, 1.13), m=m["dark"], verts=12)
    for i in range(4):   # emme ağızları
        pipe([(-0.5 + i * 0.33, 0.45, 0.75), (-0.5 + i * 0.33, 0.75, 0.85), (-0.5 + i * 0.33, 0.9, 1.1)], 0.07, m["alu"])
    box((1.6, 0.25, 0.3), (0, 1.0, 1.15), m=m["alu"], bevel=0.04)   # plenum
    cyl(0.3, 0.12, (-0.9, -0.1, 0.4), (0, 90, 0), m["dark"], verts=24)   # kasnak


def turbo(scale=1.0, accent="alu", loc=(0, 0, 0)):
    m = M()
    x0, y0, z0 = loc
    s = scale
    # Kompresör salyangozu (alüminyum) + türbin salyangozu (dökme)
    cyl(0.55 * s, 0.42 * s, (x0 - 0.35 * s, y0, z0), (0, 90, 0), m[accent], verts=28, bevel=0.06)
    torus(0.5 * s, 0.16 * s, (x0 - 0.35 * s, y0, z0), (0, 90, 0), m[accent], seg=28, mseg=10)
    cyl(0.25 * s, 0.4 * s, (x0 - 0.75 * s, y0, z0), (0, 90, 0), m[accent], verts=24)   # giriş ağzı
    cyl(0.2 * s, 0.42 * s, (x0 - 0.76 * s, y0, z0), (0, 90, 0), m["dark"], verts=24)
    cyl(0.22 * s, 0.3 * s, (x0, y0, z0), (0, 90, 0), m["steel"], verts=20)   # gövde
    cyl(0.5 * s, 0.38 * s, (x0 + 0.38 * s, y0, z0), (0, 90, 0), m["cast"], verts=28, bevel=0.06)
    torus(0.46 * s, 0.15 * s, (x0 + 0.38 * s, y0, z0), (0, 90, 0), m["cast"], seg=28, mseg=10)
    pipe([(x0 - 0.35 * s, y0 + 0.5 * s, z0 + 0.25 * s), (x0 - 0.35 * s, y0 + 0.9 * s, z0 + 0.35 * s)], 0.17 * s, m[accent])
    box((0.5 * s, 0.12 * s, 0.5 * s), (x0 + 0.38 * s, y0 - 0.55 * s, z0 - 0.15 * s), m=m["cast"], bevel=0.02)   # flanş


def intercooler():
    m = M()
    box((1.9, 0.18, 0.9), (0, 0, 0.45), m=m["alu"], bevel=0.01)
    for i in range(14):
        box((1.86, 0.2, 0.025), (0, 0.0, 0.08 + i * 0.058), m=m["steel"], bevel=0)
    for x in (-1.05, 1.05):
        box((0.22, 0.26, 1.0), (x, 0, 0.45), m=m["alu"], bevel=0.05)
        pipe([(x, 0, 0.8), (x * 1.05, -0.35, 0.95), (x * 1.0, -0.6, 0.95)], 0.1, m["alu"])


def turbine_wheel():
    m = M()
    cyl(0.62, 0.12, m=m["steel"], verts=36, bevel=0.03)
    cyl(0.16, 0.5, (0, 0, 0.2), m=m["alu"], verts=20, r2=0.08)
    for i in range(11):
        a = 2 * math.pi * i / 11
        bl = box((0.5, 0.04, 0.32), (math.cos(a) * 0.32, math.sin(a) * 0.32, 0.2), m=m["alu"], bevel=0.01)
        bl.rotation_euler = (0, math.radians(18), a)
    cyl(0.12, 0.9, (0, 0, -0.4), m=m["steel"], verts=16)


def twin_turbo():
    turbo(0.8, "blue", (0, -0.62, 0))
    turbo(0.8, "blue", (0, 0.62, 0))


# --- HAVA AKIŞI --------------------------------------------------------------------------------------

def cone_filter(color="red"):
    m = M()
    o = cyl(0.55, 1.1, (0.2, 0, 0), (0, 90, 0), m[color], verts=28, r2=0.38, bevel=0.0)
    o.modifiers.new("w", "WIREFRAME")  # pileli görünüm için alttaki koyu çekirdek
    o.modifiers["w"].thickness = 0.04
    cyl(0.5, 1.05, (0.2, 0, 0), (0, 90, 0), m["dark"], verts=28, r2=0.34)
    cyl(0.4, 0.06, (0.78, 0, 0), (0, 90, 0), m["alu"], verts=28)
    cyl(0.57, 0.1, (-0.38, 0, 0), (0, 90, 0), m["alu"], verts=28)
    cyl(0.3, 0.5, (-0.65, 0, 0), (0, 90, 0), m["rubber"], verts=24)


def cold_air():
    m = M()
    pipe([(-1.0, 0, 0), (-0.3, 0.1, 0.0), (0.2, 0.5, 0.35), (0.6, 0.9, 0.4)], 0.2, m["blue"])
    cyl(0.25, 0.25, (-1.05, 0, 0), (0, 90, 0), m["rubber"], verts=24)
    o = cyl(0.42, 0.8, (0.85, 1.25, 0.4), (90, 0, -35), m["red"], verts=24, r2=0.3)
    cyl(0.32, 0.05, (1.05, 1.55, 0.4), (90, 0, -35), m["alu"], verts=24)


def downpipe():
    m = M()
    pipe([(0, 0, 0.9), (0.1, 0, 0.3), (0.5, 0, -0.15), (1.2, 0, -0.25)], 0.17, m["steel"])
    cyl(0.32, 0.06, (0, 0, 0.95), m=m["steel"], verts=6)   # flanş (altıgen)
    cyl(0.26, 0.06, (1.25, 0, -0.25), (0, 90, 0), m["steel"], verts=24)
    cyl(0.22, 0.4, (0.55, 0, -0.17), (0, 90, 0), m["alu"], verts=20)   # esnek bölüm
    for i in range(5):
        torus(0.22, 0.025, (0.4 + i * 0.075, 0, -0.17), (0, 90, 0), m["alu"], seg=20, mseg=6)


def header(material="steel"):
    m = M()
    box((1.6, 0.12, 0.42), (0, 0, 0.9), m=m[material], bevel=0.02)   # silindir kafası flanşı
    for i in range(4):
        x = -0.6 + i * 0.4
        pipe([(x, 0.06, 0.9), (x, 0.4, 0.75), (x * 0.4, 0.55, 0.25), (0, 0.55, -0.15)], 0.09, m[material])
    cyl(0.17, 0.5, (0, 0.55, -0.35), m=m[material], verts=20)


def race_exhaust():
    m = M()
    cyl(0.4, 1.3, (0, 0, 0), (0, 90, 0), m["ti"], verts=28, bevel=0.05)
    cyl(0.42, 0.08, (-0.62, 0, 0), (0, 90, 0), m["carbon"], verts=28)
    cyl(0.42, 0.08, (0.62, 0, 0), (0, 90, 0), m["carbon"], verts=28)
    cyl(0.17, 0.55, (0.9, 0, 0), (0, 90, 0), m["ti2"], verts=24, r2=0.22)   # uç
    cyl(0.15, 0.56, (0.9, 0, 0), (0, 90, 0), m["dark"], verts=24, r2=0.2)
    pipe([(-0.65, 0, 0), (-1.1, 0, 0.1), (-1.4, 0, 0.4)], 0.13, m["ti"])


# --- ŞANZIMAN ----------------------------------------------------------------------------------------

def shifter():
    m = M()
    box((0.9, 0.9, 0.12), (0, 0, 0.06), m=m["alu"], bevel=0.03)
    cyl(0.32, 0.35, (0, 0, 0.3), m=m["rubber"], verts=20, r2=0.12)   # körük
    cyl(0.04, 0.85, (0.05, 0, 0.8), (0, 12, 0), m["steel"], verts=12)
    sphere(0.17, (0.14, 0, 1.25), m["dark"], seg=20)
    cyl(0.1, 0.02, (0.14, 0, 1.4), m=m["yellow"], verts=20)
    for x, y in ((-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)):
        cyl(0.04, 0.05, (x, y, 0.13), m=m["dark"], verts=8)


def clutch_disc():
    m = M()
    cyl(0.85, 0.06, m=m["steel"], verts=40, bevel=0.01)
    for i in range(6):   # sürtünme pabuçları
        a = 2 * math.pi * i / 6
        p = box((0.32, 0.26, 0.1), (math.cos(a) * 0.67, math.sin(a) * 0.67, 0), m=m["orange"], bevel=0.02)
        p.rotation_euler = (0, 0, a)
    cyl(0.3, 0.12, m=m["dark"], verts=24)
    for i in range(4):   # yaylar
        a = 2 * math.pi * i / 4 + 0.4
        torus(0.06, 0.025, (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.06), (0, 90, math.degrees(a)), m["red"], seg=12, mseg=6)
    gear(0.11, 0.16, 14, m=m["steel"], tooth=0.035)


def flywheel(material="alu"):
    m = M()
    gear(0.9, 0.12, 40, m=m["steel"], tooth=0.06)
    cyl(0.86, 0.14, m=m[material], verts=40, bevel=0.02)
    for i in range(6):   # hafifletme delikleri
        a = 2 * math.pi * i / 6
        cyl(0.13, 0.16, (math.cos(a) * 0.52, math.sin(a) * 0.52, 0), m=m["dark"], verts=16)
    cyl(0.2, 0.18, m=m["dark"], verts=20)
    for i in range(6):
        a = 2 * math.pi * i / 6 + 0.5
        cyl(0.035, 0.2, (math.cos(a) * 0.28, math.sin(a) * 0.28, 0), m=m["gold"], verts=6)


def gear_set():
    m = M()
    gear(0.6, 0.25, 26, (-0.38, 0, 0), m=m["steel"], tooth=0.09, hole=0.15)
    gear(0.38, 0.25, 17, (0.62, 0.02, 0), m=m["gold"], tooth=0.09, hole=0.1)
    cyl(0.08, 1.0, (-0.38, 0, 0), m=m["dark"], verts=12)
    cyl(0.06, 1.0, (0.62, 0.02, 0), m=m["dark"], verts=12)


def sequential_box():
    m = M()
    box((1.3, 0.8, 0.75), (0, 0, 0.38), m=m["cast"], bevel=0.08)
    cyl(0.55, 0.3, (-0.75, 0, 0.42), (0, 90, 0), m["cast"], verts=28, r2=0.42)   # çan
    for i in range(3):
        box((0.06, 0.82, 0.5), (-0.3 + i * 0.3, 0, 0.42), m=m["alu"], bevel=0.01)
    cyl(0.04, 0.9, (0.25, 0, 1.1), (0, -18, 0), m["steel"], verts=12)   # sıralı kol
    box((0.14, 0.14, 0.28), (0.4, 0, 1.55), m=m["red"], bevel=0.04)
    box((0.3, 0.2, 0.12), (0.2, 0, 0.8), m=m["dark"], bevel=0.02)


# --- LASTİK & JANT -----------------------------------------------------------------------------------

def tire(width=0.45, radius=0.95, slick=False, side=False):
    """Lastik: yan yüzü kameraya (-Y) dönük, kenarları yuvarlatılmış silindir; dişli lastikte çevresel oluklar."""
    m = M()
    o = cyl(radius, width, rot=(90, 0, 0), m=m["rubber"], verts=48, bevel=0.0)
    b = o.modifiers.new("round", "BEVEL")
    b.width = min(0.16, width * 0.3)
    b.segments = 4
    b.limit_method = "ANGLE"
    if not slick:
        for k in range(3):
            y = (k - 1) * width * 0.28
            torus(radius + 0.005, 0.025, (0, y, 0), (90, 0, 0), m["dark"], seg=48, mseg=6)
        for i in range(24):   # enine dişler (yalnızca sırtta)
            a = 2 * math.pi * i / 24
            t = box((0.05, width * 0.7, 0.03), (math.cos(a) * (radius + 0.005), 0, math.sin(a) * (radius + 0.005)),
                    m=m["dark"], bevel=0.0)
            t.rotation_euler = (0, math.pi / 2 - a, 0)
    if side:   # yan yazı bandı
        torus(radius - 0.2, 0.014, (0, -width / 2 - 0.005, 0), (90, 0, 0), m["yellow"], seg=48, mseg=4)
    else:   # yanak çizgisi
        torus(radius - 0.12, 0.01, (0, -width / 2 - 0.005, 0), (90, 0, 0), m["cast"], seg=48, mseg=4)
    cyl(radius * 0.62, width * 1.01, rot=(90, 0, 0), m=m["dark"], verts=40)
    return o


def wheel(spokes=5, rim="alu", width=0.45, slick=False, side=False):
    m = M()
    tire(width, 0.95, slick, side)
    face_y = -width * 0.5
    torus(0.6, 0.045, (0, face_y - 0.01, 0), (90, 0, 0), m["gold" if rim == "carbon" else rim], seg=40, mseg=8)   # jant dudağı
    cyl(0.56, 0.05, (0, face_y + 0.06, 0), (90, 0, 0), m["dark"], verts=40)
    for i in range(spokes):
        a = 2 * math.pi * i / spokes + math.pi / 2
        s = box((0.1 if spokes > 6 else 0.16, 0.06, 0.48), (math.cos(a) * 0.3, face_y - 0.01, math.sin(a) * 0.3), m=m[rim], bevel=0.02)
        s.rotation_euler = (0, math.pi / 2 - a, 0)
    cyl(0.16, 0.1, (0, face_y - 0.02, 0), (90, 0, 0), m[rim], verts=20)
    cyl(0.07, 0.1, (0, face_y - 0.05, 0), (90, 0, 0), m["gold" if rim != "gold" else "dark"], verts=6)


# --- GÖVDE -------------------------------------------------------------------------------------------

def battery(material="carbon", lightning=False):
    m = M()
    box((1.1, 0.7, 0.75), (0, 0, 0.38), m=m[material] if material != "carbon" else m["carbon"], bevel=0.04)
    box((1.12, 0.72, 0.12), (0, 0, 0.8), m=m["dark"], bevel=0.03)
    cyl(0.08, 0.14, (-0.35, 0.15, 0.92), m=m["red"], verts=16)
    cyl(0.08, 0.14, (0.35, 0.15, 0.92), m=m["dark"], verts=16)
    box((0.5, 0.02, 0.25), (0, -0.36, 0.42), m=m["yellow"], bevel=0.0)   # etiket
    if lightning:
        bolt(m["yellow"], (0, -0.38, 0.45), 0.35).rotation_euler = (math.radians(90), 0, 0)


def hood():
    m = M()
    bpy.ops.mesh.primitive_grid_add(x_subdivisions=8, y_subdivisions=8, size=2.0)
    o = bpy.context.object
    for v in o.data.vertices:
        x, y = v.co.x, v.co.y
        v.co.z = 0.25 * (1 - x * x) + 0.12 * (1 - (y + 1) / 2) - 0.08 * (1 - y * y)
    o.scale = (1.0, 0.75, 1.0)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    sol = o.modifiers.new("s", "SOLIDIFY")
    sol.thickness = 0.06
    _finish(o, m["carbon"])
    for x in (-0.35, 0.35):   # hava çıkışları
        v = box((0.35, 0.45, 0.05), (x, -0.05, 0.3), m=m["dark"], bevel=0.02)


def bucket_seat():
    m = M()
    box((0.8, 0.8, 0.18), (0, 0, 0.1), m=m["rubber"], bevel=0.06)     # oturak
    box((0.8, 0.2, 1.2), (0, 0.45, 0.65), (12, 0, 0), m["rubber"], bevel=0.07)   # sırt
    for x in (-0.46, 0.46):   # yan destekler
        box((0.14, 0.95, 0.35), (x, 0.05, 0.25), m=m["carbon"], bevel=0.05)
        box((0.14, 0.25, 1.1), (x, 0.47, 0.75), (12, 0, 0), m["carbon"], bevel=0.05)
    for x in (-0.15, 0.15):   # kemer delikleri
        box((0.1, 0.05, 0.22), (x, 0.33, 1.1), (12, 0, 0), m["dark"], bevel=0.01)
    box((0.3, 0.06, 0.12), (0, 0.33, 1.3), (12, 0, 0), m["red"], bevel=0.01)
    box((0.06, 0.8, 0.08), (-0.25, 0, -0.04), m=m["alu"], bevel=0.01)
    box((0.06, 0.8, 0.08), (0.25, 0, -0.04), m=m["alu"], bevel=0.01)


def spoiler():
    m = M()
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (2.0, 0.55, 0.08)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in o.data.vertices:   # kanat profili: arka kenar yukarı
        if v.co.y > 0:
            v.co.z += 0.12
    o.location = (0, 0, 0.75)
    o.rotation_euler = (math.radians(-8), 0, 0)
    _finish(o, m["carbon"], smooth=False, bevel=0.02)
    for x in (-1.02, 1.02):
        box((0.04, 0.7, 0.4), (x, 0.03, 0.82), m=m["carbon"], bevel=0.01)
    for x in (-0.55, 0.55):
        box((0.05, 0.2, 0.7), (x, -0.05, 0.35), m=m["alu"], bevel=0.01)
        box((0.25, 0.3, 0.04), (x, -0.05, 0.0), m=m["alu"], bevel=0.01)


def carbon_body():
    m = M()
    # Basit coupe silueti: alt gövde + kabin, karbon
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.object
    o.scale = (2.4, 1.05, 0.42)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in o.data.vertices:
        if v.co.x > 0.5 and v.co.z > 0:
            v.co.z -= 0.12   # kaput eğimi
    o.location = (0, 0, 0.38)
    _finish(o, m["carbon"], smooth=False, bevel=0.08)
    bpy.ops.mesh.primitive_cube_add(size=1)
    c = bpy.context.object
    c.scale = (1.15, 0.9, 0.38)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for v in c.data.vertices:
        if v.co.z > 0:
            v.co.x *= 0.7
    c.location = (-0.2, 0, 0.75)
    _finish(c, m["carbon"], smooth=False, bevel=0.06)
    box((0.02, 0.8, 0.28), (0.36, 0, 0.75), (0, -38, 0), m["ti2"], bevel=0.0)   # cam
    for x in (-0.8, 0.8):
        for y in (-0.5, 0.5):
            cyl(0.24, 0.16, (x, y, 0.2), (90, 0, 0), m["rubber"], verts=20)
            cyl(0.14, 0.17, (x, y, 0.2), (90, 0, 0), m["gold"], verts=16)
    box((0.12, 1.1, 0.06), (-1.2, 0, 0.72), m=m["carbon"], bevel=0.01)   # kanat


# --- KLASİK -----------------------------------------------------------------------------------------

def distributor():
    m = M()
    cyl(0.35, 0.5, (0, 0, 0.25), m=m["cast"], verts=24)
    cyl(0.42, 0.3, (0, 0, 0.62), m=m["red"], verts=24, bevel=0.03)
    for i in range(6):
        a = 2 * math.pi * i / 6
        p = (math.cos(a) * 0.3, math.sin(a) * 0.3, 0.8)
        cyl(0.05, 0.12, p, m=m["dark"], verts=10)
        pipe([p, (math.cos(a) * 0.7, math.sin(a) * 0.7, 1.0), (math.cos(a) * 1.0, math.sin(a) * 1.0, 0.6)], 0.035, m["yellow"])
    cyl(0.06, 0.3, (0, 0, 0.92), m=m["dark"], verts=10)
    box((0.3, 0.2, 0.2), (0.4, 0, 0.2), m=m["alu"], bevel=0.02)


def supercharger(big=False, scoop=False, screw=False):
    m = M()
    w = 1.5 if big else 1.2
    box((w, 0.9, 0.6), (0, 0, 0.45), m=m["alu"], bevel=0.1)
    for i in range(8):   # kanatçıklar
        box((w * 0.95, 0.04, 0.12), (0, -0.4 + i * 0.115, 0.8), m=m["alu"], bevel=0.01)
    box((w * 1.05, 1.0, 0.15), (0, 0, 0.08), m=m["cast"], bevel=0.03)
    cyl(0.32, 0.12, (-w / 2 - 0.15, 0, 0.5), (0, 90, 0), m["dark"], verts=24)   # kasnak
    cyl(0.12, 0.14, (-w / 2 - 0.15, 0, 0.5), (0, 90, 0), m["steel"], verts=16)
    if scoop:
        box((0.6, 0.7, 0.45), (0.1, 0, 1.08), m=m["red"], bevel=0.08)
        box((0.5, 0.05, 0.3), (0.1, -0.36, 1.1), m=m["dark"], bevel=0.01)
    if screw:
        for y in (-0.22, 0.22):
            cyl(0.2, w * 0.8, (0, y, 0.95), (0, 90, 0), m["steel"], verts=16)
            for i in range(6):
                torus(0.2, 0.03, (-w * 0.35 + i * w * 0.14, y, 0.95), (0, 90 + 20, 0), m["alu"], seg=16, mseg=6)


def pulley():
    m = M()
    cyl(0.85, 0.3, rot=(90, 0, 0), m=m["alu"], verts=40, bevel=0.03)
    for i in range(5):
        torus(0.85, 0.025, (0, -0.12 + i * 0.06, 0), (90, 0, 0), m["dark"], seg=40, mseg=6)
    cyl(0.3, 0.34, rot=(90, 0, 0), m=m["dark"], verts=24)
    cyl(0.4, 0.33, (1.3, 0, -0.6), (90, 0, 0), m["alu"], verts=28)
    pipe([(0, -0.02, 0.88), (1.3, -0.02, -0.2), (1.6, -0.02, -0.75), (1.0, -0.02, -0.95), (-0.6, -0.02, -0.6)], 0.05, m["rubber"])


def round_air_cleaner():
    m = M()
    cyl(1.0, 0.35, (0, 0, 0.4), m=m["alu"], verts=40, bevel=0.06)
    cyl(0.85, 0.36, (0, 0, 0.4), m=m["red"], verts=40)
    cyl(1.05, 0.06, (0, 0, 0.6), m=m["alu"], verts=40, bevel=0.02)
    cyl(0.12, 0.2, (0, 0, 0.72), m=m["gold"], verts=6)   # kelebek somun
    cyl(0.5, 0.3, (0, 0, 0.1), m=m["cast"], verts=24)


def carburetor(count=1, stacks=False):
    m = M()
    for k in range(count):
        x = (k - (count - 1) / 2) * 0.9
        box((0.7, 0.6, 0.6), (x, 0, 0.3), m=m["alu"], bevel=0.05)
        cyl(0.22, 0.3, (x, 0, 0.75), m=m["alu"], verts=20)
        if stacks:
            for dx in (-0.16, 0.16):
                cyl(0.14, 0.5, (x + dx, 0, 0.85), m=m["gold"], verts=20, r2=0.2)
        else:
            cyl(0.3, 0.12, (x, 0, 0.95), m=m["steel"], verts=24)
        pipe([(x + 0.36, -0.1, 0.4), (x + 0.6, -0.3, 0.55), (x + 0.75, -0.5, 0.5)], 0.04, m["red"])
    box((count * 0.9 + 0.2, 0.7, 0.12), (0, 0, 0.02), m=m["cast"], bevel=0.03)


def throttle_bodies():
    m = M()
    box((1.8, 0.5, 0.2), (0, 0, 0.1), m=m["cast"], bevel=0.03)
    for i in range(4):
        x = -0.66 + i * 0.44
        cyl(0.16, 0.5, (x, 0, 0.45), m=m["alu"], verts=20)
        cyl(0.2, 0.25, (x, 0, 0.82), m=m["gold"], verts=20, r2=0.24)
    pipe([(-0.9, 0.3, 0.55), (0.9, 0.3, 0.55)], 0.06, m["red"])   # yakıt rampası
    for i in range(4):
        cyl(0.04, 0.2, (-0.66 + i * 0.44, 0.3, 0.45), m=m["dark"], verts=8)


# --- ELEKTRİK -----------------------------------------------------------------------------------------

def inverter(sic=False):
    m = M()
    box((1.3, 0.9, 0.4), (0, 0, 0.2), m=m["alu"], bevel=0.05)
    box((1.0, 0.6, 0.06), (0, 0, 0.43), m=m["pcb" if not sic else "chip"], bevel=0.005)
    if sic:
        for i in range(3):
            box((0.22, 0.22, 0.06), (-0.33 + i * 0.33, 0, 0.48), m=m["gold"], bevel=0.005)
    else:
        for i in range(6):
            cyl(0.07, 0.16, (-0.4 + i * 0.16, 0.12, 0.52), m=m["dark"], verts=12)
    for y in (-0.25, 0.0, 0.25):
        pipe([(0.65, y, 0.2), (1.0, y, 0.25), (1.3, y * 1.6, 0.05)], 0.06, m["orange"])


def rotor():
    m = M()
    cyl(0.5, 1.2, rot=(0, 90, 0), m=m["dark"], verts=28)
    for i in range(10):   # bakır sargılar
        a = 2 * math.pi * i / 10
        b = box((1.1, 0.16, 0.12), (0, math.cos(a) * 0.5, math.sin(a) * 0.5), m=m["copper"], bevel=0.03)
        b.rotation_euler = (a, 0, 0)
    cyl(0.12, 2.0, rot=(0, 90, 0), m=m["steel"], verts=16)
    cyl(0.55, 0.08, (-0.62, 0, 0), (0, 90, 0), m["carbon"], verts=28)
    cyl(0.55, 0.08, (0.62, 0, 0), (0, 90, 0), m["carbon"], verts=28)


def e_motor():
    m = M()
    cyl(0.6, 1.3, rot=(0, 90, 0), m=m["alu"], verts=32, bevel=0.04)
    for i in range(9):
        torus(0.6, 0.035, (-0.5 + i * 0.125, 0, 0), (0, 90, 0), m["alu"], seg=32, mseg=6)
    cyl(0.62, 0.12, (0.7, 0, 0), (0, 90, 0), m["carbon"], verts=32)
    cyl(0.14, 0.4, (0.9, 0, 0), (0, 90, 0), m["steel"], verts=16)
    box((0.5, 0.3, 0.3), (-0.2, 0, 0.7), m=m["dark"], bevel=0.04)
    for y in (-0.08, 0.08):
        pipe([(-0.2, y, 0.85), (-0.6, y * 2, 1.0), (-1.0, y * 3, 0.7)], 0.05, m["orange"])


def cell_pack(kind="round"):
    m = M()
    box((1.4, 1.0, 0.12), (0, 0, 0.06), m=m["dark"], bevel=0.02)
    if kind == "round":
        for i in range(6):
            for j in range(4):
                cyl(0.1, 0.6, (-0.55 + i * 0.22, -0.33 + j * 0.22, 0.42), m=m["blue"], verts=16)
                cyl(0.05, 0.62, (-0.55 + i * 0.22, -0.33 + j * 0.22, 0.42), m=m["steel"], verts=8)
    else:
        for i in range(7):
            box((0.12, 0.85, 0.75), (-0.6 + i * 0.2, 0, 0.5), m=m["alu"], bevel=0.03)
            box((0.06, 0.1, 0.12), (-0.6 + i * 0.2, 0.3, 0.92), m=m["copper"], bevel=0.01)
    box((1.4, 0.06, 0.1), (0, 0.45, 0.85), m=m["orange"], bevel=0.01)


def supercaps():
    m = M()
    for i in range(3):
        for j in range(2):
            cyl(0.26, 1.0, (-0.6 + i * 0.6, -0.3 + j * 0.6, 0.5), m=m["blue"], verts=24, bevel=0.03)
            cyl(0.27, 0.1, (-0.6 + i * 0.6, -0.3 + j * 0.6, 0.95), m=m["alu"], verts=24)
    pipe([(-0.6, -0.3, 1.05), (0, 0, 1.25), (0.6, 0.3, 1.05)], 0.05, m["orange"])


def race_battery():
    m = M()
    box((1.8, 1.1, 0.5), (0, 0, 0.25), m=m["carbon"], bevel=0.06)
    box((1.82, 1.12, 0.08), (0, 0, 0.52), m=m["orange"], bevel=0.01)
    bolt(m["yellow"], (0, -0.2, 0.58), 0.45)
    for x in (-0.7, 0.7):
        cyl(0.1, 0.2, (x, 0.4, 0.62), m=m["orange"], verts=16)


def radiator(fan=False):
    m = M()
    box((1.6, 0.15, 1.1), (0, 0, 0.55), m=m["alu"], bevel=0.01)
    for i in range(18):
        box((1.55, 0.17, 0.02), (0, 0, 0.06 + i * 0.058), m=m["steel"], bevel=0)
    for x in (-0.86, 0.86):
        box((0.14, 0.22, 1.15), (x, 0, 0.55), m=m["blue" if fan else "alu"], bevel=0.04)
    pipe([(0.86, 0, 1.0), (1.1, -0.3, 1.1), (1.2, -0.6, 1.0)], 0.07, m["blue"])
    if fan:
        cyl(0.45, 0.08, (0, -0.15, 0.55), (90, 0, 0), m["dark"], verts=28)
        for i in range(7):
            a = 2 * math.pi * i / 7
            bl = box((0.38, 0.03, 0.16), (math.cos(a) * 0.22, -0.2, 0.55 + math.sin(a) * 0.22), m=m["dark"], bevel=0.01)
            bl.rotation_euler = (math.radians(20), -a, 0)


def heater_plate():
    m = M()
    box((1.5, 1.0, 0.1), (0, 0, 0.05), m=m["alu"], bevel=0.02)
    pts = []
    for i in range(6):
        y = -0.38 + i * 0.15
        pts += [(-0.6 if i % 2 == 0 else 0.6, y, 0.14), (0.6 if i % 2 == 0 else -0.6, y, 0.14)]
    pipe(pts, 0.035, m["orange"], res=4)
    bolt(m["red"], (0.0, 0.0, 0.2), 0.3)


def cooled_cable():
    m = M()
    pts = []
    for i in range(16):
        a = i * 0.9
        pts.append((math.cos(a) * 0.6, math.sin(a) * 0.6, i * 0.06))
    pipe(pts, 0.09, m["orange"])
    pipe([(p[0] * 1.25, p[1] * 1.25, p[2] + 0.03) for p in pts[::2]], 0.05, m["ti2"])
    box((0.35, 0.3, 0.25), (0.6, 0, 1.0), m=m["dark"], bevel=0.04)


def cryo():
    m = M()
    cyl(0.5, 1.3, (0, 0, 0.65), m=m["white"], verts=28, bevel=0.06)
    cyl(0.52, 0.12, (0, 0, 0.3), m=m["ti2"], verts=28)
    cyl(0.18, 0.25, (0, 0, 1.4), m=m["steel"], verts=16)
    cyl(0.28, 0.06, (0, 0, 1.55), m=m["blue"], verts=16)
    pipe([(0.1, 0, 1.45), (0.6, 0, 1.6), (0.95, 0, 1.2)], 0.05, m["steel"])
    for i in range(5):   # kırağı kristalleri
        a = i * 1.3
        sphere(0.07, (math.cos(a) * 0.52, math.sin(a) * 0.52, 0.5 + i * 0.15), m["frost"], seg=8)


# --- Parça listesi: id → model (PerformanceMods.PART_ICONS bu id'leri kullanır) ---------------------------

PARTS = {
    # MOTOR
    "motor_ecu": lambda: ecu("green"),
    "motor_cam": camshaft,
    "motor_piston": piston,
    "motor_crank": crankshaft,
    "motor_block": lambda: engine_block("red"),
    # TURBO
    "turbo_small": lambda: turbo(0.9, "alu"),
    "turbo_intercooler": intercooler,
    "turbo_wheel": turbine_wheel,
    "turbo_big": lambda: turbo(1.15, "blue"),
    "turbo_twin": twin_turbo,
    # HAVA AKIŞI
    "air_filter": lambda: cone_filter("red"),
    "air_cold": cold_air,
    "air_downpipe": downpipe,
    "air_header": lambda: header("steel"),
    "air_exhaust": race_exhaust,
    # ŞANZIMAN
    "gear_shifter": shifter,
    "gear_clutch": clutch_disc,
    "gear_flywheel": lambda: flywheel("alu"),
    "gear_set": gear_set,
    "gear_sequential": sequential_box,
    # LASTİK & JANT
    "tire_sport": lambda: tire(0.45, 0.95, False, False),
    "tire_semi": lambda: wheel(5, "alu", 0.45),
    "tire_radial": lambda: wheel(10, "steel", 0.6, False, True),
    "tire_slick": lambda: wheel(6, "gold", 0.6, True),
    "tire_pro": lambda: wheel(5, "carbon", 0.75, True, True),
    # GÖVDE
    "body_battery": lambda: battery("carbon"),
    "body_hood": hood,
    "body_seat": bucket_seat,
    "body_spoiler": spoiler,
    "body_shell": carbon_body,
    # KLASİK: ateşleme, KOMPRESÖR, KARBÜRATÖR & EGZOZ
    "classic_ignition": distributor,
    "classic_sc_kit": supercharger,
    "classic_pulley": pulley,
    "classic_roots": lambda: supercharger(True, True),
    "classic_screw": lambda: supercharger(True, False, True),
    "classic_cleaner": round_air_cleaner,
    "classic_twin_carb": lambda: carburetor(2),
    "classic_weber": lambda: carburetor(1, True),
    "classic_fi": throttle_bodies,
    # ELEKTRİK: MOTOR, BATARYA, SOĞUTMA
    "ev_software": lambda: ecu("blue"),
    "ev_inverter": inverter,
    "ev_sic": lambda: inverter(True),
    "ev_rotor": rotor,
    "ev_motor": e_motor,
    "ev_discharge": lambda: battery("blue", True),
    "ev_cells": lambda: cell_pack("round"),
    "ev_pouch": lambda: cell_pack("pouch"),
    "ev_supercap": supercaps,
    "ev_pack": race_battery,
    "ev_radiator": radiator,
    "ev_preheat": heater_plate,
    "ev_cable": cooled_cable,
    "ev_race_cool": lambda: radiator(True),
    "ev_cryo": cryo,
}


# --- Sahne / render ------------------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _MATS.clear()
    scn = bpy.context.scene
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = SAMPLES
    scn.cycles.use_denoising = True
    scn.render.film_transparent = True
    scn.render.resolution_x = SIZE
    scn.render.resolution_y = SIZE
    scn.render.image_settings.file_format = "PNG"
    scn.render.image_settings.color_mode = "RGBA"
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    world = bpy.data.worlds.new("w")
    scn.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = lin("FFF3DD")
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
    # Mürekkep kontur (HUD plaka dili)
    scn.render.use_freestyle = True
    scn.render.line_thickness_mode = "ABSOLUTE"
    scn.render.line_thickness = 1.6
    scn.view_layers[0].use_freestyle = True
    ls = scn.view_layers[0].freestyle_settings.linesets.new("ink")
    ls.select_by_visibility = True
    ls.select_by_edge_types = True
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = False
    ls.linestyle.color = lin("2F3236")[:3]
    ls.linestyle.thickness = 1.6
    return scn


def light_and_frame(scn):
    objs = [o for o in scn.objects if o.type == "MESH"]
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    # Oyunun izometrik açısı: 35° yükseklik, 45° yön
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam = bpy.data.objects.new("cam", cam_data)
    scn.collection.objects.link(cam)
    scn.camera = cam
    direction = Vector((1, -1, 0.95)).normalized()
    cam.location = center + direction * 20
    cam.rotation_euler = (-direction).to_track_quat("-Z", "Y").to_euler()
    bpy.context.view_layer.update()
    # Kadraj: köşelerin kamera düzlemindeki izdüşümü
    inv = cam.matrix_world.inverted()
    xs, ys = [], []
    for o in objs:
        for c in o.bound_box:
            p = inv @ (o.matrix_world @ Vector(c))
            xs.append(p.x)
            ys.append(p.y)
    span = max(max(xs) - min(xs), max(ys) - min(ys))
    cam_data.ortho_scale = span * 1.12
    cam_data.shift_x = (max(xs) + min(xs)) / 2 / cam_data.ortho_scale
    cam_data.shift_y = (max(ys) + min(ys)) / 2 / cam_data.ortho_scale
    key = bpy.data.lights.new("key", "SUN")
    key.energy = 3.2
    key.angle = math.radians(8)
    k = bpy.data.objects.new("key", key)
    k.rotation_euler = (math.radians(50), 0, math.radians(20))
    scn.collection.objects.link(k)
    rim = bpy.data.lights.new("rim", "SUN")
    rim.energy = 1.4
    r = bpy.data.objects.new("rim", rim)
    r.rotation_euler = (math.radians(-60), 0, math.radians(200))
    scn.collection.objects.link(r)


def render(part_id, out_dir):
    scn = reset_scene()
    PARTS[part_id]()
    if part_id.startswith("tire_"):   # sırt (diş) da görünsün: tekerlek kameraya hafif yan döner
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.transform.rotate(value=math.radians(30), orient_axis="Z", center_override=(0, 0, 0))
        bpy.ops.object.select_all(action="DESELECT")
    light_and_frame(scn)
    scn.render.filepath = os.path.join(out_dir, part_id + ".png")
    bpy.ops.render.render(write_still=True)
    print("İKON", scn.render.filepath)


def main():
    argv = sys.argv
    args = argv[argv.index("--") + 1:] if "--" in argv else argv[1:]
    out_dir = args[0] if args else os.path.join(PROJECT, "ui/hud/art/parts")
    ids = args[1:] or list(PARTS.keys())
    os.makedirs(out_dir, exist_ok=True)
    for part_id in ids:
        render(part_id, out_dir)


if __name__ == "__main__":
    main()
