#!/usr/bin/env python3
"""KASA / GEM EKONOMİSİ SİMÜLASYONU — oyunun GERÇEK verisini okur (vehicles/cars.json,
vehicles/crates.json) ve gem kaynaklarını oyundaki sabitlerle aynı kurallarla modeller.

Tasarım: docs/vehicle_crate_design_v2.md · Uygulama raporu: docs/vehicle_crate_implementation_report.md

Kullanım:
  python3 tools/economy/crate_sim.py theory                 # oranlar + belirli aracı görme olasılığı
  python3 tools/economy/crate_sim.py crates  [--players N]  # kasa tamamlama dağılımı
  python3 tools/economy/crate_sim.py ncrates [--players N]  # 10/25/50/100/200 kasa sonrası koleksiyon
  python3 tools/economy/crate_sim.py days    [--players N]  # CASUAL/ACTIVE/HEAVY 1/3/7/14/30 gün
  python3 tools/economy/crate_sim.py all     [--players N]  # hepsi (varsayılan N = 100000)

Gem kaynaklarının oyundaki karşılıkları (değer değişirse burası da güncellenmeli; test_sync kontrol eder):
  başlangıç 40 gem ........................ PlayerProgress.gems (Main.tscn)
  7 hikâye görevi (125) + İLK KASA ........ gameplay/quest_catalog.gd
  seviye 5, her 5. seviyede +25 ........... PlayerProgress.LEVEL_GEMS / LEVEL_GEM_MILESTONE
  giriş 10·10·15·10·15·10·40 .............. GemRewards.LOGIN_CYCLE
  günlük 5/5 bonusu, haftalık görev + büyük ödül  MissionCatalog.DAILY_BONUS_GEMS / WEEKLY_GEMS / WEEKLY_BONUS_GEMS
  başarım yıldızları ...................... MissionCatalog.ACHIEVEMENTS / ACH_GEMS (ölçülebilen çizgiler)
  bahşiş 20 tamirde 1, günde en çok 40 .... GemRewards.TIP_EVERY / TIP_DAILY_CAP
  ustalık yıldızı 10 ...................... GemRewards.MASTERY_STAR_GEMS
  keşif / koleksiyon / kopya hurdası ...... CrateManager.DISCOVERY_GEMS / COLLECTION_MILESTONES / DUP_SCRAP
Oynanış dakikası → seviye / ustalık / tamir eğrileri ölçülmüş simülasyondan (docs/AUDIT_2026_09.md §6).
"""
import argparse
import bisect
import json
import math
import os
import random
import statistics as st

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def load_data():
    cars = json.load(open(os.path.join(ROOT, "vehicles", "cars.json")))["cars"]
    crates_doc = json.load(open(os.path.join(ROOT, "vehicles", "crates.json")))
    weights = {r["id"]: float(r["weight"]) for r in crates_doc["rarities"]}
    car = {c["id"]: c for c in cars}
    crates = []
    for c in crates_doc["crates"]:
        pool = [v for v in c["pool"] if v in car]
        tot = sum(weights[car[v]["rarity"]] for v in pool)
        odds = [(v, weights[car[v]["rarity"]] / tot) for v in pool]
        crates.append({"id": c["id"], "name": c["short_name"], "price": int(c["price_gems"]),
                       "level": int(c["min_level"]), "odds": odds})
    starters = [c for c in car if not any(c in [v for v, _ in k["odds"]] for k in crates)]
    return car, crates, starters, crates_doc.get("sets", [])


CAR, CRATES, STARTERS, SETS = load_data()
BY_ID = {k["id"]: k for k in CRATES}
TOTAL = len(CAR)
STARTING_VEHICLE = "tofas_sahin"

# --- Oyundaki sabitler (bkz. docstring) ---------------------------------------------------------
START_GEMS = 40
STORY = [(0, 0), (25, 10), (41, 15), (45, 10), (78, 15), (80, 20), (90, 25), (95, 30)]   # (dk, gem)
FIRST_CRATE_LEVEL = 2
LEVEL_GEMS, LEVEL_GEM_MILESTONE = 2, 10
LOGIN_CYCLE = [10, 10, 15, 10, 15, 10, 40]
DAILY_BONUS_GEMS, TASK_MIN_LEVEL = 10, 3
WEEKLY_GEMS, WEEKLY_BONUS_GEMS = 0, 40
TIP_EVERY, TIP_DAILY_CAP = 50, 3
MASTERY_STAR_GEMS = 3
DISCOVERY_GEMS = {"common": 1, "rare": 3, "epic": 8, "legendary": 15}
COLLECTION_MILESTONES = {5: 5, 10: 10, 14: 20, 16: 40}
DUP_SCRAP = {"common": 1, "rare": 2, "epic": 5, "legendary": 12}
STAR_THRESHOLDS = [1, 3, 6, 10, 15]

# --- Ölçülmüş eğriler ------------------------------------------------------------------------
LEVEL_CURVE = [(0, 1), (5, 2), (10, 3), (20, 5), (30, 6), (60, 11), (120, 16), (300, 22), (600, 25), (660, 26),
               (795, 27), (963, 28), (1170, 29), (1430, 30), (1760, 31), (2170, 32), (2680, 33), (3300, 34),
               (4080, 35), (5050, 36)]
STAR_CURVE = [(0, 0), (20, 4), (60, 8), (120, 13), (300, 21), (600, 28), (1500, 32), (3000, 35)]
REPAIRS_PER_MIN = 3.8
# dk/gün, günlük 5/5 olasılığı, haftalık 5/5 olasılığı, haftalık tamamlanan görev (5/5 değilse) —
# olasılıklar qa/mission_sim.gd çıktısından (2026-10-11).
PROFILES = {"CASUAL": (20, 0.45, 0.46, 3), "ACTIVE": (60, 0.62, 0.81, 4), "HEAVY": (150, 0.65, 0.89, 4)}


def _round(x):
    """GDScript round(): yarım sıfırdan uzağa (Python round bankacı yuvarlaması yapar)."""
    return int(math.floor(x + 0.5))


def _load_achievements():
    """MissionCatalog.ACHIEVEMENTS: yalnızca dakikadan / simülasyon durumundan ölçülebilen çizgiler.
    Ölçülemeyenler (₺, yarış, dekor, garaj, rütbe …) DAHİL DEĞİL → başarım gemi alt sınırdır."""
    import re
    src = open(os.path.join(ROOT, "gameplay", "missions", "mission_catalog.gd"), encoding="utf-8").read()
    base = [int(x) for x in re.findall(r"\d+", re.search(r"const ACH_VALUE[^=]*=\s*\[(.*?)\]", src).group(1))]
    share = float(re.search(r"const ACH_GEM_SHARE[^=]*=\s*([\d.]+)", src).group(1))
    lines = {}
    for m in re.finditer(r'\{"id": &"(a_\w+)".*?"metric": &"(\w+)".*?"tiers": \[([^\]]*)\](.*?)\},?\n', src):
        tiers = [int(x) for x in m.group(3).split(",")]
        g = re.search(r'"value": \[([^\]]*)\]', m.group(4))
        if g:
            value = [int(x) for x in g.group(1).split(",")]
        else:
            mult = float(re.search(r'"mult": ([\d.]+)', m.group(4)).group(1))
            value = [max(_round(b * mult), 1) for b in base[:len(tiers)]]
        gems = [max(_round(v * share), 1) for v in value]
        lines[m.group(2)] = list(zip(tiers, gems))
    return base, lines


ACH_BASE, ACH_LINES = _load_achievements()
ACH_MEASURED = ("repairs", "player_level", "job_stars", "days_played", "best_streak", "daily_done", "daily_all",
                "weekly_all", "cars_discovered", "crates_opened")


def interp(curve, m):
    for (a, x), (b, y) in zip(curve, curve[1:]):
        if a <= m < b:
            return x + (y - x) * (m - a) / (b - a)
    return curve[-1][1]


def level_at(m):
    return int(interp(LEVEL_CURVE, m))


def level_gems(lv):
    return sum(LEVEL_GEMS + (LEVEL_GEM_MILESTONE if l % 5 == 0 else 0) for l in range(2, lv + 1))


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(int(q * len(xs)), len(xs) - 1)]


class Drawer:
    def __init__(self):
        self.cum = {}
        for k in CRATES:
            acc, s = [], 0.0
            for _, p in k["odds"]:
                s += p
                acc.append(s)
            self.cum[k["id"]] = ([v for v, _ in k["odds"]], acc)

    def draw(self, crate, rng):
        ids, acc = self.cum[crate]
        return ids[min(bisect.bisect_left(acc, rng.random()), len(ids) - 1)]


DRAW = Drawer()


def p_new(crate, owned):
    return sum(p for v, p in BY_ID[crate]["odds"] if v not in owned)


def pick_crate(owned, level, gems=None):
    """Oyuncu politikası: açık kasalar arasında P(yeni)/fiyat oranı en iyi olan (qa/sim_progress.gd ile aynı)."""
    opts = [k["id"] for k in CRATES if level >= k["level"] and p_new(k["id"], owned) > 0]
    if not opts:
        return None
    return max(opts, key=lambda c: p_new(c, owned) / BY_ID[c]["price"])


# --- Oyunla eşleşme kontrolü --------------------------------------------------------------------

def _gd(path):
    return open(os.path.join(ROOT, path), encoding="utf-8").read()


def _const(src, name):
    import re
    m = re.search(r"const %s\s*:[^=]*=\s*(.+)" % name, src)
    if not m:
        raise KeyError(name)
    return m.group(1).strip()


def sync_check():
    """Simülasyon sabitleri oyundaki GDScript sabitleriyle aynı mı? Farklıysa sonuç yanlıştır."""
    import re
    gr, cm, pp, qc, mc = _gd("gameplay/gem_rewards.gd"), _gd("gameplay/crate_manager.gd"), \
        _gd("gameplay/player_progress.gd"), _gd("gameplay/quest_catalog.gd"), _gd("gameplay/missions/mission_catalog.gd")
    ints = lambda s: [int(x) for x in re.findall(r"-?\d+", s)]
    game = {
        "LOGIN_CYCLE": ints(_const(gr, "LOGIN_CYCLE")),
        "DAILY_BONUS_GEMS": ints(_const(mc, "DAILY_BONUS_GEMS"))[0], "TASK_MIN_LEVEL": ints(_const(mc, "MIN_LEVEL"))[0],
        "WEEKLY_GEMS": ints(_const(mc, "WEEKLY_GEMS"))[0], "WEEKLY_BONUS_GEMS": ints(_const(mc, "WEEKLY_BONUS_GEMS"))[0],
        "TIP_EVERY": ints(_const(gr, "TIP_EVERY"))[0], "TIP_DAILY_CAP": ints(_const(gr, "TIP_DAILY_CAP"))[0],
        "MASTERY_STAR_GEMS": ints(_const(gr, "MASTERY_STAR_GEMS"))[0],
        "LEVEL_GEMS": ints(_const(pp, "LEVEL_GEMS"))[0], "LEVEL_GEM_MILESTONE": ints(_const(pp, "LEVEL_GEM_MILESTONE"))[0],
        "STORY_GEMS": sum(int(x) for x in re.findall(r'"gems":\s*(\d+)', qc)),
    }
    for name in ("DUP_SCRAP", "DISCOVERY_GEMS"):
        game[name] = {k: int(v) for k, v in re.findall(r'&"(\w+)":\s*(\d+)', _const(cm, name))}
    game["COLLECTION_MILESTONES"] = {int(k): int(v) for k, v in re.findall(r"(\d+):\s*(\d+)", _const(cm, "COLLECTION_MILESTONES"))}
    sim = {"LOGIN_CYCLE": LOGIN_CYCLE, "DAILY_BONUS_GEMS": DAILY_BONUS_GEMS, "TASK_MIN_LEVEL": TASK_MIN_LEVEL,
           "WEEKLY_GEMS": WEEKLY_GEMS, "WEEKLY_BONUS_GEMS": WEEKLY_BONUS_GEMS,
           "TIP_EVERY": TIP_EVERY, "TIP_DAILY_CAP": TIP_DAILY_CAP, "MASTERY_STAR_GEMS": MASTERY_STAR_GEMS,
           "LEVEL_GEMS": LEVEL_GEMS, "LEVEL_GEM_MILESTONE": LEVEL_GEM_MILESTONE,
           "STORY_GEMS": sum(g for _, g in STORY), "DUP_SCRAP": DUP_SCRAP, "DISCOVERY_GEMS": DISCOVERY_GEMS,
           "COLLECTION_MILESTONES": COLLECTION_MILESTONES}
    bad = [k for k in sim if sim[k] != game[k]]
    print("\n=== OYUNLA EŞLEŞME ===")
    for k in sim:
        print("%-22s %s" % (k, "aynı" if k not in bad else "FARKLI  sim=%s  oyun=%s" % (sim[k], game[k])))
    if bad:
        raise SystemExit("simülasyon sabitleri oyunla uyuşmuyor: %s" % bad)


# --- Raporlar ---------------------------------------------------------------------------------

def report_theory():
    print("\n=== ORANLAR (kasa ekranında gösterilen, vehicles/crates.json ağırlıklarından) ===")
    for k in CRATES:
        print("%-8s %3d gem  sv%2d  " % (k["name"], k["price"], k["level"]) +
              "  ".join("%s(%s) %.2f%%" % (v, CAR[v]["rarity"][0].upper(), 100 * p) for v, p in k["odds"]))
    print("\n=== BELİRLİ ARACI GÖRME (o kasadan n açılış) — Epic ve Legendary ===")
    print("araç | p | 10 | 25 | 50 | 100 | 200 | %50 | %75 | %90 | %95 (kasa)")
    for k in CRATES:
        for v, p in k["odds"]:
            if CAR[v]["rarity"] in ("epic", "legendary"):
                row = " | ".join("%.1f%%" % (100 * (1 - (1 - p) ** n)) for n in (10, 25, 50, 100, 200))
                need = [math.ceil(math.log(1 - q) / math.log(1 - p)) for q in (0.5, 0.75, 0.9, 0.95)]
                print("%s | %.2f%% | %s | %d | %d | %d | %d" % (v, 100 * p, row, *need))


def report_crates(n_players, rng):
    print("\n=== KASA TAMAMLAMA (%d oyuncu / kasa) ===" % n_players)
    print("kasa | havuz | medyan | P75 | P90 | P95 | medyan gem | P90 gem")
    for k in CRATES:
        size = len(k["odds"])
        runs = []
        for _ in range(n_players):
            seen, n = set(), 0
            while len(seen) < size:
                seen.add(DRAW.draw(k["id"], rng))
                n += 1
            runs.append(n)
        print("%s | %d | %d | %d | %d | %d | %d | %d" % (k["name"], size, pct(runs, .5), pct(runs, .75), pct(runs, .9),
                                                        pct(runs, .95), pct(runs, .5) * k["price"], pct(runs, .9) * k["price"]))


def report_ncrates(n_players, rng):
    marks = [10, 25, 50, 100, 200]
    res = {m: [] for m in marks}
    gem = {m: [] for m in marks}
    dup = {m: [] for m in marks}
    leg = {m: [0, 0] for m in marks}
    done = []
    for _ in range(n_players):
        owned = set(STARTERS)
        spent = d = 0
        fin = None
        for n in range(1, 201):
            crate = pick_crate(owned, 99) or CRATES[-1]["id"]
            spent += BY_ID[crate]["price"]
            v = DRAW.draw(crate, rng)
            if v in owned:
                d += 1
            owned.add(v)
            if fin is None and len(owned) == TOTAL:
                fin = n
            if n in res:
                res[n].append(len(owned))
                gem[n].append(spent)
                dup[n].append(d)
                leg[n][0] += "bmw_e60" in owned
                leg[n][1] += "bmw_e46" in owned
        done.append(fin or 999)
    print("\n=== KASA SAYISINA GÖRE KOLEKSİYON (%d oyuncu, tüm kasalar açık, %d araç) ===" % (n_players, TOTAL))
    print("kasa | ort | P10 | P25 | medyan | P75 | P90 | P95 | 16/16 | E60 | E46 | kopya | gem")
    for m in marks:
        x = res[m]
        print("%d | %.2f | %d | %d | %d | %d | %d | %d | %.1f%% | %.1f%% | %.1f%% | %.1f | %.0f" % (
            m, st.mean(x), pct(x, .1), pct(x, .25), pct(x, .5), pct(x, .75), pct(x, .9), pct(x, .95),
            100 * sum(v == TOTAL for v in x) / n_players, 100 * leg[m][0] / n_players, 100 * leg[m][1] / n_players,
            st.mean(dup[m]), st.mean(gem[m])))
    print("16/16 için kasa: medyan %d, P75 %d, P90 %d, P95 %s" % (
        pct(done, .5), pct(done, .75), pct(done, .9), pct(done, .95) if pct(done, .95) < 999 else ">200"))


def simulate_player(profile, rng, days=30):
    mpd, p_daily_all, p_weekly_all, weekly_partial = PROFILES[profile]
    owned = {STARTING_VEHICLE}
    discovered = set(owned)
    earned = {"hikaye": START_GEMS, "seviye": 0, "giris": 0, "gunluk": 0, "haftalik": 0, "ustalik": 0,
              "basarim": 0, "bahsis": 0, "kesif": 0, "koleksiyon": 0, "kopya": 0}
    spent = opened = dups = 0
    dup_by = {"common": 0, "rare": 0, "epic": 0, "legendary": 0}
    story_prev = stars_prev = 0
    lv_prev = 1
    paid_ms = set()
    free_crate = True
    metrics = {k: 0 for k in ACH_MEASURED}
    ach_paid = {k: 0 for k in ACH_MEASURED}   # ödenmiş yıldız sayısı
    snaps = {}

    def pay_achievements():
        stars = sum(ach_paid.values())
        for k in ACH_MEASURED:
            for tier, gm in ACH_LINES.get(k, [])[ach_paid[k]:]:
                if metrics[k] < tier:
                    break
                ach_paid[k] += 1
                earned["basarim"] += gm
        # YILDIZ TOPLAYICI: diğer çizgilerin yıldızları (ölçülmeyen çizgiler sayılmaz → alt sınır)
        meta = ACH_LINES.get("ach_stars", [])
        total = sum(ach_paid.values())
        while ach_paid.get("_meta", 0) < len(meta) and total >= meta[ach_paid.get("_meta", 0)][0]:
            earned["basarim"] += meta[ach_paid.get("_meta", 0)][1]
            ach_paid["_meta"] = ach_paid.get("_meta", 0) + 1
        return sum(ach_paid.values()) != stars

    for day in range(1, days + 1):
        m = mpd * day
        story = sum(gm for t, gm in STORY if t <= m)
        earned["hikaye"] += story - story_prev
        story_prev = story
        lv = level_at(m)
        earned["seviye"] += level_gems(lv) - level_gems(lv_prev)
        lv_prev = lv
        earned["giris"] += LOGIN_CYCLE[(day - 1) % 7]
        if lv >= TASK_MIN_LEVEL:
            metrics["daily_done"] += 4
            if rng.random() < p_daily_all:
                earned["gunluk"] += DAILY_BONUS_GEMS
                metrics["daily_done"] += 1
                metrics["daily_all"] += 1
            if day % 7 == 0:
                if rng.random() < p_weekly_all:
                    earned["haftalik"] += 5 * WEEKLY_GEMS + WEEKLY_BONUS_GEMS
                    metrics["weekly_all"] += 1
                else:
                    earned["haftalik"] += weekly_partial * WEEKLY_GEMS
        earned["bahsis"] += min(int(mpd * REPAIRS_PER_MIN / TIP_EVERY), TIP_DAILY_CAP)
        s = int(interp(STAR_CURVE, m))
        earned["ustalik"] += (s - stars_prev) * MASTERY_STAR_GEMS
        stars_prev = s
        metrics.update(repairs=int(m * REPAIRS_PER_MIN), player_level=lv, job_stars=s, days_played=day,
                       best_streak=day, cars_discovered=len(discovered), crates_opened=opened)
        pay_achievements()
        gems = sum(earned.values()) - spent
        while True:
            crate = pick_crate(owned, lv)
            if crate is None:
                break
            price = BY_ID[crate]["price"]
            if free_crate and crate == CRATES[0]["id"] and lv >= FIRST_CRATE_LEVEL:
                free_crate, price = False, 0
            elif gems < price:
                break
            spent += price
            gems -= price
            opened += 1
            v = DRAW.draw(crate, rng)
            r = CAR[v]["rarity"]
            if v in owned:
                dups += 1
                dup_by[r] += 1
                earned["kopya"] += DUP_SCRAP[r]
                gems += DUP_SCRAP[r]
            else:
                owned.add(v)
                discovered.add(v)
                earned["kesif"] += DISCOVERY_GEMS[r]
                gems += DISCOVERY_GEMS[r]
                for th, gm in COLLECTION_MILESTONES.items():
                    if len(discovered) >= th and th not in paid_ms:
                        paid_ms.add(th)
                        earned["koleksiyon"] += gm
                        gems += gm
        metrics.update(cars_discovered=len(discovered), crates_opened=opened)
        pay_achievements()
        snaps[day] = {"lv": lv, "earned": sum(earned.values()), "spent": spent, "opened": opened, "owned": len(owned),
                      "dups": dups, "dup_by": dict(dup_by), "src": dict(earned),
                      "epic": sum(1 for c in owned if CAR[c]["rarity"] == "epic"),
                      "leg": sum(1 for c in owned if CAR[c]["rarity"] == "legendary"),
                      "e60": "bmw_e60" in owned, "e46": "bmw_e46" in owned, "owned_set": frozenset(owned)}
    return snaps


def report_days(n_players, rng):
    for profile in PROFILES:
        runs = [simulate_player(profile, rng) for _ in range(n_players)]
        print("\n=== %s (%d dk/gün, %d oyuncu) ===" % (profile, PROFILES[profile][0], n_players))
        print("gün | sv | kazanılan gem | harcanan | kasa | araç medyan (P25-P75, P90) | 16/16 | kopya | epic | leg | E46 | E60")
        for d in (1, 3, 7, 14, 30):
            S = [r[d] for r in runs]
            own = [s["owned"] for s in S]
            print("%d | %d | %.0f | %.0f | %.1f | %d (%d-%d, %d) | %.1f%% | %.1f | %.2f | %.2f | %.1f%% | %.1f%%" % (
                d, S[0]["lv"], st.mean(s["earned"] for s in S), st.mean(s["spent"] for s in S),
                st.mean(s["opened"] for s in S), pct(own, .5), pct(own, .25), pct(own, .75), pct(own, .9),
                100 * sum(o == TOTAL for o in own) / n_players, st.mean(s["dups"] for s in S),
                st.mean(s["epic"] for s in S), st.mean(s["leg"] for s in S),
                100 * st.mean(s["e46"] for s in S), 100 * st.mean(s["e60"] for s in S)))
        for a_, b_ in ((1, 7), (7, 30)):
            print("gün %d→%d arası ortalama gem/gün: %.1f" % (a_, b_, st.mean(
                (r[b_]["earned"] - r[a_]["earned"]) / (b_ - a_) for r in runs)))
        S = [r[30] for r in runs]
        print("30. gün gem kaynakları:", {k: round(st.mean(s["src"][k] for s in S)) for k in S[0]["src"]})
        print("30. gün kopya nadirliği:", {k: round(st.mean(s["dup_by"][k] for s in S), 2) for k in S[0]["dup_by"]})
        print("30. gün set tamamlanma:", {s_["name"]: "%.0f%%" % (100 * sum(all(c in r[30]["owned_set"] for c in s_["cars"])
                                                                     for r in runs) / n_players) for s_ in SETS})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", nargs="?", default="all", choices=["theory", "crates", "ncrates", "days", "all"])
    ap.add_argument("--players", type=int, default=100000)
    ap.add_argument("--seed", type=int, default=20260929)
    a = ap.parse_args()
    rng = random.Random(a.seed)
    print("veri: %d araç, %d kasa, başlangıç: %s" % (TOTAL, len(CRATES), STARTERS))
    sync_check()
    if a.mode in ("theory", "all"):
        report_theory()
    if a.mode in ("crates", "all"):
        report_crates(a.players, rng)
    if a.mode in ("ncrates", "all"):
        report_ncrates(a.players, rng)
    if a.mode in ("days", "all"):
        report_days(a.players, rng)


if __name__ == "__main__":
    main()
