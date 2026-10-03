#!/usr/bin/env python3
"""PARAMETRİK EDİNİM SİMÜLASYONU — kasa (gem) + doğrudan satın alma (₺), HERHANGİ bir katalogla.
ANALİZ ARACI; oyun kodu değil. Tasarım: docs/direct_vehicle_purchase_design.md §10 ve §16.

direct_purchase_sim.py'nin genelleştirilmiş hali:
  * katalog gerçek (vehicles/*.json) ya da sentetik (acquisition_model.synthetic) olabilir,
  * fiyat / seviye / sadakat acquisition_model'deki genel kurallardan türetilir (araç kimliği yok),
  * "Legendary sahipliği" tek araç adıyla değil nadirlik + sınıf ile ölçülür (gerçek katalogda E60 / E46 ayrıca),
  * koleksiyon gem eşikleri katalog büyüklüğüne oranlanır (bugünkü 5/10/14/16 = 16 aracın %31/%63/%88/%100'ü),
  * çok çekirdekli; kasa P(yeni) değerleri artımlı tutulur (200 araçta da hızlı).
Gem kaynakları ve ₺ eğrisi crate_sim.py / direct_purchase_sim.py ile AYNI (ölçülmüş, 16 araçlık bugünkü oyun).

Kullanım:
  python3 tools/economy/acquisition_sim.py --players 100000 --catalogs 16,50,100
  python3 tools/economy/acquisition_sim.py --players 20000 --catalogs 16 --check     # eski simülasyonla karşılaştırma
"""
import argparse
import math
import multiprocessing as mp
import random
import statistics as st
import time

import acquisition_model as M
import crate_sim as C
from direct_purchase_sim import income_at, START_MONEY, UPGRADES, DECOR_TOTAL

PROFILES = {"CASUAL": (20, 2, 30), "ACTIVE": (60, 3, 30), "HEAVY": (150, 3, 30), "10 SAAT (tek gün)": (600, 3, 1)}
MILESTONE_FRACTIONS = [(5 / 16, 15), (10 / 16, 30), (14 / 16, 50), (1.0, 100)]


def milestones(total):
    return {max(1, math.ceil(f * total - 1e-9)): g for f, g in MILESTONE_FRACTIONS}


class Prepared:
    """Simülasyon için önceden hesaplanmış katalog + politika (araç başına sabitler, kasa tabloları)."""

    def __init__(self, cat, pol, direct):
        self.cat, self.direct = cat, direct
        d = M.derive_all(pol, cat) if pol else {}
        ids = list(cat.cars)
        self.ids = ids
        self.idx = {v: i for i, v in enumerate(ids)}
        self.rarity = [cat.cars[v]["rarity"] for v in ids]
        self.base = [cat.cars[v]["base_value"] for v in ids]
        self.disc_gems = [C.DISCOVERY_GEMS.get(r, 0) for r in self.rarity]
        self.scrap = [C.DUP_SCRAP.get(r, 0) for r in self.rarity]
        self.crates = [c for c in cat.crates if c["odds"]]
        self.ci = {c["id"]: k for k, c in enumerate(self.crates)}
        self.crate_level = [c["level"] for c in self.crates]
        self.crate_price = [c["price"] for c in self.crates]
        self.crate_pool = [[(self.idx[v], p) for v, p in c["odds"]] for c in self.crates]
        self.cum = []
        for c in self.crates:
            acc, s = [], 0.0
            for _, p in c["odds"]:
                s += p
                acc.append(s)
            self.cum.append(([self.idx[v] for v, _ in c["odds"]], acc))
        self.car_crates = [[self.ci[c] for c in cat.crates_of[v] if c in self.ci] for v in ids]
        self.first_crate = min(range(len(self.crates)), key=lambda k: self.crate_level[k]) if self.crates else None
        self.starters = [self.idx[v] for v in cat.starters if v in self.idx]
        self.ms = milestones(len(ids))
        # doğrudan satın alma: (fiyat, seviye, sadakat, kasa indeksleri) — fiyata göre sıralı
        self.buyable = []
        if direct:
            for v in ids:
                r = d[v]
                if r["for_sale"] and r["price"] is not None:
                    self.buyable.append((r["price"], r["level"], r["loyalty"], [self.ci[c] for c in r["loyalty_crates"] if c in self.ci],
                                         self.idx[v]))
            self.buyable.sort()
        self.legendary = [i for i, r in enumerate(self.rarity) if r == "legendary"]
        top_class = "A" if any(cat.cars[v]["class"] == "A" for v in ids) else None
        self.leg_top = [i for i in self.legendary if cat.cars[ids[i]]["class"] == top_class]
        self.named = {n: self.idx[n] for n in ("bmw_e60", "bmw_e46") if n in self.idx}


def simulate(P, profile, rng):
    mpd, tasks, days = PROFILES[profile]
    n = len(P.ids)
    owned = [False] * n
    n_owned = 0
    pnew = [sum(p for _, p in pool) for pool in P.crate_pool]
    earned_g, spent_g = C.START_GEMS, 0
    story_prev = stars_prev = rep_step = 0
    lv_prev = 1
    paid = set()
    free_crate = True
    week_tasks = opened = dups = 0
    opened_by = [0] * len(P.crates)
    money = START_MONEY
    upg = list(UPGRADES)
    spent_upg = spent_cars = spent_decor = 0
    direct_n = crate_new = 0
    src = {"crate": {}, "direct": {}}
    income_prev = 0.0

    def own(i, how):
        nonlocal n_owned, earned_g
        owned[i] = True
        n_owned += 1
        for k in P.car_crates[i]:
            pnew[k] -= dict(P.crate_pool[k])[i]
        earned_g += P.disc_gems[i]
        for th, gm in P.ms.items():
            if n_owned >= th and th not in paid:
                paid.add(th)
                earned_g += gm
        if how:
            src[how][P.rarity[i]] = src[how].get(P.rarity[i], 0) + 1

    for s in P.starters:
        own(s, None)
    earned_g -= sum(P.disc_gems[s] for s in P.starters)   # başlangıç aracı keşif gemi vermez
    for day in range(1, days + 1):
        m = mpd * day
        story = sum(g for t, g in C.STORY if t <= m)
        earned_g += story - story_prev
        story_prev = story
        lv = C.level_at(m)
        earned_g += C.level_gems(lv) - C.level_gems(lv_prev)
        lv_prev = lv
        earned_g += C.LOGIN_CYCLE[(day - 1) % 7]
        if lv >= C.TASK_MIN_LEVEL:
            earned_g += tasks * C.TASK_GEMS + (C.ALL_TASKS_BONUS if tasks >= 3 else 0)
            week_tasks += tasks
        earned_g += min(int(mpd * C.REPAIRS_PER_MIN / C.TIP_EVERY), C.TIP_DAILY_CAP)
        if day % 7 == 0:
            if week_tasks >= C.WEEKLY_NEED:
                earned_g += C.WEEKLY_GEMS
            week_tasks = 0
        s = int(C.interp(C.STAR_CURVE, m))
        earned_g += (s - stars_prev) * C.MASTERY_STAR_GEMS
        stars_prev = s
        while rep_step < len(C.REPAIR_MILESTONES) and m * C.REPAIRS_PER_MIN >= C.REPAIR_MILESTONES[rep_step][0]:
            earned_g += C.REPAIR_MILESTONES[rep_step][1]
            rep_step += 1
        inc = income_at(m)
        money += inc - income_prev
        income_prev = inc
        while upg and money >= upg[0]:
            money -= upg[0]
            spent_upg += upg.pop(0)
        # gem → kasa: P(yeni)/fiyat en iyi açık kasa; yeni araç kalmamış kasayı açmaz
        while True:
            best, score = None, 0.0
            for k in range(len(P.crates)):
                if lv >= P.crate_level[k] and pnew[k] > 1e-12:
                    sc = pnew[k] / P.crate_price[k]
                    if sc > score:
                        best, score = k, sc
            if best is None:
                break
            cost = P.crate_price[best]
            if free_crate and best == P.first_crate and lv >= C.FIRST_CRATE_LEVEL:
                free_crate, cost = False, 0
            elif earned_g - spent_g < cost:
                break
            spent_g += cost
            opened += 1
            opened_by[best] += 1
            ids, acc = P.cum[best]
            lo, hi, x = 0, len(acc) - 1, rng.random()
            while lo < hi:
                mid = (lo + hi) // 2
                if acc[mid] < x:
                    lo = mid + 1
                else:
                    hi = mid
            v = ids[lo]
            if owned[v]:
                dups += 1
                earned_g += P.scrap[v]
            else:
                crate_new += 1
                own(v, "crate")
        # ₺ → doğrudan: parası yeten en ucuz yeni araç (koleksiyoncu, en kötü durum)
        reserve = 0
        if P.direct and not upg:
            while True:
                cand = None
                for price, level, need, crates, i in P.buyable:
                    if owned[i] or lv < level:
                        continue
                    if need and sum(opened_by[k] for k in crates) < need:
                        continue
                    cand = (price, i)
                    break
                if cand is None:
                    break
                if money < cand[0]:
                    reserve = cand[0]
                    break
                money -= cand[0]
                spent_cars += cand[0]
                direct_n += 1
                own(cand[1], "direct")
        if not upg:
            d = max(0, min(money - reserve, DECOR_TOTAL - spent_decor))
            money -= d
            spent_decor += d
    gv = sum(P.base[i] for i in range(n) if owned[i]) + spent_upg + spent_decor
    return {"owned": n_owned, "full": n_owned == n, "leg": sum(owned[i] for i in P.legendary),
            "leg_top": sum(owned[i] for i in P.leg_top), "named": {k: owned[i] for k, i in P.named.items()},
            "gv": gv, "spent": spent_upg + spent_cars + spent_decor, "spent_cars": spent_cars, "spent_decor": spent_decor,
            "money": money, "gems": spent_g, "crates": opened, "dups": dups, "direct": direct_n, "crate_new": crate_new,
            "src": src, "lv": lv}


# --- Çok çekirdekli koşu ------------------------------------------------------------------------

_P = None


def policy_for(overrides):
    pol = M.Policy.load()
    return pol.variant(**overrides) if overrides else pol


def _init(cat_spec, direct, overrides):
    global _P
    cat = build_catalog(cat_spec)
    _P = Prepared(cat, policy_for(overrides) if direct else None, direct)


def _work(args):
    profile, seed, count = args
    rng = random.Random(seed)
    return [simulate(_P, profile, rng) for _ in range(count)]


def build_catalog(spec):
    return M.Catalog.load_real() if spec == 16 else M.synthetic(spec, seed=spec)


def run(cat_spec, direct, profile, players, seed, procs, overrides=None):
    chunk = max(1, players // (procs * 4))
    jobs = [(profile, seed * 1000003 + k, min(chunk, players - k * chunk)) for k in range((players + chunk - 1) // chunk)]
    with mp.Pool(procs, initializer=_init, initargs=(cat_spec, direct, overrides)) as pool:
        out = []
        for part in pool.imap_unordered(_work, jobs):
            out.extend(part)
    return out


def summarize(R, P):
    own = sorted(r["owned"] for r in R)
    q = lambda p: own[min(int(p * len(own)), len(own) - 1)]
    tot = {"crate": {}, "direct": {}}
    for r in R:
        for how in tot:
            for k, c in r["src"][how].items():
                tot[how][k] = tot[how].get(k, 0) + c
    nleg = max(len(P.legendary), 1)
    return {"n": len(P.ids), "lv": R[0]["lv"], "med": q(.5), "p10": q(.1), "p90": q(.9), "mean": st.mean(own),
            "full": st.mean(r["full"] for r in R), "pct": st.mean(r["owned"] for r in R) / len(P.ids),
            "leg_share": st.mean(r["leg"] for r in R) / nleg, "leg_any": st.mean(r["leg"] > 0 for r in R),
            "leg_top": (st.mean(r["leg_top"] for r in R) / len(P.leg_top)) if P.leg_top else None,
            "named": {k: st.mean(r["named"][k] for r in R) for k in P.named},
            "gv": st.mean(r["gv"] for r in R), "spent": st.mean(r["spent"] for r in R),
            "spent_cars": st.mean(r["spent_cars"] for r in R), "spent_decor": st.mean(r["spent_decor"] for r in R),
            "money": st.mean(r["money"] for r in R), "gems": st.mean(r["gems"] for r in R),
            "crates": st.mean(r["crates"] for r in R), "dups": st.mean(r["dups"] for r in R),
            "direct": st.mean(r["direct"] for r in R), "crate_new": st.mean(r["crate_new"] for r in R),
            "src": {h: {k: c / len(R) for k, c in d.items()} for h, d in tot.items()}}


def fmt(s):
    named = " ".join("%s %.1f%%" % (k.replace("bmw_", "").upper(), 100 * v) for k, v in s["named"].items())
    src = []
    for r in M.RARITY_ORDER:
        c, d = s["src"]["crate"].get(r, 0), s["src"]["direct"].get(r, 0)
        if c + d > 0:
            src.append("%s %d%%" % (r[0].upper(), round(100 * c / (c + d))))
    return ("%d | %d (%d-%d) | %.1f | %.1f%% | %.1f%% | %.1f%% | %s | %s | %.0f | %.0f (%.0f / %.0f) | %.0f | %.0f | %.1f | %.1f | %.2f | %.2f | %d%% | %s"
            % (s["lv"], s["med"], s["p10"], s["p90"], s["mean"], 100 * s["pct"], 100 * s["full"], 100 * s["leg_share"],
               "%.1f%%" % (100 * s["leg_top"]) if s["leg_top"] is not None else "-", named or "-", s["gv"], s["spent"],
               s["spent_cars"], s["spent_decor"], s["money"], s["gems"], s["crates"], s["dups"], s["crate_new"], s["direct"],
               round(100 * s["crate_new"] / max(s["crate_new"] + s["direct"], 1e-9)), " ".join(src)))


HEADER = ("profil | sv | araç medyan (P10-P90) | ort. araç | koleksiyon % | tam koleksiyon | Legendary payı | A-sınıfı Legendary | "
          "E60/E46 | garaj değeri | ₺ harcama (araç / dekor) | ₺ bakiye | gem harcama | kasa | kopya | kasadan yeni | doğrudan | "
          "yeni araçta kasa payı | nadirliğe göre kasa payı")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--players", type=int, default=100000)
    ap.add_argument("--catalogs", default="16,50,100")
    ap.add_argument("--modes", default="crate_only,final")
    ap.add_argument("--profiles", default=",".join(PROFILES))
    ap.add_argument("--procs", type=int, default=max(1, mp.cpu_count() - 1))
    ap.add_argument("--seed", type=int, default=20261002)
    ap.add_argument("--tuning", type=float, default=None, help="direct_purchase.tuning_multiplier denemesi")
    ap.add_argument("--override", default=None, help='politika denemesi, JSON: {"rarity": {"common": {"level_offset": 3}}}')
    a = ap.parse_args()
    C.sync_check()
    for spec in [int(x) for x in a.catalogs.split(",")]:
        cat = build_catalog(spec)
        issues = M.validate(M.Policy.load(), cat)
        rc = {}
        for v in cat.cars.values():
            rc[v["rarity"]] = rc.get(v["rarity"], 0) + 1
        print("\n================ KATALOG: %s · %d kasa · nadirlik %s · doğrulama %d ERROR / %d WARN"
              % (cat.name, len(cat.crates), rc, sum(i[0] == "ERROR" for i in issues), sum(i[0] == "WARN" for i in issues)))
        overrides = {"tuning_multiplier": a.tuning} if a.tuning is not None else {}
        if a.override:
            import json
            overrides.update(json.loads(a.override))
        for mode in a.modes.split(","):
            direct = mode != "crate_only"
            P = Prepared(cat, policy_for(overrides) if direct else None, direct)
            print("\n##### %s · %s%s · %d oyuncu" % (cat.name, mode, (" %s" % overrides) if direct and overrides else "", a.players))
            print(HEADER)
            for profile in a.profiles.split(","):
                t0 = time.time()
                R = run(spec, direct, profile, a.players, a.seed + spec, a.procs, overrides)
                print("%s | %s   [%.0f sn]" % (profile, fmt(summarize(R, P)), time.time() - t0), flush=True)


if __name__ == "__main__":
    main()
