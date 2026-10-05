#!/usr/bin/env bash
# AUTO YARD'a özel küçültülmüş Android motoru (release şablonu, arm64) derler ve projeye kurar.
#
#   tools/engine/build_engine.sh            # derle + kur
#   tools/engine/build_engine.sh --install  # yalnızca kur (derlenmiş .so varsa)
#   tools/engine/build_engine.sh --restore  # resmi motoru geri koy
#
# Neden: resmi şablon (69 MB .so) Vulkan çizicisini, XR'ı, ağı, navigasyonu, videoyu vb. taşıyor;
# oyun bunların hiçbirini kullanmıyor (GL Compatibility + Jolt). Çıkarılanlar: autoyard_profile.py.
# Ölçüm ve kararlar: docs/MESH_BUTCESI.md "Paket boyutu".
#
# android/ git'te değil: editörden "Android Build Template" yeniden kurulursa bu betik --install ile
# tekrar çalıştırılmalı. Sürüm .build_version ile eşleşmezse betik durur (motor ve editör aynı sürüm olmalı).
# Gerekenler: ~/Android/Sdk/ndk/29.0.14206865, SCons (~/godot-build/venv), ~6 GB disk.
set -euo pipefail
cd "$(dirname "$0")/../.."
PROJECT="$PWD"
VERSION="4.7.2-stable"
WORK="${GODOT_BUILD_DIR:-$HOME/godot-build}"
SRC="$WORK/godot"
OUT_SO="$WORK/out/libgodot_android.template_release.arm64.so"
# Motor libc++'a dinamik bağlı: derlemede kullanılan NDK'nın kopyası da birlikte gitmeli (resmi aar'dakiyle aynı değil).
OUT_CXX="$WORK/out/libc++_shared.arm64.so"
AAR="$PROJECT/android/build/libs/release/godot-lib.template_release.aar"
ORIG_AAR="$WORK/out/godot-lib.template_release.official.aar"

expected="$(cut -d. -f1-3 < "$PROJECT/android/.build_version")"   # 4.7.2
[[ "$VERSION" == "$expected-stable" ]] || { echo "Sürüm uyuşmuyor: şablon $expected, betik $VERSION"; exit 1; }

mode="${1:-}"
if [[ "$mode" == "--restore" ]]; then
	cp "$ORIG_AAR" "$AAR" && echo "Resmi motor geri kondu." && exit 0
fi

if [[ "$mode" != "--install" ]]; then
	[[ -d "$SRC" ]] || git clone --depth 1 --branch "$VERSION" https://github.com/godotengine/godot.git "$SRC"
	[[ -x "$WORK/venv/bin/scons" ]] || { python3 -m venv "$WORK/venv" && "$WORK/venv/bin/pip" install -q scons; }
	( cd "$SRC" && ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}" nice -n 5 "$WORK/venv/bin/scons" \
		platform=android arch=arm64 target=template_release profile="$PROJECT/tools/engine/autoyard_profile.py" \
		swappy=no lto=full -j"$(( $(nproc) > 2 ? $(nproc) - 2 : 1 ))" )
	mkdir -p "$WORK/out"
	cp "$SRC/platform/android/java/lib/libs/release/arm64-v8a/libgodot_android.so" "$OUT_SO"
	cp "$SRC/platform/android/java/lib/libs/release/arm64-v8a/libc++_shared.so" "$OUT_CXX"
fi

[[ -f "$OUT_SO" && -f "$OUT_CXX" ]] || { echo "Derlenmiş motor yok: $OUT_SO / $OUT_CXX"; exit 1; }
mkdir -p "$WORK/out"
# Resmi aar'ı bir kez sakla (yalnızca içinde resmi büyük .so varken).
if [[ ! -f "$ORIG_AAR" ]]; then cp "$AAR" "$ORIG_AAR"; fi
python3 - "$ORIG_AAR" "$AAR" "$OUT_SO" "$OUT_CXX" <<'PY'
import sys, zipfile
src, dst, so, cxx = sys.argv[1:5]
new = {"jni/arm64-v8a/libgodot_android.so": so, "jni/arm64-v8a/libc++_shared.so": cxx}
with zipfile.ZipFile(src) as zin, zipfile.ZipFile(dst + ".tmp", "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        if item.filename in new:
            zout.write(new[item.filename], item.filename)
        else:
            zout.writestr(item, zin.read(item.filename))
import os; os.replace(dst + ".tmp", dst)
print("Kuruldu: %s (.so %.1f MB)" % (dst, os.path.getsize(so) / 1048576))
PY
