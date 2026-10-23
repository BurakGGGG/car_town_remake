#!/bin/bash
# Play'e yüklenecek release AAB'yi yükleme anahtarıyla imzalayarak üretir.
# Parola sorulur (ekranda görünmez, hiçbir yere yazılmaz).
# Kullanım: tools/build_release_aab.sh
set -eu
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
KEYSTORE="${AY_KEYSTORE:-$HOME/keys/autoyard-upload.keystore}"
ALIAS="${AY_KEY_ALIAS:-autoyard-upload}"
OUT="$PROJ/../AutoYard_release/AutoYard.aab"
[ -f "$KEYSTORE" ] || { echo "Keystore yok: $KEYSTORE"; exit 1; }
read -rsp "Keystore parolası: " PASS
echo
mkdir -p "$(dirname "$OUT")"
cd "$PROJ"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/snap/godot-4/common/gradle}"
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE"
export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$ALIAS"
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$PASS"
# Kayıpsız paket küçültme (docs/MESH_BUTCESI.md "Paket boyutu 4"): içe aktarma güncellenir, sonra mesh / sahne
# kapları (RSCC) 4 KB yerine 1 MiB blokla yeniden sıkıştırılır (açılan içerik aynı; −~18 MiB).
godot-4 --headless --path . --import
python3 tools/size/rscc_repack.py
godot-4 --headless --path . --export-release Android "$OUT"
echo "--- İmza ---"
keytool -printcert -jarfile "$OUT" | head -4
ls -la "$OUT"
