#!/usr/bin/env python3
"""qa/script_profile.gd çıktısını özetler: her "=== PROF <etiket> wall=<ms>" satırından sonra gelen
"ACCUMULATED:" dökümü o etikete aittir. Etiket başına betik toplamı ve kendi süresine göre en pahalı
fonksiyonlar yazılır.

Kullanım: python3 tools/prof_report.py prof.log [--top N] [--match <etiket parçası>] [--by total]
"""
import argparse
import re
import sys


def parse(path):
    sections = []
    label = None
    wall = 0.0
    rows = None
    pending = None
    with open(path, encoding="utf-8", errors="replace") as fh:
        lines = fh.read().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"=== PROF (.*) wall=([\d.]+)", line)
        if m:
            label, wall = m.group(1), float(m.group(2))
            i += 1
            continue
        if line.startswith("ACCUMULATED:") and label is not None:
            rows = []
            i += 1
            while i + 1 < len(lines):
                h = re.match(r"(\d+):(.*)", lines[i])
                t = re.search(r"total: ([\d.e+-]+)/.*self: ([\d.e+-]+)/.*calls: (\d+)", lines[i + 1])
                if not (h and t):
                    break
                calls = int(t.group(3))
                if calls > 0:
                    rows.append((float(t.group(2)) * 1000.0, float(t.group(1)) * 1000.0, calls, h.group(2)))
                i += 2
            sections.append((label, wall, rows))
            label = None
            continue
        i += 1
    return sections


def short(sig):
    # res://ui/hud/hud.gd::1208::Hud._build_junkyard_screens → ui/hud/hud.gd:1208 Hud._build_junkyard_screens
    parts = sig.split("::")
    if len(parts) == 3:
        return "%s:%s %s" % (parts[0].replace("res://", ""), parts[1], parts[2])
    return sig


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("--top", type=int, default=25)
    ap.add_argument("--match", default="")
    ap.add_argument("--by", choices=["self", "total"], default="self")
    a = ap.parse_args()
    for label, wall, rows in parse(a.log):
        if a.match and a.match not in label:
            continue
        script = sum(r[0] for r in rows)
        print("\n## %s — duvar saati %.1f ms, betik (kendi süreleri toplamı) %.1f ms" % (label, wall, script))
        key = 0 if a.by == "self" else 1
        for st, tt, calls, sig in sorted(rows, key=lambda r: -r[key])[: a.top]:
            print("%8.1f kendi %8.1f toplam %8dx  %s" % (st, tt, calls, short(sig)))


if __name__ == "__main__":
    sys.exit(main())
