#!/usr/bin/env python3
"""HURDALIK EKONOMİ SİMÜLASYONU — yığın sayısı, dolma süresi, boş çıkma olasılığı ve tamirden parça düşmesi
hedef sürelere (docs/HURDALIK_TASARIM.md §5: temel araç ~1–2 gün, usta araç ~1–2 hafta) uyuyor mu?

Model (JunkyardManager'ın kuralları birebir):
  * Oyuncu günde 3 oturum (~08:30 / 13:00 / 21:00, ±60 dk) + %35 olasılıkla 4. oturum açar. Her oturumda
    hurdalığa gider, DOLU yığınların hepsini arar, 5 tamir yapar.
  * Aranan yığın refill dakika sonra dolar. Arama empty olasılıkla boş, değilse parts_min..parts_max parça;
    parça AÇIK kademelerin reçetelerinde geçenlerden (uniform: eşit, weighted: reçetelerdeki toplam
    kullanımına göre). İlk arama her zaman dolu.
  * Tamirden parça düşmesi: her tamirde drop olasılığıyla 1 parça (aynı havuzdan).
  * Sahada her gece yarısı 3 araç (havuz = açık kademelerin bitmemiş araçları, dünkülerden kaçınılır).
    Oyuncunun TEK projesi olur (bir tamir alanı); proje yoksa sahadaki araçlardan birini RASTGELE seçer.
    Envanterdeki parçalar hemen takılır, %100'de biter. Gem harcanmaz (ücretsiz oyuncu).
  * 10 temel restorasyondan sonra usta kademeleri (klasik + yarış) açılır.
Çıktı: her ayar için temel ve usta araçların ortalama / medyan bitiş süresi (gün), 10. temelin günü.

Kullanım: python3 tools/economy/junkyard_sim.py [--runs 200] [--grid]
"""
import json, random, statistics, sys, os, itertools

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = json.load(open(os.path.join(ROOT, "vehicles/restorations.json"), encoding="utf-8"))
MODELS = {c["id"] for c in json.load(open(os.path.join(ROOT, "vehicles/cars.json"), encoding="utf-8"))["cars"]}
CARS = [c for c in DATA["cars"] if c["id"] in MODELS]
PARTS = [p["id"] for p in DATA["parts"]]
TIER_REQ = {t["id"]: t["requires_completed"] for t in DATA["tiers"]}
DAYS = 90
REPAIRS_PER_SESSION = 5


PROFILE = "normal"   # light: günde 2 oturum · normal: 3 (+%35 4.) · heavy: 6 oturum


def sessions_for_day(rng, day):
    if PROFILE == "light":
        times = [9 * 60, 21 * 60]
    elif PROFILE == "heavy":
        times = [8 * 60, 10.5 * 60, 13 * 60, 16 * 60, 19 * 60, 22 * 60]
    else:
        times = [8.5 * 60, 13 * 60, 21 * 60]
        if rng.random() < 0.35:
            times.append(17.5 * 60)
    return sorted(day * 1440 + t + rng.uniform(-60, 60) for t in times)


def pool_parts(completed_basic, weighted):
    unlocked = {t for t, req in TIER_REQ.items() if completed_basic >= req}
    use = {}
    for c in CARS:
        if c["tier"] in unlocked:
            for p, n in c["recipe"].items():
                use[p] = use.get(p, 0) + n
    parts = [p for p in PARTS if p in use]
    weights = [use[p] if weighted else 1 for p in parts]
    return parts, weights


def run(cfg, seed):
    rng = random.Random(seed)
    piles = [0.0] * cfg["piles"]
    inv = {}
    project = None          # {"car": entry, "installed": {...}, "start": minute}
    done = []               # (car, tier, minutes taken, finished at)
    completed = set()
    yard, prev, yard_day = [], [], -1
    searches = 0
    for day in range(DAYS):
        # Saha yenilenir
        basic_done = sum(1 for _, t, _, _ in done if t == "basic")
        unlocked = {t for t, req in TIER_REQ.items() if basic_done >= req}
        pool = [c for c in CARS if c["tier"] in unlocked and c["id"] not in completed
                and not (project and project["car"]["id"] == c["id"])]
        fresh = [c for c in pool if c["id"] not in prev] or pool
        rng.shuffle(fresh)
        yard = fresh[:3]
        prev = [c["id"] for c in yard]
        for t in sessions_for_day(rng, day):
            basic_done = sum(1 for _, tier, _, _ in done if tier == "basic")
            parts, weights = pool_parts(basic_done, cfg["weighted"])

            def gain():
                p = rng.choices(parts, weights)[0]
                inv[p] = inv.get(p, 0) + 1
            for i in range(cfg["piles"]):
                if piles[i] <= t:
                    first = searches == 0
                    searches += 1
                    if first or rng.random() >= cfg["empty"]:
                        for _ in range(rng.randint(cfg["pmin"], cfg["pmax"])):
                            gain()
                    piles[i] = t + cfg["refill"]
            for _ in range(REPAIRS_PER_SESSION):
                if rng.random() < cfg["drop"]:
                    gain()
            if project is None and yard:
                pick = rng.choice(yard)
                yard.remove(pick)
                project = {"car": pick, "installed": {}, "start": t}
            if project:
                rec = project["car"]["recipe"]
                for p, need in rec.items():
                    have = project["installed"].get(p, 0)
                    take = min(need - have, inv.get(p, 0))
                    if take > 0:
                        project["installed"][p] = have + take
                        inv[p] -= take
                if all(project["installed"].get(p, 0) >= n for p, n in rec.items()):
                    c = project["car"]
                    done.append((c["id"], c["tier"], t - project["start"], t))
                    completed.add(c["id"])
                    project = None
    return done


def summarize(cfg, runs):
    basic, master, tenth, first, count = [], [], [], [], []
    for s in range(runs):
        done = run(cfg, s)
        b = [d[2] / 1440 for d in done if d[1] == "basic"]
        m = [d[2] / 1440 for d in done if d[1] != "basic"]
        basic += b
        master += m
        bdone = [d[3] / 1440 for d in done if d[1] == "basic"]
        if len(bdone) >= 10:
            tenth.append(bdone[9])
        if done:
            first.append(done[0][3] / 1440)
        count.append(len(done))
    med = lambda xs: statistics.median(xs) if xs else float("nan")
    avg = lambda xs: statistics.mean(xs) if xs else float("nan")
    return {"basic_avg": avg(basic), "basic_med": med(basic), "master_avg": avg(master), "master_med": med(master),
            "tenth": med(tenth), "first": med(first), "done90": avg(count), "tenth_reached": len(tenth) / runs}


def label(cfg):
    return "%d yığın · %dsa dolma · boş %%%d · %d–%d parça · tamir %%%d · %s" % (
        cfg["piles"], cfg["refill"] // 60, int(cfg["empty"] * 100), cfg["pmin"], cfg["pmax"], int(cfg["drop"] * 100),
        "ağırlıklı" if cfg["weighted"] else "eşit")


def main():
    runs = int(sys.argv[sys.argv.index("--runs") + 1]) if "--runs" in sys.argv else 120
    if "--profiles" in sys.argv:
        global PROFILE
        candidates = [
            dict(piles=4, refill=240, empty=0.35, pmin=1, pmax=2, drop=0.0, weighted=False),
            dict(piles=4, refill=180, empty=0.25, pmin=1, pmax=1, drop=0.1, weighted=False),
            dict(piles=5, refill=360, empty=0.35, pmin=1, pmax=2, drop=0.1, weighted=False),
            dict(piles=3, refill=240, empty=0.25, pmin=1, pmax=2, drop=0.1, weighted=False),
            dict(piles=6, refill=480, empty=0.25, pmin=1, pmax=1, drop=0.1, weighted=False),
        ]
        for cfg in candidates:
            print(label(cfg))
            for profile in ["light", "normal", "heavy"]:
                PROFILE = profile
                r = summarize(cfg, runs)
                print("   %-6s temel %.2f g · usta %.1f g · 10. temel %.1f. gün · 90 günde %.1f araç" % (
                    profile, r["basic_avg"], r["master_avg"], r["tenth"], r["done90"]))
        return
    if "--grid" in sys.argv:
        rows = []
        for piles, refill, empty, (pmin, pmax), drop, weighted in itertools.product(
                [3, 4, 5, 6], [120, 180, 240, 360, 480], [0.25, 0.35], [(1, 1), (1, 2)], [0.0, 0.1], [False, True]):
            cfg = dict(piles=piles, refill=refill, empty=empty, pmin=pmin, pmax=pmax, drop=drop, weighted=weighted)
            r = summarize(cfg, max(20, runs // 6))
            ok = 1.0 <= r["basic_avg"] <= 2.0 and 7.0 <= r["master_avg"] <= 14.0
            rows.append((ok, abs(r["basic_avg"] - 1.5) + abs(r["master_avg"] - 10.5) / 7, cfg, r))
        rows.sort(key=lambda x: (not x[0], x[1]))
        for ok, score, cfg, r in rows[:25]:
            print("%s %-62s temel %.2f g (med %.2f) · usta %.1f g (med %.1f) · 10. temel %.1f. gün" % (
                "✔" if ok else " ", label(cfg), r["basic_avg"], r["basic_med"], r["master_avg"], r["master_med"], r["tenth"]))
        return
    y = DATA.get("yard", {})
    cfg = dict(piles=y.get("piles", 6), refill=y.get("refill_minutes", 240), empty=y.get("empty_chance", 0.3),
               pmin=y.get("parts_min", 1), pmax=y.get("parts_max", 2), drop=0.0, weighted=False)
    r = summarize(cfg, runs)
    print("ŞU ANKİ AYAR:", label(cfg))
    for k, v in r.items():
        print("  %-14s %.2f" % (k, v))


if __name__ == "__main__":
    main()
