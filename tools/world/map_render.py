"""HARİTA görseli — çizgi-film tarzı küçük diorama (Blender, ekransız).

Kullanım:
    blender -b --factory-startup --python tools/world/map_render.py [-- --preview | --full-preview]
    (--preview: yarım boy, --full-preview: tam boy; ikisi de ct_shots/map_preview.png'ye yazar, asset'e dokunmaz)

Çıktılar:
  assets/ui/map/world_map.png   — harita arka planı (1920×1080). Simgeler ve rota OYUNDA kodla çizilir
                                  (docs/HURDALIK_TASARIM.md §1): görselde yalnız arazi, şehir, hurdalık ve
                                  soluk bir toprak yol var.
  assets/ui/map/world_map.json  — mekânların ve yolun ekran konumu (0..1, sol üst köşe başlangıç): harita
                                  ekranı simgeleri ve animasyonlu rotayı buradan yerleştirir. Görsel yeniden
                                  render edilince konumlar da güncellenir (elle konum yok).

Düzen (harita birimi ≈ metre, X doğu, Y kuzey): batıda çöl + kızıl kayalıklar + HURDALIK, doğuda yeşil
ŞEHİR, arada kuzeyden denize akan nehir ve köprü, güneyde kıyı. Kenarlarda bulutlar (haritanın ucu).
YAKINDA mekânları (2026-10-23, henüz oynanmaz): kuzeyde çöl düzlüğünde OTO ŞOV (araç sergisi / buluşma), şehrin
güneyinde kıyıda LİMAN (ithal araçların geldiği rıhtım). İkisi de gri maket gibi çizilir (greyed()): açılınca
greyed() kaldırılıp yeniden render edilir.
"""
import bpy, bmesh, math, random, json, os, sys
from contextlib import contextmanager
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

PROJECT = "/home/burak/Projects/car-town-remake"
OUT_DIR = os.path.join(PROJECT, "assets/ui/map")
PREVIEW = "--preview" in (sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else [])
RES = (960, 540) if PREVIEW else (1920, 1080)
if "--full-preview" in sys.argv:
    PREVIEW, RES = True, (1920, 1080)

CITY = (38.0, 6.0)
JUNKYARD = (-44.0, 4.0)
# Yol: şehirden çıkıp nehri köprüyle geçer, çölde kayalıkların arasından hurdalığa kıvrılır
ROAD = [(22.0, 3.0), (17.0, 2.5), (12.0, 3.5), (6.0, 5.0), (-2.0, 4.0), (-10.0, 0.5), (-18.0, -1.0),
        (-26.0, 2.5), (-31.0, 4.5), (-34.0, 4.2)]
RIVER = [(4.0, 60.0), (6.0, 40.0), (2.0, 24.0), (7.0, 10.0), (5.0, -6.0), (8.0, -20.0), (7.0, -27.5)]
SEA_Y = -26.0
MEET = (-14.0, 27.5)   # OTO ŞOV (YAKINDA)
PORT = (37.0, -25.0)   # LİMAN (YAKINDA)
# Ana yoldan OTO ŞOV'a kuzeye, şehrin güney ucundan LİMAN'a inen yan yollar. İki mekân da 20:9 / 21:9
# telefonun üst / alt kırpma payının içinde kalmalı (harita ekranı geniş ekranda üstten ve alttan kırpılır).
MEET_ROAD = [(-3.5, 4.4), (-5.5, 10.0), (-9.5, 15.5), (-14.0, 20.4)]
PORT_ROAD = [(39.0, -4.6), (38.4, -9.0), (37.2, -14.0), (36.8, -19.6)]
CAR_COLORS = ["#D9483B", "#F2C14E", "#3F7FC1", "#F4EFE4", "#4FA46A", "#2E3440", "#E8833A", "#9B6FC4"]

R = random.Random(5)


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


_MATS = {}
GREY = False   # greyed() içinde True: mat() rengi gri maket tonuna çevirir (YAKINDA mekânları)


@contextmanager
def greyed():
    global GREY
    GREY = True
    try:
        yield
    finally:
        GREY = False


def grey_hex(hexcol):
    """Rengin parlaklığına göre gri (renkler arasındaki açık / koyu farkı kalır: maket okunur), hafif soğuk."""
    h = hexcol.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    v = int(62 + (0.299 * r + 0.587 * g + 0.114 * b) / 255.0 * 168)
    return "#%02X%02X%02X" % (v, v, min(255, v + 5))


def mat(hexcol, rough=0.8, emit=0.0):
    if GREY:
        hexcol, emit = grey_hex(hexcol), 0.0
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


def _turn(x, y, rot, dx, dy):
    """(x, y) merkezli, rot derece dönük nesnede yerel (dx, dy) noktasının dünya konumu."""
    a = math.radians(rot)
    return x + dx * math.cos(a) - dy * math.sin(a), y + dx * math.sin(a) + dy * math.cos(a)


def toy_car(name, x, y, z, rot, color, s=1.0, wheels=True):
    """Oyuncak araba: gövde + camlı kabin + tavan (+ teker). Boyu X ekseninde, rot derece döner."""
    body = mat(color, rough=0.45)
    box(name, (x, y, z + 0.18 * s), (1.8 * s, 0.85 * s, 0.42 * s), body, rot=rot, bevel=0.12 * s)
    kx, ky = _turn(x, y, rot, -0.12 * s, 0.0)
    box(name + "Cab", (kx, ky, z + 0.58 * s), (0.95 * s, 0.74 * s, 0.32 * s), mat("#BFE3F2", rough=0.2), rot=rot, bevel=0.1 * s)
    box(name + "Top", (kx, ky, z + 0.88 * s), (0.86 * s, 0.7 * s, 0.07 * s), body, rot=rot, bevel=0.02 * s)
    if wheels:
        tire = mat("#2A2A2E")
        for dx in (-0.55, 0.55):
            for dy in (-0.42, 0.42):
                wx, wy = _turn(x, y, rot, dx * s, dy * s)
                w = cyl(name + "W", (wx, wy, z), 0.2 * s, 0.16 * s, tire, segs=10)
                w.location.z = z + 0.2 * s
                w.rotation_euler = (math.radians(90), 0, math.radians(rot))   # aks aracın yan ekseninde


def wreck(name, x, y, z, rot, color):
    """Ezik hurda araba: basık gövde + çökmüş kabin, tekersiz."""
    rusty = mat(color, rough=0.9)
    box(name, (x, y, z), (1.9, 0.9, 0.36), rusty, rot=rot, bevel=0.1)
    kx, ky = _turn(x, y, rot, -0.15, 0.04)
    box(name + "Cab", (kx, ky, z + 0.36), (0.95, 0.78, 0.2), rusty, rot=rot + 4, bevel=0.06)


def tent(name, x, y, size, color, h=1.1):
    """Stant çadırı: dört ince direk + piramit tente."""
    pole = mat("#E9E4DA")
    for dx in (-1, 1):
        for dy in (-1, 1):
            box(name + "P", (x + dx * size * 0.42, y + dy * size * 0.42, 0.12), (0.08, 0.08, h), pole)
    roof = box(name + "Roof", (x, y, 0.12 + h), (size, size, 0.55 * size), mat(color))
    bm = bmesh.new()
    bm.from_mesh(roof.data)
    for v in bm.verts:   # üst yüz tek noktada toplanır
        if v.co.z > 0:
            v.co.x = v.co.y = 0.0
    bm.to_mesh(roof.data)
    bm.free()


def flag(name, x, y, color, h=2.4):
    box(name, (x, y, 0.1), (0.07, 0.07, h), mat("#E9E4DA"))
    box(name + "Cloth", (x + 0.38, y, h - 0.45), (0.7, 0.04, 0.42), mat(color))


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
    for k, (x, y, r, h) in enumerate([(-62, 22, 7, 7), (-38, 31, 5, 5), (-70, -8, 6, 6), (-20, -16, 4, 4),
                                      (-52, 40, 9, 9), (-86, 18, 8, 8)]):
        cyl("Mesa%d" % k, (x, y, 0), r, h * 0.55, rock_dark, segs=10, r2=r * 0.9)
        cyl("MesaB%d" % k, (x, y, h * 0.55), r * 0.9, h * 0.35, rock, segs=10, r2=r * 0.82)
        cyl("MesaT%d" % k, (x, y, h * 0.9), r * 0.82, 0.25, rock_top, segs=10)
    cactus = mat("#5E9A4A")
    for k in range(26):
        x, y = R.uniform(-100, -12), R.uniform(-18, 60)
        if abs(y - 3) < 5 and x > -50 or _near_new_places(x, y):
            continue
        cyl("Cactus%d" % k, (x, y, 0), 0.35, R.uniform(1.0, 2.0), cactus, segs=8)


def trees():
    leaf = [mat("#4E9A3E"), mat("#63AE47"), mat("#3E8A3A")]
    trunk = mat("#7A5434")
    for k in range(120):
        x, y = R.uniform(14, 108), R.uniform(-20, 68)
        if abs(x - CITY[0]) < 15 and abs(y - CITY[1]) < 11:
            continue
        if abs(y - 3.5) < 3 and x < 34 or _near_new_places(x, y, 1.0):
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
    """Şehir: asfalt ızgara sokaklar (yatay caddelerde kesik orta çizgi), basamaklı cam kuleler (kat bantları, çatıda
    helikopter pisti / su deposu / anten), pencere bantlı renkli çatılı alçak binalar, dükkân tenteleri, çeşmeli park,
    sokaklarda küçük arabalar; batı ucunda garajımız (sarı tabela, kepenkler, önünde araçlar), güneydoğu köşesinde
    sarı-siyah direkli SHOWROOM (oyundaki CAR PARTS & SHOWROOM pilonu)."""
    cx, cy = CITY
    box("CityBase", (cx, cy, 0.02), (30.5, 21.0, 0.12), mat("#DCD6CA"))
    asphalt, dash = mat("#7E7872"), mat("#F4EFE4")
    for gx in range(-3, 3):
        box("StreetV%d" % gx, (cx + (gx + 0.5) * 4.2, cy, 0.14), (1.05, 20.4, 0.02), asphalt)
    for gy in range(-2, 2):
        y = cy + (gy + 0.5) * 4.0
        box("StreetH%d" % gy, (cx, y, 0.14), (29.9, 1.05, 0.02), asphalt)
        for k in range(14):
            box("Dash%d_%d" % (gy, k), (cx - 14.0 + k * 2.15, y, 0.16), (0.7, 0.09, 0.01), dash)
    walls = [mat("#F4EFE4"), mat("#EADFCB"), mat("#D9E3EA"), mat("#F2E3C2"), mat("#F3D9CF")]
    roofs = [mat("#E2725B"), mat("#F2C14E"), mat("#6FA8DC"), mat("#9BC46B"), mat("#C9584A"), mat("#F5F1E6")]
    glass = [mat("#7FC8E8", rough=0.15), mat("#9FD6EA", rough=0.15), mat("#86B9D8", rough=0.15)]
    band, window = mat("#F4F7F8"), mat("#5E8FAF", rough=0.25)
    awnings = [mat("#D9483B"), mat("#3F9B6A"), mat("#F2C14E"), mat("#3F7FC1")]
    for gx in range(-3, 4):
        for gy in range(-2, 3):
            if (gx, gy) in ((1, -1), (1, 0), (3, -2)):
                continue   # park, showroom
            bx, by = cx + gx * 4.2, cy + gy * 4.0
            w, d = R.uniform(2.6, 3.1), R.uniform(2.4, 2.9)
            if abs(gx) <= 1 and abs(gy) <= 1 and R.random() < 0.75:
                _tower("T%d_%d" % (gx, gy), bx, by, w, d, R.uniform(5.0, 9.0), R.choice(glass), band)
            else:
                _low("L%d_%d" % (gx, gy), bx, by, w, d, R.uniform(1.4, 3.0), R.choice(walls), window, R.choice(roofs),
                     R.choice(awnings))
    # Park: çapraz yollar, ortada çeşme, kenarlarda ağaçlar
    px, py = cx + 4.2, cy - 2.0
    box("Park", (px, py, 0.1), (3.8, 7.6, 0.1), mat("#78B84E"))
    path_m = mat("#E8DCC0")
    box("ParkPathV", (px, py, 0.2), (0.4, 7.6, 0.02), path_m)
    box("ParkPathH", (px, py, 0.2), (3.8, 0.4, 0.02), path_m)
    cyl("Fountain", (px, py, 0.2), 0.75, 0.22, mat("#E9E4DA"), segs=18)
    cyl("FountainWater", (px, py, 0.42), 0.6, 0.02, mat("#5FC0DD", rough=0.15), segs=18)
    cyl("FountainJet", (px, py, 0.42), 0.12, 0.5, mat("#BFE9F5", rough=0.1), segs=8, r2=0.03)
    leaves = [mat("#4E9A3E"), mat("#63AE47")]
    for k, (dx, dy) in enumerate([(-1.3, 3.0), (1.3, 3.0), (-1.3, 1.2), (1.3, 1.2), (-1.3, -1.4), (1.3, -1.4),
                                  (-1.3, -3.1), (1.3, -3.1)]):
        blob("ParkTree%d" % k, (px + dx, py + dy, 0.95), 0.62, (1, 1, 1.05), R.choice(leaves), segs=8, rings=6)
    # SHOWROOM: camlı salon, koyu çatı, sarı alın bandı, sarı-siyah direk, önünde sergi arabası
    sx, sy = cx + 12.6, cy - 8.0
    box("ShowroomLot", (sx, sy, 0.1), (3.6, 3.2, 0.06), mat("#C9C4BA"))
    box("Showroom", (sx + 0.3, sy + 0.45, 0.16), (2.9, 2.0, 1.5), glass[0], bevel=0.05)
    box("ShowroomRoof", (sx + 0.3, sy + 0.45, 1.66), (3.1, 2.2, 0.22), mat("#2E3440"), bevel=0.04)
    box("ShowroomBand", (sx + 0.3, sy - 0.57, 1.25), (2.95, 0.06, 0.3), mat("#F2C14E"))
    box("Pylon", (sx - 1.35, sy - 1.0, 0.16), (0.45, 0.45, 3.6), mat("#23262B"), bevel=0.03)
    box("PylonFace", (sx - 1.35, sy - 1.24, 0.6), (0.3, 0.04, 2.9), mat("#F2C14E"))
    box("PylonCap", (sx - 1.35, sy - 1.0, 3.76), (0.62, 0.62, 0.12), mat("#F2C14E"))
    toy_car("ShowCar", sx + 0.6, sy - 1.05, 0.16, 12, "#D9483B", s=0.6)
    # Garajımız: batı ucunda, yol buraya bağlanır
    gx0, gy0 = cx - 17.6, cy - 1.0
    box("GarageApron", (gx0, gy0 - 0.6, 0.02), (5.2, 5.0, 0.12), mat("#CFC8BA"))
    box("Garage", (gx0, gy0 + 0.6, 0.12), (4.2, 3.0, 2.2), mat("#F3E8CF"), bevel=0.08)
    box("GarageRoof", (gx0, gy0 + 0.6, 2.32), (4.4, 3.2, 0.3), mat("#C24B3A"), bevel=0.05)
    for k in range(2):
        box("GarageDoor%d" % k, (gx0 - 1.0 + k * 2.0, gy0 - 0.93, 0.12), (1.5, 0.06, 1.45), mat("#8C8F94"))
    box("GarageSign", (gx0, gy0 - 1.0, 1.72), (2.8, 0.1, 0.5), mat("#F5BE4C"), bevel=0.02)
    toy_car("GarageCar0", gx0 - 1.1, gy0 - 2.2, 0.14, 95, "#D9483B", s=0.6)
    toy_car("GarageCar1", gx0 + 1.1, gy0 - 2.3, 0.14, 82, "#F4EFE4", s=0.6)
    # Sokakta arabalar (parka girmez)
    for k in range(18):
        gy = R.randrange(-2, 2)
        lane = R.choice([-0.25, 0.25])
        x, y = cx + R.uniform(-14.0, 14.0), cy + (gy + 0.5) * 4.0 + lane
        if gy == -1 and abs(x - px) < 2.3:
            continue
        toy_car("Traffic%d" % k, x, y, 0.15, 0 if lane < 0 else 180, R.choice(CAR_COLORS), s=0.4, wheels=False)
    for k in range(9):
        gx = R.randrange(-3, 3)
        lane = R.choice([-0.25, 0.25])
        x, y = cx + (gx + 0.5) * 4.2 + lane, cy + R.uniform(-9.5, 9.5)
        toy_car("TrafficV%d" % k, x, y, 0.15, 90 if lane > 0 else 270, R.choice(CAR_COLORS), s=0.4, wheels=False)


def _tower(name, x, y, w, d, h, glass, band):
    """Basamaklı cam kule: üç kademe, her katta beyaz bant, tepede çatı ayrıntısı."""
    z = 0.1
    for i, (k, part) in enumerate([(1.0, 0.55), (0.82, 0.3), (0.64, 0.15)]):
        hh, tw, td = h * part, w * k, d * k
        box("%s_%d" % (name, i), (x, y, z), (tw, td, hh), glass, bevel=0.05)
        f = z + 0.7
        while f < z + hh - 0.25:
            box("%s_b%d_%.1f" % (name, i, f), (x, y, f), (tw + 0.05, td + 0.05, 0.07), band)
            f += 0.9
        z += hh
    tw, td = w * 0.64, d * 0.64
    box(name + "_cap", (x, y, z), (tw + 0.1, td + 0.1, 0.12), band, bevel=0.03)
    z += 0.12
    r = R.random()
    if r < 0.35:   # helikopter pisti
        cyl(name + "_pad", (x, y, z), min(tw, td) * 0.42, 0.04, mat("#3A3F45"), segs=20)
        cyl(name + "_ring", (x, y, z + 0.04), min(tw, td) * 0.28, 0.02, mat("#F2C14E"), segs=20)
    elif r < 0.7:  # su deposu
        cyl(name + "_tank", (x + tw * 0.2, y, z), 0.35, 0.6, mat("#B5835A"), segs=10)
        cyl(name + "_tankcap", (x + tw * 0.2, y, z + 0.6), 0.38, 0.2, mat("#8A5E3E"), segs=10, r2=0.05)
    else:          # anten
        box(name + "_ant", (x, y, z), (0.08, 0.08, 1.4), mat("#C9584A"))


def _low(name, x, y, w, d, h, wall, window, roof, awning):
    """Alçak bina: pencere bantları, renkli çatı, çatıda klima; bazısında güneye bakan dükkân tentesi."""
    box(name, (x, y, 0.1), (w, d, h), wall, bevel=0.06)
    f = 0.75
    while f < h - 0.35:
        box(name + "_w%.1f" % f, (x, y, 0.1 + f), (w + 0.04, d + 0.04, 0.22), window)
        f += 0.85
    box(name + "_roof", (x, y, 0.1 + h), (w + 0.15, d + 0.15, 0.22), roof, bevel=0.04)
    if R.random() < 0.6:
        box(name + "_ac", (x + R.uniform(-0.6, 0.6), y + R.uniform(-0.5, 0.5), 0.32 + h), (0.5, 0.4, 0.28),
            mat("#C9CED3"), bevel=0.03)
    if R.random() < 0.55:
        box(name + "_awn", (x, y - d / 2 - 0.2, 0.72), (w * 0.8, 0.42, 0.08), awning)


def junkyard():
    """Hurdalık: oluklu sac çit (doğuda yol kapısı), üst üste ezik araç yığınları, lastik kuleleri, mıknatıslı vinç
    (ucunda asılı araba), pres + ezilmiş küpler, Necati'nin karavan ofisi ve varilleri (sonunda 1,3 kat)."""
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
    box("YardBase", (cx, cy, 0.02), (17.0, 12.0, 0.1), mat("#B88E5E"))
    ribbon("YardTrack", [(cx + 8.6, cy + 0.15), (cx + 4.5, cy + 0.3), (cx + 0.5, cy - 1.2), (cx - 4.5, cy - 0.6)], 1.5,
           0.13, mat("#A07C52"), smooth=6)
    # Oluklu sac çit: renkli paneller + direkler, doğu duvarında kapı (y = cy + 0.15)
    panels = [mat("#A35F38"), mat("#8E949B"), mat("#B8743F"), mat("#7D8389")]
    post = mat("#5E5A55")
    n = 12
    for side in (-1, 1):
        for i in range(n):
            x = cx - 8.5 + (i + 0.5) * 17.0 / n
            box("FenceH%d_%d" % (side, i), (x, cy + side * 6.0, 0.1), (17.0 / n - 0.06, 0.2, 1.15), panels[(i + side) % 4])
    m = 9
    for side in (-1, 1):
        for i in range(m):
            y = cy - 6.0 + (i + 0.5) * 12.0 / m
            if side == 1 and abs(y - (cy + 0.15)) < 1.4:
                continue   # kapı
            box("FenceV%d_%d" % (side, i), (cx + side * 8.5, y, 0.1), (0.2, 12.0 / m - 0.06, 1.15), panels[(i + 2 + side) % 4])
    for x, y in [(cx - 8.5, cy - 6.0), (cx + 8.5, cy - 6.0), (cx - 8.5, cy + 6.0), (cx + 8.5, cy + 6.0)]:
        box("FencePost", (x, y, 0.1), (0.3, 0.3, 1.35), post)
    yellow = mat("#E0A81E")
    for dy in (-1.45, 1.75):
        box("GatePost", (cx + 8.5, cy + dy, 0.1), (0.32, 0.32, 1.7), yellow)
    box("YardSign", (cx + 5.6, cy - 6.15, 1.1), (3.2, 0.12, 0.9), yellow, bevel=0.03)
    box("YardSignInk", (cx + 5.6, cy - 6.23, 1.3), (2.6, 0.04, 0.22), mat("#3A3F45"))
    for dx in (-1.2, 1.2):
        box("YardSignPost", (cx + 5.6 + dx, cy - 6.15, 0.1), (0.12, 0.12, 1.0), post)
    # Ezik araç yığınları
    faded = ["#7FA7A0", "#B9564A", "#D8CFA8", "#6E86A8", "#C9A04A", "#8C8C84", "#A8705A"]
    for k, (x, y, count, rot) in enumerate([(cx - 6.0, cy - 3.7, 3, 8), (cx - 3.4, cy - 4.1, 2, -12), (cx - 6.3, cy + 3.9, 3, 4),
                                             (cx - 3.6, cy + 4.2, 2, -8), (cx + 1.6, cy + 4.1, 3, 10), (cx + 4.0, cy + 4.0, 2, -6)]):
        for j in range(count):
            wreck("Wreck%d_%d" % (k, j), x + R.uniform(-0.15, 0.15), y + R.uniform(-0.1, 0.1), 0.12 + j * 0.58,
                  rot + R.uniform(-9, 9), R.choice(faded))
    # Lastik kuleleri (üstte koyu delik)
    tire, hole = mat("#2B2B2E"), mat("#4A3A2A")
    for k, (x, y, count) in enumerate([(cx + 6.4, cy - 4.3, 4), (cx + 7.3, cy - 3.2, 3), (cx - 7.3, cy - 0.4, 3),
                                        (cx + 5.6, cy - 3.0, 2), (cx - 7.2, cy + 0.8, 2)]):
        for j in range(count):
            cyl("Tire%d_%d" % (k, j), (x, y, 0.12 + j * 0.32), 0.46, 0.3, tire, segs=14)
        cyl("TireHole%d" % k, (x, y, 0.12 + count * 0.32), 0.22, 0.015, hole, segs=12)
    # Mıknatıslı vinç: paletli gövde, kabin, bom, kablo, mıknatıs, asılı araba
    dark = mat("#3A3F45")
    box("CraneTrack", (cx - 2.4, cy + 1.0, 0.1), (2.4, 2.0, 0.45), dark, bevel=0.1)
    box("CraneBody", (cx - 2.4, cy + 1.0, 0.55), (2.0, 1.7, 1.0), yellow, bevel=0.08)
    box("CraneCab", (cx - 2.9, cy + 0.4, 1.55), (0.9, 0.8, 0.8), mat("#BFE3F2", rough=0.2), bevel=0.05)
    boom = box("Boom", (cx - 0.4, cy + 1.0, 2.2), (4.6, 0.32, 0.32), yellow)
    boom.rotation_euler = (0, math.radians(-28), 0)
    tip_x, tip_z = cx - 0.4 + 2.3 * math.cos(math.radians(28)), 2.36 + 2.3 * math.sin(math.radians(28))
    box("Cable", (tip_x, cy + 1.0, 2.05), (0.05, 0.05, tip_z - 2.05), dark)
    cyl("Magnet", (tip_x, cy + 1.0, 1.85), 0.45, 0.2, dark, segs=16)
    wreck("Hanging", tip_x, cy + 1.0, 1.15, 20, "#B9564A")
    # Pres + ezilmiş küpler
    box("Press", (cx + 5.4, cy + 1.2, 0.1), (2.6, 2.0, 1.6), mat("#2F5C8A"), bevel=0.08)
    box("PressTop", (cx + 5.4, cy + 1.2, 1.7), (2.2, 1.6, 0.6), mat("#3E73A8"), bevel=0.06)
    box("PressStripe", (cx + 5.4, cy + 0.18, 0.85), (2.62, 0.04, 0.25), yellow)
    cubes = [mat("#8A4A2A"), mat("#6E5C4E"), mat("#A0623A"), mat("#5C6670"), mat("#B5893F")]
    for k in range(5):
        box("Cube%d" % k, (cx + 3.9 + (k % 3) * 0.85, cy - 0.8, 0.1 + (k // 3) * 0.75), (0.75, 0.75, 0.75),
            R.choice(cubes), rot=R.uniform(-8, 8))
    # Necati'nin karavan ofisi + variller
    ox, oy = cx + 1.6, cy - 4.4
    box("Office", (ox, oy, 0.1), (3.0, 1.5, 1.3), mat("#F3E8CF"), bevel=0.08)
    box("OfficeRoof", (ox, oy, 1.4), (3.2, 1.7, 0.12), mat("#C24B3A"))
    box("OfficeDoor", (ox - 0.8, oy - 0.77, 0.1), (0.5, 0.05, 0.95), mat("#8A5E3E"))
    box("OfficeWin", (ox + 0.5, oy - 0.77, 0.6), (1.0, 0.05, 0.4), mat("#7FC8E8", rough=0.2))
    for k, (dx, dy, c) in enumerate([(2.0, 0.3, "#2F6FB3"), (2.55, 0.1, "#C24B3A"), (2.25, -0.4, "#2F6FB3")]):
        cyl("Barrel%d" % k, (ox + dx, oy + dy, 0.1), 0.26, 0.7, mat(c), segs=12)
    # Arka tarafta dağınık hurda tepecikleri
    rust = [mat("#8A4A2A"), mat("#6E5C4E"), mat("#A0623A"), mat("#5C6670")]
    for k, (x, y) in enumerate([(cx - 1.0, cy + 4.6), (cx + 6.6, cy + 4.4), (cx - 7.0, cy + 2.4), (cx + 0.2, cy - 2.6)]):
        blob("Junk%d" % k, (x, y, -0.3), R.uniform(0.9, 1.3), (1.2, 1.0, 0.7), R.choice(rust), segs=7, rings=5)


def meet():
    """OTO ŞOV (YAKINDA, gri maket): çölde asfalt araç sergisi / buluşma alanı — park çizgili iki sıra araba, ortada döner
    sergi platformunda bir araba, güneyde giriş takı, tenteli stantlar, bayraklar, yemek kamyoneti, ışık direkleri
    (sonunda 1,2 kat)."""
    before = set(bpy.data.objects)
    _meet_parts()
    mx, my = MEET
    for o in set(bpy.data.objects) - before:
        o.location.x = mx + (o.location.x - mx) * 1.2
        o.location.y = my + (o.location.y - my) * 1.2
        o.location.z *= 1.2
        o.scale = o.scale * 1.2


def _meet_parts():
    mx, my = MEET
    box("MeetCurb", (mx, my, 0.0), (19.6, 12.1, 0.1), mat("#D9D2C2"))
    box("MeetLot", (mx, my, 0.02), (19.0, 11.5, 0.12), mat("#6B625A"))
    line = mat("#F4EFE4")
    for row, ry, rot in ((0, my + 3.5, 90), (1, my - 3.3, 270)):
        for i in range(8):
            x = mx - 7.7 + i * 2.2
            box("MeetLine%d_%d" % (row, i), (x - 1.1, ry, 0.14), (0.08, 2.4, 0.01), line)
            if row == 1 and i in (3, 4):
                continue   # giriş yolu
            toy_car("MeetCar%d_%d" % (row, i), x, ry, 0.14, rot + R.uniform(-4, 4), R.choice(CAR_COLORS), s=0.8)
    cyl("Turntable", (mx, my + 0.1, 0.14), 2.0, 0.25, mat("#E9E4DA"), segs=28)
    cyl("TurntableTop", (mx, my + 0.1, 0.39), 1.75, 0.1, mat("#C24B3A"), segs=28)
    toy_car("ShowcaseCar", mx, my + 0.1, 0.49, 25, "#F2C14E", s=1.05)
    tent("MeetTent0", mx - 7.6, my + 0.2, 2.1, "#D9483B")
    tent("MeetTent1", mx + 7.6, my + 0.2, 2.1, "#3F7FC1")
    tent("MeetTent2", mx - 4.9, my + 0.2, 1.6, "#F2C14E")
    box("FoodTruck", (mx + 4.8, my + 0.2, 0.14), (2.4, 1.2, 1.2), mat("#F4EFE4"), bevel=0.1)
    box("FoodTruckCab", (mx + 6.2, my + 0.2, 0.14), (0.6, 1.1, 0.9), mat("#D9483B"), bevel=0.08)
    box("FoodTruckWin", (mx + 4.6, my - 0.42, 0.7), (1.4, 0.04, 0.4), mat("#3A3F45"))
    for dx in (-2.2, 2.2):
        box("MeetGate", (mx + dx, my - 5.9, 0.1), (0.35, 0.35, 2.5), mat("#C24B3A"))
    box("MeetGateBeam", (mx, my - 5.9, 2.6), (5.0, 0.35, 0.55), mat("#F2C14E"), bevel=0.04)
    for k, (dx, dy, c) in enumerate([(-3.0, -5.9, "#D9483B"), (3.0, -5.9, "#3F7FC1"), (-9.3, 5.6, "#F2C14E"),
                                      (9.3, 5.6, "#4FA46A"), (-9.3, -5.6, "#3F7FC1"), (9.3, -5.6, "#D9483B")]):
        flag("MeetFlag%d" % k, mx + dx, my + dy, c)
    for k, (dx, dy) in enumerate([(-9.6, 0.0), (9.6, 0.0), (0.0, 5.9)]):
        box("MeetLamp%d" % k, (mx + dx, my + dy, 0.1), (0.1, 0.1, 3.2), mat("#5E5A55"))
        box("MeetLampHead%d" % k, (mx + dx, my + dy, 3.3), (0.7, 0.3, 0.15), mat("#5E5A55"))


def port():
    """LİMAN (YAKINDA, gri maket): kıyıdan denize uzanan beton rıhtım, iki portal vinç, konteyner yığınları, rıhtıma
    yanaşmış araç taşıyıcı gemi (rampası inik), sıra sıra yeni gelmiş arabalar, depo binası."""
    px, py = PORT
    box("Quay", (px, py - 1.0, -1.4), (24.0, 10.4, 1.75), mat("#C9C4BA"))   # üst yüz z = 0.35
    box("QuayEdge", (px, py - 6.05, 0.35), (24.0, 0.3, 0.06), mat("#F2C14E"))
    for k in range(9):
        cyl("Bollard%d" % k, (px - 11.0 + k * 2.75, py - 5.8, 0.35), 0.13, 0.25, mat("#3A3F45"), segs=8)
    # Konteyner gemisi (rıhtımın güneyinde): sivri burunlu gövde, güvertede konteyner sıraları, kıçta köprü + baca
    sy = py - 8.5
    hull = box("ShipHull", (px + 0.5, sy, -0.7), (19.0, 4.2, 1.9), mat("#2F5C8A"), bevel=0.2)
    bm = bmesh.new()
    bm.from_mesh(hull.data)
    for v in bm.verts:   # burun (batı ucu) sivrilir
        if v.co.x < -9.0:
            v.co.y *= 0.2
            v.co.x -= 1.2
    bm.to_mesh(hull.data)
    bm.free()
    box("ShipDeck", (px + 0.5, sy, 1.2), (18.4, 3.9, 0.1), mat("#C24B3A"))
    cont = ["#C24B3A", "#3F7FC1", "#F2C14E", "#4FA46A", "#E8833A", "#F4EFE4"]
    for i in range(6):
        for j in range(3):
            for k in range(R.randint(1, 2)):
                box("ShipBox%d_%d_%d" % (i, j, k), (px - 6.8 + i * 2.15, sy - 1.2 + j * 1.2, 1.3 + k * 0.9),
                    (2.0, 1.1, 0.9), mat(R.choice(cont)), bevel=0.03)
    box("ShipBridge", (px + 7.9, sy, 1.3), (2.0, 3.6, 2.6), mat("#F4EFE4"), bevel=0.08)
    box("ShipBridgeWin", (px + 7.9, sy - 1.82, 3.3), (1.8, 0.04, 0.35), mat("#3A3F45"))
    cyl("ShipFunnel", (px + 8.4, sy + 0.5, 3.9), 0.45, 1.1, mat("#C24B3A"), segs=12)
    # Konteyner yığınları (rıhtımın kuzeybatısı)
    cont = ["#C24B3A", "#3F7FC1", "#F2C14E", "#4FA46A", "#E8833A"]
    for i in range(4):
        for j in range(2):
            for k in range(R.randint(1, 3)):
                box("Container%d_%d_%d" % (i, j, k), (px - 9.6 + i * 2.8, py + 2.6 - j * 1.25, 0.35 + k * 1.0), (2.6, 1.1, 1.0),
                    mat(R.choice(cont)), bevel=0.03)
    # Yeni gelmiş arabalar (rıhtımın doğusunda sıra sıra)
    for r in range(3):
        for c in range(6):
            toy_car("PortCar%d_%d" % (r, c), px + 1.6 + c * 1.55, py + 1.2 - r * 1.6, 0.35, 90, R.choice(CAR_COLORS), s=0.62)
    # Portal vinçler: bacakları rıhtımda, ince kafes kolu gemiye uzanır
    orange = mat("#E8833A")
    for k, vx in enumerate((px - 6.6, px - 1.2)):
        for dx in (-1.1, 1.1):
            for dy in (-5.4, -2.6):
                box("CraneLeg%d" % k, (vx + dx, py + dy, 0.35), (0.26, 0.26, 4.6), orange)
            box("CraneRail%d" % k, (vx + dx, py - 5.6, 4.95), (0.24, 9.0, 0.3), orange)
        for dy in (-9.6, -6.8, -4.0, -1.4):
            box("CraneTie%d" % k, (vx, py + dy, 4.95), (2.4, 0.2, 0.25), orange)
        box("CraneCab%d" % k, (vx, py - 7.6, 4.25), (0.9, 0.9, 0.7), mat("#F4EFE4"), bevel=0.05)
        box("CraneCable%d" % k, (vx, py - 8.8, 2.4), (0.05, 0.05, 2.5), mat("#3A3F45"))
    # Depo binası
    box("Warehouse", (px + 7.6, py + 2.8, 0.35), (6.2, 2.4, 2.0), mat("#D9D4CA"), bevel=0.06)
    box("WarehouseRoof", (px + 7.6, py + 2.8, 2.35), (6.4, 2.6, 0.25), mat("#6FA8DC"), bevel=0.04)
    for k in range(3):
        box("WarehouseDoor%d" % k, (px + 5.6 + k * 2.0, py + 1.57, 0.35), (1.3, 0.05, 1.3), mat("#8C8F94"))


def side_roads():
    """YAKINDA mekânlarına giden yan yollar (gri)."""
    for name, pts in (("MeetRoad", MEET_ROAD), ("PortRoad", PORT_ROAD)):
        ribbon(name, pts, 1.6, 0.075, mat("#9A948C"), smooth=8)
        ribbon(name + "Edge", pts, 2.1, 0.055, mat("#C8BFAE"), smooth=8)


def _near_new_places(x, y, pad=0.0):
    """Ağaç / kaktüs / ev buraya konmasın: garaj önü, YAKINDA mekânları ve yan yolları."""
    if abs(x - MEET[0]) < 12.5 + pad and abs(y - MEET[1]) < 8.5 + pad:
        return True
    if PORT[0] - 15 - pad < x < PORT[0] + 15 + pad and -38 < y < PORT[1] + 6 + pad:
        return True
    if 15 < x < 25 + pad and -1 - pad < y < 9 + pad:
        return True
    for pts in (MEET_ROAD, PORT_ROAD):
        for (ax, ay), (bx, by) in zip(pts, pts[1:]):
            for t in (0.0, 0.25, 0.5, 0.75, 1.0):
                if math.hypot(x - (ax + (bx - ax) * t), y - (ay + (by - ay) * t)) < 2.6 + pad:
                    return True
    return False


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
        if abs(y - 3.5) < 3 and x < CITY[0] or _near_new_places(x, y, 1.0):
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
    for k, (bx, by, rot) in enumerate([(-32, -36, 20), (18, -34, -15), (22, -43, 40), (-8, -44, -60)]):
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
        if abs(x - PORT[0]) < 26 and y < -18:
            x = PORT[0] + 26 + abs(x - PORT[0])   # LİMAN bulutun altında kalmasın
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
    cam.location = (-2.0, 6.0 - math.sin(tilt) * 200.0, math.cos(tilt) * 200.0)
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
    side_roads()
    with greyed():
        meet()
        port()
    extras()
    clouds()
    cam = camera_light()
    os.makedirs(OUT_DIR, exist_ok=True)
    scn = bpy.context.scene
    scn.render.filepath = os.path.join(OUT_DIR, "world_map.png") if not PREVIEW else "/home/burak/Projects/ct_shots/map_preview.png"
    scn.render.image_settings.file_format = 'PNG'
    scn.render.image_settings.color_mode = 'RGB'   # saydamlık yok: alfa kanalı boşuna yer tutmasın
    bpy.ops.render.render(write_still=True)
    data = {
        "_readme": "tools/world/map_render.py üretir. Konumlar ekran oranı (0..1), sol üst köşe başlangıç.",
        "places": {
            "city": screen_point(cam, CITY[0], CITY[1], 6.0),
            "junkyard": screen_point(cam, JUNKYARD[0], JUNKYARD[1], 2.0),
            "meet": screen_point(cam, MEET[0], MEET[1], 2.0),
            "port": screen_point(cam, PORT[0], PORT[1], 3.0),
        },
        "route": [screen_point(cam, x, y, 0.1) for (x, y) in path[::3]] + [screen_point(cam, *path[-1], 0.1)],
    }
    if not PREVIEW:
        with open(os.path.join(OUT_DIR, "world_map.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    print("HARİTA", scn.render.filepath, data["places"])


main()
