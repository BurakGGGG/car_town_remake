"""CAR PARTS & SHOWROOM binası — Blender'da baştan kurulur, assets/world/showroom.glb yazılır.

Kullanım (canlı Blender oturumu, blender-mcp eklentisi 127.0.0.1:9876):
    python3 tools/decor/blender_send.py tools/world/showroom.py

Kullanıcının açık sahnesine dokunulmaz: "Showroom" adlı AYRI bir sahnede çalışılır.

Birim METRE; oyunda kök düğüm DecorBuilder.METER (0,1367) ile ölçeklenir (araç 4,4 m = 0,6 birim).
Blender eksenleri: X doğu, Y kuzey, Z yukarı. glTF'e +Y yukarı çevrilir: Blender (x, y, z) →
Godot (x, z, -y). Orijin = parselin GÜNEYBATI köşesi, yol seviyesi (kavşağın kuzeydoğusu).
Kamera parseli güneydoğudan (+x, +z) görür: vitrinler güney ve doğu cephede.

Yerleşim (metre, parsel 52 × 42):
    güney şerit   Y 0–11  : giriş meydanı (batı), otopark (doğu), bayraklar, köşe totemi
    CAR PARTS     X 3–15, Y 13–33 : dolu duvarlı blok, iki kepenkli servis kapısı
    SHOWROOM      X 15–41, Y 13–33 : güney ve doğu cephesi cam, içeride iki sergi aracı
    açık sergi    X 43–48, Y 13–32 : üç araç platformu
    çevre         kuzey / doğu / batı çim şeritleri, ağaçlar, çit
Tabelaların YAZISI Godot'ta Label3D ile oyunun yazı tipinde (world/world_dressing.gd); burada
yalnızca levha yüzeyleri var.
"""
import bpy, bmesh, math, os

OUT = "/home/burak/Projects/car-town-remake/assets/world/showroom.glb"
SCENE = "Showroom"
COLL = "ShowroomLot"
_MATS = {}


# --- Kurulum -----------------------------------------------------------------------------

def srgb(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def use_scene():
    scn = bpy.data.scenes.get(SCENE)
    if scn is None:
        scn = bpy.data.scenes.new(SCENE)
    bpy.context.window.scene = scn
    col = bpy.data.collections.get(COLL)
    if col is None:
        col = bpy.data.collections.new(COLL)
    if col.name not in scn.collection.children:
        scn.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    return col


def mat(name, hexcol, rough=0.75, metal=0.0, alpha=1.0, emit=None, strength=2.0):
    if name in _MATS:
        return _MATS[name]
    m = bpy.data.materials.get("SR_" + name) or bpy.data.materials.new("SR_" + name)
    m.use_nodes = True
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    c = srgb(hexcol)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    m.diffuse_color = (c[0], c[1], c[2], alpha)   # Blender'ın katı görünümünde de renkli görünsün
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        e = srgb(emit)
        b.inputs["Emission Color"].default_value = (e[0], e[1], e[2], 1.0)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        try:
            m.blend_method = 'BLEND'
        except Exception:
            pass
    _MATS[name] = m
    return m


def _link(o, material):
    for c in list(o.users_collection):
        c.objects.unlink(o)
    bpy.data.collections[COLL].objects.link(o)
    o.data.materials.clear()
    o.data.materials.append(material)
    return o


def _bevel(o, width, segments=2):
    if width <= 0.0:
        return o
    bpy.ops.object.select_all(action='DESELECT')
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    mod = o.modifiers.new("Bevel", 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    bpy.ops.object.modifier_apply(modifier=mod.name)
    return o


def box(x0, x1, y0, y1, z0, z1, material, bevel=0.0, seg=2):
    """Eksene hizalı kutu, köşe koordinatlarıyla (metre)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2))
    o = bpy.context.object
    o.scale = (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0))
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    _link(o, material)
    return _bevel(o, bevel, seg)


def box_at(size, loc, material, rot_z=0.0, bevel=0.0, seg=2):
    """Merkez + boyut + Z dönüşü (derece)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=(0.0, 0.0, math.radians(rot_z)))
    o = bpy.context.object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    _link(o, material)
    return _bevel(o, bevel, seg)


def cyl(r, z0, z1, x, y, material, seg=16, r_top=None):
    if r_top is None:
        bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=z1 - z0, vertices=seg,
                                            location=(x, y, (z0 + z1) / 2))
    else:
        bpy.ops.mesh.primitive_cone_add(radius1=r, radius2=r_top, depth=z1 - z0, vertices=seg,
                                        location=(x, y, (z0 + z1) / 2))
    return _link(bpy.context.object, material)


def ball(r, loc, material, scale=(1.0, 1.0, 1.0), subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(radius=r, subdivisions=subdiv, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _link(o, material)


def rounded_slab(x0, x1, y0, y1, z0, z1, radius, material, seg=6):
    """Köşeleri yuvarlatılmış yatay levha (yüzen çatı)."""
    bm = bmesh.new()
    vs = [bm.verts.new((x0, y0, z0)), bm.verts.new((x1, y0, z0)),
          bm.verts.new((x1, y1, z0)), bm.verts.new((x0, y1, z0))]
    bm.faces.new(vs)
    bmesh.ops.bevel(bm, geom=vs, offset=radius, segments=seg, affect='VERTICES', profile=0.5)
    bm.faces.ensure_lookup_table()
    face = bm.faces[0]
    ret = bmesh.ops.extrude_face_region(bm, geom=[face])
    top = [g for g in ret["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=top, vec=(0.0, 0.0, z1 - z0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new("slab")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("slab", me)
    bpy.data.collections[COLL].objects.link(o)
    o.data.materials.append(material)
    return o


# --- Malzemeler (oyunun paleti: krem, kehribar, mürekkep) ----------------------------------

def materials():
    return {
        "paver": mat("paver", "#D8D2C4", 0.9),
        "asphalt": mat("asphalt", "#4B4B50", 0.95),
        "line": mat("line", "#F4F3EE", 0.8),
        "lawn": mat("lawn", "#7DB04C", 0.95),
        "wall": mat("wall", "#F3F1EC", 0.8),
        "cream": mat("cream", "#EDE2C8", 0.85),
        "roof": mat("roof", "#F8F7F3", 0.7),
        "ink": mat("ink", "#2A2E35", 0.55, 0.3),
        "glass": mat("glass", "#B4E0EF", 0.05, 0.0, 0.24),
        "window": mat("window", "#34414F", 0.15, 0.4),
        "floor": mat("floor", "#E9E6DF", 0.35),
        "amber": mat("amber", "#F5BE4C", 0.55),
        "led": mat("led", "#FFF1CF", 0.4, 0.0, 1.0, "#FFE3A8", 3.0),
        "steel": mat("steel", "#C4C8CE", 0.35, 0.8),
        "leaf": mat("leaf", "#5A9A42", 0.9),
        "leaf2": mat("leaf2", "#6DAE4C", 0.9),
        "trunk": mat("trunk", "#7C5536", 0.9),
        "shutter": mat("shutter", "#B9BDC3", 0.6, 0.4),
        "red": mat("car_red", "#D8362E", 0.35, 0.2),
        "white": mat("car_white", "#F1F1ED", 0.35, 0.1),
        "blue": mat("car_blue", "#2F6ED0", 0.35, 0.2),
        "tyre": mat("tyre", "#1D1E21", 0.8),
        "tail": mat("tail", "#B8231D", 0.4),
    }


# --- Parçalar ------------------------------------------------------------------------------

def car(M, x, y, heading, paint):
    """Sergi aracı: sade, düşük poligonlu ama araç gibi okunan siluet. İleri = +X (heading derece)."""
    parts = []
    parts.append(box_at((4.3, 1.82, 0.62), (0.0, 0.0, 0.66), paint, bevel=0.14, seg=2))
    cabin = box_at((2.4, 1.64, 0.52), (-0.25, 0.0, 1.23), M["window"], bevel=0.05, seg=1)
    # Cam kabin: üstü öne-arkaya ve yanlara daralır (ön cam eğimi, tavan kavisi)
    for v in cabin.data.vertices:
        if v.co.z > 1.2:
            v.co.x = v.co.x * 0.7 - 0.1
            v.co.y = v.co.y * 0.86
    parts.append(cabin)
    parts.append(box_at((1.62, 1.42, 0.1), (-0.42, 0.0, 1.52), paint, bevel=0.04, seg=1))
    parts.append(box_at((4.34, 1.86, 0.14), (0.0, 0.0, 0.42), M["tyre"], bevel=0.05, seg=1))
    for sx in (-1.38, 1.38):
        for sy in (-0.84, 0.84):
            bpy.ops.mesh.primitive_cylinder_add(radius=0.35, depth=0.28, vertices=14,
                                                location=(sx, sy, 0.35), rotation=(math.radians(90), 0, 0))
            parts.append(_link(bpy.context.object, M["tyre"]))
            bpy.ops.mesh.primitive_cylinder_add(radius=0.19, depth=0.3, vertices=10,
                                                location=(sx, sy, 0.35), rotation=(math.radians(90), 0, 0))
            parts.append(_link(bpy.context.object, M["steel"]))
    for sy in (-0.6, 0.6):
        parts.append(box_at((0.06, 0.34, 0.12), (2.16, sy, 0.78), M["led"]))
        parts.append(box_at((0.06, 0.36, 0.1), (-2.16, sy, 0.8), M["tail"]))
    bpy.ops.object.select_all(action='DESELECT')
    for p in parts:
        p.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    o = bpy.context.object
    o.rotation_euler = (0.0, 0.0, math.radians(heading))
    o.location = (x, y, 0.0)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=False)
    return o


def tree(M, x, y, h=6.5, r=2.0, alt=False):
    cyl(0.22, 0.06, h * 0.45, x, y, M["trunk"], seg=7)
    leaf = M["leaf2"] if alt else M["leaf"]
    ball(r, (x, y, h * 0.55), leaf, scale=(1.0, 1.0, 1.05), subdiv=1)
    ball(r * 0.72, (x + r * 0.35, y - r * 0.2, h * 0.78), leaf, subdiv=1)
    ball(r * 0.6, (x - r * 0.4, y + r * 0.25, h * 0.74), M["leaf2"] if not alt else M["leaf"], subdiv=1)


def shrub(M, x, y, r=0.7):
    ball(r, (x, y, 0.08 + r * 0.75), M["leaf"], scale=(1.15, 1.15, 0.85), subdiv=1)


def planter(M, x0, x1, y0, y1, shrubs):
    box(x0, x1, y0, y1, 0.06, 0.55, M["ink"], bevel=0.05, seg=1)
    box(x0 + 0.12, x1 - 0.12, y0 + 0.12, y1 - 0.12, 0.55, 0.62, M["lawn"])
    for i in range(shrubs):
        t = (i + 0.5) / shrubs
        shrub(M, x0 + (x1 - x0) * t, (y0 + y1) / 2, r=min(0.62, (y1 - y0) * 0.55))


def lamp(M, x, y):
    cyl(0.1, 0.06, 6.0, x, y, M["ink"], seg=8)
    box_at((1.3, 0.28, 0.16), (x + 0.5, y, 6.0), M["ink"], bevel=0.04, seg=1)
    box_at((0.9, 0.2, 0.04), (x + 0.6, y, 5.9), M["led"])


def flag(M, x, y, cloth):
    cyl(0.07, 0.06, 9.0, x, y, M["steel"], seg=8)
    ball(0.12, (x, y, 9.05), M["steel"], subdiv=1)
    box(x + 0.08, x + 2.0, y - 0.02, y + 0.02, 7.3, 8.6, cloth)


def build():
    col = use_scene()
    M = materials()

    # Zemin: parsel levhası (kilit taşı), otopark asfaltı, çim şeritleri
    box(0.0, 52.0, 0.0, 42.0, -0.12, 0.06, M["paver"])
    box(17.0, 52.0, 0.8, 10.6, 0.06, 0.075, M["asphalt"])
    for i in range(14):
        x = 17.6 + i * 2.6
        box(x - 0.06, x + 0.06, 1.6, 6.6, 0.075, 0.08, M["line"])
    box(17.3, 51.7, 6.9, 7.0, 0.075, 0.08, M["line"])
    box(48.6, 52.0, 11.0, 42.0, 0.06, 0.11, M["lawn"])
    box(0.0, 48.6, 35.4, 42.0, 0.06, 0.11, M["lawn"])
    box(0.0, 2.6, 11.0, 35.4, 0.06, 0.11, M["lawn"])

    # CAR PARTS bloğu: krem duvar, parapet, iki kepenkli servis kapısı, kehribar tabela bandı
    box(3.0, 15.0, 13.0, 33.0, 0.06, 5.6, M["cream"])
    box(2.8, 15.2, 12.8, 33.2, 5.6, 6.1, M["ink"])
    box(3.0, 15.0, 13.0, 33.0, 6.1, 6.15, M["cream"])
    for x0 in (4.2, 9.6):
        # Kehribar çerçeve duvardan çıkar; kepenk çerçevenin ÖNÜNDE (önceden arkasında kalıyordu)
        box(x0 - 0.25, x0 + 4.45, 12.78, 13.0, 0.06, 4.35, M["amber"])
        box(x0, x0 + 4.2, 12.72, 12.78, 0.06, 4.1, M["shutter"])
        for k in range(9):
            z = 0.5 + k * 0.42
            box(x0, x0 + 4.2, 12.68, 12.72, z, z + 0.05, M["ink"])
    box(3.3, 14.7, 12.72, 13.0, 4.55, 5.35, M["amber"])
    box(11.0, 13.2, 20.0, 23.0, 6.15, 7.0, M["steel"], bevel=0.08, seg=1)
    box(5.0, 6.6, 26.0, 27.6, 6.15, 6.8, M["steel"], bevel=0.08, seg=1)

    # SHOWROOM salonu: iç zemin, cam cepheler (güney + doğu), ince koyu doğramalar, dolu kuzey duvarı
    box(15.0, 41.0, 13.0, 33.0, 0.06, 0.14, M["floor"])
    box(15.0, 41.0, 32.8, 33.0, 0.14, 6.9, M["wall"])
    box(15.0, 15.2, 13.0, 33.0, 0.14, 6.9, M["wall"])
    box(15.2, 40.8, 13.0, 13.06, 0.45, 6.9, M["glass"])
    box(40.94, 41.0, 13.2, 32.8, 0.45, 6.9, M["glass"])
    box(15.0, 41.0, 12.9, 13.1, 0.14, 0.45, M["ink"])
    box(40.9, 41.1, 13.0, 33.0, 0.14, 0.45, M["ink"])
    for i in range(9):
        x = 15.1 + i * (25.8 / 8.0)
        box(x - 0.09, x + 0.09, 12.88, 13.12, 0.14, 6.9, M["ink"])
    for i in range(7):
        y = 13.1 + i * (19.8 / 6.0)
        box(40.88, 41.12, y - 0.09, y + 0.09, 0.14, 6.9, M["ink"])
    box(15.0, 41.0, 12.9, 13.1, 3.25, 3.37, M["ink"])
    box(40.9, 41.1, 13.0, 33.0, 3.25, 3.37, M["ink"])

    # Giriş portalı: öne çıkan koyu çerçeve, cam kapı, paspas
    box(25.0, 25.5, 11.6, 13.0, 0.14, 5.4, M["ink"], bevel=0.04, seg=1)
    box(30.5, 31.0, 11.6, 13.0, 0.14, 5.4, M["ink"], bevel=0.04, seg=1)
    box(25.0, 31.0, 11.6, 13.0, 5.4, 6.0, M["ink"], bevel=0.04, seg=1)
    box(25.5, 30.5, 11.9, 11.95, 0.14, 5.4, M["glass"])
    box(27.95, 28.05, 11.88, 11.97, 0.14, 5.4, M["ink"])
    box(25.3, 30.7, 10.4, 11.6, 0.06, 0.09, M["ink"])

    # Yüzen çatı: köşeleri yuvarlak kalın beyaz levha, güneye ve doğuya taşar; alt kenarda sıcak LED,
    # güney yüzünde koyu tabela bandı (yazı Godot'ta)
    rounded_slab(14.34, 44.26, 9.54, 33.66, 6.84, 6.93, 2.26, M["amber"])
    rounded_slab(14.4, 44.2, 9.6, 33.6, 6.93, 7.85, 2.2, M["roof"])
    box(19.0, 36.0, 19.5, 23.5, 7.85, 8.0, M["steel"])
    box(19.25, 35.75, 19.75, 23.25, 8.0, 8.06, M["glass"])
    for i in range(1, 8):
        x = 19.0 + i * 17.0 / 8.0
        box(x - 0.06, x + 0.06, 19.75, 23.25, 8.0, 8.08, M["ink"])
    for x in (20.0, 24.0, 28.0):
        box(x, x + 2.4, 28.0, 30.4, 7.85, 8.9, M["steel"], bevel=0.1, seg=1)
        box(x + 0.3, x + 2.1, 28.3, 30.1, 8.9, 8.95, M["ink"])
    box(15.5, 43.4, 9.62, 9.72, 6.84, 6.9, M["led"])
    box(43.3, 43.4, 10.6, 32.6, 6.84, 6.9, M["led"])
    box(18.0, 38.0, 9.52, 9.62, 6.98, 7.76, M["ink"])
    box(43.9, 44.0, 16.0, 30.0, 6.98, 7.76, M["ink"])

    # İç mekân: iki sergi kaidesi ve araç, danışma masası, arka duvarda kehribar şerit, saksılar
    for (x, y, head, paint) in ((21.5, 20.5, 28.0, M["red"]), (33.5, 22.0, -24.0, M["white"])):
        cyl(3.0, 0.14, 0.42, x, y, M["wall"], seg=28)
        cyl(3.06, 0.36, 0.44, x, y, M["amber"], seg=28)
        car(M, x, y, head, paint).location.z += 0.44
    box(35.5, 39.5, 28.6, 30.0, 0.14, 1.15, M["wall"], bevel=0.08, seg=1)
    box(35.4, 39.6, 28.5, 30.1, 1.15, 1.25, M["ink"])
    box(15.4, 40.6, 32.7, 32.8, 3.0, 3.6, M["amber"])
    for x in (17.0, 39.0):
        cyl(0.45, 0.14, 0.9, x, 31.5, M["ink"], seg=10)
        ball(0.75, (x, 31.5, 1.6), M["leaf"], scale=(1.0, 1.0, 1.25), subdiv=1)

    # Açık sergi: doğu şeridinde üç platform ve araç, kenarları kehribar
    for (y, head, paint) in ((16.5, -38.0, M["blue"]), (22.5, -38.0, M["red"]), (28.5, -38.0, M["white"])):
        box(43.0, 48.2, y - 2.3, y + 2.3, 0.06, 0.26, M["wall"], bevel=0.06, seg=1)
        box(43.0, 48.2, y - 2.3, y - 2.18, 0.26, 0.3, M["amber"])
        car(M, 45.6, y, head, paint).location.z += 0.26

    # Köşe totemi (kavşağa bakan): koyu gövde, iki yüzünde kehribar levha (yazı Godot'ta)
    # (10,5 m'lik ilk sürüm varsayılan görünümde sağ üstteki HUD düğmelerine kadar uzanıyordu)
    box(1.6, 4.6, 1.2, 3.4, 0.06, 0.45, M["ink"], bevel=0.06, seg=1)
    box(2.3, 3.9, 1.7, 2.9, 0.45, 7.6, M["ink"], bevel=0.05, seg=1)
    box(2.5, 3.7, 1.6, 1.7, 1.1, 7.1, M["amber"])
    box(3.9, 4.0, 1.9, 2.7, 1.1, 7.1, M["amber"])
    box(2.2, 4.0, 1.6, 3.0, 7.6, 7.9, M["amber"], bevel=0.04, seg=1)

    # Bayraklar, lambalar, saksılar, çit, ağaçlar
    for (y, cloth) in ((5.2, M["amber"]), (7.4, M["cream"]), (9.6, M["ink"])):
        flag(M, 1.5, y, cloth)
    for x in (20.0, 30.5, 41.0, 51.2):
        lamp(M, x, 0.5)
    planter(M, 15.6, 24.4, 10.3, 11.3, 4)
    planter(M, 31.6, 40.4, 10.3, 11.3, 4)
    planter(M, 3.2, 14.8, 10.9, 11.9, 5)
    box(0.6, 1.8, 12.0, 34.8, 0.11, 1.2, M["leaf"], bevel=0.35, seg=2)
    for i, x in enumerate((5.0, 13.0, 21.0, 29.0, 37.0, 45.0)):
        tree(M, x, 38.7, h=6.8 + (i % 2) * 0.9, r=2.1, alt=bool(i % 2))
    tree(M, 50.3, 36.8, h=6.4, r=1.8, alt=True)
    tree(M, 46.5, 34.4, h=5.8, r=1.6)
    for y in (13.2, 19.5, 25.5, 31.2):
        shrub(M, 50.2, y, 0.62)

    # Tek gövde: her malzeme bir yüzey (oyunda ~20 çizim çağrısı)
    objs = list(col.objects)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    body = bpy.context.object
    body.name = "Showroom"
    tris = sum(len(p.vertices) - 2 for p in body.data.polygons)
    d = body.dimensions
    print("Showroom: %.1f x %.1f x %.1f m, %d ucgen, %d malzeme" % (d.x, d.y, d.z, tris, len(body.data.materials)))
    return body


def export(body):
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    # use_active_scene: dışa aktarıcı varsayılan olarak BÜTÜN sahneleri gezer ve seçim süzgecini
    # her birine uygular — kullanıcının kendi sahnesinde seçili duran araç parçaları da GLB'ye
    # giriyordu (ilk denemede 500 bin üçgen, 19 MB).
    bpy.ops.export_scene.gltf(filepath=OUT, export_format='GLB', use_selection=True,
                              use_active_scene=True, export_apply=True, export_yup=True,
                              export_cameras=False, export_lights=False)
    print("yazildi: %s (%.1f KB)" % (OUT, os.path.getsize(OUT) / 1024.0))


body = build()
export(body)
