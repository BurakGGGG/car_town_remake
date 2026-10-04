#!/usr/bin/env python3
"""Çeviri denetimi: locale/strings.json'daki her metnin locale/en.json ve locale/es.json'da çevirisi var mı,
biçim belirteçleri (%s %d %02d %%…) aynı sırada mı, eskimiş (artık kodda olmayan) çeviri var mı.
Bilerek çevrilmeyen (editör / hata ayıklama) metinler: değeri "" olan anahtarlar.
Çıkış kodu: hata varsa 1. Kullanım: python3 tools/i18n/check.py"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPEC = re.compile(r"%%|%[-+ 0#]*\d*(?:\.\d+)?[sdifxXc]")


def specs(text):
    """Biçim belirteçleri sırası (%% yer değiştirebilir: TR "%25", EN "25%")."""
    return [m for m in SPEC.findall(text) if m != "%%"], text.count("%%")


source = json.load(open(os.path.join(ROOT, "locale/strings.json"), encoding="utf-8"))
errors = 0
for lang in ("en", "es"):
    path = os.path.join(ROOT, f"locale/{lang}.json")
    data = json.load(open(path, encoding="utf-8"))
    missing = [k for k in source if k not in data]
    stale = [k for k in data if k not in source and not ("|" in k and k.rsplit("|", 1)[0] in source)]
    bad = [k for k, v in data.items() if v and specs(k) != specs(v)]
    for k in missing:
        print(f"[{lang}] EKSİK: {k!r}")
    for k in bad:
        print(f"[{lang}] BİÇİM UYUŞMUYOR: {k!r} → {data[k]!r}")
    for k in stale:
        print(f"[{lang}] ESKİMİŞ: {k!r}")
    errors += len(missing) + len(bad)
    print(f"{lang}: {len(source)} metin, {sum(1 for k in source if data.get(k))} çevrili, {len(missing)} eksik, {len(bad)} biçim hatası, {len(stale)} eskimiş")
sys.exit(1 if errors else 0)
