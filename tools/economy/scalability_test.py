#!/usr/bin/env python3
"""DOĞRUDAN SATIN ALMA ÖLÇEKLENEBİLİRLİK TESTİ — 16 gerçek + 20/50/100/200 sentetik araç, farklı dağılımlar.
ANALİZ ARACI; oyun kodu değil. Tasarım: docs/direct_vehicle_purchase_design.md §16.

Kontrol edilenler (her katalog × dağılım × tohum):
  fiyat üretimi · açılış üretimi · sadakat · garaj değeri · koleksiyon (erişilebilirlik + kilometre taşları) · kasa havuzu oranları
  + yeni araç ekleme örnekleri + yeni nadirlik örneği + "kodda araç kimliği yok" taraması + performans.
Çıkış kodu: hata varsa 1.

  python3 tools/economy/scalability_test.py
"""
import math
import os
import random
import re
import sys
import time

import acquisition_model as M
import acquisition_sim as S

FAILS = []
CHECKS = [0]


def check(cond, msg):
    CHECKS[0] += 1
    if not cond:
        FAILS.append(msg)


EXPECTED_16 = {  # §5 tablosu (Kamiq: yarım-yukarı yuvarlama 82.500 → 83.000)
    "renault_toros": (60000, 9, 5), "hyundai_era": (45000, 9, 0), "hyundai_getz": (35000, 8, 0),
    "hyundai_accent_blue": (38000, 8, 0), "ford_focus": (68000, 13, 0), "vw_passat_b55": (50000, 12, 0),
    "skoda_kamiq": (83000, 15, 0), "renault_fluence": (60000, 15, 0), "vw_golf_7": (195000, 21, 5),
    "seat_leon": (68000, 16, 0), "honda_civic": (216000, 24, 5), "bmw_e46": (1020000, 26, 60),
    "audi_a3": (95000, 20, 0), "volvo_s60": (158000, 25, 0), "bmw_e60": (1440000, 37, 73),   # E60: kuyruk kuralı 60 → 73
}

MIXES = {
    "varsayılan": {},
    "legendary-ağır": {"rarity_mix": {"common": 0.25, "rare": 0.25, "epic": 0.25, "legendary": 0.25}},
    "common-ağır": {"rarity_mix": {"common": 0.75, "rare": 0.15, "epic": 0.08, "legendary": 0.02}},
    "üst-sınıf": {"class_mix": {"B": 0.2, "A": 0.5, "S": 0.3}},
    "büyük-kasalar": {"crate_size": (10, 16)},
    "tek-araçlı-kasalar": {"crate_size": (1, 2), "direct_only_share": 0.0},
    "çok-doğrudan-özel": {"direct_only_share": 0.30},
    "yeni-nadirlik(mythic)": {"rarity_mix": {"common": 0.4, "rare": 0.3, "epic": 0.15, "legendary": 0.1, "mythic": 0.05},
                              "extra_rarities": {"mythic": 1}},
}


def invariants(pol, cat, label):
    d = M.derive_all(pol, cat)
    rank = {r: i for i, r in enumerate(pol.rarity)}
    for v, car in cat.cars.items():
        r = d[v]
        known = car["rarity"] in pol.rarity
        if v in cat.starters:
            check(not r["for_sale"], "%s %s: başlangıç aracı satışta" % (label, v))
            continue
        if not known:
            check(not r["for_sale"] and r["price"] is None, "%s %s: bilinmeyen nadirlik satışa çıktı" % (label, v))
            continue
        # fiyat
        check(isinstance(r["price"], int) and r["price"] > 0 and r["price"] % pol.round_to == 0,
              "%s %s: fiyat geçersiz %r" % (label, v, r["price"]))
        mult = float(pol.rarity[car["rarity"]]["price_multiplier"]) * pol.tuning
        exact = car["base_value"] * mult
        check(abs(r["price"] - exact) <= pol.round_to / 2 + 1e-6 or r["price"] == pol.round_to,
              "%s %s: fiyat formülden sapıyor %d / %.0f" % (label, v, r["price"], exact))
        # açılış
        check(pol.min_level <= r["level"] <= pol.max_level, "%s %s: seviye aralık dışı %d" % (label, v, r["level"]))
        gate = M.crate_gate(cat, v)
        if gate is not None:
            check(r["level"] >= gate, "%s %s: doğrudan yol kasasından önce açılıyor (%d < %d)" % (label, v, r["level"], gate))
        check(r["level"] >= car["progression_level"], "%s %s: seviye ilerleme seviyesinin altında" % (label, v))
        # sadakat
        need = int(pol.rarity[car["rarity"]]["loyalty_crates"])
        tail = float(pol.rarity[car["rarity"]].get("loyalty_tail", 0) or 0)
        if cat.crates_of[v]:
            check(r["loyalty"] >= need and r["loyalty_crates"] == cat.crates_of[v], "%s %s: sadakat yanlış" % (label, v))
            if tail > 0:
                p = max(dict(cat.by_id[c]["odds"])[v] for c in cat.crates_of[v])
                found = 1 - (1 - p) ** r["loyalty"]
                check(found >= tail - 1e-9 or r["loyalty"] == need,
                      "%s %s: sadakat kuyruğun altında (%d kasada bulma %.3f < %.2f)" % (label, v, r["loyalty"], found, tail))
        elif need == 0:
            check(r["loyalty"] == 0, "%s %s: sadakatsiz nadirlikte sadakat" % (label, v))
        elif pol.direct_only_loyalty == "waived":
            check(r["loyalty"] == 0, "%s %s: kasasız araçta sadakat kalkmalıydı" % (label, v))
        else:
            check(r["loyalty"] >= need and len(r["loyalty_crates"]) == len(cat.crates),
                  "%s %s: kasasız araçta sadakat tüm kasalarla ölçülmeli" % (label, v))
        # garaj değeri: katalog değeri, ödenen fiyat değil
        check(r["garage_value"] == car["base_value"], "%s %s: garaj değeri ödenen fiyata bağlı" % (label, v))
        # koleksiyon: erişilebilir
        check(r["for_sale"] or r["crate_eligible"], "%s %s: araca ulaşılamıyor" % (label, v))
    # nadirlik monotonluğu: aynı araç daha nadir olsaydı fiyatı / seviyesi / sadakati düşmezdi
    for v, car in list(cat.cars.items())[:40]:
        if car["rarity"] not in pol.rarity or v in cat.starters:
            continue
        original = car["rarity"]
        prev = None
        for rr in sorted(pol.rarity, key=lambda x: rank[x]):
            cat.cars[v]["rarity"] = rr
            cur = (M.direct_price(pol, cat, v), M.direct_level(pol, cat, v), M.loyalty(pol, cat, v)[1])
            if prev:
                check(all(c >= p for c, p in zip(cur, prev)), "%s %s: %s nadirliğinde değer düştü %r < %r" % (label, v, rr, cur, prev))
            prev = cur
        cat.cars[v]["rarity"] = original
    # kasa havuzu: oran = ağırlık / havuz toplamı; toplam 1; sahiplikten bağımsız (yalnızca ağırlık)
    for c in cat.crates:
        if not c["odds"]:
            continue
        tot = sum(cat.weights.get(cat.cars[v]["rarity"], 0) for v in c["pool"])
        for v, p in c["odds"]:
            check(abs(p - cat.weights.get(cat.cars[v]["rarity"], 0) / tot) < 1e-12, "%s %s: oran yanlış" % (label, c["id"]))
        check(abs(sum(p for _, p in c["odds"]) - 1) < 1e-9, "%s %s: oran toplamı ≠ 1" % (label, c["id"]))
    # koleksiyon kilometre taşları katalog büyüklüğüne oranlı, artan, sonuncusu = tam koleksiyon
    ms = sorted(S.milestones(len(cat.cars)))
    check(ms == sorted(set(ms)) and ms[-1] == len(cat.cars), "%s: kilometre taşları bozuk %r" % (label, ms))
    return d


def snapshot_all(pol, cat):
    """Yeni araç eklemeden önceki ve sonraki türetilmiş değerleri karşılaştırmak için."""
    return {v: (r["price"], r["level"], r["loyalty"], r["garage_value"]) for v, r in M.derive_all(pol, cat).items()}


def add_vehicle_example(pol, title, vid, meta, crate_id):
    cat = M.Catalog.load_real()
    before = snapshot_all(pol, cat)
    odds_before = dict(cat.by_id[crate_id]["odds"])
    cars = dict(cat.cars)
    cars[vid] = meta
    crates = [dict(c, pool=list(c["pool"]) + ([vid] if c["id"] == crate_id else [])) for c in cat.crates]
    cat2 = M.Catalog(cars, crates, cat.weights, cat.starters, "16 + 1")
    after = snapshot_all(pol, cat2)
    d = M.derive_all(pol, cat2)[vid]
    unchanged = all(after[v][0] == before[v][0] and after[v][1] == before[v][1] and after[v][3] == before[v][3] for v in before)
    check(unchanged, "%s: mevcut araçların fiyat / seviye / garaj değeri değişti" % title)
    moved = {v: (before[v][2], after[v][2]) for v in before if after[v][2] != before[v][2]}
    for v, (a, b) in moved.items():
        check(crate_id in cat.crates_of[v] and b > a and float(pol.rarity[cat.cars[v]["rarity"]].get("loyalty_tail", 0) or 0) > 0,
              "%s: %s sadakati beklenmedik biçimde değişti %d → %d" % (title, v, a, b))
    check(not M.validate(pol, cat2) or all(i[0] == "WARN" for i in M.validate(pol, cat2)), "%s: doğrulama hatası" % title)
    odds_after = dict(cat2.by_id[crate_id]["odds"])
    print("\n--- %s" % title)
    print("metadata: %s · kasa havuzu: %s" % (meta, crate_id))
    print("türetilen: doğrudan %s ₺ · sv %d · sadakat %s · kasadan p %.2f%% · garaj değeri +%d · mevcut 16 aracın değerleri %s"
          % ("{:,}".format(d["price"]).replace(",", "."), d["level"],
             "%d %s" % (d["loyalty"], crate_id) if d["loyalty"] else "yok", 100 * odds_after[vid], d["garage_value"],
             "fiyat / seviye / garaj değeri AYNI" if unchanged else "DEĞİŞTİ"))
    if moved:
        print("kuyruk sadakati otomatik güncellendi (havuz büyüdü, oran düştü): %s"
              % ", ".join("%s %d → %d kasa" % (v, a, b) for v, (a, b) in moved.items()))
    shifts = ", ".join("%s %.1f→%.1f%%" % (v, 100 * odds_before[v], 100 * odds_after[v]) for v in odds_before)
    print("aynı kasadaki diğer araçların oranı (havuz büyüdüğü için doğal sulanma): %s" % shifts)
    return d


def id_scan():
    """Ekonomi kodunda gerçek araç kimliği geçmemeli (yalnızca raporlama / test beklentileri hariç)."""
    real = list(M.Catalog.load_real().cars)
    src = open(os.path.join(os.path.dirname(__file__), "acquisition_model.py"), encoding="utf-8").read()
    pol = open(M.POLICY_PATH, encoding="utf-8").read()
    hits = [v for v in real if re.search(r"\b%s\b" % re.escape(v), src)]
    hits_pol = [v for v in real if v in pol]
    check(not hits, "acquisition_model.py araç kimliği içeriyor: %s" % hits)
    check(not hits_pol, "politika dosyası araç kimliği içeriyor: %s" % hits_pol)
    print("kimlik taraması: acquisition_model.py → %s · direct_purchase_policy.json → %s"
          % ("temiz" if not hits else hits, "temiz" if not hits_pol else hits_pol))


def main():
    pol = M.Policy.load()
    print("=== 1) 16 GERÇEK ARAÇ: formül §5 tablosunu üretiyor mu")
    real = M.Catalog.load_real()
    d = invariants(pol, real, "gerçek16")
    for v, (p, lv, ly) in EXPECTED_16.items():
        check((d[v]["price"], d[v]["level"], d[v]["loyalty"]) == (p, lv, ly),
              "gerçek16 %s: %r ≠ beklenen %r" % (v, (d[v]["price"], d[v]["level"], d[v]["loyalty"]), (p, lv, ly)))
    print("16 araç: %d/15 satılabilir araç beklenen fiyat / seviye / sadakatle aynı" %
          sum((d[v]["price"], d[v]["level"], d[v]["loyalty"]) == e for v, e in EXPECTED_16.items()))

    print("\n=== 2) SENTETİK KATALOGLAR (değişmezler)")
    print("katalog | dağılım | tohum | kasa | nadirlik | ERROR | WARN | türetme ms | doğrulama ms")
    for n in (20, 50, 100, 200):
        for mix, kw in MIXES.items():
            for seed in (1, 2, 3):
                cat = M.synthetic(n, seed=seed * 7 + n, **kw)
                pol_m = pol if "mythic" not in mix else pol   # mythic politikada YOK → satışa çıkmamalı
                t0 = time.perf_counter()
                for _ in range(20):
                    M.derive_all(pol_m, cat)
                t_der = (time.perf_counter() - t0) / 20 * 1000
                t0 = time.perf_counter()
                issues = M.validate(pol_m, cat)
                t_val = (time.perf_counter() - t0) * 1000
                invariants(pol_m, cat, "%d/%s/%d" % (n, mix, seed))
                rc = {}
                for v in cat.cars.values():
                    rc[v["rarity"][0].upper()] = rc.get(v["rarity"][0].upper(), 0) + 1
                errs = [i for i in issues if i[0] == "ERROR"]
                if "mythic" in mix:
                    # mythic satılık değil ama kasada var → ulaşılabilir; kasada olmayan mythic → ERROR beklenir
                    myth = {v for v, c in cat.cars.items() if c["rarity"] == "mythic"}
                    check(all(m.split(":")[0] in myth for _, m in errs), "%d/%s: beklenmeyen hata %r" % (n, mix, errs[:2]))
                else:
                    check(not errs, "%d/%s/%d: doğrulama hatası %r" % (n, mix, seed, errs[:2]))
                if seed == 1:
                    print("%d | %s | %d | %d | %s | %d | %d | %.2f | %.2f" % (n, mix, seed, len(cat.crates),
                          " ".join("%s%d" % kv for kv in sorted(rc.items())), len(errs), len(issues) - len(errs), t_der, t_val))

    print("\n=== 3) YENİ NADİRLİK: 'mythic' politikaya eklenince")
    cat = M.synthetic(100, seed=99, rarity_mix={"common": 0.4, "rare": 0.3, "epic": 0.15, "legendary": 0.1, "mythic": 0.05},
                      extra_rarities={"mythic": 1})
    myth = [v for v, c in cat.cars.items() if c["rarity"] == "mythic"]
    before = sum(M.derive_all(pol, cat)[v]["for_sale"] for v in myth)
    bad = pol.variant(rarity={"mythic": {"price_multiplier": 30.0, "level_offset": 16, "loyalty_crates": 100}})
    bad_err = [m for sev, m in M.validate(bad, cat) if sev == "ERROR" and m.startswith("politika")]
    check(any("loyalty_tail" in m for m in bad_err), "tutarsız mythic politikası (kuyruk yok) yakalanmadı")
    print("tutarsız satır (loyalty_tail yok) → doğrulama: %s" % bad_err[0])
    pol2 = pol.variant(rarity={"mythic": {"price_multiplier": 30.0, "level_offset": 16, "loyalty_crates": 100, "loyalty_tail": 0.93}})
    check(not [m for sev, m in M.validate(pol2, cat) if sev == "ERROR" and m.startswith("politika")], "tutarlı mythic politikası reddedildi")
    d2 = M.derive_all(pol2, cat)
    after = sum(d2[v]["for_sale"] for v in myth)
    invariants(pol2, cat, "mythic-eklendi")
    check(before == 0 and after == len(myth), "mythic: politika satırı eklenince satışa çıkmadı")
    ex = myth[0]
    print("%d mythic araç · politika satırı yokken satılık %d · satır eklenince %d · örnek %s: base %d → %d ₺, sv %d, sadakat %d"
          % (len(myth), before, after, ex, cat.cars[ex]["base_value"], d2[ex]["price"], d2[ex]["level"], d2[ex]["loyalty"]))

    print("\n=== 3b) KATALOG KURALI: kasasız Legendary")
    cat = M.Catalog.load_real()
    cars = dict(cat.cars)
    cars["orphan_legendary"] = {"class": "A", "rarity": "legendary", "base_value": 140000, "progression_level": 28, "category": "sport"}
    cat3 = M.Catalog(cars, [dict(c) for c in cat.crates], cat.weights, cat.starters, "16 + kasasız")
    errs = [m for sev, m in M.validate(pol, cat3) if sev == "ERROR"]
    d3 = M.derive_all(pol, cat3)["orphan_legendary"]
    check(any(m.startswith("orphan_legendary") for m in errs), "kasasız Legendary ERROR vermedi")
    check(d3["loyalty"] >= 60 and len(d3["loyalty_crates"]) == len(cat3.crates), "kasasız Legendary sadakati tüm kasalarla ölçülmedi")
    print("doğrulama: %s · yine de yayınlanırsa sadakat: %d kasa, %d kasanın toplamı" % (errs[0], d3["loyalty"], len(d3["loyalty_crates"])))

    print("\n=== 4) YENİ ARAÇ EKLEME ÖRNEKLERİ (gerçek kataloğa yalnızca metadata)")
    add_vehicle_example(pol, "Örnek 1: yeni B sınıfı, Rare, spor araç",
                        "new_b_rare_sport", {"class": "B", "rarity": "rare", "base_value": 70000, "progression_level": 17,
                                             "category": "sport"}, "sport_crate")
    add_vehicle_example(pol, "Örnek 2: yeni A sınıfı, Legendary araç",
                        "new_a_legendary", {"class": "A", "rarity": "legendary", "base_value": 130000,
                                            "progression_level": 26, "category": "sedan"}, "prestige_crate")

    print("\n=== 5) KİMLİK TARAMASI")
    id_scan()

    print("\n=== 6) PERFORMANS")
    for n in (16, 20, 50, 100, 200):
        cat = M.Catalog.load_real() if n == 16 else M.synthetic(n, seed=n)
        t0 = time.perf_counter()
        for _ in range(200):
            M.derive_all(pol, cat)
        t_der = (time.perf_counter() - t0) / 200 * 1000
        P = S.Prepared(cat, pol, True)
        rng = random.Random(1)
        k = 400
        t0 = time.perf_counter()
        R = [S.simulate(P, "HEAVY", rng) for _ in range(k)]
        t_sim = (time.perf_counter() - t0) / k * 1000
        check(all(r["owned"] <= n for r in R), "%d: sahiplik katalogdan büyük" % n)
        check(all(r["crate_new"] + r["direct"] + 1 == r["owned"] for r in R), "%d: edinim muhasebesi tutmuyor" % n)
        print("%d araç · türetme (tüm katalog) %.2f ms · 30 gün HEAVY oyuncu %.2f ms · 100.000 oyuncu tek çekirdek ≈ %.0f sn"
              % (n, t_der, t_sim, t_sim * 100))

    print("\n=== SONUÇ: %d kontrol, %d hata" % (CHECKS[0], len(FAILS)))
    for f in FAILS[:30]:
        print("  HATA:", f)
    sys.exit(1 if FAILS else 0)


if __name__ == "__main__":
    main()
