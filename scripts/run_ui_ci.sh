#!/usr/bin/env bash
set -euo pipefail
pixels="${1:?pixel width required}"
width="${2:?logical width required}"
[[ "$pixels" =~ ^[0-9]+$ && "$width" =~ ^[0-9]+$ ]] || exit 2
adb shell wm size "${pixels}x2676"
adb shell wm density 480
chmod +x gradlew
status=0
./gradlew :app:connectedDebugAndroidTest --stacktrace || status=$?
mkdir -p build/native-screenshots
if adb shell run-as com.ningso.aps.debug test -d files/screenshots; then
  adb exec-out run-as com.ningso.aps.debug tar -cf - -C files screenshots > "build/native-screenshots/native-${width}dp.tar"
fi
exit "$status"
