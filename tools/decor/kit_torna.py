"""Ek dekor yardımcıları — torna (lathe), yerel grup, eğri yüzey, boru, elips silindir, kırık çizgi çubuk.

kit.py'den SONRA yüklenir; props_v11+ betikleri başta şöyle çağırır (run_bpy.py kapsamına __file__ koyar):
    exec(open(os.path.join(os.path.dirname(__file__), "kit_torna.py"), encoding="utf-8").read())
Kurallar kit.py ile aynı: metre, ÖN = −Y, Z yukarı, orijin tabanın ortası.
"""
import math as _m

import bmesh
import mathutils


def _obj_from_bm(bm, name, material):
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    col().objects.link(o)
    return _place(o, material)


def lathe(profile, material, loc=(0.0, 0.0, 0.0), seg=24, smooth=True, closed=False):
    """(yarıçap, yükseklik) hattını Z çevresinde döndürür. closed=True: hat kapalı halka, kapak yok; değilse
    uçlardaki yarıçap > 0 ise kapak."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        rings.append([bm.verts.new((loc[0] + r * _m.cos(2 * _m.pi * k / seg), loc[1] + r * _m.sin(2 * _m.pi * k / seg),
                                    loc[2] + z)) for k in range(seg)])
    n = len(rings)
    for i in range(n if closed else n - 1):
        a, b = rings[i], rings[(i + 1) % n]
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((a[k], a[j], b[j], b[k]))
            f.smooth = smooth
    if not closed:
        if profile[0][0] > 0.0:
            bm.faces.new(list(reversed(rings[0])))
        if profile[-1][0] > 0.0:
            bm.faces.new(rings[-1])
    return _obj_from_bm(bm, "torna", material)


def local(build, loc=(0.0, 0.0, 0.0), yaw=0.0, pitch=0.0, roll=0.0, scale=1.0):
    """build() içinde kurulan parçaları birlikte döndürüp taşır (yaw: Z, pitch: X, roll: Y çevresinde)."""
    before = {o.name for o in col().objects}
    build()
    m = (mathutils.Matrix.Translation(loc) @ mathutils.Matrix.Rotation(yaw, 4, 'Z')
         @ mathutils.Matrix.Rotation(roll, 4, 'Y') @ mathutils.Matrix.Rotation(pitch, 4, 'X')
         @ mathutils.Matrix.Scale(scale, 4))
    for o in col().objects:
        if o.name not in before:
            o.matrix_world = m @ o.matrix_world


def solidify(o, t):
    """Yüzeye kalınlık verir (değiştiriciyi uygular)."""
    mod = o.modifiers.new("kalinlik", 'SOLIDIFY')
    mod.thickness = t
    mod.offset = 0.0
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def sheet(fn, x0, x1, y0, y1, nx, ny, material, t=0.0):
    """z = fn(x, y) eğri yüzey (hamak bezi, perde): nx × ny göz; t > 0 ise kalınlık."""
    bm = bmesh.new()
    grid = [[bm.verts.new((x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny,
                           fn(x0 + (x1 - x0) * i / nx, y0 + (y1 - y0) * j / ny)))
             for j in range(ny + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(ny):
            f = bm.faces.new((grid[i][j], grid[i + 1][j], grid[i + 1][j + 1], grid[i][j + 1]))
            f.smooth = True
    o = _obj_from_bm(bm, "yuzey", material)
    return solidify(o, t) if t > 0.0 else o


def sheet_xz(fn, x0, x1, z0, z1, nx, nz, material, t=0.0):
    """y = fn(x, z) dik yüzey (önden bakan perde / bayrak dalgası): nx × nz göz."""
    bm = bmesh.new()
    grid = [[bm.verts.new((x0 + (x1 - x0) * i / nx, fn(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz),
                           z0 + (z1 - z0) * j / nz)) for j in range(nz + 1)] for i in range(nx + 1)]
    for i in range(nx):
        for j in range(nz):
            f = bm.faces.new((grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]))
            f.smooth = True
    o = _obj_from_bm(bm, "perde", material)
    return solidify(o, t) if t > 0.0 else o


def tube(path, radius, material, seg=12, caps=False, smooth=True):
    """Yol boyunca boru: path 3B noktalar; radius sayı ya da f(i, n) (nokta başına yarıçap). Halkalar yola dik."""
    pts = [mathutils.Vector(p) for p in path]
    n = len(pts)
    bm = bmesh.new()
    rings = []
    for i in range(n):
        t = (pts[min(i + 1, n - 1)] - pts[max(i - 1, 0)]).normalized()
        up = mathutils.Vector((0.0, 0.0, 1.0)) if abs(t.z) < 0.9 else mathutils.Vector((1.0, 0.0, 0.0))
        n1 = (up - t * up.dot(t)).normalized()
        n2 = t.cross(n1)
        r = radius(i, n) if callable(radius) else radius
        rings.append([bm.verts.new(pts[i] + r * (_m.cos(2 * _m.pi * k / seg) * n1 + _m.sin(2 * _m.pi * k / seg) * n2))
                      for k in range(seg)])
    for i in range(n - 1):
        a, b = rings[i], rings[i + 1]
        for k in range(seg):
            j = (k + 1) % seg
            f = bm.faces.new((a[k], a[j], b[j], b[k]))
            f.smooth = smooth
    if caps:
        bm.faces.new(list(reversed(rings[0])))
        bm.faces.new(rings[-1])
    return _obj_from_bm(bm, "boru", material)


def ecyl(rx, ry, h, loc, material, seg=24, rot=(0.0, 0.0, 0.0)):
    """Elips tabanlı silindir (yerel Z ekseni boyunca h)."""
    o = cyl(1.0, h, (0.0, 0.0, 0.0), material, seg=seg)
    o.scale = (rx, ry, 1.0)
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.rotation_euler = rot
    o.location = loc
    return o


def branch(points, r0, r1, material, seg=8):
    """Kırık çizgi dal / gövde: uçtan uca incelen çubuklar + eklemlerde top (boşluk kalmasın)."""
    n = len(points)
    for i in range(n - 1):
        ra = r0 + (r1 - r0) * i / max(n - 1, 1)
        rod(points[i], points[i + 1], ra, material, seg=seg)
        if i > 0:
            ball(ra, points[i], material, seg=seg, ring=5)


print("kit_torna yuklendi")
