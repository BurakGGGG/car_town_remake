#!/bin/bash
# Bir QA betiğini YALITILMIŞ kullanıcı klasöründe (temiz kayıtla) çalıştırır: geliştirme kaydına
# araç / rekor yazan QA'lar (ör. qa/drag_feel.gd) gerçek ilerlemeyi kirletmesin.
# run_tests.sh ile aynı override.cfg yöntemi; ikisi AYNI ANDA çalıştırılmamalı.
# Kullanım: tools/qa_isolated.sh <res://qa/betik.gd> [godot argümanları ...] [-- betik argümanları]
# QA_SAVE=<savegame.json> verilirse temiz kayıt yerine o kaydın KOPYASIYLA başlar (asıl dosyaya dokunulmaz).
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-godot-4}"
SCRIPT="$1"; shift
cd "$PROJ" || exit 1
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_qa"\n' > override.cfg
trap 'rm -f "$PROJ/override.cfg"' EXIT
for d in "$HOME/snap/godot-4"/*/.local/share/ct_qa "${XDG_DATA_HOME:-$HOME/.local/share}/ct_qa"; do
	[ "$GODOT" = "godot-4" ] && [[ "$d" != "$HOME/snap/"* ]] && continue
	mkdir -p "$d"
	rm -f "$d/savegame.json" "$d/cloud_sync.json"
	[ -n "${QA_SAVE:-}" ] && cp "$QA_SAVE" "$d/savegame.json"
	printf '[general]\nlanguage="tr"\n' > "$d/settings.cfg"
done
stdbuf -oL "$GODOT" --path . --script "$SCRIPT" "$@"
