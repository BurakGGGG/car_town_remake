# TEKER EKSENİ ARAMASI (dönel öz-benzerlik) — optimize GLB'deki dört teker parçasını (tripo_part_3..6, Meshy hattı)
# aday eksen etrafında 40 / 90 / 135 / 180 / 225 / 270° döndürüp yan izdüşümde kendisiyle örtüşmesini (Chamfer: döndürülmüş
# her noktanın özgün noktalara en yakın uzaklığı) ölçer; en küçük maliyetli merkezi kaba → ince ızgarayla bulur.
#
# Neden (2026-11-02, onuncu parti): Meshy lastikleri hafif oval / tabanı ezik ve kimi tekerin tepesi kemere kaynaşık; dış
# zarf ya da yüzdelik uçlarla ölçülen merkez AE86'da dikeyde ~4 mm kaçıyordu (wheel_blur'da lastik kenarı çift). Dönen
# tekerde asıl görünen jant ve lastik halkasıdır; doğru eksende döndürülmüş parça kendi üstüne oturur.
#
#   blender -b --factory-startup --python tools/wheel_axis_search.py -- <optimize.glb> '<başlangıç wheel_axes JSON>'
# Başlangıç: CarPartMap wheel_axes ({"fl": [y, z, r], ...}, Godot uzayı; meshy_prep'in ÖZET satırı). Yarıçap değişmez.
# Çıktı: EKSEN satırları + CarPartMap'e yapıştırılacak "wheel_axes" satırı. Sonra wheel_blur ile gözle doğrula.
import bpy, sys, math, json
import numpy as np
from mathutils.kdtree import KDTree

argv = sys.argv[sys.argv.index("--") + 1:]
path, start = argv[0], json.loads(argv[1])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=path)
sc = bpy.context.scene
NAMES = {"fl": "tripo_part_3", "fr": "tripo_part_4", "rl": "tripo_part_5", "rr": "tripo_part_6"}
ANGLES = (40, 90, 135, 180, 225, 270)
out = {}
for k, nm in NAMES.items():
    o = sc.objects[nm]
    v = np.array([(o.matrix_world @ x.co)[:] for x in o.data.vertices])
    P = np.c_[-v[:, 1], v[:, 2]]          # Godot (z ileri, y yukarı); glTF içe aktarma: Blender y = -Godot z
    if len(P) > 4000:
        P = P[np.random.default_rng(1).choice(len(P), 4000, replace=False)]
    kd = KDTree(len(P))
    for i, p in enumerate(P):
        kd.insert((p[0], p[1], 0.0), i)
    kd.balance()

    def cost(cz, cy):
        tot = 0.0
        for a in ANGLES:
            t = math.radians(a)
            c, s = math.cos(t), math.sin(t)
            q = P - [cz, cy]
            rot = np.c_[q[:, 0] * c - q[:, 1] * s, q[:, 0] * s + q[:, 1] * c] + [cz, cy]
            tot += sum(kd.find((x, y, 0.0))[2] for x, y in rot[::4])
        return tot

    y0, z0, r0 = start[k]
    best = (cost(z0, y0), z0, y0)
    c0 = best[0]
    step = 0.002
    for _ in range(3):
        bz, by = best[1], best[2]
        for dz in np.arange(-3, 4) * step:
            for dy in np.arange(-3, 4) * step:
                c_ = cost(bz + dz, by + dy)
                if c_ < best[0]:
                    best = (c_, bz + dz, by + dy)
        step /= 3
    out[k] = [round(best[2], 4), round(best[1], 4), r0]
    print("EKSEN %s başlangıç y %.4f z %.4f maliyet %.4f → y %.4f z %.4f maliyet %.4f" % (k, y0, z0, c0, best[2], best[1], best[0]))
print('"wheel_axes": {' + ", ".join('"%s": [%.4f, %.4f, %.4f]' % (k, *out[k]) for k in ("fl", "fr", "rl", "rr")) + "},")
