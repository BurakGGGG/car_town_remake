#!/bin/bash
# AUTO YARD teaser'ı baştan üretir: 8 bölüm (tam çözünürlük kareler) → ses bandı → MP4.
# Kullanım: qa/teaser/render_all.sh [çalışma_klasörü] [bölüm ...]   (bölüm verilmezse hepsi)
# Snap Godot/Blender kendi /tmp'sini görür: çalışma klasörü ev dizininde olmalı.
set -eu
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${1:-$HOME/Projects/social_media/teaser/work}"
shift || true
SEGS=("$@")
[ ${#SEGS[@]} -eq 0 ] && SEGS=(hikaye garaj drag vitrin_ev vitrin_sanayi vitrin_luks vitrin_eglence logo)
FRAMES="$WORK/frames"
[ ${#@} -eq 0 ] && [ "${KEEP_FRAMES:-}" = "" ] && rm -rf "$FRAMES"   # tam çekimde eski kareler silinir
mkdir -p "$FRAMES"
cd "$PROJ"
GODOT_ARGS=(--display-driver x11 --disable-vsync --fixed-fps 30 --resolution 540x960)
for seg in "${SEGS[@]}"; do
	echo "== $seg"
	if [ "$seg" = "garaj" ] || [[ "$seg" == vitrin_* ]]; then
		# Main.tscn kaydı okur/yazar: yalıtılmış kullanıcı klasörü, eğitim kapalı
		CT_NO_TUTORIAL=1 tools/qa_isolated.sh res://qa/teaser/teaser.gd "${GODOT_ARGS[@]}" -- "$seg" "$FRAMES" > "$WORK/$seg.log" 2>&1
	else
		godot-4 --path . "${GODOT_ARGS[@]}" --script qa/teaser/teaser.gd -- "$seg" "$FRAMES" > "$WORK/$seg.log" 2>&1
	fi
	grep -E "TEASER|SCRIPT ERROR" "$WORK/$seg.log" || true
done
echo "== ses"
PY=/snap/blender/current/5.2/python/bin/python3.13
VOICE_MP3="$(dirname "$WORK")/ses"   # ElevenLabs satırları 01..06.mp3 (yoksa seslendirmesiz)
if [ -d "$VOICE_MP3" ]; then
	blender -b --factory-startup --python qa/teaser/decode_voice.py -- "$VOICE_MP3" "$WORK/ses_wav" > "$WORK/decode.log" 2>&1
	$PY -I qa/teaser/voice_prep.py "$WORK/ses_wav" "$WORK/ses_hazir" 1.1
fi
$PY -I qa/teaser/soundtrack.py "$WORK/soundtrack.wav" "$WORK/ses_hazir"
echo "== mp4"
OUT="$(dirname "$WORK")/AutoYard_teaser_TR_dikey_1080x1920.mp4"
blender -b --factory-startup --python-exit-code 1 -P qa/teaser/assemble_blender.py -- "$FRAMES" "$WORK/soundtrack.wav" "$OUT" > "$WORK/assemble.log" 2>&1
grep -E "TEASER MP4|Error" "$WORK/assemble.log" || true
ls -la "$OUT"
