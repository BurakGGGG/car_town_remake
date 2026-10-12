#!/usr/bin/env python3
"""RESTORASYON (klasik) araçlarının vehicles/cars.json kayıtlarını üretir / günceller.

Veri kaynağı bu dosyadaki CARS tablosu (gerçek fabrika verisi). Kurallar (kullanıcı kararları 2026-10-11,
bkz. docs/HURDALIK_ARASTIRMA.md): trafikte dolaşmaz, kasada yoktur, satılabilir ama düşük fiyata
(fiyat × VehicleOwnership.SELL_RATIO 0,4 = satış: temel 10.000 ₺, usta 25.000 ₺).
default_color boya maskesi aracının ölçtüğü renktir (--colors renkler.txt "id #RRGGBB" satırları).
class burada geçicidir: tools/bake_race_specs.gd sonrası 300 m süresinden atanır (--classes dosyası).

  python3 tools/junkyard/klasik_catalog.py [--colors f] [--classes f]
"""
import json, os, sys

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
PRICE = {"basic": 25000, "classic": 62500, "race": 62500}
# id: (marka, model, yıl, kademe, kategori, varyant, motor, hp, 0-100, son hız, çekiş, (boy, en, yükseklik, dingil), tepki, tutuş)
CARS = {
 "tofas_murat_124": ("TOFAŞ", "MURAT 124", 1971, "basic", "sedan", "Tofaş Murat 124", "1.2", 60, 16.5, 145, "RWD", (4.03, 1.61, 1.42, 2.42), 45, 42),
 "anadol_a1": ("ANADOL", "A1", 1967, "basic", "sedan", "Anadol A1", "1.2", 53, 20.0, 130, "RWD", (4.20, 1.57, 1.41, 2.41), 44, 40),
 "vw_beetle_1967": ("VOLKSWAGEN", "BEETLE", 1967, "basic", "coupe", "Volkswagen Beetle 1500", "1.5", 53, 20.0, 125, "RWD", (4.08, 1.54, 1.50, 2.40), 44, 40),
 "fiat_500_1965": ("FIAT", "500", 1965, "basic", "hatchback", "Fiat Nuova 500 D", "0.5", 18, 35.0, 95, "RWD", (2.97, 1.32, 1.33, 1.84), 42, 38),
 "tofas_murat_131": ("TOFAŞ", "MURAT 131", 1979, "basic", "sedan", "Tofaş Murat 131", "1.6", 75, 14.0, 155, "RWD", (4.23, 1.65, 1.40, 2.49), 46, 44),
 "mini_cooper_1965": ("MINI", "COOPER", 1965, "basic", "hatchback", "Mini Cooper 998", "1.0", 55, 14.8, 145, "FWD", (3.05, 1.41, 1.35, 2.04), 50, 52),
 "willys_jeep_mb": ("WILLYS", "JEEP MB", 1944, "basic", "suv", "Willys MB", "2.2", 60, 30.0, 105, "AWD", (3.36, 1.57, 1.77, 2.03), 42, 46),
 "peugeot_404": ("PEUGEOT", "404", 1968, "basic", "sedan", "Peugeot 404", "1.6", 72, 17.0, 145, "RWD", (4.44, 1.62, 1.45, 2.65), 45, 42),
 "mercedes_w123": ("MERCEDES-BENZ", "W123", 1980, "basic", "sedan", "Mercedes-Benz 240 D", "2.4 Dizel", 72, 22.0, 143, "RWD", (4.73, 1.79, 1.44, 2.80), 44, 44),
 "vw_t1_bus": ("VOLKSWAGEN", "T1", 1965, "basic", "van", "Volkswagen T1 1500", "1.5", 44, 40.0, 105, "RWD", (4.28, 1.75, 1.94, 2.40), 42, 40),
 "land_rover_series3": ("LAND ROVER", "SERIES III", 1975, "basic", "suv", "Land Rover Series III 88", "2.25", 70, 29.0, 110, "AWD", (3.62, 1.68, 1.97, 2.24), 42, 46),
 "chevrolet_bel_air_1956": ("CHEVROLET", "BEL AIR", 1956, "basic", "sedan", "Chevrolet Bel Air 265 V8", "4.3 V8", 162, 12.0, 165, "RWD", (5.04, 1.88, 1.53, 2.92), 46, 42),
 "ford_mustang_1967": ("FORD", "MUSTANG", 1967, "classic", "coupe", "Ford Mustang Fastback GT 390", "6.4 V8", 320, 7.4, 195, "RWD", (4.61, 1.80, 1.31, 2.74), 60, 55),
 "chevrolet_corvette_c2": ("CHEVROLET", "CORVETTE C2", 1963, "classic", "coupe", "Chevrolet Corvette Sting Ray 327", "5.4 V8", 360, 6.3, 225, "RWD", (4.45, 1.77, 1.26, 2.49), 62, 58),
 "jaguar_e_type": ("JAGUAR", "E-TYPE", 1961, "classic", "coupe", "Jaguar E-Type 3.8", "3.8", 265, 7.1, 241, "RWD", (4.45, 1.66, 1.22, 2.44), 60, 58),
 "aston_martin_db5": ("ASTON MARTIN", "DB5", 1964, "classic", "coupe", "Aston Martin DB5", "4.0", 282, 8.0, 233, "RWD", (4.57, 1.68, 1.34, 2.49), 60, 58),
 "dodge_charger_1970": ("DODGE", "CHARGER", 1970, "classic", "coupe", "Dodge Charger R/T 440", "7.2 V8", 375, 6.7, 210, "RWD", (5.28, 1.95, 1.35, 2.97), 62, 55),
 "porsche_911_1973": ("PORSCHE", "911 CARRERA RS", 1973, "classic", "coupe", "Porsche 911 Carrera RS 2.7", "2.7", 210, 5.8, 245, "RWD", (4.15, 1.65, 1.32, 2.27), 66, 64),
 "mercedes_300sl": ("MERCEDES-BENZ", "300 SL", 1955, "classic", "coupe", "Mercedes-Benz 300 SL", "3.0", 215, 8.8, 235, "RWD", (4.52, 1.79, 1.30, 2.40), 60, 58),
 "lamborghini_miura": ("LAMBORGHINI", "MIURA", 1968, "classic", "coupe", "Lamborghini Miura P400", "3.9 V12", 350, 6.7, 280, "RWD", (4.36, 1.76, 1.06, 2.50), 64, 62),
 "ford_escort_rs1600": ("FORD", "ESCORT RS1600", 1972, "race", "sedan", "Ford Escort RS1600", "1.6", 120, 8.9, 182, "RWD", (4.00, 1.57, 1.37, 2.40), 70, 70),
 "lancia_stratos": ("LANCIA", "STRATOS HF", 1974, "race", "coupe", "Lancia Stratos HF Stradale", "2.4 V6", 190, 6.8, 232, "RWD", (3.71, 1.75, 1.11, 2.18), 72, 72),
 "bmw_m3_e30": ("BMW", "M3 E30", 1990, "race", "coupe", "BMW M3 E30 Evolution", "2.3", 215, 6.6, 241, "RWD", (4.35, 1.68, 1.37, 2.56), 72, 72),
 "toyota_celica_gt4": ("TOYOTA", "CELICA GT-FOUR", 1993, "race", "coupe", "Toyota Celica GT-Four ST185", "2.0 Turbo", 208, 7.5, 230, "AWD", (4.42, 1.75, 1.30, 2.53), 72, 74),
 # 2026-10-12: yarış dalının son dördü. Stratos gibi YOL (homologasyon) sürümlerinin verisi: Group B ralli
 # sürümleri (S1 E2 ~470 hp, RS200 Evo ~550 hp) normal araçların en hızlılarını da geçip dengeyi bozardı.
 "lancia_delta_integrale": ("LANCIA", "DELTA INTEGRALE", 1992, "race", "hatchback", "Lancia Delta HF Integrale Evoluzione", "2.0 Turbo", 210, 5.7, 220, "AWD", (3.90, 1.77, 1.37, 2.48), 74, 78),
 "audi_quattro_s1": ("AUDI", "SPORT QUATTRO S1", 1985, "race", "coupe", "Audi Sport Quattro", "2.1 Turbo", 306, 4.8, 250, "AWD", (4.16, 1.78, 1.35, 2.22), 74, 78),
 "ford_rs200": ("FORD", "RS200", 1986, "race", "coupe", "Ford RS200", "1.8 Turbo", 250, 6.1, 225, "AWD", (4.00, 1.76, 1.32, 2.53), 74, 76),
 "mitsubishi_evo6": ("MITSUBISHI", "LANCER EVO VI", 1999, "race", "sedan", "Mitsubishi Lancer Evolution VI GSR", "2.0 Turbo", 280, 4.4, 240, "AWD", (4.35, 1.77, 1.41, 2.51), 76, 78),
}
REFERENCE_LENGTH_M = 4.39   # CarCatalog.REFERENCE_LENGTH_M: model_scale ilk tahmini = gerçek boy / 4,39


def accel_stat(t):
    return max(0, min(100, round((16.0 - t) / (16.0 - 2.5) * 100)))


def read_pairs(path):
    out = {}
    if path and os.path.exists(path):
        for line in open(path, encoding="utf-8"):
            parts = line.split()
            if len(parts) >= 2:
                out[parts[0]] = parts[1]
    return out


def main():
    args = sys.argv[1:]
    colors = read_pairs(args[args.index("--colors") + 1]) if "--colors" in args else {}
    classes = read_pairs(args[args.index("--classes") + 1]) if "--classes" in args else {}
    path = os.path.join(ROOT, "vehicles/cars.json")
    data = json.load(open(path, encoding="utf-8"))
    by_id = {c["id"]: c for c in data["cars"]}
    for cid, (brand, model, year, tier, cat, variant, engine, hp, z100, top, drive, dims, reaction, grip) in CARS.items():
        old = by_id.get(cid, {})
        entry = {
            "id": cid, "brand": brand, "model": model, "label": "%s\n%s" % (brand, model),
            "year": year, "price": PRICE[tier], "condition": 1.0, "category": cat,
            "scene_path": "res://assets/cars/%s.tscn" % cid,
            "source_path": "res://assets/cars/source/%s.glb" % cid,
            "optimized_path": "res://assets/cars/optimized/%s.glb" % cid,
            "default_color": colors.get(cid, old.get("default_color", "#CCCCCC")),
            "world_node": "", "plate_color": "#E8C58A", "traffic": False,
            "class": classes.get(cid, old.get("class", "D")),
            "rarity": "common", "min_level": 1, "min_garage_rank": 1,
            "race": {"top_speed": top, "acceleration": accel_stat(z100), "reaction": reaction, "grip": grip},
            "performance": {"variant": variant, "engine": engine, "hp": hp, "zero_100": z100, "top_speed": top, "drivetrain": drive},
            "real_dimensions": {"length_m": dims[0], "width_m": dims[1], "height_m": dims[2], "wheelbase_m": dims[3]},
            "model_scale": old.get("model_scale", round(dims[0] / REFERENCE_LENGTH_M, 2)),
        }
        entry["available_colors"] = [entry["default_color"]]
        if cid in by_id:
            by_id[cid].clear()
            by_id[cid].update(entry)
        else:
            data["cars"].append(entry)
    open(path, "w", encoding="utf-8").write(json.dumps(data, ensure_ascii=False, indent=2) + "\n")
    print("cars.json: %d araç (%d restorasyon)" % (len(data["cars"]), len(CARS)))


if __name__ == "__main__":
    main()
