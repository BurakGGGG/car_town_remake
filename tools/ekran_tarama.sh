#!/bin/bash
# EKRAN TARAMASI: qa/ekran_tarama.gd'yi tüm cihaz oranlarında (ayrı süreçlerde) koşar.
# Kullanım: tools/ekran_tarama.sh [profil ...] [-- durum_öneki ...]
#   profiller: p20x9 p16x9 t16x10 t4x3 fold p21x9 desk (boşsa hepsi)
# Kayıt: QA_SAVE (varsayılan ~/Projects/ct_shots/bench_saves/dev.json); eğitim kapalı.
# Dil: CT_LANG=en|es (etiketin sonuna eklenir: p16x9_es); boşsa Türkçe.
set -u
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
declare -A RES=( [p20x9]=1440x648 [p16x9]=1152x648 [t16x10]=1152x720 [t4x3]=1152x864 [fold]=1152x960
	[p21x9]=1512x648 [desk]=1152x648 )
ORDER="p20x9 p16x9 t16x10 t4x3 fold p21x9 desk"
profiles=()
states=()
seen_dash=0
for a in "$@"; do
	if [ "$a" = "--" ]; then seen_dash=1; continue; fi
	if [ $seen_dash = 1 ]; then states+=("$a"); else profiles+=("$a"); fi
done
[ ${#profiles[@]} -eq 0 ] && read -ra profiles <<< "$ORDER"
export QA_SAVE="${QA_SAVE:-$HOME/Projects/ct_shots/bench_saves/dev.json}"
export CT_NO_TUTORIAL=1
mkdir -p "$HOME/Projects/ct_shots/ekran_tarama"
for p in "${profiles[@]}"; do
	mode=mobil
	[ "$p" = "desk" ] && mode=masaustu
	tag="$p${CT_LANG:+_$CT_LANG}"
	log="$HOME/Projects/ct_shots/ekran_tarama/$tag.log"
	QA_LANG="${CT_LANG:-tr}" timeout 600 "$PROJ/tools/qa_isolated.sh" res://qa/ekran_tarama.gd --display-driver x11 --disable-vsync \
		--position 0,0 --resolution "${RES[$p]}" -- "$tag" "$mode" "${states[@]}" > "$log" 2>&1
	echo "$tag: $(grep -c '  SORUN ' "$log") sorun  ($(grep -m1 'TOPLAM SORUN' "$log" || echo 'BİTMEDİ'))"
done
