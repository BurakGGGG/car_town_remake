#!/bin/bash
# Tüm test paketlerini YALITILMIŞ kullanıcı klasöründe çalıştırır.
#
# Neden yalıtım: testler user://savegame.json üzerinden ilerlemeyi okur. Geliştirme kaydı
# (seviye 20, ustalık 150+) kullanılırsa "10 MOTOR işi → 1★" gibi eşik testleri yanlış FAIL verir.
# override.cfg geçici olarak yazılır, bitince silinir; gerçek kayıt dosyasına dokunulmaz.
#
# Kullanım: tools/run_tests.sh [test_adı ...]   (boşsa hepsi)
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
SUITE="${CT_SUITE_DIR:-$HOME/snap/godot-4/common/cloudtest}"
GODOT="${GODOT:-godot-4}"
OUT="${CT_OUT:-/tmp/ct_tests}"
HEADLESS="save_test edge_test quest_test paint_test cloud_test drag_transmission_test vehicle_wheel_test"
WINDOWED="ui_test race_test progression_test vehicle_asset_test vehicle_scale_test"
ALL="${*:-$HEADLESS $WINDOWED}"
mkdir -p "$OUT"
cd "$PROJ" || exit 1
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_suite"\n' > override.cfg
trap 'rm -f "$PROJ/override.cfg"' EXIT
fails=0
for t in $ALL; do
	# Her paket TEMİZ kayıtla başlar: aksi halde bir önceki paketin bıraktığı ilerleme
	# (ustalık sayaçları, garaj seviyesi) eşik testlerini yanlış FAIL'e düşürüyor.
	rm -f "$HOME/snap/godot-4/33/.local/share/ct_suite/savegame.json" \
	      "$HOME/snap/godot-4/33/.local/share/ct_suite/cloud_sync.json"
	mode="--headless"
	case " $WINDOWED " in *" $t "*) mode="--resolution 1152x648";; esac
	timeout 600 stdbuf -oL "$GODOT" --path . $mode --script "$SUITE/$t.gd" > "$OUT/$t.txt" 2>&1
	ok=$(grep -c '  OK ' "$OUT/$t.txt")
	bad=$(grep -cE '^  FAIL|^\s+FAIL' "$OUT/$t.txt")
	printf "%-22s %4d OK  %2d FAIL\n" "$t" "$ok" "$bad"
	fails=$((fails + bad))
done
echo "-----------------------------------"
echo "TOPLAM HATA: $fails"
exit $((fails > 0))
