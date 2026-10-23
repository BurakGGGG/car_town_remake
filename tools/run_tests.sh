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
HEADLESS="tutorial_test save_test edge_test quest_test paint_test account_delete_test login_flow_test drag_transmission_test vehicle_wheel_test decor_test garage_decoration_placement_test crate_test release_test ads_test bay_move_test vehicle_display_test mission_test locale_test decor_v2_test social_test race_record_test race_replay_test rival_select_test race_learning_test mod_garage_test purchase_test junkyard_test performance_mod_test car_thumbs_test luxury_decor_test police_lights_test office_decor_test welcome_crate_test profile_test friend_race_test race_news_test offline_earnings_test news_sources_test visit_early_test all_cars_test car_garage_test founder_reward_test gem_exchange_test level_up_test app_config_test mail_test moderation_test name_sign_test telemetry_test live_event_test ad_offers_test audio_cache_test garage_upgrades_test"
WINDOWED="photo_mode_test repair_collect_test city_life_test race_rematch_test customer_patience_test police_chase_test touch_scroll_test scroll_drag_test settings_test ui_test login_reload_test race_test progression_test vehicle_asset_test vehicle_scale_test traffic_pool_test visit_test exotic_traffic_test traffic_sound_test"
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
	# GODOT=<snap dışı ikili> (ör. tools/engine ile derlenen motor) kaydı ~/.local/share/ct_suite'e yazar.
	for d in "$HOME/snap/godot-4"/*/.local/share/ct_suite "${XDG_DATA_HOME:-$HOME/.local/share}/ct_suite"; do
		[ "$GODOT" = "godot-4" ] && [[ "$d" != "$HOME/snap/"* ]] && continue
		mkdir -p "$d"
		rm -f "$d/savegame.json" "$d/cloud_sync.json"
		# Dil: testler Türkçe metinleri denetler; cihaz dili (ör. en_US) oyunu İngilizce açmasın
		printf '[general]\nlanguage="tr"\n' > "$d/settings.cfg"
	done
	mode="--headless"
	# Wayland'de örtülü pencereye kare çizilmez ve frame_post_draw bekleyen test (race_test _shot) sonsuza
	# kadar bekleyip 600 sn'de kesiliyordu; XWayland (x11 sürücüsü) örtülü pencerede de çizer.
	x11=""
	[ -n "${WAYLAND_DISPLAY:-}" ] && x11="--display-driver x11"
	case " $WINDOWED " in *" $t "*) mode="--resolution 1152x648 $x11";; esac
	script="$SUITE/$t.gd"
	[ -f "$PROJ/tests/$t.gd" ] && script="res://tests/$t.gd"
	# Eğitim (Rıza Usta) kapalı: temiz kayıtta hoş geldin kartı testlerin dokunuşlarını tutardı
	CT_NO_TUTORIAL=1 timeout 600 stdbuf -oL "$GODOT" --path . $mode --script "$script" > "$OUT/$t.txt" 2>&1
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
