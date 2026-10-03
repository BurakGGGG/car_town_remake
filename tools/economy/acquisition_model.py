#!/usr/bin/env python3
"""ARAÇ EDİNİM MODELİ — katalog (gerçek ya da sentetik) + doğrudan satın alma politikası + türetme kuralları.
ANALİZ ARACI; oyun kodu değil. Tasarım: docs/direct_vehicle_purchase_design.md §16 (Future Vehicle Scalability).

Hiçbir yerde araç kimliğine göre kural YOKTUR. Bir aracın doğrudan fiyatı, açılış seviyesi, kasa sadakati,
kasa uygunluğu ve garaj değeri yalnızca şu metadata'dan türetilir:
    rarity, class, base_value (cars.json "price"), progression_level (cars.json "min_level"),
    category (isteğe bağlı), kasa havuzları (crates.json "pool").
Politika: tools/economy/direct_purchase_policy.json (uygulamada vehicles/crates.json'a taşınır).
"""
import json
import math
import os
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
POLICY_PATH = os.path.join(os.path.dirname(__file__), "direct_purchase_policy.json")
RARITY_ORDER = ["common", "rare", "epic", "legendary"]


# --- Politika ---------------------------------------------------------------------------------------

class Policy:
    def __init__(self, data):
        self.data = data
        self.rarity = data["rarity"]
        dp = data["direct_purchase"]
        self.class_mod = dp.get("class_modifier", {"default": 1.0})
        self.category_mod = dp.get("category_modifier", {"default": 1.0})
        self.tuning = float(dp.get("tuning_multiplier", 1.0))
        self.round_to = int(dp.get("round_to", 1000))
        self.rounding = dp.get("rounding", "half_up")
        self.min_level = int(dp.get("min_unlock_level", 1))
        self.max_level = int(dp.get("max_unlock_level", 99))
        self.unknown_rarity = dp.get("unknown_rarity", "not_for_sale")
        self.direct_only_loyalty = dp.get("loyalty_for_direct_only_vehicles", "waived")

    @staticmethod
    def load(path=POLICY_PATH):
        return Policy(json.load(open(path, encoding="utf-8")))

    def variant(self, **changes):
        """Ayar denemesi için kopya: variant(rarity={"legendary": {"loyalty_crates": 30}}, tuning_multiplier=1.2)."""
        d = json.loads(json.dumps(self.data))
        for key, value in changes.items():
            if key == "rarity":
                for r, fields in value.items():
                    d["rarity"].setdefault(r, {}).update(fields)
            else:
                d["direct_purchase"][key] = value
        return Policy(d)

    def _mod(self, table, key):
        return float(table.get(key, table.get("default", 1.0)))

    def round_price(self, x):
        step = self.round_to
        if self.rounding == "half_up":
            return int(math.floor(x / step + 0.5)) * step
        if self.rounding == "up":
            return int(math.ceil(x / step)) * step
        return int(math.floor(x / step)) * step


# --- Katalog ----------------------------------------------------------------------------------------

class Catalog:
    """cars: id → {class, rarity, base_value, progression_level, category}
       crates: [{id, price, level, pool: [ids]}];  weights: rarity → kasa ağırlığı;  starters: [ids]"""

    def __init__(self, cars, crates, weights, starters, name=""):
        self.cars, self.crates, self.weights, self.starters, self.name = cars, crates, weights, starters, name
        self.crates_of = {v: [] for v in cars}
        for c in crates:
            for v in c["pool"]:
                if v in self.crates_of:
                    self.crates_of[v].append(c["id"])
        self.by_id = {c["id"]: c for c in crates}
        for c in crates:
            tot = sum(weights.get(cars[v]["rarity"], 0) for v in c["pool"])
            c["odds"] = [(v, weights.get(cars[v]["rarity"], 0) / tot) for v in c["pool"]] if tot > 0 else []

    @staticmethod
    def load_real(starters=None):
        """Başlangıç aracı: cars.json'da "starter": true olanlar; yoksa oyunun başlangıç aracı sabiti (crate_sim)."""
        cars_raw = json.load(open(os.path.join(ROOT, "vehicles", "cars.json"), encoding="utf-8"))["cars"]
        crates_doc = json.load(open(os.path.join(ROOT, "vehicles", "crates.json"), encoding="utf-8"))
        cars = {c["id"]: {"class": c.get("class", ""), "rarity": c.get("rarity", "common"), "base_value": int(c["price"]),
                          "progression_level": int(c.get("min_level", 1)), "category": c.get("category", "")}
                for c in cars_raw}
        crates = [{"id": c["id"], "price": int(c["price_gems"]), "level": int(c["min_level"]),
                   "pool": [v for v in c["pool"] if v in cars]} for c in crates_doc["crates"]]
        weights = {r["id"]: float(r["weight"]) for r in crates_doc["rarities"]}
        if starters is None:
            starters = [c["id"] for c in cars_raw if c.get("starter")]
            if not starters:
                import crate_sim
                starters = [crate_sim.STARTING_VEHICLE]
        return Catalog(cars, crates, weights, list(starters), "gerçek (%d araç)" % len(cars))


# --- Türetme (araç kimliği YOK) ------------------------------------------------------------------------

def crate_gate(cat, v):
    gates = [cat.by_id[c]["level"] for c in cat.crates_of[v]]
    return min(gates) if gates else None


def is_for_sale(pol, cat, v):
    return cat.cars[v]["rarity"] in pol.rarity and v not in cat.starters


def direct_price(pol, cat, v):
    car = cat.cars[v]
    r = pol.rarity.get(car["rarity"])
    if r is None:
        return None
    raw = car["base_value"] * float(r["price_multiplier"]) * pol._mod(pol.class_mod, car["class"]) \
        * pol._mod(pol.category_mod, car.get("category", "")) * pol.tuning
    return max(pol.round_price(raw), pol.round_to)


def direct_level(pol, cat, v):
    car = cat.cars[v]
    r = pol.rarity.get(car["rarity"])
    if r is None:
        return None
    gate = crate_gate(cat, v) or 1
    return max(pol.min_level, min(pol.max_level, max(car["progression_level"], gate) + int(r["level_offset"])))


def loyalty(pol, cat, v):
    """(kasa id'leri, gereken açılış sayısı). Kasada olmayan araçta politika gereği 0."""
    r = pol.rarity.get(cat.cars[v]["rarity"])
    if r is None:
        return ([], 0)
    crates = cat.crates_of[v]
    need = int(r["loyalty_crates"])
    tail = float(r.get("loyalty_tail", 0) or 0)
    if tail > 0 and crates:
        # kasa yolu kuyruğu: oyuncuların 'tail' kadarı aracı kasadan bulmuş olduğunda doğrudan yol açılır
        p = max(dict(cat.by_id[c]["odds"]).get(v, 0) for c in crates)
        if 0 < p < 1:
            need = max(need, int(math.ceil(math.log(1 - tail) / math.log(1 - p) - 1e-9)))
    if not crates:
        # Yalnızca doğrudan satılan araç. "waived" sadakati kaldırır: 50 araçlık sentetik katalogda tek bir kasasız
        # Legendary, ACTIVE Legendary payını %5,7 → %24,8'e çıkardı. "any_crate" tüm kasaların toplamını sayar: ACTIVE
        # düzeldi ama HEAVY toplam 60 kasayı aşıp yine aldı (%28,2). Önerilen "error": validate() ERROR verir (katalog
        # kuralı: sadakatli nadirlik bir kasada olmalı), yanlışlıkla yayınlanırsa yine tüm kasaların toplamı sayılır.
        if pol.direct_only_loyalty == "waived":
            return ([], 0)
        return ([c["id"] for c in cat.crates], need)
    return (crates, need)


def garage_value(cat, v):
    """Garaj değerine yazılan: katalog (base) değeri — hangi yoldan gelirse gelsin, ödenen fiyat değil."""
    return cat.cars[v]["base_value"]


def derive_all(pol, cat):
    out = {}
    for v in cat.cars:
        crates, need = loyalty(pol, cat, v)
        out[v] = {"for_sale": is_for_sale(pol, cat, v), "price": direct_price(pol, cat, v),
                  "level": direct_level(pol, cat, v), "loyalty_crates": crates, "loyalty": need,
                  "crate_eligible": bool(cat.crates_of[v]), "garage_value": garage_value(cat, v)}
    return out


def validate(pol, cat):
    """Metadata sorunları: (önem, mesaj). ERROR = satışa çıkamaz / kopuk; WARN = tasarım riski."""
    issues = []
    for v, car in cat.cars.items():
        if car["rarity"] not in pol.rarity:
            issues.append(("ERROR", "%s: nadirlik '%s' politikada yok → satışa çıkmaz" % (v, car["rarity"])))
        if car["rarity"] not in cat.weights and cat.crates_of[v]:
            issues.append(("ERROR", "%s: nadirlik '%s' kasa ağırlığı yok → kasadan çıkamaz" % (v, car["rarity"])))
        if car["base_value"] <= 0:
            issues.append(("ERROR", "%s: base_value ≤ 0" % v))
        if not cat.crates_of[v] and v not in cat.starters and car["rarity"] in pol.rarity \
                and int(pol.rarity[car["rarity"]]["loyalty_crates"]) > 0:
            sev = "ERROR" if pol.direct_only_loyalty == "error" else "WARN"
            issues.append((sev, "%s: %s araç hiçbir kasada değil → sadakat %s" % (v, car["rarity"],
                          "KALKAR (yalnızca fiyat + seviye korur)" if pol.direct_only_loyalty == "waived"
                          else "tüm kasalardan açılan toplamla ölçülür; sadakatli nadirlik bir kasa havuzuna eklenmeli")))
        if not cat.crates_of[v] and v not in cat.starters and car["rarity"] not in pol.rarity:
            issues.append(("ERROR", "%s: ne kasada ne satışta → koleksiyonda ulaşılamaz" % v))
        if car["class"] not in pol.class_mod and "default" not in pol.class_mod:
            issues.append(("WARN", "%s: sınıf '%s' için çarpan yok" % (v, car["class"])))
    # politika tutarlılığı: kasada daha nadir olan (ağırlığı düşük) nadirlik daha kolay / ucuz olamaz
    ranked = sorted([r for r in pol.rarity if r in cat.weights], key=lambda r: -cat.weights[r])
    for a, b in zip(ranked, ranked[1:]):
        for field in ("price_multiplier", "level_offset", "loyalty_crates", "loyalty_tail"):
            if float(pol.rarity[b].get(field, 0) or 0) < float(pol.rarity[a].get(field, 0) or 0):
                issues.append(("ERROR", "politika: '%s' (%s) '%s'den daha nadir ama %s daha düşük" % (b, cat.weights[b], a, field)))
    for c in cat.crates:
        s = sum(p for _, p in c["odds"])
        if c["pool"] and abs(s - 1.0) > 1e-9:
            issues.append(("ERROR", "%s: oran toplamı %.6f" % (c["id"], s)))
    return issues


# --- Sentetik katalog ------------------------------------------------------------------------------------

CLASS_BANDS = {  # sınıf → (ilerleme seviyesi aralığı, base value aralığı)
    "D": ((1, 6), (12000, 25000)),
    "C": ((4, 14), (28000, 50000)),
    "B": ((10, 24), (50000, 85000)),
    "A": ((18, 32), (90000, 150000)),
    "S": ((26, 36), (150000, 260000)),   # mevcut kadroda olmayan, ileride gelebilecek sınıf
}
CATEGORIES = ["sedan", "hatchback", "suv", "sport", "classic", "pickup"]


def synthetic(n, seed=1, rarity_mix=None, class_mix=None, crate_size=(4, 7), direct_only_share=0.05,
              extra_rarities=None, weights=None):
    """n araçlık sentetik katalog. Kasa havuzları ilerleme seviyesine göre sıralı gruplardır; kasa kapısı
    havuzun en düşük seviyesi, gem fiyatı 30 + 4,5 × kapı (mevcut 4 kasaya uyum: 1→30, 10→75, 14→93, 20→120)."""
    rng = random.Random(seed)
    rarity_mix = rarity_mix or {"common": 0.45, "rare": 0.28, "epic": 0.18, "legendary": 0.09}
    class_mix = class_mix or {"D": 0.12, "C": 0.25, "B": 0.36, "A": 0.22, "S": 0.05}
    weights = dict(weights or {"common": 100, "rare": 40, "epic": 15, "legendary": 4})
    if extra_rarities:
        weights.update(extra_rarities)
    rar_ids, rar_w = list(rarity_mix), list(rarity_mix.values())
    cls_ids, cls_w = list(class_mix), list(class_mix.values())
    cars = {"syn_starter": {"class": "D", "rarity": "common", "base_value": 15000, "progression_level": 1, "category": "sedan"}}
    for i in range(n - 1):
        k = rng.choices(cls_ids, cls_w)[0]
        (l0, l1), (b0, b1) = CLASS_BANDS[k]
        lvl = rng.randint(l0, l1)
        base = int(round((b0 + (b1 - b0) * (lvl - l0) / max(l1 - l0, 1) * rng.uniform(0.7, 1.0)) / 1000.0)) * 1000
        cars["syn_%03d" % i] = {"class": k, "rarity": rng.choices(rar_ids, rar_w)[0], "base_value": base,
                                "progression_level": lvl, "category": rng.choice(CATEGORIES)}
    pool_ids = [v for v in cars if v != "syn_starter"]
    no_loyalty = [v for v in pool_ids if cars[v]["rarity"] in ("common", "rare")]
    direct_only = set(rng.sample(no_loyalty, min(len(no_loyalty), int(len(pool_ids) * direct_only_share))))
    in_crates = sorted([v for v in pool_ids if v not in direct_only], key=lambda v: cars[v]["progression_level"])
    crates, i, ci = [], 0, 0
    while i < len(in_crates):
        size = rng.randint(*crate_size)
        pool = in_crates[i:i + size]
        if len(pool) < crate_size[0] and crates:
            crates[-1]["pool"] += pool
            break
        gate = max(1, min(cars[v]["progression_level"] for v in pool))
        crates.append({"id": "syn_crate_%02d" % ci, "price": int(30 + 4.5 * (gate - 1)), "level": gate, "pool": pool})
        i += size
        ci += 1
    return Catalog(cars, crates, weights, ["syn_starter"], "sentetik %d araç (tohum %d)" % (n, seed))


if __name__ == "__main__":
    pol, cat = Policy.load(), Catalog.load_real()
    d = derive_all(pol, cat)
    print("araç | nadirlik | sınıf | base | doğrudan ₺ | sv | sadakat | kasa")
    for v in sorted(cat.cars, key=lambda x: cat.cars[x]["base_value"]):
        r = d[v]
        print("%s | %s | %s | %d | %s | %s | %s | %s" % (v, cat.cars[v]["rarity"], cat.cars[v]["class"], r["garage_value"],
              r["price"] if r["for_sale"] else "başlangıç", r["level"] if r["for_sale"] else "-",
              "%d %s" % (r["loyalty"], "/".join(r["loyalty_crates"])) if r["loyalty"] else "-", "/".join(cat.crates_of[v]) or "-"))
    print("doğrulama:", validate(pol, cat) or "sorun yok")
