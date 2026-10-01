#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p ios/build
bash ios/bootstrap.sh
xcodebuild -version
xcrun simctl list devices available --json > ios/build/devices.json
export IOS_SIMULATOR_SDK="$(xcrun --sdk iphonesimulator --show-sdk-version)"
DEVICE="$(python3 - <<'PY'
import json, os, re
from pathlib import Path
j=json.loads(Path('ios/build/devices.json').read_text())
sdk=tuple(map(int,os.environ['IOS_SIMULATOR_SDK'].split('.')[:2]))
candidates=[]
for runtime, devices in j['devices'].items():
    match=re.search(r'iOS-(\d+)-(\d+)',runtime)
    if not match:
        continue
    version=tuple(map(int,match.groups()))
    if version > sdk or version < (16,0):
        continue
    for d in devices:
        if d['name'].startswith('iPhone') and d.get('isAvailable'):
            candidates.append((version,d['name'],d['udid']))
if not candidates:
    raise SystemExit('No iPhone simulator compatible with the selected Xcode SDK')
version,name,udid=sorted(candidates,reverse=True)[0]
Path('ios/build/selected-device.json').write_text(json.dumps({'runtime':version,'device':name,'sdk':sdk}))
print(udid)
PY
)"
xcrun simctl boot "$DEVICE" 2>/dev/null || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl io "$DEVICE" recordVideo ios/build/ui-tests.mov > ios/build/video.log 2>&1 &
VIDEO_PID=$!
cleanup() { kill -INT "$VIDEO_PID" 2>/dev/null || true; wait "$VIDEO_PID" 2>/dev/null || true; }
trap cleanup EXIT
set +e
xcodebuild -project ios/APS.xcodeproj -scheme APS \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -derivedDataPath ios/build/DerivedData -resultBundlePath ios/build/Tests.xcresult \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test 2>&1 | tee ios/build/xcodebuild.log
TEST_STATUS=${PIPESTATUS[0]}
set -e
cleanup
trap - EXIT
# Keep failure screenshots as well; never change the original test exit status.
xcrun xcresulttool export attachments --path ios/build/Tests.xcresult --output-path ios/build/screenshots || true
xcrun xcresulttool get test-results summary --path ios/build/Tests.xcresult > ios/build/test-summary.json || true
if [ "$TEST_STATUS" -eq 0 ]; then
  # Preserve executable permissions and bundle structure inside the Actions artifact.
  ditto -c -k --sequesterRsrc --keepParent \
    ios/build/DerivedData/Build/Products/Debug-iphonesimulator/APS.app ios/build/aps-ios-simulator.zip
fi
exit "$TEST_STATUS"
