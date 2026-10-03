"""Şehir bitkileri — Car Town tarzı dolgun ağaçlar, çamlar, çalılar. assets/world/veg_*.glb yazar.

Kullanım: python3 tools/decor/blender_send.py tools/world/vegetation.py   (canlı Blender)
      ya da: blender -b --factory-startup --python tools/world/vegetation.py
Kullanıcının sahnesine dokunmaz ("Vegetation" sahnesi). Birim metre, orijin gövde tabanı.
Taçlar birkaç yumrudan oluşur; her yumruda alt yarı KOYU, üst yarı AÇIK yeşil (üstten güneş
alıyormuş gibi okunur), köşeler hafif rastgele itilir (düzgün top gibi durmasın).
"""
import bpy, bmesh, math, os, random

OUT = "/home/burak/Projects/car-town-remake/assets/world"
SCENE = "Vegetation"
COLL = "VegLot"
_M = {}


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def mat(name, hexcol, rough=0.85):
    if name in _M:
        return _M[name]
    m = bpy.data.materials.get("VG_" + name) or bpy.data.materials.new("VG_" + name)
    m.use_nodes = True
    b = next(n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    c = srgb(hexcol)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    _M[name] = m
    return m


def scene():
    scn = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    if bpy.context.window:   # canlı oturum; arka planda (blender -b) pencere yok
        bpy.context.window.scene = scn
    else:
        scn = bpy.context.scene
    col = bpy.data.collections.get(COLL) or bpy.data.collections.new(COLL)
    if col.name not in scn.collection.children:
        scn.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return col


def _obj(bm, name, mats):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.data.collections[COLL].objects.link(o)
    for m in mats:
        o.data.materials.append(m)
    return o


def blob(bm, center, radius, squash, rng, subdiv=2, jitter=0.12):
    """Yumru: ikosfer, köşeler rastgele itilir; alt yarı malzeme 0 (koyu), üst yarı 1 (açık)."""
    ret = bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    verts = ret["verts"]
    for v in verts:
        n = v.co.normalized()
        k = 1.0 + rng.uniform(-jitter, jitter)
        v.co = n * radius * k
        v.co.z *= squash
        v.co += center
    faces = {f for v in verts for f in v.link_faces}
    for f in faces:
        f.material_index = 1 if f.calc_center_median().z > center.z - radius * squash * 0.05 else 0
    return faces


def trunk(bm, h, r, lean=0.0):
    ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=r, radius2=r * 0.7, depth=h)
    for v in ret["verts"]:
        v.co.z += h / 2
        v.co.x += lean * (v.co.z / h)
    for f in {f for v in ret["verts"] for f in v.link_faces}:
        f.material_index = 2


def round_tree(name, seed, height, spread):
    import mathutils
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, height * 0.5, 0.22, rng.uniform(-0.2, 0.2))
    V = mathutils.Vector
    blob(bm, V((0, 0, height * 0.62)), spread, 0.85, rng)
    for i in range(5):
        a = i / 5 * math.tau + rng.uniform(-0.3, 0.3)
        d = spread * rng.uniform(0.45, 0.7)
        blob(bm, V((math.cos(a) * d, math.sin(a) * d, height * rng.uniform(0.52, 0.72))),
             spread * rng.uniform(0.55, 0.72), 0.85, rng)
    blob(bm, V((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), height * 0.86)), spread * 0.62, 0.85, rng)
    return _obj(bm, name, [mat("leaf_dark", "#3F8A34"), mat("leaf_light", "#6DB847"), mat("bark", "#7A5334")])


def pine(name, seed, height):
    import mathutils
    rng = random.Random(seed)
    bm = bmesh.new()
    trunk(bm, height * 0.3, 0.2)
    tiers = 4
    for t in range(tiers):
        f = t / tiers
        r = (1.0 - f) * height * 0.26 + 0.35
        z0 = height * (0.2 + f * 0.62)
        ret = bmesh.ops.create_cone(bm, cap_ends=True, segments=8, radius1=r, radius2=0.05,
                                    depth=height * 0.34)
        for v in ret["verts"]:
            v.co.z += z0 + height * 0.17
            v.co.x += rng.uniform(-0.06, 0.06)
            v.co.y += rng.uniform(-0.06, 0.06)
        for fc in {fc for v in ret["verts"] for fc in v.link_faces}:
            fc.material_index = 1 if fc.normal.z > 0.35 else 0
    return _obj(bm, name, [mat("pine_dark", "#2F6B3A"), mat("pine_light", "#4E9A4E"), mat("bark", "#7A5334")])


def bush(name, seed, size):
    import mathutils
    rng = random.Random(seed)
    bm = bmesh.new()
    V = mathutils.Vector
    for i in range(4):
        a = i / 4 * math.tau + rng.uniform(-0.4, 0.4)
        d = size * 0.35
        r = size * rng.uniform(0.42, 0.55)
        blob(bm, V((math.cos(a) * d, math.sin(a) * d, r * 0.7)), r, 0.8, rng, subdiv=1, jitter=0.1)
    blob(bm, V((0, 0, size * 0.55)), size * 0.5, 0.8, rng, subdiv=1, jitter=0.1)
    return _obj(bm, name, [mat("leaf_dark", "#3F8A34"), mat("leaf_light", "#6DB847")])


def flower_bush(name, seed, size):
    o = bush(name, seed, size)
    return o


def export(o):
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    path = os.path.join(OUT, o.name + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format='GLB', use_selection=True, use_active_scene=True,
                              export_apply=True, export_yup=True, export_cameras=False, export_lights=False)
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    print("%s: %d ucgen, %.0f KB" % (o.name, tris, os.path.getsize(path) / 1024))


scene()
os.makedirs(OUT, exist_ok=True)
objs = [round_tree("veg_tree_a", 3, 7.5, 2.3), round_tree("veg_tree_b", 11, 6.2, 1.9),
        pine("veg_pine", 5, 8.5), bush("veg_bush", 7, 1.6)]
for i, o in enumerate(objs):
    export(o)
    o.location.x = i * 7.0
