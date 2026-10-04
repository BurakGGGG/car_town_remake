#!/usr/bin/env python3
"""Oyundaki oyuncuya görünen metinleri çıkarır (çeviri kaynağı = Türkçe metnin kendisi).

Kaynaklar:
  * .gd dosyalarındaki çift tırnaklı dizgeler (StringName &"..." , yollar, sinyal/grup adları, log satırları,
    yorumlar hariç) — sezgisel: içinde en az bir harf olan ve "kod kimliği"ne benzemeyenler.
  * veri dosyaları: decor/decorations.json (title, desc), vehicles/crates.json (display_name, sets.name).
Çıktı: locale/strings.json  {"metin": ["dosya:satır", ...]}
Kullanım: python3 tools/i18n/extract.py
"""
import json, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCAN = ["gameplay", "ui", "world", "vfx", "race", "traffic", "ads", "vehicles", "garage_system.gd",
        "car_hitbox.gd", "shop_hitbox.gd", "world_camera.gd", "build_grid.gd"]
SKIP_CALLS = ("push_warning", "push_error", "print", "printerr", "assert", "get_node", "has_method",
              "has_signal", "get_first_node_in_group", "add_to_group", "is_in_group", "connect", "load(",
              "preload", "get_setting", "find_child", "get_node_or_null", "set_value", "get_value",
              "ProjectSettings", "Engine.has_singleton", "call(", "theme_type_variation", "emit_signal",
              "add_theme_", "get_theme_", "OS.shell_open", "set_meta", "get_meta", "has_meta", "FileAccess",
              "DirAccess", "JSON.", "ResourceLoader", "RenderingServer", "AudioServer", "Time.", "set_bus_name")
STR = re.compile(r'(?<![&\^$])"((?:[^"\\\n]|\\.)*)"')

TR_UPPER = "ÇĞİÖŞÜ"
EXCLUDE = {"Master", "Document does not exist", "TÜRKÇE", "ENGLISH", "ESPAÑOL", "DİL · LANGUAGE · IDIOMA"}


def user_facing(s: str) -> bool:
    if not s or len(s) < 2 or s in EXCLUDE:
        return False
    if s.startswith(("res://", "user://", "uid://", "http", "/", "#")):
        return False
    if re.fullmatch(r"[0-9A-Fa-f]{6,8}", s):               # renk kodu
        return False
    if not re.search(r"[A-Za-zÇĞİÖŞÜçğıöşü]{2,}", s):
        return False
    if " " not in s and "\n" not in s:
        # Tek sözcük: yalnızca TAMAMI BÜYÜK harf (KAPAT, USTA) ya da Türkçe harf içeren sözcük oyuncu metnidir;
        # CamelCase / küçük harf kimlikler (AcceptButton, engine) düğüm adı / kimliktir.
        letters = re.sub(r"[^A-Za-zÇĞİÖŞÜçğıöşü]", "", s)
        if letters.isupper() or any(c in s for c in TR_UPPER + "çğıöşü"):
            return not re.fullmatch(r"[A-Z0-9_]+_[A-Z0-9_]+", s)   # SABİT_ADI değil
        return False
    if re.fullmatch(r"[a-z0-9_ ./:%-]+", s) and len(re.findall(r"[a-z]{2,}", s)) < 2:
        return False   # kod / yol (tek sözcük); iki ve daha çok sözcüklü küçük harfli cümle oyuncu metnidir
    return True


def literals(line: str):
    """Satırdaki dizge sabitleri (yorum hariç). &"..." (StringName) ve ^"..." (NodePath) atlanır."""
    i, n = 0, len(line)
    while i < n:
        ch = line[i]
        if ch == "#":
            return
        if ch == '"':
            prefix = line[i - 1] if i > 0 else ""
            j = i + 1
            buf = []
            while j < n and line[j] != '"':
                if line[j] == "\\" and j + 1 < n:
                    buf.append(line[j:j + 2]); j += 2; continue
                buf.append(line[j]); j += 1
            raw = "".join(buf)
            if prefix not in ("&", "^", "$"):
                yield raw
            i = j + 1
            continue
        i += 1


def decode(raw: str) -> str:
    return raw.replace("\\n", "\n").replace('\\"', '"').replace("\\t", "\t").replace("\\\\", "\\")


def scan_gd(path, out):
    rel = os.path.relpath(path, ROOT)
    with open(path, encoding="utf-8") as f:
        for no, line in enumerate(f, 1):
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if any(c in line for c in SKIP_CALLS) and not re.search(r"\.text\s*=|_label\(|text\s*%|tr\(|Loc\.t\(", line):
                continue
            for raw in literals(line):
                s = decode(raw)
                if user_facing(s):
                    out.setdefault(s, []).append(f"{rel}:{no}")


def scan_json(out):
    decor = json.load(open(os.path.join(ROOT, "decor/decorations.json"), encoding="utf-8"))
    for it in decor.get("items", []):
        for key in ("title", "desc"):
            if it.get(key):
                out.setdefault(it[key], []).append(f"decor/decorations.json:{it['id']}.{key}")
    crates = json.load(open(os.path.join(ROOT, "vehicles/crates.json"), encoding="utf-8"))
    for c in crates.get("crates", []):
        for key in ("display_name", "short_name", "description", "subtitle"):
            if c.get(key):
                out.setdefault(c[key], []).append(f"vehicles/crates.json:{c['id']}.{key}")
    for st in crates.get("sets", []):
        if st.get("name"):
            out.setdefault(st["name"], []).append(f"vehicles/crates.json:set.{st['id']}")

def scan_tscn(out):
    """Sahne dosyalarındaki Label / Button metinleri (text = "…"); Control kendi metnini çevirir."""
    for rel in ("ui/hud/hud.tscn", "ui/hud/garage_screen.tscn", "Main.tscn"):
        path = os.path.join(ROOT, rel)
        if not os.path.exists(path):
            continue
        for no, line in enumerate(open(path, encoding="utf-8"), 1):
            m = re.match(r'^text = "((?:[^"\\]|\\.)*)"', line)
            if m:
                s = decode(m.group(1))
                if user_facing(s):
                    out.setdefault(s, []).append(f"{rel}:{no}")


def main():
    out = {}
    scan_tscn(out)
    for entry in SCAN:
        p = os.path.join(ROOT, entry)
        if os.path.isfile(p):
            scan_gd(p, out)
            continue
        for d, _, files in os.walk(p):
            for fn in files:
                if fn.endswith(".gd") and fn != "loc.gd":
                    scan_gd(os.path.join(d, fn), out)
    scan_json(out)
    os.makedirs(os.path.join(ROOT, "locale"), exist_ok=True)
    with open(os.path.join(ROOT, "locale/strings.json"), "w", encoding="utf-8") as f:
        json.dump(dict(sorted(out.items())), f, ensure_ascii=False, indent=1)
    print(len(out), "metin")

if __name__ == "__main__":
    main()
