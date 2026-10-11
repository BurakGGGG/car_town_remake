"""HARİTA görseli — çizgi-film tarzı küçük diorama (Blender, ekransız).

Kullanım:
    blender -b --factory-startup --python tools/world/map_render.py [-- --preview]

Çıktılar:
  assets/ui/map/world_map.png   — harita arka planı (1920×1080). Simgeler ve rota OYUNDA kodla çizilir
                                  (docs/HURDALIK_TASARIM.md §1): görselde yalnız arazi, şehir, hurdalık ve
                                  soluk bir toprak yol var.
  assets/ui/map/world_map.json  — mekânların ve yolun ekran konumu (0..1, sol üst köşe başlangıç): harita
                                  ekranı simgeleri ve animasyonlu rotayı buradan yerleştirir. Görsel yeniden
                                  render edilince konumlar da güncellenir (elle konum yok).

Düzen (harita birimi ≈ metre, X doğu, Y kuzey): batıda çöl + kızıl kayalıklar + HURDALIK, doğuda yeşil
ŞEHİR, arada kuzeyden denize akan nehir ve köprü, güneyde kıyı. Kenarlarda bulutlar (haritanın ucu).
"""
import bpy, bmesh, math, random, json, os, sys
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

PROJECT = "/home/burak/Projects/car-town-remake"
OUT_DIR = os.path.join(PROJECT, "assets/ui/map")
PREVIEW = "--preview" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
RES = (960, 540) if PREVIEW else (1920, 1080)

CITY = (38.0, 6.0)
JUNKYARD = (-44.0, 4.0)
# Yol: şehirden çıkıp nehri köprüyle geçer, çölde kayalıkların arasından hurdalığa kıvrılır
ROAD = [(22.0, 3.0), (17.0, 2.5), (12.0, 3.5), (6.0, 5.0), (-2.0, 4.0), (-10.0, 0.5), (-18.0, -1.0),
        (-26.0, 2.5), (-31.0, 4.5), (-34.0, 4.2)]
RIVER = [(4.0, 60.0), (6.0, 40.0), (2.0, 24.0), (7.0, 10.0), (5.0, -6.0), (8.0, -20.0), (7.0, -27.5)]
SEA_Y = -26.0

R = random.Random(5)


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


_MATS = {}


def mat(hexcol, rough=0.8, emit=0.0):
    key = (hexcol, rough, emit)
    if key in _MATS:
        return _MATS[key]
    m = bpy.data.materials.new("Map_" + hexcol.lstrip("#"))
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = srgb(hexcol)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    if emit:
        b.inputs["Emission Color"].default_value = (c[0], c[1], c[2], 1.0)
        b.inputs["Emission Strength"].default_value = emit
    _MATS[key] = m
    return m


def add_obj(name, me, material=None):
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    if material is not None:
        me.materials.append(material)
    return o


def box(name, center, size, material, rot=0.0, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=size, verts=bm.verts)
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=2, affect='EDGES')
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = add_obj(name, me, material)
    o.location = (center[0], center[1], center[2] + size[2] / 2)
    o.rotation_euler = (0, 0, math.radians(rot))
    return o


def cyl(name, center, r, h, material, segs=16, r2=None):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=segs, radius1=r, radius2=r if r2 is None else r2, depth=h)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = add_obj(name, me, material)
    o.location = (center[0], center[1], center[2] + h / 2)
    return o


def blob(name, center, radius, scale, material, segs=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=radius)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    o = add_obj(name, me, material)
    o.location = center
    o.scale = scale
    return o


def ribbon(name, pts, width, z, material, smooth=6):
    """Yol / nehir şeridi: Catmull-Rom ile yumuşatılmış çizgi boyunca düz şerit."""
    path = catmull(pts, smooth)
    verts, faces = [], []
    for i, p in enumerate(path):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, len(path) - 1)]
        d = Vector((b[0] - a[0], b[1] - a[1])).normalized()
        n = Vector((-d.y, d.x)) * (width / 2)
        verts += [(p[0] + n.x, p[1] + n.y, z), (p[0] - n.x, p[1] - n.y, z)]
        if i > 0:
            k = i * 2
            faces.append((k - 2, k - 1, k + 1, k))
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    return add_obj(name, me, material), path


def catmull(pts, steps):
    out = []
    p = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(p) - 2):
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            x = 0.5 * ((2 * p[i][0]) + (-p[i - 1][0] + p[i + 1][0]) * t + (2 * p[i - 1][0] - 5 * p[i][0] + 4 * p[i + 1][0] - p[i + 2][0]) * t2
                       + (-p[i - 1][0] + 3 * p[i][0] - 3 * p[i + 1][0] + p[i + 2][0]) * t3)
            y = 0.5 * ((2 * p[i][1]) + (-p[i - 1][1] + p[i + 1][1]) * t + (2 * p[i - 1][1] - 5 * p[i][1] + 4 * p[i + 1][1] - p[i + 2][1]) * t2
                       + (-p[i - 1][1] + 3 * p[i][1] - 3 * p[i + 1][1] + p[i + 2][1]) * t3)
            out.append((x, y))
    out.append(pts[-1])
    return out


def river_x(y):
    """Nehrin bu enlemdeki X'i (doğrusal ara değer)."""
    for (x0, y0), (x1, y1) in zip(RIVER, RIVER[1:]):
        if y1 <= y <= y0:
            t = (y - y0) / (y1 - y0)
            return x0 + (x1 - x0) * t
    return RIVER[-1][0]


# --- Arazi -----------------------------------------------------------------------------

def ground():
    """Köşe renkli arazi: batı çöl, doğu çimen, nehir kıyısında geçiş; güneyde kumsal + deniz."""
    from mathutils import noise
    nx, ny = 330, 200
    x0, x1, y0, y1 = -110.0, 110.0, -60.0, 70.0
    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Col")
    grid = []
    for j in range(ny + 1):
        row = []
        for i in range(nx + 1):
            x = x0 + (x1 - x0) * i / nx
            y = y0 + (y1 - y0) * j / ny
            row.append(bm.verts.new((x, y, 0.0)))
        grid.append(row)
    sand, grass, beach = Vector(srgb("#DDB57A")), Vector(srgb("#8FC15B")), Vector(srgb("#F0DDA8"))
    sand_dark, grass_dark = Vector(srgb("#C99A5E")), Vector(srgb("#6FA845"))
    sea, sea_deep = Vector(srgb("#5FC0DD")), Vector(srgb("#3A93C2"))
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for loop in f.loops:
                x, y = loop.vert.co.x, loop.vert.co.y
                n = noise.noise(Vector((x * 0.05, y * 0.05, 0.3)))
                n2 = noise.noise(Vector((x * 0.18, y * 0.18, 2.0)))
                edge = river_x(y) + n * 6.0
                t = max(0.0, min(1.0, (x - edge + 6.0) / 12.0))   # 0 çöl → 1 çimen
                land = sand.lerp(sand_dark, max(0.0, n2) * 0.8).lerp(grass.lerp(grass_dark, max(0.0, n2) * 0.9), t)
                shore = shore_y(x)
                c = beach.lerp(land, max(0.0, min(1.0, (y - shore - 1.6) / 1.6)))
                loop[col] = (c.x, c.y, c.z, 1.0)
    # Kıyı: kara denize doğru eğimle iner; deniz ayrı düzlem → kıyı çizgisi iki yüzeyin kesişimi (pürüzsüz)
    for v in bm.verts:
        v.co.z = max(-1.2, min(0.0, (v.co.y - shore_y(v.co.x)) * 0.35))
    me = bpy.data.meshes.new("MapGround")
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new("Map_Ground")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.95
    add_obj("MapGround", me, m)


def shore_y(x):
    from mathutils import noise
    return SEA_Y + noise.noise(Vector((x * 0.05, SEA_Y * 0.05, 0.3))) * 3.0 + noise.noise(Vector((x * 0.12, 7.0, 1.0))) * 1.2


def sea():
    """Deniz: kıyıda açık turkuaz + köpük bandı, açıkta koyu mavi (köşe renkli düzlem)."""
    bm = bmesh.new()
    col = bm.loops.layers.float_color.new("Col")
    nx, ny = 120, 30
    x0, x1, y0, y1 = -110.0, 110.0, -60.0, SEA_Y + 4.0
    grid = [[bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny, -0.25)) for i in range(nx + 1)]
            for j in range(ny + 1)]
    shallow, deep, foam = Vector(srgb("#6CCBE3")), Vector(srgb("#3A93C2")), Vector(srgb("#D6F2F7"))
    for j in range(ny):
        for i in range(nx):
            f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
            for loop in f.loops:
                x, y = loop.vert.co.x, loop.vert.co.y
                d = shore_y(x) - y
                c = shallow.lerp(deep, max(0.0, min(1.0, d / 16.0)) ** 1.5)
                if 0.0 < d < 1.6:
                    c = c.lerp(foam, 0.6 * (1.0 - d / 1.6))
                loop[col] = (c.x, c.y, c.z, 1.0)
    me = bpy.data.meshes.new("Sea")
    bm.to_mesh(me)
    bm.free()
    m = bpy.data.materials.new("Map_Sea")
    m.use_nodes = True
    nt = m.node_tree
    b = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.3
    add_obj("Sea", me, m)


def river():
    water = mat("#4FB3D9", rough=0.25)
    ribbon("River", RIVER, 4.2, 0.05, water, smooth=8)
    ribbon("RiverBank", RIVER, 6.0, 0.03, mat("#CDB98A"), smooth=8)


def road():
    asphalt = mat("#6B625A")
    o, path = ribbon("Road", ROAD, 2.0, 0.08, asphalt, smooth=8)
    ribbon("RoadEdge", ROAD, 2.6, 0.06, mat("#BFA57A"), smooth=8)
    # Köprü: nehrin üstünde korkuluklu tabla
    bx = river_x(4.5)
    box("Bridge", (bx, 4.6, 0.1), (7.5, 3.2, 0.5), mat("#8C7B6A"), rot=-8)
    for side in (-1, 1):
        box("BridgeRail%d" % side, (bx, 4.6 + side * 1.6, 0.6), (7.5, 0.25, 0.6), mat("#C24B3A"), rot=-8)
    return path


def mesas():
    rock, rock_dark, rock_top = mat("#C77C4B"), mat("#A9603A"), mat("#DFA26A")
    for k, (x, y, r, h) in enumerate([(-62, 22, 7, 7), (-30, 26, 5, 5), (-70, -8, 6, 6), (-20, -16, 4, 4),
                                      (-52, 40, 9, 9), (-86, 18, 8, 8)]):
        cyl("Mesa%d" % k, (x, y, 0), r, h * 0.55, rock_dark, segs=10, r2=r * 0.9)
        cyl("MesaB%d" % k, (x, y, h * 0.55), r * 0.9, h * 0.35, rock, segs=10, r2=r * 0.82)
        cyl("MesaT%d" % k, (x, y, h * 0.9), r * 0.82, 0.25, rock_top, segs=10)
    cactus = mat("#5E9A4A")
    for k in range(26):
        x, y = R.uniform(-100, -12), R.uniform(-18, 60)
        if abs(y - 3) < 5 and x > -50:
            continue
        cyl("Cactus%d" % k, (x, y, 0), 0.35, R.uniform(1.0, 2.0), cactus, segs=8)


def trees():
    leaf = [mat("#4E9A3E"), mat("#63AE47"), mat("#3E8A3A")]
    trunk = mat("#7A5434")
    for k in range(120):
        x, y = R.uniform(14, 108), R.uniform(-20, 68)
        if abs(x - CITY[0]) < 15 and abs(y - CITY[1]) < 11:
            continue
        if abs(y - 3.5) < 3 and x < 34:
            continue
        s = R.uniform(0.8, 1.5)
        cyl("Trunk%d" % k, (x, y, 0), 0.25 * s, 0.9 * s, trunk, segs=6)
        if R.random() < 0.5:
            blob("Tree%d" % k, (x, y, 1.8 * s), 1.1 * s, (1, 1, 1.05), R.choice(leaf), segs=10, rings=7)
        else:
            cyl("Pine%d" % k, (x, y, 0.8 * s), 1.1 * s, 2.6 * s, R.choice(leaf), segs=8, r2=0.0)
    # Kuzeydoğuda ormanlı tepeler
    hill = mat("#7DB552")
    for k, (x, y, r) in enumerate([(70, 50, 14), (92, 30, 12), (50, 62, 10)]):
        blob("Hill%d" % k, (x, y, -r * 0.55), r, (1.2, 1, 0.7), hill, segs=20, rings=12)


def city():
    """Bloklar: ızgara sokaklar, renkli çatılı alçak binalar, ortada birkaç yüksek kule, park."""
    street = mat("#D7D2C6")
    box("CityBase", (CITY[0], CITY[1], 0.02), (30.5, 21.0, 0.12), street)
    walls = [mat("#F4EFE4"), mat("#EADFCB"), mat("#D9E3EA"), mat("#F2E3C2")]
    roofs = [mat("#E2725B"), mat("#F2C14E"), mat("#6FA8DC"), mat("#9BC46B"), mat("#C9584A"), mat("#F5F1E6")]
    glass = mat("#7FC8E8", rough=0.2)
    for gx in range(-3, 4):
        for gy in range(-2, 3):
            if (gx, gy) in ((1, -1), (1, 0)):
                continue   # park
            cx, cy = CITY[0] + gx * 4.2, CITY[1] + gy * 4.0
            tall = abs(gx) <= 1 and abs(gy) <= 1
            h = R.uniform(4.5, 8.0) if tall and R.random() < 0.6 else R.uniform(1.4, 3.0)
            w, d = R.uniform(2.6, 3.3), R.uniform(2.4, 3.1)
            box("Bld%d_%d" % (gx, gy), (cx, cy, 0.1), (w, d, h), glass if h > 4 else R.choice(walls), bevel=0.08)
            box("Roof%d_%d" % (gx, gy), (cx, cy, 0.1 + h), (w + 0.15, d + 0.15, 0.25), R.choice(roofs), bevel=0.05)
    park = mat("#78B84E")
    box("Park", (CITY[0] + 4.2, CITY[1] - 2.0, 0.1), (3.6, 7.2, 0.1), park)
    for k in range(5):
        blob("ParkTree%d" % k, (CITY[0] + 4.2 + R.uniform(-1, 1), CITY[1] - 2.0 + R.uniform(-2.8, 2.8), 0.9), 0.75,
             (1, 1, 1), mat("#4E9A3E"), segs=8, rings=6)
    # Garajımız: şehrin batı ucunda, sarı tabelalı
    box("Garage", (CITY[0] - 15.5, CITY[1] - 1.5, 0.1), (3.6, 2.9, 2.0), mat("#F3E8CF"), bevel=0.08)
    box("GarageRoof", (CITY[0] - 15.5, CITY[1] - 1.5, 2.1), (3.8, 3.1, 0.3), mat("#C24B3A"), bevel=0.05)
    box("GarageSign", (CITY[0] - 15.5, CITY[1] - 3.0, 1.3), (2.4, 0.1, 0.55), mat("#F5BE4C"), bevel=0.02)


def junkyard():
    """Minik hurdalık: oluklu çit, hurda tepecikleri, sarı vinç, pres, araç yığınları (sonunda 1,3 kat)."""
    before = set(bpy.data.objects)
    _junkyard_parts()
    cx, cy = JUNKYARD
    for o in set(bpy.data.objects) - before:
        o.location.x = cx + (o.location.x - cx) * 1.3
        o.location.y = cy + (o.location.y - cy) * 1.3
        o.location.z *= 1.3
        o.scale = o.scale * 1.3


def _junkyard_parts():
    cx, cy = JUNKYARD
    dirt = mat("#B88E5E")
    box("YardBase", (cx, cy, 0.02), (17.0, 12.0, 0.1), dirt)
    fence = mat("#8A7864")
    for side in (-1, 1):
        box("FenceH%d" % side, (cx, cy + side * 6.0, 0.1), (17.0, 0.25, 1.1), fence)
        box("FenceV%d" % side, (cx + side * 8.5, cy, 0.1), (0.25, 12.0, 1.1), fence)
    rust = [mat("#8A4A2A"), mat("#6E5C4E"), mat("#A0623A"), mat("#5C6670"), mat("#B5893F")]
    for k in range(9):
        x, y = cx + R.uniform(-7, 5), cy + R.uniform(-4.5, 4.5)
        blob("Junk%d" % k, (x, y, -0.3), R.uniform(1.0, 1.8), (1.2, 1.0, 0.75), R.choice(rust), segs=7, rings=5)
    for k in range(4):
        x, y = cx + 2.0 + (k % 2) * 2.4, cy - 3.0 + (k // 2) * 1.6
        box("Car%d" % k, (x, y, 0.1), (1.8, 0.9, 0.55), R.choice(rust), rot=R.uniform(-20, 20), bevel=0.15)
    yellow = mat("#E0A81E")
    box("Crane", (cx - 3.0, cy + 2.5, 0.1), (2.0, 1.6, 1.3), yellow, bevel=0.08)
    boom = box("Boom", (cx - 1.4, cy + 2.5, 1.2), (5.0, 0.3, 0.3), yellow)
    boom.rotation_euler = (0, math.radians(-30), 0)
    box("Press", (cx + 5.5, cy + 3.5, 0.1), (2.4, 1.8, 2.0), mat("#2F5C8A"), bevel=0.08)
    for k in range(3):
        box("Cube%d" % k, (cx + 7.0, cy + 1.6 - k * 0.9, 0.1 + (k % 2) * 0.7), (0.7, 0.7, 0.7), R.choice(rust))


def extras():
    """Haritayı canlandıran küçük ayrıntılar: tarlalar, kasaba evleri, yol üstünde benzinlik, deniz feneri,
    tekneler, çölde vaha ve rüzgârgülü."""
    # Şehrin kuzeydoğusunda çizgili tarlalar
    crops = [mat("#E6C55A"), mat("#A8C95E"), mat("#C9A35A"), mat("#8CB850")]
    for k in range(6):
        fx, fy = 58 + (k % 3) * 7.5, 22 + (k // 3) * 6.5
        c = crops[k % 4]
        for r in range(5):
            box("Field%d_%d" % (k, r), (fx, fy - 2.4 + r * 1.2, 0.02), (6.6, 0.9, 0.12), c if r % 2 == 0 else mat("#B9925A"))
    # Kasaba evleri: şehrin çevresinde dağınık, kırmızı / turuncu çatılı
    wall, roofs = mat("#F4EFE4"), [mat("#D8604A"), mat("#E2865B"), mat("#C24B3A")]
    for k in range(18):
        x, y = CITY[0] + R.uniform(-22, 26), CITY[1] + R.uniform(-16, 22)
        if abs(x - CITY[0]) < 14 and abs(y - CITY[1]) < 10:
            continue
        if abs(y - 3.5) < 3 and x < CITY[0]:
            continue
        rot = R.uniform(-30, 30)
        box("House%d" % k, (x, y, 0.0), (1.8, 1.4, 1.0), wall, rot=rot, bevel=0.05)
        roof = box("HouseRoof%d" % k, (x, y, 1.0), (2.0, 1.6, 0.6), R.choice(roofs), rot=rot)
        bm = bmesh.new()
        bm.from_mesh(roof.data)
        for v in bm.verts:   # beşik çatı: üst kenar ortada toplanır
            if v.co.z > 0:
                v.co.y *= 0.05
        bm.to_mesh(roof.data)
        bm.free()
    # Yol üstünde benzinlik (çölde, nehrin batısı)
    gx, gy = -12.0, -3.2
    box("GasBase", (gx, gy, 0.02), (6.0, 3.6, 0.1), mat("#CFC6B4"))
    box("GasShop", (gx - 1.6, gy - 0.6, 0.1), (2.4, 1.8, 1.4), mat("#F4EFE4"), bevel=0.05)
    box("GasCanopy", (gx + 1.3, gy, 1.9), (3.0, 2.4, 0.25), mat("#C24B3A"), bevel=0.04)
    for k in range(2):
        box("GasPump%d" % k, (gx + 0.8 + k * 1.2, gy, 0.1), (0.35, 0.35, 0.9), mat("#F2C14E"))
        box("GasPole%d" % k, (gx + 0.2 + k * 2.2, gy + (0.9 if k else -0.9), 0.1), (0.15, 0.15, 1.8), mat("#4A4A4A"))
    # Deniz feneri + kayalık (güneybatı kıyısı) ve tekneler
    lx, ly = -60.0, SEA_Y + 1.0
    cyl("LightRock", (lx, ly, -0.4), 3.2, 1.2, mat("#9C8C7A"), segs=9, r2=2.4)
    for k in range(4):
        cyl("Light%d" % k, (lx, ly, 0.8 + k * 1.1), 0.95 - k * 0.08, 1.1, mat("#F4EFE4" if k % 2 == 0 else "#C24B3A"),
            segs=14, r2=0.95 - (k + 1) * 0.08)
    cyl("LightTop", (lx, ly, 5.2), 0.7, 0.8, mat("#FFE08A", emit=2.0), segs=12)
    cyl("LightCap", (lx, ly, 6.0), 0.85, 0.7, mat("#C24B3A"), segs=12, r2=0.1)
    for k, (bx, by, rot) in enumerate([(-32, -36, 20), (18, -34, -15), (44, -40, 40), (-8, -44, -60)]):
        hull = box("Boat%d" % k, (bx, by, -0.1), (3.4, 1.2, 0.6), mat("#F4EFE4"), rot=rot, bevel=0.2)
        box("BoatCab%d" % k, (bx, by, 0.5), (1.2, 0.8, 0.6), mat("#6FA8DC"), rot=rot, bevel=0.05)
    # Çölde vaha: küçük göl + palmiyeler
    ox, oy = -76.0, 4.0
    blob("Oasis", (ox, oy, -0.9), 4.2, (1.4, 1.0, 0.25), mat("#4FB3D9", rough=0.25), segs=20, rings=8)
    for k in range(5):
        a = k * 1.3
        px, py = ox + math.cos(a) * 5.2, oy + math.sin(a) * 3.6
        cyl("PalmTrunk%d" % k, (px, py, 0), 0.22, 2.6, mat("#8A6A44"), segs=6, r2=0.16)
        for f in range(5):
            leaf = box("PalmLeaf%d_%d" % (k, f), (px, py, 2.5), (2.2, 0.5, 0.08), mat("#5E9A4A"), rot=f * 72)
            leaf.rotation_euler = (math.radians(-18), 0, math.radians(f * 72))
    # Rüzgârgülü (çiftlik)
    wx, wy = 74.0, 12.0
    cyl("MillTower", (wx, wy, 0), 0.9, 4.6, mat("#F4EFE4"), segs=10, r2=0.6)
    for f in range(4):
        blade = box("MillBlade%d" % f, (wx, wy - 0.7, 4.4), (0.4, 0.1, 3.4), mat("#C9A35A"))
        blade.rotation_euler = (0, math.radians(f * 90 + 20), 0)


def clouds():
    white = mat("#FFFFFF", rough=0.9)
    spots = []
    for k in range(46):
        side = R.choice(["n", "n", "w", "e", "sw", "se"])
        if side == "n":
            x, y = R.uniform(-90, 90), R.uniform(58, 74)
        elif side == "w":
            x, y = R.uniform(-96, -78), R.uniform(-30, 60)
        elif side == "e":
            x, y = R.uniform(76, 96), R.uniform(-30, 60)
        elif side == "sw":
            x, y = R.uniform(-96, -60), R.uniform(-48, -34)
        else:
            x, y = R.uniform(58, 96), R.uniform(-48, -34)
        spots.append((x, y))
    for k, (x, y) in enumerate(spots):
        r = R.uniform(5, 9)
        blob("Cloud%d" % k, (x, y, 14 + R.uniform(0, 4)), r, (1.3, 1.0, 0.55), white, segs=14, rings=8)


def camera_light():
    scn = bpy.context.scene
    cam_data = bpy.data.cameras.new("MapCam")
    cam_data.type = 'ORTHO'
    cam_data.ortho_scale = 124.0
    cam_data.clip_end = 1000
    cam = bpy.data.objects.new("MapCam", cam_data)
    scn.collection.objects.link(cam)
    tilt = math.radians(50.0)   # dikeyden eğim: diorama
    cam.location = (-2.0, 8.0 - math.sin(tilt) * 200.0, math.cos(tilt) * 200.0)
    cam.rotation_euler = (tilt, 0.0, 0.0)
    scn.camera = cam
    scn.render.resolution_x, scn.render.resolution_y = RES
    sun_data = bpy.data.lights.new("MapSun", 'SUN')
    sun_data.energy = 4.2
    sun_data.color = srgb("#FFE9C8")
    sun_data.angle = math.radians(4.0)
    sun = bpy.data.objects.new("MapSun", sun_data)
    scn.collection.objects.link(sun)
    sun.rotation_euler = (math.radians(48), 0, math.radians(-35))
    world = bpy.data.worlds.new("MapWorld")
    scn.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    c = srgb("#BFE3F2")
    bg.inputs["Color"].default_value = (c[0], c[1], c[2], 1.0)
    bg.inputs["Strength"].default_value = 1.0
    try:
        scn.render.engine = 'BLENDER_EEVEE'
    except TypeError as e:
        print(e)
    try:
        scn.view_settings.look = 'AgX - Medium High Contrast'
    except Exception:
        pass
    return cam


def screen_point(cam, x, y, z=0.0):
    p = world_to_camera_view(bpy.context.scene, cam, Vector((x, y, z)))
    return [round(p.x, 4), round(1.0 - p.y, 4)]   # sol üst başlangıç


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    ground()
    sea()
    river()
    path = road()
    mesas()
    trees()
    city()
    junkyard()
    extras()
    clouds()
    cam = camera_light()
    os.makedirs(OUT_DIR, exist_ok=True)
    scn = bpy.context.scene
    scn.render.filepath = os.path.join(OUT_DIR, "world_map.png") if not PREVIEW else "/home/burak/Projects/ct_shots/map_preview.png"
    scn.render.image_settings.file_format = 'PNG'
    bpy.ops.render.render(write_still=True)
    data = {
        "_readme": "tools/world/map_render.py üretir. Konumlar ekran oranı (0..1), sol üst köşe başlangıç.",
        "places": {
            "city": screen_point(cam, CITY[0], CITY[1], 6.0),
            "junkyard": screen_point(cam, JUNKYARD[0], JUNKYARD[1], 2.0),
        },
        "route": [screen_point(cam, x, y, 0.1) for (x, y) in path[::3]] + [screen_point(cam, *path[-1], 0.1)],
    }
    if not PREVIEW:
        with open(os.path.join(OUT_DIR, "world_map.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    print("HARİTA", scn.render.filepath, data["places"])


main()
