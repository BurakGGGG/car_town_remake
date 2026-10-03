#!/bin/bash
# Telefonda denemek için DEBUG APK üretir (Google TEST reklamlarıyla; gerçek reklam kimliği kullanılmaz).
# Preset AAB'ye ayarlı olduğundan geçici olarak APK'ya çevrilir ve geri alınır.
# Çıktı: ~/Projects/AutoYard_release/AutoYard_debug.apk   Kurulum: adb install -r <dosya>
set -eu
PROJ="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJ"
cp export_presets.cfg export_presets.cfg.bak_apk
trap 'mv -f export_presets.cfg.bak_apk export_presets.cfg' EXIT
sed -i 's|^gradle_build/export_format=.*|gradle_build/export_format=0|' export_presets.cfg
mkdir -p ../AutoYard_release
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$HOME/snap/godot-4/common/gradle}"
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$HOME/godot-debug.keystore"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
godot-4 --headless --path . --export-debug Android ../AutoYard_release/AutoYard_debug.apk
ls -la ../AutoYard_release/AutoYard_debug.apk
