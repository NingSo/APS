#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p ios/build
bash ios/bootstrap.sh
xcodebuild -version
xcrun simctl list devices available --json > ios/build/devices.json
DEVICE="$(python3 - <<'PY'
import json
from pathlib import Path
j=json.loads(Path('ios/build/devices.json').read_text())
for runtime, devices in sorted(j['devices'].items(),reverse=True):
    for d in devices:
        if 'iOS' in runtime and d['name'].startswith('iPhone') and d.get('isAvailable'):
            print(d['udid']); raise SystemExit
raise SystemExit('No available iPhone simulator')
PY
)"
# bootstatus waits for readiness; no fixed boot delay.
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl io "$DEVICE" recordVideo ios/build/ui-tests.mov > ios/build/video.log 2>&1 &
VIDEO_PID=$!
cleanup() { kill -INT "$VIDEO_PID" 2>/dev/null || true; wait "$VIDEO_PID" 2>/dev/null || true; }
trap cleanup EXIT
xcodebuild -project ios/APS.xcodeproj -scheme APS \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath ios/build/DerivedData -resultBundlePath ios/build/Tests.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee ios/build/xcodebuild.log
cleanup
trap - EXIT
xcrun xcresulttool export attachments --path ios/build/Tests.xcresult --output-path ios/build/screenshots || true
