#!/usr/bin/env python3
"""Koddaki oyuncuya görünen dizge sabitlerini Loc.t("…") ile sarar (bir kez çalıştırılır, idempotent).
Sarılmayanlar: const / @export / enum / signal / func imzası satırları ve çok satırlı const blokları,
sözlük anahtarları ("x": …), log / API çağrısı satırları, zaten Loc.t / tr içinde olanlar.
Kullanım: python3 tools/i18n/wrap.py [--dry]"""
import os, re, sys
sys.path.insert(0, os.path.dirname(__file__))
from extract import ROOT, SCAN, SKIP_CALLS, user_facing, decode   # noqa: E402

DRY = "--dry" in sys.argv
changed_files = 0
changed = 0


def process(path):
    global changed_files, changed
    lines = open(path, encoding="utf-8").read().split("\n")
    out = []
    depth = 0          # çok satırlı const bloğu içindeyken > 0
    file_changed = False
    for line in lines:
        stripped = line.strip()
        starts_const = re.match(r"\s*(const|@export|enum|signal|static var\s+\w+\s*:\s*\w+\s*=\s*\[)", line)
        if depth > 0 or starts_const:
            opened = line.count("[") + line.count("{") + line.count("(")
            closed = line.count("]") + line.count("}") + line.count(")")
            if depth > 0 or starts_const:
                depth += opened - closed
                if depth < 0:
                    depth = 0
            out.append(line)
            continue
        if stripped.startswith("#") or re.match(r"\s*(static\s+)?func\s", line) or stripped.startswith("@"):
            out.append(line)
            continue
        if any(c in line for c in SKIP_CALLS) and not re.search(r"\.text\s*=|_label\(|text\s*%", line):
            out.append(line)
            continue
        new = []
        i, n = 0, len(line)
        while i < n:
            ch = line[i]
            if ch == "#":
                new.append(line[i:]); break
            if ch == '"':
                prefix = line[i - 1] if i > 0 else ""
                j = i + 1
                while j < n and line[j] != '"':
                    j += 2 if line[j] == "\\" else 1
                raw = line[i + 1:j]
                lit = line[i:j + 1]
                after = line[j + 1:].lstrip()
                before = "".join(new)
                wrapped_already = before.rstrip().endswith(("Loc.t(", "tr(", "atr("))
                is_key = after.startswith(":") and not after.startswith(":=")
                if prefix not in ("&", "^", "$") and not wrapped_already and not is_key and user_facing(decode(raw)):
                    new.append('Loc.t(%s)' % lit)
                    file_changed = True
                    changed += 1
                else:
                    new.append(lit)
                i = j + 1
                continue
            new.append(ch)
            i += 1
        out.append("".join(new))
    if file_changed:
        changed_files += 1
        if not DRY:
            open(path, "w", encoding="utf-8").write("\n".join(out))


for entry in SCAN:
    p = os.path.join(ROOT, entry)
    paths = [p] if os.path.isfile(p) else [os.path.join(d, f) for d, _, fs in os.walk(p) for f in fs if f.endswith(".gd")]
    for path in paths:
        if path.endswith("/ui/loc.gd"):
            continue
        process(path)
print(f"{changed} dizge, {changed_files} dosya" + (" (deneme)" if DRY else ""))
