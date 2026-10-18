#!/bin/bash
# FIREBASE EKLENTİSİNİ KAYNAKTAN DERLER: syntaxerror247/GodotFirebaseAndroid be573b1 + bu klasördeki yama
# (facebook_login.patch: Facebook girişi, hesap bağlama — linkFacebook / linkGoogle / linkPendingCredential —,
# getCurrentUser "provider" + "providers" alanları, signInWithCustomToken — e-posta koduyla giriş). Çıkan AAR'lar
# addons/GodotFirebaseAndroid/bin/{debug,release}/ altına kopyalanır.
# Gereken: JDK 21 (~/java-21-openjdk-amd64; sistemdeki 17 yalnız JRE), Android SDK (~/Android/Sdk).
# Gradle sarmalayıcısı 8.2 → 8.5 (8.2 JDK 21'de çalışmaz).
# Kullanım: tools/firebase_plugin/build.sh [kaynak_klasörü]   (varsayılan ~/Projects/plugins_src/GodotFirebaseAndroid)
set -eu
PROJ="$(cd "$(dirname "$0")/../.." && pwd)"
SRC="${1:-$HOME/Projects/plugins_src/GodotFirebaseAndroid}"
COMMIT=be573b1
export JAVA_HOME="${JAVA_HOME_21:-$HOME/java-21-openjdk-amd64}"
if [ ! -d "$SRC/.git" ]; then
	git clone -q https://github.com/syntaxerror247/GodotFirebaseAndroid.git "$SRC"
fi
cd "$SRC"
git checkout -q -- firebase/ gradle/
git checkout -q "$COMMIT"
git apply "$PROJ/tools/firebase_plugin/facebook_login.patch"
sed -i 's/gradle-8.2-bin.zip/gradle-8.5-bin.zip/' gradle/wrapper/gradle-wrapper.properties
[ -f local.properties ] || echo "sdk.dir=$HOME/Android/Sdk" > local.properties
./gradlew --no-daemon -q :firebase:assembleDebug :firebase:assembleRelease
cp firebase/build/outputs/aar/GodotFirebaseAndroid-debug.aar "$PROJ/addons/GodotFirebaseAndroid/bin/debug/"
cp firebase/build/outputs/aar/GodotFirebaseAndroid-release.aar "$PROJ/addons/GodotFirebaseAndroid/bin/release/"
echo "Tamam: AAR'lar addons/GodotFirebaseAndroid/bin altına kopyalandı"
