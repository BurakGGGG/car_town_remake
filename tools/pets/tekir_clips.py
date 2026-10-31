"""TEKİR KLİPLERİ: anahtar duruşlar + aralarında yumuşak geçiş + üst üste binen sürekli katmanlar (nefes, kuyruk).
tekir_anim.py içe alır. Saf veri ve matematik: bpy yok.

KANALLAR (hepsi isteğe bağlı; olmayan kanal dinlenme değerindedir)
  "<kemik>":   (x, y, z) derece, kemiğin YEREL ekseninde. Yerel X = eğilme: omurga / boyun / baş / kuyruk / kulakta
               + uç yukarı (kulakta + uç ileri); aşağı bakan bacak kemiğinde + uç İLERİ; pençe/parmakta + uç yukarı.
               Omurga / boyun / başta yerel Z + = kedinin SOLUNA dönüş; kuyrukta yerel Z + = SAĞA.
  "hips_loc":  (dx, dy, dz) metre, dünya ekseninde kalça kayması (dy + = GERİ; kedi −Y'ye bakar).
  "root_loc":  (dx, dy, dz) bütün kedi (ayak kontrolleri dahil).
  "root_rot":  (x, y, z) derece: X öne eğilme, Y + = SOLA dönüş (dikey eksen), Z + = SAĞ yanına yatış.
  "paw_XX":    (dy, dz, rx, dx, ry): pençe kontrolü (FL/FR/RL/RR). dy + geri, dz yukarı, rx + = bilek/topuk kalkar
               (pençe ucu eksen), dx yanal, ry dikey eksende dönüş.
  "ik_XX":     0..1 bacağın IK ağırlığı (1 = pençe kontrolü sürer, 0 = bacak kemiklerinin kendi dönüşü).
"""
import math

FPS = 30
LEGS = ("FL", "FR", "RL", "RR")
LEG_FK = {"FL": ("upperarm_L", "forearm_L", "hand_L"), "FR": ("upperarm_R", "forearm_R", "hand_R"),
          "RL": ("thigh_L", "shin_L", "foot_L", "toe_L"), "RR": ("thigh_R", "shin_R", "foot_R", "toe_R")}
TAIL = ["tail%d" % i for i in range(1, 7)]


def default(ch: str):
    if ch.startswith("ik_"):
        return 1.0
    if ch.startswith("paw_"):
        return (0.0, 0.0, 0.0, 0.0, 0.0)
    return (0.0, 0.0, 0.0)


def lerp(a, b, u: float):
    if isinstance(a, (int, float)):
        return a + (b - a) * u
    return tuple(x + (y - x) * u for x, y in zip(a, b))


def ease(u: float, kind: str = "io") -> float:
    u = min(max(u, 0.0), 1.0)
    if kind == "lin":
        return u
    if kind == "in":
        return u * u
    if kind == "out":
        return 1 - (1 - u) * (1 - u)
    if kind == "hold":
        return 0.0
    return u * u * (3 - 2 * u)


def merge(*poses) -> dict:
    out = {}
    for p in poses:
        out.update(p)
    return out


def add(p: dict, q: dict) -> dict:
    for c, v in q.items():
        base = p.get(c, default(c))
        p[c] = base + v if isinstance(v, (int, float)) else tuple(x + y for x, y in zip(base, v))
    return p


# --- Dönüş karışımı: kemik Euler'leri dörtlü (quaternion) üzerinden en kısa yoldan karışır ---------------------
# (Blender 'XYZ' sırası: R = Rz · Ry · Rx.) Doğrusal Euler karışımı büyük açılarda kemiği kendi etrafında döndürüyordu.
# root_rot hariç: dönme numarası 0 → 180 → 360 bilerek tam tur atar.

def _q_mul(a, b):
    aw, ax, ay, az = a
    bw, bx, by, bz = b
    return (aw * bw - ax * bx - ay * by - az * bz, aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx, aw * bz + ax * by - ay * bx + az * bw)


def _euler_to_q(e):
    x, y, z = (math.radians(v) / 2 for v in e)
    qx = (math.cos(x), math.sin(x), 0.0, 0.0)
    qy = (math.cos(y), 0.0, math.sin(y), 0.0)
    qz = (math.cos(z), 0.0, 0.0, math.sin(z))
    return _q_mul(qz, _q_mul(qy, qx))


def _q_to_euler(q):
    w, x, y, z = q
    r00 = 1 - 2 * (y * y + z * z)
    r10 = 2 * (x * y + w * z)
    r20 = 2 * (x * z - w * y)
    r21 = 2 * (y * z + w * x)
    r22 = 1 - 2 * (x * x + y * y)
    ey = math.asin(max(-1.0, min(1.0, -r20)))
    ex = math.atan2(r21, r22)
    ez = math.atan2(r10, r00)
    return (math.degrees(ex), math.degrees(ey), math.degrees(ez))


def _slerp_euler(a, b, u: float):
    qa, qb = _euler_to_q(a), _euler_to_q(b)
    d = sum(i * j for i, j in zip(qa, qb))
    if d < 0:
        qb, d = tuple(-v for v in qb), -d
    if d > 0.9995:
        q = tuple(i + (j - i) * u for i, j in zip(qa, qb))
    else:
        th = math.acos(d)
        sa, sb = math.sin((1 - u) * th) / math.sin(th), math.sin(u * th) / math.sin(th)
        q = tuple(sa * i + sb * j for i, j in zip(qa, qb))
    n = math.sqrt(sum(v * v for v in q))
    return _q_to_euler(tuple(v / n for v in q))


def _is_rot(ch: str) -> bool:
    return not (ch.startswith(("ik_", "paw_")) or ch.endswith(("_loc", "@loc")) or ch == "root_rot")


def pose_at(keys: list, f: float) -> dict:
    """keys: [(kare, duruş, geçiş)] artan sırada; geçiş o anahtardan SONRAKİ aralığın yumuşatması."""
    if f <= keys[0][0]:
        return dict(keys[0][1])
    for i in range(len(keys) - 1):
        f0, a, kind = keys[i]
        f1, b, _ = keys[i + 1]
        if f <= f1:
            u = ease((f - f0) / max(f1 - f0, 1e-6), kind)
            chans = set(a) | set(b)
            return {c: (_slerp_euler if _is_rot(c) else lerp)(a.get(c, default(c)), b.get(c, default(c)), u) for c in chans}
    return dict(keys[-1][1])


def tail_shape(lifts, yaws=None) -> dict:
    yaws = yaws or [0] * 6
    return {TAIL[i]: (lifts[i], 0.0, yaws[i]) for i in range(6)}


# --- Temel duruşlar --------------------------------------------------------------------------

# Ayakta (referans: PACK Idle stand / Tail wag stand, FreePreviewPack Idle-Stand): kuyruk DİK, ucu öne kıvrık (soru işareti)
STAND = merge({"neck": (-3, 0, 0), "head": (3, 0, 0)}, tail_shape([58, 14, 10, 10, 14, 20]))

SIT = merge({
    "hips_loc": (0.0, 0.035, -0.112), "hips": (24, 0, 0), "spine1": (4, 0, 0), "spine2": (0, 0, 0), "chest": (-2, 0, 0),
    "neck": (12, 0, 0), "head": (-36, 0, 0),
    "paw_FL": (0.068, 0, 0, 0.004, 0), "paw_FR": (0.068, 0, 0, -0.004, 0),
    "paw_RL": (0.0, 0, -45, 0.008, 0), "paw_RR": (0.0, 0, -45, -0.008, 0),
}, tail_shape([-36, 6, 8, 8, 8, 8], [0, 22, 22, 20, 18, 14]))

CROUCH = merge({
    "hips_loc": (0.0, 0.01, -0.07), "hips": (-5, 0, 0), "spine1": (2, 0, 0), "spine2": (2, 0, 0), "chest": (-3, 0, 0),
    "neck": (-15, 0, 0), "head": (18, 0, 0),
    "paw_FL": (-0.03, 0, 0, 0, 0), "paw_FR": (-0.03, 0, 0, 0, 0),
    "paw_RL": (0.0, 0, -20, 0, 0), "paw_RR": (0.0, 0, -20, 0, 0),
}, tail_shape([-12, 0, 0, 0, 2, 4]))

# Karnının üstünde yatış (somun): gövde yere iner, patiler yerinde kalıp katlanır
LIE = merge({
    "hips_loc": (0.0, 0.0, -0.118), "hips": (0, 0, 0), "chest": (-2, 0, 0),
    "neck": (-6, 0, 0), "head": (6, 0, 0),
    "paw_FL": (0.03, 0, -10, 0.006, 0), "paw_FR": (0.03, 0, -10, -0.006, 0),
    "paw_RL": (0.0, 0, -44, 0.014, 0), "paw_RR": (0.0, 0, -44, -0.014, 0),
}, tail_shape([-30, -5, 0, 0, 0, 0], [0, -10, -10, -10, -10, -10]))

def curl(kappa: float, roll: float, extra_pitch: float = 0.0, twist: float = 0.0, tail: bool = False) -> tuple:
    """Yere paralel kıvrılma: gövde parçası `roll` derece SAĞ yanına yatıkken, yatay düzlemde SOLA (karnına doğru)
    `kappa` derece bükülme = yanal (Z) + karın yönü (−X) bileşenlerine bölünür. Kuyrukta yanal eksen ters."""
    r = math.radians(roll)
    pitch = -kappa * math.sin(r) + extra_pitch
    yaw = kappa * math.cos(r) * (-1 if tail else 1)
    return (pitch, twist, yaw)


FK_ALL = {"ik_FL": 0.0, "ik_FR": 0.0, "ik_RL": 0.0, "ik_RR": 0.0}
FK_FRONT = {"ik_FL": 0.0, "ik_FR": 0.0}
FK_REAR = {"ik_RL": 0.0, "ik_RR": 0.0}


def front_fk(l=(0, 0, 0), l2=(0, 0, 0), l3=(0, 0, 0), r=None, r2=None, r3=None) -> dict:
    """Ön bacaklar kendi dönüşüyle: (kol, ön kol, pençe). Sağ verilmezse sol aynası (yanal eksen ters)."""
    r = r if r is not None else (l[0], -l[1], -l[2])
    r2 = r2 if r2 is not None else (l2[0], -l2[1], -l2[2])
    r3 = r3 if r3 is not None else (l3[0], -l3[1], -l3[2])
    return {"upperarm_L": l, "forearm_L": l2, "hand_L": l3, "upperarm_R": r, "forearm_R": r2, "hand_R": r3}


def rear_fk(t=(0, 0, 0), s=(0, 0, 0), f=(0, 0, 0)) -> dict:
    m = lambda v: (v[0], -v[1], -v[2])
    return {"thigh_L": t, "shin_L": s, "foot_L": f, "thigh_R": m(t), "shin_R": m(s), "foot_R": m(f)}


# --- UYKU (2026-10-31 yeniden: gerçek fotoğraflardan) -----------------------------------------------
# Simit: sırt dış yay, karın içte; dört bacak gövdenin altına/içine katlı (görünmez); baş aşağı ve geri dönüp
# halkanın içine gömülür (üstten kafa tepesi + kulaklar); kuyruk dıştan öne dolanır, ucu burnun yanında.
# Kalça yan yatık (~55°), göğüs daha dik (burulma), baş kulaklar yukarı olacak şekilde geri döner.
# Simit GEOMETRİYLE kurulur (tekir_anim.solve_curl): omurga yerdeki çember yayında, kuyruk dıştan dolanır.
# Yay kalçanın DİNLENME yerinden (0, 0,077) ve yönünden (−Y) başlar: merkez = (R, 0,077), theta0 = 180° — yoksa kalça
# ters döner (−174°) ve yatıştan geçişte yerinde fırıldanır.
# Burada yalnız yer tutucu sözlük; çözülen kanallar açılışta içine yazılır (klip anahtarları aynı nesneyi tutar).
SLEEP_CURL = {}
# IK bacaklı yatışın FK ikizi (açılışta çözülür): yatış ↔ uyku geçişi IK/FK karışımı yapmasın
LIE_FK = {}
FK_TWINS = {"LIE_FK": LIE}
# Uyku duruşlarında yüzün göründüğü bakış yönü (kedinin yerel XY'sinde, Blender ekseni: +X sol, −Y ileri).
# Oyun kediyi bu yön kameraya bakacak şekilde döndürür. glTF/Godot'ta (x, y) → (x, −z).
SLEEP_FACE_DIR = (-0.707, 0.707)
SOLVED = {
    "SLEEP_CURL": {
        "center": (0.086, 0.077), "radius": 0.086, "theta0": 180.0,
        # eklem yükseklikleri: kalça, bel, sırt, göğüs, boyun kökü, ense, burun (burun halkaya gömülü)
        "heights": [0.068, 0.074, 0.077, 0.078, 0.075, 0.07, 0.035],
        # SOL yanına yatış (karın içe): kalça çok, göğüs az, baş neredeyse dik (kulaklar yukarı)
        "rolls": [55, 48, 38, 26, 14, 4],
        "tail_radius": (0.092, 0.118), "tail_heights": [0.062, 0.05, 0.036, 0.026, 0.02, 0.018, 0.017],
        "extra": {"ear_L": (-8, 0, 0), "ear_R": (-8, 0, 0)},
        # Bacaklar halkanın içinde yerde (eklem hedefleri: açı°, yarıçap, yükseklik). Sol yan alttan/içten, sağ üstten.
        "legs": {
            "FL": [(330, 0.06, 0.025), (355, 0.035, 0.015), (10, 0.03, 0.012)],
            "FR": [(325, 0.085, 0.04), (352, 0.06, 0.025), (8, 0.05, 0.02)],
            "RL": [(220, 0.05, 0.03), (195, 0.035, 0.015), (225, 0.025, 0.012), (235, 0.025, 0.01)],
            "RR": [(225, 0.07, 0.05), (198, 0.06, 0.03), (228, 0.05, 0.02), (238, 0.05, 0.018)],
        },
    },
}

# Somun uykusu (referans: PACK Sleep 1 + white-kitten): somun yatışında baş öne düşer, çene patilere / yere iner,
# gözler kapalı (oyun dokuyu değiştirir), kulaklar gevşek. Hilal (SLEEP_DOZE) kedi gibi durmadığı için kaldırıldı.
LOAF_DOZE = merge(LIE, {"chest": (-4, 0, 0), "neck": (-30, 0, 0), "head": (-6, 0, 4), "ear_L": (-10, 0, 4),
                        "ear_R": (-10, 0, -4)})

# Kulak kaşıma (referans: PACK Scratch sit): oturur, SOL arka bacak öne-yukarı kalkıp sol kulağın arkasını hızla kaşır;
# baş sola ve aşağı eğik, ağırlık sağ kalçaya kayar.
SCRATCH = merge(SIT, {"ik_RL": 0.0, "hips_loc": (0.0, 0.045, -0.105), "hips": (40, -12, 2), "spine1": (-4, -4, 4),
                      "chest": (-18, 6, 4), "neck": (-48, 0, 10), "head": (-10, -35, 18), "ear_L": (-14, 0, 0),
                      "paw_FL": (0.1, 0, 0, 0.006, 0), "paw_FR": (0.1, 0, 0, -0.004, 0)})
# Kaşıyan arka ayak: parmak ucu SOL kulağın kökünün arkasına (FABRIK, tekir_anim.solve_leg_targets); ilk tahmin büküm
# yönünü verir: diz öne-yukarı, topuk geri-yukarı, tarak öne (kediler kulağı böyle kaşır).
LEG_SOLVED = {
    # Model arka bacağı kulağa yetişmiyor (gerçek kediden kısa): boynun yanı, kulağın altı kaşınır (kediler bunu da yapar)
    "SCRATCH": {"RL": {"to": "head", "offset": (0.03, 0.018, -0.04),
                       "guess": [(0.03, -0.07, 0.03), (0.0, 0.04, 0.065), (-0.005, -0.05, 0.02), (0.0, -0.025, 0.0)]}},
}


# Ön gerinme: patiler ileri uzar, göğüs yere, kalça havada, baş kalkık
STRETCH = merge(STAND, {
    "hips_loc": (0.0, 0.0, 0.0), "hips": (-6, 0, 0), "spine1": (-6, 0, 0), "spine2": (-8, 0, 0), "chest": (-6, 0, 0),
    "neck": (8, 0, 0), "head": (16, 0, 0),
    "paw_FL": (-0.09, 0, -8, 0, 0), "paw_FR": (-0.085, 0, -8, 0, 0),
    "paw_RL": (0.01, 0, 6, 0, 0), "paw_RR": (0.01, 0, 6, 0, 0),
}, tail_shape([25, 10, 6, 4, 2, 0]))

# Zıplama: hazırlık (çömel, hedefe bak) → itiş (arka bacaklar açılır, ön bacaklar uzanır) → havada → iniş
J_CROUCH = merge(STAND, {
    "hips_loc": (0.0, 0.01, -0.05), "chest": (-4, 0, 0), "neck": (12, 0, 0), "head": (-8, 0, 0),
    "paw_RL": (0.0, 0, -25, 0, 0), "paw_RR": (0.0, 0, -25, 0, 0), "paw_FL": (-0.01, 0, 0, 0, 0), "paw_FR": (-0.01, 0, 0, 0, 0),
}, tail_shape([-20, 0, 0, 0, 0, 0]))
J_LAUNCH = merge(STAND, FK_FRONT, {
    "hips_loc": (0.0, 0.0, 0.035), "hips": (32, 0, 0), "chest": (-6, 0, 0), "neck": (0, 0, 0), "head": (-22, 0, 0),
    "paw_RL": (0.0, 0, 50, 0, 0), "paw_RR": (0.0, 0, 50, 0, 0),
}, front_fk((75, 0, 0), (-10, 0, 0), (10, 0, 0)), tail_shape([-10, 0, 0, 0, 0, 0]))
J_AIR = merge(STAND, FK_ALL, {
    "hips": (2, 0, 0), "spine1": (2, 0, 0), "neck": (-6, 0, 0), "head": (4, 0, 0),
}, front_fk((78, 0, 0), (-6, 0, 0), (14, 0, 0)), rear_fk((-58, 0, 0), (28, 0, 0), (45, 0, 0)), tail_shape([-2, 2, 2, 2, 2, 2]))
J_LAND = merge(STAND, FK_REAR, {
    "hips": (-12, 0, 0), "chest": (-4, 0, 0), "neck": (6, 0, 0), "head": (8, 0, 0),
    "paw_FL": (-0.03, 0, 0, 0, 0), "paw_FR": (-0.03, 0, 0, 0, 0),
}, rear_fk((10, 0, 0), (-25, 0, 0), (20, 0, 0)), tail_shape([5, 0, 0, 0, 0, 0]))
J_LANDLOW = merge(STAND, {
    "hips_loc": (0.0, 0.0, -0.035), "chest": (-8, 0, 0), "neck": (4, 0, 0), "head": (6, 0, 0),
    "paw_FL": (-0.02, 0, 0, 0, 0), "paw_FR": (-0.02, 0, 0, 0, 0), "paw_RL": (0.0, 0, -15, 0, 0), "paw_RR": (0.0, 0, -15, 0, 0),
}, tail_shape([-15, 5, 5, 5, 5, 5]))

SNIFF = merge(STAND, {"chest": (-4, 0, 0), "neck": (-38, 0, 0), "head": (-18, 0, 0)}, tail_shape([-10, 6, 8, 8, 8, 10]))
EAT = merge(STAND, {"hips_loc": (0.0, 0.0, -0.01), "chest": (-8, 0, 0), "neck": (-48, 0, 0), "head": (-28, 0, 0),
                    "paw_FL": (0.012, 0, 0, 0, 0), "paw_FR": (0.012, 0, 0, 0, 0)}, tail_shape([-40, 8, 10, 10, 10, 12]))

# Oturarak yalanma: sol ön pati ağza, sonra pati başın üstünden yüzü siler
GROOM_LICK = merge(SIT, {"ik_FL": 0.0, "neck": (2, 0, 6), "head": (-48, 0, 16)},
                   {"upperarm_L": (80, 0, -6), "forearm_L": (55, 0, 0), "hand_L": (-35, 0, 0)})
GROOM_WIPE = merge(SIT, {"ik_FL": 0.0, "neck": (0, 0, 10), "head": (-55, -20, 22)},
                   {"upperarm_L": (105, 0, -12), "forearm_L": (75, 0, 0), "hand_L": (-40, 0, 0)})

# Sevilme: baş kalkar ve yana yatar (ele sürtünür), gözler kapanır (doku), kuyruk dik
PET_UP = merge(SIT, {"neck": (16, 0, 0), "head": (-26, 14, 0), "ear_L": (-10, 0, 0), "ear_R": (-10, 0, 0)})
PET_L = merge(PET_UP, {"neck": (16, 0, 6), "head": (-22, 20, 12), "chest": (-2, 4, 0)})
PET_R = merge(PET_UP, {"neck": (16, 0, -6), "head": (-22, 6, -12), "chest": (-2, -4, 0)})

# Pati verme: oturur, sağ ön patisini ileri uzatır
PAW = merge(SIT, {"ik_FR": 0.0, "hips": (22, 0, 0), "neck": (14, 0, 0), "head": (-36, -8, 0)},
            {"upperarm_R": (62, 0, 0), "forearm_R": (8, 0, 0), "hand_R": (18, 0, 0)})

# Olta: oturup sol patiyle havaya vurma (iki uç)
SWAT_UP = merge(SIT, {"ik_FL": 0.0, "hips": (25, 0, 0), "neck": (14, 0, 0), "head": (-34, 0, 0)},
                {"upperarm_L": (82, 0, 0), "forearm_L": (10, 0, 0), "hand_L": (-35, 0, 0)})
SWAT_A = merge(SWAT_UP, {"upperarm_L": (90, 0, -20), "forearm_L": (0, 0, 0), "hand_L": (-50, 0, 0), "head": (-32, 0, -8)})
SWAT_B = merge(SWAT_UP, {"upperarm_L": (70, 0, 16), "forearm_L": (25, 0, 0), "hand_L": (-20, 0, 0), "head": (-36, 0, 6)})

# Olta: zıplayıp iki patiyle yere bastırma (yerinde)
P_UP = merge(CROUCH, FK_FRONT, {"hips_loc": (0.0, 0.01, -0.02), "hips": (28, 0, 0), "neck": (4, 0, 0), "head": (-20, 0, 0)},
             front_fk((95, 0, 0), (20, 0, 0), (-30, 0, 0)), tail_shape([5, 4, 4, 4, 4, 4]))
P_DOWN = merge(CROUCH, {"hips_loc": (0.0, 0.0, -0.08), "chest": (-10, 0, 0), "neck": (-10, 0, 0), "head": (10, 0, 0),
                        "paw_FL": (-0.06, 0, 0, 0.005, 0), "paw_FR": (-0.06, 0, 0, -0.005, 0)})

# Arka ayaklar üstünde (referans PACK "On hind legs"): oturuştan kısa kalkış, gövde dik, ön patiler göğsün önünde
# gevşekçe SARKAR (dirsek hafif bükük), baş biraz yukarı bakar; kısa durur ve oturuşa döner.
BEG = merge(SIT, FK_FRONT, {"hips_loc": (0.0, 0.03, -0.085), "hips": (70, 0, 0), "spine1": (4, 0, 0), "chest": (-4, 0, 0),
                            "neck": (-22, 0, 0), "head": (-26, 0, 0)},
            front_fk((-8, 0, 0), (38, 0, 0), (-30, 0, 0)), tail_shape([-62, 0, 5, 5, 5, 5], [0, 20, 20, 18, 16, 14]))

# Yuvarlanma: yan → sırtüstü (patiler havada)
SIDE = merge(FK_ALL, {"root_rot": (0, 0, 82), "root_loc": (0.11, 0.0, 0.025), "neck": (-6, 0, 0), "head": (4, 0, 0)},
             front_fk((22, 0, 0), (25, 0, 0), (-10, 0, 0)), rear_fk((18, 0, 0), (-22, 0, 0), (10, 0, 0)),
             tail_shape([-10, -5, -5, -5, -5, -5]))
BACK = merge(FK_ALL, {"root_rot": (0, 0, 168), "root_loc": (0.03, 0.0, 0.245), "spine1": (-6, 0, 0), "spine2": (-6, 0, 0),
                      "neck": (-14, 0, 0), "head": (-10, 0, 0)},
             front_fk((25, 0, 0), (100, 0, 0), (-70, 0, 0)), rear_fk((35, 0, 16), (-55, 0, 0), (30, 0, 0)),
             tail_shape([-15, -5, -5, -5, -5, -5]))

# Kuyruk YERE değip gövdenin SAĞINDAN öne sarılır (referans: PACK oturuş / somun, Tail wag sit / lie). Açılışta
# tekir_anim.solve_tails çözer; bu duruşla AYNI kuyruğu taşıyan türevlerin (yalanma, sevilme, pati...) kuyruğu da güncellenir.
# Yay: merkez (x, y), yarıçap (baş, son), ilk eklem açısı°, yön (+1 saat tersi: arkadan SAĞ yana → öne), eklem yükseklikleri.
TAIL_SOLVED = {
    "SIT": {"center": (0.0, 0.0), "radius": (0.115, 0.095), "theta0": 92.0, "sign": 1.0,
            "heights": [0.035, 0.016, 0.014, 0.014, 0.014, 0.016]},
    "LIE": {"center": (0.0, 0.0), "radius": (0.10, 0.085), "theta0": 95.0, "sign": 1.0,
            "heights": [0.038, 0.02, 0.015, 0.015, 0.015, 0.016]},
}

POSES = {k: v for k, v in dict(globals()).items()
         if k.isupper() and isinstance(v, dict) and k not in ("LEG_FK", "FK_ALL", "FK_FRONT", "FK_REAR", "POSES", "CLIPS",
                                                               "SOLVED", "FK_TWINS", "TAIL_SOLVED", "LEG_SOLVED")}


# --- Sürekli katmanlar ---------------------------------------------------------------------------

def breathe(f: float, n: int, cycles: int = 1, amp: float = 0.8) -> dict:
    s = math.sin(2 * math.pi * cycles * f / n)
    return {"spine2": (amp * s, 0, 0), "chest": (amp * 0.6 * s, 0, 0), "neck": (-amp * 0.5 * s, 0, 0)}


def tail_sway(f: float, n: int, cycles: int = 1, amp: float = 6.0, lag: float = 0.55) -> dict:
    return {TAIL[i]: (0, 0, amp * (0.4 + 0.12 * i) * math.sin(2 * math.pi * cycles * f / n - i * lag)) for i in range(6)}


# --- Klipler -----------------------------------------------------------------------------------
# {"frames": n, "keys": [(kare, duruş, geçiş)], "overlay": fn(f, n) → ek kanallar, "loop": bool}

def tail_flick(f, windows, amp=14.0, period=8.0) -> dict:
    """Kuyruk UCU seğirmesi (referans Tail wag): yalnız verilen kare aralıklarında, son iki halka yana."""
    w = max((_window(f, a, b) for a, b in windows), default=0.0)
    if w <= 0.0:
        return {}
    return {TAIL[5]: (0, 0, w * amp * math.sin(2 * math.pi * f / period)),
            TAIL[4]: (0, 0, w * amp * 0.5 * math.sin(2 * math.pi * f / period - 0.7)),
            TAIL[3]: (0, 0, w * amp * 0.2 * math.sin(2 * math.pi * f / period - 1.4))}


def _idle_overlay(f, n):
    o = add(breathe(f, n, 2), tail_sway(f, n, 1, 3))
    o = add(o, tail_flick(f, [(14, 34), (84, 100)]))
    # Kulak seğirmesi (bir kez) ve sağa-sola bakış
    if 40 <= f <= 48:
        o = add(o, {"ear_L": (-12 * math.sin(math.pi * (f - 40) / 8), 0, 0)})
    look = 14 * math.sin(math.pi * min(max((f - 60) / 50, 0), 1)) ** 2
    return add(o, {"head": (0, 0, look), "neck": (0, 0, look * 0.4)})


def _osc(f, period, amp, phase=0.0):
    return amp * math.sin(2 * math.pi * f / period + phase)


def _window(f, a, b):
    """a..b arasında 0→1→0 yumuşak pencere (bir kerelik seğirme / bakış)."""
    if f <= a or f >= b:
        return 0.0
    return math.sin(math.pi * (f - a) / (b - a)) ** 2


def _sit_overlay(f, n):
    o = add(breathe(f, n, 2), tail_flick(f, [(6, 26), (90, 112)], 18.0, 10.0))
    o = add(o, {"ear_R": (-14 * _window(f, 70, 78), 0, 0)})
    look = 12 * _window(f, 20, 60) - 10 * _window(f, 75, 110)
    return add(o, {"head": (0, 0, look), "neck": (0, 0, look * 0.3)})


def _loaf_overlay(f, n):
    o = add(breathe(f, n, 2), tail_flick(f, [(30, 52)], 16.0, 10.0))
    o = add(o, {"ear_L": (-12 * _window(f, 70, 77), 0, 0)})
    look = 10 * _window(f, 80, 115)
    return add(o, {"head": (0, 0, look), "neck": (0, 0, look * 0.3)})


def _scratch_overlay(f, n):
    w = 1.0 if 10 <= f <= 52 else 0.0
    k = _osc(f, 5, 14) * w   # hızlı kaşıma (~6 Hz)
    return {"shin_L": (k, 0, 0), "foot_L": (-k * 0.6, 0, 0), "head": (0, w * _osc(f, 10, 3), 0)}


def _sleep_overlay(f, n):
    o = breathe(f, n, 2, 1.6)
    o = add(o, {TAIL[5]: (0, 0, 14 * _window(f, 90, 104)), TAIL[4]: (0, 0, 6 * _window(f, 92, 106))})
    return add(o, {"ear_L": (-16 * _window(f, 40, 46), 0, 0)})


def _tail_quiver(f, amp=3.0):
    return {TAIL[4]: (_osc(f, 4, amp), 0, 0), TAIL[5]: (_osc(f, 4, amp * 1.4, 1.0), 0, 0)}


def _sniff_overlay(f, n):
    w = 1.0 if 12 <= f <= 60 else 0.0
    return add({"head": (w * _osc(f, 6, 2.5), 0, w * 6 * math.sin(2 * math.pi * f / 48))}, tail_sway(f, n, 1, 5))


def _eat_overlay(f, n):
    return add({"head": (_osc(f, 12, 3.0), 0, 0), "neck": (_osc(f, 12, 1.2, 0.5), 0, 0)}, tail_sway(f, n, 1, 6))


def _groom_overlay(f, n):
    lick = _osc(f, 8, 5.0) if 14 <= f <= 60 else 0.0
    wipe = _osc(f, 14, 8.0) if 72 <= f <= 100 else 0.0
    return {"head": (lick + wipe * 0.4, 0, 0), "upperarm_L": (wipe, 0, 0), "forearm_L": (-wipe * 0.5, 0, 0)}


def _crouch_overlay(f, n):
    # Popo kıpırdatma: kalça yalpası + arka patiler sırayla hafif kalkar, kuyruk ucu seğirir
    o = {"hips": (0, _osc(f, 20, 3.0), _osc(f, 20, 4.0)),
         "paw_RL": (0, max(0.0, _osc(f, 20, 0.006)), 0, 0, 0), "paw_RR": (0, max(0.0, -_osc(f, 20, 0.006)), 0, 0, 0)}
    return add(o, {TAIL[5]: (0, 0, _osc(f, 10, 12)), TAIL[4]: (0, 0, _osc(f, 10, 6, -0.6))})


def _beg_overlay(f, n):
    w = 1.0 if 10 <= f <= 30 else 0.0
    return {"head": (w * _osc(f, 10, 3), 0, w * _osc(f, 20, 6)), "forearm_L": (w * _osc(f, 12, 4), 0, 0),
            "forearm_R": (w * _osc(f, 12, 4, 1.2), 0, 0)}


def _roll_overlay(f, n):
    w = 1.0 if 44 <= f <= 66 else 0.0
    o = {"spine1": (0, 0, w * _osc(f - 44, 11, 6)), "chest": (0, 0, -w * _osc(f - 44, 11, 5)),
         "forearm_L": (w * _osc(f, 7, 15), 0, 0), "forearm_R": (-w * _osc(f, 7, 15), 0, 0),
         "shin_L": (w * _osc(f, 9, 12), 0, 0), "shin_R": (-w * _osc(f, 9, 12), 0, 0)}
    return o


def _clip(frames, keys, overlay=None, loop=False):
    return {"frames": frames, "keys": keys, "overlay": overlay, "loop": loop}


CLIPS = {
    # --- Garaj ---
    "idle": _clip(120, [(0, STAND, "io"), (120, STAND, "io")], _idle_overlay, True),
    "sit_down": _clip(24, [(0, STAND, "io"), (24, SIT, "io")]),
    "sit_idle": _clip(120, [(0, SIT, "io"), (120, SIT, "io")], _sit_overlay, True),
    "stand_up": _clip(20, [(0, SIT, "io"), (20, STAND, "io")]),
    # Derin uyku = simit (SLEEP_CURL, geometriyle çözülür), şekerleme = gözü kapalı somun (LOAF_DOZE).
    # Oyunda uyurken yüz kameraya dönük olsun: SLEEP_FACE_DIR yönünden bakınca yüz görünür.
    "sleep_down": _clip(60, [(0, STAND, "io"), (26, LIE, "lin"), (27, LIE_FK, "io"), (60, SLEEP_CURL, "io")]),
    "sleep": _clip(150, [(0, SLEEP_CURL, "io"), (150, SLEEP_CURL, "io")], _sleep_overlay, True),
    "wake": _clip(116, [(0, SLEEP_CURL, "io"), (28, LIE_FK, "lin"), (29, LIE, "io"), (36, LIE, "io"), (58, STAND, "io"), (78, STRETCH, "io"),
                        (94, STRETCH, "io"), (116, STAND, "io")]),
    # Somun (referans: PACK oturuş→somun, Sleep 1, white-kitten): uyanık somun, gözü kapalı somun uykusu
    "loaf_down": _clip(30, [(0, STAND, "io"), (30, LIE, "io")]),
    "loaf": _clip(120, [(0, LIE, "io"), (120, LIE, "io")], _loaf_overlay, True),
    "loaf_up": _clip(24, [(0, LIE, "io"), (24, STAND, "io")]),
    "doze_down": _clip(24, [(0, LIE, "io"), (24, LOAF_DOZE, "io")]),
    "doze": _clip(150, [(0, LOAF_DOZE, "io"), (150, LOAF_DOZE, "io")], _sleep_overlay, True),
    "doze_up": _clip(18, [(0, LOAF_DOZE, "io"), (18, LIE, "io")]),
    "jump_start": _clip(20, [(0, STAND, "io"), (10, J_CROUCH, "io"), (13, J_CROUCH, "out"), (20, J_LAUNCH, "io")]),
    "jump_air": _clip(12, [(0, J_AIR, "io"), (12, J_AIR, "io")], lambda f, n: tail_sway(f, n, 1, 4), True),
    "jump_land": _clip(18, [(0, J_LAND, "out"), (5, J_LANDLOW, "io"), (18, STAND, "io")]),
    "sniff": _clip(75, [(0, STAND, "io"), (12, SNIFF, "io"), (60, SNIFF, "io"), (75, STAND, "io")], _sniff_overlay),
    "eat": _clip(60, [(0, EAT, "io"), (60, EAT, "io")], _eat_overlay, True),
    "scratch": _clip(66, [(0, SIT, "io"), (10, SCRATCH, "io"), (52, SCRATCH, "io"), (66, SIT, "io")], _scratch_overlay),
    "groom": _clip(120, [(0, SIT, "io"), (14, GROOM_LICK, "io"), (60, GROOM_LICK, "io"), (72, GROOM_WIPE, "io"),
                         (100, GROOM_WIPE, "io"), (120, SIT, "io")], _groom_overlay),
    # --- Yakın kamera (hepsi oturuşla başlar / biter, oltada çömelme) ---
    "pet": _clip(64, [(0, SIT, "io"), (8, PET_UP, "io"), (20, PET_L, "io"), (34, PET_R, "io"), (48, PET_L, "io"),
                      (64, SIT, "io")], lambda f, n: _tail_quiver(f) if 6 <= f <= 56 else {}),
    "play_enter": _clip(15, [(0, SIT, "io"), (15, CROUCH, "io")]),
    "play_crouch": _clip(40, [(0, CROUCH, "io"), (40, CROUCH, "io")], _crouch_overlay, True),
    "play_pounce": _clip(36, [(0, CROUCH, "io"), (9, P_UP, "out"), (13, P_UP, "in"), (19, P_DOWN, "io"), (26, P_DOWN, "io"),
                              (36, CROUCH, "io")]),
    "play_swat": _clip(40, [(0, SIT, "io"), (8, SWAT_UP, "io"), (11, SWAT_A, "out"), (15, SWAT_B, "out"), (19, SWAT_A, "out"),
                            (23, SWAT_B, "out"), (29, SWAT_UP, "io"), (40, SIT, "io")]),
    "play_exit": _clip(15, [(0, CROUCH, "io"), (15, SIT, "io")]),
    "trick_paw": _clip(54, [(0, SIT, "io"), (12, PAW, "io"), (40, PAW, "io"), (54, SIT, "io")],
                       lambda f, n: {"upperarm_R": (_osc(f, 14, 3) if 12 <= f <= 40 else 0, 0, 0)}),
    "trick_beg": _clip(44, [(0, SIT, "io"), (10, BEG, "out"), (30, BEG, "io"), (44, SIT, "io")], _beg_overlay),
    "trick_roll": _clip(108, [(0, SIT, "io"), (18, LIE, "io"), (32, SIDE, "io"), (44, BACK, "io"), (66, BACK, "io"),
                              (78, SIDE, "io"), (92, LIE, "io"), (108, SIT, "io")], _roll_overlay),
}
