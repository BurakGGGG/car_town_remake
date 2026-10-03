#!/bin/bash
# Tüm test paketlerini YALITILMIŞ kullanıcı klasöründe çalıştırır.
#
# Neden yalıtım: testler user://savegame.json üzerinden ilerlemeyi okur. Geliştirme kaydı
# (seviye 20, ustalık 150+) kullanılırsa "10 MOTOR işi → 1★" gibi eşik testleri yanlış FAIL verir.
# override.cfg geçici olarak yazılır, bitince silinir; gerçek kayıt dosyasına dokunulmaz.
#
# Kullanım: tools/run_tests.sh [test_adı ...]   (boşsa hepsi)
# Paket önce depodaki tests/<ad>.gd'de aranır, yoksa $SUITE/<ad>.gd (depo dışı eski paketler).
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
SUITE="${CT_SUITE_DIR:-$HOME/snap/godot-4/common/cloudtest}"
GODOT="${GODOT:-godot-4}"
OUT="${CT_OUT:-/tmp/ct_tests}"
HEADLESS="save_test edge_test quest_test paint_test account_delete_test login_flow_test drag_transmission_test vehicle_wheel_test decor_test garage_decoration_placement_test crate_test release_test ads_test bay_move_test"
WINDOWED="touch_scroll_test ui_test login_reload_test race_test progression_test vehicle_asset_test vehicle_scale_test"
ALL="${*:-$HEADLESS $WINDOWED}"
mkdir -p "$OUT"
cd "$PROJ" || exit 1
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_suite"\n' > override.cfg
trap 'rm -f "$PROJ/override.cfg"' EXIT
fails=0
for t in $ALL; do
	# Her paket TEMİZ kayıtla başlar: aksi halde bir önceki paketin bıraktığı ilerleme
	# (ustalık sayaçları, garaj seviyesi) eşik testlerini yanlış FAIL'e düşürüyor.
	# Snap sürüm numarası yola giriyor ve snap kendini güncelliyor (33 → 40 görüldü);
	# sabit yazılırsa temizlik sessizce hiçbir şey silmez ve testler kirli kayıtla koşar.
	for d in "$HOME/snap/godot-4"/*/.local/share/ct_suite; do
		rm -f "$d/savegame.json" "$d/cloud_sync.json"
	done
	mode="--headless"
	case " $WINDOWED " in *" $t "*) mode="--resolution 1152x648";; esac
	script="$SUITE/$t.gd"
	[ -f "$PROJ/tests/$t.gd" ] && script="res://tests/$t.gd"
	timeout 600 stdbuf -oL "$GODOT" --path . $mode --script "$script" > "$OUT/$t.txt" 2>&1
	ok=$(grep -c '  OK ' "$OUT/$t.txt")
	bad=$(grep -cE '^  FAIL|^\s+FAIL' "$OUT/$t.txt")
	note=""
	# Sonuç satırı yoksa paket hiç bitmedi (betik derlenemedi, çöktü, zaman aşımı): "0 OK 0 FAIL"
	# geçti sayılmasın. Eski decor_test v9'dan sonra derlenmiyordu ve toplamda 0 hata görünüyordu.
	if ! grep -qE '^RESULT fails=|^SONUC:' "$OUT/$t.txt"; then
		bad=$((bad + 1))
		note="  ← BİTMEDİ (bkz. $OUT/$t.txt)"
	fi
	printf "%-22s %4d OK  %2d FAIL%s\n" "$t" "$ok" "$bad" "$note"
	fails=$((fails + bad))
done
echo "-----------------------------------"
echo "TOPLAM HATA: $fails"
exit $((fails > 0))
