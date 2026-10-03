#!/usr/bin/env python3
"""DOĞRUDAN ARAÇ SATIN ALMA (₺) + KASA (gem) EKONOMİ SİMÜLASYONU — ANALİZ ARACI, oyun kodu değil.

Tasarım: docs/direct_vehicle_purchase_design.md

Kasa tarafı tools/economy/crate_sim.py'den gelir (gerçek cars.json / crates.json, oyundaki gem sabitleri —
crate_sim.sync_check() eşleşmeyi doğrular). ₺ tarafı ÖLÇÜLMÜŞTÜR: qa/sim_progress.gd -- 600 gerçek oyun
koşusunun kümülatif tamir geliri (docs/crate_system_qa_report.md §10.2); 600. dakikadan sonrası son
dilimin eğimiyle (≈3.827 ₺/dk) uzatılır.

Kullanım:
  python3 tools/economy/direct_purchase_sim.py                  # 5 senaryo, 100.000 oyuncu, 30 gün + 10 saat
  python3 tools/economy/direct_purchase_sim.py --players 20000
  python3 tools/economy/direct_purchase_sim.py --scenario final --policy target
"""
import argparse
import math
import random
import statistics as st

import crate_sim as C

# --- ₺: ölçülmüş kümülatif tamir geliri (dk → ₺), gerçek oyun 600 dk koşusu ------------------------
INCOME = [(0, 0), (5, 2770), (10, 7284), (20, 17747), (30, 29883), (60, 103842), (120, 320867),
          (180, 514063), (300, 944237), (450, 1449215), (600, 2023456)]
LATE_RATE = (2023456 - 1449215) / 150.0          # ₺/dk, 600. dakikadan sonra
START_MONEY = 5000
# Zorunlu (ilerleme) harcamaları, gerçek oyundaki satın alma sırasıyla: tamir hızı 2-5, garaj 2, alan 2,
# garaj 3, alan 3, garaj 4 (GarageUpgradeManager / RepairBayManager fiyatları; toplam 130.500 ₺)
UPGRADES = [1000, 2000, 3500, 5000, 12000, 5000, 30000, 12000, 60000]
DECOR_TOTAL = 1759800                            # 74 eşyanın tamamı (decor/decorations.json)
GARAGE_LEVEL_FOR_UPGRADE = None


def income_at(m):
    if m >= INCOME[-1][0]:
        return INCOME[-1][1] + (m - INCOME[-1][0]) * LATE_RATE
    for (a, x), (b, y) in zip(INCOME, INCOME[1:]):
        if a <= m < b:
            return x + (y - x) * (m - a) / (b - a)
    return 0.0


def income_rate(m):
    return (income_at(m + 5) - income_at(m)) / 5.0


def minute_for_level(lv):
    for (a, x), (b, y) in zip(C.LEVEL_CURVE, C.LEVEL_CURVE[1:]):
        if x <= lv <= y:
            return a + (b - a) * (lv - x) / max(y - x, 1e-9)
    return C.LEVEL_CURVE[-1][0]


# --- Senaryolar ---------------------------------------------------------------------------------
RARITY_OFFSET = {"common": 0, "rare": 3, "epic": 6, "legendary": 10}   # final: doğrudan açılış seviyesi farkı
RARITY_OFFSET_V2 = {"common": 0, "rare": 3, "epic": 6, "legendary": 12}


def crate_gate(v):
    k = C.CAR[v]
    cid = next((c["id"] for c in C.CRATES if v in [x for x, _ in c["odds"]]), None)
    return C.BY_ID[cid]["level"] if cid else 1


def crate_of(v):
    return next((c["id"] for c in C.CRATES if v in [x for x, _ in c["odds"]]), None)


SCENARIOS = {
    # 1) yalnızca kasa (bugünkü sistem)
    "crate_only": {"direct": False},
    # 2) kasa + doğrudan: katalog fiyatı, eski cars.json seviyesi (Car Town'ın düz "Buy Cars"ı)
    "direct_catalog": {"direct": True, "mult": {"common": 1, "rare": 1, "epic": 1, "legendary": 1},
                       "level": lambda v: C.CAR[v]["min_level"]},
    # 3) aşırı ucuz: katalogun yarısı, eski seviye
    "direct_cheap": {"direct": True, "mult": {"common": .5, "rare": .5, "epic": .5, "legendary": .5},
                     "level": lambda v: C.CAR[v]["min_level"]},
    # 4) pahalı: katalog × 8 herkes için, eski seviye
    "direct_expensive": {"direct": True, "mult": {"common": 8, "rare": 8, "epic": 8, "legendary": 8},
                         "level": lambda v: C.CAR[v]["min_level"]},
    # ARA DENEME v1 (ayar geçmişi): nadirlik çarpanı + seviye farkı + Legendary 10 kasa sadakati
    "ara_v1": {"direct": True, "mult": {"common": 1.0, "rare": 1.5, "epic": 3.0, "legendary": 12.0},
              "level": lambda v: max(C.CAR[v]["min_level"], crate_gate(v)) + RARITY_OFFSET[C.CAR[v]["rarity"]],
              "loyalty": {"legendary": 10}},   # o kasadan en az 10 kasa açmış olmak
    # 5c) final v2: Legendary seviye farkı +12 ve kasa sadakati Epic 5 / Legendary 15 kasa
    "ara_v2": {"direct": True, "mult": {"common": 1.0, "rare": 1.5, "epic": 3.0, "legendary": 12.0},
                 "level": lambda v: max(C.CAR[v]["min_level"], crate_gate(v)) + RARITY_OFFSET_V2[C.CAR[v]["rarity"]],
                 "loyalty": {"epic": 5, "legendary": 15}},
    # 5d) final v3: v2 + Legendary fiyatı geç oyunun ₺ akışına göre (×35: E46 ~3,0 M, E60 ~4,2 M)
    "ara_v3": {"direct": True, "mult": {"common": 1.0, "rare": 1.5, "epic": 3.0, "legendary": 35.0},
                 "level": lambda v: max(C.CAR[v]["min_level"], crate_gate(v)) + RARITY_OFFSET_V2[C.CAR[v]["rarity"]],
                 "loyalty": {"epic": 5, "legendary": 15}},
    # 5e) final v4: Legendary'nin nadirliği ₺ ile değil KASA SADAKATİYLE korunur (o kasadan 30 kasa);
    #     fiyat ×12 (E46 1,02 M · E60 1,44 M) — geç oyunda ₺ fiilen sınırsız olduğu için fiyat koruma değil
    "ara_v4": {"direct": True, "mult": {"common": 1.0, "rare": 1.5, "epic": 3.0, "legendary": 12.0},
                 "level": lambda v: max(C.CAR[v]["min_level"], crate_gate(v)) + RARITY_OFFSET_V2[C.CAR[v]["rarity"]],
                 "loyalty": {"epic": 5, "legendary": 30}},
    # 5) FİNAL ÖNERİ (v5): Legendary doğrudan yolu kasa yolunun kötü şans kuyruğunun ÖTESİNDE (o kasadan 60 kasa;
    #     E46 P90 = 68 SPOR, E60 P90 = 82 PRESTİJ kasası) — şanssız ama sadık oyuncuya garanti yol
    "final": {"direct": True, "mult": {"common": 1.0, "rare": 1.5, "epic": 3.0, "legendary": 12.0},
                 "level": lambda v: max(C.CAR[v]["min_level"], crate_gate(v)) + RARITY_OFFSET_V2[C.CAR[v]["rarity"]],
                 "loyalty": {"epic": 5, "legendary": 60}},
}


def price(sc, v):
    return int(round(C.CAR[v]["price"] * sc["mult"][C.CAR[v]["rarity"]] / 1000.0)) * 1000


def direct_level(sc, v):
    return int(sc["level"](v))


# --- Oyuncu ---------------------------------------------------------------------------------------
PROFILES = {"CASUAL": (20, 2, 30), "ACTIVE": (60, 3, 30), "HEAVY": (150, 3, 30), "10 SAAT (tek gün)": (600, 3, 1)}


def simulate(sc, profile, rng, policy="cheapest"):
    mpd, tasks, days = PROFILES[profile]
    owned = {C.STARTING_VEHICLE}
    earned_g = C.START_GEMS
    spent_g = 0
    story_prev = stars_prev = rep_step = 0
    lv_prev = 1
    paid_ms = set()
    free_crate = True
    week_tasks = 0
    opened = dups = 0
    opened_by = {c["id"]: 0 for c in C.CRATES}
    money = START_MONEY
    upgrades_left = list(UPGRADES)
    spent_upg = spent_cars = spent_decor = 0
    direct_count = crate_new = 0
    income_prev = 0.0
    for day in range(1, days + 1):
        m = mpd * day
        # --- gem kaynakları (crate_sim ile aynı kurallar)
        story = sum(gm for t, gm in C.STORY if t <= m)
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

        def discover(v):
            nonlocal earned_g
            owned.add(v)
            earned_g += C.DISCOVERY_GEMS[C.CAR[v]["rarity"]]
            for th, gm in C.COLLECTION_MILESTONES.items():
                if len(owned) >= th and th not in paid_ms:
                    paid_ms.add(th)
                    earned_g += gm

        # --- gün boyu ₺ geliri, zorunlu yatırımlar önce
        inc = income_at(m)
        money += inc - income_prev
        income_prev = inc
        while upgrades_left and money >= upgrades_left[0]:
            money -= upgrades_left[0]
            spent_upg += upgrades_left.pop(0)

        # --- gem → kasa (bugünkü politika: P(yeni)/fiyat en iyi açık kasa; yeni yoksa açmaz)
        while True:
            crate = C.pick_crate(owned, lv)
            if crate is None:
                break
            cost = C.BY_ID[crate]["price"]
            if free_crate and crate == C.CRATES[0]["id"] and lv >= C.FIRST_CRATE_LEVEL:
                free_crate, cost = False, 0
            elif earned_g - spent_g < cost:
                break
            spent_g += cost
            opened += 1
            opened_by[crate] += 1
            v = C.DRAW.draw(crate, rng)
            if v in owned:
                dups += 1
                earned_g += C.DUP_SCRAP[C.CAR[v]["rarity"]]
            else:
                crate_new += 1
                discover(v)

        # --- ₺ → doğrudan satın alma (zorunlu yatırımlar bittiyse)
        if sc["direct"] and not upgrades_left:
            while True:
                cands = []
                for v in C.CAR:
                    if v in owned or lv < direct_level(sc, v):
                        continue
                    need = sc.get("loyalty", {}).get(C.CAR[v]["rarity"], 0)
                    if need and opened_by.get(crate_of(v), 0) < need:
                        continue
                    cands.append(v)
                if not cands:
                    break
                if policy == "target":      # hedefli oyuncu: en nadir / en pahalı aracı biriktirerek alır
                    v = max(cands, key=lambda x: price(sc, x))
                else:                       # koleksiyoncu: parası yeten en ucuz yeni araç
                    v = min(cands, key=lambda x: price(sc, x))
                if money < price(sc, v):
                    break
                money -= price(sc, v)
                spent_cars += price(sc, v)
                direct_count += 1
                discover(v)
        # --- kalan ₺ → dekor (katalog bitene kadar)
        if not upgrades_left:
            d = min(money, DECOR_TOTAL - spent_decor)
            # dekor yalnızca sıradaki doğrudan araç için biriktirilen para dışındaki kısımdan
            if sc["direct"]:
                nxt = [price(sc, v) for v in C.CAR if v not in owned and lv >= direct_level(sc, v)]
                reserve = min(nxt) if (nxt and policy != "target") else (max(nxt) if nxt else 0)
                d = max(0, min(d, money - reserve))
            money -= d
            spent_decor += d
    gv = sum(C.CAR[v]["price"] for v in owned) + spent_upg + spent_decor
    return {"owned": len(owned), "e60": "bmw_e60" in owned, "e46": "bmw_e46" in owned, "full": len(owned) == C.TOTAL,
            "gv": gv, "spent_money": spent_upg + spent_cars + spent_decor, "spent_cars": spent_cars,
            "spent_decor": spent_decor, "money": money, "gems_spent": spent_g, "crates": opened, "dups": dups,
            "direct": direct_count, "crate_new": crate_new, "lv": lv}


def pct(xs, q):
    xs = sorted(xs)
    return xs[min(int(q * len(xs)), len(xs) - 1)]


def report(name, n, rng, policy):
    sc = SCENARIOS[name]
    print("\n##### SENARYO: %s  (politika: %s, %d oyuncu)" % (name, policy, n))
    print("profil | sv | araç medyan (P10-P90) | E60 | E46 | 16/16 | garaj değeri | ₺ harcama (araç / dekor) | ₺ bakiye | gem harcama | kasa | kopya | kasadan yeni | doğrudan")
    for profile in PROFILES:
        R = [simulate(sc, profile, rng, policy) for _ in range(n)]
        own = [r["owned"] for r in R]
        print("%s | %d | %d (%d-%d) | %.1f%% | %.1f%% | %.1f%% | %.0f | %.0f (%.0f / %.0f) | %.0f | %.0f | %.1f | %.1f | %.2f | %.2f" % (
            profile, R[0]["lv"], pct(own, .5), pct(own, .1), pct(own, .9),
            100 * st.mean(r["e60"] for r in R), 100 * st.mean(r["e46"] for r in R), 100 * st.mean(r["full"] for r in R),
            st.mean(r["gv"] for r in R), st.mean(r["spent_money"] for r in R), st.mean(r["spent_cars"] for r in R),
            st.mean(r["spent_decor"] for r in R), st.mean(r["money"] for r in R), st.mean(r["gems_spent"] for r in R),
            st.mean(r["crates"] for r in R), st.mean(r["dups"] for r in R), st.mean(r["crate_new"] for r in R),
            st.mean(r["direct"] for r in R)))


def price_table():
    sc = SCENARIOS["final"]
    print("\n=== FİNAL FİYAT TABLOSU ===")
    print("araç | sınıf | nadirlik | katalog | kasa | p | kasa: beklenen kasa / gem (ort) | medyan kasa | doğrudan fiyat | doğrudan sv | açılış dk | o andaki ₺/dk | biriktirme dk | kasa sadakati")
    for v in sorted(C.CAR, key=lambda x: C.CAR[x]["price"]):
        cid = crate_of(v)
        p = dict(C.BY_ID[cid]["odds"])[v] if cid else 1.0
        exp_crates = 1 / p if cid else 0
        gem = exp_crates * C.BY_ID[cid]["price"] if cid else 0
        med = math.ceil(math.log(0.5) / math.log(1 - p)) if cid and p < 1 else 1
        lvl = direct_level(sc, v)
        m = minute_for_level(lvl)
        rate = income_rate(m)
        print("%s | %s | %s | %d | %s | %.4f | %.1f / %.0f | %d | %d | %d | %.0f | %.0f | %.0f | %d" % (
            v, C.CAR[v]["class"], C.CAR[v]["rarity"], C.CAR[v]["price"], cid or "başlangıç", p, exp_crates, gem, med,
            price(sc, v), lvl, m, rate, price(sc, v) / max(rate, 1),
            sc.get("loyalty", {}).get(C.CAR[v]["rarity"], 0)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--players", type=int, default=100000)
    ap.add_argument("--scenario", default="all")
    ap.add_argument("--policy", default="cheapest", choices=["cheapest", "target"])
    ap.add_argument("--seed", type=int, default=20260930)
    a = ap.parse_args()
    C.sync_check()
    rng = random.Random(a.seed)
    price_table()
    main_set = ["crate_only", "direct_catalog", "direct_cheap", "direct_expensive", "final"]
    tuning = [k for k in SCENARIOS if k.startswith("ara_")]
    names = main_set if a.scenario == "all" else (tuning if a.scenario == "tuning" else [a.scenario])
    for name in names:
        report(name, a.players, rng, a.policy)


if __name__ == "__main__":
    main()
