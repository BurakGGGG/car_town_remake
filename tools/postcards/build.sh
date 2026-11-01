#!/bin/bash
# HURDALIK KARTPOSTALLARI: restorasyon araçlarının eski, sararmış kartpostal fotoğraflarını yeniden üretir.
#   1) scenes.py         kademe manzaraları (SVG, depoda)
#   2) render_cars.gd    araçların temiz hâli, kartpostal açısından (PENCERELİ Godot) + manzara pikselleri
#   3) make_postcards.py birleştir + eskit → assets/ui/postcards/<id>.jpg + kirisik.png
#   4) --import, sonra .import'lar kayıplı (WebP 0,85, yükleme slaytları gibi) ve yeniden içe aktarılır
# Ne zaman: yeni restorasyon aracı eklenince, bir aracın modeli / rengi değişince, manzara değişince.
# Kullanım: tools/postcards/build.sh [<araç_id> ...]   (boşsa hepsi)
# Ara dosyalar: $POSTCARD_WORK (varsayılan ~/Projects/ct_shots/kartpostal/work — snap Godot gizli klasöre yazamaz)
set -eu
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
GODOT="${GODOT:-godot-4}"
WORK="${POSTCARD_WORK:-$HOME/Projects/ct_shots/kartpostal/work}"
cd "$PROJ"
mkdir -p "$WORK"

python3 tools/postcards/scenes.py
"$GODOT" --path . --display-driver x11 --disable-vsync --resolution 640x360 \
	--script res://tools/postcards/render_cars.gd -- "$WORK" "$@" 2>&1 | grep -E "ARAÇ|MANZARA|ATLANDI|BİTTİ|ERROR: [^1]" || true
python3 tools/postcards/make_postcards.py "$WORK" "$@"

"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
changed=0
for f in assets/ui/postcards/*.jpg.import assets/ui/postcards/*.png.import; do
	[ -f "$f" ] || continue
	if ! grep -q '^compress/mode=1$' "$f" || ! grep -q '^compress/lossy_quality=0.85$' "$f"; then
		sed -i -e 's/^compress\/mode=.*/compress\/mode=1/' -e 's/^compress\/lossy_quality=.*/compress\/lossy_quality=0.85/' \
			-e 's/^mipmaps\/generate=.*/mipmaps\/generate=false/' "$f"
		src="$(basename "${f%.import}")"
		rm -f .godot/imported/"$src"-*   # içe aktarma ayarı değişti: eski çıktı silinir, yeniden üretilir
		changed=$((changed + 1))
	fi
done
# Seçili araçlar yeniden üretildiyse resimleri değişti: onların çıktısı da yenilensin
for id in "$@"; do rm -f .godot/imported/"$id".jpg-*; done
if [ $changed -gt 0 ] || [ $# -gt 0 ]; then
	"$GODOT" --headless --path . --import > /dev/null 2>&1 || true
fi
echo "kartpostal içe aktarma: $changed .import kayıplıya çevrildi"
