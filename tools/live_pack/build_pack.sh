#!/bin/bash
# İÇERİK PAKETİ KUR: tools/live_pack/content/<kimlik>/ → firebase/admin/packs/<kimlik>.pck (+ <kimlik>.json: özet, boyut).
# Önce modeller içe aktarılır (headless --import; editör açıksa zaten içe aktarmıştır). Paket yönetim panelinden
# (İÇERİK PAKETLERİ › Yükle) Firebase Storage'a gider ve config/app.packs'e yazılır. Ayrıntı: docs/CANLI_ETKINLIK.md
# Kullanım: tools/live_pack/build_pack.sh <kimlik>
set -u
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot-4}"
ID="${1:?kullanım: tools/live_pack/build_pack.sh <kimlik>}"
OUT="$PROJ/firebase/admin/packs"
[ -f "$PROJ/tools/live_pack/content/$ID/pack.json" ] || { echo "yok: tools/live_pack/content/$ID/pack.json"; exit 1; }
[ -f "$PROJ/override.cfg" ] && { echo "override.cfg var (test / tarama sürüyor olabilir): bitince yeniden dene"; exit 1; }
mkdir -p "$OUT"
cd "$PROJ"
timeout 900 "$GODOT" --headless --path . --import > /dev/null 2>&1 || true
"$GODOT" --headless --path . --script res://tools/live_pack/build_pack.gd -- "$ID" "$OUT" > "$OUT/$ID.log" 2>&1
status=$?
grep -v "^Godot Engine\|^$" "$OUT/$ID.log"
exit $status
