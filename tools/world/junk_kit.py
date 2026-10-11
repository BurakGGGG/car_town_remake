"""HURDALIK parça kiti — detaylı, tekrar kullanılan modeller (junkyard.py ve garajdaki restorasyon şasisi).

Her üretici tek bir nesne döndürür (parçalar birleştirilmiş: oyunda az düğüm, az çizim çağrısı).
Birim METRE, Blender eksenleri (X doğu, Y kuzey, Z yukarı). Araç ön tarafı +X.

Kullanım: junkyard.py başında exec edilir; tek başına denemek için:
    exec(open(".../tools/world/junk_kit.py").read()); kit_preview()
"""
import bpy, bmesh, math, random

_KIT_MATS = {}
_SURF = {}

# RENK DÜZENİ (kullanıcı: "çok amatör" → 2026-10-11 yeniden yapıldı): bütün renkler KÖŞE RENGİNDE ("Col",
# FLOAT_COLOR, köşe başına, lineer). Materyaller yalnızca YÜZEY TÜRÜDÜR (mat, ahşap, metal, krom, lastik, cam,
# ışıklı): oyunda az materyal = az çizim çağrısı; her parça hafif renk çeşitlemesi alır ve finish() yere
# yaklaştıkça koyulaştırır (GL Compatibility'de gerçek zamanlı AO yok — gölgelenme köşe rengine pişirilir).
# Godot glTF'i köşe rengiyle içe aktarır ama materyalde kullanmaz: hurdalık sahnesi yüklenirken
# vertex_color_use_as_albedo açılır (bkz. docs/HURDALIK_TASARIM.md).
AO_FLOOR = 0.55      # zemine değen köşenin parlaklık çarpanı
AO_HEIGHT = 1.4      # bu yükseklikte (m) koyulaşma biter
JITTER = 0.07        # parça başına parlaklık / ton oynaması


def k_srgb(hexcol):
    h = hexcol.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


def k_mat(name, hexcol, rough=0.8, metal=0.0, emit=None, strength=2.0):
    """Renk + yüzey tanımı. Döndürülen materyal ön izleme içindir (kutu / silindir yardımcıları); Builder ve
    postprocess rengi köşe rengine yazar, yuvaya yüzey materyalini (surface_for) koyar."""
    if name in _KIT_MATS:
        return _KIT_MATS[name]
    m = bpy.data.materials.get("JY_" + name) or bpy.data.materials.new("JY_" + name)
    m.use_nodes = True
    m.use_backface_culling = False
    b = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    c = k_srgb(hexcol)
    b.inputs["Base Color"].default_value = (c[0], c[1], c[2], 1.0)
    m.diffuse_color = (c[0], c[1], c[2], 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        e = k_srgb(emit)
        b.inputs["Emission Color"].default_value = (e[0], e[1], e[2], 1.0)
        b.inputs["Emission Strength"].default_value = strength
    else:
        b.inputs["Emission Strength"].default_value = 0.0
    m["jy_hex"] = hexcol
    m["jy_rough"] = rough
    m["jy_metal"] = metal
    m["jy_emit"] = emit or ""
    m["jy_strength"] = strength
    _KIT_MATS[name] = m
    return m


def surface_mat(kind, rough, metal, emit=None, strength=0.0):
    """Köşe rengini temel renk olarak kullanan yüzey materyali (ışıklılar ayrı: kendi ışık rengiyle)."""
    key = "emit_%s_%d" % (emit.lstrip("#"), int(strength)) if emit else kind
    if key in _SURF:
        return _SURF[key]
    m = bpy.data.materials.get("JYS_" + key) or bpy.data.materials.new("JYS_" + key)
    m.use_nodes = True
    m.use_backface_culling = False
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
    vc = nt.nodes.new("ShaderNodeVertexColor")
    vc.layer_name = "Col"
    nt.links.new(vc.outputs["Color"], bsdf.inputs["Base Color"])
    nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emit:
        e = k_srgb(emit)
        bsdf.inputs["Emission Color"].default_value = (e[0], e[1], e[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    m["jy_surface"] = key
    _SURF[key] = m
    return m


def surface_for(material):
    """Renk materyalinin (k_mat) yüzey türü."""
    if material is None:
        return surface_mat("matte", 0.85, 0.0)
    if material.get("jy_surface"):
        return material
    rough = float(material.get("jy_rough", 0.8))
    metal = float(material.get("jy_metal", 0.0))
    emit = material.get("jy_emit", "")
    if emit:
        # Işıklılar 3 materyalde toplanır (çizim çağrısı): ateş ailesi (kor / alev), arama halkası (zayıf), sıcak ışık
        # (ampul / lamba / pencere). Asıl renk köşe renginde; ışık rengi ailenin rengi.
        strength = float(material.get("jy_strength", 2.0))
        er, eg, eb = k_srgb(emit)
        if strength <= 3.0:
            return surface_mat("emit", 0.5, 0.0, "#FFC94A", 3.0)
        if eg < 0.45 * er:
            return surface_mat("emit", 0.5, 0.0, "#FF6A1A", 12.0)
        return surface_mat("emit", 0.5, 0.0, "#FFD08A", 7.0)
    if metal >= 0.85:
        return surface_mat("chrome", 0.22, 0.9)
    if rough <= 0.3:
        return surface_mat("glass", 0.15, 0.3)
    if metal >= 0.3:
        return surface_mat("metal", 0.55, 0.55)
    if rough >= 0.93:
        return surface_mat("rough", 0.97, 0.0)
    return surface_mat("matte", 0.82, 0.0)


def lin_color(material):
    return k_srgb(material.get("jy_hex", "#808080")) if material is not None else (0.2, 0.2, 0.2)


def ao_factor(z):
    t = max(0.0, min(1.0, z / AO_HEIGHT))
    t = t * t * (3 - 2 * t)
    return AO_FLOOR + (1.0 - AO_FLOOR) * t


class Builder:
    """Parçaları tek bmesh'te toplar; renk köşe rengine ("Col"), yuvaya yüzey türü. finish() tek nesne üretir."""

    def __init__(self, name, seed=None):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.mats = []
        self.rng = random.Random(seed if seed is not None else (hash(name) & 0xffffff))

    def _slot(self, material):
        if material not in self.mats:
            self.mats.append(material)
        return self.mats.index(material)

    def _tint(self, material, jitter=True):
        c = lin_color(material)
        if not jitter:
            return (c[0], c[1], c[2], 1.0)
        k = 1.0 + self.rng.uniform(-JITTER, JITTER)
        h = self.rng.uniform(-0.03, 0.03)
        return (c[0] * k * (1 + h), c[1] * k, c[2] * k * (1 - h), 1.0)

    def _add(self, verts, faces, material, jitter=True):
        slot = self._slot(surface_for(material))
        color = self._tint(material, jitter)
        vs = [self.bm.verts.new(v) for v in verts]
        for f in faces:
            try:
                face = self.bm.faces.new([vs[i] for i in f])
            except ValueError:
                continue
            face.material_index = slot
            face.smooth = False
            for loop in face.loops:
                loop[self.col] = color

    def add_mesh(self, me, matrix, material=None, tint=(1.0, 1.0, 1.0)):
        """Hazır mesh'i (hurda araç: kendi "Col" köşe rengiyle) dönüşümle ekler; yüzey türü material'den."""
        from mathutils import Matrix
        slot = self._slot(surface_for(material) if material is not None else surface_mat("metal_paint", 0.7, 0.25))
        tb = bmesh.new()
        tb.from_mesh(me)
        tb.transform(matrix)
        src = tb.loops.layers.float_color.get("Col")
        vmap = {v: self.bm.verts.new(v.co) for v in tb.verts}
        for f in tb.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf.material_index = slot
            nf.smooth = False
            for ln, lo in zip(nf.loops, f.loops):
                c = lo[src] if src is not None else (0.5, 0.5, 0.5, 1.0)
                ln[self.col] = (c[0] * tint[0], c[1] * tint[1], c[2] * tint[2], 1.0)
        tb.free()

    @staticmethod
    def _xf(p, loc, rot, origin=(0, 0, 0)):
        """Noktayı origin etrafında X(roll) → Y(pitch) → Z(yaw) sırasıyla döndürüp loc'a taşır (derece)."""
        x, y, z = p[0] - origin[0], p[1] - origin[1], p[2] - origin[2]
        rx, ry, rz = (math.radians(a) for a in rot)
        y, z = y * math.cos(rx) - z * math.sin(rx), y * math.sin(rx) + z * math.cos(rx)
        x, z = x * math.cos(ry) + z * math.sin(ry), -x * math.sin(ry) + z * math.cos(ry)
        x, y = x * math.cos(rz) - y * math.sin(rz), x * math.sin(rz) + y * math.cos(rz)
        return (x + origin[0] + loc[0], y + origin[1] + loc[1], z + origin[2] + loc[2])

    def box(self, center, size, material, rot=(0, 0, 0)):
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        corners = [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, hy, -hz), (-hx, hy, -hz),
                   (-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]
        v = [self._xf(c, center, rot) for c in corners]
        self._add(v, [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], material)

    def cyl(self, center, radius, length, material, axis='Z', segs=12, rot=(0, 0, 0), r2=None):
        """Silindir (r2 verilirse kesik koni); axis yönünde uzanır."""
        r2 = radius if r2 is None else r2
        ring0, ring1 = [], []
        for i in range(segs):
            a = math.tau * i / segs
            ca, sa = math.cos(a), math.sin(a)
            if axis == 'Z':
                p0, p1 = (ca * radius, sa * radius, -length / 2), (ca * r2, sa * r2, length / 2)
            elif axis == 'X':
                p0, p1 = (-length / 2, ca * radius, sa * radius), (length / 2, ca * r2, sa * r2)
            else:
                p0, p1 = (ca * radius, -length / 2, sa * radius), (ca * r2, length / 2, sa * r2)
            ring0.append(p0)
            ring1.append(p1)
        v = [self._xf(p, center, rot) for p in ring0 + ring1]
        f = [(i, (i + 1) % segs, segs + (i + 1) % segs, segs + i) for i in range(segs)]
        f.append(tuple(reversed(range(segs))))
        f.append(tuple(range(segs, 2 * segs)))
        self._add(v, f, material)

    def tube(self, points, radius, material, segs=6):
        """Kırık çizgi boyunca boru (egzoz, kablo, tel): her parça ayrı silindir."""
        for a, b in zip(points[:-1], points[1:]):
            dx, dy, dz = b[0] - a[0], b[1] - a[1], b[2] - a[2]
            length = math.sqrt(dx * dx + dy * dy + dz * dz)
            yaw = math.degrees(math.atan2(dy, dx))
            pitch = -math.degrees(math.atan2(dz, math.hypot(dx, dy)))
            mid = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
            self.cyl(mid, radius, length, material, axis='X', segs=segs, rot=(0, pitch, yaw))

    def corrugated(self, origin, width, height, material, period=0.16, depth=0.05, rot=(0, 0, 0), along='X'):
        """Oluklu sac panel: genişlik boyunca sinüs dalgalı, iki yüzlü (backface culling kapalı)."""
        n = max(4, int(width / period * 2))   # dalga başına 2 köşe (üçgen dalga): uzaktan aynı, yarı maliyet
        v, f = [], []
        for i in range(n + 1):
            t = width * i / n
            d = depth * math.sin(math.tau * t / period)
            if along == 'X':
                v += [(t, d, 0.0), (t, d, height)]
            else:
                v += [(d, t, 0.0), (d, t, height)]
        for i in range(n):
            f.append((2 * i, 2 * i + 2, 2 * i + 3, 2 * i + 1))
        self._add([self._xf(p, origin, rot) for p in v], f, material)

    def dome(self, center, rx, ry, h, material, seed=0, rings=7, segs=14, rough=0.15, speckle=None):
        """Düzensiz kubbe (hurda / toprak tepesi çekirdeği): alt halka zeminde, tepe yuvarlak, pürüzlü."""
        r = random.Random(seed)
        v, f = [], []
        for i in range(rings + 1):
            t = i / rings
            ang = t * math.pi / 2
            for j in range(segs):
                a = math.tau * j / segs
                k = 1.0 + (r.uniform(-rough, rough) if 0 < i < rings else 0.0)
                v.append((center[0] + math.cos(a) * math.cos(ang) * rx * k,
                          center[1] + math.sin(a) * math.cos(ang) * ry * k,
                          center[2] + math.sin(ang) * h * (1.0 + r.uniform(-rough, rough) * 0.6)))
        for i in range(rings):
            for j in range(segs):
                a0, a1 = i * segs + j, i * segs + (j + 1) % segs
                f.append((a0, a1, a1 + segs, a0 + segs))
        if not speckle:
            self._add(v, f, material)
            return
        # Benekli kubbe: her yüz hurda paletinden rastgele renk (uzaktan yığılmış sac / pas / boya gibi)
        slot = self._slot(surface_for(material))
        vs = [self.bm.verts.new(p) for p in v]
        for fi in f:
            try:
                face = self.bm.faces.new([vs[i] for i in fi])
            except ValueError:
                continue
            face.material_index = slot
            face.smooth = False
            c = k_srgb(speckle[r.randrange(len(speckle))])
            k = r.uniform(0.85, 1.05)
            for loop in face.loops:
                loop[self.col] = (c[0] * k, c[1] * k, c[2] * k, 1.0)

    def ball(self, center, radius, material, segs=9, rings=6, scale=(1.0, 1.0, 1.0), rot=(0, 0, 0)):
        """Küre / elipsoit (baş, burun, göbek, kas)."""
        v, f = [], []
        for i in range(rings + 1):
            t = math.pi * i / rings
            for j in range(segs):
                a = math.tau * j / segs
                p = (math.sin(t) * math.cos(a) * radius * scale[0], math.sin(t) * math.sin(a) * radius * scale[1],
                     math.cos(t) * radius * scale[2])
                v.append(self._xf(p, center, rot))
        for i in range(rings):
            for j in range(segs):
                a0, a1 = i * segs + j, i * segs + (j + 1) % segs
                f.append((a0, a1, a1 + segs, a0 + segs))
        self._add(v, f, material)

    def limb(self, a, b_, r0, r1, material, segs=7):
        """İki nokta arası konik uzuv (kol, bacak) + uçlarda yuvarlak eklem."""
        dx, dy, dz = b_[0] - a[0], b_[1] - a[1], b_[2] - a[2]
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        yaw = math.degrees(math.atan2(dy, dx))
        pitch = -math.degrees(math.atan2(dz, math.hypot(dx, dy)))
        mid = ((a[0] + b_[0]) / 2, (a[1] + b_[1]) / 2, (a[2] + b_[2]) / 2)
        self.cyl(mid, r0, length, material, axis='X', segs=segs, rot=(0, pitch, yaw), r2=r1)
        self.ball(b_, r1 * 1.02, material, segs=segs, rings=5)

    def finish(self, col, loc=(0, 0, 0), rot=(0, 0, 0), ao=True):
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        o = bpy.data.objects.new(self.name, me)
        col.objects.link(o)
        o.location = loc
        o.rotation_euler = tuple(math.radians(a) for a in rot)
        o["jy_vc"] = True
        if ao:
            bake_height_ao(o)
        return o


def bake_height_ao(o):
    """Köşe rengini dünya yüksekliğine göre koyulaştırır (zemine değen yerler koyu)."""
    me = o.data
    attr = me.color_attributes.get("Col")
    if attr is None:
        return
    mw = o.matrix_world.copy()
    if o.parent is None:
        from mathutils import Matrix, Euler
        mw = Matrix.Translation(o.location) @ Euler(o.rotation_euler).to_matrix().to_4x4() @ Matrix.Diagonal((*o.scale, 1.0))
    zs = [(mw @ v.co).z for v in me.vertices]
    for li, loop in enumerate(me.loops):
        k = ao_factor(zs[loop.vertex_index])
        c = attr.data[li].color
        attr.data[li].color = (c[0] * k, c[1] * k, c[2] * k, 1.0)


def postprocess(col):
    """Builder dışından gelen (bpy.ops ile kurulan) nesneleri aynı düzene çevirir: renk materyalinden köşe
    rengi + yükseklik gölgesi, yuvaya yüzey türü. Dokulu nesneler (jy_textured) ve ışıklar atlanır."""
    for o in col.objects:
        if o.type != 'MESH' or o.get("jy_vc") or o.get("jy_textured"):
            continue
        me = o.data
        if me.users > 1:
            o.data = me = me.copy()
        attr = me.color_attributes.get("Col") or me.color_attributes.new("Col", 'FLOAT_COLOR', 'CORNER')
        r = random.Random(hash(o.name) & 0xffffff)
        k = 1.0 + r.uniform(-JITTER, JITTER)
        mats = [s.material for s in o.material_slots]
        mw = o.matrix_world
        zs = [(mw @ v.co).z for v in me.vertices]
        for poly in me.polygons:
            m = mats[poly.material_index] if poly.material_index < len(mats) else None
            c = lin_color(m) if m is not None and m.get("jy_hex") else (0.5, 0.5, 0.5)
            for li in poly.loop_indices:
                a = ao_factor(zs[me.loops[li].vertex_index]) * k
                attr.data[li].color = (c[0] * a, c[1] * a, c[2] * a, 1.0)
        for i, s in enumerate(o.material_slots):
            s.material = surface_for(s.material)
        o["jy_vc"] = True


# --- Malzemeler -------------------------------------------------------------------------

def kit_mats():
    return {
        "frame": k_mat("frame_rust", "#5B3220", rough=0.9, metal=0.35),
        "frame_dark": k_mat("frame_dark", "#2E2622", rough=0.8, metal=0.5),
        "engine": k_mat("engine_block", "#4C4844", rough=0.6, metal=0.55),
        "engine_rust": k_mat("engine_rust", "#7A4426", rough=0.9, metal=0.2),
        "steel": k_mat("steel", "#8D8F91", rough=0.45, metal=0.75),
        "chrome": k_mat("chrome", "#C9CDD1", rough=0.2, metal=0.95),
        "rubber": k_mat("tire", "#1E1E1E", rough=0.95),
        "drum": k_mat("brake_drum", "#6A3B26", rough=0.85, metal=0.3),
        "spring": k_mat("leaf_spring", "#3A3430", rough=0.7, metal=0.5),
    }


# --- Araç iskeleti / restorasyon şasisi ----------------------------------------------------

def chassis(col, name="Chassis", loc=(0, 0, 0), rot=(0, 0, 0), wheels=False, rust=1.0, seed=1):
    """Tekerleksiz (ya da tekerlekli) klasik araç merdiven şasisi: ön +X, uzunluk ~4,2 m, iz ~1,4 m.
    Parçalar: iki boyuna kiriş (önde ve arkada yükselen kıvrımlı), 5 traversi, ön aks + makas yayları,
    arka diferansiyel + aks + makas yayları, 4 fren kampanası / göbek, motor bloğu (kapak, karbüratör,
    egzoz manifoldu, alternatör), şanzıman + şaft, radyatör, direksiyon kutusu ve kolonu, egzoz hattı.
    Garajdaki restorasyonun 1. aşaması (%0–33) ve sahadaki hurda iskeletleri bu modeldir."""
    M = kit_mats()
    fr = M["frame"] if rust > 0.5 else M["frame_dark"]
    b = Builder(name)
    track, rail_y, wheel_z = 1.42, 0.46, 0.33
    fx, rx = 1.35, -1.35       # ön ve arka aks X
    # Boyuna kirişler: arka aks üstünde kavis (kick-up), önde motor bölmesi için hafif içe
    pts = [(-2.05, 0.42), (-1.75, 0.42), (-1.55, 0.62), (-1.15, 0.62), (-0.95, 0.40), (1.0, 0.40), (1.35, 0.46), (2.05, 0.46)]
    for side in (-1, 1):
        for (x0, z0), (x1, z1) in zip(pts[:-1], pts[1:]):
            dx, dz = x1 - x0, z1 - z0
            length = math.hypot(dx, dz)
            pitch = -math.degrees(math.atan2(dz, dx))
            y = side * (rail_y if x0 < 0.9 else rail_y - 0.06)
            b.box(((x0 + x1) / 2, y, (z0 + z1) / 2), (length + 0.02, 0.08, 0.16), fr, rot=(0, pitch, 0))
    for x in (-2.0, -1.35, -0.2, 0.75, 1.95):
        z = 0.62 if -1.6 < x < -1.1 else (0.46 if x > 1.2 else 0.40)
        b.box((x, 0, z), (0.09, rail_y * 2, 0.11), fr)
    # Çapraz X takviyesi (orta)
    for s in (-1, 1):
        b.box((-0.55, 0, 0.38), (1.15, 0.07, 0.07), fr, rot=(0, 0, s * 33))
    # Ön aks (kiriş) + makas yayları + amortisör
    b.box((fx, 0, wheel_z), (0.1, track - 0.1, 0.1), M["frame_dark"])
    for side in (-1, 1):
        y = side * rail_y
        for k in range(3):
            b.box((fx, y, wheel_z + 0.06 + k * 0.025), (0.9 - k * 0.2, 0.06, 0.02), M["spring"])
        b.cyl((fx + 0.12, y + side * 0.04, wheel_z + 0.18), 0.03, 0.32, M["steel"], segs=8)
    # Arka diferansiyel + aks + yaylar
    b.cyl((rx, 0, wheel_z), 0.05, track - 0.12, M["frame_dark"], axis='Y', segs=10)
    b.cyl((rx, 0, wheel_z), 0.17, 0.2, M["engine"], axis='Y', segs=14)
    b.cyl((rx + 0.14, 0, wheel_z), 0.09, 0.16, M["engine"], axis='X', segs=12)
    for side in (-1, 1):
        y = side * rail_y
        for k in range(4):
            b.box((rx, y, wheel_z + 0.06 + k * 0.025), (1.05 - k * 0.18, 0.06, 0.02), M["spring"])
    # Fren kampanaları / göbekler (tekerlek yerine) ya da tekerlekler
    for x in (fx, rx):
        for side in (-1, 1):
            y = side * (track / 2)
            if wheels:
                b.cyl((x, y, wheel_z), 0.33, 0.2, M["rubber"], axis='Y', segs=18)
                b.cyl((x, y + side * 0.02, wheel_z), 0.2, 0.2, M["steel"], axis='Y', segs=14)
            else:
                b.cyl((x, y, wheel_z), 0.15, 0.12, M["drum"], axis='Y', segs=14)
                b.cyl((x, y + side * 0.07, wheel_z), 0.07, 0.04, M["steel"], axis='Y', segs=8)
                for k in range(4):   # bijon cıvataları
                    a = math.tau * k / 4
                    b.cyl((x + math.cos(a) * 0.06, y + side * 0.09, wheel_z + math.sin(a) * 0.06), 0.012, 0.04, M["steel"], axis='Y', segs=5)
    # Motor bloğu (sıralı 4): blok, karter, kapak, karbüratör + hava filtresi, manifold, alternatör, kasnak
    eng = M["engine_rust"] if rust > 0.5 else M["engine"]
    b.box((1.05, 0, 0.62), (0.62, 0.42, 0.42), eng)
    b.box((1.05, 0, 0.36), (0.58, 0.36, 0.14), M["frame_dark"])
    b.box((1.05, 0, 0.88), (0.6, 0.3, 0.1), M["engine"])
    for k in range(4):
        b.cyl((0.82 + k * 0.155, 0.0, 0.95), 0.025, 0.06, M["chrome"], segs=6)
    b.cyl((1.0, 0.27, 0.86), 0.06, 0.16, M["steel"], segs=8)
    b.cyl((1.0, 0.27, 0.98), 0.14, 0.06, M["chrome"], segs=16)
    for k in range(4):
        b.box((0.82 + k * 0.155, -0.27, 0.66), (0.06, 0.12, 0.05), M["frame_dark"])
    b.box((1.05, -0.33, 0.66), (0.6, 0.05, 0.06), M["frame_dark"])
    b.cyl((1.38, 0.18, 0.72), 0.07, 0.1, M["steel"], axis='X', segs=10)
    b.cyl((1.38, 0, 0.58), 0.1, 0.04, M["frame_dark"], axis='X', segs=14)
    # Radyatör
    b.box((1.62, 0, 0.72), (0.08, 0.62, 0.5), M["frame_dark"])
    b.box((1.66, 0, 0.72), (0.02, 0.54, 0.42), M["steel"])
    # Şanzıman + kardan
    b.cyl((0.55, 0, 0.55), 0.13, 0.42, M["engine"], axis='X', segs=12, r2=0.09)
    b.cyl((-0.4, 0, 0.45), 0.035, 1.7, M["steel"], axis='X', segs=8, rot=(0, -3, 0))
    # Direksiyon kutusu + kolon (arkaya, yukarı)
    b.box((1.35, 0.32, 0.5), (0.14, 0.12, 0.12), M["frame_dark"])
    b.tube([(1.35, 0.32, 0.56), (0.55, 0.3, 1.05)], 0.025, M["steel"])
    b.cyl((0.5, 0.3, 1.08), 0.18, 0.03, M["frame_dark"], axis='X', segs=16, rot=(0, -60, 0))
    # Egzoz hattı: manifolddan aşağı, boyunca, susturucu, arkada çıkış
    b.tube([(0.85, -0.33, 0.62), (0.75, -0.3, 0.3), (0.0, -0.28, 0.27), (-1.0, -0.28, 0.27)], 0.03, M["steel"])
    b.cyl((-1.3, -0.28, 0.3), 0.08, 0.5, M["drum"], axis='X', segs=10)
    b.tube([(-1.55, -0.28, 0.3), (-2.1, -0.3, 0.32)], 0.028, M["steel"])
    # Yakıt deposu (arkada traversler arası)
    b.box((-1.8, 0, 0.5), (0.4, 0.75, 0.22), M["engine_rust"] if rust > 0.5 else M["engine"])
    # Tampon kalıntısı (önde), paslı
    b.box((2.08, 0, 0.45), (0.08, 1.4, 0.12), M["chrome"] if rust < 0.5 else M["engine_rust"])
    return b.finish(col, loc=loc, rot=rot)


# --- Araç kabuğu (hurda yığınları, kuleler, vinçteki araba) -----------------------------------

def shell_into(b, center, yaw, material, crush=1.0, pitch=0.0, roll=0.0, scale=1.0, cabin=True, trim=None):
    """Builder'a tekerleksiz araç kabuğu ekler: yuvarlatılmış burun / bagaj, eğik camlı kabin, tampon."""
    L, Wd, H = 4.3 * scale, 1.8 * scale, 0.62 * crush * scale
    hl, hw = L / 2, Wd / 2
    nose = 0.25 * scale
    prof = [(-hl, H * 0.55), (-hl + nose, H * 0.85), (hl - nose, H), (hl, H * 0.6)]   # yan profil üst çizgisi
    v = []
    for (x, z) in [(-hl, 0.0), (hl, 0.0)] + prof:
        pass
    # Gövde: 6 kesitli prizma (alt düz, üst profil)
    xs = [-hl, -hl + nose, hl - nose, hl]
    zs_top = [H * 0.55, H * 0.88, H, H * 0.62]
    ring = []
    for x, zt in zip(xs, zs_top):
        ring.append([(x, -hw, 0.06), (x, hw, 0.06), (x, hw, zt), (x, -hw, zt)])
    verts = [p for r in ring for p in r]
    faces = []
    for i in range(len(xs) - 1):
        a, c = i * 4, (i + 1) * 4
        faces += [(a + 0, c + 0, c + 1, a + 1), (a + 1, c + 1, c + 2, a + 2), (a + 2, c + 2, c + 3, a + 3), (a + 3, c + 3, c + 0, a + 0)]
    faces += [(0, 1, 2, 3), (12, 15, 14, 13)]
    origin = (0, 0, 0)
    vv = [b._xf(b._xf(p, (0, 0, 0), (roll, pitch, yaw)), center, (0, 0, 0)) for p in verts]
    b._add(vv, faces, material)
    if cabin:
        ch = 0.55 * crush * scale
        cab = [(-1.0 * scale, -hw * 0.9, H * 0.97), (0.8 * scale, -hw * 0.9, H), (0.8 * scale, hw * 0.9, H), (-1.0 * scale, hw * 0.9, H * 0.97),
               (-0.55 * scale, -hw * 0.78, H + ch), (0.25 * scale, -hw * 0.78, H + ch), (0.25 * scale, hw * 0.78, H + ch), (-0.55 * scale, hw * 0.78, H + ch)]
        cf = [(4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
        b._add([b._xf(b._xf(p, (0, 0, 0), (roll, pitch, yaw)), center, (0, 0, 0)) for p in cab], cf,
               k_mat("glass_dark", "#2A3338", rough=0.25, metal=0.3) if crush > 0.8 and trim != "bare" else material)
    if trim is not None and trim != "bare":
        for sx in (-1, 1):   # tamponlar
            p = (sx * (hl + 0.04), 0, 0.22 * crush * scale)
            b.box(b._xf(b._xf(p, (0, 0, 0), (roll, pitch, yaw)), center, (0, 0, 0)), (0.08, Wd * 0.95, 0.12), trim, rot=(roll, pitch, yaw))


# --- Gerçek hurda araçlar (junk_wrecks.py) ---------------------------------------------------

WRECKS = {}       # car_id → tam (≈1.800 üçgen)
WRECKS_LOW = {}   # car_id → hafif (≈600 üçgen)


def load_wrecks():
    exec(open("/home/burak/Projects/car-town-remake/tools/world/junk_wrecks.py").read(), globals())
    WRECKS.update(ensure_wrecks())
    WRECKS_LOW.update(ensure_wrecks(ids=LOW_IDS, low=True))


_WRECK_BOUNDS = {}


def wreck_into(b, which, center, yaw, pitch=0.0, roll=0.0, crush=1.0, low=False, scale=1.0, tint=(1, 1, 1), fit=None):
    """Builder'a gerçek hurda araç ekler. which = car_id ya da indeks. crush < 1 → dikeyde ezilmiş.
    fit=(x, y, z) → araç bu kutuya sıkıştırılır (pres küpü: gerçek boyası / cam / krom kırıntısıyla)."""
    from mathutils import Matrix
    lib = WRECKS_LOW if low else WRECKS
    if not lib:
        load_wrecks()
        lib = WRECKS_LOW if low else WRECKS
    keys = sorted(lib.keys())
    if isinstance(which, str) and which not in lib:
        lib = WRECKS          # hafif kütüphanede yoksa tam varyant
    me = lib[which] if isinstance(which, str) else lib[keys[which % len(keys)]]
    if fit is not None:
        if me.name not in _WRECK_BOUNDS:
            xs = [v.co.x for v in me.vertices]
            ys = [v.co.y for v in me.vertices]
            zs = [v.co.z for v in me.vertices]
            _WRECK_BOUNDS[me.name] = (max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs), min(zs))
        lx, ly, lz, z0 = _WRECK_BOUNDS[me.name]
        sx, sy, sz = fit[0] / lx, fit[1] / ly, fit[2] / lz
        m = (Matrix.Translation(center) @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(pitch), 4, 'Y')
             @ Matrix.Rotation(math.radians(roll), 4, 'X') @ Matrix.Diagonal((sx, sy, sz, 1.0)) @ Matrix.Translation((0, 0, -z0)))
    else:
        m = (Matrix.Translation(center) @ Matrix.Rotation(math.radians(yaw), 4, 'Z') @ Matrix.Rotation(math.radians(pitch), 4, 'Y')
             @ Matrix.Rotation(math.radians(roll), 4, 'X') @ Matrix.Diagonal((scale, scale, scale * crush, 1.0)))
    b.add_mesh(me, m, tint=tint)


CUBE_PAINTS = ["#9C4A32", "#6F7F86", "#B58A4A", "#5E6B55", "#A7A196", "#7A3F3A", "#4F5A63", "#C2B8A0", "#3E5F8A",
               "#8A6E2A", "#2F4A3A"]


def crushed_cube(b, which, center_bottom, size, yaw=0.0):
    """Pres küpü (ezilmiş araç): 6–9 hafif kaymış katman — bir ana araç boyası + aralarda pas, çelik ve koyu
    bantlar; kenarlardan taşan sac parçaları, bir yüzde ezik jant. Gerçek pres küplerinin tanıtıcı izi katmanlardır."""
    r = random.Random(hash((which, round(center_bottom[0], 2), round(center_bottom[1], 2), round(center_bottom[2], 2))) & 0xffffff)
    paint = k_mat("cube_paint_%d" % (which % len(CUBE_PAINTS)), CUBE_PAINTS[which % len(CUBE_PAINTS)], rough=0.7, metal=0.25)
    rust = k_mat("cube_rust_%d" % (which % 3), ("#7A3E22", "#8F4F2A", "#5E3220")[which % 3], rough=0.95, metal=0.1)
    steel = k_mat("cube_steel", "#7E8082", rough=0.5, metal=0.6)
    dark = k_mat("cube_dark", "#2E2622", rough=0.9)
    cx, cy, cz = center_bottom
    z = cz
    top = cz + size
    while z < top - 0.05:
        h = min(top - z, r.uniform(0.12, 0.3))
        m = r.choices((paint, rust, steel, dark), weights=(5, 3, 2, 1))[0]
        j = size * r.uniform(0.96, 1.04)
        b.box((cx + r.uniform(-0.04, 0.04), cy + r.uniform(-0.04, 0.04), z + h / 2), (j, size * r.uniform(0.96, 1.04), h), m,
              rot=(r.uniform(-2, 2), r.uniform(-2, 2), yaw + r.uniform(-3, 3)))
        z += h
    for k in range(r.randint(2, 4)):   # taşan sac parçaları
        a = math.radians(yaw) + r.choice((0, 1, 2, 3)) * math.pi / 2
        d = size * 0.52
        b.box((cx + math.cos(a) * d, cy + math.sin(a) * d, cz + r.uniform(0.2, size - 0.2)),
              (r.uniform(0.25, 0.5), r.uniform(0.3, 0.7), 0.04), r.choice((paint, rust, steel)),
              rot=(r.uniform(-30, 30), r.uniform(-20, 20), math.degrees(a) + r.uniform(-40, 40)))
    if r.random() < 0.5:   # ezik jant
        a = math.radians(yaw)
        b.cyl((cx + math.cos(a) * size * 0.51, cy + math.sin(a) * size * 0.51, cz + size * r.uniform(0.3, 0.7)), size * 0.18, 0.05,
              steel, axis='X', segs=10, rot=(r.uniform(-20, 20), 0, yaw))


# --- Konteyner, açık kasa ------------------------------------------------------------------

def container(col, name, color, length=12.0, loc=(0, 0, 0), rot=(0, 0, 0), rust=0.3, open_top=False, height=2.6, doors=True):
    """Nakliye konteyneri: uzun yanlar ve üst oluklu (kaburgalı), köşe dikmeleri, alt/üst kirişler, uçta çift
    kapı (dikey çıta + 4 kilit kolu). open_top → üstü açık hurda kasası (yükseklik ayrı)."""
    W, H = 2.44, height
    body = k_mat("cont_%s" % color.lstrip("#"), color, rough=0.6, metal=0.35)
    frame = k_mat("cont_frame", "#2C2A28", rough=0.6, metal=0.5)
    rustm = k_mat("rust_streak", "#7A3E22", rough=0.95, metal=0.1)
    steel = kit_mats()["steel"]
    b = Builder(name)
    for side in (-1, 1):
        b.corrugated((-length / 2, side * W / 2, 0.12), length, H - 0.24, body, period=0.28, depth=0.04)
    b.corrugated((-length / 2 + 0.0, -W / 2, 0), W, H - 0.24, body, period=0.28, depth=0.03, rot=(0, 0, 0), along='Y') if False else None
    # Uç duvarları: arkada düz panel, önde kapı
    b.box((-length / 2 + 0.03, 0, H / 2), (0.06, W - 0.1, H - 0.24), body)
    b.box((length / 2 - 0.03, 0, H / 2), (0.06, W - 0.1, H - 0.24), body)
    if not open_top:
        b.box((0, 0, H - 0.04), (length - 0.1, W - 0.1, 0.06), body)
    # Çerçeve: köşe dikmeleri + alt/üst boyuna kirişler
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * (length / 2 - 0.08), sy * (W / 2 - 0.06), H / 2), (0.16, 0.14, H), frame)
        b.box((0, sx * (W / 2 - 0.04), 0.07), (length, 0.1, 0.14), frame)
        b.box((0, sx * (W / 2 - 0.04), H - 0.07), (length, 0.1, 0.14), frame)
    if doors:
        x = length / 2 + 0.01
        b.box((x, 0, H / 2), (0.02, 0.02, H - 0.3), frame)   # kapı aralığı
        for k, y in enumerate((-0.75, -0.3, 0.3, 0.75)):
            b.cyl((x + 0.04, y, H / 2), 0.025, H - 0.4, steel, segs=6)
            b.box((x + 0.05, y + 0.06, H / 2 - 0.2), (0.03, 0.14, 0.05), steel)
        for z in (0.5, H - 0.5):
            b.box((x + 0.01, 0, z), (0.02, W - 0.2, 0.05), frame)
    # Pas akıntıları (rastgele dikey şeritler)
    r = random.Random(hash(name) & 0xffff)
    for k in range(int(6 * rust)):
        x = r.uniform(-length / 2 + 0.5, length / 2 - 0.5)
        side = r.choice((-1, 1))
        hh = r.uniform(0.5, H * 0.8)
        b.box((x, side * (W / 2 + 0.05), H - 0.2 - hh / 2), (r.uniform(0.12, 0.3), 0.01, hh), rustm)
    return b.finish(col, loc=loc, rot=rot)


def scrap_bin(col, name, color, length=6.0, loc=(0, 0, 0), rot=0.0, seed=1):
    """Orijinaldeki gibi: üstü açık hurda kasası, içinden sac / kabuk / boru / jant taşıyor."""
    o = container(col, name + "_box", color, length=length, height=1.7, open_top=True, doors=False, loc=loc, rot=(0, 0, rot))
    r = random.Random(seed)
    b = Builder(name + "_junk")
    paints = ["#9C4A32", "#6F7F86", "#B58A4A", "#5E6B55", "#8A6E5A", "#A7A196", "#4F5A63"]
    steel = kit_mats()["steel"]
    rubber = kit_mats()["rubber"]
    for i in range(18):
        px, py = r.uniform(-length / 2 + 0.6, length / 2 - 0.6), r.uniform(-0.8, 0.8)
        pz = r.uniform(1.2, 2.1)
        k = r.random()
        m = k_mat("paint_%s" % paints[i % len(paints)].lstrip("#"), paints[i % len(paints)], rough=0.7, metal=0.25)
        if k < 0.22:
            wreck_into(b, r.randrange(99), (px, py, pz - 0.9), r.uniform(0, 360), pitch=r.uniform(-25, 25),
                       roll=r.uniform(-25, 25), crush=r.uniform(0.35, 0.6), low=True, scale=0.7)
        elif k < 0.65:
            b.box((px, py, pz), (r.uniform(0.8, 1.8), r.uniform(0.5, 1.2), 0.05), m,
                  rot=(r.uniform(-60, 60), r.uniform(-40, 40), r.uniform(0, 180)))
        elif k < 0.82:
            b.cyl((px, py, pz), r.uniform(0.05, 0.1), r.uniform(1.2, 2.6), steel, axis='X', segs=8,
                  rot=(0, r.uniform(-40, 40), r.uniform(0, 180)))
        elif k < 0.92:
            b.cyl((px, py, pz), 0.4, 0.26, rubber, segs=14, rot=(r.uniform(-60, 60), r.uniform(-30, 30), 0))
        else:
            b.cyl((px, py, pz), 0.33, 0.16, steel, segs=14, rot=(r.uniform(-60, 60), 0, 0))
    j = b.finish(col, loc=loc, rot=(0, 0, rot))
    return o, j


# --- Jant kapaklı duvar, sokak lambası, lastik yığını ---------------------------------------

def hubcap_wall(col, name, length=8.0, loc=(0, 0, 0), rot=0.0):
    """Orijinaldeki koyu duvar: dikey tahtalar + direkler, üç sıra jant kapağı ve birkaç plaka / tabela."""
    wood = k_mat("wall_wood", "#3B302A", rough=0.9)
    wood2 = k_mat("wall_wood2", "#2E2622", rough=0.9)
    chrome = kit_mats()["chrome"]
    steel = kit_mats()["steel"]
    b = Builder(name)
    H = 2.8
    n = int(length / 0.32)
    for i in range(n):
        x = -length / 2 + (i + 0.5) * length / n
        b.box((x, 0, H / 2 + (0.03 if i % 3 == 0 else 0)), (length / n - 0.02, 0.08, H + (0.06 if i % 3 == 0 else 0)),
              wood if i % 2 else wood2)
    for x in (-length / 2, 0, length / 2):
        b.box((x, 0.08, H / 2 + 0.1), (0.16, 0.16, H + 0.2), wood2)
    r = random.Random(len(name))
    for row, z in enumerate((0.75, 1.5, 2.25)):
        for k in range(int(length / 0.75)):
            x = -length / 2 + 0.45 + k * 0.75 + (0.2 if row % 2 else 0)
            if x > length / 2 - 0.35:
                continue
            rad = r.uniform(0.2, 0.27)
            b.cyl((x, -0.08, z), rad, 0.04, chrome if r.random() < 0.75 else steel, axis='Y', segs=10)
            b.cyl((x, -0.11, z), rad * 0.45, 0.03, steel, axis='Y', segs=7)
    plate = k_mat("license_plate", "#E8E2CF", rough=0.6)
    for k in range(3):
        b.box((-length / 2 + 1.2 + k * 2.6, -0.07, 2.75), (0.52, 0.02, 0.12), plate)
    return b.finish(col, loc=loc, rot=(0, 0, rot))


def street_lamp(col, name, loc=(0, 0, 0), rot=0.0, height=6.0):
    """Kavisli kollu sokak lambası (orijinaldeki gibi): gövde, kol, başlık, yanan ampul."""
    dark = k_mat("lamp_metal", "#3A3836", rough=0.5, metal=0.6)
    glow = k_mat("lamp_glow", "#FFF0C6", emit="#FFE0A0", strength=9.0)
    b = Builder(name)
    b.cyl((0, 0, 0.15), 0.2, 0.3, dark, segs=10)
    b.cyl((0, 0, height / 2), 0.08, height, dark, segs=8, r2=0.06)
    pts = []
    for k in range(7):
        a = math.radians(90 - k * 15)
        pts.append((0.9 - math.cos(a) * 0.9 + 0.0, 0, height - 0.9 + math.sin(a) * 0.9 + 0.0))
    pts = [(p[0] * 1.0, 0, p[2]) for p in pts]
    b.tube([(0, 0, height - 0.9)] + [(0.9 - math.cos(math.radians(k * 15)) * 0.9, 0, height - 0.9 + math.sin(math.radians(k * 15)) * 0.9) for k in range(1, 7)], 0.05, dark)
    hx = 0.9 + 0.35
    b.cyl((hx, 0, height - 0.05), 0.05, 0.6, dark, axis='X', segs=6)
    b.cyl((hx + 0.25, 0, height - 0.2), 0.38, 0.22, dark, segs=14, r2=0.12)
    b.cyl((hx + 0.25, 0, height - 0.33), 0.3, 0.04, glow, segs=14)
    return b.finish(col, loc=loc, rot=(0, 0, rot))


def tire_stack(col, name, count=5, loc=(0, 0, 0), seed=1, lean=True):
    """Lastik yığını: içi boş görünen lastikler (dış silindir + koyu iç disk + jant izi)."""
    r = random.Random(seed)
    rubber = kit_mats()["rubber"]
    inner = k_mat("tire_inner", "#0E0E0E", rough=1.0)
    b = Builder(name)
    z = 0.0
    for k in range(count):
        ox, oy = r.uniform(-0.08, 0.08), r.uniform(-0.08, 0.08)
        tilt = (r.uniform(-6, 6), r.uniform(-6, 6), 0) if lean else (0, 0, 0)
        b.cyl((ox, oy, z + 0.14), 0.46, 0.27, rubber, segs=18, rot=tilt)
        b.cyl((ox, oy, z + 0.141), 0.25, 0.275, inner, segs=14, rot=tilt)
        z += 0.27
    return b.finish(col, loc=loc)


# --- Baraka (Hurdacı Necati) ---------------------------------------------------------------

def shack(col, name="Shack", loc=(0, 0, 0), rot=0.0):
    """Orijinaldeki JUNK barakası: dikey tahta duvarlar, beşik oluklu sac çatı, çatı sırtında oval tabela
    (yazı Godot'ta Label3D), ışığı yanan iki pencere (kayıt + çıtalar), kapı + saçak, ön verandada koltuk,
    masa, soba ve bacası, yağmur oluğu. Ön cephe +X (kameraya / girişe döner)."""
    w1 = k_mat("shack_wood", "#6B4A30", rough=0.9)
    w2 = k_mat("shack_wood2", "#56391F", rough=0.9)
    w3 = k_mat("shack_wood3", "#7C5838", rough=0.9)
    trim = k_mat("shack_trim", "#3A2A1E", rough=0.85)
    tin = k_mat("roof_tin", "#6B6660", rough=0.6, metal=0.45)
    tin_rust = k_mat("roof_rust", "#7A4A2E", rough=0.9, metal=0.15)
    glow = k_mat("window_lit", "#FFD27A", emit="#FFAE45", strength=5.0)
    sign_face = k_mat("sign_face", "#E3B046", rough=0.6, metal=0.2)
    sign_rim = k_mat("sign_rim", "#2E3B44", rough=0.4, metal=0.6)
    dark = k_mat("lamp_metal", "#3A3836", rough=0.5, metal=0.6)
    L, Wd, H, ridge = 8.0, 6.0, 3.2, 1.6
    b = Builder(name)
    # Duvarlar: dikey tahtalar (renkleri karışık), dört cephe
    r = random.Random(3)
    planks = [w1, w2, w3]
    step = 0.3
    for face in ("front", "back", "left", "right"):
        if face in ("front", "back"):
            n = int(Wd / step)
            x = L / 2 if face == "front" else -L / 2
            for i in range(n):
                y = -Wd / 2 + (i + 0.5) * Wd / n
                b.box((x, y, H / 2), (0.08, Wd / n - 0.015, H + r.uniform(-0.05, 0.05)), r.choice(planks))
            # Beşik üçgeni (alın)
            for i in range(n):
                y = -Wd / 2 + (i + 0.5) * Wd / n
                hh = ridge * (1 - abs(y) / (Wd / 2))
                if hh > 0.05:
                    b.box((x, y, H + hh / 2), (0.08, Wd / n - 0.015, hh), r.choice(planks))
        else:
            n = int(L / step)
            y = Wd / 2 if face == "left" else -Wd / 2
            for i in range(n):
                xx = -L / 2 + (i + 0.5) * L / n
                b.box((xx, y, H / 2), (L / n - 0.015, 0.08, H + r.uniform(-0.05, 0.05)), r.choice(planks))
    # Köşe dikmeleri
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * L / 2, sy * Wd / 2, H / 2), (0.18, 0.18, H), trim)
    # Beşik çatı: sırt X boyunca; iki yüzey sırttan (y=0, z=H+ridge) saçağa (y=±(Wd/2+0.5)) iner.
    # Her yüzey dar sac şeritlerinden: renkleri karışık (yer yer paslı), hafif dalgalı.
    eave = Wd / 2 + 0.5
    drop = ridge * eave / (Wd / 2)
    slope = math.atan2(drop, eave)
    span = math.hypot(eave, drop)
    n = int((L + 1.0) / 0.25)
    for side in (-1, 1):
        tilt = (-side * math.degrees(slope), 0, 0)
        cy = side * eave / 2
        cz = H + ridge + 0.08 - drop / 2
        for i in range(n):
            x = -L / 2 - 0.5 + (i + 0.5) * (L + 1.0) / n
            m = tin_rust if r.random() < 0.25 else tin
            b.box((x, cy, cz + 0.015 * math.sin(i * 2.4)), ((L + 1.0) / n + 0.01, span, 0.05), m, rot=tilt)
    b.box((0, 0, H + ridge + 0.1), (L + 1.0, 0.25, 0.12), dark)   # sırt kapağı
    # Yağmur olukları
    for side in (-1, 1):
        b.cyl((0, side * (Wd / 2 + 0.5), H + 0.02), 0.06, L + 1.0, dark, axis='X', segs=6)
    # Ön cephe (+X): kapı + saçak + iki pencere
    fx = L / 2 + 0.05
    b.box((fx, -1.3, 1.1), (0.08, 1.1, 2.2), trim)
    b.box((fx + 0.03, -1.3, 1.1), (0.04, 0.95, 2.05), w2)
    b.cyl((fx + 0.08, -0.95, 1.05), 0.04, 0.06, dark, axis='X', segs=6)
    b.box((fx + 0.5, -1.3, 2.45), (1.0, 1.5, 0.08), tin, rot=(0, -15, 0))
    for y in (0.7, 2.1):
        b.box((fx, y, 1.6), (0.1, 1.0, 1.0), trim)
        b.box((fx + 0.02, y, 1.6), (0.04, 0.84, 0.84), glow)
        b.box((fx + 0.05, y, 1.6), (0.03, 0.05, 0.84), trim)
        b.box((fx + 0.05, y, 1.6), (0.03, 0.84, 0.05), trim)
    # Yan pencere (kameraya bakan güney yüz, -Y)
    b.box((1.0, -Wd / 2 - 0.05, 1.6), (1.2, 0.1, 0.9), trim)
    b.box((1.0, -Wd / 2 - 0.07, 1.6), (1.04, 0.04, 0.76), glow)
    # Veranda: tahta döşeme + koltuk + masa + soba borusu
    for i in range(10):
        b.box((fx + 1.0, -Wd / 2 + 0.3 + i * 0.58, 0.1), (2.0, 0.55, 0.12), r.choice(planks))
    chair = k_mat("chair", "#7A3B32", rough=0.8)
    b.box((fx + 1.2, 0.9, 0.45), (0.8, 0.8, 0.5), chair)
    b.box((fx + 0.9, 0.9, 0.9), (0.2, 0.8, 0.6), chair)
    b.box((fx + 1.3, 2.0, 0.45), (0.7, 0.6, 0.7), w2)
    stove_x, stove_y = -L / 2 + 1.0, Wd / 2 - 1.0
    b.cyl((stove_x, stove_y, H + ridge * 0.5 + 0.8), 0.12, 2.0, dark, segs=8)
    b.cyl((stove_x, stove_y, H + ridge * 0.5 + 1.85), 0.22, 0.12, dark, segs=8, r2=0.05)
    # Çatı sırtında oval tabela (iki direk üstünde, kameraya dönük)
    sx, sz = 0.6, H + ridge + 1.3
    for y in (-0.9, 0.9):
        b.cyl((sx, y, H + ridge + 0.5), 0.05, 1.1, dark, segs=6)
    seg = 24
    face_pts, rim_o = [], []
    for i in range(seg):
        a = math.tau * i / seg
        face_pts.append((sx + 0.06, math.cos(a) * 1.7, sz + math.sin(a) * 0.7))
    b._add(face_pts, [tuple(range(seg))], sign_face)
    for i in range(seg):
        a0, a1 = math.tau * i / seg, math.tau * (i + 1) / seg
        p0 = (sx + 0.08, math.cos(a0) * 1.82, sz + math.sin(a0) * 0.8)
        p1 = (sx + 0.08, math.cos(a1) * 1.82, sz + math.sin(a1) * 0.8)
        b.tube([p0, p1], 0.07, sign_rim, segs=6)
    b.box((sx - 0.02, 0, sz), (0.06, 3.3, 1.3), sign_rim)
    return b.finish(col, loc=loc, rot=(0, 0, rot))


# --- Vinç, pres, çit -------------------------------------------------------------------------

def magnet_crane(col, name="Crane", loc=(0, 0, 0), rot=0.0, boom_yaw=-130.0, boom_len=11.0, boom_pitch=38.0,
                 carry=True):
    """Tırtıllı mıknatıslı vinç: palet + döner tabla + kabin (camlı) + karşı ağırlık + kafes bom + halat +
    zincirli mıknatıs; carry=True → mıknatısa yapışık hurda araba. Bom, kabinin önünden boom_yaw yönüne uzanır.
    Mıknatıs ve araba ayrı nesnedir (Godot'ta sallanma animasyonu): <name>_Hook döner."""
    yellow = k_mat("crane_yellow", "#E0A81E", rough=0.5, metal=0.25)
    dark = k_mat("crane_dark", "#2B2926", rough=0.6, metal=0.55)
    glass = k_mat("glass_dark", "#2A3338", rough=0.25, metal=0.3)
    stripe = k_mat("hazard_black", "#1C1C1C", rough=0.6)
    steel = kit_mats()["steel"]
    b = Builder(name)
    # Paletler (tırtıl): gövde + papuç çıtaları
    for side in (-1, 1):
        b.box((0, side * 1.45, 0.5), (5.2, 0.9, 1.0), dark)
        for k in range(16):
            b.box((-2.5 + k * 0.33, side * 1.45, 1.02), (0.16, 0.92, 0.06), steel)
        for k in range(4):
            b.cyl((-1.8 + k * 1.2, side * 1.92, 0.5), 0.32, 0.08, steel, axis='Y', segs=12)
    b.box((0, 0, 1.15), (3.4, 2.2, 0.35), dark)
    b.cyl((0, 0, 1.45), 1.4, 0.3, yellow, segs=20)
    # Üst gövde: kabin (önde sağ), motor kaputu, karşı ağırlık (arkada)
    b.box((-0.3, 0, 2.3), (3.6, 2.6, 1.4), yellow)
    b.box((-2.0, 0, 2.2), (0.8, 2.8, 1.2), dark)
    for k in range(4):
        b.box((-2.42, -1.2 + k * 0.8, 2.2), (0.04, 0.35, 1.0), yellow if k % 2 else stripe)
    b.box((1.0, -0.75, 3.55), (1.6, 1.2, 1.6), yellow)
    b.box((1.81, -0.75, 3.6), (0.04, 1.05, 1.2), glass)
    b.box((1.0, -1.36, 3.6), (1.4, 0.04, 1.2), glass)
    b.box((1.0, -0.75, 4.38), (1.75, 1.35, 0.08), dark)
    b.cyl((-0.9, 0.8, 3.5), 0.1, 1.0, dark, segs=8)   # egzoz
    # Kafes bom: iki alt + bir üst boyuna boru, aralarında zikzak çapraz
    yaw, pitch = math.radians(boom_yaw), math.radians(boom_pitch)
    base = (1.4, 0.55, 3.0)
    dirv = (math.cos(yaw) * math.cos(pitch), math.sin(yaw) * math.cos(pitch), math.sin(pitch))
    side = (-math.sin(yaw), math.cos(yaw), 0.0)
    up = (-math.cos(yaw) * math.sin(pitch), -math.sin(yaw) * math.sin(pitch), math.cos(pitch))
    def at(t, s, u):
        return (base[0] + dirv[0] * t + side[0] * s + up[0] * u,
                base[1] + dirv[1] * t + side[1] * s + up[1] * u,
                base[2] + dirv[2] * t + side[2] * s + up[2] * u)
    w, hgt = 0.45, 0.6
    chords = [(-w, 0), (w, 0), (0, hgt)]
    for (cs, cu) in chords:
        b.tube([at(0, cs, cu), at(boom_len, cs * 0.5, cu * 0.5)], 0.07, yellow, segs=6)
    segs = 10
    for k in range(segs):
        t0, t1 = boom_len * k / segs, boom_len * (k + 1) / segs
        f0, f1 = 1 - 0.5 * k / segs, 1 - 0.5 * (k + 1) / segs
        a, bb = chords[k % 3], chords[(k + 1) % 3]
        b.tube([at(t0, a[0] * f0, a[1] * f0), at(t1, bb[0] * f1, bb[1] * f1)], 0.04, yellow, segs=5)
        b.tube([at(t1, -w * f1, 0), at(t1, w * f1, 0)], 0.035, yellow, segs=5)
    tip = at(boom_len, 0, 0)
    b.cyl(tip, 0.22, 0.3, dark, axis='Y', segs=12, rot=(0, 0, math.degrees(yaw)))
    # Askı halatı (tepeden kabin arkasına) — bomu tutan halatlar
    b.tube([at(boom_len, 0, hgt * 0.5), (-1.6, 0.0, 4.2)], 0.025, dark, segs=4)
    obj = b.finish(col, loc=loc, rot=(0, 0, rot))
    # Kanca: halat + mıknatıs + zincirler (+ araba) ayrı nesne, tepe noktasında asılı
    hb = Builder(name + "_Hook")
    drop = 4.0
    hb.cyl((0, 0, -drop / 2), 0.04, drop, dark, segs=5)
    for k in range(3):
        a = math.tau * k / 3
        hb.tube([(0, 0, -drop), (math.cos(a) * 0.9, math.sin(a) * 0.9, -drop - 0.55)], 0.03, steel, segs=4)
    hb.cyl((0, 0, -drop - 0.8), 1.2, 0.5, dark, segs=24)
    hb.cyl((0, 0, -drop - 0.52), 0.5, 0.08, stripe, segs=16)
    for k in range(12):
        a = math.tau * k / 12
        hb.box((math.cos(a) * 1.21, math.sin(a) * 1.21, -drop - 0.8), (0.08, 0.08, 0.5), yellow if k % 2 else stripe,
               rot=(0, 0, math.degrees(a)))
    if carry:
        car = k_mat("paint_9C4A32", "#9C4A32", rough=0.7, metal=0.25)
        wreck_into(hb, "chevrolet_bel_air_1956", (0, 0, -drop - 1.05 - 1.5), 25, pitch=6, roll=-8)
    # tip noktası (dünya) — kancanın asılacağı yer
    rz = math.radians(rot)
    tx, ty = tip[0] * math.cos(rz) - tip[1] * math.sin(rz), tip[0] * math.sin(rz) + tip[1] * math.cos(rz)
    hook = hb.finish(col, loc=(loc[0] + tx, loc[1] + ty, loc[2] + tip[2]))
    return obj, hook


def car_press(col, name="Press", loc=(0, 0, 0), rot=0.0):
    """Hurda araç presi: beton taban, iki mavi kolon, üst kiriş, 2 hidrolik piston + çene (Ram ayrı nesne),
    uyarı şeritleri, kumanda dolabı, hortumlar; içinde yarı ezilmiş araç."""
    blue = k_mat("press_blue", "#3A6E9A", rough=0.5, metal=0.35)
    dark = k_mat("crane_dark", "#2B2926", rough=0.6, metal=0.55)
    yellow = k_mat("crane_yellow", "#E0A81E", rough=0.5, metal=0.25)
    black = k_mat("hazard_black", "#1C1C1C", rough=0.6)
    concrete = k_mat("concrete", "#9A938A", rough=0.95)
    steel = kit_mats()["steel"]
    b = Builder(name)
    L, Wd = 9.0, 4.4
    b.box((0, 0, 0.4), (L + 1.0, Wd + 1.0, 0.8), concrete)
    b.box((0, 0, 1.0), (L, Wd, 0.4), dark)
    for sx in (-1, 1):
        b.box((sx * (L / 2 - 0.5), 0, 3.4), (1.0, Wd, 4.6), blue)
        for k in range(8):   # sarı-siyah uyarı şeridi kolonların dibinde
            b.box((sx * (L / 2 - 0.5) + (0.51 if sx < 0 else -0.51), -Wd / 2 + 0.27 + k * 0.55, 1.5), (0.02, 0.5, 0.35),
                  yellow if k % 2 else black)
    b.box((0, 0, 6.1), (L, Wd, 0.9), blue)
    for x in (-2.0, 2.0):
        b.cyl((x, 0, 7.3), 0.45, 1.6, dark, segs=14)
        b.cyl((x, 0, 6.0 - 0.6), 0.22, 1.4, steel, segs=12)
    # Kumanda dolabı + hortumlar
    b.box((L / 2 + 0.9, -Wd / 2 + 0.6, 1.4), (0.6, 0.8, 1.6), yellow)
    b.box((L / 2 + 1.21, -Wd / 2 + 0.6, 1.6), (0.02, 0.5, 0.5), dark)
    b.tube([(L / 2 + 0.9, -Wd / 2 + 0.6, 2.2), (L / 2 + 0.6, -Wd / 2 + 0.4, 4.0), (2.0, -Wd / 2 + 0.2, 7.2)], 0.06, black, segs=6)
    b.tube([(L / 2 + 0.9, -Wd / 2 + 0.8, 2.2), (L / 2 + 0.5, -Wd / 2 + 0.9, 5.5), (-2.0, -Wd / 2 + 0.2, 7.2)], 0.06, black, segs=6)
    # İçinde yarı ezilmiş araç
    wreck_into(b, "mercedes_w123", (0, 0, 1.2), 0, crush=0.42, low=True)
    obj = b.finish(col, loc=loc, rot=(0, 0, rot))
    rb = Builder(name + "_Ram")
    rb.box((0, 0, 0), (L - 2.2, Wd - 0.5, 0.6), dark)
    for k in range(6):
        rb.box((-(L - 2.2) / 2 + 0.6 + k * 1.1, -(Wd - 0.5) / 2 - 0.01, 0), (0.55, 0.02, 0.5), yellow if k % 2 else black)
    rz = math.radians(rot)
    ram = rb.finish(col, loc=(loc[0], loc[1], loc[2] + 4.7), rot=(0, 0, rot))
    return obj, ram


def fence_run(col, name, start, end, height=2.3, seed=1, gap=None):
    """Oluklu sac çit hattı: 3 m'lik paneller (bir kısmı paslı, hafif eğri), direkler, üstte dikenli tel."""
    sheet = k_mat("corrugated", "#8A7864", rough=0.6, metal=0.4)
    rustm = k_mat("rust_8F4F2A", "#8F4F2A", rough=0.95, metal=0.1)
    post = k_mat("crane_dark", "#2B2926", rough=0.6, metal=0.55)
    wire = k_mat("wire", "#2A2826", rough=0.5, metal=0.6)
    r = random.Random(seed)
    b = Builder(name)
    dx, dy = end[0] - start[0], end[1] - start[1]
    length = math.hypot(dx, dy)
    yaw = math.degrees(math.atan2(dy, dx))
    n = max(1, int(round(length / 3.0)))
    seg = length / n
    for i in range(n):
        t0 = i * seg
        if gap and gap[0] < t0 + seg / 2 < gap[1]:
            continue
        h = height + r.uniform(-0.25, 0.1)
        m = rustm if r.random() < 0.3 else sheet
        b.corrugated((t0, 0, 0), seg, h, m, period=0.2, depth=0.045, rot=(r.uniform(-2, 2), 0, 0))
        b.box((t0, 0.06, (height + 0.5) / 2), (0.12, 0.12, height + 0.5), post)
        if not (gap and gap[0] < t0 + seg * 1.5 < gap[1]):
            for z in (height + 0.2, height + 0.4):
                b.box((t0 + seg / 2, 0.06, z), (seg, 0.025, 0.025), wire)
    return b.finish(col, loc=(start[0], start[1], 0), rot=(0, 0, yaw))


def fire_barrel(col, name, loc, seed=0):
    """Ateş varili: paslı varil (çemberli, delikli), içinde kor, üstte üç kıvrık alev dili (ışıklı)."""
    r = random.Random(seed)
    barrel = k_mat("barrel_rust", "#6E3B26", rough=0.85, metal=0.3)
    hoop = k_mat("frame_dark", "#2E2622", rough=0.8, metal=0.5)
    ember = k_mat("ember", "#FF7A2A", emit="#FF5A12", strength=14.0)
    flame_o = k_mat("flame_outer", "#FF8A2A", emit="#FF6A1A", strength=10.0)
    flame_i = k_mat("flame_inner", "#FFD27A", emit="#FFC14A", strength=16.0)
    b = Builder(name, seed=seed)
    b.cyl((0, 0, 0.45), 0.33, 0.9, barrel, segs=16)
    for z in (0.15, 0.45, 0.75):
        b.cyl((0, 0, z), 0.345, 0.05, hoop, segs=16)
    for k in range(6):   # hava delikleri (koru gösteren ışıklı yarıklar)
        a = math.tau * k / 6 + 0.3
        b.box((math.cos(a) * 0.335, math.sin(a) * 0.335, 0.3), (0.05, 0.12, 0.1), ember, rot=(0, 0, math.degrees(a)))
    b.cyl((0, 0, 0.88), 0.28, 0.04, ember, segs=14)
    for k in range(3):
        a = math.tau * k / 3 + r.uniform(-0.3, 0.3)
        ox, oy = math.cos(a) * 0.1, math.sin(a) * 0.1
        h = r.uniform(0.7, 1.0)
        # Alev dili: üst üste küçülen, kıvrılarak kayan kesik koniler
        for j, (rad, hh, m) in enumerate(((0.2, 0.35, flame_o), (0.14, 0.3, flame_o), (0.08, 0.25, flame_i))):
            z = 0.9 + j * 0.28 * h
            b.cyl((ox * (1 + j * 0.6), oy * (1 + j * 0.6), z + hh * h / 2), rad, hh * h, m, segs=7, r2=rad * 0.45,
                  rot=(r.uniform(-12, 12), r.uniform(-12, 12), 0))
    return b.finish(col, loc=loc, ao=False)


# --- Necati'nin barakası v2 (kullanıcı 2026-10-11: "kulübe saçma duruyor, güzelleştir, yerini güncelle") ---

def shack_v2(col, name="Shack", loc=(0, 0, 0), rot=0.0, seed=4):
    """Hurdacı Necati'nin barakası. Yerel eksen: ön cephe -Y (giriş yoluna / kameraya), sırt Y boyunca.
      gövde       9 × 6,5 m, beton bloklar üstünde 0,45 m yükseltilmiş, dikey tahta kaplama (karışık tonlar)
      çatı        beşik oluklu sac (yer yer paslı), saçaklar taşar, sırt kapağı; ön alın tahta
      veranda     önde 2,6 m derin döşeme, iki basamak, korkuluk, eğik sac sundurma + 4 direk,
                  sundurma ön kenarında ampul çerçeveli büyük tabela (yazı Godot'ta Label3D: HURDACI NECATİ),
                  direkler arasında sarkan ampul dizisi
      cephe       kapı (saçaklı, solgun turkuaz), iki ışıklı pencere (kayıt, çıta, kanatlı panjur),
                  duvarda jant kapakları + plakalar
      doğu yanı   açık atölye sundurması: tezgâh, alet panosu, sehpada motor, lastikler
      eşyalar     araba koltuğundan bank, soğutucu, varil sehpa, soba bacası
    """
    r = random.Random(seed)
    planks = [k_mat("shack_wood", "#6B4A30", rough=0.9), k_mat("shack_wood2", "#56391F", rough=0.9),
              k_mat("shack_wood3", "#7C5838", rough=0.9)]
    trim = k_mat("shack_trim", "#3A2A1E", rough=0.85)
    deck = k_mat("deck_wood", "#8A6A48", rough=0.9)
    teal = k_mat("shutter_teal", "#3F7F7A", rough=0.8)
    tin = k_mat("roof_tin", "#6B6660", rough=0.6, metal=0.45)
    tin_rust = k_mat("roof_rust", "#7A4A2E", rough=0.9, metal=0.15)
    block = k_mat("cinder_block", "#8E8A84", rough=0.95)
    dark = k_mat("lamp_metal", "#3A3836", rough=0.5, metal=0.6)
    glow = k_mat("window_lit", "#FFD27A", emit="#FFAE45", strength=5.0)
    bulb = k_mat("bulb", "#FFD27A", emit="#FFB84A", strength=8.0)
    sign_face = k_mat("sign_cream", "#E8DCC0", rough=0.7)
    sign_red = k_mat("sign_red", "#A8342A", rough=0.6)
    chrome = kit_mats()["chrome"]
    steel = kit_mats()["steel"]
    rubber = kit_mats()["rubber"]
    b = Builder(name, seed=seed)
    L, Dp, F, H, ridge = 9.0, 6.5, 0.45, 3.0, 1.8
    hx, hy = L / 2, Dp / 2
    top = F + H
    # Temel: beton bloklar (çevre), aralarda gölge boşlukları
    for x in [-hx + 0.25 + i * 0.85 for i in range(11)]:
        for y in (-hy + 0.2, hy - 0.2):
            b.box((x, y, F / 2), (0.7, 0.35, F), block)
    for y in [-hy + 0.6 + i * 0.85 for i in range(7)]:
        for x in (-hx + 0.2, hx - 0.2):
            b.box((x, y, F / 2), (0.35, 0.7, F), block)
    b.box((0, 0, F - 0.05), (L - 0.2, Dp - 0.2, 0.1), trim)
    # Duvarlar: dikey tahtalar
    step = 0.3
    for face in ("front", "back", "left", "right"):
        if face in ("front", "back"):
            n = int(L / step)
            y = -hy if face == "front" else hy
            for i in range(n):
                x = -hx + (i + 0.5) * L / n
                hh = H + r.uniform(-0.04, 0.04)
                b.box((x, y, F + hh / 2), (L / n - 0.012, 0.08, hh), r.choice(planks))
                g = ridge * (1 - abs(x) / hx)
                if g > 0.05:
                    b.box((x, y, top + g / 2), (L / n - 0.012, 0.08, g), r.choice(planks))
        else:
            n = int(Dp / step)
            x = -hx if face == "left" else hx
            for i in range(n):
                y = -hy + (i + 0.5) * Dp / n
                b.box((x, y, F + H / 2), (0.08, Dp / n - 0.012, H + r.uniform(-0.04, 0.04)), r.choice(planks))
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.box((sx * hx, sy * hy, F + H / 2), (0.2, 0.2, H), trim)
    # Beşik çatı: sırt Y boyunca (ön alın kameraya bakar), saçak 0,6 m
    eave = hx + 0.6
    drop = ridge * eave / hx
    slope = math.atan2(drop, eave)
    span = math.hypot(eave, drop)
    n = int((Dp + 1.4) / 0.26)
    for side in (-1, 1):
        tilt = (0, side * math.degrees(slope), 0)
        cx = side * eave / 2
        cz = top + ridge + 0.1 - drop / 2
        for i in range(n):
            y = -hy - 0.7 + (i + 0.5) * (Dp + 1.4) / n
            m = tin_rust if r.random() < 0.22 else tin
            b.box((cx, y, cz + 0.015 * math.sin(i * 2.1)), (span, (Dp + 1.4) / n + 0.01, 0.05), m, rot=tilt)
    b.box((0, 0, top + ridge + 0.14), (0.3, Dp + 1.4, 0.12), dark)
    for sx in (-1, 1):   # alın tahtaları (saçak kenarı)
        b.tube([(0, -hy - 0.72, top + ridge + 0.1), (sx * eave, -hy - 0.72, top + 0.1 - (drop - ridge))], 0.07, trim, segs=4)
    # Ön cephe: kapı + iki pencere
    fy = -hy - 0.06
    b.box((-2.2, fy, F + 1.15), (1.3, 0.1, 2.3), trim)
    b.box((-2.2, fy - 0.03, F + 1.1), (1.1, 0.05, 2.15), teal)
    for z in (F + 0.6, F + 1.6):
        b.box((-2.2, fy - 0.06, z), (0.9, 0.03, 0.06), trim)
    b.cyl((-1.8, fy - 0.08, F + 1.1), 0.04, 0.06, chrome, axis='Y', segs=6)
    b.box((-2.2, fy - 0.45, F + 2.55), (1.6, 0.9, 0.06), tin, rot=(-12, 0, 0))
    for wx in (1.0, 3.0):
        b.box((wx, fy, F + 1.65), (1.2, 0.1, 1.15), trim)
        b.box((wx, fy - 0.02, F + 1.65), (1.0, 0.05, 0.95), glow)
        b.box((wx, fy - 0.06, F + 1.65), (0.05, 0.03, 0.95), trim)
        b.box((wx, fy - 0.06, F + 1.65), (1.0, 0.03, 0.05), trim)
        for sx in (-1, 1):   # açık panjur kanatları
            b.box((wx + sx * 0.88, fy - 0.08, F + 1.65), (0.5, 0.05, 1.1), teal, rot=(0, 0, sx * 12))
        b.box((wx, fy - 0.18, F + 1.02), (1.15, 0.28, 0.08), trim)   # pencere önü rafı
    for k, x in enumerate((-3.9, -3.3, -0.6, 4.0)):
        b.cyl((x, fy - 0.07, F + 2.3 + (k % 2) * 0.35), 0.24, 0.04, chrome, axis='Y', segs=16)
        b.cyl((x, fy - 0.1, F + 2.3 + (k % 2) * 0.35), 0.1, 0.03, steel, axis='Y', segs=10)
    # Ön alında yuvarlak "HURDA" plakası (eski oval tabelanın yerine, duvara asılı)
    b.cyl((0, -hy - 0.12, top + 0.75), 0.55, 0.06, sign_red, axis='Y', segs=24)
    b.cyl((0, -hy - 0.16, top + 0.75), 0.45, 0.04, sign_face, axis='Y', segs=24)
    # Doğu duvarı: pencere + plakalar
    ex = hx + 0.06
    b.box((ex, 1.2, F + 1.65), (0.1, 1.2, 1.1), trim)
    b.box((ex + 0.02, 1.2, F + 1.65), (0.05, 1.0, 0.9), glow)
    plate = k_mat("license_plate", "#E8E2CF", rough=0.6)
    for k, (y, z) in enumerate(((-2.4, F + 2.6), (-1.6, F + 2.4), (-2.0, F + 2.0))):
        b.box((ex + 0.05, y, z), (0.02, 0.55, 0.13), plate, rot=(r.uniform(-8, 8), 0, 0))
    # Veranda: döşeme, basamaklar, korkuluk, sundurma + direkler
    pd = 2.6
    py0, py1 = -hy - pd, -hy
    n = 16
    for i in range(n):
        x = -hx + (i + 0.5) * L / n
        b.box((x, (py0 + py1) / 2, F - 0.04), (L / n - 0.03, pd, 0.08), deck)
    for x in (-hx + 0.15, -1.0, 1.5, hx - 0.15):
        for y in (py0 + 0.15,):
            b.box((x, y, F / 2), (0.2, 0.2, F), trim)
    for k in range(2):
        b.box((-2.2, py0 - 0.3 - k * 0.32, (F - 0.05) * (1 - k * 0.5) / 2 + 0.0), (1.6, 0.32, (F - 0.05) * (1 - k * 0.5)), deck)
    posts = [-hx + 0.15, -0.9, 2.2, hx - 0.15]
    for x in posts:
        b.box((x, py0 + 0.15, F + 1.3), (0.18, 0.18, 2.6), trim)
    for (xa, xb) in ((-hx + 0.15, -3.0), (-1.4, 2.2), (2.2, hx - 0.15)):
        for z in (F + 0.45, F + 0.95):
            b.box(((xa + xb) / 2, py0 + 0.15, z), (abs(xb - xa), 0.07, 0.07), trim)
        k = int(abs(xb - xa) / 0.4)
        for i in range(1, k):
            b.box((xa + (xb - xa) * i / k, py0 + 0.15, F + 0.7), (0.05, 0.05, 0.5), trim)
    porch_drop = 0.55
    pslope = math.degrees(math.atan2(porch_drop, pd + 0.4))
    nn = int((L + 0.6) / 0.26)
    for i in range(nn):
        x = -hx - 0.3 + (i + 0.5) * (L + 0.6) / nn
        m = tin_rust if r.random() < 0.2 else tin
        b.box((x, (py0 - 0.4 + py1) / 2, F + 2.95 - porch_drop / 2 + 0.015 * math.sin(i * 1.7)),
              ((L + 0.6) / nn + 0.01, pd + 0.45, 0.05), m, rot=(pslope, 0, 0))
    # Tabela: sundurmanın ön kenarında, ampul çerçeveli (yazı Godot'ta)
    sw, sh = 5.6, 1.2
    sy = py0 - 0.42
    sz = F + 2.95 - porch_drop + sh / 2 + 0.05
    b.box((0, sy, sz), (sw + 0.3, 0.12, sh + 0.3), sign_red)
    b.box((0, sy - 0.07, sz), (sw, 0.04, sh), sign_face)
    nb = 18
    for k in range(nb):
        x = -sw / 2 - 0.05 + (sw + 0.1) * k / (nb - 1)
        for z in (sz - sh / 2 - 0.1, sz + sh / 2 + 0.1):
            b.cyl((x, sy - 0.1, z), 0.06, 0.05, bulb, axis='Y', segs=6)
    for z in [sz - sh / 2 + i * sh / 3 for i in range(4)]:
        for x in (-sw / 2 - 0.1, sw / 2 + 0.1):
            b.cyl((x, sy - 0.1, z), 0.06, 0.05, bulb, axis='Y', segs=6)
    for x in (-sw / 2 + 0.3, sw / 2 - 0.3):
        b.box((x, sy + 0.1, sz - sh / 2 - 0.25), (0.1, 0.1, 0.5), dark)
    # Sarkan ampul dizisi (direkler arası, sundurma altı)
    for xa, xb in zip(posts[:-1], posts[1:]):
        pts = []
        for i in range(9):
            t = i / 8
            x = xa + (xb - xa) * t
            z = F + 2.35 - 0.35 * math.sin(math.pi * t)
            pts.append((x, py0 + 0.1, z))
        b.tube(pts, 0.012, dark, segs=4)
        for p in pts[1:-1]:
            b.cyl((p[0], p[1], p[2] - 0.08), 0.05, 0.1, bulb, segs=6)
    # Verandada: araba koltuğu bank, soğutucu, varil sehpa
    seat = k_mat("car_seat", "#8A2E26", rough=0.75)
    b.box((2.4, py0 + 1.3, F + 0.25), (1.6, 0.6, 0.35), seat)
    b.box((2.4, py0 + 1.65, F + 0.75), (1.6, 0.18, 0.75), seat, rot=(-12, 0, 0))
    cooler = k_mat("cooler_red", "#B0372C", rough=0.6)
    b.box((3.8, py0 + 1.4, F + 0.3), (0.7, 0.45, 0.5), cooler)
    b.box((3.8, py0 + 1.4, F + 0.57), (0.72, 0.47, 0.06), sign_face)
    b.cyl((1.0, py0 + 1.2, F + 0.4), 0.3, 0.8, k_mat("barrel_blue", "#2F5A8C", rough=0.7, metal=0.3), segs=14)
    # Soba bacası (arka sağ), şapkalı
    b.cyl((2.4, 1.6, top + ridge * 0.45 + 1.0), 0.12, 2.4, dark, segs=8)
    b.cyl((2.4, 1.6, top + ridge * 0.45 + 2.25), 0.24, 0.12, dark, segs=8, r2=0.05)
    # Doğu yanı: açık atölye sundurması
    ax0, ax1 = hx, hx + 3.0
    ay0, ay1 = -hy + 0.2, 1.4
    for (x, y) in ((ax1 - 0.1, ay0 + 0.1), (ax1 - 0.1, ay1 - 0.1)):
        b.box((x, y, 1.35), (0.16, 0.16, 2.7), trim)
    lslope = math.degrees(math.atan2(0.5, 3.2))
    nn = int((ay1 - ay0 + 0.4) / 0.26)
    for i in range(nn):
        y = ay0 - 0.2 + (i + 0.5) * (ay1 - ay0 + 0.4) / nn
        m = tin_rust if r.random() < 0.3 else tin
        b.box(((ax0 + ax1) / 2 + 0.1, y, 2.95), (3.4, (ay1 - ay0 + 0.4) / nn + 0.01, 0.05), m, rot=(0, lslope, 0))
    b.box((ax0 + 0.45, (ay0 + ay1) / 2, 0.85), (0.8, ay1 - ay0 - 0.4, 0.08), trim)        # tezgâh
    for y in (ay0 + 0.3, ay1 - 0.3):
        b.box((ax0 + 0.45, y, 0.42), (0.7, 0.08, 0.84), trim)
    b.box((ax0 + 0.08, (ay0 + ay1) / 2, 1.8), (0.06, ay1 - ay0 - 0.6, 1.1), k_mat("pegboard", "#9C8466", rough=0.9))
    for k in range(7):   # alet silüetleri panoda
        y = ay0 + 0.6 + k * (ay1 - ay0 - 1.2) / 6
        b.box((ax0 + 0.13, y, 1.8 + (k % 3 - 1) * 0.25), (0.03, 0.08, 0.45), steel if k % 2 else dark)
    eng = kit_mats()["engine"]
    b.box((ax0 + 1.8, -1.6, 0.9), (0.7, 0.5, 0.55), eng)
    b.cyl((ax0 + 1.8, -1.6, 0.4), 0.06, 0.8, dark, segs=6)
    b.box((ax0 + 1.8, -1.6, 0.04), (0.8, 0.8, 0.08), dark)
    for k in range(3):
        b.cyl((ax0 + 2.4, 0.6, 0.15 + k * 0.28), 0.42, 0.27, rubber, segs=16)
    return b.finish(col, loc=loc, rot=(0, 0, rot))


def water_tower(col, name, loc, seed=6):
    """Ahşap ayaklı su deposu: 4 eğik ayak + çapraz kuşaklar, platform, çemberli ahşap tank, konik sac kapak,
    aşağı inen boru ve merdiven."""
    r = random.Random(seed)
    leg = k_mat("tower_wood", "#5A4028", rough=0.9)
    stave = k_mat("tank_wood", "#7A5634", rough=0.9)
    hoop = k_mat("frame_dark", "#2E2622", rough=0.8, metal=0.5)
    tin = k_mat("roof_tin", "#6B6660", rough=0.6, metal=0.45)
    steel = kit_mats()["steel"]
    b = Builder(name, seed=seed)
    Hh = 5.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.tube([(sx * 1.35, sy * 1.35, 0.0), (sx * 0.95, sy * 0.95, Hh)], 0.11, leg, segs=6)
    for z in (1.6, 3.4):
        k = 1.35 - (1.35 - 0.95) * z / Hh
        for (a, c) in (((-k, -k), (k, -k)), ((k, -k), (k, k)), ((k, k), (-k, k)), ((-k, k), (-k, -k))):
            b.tube([(a[0], a[1], z), (c[0], c[1], z)], 0.06, leg, segs=4)
            b.tube([(a[0], a[1], z), (c[0], c[1], z + 1.6)], 0.045, leg, segs=4)
    b.box((0, 0, Hh + 0.08), (2.4, 2.4, 0.16), leg)
    b.cyl((0, 0, Hh + 1.1), 1.15, 1.9, stave, segs=18)
    for z in (Hh + 0.45, Hh + 1.1, Hh + 1.75):
        b.cyl((0, 0, z), 1.18, 0.07, hoop, segs=18)
    b.cyl((0, 0, Hh + 2.35), 1.3, 0.6, tin, segs=18, r2=0.15)
    b.tube([(0.9, -0.4, Hh), (0.9, -0.4, 0.3), (1.3, -0.4, 0.2)], 0.07, steel, segs=6)
    for k in range(9):   # merdiven
        z = 0.4 + k * 0.55
        b.box((-1.2 + 0.0, -1.55, z), (0.6, 0.05, 0.05), leg)
    for x in (-1.5, -0.9):
        b.box((x, -1.55, Hh / 2), (0.06, 0.06, Hh), leg)
    return b.finish(col, loc=loc)


# --- Karakterler: Hurdacı Necati, Çırak Cemo, bekçi köpeği -------------------------------------

def necati(col, name="Necati", loc=(0, 0, 0), rot=0.0):
    """Hurdacı Necati — OTURUR hâlde (kök = kalça, oturak yüzeyi). Ön yüz +X. Yaşlı, beyaz kalın bıyıklı,
    kasketli, ekose gömlek üstüne solgun mavi tulum, göbekli; sağ elinde ince belli çay bardağı + tabak."""
    overall = k_mat("overall_blue", "#3E5F8A", rough=0.85)
    shirt = k_mat("shirt_plaid", "#9C3B2E", rough=0.85)
    shirt2 = k_mat("shirt_plaid2", "#6E2A22", rough=0.85)
    skin = k_mat("skin", "#D9A47C", rough=0.7)
    hair = k_mat("hair_white", "#E4DED4", rough=0.8)
    cap = k_mat("cap_grey", "#55504A", rough=0.85)
    boot = k_mat("boot", "#2E241C", rough=0.8)
    tea = k_mat("tea_glass", "#9A3412", rough=0.15, metal=0.0)
    saucer = k_mat("saucer", "#E8E2D6", rough=0.4)
    b = Builder(name, seed=11)
    # Kalça + bacaklar (uyluk öne, baldır aşağı), postallar
    b.box((0.02, 0, 0.1), (0.36, 0.44, 0.22), overall)
    for y in (-0.12, 0.12):
        b.limb((0.0, y, 0.12), (0.46, y * 1.1, 0.14), 0.1, 0.085, overall)
        b.limb((0.46, y * 1.1, 0.14), (0.5, y * 1.15, -0.76), 0.08, 0.065, overall)
        b.box((0.56, y * 1.15, -0.82), (0.3, 0.15, 0.12), boot)
    # Gövde: gömlek, göbek (tulumun önlüğü), askılar
    b.box((-0.04, 0, 0.5), (0.3, 0.46, 0.62), shirt)
    for k in range(4):   # ekose çizgiler
        b.box((0.112, 0, 0.3 + k * 0.15), (0.01, 0.47, 0.025), shirt2)
    b.ball((0.07, 0, 0.36), 0.24, overall, scale=(1.0, 1.0, 0.95))
    b.box((0.12, 0, 0.58), (0.06, 0.3, 0.3), overall)
    for y in (-0.12, 0.12):
        b.box((0.0, y, 0.72), (0.32, 0.06, 0.03), overall, rot=(0, -10, 0))
    # Kollar: sol el dizinde, sağ el çay bardağıyla göğüs önünde
    b.limb((-0.02, -0.27, 0.74), (0.05, -0.33, 0.42), 0.075, 0.065, shirt)
    b.limb((0.05, -0.33, 0.42), (0.36, -0.16, 0.26), 0.065, 0.055, shirt)
    b.ball((0.4, -0.15, 0.26), 0.06, skin)
    b.limb((-0.02, 0.27, 0.74), (0.05, 0.33, 0.44), 0.075, 0.065, shirt)
    b.limb((0.05, 0.33, 0.44), (0.32, 0.12, 0.52), 0.065, 0.055, shirt)
    b.ball((0.36, 0.1, 0.53), 0.06, skin)
    b.cyl((0.4, 0.1, 0.6), 0.032, 0.1, tea, segs=10, r2=0.04)
    b.cyl((0.4, 0.1, 0.545), 0.07, 0.012, saucer, segs=12)
    # Boyun + baş: büyük burun, kalın beyaz bıyık, kaşlar, kulaklar, ense saçı, kasket
    b.cyl((-0.02, 0, 0.84), 0.07, 0.1, skin, segs=8)
    b.ball((0.0, 0, 1.0), 0.17, skin, scale=(1.0, 0.95, 1.08))
    b.ball((0.165, 0, 0.98), 0.05, skin, scale=(1.0, 0.9, 1.1))
    b.ball((0.15, 0.06, 0.92), 0.055, hair, scale=(0.6, 1.2, 0.55))
    b.ball((0.15, -0.06, 0.92), 0.055, hair, scale=(0.6, 1.2, 0.55))
    for y in (-0.065, 0.065):
        b.box((0.155, y, 1.065), (0.03, 0.07, 0.022), hair)
        b.box((0.16, y, 1.03), (0.01, 0.025, 0.02), boot)   # gözler
    for y in (-0.165, 0.165):
        b.ball((0.0, y, 0.99), 0.04, skin, scale=(0.6, 0.4, 1.0))
    b.ball((-0.08, 0, 0.98), 0.14, hair, scale=(0.7, 1.15, 0.6))
    b.cyl((-0.01, 0, 1.13), 0.18, 0.08, cap, segs=14, r2=0.17)
    b.box((0.15, 0, 1.105), (0.16, 0.3, 0.03), cap, rot=(0, -8, 0))
    return b.finish(col, loc=loc, rot=(0, 0, rot), ao=False)


def necati_standing(col, name="Necati", loc=(0, 0, 0), rot=0.0):
    """Hurdacı Necati — AYAKTA (verandada, kapının önünde). Ön yüz +X. Yaşlı, göbekli, beyaz kalın bıyıklı,
    kasketli, ekose gömlek + solgun mavi tulum; sağ elinde çay bardağı + tabak, sol eli belinde."""
    overall = k_mat("overall_blue", "#3E5F8A", rough=0.85)
    shirt = k_mat("shirt_plaid", "#9C3B2E", rough=0.85)
    shirt2 = k_mat("shirt_plaid2", "#6E2A22", rough=0.85)
    skin = k_mat("skin", "#D9A47C", rough=0.7)
    hair = k_mat("hair_white", "#E4DED4", rough=0.8)
    cap = k_mat("cap_grey", "#55504A", rough=0.85)
    boot = k_mat("boot", "#2E241C", rough=0.8)
    tea = k_mat("tea_glass", "#9A3412", rough=0.15, metal=0.0)
    saucer = k_mat("saucer", "#E8E2D6", rough=0.4)
    b = Builder(name, seed=11)
    for y in (-0.12, 0.12):
        b.limb((0.0, y, 0.9), (0.02, y * 1.05, 0.48), 0.1, 0.085, overall)
        b.limb((0.02, y * 1.05, 0.48), (0.0, y * 1.1, 0.1), 0.085, 0.07, overall)
        b.box((0.07, y * 1.1, 0.05), (0.3, 0.16, 0.1), boot)
    b.box((0.0, 0, 1.25), (0.3, 0.48, 0.62), shirt)
    for k in range(4):
        b.box((0.152, 0, 1.02 + k * 0.15), (0.01, 0.49, 0.025), shirt2)
    b.ball((0.07, 0, 1.06), 0.26, overall, scale=(1.0, 1.0, 0.95))          # göbek (tulum)
    b.box((0.13, 0, 1.3), (0.07, 0.32, 0.32), overall)
    for y in (-0.13, 0.13):
        b.box((0.04, y, 1.47), (0.32, 0.06, 0.03), overall, rot=(0, -10, 0))
    # Sağ kol: çay bardağı göğüs önünde; sol kol: el belde
    b.limb((0.0, -0.29, 1.5), (0.06, -0.36, 1.18), 0.08, 0.068, shirt)
    b.limb((0.06, -0.36, 1.18), (0.3, -0.2, 1.24), 0.068, 0.058, shirt)
    b.ball((0.34, -0.18, 1.25), 0.065, skin)
    b.cyl((0.36, -0.17, 1.33), 0.034, 0.1, tea, segs=10, r2=0.042)
    b.cyl((0.36, -0.17, 1.275), 0.075, 0.012, saucer, segs=12)
    b.limb((0.0, 0.29, 1.5), (-0.06, 0.4, 1.22), 0.08, 0.068, shirt)
    b.limb((-0.06, 0.4, 1.22), (0.06, 0.27, 1.02), 0.068, 0.058, shirt)
    b.ball((0.08, 0.25, 1.01), 0.06, skin)
    z0 = 1.76
    b.cyl((-0.01, 0, z0 - 0.16), 0.075, 0.1, skin, segs=8)
    b.ball((0.0, 0, z0), 0.18, skin, scale=(1.0, 0.95, 1.08))
    b.ball((0.175, 0, z0 - 0.02), 0.055, skin, scale=(1.0, 0.9, 1.1))
    b.ball((0.16, 0.065, z0 - 0.085), 0.06, hair, scale=(0.6, 1.25, 0.55))
    b.ball((0.16, -0.065, z0 - 0.085), 0.06, hair, scale=(0.6, 1.25, 0.55))
    for y in (-0.07, 0.07):
        b.box((0.165, y, z0 + 0.07), (0.03, 0.075, 0.024), hair)
        b.box((0.17, y, z0 + 0.035), (0.01, 0.026, 0.022), boot)
        b.ball((0.0, y * 2.5, z0 - 0.01), 0.042, skin, scale=(0.6, 0.4, 1.0))
    b.ball((-0.085, 0, z0 - 0.02), 0.15, hair, scale=(0.7, 1.15, 0.6))
    b.cyl((-0.01, 0, z0 + 0.14), 0.19, 0.08, cap, segs=14, r2=0.18)
    b.box((0.16, 0, z0 + 0.115), (0.17, 0.32, 0.03), cap, rot=(0, -8, 0))
    return b.finish(col, loc=loc, rot=(0, 0, rot), ao=False)


def preview_text(col, name, text, loc, rot, size, hexcol="#7A2A20"):
    """YALNIZ ÖNİZLEME: tabela yazısı (oyunda Label3D, dışa aktarımda atlanır — jy_preview_only)."""
    cu = bpy.data.curves.new(name, 'FONT')
    cu.body = text
    cu.size = size
    cu.align_x = 'CENTER'
    cu.align_y = 'CENTER'
    cu.extrude = 0.01
    o = bpy.data.objects.new(name, cu)
    col.objects.link(o)
    o.location = loc
    o.rotation_euler = tuple(math.radians(a) for a in rot)
    o.data.materials.append(k_mat("sign_text_%s" % hexcol.lstrip("#"), hexcol, rough=0.6))
    o["jy_preview_only"] = True
    return o


def cemo(col, name="Cemo", loc=(0, 0, 0), rot=0.0):
    """Çırak Cemo — AYAKTA. Ön yüz +X. Genç, ince; turuncu tulum, beyaz tişört, ters kırmızı kasket,
    sağ omzunda kocaman İngiliz anahtarı, sol el belde."""
    overall = k_mat("overall_orange", "#D07A2A", rough=0.85)
    tee = k_mat("tee_white", "#E6E1D6", rough=0.85)
    skin = k_mat("skin2", "#C99070", rough=0.7)
    hair = k_mat("hair_dark", "#2A1E18", rough=0.8)
    cap = k_mat("cap_red", "#B0372C", rough=0.8)
    boot = k_mat("boot", "#2E241C", rough=0.8)
    steel = kit_mats()["steel"]
    b = Builder(name, seed=12)
    for y in (-0.11, 0.11):
        b.limb((0.0, y, 0.92), (0.02, y * 1.1, 0.48), 0.09, 0.075, overall)
        b.limb((0.02, y * 1.1, 0.48), (0.0, y * 1.15, 0.1), 0.075, 0.065, overall)
        b.box((0.06, y * 1.15, 0.05), (0.28, 0.14, 0.1), boot)
    b.box((0, 0, 0.98), (0.26, 0.38, 0.2), overall)
    b.box((0, 0, 1.25), (0.24, 0.4, 0.42), tee)
    b.box((0.1, 0, 1.18), (0.05, 0.3, 0.28), overall)
    for y in (-0.11, 0.11):
        b.box((0.0, y, 1.38), (0.28, 0.05, 0.03), overall)
    # Sağ kol yukarı, omuzda anahtar; sol el belde
    b.limb((0.0, -0.24, 1.42), (0.12, -0.32, 1.2), 0.065, 0.055, tee)
    b.limb((0.12, -0.32, 1.2), (0.08, -0.22, 1.5), 0.055, 0.05, skin)
    b.ball((0.07, -0.2, 1.53), 0.055, skin)
    b.box((-0.05, -0.2, 1.62), (0.75, 0.06, 0.05), steel, rot=(0, -25, 0))
    b.cyl((0.27, -0.2, 1.72), 0.08, 0.05, steel, axis='Y', segs=10)
    b.cyl((-0.36, -0.2, 1.43), 0.07, 0.05, steel, axis='Y', segs=10)
    b.limb((0.0, 0.24, 1.42), (-0.04, 0.33, 1.18), 0.065, 0.055, tee)
    b.limb((-0.04, 0.33, 1.18), (0.06, 0.22, 1.0), 0.055, 0.05, skin)
    b.ball((0.08, 0.2, 0.99), 0.05, skin)
    b.cyl((0, 0, 1.52), 0.06, 0.1, skin, segs=8)
    b.ball((0.0, 0, 1.68), 0.15, skin, scale=(1.0, 0.92, 1.1))
    b.ball((0.145, 0, 1.66), 0.035, skin)
    for y in (-0.055, 0.055):
        b.box((0.14, y, 1.71), (0.01, 0.025, 0.022), hair)
    b.ball((-0.03, 0, 1.74), 0.15, hair, scale=(0.95, 1.0, 0.6))
    b.cyl((-0.01, 0, 1.79), 0.155, 0.08, cap, segs=14, r2=0.14)
    b.box((-0.16, 0, 1.77), (0.15, 0.24, 0.03), cap, rot=(0, 10, 0))   # ters siperlik (arkada)
    return b.finish(col, loc=loc, rot=(0, 0, rot), ao=False)


def guard_dog(col, name="Dog", loc=(0, 0, 0), rot=0.0):
    """Oturan bekçi köpeği (Karabaş havası): kahverengi gövde, açık göğüs, siyah maske, düşük kulaklar, kuyruk."""
    fur = k_mat("dog_fur", "#9A6A3A", rough=0.9)
    light = k_mat("dog_light", "#D9C3A0", rough=0.9)
    dark = k_mat("dog_dark", "#2A221C", rough=0.9)
    b = Builder(name, seed=13)
    b.ball((-0.12, 0, 0.3), 0.26, fur, scale=(1.1, 0.85, 1.0))                # kalça (oturuyor)
    b.ball((0.08, 0, 0.5), 0.22, fur, scale=(0.9, 0.8, 1.25))                 # göğüs / gövde dik
    b.ball((0.18, 0, 0.45), 0.13, light, scale=(0.6, 0.9, 1.3))
    for y in (-0.09, 0.09):
        b.limb((0.18, y, 0.42), (0.22, y, 0.04), 0.05, 0.045, fur)
        b.ball((0.25, y, 0.03), 0.05, light, scale=(1.4, 1.0, 0.6))
        b.ball((-0.08, y * 1.9, 0.12), 0.1, fur, scale=(1.4, 0.7, 0.8))
    b.ball((0.22, 0, 0.8), 0.13, fur, scale=(1.0, 0.9, 0.95))                 # baş
    b.ball((0.34, 0, 0.76), 0.07, dark, scale=(1.3, 0.85, 0.8))               # siyah ağız / burun
    for y in (-0.1, 0.1):
        b.ball((0.18, y, 0.84), 0.06, dark, scale=(0.6, 0.5, 1.4), rot=(y * 300, 0, 0))   # düşük kulak
        b.box((0.32, y * 0.5, 0.85), (0.01, 0.02, 0.02), dark)
    b.limb((-0.34, 0, 0.32), (-0.48, 0.05, 0.62), 0.04, 0.025, fur)          # kuyruk (Godot'ta sallanır)
    return b.finish(col, loc=loc, rot=(0, 0, rot), ao=False)


def kit_preview():
    """Kiti boş "JunkKit" sahnesinde dizer (yalnız görsel kontrol)."""
    scn = bpy.data.scenes.get("JunkKit") or bpy.data.scenes.new("JunkKit")
    bpy.context.window.scene = scn
    col = bpy.data.collections.get("JunkKitCol") or bpy.data.collections.new("JunkKitCol")
    if col.name not in scn.collection.children:
        scn.collection.children.link(col)
    for o in list(col.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    chassis(col, "Chassis_Rust", loc=(0, 0, 0), rust=1.0)
    chassis(col, "Chassis_Clean", loc=(0, 3.0, 0), rust=0.0)
    chassis(col, "Chassis_Wheels", loc=(0, 6.0, 0), rust=0.0, wheels=True)
    container(col, "Container_Test", "#3F6E52", loc=(10, 0, 0))
    scrap_bin(col, "Bin_Test", "#7B3328", loc=(10, 5, 0), seed=3)
    hubcap_wall(col, "HubWall_Test", loc=(10, 10, 0))
    street_lamp(col, "Lamp_Test", loc=(16, 10, 0))
    tire_stack(col, "Tires_Test", 6, loc=(18, 10, 0))
    shack(col, "Shack_Test", loc=(-10, 3, 0))
    magnet_crane(col, "Crane_Test", loc=(0, -14, 0))
    car_press(col, "Press_Test", loc=(14, -14, 0))
    fence_run(col, "Fence_Test", (-6, -22), (12, -22))
    sun = bpy.data.objects.get("Kit_Sun")
    if sun is None:
        sun = bpy.data.objects.new("Kit_Sun", bpy.data.lights.new("Kit_Sun", 'SUN'))
        col.objects.link(sun)
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(-30))
    if scn.world is None:
        scn.world = bpy.data.worlds.new("Kit_World")
