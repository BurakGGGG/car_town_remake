#!/bin/bash
# Öne çıkan garajları kurar / görüntüler / (--export ile) dışa aktarır. Kullanım: tools/featured/run.sh [kimlik] [--export]
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$PROJ" || exit 1
printf '[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="ct_featured"\n' > override.cfg
trap 'rm -f "$PROJ/override.cfg"' EXIT
timeout 600 godot-4 --path . --resolution 1600x900 --script res://tools/featured/build_featured.gd -- "$@" 2>&1 \
	| grep -E "^==|^  |RESULT|SCRIPT ERROR|^ERROR" | grep -v "resources still in use"
