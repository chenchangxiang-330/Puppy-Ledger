#!/usr/bin/env bash
# Build the independent emulator test host. Never uses the ledger's private key.
set -euo pipefail
: "${ANDROID_HOME:?Set ANDROID_HOME to an Android SDK with Platform and Build Tools 36}"
: "${JAVA_HOME:?Set JAVA_HOME to a JDK}"
host_src=$(cd "$(dirname "$0")" && pwd)
host_out=${1:-"$PWD/widget-test-host.apk"}
host_tmp=$(mktemp -d)
trap 'rm -rf -- "$host_tmp"' EXIT
host_tools="$ANDROID_HOME/build-tools/36.0.0"
host_sdk="$ANDROID_HOME/platforms/android-36/android.jar"
mkdir -p "$host_tmp/classes" "$host_tmp/dex"
"$JAVA_HOME/bin/javac" --release 8 -cp "$host_sdk" -d "$host_tmp/classes" "$host_src/HostActivity.java"
"$JAVA_HOME/bin/jar" cf "$host_tmp/classes.jar" -C "$host_tmp/classes" .
"$host_tools/d8" --min-api 24 --lib "$host_sdk" --output "$host_tmp/dex" "$host_tmp/classes.jar"
"$host_tools/aapt2" link -I "$host_sdk" --manifest "$host_src/AndroidManifest.xml" -o "$host_tmp/base.apk"
(cd "$host_tmp/dex" && zip -q "$host_tmp/base.apk" classes.dex)
"$host_tools/zipalign" -f 4 "$host_tmp/base.apk" "$host_tmp/aligned.apk"
"$JAVA_HOME/bin/keytool" -genkeypair -keystore "$host_tmp/host.p12" -alias host -storepass test-only -keypass test-only -keyalg RSA -keysize 2048 -validity 30 -dname 'CN=Widget Test Host'
"$host_tools/apksigner" sign --ks "$host_tmp/host.p12" --ks-pass pass:test-only --out "$host_out" "$host_tmp/aligned.apk"
