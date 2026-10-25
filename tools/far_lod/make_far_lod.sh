#!/bin/bash
# ARAÇ UZAK LOD'U → assets/cars/far_lod/<model>.res (bkz. vehicles/car_far_lod.gd, tools/far_lod/make_far_lod.gd).
# Kullanım: tools/far_lod/make_far_lod.sh [<araç_id> ...]   (boşsa bütün araçlar)
# FAR_LOD_ERROR: sapma sınırı (mesh birimi, araç uzunluğu = 1; varsayılan 0.004 ≈ 4,4 m araçta 1,8 cm).
# FAR_LOD_WHEEL_ERROR: dönen parçaların (teker / lastik / jant) sınırı; 0 (varsayılan) = tekerler yazılmaz.
set -eu
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot-4}"
cd "$PROJ"
"$GODOT" --path . --display-driver x11 --resolution 640x360 --script res://tools/far_lod/make_far_lod.gd -- dump \
	--error="${FAR_LOD_ERROR:-0.004}" "$@" \
	2>&1 | grep -E "ERROR|FARLOD" || true
for f in .godot/far_lod/*.in; do
	python3 tools/far_lod/simplify_far_lod.py --error "${FAR_LOD_ERROR:-0.004}" --wheel-error "${FAR_LOD_WHEEL_ERROR:-0}" \
		${FAR_LOD_NORMAL_TOL:+--normal-tol "$FAR_LOD_NORMAL_TOL"} ${FAR_LOD_NO_PERMISSIVE:+--no-permissive} \
		"$f" "${f%.in}.out"
done
"$GODOT" --headless --path . --script res://tools/far_lod/make_far_lod.gd -- pack 2>&1 | grep -E "ERROR|FARLOD" || true
# Godot 4 KB'lık bloklarla yazar; tek blok zstd-19 ~%15 küçük (tools/size/rscc_repack.py'nin kabı; derleme betikleri de
# EXTRA listesiyle yapar). Yalnız bu dosyalar: .godot/imported'a dokunulmaz.
python3 - <<'PY'
import glob, sys
sys.path.insert(0, "tools/size")
import rscc_repack as R
total = 0
for path in sorted(glob.glob("assets/cars/far_lod/*.res")):
    blob = open(path, "rb").read()
    raw, block = R.unpack(blob)
    new = R.pack(raw)
    if R.unpack(new)[0] == raw and len(new) < len(blob):
        open(path, "wb").write(new)
        blob = new
    total += len(blob)
print("FARLOD toplam %.2f MB" % (total / 1e6))
PY
rm -f .godot/far_lod/*.in .godot/far_lod/*.out   # döküm ~yüzlerce MB: yalnız bu çalışmanın ara dosyası
