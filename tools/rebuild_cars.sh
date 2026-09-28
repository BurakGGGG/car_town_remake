#!/bin/bash
# 16 aracı kaynaktan yeniden üretir ve TANJANTI ATAR.
# Gerekçe ve ölçümler: docs/MESH_BUTCESI.md
#
# Kaynaştırma (Blender'da kopya vertex birleştirme) DENENDİ VE BIRAKILDI: ölçümde ne boyut ne
# kalite kazandırdı — sadeleştirici daha iyi bağlantılı mesh'te daha yüksek bir LOD basamağı
# seçtiği için içe aktarılmış mesh 3,63 yerine 3,77 MB çıkıyordu (bmw_e46). Betiği
# tools/decor/mesh_kaynastir.py'de duruyor, kullanılmıyor.
set -u
cd "$(dirname "$0")/.." || exit 1
GODOT="${GODOT:-godot-4}"
python3 - <<'PY' > /tmp/ct_cars.txt
import json
for c in json.load(open("vehicles/cars.json"))["cars"]:
    src = c["source_path"].replace("res://", "")
    # Çıktı adı cars.json'daki optimized_path'ten gelir; id'den TÜRETİLMEZ
    # (vw_passat_b55 → volswagen_passat_b5_5.glb gibi uyuşmazlıklar var).
    out = c["optimized_path"].replace("res://", "")
    extra = "--ratio 0.08 --rename" if c["id"] == "renault_toros" else "--ratio 0.125"
    print("%s|%s|%s|%s|%s" % (c["id"], src, out, c["scene_path"], extra))
PY
fail=0
while IFS='|' read -r id src out scene extra; do
	if [ ! -f "$src" ]; then echo "ATLANDI $id: $src yok"; fail=$((fail+1)); continue; fi
	line=$(timeout 900 "$GODOT" --headless --path . -s res://tools/optimize_car.gd -- \
		--in "res://$src" --out "res://$out" $extra --min-tris 300 --map "$scene" 2>&1 | grep "^cikis")
	if [ -z "$line" ]; then echo "HATA $id: optimize başarısız"; fail=$((fail+1)); continue; fi
	python3 tools/strip_tangents.py "$out" | sed "s|^|  |"
	echo "$id  ${line#cikis : }"
done < /tmp/ct_cars.txt
# Yeni dokular başsız import'ta sıkıştırılmadan geliyor (mode=0 → 16 MB VRAM); mode=2'ye çek.
sed -i 's|^compress/mode=0|compress/mode=2|' assets/cars/optimized/*_albedo.jpg.import 2>/dev/null
echo "=== import ==="
timeout 1800 "$GODOT" --headless --path . --import 2>&1 | grep -c reimport
echo "=== boya maskeleri ==="
timeout 1800 "$GODOT" --headless --path . -s res://tools/make_paint_mask.gd -- --all 2>&1 | grep "\[mask\]"
echo "=== başarısız: $fail ==="
